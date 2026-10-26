#!/bin/bash
# Mostra os metadados das digitais cadastradas no site de provas.
for f in /root/provas/data/digitais/*.fpr; do [ -f "$f" ] && echo "$(basename $f): $(docker exec -i provas ler-digital /dev/stdin < "$f")"; done
