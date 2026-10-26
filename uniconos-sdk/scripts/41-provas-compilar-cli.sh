#!/bin/bash
# Compila os utilitarios de digital do site de provas e testa se o leitor abre (sem dedo: espera 15 s e encerra).
S=/mnt/c/ScoutSetup/provas/app/cadastro; B=/root/provas/bin; mkdir -p $B
for p in cadastrar-digital ler-digital; do gcc -O2 -o $B/$p $S/$p.c $(pkg-config --cflags --libs libfprint-2) || exit 1; done
ls -la $B
timeout 15 $B/cadastrar-digital /tmp/teste.fpr t1 "Teste" ; echo "saida: $?"
