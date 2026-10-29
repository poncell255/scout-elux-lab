"""Agência demonstrativa BTG (teste POPULOS). Contas e valores fictícios; biometria local libfprint."""
import hashlib
import hmac
import imghdr
import io
import json
import os
from pathlib import Path
import secrets
import sqlite3
import subprocess
import tarfile
import threading
import time
from datetime import date, datetime, timedelta
from functools import wraps

from flask import Flask, Response, abort, g, jsonify, request, send_from_directory

BASE = Path(__file__).resolve().parent
DATA = Path(os.environ.get('BTG_DADOS', '/data'))
DIGITAIS = DATA / 'digitais'
FOTOS = DATA / 'fotos'
for folder in (DATA, DIGITAIS, FOTOS):
    folder.mkdir(parents=True, exist_ok=True)
ADMIN_AUTH = json.loads(Path(os.environ['BTG_ADMIN_AUTH']).read_text(encoding='utf-8'))
KEY = os.environ['BTG_CHAVE']
CADASTRAR = os.environ.get('BTG_CADASTRAR', '/usr/local/bin/cadastrar-digital')
CSRF = hmac.new(bytes.fromhex(ADMIN_AUTH['digest']), b'btg-local-admin-csrf-v1', hashlib.sha256).hexdigest()
COOKIE = 'btg_sessao'
TTL = 900
PERFIS = ('conservador', 'moderado', 'arrojado')
app = Flask(__name__, static_folder=None)
app.config['MAX_CONTENT_LENGTH'] = 5 * 1024 * 1024


def db():
    if 'db' not in g:
        g.db = sqlite3.connect(DATA / 'btg.db', timeout=15)
        g.db.row_factory = sqlite3.Row
        g.db.execute('PRAGMA foreign_keys=ON')
    return g.db


@app.teardown_appcontext
def close_db(_):
    conn = g.pop('db', None)
    if conn:
        conn.close()


with app.app_context():
    db().executescript('''
    PRAGMA journal_mode=WAL;
    CREATE TABLE IF NOT EXISTS clientes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL,
      nascimento TEXT NOT NULL, perfil TEXT NOT NULL, foto TEXT,
      digital INTEGER NOT NULL DEFAULT 0, criado REAL NOT NULL);
    CREATE TABLE IF NOT EXISTS itens (
      id INTEGER PRIMARY KEY AUTOINCREMENT, cliente INTEGER NOT NULL REFERENCES clientes(id),
      tipo TEXT NOT NULL, titulo TEXT NOT NULL, data TEXT NOT NULL, categoria TEXT NOT NULL,
      valor REAL NOT NULL, detalhe TEXT NOT NULL, estado TEXT NOT NULL DEFAULT '', assinado TEXT);
    CREATE TABLE IF NOT EXISTS acessos (
      token_hash TEXT PRIMARY KEY, cliente INTEGER NOT NULL REFERENCES clientes(id),
      criado REAL NOT NULL, expira REAL NOT NULL, usado INTEGER NOT NULL DEFAULT 0,
      revogado INTEGER NOT NULL DEFAULT 0, dispositivo TEXT);
    CREATE TABLE IF NOT EXISTS sessoes (
      cookie_hash TEXT PRIMARY KEY, acesso TEXT NOT NULL REFERENCES acessos(token_hash));
    ''')
    db().commit()


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def verify_admin(password):
    candidate = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(ADMIN_AUTH['salt']), ADMIN_AUTH['iterations'])
    return secrets.compare_digest(candidate.hex(), ADMIN_AUTH['digest'])


def admin_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth = request.authorization
        if not auth or auth.username != 'admin' or not verify_admin(auth.password or ''):
            return Response('Acesso restrito', 401, {'WWW-Authenticate': 'Basic realm="BTG demonstracao", charset="UTF-8"'})
        if request.method != 'GET' and not secrets.compare_digest(request.headers.get('X-CSRF-Token', ''), CSRF):
            abort(403)
        return fn(*args, **kwargs)
    return wrapper


def key_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not secrets.compare_digest(request.headers.get('X-BTG-Chave', ''), KEY):
            abort(403)
        return fn(*args, **kwargs)
    return wrapper


@app.after_request
def headers(response):
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['Content-Security-Policy'] = "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
    return response


