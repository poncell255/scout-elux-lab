# Populos UniconOS SDK (Conversor Unicon)

Página web que transforma programas e drivers para Ubuntu em pacotes eLux/UniconOS 7 (EPM/FPM): **http://10.5.0.166/conversor/**.

Tem duas áreas com o mesmo motor, como a Citrix separa produto de software e de drivers:
- **Software** (`/conversor/#software`);
- **Drivers** (`/conversor/#drivers`). A análise destaca:
  - módulos `.ko`/`.ko.xz`, com o kernel para o qual foram compilados (`vermagic`) contra o kernel do eLux (`6.18.48unicon0`, lido do FPM `kernelimage`). Módulo de outro kernel não carrega;
  - código-fonte DKMS, que não compila no aparelho;
  - firmware, regras udev, `modprobe.d`/`modules-load.d`;
  - filtros, backends e PPDs CUPS, que pedem `baseprinter_cupsbin`/`cupsfilter` na imagem;
  - backends SANE, que pedem `sane_base`.

Cada trabalho guarda a `categoria` (`software` ou `driver`), e a lista mostra só os trabalhos da área aberta. Visual no padrão dos papéis de parede "Secure Endpoint" (azul-marinho com losangos), com os logos POPULOS (`static/populos-branco.png`) e Citrix.

O login pede a senha do rótulo **Conversor Unicon admin** em `C:\ScoutSetup\credenciais.txt`.

## O que faz

1. **Enviar:** aceita `.deb`, `.AppImage`, `.run` (makeself), `.tar.gz`/`.tar.xz`/`.zip` ou um binário ELF, até 2 GB.
   - Um `.tar`/`.zip` com vários `.deb` dentro, como o `LibreOffice_*_deb.tar.gz`, tem todos os `.deb` abertos na mesma árvore.
   - Nada do que é enviado é executado: o arquivo só é aberto e analisado.
2. **Analisar** contra a imagem escolhida (padrão v22). Cada biblioteca (`NEEDED`) de cada binário cai em uma de quatro situações:
   - **no programa:** já vem dentro do próprio pacote;
   - **na imagem:** um FPM da imagem já tem a biblioteca;
   - **pacote Unicon:** existe um FPM no ELIAS que tem a biblioteca, mas ele não está na imagem;
   - **falta no eLux:** nenhum pacote Unicon tem a biblioteca.

   A análise também mostra:
   - interpretadores de scripts (`#!`);
   - GLIBC exigida contra a do eLux (2.35);
   - binários que não são x86-64;
   - arquivos que já existem em pacotes do eLux (conflito no ELIAS);
   - scripts de instalação do `.deb` ou `.run`, que não rodam no eLux;
   - serviços systemd e atalhos `.desktop`, com o comando para o app local no Scout;
   - tamanho total contra o limite de 3.700 MB.
3. **Converter:**
   - parte sempre de uma extração limpa;
   - opcionalmente embute do Ubuntu 22.04 as bibliotecas que faltam, recursivamente. Elas vão para `/opt/<nome>/lib-ubuntu`, buscadas com `apt-file` e `apt-get download` e ligadas por RPATH com `patchelf`;
   - habilita os serviços (`WantedBy`) e tira docs e manuais;
   - gera o EPM/FPM com o container oficial `citrix/uniconos7-sdk-epkg`.
   - Os nomes ganham o prefixo `populos_`, para não colidir com os EPMs da Unicon.
4. **Criar a imagem:** botão no trabalho pronto (`app/imagem.py`, porta Python do `imagem-derivada.ps1`/`montar-idf.ps1`/`reparar-idfs.ps1`; o serviço no WSL não alcança o PowerShell do Windows). Confere se a versão importada no ELIAS é a da conversão, repara as imagens em uso que dão 404, recusa imagem acima de 3.700 MB sem confirmação e testa o download. `tests/teste_imagem.py` confere a porta contra imagens existentes.
5. **Baixar:** `.zip` para importar no ELIAS, `.epm`, `.fpm`, relatório `.json` e log. A página também mostra o comando `imagem-derivada.ps1` com os pacotes Unicon que precisam entrar na imagem.

Os trabalhos ficam guardados por 7 dias.

## Onde fica

| Parte | Local |
|---|---|
| Código (Flask + waitress) | `C:\ScoutSetup\conversor\app` (`conversor.py`, `analise.py`, `empacotar.py`, `web/`) |
| Serviço no WSL | `conversor-unicon.service` (`deploy/`), porta 3200, roda como root (usa Docker e epkg) |
| Dados | `/root/conversor` no WSL: `trabalhos/`, `cache/debs`, `admin-auth.json` (PBKDF2), `segredo-sessao` |
| IIS | diretório virtual `/conversor` → `C:\inetpub\conversor\web.config` (rewrite para `localhost:3200`, upload até 2 GB). Proxy ARR com timeout de 30 min |
| Catálogo usado | `C:\ScoutSetup\diag\elias-fpms.json` e `idf-populos-v*.json` (atualizados por `import-package.ps1` e `imagem-derivada.ps1`) |
| Teste | `tests/teste_fluxo.py <arquivo> [imagem]` (WSL, root): login, envio, análise, conversão e download numa pasta temporária |

O WSL precisa estar ligado. A tarefa agendada **WSL GLPI** (`27-wsl-manter-ligado.sh`, `sleep infinity`) cuida disso. Se ela parar, o WSL desliga quando fica ocioso e leva o conversor, a sala de provas e o GLPI junto. Para religar: `Start-ScheduledTask 'WSL GLPI'`.

## Limites

- O `.run` não é instalado: o conteúdo vai para `/opt/<nome>`, e o script de instalação aparece no relatório para ser adaptado (como no `netskope-elux`).
- Os scripts `postinst` do `.deb` não rodam: o relatório mostra o que fazem.
- No eLux só são graváveis `/etc`, `/opt`, `/var`, `/root` e `/home/elux`, em RAM; `/setup` é persistente e pequena. Programas que gravam em `/usr` precisam de ajuste.
- A importação no ELIAS e a montagem da imagem continuam manuais. A página mostra os passos e o comando.
