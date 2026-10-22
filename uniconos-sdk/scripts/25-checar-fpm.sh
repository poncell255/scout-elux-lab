#!/bin/bash
# Mostra as dependencias declaradas de um FPM (para ver se o RPM gerou requires automaticos).
B=/root/pkgs/build/populos_glpi/epm/output/populos_glpi
grep -iE 'autoreq|autoprov|requires|provides' $B/*.spec | head
ls $B/populos_glpi_agent/opt/glpi-agent | head -3
F=$(ls /mnt/c/UniconSDK/saida/${1:-populos_glpi_agent}-*.fpm | tail -1)
file "$F"
command -v rpm > /dev/null && rpm -qp --requires "$F" 2>/dev/null | head -20
