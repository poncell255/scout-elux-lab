#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/hapvida-saude
docker run --rm -v "$SRC/app:/app:ro" -v "$SRC/tests:/tests:ro" populos-provas python3 /tests/test_app.py
python3 -m py_compile "$SRC/app/app.py"
bash -n "$SRC/elux/prontuario.sh"
bash -n "$SRC/deploy/build-package.sh"
if command -v node >/dev/null; then
    node --check "$SRC/app/web/static/admin.js"
    node --check "$SRC/app/web/static/portal.js"
fi
