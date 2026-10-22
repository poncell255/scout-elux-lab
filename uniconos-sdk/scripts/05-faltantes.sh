#!/bin/bash
# Fecha as dependências (NEEDED recursivo) e diz quais bibliotecas não existem na imagem v6 do eLux.
tr -d "" < /mnt/c/UniconSDK/elux-v6-arquivos.txt > /tmp/elux-lista.txt; lista=/tmp/elux-lista.txt
declare -A visto
fila=(/root/pkgs/populos_digital/bin/populos-digital)
while ((${#fila[@]})); do
  f=${fila[0]}; fila=("${fila[@]:1}")
  for n in $(readelf -d "$f" 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/'); do
    [[ -n ${visto[$n]} ]] && continue; visto[$n]=1
    if grep -q "/$n\$" $lista; then continue; fi
    caminho=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "$n" 2>/dev/null | head -1)
    pac=$(dpkg -S "$(readlink -f "$caminho")" 2>/dev/null | cut -d: -f1 | head -1)
    echo "FALTA: $n  ($caminho, pacote $pac)"
    fila+=("$(readlink -f "$caminho")")
  done
done
echo "-- fim"
