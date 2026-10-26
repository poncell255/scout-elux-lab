#!/bin/bash
# Gera o manual em Word e PDF a partir de C:\ScoutSetup\manual\manual.md (montado por montar-manual.ps1).
set -e
M=/mnt/c/ScoutSetup/manual; T=/root/manual; rm -rf $T; mkdir -p $T; cd $T
NOME=Manual-Implantacao-Scout-eLux-POPULOS
pandoc -o ref.docx --print-default-data-file reference.docx
python3 $M/estilo.py ref ref.docx
pandoc $M/manual.md -f markdown-auto_identifiers+pipe_tables -o $NOME.docx --reference-doc=ref.docx \
  --toc --toc-depth=2 -M toc-title="Sumário" --highlight-style=tango
python3 $M/estilo.py pos $NOME.docx
# PDF pelo LibreOffice com o sumário preenchido (a conversão direta deixa o sumário vazio)
python3 -c 'import uno' 2> /dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3-uno > /dev/null
soffice --headless --invisible --norestore --accept='socket,host=localhost,port=2002;urp;' > /dev/null 2>&1 &
python3 $M/pdf-com-sumario.py $T/$NOME.docx $T/$NOME.pdf
wait
pdfinfo $NOME.pdf | grep -E 'Pages|Page size'
rm -f pag-*.jpg; pdftoppm -jpeg -r 50 $NOME.pdf pag
cp $NOME.docx $NOME.pdf $M/
mkdir -p $M/previa; rm -f $M/previa/*; cp pag-*.jpg $M/previa/
ls -la $M/$NOME.*
