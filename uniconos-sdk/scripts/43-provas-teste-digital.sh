#!/bin/bash
# Testa no WSL o que o eLux da OU Provas faz: baixa a galeria do site (com a chave) e identifica pela digital
# (populos-digital 1.2.0, modo prova, em tela virtual Xvfb). Uso: CHAVE=... bash 43-provas-teste-digital.sh
# Pare o leitor no container antes? Não: o container só abre o leitor durante um cadastro.
G=/tmp/provas-galeria; rm -rf $G; mkdir -p $G
wget -qO- -T 15 --header "X-Provas-Chave: $CHAVE" http://127.0.0.1:3100/provas/api/galeria | tar -xz -C $G || { echo "galeria indisponível"; exit 1; }
echo "digitais na galeria:"; for f in $G/*.fpr; do [ -f "$f" ] && docker exec -i provas ler-digital /dev/stdin < "$f"; done
command -v Xvfb > /dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xvfb > /dev/null
Xvfb :77 -screen 0 1280x800x24 > /dev/null 2>&1 & XP=$!
sleep 1
echo ">>> coloque o dedo cadastrado no leitor (60 s)"
DISPLAY=:77 GDK_BACKEND=x11 WAYLAND_DISPLAY= timeout 60 /root/pkgs/populos_digital/bin/populos-digital prova $G; echo "saída: $?"
kill $XP
