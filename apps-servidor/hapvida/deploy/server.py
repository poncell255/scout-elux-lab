"""Provisiona apenas o container HAPVIDA. Credenciais chegam por stdin, nunca em arquivos."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.request

credentials = json.load(sys.stdin)
if set(credentials) != {'HAPVIDA_ADMIN', 'HAPVIDA_CHAVE'}:
    raise SystemExit('Credenciais esperadas não recebidas.')
if subprocess.run(['docker', 'container', 'inspect', 'hapvida'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    raise SystemExit('Container hapvida já existe; preservado. Inspecione antes de atualizar.')
folder = Path('/root/hapvida')
folder.mkdir(mode=0o700, exist_ok=True)
(folder / 'data').mkdir(mode=0o700, exist_ok=True)
env = os.environ.copy()
env.update(credentials)
subprocess.run(['docker', 'run', '-d', '--name', 'hapvida', '--restart', 'unless-stopped',
                '-p', '127.0.0.1:3101:3101', '--env', 'HAPVIDA_ADMIN', '--env', 'HAPVIDA_CHAVE',
                '-v', '/root/hapvida/data:/data', '-v', '/mnt/c/ScoutSetup/hapvida/app:/app:ro',
                '-v', '/dev/bus/usb:/dev/bus/usb', '--device-cgroup-rule=c 189:* rmw',
                'populos-provas'], env=env, check=True, stdout=subprocess.DEVNULL)
for _ in range(20):
    try:
        with urllib.request.urlopen('http://127.0.0.1:3101/hapvida/', timeout=2) as response:
            if response.status == 200:
                print('Container HAPVIDA ativo; HTTP 200. Credenciais não exibidas.')
                break
    except Exception:
        time.sleep(1)
else:
    raise SystemExit('Container criado, mas a verificação HTTP falhou; verificar logs sem expor credenciais.')
