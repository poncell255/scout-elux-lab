# Pacotes próprios para o UniconOS (eLux 7) com o SDK da Unicon

Pacotes POPULOS montados com o **UniconOS 2609 SDK** (`epkg` em Docker), importados no ELIAS 18 e entregues pelo Scout na OU Populos Dev.

| EPM | FPM | Função |
|---|---|---|
| `populos_digital` | `populos_digital_portao` | 2º fator por impressão digital depois do login do AD (leitor HID DigitalPersona U.are.U 4500). Programa em C + GTK3 + libfprint 1.94 (`pkgs/populos_digital/src/populos-digital.c`), regra udev, `tmpfiles.d` e `login.d/25-populos-digital`. |
| `populos_vscode` | `populos_vscode_app` | VS Code oficial (`.deb` da Microsoft) sem Copilot embutido, Mermaid, code-tunnel e idiomas extras; `persistentdirs` para `.config/Code` e `.vscode`. |
| `populos_ajustes` | `populos_edge_persistente` | Substitui `logout.d/95-microsoft-edge-clean-userdata` do pacote do Edge (`corrupts=microsoft_edge_stable`) para não apagar o perfil quando a home persistente está ligada. |
| `populos_ajustes` | `populos_claude_code` | `populos-claude-wrapper` + `login.d/26-populos-vscode-claude`: a extensão do Claude Code roda mesmo com a home sem permissão de execução. |

## Ambiente de construção

- WSL2 com Ubuntu 22.04 (a base do UniconOS 2609) no Windows Server: instalar o MSI do WSL do GitHub da Microsoft (o `wsl.exe` do Windows Server é só um atalho) e `wsl --install -d Ubuntu-22.04`.
- `scripts/01-preparar-wsl.sh`: Docker, compiladores, `libfprint-2-dev`, `libgtk-3-dev`.
- `scripts/02-carregar-sdk.sh`: `docker load` da imagem `uniconos7-sdk-epkg-<versão>.tar.xz` (vem no ZIP do SDK, enviado pela Unicon por e-mail) e um pacote de teste.
- Rodar a partir do Windows: `wsl -d Ubuntu-22.04 -u root -- bash /mnt/c/UniconSDK/scripts/<script>.sh` (no Git Bash, prefixar `MSYS_NO_PATHCONV=1`).

## Construir

| Script | O que faz |
|---|---|
| `04-compilar-digital.sh` | Compila `populos-digital` e mostra as bibliotecas |
| `05-faltantes.sh` / `06-vscode-deps.sh` | Comparam as bibliotecas com a lista de arquivos da imagem do eLux (gerada do catálogo do ELIAS) |
| `10-build-digital-ajustes.sh` | Monta `populos_digital` (e a 1ª versão de `populos_ajustes`) |
| `12-build-vscode.sh` | Monta `populos_vscode` com lista explícita de arquivos |
| `15-build-ajustes.sh <versão>` | Monta `populos_ajustes` (Edge + Claude Code) |

Pontos do `epkg` que custaram tempo:
- A imagem não traz repositórios Debian (`/usr/share/unicon/suiteCPP.ini` ausente): use `.deb` baixados (`apt-get download`) em `.thirdparty`, como no exemplo da Unicon.
- O nome do FPM não pode ser igual ao do EPM.
- `.install` lista arquivo por arquivo (um diretório sozinho não copia nada; `*` é curinga simples).
- Evite `%` em nomes de arquivo (`%3a` dos `.deb` do Ubuntu): o `epkg` usa `%variavel%`.

## Importar no ELIAS 18 e montar a imagem

1. ZIP com os `.epm`/`.fpm` (o mesmo formato do "AllPackages" da Unicon).
2. `POST /ELIAS/api/<container>/v1.0/import/<nome>.zip` (multipart, campo `file`, cookie de login) → cabeçalho `UUID` → `GET .../checkimport/<uuid>` até `finished`. Pacotes sem assinatura aparecem como `noSig`.
3. Atualizar o catálogo local e montar a IDF com `scripts/montar-idf.ps1 -AddEpms ...,populos_digital,populos_vscode,populos_ajustes` (escolhe a versão mais nova de cada EPM).
4. Scout: `Setup.ImageFile` da OU → **Deliver software** (padrão, sem formatar) → **Update software**.

## Observações do UniconOS 2609

- Sessões rodam como usuário `elux`; `20-userauth` coloca o usuário do AD em `$USER`.
- `ucsettingsctl --run Session.Close` encerra a sessão; `soft-logoff` só reinicia os apps.
- A home não permite executar programas; `/setup` é persistente e do root (use `tmpfiles.d` para criar pastas do usuário).
- Partições têm tamanho fixo definido na instalação (eLux instalado a partir de pendrive fica com `custom` de 3,75 GB; instalado em disco grande, dezenas de GB).
- A próxima versão do UniconOS (7.2612, Ubuntu 26.04) exige reconstruir os pacotes com o SDK novo (`osEdition`).
