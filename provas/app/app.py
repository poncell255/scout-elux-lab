"""Site de provas POPULOS: cadastro de alunos com digital, prova com tempo e nota.

Partes:
  /provas/admin        cadastro de alunos, captura da digital e resultados (login Basic: admin + PROVAS_ADMIN)
  /provas/api/...      usado pelo eLux da OU "Provas" (cabeçalho X-Provas-Chave = PROVAS_CHAVE)
  /provas/p/<token>    a prova do aluno (aberta pelo eLux em modo quiosque)
"""
import io, json, os, random, secrets, sqlite3, subprocess, tarfile, threading, time
from functools import wraps
from flask import Flask, Response, abort, g, jsonify, request, send_from_directory

BASE = os.path.dirname(os.path.abspath(__file__))
DADOS = os.environ.get('PROVAS_DADOS', '/data')
DIGITAIS = os.path.join(DADOS, 'digitais')
CADASTRAR = os.environ.get('PROVAS_CADASTRAR', '/usr/local/bin/cadastrar-digital')
ADMIN_SENHA = os.environ['PROVAS_ADMIN']
CHAVE = os.environ['PROVAS_CHAVE']
os.makedirs(DIGITAIS, exist_ok=True)

PROVAS = {}
for arq in sorted(os.listdir(os.path.join(BASE, 'questoes'))):
    with open(os.path.join(BASE, 'questoes', arq), encoding='utf-8') as f:
        p = json.load(f)
    PROVAS[p['codigo']] = p

app = Flask(__name__, static_folder=None)


# ---------- banco ----------
def db():
    if 'db' not in g:
        g.db = sqlite3.connect(os.path.join(DADOS, 'provas.db'), timeout=10)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def fechar_db(_):
    d = g.pop('db', None)
    if d: d.close()


def criar_banco():
    c = sqlite3.connect(os.path.join(DADOS, 'provas.db'))
    c.executescript('''
    CREATE TABLE IF NOT EXISTS alunos (
        id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, prova TEXT NOT NULL,
        digital INTEGER NOT NULL DEFAULT 0, criado REAL NOT NULL);
    CREATE TABLE IF NOT EXISTS sessoes (
        token TEXT PRIMARY KEY, aluno_id INTEGER NOT NULL, prova TEXT NOT NULL, dispositivo TEXT,
        criada REAL NOT NULL, inicio REAL, fim REAL, ordem TEXT NOT NULL, respostas TEXT NOT NULL DEFAULT '{}',
        marcadas TEXT NOT NULL DEFAULT '[]', acertos INTEGER, total INTEGER, nota REAL, aprovado INTEGER,
        por_dominio TEXT, saiu INTEGER NOT NULL DEFAULT 0);
    ''')
    c.commit(); c.close()


criar_banco()


def agora():
    return time.time()


# ---------- autenticação ----------
def exige_admin(f):
    @wraps(f)
    def w(*a, **k):
        au = request.authorization
        if not au or au.username != 'admin' or not secrets.compare_digest(au.password or '', ADMIN_SENHA):
            return Response('Acesso restrito', 401, {'WWW-Authenticate': 'Basic realm="Provas POPULOS"'})
        return f(*a, **k)
    return w


def exige_chave(f):
    @wraps(f)
    def w(*a, **k):
        if not secrets.compare_digest(request.headers.get('X-Provas-Chave', ''), CHAVE):
            abort(403)
        return f(*a, **k)
    return w


# ---------- prova: montagem e correção ----------
def montar_ordem(prova):
    """Ordem embaralhada das questões e das opções de cada uma (fixa por sessão)."""
    qs = PROVAS[prova]['questoes']
    idx = list(range(len(qs))); random.shuffle(idx)
    ordem = []
    for i in idx:
        ops = list(range(len(qs[i]['o']))); random.shuffle(ops)
        ordem.append({'q': i, 'o': ops})
    return ordem


def corrigir(s):
    p = PROVAS[s['prova']]
    ordem = json.loads(s['ordem']); resp = json.loads(s['respostas'])
    acertos = 0; dom = {}
    for n, item in enumerate(ordem):
        q = p['questoes'][item['q']]
        marcadas = sorted(item['o'][x] for x in resp.get(str(n), []) if 0 <= x < len(item['o']))
        ok = marcadas == sorted(q['c'])
        acertos += ok
        d = dom.setdefault(q['d'], [0, 0]); d[0] += ok; d[1] += 1
    total = len(ordem)
    nota = round(100.0 * acertos / total, 1) if total else 0
    return acertos, total, nota, nota >= p['aprovacao'], dom


