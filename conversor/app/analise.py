"""Extração e análise de programas Linux (Ubuntu) para empacotar no eLux/UniconOS.

Nada do que é enviado é executado: .deb é aberto com dpkg-deb, AppImage com unsquashfs, .run (makeself)
lendo o tar.gz depois do cabeçalho, tar/zip com os módulos do Python (filtro 'data' contra caminhos maliciosos).
"""
import gzip
import json
import lzma
import os
import re
import shutil
import stat
import subprocess
import tarfile
import zipfile
from pathlib import Path

ELIAS_FPMS = Path('/mnt/c/ScoutSetup/diag/elias-fpms.json')
DIAG = Path('/mnt/c/ScoutSetup/diag')
LIMITE_IMAGEM_MB = 3700
# Sempre presentes no eLux (glibc); não precisam de pacote nem de embutir
BASE_GLIBC = {'libc.so.6', 'libm.so.6', 'libpthread.so.0', 'libdl.so.2', 'librt.so.1', 'ld-linux-x86-64.so.2',
              'libresolv.so.2', 'libutil.so.1', 'libanl.so.1', 'libmvec.so.1', 'libnsl.so.1', 'libcrypt.so.1'}
# Áreas graváveis do eLux (overlay em RAM) e persistente
GRAVAVEIS = ('/etc/', '/opt/', '/var/', '/root/', '/home/elux/', '/setup/', '/tmp/')
LIB_DIRS = ('/lib/', '/usr/lib/', '/lib64/', '/usr/lib64/', '/usr/local/lib/')
# EPMs que identificam uma imagem na lista do SDK
NOMES_EPM = [('ica', 'Citrix'), ('vmwareviewclient', 'Horizon'), ('microsoft_edge', 'Edge'), ('google_chrome', 'Chrome'),
             ('populos_teams', 'Teams'), ('populos_netskope', 'Netskope'), ('uberagent', 'uberAgent'), ('populos_glpi', 'GLPI')]


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, errors='replace', **kw)


def nome_pacote(texto):
    n = re.sub(r'[^a-z0-9]+', '_', texto.lower()).strip('_')
    n = re.sub(r'_+', '_', n) or 'programa'
    # Prefixo populos_ para não colidir com EPMs oficiais da Unicon no ELIAS (ex.: "xdotool", "google_chrome")
    if not n.startswith('populos_'):
        n = 'populos_' + n
    return n[:40]


def versao_pacote(texto):
    partes = re.findall(r'\d+', (texto or '').split(':')[-1].split('-')[0].split('+')[0].split('~')[0])
    partes = [str(int(p)) for p in partes[:4]]
    while len(partes) < 3:
        partes.append('0')
    return '.'.join(partes) if partes else '1.0.0'


