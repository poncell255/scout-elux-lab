# BTG Local (teste): agência digital no eLux

OU **BTG**, GroupID **15**, SetupID **11**, sem AD, imagem **populos-elux7-v35** (3.667 MB). É uma cópia da OU HAPVIDA Local com outra marca e outro conteúdo:

- **Tema `btg-v1`**: papel de parede BTG e logo btg na tela de boot. A pasta do tema é `C:\eLuxContainer\theme\btg`.
- **Azure Virtual Desktop** (app 98): usa o cliente oficial `ms_avd_client` com o feed `https://rdweb.wvd.microsoft.com/api/arm/feeddiscovery`. O usuário entra com a conta Microsoft Entra.
- **Cadastro de Clientes BTG** (app 97): abre `/usr/bin/btg-local-admin` (`http://127.0.0.1:3132/btg/admin`, usuário `admin`, senha no rótulo **BTG Local admin** de `C:\ScoutSetup\credenciais.txt`).
  - Abre a conta de teste com o perfil de investidor, a foto (arquivo ou câmera) e a digital no leitor USB.
- **Minha Conta BTG** (app 96): abre `/usr/bin/btg-local-cliente`.
  - O cliente coloca o dedo, é identificado e a conta abre numa janela do Edge.
  - A conta mostra saldo, investimentos, extrato e autorizações.
  - As operações pendentes (PIX, resgate e limite) são autorizadas ou recusadas, e cada decisão fica registrada como assinada pela digital naquele equipamento.
- Horizon não está nesta OU, para caber o cliente AVD.

Todos os dados são fictícios e as telas avisam isso. Cada aparelho guarda a própria base em `/setup/btg-local/dados`, sem sincronização entre aparelhos.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `app/` | Backend Flask (`app.py`, `run.py`) e páginas (`web/`) |
| `native/` | Tela GTK da digital (`btg-local-digital.c`) e cadastro (`btg-cadastrar-digital.c`); preferem o leitor U.are.U (`POPULOS_LEITOR` muda o driver) |
| `elux/` | Launchers `admin.sh` e `cliente.sh`, serviço systemd e tmpfiles |
| `deploy/build-package.sh <versão>` | Compila no WSL (`wsl -u root`) e gera o EPM/FPM em `saida/` |
| `deploy/import-package.ps1 -Versao <v>` | Importa o pacote no ELIAS e atualiza o catálogo |
| `deploy/create-ou.ps1` | Cria a OU (com backup do banco); recusa rodar se a OU BTG já existir |
| `deploy/test-isolated.sh` | 7 testes do backend com `--network none` |
| `tests/preview_server.py` | Servidor de prévia com dois clientes fictícios |

## Implantar num aparelho

1. Mova o eLux para a OU **BTG** no Scout.
2. Clique em **Deliver software**, espere terminar e só então clique em **Update software**.
3. Reinicie duas vezes: a primeira aplica o tema e a segunda mostra o logo no boot.
4. Abra **Cadastro de Clientes BTG**, crie o cliente e capture a digital.
5. Abra **Minha Conta BTG** e coloque o dedo no leitor.
