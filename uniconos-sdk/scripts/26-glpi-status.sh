#!/bin/bash
# Estado do GLPI no Docker.
docker ps --format '{{.Names}} {{.Status}}'
docker logs --tail 15 glpi 2>&1
curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1:8080/
