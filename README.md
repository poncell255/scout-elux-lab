# Scout Enterprise + ELIAS 18 + eLux 7 — laboratório POPULOS

Repositório para **recriar do zero** um ambiente de gerenciamento de thin clients eLux 7 com Citrix/Unicon Scout Enterprise num Windows Server (começou fora de domínio e depois entrou no AD `populos.local`), com login do Scout Board via Microsoft Entra ID, imagens de firmware montadas no ELIAS 18, temas por OU, login AD nos eLux e uma parede de 6 TVs (OU "TV Projetos").

> Escrito para ser seguido por uma pessoa **ou por outro agente de IA**.
> - **Agente de IA ou recém-chegado:** comece por **[docs/COMECE-AQUI-IA.md](docs/COMECE-AQUI-IA.md)**, que traz o modelo mental, a ordem de leitura, o mapa, as regras, o estado e um prompt pronto.
> - **Para implantar do zero:** siga o **[Guia de implantação](docs/GUIA-IMPLANTACAO.md)**, fases 1–31, com validação e solução de problemas.
> - **Versão resumida:** o [RUNBOOK](docs/RUNBOOK.md).

## O que este ambiente entrega

| Componente | Versão usada | Função |
|---|---|---|
| Windows Server 2025 (sem domínio) | 10.0.26100 | Host único |
| SQL Server Express | 2025 (17.0) | Banco `ScoutEnterprise` |
| Scout Enterprise Management Suite | 15.2609 (26.9.0) | Gerência dos eLux (Server, Console, Board, Keep Alive, Report, Recovery, ELIAS clássico) |
| Citrix License Server | 11.17.2 build 56200 | Licença do Scout via LAS (Citrix Cloud) |
| ELIAS 18 | 26.3.2 | Montagem das imagens (IDF) e servidor de firmware via IIS |
| eLux 7 | 7.2609 | Sistema dos thin clients |
| Microsoft Entra ID | — | Login do Scout Board (OIDC) |
| UniconOS SDK (`epkg`) | 7.2609.0-5 | Pacotes próprios (digital, ajustes, GLPI Agent) em Docker no WSL2 |
| GLPI | 12.0.0 (Docker) + GLPI Agent 1.21 | Inventário dos eLux |
| uberAgent | 8.0.7535 (EPM oficial) | Métricas para dois receptores Splunk HEC |
| Netskope Client | 142.1.0.2831 (empacotado do `.run`) | Segurança de rede nas OUs Populos, HAPVIDA e HAPVIDA Local |
| Python 3.10 + Flask | FPMs oficiais do catálogo | Sistemas locais dentro do eLux (HAPVIDA Local, BTG, Porto) |
| Populos UniconOS SDK | próprio (Flask no WSL, `/conversor`) | Converte programas e drivers Ubuntu em EPM/FPM e cria a imagem no ELIAS |

Resultado validado: eLux registrado no Scout; firmware atualizado pelas imagens `populos-elux7-v4` (geral) e `populos-elux7-v5` (v4 + driver NVIDIA, OU TV Projetos); temas por OU (papel de parede e logo na tela de boot); Outlook e Teams via Edge `--app`; Citrix Workspace (StoreFront); Horizon (Omnissa); OU de quiosque; **login AD (Kerberos) nos eLux** com OUs sem AD (Populos NonDomain, Modo Kiosk, TV Projetos); NTP; **mirror pelo Scout Board** com controle e sem pedir permissão; tela sempre ativa (sem bloqueio/suspensão); 2 monitores clonados; **6 TVs** com duas NVIDIA Quadro em Base Mosaic, cada uma com uma página do PopulosHub em quiosque, login automático e recarga a cada 5 min. Depois: OU Populos Dev (home persistente, OneDrive, digital como 2º fator); OU **Porto** sem AD, entrada só com a **impressão digital**, CXone e leitor de PDF; **Google Chrome** e **inventário no GLPI** em todas as OUs; **uberAgent** enviando para dois servidores; **Teams for Linux** (comunitário); **sala de provas** (OU "Provas": digital abre a prova de certificação Citrix ou Nutanix do aluno, com tempo e nota). Até 30/10, também:
- OU **HAPVIDA**, com o simulador de saúde no servidor;
- sistemas **locais** dentro do eLux, com cadastro, câmera e digital: **HAPVIDA Local**, **BTG** (com AVD) e **Porto**;
- **Netskope**;
- Word/Excel/PowerPoint web;
- temas "Secure Endpoint" por cliente;
- reparo automático das imagens do ELIAS;
- o **Populos UniconOS SDK**.

## Estrutura

```
README.md                        este arquivo
docs/COMECE-AQUI-IA.md           entrada para agentes de IA: modelo mental, mapa, regras, estado, prompt
docs/GUIA-IMPLANTACAO.md         guia completo de implantação do zero, fases 1–31
docs/CONTINUAR-COM-CODEX.md      estado vivo do laboratório original (IDs, imagens, pendências)
uniconos-sdk/                    pacotes próprios com o SDK da Unicon (digital, ajustes, GLPI, Teams) e scripts WSL
conversor/                       Populos UniconOS SDK: conversor web de programas/drivers + criação de imagem
apps-locais/                     sistemas que rodam no eLux (hapvida-local, btg-local, porto-local) e netskope-elux
apps-servidor/hapvida/           simulador de saúde HAPVIDA no servidor (OU HAPVIDA)
docs/RUNBOOK.md                  passo a passo resumido
docs/DB-REFERENCE.md             tabelas e códigos do banco do Scout (não documentados pela Citrix)
docs/LICOES.md                   armadilhas encontradas e como evitar
docs/HISTORICO.md                diário completo da implantação original (sanitizado)
scripts/                         PowerShell e SQL usados
tv-projetos/                     parede de 6 TVs: proxy IIS + tv.js, start-tv.sh, Xorg Base Mosaic (ver tv-projetos/README.md)
assets/themes/                   temas eLux prontos (Populos, Bom Jesus, Enterprise, Porto, BTG, HAPVIDA v4)
assets/icons/                    ícones 32x32 dos apps
provas/                          site de provas com digital (Flask em Docker) e script do eLux
manual/                          manual de implantação em Word/PDF e as fontes para gerá-lo
config/parametros.example.ps1    valores que mudam de um ambiente para outro
```

## Segredos

Nenhuma senha, chave ou token está neste repositório; todos viraram marcadores `<ASSIM>`. Os valores reais ficam no servidor, em `C:\ScoutSetup\credenciais.txt` (fora do Git, ACL só Administradores). Envie sempre com `scripts/continuar.ps1 push -Mensagem "..."`. Ele roda `verificar-segredos.ps1`, procura no repositório todos os valores do `credenciais.txt` e da lista de saneamento (`C:\ScoutSetup\saneamento.txt`, também fora do Git) e se recusa a enviar se achar algum.