# ---------------------------------------------------------------- catálogo ELIAS e imagens
class Catalogo:
    def __init__(self):
        self.mtime = None
        self.carregar()

    def carregar(self):
        m = ELIAS_FPMS.stat().st_mtime
        if m == self.mtime:
            return
        dados = json.loads(ELIAS_FPMS.read_text(encoding='utf-8-sig'))
        self.fpms = {}
        self.por_so = {}
        self.por_caminho = {}
        self.por_comando = {}
        for f in dados:
            nome = f.get('name')
            if not nome:
                continue
            ant = self.fpms.get(nome)
            if ant and str(ant.get('version')) >= str(f.get('version')):
                continue
            self.fpms[nome] = f
        for nome, f in self.fpms.items():
            for p in f.get('filenames') or []:
                self.por_caminho.setdefault(p, nome)
                b = p.rsplit('/', 1)[-1]
                if '.so' in b and any(p.startswith(d) for d in LIB_DIRS):
                    self.por_so.setdefault(b, set()).add(nome)
                if re.match(r'^/(usr/)?(s?bin)/[^/]+$', p):
                    self.por_comando.setdefault(b, set()).add(nome)
        # O catálogo só traz a versão eLux do minsystem (7.2609.0); a glibc é a do Ubuntu 22.04,
        # base do eLux 7 (mesmas versões de gtk 3.24.33, ffmpeg 4.4.2 etc.)
        self.glibc = '2.35'
        # Kernel do eLux: nome da pasta de módulos do kernelimage (ex.: /usr/lib/modules/6.18.48unicon0)
        ki = self.fpms.get('kernelimage', {})
        self.kernel = next((m.group(1) for p in ki.get('filenames') or []
                            for m in [re.match(r'^/usr/lib/modules/(\d[^/]*)$', p)] if m), '')
        self.mtime = m

    def imagens(self):
        res = []
        for p in sorted(DIAG.glob('idf-populos-v*.json'), key=lambda x: int(re.sub(r'\D', '', x.stem) or 0), reverse=True):
            res.append(p.stem.replace('idf-populos-', ''))
        return res

    def info_imagens(self):
        """Para a lista do SDK: OUs que usam cada imagem (diag/imagens-uso.json, gravado por imagens-uso.ps1), tamanho e destaques."""
        try:
            uso = json.loads((DIAG / 'imagens-uso.json').read_text(encoding='utf-8-sig'))
        except (OSError, ValueError):
            uso = {}
        res = []
        for v in self.imagens():
            try:
                idf = json.loads((DIAG / f'idf-populos-{v}.json').read_text(encoding='utf-8-sig'))
            except (OSError, ValueError):
                continue
            nomes = {e.get('name', '') for e in idf.get('epms', [])}
            dest = [r for n, r in NOMES_EPM if n in nomes]
            dest += sorted(n.replace('populos_', '').replace('_', ' ') for n in nomes
                           if n.startswith('populos_') and n not in dict(NOMES_EPM))
            ous = (uso.get('imagens') or {}).get(v) or []
            res.append({'id': v, 'mb': int((idf.get('imageSize') or 0) / 1048576), 'destaques': dest,
                        'ous': [o['ou'] for o in ous], 'aparelhos': sum(o.get('aparelhos', 0) for o in ous)})
        return res, uso.get('gerado', '')

    def fpms_da_imagem(self, imagem):
        p = DIAG / f'idf-populos-{imagem}.json'
        if not p.exists():
            return set(), 0
        idf = json.loads(p.read_text(encoding='utf-8-sig'))
        sel = {f['name'] for e in idf.get('epms', []) for f in e.get('fpms', []) if f.get('selected')}
        return sel, int((idf.get('imageSize') or 0) / 1048576)


# ---------------------------------------------------------------- extração
def tipo_arquivo(caminho):
    with open(caminho, 'rb') as f:
        ini = f.read(16384)
    nome = caminho.name.lower()
    if ini.startswith(b'!<arch>\ndebian-binary'):
        return 'deb'
    if ini[:4] == b'\x7fELF' and (ini[8:11] == b'AI\x02' or nome.endswith('.appimage')):
        return 'appimage'
    if ini[:2] in (b'#!',) and b'makeself' in ini.lower() or (nome.endswith('.run') and b'offset=`head -n' in ini):
        return 'makeself'
    if ini[:2] == b'\x1f\x8b' or ini[:3] == b'BZh' or ini[:6] == b'\xfd7zXZ\x00' or ini[257:262] == b'ustar':
        return 'tar'
    if ini[:4] == b'PK\x03\x04':
        return 'zip'
    if ini[:4] == b'\x7fELF':
        return 'elf'
    return 'desconhecido'


def _tar_seguro(origem, destino, fileobj=None):
    with tarfile.open(name=None if fileobj else origem, fileobj=fileobj, mode='r|*' if fileobj else 'r:*') as t:
        if hasattr(tarfile, 'data_filter'):
            t.extractall(destino, filter='data')
        else:
            for m in t:
                alvo = (Path(destino) / m.name).resolve()
                if not str(alvo).startswith(str(Path(destino).resolve())) or m.isdev():
                    continue
                t.extract(m, destino)


