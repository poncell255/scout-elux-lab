#!/bin/bash
f=/mnt/c/dg1/edge/edge.fpm
tail -c +49875 "$f" | gunzip 2>/dev/null | cpio -itv 2>/dev/null | grep -E 'logout.d|login.d' | head
f2=/mnt/c/dg1/ucd/ucd.fpm; off=$(grep -obUaP '\x1f\x8b\x08' "$f2" | head -1 | cut -d: -f1)
tail -c +$((off+1)) "$f2" | gunzip 2>/dev/null | cpio -itv 2>/dev/null | grep -E 'login.d/(20|25|29)|logout.d' | head
