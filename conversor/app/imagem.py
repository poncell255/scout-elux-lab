"""Cria imagens (IDF) no ELIAS a partir do SDK, sem rodar script no Windows.

Mesma lógica de C:\\ScoutSetup\\scripts\\imagem-derivada.ps1 + montar-idf.ps1 (a imagem nova é a imagem de origem
+ os pacotes pedidos, com as dependências resolvidas) e de reparar-idfs.ps1 (importar pacote no ELIAS faz as imagens
existentes darem 404; elas são remontadas com a mesma seleção e regravadas no mesmo registro).
O serviço roda no WSL e o PowerShell do Windows não é alcançável de um serviço systemd, por isso a reescrita em Python.
"""
import json
import re
import time
from pathlib import Path

import requests

DIAG = Path('/mnt/c/ScoutSetup/diag')
CREDENCIAIS = Path('/mnt/c/ScoutSetup/credenciais.txt')
ELIAS = 'http://10.5.0.166/ELIAS'
API = ELIAS + '/api/UC_RP6_X64/v1.0'
LIMITE_MB = 3700


def _json(p):
    return json.loads(Path(p).read_text(encoding='utf-8-sig'))


def _gravar(p, dados):
    tmp = Path(str(p) + '.tmp')
    tmp.write_text(json.dumps(dados, ensure_ascii=False, indent=1), encoding='utf-8')
    tmp.replace(p)


def _lista(x):
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def _chave_versao(v):
    return [int(p) for p in re.sub(r'[^0-9.]', '', str(v)).strip('.').split('.') if p] or [0]


class Elias:
    def __init__(self, log):
        self.log = log
        self.s = requests.Session()
        linha = next((l for l in CREDENCIAIS.read_text(encoding='utf-8-sig', errors='replace').splitlines()
                      if l.startswith('ELIAS 18 (web)')), None)
        if not linha or ' / ' not in linha:
            raise RuntimeError('Rótulo "ELIAS 18 (web)" não encontrado em credenciais.txt')
        r = self.s.post(API + '/authenticate/', json={'user': 'admin', 'domain': '', 'password': linha.split(' / ', 1)[1].strip()}, timeout=60)
        if r.status_code >= 400:
            raise RuntimeError(f'Login no ELIAS falhou (HTTP {r.status_code})')

    def get(self, caminho):
        r = self.s.get(f'{API}/{caminho}', timeout=120)
        r.raise_for_status()
        return r.json()

    def atualizar_catalogo(self):
        # Pacotes importados pela tela do ELIAS só aparecem aqui depois de recarregar o cache local
        for n in ('epms', 'fpms'):
            _gravar(DIAG / f'elias-{n}.json', self.get(n))
        self.log('catálogo do ELIAS atualizado')

    def idfs(self):
        return _lista(self.get('idfs'))

    def publicar(self, idf):
        r = self.s.post(API + '/idfs', json={'idf': idf}, timeout=600)
        if r.status_code >= 400:
            raise RuntimeError(f'ELIAS recusou a imagem (HTTP {r.status_code}): {r.text[:400]}')
        return r.json()

    def regravar(self, _id, idf):
        r = self.s.put(f'{API}/idf/{_id}', json={'idf': idf, 'silent': True, 'overwrite': True}, timeout=600)
        if r.status_code >= 400:
            raise RuntimeError(f'ELIAS recusou a regravação (HTTP {r.status_code}): {r.text[:400]}')
        return r.json()


def baixa(versao):
    try:
        return requests.get(f'{ELIAS}/UC_RP6_X64/populos-elux7-{versao}.idf', timeout=30).status_code
    except requests.RequestException:
        return 0


def proxima_versao():
    nums = [int(m.group(1)) for p in DIAG.glob('idf-populos-v*.json') for m in [re.match(r'idf-populos-v(\d+)$', p.stem)] if m]
    return f'v{max(nums + [0]) + 1}'


