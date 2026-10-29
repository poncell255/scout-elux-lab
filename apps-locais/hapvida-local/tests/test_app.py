import base64
import hashlib
import json
import importlib.util
import io
import os
from pathlib import Path
import secrets
import tempfile
import time
import unittest

TEMP = tempfile.TemporaryDirectory()
PASSWORD = secrets.token_hex(24)
SALT = secrets.token_bytes(16)
AUTH = Path(TEMP.name) / 'admin-auth.json'
AUTH.write_text(json.dumps({'salt': SALT.hex(), 'iterations': 210000, 'digest': hashlib.pbkdf2_hmac('sha256', PASSWORD.encode(), SALT, 210000).hex()}))
os.environ.update(HAPVIDA_DADOS=TEMP.name, HAPVIDA_ADMIN_AUTH=str(AUTH), HAPVIDA_CHAVE=secrets.token_hex(24), HAPVIDA_CADASTRAR='/bin/false')
spec = importlib.util.spec_from_file_location('hapvida', '/app/app.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class PortalTests(unittest.TestCase):
    def setUp(self):
        self.client = mod.app.test_client()
        self.admin = {'Authorization': 'Basic ' + base64.b64encode(('admin:' + PASSWORD).encode()).decode(), 'X-CSRF-Token': mod.CSRF}
        self.key = {'X-Hapvida-Chave': mod.KEY}
        with mod.app.app_context(), mod.db():
            for table in ('sessoes', 'acessos', 'documentos', 'pacientes'):
                mod.db().execute('DELETE FROM ' + table)

    def new(self, name='Paciente de Teste'):
        response = self.client.post('/hapvida/admin/api/pacientes', json={'nome': name, 'nascimento': '1990-01-02'}, headers=self.admin)
        self.assertEqual(response.status_code, 201)
        return response.json['id']

    def enrolled(self, name='Paciente de Teste'):
        pid = self.new(name)
        # Artefato fictício apenas para testar autorização e arquivo; não é uma digital.
        (mod.DIGITAIS / f'{pid}.fpr').write_bytes(b'test-fixture-not-a-fingerprint')
        with mod.app.app_context(), mod.db():
            mod.db().execute('UPDATE pacientes SET digital=1 WHERE id=?', (pid,))
        return pid

    def login(self, pid):
        r = self.client.post('/hapvida/api/sessao', data={'paciente': pid, 'dispositivo': 'teste-isolado'}, headers=self.key)
        self.assertEqual(r.status_code, 200)
        token = r.get_data(as_text=True)
        self.assertEqual(len(token), 64)
        self.assertEqual(self.client.get('/hapvida/entrar/' + token).status_code, 303)
        return token

    def test_admin_and_csrf(self):
        self.assertEqual(self.client.get('/hapvida/admin').status_code, 401)
        no_csrf = {k: v for k, v in self.admin.items() if k != 'X-CSRF-Token'}
        self.assertEqual(self.client.post('/hapvida/admin/api/pacientes', json={}, headers=no_csrf).status_code, 403)
        self.assertEqual(self.client.get('/hapvida/admin/api/pacientes', headers=self.admin).json['csrf'], mod.CSRF)

    def test_registration_validation_and_synthetic_history(self):
        self.assertEqual(self.client.post('/hapvida/admin/api/pacientes', json={'nome': 'X', 'nascimento': 'future'}, headers=self.admin).status_code, 400)
        pid = self.new('<Paciente & teste>')
        with mod.app.app_context():
            docs = mod.db().execute('SELECT * FROM documentos WHERE paciente=?', (pid,)).fetchall()
            self.assertEqual(len(docs), 6)
            self.assertEqual(sum(r['tipo'] == 'exame' for r in docs), 3)
        self.assertEqual(self.client.post('/hapvida/api/sessao', data={'paciente': pid}, headers=self.key).status_code, 409)

    def test_gallery_and_record_access_require_auth(self):
        self.assertEqual(self.client.get('/hapvida/api/galeria').status_code, 403)
        self.assertEqual(self.client.get('/hapvida/api/me').status_code, 401)
        self.assertEqual(self.client.get('/hapvida/api/me/foto').status_code, 401)
        self.assertEqual(self.client.post('/hapvida/api/sessao', data={'paciente': 1}).status_code, 403)

    def test_patient_isolation_token_replay_and_logout(self):
        p1 = self.enrolled('Primeiro paciente')
        p2 = self.enrolled('Segundo paciente')
        token = self.login(p1)
        r = self.client.get('/hapvida/api/me')
        self.assertEqual(r.json['paciente']['id'], p1)
        self.assertTrue(all(d['paciente'] == p1 for d in r.json['documentos']))
        self.assertNotIn('Segundo paciente', r.get_data(as_text=True))
        self.assertEqual(self.client.get('/hapvida/entrar/' + token).status_code, 401)
        self.assertEqual(self.client.post('/hapvida/api/sair').status_code, 403)
        self.assertEqual(self.client.post('/hapvida/api/sair', headers={'X-CSRF-Token': r.json['csrf']}).status_code, 200)
        self.assertEqual(self.client.get('/hapvida/api/me').status_code, 401)

    def test_expiration_and_native_revoke(self):
        pid = self.enrolled()
        token = self.login(pid)
        with mod.app.app_context(), mod.db():
            mod.db().execute('UPDATE acessos SET expira=0 WHERE token_hash=?', (mod.digest(token),))
        self.assertEqual(self.client.get('/hapvida/api/me').status_code, 401)
        token = self.login(pid)
        self.assertEqual(self.client.post(f'/hapvida/api/sessao/{token}/encerrar', headers=self.key).status_code, 200)
        self.assertEqual(self.client.get('/hapvida/api/me').status_code, 401)

    def test_photo_upload_validation_and_private_delivery(self):
        pid = self.enrolled()
        r = self.client.post(f'/hapvida/admin/api/pacientes/{pid}/foto', data={'foto': (io.BytesIO(b'<svg></svg>'), 'test.svg')}, headers=self.admin)
        self.assertEqual(r.status_code, 400)
        png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jB34AAAAASUVORK5CYII=')
        r = self.client.post(f'/hapvida/admin/api/pacientes/{pid}/foto', data={'foto': (io.BytesIO(png), 'foto.png')}, headers=self.admin)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.client.get(f'/hapvida/admin/api/pacientes/{pid}/foto').status_code, 401)
        self.login(pid)
        response = self.client.get('/hapvida/api/me/foto')
        self.assertEqual(response.data, png)
        self.assertEqual(response.headers['Cache-Control'], 'no-store')
        response.close()

    def test_failed_capture_preserves_previous(self):
        pid = self.enrolled()
        before = (mod.DIGITAIS / f'{pid}.fpr').read_bytes()
        mod.CANCEL.clear()
        mod.CAPTURE.update(ativo=True, ok=False)
        mod.capture(pid, 'Teste')
        self.assertFalse(mod.CAPTURE['ok'])
        self.assertFalse(mod.CAPTURE['ativo'])
        self.assertEqual((mod.DIGITAIS / f'{pid}.fpr').read_bytes(), before)

    def test_pages_assets_headers(self):
        for path in ('/', '/static/style.css', '/static/admin.js', '/static/portal.js', '/static/logo.png'):
            r = self.client.get('/hapvida' + path)
            self.assertEqual(r.status_code, 200)
            self.assertEqual(r.headers['Referrer-Policy'], 'no-referrer')
            r.close()
        with self.client.get('/hapvida/admin', headers=self.admin) as r:
            self.assertEqual(r.status_code, 200)


if __name__ == '__main__':
    unittest.main(verbosity=2)
