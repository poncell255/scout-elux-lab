"""Completa e empacota a árvore extraída: bibliotecas do Ubuntu 22.04 que o eLux não tem, serviços, EPM/FPM via epkg."""
import configparser
import os
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

from analise import BASE_GLIBC, eh_elf, info_elf, run

CACHE = Path('/root/conversor/cache/debs')
EPKG_IMAGEM = Path('/root/epkg-image')


def _apt_pacotes_dos_so(sos):
    """Uma varredura do índice apt-file para várias libs: {so: pacote Ubuntu}."""
    if not sos:
        return {}
    alt = '|'.join(re.escape(s) for s in sorted(sos))
    r = run(['apt-file', 'search', '-x', r'^/(usr/)?lib/x86_64-linux-gnu/(' + alt + ')$'])
    res = {}
    for l in r.stdout.splitlines():
        if ': ' not in l:
            continue
        pkg, caminho = l.split(': ', 1)
        so = caminho.rsplit('/', 1)[-1]
        if re.search(r'-(dbg|dbgsym|dev)$', pkg) or so in res:
            continue
        res[so] = pkg
    return res


def _baixar_deb(pacote, log):
    CACHE.mkdir(parents=True, exist_ok=True)
    existentes = list(CACHE.glob(f'{pacote}_*.deb'))
    if existentes:
        return existentes[0]
    r = run(['apt-get', 'download', pacote], cwd=CACHE)
    if r.returncode:
        log(f'apt-get download {pacote} falhou: {r.stderr.strip()[-200:]}')
        return None
    ex = list(CACHE.glob(f'{pacote}_*.deb'))
    return ex[0] if ex else None


def embutir_faltantes(raiz, nome, analise, cat, sel, log):
    """Baixa do Ubuntu 22.04 as libs que nem o pacote nem o eLux têm e coloca em /opt/<nome>/lib-ubuntu.
    Repete para as dependências das libs embutidas. Devolve (embutidas, nao_achadas, dir_rel)."""
    destino_rel = f'/opt/{nome}/lib-ubuntu'
    destino = raiz / destino_rel.lstrip('/')
    pend = list(analise['faltando'])
    vistos, embutidas, nao = set(), {}, []
    mapa, buscados = {}, set()
    while pend:
        rodada = [s for s in dict.fromkeys(pend) if s not in buscados]
        if rodada:
            buscados.update(rodada)
            mapa.update(_apt_pacotes_dos_so(rodada))
        so = pend.pop(0)
        if so in vistos:
            continue
        vistos.add(so)
        pkg = mapa.get(so)
        if not pkg:
            nao.append(so)
            continue
        deb = _baixar_deb(pkg, log)
        if not deb:
            nao.append(so)
            continue
        tmp = raiz.parent / 'deb-tmp'
        shutil.rmtree(tmp, ignore_errors=True)
        tmp.mkdir(parents=True)
        r = run(['dpkg-deb', '-x', str(deb), str(tmp)])
        if r.returncode:
            log(f'dpkg-deb -x {deb.name} falhou: {r.stderr.strip()[-200:]}')
        achou = None
        for p in tmp.rglob(so):
            achou = p
            break
        if not achou:
            nao.append(so)
            shutil.rmtree(tmp, ignore_errors=True)
            continue
        destino.mkdir(parents=True, exist_ok=True)
        real = achou.resolve()
        shutil.copy2(real, destino / real.name)
        if real.name != so:
            alvo = destino / so
            if not alvo.exists():
                os.symlink(real.name, alvo)
        embutidas[so] = pkg
        log(f'embutida {so} (Ubuntu {pkg})')
        for dep in info_elf(destino / real.name)['needed']:
            if dep in vistos or dep in BASE_GLIBC or dep in embutidas:
                continue
            if (raiz / 'opt').exists() and any((raiz).rglob(dep)):
                continue
            fpms = cat.por_so.get(dep, ())
            if fpms and any(f in sel for f in fpms):
                continue
            pend.append(dep)
        shutil.rmtree(tmp, ignore_errors=True)
    return embutidas, nao, destino_rel


def ajustar_runpath(raiz, dir_rel, log):
    """Acrescenta o diretório das libs embutidas ao RUNPATH de todo ELF do pacote (patchelf)."""
    n = 0
    for p in raiz.rglob('*'):
        if p.is_symlink() or not p.is_file() or not eh_elf(p):
            continue
        atual = run(['patchelf', '--print-rpath', str(p)])
        if atual.returncode:
            continue
        caminhos = [c for c in atual.stdout.strip().split(':') if c]
        if dir_rel in caminhos:
            continue
        # Sem RUNPATH próprio usa DT_RPATH (--force-rpath), que vale também para as dependências indiretas
        runpath = '(RUNPATH)' in run(['readelf', '-dW', str(p)]).stdout
        r = run(['patchelf'] + ([] if runpath else ['--force-rpath']) + ['--set-rpath', ':'.join(caminhos + [dir_rel]), str(p)])
        if r.returncode == 0:
            n += 1
    log(f'RUNPATH ajustado em {n} ELF')
    return n


