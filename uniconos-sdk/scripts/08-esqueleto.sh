#!/bin/bash
IMG=$(cat /root/epkg-image); d=/root/pkgs/esqueleto; rm -rf $d; mkdir -p $d; cd $d
docker run --rm -v "$d:/epm" "$IMG" epkg New --epm teste_epm --fpms teste_fpm > /dev/null
find . -type f | sort; echo "== variables"; cat elux/variables 2>/dev/null; echo "== control"; cat elux/control 2>/dev/null