@app.errorhandler(413)
def too_large(_):
    return jsonify(erro='Envie uma foto PNG ou JPEG de até 4 MB.'), 413


@app.get('/btg/health')
def local_health():
    return jsonify(ok=True, modo='local')


@app.get('/btg/')
def home():
    return send_from_directory(BASE / 'web', 'index.html')


@app.get('/btg/admin')
@admin_required
def admin_page():
    return send_from_directory(BASE / 'web', 'admin.html')


@app.get('/btg/portal')
def portal():
    active_session()
    return send_from_directory(BASE / 'web', 'portal.html')


@app.get('/btg/encerrado')
def ended():
    return send_from_directory(BASE / 'web', 'encerrado.html')


@app.get('/btg/static/<path:name>')
def assets(name):
    return send_from_directory(BASE / 'web' / 'static', name)


def client(cid):
    row = db().execute('SELECT * FROM clientes WHERE id=?', (cid,)).fetchone()
    if row is None:
        abort(404)
    return row


def account(cid):
    """Agência/conta fictícias derivadas do id (sem relação com contas reais)."""
    num = f'{cid:06d}'
    dv = sum(int(c) * (i + 2) for i, c in enumerate(reversed(num))) % 11 % 10
    return {'agencia': '0001', 'conta': f'{num}-{dv}'}


def synthetic_account(cid, profile):
    """Carteira, extrato e operações inventados para apresentação; nenhum valor é real."""
    today = date.today()
    k = {'conservador': 1.0, 'moderado': 1.8, 'arrojado': 3.2}[profile]
    inv = [('CDB BTG Pactual 110% CDI', 'Renda fixa', 42000 * k, {'vencimento': (today + timedelta(days=720)).isoformat(), 'rentabilidade': '110% do CDI', 'liquidez': 'Diária', 'rendimento_mes': '1,02%'}),
           ('Tesouro IPCA+ 2035', 'Tesouro Direto', 25000 * k, {'vencimento': '2035-05-15', 'rentabilidade': 'IPCA + 6,1% a.a.', 'liquidez': 'D+1', 'rendimento_mes': '0,74%'}),
           ('LCI BTG 95% CDI', 'Renda fixa isenta', 18000 * k, {'vencimento': (today + timedelta(days=365)).isoformat(), 'rentabilidade': '95% do CDI', 'liquidez': 'No vencimento', 'rendimento_mes': '0,88%'})]
    if profile != 'conservador':
        inv.append(('Fundo Crédito Corporativo (demo)', 'Fundos', 30000 * k, {'vencimento': '—', 'rentabilidade': 'CDI + 1,8% a.a.', 'liquidez': 'D+30', 'rendimento_mes': '1,11%'}))
    if profile == 'arrojado':
        inv.append(('Ações BPAC11 (demo)', 'Renda variável', 22000 * k, {'vencimento': '—', 'rentabilidade': 'Variável', 'liquidez': 'D+2', 'rendimento_mes': '2,35%'}))
    mov = [('PIX recebido · Empresa Demo S.A.', 1, 'Entrada', 8500.00, {'canal': 'PIX', 'contraparte': 'Empresa Demo S.A. (fictícia)'}),
           ('Aplicação CDB BTG 110% CDI', 3, 'Investimento', -5000.00, {'canal': 'Investimentos', 'contraparte': 'BTG Pactual (demonstração)'}),
           ('Cartão BTG · fatura', 6, 'Pagamento', -2314.90, {'canal': 'Débito em conta', 'contraparte': 'Cartão final 0000 (fictício)'}),
           ('TED enviada · Imobiliária Demo', 9, 'Saída', -3200.00, {'canal': 'TED', 'contraparte': 'Imobiliária Demo Ltda. (fictícia)'}),
           ('Rendimentos · conta remunerada', 12, 'Rendimento', 187.43, {'canal': 'Conta', 'contraparte': 'BTG Pactual (demonstração)'}),
           ('PIX recebido · João Exemplo', 15, 'Entrada', 1200.00, {'canal': 'PIX', 'contraparte': 'João Exemplo (fictício)'})]
    ops = [('PIX para Fornecedor Demo Ltda.', 'Transferência PIX', 2500.00, {'canal': 'PIX', 'destino': 'Fornecedor Demo Ltda. (fictícia)', 'chave': 'demo@exemplo.com.br'}),
           ('Resgate parcial · CDB BTG 110% CDI', 'Resgate', 10000.00, {'canal': 'Investimentos', 'destino': 'Conta corrente BTG', 'chave': '—'}),
           ('Limite PIX noturno para R$ 5.000,00', 'Alteração de limite', 0.0, {'canal': 'Segurança', 'destino': 'Conta corrente BTG', 'chave': '—'})]
    rows = [('investimento', t, today.isoformat(), c, round(v, 2), d, '') for t, c, v, d in inv]
    rows += [('movimento', t, (today - timedelta(days=dd)).isoformat(), c, v, d, '') for t, dd, c, v, d in mov]
    rows += [('operacao', t, today.isoformat(), c, v, d, 'pendente') for t, c, v, d in ops]
    rows.append(('saldo', 'Conta corrente', today.isoformat(), 'Saldo', round(12750.35 * k, 2), {}, ''))
    for kind, title, day, cat, value, body, state in rows:
        db().execute('INSERT INTO itens (cliente,tipo,titulo,data,categoria,valor,detalhe,estado) VALUES (?,?,?,?,?,?,?,?)',
                     (cid, kind, title, day, cat, value, json.dumps(body, ensure_ascii=False), state))