def finalizar(token):
    d = db(); s = d.execute('SELECT * FROM sessoes WHERE token=?', (token,)).fetchone()
    if not s or s['fim']: return
    acertos, total, nota, aprovado, dom = corrigir(s)
    fim = min(agora(), (s['inicio'] or agora()) + PROVAS[s['prova']]['minutos'] * 60)
    d.execute('UPDATE sessoes SET fim=?, acertos=?, total=?, nota=?, aprovado=?, por_dominio=? WHERE token=?',
              (fim, acertos, total, nota, int(aprovado), json.dumps(dom, ensure_ascii=False), token))
    d.commit()


def sessao(token):
    s = db().execute('SELECT * FROM sessoes WHERE token=?', (token,)).fetchone()
    if not s: abort(404)
    # tempo esgotado: corrige sozinho
    if s['inicio'] and not s['fim'] and agora() >= s['inicio'] + PROVAS[s['prova']]['minutos'] * 60:
        finalizar(token)
        s = db().execute('SELECT * FROM sessoes WHERE token=?', (token,)).fetchone()
    return s


def resultado_json(s):
    p = PROVAS[s['prova']]
    return {'acertos': s['acertos'], 'total': s['total'], 'nota': s['nota'], 'aprovado': bool(s['aprovado']),
            'aprovacao': p['aprovacao'], 'dominios': json.loads(s['por_dominio'] or '{}'),
            'inicio': s['inicio'], 'fim': s['fim']}


# ---------- páginas ----------
@app.get('/provas/')
def inicio():
    return send_from_directory(os.path.join(BASE, 'web'), 'inicio.html')


@app.get('/provas/static/<path:arq>')
def estaticos(arq):
    return send_from_directory(os.path.join(BASE, 'web', 'static'), arq)


@app.get('/provas/admin')
@exige_admin
def admin():
    return send_from_directory(os.path.join(BASE, 'web'), 'admin.html')


@app.get('/provas/p/<token>')
def pagina_prova(token):
    sessao(token)
    return send_from_directory(os.path.join(BASE, 'web'), 'prova.html')


# ---------- API do administrador ----------
@app.get('/provas/admin/api/alunos')
@exige_admin
def listar_alunos():
    d = db(); out = []
    for a in d.execute('SELECT * FROM alunos ORDER BY id DESC'):
        s = d.execute('SELECT * FROM sessoes WHERE aluno_id=? ORDER BY criada DESC LIMIT 1', (a['id'],)).fetchone()
        estado = 'aguardando'
        if s:
            estado = 'finalizada' if s['fim'] else ('em andamento' if s['inicio'] else 'aberta')
        out.append({'id': a['id'], 'nome': a['nome'], 'prova': a['prova'], 'titulo_prova': PROVAS[a['prova']]['titulo'],
                    'digital': bool(a['digital']), 'estado': estado,
                    'resultado': resultado_json(s) if s and s['fim'] else None,
                    'dispositivo': s['dispositivo'] if s else None})
    return jsonify({'alunos': out, 'provas': [{'codigo': k, 'titulo': v['titulo'], 'questoes': len(v['questoes'])} for k, v in PROVAS.items()]})


@app.post('/provas/admin/api/alunos')
@exige_admin
def novo_aluno():
    j = request.get_json(force=True)
    nome = (j.get('nome') or '').strip()[:80]; prova = j.get('prova')
    if not nome or prova not in PROVAS: return jsonify({'erro': 'Informe o nome e a prova.'}), 400
    d = db(); cur = d.execute('INSERT INTO alunos (nome, prova, criado) VALUES (?,?,?)', (nome, prova, agora())); d.commit()
    return jsonify({'id': cur.lastrowid})


@app.post('/provas/admin/api/alunos/<int:aid>/prova')
@exige_admin
def trocar_prova(aid):
    prova = request.get_json(force=True).get('prova')
    if prova not in PROVAS: abort(400)
    d = db(); d.execute('UPDATE alunos SET prova=? WHERE id=?', (prova, aid)); d.commit()
    return jsonify({'ok': True})


@app.post('/provas/admin/api/alunos/<int:aid>/liberar')
@exige_admin
def liberar_de_novo(aid):
    """Permite refazer: apaga as sessões do aluno (os resultados antigos se perdem)."""
    d = db(); d.execute('DELETE FROM sessoes WHERE aluno_id=?', (aid,)); d.commit()
    return jsonify({'ok': True})


