#!/bin/bash
set -u
URL=http://127.0.0.1:3131
for i in $(seq 1 20); do
    if wget -q -T 1 -O /dev/null "$URL/hapvida/health"; then
        exec /opt/microsoft/msedge/microsoft-edge --app="$URL/hapvida/admin" \
            --user-data-dir=/home/elux/.config/microsoft-edge/app-hapvida-local-admin \
            --class=HapvidaLocalCadastro --no-first-run --no-default-browser-check --password-store=basic
    fi
    sleep 1
done
/usr/bin/hapvida-local-digital aviso 'O serviço local ainda não está pronto. Aguarde o recebimento da configuração da OU HAPVIDA Local e tente novamente.'
