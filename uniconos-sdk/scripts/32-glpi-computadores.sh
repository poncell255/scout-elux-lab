#!/bin/bash
# Lista os computadores no GLPI e os ultimos inventarios recebidos.
. /root/glpi/.env
docker exec glpi-db mysql -uglpi -p"$GLPI_DB_PASSWORD" glpi -t -e "SELECT c.id, c.name, c.serial, c.date_mod, c.last_inventory_update, a.tag FROM glpi_computers c LEFT JOIN glpi_agents a ON a.items_id=c.id AND a.itemtype='Computer' WHERE c.is_deleted=0 ORDER BY c.date_mod DESC" 2>/dev/null
docker logs --since 30m glpi 2>&1 | grep -E 'POST / |front/inventory|inventory' | tail -8
