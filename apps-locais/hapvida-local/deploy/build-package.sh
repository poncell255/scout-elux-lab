#!/bin/bash
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/hapvida-local
B=/root/pkgs/build/populos_hapvida_local
OUT=$SRC/saida
test ! -e "$B" || { echo 'Build existente; preservado para revisão.'; exit 1; }
mkdir -p "$B/epm" "$B/data" "$OUT"
gcc -O2 -Wall -Wextra -Wno-unused-parameter -o "$B/hapvida-local-digital" "$SRC/native/hapvida-local-digital.c" $(pkg-config --cflags --libs gtk+-3.0 libfprint-2)
gcc -O2 -Wall -Wextra -o "$B/hapvida-local-cadastrar" "$SRC/native/hapvida-cadastrar-digital.c" $(pkg-config --cflags --libs libfprint-2)
strip "$B/hapvida-local-digital" "$B/hapvida-local-cadastrar"
IMG=$(cat /root/epkg-image)
epkg(){ docker run --rm -v "$B/epm:/epm" -v "$B/data:/data" "$IMG" epkg "$@"; }
epkg New --epm populos_hapvida_local --fpms populos_hapvida_local_app >/dev/null
python3 - "$B/epm/input/ebkepm" <<'PY'
import configparser,sys
p=sys.argv[1]; c=configparser.RawConfigParser(); c.optionxform=str; c.read(p)
for section in c.sections():
    for key,val in {'version':'1.0.0','vendor':'POPULOS','copyright':'POPULOS'}.items():c.set(section,key,val)
    if section=='EPM':
        c.set(section,'category','Application');c.set(section,'summary','HAPVIDA Local - servidor e dados no eLux')
        c.set(section,'description','Cadastro com foto e digital, exames e prontuario demonstrativos independentes do servidor.')
    else:c.set(section,'installoption','2')
with open(p,'w') as f:c.write(f,space_around_delimiters=False)
PY
F=populos_hapvida_local_app
I=$B/epm/input/$F
mkdir -p "$I/opt/hapvida-local/vendor" "$I/usr/bin" "$I/usr/lib/systemd/system/multi-user.target.wants" "$I/usr/lib/tmpfiles.d"
cp -r "$SRC/app/." "$I/opt/hapvida-local/"
find "$I/opt/hapvida-local" -type d -name __pycache__ -prune -exec rm -r {} +
docker cp hapvida:/usr/lib/python3/dist-packages/waitress "$I/opt/hapvida-local/vendor/"
find "$I/opt/hapvida-local/vendor" -type d -name __pycache__ -prune -exec rm -r {} +
cp "$B/hapvida-local-digital" "$B/hapvida-local-cadastrar" "$I/usr/bin/"
cp "$SRC/elux/admin.sh" "$I/usr/bin/hapvida-local-admin"
cp "$SRC/elux/paciente.sh" "$I/usr/bin/hapvida-local-paciente"
cp "$SRC/elux/hapvida-local.service" "$I/usr/lib/systemd/system/"
cp "$SRC/elux/hapvida-local.conf" "$I/usr/lib/tmpfiles.d/"
ln -s ../hapvida-local.service "$I/usr/lib/systemd/system/multi-user.target.wants/hapvida-local.service"
cat > "$B/epm/elux/$F.postCommands" <<'EOF'
chmod 0755 %root%/usr/bin/hapvida-local-digital %root%/usr/bin/hapvida-local-cadastrar %root%/usr/bin/hapvida-local-admin %root%/usr/bin/hapvida-local-paciente
EOF
cat > "$B/epm/elux/$F.postInst" <<'EOF'
#!/bin/bash
systemd-tmpfiles --create /usr/lib/tmpfiles.d/hapvida-local.conf >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
true
EOF
epkg Build --container elux7 --releaseType test --skipSign --log > "$B/build.log" 2>&1 || { tail -60 "$B/build.log"; exit 1; }
cp "$B/epm/output/container/"*/*.epm "$B/epm/output/container/"*/*.fpm "$OUT/"
echo 'Pacote local compilado:'
ls -lh "$OUT/"
test ! -d "$I/usr/share/X11/login.d"
test -f "$I/opt/hapvida-local/vendor/waitress/__init__.py"
