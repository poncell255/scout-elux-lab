"""Extrai FPM cpio/newc em pasta isolada para validar o runtime oficial."""
import gzip
import os
from pathlib import Path
import stat
import sys

source, destination = map(Path, sys.argv[1:3])
raw = source.read_bytes()
offset = -1
for _ in range(100):
    offset = raw.find(b'\x1f\x8b\x08', offset + 1)
    if offset < 0:
        raise SystemExit('Payload gzip/cpio não encontrado.')
    try:
        payload = gzip.decompress(raw[offset:])
        if payload[:6] in (b'070701', b'070702'):
            break
    except (OSError, EOFError):
        continue
else:
    raise SystemExit('Payload cpio inválido.')
position = 0
count = 0
while position + 110 <= len(payload):
    header = payload[position:position + 110]
    if header[:6] not in (b'070701', b'070702'):
        raise SystemExit('Cabeçalho cpio inválido.')
    mode = int(header[14:22], 16)
    size = int(header[54:62], 16)
    namesize = int(header[94:102], 16)
    name = payload[position + 110:position + 110 + namesize - 1].decode()
    if name == 'TRAILER!!!':
        break
    relative = Path(name)
    if relative.is_absolute() or '..' in relative.parts:
        raise SystemExit('Caminho inválido no pacote.')
    start = (position + 110 + namesize + 3) & ~3
    content = payload[start:start + size]
    target = destination / relative
    if stat.S_ISDIR(mode):
        target.mkdir(parents=True, exist_ok=True)
    elif stat.S_ISREG(mode):
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        target.chmod(stat.S_IMODE(mode))
        count += 1
    elif stat.S_ISLNK(mode):
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.is_symlink() and not target.exists():
            target.symlink_to(content.decode())
    position = (start + size + 3) & ~3
print(f'{source.name}: {count} arquivos extraídos.')
