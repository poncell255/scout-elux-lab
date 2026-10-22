#!/bin/bash
# Espera ate aparecer um computador novo no GLPI (alem do teste "scoutboard"). Uso: 33-glpi-esperar.sh <minutos>
. /root/glpi/.env
for i in $(seq 1 $(( ${1:-20} * 4 ))); do
  n=$(docker exec glpi-db mysql -uglpi -p"$GLPI_DB_PASSWORD" glpi -N -e "SELECT COUNT(*) FROM glpi_computers WHERE name<>'scoutboard' AND is_deleted=0" 2>/dev/null)
  [ "${n:-0}" -gt 0 ] && { bash /mnt/c/UniconSDK/scripts/32-glpi-computadores.sh; exit 0; }
  sleep 15
done
echo "nenhum computador novo em ${1:-20} min"; exit 1
