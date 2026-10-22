#!/bin/bash
# Mostra o estado do Docker e as versoes mais novas do GLPI e do GLPI Agent.
service docker start >/dev/null 2>&1
docker info --format 'docker {{.ServerVersion}}'
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curl -s https://api.github.com/repos/glpi-project/glpi-agent/releases/latest | grep -E '"tag_name"|browser_download_url' | grep -E 'tag_name|x86_64.AppImage"|_all.deb"|linux-installer.pl"'
curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep '"tag_name"'
ls /mnt/c/UniconSDK/pkgs
grep MemTotal /proc/meminfo
df -h / | tail -1
