#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/porto-local
ROOT=/root/pkgs/hapvida-local-runtime
docker run --rm --network none \
    -v "$ROOT:/runtime:ro" -v "$SRC/app:/app:ro" -v "$SRC/tests:/tests:ro" \
    -e PYTHONHOME=/runtime/usr -e PYTHONPATH=/runtime/usr/lib/python3/dist-packages \
    -e PYTHONDONTWRITEBYTECODE=1 \
    populos-provas /runtime/usr/bin/python3.10 /tests/test_app.py
for f in "$SRC/elux/"*.sh; do bash -n "$f"; done
echo 'Backend testado com Python/Flask oficiais e network=none.'
