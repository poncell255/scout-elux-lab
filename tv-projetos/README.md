# TV Projetos — parede de 6 TVs com eLux

Um PC (2x NVIDIA Quadro P620, 6 TVs LG SIGNAGE 1920x1080) com eLux 7 mostra 6 páginas do PopulosHub, cada uma em tela cheia numa TV, com login automático.

## Peças

| Arquivo | Onde fica | Função |
|---|---|---|
| `iis/web.config` | `C:\inetpub\tvprojetos\` (site IIS "TV Projetos", porta 8090) | Proxy reverso (ARR + URL Rewrite) para o PopulosHub; injeta `/tv/tv.js` logo após `<head>`; tira `Secure` do cookie de sessão (proxy HTTP). Exige `HTTP_ACCEPT_ENCODING` e `HTTP_X_ORIGINAL_ACCEPT_ENCODING` em `allowedServerVariables` (APPHOST) e firewall TCP 8090. |
| `iis/tv/tv.js` | `C:\inetpub\tvprojetos\tv\` | Lê `#tv&d=<página>&u=&p=&pg=<aba>`; faz login local (`/api/login`) quando `/api/me` cai; volta para a página `d` (sem sessão o hub redireciona para `/`); no portfólio clica `#nextBtn` até a aba; simula a tela cheia e chama o `toggleFullscreen()` da página (as páginas só atualizam sozinhas com `document.fullscreenElement`); recarrega a cada 5 min se o hub responder. |
| `start-tv.example.sh` | eLux `/setup/tv/start-tv.sh` (FileEntry da OU) | Abre 6 Edge `--kiosk` com perfis separados, cada um numa posição da área 5760x2160 (`TELAS`); posiciona as saídas com `xrandr` (`LAYOUT`) e refaz a grade + reabre as janelas se o eLux clonar as telas; `xset s off -dpms`; reabre janela que fechar. Troque `<usuario>`/`<senha-url-encoded>`. |
| `20-tv-mosaic.conf` | eLux `/setup/X11/xorg.conf.d/` (FileEntry da OU) | Xorg: `AutoAddGPU false`, `BaseMosaic` na placa `PCI:1:0:0`, `MetaModes` com as 6 saídas (GPU-0 em cima, GPU-1 embaixo). |

## Scout

- OU com setup próprio **sem AD**, `UseParentApps=0`, app local `/bin/bash /setup/tv/start-tv.sh` com `AutoStart=1` e `TM=1`, `ShowTaskbar=0`, IniEntry `/setup/terminal.ini [Screen] AutomaticLayoutAdjustment=false`.
- Imagem `populos-elux7-v5` = v4 + EPM `nvidia_driver` (580.173.02). Sem ele o eLux usa `nouveau` sem aceleração e só acende 3 TVs.
- Scripts: `scripts/criar-ou-tv-projetos.ps1` (cria tudo) e `scripts/tv-projetos-arquivos.ps1` (reentrega os arquivos com `TimeModified` novo).

## Ordem atual das telas (posição na área 5760x2160)

| | x 0 | x 1920 | x 3840 |
|---|---|---|---|
| **y 0** | portfólio 3/3 | mapa de calor | time |
| **y 1080** | viagens | portfólio 2/3 | portfólio 1/3 |

## Problemas conhecidos

- As 6 TVs têm EDID idêntico: o eLux as trata como um monitor e as clona ao reconfigurar as telas (boot, nova configuração do Scout). O `start-tv.sh` corrige em até ~40 s, com uma piscada.
- Testar sem o eLux: Edge headless no servidor com `--enable-logging=stderr` e procurar `[tv]` no log.
