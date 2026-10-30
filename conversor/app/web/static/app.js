'use strict';
const API = '/conversor/api';
const $ = s => document.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ESTADOS = { 'na fila': 'Na fila', analisando: 'Analisando', analisado: 'Analisado', convertendo: 'Convertendo', 'criando imagem': 'Criando imagem', pronto: 'Pronto', erro: 'Erro' };
const ANDAMENTO = ['na fila', 'analisando', 'convertendo', 'criando imagem'];
const LIB = { pacote: 'no programa', imagem: 'na imagem', fpm: 'pacote Unicon', faltando: 'falta no eLux' };
let atual = null, timer = null, aba = 'software', estadoSrv = {};
const TIPOS_ARQ = '.deb · .AppImage · .run · .tar.gz · .tar.xz · .zip · binário';
// As duas áreas usam o mesmo caminho (análise → conversão → EPM/FPM); muda o texto e o que a análise destaca
const ABAS = {
  software: {
    sobre: 'Software', titulo: 'Programas Ubuntu como <b>pacotes UniconOS</b>',
    texto: 'Leve aplicativos, agentes e ferramentas do Ubuntu 22.04 para o eLux 7: o SDK confere as bibliotecas contra a imagem, embute o que falta e gera o EPM/FPM para o ELIAS.',
    envio: '1. Enviar programa', lista: 'Trabalhos de software', soltar: 'Escolha ou arraste o programa',
    passos: [
      '<b>Envie</b> o programa para Ubuntu (o eLux 7 tem a mesma base do Ubuntu 22.04).',
      'A <b>análise</b> abre o pacote e confere cada biblioteca: se já vem no programa, se já está na imagem escolhida, se existe como pacote Unicon no ELIAS ou se falta.',
      'A <b>conversão</b> embute do Ubuntu 22.04 o que o eLux não tem, habilita os serviços systemd e gera o EPM/FPM com o epkg oficial da Unicon.',
      '<b>Baixe</b> o .zip, importe no ELIAS e rode o comando de imagem que aparece no fim.'],
    chips: () => ['Ubuntu 22.04 → eLux 7', `GLIBC <b>${esc(estadoSrv.glibc || '2.35')}</b>`, 'Limite da imagem <b>3.700 MB</b>'],
  },
  driver: {
    sobre: 'Drivers', titulo: 'Drivers e periféricos para o <b>UniconOS</b>',
    texto: 'Impressoras (CUPS/PPD), scanners (SANE), leitores e dispositivos USB (regras udev), firmware e módulos do kernel. O SDK mostra o que carrega no kernel do eLux e o que precisa ser recompilado.',
    envio: '1. Enviar driver', lista: 'Trabalhos de drivers', soltar: 'Escolha ou arraste o driver',
    passos: [
      '<b>Envie</b> o driver para Ubuntu 22.04 (.deb, .run ou .tar do fabricante).',
      'A <b>análise</b> separa as peças do driver: módulos <code>.ko</code> (com o kernel para o qual foram compilados), DKMS, firmware, regras udev, filtros e PPDs de impressora e backends de scanner.',
      'Módulo compilado para outro kernel <b>não carrega</b> no eLux: o SDK avisa e mostra o kernel certo. Bibliotecas e serviços seguem o mesmo caminho do software.',
      '<b>Baixe</b> o .zip, importe no ELIAS e rode o comando de imagem. Impressora: crie a fila no Scout apontando para o PPD do pacote.'],
    chips: () => [`Kernel eLux <b>${esc(estadoSrv.kernel || '?')}</b>`, 'CUPS · SANE · udev', 'Firmware em <b>/usr/lib/firmware</b>'],
  },
};

