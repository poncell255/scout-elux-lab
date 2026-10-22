#!/bin/bash
# Sobe o GLPI (imagem oficial glpi/glpi) + MySQL em Docker no WSL.
# Espera /root/glpi/.env com GLPI_DB_PASSWORD (gerado no Windows, guardado em credenciais.txt).
set -e
service docker start > /dev/null 2>&1 || true
D=/root/glpi; mkdir -p $D/storage/glpi $D/storage/mysql; chmod 700 $D
chown 33:33 $D/storage/glpi   # o container roda como www-data (uid 33)
. $D/.env
docker network inspect glpi > /dev/null 2>&1 || docker network create glpi > /dev/null
docker pull -q glpi/glpi:latest; docker pull -q mysql:8.4
if ! docker ps -a --format '{{.Names}}' | grep -qx glpi-db; then
  docker run -d --name glpi-db --network glpi --restart unless-stopped \
    -e MYSQL_RANDOM_ROOT_PASSWORD=yes -e MYSQL_DATABASE=glpi -e MYSQL_USER=glpi -e MYSQL_PASSWORD="$GLPI_DB_PASSWORD" \
    -v $D/storage/mysql:/var/lib/mysql mysql:8.4 > /dev/null
fi
if ! docker ps -a --format '{{.Names}}' | grep -qx glpi; then
  docker run -d --name glpi --network glpi --restart unless-stopped -p 8080:80 \
    -e GLPI_DB_HOST=glpi-db -e GLPI_DB_PORT=3306 -e GLPI_DB_NAME=glpi -e GLPI_DB_USER=glpi -e GLPI_DB_PASSWORD="$GLPI_DB_PASSWORD" \
    -v $D/storage/glpi:/var/glpi glpi/glpi:latest > /dev/null
fi
docker ps --format '{{.Names}} {{.Image}} {{.Status}}'
