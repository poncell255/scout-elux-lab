"""Atualiza credenciais de runtime via stdin; preserva dados e imagem do container."""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime


def run(args, **kwargs):
    return subprocess.run(['docker', *args], check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, **kwargs)


def request_status(password, path='/hapvida/admin'):
    encoded = base64.b64encode(('admin:' + password).encode()).decode()
    req = urllib.request.Request('http://127.0.0.1:3101' + path,
                                 headers={'Authorization': 'Basic ' + encoded})
    try:
        with urllib.request.urlopen(req, timeout=3) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, b''


def main():
    incoming = json.load(sys.stdin)
    if set(incoming) != {'HAPVIDA_ADMIN', 'HAPVIDA_CHAVE'}:
        raise RuntimeError('Dados de credencial incompletos.')
    spec = json.loads(run(['inspect', 'hapvida']).stdout)[0]
    previous = dict(item.split('=', 1) for item in spec['Config']['Env'])
    # Esta operacao troca apenas a senha administrativa; mantem a chave de runtime intacta.
    incoming['HAPVIDA_CHAVE'] = previous['HAPVIDA_CHAVE']
    status, raw = request_status(previous['HAPVIDA_ADMIN'], '/hapvida/admin/api/captura')
    if status != 200 or json.loads(raw).get('ativo'):
        raise RuntimeError('Cadastro biometrico em andamento ou consulta indisponivel; preservado.')
    if previous['HAPVIDA_ADMIN'] == incoming['HAPVIDA_ADMIN']:
        if request_status(incoming['HAPVIDA_ADMIN'])[0] != 200:
            raise RuntimeError('Verificacao da credencial falhou.')
        print('Credencial de runtime ja corresponde ao arquivo central; login HTTP 200.')
        return
    mounts = {m['Destination']: m for m in spec['Mounts']}
    if mounts.get('/data', {}).get('Source') != '/root/hapvida/data':
        raise RuntimeError('Volume de dados inesperado; preservado.')
    if mounts.get('/app', {}).get('Source') != '/mnt/c/ScoutSetup/hapvida/app':
        raise RuntimeError('Montagem de codigo inesperada; preservada.')
    ports = spec['HostConfig']['PortBindings'].get('3101/tcp', [])
    if ports != [{'HostIp': '127.0.0.1', 'HostPort': '3101'}]:
        raise RuntimeError('Porta do container diverge do esperado.')
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    backup_name = 'hapvida-antes-credencial-' + stamp
    backup_code = (
        "import sqlite3,pathlib; p=pathlib.Path('/data/backups'); p.mkdir(exist_ok=True);"
        "a=sqlite3.connect('/data/hapvida.db');"
        f"b=sqlite3.connect('/data/backups/pre-credencial-{stamp}.db');"
        "a.backup(b); b.close(); a.close()"
    )
    run(['exec', 'hapvida', 'python3', '-c', backup_code])
    renamed = False
    created = False
    try:
        run(['stop', '--time', '15', 'hapvida'])
        run(['rename', 'hapvida', backup_name])
        renamed = True
        environment = os.environ.copy()
        environment.update(previous)
        environment.update(incoming)
        args = ['run', '-d', '--name', 'hapvida', '--restart', 'unless-stopped',
                '-p', '127.0.0.1:3101:3101', '-v', '/root/hapvida/data:/data',
                '-v', '/mnt/c/ScoutSetup/hapvida/app:/app:ro',
                '-v', '/dev/bus/usb:/dev/bus/usb', '--device-cgroup-rule=c 189:* rmw']
        for name in previous:
            args.extend(['--env', name])
        args.append(spec['Image'])
        run(args, env=environment)
        created = True
        for _ in range(25):
            try:
                if request_status(incoming['HAPVIDA_ADMIN'])[0] == 200:
                    break
            except (OSError, urllib.error.URLError):
                pass
            time.sleep(0.5)
        else:
            raise RuntimeError('Novo container nao passou na verificacao de login.')
        if request_status(previous['HAPVIDA_ADMIN'])[0] != 401:
            raise RuntimeError('Credencial anterior ainda aceita; verificar rotacao.')
    except Exception:
        if created:
            run(['rm', '--force', 'hapvida'])  # sem -v: nenhum volume de dados removido
        if renamed:
            run(['rename', backup_name, 'hapvida'])
        run(['start', 'hapvida'])
        raise
    cleanup = subprocess.run(['docker', 'rm', backup_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if cleanup.returncode:
        print('Container anterior permaneceu parado para revisao; rotacao de senha confirmada.')
    print('Senha administrativa aplicada: login novo HTTP 200; credencial anterior HTTP 401.')
    print('Mesmo volume de pacientes/fotos/digitais e mesma imagem preservados; backup SQLite criado.')


try:
    main()
except RuntimeError as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
except Exception:
    print('Rotacao nao concluida; detalhes omitidos para proteger credenciais. Verifique o estado antes de repetir.', file=sys.stderr)
    sys.exit(1)