function trocarAba() {
  aba = location.hash === '#drivers' ? 'driver' : 'software';
  const c = ABAS[aba];
  document.body.classList.toggle('aba-driver', aba === 'driver');
  document.querySelectorAll('#abas a').forEach(a => a.classList.toggle('ativa', a.dataset.aba === aba));
  $('#h-sobre').textContent = c.sobre; $('#h-titulo').innerHTML = c.titulo; $('#h-texto').textContent = c.texto;
  $('#envio-titulo').textContent = c.envio; $('#lista-titulo').textContent = c.lista; $('#categoria').value = aba;
  $('#passos').innerHTML = c.passos.map(p => `<li>${p}</li>`).join('');
  $('#extra').innerHTML = `<div class="chips">${c.chips().map(x => `<span class="chip">${x}</span>`).join('')}</div>`;
  if (!arquivo.files[0]) textoSoltar();
  atual = null; clearTimeout(timer); $('#detalhe').hidden = true; $('#vazio').hidden = false;
  document.title = `${c.sobre} · Populos UniconOS SDK`;
  if (!$('#tela-app').hidden) listar();
}
function textoSoltar() { $('#soltar-texto').innerHTML = `<b>${ABAS[aba].soltar}</b><br><small>${TIPOS_ARQ} · até ${estadoSrv.max_mb || 2000} MB</small>`; }

async function api(caminho, op = {}) {
  const r = await fetch(API + caminho, op);
  const j = await r.json().catch(() => ({}));
  if (r.status === 401) { mostrarLogin(); throw new Error('login'); }
  if (!r.ok) throw new Error(j.erro || ('HTTP ' + r.status));
  return j;
}
const post = (c, corpo) => api(c, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(corpo || {}) });

function mostrarLogin() { $('#tela-login').hidden = false; $('#tela-app').hidden = true; $('#sair').hidden = true; $('#abas').hidden = true; }

async function iniciar() {
  const e = await api('/estado');
  estadoSrv = e;
  if (!e.logado) return mostrarLogin();
  $('#tela-login').hidden = true; $('#tela-app').hidden = false; $('#sair').hidden = false; $('#abas').hidden = false;
  $('#imagem').innerHTML = opcoesImagem(e.padrao);
  $('#imagem').onchange = () => infoImagem($('#imagem').value, $('#imagem-info'));
  infoImagem($('#imagem').value, $('#imagem-info'));
  trocarAba();
}
window.addEventListener('hashchange', trocarAba);

// Imagens: as que alguma OU usa primeiro, com o nome da OU; as outras são versões antigas, guardadas no ELIAS
function opcoesImagem(sel) {
  const l = estadoSrv.info_imagens || [], op = i => `<option value="${esc(i.id)}" ${i.id === sel ? 'selected' : ''}>${esc(i.id)}${i.ous.length ? ' · ' + esc(i.ous.join(', ')) : ''} · ${i.mb.toLocaleString('pt-BR')} MB</option>`;
  const uso = l.filter(i => i.ous.length), resto = l.filter(i => !i.ous.length);
  return `<optgroup label="Em uso nas OUs">${uso.map(op).join('')}</optgroup><optgroup label="Sem OU (versões anteriores)">${resto.map(op).join('')}</optgroup>`;
}
function infoImagem(id, alvo) {
  const i = (estadoSrv.info_imagens || []).find(x => x.id === id);
  if (!alvo || !i) return;
  alvo.innerHTML = (i.ous.length ? `Usada por <b>${esc(i.ous.join(', '))}</b> (${i.aparelhos} aparelho${i.aparelhos === 1 ? '' : 's'}).`
    : 'Nenhuma OU usa esta imagem hoje.') + (i.destaques.length ? ` Tem: ${esc(i.destaques.join(', '))}.` : '')
    + (estadoSrv.uso_gerado ? ` <span class="sutil">(OUs lidas do Scout em ${esc(estadoSrv.uso_gerado)})</span>` : '');
}

$('#form-login').addEventListener('submit', async ev => {
  ev.preventDefault();
  $('#erro-login').textContent = '';
  const r = await fetch(API + '/login', { method: 'POST', body: new FormData(ev.target) });
  if (r.ok) { ev.target.reset(); iniciar(); } else $('#erro-login').textContent = (await r.json()).erro || 'Falhou';
});
$('#sair').addEventListener('click', async () => { await post('/sair'); location.reload(); });

const soltar = $('#soltar'), arquivo = $('#arquivo');
arquivo.addEventListener('change', () => { if (arquivo.files[0]) $('#soltar-texto').innerHTML = `<b>${esc(arquivo.files[0].name)}</b><br><small>${(arquivo.files[0].size / 1048576).toFixed(1)} MB</small>`; });
['dragenter', 'dragover'].forEach(t => soltar.addEventListener(t, e => { e.preventDefault(); soltar.classList.add('ativo'); }));
['dragleave', 'drop'].forEach(t => soltar.addEventListener(t, e => { e.preventDefault(); soltar.classList.remove('ativo'); }));
soltar.addEventListener('drop', e => { if (e.dataTransfer.files.length) { arquivo.files = e.dataTransfer.files; arquivo.dispatchEvent(new Event('change')); } });

