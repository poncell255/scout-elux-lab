#!/bin/bash
# Compila e gera prévias da tela (padrão e Porto).
cd /root/pkgs/populos_digital
cp /mnt/c/UniconSDK/pkgs/populos_digital/src/populos-digital.c .
gcc -O2 -Wall -Wextra -Wno-unused-parameter -o bin/populos-digital populos-digital.c $(pkg-config --cflags --libs gtk+-3.0 libfprint-2) 2>&1 | head; strip bin/populos-digital
mkdir -p /setup/populos-digital
for v in porto padrao; do
  rm -f /setup/populos-digital/logo.png /setup/populos-digital/cor-fundo
  if [ $v = porto ]; then cp /mnt/c/Users/Administrator/Downloads/portoboot.png /setup/populos-digital/logo.png; echo '#0099ff' > /setup/populos-digital/cor-fundo; fi
  Xvfb :80 -screen 0 1280x800x24 >/dev/null 2>&1 & XP=$!; sleep 2
  (GDK_BACKEND=x11 WAYLAND_DISPLAY= DISPLAY=:80 timeout 9 ./bin/populos-digital entrada >/dev/null 2>&1 &); sleep 6
  DISPLAY=:80 xwd -root -silent > /tmp/t.xwd; convert /tmp/t.xwd -resize 50% /mnt/c/UniconSDK/saida/preview-$v.png
  sleep 4; kill $XP 2>/dev/null; sleep 1
done
rm -f /setup/populos-digital/logo.png /setup/populos-digital/cor-fundo
ls -l /mnt/c/UniconSDK/saida/preview-*.png