def habilitar_unidades(raiz, analise, log):
    feitos = []
    for u in analise['unidades']:
        if u['habilitada'] or not u['wantedby']:
            continue
        base = raiz / u['arquivo'].lstrip('/')
        for alvo in u['wantedby']:
            d = base.parent / f'{alvo}.wants'
            d.mkdir(parents=True, exist_ok=True)
            link = d / base.name
            if not link.exists():
                os.symlink(f'../{base.name}', link)
                feitos.append(f'{alvo}.wants/{base.name}')
    if feitos:
        log('serviços habilitados: ' + ', '.join(feitos))
    return feitos


def remover_docs(raiz):
    for d in ('usr/share/doc', 'usr/share/man', 'usr/share/info', 'usr/share/lintian'):
        shutil.rmtree(raiz / d, ignore_errors=True)


def construir(trabalho, raiz, nome, versao, resumo, descricao, log):
    """epkg New/Build no container oficial da Unicon. Devolve (epm, fpm, zip)."""
    b = trabalho / 'build'
    shutil.rmtree(b, ignore_errors=True)
    (b / 'epm').mkdir(parents=True)
    (b / 'data').mkdir()
    imagem = EPKG_IMAGEM.read_text().strip()
    fpm = f'{nome}_app'

    def epkg(*args):
        r = run(['docker', 'run', '--rm', '-v', f'{b}/epm:/epm', '-v', f'{b}/data:/data', imagem, 'epkg', *args])
        (b / 'epkg.log').open('a').write(r.stdout + r.stderr)
        if r.returncode:
            raise RuntimeError('epkg ' + args[0] + ' falhou:\n' + (r.stdout + r.stderr)[-1500:])

    epkg('New', '--epm', nome, '--fpms', fpm)
    ini = b / 'epm' / 'input' / 'ebkepm'
    c = configparser.RawConfigParser()
    c.optionxform = str
    c.read(ini)
    for s in c.sections():
        c.set(s, 'version', versao)
        c.set(s, 'vendor', 'POPULOS')
        c.set(s, 'copyright', 'Conversor Unicon POPULOS (programa de terceiros)')
        if s == 'EPM':
            c.set(s, 'category', 'Application')
            c.set(s, 'summary', resumo[:80] or nome)
            c.set(s, 'description', re.sub(r'\s+', ' ', descricao or resumo or nome)[:900])
        else:
            c.set(s, 'installoption', '2')
    with open(ini, 'w') as f:
        c.write(f, space_around_delimiters=False)
    entrada = b / 'epm' / 'input' / fpm
    shutil.rmtree(entrada, ignore_errors=True)
    shutil.copytree(raiz, entrada, symlinks=True)
    execs = []
    for p in entrada.rglob('*'):
        if p.is_file() and not p.is_symlink() and os.access(p, os.X_OK):
            execs.append('%root%/' + str(p.relative_to(entrada)))
    elux = b / 'epm' / 'elux'
    elux.mkdir(parents=True, exist_ok=True)
    if execs:
        linhas = []
        for i in range(0, len(execs), 40):
            linhas.append('chmod 0755 ' + ' '.join(execs[i:i + 40]))
        (elux / f'{fpm}.postCommands').write_text('\n'.join(linhas) + '\n')
    (elux / f'{fpm}.postInst').write_text('#!/bin/bash\nsystemctl daemon-reload >/dev/null 2>&1\ntrue\n')
    log('epkg Build...')
    epkg('Build', '--container', 'elux7', '--releaseType', 'test', '--skipSign', '--log')
    saida = trabalho / 'saida'
    shutil.rmtree(saida, ignore_errors=True)
    saida.mkdir()
    out = b / 'epm' / 'output' / 'container'
    epm_f = next(out.rglob('*.epm'))
    fpm_f = next(out.rglob('*.fpm'))
    shutil.copy2(epm_f, saida / epm_f.name)
    shutil.copy2(fpm_f, saida / fpm_f.name)
    z = saida / f'{nome}-{versao}.zip'
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.write(saida / epm_f.name, epm_f.name)
        zf.write(saida / fpm_f.name, fpm_f.name)
    log(f'pacote pronto: {epm_f.name}, {fpm_f.name}')
    shutil.rmtree(entrada, ignore_errors=True)
    return epm_f.name, fpm_f.name, z.name
