#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/btg-local
ROOT=/root/pkgs/btg-local-runtime
PAYLOAD=/root/pkgs/btg-local-payload-qa
mkdir -p "$PAYLOAD"
python3 "$SRC/deploy/extract-fpm.py" "$SRC/saida/populos_btg_local_app-1.0.0-1~testing.UC_ELUX7-1.0.fpm" "$PAYLOAD"
test -L "$PAYLOAD/usr/lib/systemd/system/multi-user.target.wants/btg-local.service"
test -x "$PAYLOAD/usr/bin/btg-local-admin"
test -x "$PAYLOAD/usr/bin/btg-local-paciente"
test -x "$PAYLOAD/usr/bin/btg-local-cadastrar"
docker run --rm --network none -v "$ROOT:/runtime:ro" \
    -v "$PAYLOAD/opt/btg-local:/opt/btg-local:ro" -v "$SRC/tests:/tests:ro" \
    -e PYTHONHOME=/runtime/usr -e PYTHONPATH=/runtime/usr/lib/python3/dist-packages \
    -e PYTHONDONTWRITEBYTECODE=1 \
    populos-provas /runtime/usr/bin/python3.10 /tests/test_runtime.py
echo 'Atalhos executaveis e servico habilitado no payload conferidos.'
