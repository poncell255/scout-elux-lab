#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/hapvida-local
ROOT=/root/pkgs/hapvida-local-runtime
PAYLOAD=/root/pkgs/hapvida-local-payload-qa
mkdir -p "$PAYLOAD"
python3 "$SRC/deploy/extract-fpm.py" "$SRC/saida/populos_hapvida_local_app-1.0.0-1~testing.UC_ELUX7-1.0.fpm" "$PAYLOAD"
test -L "$PAYLOAD/usr/lib/systemd/system/multi-user.target.wants/hapvida-local.service"
test -x "$PAYLOAD/usr/bin/hapvida-local-admin"
test -x "$PAYLOAD/usr/bin/hapvida-local-paciente"
test -x "$PAYLOAD/usr/bin/hapvida-local-cadastrar"
docker run --rm --network none -v "$ROOT:/runtime:ro" \
    -v "$PAYLOAD/opt/hapvida-local:/opt/hapvida-local:ro" -v "$SRC/tests:/tests:ro" \
    -e PYTHONHOME=/runtime/usr -e PYTHONPATH=/runtime/usr/lib/python3/dist-packages \
    -e PYTHONDONTWRITEBYTECODE=1 \
    populos-provas /runtime/usr/bin/python3.10 /tests/test_runtime.py
echo 'Atalhos executaveis e servico habilitado no payload conferidos.'
