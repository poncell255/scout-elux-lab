#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/porto-local
VERSAO=${1:-1.0.0}
PAYLOAD=/root/pkgs/porto-local-payload-qa
rm -rf "$PAYLOAD"; mkdir -p "$PAYLOAD"
python3 "$SRC/deploy/extract-fpm.py" "$SRC/saida/populos_porto_local_app-$VERSAO-1~testing.UC_ELUX7-1.0.fpm" "$PAYLOAD"
test -L "$PAYLOAD/usr/lib/systemd/system/multi-user.target.wants/porto-local.service"
for f in admin cliente cadastrar digital; do test -x "$PAYLOAD/usr/bin/porto-local-$f"; done
test -f "$PAYLOAD/opt/porto-local/vendor/waitress/__init__.py"
echo 'Atalhos executaveis, waitress e servico habilitado no payload conferidos.'
