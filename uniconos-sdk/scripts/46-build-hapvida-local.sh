#!/bin/bash
# Recompila o pacote populos_hapvida_local numa versão nova usando o build do Codex (Downloads\hapvida-local\deploy\build-package.sh),
# que é fixo na 1.0.0 e recusa rodar com build anterior: guarda o build antigo e troca a versão numa cópia.
# Uso: 46-build-hapvida-local.sh 1.0.1
set -euo pipefail
V=${1:?versão}
B=/root/pkgs/build/populos_hapvida_local
[ -e "$B" ] && mv "$B" "$B.anterior-$(date +%Y%m%d%H%M%S)"
SRC=/mnt/c/Users/Administrator/Downloads/hapvida-local
sed -e "s/'version':'1.0.0'/'version':'$V'/" -e 's/\r$//' "$SRC/deploy/build-package.sh" > /tmp/build-hapvida-local.sh
grep -q "'version':'$V'" /tmp/build-hapvida-local.sh || { echo "não consegui trocar a versão"; exit 1; }
bash /tmp/build-hapvida-local.sh | tail -6
# confere que o binário novo tem a escolha do leitor
strings "$B/hapvida-local-digital" | grep -q POPULOS_LEITOR && echo "binário com escolha de leitor: ok"
