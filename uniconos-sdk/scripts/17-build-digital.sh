#!/bin/bash
# Monta os EPMs populos_digital e populos_ajustes com o epkg (UniconOS 7.2609, Ubuntu 22.04).
IMG=$(cat /root/epkg-image); VERSAO=${1:-1.1.0}
SRC=/mnt/c/UniconSDK/pkgs
OUT=/mnt/c/UniconSDK/saida; mkdir -p $OUT
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
comum() { ini "$1" "$2" version ${VERSAO:-1.0.0}; ini "$1" "$2" vendor POPULOS; ini "$1" "$2" copyright POPULOS; }

# ---------------- populos_digital ----------------
EPM=populos_digital; F=populos_digital_portao
B=/root/pkgs/build/$EPM; rm -rf $B; mkdir -p $B/epm $B/data
cd $B/data && apt-get download -qq libfprint-2-2 libgusb2 2>/dev/null
for x in *%3a*; do [ -e "$x" ] && mv "$x" "${x//%3a/}"; done; ls $B/data
epkg $B/epm $B/data New --epm $EPM --fpms $F > /dev/null
E=$B/epm/input/ebkepm
ini $E EPM category Security
ini $E EPM summary "POPULOS - 2o fator por impressao digital"
ini $E EPM description "Pede a impressao digital do usuario do AD depois do login (libfprint 1.94, leitor U.are.U 4500)."
comum $E EPM
ini $E $F installoption 2
ini $E $F summary "Portao de digital e cadastro"
comum $E $F
echo "dataDir=/data" > $B/epm/elux/variables
for d in $B/data/*.deb; do echo "%dataDir%/$(basename $d)"; done > $B/epm/elux/$F.thirdparty
printf '%s\n' 'usr/lib/%archLibDir%/libfprint-2.so.2' 'usr/lib/%archLibDir%/libfprint-2.so.2.0.0' 'usr/lib/%archLibDir%/libgusb.so.2' 'usr/lib/%archLibDir%/libgusb.so.2.0.10' > $B/epm/elux/$F.install
mkdir -p $B/epm/input/$F
cp -r $SRC/populos_digital/input/populos_digital/. $B/epm/input/$F/
cp /root/pkgs/populos_digital/bin/populos-digital $B/epm/input/$F/usr/bin/
cat > $B/epm/elux/$F.postCommands <<'X'
chmod 0755 %root%/usr/bin/populos-digital %root%/usr/bin/populos-digital-cadastro
chmod 0644 %root%/usr/share/X11/login.d/25-populos-digital %root%/usr/lib/udev/rules.d/70-populos-digital.rules %root%/usr/lib/tmpfiles.d/populos-digital.conf
X
cat > $B/epm/elux/$F.postInst <<'X'
#!/bin/bash
systemd-tmpfiles --create /usr/lib/tmpfiles.d/populos-digital.conf > /dev/null 2>&1
udevadm control --reload-rules > /dev/null 2>&1
udevadm trigger --subsystem-match=usb --attr-match=idVendor=05ba > /dev/null 2>&1
true
X
epkg $B/epm $B/data Build --container elux7 --releaseType test --skipSign --log 2>&1 | tail -4
rm -f $OUT/populos_digital*; cp $B/epm/output/container/*/*.epm $B/epm/output/container/*/*.fpm $OUT/ && echo "copiado"; ls -l $OUT | grep populos_digital
echo "== conteudo de $F"; (cd $B/epm/output/$EPM/$F && find . \( -type f -o -type l \) -printf '%m %p\n')