@app.post('/provas/admin/api/alunos/<int:aid>/excluir')
@exige_admin
def excluir_aluno(aid):
    d = db(); d.execute('DELETE FROM sessoes WHERE aluno_id=?', (aid,)); d.execute('DELETE FROM alunos WHERE id=?', (aid,)); d.commit()
    try: os.remove(os.path.join(DIGITAIS, f'{aid}.fpr'))
    except FileNotFoundError: pass
    return jsonify({'ok': True})


# captura da digital: um cadastro por vez (o leitor é um só)
CAPTURA = {'ativo': False}
TRAVA = threading.Lock()


def capturar(aid, nome):
    destino = os.path.join(DIGITAIS, f'{aid}.fpr'); tmp = destino + '.novo'
    CAPTURA.update({'ativo': True, 'aluno': aid, 'nome': nome, 'feitas': 0, 'total': 0, 'mensagem': 'Abrindo o leitor...', 'ok': False, 'erro': None})
    try:
        pr = subprocess.Popen([CADASTRAR, tmp, str(aid), nome], stdout=subprocess.PIPE, text=True)
        CAPTURA['pid'] = pr.pid
        for linha in pr.stdout:
            cmd, _, resto = linha.strip().partition(' ')
            if cmd == 'LEITOR': CAPTURA['mensagem'] = 'Coloque o dedo indicador direito no leitor.'
            elif cmd == 'ETAPAS': CAPTURA['total'] = int(resto)
            elif cmd == 'LEITURA':
                f, t = resto.split(); CAPTURA.update({'feitas': int(f), 'total': int(t)})
                CAPTURA['mensagem'] = f'Leitura {f} de {t}. Levante e coloque o mesmo dedo de novo.'
            elif cmd == 'REPETIR': CAPTURA['mensagem'] = f'Leitura não aproveitada ({resto}). Coloque o dedo de novo.'
            elif cmd == 'OK':
                os.replace(tmp, destino)
                c = sqlite3.connect(os.path.join(DADOS, 'provas.db')); c.execute('UPDATE alunos SET digital=1 WHERE id=?', (aid,)); c.commit(); c.close()
                CAPTURA.update({'ok': True, 'mensagem': 'Digital cadastrada.'})
            elif cmd == 'ERRO': CAPTURA.update({'erro': resto, 'mensagem': resto})
        pr.wait()
        if not CAPTURA['ok'] and not CAPTURA['erro']:
            CAPTURA.update({'erro': 'cadastro interrompido', 'mensagem': 'Cadastro interrompido.'})
    except Exception as e:
        CAPTURA.update({'erro': str(e), 'mensagem': f'Erro: {e}'})
    finally:
        CAPTURA['ativo'] = False


@app.post('/provas/admin/api/alunos/<int:aid>/digital')
@exige_admin
def iniciar_captura(aid):
    a = db().execute('SELECT * FROM alunos WHERE id=?', (aid,)).fetchone()
    if not a: abort(404)
    with TRAVA:
        if CAPTURA.get('ativo'): return jsonify({'erro': 'Já existe um cadastro em andamento.'}), 409
        CAPTURA['ativo'] = True
    threading.Thread(target=capturar, args=(aid, a['nome']), daemon=True).start()
    return jsonify({'ok': True})


@app.post('/provas/admin/api/captura/cancelar')
@exige_admin
def cancelar_captura():
    pid = CAPTURA.get('pid')
    if CAPTURA.get('ativo') and pid:
        try: os.kill(pid, 15)
        except ProcessLookupError: pass
    return jsonify({'ok': True})


@app.get('/provas/admin/api/captura')
@exige_admin
def estado_captura():
    return jsonify({k: v for k, v in CAPTURA.items() if k != 'pid'})


# ---------- API do eLux ----------
@app.get('/provas/api/galeria')
@exige_chave
def galeria():
    """Digitais dos alunos com prova pendente (sem prova finalizada), em .tar.gz: <id>.fpr."""
    d = db(); buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w:gz') as tar:
        for a in d.execute('SELECT id FROM alunos WHERE digital=1'):
            fim = d.execute('SELECT 1 FROM sessoes WHERE aluno_id=? AND fim IS NOT NULL', (a['id'],)).fetchone()
            arq = os.path.join(DIGITAIS, f"{a['id']}.fpr")
            if not fim and os.path.exists(arq): tar.add(arq, arcname=f"{a['id']}.fpr")
    return Response(buf.getvalue(), mimetype='application/gzip')


