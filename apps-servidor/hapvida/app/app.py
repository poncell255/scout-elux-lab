"""Portal demonstrativo HAPVIDA. Prontuários sintéticos; biometria local libfprint."""
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
from datetime import date, timedelta
from functools import wraps

from flask import Flask, Response, abort, g, jsonify, request, send_from_directory

BASE = Path(__file__).resolve().parent
DATA = Path(os.environ.get('HAPVIDA_DADOS', '/data'))
DIGITAIS = DATA / 'digitais'
FOTOS = DATA / 'fotos'
for folder in (DATA, DIGITAIS, FOTOS):
    folder.mkdir(parents=True, exist_ok=True)
ADMIN = os.environ['HAPVIDA_ADMIN']
KEY = os.environ['HAPVIDA_CHAVE']
CADASTRAR = os.environ.get('HAPVIDA_CADASTRAR', '/usr/local/bin/cadastrar-digital')
CSRF = hmac.new(ADMIN.encode(), b'hapvida-admin-csrf-v1', hashlib.sha256).hexdigest()
COOKIE = 'hapvida_sessao'
TTL = 900
app = Flask(__name__, static_folder=None)
app.config['MAX_CONTENT_LENGTH'] = 5 * 1024 * 1024


def db():
    if 'db' not in g:
        g.db = sqlite3.connect(DATA / 'hapvida.db', timeout=15)
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
    CREATE TABLE IF NOT EXISTS pacientes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL,
      nascimento TEXT NOT NULL, perfil TEXT NOT NULL, foto TEXT,
      digital INTEGER NOT NULL DEFAULT 0, criado REAL NOT NULL);
    CREATE TABLE IF NOT EXISTS documentos (
      id INTEGER PRIMARY KEY AUTOINCREMENT, paciente INTEGER NOT NULL REFERENCES pacientes(id),
      tipo TEXT NOT NULL, titulo TEXT NOT NULL, data TEXT NOT NULL,
      especialidade TEXT NOT NULL, resumo TEXT NOT NULL, conteudo TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS acessos (
      token_hash TEXT PRIMARY KEY, paciente INTEGER NOT NULL REFERENCES pacientes(id),
      criado REAL NOT NULL, expira REAL NOT NULL, usado INTEGER NOT NULL DEFAULT 0,
      revogado INTEGER NOT NULL DEFAULT 0, dispositivo TEXT);
    CREATE TABLE IF NOT EXISTS sessoes (
      cookie_hash TEXT PRIMARY KEY, acesso TEXT NOT NULL REFERENCES acessos(token_hash));
    ''')
    db().commit()


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def admin_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth = request.authorization
        if not auth or auth.username != 'admin' or not secrets.compare_digest(auth.password or '', ADMIN):
            return Response('Acesso restrito', 401, {'WWW-Authenticate': 'Basic realm="HAPVIDA demonstracao", charset="UTF-8"'})
        if request.method != 'GET' and not secrets.compare_digest(request.headers.get('X-CSRF-Token', ''), CSRF):
            abort(403)
        return fn(*args, **kwargs)
    return wrapper


def key_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not secrets.compare_digest(request.headers.get('X-Hapvida-Chave', ''), KEY):
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


@app.get('/hapvida/')
def home():
    return send_from_directory(BASE / 'web', 'index.html')


@app.get('/hapvida/admin')
@admin_required
def admin_page():
    return send_from_directory(BASE / 'web', 'admin.html')


@app.get('/hapvida/portal')
def portal():
    active_session()
    return send_from_directory(BASE / 'web', 'portal.html')


@app.get('/hapvida/encerrado')
def ended():
    return send_from_directory(BASE / 'web', 'encerrado.html')


@app.get('/hapvida/static/<path:name>')
def assets(name):
    return send_from_directory(BASE / 'web' / 'static', name)


def patient(pid):
    row = db().execute('SELECT * FROM pacientes WHERE id=?', (pid,)).fetchone()
    if row is None:
        abort(404)
    return row


def synthetic_records(pid, profile):
    """Conteúdo inventado para apresentação, sem prescrição ou orientação clínica."""
    today = date.today()
    rows = [
        ('exame', 'Hemograma completo', 2, 'Análises clínicas', 'Resultado disponível • 18 parâmetros',
         {'texto': 'Laudo sintético de demonstração. Valores ilustrativos, sem validade clínica.',
          'itens': [['Hemoglobina', '14,2', 'g/dL', '12,0 – 17,5'], ['Hematócrito', '42,1', '%', '36,0 – 52,0'],
                    ['Leucócitos', '6.800', '/mm³', '4.000 – 11.000'], ['Plaquetas', '248.000', '/mm³', '150.000 – 450.000']]}),
        ('exame', 'Perfil metabólico', 8, 'Análises clínicas', 'Glicemia e perfil lipídico',
         {'texto': 'Amostra e resultados fictícios. Não representam a saúde da pessoa cadastrada.',
          'itens': [['Glicose', '92', 'mg/dL', '70 – 99'], ['Colesterol total', '172', 'mg/dL', '< 190'],
                    ['HDL', '53', 'mg/dL', '> 40'], ['Triglicerídeos', '114', 'mg/dL', '< 150']]}),
        ('exame', 'Radiografia de tórax', 15, 'Diagnóstico por imagem', 'Laudo demonstrativo de imagem',
         {'texto': 'Exame inteiramente simulado. Campos pulmonares ilustrativamente preservados. Sem imagens diagnósticas reais. Laudo fictício, sem validade clínica.', 'itens': []}),
        ('prontuario', 'Consulta de acompanhamento' if profile == 'acompanhamento' else 'Consulta de check-up', 1,
         'Clínica médica', 'Avaliação ambulatorial • Unidade Asa Sul',
         {'texto': 'Atendimento fictício criado para demonstrar a navegação do prontuário eletrônico.',
          'secoes': [['Motivo da consulta', 'Retorno demonstrativo para revisão de exames de rotina.'],
                     ['História registrada', 'Paciente fictício relata estar bem no cenário de demonstração.'],
                     ['Evolução', 'Resultados sintéticos apresentados e registro de acompanhamento simulado.'],
                     ['Plano registrado', 'Sem prescrição. Este registro serve exclusivamente à demonstração do sistema.']]}),
        ('prontuario', 'Avaliação de enfermagem', 8, 'Enfermagem', 'Triagem e sinais vitais simulados',
         {'texto': 'Dados ilustrativos: PA 120/80 mmHg · FC 72 bpm · temperatura 36,5 °C.',
          'secoes': [['Acolhimento', 'Identificação conferida no cenário de demonstração.'],
                     ['Observação', 'Informações geradas automaticamente; não são medições do paciente.']]}),
        ('prontuario', 'Primeiro atendimento', 30, 'Clínica médica', 'Histórico inicial da demonstração',
         {'texto': 'Abertura de prontuário fictício na unidade HAPVIDA de demonstração.',
          'secoes': [['Histórico', 'Cadastro demonstrativo e solicitação fictícia de exames de rotina.'],
                     ['Responsável', 'Equipe fictícia da demonstração · sem identificação profissional real.']]})]
    for kind, title, days, specialty, summary, body in rows:
        db().execute('INSERT INTO documentos (paciente,tipo,titulo,data,especialidade,resumo,conteudo) VALUES (?,?,?,?,?,?,?)',
                     (pid, kind, title, (today - timedelta(days=days)).isoformat(), specialty, summary, json.dumps(body, ensure_ascii=False)))


@app.get('/hapvida/admin/api/pacientes')
@admin_required
def patients():
    return jsonify(csrf=CSRF, pacientes=[dict(r) for r in db().execute(
        'SELECT id,nome,nascimento,perfil,foto,digital FROM pacientes ORDER BY id DESC')])


@app.post('/hapvida/admin/api/pacientes')
@admin_required
def new_patient():
    payload = request.get_json(silent=True) or {}
    name = str(payload.get('nome', '')).strip()
    birth = str(payload.get('nascimento', ''))
    profile = payload.get('perfil', 'checkup')
    try:
        birthday = date.fromisoformat(birth)
        if not date(1900, 1, 1) <= birthday <= date.today():
            raise ValueError()
    except ValueError:
        return jsonify(erro='Informe uma data de nascimento válida.'), 400
    if not 2 <= len(name) <= 100 or profile not in ('checkup', 'acompanhamento'):
        return jsonify(erro='Informe o nome e o cenário demonstrativo.'), 400
    with db():
        pid = db().execute('INSERT INTO pacientes (nome,nascimento,perfil,criado) VALUES (?,?,?,?)',
                           (name, birth, profile, time.time())).lastrowid
        synthetic_records(pid, profile)
    return jsonify(id=pid), 201


@app.post('/hapvida/admin/api/pacientes/<int:pid>/foto')
@admin_required
def upload_photo(pid):
    patient(pid)
    upload = request.files.get('foto')
    if not upload:
        return jsonify(erro='Selecione a foto.'), 400
    raw = upload.read(4 * 1024 * 1024 + 1)
    kind = imghdr.what(None, raw)
    if len(raw) > 4 * 1024 * 1024 or kind not in ('jpeg', 'png'):
        return jsonify(erro='Use PNG ou JPEG de até 4 MB.'), 400
    filename = f'{pid}.{kind}'
    path = FOTOS / filename
    temp = FOTOS / f'{pid}.upload'
    temp.write_bytes(raw)
    os.chmod(temp, 0o600)
    os.replace(temp, path)
    with db():
        db().execute('UPDATE pacientes SET foto=? WHERE id=?', (filename, pid))
    return jsonify(ok=True)


@app.get('/hapvida/admin/api/pacientes/<int:pid>/foto')
@admin_required
def admin_photo(pid):
    row = patient(pid)
    if not row['foto']:
        abort(404)
    return send_from_directory(FOTOS, row['foto'])


CAPTURE = {'ativo': False, 'mensagem': 'Nenhuma captura em andamento.', 'ok': False}
LOCK = threading.Lock()
PROCESS = None
CANCEL = threading.Event()


def capture(pid, name):
    global PROCESS
    temp = DIGITAIS / f'{pid}.novo'
    timer = None
    try:
        if CANCEL.is_set():
            return
        PROCESS = subprocess.Popen([CADASTRAR, str(temp), str(pid), name], stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        if CANCEL.is_set():
            PROCESS.terminate()
        timer = threading.Timer(90, lambda: PROCESS.terminate() if PROCESS and PROCESS.poll() is None else None)
        timer.start()
        got_ok = False
        for line in PROCESS.stdout:
            cmd, _, rest = line.strip().partition(' ')
            if cmd == 'LEITOR':
                CAPTURE['mensagem'] = 'Coloque o dedo no leitor do servidor.'
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
            os.replace(temp, DIGITAIS / f'{pid}.fpr')
            with sqlite3.connect(DATA / 'hapvida.db') as conn:
                conn.execute('UPDATE pacientes SET digital=1 WHERE id=?', (pid,))
            CAPTURE.update(ok=True, mensagem='Digital cadastrada. O paciente já pode abrir o aplicativo no UniconOS.')
        elif not CAPTURE.get('erro'):
            CAPTURE.update(erro='Captura cancelada ou tempo esgotado.', mensagem='Captura cancelada ou tempo esgotado. Tente novamente.')
    except (OSError, ValueError):
        CAPTURE.update(erro='Não foi possível acessar o leitor.', mensagem='Não foi possível acessar o leitor. Confira a conexão USB e o anexo ao WSL.')
    finally:
        if timer:
            timer.cancel()
        if temp.exists():
            temp.unlink()
        PROCESS = None
        with LOCK:
            CAPTURE['ativo'] = False


@app.post('/hapvida/admin/api/pacientes/<int:pid>/digital')
@admin_required
def start_capture(pid):
    row = patient(pid)
    with LOCK:
        if CAPTURE['ativo']:
            return jsonify(erro='Já existe uma captura em andamento.'), 409
        CANCEL.clear()
        CAPTURE.clear()
        CAPTURE.update(ativo=True, paciente=pid, nome=row['nome'], feitas=0, total=5, ok=False, mensagem='Abrindo o leitor...')
    threading.Thread(target=capture, args=(pid, row['nome']), daemon=True).start()
    return jsonify(ok=True)


@app.get('/hapvida/admin/api/captura')
@admin_required
def capture_state():
    return jsonify(CAPTURE)


@app.post('/hapvida/admin/api/captura/cancelar')
@admin_required
def cancel_capture():
    CANCEL.set()
    if PROCESS and PROCESS.poll() is None:
        PROCESS.terminate()
    return jsonify(ok=True)


@app.get('/hapvida/api/galeria')
@key_required
def gallery():
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w:gz') as archive:
        for row in db().execute('SELECT id FROM pacientes WHERE digital=1'):
            path = DIGITAIS / f'{row[0]}.fpr'
            if path.is_file():
                archive.add(path, arcname=path.name, recursive=False)
    return Response(buf.getvalue(), mimetype='application/gzip')


@app.post('/hapvida/api/sessao')
@key_required
def open_session():
    try:
        pid = int(request.form.get('paciente', ''))
    except ValueError:
        abort(400)
    row = patient(pid)
    if not row['digital'] or not (DIGITAIS / f'{pid}.fpr').is_file():
        return jsonify(erro='Paciente sem digital cadastrada.'), 409
    token = secrets.token_hex(32)
    now = time.time()
    with db():
        db().execute('INSERT INTO acessos (token_hash,paciente,criado,expira,dispositivo) VALUES (?,?,?,?,?)',
                     (digest(token), pid, now, now + TTL, request.form.get('dispositivo', '')[:80]))
    return Response(token, mimetype='text/plain')


@app.get('/hapvida/entrar/<token>')
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
    response = Response(status=303, headers={'Location': '/hapvida/portal'})
    response.set_cookie(COOKIE, cookie, max_age=TTL, path='/hapvida', httponly=True, samesite='Strict')
    return response


def active_session():
    cookie = request.cookies.get(COOKIE, '')
    row = db().execute('SELECT a.* FROM sessoes s JOIN acessos a ON s.acesso=a.token_hash WHERE s.cookie_hash=? AND a.revogado=0 AND a.expira>?',
                       (digest(cookie), time.time())).fetchone()
    if row is None:
        abort(401)
    return row


@app.get('/hapvida/api/me')
def my_records():
    session = active_session()
    row = patient(session['paciente'])
    docs = []
    for r in db().execute('SELECT * FROM documentos WHERE paciente=? ORDER BY data DESC,id DESC', (row['id'],)):
        d = dict(r)
        d['conteudo'] = json.loads(d['conteudo'])
        docs.append(d)
    return jsonify(paciente={'id': row['id'], 'nome': row['nome'], 'nascimento': row['nascimento'], 'foto': bool(row['foto'])},
                   documentos=docs, expira=session['expira'], csrf=digest(request.cookies[COOKIE] + ':sair'))


@app.get('/hapvida/api/me/foto')
def my_photo():
    row = patient(active_session()['paciente'])
    if not row['foto']:
        abort(404)
    return send_from_directory(FOTOS, row['foto'])


@app.post('/hapvida/api/sair')
def logout():
    session = active_session()
    csrf = digest(request.cookies[COOKIE] + ':sair')
    if not secrets.compare_digest(request.headers.get('X-CSRF-Token', ''), csrf):
        abort(403)
    with db():
        db().execute('UPDATE acessos SET revogado=1 WHERE token_hash=?', (session['token_hash'],))
    response = jsonify(ok=True)
    response.delete_cookie(COOKIE, path='/hapvida')
    return response


@app.post('/hapvida/api/sessao/<token>/encerrar')
@key_required
def native_logout(token):
    with db():
        db().execute('UPDATE acessos SET revogado=1 WHERE token_hash=?', (digest(token),))
    return jsonify(ok=True)


if __name__ == '__main__':
    from waitress import serve
    serve(app, host='0.0.0.0', port=3101, threads=6)
