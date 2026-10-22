#!/bin/bash
# Compila o populos-digital e lista as bibliotecas necessárias.
set -e
d=/root/pkgs/populos_digital; mkdir -p $d/bin
cp /mnt/c/UniconSDK/pkgs/populos_digital/src/populos-digital.c $d/
cd $d
gcc -O2 -Wall -Wextra -Wno-unused-parameter -o bin/populos-digital populos-digital.c $(pkg-config --cflags --libs gtk+-3.0 libfprint-2)
strip bin/populos-digital
ls -l bin/populos-digital
echo "== NEEDED do binario"; readelf -d bin/populos-digital | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/'
lib=$(find /usr/lib/x86_64-linux-gnu -name 'libfprint-2.so.2*' -type f | head -1)
echo "== libfprint: $lib"; readelf -d "$lib" | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/'
