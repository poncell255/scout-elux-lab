#!/bin/bash
# Baixa o .deb mais novo do Teams for Linux (comunitario, github.com/IsmaelMartinez/teams-for-linux), extrai e mede.
D=/root/pkgs/teams; mkdir -p $D; cd $D
URL=$(curl -s https://api.github.com/repos/IsmaelMartinez/teams-for-linux/releases/latest | grep -o 'https://[^"]*_amd64\.deb' | head -1)
echo "url: $URL"
F=$(basename "$URL"); [ -f "$F" ] || curl -sL -o "$F" "$URL"
ls -la "$F"; rm -rf x; mkdir x; dpkg-deb -x "$F" x; dpkg-deb -f "$F" Version Depends Installed-Size
du -sh x; du -sh x/opt/* 2>/dev/null; du -sh x/opt/*/locales 2>/dev/null; ls x/usr/bin 2>/dev/null; find x -maxdepth 3 -type d | head -20
