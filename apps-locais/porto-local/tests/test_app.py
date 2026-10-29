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
os.environ.update(PORTO_DADOS=TEMP.name, PORTO_ADMIN_AUTH=str(AUTH), PORTO_CHAVE=secrets.token_hex(24), PORTO_CADASTRAR='/bin/false')
spec = importlib.util.spec_from_file_location('porto', '/app/app.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class SeguradoTests(unittest.TestCase):
    def setUp(self):
        self.client = mod.app.test_client()
        self.admin = {'Authorization': 'Basic ' + base64.b64encode(('admin:' + PASSWORD).encode()).decode(), 'X-CSRF-Token': mod.CSRF}
        self.key = {'X-Porto-Chave': mod.KEY}
        with mod.app.app_context(), mod.db():
            for table in ('sessoes', 'acessos', 'itens', 'segurados'):
                mod.db().execute(f'DELETE FROM {table}')

    def new_insured(self, name='Ana Teste', plano='auto_residencia'):
        r = self.client.post('/porto/admin/api/segurados', json={'nome': name, 'nascimento': '1990-01-02', 'plano': plano}, headers=self.admin)
        self.assertEqual(r.status_code, 201, r.data)
        return r.json['id']

    def enroll(self, sid):
        (mod.DIGITAIS / f'{sid}.fpr').write_bytes(b'ficticio')
        with mod.app.app_context(), mod.db():
            mod.db().execute('UPDATE segurados SET digital=1 WHERE id=?', (sid,))

    def login(self, sid):
        r = self.client.post('/porto/api/sessao', data={'segurado': sid, 'dispositivo': 'teste'}, headers=self.key)
        self.assertEqual(r.status_code, 200)
        token = r.data.decode()
        self.assertEqual(self.client.get('/porto/entrar/' + token).status_code, 303)
        return token

    def test_admin_auth_and_csrf(self):
        self.assertEqual(self.client.get('/porto/admin').status_code, 401)
        no_csrf = {'Authorization': self.admin['Authorization']}
        self.assertEqual(self.client.post('/porto/admin/api/segurados', json={}, headers=no_csrf).status_code, 403)
        self.assertEqual(self.client.post('/porto/admin/api/segurados', json={'nome': 'Ana', 'nascimento': '1990-01-01', 'plano': 'x'}, headers=self.admin).status_code, 400)

    def test_synthetic_policies_by_plan(self):
        a = self.new_insured(plano='auto')
        c = self.new_insured('Bruno Teste', plano='completo')
        lst = self.client.get('/porto/admin/api/segurados', headers=self.admin).json['segurados']
        self.assertEqual({x['id'] for x in lst}, {a, c})
        self.assertRegex(lst[0]['codigo'], r'^PS-\d{6}-\d$')
        with mod.app.app_context():
            count = lambda sid, t: mod.db().execute('SELECT COUNT(*) FROM itens WHERE segurado=? AND tipo=?', (sid, t)).fetchone()[0]
            self.assertEqual(count(a, 'apolice'), 1)
            self.assertEqual(count(c, 'apolice'), 3)
            self.assertEqual(count(c, 'solicitacao'), 3)

    def test_session_flow_and_isolation(self):
        a = self.new_insured()
        b = self.new_insured('Outro Segurado')
        self.assertEqual(self.client.post('/porto/api/sessao', data={'segurado': a}, headers=self.key).status_code, 409)
        self.assertEqual(self.client.post('/porto/api/sessao', data={'segurado': a}).status_code, 403)
        self.enroll(a)
        token = self.login(a)
        me = self.client.get('/porto/api/me').json
        self.assertEqual(me['segurado']['id'], a)
        self.assertTrue(all(i['segurado'] == a for i in me['itens']))
        self.assertEqual(self.client.get('/porto/entrar/' + token).status_code, 401)  # uso único
        mine = [i for i in me['itens'] if i['tipo'] == 'solicitacao'][0]['id']
        with mod.app.app_context():
            other = mod.db().execute("SELECT id FROM itens WHERE segurado=? AND tipo='solicitacao'", (b,)).fetchone()[0]
        h = {'X-CSRF-Token': me['csrf']}
        self.assertEqual(self.client.post(f'/porto/api/solicitacoes/{other}/aprovar', headers=h).status_code, 409)
        self.assertEqual(self.client.post(f'/porto/api/solicitacoes/{mine}/aprovar').status_code, 403)
        self.assertEqual(self.client.post('/porto/api/sair', headers=h).status_code, 200)
        self.assertEqual(self.client.get('/porto/api/me').status_code, 401)

    def test_approve_signs_once_and_records_payment(self):
        a = self.new_insured()
        self.enroll(a)
        self.login(a)
        me = self.client.get('/porto/api/me').json
        pays = lambda d: [i for i in d['itens'] if i['tipo'] == 'pagamento']
        sin = [i for i in me['itens'] if i['tipo'] == 'solicitacao' and i['categoria'] == 'Sinistro'][0]
        h = {'X-CSRF-Token': me['csrf']}
        r = self.client.post(f"/porto/api/solicitacoes/{sin['id']}/aprovar", headers=h)
        self.assertEqual(r.json['estado'], 'aprovada')
        self.assertEqual(self.client.post(f"/porto/api/solicitacoes/{sin['id']}/aprovar", headers=h).status_code, 409)
        after = self.client.get('/porto/api/me').json
        self.assertEqual(len(pays(after)), len(pays(me)) + 1)
        self.assertIn(-sin['valor'], [p['valor'] for p in pays(after)])
        req = [i for i in after['itens'] if i['id'] == sin['id']][0]
        self.assertIn('digital', req['assinado'])
        ren = [i for i in after['itens'] if i['tipo'] == 'solicitacao' and i['categoria'] == 'Renovação'][0]
        self.client.post(f"/porto/api/solicitacoes/{ren['id']}/aprovar", headers=h)
        self.assertIn(-round(ren['valor'] / 12, 2), [p['valor'] for p in pays(self.client.get('/porto/api/me').json)])
        tow = [i for i in after['itens'] if i['tipo'] == 'solicitacao' and i['valor'] == 0][0]
        self.assertEqual(self.client.post(f"/porto/api/solicitacoes/{tow['id']}/recusar", headers=h).json['estado'], 'recusada')

    def test_expired_and_native_logout(self):
        a = self.new_insured()
        self.enroll(a)
        token = self.login(a)
        self.assertEqual(self.client.post(f'/porto/api/sessao/{token}/encerrar', headers=self.key).status_code, 200)
        self.assertEqual(self.client.get('/porto/api/me').status_code, 401)

    def test_photo_private(self):
        a = self.new_insured()
        r = self.client.post(f'/porto/admin/api/segurados/{a}/foto', data={'foto': (io.BytesIO(b'<svg></svg>'), 'x.svg')}, headers=self.admin)
        self.assertEqual(r.status_code, 400)
        png = b'\x89PNG\r\n\x1a\n' + b'0' * 32
        r = self.client.post(f'/porto/admin/api/segurados/{a}/foto', data={'foto': (io.BytesIO(png), 'f.png')}, headers=self.admin)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.client.get(f'/porto/admin/api/segurados/{a}/foto').status_code, 401)

    def test_gallery_and_pages(self):
        a = self.new_insured()
        self.enroll(a)
        self.assertEqual(self.client.get('/porto/api/galeria').status_code, 403)
        self.assertEqual(self.client.get('/porto/api/galeria', headers=self.key).status_code, 200)
        for path in ('/', '/encerrado', '/static/style.css', '/static/portal.js', '/static/admin.js', '/static/logo.png', '/static/logo-branco.png', '/health'):
            r = self.client.get('/porto' + path)
            self.assertEqual(r.status_code, 200, path)
            r.close()
        self.assertEqual(self.client.get('/porto/portal').status_code, 401)
        with self.client.get('/porto/admin', headers=self.admin) as r:
            self.assertEqual(r.status_code, 200)


if __name__ == '__main__':
    unittest.main(verbosity=2)
