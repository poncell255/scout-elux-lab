#!/bin/bash
# Prévia da tela da sala de provas (modo prova com pasta vazia: mostra a mensagem e os botões).
cd /root/pkgs/populos_digital; mkdir -p /tmp/galeria-vazia; rm -f /tmp/galeria-vazia/*
Xvfb :81 -screen 0 1280x800x24 >/dev/null 2>&1 & XP=$!; sleep 2
(GDK_BACKEND=x11 WAYLAND_DISPLAY= DISPLAY=:81 timeout 10 ./bin/populos-digital prova /tmp/galeria-vazia >/dev/null 2>&1 &); sleep 6
DISPLAY=:81 xwd -root -silent > /tmp/p.xwd; convert /tmp/p.xwd -resize 60% /mnt/c/UniconSDK/saida/preview-prova.png
sleep 5; kill $XP 2>/dev/null
ls -l /mnt/c/UniconSDK/saida/preview-prova.png
