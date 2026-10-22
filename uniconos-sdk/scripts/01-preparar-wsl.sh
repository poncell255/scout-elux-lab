#!/bin/bash
# Prepara o Ubuntu 22.04 (WSL2) para o SDK do UniconOS: Docker, compiladores e bibliotecas de desenvolvimento.
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq docker.io build-essential pkg-config libfprint-2-dev libgtk-3-dev unzip xz-utils dpkg-dev > /tmp/apt.log 2>&1
echo "apt: $?"
service docker start > /dev/null 2>&1
sleep 3
docker --version
docker info 2>/dev/null | grep -E 'Server Version|Storage Driver'
echo "libfprint-2: $(pkg-config --modversion libfprint-2)"
echo "gtk+-3.0: $(pkg-config --modversion gtk+-3.0)"
