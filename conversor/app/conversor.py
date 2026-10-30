"""Conversor Unicon (POPULOS): interface web para transformar programas Ubuntu em pacotes eLux/UniconOS (EPM/FPM).

Roda no WSL (Ubuntu 22.04, mesma base do eLux 7) atrás do IIS em /conversor. Um trabalho por vez numa fila:
upload -> análise (extração + bibliotecas x catálogo ELIAS x imagem) -> conversão (libs do Ubuntu, serviços, epkg) -> download.
"""
import hashlib
import hmac
import json
import os
import queue
import re
import secrets
import shutil
import threading
import time
import traceback
import uuid
from functools import wraps
from pathlib import Path

from flask import Flask, abort, jsonify, redirect, request, send_file, send_from_directory, session

import analise
import empacotar
import imagem

BASE = Path(os.environ.get('CONVERSOR_DADOS', '/root/conversor'))
JOBS = BASE / 'trabalhos'
WEB = Path(__file__).resolve().parent / 'web'
PREFIXO = '/conversor'
MAX_MB = int(os.environ.get('CONVERSOR_MAX_MB', '2000'))
DIAS_GUARDAR = 7

JOBS.mkdir(parents=True, exist_ok=True)
segredo = BASE / 'segredo-sessao'
if not segredo.exists():
    segredo.write_text(secrets.token_hex(32))
    segredo.chmod(0o600)

app = Flask(__name__, static_folder=None)
app.secret_key = segredo.read_text().strip()
app.config.update(MAX_CONTENT_LENGTH=MAX_MB * 1048576, SESSION_COOKIE_NAME='conversor_sessao',
                  SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE='Strict', SESSION_COOKIE_PATH=PREFIXO)
cat = analise.Catalogo()
fila = queue.Queue()
trava = threading.Lock()


# ---------------------------------------------------------------- trabalhos
def jdir(jid):
    if not re.fullmatch(r'[0-9a-f]{12}', jid or ''):
        abort(404)
    d = JOBS / jid
    if not d.is_dir():
        abort(404)
    return d


def ler(jid):
    return json.loads((JOBS / jid / 'trabalho.json').read_text())


def gravar(jid, dados):
    with trava:
        p = JOBS / jid / 'trabalho.json'
        atual = json.loads(p.read_text()) if p.exists() else {}
        atual.update(dados)
        tmp = p.with_suffix('.tmp')
        tmp.write_text(json.dumps(atual, ensure_ascii=False, indent=1))
        tmp.replace(p)
        return atual


def registrar(jid):
    def log(msg):
        with open(JOBS / jid / 'log.txt', 'a') as f:
            f.write(time.strftime('%H:%M:%S ') + msg + '\n')
    return log


def fazer_analise(jid):
    t = ler(jid)
    d = JOBS / jid
    log = registrar(jid)
    entrada = d / 'entrada' / t['arquivo']
    raiz = d / 'raiz'
    shutil.rmtree(raiz, ignore_errors=True)
    for x in ('controle', 'arquivo'):
        shutil.rmtree(d / x, ignore_errors=True)
    tipo = analise.tipo_arquivo(entrada)
    gravar(jid, {'tipo': tipo})
    log(f'tipo detectado: {tipo}')
    base_nome = re.sub(r'(\.tar)?\.(deb|appimage|run|tgz|gz|xz|bz2|zip)$', '', t['arquivo'], flags=re.I)
    base_nome = re.sub(r'[_-]v?\d[\w.+~-]*$', '', base_nome) or base_nome
    nome = analise.nome_pacote(t.get('nome_pedido') or base_nome)
    meta = analise.extrair(entrada, tipo, raiz, nome, log)
    if tipo == 'deb' and not t.get('nome_pedido') and meta.get('pacote'):
        nome = analise.nome_pacote(meta['pacote'])
    versao = analise.versao_pacote(meta.get('versao') or (re.search(r'\d+(\.\d+)+', t['arquivo']) or [None])[0] or '1.0.0')
    res = analise.analisar(raiz, cat, t['imagem'], meta, log, t.get('categoria', 'software'))
    gravar(jid, {'estado': 'analisado', 'nome': nome, 'versao': versao, 'meta': meta, 'analise': res,
                 'resumo': (meta.get('descricao') or '').split('\n')[0][:80] or nome})
    log('análise concluída')


