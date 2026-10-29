import base64
import hashlib
import json
import importlib.util
import io
import os
from pathlib import Path
import secrets
import tempfile
import unittest

TEMP = tempfile.TemporaryDirectory()
PASSWORD = secrets.token_hex(24)
SALT = secrets.token_bytes(16)
AUTH = Path(TEMP.name) / 'admin-auth.json'
AUTH.write_text(json.dumps({'salt': SALT.hex(), 'iterations': 210000, 'digest': hashlib.pbkdf2_hmac('sha256', PASSWORD.encode(), SALT, 210000).hex()}))
os.environ.update(BTG_DADOS=TEMP.name, BTG_ADMIN_AUTH=str(AUTH), BTG_CHAVE=secrets.token_hex(24), BTG_CADASTRAR='/bin/false')
spec = importlib.util.spec_from_file_location('btg', '/app/app.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class AgenciaTests(unittest.TestCase):
    def setUp(self):
        self.client = mod.app.test_client()
        self.admin = {'Authorization': 'Basic ' + base64.b64encode(('admin:' + PASSWORD).encode()).decode(), 'X-CSRF-Token': mod.CSRF}
        self.key = {'X-BTG-Chave': mod.KEY}
        with mod.app.app_context(), mod.db():
            for table in ('sessoes', 'acessos', 'itens', 'clientes'):
                mod.db().execute(f'DELETE FROM {table}')

    def new_client(self, name='Ana Teste', perfil='moderado'):
        r = self.client.post('/btg/admin/api/clientes', json={'nome': name, 'nascimento': '1990-01-02', 'perfil': perfil}, headers=self.admin)
        self.assertEqual(r.status_code, 201, r.data)
        return r.json['id']

    def enroll(self, cid):
        (mod.DIGITAIS / f'{cid}.fpr').write_bytes(b'ficticio')
        with mod.app.app_context(), mod.db():
            mod.db().execute('UPDATE clientes SET digital=1 WHERE id=?', (cid,))

    def login(self, cid):
        r = self.client.post('/btg/api/sessao', data={'cliente': cid, 'dispositivo': 'teste'}, headers=self.key)
        self.assertEqual(r.status_code, 200)
        token = r.data.decode()
        self.assertEqual(self.client.get('/btg/entrar/' + token).status_code, 303)
        return token

    def test_admin_auth_and_csrf(self):
        self.assertEqual(self.client.get('/btg/admin').status_code, 401)
        no_csrf = {'Authorization': self.admin['Authorization']}
        self.assertEqual(self.client.post('/btg/admin/api/clientes', json={}, headers=no_csrf).status_code, 403)
        self.assertEqual(self.client.post('/btg/admin/api/clientes', json={'nome': 'Ana', 'nascimento': '1990-01-01', 'perfil': 'x'}, headers=self.admin).status_code, 400)

    def test_synthetic_account_by_profile(self):
        c = self.new_client(perfil='conservador')
        a = self.new_client('Bruno Teste', perfil='arrojado')
        lst = self.client.get('/btg/admin/api/clientes', headers=self.admin).json['clientes']
        self.assertEqual({x['id'] for x in lst}, {c, a})
        self.assertRegex(lst[0]['conta'], r'^\d{6}-\d$')
        with mod.app.app_context():
            count = lambda cid, t: mod.db().execute('SELECT COUNT(*) FROM itens WHERE cliente=? AND tipo=?', (cid, t)).fetchone()[0]
            self.assertEqual(count(c, 'investimento'), 3)
            self.assertEqual(count(a, 'investimento'), 5)
            self.assertEqual(count(a, 'operacao'), 3)

    def test_session_flow_and_isolation(self):
        a = self.new_client()
        b = self.new_client('Outro Cliente')
        self.assertEqual(self.client.post('/btg/api/sessao', data={'cliente': a}, headers=self.key).status_code, 409)
        self.assertEqual(self.client.post('/btg/api/sessao', data={'cliente': a}).status_code, 403)
        self.enroll(a)
        token = self.login(a)
        me = self.client.get('/btg/api/me').json
        self.assertEqual(me['cliente']['id'], a)
        self.assertTrue(all(i['cliente'] == a for i in me['itens']))
        self.assertEqual(self.client.get('/btg/entrar/' + token).status_code, 401)  # uso único
        other = [i for i in me['itens'] if i['tipo'] == 'operacao'][0]['id']
        with mod.app.app_context():
            bop = mod.db().execute("SELECT id FROM itens WHERE cliente=? AND tipo='operacao'", (b,)).fetchone()[0]
        h = {'X-CSRF-Token': me['csrf']}
        self.assertEqual(self.client.post(f'/btg/api/operacoes/{bop}/aprovar', headers=h).status_code, 409)
        self.assertEqual(self.client.post(f'/btg/api/operacoes/{other}/aprovar').status_code, 403)
        self.assertEqual(self.client.post('/btg/api/sair', headers=h).status_code, 200)
        self.assertEqual(self.client.get('/btg/api/me').status_code, 401)

    def test_approve_updates_balance_once(self):
        a = self.new_client()
        self.enroll(a)
        self.login(a)
        me = self.client.get('/btg/api/me').json
        saldo = lambda d: [i for i in d['itens'] if i['tipo'] == 'saldo'][0]['valor']
        pix = [i for i in me['itens'] if i['tipo'] == 'operacao' and i['categoria'] == 'Transferência PIX'][0]
        h = {'X-CSRF-Token': me['csrf']}
        r = self.client.post(f"/btg/api/operacoes/{pix['id']}/aprovar", headers=h)
        self.assertEqual(r.json['estado'], 'aprovada')
        self.assertEqual(self.client.post(f"/btg/api/operacoes/{pix['id']}/aprovar", headers=h).status_code, 409)
        after = self.client.get('/btg/api/me').json
        self.assertAlmostEqual(saldo(after), saldo(me) - pix['valor'], places=2)
        op = [i for i in after['itens'] if i['id'] == pix['id']][0]
        self.assertIn('digital', op['assinado'])
        lim = [i for i in after['itens'] if i['tipo'] == 'operacao' and i['valor'] == 0][0]
        self.assertEqual(self.client.post(f"/btg/api/operacoes/{lim['id']}/recusar", headers=h).json['estado'], 'recusada')

    def test_expired_and_native_logout(self):
        a = self.new_client()
        self.enroll(a)
        token = self.login(a)
        self.assertEqual(self.client.post(f'/btg/api/sessao/{token}/encerrar', headers=self.key).status_code, 200)
        self.assertEqual(self.client.get('/btg/api/me').status_code, 401)

    def test_photo_private(self):
        a = self.new_client()
        r = self.client.post(f'/btg/admin/api/clientes/{a}/foto', data={'foto': (io.BytesIO(b'<svg></svg>'), 'x.svg')}, headers=self.admin)
        self.assertEqual(r.status_code, 400)
        png = b'\x89PNG\r\n\x1a\n' + b'0' * 32
        r = self.client.post(f'/btg/admin/api/clientes/{a}/foto', data={'foto': (io.BytesIO(png), 'f.png')}, headers=self.admin)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.client.get(f'/btg/admin/api/clientes/{a}/foto').status_code, 401)

    def test_gallery_and_pages(self):
        a = self.new_client()
        self.enroll(a)
        self.assertEqual(self.client.get('/btg/api/galeria').status_code, 403)
        self.assertEqual(self.client.get('/btg/api/galeria', headers=self.key).status_code, 200)
        for path in ('/', '/encerrado', '/static/style.css', '/static/portal.js', '/static/admin.js', '/static/logo.png', '/static/logo-branco.png', '/health'):
            r = self.client.get('/btg' + path)
            self.assertEqual(r.status_code, 200, path)
            r.close()
        self.assertEqual(self.client.get('/btg/portal').status_code, 401)
        with self.client.get('/btg/admin', headers=self.admin) as r:
            self.assertEqual(r.status_code, 200)


if __name__ == '__main__':
    unittest.main(verbosity=2)