$('#form-envio').addEventListener('submit', ev => {
  ev.preventDefault();
  $('#erro-envio').textContent = '';
  const fd = new FormData(ev.target), x = new XMLHttpRequest(), barra = $('#progresso');
  barra.hidden = false; $('#botao-enviar').disabled = true;
  x.upload.onprogress = p => { if (p.lengthComputable) barra.firstElementChild.style.width = (100 * p.loaded / p.total) + '%'; };
  x.onload = async () => {
    barra.hidden = true; $('#botao-enviar').disabled = false; barra.firstElementChild.style.width = 0;
    let j = {}; try { j = JSON.parse(x.responseText); } catch (_) { }
    if (x.status !== 200) { $('#erro-envio').textContent = j.erro || `Falhou (HTTP ${x.status})`; return; }
    ev.target.reset(); $('#categoria').value = aba; textoSoltar();
    await listar(); abrir(j.id);
  };
  x.onerror = () => { barra.hidden = true; $('#botao-enviar').disabled = false; $('#erro-envio').textContent = 'Falha de rede no envio'; };
  x.open('POST', API + '/enviar'); x.send(fd);
});

async function listar() {
  const l = (await api('/trabalhos')).filter(t => (t.categoria || 'software') === aba);
  $('#lista').innerHTML = l.length ? l.map(t => `<li data-id="${t.id}" class="${t.id === atual ? 'sel' : ''}">
      <div><span class="nome">${esc(t.nome || t.arquivo)}</span><small>${esc(t.arquivo)} · ${esc(t.criado)} · ${esc(t.imagem)}</small></div>
      <span class="selo s-${esc((t.estado || '').replace(' ', '-'))}">${esc(ESTADOS[t.estado] || t.estado)}</span></li>`).join('')
    : `<li class="sutil">Nenhum ${aba === 'driver' ? 'driver' : 'programa'} enviado ainda.</li>`;
  document.querySelectorAll('#lista li[data-id]').forEach(li => li.onclick = () => abrir(li.dataset.id));
}

async function abrir(id) {
  atual = id; clearTimeout(timer);
  const t = await api('/trabalhos/' + id);
  $('#vazio').hidden = true; $('#detalhe').hidden = false;
  $('#detalhe').innerHTML = render(t);
  ligar(t);
  document.querySelectorAll('#lista li').forEach(li => li.classList.toggle('sel', li.dataset.id === id));
  if (ANDAMENTO.includes(t.estado)) timer = setTimeout(() => { abrir(id); listar(); }, 2000);
}

function selo(estado, texto) { return `<span class="selo s-${esc(estado)}">${esc(texto)}</span>`; }

