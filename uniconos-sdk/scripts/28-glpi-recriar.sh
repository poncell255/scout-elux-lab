#!/bin/bash
# Apaga o GLPI (containers + dados) e sobe de novo do zero. CUIDADO: perde todo o inventario.
docker rm -f glpi glpi-db > /dev/null 2>&1
rm -rf /root/glpi/storage
bash /mnt/c/UniconSDK/scripts/23-glpi-servidor.sh
