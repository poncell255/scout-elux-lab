#!/bin/bash
# Autostart da sessão: o stAgentApp (e o ícone) só se registram se o stAgentSvc já estiver ouvindo em /opt/netskope/stagent/svc.
# No eLux o login acontece antes do stagentd (que espera a rede), então espera o serviço até 5 min antes de abrir.
A=/opt/netskope/stagent
programa=${1:-stAgentApp}
for _ in $(seq 1 150); do
    pgrep -x stAgentSvc >/dev/null && [ -S "$A/svc" ] && break
    sleep 2
done
sleep 3
pgrep -u "$(id -u)" -x "$programa" >/dev/null || exec "$A/$programa"
