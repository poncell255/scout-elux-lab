#!/bin/bash
# Monta o EPM populos_glpi: GLPI Agent (AppImage extraido em /opt/glpi-agent) + timer de inventario.
# Antes: 22-glpi-agent-baixar.sh <versao do agente>
IMG=$(cat /root/epkg-image); SRC=/mnt/c/UniconSDK/pkgs; OUT=/mnt/c/UniconSDK/saida; mkdir -p $OUT
VERSAO=${1:-1.21.0}
ini() { python3 - "$@" <<'PY'
import sys, configparser
arq, secao, chave, valor = sys.argv[1:5]
c = configparser.RawConfigParser(); c.optionxform = str; c.read(arq)
for s in c.sections():
    if s == secao or c.get(s, 'name', fallback='') == secao: c.set(s, chave, valor)
with open(arq, 'w') as f: c.write(f, space_around_delimiters=False)
PY
}
epkg() { docker run --rm -v "$1:/epm" -v "$2:/data" "$IMG" epkg "${@:3}"; }
EPM=populos_glpi; F1=populos_glpi_agent
B=/root/pkgs/build/$EPM; rm -rf $B; mkdir -p $B/epm $B/data
epkg $B/epm $B/data New --epm $EPM --fpms $F1 > /dev/null
E=$B/epm/input/ebkepm
ini $E EPM category Miscellaneous; ini $E EPM summary "POPULOS - inventario no GLPI"
for s in EPM $F1; do ini $E $s version $VERSAO; ini $E $s vendor POPULOS; ini $E $s copyright POPULOS; ini $E $s installoption 2; done
ini $E $F1 summary "GLPI Agent: envia o inventario do eLux para o GLPI (boot + a cada 4 h)"
I=$B/epm/input/$F1; mkdir -p $I/opt
cp -r $SRC/populos_glpi/input/$F1/. $I/
find $I/usr -type f -exec sed -i 's/\r$//' {} +
cp -a /root/pkgs/glpi/squashfs-root $I/opt/glpi-agent
find $I/opt/glpi-agent -type d -exec chmod 755 {} +
mkdir -p $I/usr/lib/systemd/system/timers.target.wants
ln -sf ../populos-glpi-inventario.timer $I/usr/lib/systemd/system/timers.target.wants/populos-glpi-inventario.timer
cat > $B/epm/elux/$F1.postCommands <<'X'
chmod 0755 %root%/usr/bin/populos-glpi-inventario
chmod 0644 %root%/usr/lib/systemd/system/populos-glpi-inventario.service %root%/usr/lib/systemd/system/populos-glpi-inventario.timer
X
epkg $B/epm $B/data Build --container elux7 --releaseType test --skipSign 2>&1 | grep -E 'Creating package|ERROR|WARN'
rm -f $OUT/populos_glpi*
cp $B/epm/output/container/*/*.epm $B/epm/output/container/*/*.fpm $OUT/
(cd $B/epm/output/$EPM && find . -path ./*/opt -prune -o -printf '%m %y %p -> %l\n' | head -30; find . | wc -l)
ls -l $OUT | grep glpi
