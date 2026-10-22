#!/bin/bash
B=/root/pkgs/build/populos_vscode/epm
ls -la $B/tmp/usr/share | head; ls $B/tmp/usr/bin 2>&1 | head -3; du -sh $B/tmp 2>/dev/null
grep -n -i -E "dpkg|tar |extract|Copy|No files|not part" $B/epkg.log | head -20