@app.get('/btg/admin/api/clientes')
@admin_required
def clients():
    rows = []
    for r in db().execute('SELECT id,nome,nascimento,perfil,foto,digital FROM clientes ORDER BY id DESC'):
        rows.append({**dict(r), **account(r['id'])})
    return jsonify(csrf=CSRF, clientes=rows)


@app.post('/btg/admin/api/clientes')
@admin_required
def new_client():
    payload = request.get_json(silent=True) or {}
    name = str(payload.get('nome', '')).strip()
    birth = str(payload.get('nascimento', ''))
    profile = payload.get('perfil', 'moderado')
    try:
        birthday = date.fromisoformat(birth)
        if not date(1900, 1, 1) <= birthday <= date.today():
            raise ValueError()
    except ValueError:
        return jsonify(erro='Informe uma data de nascimento válida.'), 400
    if not 2 <= len(name) <= 100 or profile not in PERFIS:
        return jsonify(erro='Informe o nome e o perfil de investidor.'), 400
    with db():
        cid = db().execute('INSERT INTO clientes (nome,nascimento,perfil,criado) VALUES (?,?,?,?)',
                           (name, birth, profile, time.time())).lastrowid
        synthetic_account(cid, profile)
    return jsonify(id=cid), 201


@app.post('/btg/admin/api/clientes/<int:cid>/foto')
@admin_required
def upload_photo(cid):
    client(cid)
    upload = request.files.get('foto')
    if not upload:
        return jsonify(erro='Selecione a foto.'), 400
    raw = upload.read(4 * 1024 * 1024 + 1)
    kind = imghdr.what(None, raw)
    if len(raw) > 4 * 1024 * 1024 or kind not in ('jpeg', 'png'):
        return jsonify(erro='Use PNG ou JPEG de até 4 MB.'), 400
    filename = f'{cid}.{kind}'
    path = FOTOS / filename
    temp = FOTOS / f'{cid}.upload'
    temp.write_bytes(raw)
    os.chmod(temp, 0o600)
    os.replace(temp, path)
    with db():
        db().execute('UPDATE clientes SET foto=? WHERE id=?', (filename, cid))
    return jsonify(ok=True)


@app.get('/btg/admin/api/clientes/<int:cid>/foto')
@admin_required
def admin_photo(cid):
    row = client(cid)
    if not row['foto']:
        abort(404)
    return send_from_directory(FOTOS, row['foto'])


CAPTURE = {'ativo': False, 'mensagem': 'Nenhuma captura em andamento.', 'ok': False}
LOCK = threading.Lock()
PROCESS = None
CANCEL = threading.Event()


