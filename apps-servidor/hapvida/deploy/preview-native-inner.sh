#!/bin/bash
set -euo pipefail
BIN=/root/pkgs/build/populos_hapvida/hapvida-digital
"$BIN" paciente /tmp/hapvida-qa-galeria > /tmp/hapvida-native-qa.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
sleep 2
xwd -root -silent -out /tmp/hapvida-native.xwd
convert /tmp/hapvida-native.xwd "$SRC/previa/digital-hapvida.png"
echo 'Previa nativa salva; sem teste de reconhecimento, leitor ausente.'
