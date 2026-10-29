"""Backend autônomo do eLux: loopback, dados persistentes e chave própria por aparelho."""
import fcntl
import os
from pathlib import Path
import secrets
import sys
import time

os.umask(0o077)
ROOT = Path(os.environ.get('PORTO_LOCAL_ROOT', '/setup/porto-local'))
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
os.environ.update(PORTO_DADOS=str(ROOT / 'dados'), PORTO_ADMIN_AUTH=str(auth),
                  PORTO_CHAVE=key_path.read_text(encoding='ascii').strip(),
                  PORTO_CADASTRAR='/usr/bin/porto-local-cadastrar')
sys.path.insert(0, '/opt/porto-local/vendor')
from app import app
from waitress import serve
serve(app, host='127.0.0.1', port=int(os.environ.get('PORTO_PORTA', '3133')), threads=6)
