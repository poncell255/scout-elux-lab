#!/bin/bash
cd /root/pkgs/populos_vscode/data/x/usr/share/code
du -sh * 2>/dev/null | sort -h | tail -8
echo "== resources/app"; du -sh resources/app/* 2>/dev/null | sort -h | tail -6
echo "== node_modules maiores"; du -sh resources/app/node_modules/* 2>/dev/null | sort -h | tail -8
echo "== locales"; ls locales | wc -l; du -sh locales
echo "== extensions"; du -sh resources/app/extensions; ls resources/app/extensions | wc -l
echo "== comprimido xz (estimativa)"; tar -cf - . | xz -T0 -6 | wc -c | awk '{printf "%.0f MB\n",$1/1048576}'
