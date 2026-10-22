#!/bin/bash
# Monta o EPM populos_vscode (VS Code oficial .deb) com o epkg.
# Sem Copilot embutido, Mermaid, code-tunnel e idiomas extras, para caber na partição custom de 3,75 GB.
IMG=$(cat /root/epkg-image)
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
EPM=populos_vscode; F=populos_vscode_app
X=/root/pkgs/populos_vscode/data/x
B=/root/pkgs/build/$EPM; rm -rf $B; mkdir -p $B/epm $B/data
VER=$(dpkg-deb -f /root/pkgs/populos_vscode/data/code.deb Version | cut -d- -f1)
cp /root/pkgs/populos_vscode/data/code.deb $B/data/code_${VER}_amd64.deb
epkg $B/epm $B/data New --epm $EPM --fpms $F > /dev/null
E=$B/epm/input/ebkepm
ini $E EPM category Application
ini $E EPM summary "Visual Studio Code $VER (POPULOS)"
ini $E EPM description "VS Code oficial da Microsoft, sem Copilot embutido, Mermaid, code-tunnel e idiomas extras (en-US e pt-BR)."
for s in EPM $F; do ini $E $s version $VER; ini $E $s vendor POPULOS; ini $E $s copyright POPULOS; done
ini $E $F installoption 2
ini $E $F summary "Visual Studio Code"
echo "dataDir=/data" > $B/epm/elux/variables
printf '%s\n' "%dataDir%/code_${VER}_amd64.deb" 'Licence: LicenseRef-Microsoft-VSCode' > $B/epm/elux/$F.thirdparty

# lista explícita de arquivos (recomendação da Unicon), sem as partes removidas
( cd $X && find usr/share/code usr/share/pixmaps -type f -o -type l ) \
  | grep -v -E '^usr/share/code/resources/app/extensions/(copilot|mermaid-markdown-features)/' \
  | grep -v -E '^usr/share/code/bin/(code-tunnel|copilot-shim)$' \
  | grep -v -E '^usr/share/code/locales/' | sort > $B/epm/elux/$F.install
printf '%s\n' usr/share/code/locales/en-US.pak usr/share/code/locales/pt-BR.pak >> $B/epm/elux/$F.install
echo "linhas no .install: $(wc -l < $B/epm/elux/$F.install)"

mkdir -p $B/epm/input/$F/usr/share/elux/persistentdirs
printf '%s\n' '.config/Code' '.vscode' > $B/epm/input/$F/usr/share/elux/persistentdirs/populos-vscode.home_dirs
cat > $B/epm/elux/$F.postCommands <<'POST'
mkdir -p %root%/usr/bin && ln -sf ../share/code/bin/code %root%/usr/bin/code
chmod 4755 %root%/usr/share/code/chrome-sandbox
chmod 0644 %root%/usr/share/elux/persistentdirs/populos-vscode.home_dirs
POST

epkg $B/epm $B/data Build --container elux7 --releaseType test --skipSign --log 2>&1 | grep -v -E '^\s*$' | tail -6
rm -f $OUT/populos_vscode*
cp $B/epm/output/container/*/*.epm $B/epm/output/container/*/*.fpm $OUT/ && echo copiado
R=$B/epm/output/$EPM/$F
echo "== instalado: $(du -sh $R | cut -f1); arquivos: $(find $R -type f | wc -l)"
ls -l $R/usr/bin/code $R/usr/share/code/chrome-sandbox; ls $R/usr/share/code/locales
echo "extensoes: $(ls $R/usr/share/code/resources/app/extensions | wc -l)"
grep -E 'UncompressedSize|CompressedSize' $B/epm/elux/$F.size
ls -l $OUT/populos_vscode*
