# Fase 18 — Pacotes próprios com o SDK da Unicon

Objetivo: criar pacotes eLux (EPM/FPM) que não existem no catálogo oficial e colocá-los nas imagens. No projeto: impressão digital (`populos_digital`), ajustes do Edge e do VS Code (`populos_ajustes`), VS Code nativo (`populos_vscode`) e GLPI Agent (`populos_glpi`).

## 18.1 Preparar o WSL2 no Windows Server

1. Habilite os recursos (o servidor **reinicia**):
   ```powershell
   dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   Restart-Computer
   ```
2. Instale o MSI do WSL baixado do GitHub `microsoft/WSL` (o `wsl.exe` nativo do Windows Server é só um atalho e não instala distribuições).
3. Instale o Ubuntu 22.04 (mesma base do UniconOS 2609):
   ```powershell
   wsl --install -d Ubuntu-22.04
   ```
4. Copie o conteúdo do SDK para `C:\UniconSDK\zip\` (descompacte `UniconOS.2609.SdkDockerEnv.zip`) e os scripts para `C:\UniconSDK\scripts\`. Leia o `sdk-and-epkg-doc.html` que vem no ZIP.
5. Rode os scripts como root no Ubuntu. A partir do Windows:
   ```powershell
   wsl -d Ubuntu-22.04 -u root -- bash /mnt/c/UniconSDK/scripts/01-preparar-wsl.sh
   wsl -d Ubuntu-22.04 -u root -- bash /mnt/c/UniconSDK/scripts/02-carregar-sdk.sh
   ```
   - `01-preparar-wsl.sh`: instala Docker (`docker.io`), compiladores, `libfprint-2-dev`, `libgtk-3-dev`.
   - `02-carregar-sdk.sh`: `docker load` da imagem `uniconos7-sdk-epkg-7.2609.0-5.tar.xz`, grava o nome da imagem em `/root/epkg-image` e monta um pacote de teste.
   - No Git Bash, prefixe os comandos com `MSYS_NO_PATHCONV=1`, senão os caminhos `/mnt/c/...` são convertidos.

**Validação:** o pacote de teste sai em `output/container/` com um `.epm` e um `.fpm`.

## 18.2 Como um pacote é montado

Todos os scripts de build seguem o mesmo molde (veja `15-build-ajustes.sh` e `24-build-glpi.sh`):

1. `epkg New --epm <nome_epm> --fpms <nome_fpm>` cria o esqueleto (`input/ebkepm` + uma pasta por FPM).
2. O arquivo `input/ebkepm` recebe categoria, resumo, versão, fornecedor (`vendor`) e `installoption=2`.
3. Os arquivos vão para `input/<fpm>/` exatamente no caminho em que devem ficar no eLux (ex.: `input/populos_glpi_agent/usr/bin/...`).
4. `elux/<fpm>.postCommands` ajusta permissões (`chmod`) e cria links; `elux/<fpm>.postInst` roda na instalação.
5. `epkg Build --container elux7 --releaseType test --skipSign` gera `output/container/*/*.epm` e `*.fpm`, que o script copia para `C:\UniconSDK\saida\`.

Pontos do `epkg` que custaram tempo:

| Armadilha | Como evitar |
|---|---|
| A imagem do SDK não traz repositórios Debian | Baixe os `.deb` (`apt-get download`) e use a pasta `.thirdparty`, como no exemplo da Unicon |
| Nome do FPM igual ao do EPM | Use nomes diferentes (`populos_glpi` / `populos_glpi_agent`) |
| Diretório no `.install` não copia nada | Liste arquivo por arquivo (`*` é curinga simples) |
| `%` em nome de arquivo (ex.: `%3a` dos `.deb` do Ubuntu) | Renomeie: o `epkg` usa `%variavel%` |
| Arquivos com final de linha do Windows (CRLF) | Converta para LF antes do build (`sed -i 's/\r$//'`) |
| Dependências automáticas do RPM | O spec gerado já vem com `Autoreqprov: no`; confira com `25-checar-fpm.sh` |

## 18.3 Pacotes do projeto

| Script | Pacote | Conteúdo |
|---|---|---|
| `04-compilar-digital.sh`, `17-build-digital.sh <versão>` | `populos_digital` (FPM `populos_digital_portao`) | Programa em C + GTK3 + libfprint 1.94 (`pkgs/populos_digital/src/populos-digital.c`), regra udev do leitor 05BA:000A, `tmpfiles.d`, `login.d/25-populos-digital`, app de cadastro `populos-digital-cadastro` |
| `15-build-ajustes.sh <versão>` | `populos_ajustes` (FPMs `populos_edge_persistente`, `populos_claude_code`) | Troca o `logout.d/95-microsoft-edge-clean-userdata` do Edge para não apagar o perfil; wrapper `/usr/bin/populos-claude-wrapper` e lançador `/usr/bin/populos-code` |
| `12-build-vscode.sh` | `populos_vscode` (FPM `populos_vscode_app`) | VS Code oficial enxuto, com `persistentdirs` para `.config/Code` e `.vscode` (675 MB) |
| `22-glpi-agent-baixar.sh`, `24-build-glpi.sh <versão>` | `populos_glpi` (FPM `populos_glpi_agent`) | GLPI Agent (Fase 20) |
| `16-teste-xvfb.sh`, `18-preview.sh`, `20-preview.sh` | — | Prévia da tela da digital em Xvfb (use `GDK_BACKEND=x11`; o WSLg rouba a janela) |

## 18.4 Importar no ELIAS 18

1. Junte os `.epm`/`.fpm` num ZIP (mesmo formato do "AllPackages" da Unicon).
2. Login na API e importação (multipart, campo `file`):
   ```powershell
   $base = "http://localhost/ELIAS/api/UC_RP6_X64/v1.0"; $jar = "C:\ScoutSetup\elias_cj.txt"
   # login: POST $base/authenticate/ com {"user":"admin","domain":"","password":"<SENHA_ELIAS_ADMIN>"} (cookie em $jar)
   curl.exe -s -b $jar -D cab.txt -X POST "$base/import/pacotes.zip" -F "file=@pacotes.zip;filename=pacotes.zip;type=application/zip"
   # cabeçalho UUID: <uuid>  →  GET $base/checkimport/<uuid> até "status":"finished"
   ```
   Enviar o arquivo como corpo bruto dá "Unsupported Media Type". Pacotes sem assinatura aparecem como `noSig` e são aceitos.
3. Atualize o catálogo local (`GET .../epms` e `.../fpms` → `C:\ScoutSetup\diag\elias-epms.json` e `elias-fpms.json`).
4. Monte a imagem: `scripts\montar-idf.ps1` (escolhe a versão mais nova de cada EPM) ou `scripts\imagem-derivada.ps1` (Fase 20).
5. Scout: `Setup.ImageFile` → **Deliver software** (sem formatar) → **Update software**.

## 18.5 Observações do UniconOS 2609

- Sessões rodam como o usuário `elux`; o `login.d/20-userauth` coloca o usuário do AD em `$USER`. Os scripts de `login.d` são carregados com `source`: use `return`, não `exit`.
- Encerrar sessão: `ucsettingsctl --run Session.Close`; desligar: `Session.Shutdown`.
- A home **não permite executar programas**. `/setup` é persistente e pertence ao root (use `tmpfiles.d` para criar pastas do usuário).
- Partições têm tamanho fixo definido na instalação. Confira `Device.PartitionInfo` antes de colocar pacotes grandes.
- A próxima versão do UniconOS (7.2612, base Ubuntu 26.04) exige reconstruir os pacotes com o SDK novo.

## 18.6 OU Populos Dev: digital como 2º fator

1. Imagem com `populos_digital`, `populos_ajustes` e o FPM `baseos_persistent_home`.
2. Apps na OU: "Cadastrar digital" (`/usr/bin/populos-digital-cadastro`).
3. Regra USB do Citrix (`/setup/ica/usb.conf` com `CONNECT: vid=05ba pid=000a`) só se o leitor também for usado dentro da sessão Citrix: enquanto a sessão estiver aberta, ela "pega" o leitor.
4. Teste: login AD → cadastro da digital no 1º acesso → nos próximos, a digital é pedida depois do AD; 5 erros ou "Encerrar sessão" encerram a sessão. O arquivo `/setup/populos-digital/DESATIVADO` desliga a verificação.
