"""Área do segurado Porto (teste POPULOS). Apólices, sinistros e valores fictícios; biometria local libfprint."""
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
DATA = Path(os.environ.get('PORTO_DADOS', '/data'))
DIGITAIS = DATA / 'digitais'
FOTOS = DATA / 'fotos'
for folder in (DATA, DIGITAIS, FOTOS):
    folder.mkdir(parents=True, exist_ok=True)
ADMIN_AUTH = json.loads(Path(os.environ['PORTO_ADMIN_AUTH']).read_text(encoding='utf-8'))
KEY = os.environ['PORTO_CHAVE']
CADASTRAR = os.environ.get('PORTO_CADASTRAR', '/usr/local/bin/cadastrar-digital')
CSRF = hmac.new(bytes.fromhex(ADMIN_AUTH['digest']), b'porto-local-admin-csrf-v1', hashlib.sha256).hexdigest()
COOKIE = 'porto_sessao'
TTL = 900
PLANOS = ('auto', 'auto_residencia', 'completo')
app = Flask(__name__, static_folder=None)
app.config['MAX_CONTENT_LENGTH'] = 5 * 1024 * 1024


def db():
    if 'db' not in g:
        g.db = sqlite3.connect(DATA / 'porto.db', timeout=15)
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
    CREATE TABLE IF NOT EXISTS segurados (
      id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL,
      nascimento TEXT NOT NULL, plano TEXT NOT NULL, foto TEXT,
      digital INTEGER NOT NULL DEFAULT 0, criado REAL NOT NULL);
    CREATE TABLE IF NOT EXISTS itens (
      id INTEGER PRIMARY KEY AUTOINCREMENT, segurado INTEGER NOT NULL REFERENCES segurados(id),
      tipo TEXT NOT NULL, titulo TEXT NOT NULL, data TEXT NOT NULL, categoria TEXT NOT NULL,
      valor REAL NOT NULL, detalhe TEXT NOT NULL, estado TEXT NOT NULL DEFAULT '', assinado TEXT);
    CREATE TABLE IF NOT EXISTS acessos (
      token_hash TEXT PRIMARY KEY, segurado INTEGER NOT NULL REFERENCES segurados(id),
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
            return Response('Acesso restrito', 401, {'WWW-Authenticate': 'Basic realm="Porto demonstracao", charset="UTF-8"'})
        if request.method != 'GET' and not secrets.compare_digest(request.headers.get('X-CSRF-Token', ''), CSRF):
            abort(403)
        return fn(*args, **kwargs)
    return wrapper


def key_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not secrets.compare_digest(request.headers.get('X-Porto-Chave', ''), KEY):
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


@app.get('/porto/health')
def local_health():
    return jsonify(ok=True, modo='local')


@app.get('/porto/')
def home():
    return send_from_directory(BASE / 'web', 'index.html')


@app.get('/porto/admin')
@admin_required
def admin_page():
    return send_from_directory(BASE / 'web', 'admin.html')


@app.get('/porto/portal')
def portal():
    active_session()
    return send_from_directory(BASE / 'web', 'portal.html')


@app.get('/porto/encerrado')
def ended():
    return send_from_directory(BASE / 'web', 'encerrado.html')


@app.get('/porto/static/<path:name>')
def assets(name):
    return send_from_directory(BASE / 'web' / 'static', name)


def insured(sid):
    row = db().execute('SELECT * FROM segurados WHERE id=?', (sid,)).fetchone()
    if row is None:
        abort(404)
    return row


def code(sid):
    """Código de segurado fictício derivado do id (sem relação com clientes reais)."""
    num = f'{sid:06d}'
    dv = sum(int(c) * (i + 2) for i, c in enumerate(reversed(num))) % 11 % 10
    return {'codigo': f'PS-{num}-{dv}'}


def synthetic_policies(sid, plan):
    """Apólices, pagamentos e solicitações inventados para apresentação; nenhum valor é real."""
    today = date.today()
    end = (today + timedelta(days=300)).isoformat()
    n = f'{sid:06d}'
    pol = [('Porto Seguro Auto · Jeep Compass 2023', 'Seguro Auto', 289.90,
            {'apolice': f'0531.{n}.01', 'bem': 'Jeep Compass Longitude 2023 · placa DEM-0A00 (fictícia)', 'cobertura': 'Compreensiva · 100% da tabela FIPE',
             'franquia': 'R$ 4.200,00', 'assistencia': 'Guincho sem limite de km · carro reserva 15 dias', 'vigencia': end})]
    if plan != 'auto':
        pol.append(('Porto Seguro Residência · Apartamento', 'Seguro Residência', 64.50,
                    {'apolice': f'0114.{n}.02', 'bem': 'Rua Exemplo, 100, ap. 72 · São Paulo/SP (fictício)', 'cobertura': 'Incêndio R$ 500 mil · danos elétricos · roubo',
                     'franquia': '—', 'assistencia': 'Chaveiro, encanador e eletricista 24h', 'vigencia': end}))
    if plan == 'completo':
        pol.append(('Porto Seguro Vida Individual', 'Seguro Vida', 98.00,
                    {'apolice': f'0982.{n}.03', 'bem': 'Titular da apólice', 'cobertura': 'Morte R$ 300 mil · invalidez por acidente',
                     'franquia': '—', 'assistencia': 'Assistência funeral familiar', 'vigencia': end}))
    pay = [('Parcela 4/12 · Seguro Auto', 3, 'Pago', -289.90, {'canal': 'Cartão Porto Bank final 0000 (fictício)'}),
           ('Cashback Porto Plus', 8, 'Crédito', 23.40, {'canal': 'Programa de vantagens (demonstração)'}),
           ('Parcela 3/12 · Seguro Auto', 33, 'Pago', -289.90, {'canal': 'Cartão Porto Bank final 0000 (fictício)'}),
           ('Assistência 24h · troca de pneu', 41, 'Serviço', 0.0, {'canal': 'Serviço incluso no seguro'})]
    if plan != 'auto':
        pay.append(('Parcela 4/12 · Seguro Residência', 5, 'Pago', -64.50, {'canal': 'Débito automático (fictício)'}))
    if plan == 'completo':
        pay.append(('Parcela 7/12 · Seguro Vida', 10, 'Pago', -98.00, {'canal': 'Débito automático (fictício)'}))
    req = [('Orçamento de reparo · sinistro de colisão', 'Sinistro', 4200.00,
            {'protocolo': f'SIN-2026-{n[-4:]}', 'destino': 'Centro Automotivo Demo (oficina referenciada, fictícia)', 'canal': 'Franquia do Seguro Auto',
             'descricao': 'Para-choque e farol dianteiros · reparo estimado em R$ 11.850,00'}),
           ('Guincho · Assistência 24h', 'Assistência', 0.0,
            {'protocolo': f'AST-2026-{n[-4:]}', 'destino': 'Av. Exemplo, 1000 → Centro Automotivo Demo (fictícios)', 'canal': 'Assistência 24h',
             'descricao': 'Remoção do veículo até a oficina referenciada, sem custo'}),
           ('Renovação antecipada · Seguro Auto 2027', 'Renovação', 3360.00,
            {'protocolo': f'REN-2027-{n[-4:]}', 'destino': 'Porto Seguro Auto (demonstração)', 'canal': '12 parcelas de R$ 280,00 sem juros',
             'descricao': 'Mantém coberturas e bônus classe 7 · desconto de 4% por renovar antes'})]
    rows = [('apolice', t, today.isoformat(), c, v, d, 'ativa') for t, c, v, d in pol]
    rows += [('pagamento', t, (today - timedelta(days=dd)).isoformat(), c, v, d, '') for t, dd, c, v, d in pay]
    rows += [('solicitacao', t, today.isoformat(), c, v, d, 'pendente') for t, c, v, d in req]
    for kind, title, day, cat, value, body, state in rows:
        db().execute('INSERT INTO itens (segurado,tipo,titulo,data,categoria,valor,detalhe,estado) VALUES (?,?,?,?,?,?,?,?)',
                     (sid, kind, title, day, cat, value, json.dumps(body, ensure_ascii=False), state))


@app.get('/porto/admin/api/segurados')
@admin_required
def insured_list():
    rows = []
    for r in db().execute('SELECT id,nome,nascimento,plano,foto,digital FROM segurados ORDER BY id DESC'):
        rows.append({**dict(r), **code(r['id'])})
    return jsonify(csrf=CSRF, segurados=rows)


@app.post('/porto/admin/api/segurados')
@admin_required
def new_insured():
    payload = request.get_json(silent=True) or {}
    name = str(payload.get('nome', '')).strip()
    birth = str(payload.get('nascimento', ''))
    plan = payload.get('plano', 'auto_residencia')
    try:
        birthday = date.fromisoformat(birth)
        if not date(1900, 1, 1) <= birthday <= date.today():
            raise ValueError()
    except ValueError:
        return jsonify(erro='Informe uma data de nascimento válida.'), 400
    if not 2 <= len(name) <= 100 or plan not in PLANOS:
        return jsonify(erro='Informe o nome e os seguros contratados.'), 400
    with db():
        sid = db().execute('INSERT INTO segurados (nome,nascimento,plano,criado) VALUES (?,?,?,?)',
                           (name, birth, plan, time.time())).lastrowid
        synthetic_policies(sid, plan)
    return jsonify(id=sid), 201


@app.post('/porto/admin/api/segurados/<int:sid>/foto')
@admin_required
def upload_photo(sid):
    insured(sid)
    upload = request.files.get('foto')
    if not upload:
        return jsonify(erro='Selecione a foto.'), 400
    raw = upload.read(4 * 1024 * 1024 + 1)
    kind = imghdr.what(None, raw)
    if len(raw) > 4 * 1024 * 1024 or kind not in ('jpeg', 'png'):
        return jsonify(erro='Use PNG ou JPEG de até 4 MB.'), 400
    filename = f'{sid}.{kind}'
    path = FOTOS / filename
    temp = FOTOS / f'{sid}.upload'
    temp.write_bytes(raw)
    os.chmod(temp, 0o600)
    os.replace(temp, path)
    with db():
        db().execute('UPDATE segurados SET foto=? WHERE id=?', (filename, sid))
    return jsonify(ok=True)


@app.get('/porto/admin/api/segurados/<int:sid>/foto')
@admin_required
def admin_photo(sid):
    row = insured(sid)
    if not row['foto']:
        abort(404)
    return send_from_directory(FOTOS, row['foto'])


CAPTURE = {'ativo': False, 'mensagem': 'Nenhuma captura em andamento.', 'ok': False}
LOCK = threading.Lock()
PROCESS = None
CANCEL = threading.Event()


def capture(sid, name):
    global PROCESS
    temp = DIGITAIS / f'{sid}.novo'
    timer = None
    try:
        if CANCEL.is_set():
            return
        PROCESS = subprocess.Popen([CADASTRAR, str(temp), str(sid), name], stdout=subprocess.PIPE,
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
            os.replace(temp, DIGITAIS / f'{sid}.fpr')
            with sqlite3.connect(DATA / 'porto.db') as conn:
                conn.execute('UPDATE segurados SET digital=1 WHERE id=?', (sid,))
            CAPTURE.update(ok=True, mensagem='Digital cadastrada. O segurado já pode abrir "Meu Seguro Porto" no UniconOS.')
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


@app.post('/porto/admin/api/segurados/<int:sid>/digital')
@admin_required
def start_capture(sid):
    row = insured(sid)
    with LOCK:
        if CAPTURE['ativo']:
            return jsonify(erro='Já existe uma captura em andamento.'), 409
        CANCEL.clear()
        CAPTURE.clear()
        CAPTURE.update(ativo=True, segurado=sid, nome=row['nome'], feitas=0, total=5, ok=False, mensagem='Abrindo o leitor...')
    threading.Thread(target=capture, args=(sid, row['nome']), daemon=True).start()
    return jsonify(ok=True)


@app.get('/porto/admin/api/captura')
@admin_required
def capture_state():
    return jsonify(CAPTURE)


@app.post('/porto/admin/api/captura/cancelar')
@admin_required
def cancel_capture():
    CANCEL.set()
    if PROCESS and PROCESS.poll() is None:
        PROCESS.terminate()
    return jsonify(ok=True)


@app.get('/porto/api/galeria')
@key_required
def gallery():
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w:gz') as archive:
        for row in db().execute('SELECT id FROM segurados WHERE digital=1'):
            path = DIGITAIS / f'{row[0]}.fpr'
            if path.is_file():
                archive.add(path, arcname=path.name, recursive=False)
    return Response(buf.getvalue(), mimetype='application/gzip')


@app.post('/porto/api/sessao')
@key_required
def open_session():
    try:
        sid = int(request.form.get('segurado', ''))
    except ValueError:
        abort(400)
    row = insured(sid)
    if not row['digital'] or not (DIGITAIS / f'{sid}.fpr').is_file():
        return jsonify(erro='Segurado sem digital cadastrada.'), 409
    token = secrets.token_hex(32)
    now = time.time()
    with db():
        db().execute('INSERT INTO acessos (token_hash,segurado,criado,expira,dispositivo) VALUES (?,?,?,?,?)',
                     (digest(token), sid, now, now + TTL, request.form.get('dispositivo', '')[:80]))
    return Response(token, mimetype='text/plain')


@app.get('/porto/entrar/<token>')
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
    response = Response(status=303, headers={'Location': '/porto/portal'})
    response.set_cookie(COOKIE, cookie, max_age=TTL, path='/porto', httponly=True, samesite='Strict')
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


@app.get('/porto/api/me')
def my_policies():
    session = active_session()
    row = insured(session['segurado'])
    items = []
    for r in db().execute('SELECT * FROM itens WHERE segurado=? ORDER BY data DESC,id', (row['id'],)):
        d = dict(r)
        d['detalhe'] = json.loads(d['detalhe'])
        items.append(d)
    return jsonify(segurado={'id': row['id'], 'nome': row['nome'], 'nascimento': row['nascimento'], 'plano': row['plano'],
                             'foto': bool(row['foto']), **code(row['id'])},
                   itens=items, expira=session['expira'], dispositivo=session['dispositivo'] or '', csrf=session_csrf())


@app.get('/porto/api/me/foto')
def my_photo():
    row = insured(active_session()['segurado'])
    if not row['foto']:
        abort(404)
    return send_from_directory(FOTOS, row['foto'])


@app.post('/porto/api/solicitacoes/<int:rid>/<acao>')
def decide_request(rid, acao):
    """A sessão só existe depois da digital reconhecida no leitor: a decisão fica registrada como assinada por ela."""
    session = active_session()
    check_session_csrf()
    if acao not in ('aprovar', 'recusar'):
        abort(404)
    state = 'aprovada' if acao == 'aprovar' else 'recusada'
    stamp = datetime.now().strftime('%d/%m/%Y %H:%M')
    with db():
        updated = db().execute("UPDATE itens SET estado=?, assinado=? WHERE id=? AND segurado=? AND tipo='solicitacao' AND estado='pendente'",
                               (state, f'{stamp} · digital · {session["dispositivo"] or "eLux"}', rid, session['segurado']))
        if updated.rowcount != 1:
            return jsonify(erro='Solicitação não encontrada ou já decidida.'), 409
        req = db().execute('SELECT * FROM itens WHERE id=?', (rid,)).fetchone()
        if state == 'aprovada' and req['valor'] > 0:
            first = req['valor'] if req['categoria'] != 'Renovação' else round(req['valor'] / 12, 2)
            db().execute('INSERT INTO itens (segurado,tipo,titulo,data,categoria,valor,detalhe) VALUES (?,?,?,?,?,?,?)',
                         (session['segurado'], 'pagamento', req['titulo'], date.today().isoformat(), 'Pago', -first,
                          json.dumps({'canal': 'Cartão Porto Bank final 0000 (fictício)'}, ensure_ascii=False)))
    return jsonify(ok=True, estado=state)


@app.post('/porto/api/sair')
def logout():
    session = active_session()
    check_session_csrf()
    with db():
        db().execute('UPDATE acessos SET revogado=1 WHERE token_hash=?', (session['token_hash'],))
    response = jsonify(ok=True)
    response.delete_cookie(COOKIE, path='/porto')
    return response


@app.post('/porto/api/sessao/<token>/encerrar')
@key_required
def native_logout(token):
    with db():
        db().execute('UPDATE acessos SET revogado=1 WHERE token_hash=?', (digest(token),))
    return jsonify(ok=True)


if __name__ == '__main__':
    from waitress import serve
    serve(app, host='127.0.0.1', port=int(os.environ.get('PORTO_PORTA', '3133')), threads=6)
