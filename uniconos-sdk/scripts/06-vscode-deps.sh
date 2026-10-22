#!/bin/bash
# Baixa o VS Code (.deb oficial) e lista bibliotecas que faltam no eLux.
set -e
tr -d '\r' < /mnt/c/UniconSDK/elux-v6-arquivos.txt > /tmp/elux-lista.txt
d=/root/pkgs/populos_vscode/data; mkdir -p $d; cd $d
[ -f code.deb ] || curl -sSL -o code.deb 'https://update.code.visualstudio.com/latest/linux-deb-x64/stable'
dpkg-deb -f code.deb Package Version Installed-Size Depends
rm -rf x; mkdir x; dpkg-deb -x code.deb x
du -sh x/usr/share/code
declare -A visto
for f in $(find x -type f \( -perm -u+x -o -name '*.so*' -o -name '*.node' \) ); do
  file -b "$f" | grep -q ELF || continue
  for n in $(readelf -d "$f" 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/'); do
    [[ -n ${visto[$n]} ]] && continue; visto[$n]=1
    grep -q "/$n\$" /tmp/elux-lista.txt && continue
    find x -name "$n" | grep -q . && continue   # vem junto no próprio VS Code
    echo "FALTA: $n  (pacote $(dpkg -S "$n" 2>/dev/null | head -1 | cut -d: -f1))"
  done
done
echo "-- fim"