def montar(nome, add_epms, add_fpms):
    """Porta de montar-idf.ps1: imagem oficial migration-system + pacotes extras, resolvendo dependências."""
    epms = _lista(_json(DIAG / 'elias-epms.json'))
    fpms = _lista(_json(DIAG / 'elias-fpms.json'))
    base = next(i for i in _lista(_json(DIAG / 'elias-idfs.json')) if str(i.get('name', '')).startswith('migration-system'))
    epm_id = {e['id']: e for e in epms}
    fpm_id = {f['id']: f for f in fpms}

    def epm_do_fpm(fid):
        return next((e['id'] for e in epms if fid in _lista(e.get('fpms'))), None)

    prov = {}
    for e in epms:
        for c in [e['name']] + [p for p in _lista(e.get('provideNames')) if p]:
            prov.setdefault(c, []).append(('epm', e['id']))
    for f in fpms:
        caps = [f['name']] + [p for p in _lista(f.get('provideNames')) if p] + [x for x in _lista(f.get('filenames')) if x in ('/bin/sh', '/bin/bash')]
        for c in caps:
            prov.setdefault(c, []).append(('fpm', f['id']))

    sel_epm, sel_fpm, motivo, nao = {}, set(), {}, {}
    for e in _lista(base.get('epms')):
        sel_epm[e['id']] = True
        sel_fpm.update(f['id'] for f in _lista(e.get('fpms')) if f.get('selected'))

    def sel_e(eid, why):
        if eid not in sel_epm:
            sel_epm[eid] = True
            motivo[eid] = why
            for fid in _lista(epm_id[eid].get('fpms')):
                f = fpm_id.get(fid)
                if f and (f.get('isMandatory') or f.get('isPreselected')):
                    sel_fpm.add(fid)

    for n in add_epms:
        cand = sorted((e for e in epms if e['name'] == n), key=lambda e: _chave_versao(e.get('version')), reverse=True)
        if not cand:
            raise RuntimeError(f'EPM não encontrado no ELIAS: {n}')
        sel_e(cand[0]['id'], 'pedido')
    for n in add_fpms:
        cand = sorted((f for f in fpms if f['name'] == n), key=lambda f: _chave_versao(f.get('version')), reverse=True)
        if not cand:
            raise RuntimeError(f'FPM não encontrado no ELIAS: {n}')
        sel_fpm.add(cand[0]['id'])
        motivo[cand[0]['id']] = 'pedido'
        eid = epm_do_fpm(cand[0]['id'])
        if eid:
            sel_e(eid, f'contém {n}')

    for _ in range(30):
        mudou = False
        caps = set()
        for eid in sel_epm:
            e = epm_id[eid]
            caps.add(e['name'])
            caps.update(p for p in _lista(e.get('provideNames')) if p)
        for fid in list(sel_fpm):
            f = fpm_id.get(fid)
            if not f:
                continue
            caps.add(f['name'])
            caps.update(p for p in _lista(f.get('provideNames')) if p)
            caps.update(x for x in _lista(f.get('filenames')) if x in ('/bin/sh', '/bin/bash'))
        reqs = [(r, eid) for eid in sel_epm for r in _lista(epm_id[eid].get('requireNames')) if r]
        reqs += [(r, fid) for fid in list(sel_fpm) if fpm_id.get(fid) for r in _lista(fpm_id[fid].get('requireNames')) if r]
        for cap, quem in reqs:
            if cap in caps or cap.startswith('rpmlib('):
                continue
            cands = prov.get(cap)
            if not cands:
                nao[cap] = quem
                continue
            c = next((x for x in cands if x[0] == 'fpm' and fpm_id[x[1]].get('isMandatory')), cands[0])
            if c[0] == 'epm':
                sel_e(c[1], f'requer {cap} ({quem})')
            else:
                sel_fpm.add(c[1])
                motivo[c[1]] = f'requer {cap} ({quem})'
                eid = epm_do_fpm(c[1])
                if eid:
                    sel_e(eid, f'contém {c[1]}')
            caps.add(cap)
            mudou = True
        if not mudou:
            break

    lista_epm, pacotes, tam = [], [], 0
    base_epm = {e['id']: e for e in _lista(base.get('epms'))}
    for eid in sel_epm:
        e = epm_id[eid]
        pacotes.append(eid)
        bfs = {f['id']: f for f in _lista(base_epm.get(eid, {}).get('fpms'))}
        fl = []
        for fid in _lista(e.get('fpms')):
            f = fpm_id.get(fid)
            if not f:
                continue
            s = fid in sel_fpm
            if s:
                pacotes.append(fid)
                tam += int(f.get('packageSize') or 0)
            bf = bfs.get(fid)
            fl.append({'id': fid, 'available': True, 'selected': s, 'summary': f.get('summary'), 'name': f['name'], 'version': f.get('version'),
                       'release': _lista(f.get('release')), 'size': int(f.get('packageSize') or 0),
                       'isUserSelected': bool(bf.get('isUserSelected')) if bf else (s and not f.get('isMandatory')),
                       'isMandatory': bool(f.get('isMandatory')), 'isPreselected': bool(f.get('isPreselected'))})
        lista_epm.append({'id': eid, 'copyright': e.get('copyright'), 'version': e.get('version'), 'name': e['name'], 'available': True,
                          'isUserSelected': True, 'summary': e.get('summary'), 'release': _lista(e.get('release')), 'fpms': fl})
    idf = {'name': nome, 'version': base.get('version'), 'author': 'POPULOS', 'container': base.get('container'), 'copyright': base.get('copyright'),
           'description': f'{nome}.idf', 'isTemplate': False, 'selfContained': base.get('selfContained'), 'legacyIDF': False,
           'conflicted': False, 'hasMissing': False, 'conflicts': [], 'imageSize': tam, 'packageList': pacotes, 'epms': lista_epm}
    return idf, motivo, nao


