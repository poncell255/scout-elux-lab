#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/hapvida-saude
export SRC
export GDK_BACKEND=x11
mkdir -p /setup/hapvida
cp "$SRC/app/web/static/logo.png" /setup/hapvida/logo.png
printf '#FFF7EC\n' > /setup/hapvida/cor-fundo
mkdir -p "$SRC/previa" /tmp/hapvida-qa-galeria
xvfb-run -a -s '-screen 0 1024x800x24' bash "$SRC/deploy/preview-native-inner.sh"
