#!/bin/bash
IMG=$(cat /root/epkg-image)
docker run --rm "$IMG" cat /usr/share/unicon/suiteCPP.ini
echo "== keyrings"; docker run --rm "$IMG" ls /usr/share/keyrings/
