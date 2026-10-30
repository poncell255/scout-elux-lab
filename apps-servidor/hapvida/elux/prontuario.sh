#!/bin/bash
# Janela normal. Cada abertura exige digital; não altera login AD nem inicia no boot.
set -u
umask 077
CFG=/setup/hapvida
SERVIDOR=$(head -n1 "$CFG/servidor" 2>/dev/null | tr -d ' \t\r\n')
SERVIDOR=${SERVIDOR:-http://10.5.0.166/hapvida}
CHAVE=$(head -n1 "$CFG/chave" 2>/dev/null | tr -d '\r\n')
BIO=/usr/bin/hapvida-digital
LOCK=/tmp/hapvida-prontuario-$(id -u).lock
if ! mkdir "$LOCK" 2>/dev/null; then "$BIO" aviso 'O aplicativo já está aberto. Termine o acesso atual antes de abrir novamente.'; exit 0; fi
TMP=$(mktemp -d /tmp/hapvida.XXXXXX) || { rmdir "$LOCK"; exit 1; }
TOKEN=''
PID=''
api() { wget -qO- -T 20 --header "X-Hapvida-Chave: $CHAVE" "$@"; }
cleanup() {
    if [ -n "$PID" ]; then kill "$PID" 2>/dev/null || true; fi
    if [ -n "$TOKEN" ]; then api --post-data '' "$SERVIDOR/api/sessao/$TOKEN/encerrar" >/dev/null 2>&1 || true; fi
    rm -rf "$TMP"
    rmdir "$LOCK" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' INT TERM HUP
mkdir -p "$TMP/galeria" "$TMP/perfil"
if ! api "$SERVIDOR/api/galeria" > "$TMP/galeria.tar.gz"; then
    "$BIO" aviso 'Não foi possível acessar o servidor HAPVIDA. Confira a rede e tente novamente.'; exit 1
fi
if ! tar -xzf "$TMP/galeria.tar.gz" -C "$TMP/galeria" 2>/dev/null; then
    "$BIO" aviso 'A galeria de digitais não pôde ser carregada. Tente novamente.'; exit 1
fi
if ! ls "$TMP/galeria/"*.fpr >/dev/null 2>&1; then
    "$BIO" aviso 'Nenhum paciente com digital cadastrada. Acesse a área de cadastro HAPVIDA no servidor para cadastrar o paciente, sua foto e a digital.'; exit 0
fi
SAIDA=$("$BIO" paciente "$TMP/galeria"); RC=$?
[ "$RC" -eq 0 ] || exit 0
ID=$(printf '%s\n' "$SAIDA" | sed -n 's/^IDENTIFICADO://p' | head -n1)
case "$ID" in ''|*[!0-9]*) exit 0;; esac
TOKEN=$(api --post-data "paciente=$ID&dispositivo=$(hostname)" "$SERVIDOR/api/sessao") || TOKEN=''
case "$TOKEN" in ''|*[!0-9a-f]*) "$BIO" aviso 'Não foi possível abrir o prontuário. Confirme a digital novamente.'; exit 1;; esac
[ "${#TOKEN}" -eq 64 ] || exit 1
/opt/microsoft/msedge/microsoft-edge --user-data-dir="$TMP/perfil" \
    --app="$SERVIDOR/entrar/$TOKEN" --window-size=1280,900 --class=HapvidaProntuario \
    --no-first-run --no-default-browser-check --password-store=basic \
    --disable-features=Translate >/dev/null 2>&1 &
PID=$!
wait "$PID"
PID=''