function render(t) {
  const a = t.analise, em = ANDAMENTO.includes(t.estado);
  let h = `<div class="cartao"><div class="cab"><div><h2>${esc(t.nome || t.arquivo)} <span class="sutil">${esc(t.versao || '')}</span></h2>
    <div class="sutil">${esc(t.arquivo)} · ${esc(t.tipo || '?')} · ${esc(t.tamanho_mb)} MB · imagem ${esc(t.imagem)}</div></div>
    <div>${selo((t.estado || '').replace(' ', '-'), ESTADOS[t.estado] || t.estado)}</div></div>`;
  if (t.erro) h += `<div class="caixa ruim"><b>Erro${t.etapa_erro ? ' na ' + (t.etapa_erro === 'analise' ? 'análise' : 'conversão') : ''}:</b><pre>${esc(t.erro)}</pre></div>`;
  if (em) h += `<p class="sutil">${t.estado === 'convertendo' ? 'Convertendo: extração limpa, bibliotecas do Ubuntu, serviços e epkg (pode levar alguns minutos)...'
    : t.estado === 'criando imagem' ? 'Criando a imagem no ELIAS: catálogo, reparo das imagens em uso e montagem (pode levar alguns minutos)...' : 'Trabalhando...'}</p>`;
  if (t.meta?.descricao) h += `<p>${esc(t.meta.descricao.split('\n')[0])}</p>`;
  if (a) {
    const libs = Object.entries(a.libs), cont = k => libs.filter(([, d]) => d.estado === k).length;
    const total = (a.tamanho_imagem_mb || 0) + (a.tamanho_mb - (a.docs_mb || 0));
    h += `<div class="numeros">
      <div class="numero"><b>${a.arquivos}</b><span>arquivos · ${a.tamanho_mb} MB</span></div>
      <div class="numero"><b>${a.elfs}</b><span>binários ELF</span></div>
      <div class="numero"><b>${libs.length}</b><span>bibliotecas usadas</span></div>
      <div class="numero"><b>${cont('fpm')}</b><span>pacotes Unicon a incluir</span></div>
      <div class="numero"><b>${cont('faltando')}</b><span>faltam no eLux</span></div>
      <div class="numero"><b>${esc(a.glibc_exigida || '—')}</b><span>GLIBC exigida (eLux ${esc(a.glibc_elux)})</span></div></div>`;
    const ruim = a.avisos.some(x => /não vai rodar|não são x86-64|não carregam no eLux|não compila módulos/.test(x));
    h += `<div class="caixa ${ruim ? 'ruim' : (cont('faltando') || cont('fpm') ? 'atencao' : 'ok')}">${ruim ? '<b>Provavelmente não roda no eLux.</b> Veja os avisos.'
      : cont('faltando') ? `<b>Faltam ${cont('faltando')} biblioteca(s) no eLux.</b> A conversão tenta embutir do Ubuntu 22.04.`
        : cont('fpm') ? `<b>Tudo existe no eLux</b>, mas ${a.fpms_adicionar.length} pacote(s) Unicon precisam entrar na imagem.` : '<b>Tudo o que o programa usa já está na imagem.</b>'}
      Imagem ${esc(t.imagem)} (${a.tamanho_imagem_mb} MB) + programa ≈ <b>${Math.round(total)} MB</b>${total > 3700 ? ' — <b>acima do limite de 3.700 MB</b> dos eLux de pendrive/dual-boot' : ''}.</div>`;
    h += `<h3>Avisos</h3><ul class="avisos">${a.avisos.map(x => `<li>${esc(x)}</li>`).join('')}</ul>`;
    h += renderDriver(a.driver, t.categoria === 'driver');
    h += `<h3>Bibliotecas</h3><div class="rolagem"><table><tr><th>Biblioteca</th><th>Situação</th><th>Onde / pacote</th><th>Usada por</th></tr>${libs.map(([so, d]) =>
      `<tr><td><code>${esc(so)}</code></td><td>${selo(d.estado, LIB[d.estado])}</td><td><code>${esc(d.onde || d.fpm || (d.estado === 'faltando' ? 'embutir do Ubuntu' : ''))}</code></td><td><code>${esc(d.usado_por.slice(0, 3).join(' '))}</code></td></tr>`).join('') || '<tr><td colspan=4 class=sutil>Nenhum binário ELF.</td></tr>'}</table></div>`;
    const it = Object.entries(a.interpretes || {});
    if (it.length) h += `<h3>Interpretadores de scripts</h3><table><tr><th>Comando</th><th>Situação</th><th>Pacote</th><th>Scripts</th></tr>${it.map(([c, d]) =>
      `<tr><td><code>${esc(c)}</code></td><td>${selo(d.estado, LIB[d.estado])}</td><td><code>${esc(d.fpm || '')}</code></td><td><code>${esc(d.usado_por.join(' '))}</code></td></tr>`).join('')}</table>`;
    if (a.fpms_adicionar.length) h += `<p>Pacotes Unicon para incluir na imagem: ${a.fpms_adicionar.map(f => `<code>${esc(f)}</code>`).join(', ')}</p>`;
    if (a.unidades.length) h += `<h3>Serviços systemd</h3><table><tr><th>Unidade</th><th>WantedBy</th><th>Habilitada no pacote</th></tr>${a.unidades.map(u =>
      `<tr><td><code>${esc(u.arquivo)}</code></td><td>${esc(u.wantedby.join(' '))}</td><td>${u.habilitada ? 'sim' : 'não (a conversão habilita)'}</td></tr>`).join('')}</table>`;
    if (a.atalhos.length) h += `<h3>Atalhos (.desktop) → app local no Scout</h3><table><tr><th>Nome</th><th>Comando (Parâmetro do app local)</th></tr>${a.atalhos.map(s =>
      `<tr><td>${esc(s.nome)}</td><td><code>${esc(s.exec)}</code></td></tr>`).join('')}</table>`;
    else if (a.executaveis.length) h += `<h3>Executáveis</h3><p>${a.executaveis.slice(0, 20).map(x => `<code>${esc(x)}</code>`).join(' ')}</p>`;
    if (t.meta?.depends) h += `<details><summary>Dependências declaradas no .deb</summary><p><code>${esc(t.meta.depends)}</code></p><p class="sutil">Referência apenas: a análise das bibliotecas acima é o que vale no eLux.</p></details>`;
    if (a.conflitos.length) h += `<details><summary>Conflitos com pacotes do eLux (${a.conflitos.length})</summary><table><tr><th>Arquivo</th><th>Já existe em</th></tr>${a.conflitos.map(c =>
      `<tr><td><code>${esc(c.arquivo)}</code></td><td><code>${esc(c.fpm)}</code></td></tr>`).join('')}</table></details>`;
    for (const [n, s] of Object.entries(t.meta?.scripts || {})) h += `<details><summary>Script: ${esc(n)}</summary><pre>${esc(s)}</pre></details>`;
  }
  h += '</div>';
  if (a && !em) {
    const op = t.pedido?.opcoes || {};
    const ck = (k, txt) => `<label><input type="checkbox" name="${k}" ${op[k] === false ? '' : 'checked'}> <span>${txt}</span></label>`;
    h += `<form class="cartao" id="form-conv"><h2>2. Converter</h2>
      <div class="form-conv"><label>Nome do pacote<input name="nome" value="${esc(t.nome)}" maxlength="40"></label>
      <label>Versão<input name="versao" value="${esc(t.versao)}"></label>
      <label>Resumo<input name="resumo" value="${esc(t.resumo || '')}" maxlength="80"></label></div>
      <div class="opcoes">${ck('embutir', 'Embutir do Ubuntu 22.04 as bibliotecas que faltam no eLux (em <code>/opt/&lt;nome&gt;/lib-ubuntu</code>, com RUNPATH ajustado)')}
      ${ck('servicos', 'Habilitar os serviços systemd que o pacote traz (WantedBy)')}
      ${ck('sem_docs', 'Tirar documentação e manuais (/usr/share/doc, man, info) para economizar espaço')}</div>
      <div class="botoes"><button type="submit">${t.estado === 'pronto' ? 'Converter de novo' : 'Converter para Unicon'}</button>
      <button type="button" class="sec" id="reanalisar">Analisar de novo com a imagem</button><select id="re-imagem" style="width:auto"></select>
      <button type="button" class="perigo" id="apagar">Apagar</button></div></form>`;
  }
  if (t.estado === 'pronto' && t.saida) {
    const f = t.feito || {};
    h += `<div class="cartao"><h2>3. Baixar</h2><div class="botoes">
      <a href="${API}/trabalhos/${t.id}/baixar/zip"><button type="button">Baixar .zip para o ELIAS</button></a>
      <a href="${API}/trabalhos/${t.id}/baixar/epm"><button type="button" class="sec">.epm</button></a>
      <a href="${API}/trabalhos/${t.id}/baixar/fpm"><button type="button" class="sec">.fpm (${t.saida.fpm_mb} MB)</button></a>
      <a href="${API}/trabalhos/${t.id}/baixar/relatorio"><button type="button" class="sec">Relatório .json</button></a></div>`;
    if (Object.keys(f.embutidas || {}).length) h += `<h3>Embutidas do Ubuntu 22.04</h3><p>${Object.entries(f.embutidas).map(([s, p]) => `<code>${esc(s)}</code> <span class="sutil">(${esc(p)})</span>`).join(', ')}</p>`;
    if ((f.nao_achadas || []).length) h += `<div class="caixa ruim"><b>Não encontradas nem no Ubuntu:</b> ${f.nao_achadas.map(s => `<code>${esc(s)}</code>`).join(', ')}. O programa pode não abrir.</div>`;
    if ((f.servicos || []).length) h += `<p>Serviços habilitados: ${f.servicos.map(s => `<code>${esc(s)}</code>`).join(', ')}</p>`;
    h += `<h3>Próximos passos</h3><ol>
      <li>No ELIAS, <b>importe</b> o .zip (Pacotes → Importar).</li>
      <li>Crie a imagem com o pacote${t.analise.fpms_adicionar.length ? ' e os pacotes Unicon que ele precisa' : ''} no bloco <b>4. Criar a imagem</b> abaixo.</li>
      <li>No Scout, aponte a OU para a imagem nova${t.analise.atalhos.length ? ' e crie um app local com o comando do atalho' : ''}, depois Deliver software e Update software.</li></ol></div>`;
    h += renderImagem(t);
  }
  if (t.log) h += `<details class="cartao"><summary>Log</summary><pre>${esc(t.log)}</pre><a href="${API}/trabalhos/${t.id}/baixar/log">baixar log</a></details>`;
  return h;
}

