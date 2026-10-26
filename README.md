# Scout Enterprise + ELIAS 18 + eLux 7 — laboratório POPULOS

Repositório para **recriar do zero** um ambiente de gerenciamento de thin clients eLux 7 com Citrix/Unicon Scout Enterprise num Windows Server (começou fora de domínio e depois entrou no AD `populos.local`), com login do Scout Board via Microsoft Entra ID, imagens de firmware montadas no ELIAS 18, temas por OU, login AD nos eLux e uma parede de 6 TVs (OU "TV Projetos").

> Escrito para ser seguido por uma pessoa **ou por outro agente de IA**. Para implantar do zero em outro ambiente, comece pelo **[Guia de implantação](docs/GUIA-IMPLANTACAO.md)** (completo, em fases, com validação e solução de problemas). O [RUNBOOK](docs/RUNBOOK.md) é a versão resumida.

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

Resultado validado: eLux registrado no Scout; firmware atualizado pelas imagens `populos-elux7-v4` (geral) e `populos-elux7-v5` (v4 + driver NVIDIA, OU TV Projetos); temas por OU (papel de parede e logo na tela de boot); Outlook e Teams via Edge `--app`; Citrix Workspace (StoreFront); Horizon (Omnissa); OU de quiosque; **login AD (Kerberos) nos eLux** com OUs sem AD (Populos NonDomain, Modo Kiosk, TV Projetos); NTP; **mirror pelo Scout Board** com controle e sem pedir permissão; tela sempre ativa (sem bloqueio/suspensão); 2 monitores clonados; **6 TVs** com duas NVIDIA Quadro em Base Mosaic, cada uma com uma página do PopulosHub em quiosque, login automático e recarga a cada 5 min. Depois: OU Populos Dev (home persistente, OneDrive, digital como 2º fator); OU **Porto** sem AD, entrada só com a **impressão digital**, CXone e leitor de PDF; **Google Chrome** e **inventário no GLPI** em todas as OUs; **uberAgent** enviando para dois servidores; **Teams for Linux** (comunitário); **sala de provas** (OU "Provas": digital abre a prova de certificação Citrix ou Nutanix do aluno, com tempo e nota).

## Estrutura

```
README.md                        este arquivo
docs/GUIA-IMPLANTACAO.md         guia completo de implantação do zero (comece aqui)
docs/RUNBOOK.md                  passo a passo resumido
docs/DB-REFERENCE.md             tabelas e códigos do banco do Scout (não documentados pela Citrix)
docs/LICOES.md                   armadilhas encontradas e como evitar
docs/HISTORICO.md                diário completo da implantação original (sanitizado)
scripts/                         PowerShell e SQL usados
tv-projetos/                     parede de 6 TVs: proxy IIS + tv.js, start-tv.sh, Xorg Base Mosaic (ver tv-projetos/README.md)
assets/themes/                   temas eLux prontos (Populos, Bom Jesus, Enterprise)
assets/icons/                    ícones 32x32 dos apps
provas/                          site de provas com digital (Flask em Docker) e script do eLux
manual/                          manual de implantação em Word/PDF e as fontes para gerá-lo
config/parametros.example.ps1    valores que mudam de um ambiente para outro
```

## Segredos

Nenhuma senha, chave ou token está neste repositório; todos viraram marcadores `<ASSIM>`. Os valores reais ficam no servidor, em `C:\ScoutSetup\credenciais.txt` (fora do Git, ACL só Administradores). Antes de qualquer `git push`, rode `scripts/verificar-segredos.ps1`.
