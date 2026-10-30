#!/bin/bash
# Gera o EPM/FPM populos_netskope a partir do instalador oficial NSClient_*.run (sem o token: o nome do .run vai sÃ³ pelo Scout).
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/netskope-elux
RUN=$(ls /mnt/c/Users/Administrator/Downloads/NSClient_*.run | head -n1)
# VersÃ£o do pacote = versÃ£o do cliente + revisÃ£o POPULOS (.1 = sem nsdiag, para a imagem caber em 3.700 MB;
# .2 = ip6tables, pasta de CA gravÃ¡vel e status/logs no diagnÃ³stico do Scout;
# .3 = agente e Ã­cone sÃ³ abrem depois do stagentd, socket fora do estado salvo, logs do usuÃ¡rio no diagnÃ³stico)
VERSAO=${1:-142.1.0.2831.4}
APPV=${VERSAO%.*}
B=/root/pkgs/build/populos_netskope
if [ -e "$B" ]; then mv "$B" "$B-anterior-$(date +%Y%m%d%H%M%S)"; fi
OUT=$SRC/saida
mkdir -p "$B/epm" "$B/data" "$B/payload" "$OUT"
# Payload makeself (tar.gz depois do cabeÃ§alho); confere a versÃ£o antes de usar
grep -a -q "appversion=\"$APPV\"" <(head -c 4096 "$RUN") || { echo "Instalador nÃ£o Ã© a versÃ£o $APPV"; exit 1; }
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
install -m 755 "$SRC/elux/netskope-estado.sh" "$SRC/elux/iniciar-usuario.sh" "$A/scripts/"
install -m 644 "$SRC/elux/stagentd.service" "$A/scripts/stagentd.service"
cp "$P"/resources/*.ico "$P"/resources/*.png "$P"/resources/*.html "$A/resources/"
cp "$P"/resources/idpServiceProviderPages/*.html "$A/resources/idpServiceProviderPages/"
for f in fips.so legacy.so openssl.cnf; do install -m 644 "$P/ossl-modules/$f" "$A/ossl-modules/"; done
find "$A/resources" -type f -exec chmod 644 {} +
install -m 644 "$SRC/elux/stagentd.service" "$SRC/elux/netskope-salvar.service" "$SRC/elux/netskope-salvar.timer" "$I/usr/lib/systemd/system/"
ln -s ../stagentd.service "$I/usr/lib/systemd/system/multi-user.target.wants/stagentd.service"
ln -s ../netskope-salvar.timer "$I/usr/lib/systemd/system/timers.target.wants/netskope-salvar.timer"
install -m 644 "$SRC/elux/stagentui.desktop" "$I/usr/share/applications/stagentui.desktop"
install -m 644 "$SRC/elux/stagentui.desktop" "$I/etc/xdg/autostart/stagentui.desktop"
install -m 644 "$SRC/elux/stagentapp.desktop" "$I/etc/xdg/autostart/stagentapp.desktop"
ln -s /opt/netskope/stagent/stAgentCli "$I/usr/bin/nsclient"
# ip6tables: o eLux sÃ³ traz iptables (openvpn, xtables-nft-multi); o stAgentSvc tambÃ©m chama ip6tables
mkdir -p "$I/usr/sbin"
for f in ip6tables-nft ip6tables-nft-save ip6tables-nft-restore; do ln -s xtables-nft-multi "$I/usr/sbin/$f"; done
for f in ip6tables ip6tables-save ip6tables-restore; do ln -s "/usr/sbin/${f/ip6tables/ip6tables-nft}" "$I/usr/sbin/$f"; done
# CA do Netskope: /usr/local Ã© somente leitura no eLux; aponta para /var (overlay gravÃ¡vel) e o update-ca-certificates grava em /etc/ssl
mkdir -p "$I/usr/local/share" "$I/usr/lib/tmpfiles.d" "$I/usr/share/diagnostic/commands.d"
ln -s /var/lib/netskope/ca-certificates "$I/usr/local/share/ca-certificates"
echo 'd /var/lib/netskope/ca-certificates 0755 root root -' > "$I/usr/lib/tmpfiles.d/populos-netskope.conf"
install -m 755 "$SRC/elux/diag-netskope" "$I/usr/share/diagnostic/commands.d/populos_netskope-status"
cat > "$B/epm/elux/$F.postCommands" <<'EOF'
chmod 0755 %root%/opt/netskope/stagent/stAgentSvc %root%/opt/netskope/stagent/stAgentApp %root%/opt/netskope/stagent/stAgentCli %root%/opt/netskope/stagent/stAgentUI %root%/opt/netskope/stagent/certutil %root%/opt/netskope/stagent/installerutil %root%/opt/netskope/stagent/uninstall.sh %root%/opt/netskope/stagent/scripts/netskope-estado.sh %root%/opt/netskope/stagent/scripts/iniciar-usuario.sh %root%/opt/netskope/stagent/scripts/stagentd_pre_exec.sh %root%/opt/netskope/stagent/scripts/gpgverify.sh %root%/usr/share/diagnostic/commands.d/populos_netskope-status
EOF
cat > "$B/epm/elux/$F.postInst" <<'EOF'
#!/bin/bash
systemd-tmpfiles --create /usr/lib/tmpfiles.d/populos-netskope.conf >/dev/null 2>&1
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