function renderImagem(t) {
  const r = t.imagem_criada, p = t.pedido_imagem || {};
  let h = `<form class="cartao" id="form-imagem"><h2>4. Criar a imagem no ELIAS</h2>
    <p class="sutil">A imagem nova é a de origem + <code>${esc(t.nome)}</code>${t.analise.fpms_adicionar.length ? ' + ' + t.analise.fpms_adicionar.map(f => `<code>${esc(f)}</code>`).join(', ') : ''}, com as dependências resolvidas. Ganha o próximo número livre e não substitui nenhuma imagem.</p>
    <label>Imagem de origem (use a da OU onde o pacote vai rodar)<select name="de" id="img-de">${opcoesImagem(p.de || t.imagem)}</select></label>
    <p class="info-imagem" id="img-de-info"></p>
    <div class="opcoes">
      <label><input type="checkbox" name="reparar" ${p.reparar === false ? '' : 'checked'}> <span>Reparar antes as imagens em uso que deram 404 (a importação de pacote no ELIAS derruba as imagens existentes; são remontadas com a mesma seleção)</span></label>
      <label><input type="checkbox" name="forcar" ${p.forcar ? 'checked' : ''}> <span>Criar mesmo acima de 3.700 MB (não cabe em eLux de dual-boot/pendrive, como o Notebook-Wagner)</span></label></div>
    <div class="botoes"><button type="submit">Criar imagem no ELIAS</button></div>`;
  if (t.imagem_erro) h += `<div class="caixa ruim"><b>Não criada:</b> ${esc(t.imagem_erro)}</div>`;
  if (r) {
    const bom = !r.conflito && !r.faltando && r.download === 200;
    h += `<div class="caixa ${bom ? 'ok' : 'ruim'}"><b>${bom ? 'Imagem criada' : 'Imagem criada com problema'}: <code>${esc(r.nome)}</code></b> · ${r.mb.toLocaleString('pt-BR')} MB · de ${esc(r.de)}
      · conflitos ${r.conflito ? '<b>sim</b>' : 'não'} · pacotes faltando ${r.faltando ? '<b>sim</b>' : 'não'} · download ${r.download === 200 ? 'ok' : '<b>' + esc(r.download) + '</b>'}${r.mb > 3700 ? ' · <b>acima de 3.700 MB</b>' : ''}</div>`;
    if (r.adicionados?.length) h += `<details><summary>Pacotes que entraram além da imagem de origem (${r.adicionados.length})</summary><p>${r.adicionados.map(x => `<code>${esc(x)}</code>`).join('<br>')}</p></details>`;
    if (r.reparadas?.length) h += `<p>Imagens em uso reparadas (voltaram a baixar): ${r.reparadas.map(x => `<code>${esc(x)}</code>`).join(', ')}</p>`;
    if (r.reparo_falhou?.length) h += `<div class="caixa atencao"><b>Reparo não feito:</b> ${r.reparo_falhou.map(esc).join('; ')}</div>`;
    h += `<h3>No Scout</h3><ol><li>Faça o backup do banco.</li><li>Clique com o botão direito na OU → <b>Setup</b> → aba <b>Firmware</b> → em <b>Image file</b> coloque <code>${esc(r.nome)}</code> → OK.</li>
      <li>Crie o app local${t.analise.atalhos.length ? ' com o comando do atalho (tabela acima)' : ''} na OU, se ainda não existir.</li><li>Nos aparelhos da OU: <b>Deliver software</b> e depois <b>Update software</b>; reinicie.</li>
      <li>No servidor, rode <code>C:\\ScoutSetup\\scripts\\imagens-uso.ps1</code> para o SDK saber que a OU mudou de imagem.</li></ol>`;
  }
  h += `<details><summary>Fazer pelo PowerShell</summary><pre>${esc(t.comando_imagem)}</pre></details></form>`;
  return h;
}

