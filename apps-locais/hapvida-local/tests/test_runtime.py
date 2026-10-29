"""Teste do pacote instalado sem rede externa, com persistência após reiniciar o backend."""
import base64
import hashlib
import http.cookiejar
import io
import json
import os
from pathlib import Path
import secrets
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    password = secrets.token_hex(24)
    salt = secrets.token_bytes(16)
    (root / 'admin-auth.json').write_text(json.dumps({'salt': salt.hex(), 'iterations': 210000,
        'digest': hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 210000).hex()}))
    env = os.environ.copy()
    env.update(HAPVIDA_LOCAL_ROOT=tmp, HAPVIDA_PORTA='3132')
    base = 'http://127.0.0.1:3132/hapvida'
    auth = {'Authorization': 'Basic ' + base64.b64encode(('admin:' + password).encode()).decode()}
    process = None

    def start():
        global process
        process = subprocess.Popen([sys.executable, '/opt/hapvida-local/run.py'], env=env,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        for _ in range(80):
            try:
                with urllib.request.urlopen(base + '/health', timeout=1) as response:
                    assert json.load(response)['modo'] == 'local'
                    return
            except OSError:
                if process.poll() is not None:
                    raise RuntimeError('Servico local encerrou durante inicializacao: ' + process.stderr.read().decode()[:300])
                time.sleep(0.1)
        raise RuntimeError('Servico local nao iniciou.')

    def stop():
        if process and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        if process:
            process.stderr.close()

    def call(path, data=None, headers=None, opener=None):
        request = urllib.request.Request(base + path, data=data, headers=headers or {})
        with (opener or urllib.request).open(request, timeout=5) if opener else urllib.request.urlopen(request, timeout=5) as response:
            return response.read()

    try:
        start()
        listing = json.loads(call('/admin/api/pacientes', headers=auth))
        assert listing['pacientes'] == []
        headers = {**auth, 'X-CSRF-Token': listing['csrf'], 'Content-Type': 'application/json'}
        created = json.loads(call('/admin/api/pacientes', json.dumps({'nome': 'Paciente Offline de Teste',
                                  'nascimento': '1988-04-18', 'perfil': 'checkup'}).encode(), headers))['id']
        # Artefato de teste apenas: o hardware biometrico real e validado separadamente.
        (root / 'dados' / 'digitais' / f'{created}.fpr').write_bytes(b'fixture-not-a-fingerprint')
        with sqlite3.connect(root / 'dados' / 'hapvida.db') as conn:
            conn.execute('UPDATE pacientes SET digital=1 WHERE id=?', (created,))
        key = (root / '.chave-local').read_text()
        native = {'X-Hapvida-Chave': key}
        gallery = call('/api/galeria', headers=native)
        with tarfile.open(fileobj=io.BytesIO(gallery), mode='r:gz') as archive:
            assert archive.getnames() == [f'{created}.fpr']
        token = call('/api/sessao', f'paciente={created}&dispositivo=teste-offline'.encode(), native).decode()
        jar = http.cookiejar.CookieJar()
        browser = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        call('/entrar/' + token, opener=browser)
        records = json.loads(call('/api/me', opener=browser))
        assert records['paciente']['id'] == created and len(records['documentos']) == 6
        stop()
        start()
        listing = json.loads(call('/admin/api/pacientes', headers=auth))
        assert len(listing['pacientes']) == 1 and listing['pacientes'][0]['id'] == created
        assert (root / '.chave-local').read_text() == key
        assert (root / 'dados' / 'digitais' / f'{created}.fpr').is_file()
        print('Pacote instalado: backend local, cadastro, galeria, sessao e seis documentos OK sem rede externa.')
        print('Persistencia apos reiniciar backend: paciente, digital e chave local preservados.')
    finally:
        stop()
