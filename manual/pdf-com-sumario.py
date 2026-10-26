"""Abre o .docx no LibreOffice, atualiza o sumário (índices) e exporta o PDF.
Uso: soffice --headless --accept=... & ; python3 pdf-com-sumario.py <docx> <pdf>"""
import sys, time, uno
from com.sun.star.beans import PropertyValue


def prop(nome, valor):
    p = PropertyValue(); p.Name = nome; p.Value = valor; return p


def main(docx, pdf):
    local = uno.getComponentContext()
    resolver = local.ServiceManager.createInstanceWithContext('com.sun.star.bridge.UnoUrlResolver', local)
    for _ in range(60):
        try:
            ctx = resolver.resolve('uno:socket,host=localhost,port=2002;urp;StarOffice.ComponentContext'); break
        except Exception:
            time.sleep(1)
    desktop = ctx.ServiceManager.createInstanceWithContext('com.sun.star.frame.Desktop', ctx)
    doc = desktop.loadComponentFromURL(uno.systemPathToFileUrl(docx), '_blank', 0, (prop('Hidden', True),))
    idx = doc.getDocumentIndexes()
    for i in range(idx.getCount()):
        idx.getByIndex(i).update()
    doc.refresh()
    for i in range(idx.getCount()):   # segunda passada: o sumário muda a paginação
        idx.getByIndex(i).update()
    n = idx.getCount()
    doc.storeToURL(uno.systemPathToFileUrl(pdf), (prop('FilterName', 'writer_pdf_Export'),))
    doc.close(True)
    try:
        desktop.terminate()
    except Exception:
        pass
    print('indices atualizados:', n)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
