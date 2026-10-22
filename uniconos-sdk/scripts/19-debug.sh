#!/bin/bash
cd /root/pkgs/populos_digital
mkdir -p /setup/populos-digital
cp /mnt/c/Users/Administrator/Downloads/portoboot.png /setup/populos-digital/logo.png
echo '#0099ff' > /setup/populos-digital/cor-fundo
Xvfb :79 -screen 0 1280x800x24 >/dev/null 2>&1 & XP=$!
sleep 2
(GDK_BACKEND=x11 WAYLAND_DISPLAY= DISPLAY=:79 timeout 15 ./bin/populos-digital ${1:-entrada} >/dev/null 2>&1 &)
sleep 7
DISPLAY=:79 xwininfo -root -tree | grep -E 'child|x[0-9]+\+' | head -6
DISPLAY=:79 xwd -root -silent > /tmp/t.xwd; convert /tmp/t.xwd /mnt/c/UniconSDK/saida/preview-porto-${1:-entrada}.png
ls -l /mnt/c/UniconSDK/saida/preview-porto-${1:-entrada}.png
sleep 9; kill $XP 2>/dev/null
rm -f /setup/populos-digital/logo.png /setup/populos-digital/cor-fundo
