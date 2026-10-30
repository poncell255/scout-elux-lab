#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/hapvida-saude
B=/root/pkgs/build/populos_hapvida
OUT=$SRC/saida
if [ -e "$B" ]; then echo 'Pasta de build já existe; use a saída existente ou uma pasta nova.'; exit 1; fi
mkdir -p "$B/epm" "$B/data" "$OUT"
gcc -O2 -Wall -Wextra -Wno-unused-parameter -o "$B/hapvida-digital" "$SRC/native/hapvida-digital.c" $(pkg-config --cflags --libs gtk+-3.0 libfprint-2)
strip "$B/hapvida-digital"
cp /root/pkgs/build/populos_digital/data/*.deb "$B/data/"
IMG=$(cat /root/epkg-image)
epkg() { docker run --rm -v "$B/epm:/epm" -v "$B/data:/data" "$IMG" epkg "$@"; }
epkg New --epm populos_hapvida --fpms populos_hapvida_app >/dev/null
python3 - "$B/epm/input/ebkepm" <<'PY'
import configparser,sys
p=sys.argv[1];c=configparser.RawConfigParser();c.optionxform=str;c.read(p)
for s in c.sections():
    if s=='EPM' or c.get(s,'name',fallback='')=='populos_hapvida_app':
        for k,v in {'version':'1.0.0','vendor':'POPULOS','copyright':'POPULOS'}.items():c.set(s,k,v)
    if s=='EPM':
        c.set(s,'category','Application');c.set(s,'summary','HAPVIDA - Exames e Prontuario (demonstracao)')
        c.set(s,'description','Identificacao por digital em janela normal, sem alterar login AD.')
    else:
        c.set(s,'installoption','2')
with open(p,'w') as f:c.write(f,space_around_delimiters=False)
PY
F=populos_hapvida_app
echo 'dataDir=/data' > "$B/epm/elux/variables"
for file in "$B/data/"*.deb; do echo "%dataDir%/$(basename "$file")"; done > "$B/epm/elux/$F.thirdparty"
printf '%s\n' 'usr/lib/%archLibDir%/libfprint-2.so.2' 'usr/lib/%archLibDir%/libfprint-2.so.2.0.0' 'usr/lib/%archLibDir%/libgusb.so.2' 'usr/lib/%archLibDir%/libgusb.so.2.0.10' > "$B/epm/elux/$F.install"
I=$B/epm/input/$F
mkdir -p "$I/usr/bin" "$I/usr/lib/udev/rules.d"
cp "$B/hapvida-digital" "$I/usr/bin/"
cp "$SRC/elux/prontuario.sh" "$I/usr/bin/hapvida-prontuario"
cp /mnt/c/UniconSDK/pkgs/populos_digital/input/populos_digital/usr/lib/udev/rules.d/70-populos-digital.rules "$I/usr/lib/udev/rules.d/70-hapvida-digital.rules"
cat > "$B/epm/elux/$F.postCommands" <<'EOF'
chmod 0755 %root%/usr/bin/hapvida-digital %root%/usr/bin/hapvida-prontuario
chmod 0644 %root%/usr/lib/udev/rules.d/70-hapvida-digital.rules
EOF
cat > "$B/epm/elux/$F.postInst" <<'EOF'
#!/bin/bash
udevadm control --reload-rules >/dev/null 2>&1
udevadm trigger --subsystem-match=usb --attr-match=idVendor=05ba >/dev/null 2>&1
true
EOF
epkg Build --container elux7 --releaseType test --skipSign --log > "$B/build.log" 2>&1 || { tail -60 "$B/build.log"; exit 1; }
cp "$B/epm/output/container/"*/*.epm "$B/epm/output/container/"*/*.fpm "$OUT/"
echo 'Pacote HAPVIDA compilado:'
ls -lh "$OUT/"
test ! -d "$I/usr/share/X11/login.d"
readelf -d "$B/hapvida-digital" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'