def extrair(arquivo, tipo, raiz, nome, log):
    """Monta em `raiz` a árvore de arquivos como ela ficará no eLux. Devolve metadados."""
    meta = {'scripts': {}, 'depends': '', 'descricao': '', 'pacote': '', 'versao': ''}
    raiz.mkdir(parents=True, exist_ok=True)
    if tipo == 'deb':
        r = run(['dpkg-deb', '-x', str(arquivo), str(raiz)])
        if r.returncode:
            raise RuntimeError('dpkg-deb -x falhou: ' + r.stderr[-400:])
        ctl = raiz.parent / 'controle'
        run(['dpkg-deb', '-e', str(arquivo), str(ctl)])
        campos = {}
        if (ctl / 'control').exists():
            atual = None
            for linha in (ctl / 'control').read_text(errors='replace').splitlines():
                if linha[:1] in (' ', '\t') and atual:
                    campos[atual] += '\n' + linha.strip()
                elif ':' in linha:
                    atual, v = linha.split(':', 1)
                    campos[atual] = v.strip()
        meta.update(pacote=campos.get('Package', ''), versao=campos.get('Version', ''),
                    depends=', '.join(x for x in (campos.get('Pre-Depends'), campos.get('Depends')) if x),
                    descricao=campos.get('Description', ''), arquitetura=campos.get('Architecture', ''))
        for s in ('preinst', 'postinst', 'prerm', 'postrm', 'config', 'triggers'):
            if (ctl / s).exists():
                meta['scripts'][s] = (ctl / s).read_text(errors='replace')[:20000]
    elif tipo == 'appimage':
        offset = _offset_elf(arquivo)
        destino = raiz / 'opt' / nome
        destino.parent.mkdir(parents=True, exist_ok=True)
        r = run(['unsquashfs', '-o', str(offset), '-d', str(destino), '-no-xattrs', str(arquivo)])
        if r.returncode:
            raise RuntimeError('unsquashfs falhou (AppImage tipo 2 esperado): ' + r.stderr[-400:])
        _wrapper(raiz, nome, f'/opt/{nome}/AppRun')
        for d in destino.glob('*.desktop'):
            _copiar_desktop(d, raiz, nome, f'/usr/bin/{nome}')
        meta['avisos_tipo'] = ['AppImage extraído em /opt/%s com atalho /usr/bin/%s (sem FUSE).' % (nome, nome)]
    elif tipo == 'makeself':
        with open(arquivo, 'rb') as f:
            cab = f.read(65536)
        m = re.search(rb'offset=`head -n (\d+)', cab)
        if not m:
            raise RuntimeError('cabeçalho makeself sem offset reconhecível')
        linhas = int(m.group(1))
        with open(arquivo, 'rb') as f:
            for _ in range(linhas):
                f.readline()
            destino = raiz / 'opt' / nome
            destino.mkdir(parents=True, exist_ok=True)
            _tar_seguro(None, destino, fileobj=f)
        script = re.search(rb'script="([^"]*)"', cab)
        meta['scripts']['instalador makeself'] = cab.decode('latin-1')[:6000]
        if script:
            s = destino / script.group(1).decode().lstrip('./')
            if s.is_file():
                meta['scripts'][script.group(1).decode()] = s.read_text(errors='replace')[:30000]
        meta['avisos_tipo'] = ['Instalador .run: o conteúdo foi colocado em /opt/%s, mas o script de instalação NÃO roda no eLux. '
                               'Veja abaixo o que ele faria (serviços, cópias para /usr, cadastro) e adapte.' % nome,
                               'Instaladores .run às vezes leem parâmetros do próprio nome do arquivo (ex.: Netskope); o nome original não vai no pacote.']
    elif tipo in ('tar', 'zip'):
        tmp = raiz.parent / 'arquivo'
        tmp.mkdir(exist_ok=True)
        if tipo == 'tar':
            _tar_seguro(str(arquivo), tmp)
        else:
            with zipfile.ZipFile(arquivo) as z:
                for i in z.infolist():
                    alvo = (tmp / i.filename).resolve()
                    if str(alvo).startswith(str(tmp.resolve())):
                        z.extract(i, tmp)
                        modo = i.external_attr >> 16
                        if modo & 0o111 and alvo.is_file():
                            alvo.chmod(0o755)
        itens = [p for p in tmp.iterdir()]
        base = itens[0] if len(itens) == 1 and itens[0].is_dir() else tmp
        debs = sorted(p for p in base.rglob('*.deb') if p.is_file() and tipo_arquivo(p) == 'deb')
        if debs:
            # Pacote de fabricante com vários .deb (ex.: LibreOffice_*_deb.tar.gz): abre todos na mesma árvore, como o dpkg faria
            for p in debs:
                r = run(['dpkg-deb', '-x', str(p), str(raiz)])
                if r.returncode:
                    raise RuntimeError(f'dpkg-deb -x falhou em {p.name}: ' + r.stderr[-400:])
                ctl = raiz.parent / 'controle' / p.stem
                run(['dpkg-deb', '-e', str(p), str(ctl)])
                if not meta['descricao'] and (ctl / 'control').exists():
                    d = re.search(r'(?m)^Description: (.*)$', (ctl / 'control').read_text(errors='replace'))
                    meta['descricao'] = d.group(1) if d else ''
                for s in ('preinst', 'postinst', 'prerm', 'postrm'):
                    if (ctl / s).exists():
                        meta['scripts'][f'{p.stem} {s}'] = (ctl / s).read_text(errors='replace')[:20000]
            meta['avisos_tipo'] = [f'Arquivo com {len(debs)} pacotes .deb: todos foram abertos na mesma árvore, como o dpkg instalaria.']
            log(f'{len(debs)} .deb dentro do arquivo')
        elif any((base / d).is_dir() for d in ('usr', 'opt', 'etc')):
            shutil.copytree(base, raiz, symlinks=True, dirs_exist_ok=True)
            meta['avisos_tipo'] = ['Arquivo com estrutura de sistema (usr/opt/etc): copiado como está.']
        else:
            shutil.copytree(base, raiz / 'opt' / nome, symlinks=True, dirs_exist_ok=True)
            meta['avisos_tipo'] = ['Arquivo compactado sem estrutura de sistema: colocado em /opt/%s.' % nome]
        shutil.rmtree(tmp, ignore_errors=True)
    elif tipo == 'elf':
        d = raiz / 'opt' / nome
        d.mkdir(parents=True, exist_ok=True)
        shutil.copy2(arquivo, d / arquivo.name)
        (d / arquivo.name).chmod(0o755)
        _wrapper(raiz, nome, f'/opt/{nome}/{arquivo.name}')
    else:
        raise RuntimeError('Formato não reconhecido. Envie .deb, .AppImage, .run (makeself), .tar.gz/.tar.xz, .zip ou um binário ELF.')
    log(f'extraído ({tipo})')
    return meta


