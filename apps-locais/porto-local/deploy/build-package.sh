#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/porto-local
VERSAO=${1:-1.0.0}
B=/root/pkgs/build/populos_porto_local
if [ -e "$B" ]; then mv "$B" "$B-anterior-$(date +%Y%m%d%H%M%S)"; fi
OUT=$SRC/saida
test ! -e "$B" || { echo 'Build existente; preservado para revisão.'; exit 1; }
mkdir -p "$B/epm" "$B/data" "$OUT"
gcc -O2 -Wall -Wextra -Wno-unused-parameter -o "$B/porto-local-digital" "$SRC/native/porto-local-digital.c" $(pkg-config --cflags --libs gtk+-3.0 libfprint-2)
gcc -O2 -Wall -Wextra -o "$B/porto-local-cadastrar" "$SRC/native/porto-cadastrar-digital.c" $(pkg-config --cflags --libs libfprint-2)
strip "$B/porto-local-digital" "$B/porto-local-cadastrar"
IMG=$(cat /root/epkg-image)
epkg(){ docker run --rm -v "$B/epm:/epm" -v "$B/data:/data" "$IMG" epkg "$@"; }
epkg New --epm populos_porto_local --fpms populos_porto_local_app >/dev/null
VERSAO="$VERSAO" python3 - "$B/epm/input/ebkepm" <<'PY'
import configparser,sys
p=sys.argv[1]; c=configparser.RawConfigParser(); c.optionxform=str; c.read(p)
for section in c.sections():
    for key,val in {'version':__import__('os').environ['VERSAO'],'vendor':'POPULOS','copyright':'POPULOS'}.items():c.set(section,key,val)
    if section=='EPM':
        c.set(section,'category','Application');c.set(section,'summary','Porto Local (teste) - area do segurado no eLux')
        c.set(section,'description','Cadastro de segurados com foto e digital, apolices, pagamentos e solicitacoes ficticios, independente do servidor.')
    else:c.set(section,'installoption','2')
with open(p,'w') as f:c.write(f,space_around_delimiters=False)
PY
F=populos_porto_local_app
I=$B/epm/input/$F
mkdir -p "$I/opt/porto-local/vendor" "$I/usr/bin" "$I/usr/lib/systemd/system/multi-user.target.wants" "$I/usr/lib/tmpfiles.d"
cp -r "$SRC/app/." "$I/opt/porto-local/"
find "$I/opt/porto-local" -type d -name __pycache__ -prune -exec rm -r {} +
docker cp hapvida:/usr/lib/python3/dist-packages/waitress "$I/opt/porto-local/vendor/"
find "$I/opt/porto-local/vendor" -type d -name __pycache__ -prune -exec rm -r {} +
cp "$B/porto-local-digital" "$B/porto-local-cadastrar" "$I/usr/bin/"
cp "$SRC/elux/admin.sh" "$I/usr/bin/porto-local-admin"
cp "$SRC/elux/cliente.sh" "$I/usr/bin/porto-local-cliente"
cp "$SRC/elux/porto-local.service" "$I/usr/lib/systemd/system/"
cp "$SRC/elux/porto-local.conf" "$I/usr/lib/tmpfiles.d/"
ln -s ../porto-local.service "$I/usr/lib/systemd/system/multi-user.target.wants/porto-local.service"
cat > "$B/epm/elux/$F.postCommands" <<'EOF'
chmod 0755 %root%/usr/bin/porto-local-digital %root%/usr/bin/porto-local-cadastrar %root%/usr/bin/porto-local-admin %root%/usr/bin/porto-local-cliente
EOF
cat > "$B/epm/elux/$F.postInst" <<'EOF'
#!/bin/bash
systemd-tmpfiles --create /usr/lib/tmpfiles.d/porto-local.conf >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
true
EOF
epkg Build --container elux7 --releaseType test --skipSign --log > "$B/build.log" 2>&1 || { tail -60 "$B/build.log"; exit 1; }
cp "$B/epm/output/container/"*/*.epm "$B/epm/output/container/"*/*.fpm "$OUT/"
echo 'Pacote local compilado:'
ls -lh "$OUT/"
test ! -d "$I/usr/share/X11/login.d"
test -f "$I/opt/porto-local/vendor/waitress/__init__.py"
