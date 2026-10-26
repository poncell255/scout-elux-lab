#!/bin/bash
# Ferramentas para gerar o manual (Word/PDF) no WSL: pandoc, LibreOffice Writer, poppler, fontes.
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq pandoc libreoffice-writer poppler-utils fonts-dejavu fonts-liberation fonts-crosextra-carlito python3-docx > /dev/null
pandoc --version | head -1; soffice --version; pdftoppm -v 2>&1 | head -1; python3 -c "import docx; print('python-docx ok')"
