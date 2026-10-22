#!/bin/bash
IMG=$(cat /root/epkg-image)
docker run --rm "$IMG" epkg Upload --help 2>&1 | head -40