def _offset_elf(arquivo):
    with open(arquivo, 'rb') as f:
        h = f.read(64)
    shoff = int.from_bytes(h[0x28:0x30], 'little')
    shentsize = int.from_bytes(h[0x3A:0x3C], 'little')
    shnum = int.from_bytes(h[0x3C:0x3E], 'little')
    return shoff + shentsize * shnum


def _wrapper(raiz, nome, alvo):
    b = raiz / 'usr' / 'bin'
    b.mkdir(parents=True, exist_ok=True)
    w = b / nome
    w.write_text(f'#!/bin/sh\nexec {alvo} "$@"\n')
    w.chmod(0o755)


def _copiar_desktop(origem, raiz, nome, exe):
    d = raiz / 'usr' / 'share' / 'applications'
    d.mkdir(parents=True, exist_ok=True)
    txt = re.sub(r'(?m)^Exec=\S+', f'Exec={exe}', origem.read_text(errors='replace'))
    (d / f'{nome}.desktop').write_text(txt)


# ---------------------------------------------------------------- análise
def eh_elf(p):
    try:
        with open(p, 'rb') as f:
            return f.read(4) == b'\x7fELF'
    except OSError:
        return False


def info_elf(p):
    r = run(['readelf', '-dW', str(p)])
    needed = re.findall(r'\(NEEDED\)\s+Shared library: \[([^\]]+)\]', r.stdout)
    rpath = re.findall(r'\((?:RPATH|RUNPATH)\)\s+Library (?:rpath|runpath): \[([^\]]+)\]', r.stdout)
    h = run(['readelf', '-hW', str(p)]).stdout
    classe = 'ELF64' if 'ELF64' in h else ('ELF32' if 'ELF32' in h else '')
    maquina = re.search(r'Machine:\s+(.+)', h)
    tipo = re.search(r'Type:\s+(\w+)', h)
    v = run(['objdump', '-T', str(p)]).stdout
    glibc = sorted(set(re.findall(r'GLIBC_(\d+\.\d+(?:\.\d+)?)', v)), key=lambda x: [int(i) for i in x.split('.')])
    return {'needed': needed, 'rpath': rpath, 'classe': classe, 'maquina': maquina.group(1).strip() if maquina else '',
            'tipo': tipo.group(1) if tipo else '', 'glibc': glibc[-1] if glibc else ''}


def versao_maior(a, b):
    return [int(x) for x in a.split('.')] > [int(x) for x in b.split('.')]


