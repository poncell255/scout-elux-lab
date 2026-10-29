# Porto Local (teste): área do segurado no eLux

OU **Porto**, GroupID **11**, SetupID **7**, sem AD, imagem **populos-elux7-v36** (3.660 MB = v28 + `python3`/`python3_flask` + `populos_porto_local` 1.0.0). Mesmo modelo dos sistemas BTG e HAPVIDA Local, com conteúdo de seguros:

- **Tema `porto-v2`**: papel de parede no modelo do BTG (fundo azul-marinho, losangos azul Porto, logo Porto branco + "Secure Endpoint"). A pasta do tema é `C:\eLuxContainer\theme\porto` (o tema anterior está em `anterior-v1\`).
- **Cadastro de Segurados Porto** (app 100): abre `/usr/bin/porto-local-admin` (`http://127.0.0.1:3133/porto/admin`, usuário `admin`, senha no rótulo **Porto Local admin** de `C:\ScoutSetup\credenciais.txt`).
  - Cadastra o segurado com os seguros contratados (Auto; Auto + Residência; Auto + Residência + Vida), a foto (arquivo ou câmera) e a digital no leitor USB.
- **Meu Seguro Porto** (app 99): abre `/usr/bin/porto-local-cliente`.
  - O segurado coloca o dedo, é identificado e os seguros abrem numa janela do Edge.
  - A janela mostra as apólices (coberturas, franquia, assistência e vigência), os pagamentos e as solicitações.
  - As solicitações pendentes (orçamento de sinistro, guincho da Assistência 24h e renovação antecipada) são autorizadas ou recusadas, e cada decisão fica registrada como assinada pela digital naquele equipamento.
- Ícone dos dois apps: `porto.png` global (UCFT 707), o símbolo da Porto sem fundo.

Todos os dados são fictícios e as telas avisam isso. Cada aparelho guarda a própria base em `/setup/porto-local/dados`, sem sincronização entre aparelhos.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `app/` | Backend Flask (`app.py`, `run.py`) e páginas (`web/`) |
| `native/` | Tela GTK da digital (`porto-local-digital.c`) e cadastro (`porto-cadastrar-digital.c`); preferem o leitor U.are.U (`POPULOS_LEITOR` muda o driver) |
| `elux/` | Launchers `admin.sh` e `cliente.sh`, serviço systemd (porta 3133) e tmpfiles |
| `deploy/build-package.sh <versão>` | Compila no WSL (`wsl -u root`) e gera o EPM/FPM em `saida/` |
| `deploy/test-package.sh <versão>` | Confere atalhos, waitress e serviço no FPM |
| `deploy/import-package.ps1 -Versao <v>` | Importa o pacote no ELIAS e atualiza o catálogo |
| `deploy/atualizar-ou.ps1` | Aplicado em 29/10/2026 (backup antes); recusa rodar de novo se os apps já existirem |
| `deploy/test-isolated.sh` | 7 testes do backend com `--network none` |
| `tests/preview_server.py` | Servidor de prévia com dois segurados fictícios |
| `saida/imagens/` | Papel de parede, logos e ícone gerados |

## Implantar num aparelho

1. Mova o eLux para a OU **Porto** no Scout.
2. Clique em **Deliver software**, espere terminar e só então clique em **Update software**.
3. Reinicie duas vezes: a primeira aplica o tema e a segunda mostra o logo no boot.
4. Abra **Cadastro de Segurados Porto**, cadastre o segurado e capture a digital.
5. Abra **Meu Seguro Porto** e coloque o dedo no leitor.