def fazer_conversao(jid):
    # Sempre parte de uma árvore recém-extraída (a conversão altera a árvore: libs, RUNPATH, serviços)
    pedido = ler(jid).get('pedido', {})
    if pedido.get('nome'):
        gravar(jid, {'nome_pedido': pedido['nome']})
    fazer_analise(jid)
    upd = {k: pedido[k] for k in ('nome', 'versao', 'resumo') if pedido.get(k)}
    gravar(jid, dict(upd, estado='convertendo'))
    t = ler(jid)
    d = JOBS / jid
    log = registrar(jid)
    raiz = d / 'raiz'
    op = pedido.get('opcoes', {})
    nome, versao = t['nome'], t['versao']
    sel, _ = cat.fpms_da_imagem(t['imagem'])
    feito = {'embutidas': {}, 'nao_achadas': [], 'servicos': [], 'runpath': 0}
    if op.get('sem_docs', True):
        empacotar.remover_docs(raiz)
    if op.get('embutir', True) and t['analise']['faltando']:
        emb, nao, dir_rel = empacotar.embutir_faltantes(raiz, nome, t['analise'], cat, sel, log)
        feito.update(embutidas=emb, nao_achadas=nao)
        if emb:
            feito['runpath'] = empacotar.ajustar_runpath(raiz, dir_rel, log)
    if op.get('servicos', True):
        feito['servicos'] = empacotar.habilitar_unidades(raiz, t['analise'], log)
    gravar(jid, {'estado': 'convertendo', 'feito': feito})
    epm, fpm, z = empacotar.construir(d, raiz, nome, versao, t.get('resumo') or nome,
                                     t.get('meta', {}).get('descricao', ''), log)
    tam = sum(p.stat().st_size for p in (d / 'saida').glob('*.fpm'))
    fpms = t['analise']['fpms_adicionar']
    img = t['imagem']
    novo_nome = 'populos-elux7-v' + str(max([int(re.sub(r'\D', '', i) or 0) for i in cat.imagens()] + [0]) + 1)
    comando = (f"C:\\ScoutSetup\\scripts\\imagem-derivada.ps1 -De {img} -Nome {novo_nome} -MaisEpms {nome}"
               + (f" -MaisFpms {','.join(fpms)}" if fpms else '') + ' -Publicar')
    gravar(jid, {'estado': 'pronto', 'saida': {'epm': epm, 'fpm': fpm, 'zip': z, 'fpm_mb': round(tam / 1048576, 1)},
                 'comando_imagem': comando})
    log('conversão concluída')


def fazer_imagem(jid):
    # Etapa 4: cria a imagem no ELIAS (equivale ao comando imagem-derivada.ps1). Erro aqui não apaga a conversão pronta.
    t = ler(jid)
    log = registrar(jid)
    pedido = t.get('pedido_imagem') or {}
    try:
        imagem.Elias(log).atualizar_catalogo()
        cat.carregar()
        versoes = [e.get('version') for e in imagem._lista(imagem._json(imagem.DIAG / 'elias-epms.json')) if e.get('name') == t['nome']]
        if not versoes:
            raise RuntimeError(f'O pacote {t["nome"]} não está no ELIAS. Importe o .zip desta conversão primeiro.')
        if t['versao'] not in versoes:
            raise RuntimeError(f'No ELIAS há {t["nome"]} {", ".join(sorted(versoes))}, mas esta conversão é a {t["versao"]}. '
                               'Importe o .zip desta conversão (ou converta de novo com outra versão).')
        res = imagem.criar(pedido['de'], t['nome'], t['analise'].get('fpms_adicionar') or [], log,
                           forcar=pedido.get('forcar', False), reparar=pedido.get('reparar', True))
        gravar(jid, {'estado': 'pronto', 'imagem_criada': res, 'imagem_erro': ''})
    except Exception as e:
        log(traceback.format_exc())
        gravar(jid, {'estado': 'pronto', 'imagem_erro': str(e)[:2000]})


def trabalhador():
    while True:
        jid, etapa = fila.get()
        try:
            gravar(jid, {'estado': {'analise': 'analisando', 'imagem': 'criando imagem'}.get(etapa, 'convertendo'), 'erro': ''})
            {'analise': fazer_analise, 'imagem': fazer_imagem}.get(etapa, fazer_conversao)(jid)
        except Exception as e:  # o erro vai para a tela; o traceback fica no log do trabalho
            registrar(jid)(traceback.format_exc())
            gravar(jid, {'estado': 'erro', 'erro': str(e)[:3000], 'etapa_erro': etapa})
        finally:
            fila.task_done()


