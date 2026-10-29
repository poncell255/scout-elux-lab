"""Servidor de prévia: dados temporários com segurados fictícios; imprime as URLs de admin e de sessão."""
import base64, hashlib, importlib.util, json, os, secrets, sys, tempfile
from pathlib import Path

tmp = tempfile.mkdtemp()
pw = 'previa'
salt = secrets.token_bytes(16)
auth = Path(tmp) / 'admin-auth.json'
auth.write_text(json.dumps({'salt': salt.hex(), 'iterations': 1000, 'digest': hashlib.pbkdf2_hmac('sha256', pw.encode(), salt, 1000).hex()}))
os.environ.update(PORTO_DADOS=tmp, PORTO_ADMIN_AUTH=str(auth), PORTO_CHAVE='k' * 64, PORTO_CADASTRAR='/bin/false')
spec = importlib.util.spec_from_file_location('porto', '/app/app.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
c = mod.app.test_client()
adm = {'Authorization': 'Basic ' + base64.b64encode(b'admin:' + pw.encode()).decode(), 'X-CSRF-Token': mod.CSRF}
for nome, plano in (('Ana Souza', 'completo'), ('Bruno Lima', 'auto')):
    sid = c.post('/porto/admin/api/segurados', json={'nome': nome, 'nascimento': '1988-04-12', 'plano': plano}, headers=adm).json['id']
    (mod.DIGITAIS / f'{sid}.fpr').write_bytes(b'x')
    with mod.app.app_context(), mod.db():
        mod.db().execute('UPDATE segurados SET digital=1 WHERE id=?', (sid,))
tokens = [c.post('/porto/api/sessao', data={'segurado': 1, 'dispositivo': 'NotebookCinza'}, headers={'X-Porto-Chave': 'k' * 64}).data.decode() for _ in range(3)]
print('TOKENS', ' '.join(tokens), flush=True)
try:
    from waitress import serve
    serve(mod.app, host='0.0.0.0', port=3133, threads=4)
except ImportError:
    mod.app.run(host='0.0.0.0', port=3133, threaded=True)
