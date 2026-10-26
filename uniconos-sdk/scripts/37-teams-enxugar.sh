#!/bin/bash
# Enxuga o Teams for Linux para caber na raiz do eLux: tira simbolos de depuracao, idiomas extras e compacta a licenca.
S=/root/pkgs/teams/x/opt/teams-for-linux; E=/root/pkgs/teams/enxuto
rm -rf $E; mkdir -p $E; cp -a $S $E/teams-for-linux; cd $E/teams-for-linux
before=$(du -sm . | cut -f1)
strip --strip-unneeded teams-for-linux chrome_crashpad_handler 2>/dev/null
for f in *.so *.so.*; do [ -f "$f" ] && strip --strip-unneeded "$f" 2>/dev/null; done
find locales -name '*.pak' ! -name 'en-US.pak' ! -name 'pt-BR.pak' ! -name 'pt-PT.pak' -delete
gzip -9 LICENSES.chromium.html
after=$(du -sm . | cut -f1)
echo "antes: ${before} MB  depois: ${after} MB"; du -sh teams-for-linux; ls locales
# o binario continua abrindo? (sem tela: so a versao)
./teams-for-linux --version --no-sandbox 2>&1 | head -2 || true
