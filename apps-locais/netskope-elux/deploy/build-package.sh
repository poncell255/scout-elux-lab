#!/bin/bash
# Gera o EPM/FPM populos_netskope a partir do instalador oficial NSClient_*.run (sem o token: o nome do .run vai só pelo Scout).
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/netskope-elux
RUN=$(ls /mnt/c/Users/Administrator/Downloads/NSClient_*.run | head -n1)
# Versão do pacote = versão do cliente + revisão POPULOS (.1 = sem nsdiag, para a imagem caber em 3.700 MB)
VERSAO=${1:-142.1.0.2831.1}
APPV=${VERSAO%.*}
B=/root/pkgs/build/populos_netskope
if [ -e "$B" ]; then mv "$B" "$B-anterior-$(date +%Y%m%d%H%M%S)"; fi
OUT=$SRC/saida
mkdir -p "$B/epm" "$B/data" "$B/payload" "$OUT"
# Payload makeself (tar.gz depois do cabeçalho); confere a versão antes de usar
grep -a -q "appversion=\"$APPV\"" <(head -c 4096 "$RUN") || { echo "Instalador não é a versão $APPV"; exit 1; }
LINHAS=$(head -c 30000 "$RUN" | grep -a -o 'offset=`head -n [0-9]*' | head -n1 | grep -o '[0-9]*$')
tail -c +$(( $(head -n "$LINHAS" "$RUN" | wc -c) + 1 )) "$RUN" | tar xzf - -C "$B/payload"
P=$B/payload
for f in stAgentSvc stAgentApp stAgentCli stAgentUI nsdiag certutil installerutil uninstall.sh; do test -f "$P/$f"; done
IMG=$(cat /root/epkg-image)
epkg(){ docker run --rm -v "$B/epm:/epm" -v "$B/data:/data" "$IMG" epkg "$@"; }
epkg New --epm populos_netskope --fpms populos_netskope_client >/dev/null
VERSAO="$VERSAO" python3 - "$B/epm/input/ebkepm" <<'PY'
import configparser,os,sys
p=sys.argv[1]; c=configparser.RawConfigParser(); c.optionxform=str; c.read(p)
for section in c.sections():
    for key,val in {'version':os.environ['VERSAO'],'vendor':'POPULOS','copyright':'Netskope, Inc. (cliente oficial; empacotado pela POPULOS)'}.items():c.set(section,key,val)
    if section=='EPM':
        c.set(section,'category','Application');c.set(section,'summary','Netskope Client para eLux (cadastro pelo Scout)')
        c.set(section,'description','Cliente oficial Netskope Linux com servico stagentd e icone na bandeja. O cadastro usa o nome do instalador entregue em /setup/netskope/instalador e fica guardado em /setup/netskope-estado.')
    else:c.set(section,'installoption','2')
with open(p,'w') as f:c.write(f,space_around_delimiters=False)
PY
F=populos_netskope_client
I=$B/epm/input/$F
A=$I/opt/netskope/stagent
mkdir -p "$A/scripts" "$A/resources/idpServiceProviderPages" "$A/ossl-modules" "$I/usr/bin" "$I/usr/lib/systemd/system/multi-user.target.wants" "$I/usr/lib/systemd/system/timers.target.wants" "$I/usr/share/applications" "$I/etc/xdg/autostart"
for f in stAgentSvc stAgentApp stAgentCli stAgentUI certutil uninstall.sh installerutil; do install -m 755 "$P/$f" "$A/"; done
for f in stagentd_pre_exec.sh gpgverify.sh; do install -m 755 "$P/$f" "$A/scripts/"; done
for f in stagentapp.service stagentui.desktop nsclient-pub.gpg stagentd stagentAppInit.sh; do install -m 644 "$P/$f" "$A/scripts/"; done
install -m 755 "$SRC/elux/netskope-estado.sh" "$A/scripts/"
install -m 644 "$SRC/elux/stagentd.service" "$A/scripts/stagentd.service"
cp "$P"/resources/*.ico "$P"/resources/*.png "$P"/resources/*.html "$A/resources/"
cp "$P"/resources/idpServiceProviderPages/*.html "$A/resources/idpServiceProviderPages/"
for f in fips.so legacy.so openssl.cnf; do install -m 644 "$P/ossl-modules/$f" "$A/ossl-modules/"; done
find "$A/resources" -type f -exec chmod 644 {} +
install -m 644 "$SRC/elux/stagentd.service" "$SRC/elux/netskope-salvar.service" "$SRC/elux/netskope-salvar.timer" "$I/usr/lib/systemd/system/"
ln -s ../stagentd.service "$I/usr/lib/systemd/system/multi-user.target.wants/stagentd.service"
ln -s ../netskope-salvar.timer "$I/usr/lib/systemd/system/timers.target.wants/netskope-salvar.timer"
install -m 644 "$P/stagentui.desktop" "$I/usr/share/applications/stagentui.desktop"
install -m 644 "$P/stagentui.desktop" "$I/etc/xdg/autostart/stagentui.desktop"
install -m 644 "$SRC/elux/stagentapp.desktop" "$I/etc/xdg/autostart/stagentapp.desktop"
ln -s /opt/netskope/stagent/stAgentCli "$I/usr/bin/nsclient"
cat > "$B/epm/elux/$F.postCommands" <<'EOF'
chmod 0755 %root%/opt/netskope/stagent/stAgentSvc %root%/opt/netskope/stagent/stAgentApp %root%/opt/netskope/stagent/stAgentCli %root%/opt/netskope/stagent/stAgentUI %root%/opt/netskope/stagent/certutil %root%/opt/netskope/stagent/installerutil %root%/opt/netskope/stagent/uninstall.sh %root%/opt/netskope/stagent/scripts/netskope-estado.sh %root%/opt/netskope/stagent/scripts/stagentd_pre_exec.sh %root%/opt/netskope/stagent/scripts/gpgverify.sh
EOF
cat > "$B/epm/elux/$F.postInst" <<'EOF'
#!/bin/bash
systemctl daemon-reload >/dev/null 2>&1
true
EOF
epkg Build --container elux7 --releaseType test --skipSign --log > "$B/build.log" 2>&1 || { tail -60 "$B/build.log"; exit 1; }
rm -f "$OUT"/populos_netskope*.epm "$OUT"/populos_netskope*.fpm
cp "$B/epm/output/container/"*/*.epm "$B/epm/output/container/"*/*.fpm "$OUT/"
CHAVE=$(basename "$RUN" | cut -d_ -f4)
test ${#CHAVE} -gt 10 && ! grep -r -l -a -F "$CHAVE" "$I" "$OUT" || { echo 'Token encontrado no pacote!'; exit 1; }
echo 'Pacote compilado (sem token):'
ls -lh "$OUT/"
