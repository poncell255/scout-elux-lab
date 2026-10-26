#!/bin/bash
# Monta o EPM populos_teams: Teams for Linux (comunitario, github.com/IsmaelMartinez/teams-for-linux) em /opt/teams-for-linux.
# Antes: 36-teams-baixar.sh e 37-teams-enxugar.sh (gera /root/pkgs/teams/enxuto).
IMG=$(cat /root/epkg-image); OUT=/mnt/c/UniconSDK/saida; mkdir -p $OUT
VERSAO=${1:-2.27.0}
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
EPM=populos_teams; F1=populos_teams_app
B=/root/pkgs/build/$EPM; rm -rf $B; mkdir -p $B/epm $B/data
epkg $B/epm $B/data New --epm $EPM --fpms $F1 > /dev/null
E=$B/epm/input/ebkepm
ini $E EPM category Application; ini $E EPM summary "POPULOS - Teams for Linux (cliente comunitario do Microsoft Teams)"
for s in EPM $F1; do ini $E $s version $VERSAO; ini $E $s vendor POPULOS; ini $E $s copyright "GPL-3.0 (teams-for-linux)"; ini $E $s installoption 2; done
ini $E $F1 summary "Teams for Linux $VERSAO em /opt/teams-for-linux (nao oficial da Microsoft)"
I=$B/epm/input/$F1; mkdir -p $I/opt $I/usr/bin $I/usr/share/icons/hicolor
cp -a /root/pkgs/teams/enxuto/teams-for-linux $I/opt/
rm -f $I/opt/teams-for-linux/resources/app.asar.unpacked/node_modules/@cbor-extract/cbor-extract-linux-x64/*musl*
cp -a /root/pkgs/teams/x/usr/share/icons/hicolor/. $I/usr/share/icons/hicolor/ 2>/dev/null
ln -sf /opt/teams-for-linux/teams-for-linux $I/usr/bin/teams-for-linux
find $I/opt -type d -exec chmod 755 {} +
cat > $B/epm/elux/$F1.postCommands <<'C'
chmod 0755 %root%/opt/teams-for-linux/teams-for-linux
chmod 4755 %root%/opt/teams-for-linux/chrome-sandbox
C
epkg $B/epm $B/data Build --container elux7 --releaseType test --skipSign 2>&1 | grep -E 'Creating package|ERROR|WARN'
rm -f $OUT/populos_teams*
cp $B/epm/output/container/*/*.epm $B/epm/output/container/*/*.fpm $OUT/
grep -i autoreq $B/epm/output/$EPM/*.spec | head -2
ls -l $OUT | grep teams
