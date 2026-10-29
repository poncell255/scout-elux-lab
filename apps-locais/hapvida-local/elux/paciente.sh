#!/bin/bash
set -u
umask 077
ROOT=/setup/hapvida-local
URL=http://127.0.0.1:3131/hapvida
BIO=/usr/bin/hapvida-local-digital
LOCK=/tmp/hapvida-local-paciente-$(id -u).lock
if ! mkdir "$LOCK" 2>/dev/null; then "$BIO" aviso 'O aplicativo do paciente já está aberto.'; exit 0; fi
TMP=$(mktemp -d /tmp/hapvida-local.XXXXXX) || { rmdir "$LOCK"; exit 1; }
TOKEN=''; PID=''; KEY=''
api() { wget -qO- -T 10 --header "X-Hapvida-Chave: $KEY" "$@"; }
cleanup(){
    if [ -n "$PID" ]; then kill "$PID" 2>/dev/null || true; fi
    if [ -n "$TOKEN" ]; then api --post-data '' "$URL/api/sessao/$TOKEN/encerrar" >/dev/null 2>&1 || true; fi
    rm -rf "$TMP"; rmdir "$LOCK" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' INT TERM HUP
for i in $(seq 1 20); do wget -q -T 1 -O /dev/null "$URL/health" && break; sleep 1; done
KEY=$(cat "$ROOT/.chave-local" 2>/dev/null)
if [ -z "$KEY" ] || ! wget -q -T 2 -O /dev/null "$URL/health"; then
    "$BIO" aviso 'O serviço local ainda não está pronto. Aguarde o recebimento da configuração da OU HAPVIDA Local.'; exit 1
fi
if ! ls "$ROOT/dados/digitais/"*.fpr >/dev/null 2>&1; then
    "$BIO" aviso 'Nenhum paciente com digital cadastrado neste equipamento. Abra Cadastro de Pacientes, adicione foto e digital, e tente novamente.'; exit 0
fi
OUT=$("$BIO" paciente "$ROOT/dados/digitais"); RC=$?
[ "$RC" -eq 0 ] || exit 0
ID=$(printf '%s\n' "$OUT" | sed -n 's/^IDENTIFICADO://p' | head -n1)
case "$ID" in ''|*[!0-9]*) exit 0;; esac
TOKEN=$(api --post-data "paciente=$ID&dispositivo=$(hostname)" "$URL/api/sessao") || TOKEN=''
case "$TOKEN" in ''|*[!0-9a-f]*) "$BIO" aviso 'Não foi possível abrir o prontuário local. Tente novamente.'; exit 1;; esac
[ "${#TOKEN}" -eq 64 ] || exit 1
/opt/microsoft/msedge/microsoft-edge --app="$URL/entrar/$TOKEN" --window-size=1280,900 \
    --user-data-dir="$TMP/perfil" --class=HapvidaLocalPaciente --no-first-run \
    --no-default-browser-check --password-store=basic >/dev/null 2>&1 &
PID=$!; wait "$PID"; PID=''
