#!/bin/bash
# Tira o icone oficial do Chrome (32x32) do .deb do Google para usar no Scout.
D=/root/pkgs/chrome; mkdir -p $D; cd $D
[ -f chrome.deb ] || curl -sL -o chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
rm -rf x; mkdir x; dpkg-deb -x chrome.deb x
cp x/opt/google/chrome/product_logo_32.png /mnt/c/ScoutSetup/icons/chrome.png
cp x/opt/google/chrome/product_logo_128.png /mnt/c/ScoutSetup/icons/chrome-128.png
file /mnt/c/ScoutSetup/icons/chrome.png
