#!/bin/bash
# Confere o FPM populos_netskope_client: binÃ¡rios executÃ¡veis, serviÃ§o/timer habilitados, autostart e ausÃªncia do token.
set -euo pipefail
SRC=/mnt/c/Users/Administrator/Downloads/netskope-elux
VERSAO=${1:-142.1.0.2831.1}
P=/root/pkgs/netskope-payload-qa
rm -rf "$P"; mkdir -p "$P"
python3 -I "$SRC/deploy/extract-fpm.py" "$SRC/saida/populos_netskope_client-$VERSAO-1~testing.UC_ELUX7-1.0.fpm" "$P"
for f in stAgentSvc stAgentApp stAgentCli stAgentUI installerutil scripts/netskope-estado.sh; do test -x "$P/opt/netskope/stagent/$f"; done
test -L "$P/usr/lib/systemd/system/multi-user.target.wants/stagentd.service"
test -L "$P/usr/lib/systemd/system/timers.target.wants/netskope-salvar.timer"
test -f "$P/etc/xdg/autostart/stagentui.desktop" -a -f "$P/etc/xdg/autostart/stagentapp.desktop"
grep -q ExecCondition "$P/usr/lib/systemd/system/stagentd.service"
bash -n "$P/opt/netskope/stagent/scripts/netskope-estado.sh"
CHAVE=$(basename "$(ls /mnt/c/Users/Administrator/Downloads/NSClient_*.run | head -n1)" | cut -d_ -f4)
! grep -r -l -a -F "$CHAVE" "$P"
du -sh "$P"
echo 'FPM conferido: executÃ¡veis, stagentd e timer habilitados, autostart do Ã­cone, sem token.'