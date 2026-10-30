"""Teste de ponta a ponta com o cliente de teste do Flask: login, envio de um .deb, análise, conversão e download.
Uso (WSL, root): python3 -I teste_fluxo.py /caminho/programa.deb [imagem]
Usa uma pasta de dados temporária; não mexe nos trabalhos do serviço."""
import hashlib
import json
import os
import secrets
import sys
import tempfile
import time

dados = tempfile.mkdtemp(prefix='conv-teste-')
os.environ['CONVERSOR_DADOS'] = dados
senha = secrets.token_hex(8)
salt = secrets.token_bytes(16)
open(os.path.join(dados, 'admin-auth.json'), 'w').write(json.dumps(
    {'salt': salt.hex(), 'iterations': 1000, 'digest': hashlib.pbkdf2_hmac('sha256', senha.encode(), salt, 1000).hex()}))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'app'))
import conversor  # noqa: E402

arq = sys.argv[1]
imagem = sys.argv[2] if len(sys.argv) > 2 else 'v22'
categoria = sys.argv[3] if len(sys.argv) > 3 else 'software'
c = conversor.app.test_client()
assert c.get('/conversor/api/trabalhos').status_code == 401
assert c.post('/conversor/api/login', data={'senha': 'errada'}).status_code == 403
assert c.post('/conversor/api/login', data={'senha': senha}).status_code == 200
assert c.get('/conversor/').status_code == 200
with open(arq, 'rb') as f:
    r = c.post('/conversor/api/enviar', data={'arquivo': (f, os.path.basename(arq)), 'imagem': imagem, 'categoria': categoria}, content_type='multipart/form-data')
assert r.status_code == 200, r.json
jid = r.json['id']


def esperar(alvos):
    for _ in range(600):
        t = c.get(f'/conversor/api/trabalhos/{jid}').json
        if t['estado'] in alvos:
            return t
        time.sleep(1)
    raise SystemExit('tempo esgotado: ' + t['estado'])


t = esperar(('analisado', 'erro'))
assert t['estado'] == 'analisado', t.get('erro')
a = t['analise']
print('tipo', t['tipo'], 'nome', t['nome'], 'versao', t['versao'])
print('libs', {k: v['estado'] for k, v in a['libs'].items()})
print('faltando', a['faltando'], 'fpms', a['fpms_adicionar'])
print('avisos', *a['avisos'], sep='\n  ')
print('driver', {k: v for k, v in a['driver'].items() if k != 'avisos'})
assert c.get('/conversor/api/trabalhos').json[0]['categoria'] == categoria
assert c.post(f'/conversor/api/trabalhos/{jid}/converter', json={'embutir': True, 'servicos': True, 'sem_docs': True}).status_code == 200
t = esperar(('pronto', 'erro'))
print(t['log'][-1500:])
assert t['estado'] == 'pronto', t.get('erro')
print('feito', t['feito'])
print('saida', t['saida'])
print('comando', t['comando_imagem'])
for q in ('zip', 'epm', 'fpm', 'relatorio'):
    r = c.get(f'/conversor/api/trabalhos/{jid}/baixar/{q}')
    assert r.status_code == 200 and len(r.data) > 100, q
print('OK', dados)
