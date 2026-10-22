#!/bin/bash
# Testa o script do eLux (populos-glpi-inventario) contra o GLPI local, simulando /opt e /setup.
# Uso: SENHA=... bash 29-glpi-agent-teste.sh
T=/tmp/glpi-teste; rm -rf $T; mkdir -p $T/setup/glpi-agent
ln -sfn /root/pkgs/glpi/squashfs-root $T/opt
echo "elux:$SENHA" > $T/setup/glpi-agent/auth; echo http://127.0.0.1:8080/ > $T/setup/glpi-agent/server; echo teste-wsl > $T/setup/glpi-agent/tag
sed -e "s#/opt/glpi-agent#$T/opt#; s#^VAR=.*#VAR=$T/setup/glpi-agent#" -e 's/\r$//' \
  /mnt/c/UniconSDK/pkgs/populos_glpi/input/populos_glpi_agent/usr/bin/populos-glpi-inventario > $T/inv
bash $T/inv 2>&1 | grep -v 'Wide character' | tail -6
ls $T/setup/glpi-agent
