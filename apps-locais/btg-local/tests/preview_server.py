"""Servidor de prévia: dados temporários com um cliente fictício; imprime as URLs de admin e de sessão."""
import base64, hashlib, importlib.util, json, os, secrets, sys, tempfile
from pathlib import Path

tmp = tempfile.mkdtemp()
pw = 'previa'
salt = secrets.token_bytes(16)
auth = Path(tmp) / 'admin-auth.json'
auth.write_text(json.dumps({'salt': salt.hex(), 'iterations': 1000, 'digest': hashlib.pbkdf2_hmac('sha256', pw.encode(), salt, 1000).hex()}))
os.environ.update(BTG_DADOS=tmp, BTG_ADMIN_AUTH=str(auth), BTG_CHAVE='k' * 64, BTG_CADASTRAR='/bin/false')
spec = importlib.util.spec_from_file_location('btg', '/app/app.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
c = mod.app.test_client()
adm = {'Authorization': 'Basic ' + base64.b64encode(b'admin:' + pw.encode()).decode(), 'X-CSRF-Token': mod.CSRF}
for nome, perfil in (('Ana Souza', 'arrojado'), ('Bruno Lima', 'moderado')):
    cid = c.post('/btg/admin/api/clientes', json={'nome': nome, 'nascimento': '1988-04-12', 'perfil': perfil}, headers=adm).json['id']
    (mod.DIGITAIS / f'{cid}.fpr').write_bytes(b'x')
    with mod.app.app_context(), mod.db():
        mod.db().execute('UPDATE clientes SET digital=1 WHERE id=?', (cid,))
tokens = [c.post('/btg/api/sessao', data={'cliente': 1, 'dispositivo': 'NotebookCinza'}, headers={'X-BTG-Chave': 'k' * 64}).data.decode() for _ in range(3)]
print('TOKENS', ' '.join(tokens), flush=True)
from waitress import serve
serve(mod.app, host='0.0.0.0', port=3132, threads=4)
