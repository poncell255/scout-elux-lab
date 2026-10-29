#!/bin/bash
set -u
URL=http://127.0.0.1:3133
for i in $(seq 1 20); do
    if wget -q -T 1 -O /dev/null "$URL/porto/health"; then
        exec /opt/microsoft/msedge/microsoft-edge --app="$URL/porto/admin" \
            --user-data-dir=/home/elux/.config/microsoft-edge/app-porto-local-admin \
            --class=PortoLocalCadastro --no-first-run --no-default-browser-check --password-store=basic
    fi
    sleep 1
done
/usr/bin/porto-local-digital aviso 'O serviço local ainda não está pronto. Aguarde o recebimento da configuração da OU Porto e tente novamente.'
