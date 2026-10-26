#!/bin/bash
# Sobe (ou atualiza) o site de provas em Docker no WSL: porta 3100, dados em /root/provas/data, leitor USB via usbipd.
# Espera /root/provas/.env com PROVAS_ADMIN e PROVAS_CHAVE (gerados no Windows, guardados em credenciais.txt).
set -e
service docker start > /dev/null 2>&1 || true
D=/root/provas; mkdir -p $D/data; chmod 700 $D
docker build -q -t populos-provas /mnt/c/ScoutSetup/provas/app > /dev/null
docker rm -f provas > /dev/null 2>&1 || true
# o código fica montado (somente leitura): para atualizar páginas e questões basta reiniciar o container
docker run -d --name provas --restart unless-stopped -p 3100:3100 --env-file $D/.env \
  -v $D/data:/data -v /mnt/c/ScoutSetup/provas/app:/app:ro \
  -v /dev/bus/usb:/dev/bus/usb --device-cgroup-rule='c 189:* rmw' \
  populos-provas > /dev/null
sleep 3
docker ps --filter name=provas --format '{{.Names}} {{.Status}}'
curl -s -o /dev/null -w 'site: HTTP %{http_code}\n' http://127.0.0.1:3100/provas/
docker exec provas sh -c 'ls /dev/bus/usb/*/* 2>/dev/null | head -3'
