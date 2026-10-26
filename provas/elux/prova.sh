#!/bin/bash
# Sala de provas (OU Provas). Entregue pelo Scout em /setup/provas/prova.sh; app local com AutoStart e TM.
# Ciclo: baixa as digitais dos alunos com prova pendente -> identifica pela digital -> abre a prova do aluno
# no Edge em modo quiosque -> quando o aluno clica "Encerrar" (ou 2 min após o resultado), volta para a digital.
# Arquivos em /setup/provas: chave (X-Provas-Chave do site) e servidor (opcional, URL base do site).
CFG=/setup/provas
# (o tr do eLux é o do busybox: não entende classes como [:space:], por isso os caracteres vão escritos)
SERVIDOR=$(head -n1 $CFG/servidor 2>/dev/null | tr -d ' \t\r\n'); SERVIDOR=${SERVIDOR:-http://10.5.0.166/provas}
CHAVE=$(head -n1 $CFG/chave 2>/dev/null | tr -d '\r\n')
EDGE=/opt/microsoft/msedge/microsoft-edge
GALERIA=/tmp/provas-galeria
PERFIL=/tmp/provas-edge
LOG=/tmp/provas.log
FIM_AUTOMATICO=120   # segundos mostrando o resultado antes de voltar sozinho para a digital

log() { echo "$(date '+%F %T') $*" >> $LOG; }
api() { wget -qO- -T 15 --header "X-Provas-Chave: $CHAVE" "$@"; }
fechar_navegador() { kill "$1" 2>/dev/null; sleep 1; pkill -f "user-data-dir=$PERFIL" 2>/dev/null; }

log "início (servidor $SERVIDOR)"
while true; do
    # 1) digitais dos alunos com prova pendente
    rm -rf $GALERIA; mkdir -p $GALERIA
    api "$SERVIDOR/api/galeria" | tar -xz -C $GALERIA 2>> $LOG || log "galeria indisponível"

    # 2) identificação (tela cheia, botão Desligar = saída 3)
    saida=$(/usr/bin/populos-digital prova $GALERIA); rc=$?
    ID=$(echo "$saida" | sed -n 's/^IDENTIFICADO://p' | head -n1)
    log "digital: saída $rc, aluno '$ID'"
    if [ $rc -eq 3 ]; then ucsettingsctl --run Session.Shutdown; exit 0; fi
    [ -z "$ID" ] && { sleep 3; continue; }

    # 3) sessão da prova (retoma se já estava em andamento)
    TOKEN=$(api --post-data "aluno=$ID&dispositivo=$(hostname)" "$SERVIDOR/api/sessao" | tr -cd '0-9a-f')
    [ -z "$TOKEN" ] && { log "site não devolveu a prova do aluno $ID"; sleep 3; continue; }

    # 4) navegador em quiosque; se for fechado antes do fim, reabre na mesma prova
    finalizada_desde=0
    while true; do
        rm -rf $PERFIL
        "$EDGE" --user-data-dir=$PERFIL --kiosk "$SERVIDOR/p/$TOKEN" --edge-kiosk-type=fullscreen \
            --no-first-run --no-default-browser-check --noerrdialogs --disable-session-crashed-bubble \
            --disable-features=Translate --password-store=basic --disable-pinch >> $LOG 2>&1 &
        PID=$!
        while kill -0 $PID 2>/dev/null; do
            sleep 3
            e=$(api "$SERVIDOR/api/sessao/$TOKEN/estado")
            if [ "$e" = "sair" ]; then fechar_navegador $PID; break 2; fi
            if [ "$e" = "finalizada" ]; then
                [ $finalizada_desde -eq 0 ] && finalizada_desde=$(date +%s)
                if [ $(( $(date +%s) - finalizada_desde )) -ge $FIM_AUTOMATICO ]; then fechar_navegador $PID; break 2; fi
            fi
        done
        e=$(api "$SERVIDOR/api/sessao/$TOKEN/estado")
        [ "$e" = "sair" ] && break
        log "navegador fechou com a prova em '$e': reabrindo"
        sleep 2
    done
    log "aluno $ID terminou"
done
