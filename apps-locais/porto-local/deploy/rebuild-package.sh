#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/porto-local
B=/root/pkgs/build/populos_porto_local
I=$B/epm/input/populos_porto_local_app
cp "$SRC/elux/porto-local.service" "$I/usr/lib/systemd/system/"
cp "$SRC/elux/porto-local.conf" "$I/usr/lib/tmpfiles.d/"
cp -r "$SRC/app/." "$I/opt/porto-local/"
IMG=$(cat /root/epkg-image)
docker run --rm -v "$B/epm:/epm" -v "$B/data:/data" "$IMG" epkg Build --container elux7 --releaseType test --skipSign --log > "$B/build.log" 2>&1 || { tail -50 "$B/build.log"; exit 1; }
cp "$B/epm/output/container/"*/*.epm "$B/epm/output/container/"*/*.fpm "$SRC/saida/"
echo 'Pacote local final recompilado, sem depender de grupo elux.'