def limpar_antigos():
    while True:
        lim = time.time() - DIAS_GUARDAR * 86400
        for d in JOBS.iterdir():
            if d.is_dir() and d.stat().st_mtime < lim:
                shutil.rmtree(d, ignore_errors=True)
        time.sleep(3600)


threading.Thread(target=trabalhador, daemon=True).start()
threading.Thread(target=limpar_antigos, daemon=True).start()
for _d in JOBS.iterdir():  # trabalhos interrompidos por reinício do serviço
    try:
        if ler(_d.name).get('estado') in ('na fila', 'analisando', 'convertendo', 'criando imagem'):
            gravar(_d.name, {'estado': 'erro', 'erro': 'Interrompido (serviço reiniciado). Envie de novo ou clique em Analisar.'})
    except Exception:
        pass


# ---------------------------------------------------------------- autenticação
def senha_ok(senha):
    try:
        a = json.loads((BASE / 'admin-auth.json').read_text())
    except OSError:
        return False
    d = hashlib.pbkdf2_hmac('sha256', senha.encode(), bytes.fromhex(a['salt']), int(a['iterations']))
    return hmac.compare_digest(d.hex(), a['digest'])


def exige_login(f):
    @wraps(f)
    def w(*a, **k):
        if not session.get('ok'):
            if request.path.startswith(PREFIXO + '/api/'):
                return jsonify(erro='login necessário'), 401
            return redirect(PREFIXO + '/')
        return f(*a, **k)
    return w


@app.post(PREFIXO + '/api/login')
def login():
    time.sleep(0.5)
    if senha_ok(request.form.get('senha', '')):
        session.clear()
        session['ok'] = True
        return jsonify(ok=True)
    return jsonify(erro='Senha incorreta'), 403


@app.post(PREFIXO + '/api/sair')
def sair():
    session.clear()
    return jsonify(ok=True)


# ---------------------------------------------------------------- páginas e API
@app.get(PREFIXO)
@app.get(PREFIXO + '/')
def inicio():
    return send_from_directory(WEB, 'index.html')


@app.get(PREFIXO + '/static/<path:arq>')
def estatico(arq):
    return send_from_directory(WEB / 'static', arq)


@app.get(PREFIXO + '/api/estado')
def estado():
    cat.carregar()
    info, gerado = cat.info_imagens() if session.get('ok') else ([], '')
    return jsonify(logado=bool(session.get('ok')), imagens=[i['id'] for i in info], info_imagens=info, uso_gerado=gerado,
                   glibc=cat.glibc, kernel=cat.kernel, max_mb=MAX_MB, padrao='v22')


@app.get(PREFIXO + '/api/trabalhos')
@exige_login
def lista():
    res = []
    for d in sorted(JOBS.iterdir(), key=lambda x: x.stat().st_mtime, reverse=True):
        try:
            t = ler(d.name)
        except Exception:
            continue
        item = {k: t.get(k) for k in ('id', 'arquivo', 'estado', 'tipo', 'nome', 'versao', 'imagem', 'criado', 'erro')}
        res.append(dict(item, categoria=t.get('categoria', 'software')))
    return jsonify(res)


@app.post(PREFIXO + '/api/enviar')
@exige_login
def enviar():
    f = request.files.get('arquivo')
    if not f or not f.filename:
        return jsonify(erro='Escolha um arquivo'), 400
    nome_arq = re.sub(r'[^\w.+~-]', '_', os.path.basename(f.filename))[:150]
    imagem = request.form.get('imagem') or 'v22'
    if imagem not in cat.imagens():
        return jsonify(erro='Imagem desconhecida'), 400
    categoria = request.form.get('categoria') or 'software'
    if categoria not in ('software', 'driver'):
        return jsonify(erro='Categoria desconhecida'), 400
    jid = uuid.uuid4().hex[:12]
    d = JOBS / jid
    (d / 'entrada').mkdir(parents=True)
    f.save(d / 'entrada' / nome_arq)
    gravar(jid, {'id': jid, 'arquivo': nome_arq, 'nome_original': f.filename[:200], 'imagem': imagem, 'categoria': categoria,
                 'nome_pedido': (request.form.get('nome') or '').strip()[:40], 'estado': 'na fila',
                 'criado': time.strftime('%Y-%m-%d %H:%M'), 'tamanho_mb': round((d / 'entrada' / nome_arq).stat().st_size / 1048576, 1)})
    fila.put((jid, 'analise'))
    return jsonify(id=jid)