def vermagic(p):
    """Kernel para o qual o módulo foi compilado (campo vermagic do .ko, também .ko.xz/.gz/.zst)."""
    try:
        if p.stat().st_size > 200 * 1048576:
            return ''
        if p.name.endswith('.xz'):
            dados = lzma.decompress(p.read_bytes())
        elif p.name.endswith('.gz'):
            dados = gzip.decompress(p.read_bytes())
        elif p.name.endswith('.zst'):
            dados = subprocess.run(['zstd', '-dc', str(p)], capture_output=True, timeout=60).stdout
        else:
            dados = p.read_bytes()
    except Exception:
        return ''
    m = re.search(rb'vermagic=([^\x00]+)', dados)
    return m.group(1).decode('latin-1').split()[0] if m else ''


def analisar_driver(raiz, arquivos, cat, sel):
    """Peças de driver: módulos do kernel, DKMS, firmware, udev, modprobe, impressora (CUPS/PPD) e scanner (SANE)."""
    def achar(rx):
        return [a for a in arquivos if re.search(rx, a) and not (raiz / a.lstrip('/')).is_dir()]
    k = cat.kernel
    modulos = []
    for a in achar(r'\.ko(\.(xz|gz|zst))?$')[:100]:
        vm = vermagic(raiz / a.lstrip('/'))
        modulos.append({'arquivo': a, 'vermagic': vm, 'compativel': bool(k) and vm == k,
                        'pasta_ok': bool(re.match(rf'^/(usr/)?lib/modules/{re.escape(k)}/', a)) if k else False})
    r = {
        'kernel_elux': k, 'modulos': modulos,
        'dkms': achar(r'^/usr/src/[^/]+/dkms\.conf$'),
        'firmware': achar(r'^/(usr/)?lib/firmware/'),
        'udev': achar(r'^/((usr/)?lib|etc)/udev/rules\.d/[^/]+\.rules$'),
        'modprobe': achar(r'^/((usr/)?lib|etc)/(modprobe\.d|modules-load\.d)/[^/]+\.conf$'),
        'cups': achar(r'^/usr/lib/cups/(filter|backend)/'),
        'ppd': achar(r'\.ppd(\.gz)?$|^/usr/share/cups/(drv|model)/'),
        'sane': achar(r'/sane/libsane-[^/]+\.so|^/etc/sane\.d/'),
    }
    tipos = [n for n, c in (('módulo do kernel', modulos or r['dkms']), ('firmware', r['firmware']),
                            ('regras udev', r['udev']), ('impressora (CUPS)', r['cups'] or r['ppd']),
                            ('scanner (SANE)', r['sane'])) if c]
    avisos, fpms = [], []
    ruins = [m for m in modulos if not m['compativel']]
    if ruins:
        vms = sorted({m['vermagic'] or 'desconhecido' for m in ruins})
        avisos.append(f'{len(ruins)} módulo(s) do kernel foram compilados para {", ".join(vms)}, mas o eLux usa {k or "?"}: '
                      'não carregam no eLux. Compile o driver contra o kernel do eLux (código-fonte ou DKMS) ou peça o pacote à Unicon.')
    bons = [m for m in modulos if m['compativel']]
    if bons and not all(m['pasta_ok'] for m in bons):
        avisos.append(f'Há módulos compatíveis fora de /usr/lib/modules/{k}/: mova-os para /usr/lib/modules/{k}/extern '
                      '(como fazem os pacotes kernel_*_modules da Unicon).')
    if r['dkms']:
        avisos.append('O pacote traz código-fonte DKMS: o eLux não compila módulos no aparelho. Compile antes, contra o kernel '
                      f'{k or "do eLux"}, e empacote o .ko pronto.')
    if r['cups'] or r['ppd']:
        falta = [f for f in ('baseprinter_cupsbin', 'baseprinter_cupsfilter') if f not in sel]
        fpms += falta
        avisos.append('Driver de impressora: a fila é criada no Scout (Impressoras) apontando para o PPD/filtro do pacote.'
                      + (f' A imagem precisa de {", ".join(falta)}.' if falta else ''))
    if r['sane'] and 'sane_base' not in sel:
        fpms.append('sane_base')
        avisos.append('Driver de scanner (SANE): a imagem precisa do pacote Unicon sane_base.')
    if r['udev']:
        avisos.append('Regras udev entram em vigor no próximo boot (o udev é o da imagem).')
    if r['firmware']:
        avisos.append('Firmware: confira em "Conflitos" se o arquivo já vem num pacote de firmware da Unicon.')
    for c in ('dkms', 'firmware', 'udev', 'modprobe', 'cups', 'ppd', 'sane'):
        r[c] = r[c][:50]
    r.update(tipos=tipos, avisos=avisos, fpms=fpms)
    return r


