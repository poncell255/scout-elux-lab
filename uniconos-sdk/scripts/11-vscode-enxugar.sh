#!/bin/bash
cd /root/pkgs/populos_vscode/data/x/usr/share/code/resources/app
echo "== extensoes maiores"; du -sh extensions/* | sort -h | tail -12
echo "== node_modules.asar.unpacked"; du -sh node_modules.asar.unpacked/node_modules/* 2>/dev/null | sort -h | tail -8
echo "== bin"; du -sh ../../bin/* 2>/dev/null
