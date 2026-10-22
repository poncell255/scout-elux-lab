#!/bin/bash
# Carrega a imagem Docker do epkg e valida com um pacote mínimo (epkg New + Build).
set -u
service docker start > /dev/null 2>&1; sleep 2
docker load -i /mnt/c/UniconSDK/zip/docker/uniconos7-sdk-epkg-7.2609.0-5.tar.xz | tail -1
IMG=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep uniconos7-sdk-epkg | head -1)
echo "imagem: $IMG"
echo "$IMG" > /root/epkg-image
mkdir -p /root/pkgs/teste && cd /root/pkgs/teste && rm -rf ./*
docker run --rm --volume "$(pwd):/epm" --user "$(id -u):$(id -g)" "$IMG" epkg New --epm populos_teste --fpms populos_teste_arquivo > /dev/null
sed -i 's/^category=.*/category=Miscellaneous/' input/ebkepm
grep -q '^category=' input/ebkepm || sed -i '/^\[EPM\]/a category=Miscellaneous' input/ebkepm
mkdir -p input/populos_teste_arquivo/usr/share/populos && echo "pacote de teste POPULOS" > input/populos_teste_arquivo/usr/share/populos/teste.txt
docker run --rm --volume "$(pwd):/epm" --user "$(id -u):$(id -g)" "$IMG" epkg Build --container elux7 --releaseType test --skipSign 2>&1 | tail -6
find output/container -type f | sed 's#^#  #'
echo "== ebkepm"; cat input/ebkepm