def analisar(raiz, cat, imagem, meta, log, categoria='software'):
    cat.carregar()
    sel, tam_imagem = cat.fpms_da_imagem(imagem)
    arquivos, elfs, executaveis, internos = [], {}, [], {}
    total = 0
    for p in sorted(raiz.rglob('*')):
        rel = '/' + str(p.relative_to(raiz))
        if p.is_symlink():
            arquivos.append(rel)
            if '.so' in p.name:
                internos.setdefault(p.name, rel)
            continue
        if not p.is_file():
            continue
        arquivos.append(rel)
        total += p.stat().st_size
        if '.so' in p.name:
            internos.setdefault(p.name, rel)
        if eh_elf(p):
            elfs[rel] = info_elf(p)
            if elfs[rel]['tipo'] in ('EXEC', 'DYN') and os.access(p, os.X_OK) and '.so' not in p.name:
                executaveis.append(rel)
        elif os.access(p, os.X_OK):
            executaveis.append(rel)
    log(f'{len(arquivos)} arquivos, {len(elfs)} ELF')

    libs = {}
    for rel, i in elfs.items():
        for so in i['needed']:
            libs.setdefault(so, {'usado_por': []})['usado_por'].append(rel)
    for so, d in libs.items():
        d['usado_por'] = sorted(d['usado_por'])[:8]
        fpms = sorted(cat.por_so.get(so, ()))
        if so in internos:
            d.update(estado='pacote', onde=internos[so])
        elif fpms and any(f in sel for f in fpms):
            d.update(estado='imagem', fpm=next(f for f in fpms if f in sel))
        elif fpms:
            d.update(estado='fpm', fpm=fpms[0], opcoes=fpms)
        elif so in BASE_GLIBC:
            d.update(estado='imagem', fpm='glibc (base)')
        else:
            d.update(estado='faltando')

    # Interpretadores de scripts (#!)
    interpretes = {}
    for rel in executaveis:
        p = raiz / rel.lstrip('/')
        if p.is_symlink() or rel in elfs:
            continue
        try:
            with open(p, 'rb') as f:
                l = f.readline(200).decode('latin-1').strip()
        except OSError:
            continue
        if l.startswith('#!'):
            partes = l[2:].split()
            if not partes:
                continue
            cmd = partes[1] if partes[0].endswith('/env') and len(partes) > 1 else partes[0].rsplit('/', 1)[-1]
            d = interpretes.setdefault(cmd, {'usado_por': []})
            d['usado_por'].append(rel)
    for cmd, d in interpretes.items():
        d['usado_por'] = d['usado_por'][:5]
        fpms = sorted(cat.por_comando.get(cmd, ()))
        if any(('/usr/bin/' + cmd) == a or ('/bin/' + cmd) == a for a in arquivos):
            d['estado'] = 'pacote'
        elif fpms and any(f in sel for f in fpms):
            d.update(estado='imagem', fpm=next(f for f in fpms if f in sel))
        elif fpms:
            d.update(estado='fpm', fpm=fpms[0])
        else:
            d['estado'] = 'faltando'

    avisos = list(meta.get('avisos_tipo', []))
    arqs_32 = [r for r, i in elfs.items() if i['classe'] == 'ELF32' or (i['maquina'] and 'X86-64' not in i['maquina'] and 'x86-64' not in i['maquina'].lower())]
    if arqs_32:
        avisos.append('Há binários que não são x86-64 (32 bits ou outra arquitetura); o eLux 7 é só x86-64: ' + ', '.join(arqs_32[:5]))
    glibc_max = ''
    for i in elfs.values():
        if i['glibc'] and (not glibc_max or versao_maior(i['glibc'], glibc_max)):
            glibc_max = i['glibc']
    if glibc_max and versao_maior(glibc_max, cat.glibc):
        avisos.append(f'Exige GLIBC {glibc_max}, mas o eLux tem {cat.glibc}: não vai rodar. Use a versão do programa para Ubuntu 22.04.')
    conflitos = [{'arquivo': a, 'fpm': cat.por_caminho[a]} for a in arquivos
                 if a in cat.por_caminho and not (raiz / a.lstrip('/')).is_dir() and not a.endswith('/')]
    conflitos = [c for c in conflitos if not (raiz / c['arquivo'].lstrip('/')).is_dir()]
    if conflitos:
        avisos.append(f'{len(conflitos)} arquivo(s) já existem em pacotes do eLux: o ELIAS acusa conflito se os dois estiverem na imagem. Veja "Conflitos".')
    fora = sorted({a.split('/')[1] for a in arquivos if not a.startswith(('/usr/', '/opt/', '/etc/', '/lib/', '/var/', '/bin/', '/sbin/', '/lib64/'))})
    if fora:
        avisos.append('Arquivos fora de /usr, /opt, /etc e /var: ' + ', '.join('/' + f for f in fora) + '.')
    if any(a.startswith('/usr/local/') for a in arquivos):
        avisos.append('Há arquivos em /usr/local: no eLux /usr é somente leitura; se o programa grava lá, não funciona.')
    if meta.get('scripts'):
        avisos.append('Scripts de instalação (%s) não rodam no eLux: veja o que fazem e reproduza no pacote (serviços, links, usuários, cache).'
                      % ', '.join(meta['scripts']))
    avisos.append('No eLux só são graváveis /etc, /opt, /var, /root e /home/elux (em RAM, somem no reinício) e /setup (persistente, pequena).')

    unidades = []
    for a in arquivos:
        if re.match(r'^/(usr/)?lib/systemd/system/[^/]+\.(service|timer|socket)$', a) and (raiz / a.lstrip('/')).is_file():
            txt = (raiz / a.lstrip('/')).read_text(errors='replace')
            wb = re.findall(r'(?m)^WantedBy=(.+)$', txt)
            ja = any(re.search(r'\.wants/' + re.escape(a.rsplit('/', 1)[-1]) + '$', x) for x in arquivos)
            unidades.append({'arquivo': a, 'wantedby': ' '.join(wb).split(), 'habilitada': ja})
    atalhos = []
    for a in arquivos:
        if a.startswith('/usr/share/applications/') and a.endswith('.desktop') and (raiz / a.lstrip('/')).is_file():
            txt = (raiz / a.lstrip('/')).read_text(errors='replace')
            ex = re.search(r'(?m)^Exec=(.*)$', txt)
            nm = re.search(r'(?m)^Name=(.*)$', txt)
            atalhos.append({'arquivo': a, 'nome': nm.group(1) if nm else '', 'exec': re.sub(r'\s*%[a-zA-Z]', '', ex.group(1)).strip() if ex else ''})

    doc = sum((raiz / a.lstrip('/')).stat().st_size for a in arquivos
              if a.startswith(('/usr/share/doc/', '/usr/share/man/', '/usr/share/info/', '/usr/share/lintian/'))
              and (raiz / a.lstrip('/')).is_file() and not (raiz / a.lstrip('/')).is_symlink())
    driver = analisar_driver(raiz, arquivos, cat, sel)
    if driver['tipos']:
        avisos[-1:-1] = driver['avisos']
    elif categoria == 'driver':
        avisos.insert(0, 'Não achei peças de driver (módulo .ko, DKMS, firmware, udev, CUPS/PPD ou SANE): confira se é mesmo um driver.')
    falt = [s for s, d in libs.items() if d['estado'] == 'faltando']
    fpms_add = sorted({d['fpm'] for d in list(libs.values()) + list(interpretes.values()) if d.get('estado') == 'fpm'}
                      | set(driver['fpms']))
    return {
        'imagem': imagem, 'tamanho_imagem_mb': tam_imagem, 'glibc_elux': cat.glibc, 'glibc_exigida': glibc_max,
        'arquivos': len(arquivos), 'tamanho_mb': round(total / 1048576, 1), 'docs_mb': round(doc / 1048576, 1),
        'elfs': len(elfs), 'executaveis': executaveis[:60], 'libs': dict(sorted(libs.items())), 'interpretes': interpretes,
        'faltando': falt, 'fpms_adicionar': fpms_add, 'conflitos': conflitos[:200], 'avisos': avisos,
        'unidades': unidades, 'atalhos': atalhos, 'driver': driver,
    }
