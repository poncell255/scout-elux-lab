#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/btg-local
ROOT=/root/pkgs/btg-local-runtime
mkdir -p "$ROOT"
for f in "$SRC/vendor/"*.fpm; do python3 "$SRC/deploy/extract-fpm.py" "$f" "$ROOT"; done
find "$ROOT/usr" -maxdepth 4 -type f | grep -E '(python3\.[0-9]+$|flask/__init__|sqlite|markupsafe|werkzeug/__init__)' | head -20
echo '== modulos do runtime oficial'
PYTHONHOME="$ROOT/usr" PYTHONPATH="$ROOT/usr/lib/python3/dist-packages" "$ROOT/usr/bin/python3.10" -c 'import sys,sqlite3,ssl,flask; print(sys.version); print("SQLite",sqlite3.sqlite_version,"Flask",flask.__version__); import jinja2,werkzeug,click,itsdangerous; print("Dependencias Flask OK")'
echo '== metadados epkg existente'
cat /root/pkgs/build/populos_hapvida/epm/input/ebkepm