@app.post('/provas/api/sessao')
@exige_chave
def abrir_sessao():
    """O eLux identificou o aluno pela digital: devolve o token da prova (retoma se já estiver aberta)."""
    try: aid = int(request.form.get('aluno', ''))
    except ValueError: abort(400)
    disp = (request.form.get('dispositivo') or '')[:60]
    d = db(); a = d.execute('SELECT * FROM alunos WHERE id=?', (aid,)).fetchone()
    if not a: abort(404)
    s = d.execute('SELECT * FROM sessoes WHERE aluno_id=? ORDER BY criada DESC LIMIT 1', (aid,)).fetchone()
    if s and s['prova'] == a['prova']:
        # retoma a prova em andamento; se já terminou, mostra o resultado de novo (não abre outra prova)
        d.execute('UPDATE sessoes SET dispositivo=?, saiu=0 WHERE token=?', (disp, s['token'])); d.commit()
        return Response(s['token'], mimetype='text/plain')
    token = secrets.token_hex(16)
    d.execute('INSERT INTO sessoes (token, aluno_id, prova, dispositivo, criada, ordem) VALUES (?,?,?,?,?,?)',
              (token, aid, a['prova'], disp, agora(), json.dumps(montar_ordem(a['prova']))))
    d.commit()
    return Response(token, mimetype='text/plain')


@app.get('/provas/api/sessao/<token>/estado')
@exige_chave
def estado_sessao(token):
    s = sessao(token)
    e = 'sair' if s['saiu'] else 'finalizada' if s['fim'] else 'andamento' if s['inicio'] else 'aberta'
    return Response(e, mimetype='text/plain')


# ---------- API da prova (página do aluno) ----------
@app.get('/provas/p/<token>/dados')
def dados_prova(token):
    s = sessao(token); p = PROVAS[s['prova']]
    a = db().execute('SELECT nome FROM alunos WHERE id=?', (s['aluno_id'],)).fetchone()
    out = {'aluno': a['nome'] if a else '?', 'titulo': p['titulo'], 'sigla': p['sigla'], 'minutos': p['minutos'],
           'aprovacao': p['aprovacao'], 'total': len(p['questoes']), 'agora': agora()}
    if s['fim']:
        out['estado'] = 'finalizada'; out['resultado'] = resultado_json(s); return jsonify(out)
    if not s['inicio']:
        out['estado'] = 'aberta'; return jsonify(out)
    ordem = json.loads(s['ordem'])
    out.update({'estado': 'andamento', 'termina': s['inicio'] + p['minutos'] * 60,
                'respostas': json.loads(s['respostas']), 'marcadas': json.loads(s['marcadas']),
                'questoes': [{'d': p['questoes'][it['q']]['d'], 'q': p['questoes'][it['q']]['q'],
                              'o': [p['questoes'][it['q']]['o'][x] for x in it['o']],
                              'escolher': len(p['questoes'][it['q']]['c'])} for it in ordem]})
    return jsonify(out)


@app.post('/provas/p/<token>/iniciar')
def iniciar_prova(token):
    s = sessao(token)
    if not s['inicio'] and not s['fim']:
        d = db(); d.execute('UPDATE sessoes SET inicio=? WHERE token=?', (agora(), token)); d.commit()
    return jsonify({'ok': True})


@app.post('/provas/p/<token>/responder')
def responder(token):
    s = sessao(token)
    if s['fim'] or not s['inicio']: return jsonify({'erro': 'prova encerrada'}), 409
    j = request.get_json(force=True); n = int(j.get('n', -1))
    if not 0 <= n < len(json.loads(s['ordem'])): abort(400)
    resp = json.loads(s['respostas']); marc = set(json.loads(s['marcadas']))
    if 'r' in j: resp[str(n)] = [int(x) for x in j['r']][:6]
    if 'marcada' in j: (marc.add if j['marcada'] else marc.discard)(n)
    d = db(); d.execute('UPDATE sessoes SET respostas=?, marcadas=? WHERE token=?', (json.dumps(resp), json.dumps(sorted(marc)), token)); d.commit()
    return jsonify({'ok': True})


@app.post('/provas/p/<token>/finalizar')
def finalizar_prova(token):
    s = sessao(token)
    if s['inicio'] and not s['fim']: finalizar(token)
    return jsonify(resultado_json(sessao(token)))


@app.post('/provas/p/<token>/sair')
def sair_prova(token):
    """Botão "Encerrar" na tela de resultado: avisa o eLux para fechar o navegador e voltar à digital."""
    s = sessao(token)
    if s['fim']:
        d = db(); d.execute('UPDATE sessoes SET saiu=1 WHERE token=?', (token,)); d.commit()
    return jsonify({'ok': True})


if __name__ == '__main__':
    from waitress import serve
    serve(app, host='0.0.0.0', port=3100, threads=8)
