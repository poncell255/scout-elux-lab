/* TV Projetos (eLux, OU "TV Projetos"): injetado pelo proxy do IIS antes dos scripts da página.
   URL de entrada: /<pagina>.html#tv&d=/<pagina>.html&u=<usuario>&p=<senha>&pg=<aba do portfólio>
   - guarda a configuração na sessionStorage da janela e limpa o hash;
   - faz o login local quando a sessão cai (ela dura 12 h);
   - no portfólio, avança até a aba pedida (1/3, 2/3, 3/3);
   - aciona o botão "Tela cheia" da própria página. A janela já está em quiosque, então a tela cheia
     é simulada: o navegador só permite a real com clique, e as páginas só atualizam os dados
     sozinhas quando document.fullscreenElement está preenchido;
   - recarrega a página a cada 5 minutos, se o hub estiver respondendo. */
(function () {
  var cfg = null;
  try { cfg = JSON.parse(sessionStorage.getItem('tvProjetos') || 'null'); } catch (e) {}
  if (/^#tv(&|$)/.test(location.hash)) {
    var q = new URLSearchParams(location.hash.slice(1));
    cfg = { u: q.get('u') || '', p: q.get('p') || '', pg: parseInt(q.get('pg') || '1', 10) || 1,
      // sem sessão o hub redireciona no servidor para "/", então o destino vem no hash (d=)
      pagina: q.get('d') || location.pathname };
    try { sessionStorage.setItem('tvProjetos', JSON.stringify(cfg)); } catch (e) {}
    history.replaceState(null, '', location.pathname + location.search);
  }
  if (!cfg) return;

  // Tela cheia simulada: nunca sai, e avisa a página como se tivesse entrado.
  var fsEl = null;
  function avisar() {
    document.dispatchEvent(new Event('fullscreenchange'));
    window.dispatchEvent(new Event('resize'));
  }
  try {
    Object.defineProperty(Document.prototype, 'fullscreenElement', { configurable: true, get: function () { return fsEl; } });
    Object.defineProperty(Document.prototype, 'webkitFullscreenElement', { configurable: true, get: function () { return fsEl; } });
  } catch (e) {}
  Element.prototype.requestFullscreen = function () { fsEl = this; setTimeout(avisar, 0); return Promise.resolve(); };
  Document.prototype.exitFullscreen = function () { return Promise.resolve(); };

  function log(m) { try { console.log('[tv] ' + m); } catch (e) {} }

  async function autenticado() {
    try {
      var r = await fetch('/api/me?ts=' + Date.now(), { cache: 'no-store', credentials: 'same-origin' });
      var j = await r.json();
      return !!j.isAuthenticated;
    } catch (e) { return null; } // rede fora: tenta de novo depois, sem recarregar
  }
  async function logar() {
    try {
      var r = await fetch('/api/login', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: cfg.u, password: cfg.p }) });
      return r.ok;
    } catch (e) { return false; }
  }
  async function garantirSessao() {
    var ok = await autenticado();
    if (ok === false) {
      log('sessão caiu, entrando de novo');
      // sem sessão o hub redireciona para "/", então volta para a página desta tela
      if (await logar()) { location.replace(cfg.pagina); }
      return false;
    }
    if (ok === true && location.pathname !== cfg.pagina) { location.replace(cfg.pagina); return false; }
    return ok === true;
  }

  function quando(teste, acao, limiteMs) {
    var fim = Date.now() + (limiteMs || 120000);
    (function tentar() {
      var ok = false;
      try { ok = teste(); } catch (e) {}
      if (ok) { acao(); return; }
      if (Date.now() < fim) setTimeout(tentar, 500);
    })();
  }

  function irParaAba() {
    if (cfg.pg <= 1) return;
    quando(function () {
      var t = document.getElementById('pageText');
      return t && /^\d+\/\d+$/.test(t.textContent.trim()) && document.querySelector('#portfolioGrid article');
    }, function () {
      var t = document.getElementById('pageText'), next = document.getElementById('nextBtn');
      var guarda = 10;
      while (guarda-- > 0) {
        var partes = t.textContent.trim().split('/'), atual = +partes[0], total = +partes[1];
        if (atual >= Math.min(cfg.pg, total) || !next || next.disabled) break;
        next.click();
      }
      log('aba ' + t.textContent.trim());
    });
  }

  function telaCheia() {
    quando(function () { return document.readyState === 'complete' && typeof window.toggleFullscreen === 'function'; }, function () {
      if (!document.fullscreenElement) window.toggleFullscreen();
      log('tela cheia');
    });
  }

  async function iniciar() {
    log('início em ' + location.pathname + ' (destino ' + cfg.pagina + ', aba ' + cfg.pg + ')');
    if (!(await garantirSessao())) { setTimeout(iniciar, 30000); return; }
    irParaAba();
    telaCheia();
  }

  window.addEventListener('load', iniciar);
  // a cada 5 min recarrega a página (dados novos, tela com erro), mas só se o hub responder:
  // sem rede, a página atual continua na tela em vez de virar a página de erro do navegador.
  // Depois da recarga este script refaz login, aba e tela cheia (a configuração fica na sessionStorage).
  setInterval(async function () {
    try {
      var r = await fetch(cfg.pagina + '?ts=' + Date.now(), { method: 'HEAD', cache: 'no-store', credentials: 'same-origin' });
      if (r.ok) { log('recarga de 5 min'); location.reload(); } else { log('hub respondeu ' + r.status + ', recarga adiada'); }
    } catch (e) { log('hub fora do ar, recarga adiada'); }
  }, 5 * 60 * 1000);
})();