@app.get(PREFIXO + '/api/trabalhos/<jid>')
@exige_login
def detalhe(jid):
    d = jdir(jid)
    t = ler(jid)
    t['log'] = (d / 'log.txt').read_text()[-6000:] if (d / 'log.txt').exists() else ''
    return jsonify(t)


@app.post(PREFIXO + '/api/trabalhos/<jid>/analisar')
@exige_login
def reanalisar(jid):
    jdir(jid)
    dados = request.get_json(silent=True) or {}
    upd = {'estado': 'na fila'}
    if dados.get('imagem') in cat.imagens():
        upd['imagem'] = dados['imagem']
    if dados.get('nome'):
        upd['nome_pedido'] = analise.nome_pacote(dados['nome'])
    gravar(jid, upd)
    fila.put((jid, 'analise'))
    return jsonify(ok=True)


@app.post(PREFIXO + '/api/trabalhos/<jid>/converter')
@exige_login
def converter(jid):
    jdir(jid)
    t = ler(jid)
    if t.get('estado') not in ('analisado', 'pronto', 'erro') or not t.get('analise'):
        return jsonify(erro='Espere a análise terminar'), 409
    dados = request.get_json(silent=True) or {}
    pedido = {'opcoes': {k: bool(dados.get(k, True)) for k in ('embutir', 'servicos', 'sem_docs')}}
    if dados.get('nome'):
        pedido['nome'] = analise.nome_pacote(dados['nome'])
    if dados.get('versao'):
        pedido['versao'] = analise.versao_pacote(dados['versao'])
    if dados.get('resumo'):
        pedido['resumo'] = str(dados['resumo'])[:80]
    gravar(jid, {'pedido': pedido, 'estado': 'na fila', 'saida': None, 'feito': None})
    fila.put((jid, 'conversao'))
    return jsonify(ok=True)


@app.post(PREFIXO + '/api/trabalhos/<jid>/imagem')
@exige_login
def criar_imagem(jid):
    jdir(jid)
    t = ler(jid)
    if t.get('estado') != 'pronto':
        return jsonify(erro='Converta o pacote primeiro'), 409
    dados = request.get_json(silent=True) or {}
    de = dados.get('de') or t.get('imagem')
    if de not in cat.imagens():
        return jsonify(erro='Imagem de origem desconhecida'), 400
    gravar(jid, {'estado': 'na fila', 'imagem_erro': '', 'imagem_criada': None,
                 'pedido_imagem': {'de': de, 'forcar': bool(dados.get('forcar')), 'reparar': bool(dados.get('reparar', True))}})
    fila.put((jid, 'imagem'))
    return jsonify(ok=True)


@app.get(PREFIXO + '/api/trabalhos/<jid>/baixar/<qual>')
@exige_login
def baixar(jid, qual):
    d = jdir(jid)
    t = ler(jid)
    s = t.get('saida') or {}
    if qual == 'relatorio':
        r = {k: t.get(k) for k in ('arquivo', 'tipo', 'nome', 'versao', 'imagem', 'meta', 'analise', 'feito', 'comando_imagem')}
        p = d / 'relatorio.json'
        p.write_text(json.dumps(r, ensure_ascii=False, indent=1))
        return send_file(p, as_attachment=True, download_name=f"{t.get('nome', 'programa')}-relatorio.json")
    if qual == 'log':
        return send_file(d / 'log.txt', as_attachment=True, download_name=f'{jid}-log.txt')
    if qual not in ('zip', 'epm', 'fpm') or not s.get(qual):
        abort(404)
    return send_file(d / 'saida' / s[qual], as_attachment=True, download_name=s[qual])


@app.delete(PREFIXO + '/api/trabalhos/<jid>')
@exige_login
def apagar(jid):
    d = jdir(jid)
    if ler(jid).get('estado') in ('analisando', 'convertendo'):
        return jsonify(erro='Trabalho em andamento'), 409
    shutil.rmtree(d, ignore_errors=True)
    return jsonify(ok=True)


@app.errorhandler(413)
def grande(_):
    return jsonify(erro=f'Arquivo maior que {MAX_MB} MB'), 413


if __name__ == '__main__':
    from waitress import serve
    serve(app, host='0.0.0.0', port=int(os.environ.get('CONVERSOR_PORTA', '3200')), threads=8,
          max_request_body_size=MAX_MB * 1048576)
