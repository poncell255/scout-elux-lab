#!/bin/bash
for x in node xvfb-run chromium google-chrome xwd scrot gnome-screenshot convert; do command -v "$x" || true; done
test -d /root/node_modules/playwright && echo playwright-root || true
test -d /root/node_modules/puppeteer && echo puppeteer-root || true
find /root/pkgs/build/populos_hapvida/epm/output/populos_hapvida/populos_hapvida_app -type f -o -type l | head -15