function renderDriver(d, ehDriver) {
  if (!d || (!d.tipos.length && !ehDriver)) return '';
  let h = `<h3>Peças de driver</h3><p>${d.tipos.length ? d.tipos.map(x => selo('info', x)).join(' ') : '<span class="sutil">Nenhuma encontrada.</span>'}
    <span class="sutil"> · kernel do eLux <code>${esc(d.kernel_elux || '?')}</code></span></p>`;
  if (d.modulos.length) h += `<div class="rolagem"><table><tr><th>Módulo do kernel</th><th>Compilado para</th><th>No eLux</th></tr>${d.modulos.map(m =>
    `<tr><td><code>${esc(m.arquivo)}</code></td><td><code>${esc(m.vermagic || 'não identificado')}</code></td><td>${m.compativel ? selo('ok', m.pasta_ok ? 'carrega' : 'carrega (mover pasta)') : selo('faltando', 'não carrega')}</td></tr>`).join('')}</table></div>`;
  const grupo = (titulo, l) => l.length ? `<details><summary>${titulo} (${l.length})</summary><p>${l.map(x => `<code>${esc(x)}</code>`).join('<br>')}</p></details>` : '';
  h += grupo('Código-fonte DKMS', d.dkms) + grupo('Firmware', d.firmware) + grupo('Regras udev', d.udev) + grupo('modprobe / modules-load', d.modprobe)
    + grupo('Filtros e backends CUPS', d.cups) + grupo('PPDs de impressora', d.ppd) + grupo('Scanner (SANE)', d.sane);
  return h;
}