def capture(cid, name):
    global PROCESS
    temp = DIGITAIS / f'{cid}.novo'
    timer = None
    try:
        if CANCEL.is_set():
            return
        PROCESS = subprocess.Popen([CADASTRAR, str(temp), str(cid), name], stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        if CANCEL.is_set():
            PROCESS.terminate()
        timer = threading.Timer(90, lambda: PROCESS.terminate() if PROCESS and PROCESS.poll() is None else None)
        timer.start()
        got_ok = False
        for line in PROCESS.stdout:
            cmd, _, rest = line.strip().partition(' ')
            if cmd == 'LEITOR':
                CAPTURE['mensagem'] = 'Coloque o dedo no leitor deste equipamento.'
            elif cmd == 'ETAPAS':
                CAPTURE['total'] = int(rest)
            elif cmd == 'LEITURA':
                done, total = map(int, rest.split())
                CAPTURE.update(feitas=done, total=total, mensagem=f'Leitura {done} de {total}. Levante e coloque o mesmo dedo.')
            elif cmd == 'REPETIR':
                CAPTURE['mensagem'] = 'Leitura não aproveitada. Coloque o mesmo dedo novamente.'
            elif cmd == 'OK':
                got_ok = True
            elif cmd == 'ERRO':
                CAPTURE.update(erro=rest, mensagem=rest)
        rc = PROCESS.wait()
        PROCESS.stdout.close()
        if rc == 0 and got_ok and temp.is_file() and not CANCEL.is_set():
            os.chmod(temp, 0o600)
            os.replace(temp, DIGITAIS / f'{cid}.fpr')
            with sqlite3.connect(DATA / 'btg.db') as conn:
                conn.execute('UPDATE clientes SET digital=1 WHERE id=?', (cid,))
            CAPTURE.update(ok=True, mensagem='Digital cadastrada. O cliente já pode abrir "Minha Conta BTG" no UniconOS.')
        elif not CAPTURE.get('erro'):
            CAPTURE.update(erro='Captura cancelada ou tempo esgotado.', mensagem='Captura cancelada ou tempo esgotado. Tente novamente.')
    except (OSError, ValueError):
        CAPTURE.update(erro='Não foi possível acessar o leitor.', mensagem='Não foi possível acessar o leitor. Confira a conexão USB.')
    finally:
        if timer:
            timer.cancel()
        if temp.exists():
            temp.unlink()
        PROCESS = None
        with LOCK:
            CAPTURE['ativo'] = False


@app.post('/btg/admin/api/clientes/<int:cid>/digital')
@admin_required
def start_capture(cid):
    row = client(cid)
    with LOCK:
        if CAPTURE['ativo']:
            return jsonify(erro='Já existe uma captura em andamento.'), 409
        CANCEL.clear()
        CAPTURE.clear()
        CAPTURE.update(ativo=True, cliente=cid, nome=row['nome'], feitas=0, total=5, ok=False, mensagem='Abrindo o leitor...')
    threading.Thread(target=capture, args=(cid, row['nome']), daemon=True).start()
    return jsonify(ok=True)


@app.get('/btg/admin/api/captura')
@admin_required
def capture_state():
    return jsonify(CAPTURE)


@app.post('/btg/admin/api/captura/cancelar')
@admin_required
def cancel_capture():
    CANCEL.set()
    if PROCESS and PROCESS.poll() is None:
        PROCESS.terminate()
    return jsonify(ok=True)


@app.get('/btg/api/galeria')
@key_required
def gallery():
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w:gz') as archive:
        for row in db().execute('SELECT id FROM clientes WHERE digital=1'):
            path = DIGITAIS / f'{row[0]}.fpr'
            if path.is_file():
                archive.add(path, arcname=path.name, recursive=False)
    return Response(buf.getvalue(), mimetype='application/gzip')


@app.post('/btg/api/sessao')
@key_required
def open_session():
    try:
        cid = int(request.form.get('cliente', ''))
    except ValueError:
        abort(400)
    row = client(cid)
    if not row['digital'] or not (DIGITAIS / f'{cid}.fpr').is_file():
        return jsonify(erro='Cliente sem digital cadastrada.'), 409
    token = secrets.token_hex(32)
    now = time.time()
    with db():
        db().execute('INSERT INTO acessos (token_hash,cliente,criado,expira,dispositivo) VALUES (?,?,?,?,?)',
                     (digest(token), cid, now, now + TTL, request.form.get('dispositivo', '')[:80]))
    return Response(token, mimetype='text/plain')


@app.get('/btg/entrar/<token>')
def exchange_token(token):
    """URL de uso único: trocada por cookie; token não é usado nas chamadas de dados."""
    hashed = digest(token)
    cookie = secrets.token_hex(32)
    with db():
        updated = db().execute('UPDATE acessos SET usado=1 WHERE token_hash=? AND usado=0 AND revogado=0 AND expira>?',
                               (hashed, time.time()))
        if updated.rowcount != 1:
            abort(401)
        db().execute('INSERT INTO sessoes (cookie_hash,acesso) VALUES (?,?)', (digest(cookie), hashed))
    response = Response(status=303, headers={'Location': '/btg/portal'})
    response.set_cookie(COOKIE, cookie, max_age=TTL, path='/btg', httponly=True, samesite='Strict')
    return response


def active_session():
    cookie = request.cookies.get(COOKIE, '')
    row = db().execute('SELECT a.* FROM sessoes s JOIN acessos a ON s.acesso=a.token_hash WHERE s.cookie_hash=? AND a.revogado=0 AND a.expira>?',
                       (digest(cookie), time.time())).fetchone()
    if row is None:
        abort(401)
    return row


def session_csrf():
    return digest(request.cookies[COOKIE] + ':sair')


def check_session_csrf():
    if not secrets.compare_digest(request.headers.get('X-CSRF-Token', ''), session_csrf()):
        abort(403)


@app.get('/btg/api/me')
def my_account():
    session = active_session()
    row = client(session['cliente'])
    items = []
    for r in db().execute('SELECT * FROM itens WHERE cliente=? ORDER BY data DESC,id', (row['id'],)):
        d = dict(r)
        d['detalhe'] = json.loads(d['detalhe'])
        items.append(d)
    return jsonify(cliente={'id': row['id'], 'nome': row['nome'], 'nascimento': row['nascimento'], 'perfil': row['perfil'],
                            'foto': bool(row['foto']), **account(row['id'])},
                   itens=items, expira=session['expira'], dispositivo=session['dispositivo'] or '', csrf=session_csrf())


@app.get('/btg/api/me/foto')
def my_photo():
    row = client(active_session()['cliente'])
    if not row['foto']:
        abort(404)
    return send_from_directory(FOTOS, row['foto'])


@app.post('/btg/api/operacoes/<int:oid>/<acao>')
def decide_operation(oid, acao):
    """A sessão só existe depois da digital reconhecida no leitor: a decisão fica registrada como assinada por ela."""
    session = active_session()
    check_session_csrf()
    if acao not in ('aprovar', 'recusar'):
        abort(404)
    state = 'aprovada' if acao == 'aprovar' else 'recusada'
    stamp = datetime.now().strftime('%d/%m/%Y %H:%M')
    with db():
        updated = db().execute("UPDATE itens SET estado=?, assinado=? WHERE id=? AND cliente=? AND tipo='operacao' AND estado='pendente'",
                               (state, f'{stamp} · digital · {session["dispositivo"] or "eLux"}', oid, session['cliente']))
        if updated.rowcount != 1:
            return jsonify(erro='Operação não encontrada ou já decidida.'), 409
        op = db().execute('SELECT * FROM itens WHERE id=?', (oid,)).fetchone()
        if state == 'aprovada' and op['valor'] > 0:
            sign = 1 if op['categoria'] == 'Resgate' else -1
            db().execute("UPDATE itens SET valor=round(valor+?,2) WHERE cliente=? AND tipo='saldo'", (sign * op['valor'], session['cliente']))
            db().execute('INSERT INTO itens (cliente,tipo,titulo,data,categoria,valor,detalhe) VALUES (?,?,?,?,?,?,?)',
                         (session['cliente'], 'movimento', op['titulo'], date.today().isoformat(),
                          'Entrada' if sign > 0 else 'Saída', sign * op['valor'], op['detalhe']))
    return jsonify(ok=True, estado=state)


@app.post('/btg/api/sair')
def logout():
    session = active_session()
    check_session_csrf()
    with db():
        db().execute('UPDATE acessos SET revogado=1 WHERE token_hash=?', (session['token_hash'],))
    response = jsonify(ok=True)
    response.delete_cookie(COOKIE, path='/btg')
    return response


@app.post('/btg/api/sessao/<token>/encerrar')
@key_required
def native_logout(token):
    with db():
        db().execute('UPDATE acessos SET revogado=1 WHERE token_hash=?', (digest(token),))
    return jsonify(ok=True)


if __name__ == '__main__':
    from waitress import serve
    serve(app, host='127.0.0.1', port=int(os.environ.get('BTG_PORTA', '3132')), threads=6)
