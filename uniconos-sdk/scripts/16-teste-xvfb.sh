#!/bin/bash
# Teste de fumaça do populos-digital numa tela virtual (sem leitor): não pode travar nem cair.
export DEBIAN_FRONTEND=noninteractive
command -v xvfb-run >/dev/null || apt-get install -y -qq xvfb > /dev/null 2>&1
mkdir -p /setup/populos-digital
B=/root/pkgs/populos_digital/bin/populos-digital
for modo in "entrada" "cadastrar-local" "portao wagner.poncell" "cadastrar wagner.poncell"; do
  saida=$(timeout 6 xvfb-run -a $B $modo 2>&1); rc=$?
  echo "== $modo -> rc=$rc (124 = ainda rodando após 6 s, esperado)"; echo "$saida" | grep -v -i -E 'dbus|accessibility|at-spi' | head -3
done
echo "== uso"; $B 2>&1 | head -2