function ligar(t) {
  const fi = $('#form-imagem');
  if (fi) {
    const mostrar = () => infoImagem($('#img-de').value, $('#img-de-info'));
    $('#img-de').onchange = mostrar; mostrar();
    fi.addEventListener('submit', async ev => {
      ev.preventDefault();
      const de = $('#img-de').value;
      if (!confirm(`Criar no ELIAS a próxima imagem a partir da ${de} + ${t.nome}?${fi.elements.reparar.checked ? '\n\nAntes, as imagens em uso que estiverem dando 404 serão regravadas com a mesma seleção.' : ''}`)) return;
      try { await post(`/trabalhos/${t.id}/imagem`, { de, reparar: fi.elements.reparar.checked, forcar: fi.elements.forcar.checked }); abrir(t.id); listar(); } catch (e) { alert(e.message); }
    });
  }
  const f = $('#form-conv');
  if (!f) return;
  api('/estado').then(e => { estadoSrv = e; $('#re-imagem').innerHTML = opcoesImagem(t.imagem); });
  f.addEventListener('submit', async ev => {
    ev.preventDefault();
    const d = Object.fromEntries(new FormData(f));
    ['embutir', 'servicos', 'sem_docs'].forEach(k => d[k] = f.elements[k].checked);
    try { await post(`/trabalhos/${t.id}/converter`, d); abrir(t.id); listar(); } catch (e) { alert(e.message); }
  });
  $('#reanalisar').onclick = async () => { await post(`/trabalhos/${t.id}/analisar`, { imagem: $('#re-imagem').value, nome: f.elements.nome.value }); abrir(t.id); listar(); };
  $('#apagar').onclick = async () => {
    if (!confirm('Apagar este trabalho e os arquivos dele?')) return;
    try { await api(`/trabalhos/${t.id}`, { method: 'DELETE' }); atual = null; $('#detalhe').hidden = true; $('#vazio').hidden = false; listar(); } catch (e) { alert(e.message); }
  };
}

iniciar().catch(() => { });
