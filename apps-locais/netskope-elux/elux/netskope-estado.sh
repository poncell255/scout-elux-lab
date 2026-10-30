#!/bin/bash
# Netskope no eLux: /opt fica em RAM, então o cadastro (nsbranding e config do cliente) é guardado em /setup/netskope-estado.
#   preparar: antes do stagentd; restaura o estado salvo ou faz o cadastro com o nome do instalador entregue pelo Scout.
#   salvar:   copia o estado atual para /setup quando muda (timer e parada do serviço).
A=/opt/netskope/stagent
INSTALADOR=/setup/netskope/instalador
E=/setup/netskope-estado
FIXOS=' stAgentSvc stAgentApp stAgentCli stAgentUI nsdiag certutil uninstall.sh installerutil scripts resources ossl-modules logs download tempImages svc '
log(){ echo "netskope-estado: $*"; }

salvar() {
    ls "$A"/nsbranding.json* >/dev/null 2>&1 || { log 'sem cadastro; nada a salvar'; return 0; }
    local t="$E.novo"; rm -rf "$t"; mkdir -p -m 700 "$t"
    for f in "$A"/* "$A"/.[!.]*; do
        [ -e "$f" ] || continue
        case "$FIXOS" in *" $(basename "$f") "*) continue ;; esac
        cp -a "$f" "$t/"
    done
    if [ "$(du -sm "$t" | cut -f1)" -gt 50 ]; then log 'estado maior que 50 MB; não salvo'; rm -rf "$t"; return 0; fi
    if [ -d "$E" ] && command -v diff >/dev/null && diff -r -q "$E" "$t" >/dev/null 2>&1; then rm -rf "$t"; return 0; fi
    rm -rf "$E.velho"; [ -d "$E" ] && mv "$E" "$E.velho"; mv "$t" "$E"; rm -rf "$E.velho"; sync
    log 'estado salvo'
}

preparar() {
    mkdir -p -m 755 "$A/logs" "$A/data"
    # cp -a de "$E/." leva o modo 700 de $E para $A; o agente do usuário (elux) precisa entrar em $A (socket svc e binários)
    if ls "$E"/nsbranding.json* >/dev/null 2>&1; then cp -a "$E/." "$A/"; chmod 755 "$A"; rm -f "$A/svc" "$E/svc"; log 'estado restaurado'; return 0; fi
    local nome; nome=$(head -n1 "$INSTALADOR" 2>/dev/null | tr -d '\r\n ')
    case "$nome" in NSClient_*.run) ;; *) log "nome de instalador inválido em $INSTALADOR"; return 1 ;; esac
    local i rel
    for i in $(seq 1 24); do
        rel=$(head -c 20 /dev/urandom | md5sum | head -c 20)
        "$A/installerutil" --download_branding_file '{"LoginUser":"elux","ReportFileName":"'"$rel"'","MyRunFileName":"'"$nome"'","TenantHostname":"", "Orgkey":"", "UserEmail":"", "UserUpn":"", "IdpMode":"", "TenantName":"", "TenantDomain":"", "EnrollAuthToken":"", "EnrollEncryptToken":"", "InstallTags":""}'
        [ -f "$A/logs/$rel" ] && { cat "$A/logs/$rel"; rm -f "$A/logs/$rel"; }
        if ls "$A"/nsbranding.json* >/dev/null 2>&1; then
            chmod 644 "$A"/nsbranding.json* "$A"/nsidpconfig.json 2>/dev/null
            "$A/installerutil" --update_install_status installed
            log "cadastro feito (tentativa $i)"; salvar; return 0
        fi
        sleep 5
    done
    log 'cadastro falhou: sem rede ou token recusado'; return 1
}

case "$1" in
    preparar) preparar ;;
    salvar) salvar ;;
    *) echo "uso: $0 preparar|salvar" >&2; exit 2 ;;
esac
