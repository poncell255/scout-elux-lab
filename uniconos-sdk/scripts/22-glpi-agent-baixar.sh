#!/bin/bash
# Baixa o GLPI Agent (AppImage, ja traz o proprio perl) e extrai em /root/pkgs/glpi/squashfs-root.
VERSAO=${1:-1.21}
D=/root/pkgs/glpi; mkdir -p $D; cd $D
[ -f glpi-agent-$VERSAO-x86_64.AppImage ] || curl -sLO https://github.com/glpi-project/glpi-agent/releases/download/$VERSAO/glpi-agent-$VERSAO-x86_64.AppImage
chmod +x glpi-agent-$VERSAO-x86_64.AppImage
rm -rf squashfs-root; ./glpi-agent-$VERSAO-x86_64.AppImage --appimage-extract > /dev/null
ls -la squashfs-root; du -sh squashfs-root
cat squashfs-root/AppRun | head -60
ls squashfs-root/usr/bin | head -30
