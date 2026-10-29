"""Backend autônomo do eLux: loopback, dados persistentes e chave própria por aparelho."""
import fcntl
import os
from pathlib import Path
import secrets
import sys
import time

os.umask(0o077)
ROOT = Path(os.environ.get('BTG_LOCAL_ROOT', '/setup/btg-local'))
ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
lock = (ROOT / '.servico.lock').open('a')
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    sys.exit(0)
auth = ROOT / 'admin-auth.json'
while not auth.is_file():
    time.sleep(3)  # Scout pode entregar a configuração depois do primeiro boot da imagem.
key_path = ROOT / '.chave-local'
if not key_path.exists():
    key_path.write_text(secrets.token_hex(32), encoding='ascii')
    key_path.chmod(0o600)
os.environ.update(BTG_DADOS=str(ROOT / 'dados'), BTG_ADMIN_AUTH=str(auth),
                  BTG_CHAVE=key_path.read_text(encoding='ascii').strip(),
                  BTG_CADASTRAR='/usr/bin/btg-local-cadastrar')
sys.path.insert(0, '/opt/btg-local/vendor')
from app import app
from waitress import serve
serve(app, host='127.0.0.1', port=int(os.environ.get('BTG_PORTA', '3132')), threads=6)
