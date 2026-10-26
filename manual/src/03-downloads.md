# 3. Pré-requisitos e downloads

## 3.1 Hardware e rede

- Windows Server 2022 ou 2025, 8 GB de RAM (12 GB se for rodar GLPI e o SDK no mesmo servidor), 4 ou mais núcleos, 100 GB livres, **IP fixo** ou reserva no DHCP.
- Rede em que os eLux alcancem o servidor nas portas do capítulo 1.
- **DNS:** o ideal é o DHCP da rede dos eLux entregar o DNS do AD e o sufixo do domínio. Se não entregar, a Fase 11 traz o contorno.
- Saída para a internet no servidor: licença (Citrix Cloud), NTP, Entra ID, GitHub, Docker Hub e repositórios do Ubuntu.
- Virtualização habilitada no servidor (Hyper-V/VMP) para o WSL2. Se o servidor for uma VM, ligue a virtualização aninhada.

## 3.2 Contas e direitos

| Conta | Para quê |
|---|---|
| Conta Citrix com direito a **Citrix UniconOS/eLux e Scout** | Downloads e licença (Citrix Cloud → Licensing) |
| Administrador Global do Microsoft Entra ID (ou Administrador de Aplicativos + consentimento) | App de login do Scout Board |
| Domain Admin do Active Directory | Colocar o servidor no domínio, corrigir a hora do DC |
| Contato com a Unicon/Citrix | Pedir o **UniconOS SDK** (vem por e-mail) e o Scout Agent for Windows, se for o caso |
| Acesso de administrador aos servidores de destino do uberAgent | Ler os tokens HEC |

## 3.3 Mídias a baixar

Baixe tudo antes de começar e guarde em `C:\Users\Administrator\Downloads` (ou outra pasta de mídias). O portal antigo **myelux** não aceita mais login: os downloads da Unicon ficam no portal da Citrix (**citrix.com/downloads**, seção *Citrix UniconOS / eLux & Scout*), com a conta que tem o direito às licenças.

| # | Arquivo (versão usada) | Onde baixar | Para quê |
|---|---|---|---|
| 1 | `Scout-15.2609-3.zip` → `ScoutInstaller.exe` (Scout Enterprise Management Suite 15.2609, v26.9.0) | Citrix Downloads → UniconOS Management (Scout) | Scout Server, Console, Board, DB Layer, Keep Alive, Report, Recovery, ELIAS clássico |
| 2 | `ELIAS_18.26032_*.zip` → `EliasInstaller.exe` (ELIAS 18, 26.3.2) | Citrix Downloads → ELIAS | Montagem das imagens (IDF) e servidor de firmware pelo IIS |
| 3 | `eLux-7.2609.0_AllPackages-1.zip` (~3,7 GB) | Citrix Downloads → UniconOS 7 → All packages | Container com todos os pacotes eLux (EPM/FPM) importado no ELIAS 18 |
| 4 | `eLux-certs-2025.0.zip` | Citrix Downloads → UniconOS 7 | Certificados de assinatura dos pacotes |
| 5 | `Citrix_Licensing_11.17.2.0_BUILD_56200.zip` | Citrix Downloads → Licensing | Citrix License Server (o Scout só licencia por ele desde 15/04/2026) |
| 6 | `msodbcsql.msi` (ODBC Driver 18 for SQL Server, 18.7) | Microsoft (learn.microsoft.com → ODBC Driver for SQL Server) | Acesso do Scout ao SQL |
| 7 | SQL Server Express 2025 (instalador SSEI) | `https://go.microsoft.com/fwlink/p/?linkid=2216019` | Banco `ScoutEnterprise` |
| 8 | eLux 7 em pendrive (eLux Portable) ou mídia de instalação/Recovery | Citrix Downloads → UniconOS 7 → Portable / Recovery | Primeiro thin client |
| 9 | `UniconOS.2609.SdkDockerEnv.zip` (~460 MB) | **E-mail da Unicon/Citrix**, sob pedido | SDK (`epkg`) para pacotes próprios (Fase 18) |
| 10 | MSI do WSL (`wsl.<versão>.x64.msi`) | GitHub `microsoft/WSL` → Releases | WSL2 no Windows Server (o `wsl.exe` que vem no Windows Server é só um atalho) |
| 11 | Ubuntu 22.04 para WSL | `wsl --install -d Ubuntu-22.04` (baixa sozinho) | Linux para o SDK e o GLPI |
| 12 | Imagens Docker `glpi/glpi:latest` (GLPI 12.0.0) e `mysql:8.4` | Docker Hub (baixadas pelo script da Fase 20) | Servidor GLPI |
| 13 | `glpi-agent-1.21-x86_64.AppImage` | GitHub `glpi-project/glpi-agent` → Releases 1.21 (baixado pelo script `22-glpi-agent-baixar.sh`) | Agente GLPI empacotado para o eLux |
| 14 | Pacote de configuração do uberAgent (`config.tar.gz`) | Servidor uberAgent da Populos (endereço interno, não publicar) | Base do `uberAgent.conf` (Fase 21) |

Pacotes que **não** precisam ser baixados à parte, porque vêm no catálogo do ELIAS (item 3): Citrix Workspace (`ica`), Horizon (`vmwareviewclient`), Microsoft Edge (`microsoft_edge`), Google Chrome (`google_chrome`), driver NVIDIA (`nvidia_driver`), leitor de PDF (`document_viewer`), uberAgent (`uberagent` 8.0.7535), `perl`, `mirror_server` e o restante.

> O "Scout Agent for Windows" aparece na página da Citrix, mas sem link de download. Peça ao suporte se precisar gerenciar PCs Windows pelo Scout.

## 3.4 Ordem recomendada

| Etapa | Fases | Tempo aproximado |
|---|---|---|
| Servidor, SQL, Scout, licença, Scout Board | 1 a 5 | 1 dia |
| ELIAS, imagem, primeiro eLux | 6 a 8 | 1 dia (o download do container é grande) |
| Temas, apps, AD, OUs, energia, quiosque | 9 a 15 | 1 a 2 dias |
| Parede de TVs | 16 | 1 dia (depende do hardware) |
| SDK, OU só com digital | 18 e 19 | 1 a 2 dias (o servidor reinicia para habilitar o WSL) |
| GLPI, Chrome e uberAgent | 20 e 21 | meio dia |
