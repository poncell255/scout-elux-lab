#!/bin/bash
# Monta o EPM populos_ajustes: populos_edge_persistente + populos_claude_code.
IMG=$(cat /root/epkg-image); SRC=/mnt/c/UniconSDK/pkgs; OUT=/mnt/c/UniconSDK/saida; mkdir -p $OUT
VERSAO=${1:-1.0.1}
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
EPM=populos_ajustes; F1=populos_edge_persistente; F2=populos_claude_code
B=/root/pkgs/build/$EPM; rm -rf $B; mkdir -p $B/epm $B/data
epkg $B/epm $B/data New --epm $EPM --fpms $F1 --fpms $F2 > /dev/null
E=$B/epm/input/ebkepm
ini $E EPM category Miscellaneous; ini $E EPM summary "POPULOS - ajustes do UniconOS"
for s in EPM $F1 $F2; do ini $E $s version $VERSAO; ini $E $s vendor POPULOS; ini $E $s copyright POPULOS; ini $E $s installoption 2; done
ini $E $F1 summary "Edge: manter o perfil quando a home persistente esta ligada"
ini $E $F1 corrupts microsoft_edge_stable
ini $E $F2 summary "VS Code: rodar a extensao do Claude Code (a home nao permite executar programas)"
for f in $F1 $F2; do mkdir -p $B/epm/input/$f; cp -r $SRC/populos_ajustes/input/$f/. $B/epm/input/$f/; done
echo 'chmod 0644 %root%/usr/share/X11/logout.d/95-microsoft-edge-clean-userdata' > $B/epm/elux/$F1.postCommands
cat > $B/epm/elux/$F2.postCommands <<'X'
chmod 0755 %root%/usr/bin/populos-claude-wrapper
chmod 0644 %root%/usr/lib/tmpfiles.d/populos-claude.conf %root%/usr/share/X11/login.d/26-populos-vscode-claude
X
printf '%s\n' '#!/bin/bash' 'systemd-tmpfiles --create /usr/lib/tmpfiles.d/populos-claude.conf > /dev/null 2>&1' 'true' > $B/epm/elux/$F2.postInst
epkg $B/epm $B/data Build --container elux7 --releaseType test --skipSign 2>&1 | grep -E 'Creating package|ERROR|WARN'
rm -f $OUT/populos_ajustes* $OUT/populos_edge_persistente* $OUT/populos_claude_code*
cp $B/epm/output/container/*/*.epm $B/epm/output/container/*/*.fpm $OUT/
(cd $B/epm/output/$EPM && find . -type f -printf '%m %p\n')
ls -l $OUT | grep -E 'ajustes|edge_pers|claude'