def selecao_derivada(de, mais_epms=(), mais_fpms=(), menos_epms=()):
    """Porta de imagem-derivada.ps1: EPMs e FPMs opcionais escolhidos na imagem de origem + extras."""
    old = _json(DIAG / f'idf-populos-{de}.json')
    base = next(i for i in _lista(_json(DIAG / 'elias-idfs.json')) if str(i.get('name', '')).startswith('migration-system'))
    base_ids = {e['id'] for e in _lista(base.get('epms'))}
    epms = [e['name'] for e in _lista(old.get('epms')) if e['id'] not in base_ids and e['name'] not in menos_epms] + list(mais_epms)
    fpms = [f['name'] for e in _lista(old.get('epms')) if e['name'] not in menos_epms for f in _lista(e.get('fpms'))
            if f.get('selected') and not f.get('isMandatory') and not f.get('isPreselected')] + list(mais_fpms)
    return list(dict.fromkeys(epms)), list(dict.fromkeys(fpms))


def _sel(idf):
    return {e['id'] for e in _lista(idf.get('epms'))} | {f['id'] for e in _lista(idf.get('epms')) for f in _lista(e.get('fpms')) if f.get('selected')}


def criar(de, epm, fpms_extra, log, forcar=False, reparar=True):
    el = Elias(log)
    el.atualizar_catalogo()
    resultado = {'reparadas': [], 'reparo_falhou': []}
    if reparar:
        resultado.update(reparar_em_uso(el, log))
    versao = proxima_versao()
    nome = f'populos-elux7-{versao}'
    epms, fpms = selecao_derivada(de, [epm], fpms_extra)
    idf, motivo, nao = montar(nome, epms, fpms)
    mb = round(idf['imageSize'] / 1048576)
    log(f'{nome}: {len(idf["epms"])} EPMs, {mb} MB (de {de} + {epm})')
    if mb > LIMITE_MB and not forcar:
        raise RuntimeError(f'A imagem ficaria com {mb} MB, acima do limite de {LIMITE_MB} MB (eLux em dual-boot/pendrive, como o Notebook-Wagner). '
                           'Nada foi criado. Tire pacotes da imagem de origem ou marque "criar mesmo acima do limite".')
    _gravar(DIAG / f'idf-populos-{versao}.json', idf)
    agora = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime())
    s = el.publicar(dict(idf, id=f'{nome}.idf', created=agora, modified=agora))
    resultado.update(imagem=versao, nome=f'{nome}.idf', de=de, mb=round((s.get('imageSize') or idf['imageSize']) / 1048576),
                     conflito=bool(s.get('conflicted')), faltando=bool(s.get('hasMissing')), download=baixa(versao),
                     nao_resolvidos=sorted(nao)[:20],
                     adicionados=sorted(_sel(idf) - _sel(_json(DIAG / f'idf-populos-{de}.json')))[:60])
    log(f'ELIAS: {nome}.idf conflito={resultado["conflito"]} faltando={resultado["faltando"]} download={resultado["download"]}')
    return resultado


def reparar_em_uso(el, log):
    """Porta de reparar-idfs.ps1 para as imagens que alguma OU usa (diag/imagens-uso.json)."""
    try:
        uso = list((_json(DIAG / 'imagens-uso.json').get('imagens') or {}).keys())
    except (OSError, ValueError):
        uso = []
    feitas, falhas = [], []
    registros = {i.get('id'): i for i in el.idfs()}
    for v in uso:
        if baixa(v) == 200 or not (DIAG / f'idf-populos-{v}.json').exists():
            continue
        antes = _json(DIAG / f'idf-populos-{v}.json')
        bak = Path('/mnt/c/ScoutSetup/backup') / f'idf-populos-{v}-antes-{time.strftime("%Y%m%d-%H%M%S")}.json'
        bak.write_bytes((DIAG / f'idf-populos-{v}.json').read_bytes())
        epms, fpms = selecao_derivada(v)
        novo, _, _ = montar(f'populos-elux7-{v}', epms, fpms)
        if _sel(antes) != _sel(novo):
            falhas.append(f'{v}: a seleção de pacotes mudaria; não regravada')
            continue
        cur = registros.get(f'populos-elux7-{v}.idf')
        if not cur:
            falhas.append(f'{v}: registro não encontrado no ELIAS')
            continue
        agora = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime())
        el.regravar(cur['_id'], dict(novo, id=f'populos-elux7-{v}.idf', _id=cur['_id'], created=cur.get('created'), modified=agora))
        _gravar(DIAG / f'idf-populos-{v}.json', novo)
        st = baixa(v)
        (feitas if st == 200 else falhas).append(v if st == 200 else f'{v}: download {st} depois de regravar')
        log(f'reparo {v}: download {st}')
    return {'reparadas': feitas, 'reparo_falhou': falhas}
