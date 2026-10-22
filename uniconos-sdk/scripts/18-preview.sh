#!/bin/bash
cd /root/pkgs/populos_digital
mkdir -p /setup/populos-digital
cp /mnt/c/Users/Administrator/Downloads/portoboot.png /setup/populos-digital/logo.png
echo '#0099ff' > /setup/populos-digital/cor-fundo
command -v xwininfo >/dev/null || apt-get install -y -qq x11-utils x11-apps >/dev/null 2>&1
Xvfb :77 -screen 0 1280x800x24 >/dev/null 2>&1 & XP=$!
sleep 2
DISPLAY=:77 ./bin/populos-digital ${1:-entrada} >/tmp/prev.log 2>&1 & AP=$!
sleep 6
DISPLAY=:77 xwininfo -root -children | grep -E 'children|0x' | head -5
DISPLAY=:77 xwd -root -silent | convert xwd:- /mnt/c/UniconSDK/saida/preview-porto.png
kill $AP $XP 2>/dev/null
rm -f /setup/populos-digital/logo.png /setup/populos-digital/cor-fundo
ls -l /mnt/c/UniconSDK/saida/preview-porto.png
