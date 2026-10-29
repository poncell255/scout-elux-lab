#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/btg-local
B=/root/pkgs/build/populos_btg_local
I=$B/epm/input/populos_btg_local_app
cp "$SRC/elux/btg-local.service" "$I/usr/lib/systemd/system/"
cp "$SRC/elux/btg-local.conf" "$I/usr/lib/tmpfiles.d/"
cp -r "$SRC/app/." "$I/opt/btg-local/"
IMG=$(cat /root/epkg-image)
docker run --rm -v "$B/epm:/epm" -v "$B/data:/data" "$IMG" epkg Build --container elux7 --releaseType test --skipSign --log > "$B/build.log" 2>&1 || { tail -50 "$B/build.log"; exit 1; }
cp "$B/epm/output/container/"*/*.epm "$B/epm/output/container/"*/*.fpm "$SRC/saida/"
echo 'Pacote local final recompilado, sem depender de grupo elux.'
