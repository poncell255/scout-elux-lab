#!/bin/bash
# Bibliotecas que o Teams for Linux pede (NEEDED de todos os ELF) e que nao existem na imagem v18 do eLux.
tr -d "\r" < /mnt/c/UniconSDK/elux-v18-arquivos.txt > /tmp/v18.txt
T=/root/pkgs/teams/enxuto/teams-for-linux
for f in $(find $T -type f \( -name '*.so*' -o -perm -u+x \)); do readelf -d "$f" 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/'; done | sort -u > /tmp/needed.txt
echo "bibliotecas pedidas: $(wc -l < /tmp/needed.txt)"
while read n; do
  [ -f "$T/$n" ] && continue                      # vem junto no proprio app
  grep -q "/$n\$" /tmp/v18.txt || echo "FALTA no eLux: $n"
done < /tmp/needed.txt
echo "-- fim"
