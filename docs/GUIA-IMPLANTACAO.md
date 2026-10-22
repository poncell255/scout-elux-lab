# Guia de implantação do zero — Scout Enterprise + ELIAS 18 + eLux 7

Guia para implantar, num ambiente novo, o mesmo projeto montado no laboratório da POPULOS entre 15 e 22/10/2026: gerenciamento de thin clients eLux 7 (UniconOS) com Citrix/Unicon Scout Enterprise, imagens montadas no ELIAS 18, login AD nos thin clients, OUs com apps e temas próprios, quiosque Citrix, home persistente e uma parede de 6 TVs.

**Para quem é:** quem vai executar a implantação (analista de infraestrutura ou um agente de IA). Pressupõe familiaridade com Windows Server, SQL Server, IIS, Active Directory e linha de comando PowerShell; não pressupõe conhecimento prévio de Scout ou eLux.

**Como usar:** siga as fases na ordem. Cada fase tem o objetivo, os passos, a validação e as armadilhas conhecidas. Os scripts citados estão em `scripts/` e `tv-projetos/` deste repositório. Os documentos de apoio são:

| Documento | Uso |
|---|---|
| [DB-REFERENCE.md](DB-REFERENCE.md) | Tabelas e códigos do banco do Scout (não documentados pela Citrix) |
| [LICOES.md](LICOES.md) | Lista curta das armadilhas |
| [RUNBOOK.md](RUNBOOK.md) | Versão resumida deste guia |
| [HISTORICO.md](HISTORICO.md) | Diário completo da implantação original, com cada tentativa e erro |
| [../tv-projetos/README.md](../tv-projetos/README.md) | Detalhes da parede de TVs |

---

## Sumário

1. [Visão geral e arquitetura](#1-visão-geral-e-arquitetura)
2. [Decisões de projeto](#2-decisões-de-projeto)
3. [Pré-requisitos](#3-pré-requisitos)
4. [Parâmetros do ambiente](#4-parâmetros-do-ambiente)
5. [Regras de trabalho](#5-regras-de-trabalho)
6. [Fase 1 — Servidor base](#fase-1--servidor-base)
7. [Fase 2 — SQL Server e ODBC](#fase-2--sql-server-e-odbc)
8. [Fase 3 — Scout Enterprise](#fase-3--scout-enterprise)
9. [Fase 4 — Licença](#fase-4--licença)
10. [Fase 5 — Scout Board com Entra ID](#fase-5--scout-board-com-entra-id)
11. [Fase 6 — ELIAS 18 e imagens](#fase-6--elias-18-e-imagens)
12. [Fase 7 — Registrar os eLux e entregar firmware](#fase-7--registrar-os-elux-e-entregar-firmware)
13. [Fase 8 — Como alterar o Scout pelo banco](#fase-8--como-alterar-o-scout-pelo-banco)
14. [Fase 9 — Temas por OU](#fase-9--temas-por-ou)
15. [Fase 10 — Aplicativos](#fase-10--aplicativos)
16. [Fase 11 — Login AD nos eLux](#fase-11--login-ad-nos-elux)
17. [Fase 12 — OUs com configuração própria](#fase-12--ous-com-configuração-própria)
18. [Fase 13 — Mirror, energia, monitores e barra de tarefas](#fase-13--mirror-energia-monitores-e-barra-de-tarefas)
19. [Fase 14 — Quiosque Citrix](#fase-14--quiosque-citrix)
20. [Fase 15 — Home persistente (OU de desenvolvimento)](#fase-15--home-persistente-ou-de-desenvolvimento)
21. [Fase 16 — Parede de 6 TVs](#fase-16--parede-de-6-tvs)
22. [Fase 17 — Acesso de fora da rede (opcional)](#fase-17--acesso-de-fora-da-rede-opcional)
23. [Operação e diagnóstico](#operação-e-diagnóstico)
24. [Tabela de problemas e soluções](#tabela-de-problemas-e-soluções)
25. [Validação final](#validação-final)
26. [Pendências e riscos conhecidos](#pendências-e-riscos-conhecidos)
27. [Mapa dos scripts](#mapa-dos-scripts)

---

## 1. Visão geral e arquitetura

Um único Windows Server hospeda tudo. Os eLux falam com o Scout Server para registro, configuração e comandos, e baixam imagens de firmware do IIS (ELIAS 18). Administradores usam o Scout Board (web, login Entra ID) e o ELIAS 18 (web).

```
                      ┌──────────────────────────── Windows Server (no domínio) ────────────────────────────┐
 Administradores ──HTTPS 22160──► Scout Board ──► Scout Board DB Layer (22150/22151) ──► Scout Server        │
   (login Entra ID)                                                                          │               │
 Administradores ──HTTP 80/ELIAS──► IIS ──ARR──► ELIAS 18 (22130) ──► MongoDB (27017 local)  │               │
                                    │                                                         ▼               │
 eLux ──TCP/UDP 22123, TCP 22125──────────────────────────────────────────────────► Scout Server ──► SQL Express
 eLux ──TCP 22124──► Scout Keep Alive ─────────────────────────────────────────────────────────────► (ScoutEnterprise)
 eLux ──HTTP 80──► IIS: /ELIAS/<container>/<arquivo> (imagens) e /eluxng, /certs
 eLux da OU TV ──HTTP 8090──► IIS site "TV Projetos" ──ARR──► PopulosHub (HTTPS, internet)
 Citrix License Server (27000, 7279, 8083) ◄── LAS na Citrix Cloud
                      └──────────────────────────────────────────────────────────────────────────────────────┘
 eLux ──Kerberos 88 / LDAP 389──► Controlador de domínio        eLux ──NTP 123──► a.ntp.br / b.ntp.br
```

### Componentes e versões usadas

| Componente | Versão | Função |
|---|---|---|
| Windows Server 2025 Datacenter | 10.0.26100 | Host único (8 GB RAM, 12 núcleos lógicos foram suficientes) |
| SQL Server Express | 2025 (17.0) | Banco `ScoutEnterprise`, usado pelo Scout Server e pelo Keep Alive |
| ODBC Driver 18 for SQL Server | 18.7 | Acesso do Scout ao SQL |
| Scout Enterprise Management Suite | 15.2609 (26.9.0) | Server, Console, Board, DB Layer, Keep Alive, Report, Recovery, ELIAS clássico |
| Citrix License Server | 11.17.2 build 56200 | Licença do Scout via LAS |
| ELIAS 18 | 26.3.2 | Montagem de imagens (IDF) e servidor de firmware |
| MongoDB | 7.0 (instalado pelo ELIAS) | Banco do ELIAS 18 |
| eLux 7 (UniconOS) | 7.2609.0 | Sistema dos thin clients |
| Microsoft Entra ID | — | Login do Scout Board (OIDC) |
| Active Directory | nível funcional 2016 | Login dos usuários nos eLux |

### Portas

| Porta | Direção | Uso |
|---|---|---|
| TCP+UDP 22123 | eLux → Scout | Comunicação Scout ↔ eLux |
| TCP 22125 | eLux ↔ Scout | Canal seguro; o Scout também **abre** conexão até o eLux nessa porta para comandos (reiniciar, mirror) |
| TCP 22124 | eLux → Scout | Keep Alive |
| TCP 22160 | Admin → Scout Board | Interface web (HTTPS) |
| TCP 80 | eLux/Admin → IIS | Firmware (ELIAS 18) e interface do ELIAS |
| TCP 8090 | eLux da OU TV → IIS | Proxy das páginas da parede de TVs |
| UDP 69 | eLux → Scout | TFTP (Recovery/PXE) |
| TCP 1433, UDP 1434 | local | SQL Server |
| 27000, 7279, 8083 | local | Citrix License Server |
| 88, 389 (636) | eLux → DC | Kerberos e LDAP para o login AD |
| UDP 123 | eLux → NTP | Hora (Kerberos exige diferença < 5 min) |

---

## 2. Decisões de projeto

| Decisão | Motivo | Consequência |
|---|---|---|
| Tudo num servidor só | Laboratório e ambiente pequeno | Sem alta disponibilidade; o servidor é ponto único de falha |
| SQL Server Express | O Scout só suporta MS SQL; Express basta para dezenas de eLux | Limite de 10 GB por banco |
| Scout Board com **Entra ID** | Sem domínio, o login padrão do Scout Board (AD via LDAPS) falha; mesmo com domínio, o Entra dá MFA e controle por atribuição | Cada administrador precisa estar no app do Entra **e** na tabela `Administrator` |
| **ELIAS 18** (web) em vez do ELIAS clássico | É o que o Scout Board integra; tem API para montar imagens por script | Precisa de MongoDB e IIS com ARR |
| Muitas alterações **direto no banco** | O login OIDC do Scout Board não pode ser automatizado (o código de autorização é de uso único e o navegador o consome) | Exige backup antes, transação, e marcar os dispositivos para atualizar (Fase 8) |
| Imagem enxuta (< 3 GB) | A partição de atualização do eLux tem 3,75 GB | O Firefox saiu da imagem; apps web usam o Edge |
| Apps web como **Edge `--app`** | Não há cliente nativo de Outlook/Teams/OneDrive/VS Code para eLux | Janela sem barra de endereço; depende do pacote `microsoft_edge` |
| Acesso **só pela rede local** (no fim) | A rede bloqueava a porta do Cloudflare Tunnel e eLux externos precisam de VPN ou Scout Cloud Gateway | Ver Fase 17 se precisar de acesso externo |
| Proxy reverso no IIS para a parede de TVs | O Edge do eLux bloqueia toda extensão por política da Unicon | Um site IIS a mais (porta 8090) |

---

## 3. Pré-requisitos

### Hardware e rede

- Windows Server 2022 ou 2025, 8 GB RAM, 4+ núcleos, 100 GB livres, **IP fixo** (ou reserva DHCP).
- Rede onde os eLux alcancem o servidor nas portas da seção 1.
- **DNS:** o ideal é o DHCP da rede dos eLux entregar o DNS do AD e o sufixo do domínio. Se não entregar, a Fase 11 tem o contorno.
- Saída para a internet no servidor (licença LAS, NTP, Entra ID).

### Contas e direitos

- Conta Citrix com direito às licenças **Citrix Unicon (eLux/Scout)** e acesso à Citrix Cloud (Licensing).
- Tenant Microsoft Entra ID com um **Administrador Global** (ou Administrador de Aplicativos + consentimento de administrador).
- Active Directory: uma conta de **Domain Admin** para colocar o servidor no domínio e ajustar a GPO de hora do DC.

### Mídias (baixar antes)

| Arquivo | Origem |
|---|---|
| `ScoutInstaller.exe` 15.2609 | Citrix Downloads → UniconOS Management (Scout) |
| `ELIAS_18.26032_*.zip` (`EliasInstaller.exe`) | Citrix Downloads → ELIAS |
| `eLux-7.2609.0_AllPackages-1.zip` (~3,7 GB) | Citrix Downloads → UniconOS 7 |
| `eLux-certs-2025.0.zip` | Citrix Downloads (certificados de assinatura) |
| `Citrix_Licensing_11.17.2.0_BUILD_56200.zip` | Citrix Downloads → Licensing |
| `msodbcsql.msi` (ODBC 18) | Microsoft |
| SQL Server Express (SSEI) | `https://go.microsoft.com/fwlink/p/?linkid=2216019` |
| Pendrive ou thin client com eLux 7 | Para o primeiro dispositivo (eLux Portable ou instalação via Recovery) |

> O portal **myelux** não aceita mais login; os downloads ficam na Citrix. O "Scout Agent for Windows" aparece listado na página da Citrix, mas sem link: peça ao suporte se precisar gerenciar Windows.

---

## 4. Parâmetros do ambiente

Copie `config/parametros.example.ps1` para `config/parametros.ps1` (fora do Git) e preencha. Os valores do laboratório estão à direita só como exemplo.

| Parâmetro | O que é | Exemplo do laboratório |
|---|---|---|
| `ServerIP` / `HostName` | IP fixo e nome do servidor Scout | 10.5.0.166 / SCOUTBOARD |
| `Dominio` / `DcFqdn` / `DcIp` | Domínio AD e controlador | populos.local / POPAD01.populos.local / 10.20.0.10 |
| `SearchBase` | Base LDAP | DC=populos,DC=local |
| `Ntp` | Servidores de horário públicos | a.ntp.br, b.ntp.br |
| `EliasContainer` | Container eLux no ELIAS 18 | UC_RP6_X64 |
| `Imagem` | Nome da IDF principal | populos-elux7-v4 |
| `CitrixStoreUrl` | Loja Citrix (StoreFront ou Citrix Cloud) | https://<loja>.cloud.com |
| `EntraTenantId` / `EntraAppId` | App do Scout Board | — |
| `ScoutAdmins` | E-mails dos administradores | — |
| Senhas | SQL `sa`, `scoutdb`, dispositivo eLux, admin do ELIAS, segredo do app Entra, usuário TV | **só em `C:\ScoutSetup\credenciais.txt`** |

---

## 5. Regras de trabalho

Estas regras evitaram retrabalho no projeto original. Siga-as em todas as fases.

1. **Segredos** ficam só em `C:\ScoutSetup\credenciais.txt`, uma linha por item no formato `Nome / valor`, com ACL apenas para Administradores e SYSTEM. Os scripts leem a senha do `sa` desse arquivo (`'^SQL sa'`). Nunca coloque senha em documento, chat ou repositório.
2. **Backup do banco antes de cada alteração direta:** `BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-<assunto>.bak' WITH INIT, COPY_ONLY`. Todos os scripts deste repositório já fazem isso.
3. **Uma transação por alteração**, com `ROLLBACK` em qualquer erro.
4. **Depois de gravar, marque os dispositivos:** `UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=<OU>` e reinicie o eLux (às vezes 2x).
5. **Arquivos entregues ao eLux** só são reenviados se `UCFT.TimeModified` mudar (epoch **UTC**: `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()`; no PowerShell 5.1 o `Get-Date -UFormat %s` dá hora local).
6. **Temas:** toda troca de imagem exige nome novo do tema (`-v2`, `-v3`), senão o eLux usa o cache.
7. **Documente** cada passo num documento vivo (no projeto original, `SCOUT-ELUX-GLOBAL.md`, publicado aqui como `HISTORICO.md`).

---

## Fase 1 — Servidor base

1. Defina **IP fixo** e nome definitivo do servidor **antes** de instalar o Scout (o nome entra no usuário inicial do Scout e em configurações).
2. Coloque no domínio, se o ambiente tiver AD. No laboratório isso foi feito no fim e funcionou, mas o administrador inicial do Scout ficou com o nome antigo (`<nome-antigo>\Administrator`).
3. Crie as pastas `C:\ScoutSetup\{backup,scripts,diag}` e o `credenciais.txt` com ACL restrita:
   ```powershell
   icacls C:\ScoutSetup\credenciais.txt /inheritance:r /grant:r "Administrators:F" "SYSTEM:F"
   ```
4. Firewall: crie o grupo de regras "Scout eLux" com as portas da seção 1 (TCP+UDP 22123, TCP 22125, 22124, 22160, 80, UDP 69). Não habilite grupos inteiros como "File and Printer Sharing".
5. Instale o IIS com Static Content, Directory Browsing e Management Console (o ELIAS 18 adiciona URL Rewrite e ARR).

**Validação:** `Get-NetFirewallRule -Group 'Scout eLux'`; IP fixo; servidor resolve o DNS do AD.

---

## Fase 2 — SQL Server e ODBC

1. ODBC: `msiexec /i msodbcsql.msi IACCEPTMSODBCSQLLICENSETERMS=YES /qn`
2. SQL Express pelo SSEI:
   ```
   SSEI.exe /ACTION=Download /MEDIAPATH=C:\ScoutSetup\sql /MEDIATYPE=Core /QUIET
   SQLEXPR_x64_ENU.exe /Q /X:C:\ScoutSetup\sql\extract
   setup.exe /Q /ACTION=Install /FEATURES=SQLEngine /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT="NT Service\MSSQL$SQLEXPRESS" ^
     /SQLSYSADMINACCOUNTS="BUILTIN\Administrators" /SECURITYMODE=SQL /SAPWD="<SENHA_SQL_SA>" /TCPENABLED=1 ^
     /BROWSERSVCSTARTUPTYPE=Automatic /UPDATEENABLED=0 /IACCEPTSQLSERVERLICENSETERMS
   ```
3. Porta fixa 1433: em `HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL*.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp\IPAll`, `TcpPort=1433` e `TcpDynamicPorts=""`; reinicie o serviço. Firewall TCP 1433 e UDP 1434.
4. Login do Scout:
   ```sql
   CREATE LOGIN [scoutdb] WITH PASSWORD=N'<SENHA_SQL_SCOUT>';
   ALTER SERVER ROLE [sysadmin] ADD MEMBER [scoutdb];  -- reduzir para db_owner depois da instalação
   ```

**Validação:** `sqlcmd -S localhost\SQLEXPRESS -E -C -Q "SELECT @@VERSION"` (o `-C` confia no certificado autoassinado; sem ele o ODBC 18 recusa a conexão).

---

## Fase 3 — Scout Enterprise

O instalador é um bundle WiX Burn com interface própria. Use **`/s`** e **`/v"CHAVE=valor"`**; não use `-layout` (trava).

```
ScoutInstaller.exe /s /l C:\ScoutSetup\scout-install.log ^
 /v"UCPROP_DBTYPE=2" /v"UCPROP_DBSERVER=localhost\SQLEXPRESS" /v"UCPROP_DBNAME=ScoutEnterprise" ^
 /v"DB_SCOUT_DB_AUTHENTICATION=SQL Server Authentication" /v"UCPROP_DBUSER=scoutdb" /v"UCPROP_DBPASSWORD=<SENHA_SQL_SCOUT>" ^
 /v"UCPROP_ENCRYPT=0" /v"UCPROP_TRUSTSERVERCERTIFICATE=1" /v"UCPROP_DBCREATE=1" ^
 /v"UCPROP_INITIAL_SCOUT_USER=<HOSTNAME>\Administrator" /v"DEVICE_PASSWORD=<SENHA_DISPOSITIVO_ELUX>" /v"LS=0" ^
 /v"ADDLOCAL=CommonFeature,Server,Console,Recovery,Elias,Report" ^
 /v"INSTALL_SCOUT_FEATURE=1" /v"INSTALL_SCOUTBOARD_FEATURE=1" /v"INSTALL_SCOUTKEEPALIVE_FEATURE=1" ^
 /v"UCPROP_SCOUTKEEPALIVE_DBSERVER=localhost\SQLEXPRESS" /v"UCPROP_SCOUTKEEPALIVE_DBNAME=ScoutEnterprise" ^
 /v"UCPROP_SCOUTKEEPALIVE_AUTHENTICATION=SQL Server" /v"UCPROP_SCOUTKEEPALIVE_DBUSER=scoutdb" ^
 /v"UCPROP_SCOUTKEEPALIVE_DBPASSWORD=<SENHA_SQL_SCOUT>" /v"UCPROP_SCOUTKEEPALIVE_TRUSTSERVERCERTIFICATE=1"
```

Correções depois da instalação:

| Problema | Correção |
|---|---|
| Keep Alive: "Cannot open database ScoutKeepAlive" | O Keep Alive usa a tabela `Entity` do **mesmo banco** do Scout. `UCPROP_SCOUTKEEPALIVE_DBNAME=ScoutEnterprise`, ou `scoutkeepalive.ini` → `[Database] Name=ScoutEnterprise` |
| Fuso dos eLux em US/Eastern | O instalador ignora `UCPROP_TIMEZONE`: `UPDATE Setup SET TimeZoneID=195` (195 = America/Sao_Paulo) |
| Scout Board não abre depois de reiniciar o Scout Server | Reinicie na ordem **ScoutServer → ScoutBoardDBLayer → ScoutBoard** (o DB Layer às vezes sobe com "Cannot start ZMQ broker") |

Caminhos úteis: binários em `C:\Program Files\Unicon\Scout`; configuração e log do Scout Server em `C:\Users\Public\Documents\Unicon\Scout\Server` (`eluxd.ini`, `eluxd.log`); diagnósticos de eLux em `...\Server\diag\`.

**Validação:** serviços `ScoutServer`, `ScoutBoard`, `ScoutBoardDBLayer`, `ScoutKeepAlive` rodando; `https://localhost:22160` responde (redireciona para login).

---

## Fase 4 — Licença

Desde 15/04/2026 o licenciamento por arquivo acabou: o Scout só licencia pelo **Citrix License Server ativado via LAS** (License Activation Service, Citrix Cloud).

1. `CitrixLicensing.exe /quiet /l C:\ScoutSetup\licensing-install.log` (funciona no Windows Server 2025; portas 27000, 7279, 8083).
2. `https://localhost:8083` → Settings → Citrix Cloud → **Register** → informe o código em citrix.cloud.com (Licensing → License Servers → Add).
3. Scout Board → tela de licença → modo **Citrix License Server**, servidor `localhost`.
4. `Restart-Service ScoutServer` (e depois DB Layer e Scout Board).

**Validação:** `eluxd.log` com `hasLicense: 0->1`; portas 22123/22125 em escuta (`Get-NetTCPConnection -State Listen -LocalPort 22123,22125`). Sem licença o Scout Server não abre essas portas.

---

## Fase 5 — Scout Board com Entra ID

Sem AD, o login padrão do Scout Board falha (`LDAPS_UNREACHABLE`). Mesmo com AD, o Entra ID foi a opção escolhida.

1. **App registration** (single-tenant) no Entra ID:
   - Redirect URI (Web): `https://<HOST_NAME>:22160/api/v1/auth/callback`. O Scout Board monta essa URL com `HOST_NAME` e `PORT` do `.env`; registre uma URI para cada forma de acesso (IP, FQDN, `localhost`).
   - Permissões delegadas do Microsoft Graph: `openid`, `profile`, `email`, `offline_access`, `User.Read`, `GroupMember.Read.All`, `Directory.Read.All` + **consentimento de administrador**.
   - Um segredo de cliente (anote o vencimento).
   - Na Enterprise Application: **Assignment required = Yes** e atribua só os administradores.
2. `C:\Program Files\Unicon\Scout\ScoutBoard\.env` (faça backup antes; ACL só Administradores/SYSTEM):
   ```
   AUTH_TYPE=ENTRAID_OIDC
   OIDC_ISSUER=https://login.microsoftonline.com/<TENANT_ID>/v2.0
   OIDC_CLIENT_ID=<APP_ID>
   OIDC_CLIENT_SECRET=<SEGREDO>
   HOST_NAME=<IP ou FQDN>
   PORT=22160
   ```
3. Reinicie o Scout Board.
4. **Autorização:** o e-mail/UPN do token precisa existir em `Administrator.Name`. Para cada administrador, rode `scripts/sql/admin-entra.sql` (copia os direitos do administrador inicial).

Para dar acesso a mais alguém: **atribuir no Entra ID e cadastrar em `Administrator`** (as duas coisas).

**Validação:** login no Scout Board com uma conta atribuída → painel. Uma atualização do Scout pode sobrescrever o `.env`: guarde a cópia.

---

## Fase 6 — ELIAS 18 e imagens

### Instalação

```
EliasInstaller.exe /s /log C:\ScoutSetup\elias18-install.log /v"INSTALLMONGODB=1" /v"ELIASDATABASE=ELIAS" ^
 /v"IISCONFIG=1" /v"IISROOT=Default Web Site" /v"ELIASPATH=ELIAS" /v"ELIASPORT=22130" /v"HASAD=0" /v"HASKEYCLOAK=0" ^
 /v"ADMINPASSWORD=<SENHA_ELIAS_ADMIN>"
```

| Bug/armadilha | Correção |
|---|---|
| `server.json` fica com `"server": "Empty"` (erro `getaddrinfo ENOTFOUND empty`) | Troque por `"localhost:27017"` e reinicie o serviço `ELIAS` |
| `config.json` some depois de um reinício ("Unexpected end of JSON input") | O ELIAS migra a configuração para o MongoDB e deixa `config.json.migrated`; recrie a partir dele |
| Navegadores de outras máquinas não acessam | Em `config.json`: `api` = IP/FQDN que os navegadores e eLux alcançam, `protocol`, `port`, `allowedOrigins` |

Logs do serviço: `C:\Windows\System32\config\systemprofile\AppData\Roaming\ELIAS\`. Interface: `http://<servidor>/ELIAS/`, usuário `admin`.

### Container e certificados

1. Pela interface do ELIAS 18, importe `eLux-7.2609.0_AllPackages-1.zip` → cria o container **`UC_RP6_X64`** (versão `UC_ELUX7-1.0`) com 76 EPMs / ~400 FPMs.
2. Importe os certificados de `eLux-certs-2025.0.zip` (Root, Intermediate, Issuer). Mantenha os vencidos: servem para validar pacotes antigos.

### Montar imagens pela API

A API permite montar a imagem por script (útil porque a interface é lenta para resolver dependências):

1. Login: `POST /ELIAS/api/UC_RP6_X64/v1.0/authenticate/` com `{"user":"admin","domain":"","password":"..."}` (guarda cookie).
2. Catálogos: `GET .../epms`, `.../fpms`, `.../idfs` (salve em `C:\ScoutSetup\diag\elias-epms.json` etc.).
3. `scripts/montar-idf.ps1 -Nome <nome> -AddEpms <lista> -AddFpms <lista> -Saida <json>`: parte da imagem oficial `migration-system-*`, adiciona os pacotes pedidos e resolve as dependências.
4. Publicação: `POST .../idfs` com `{"idf":{...,"id":"<nome>.idf","created":"...","modified":"..."}}`. A resposta precisa vir com `conflicted=false` e `hasMissing=false`.
5. **URL que os eLux usam:** `http://<servidor>/ELIAS/UC_RP6_X64/<arquivo>` (`.idf`, `.epm`, `.fpm`). A API `.../v1.0/...` só devolve metadados.

### Imagens do projeto

| Imagem | Conteúdo | Tamanho | Usada por |
|---|---|---|---|
| `populos-elux7-v4` | `migration-system` + `ica`, `citrix_extensions`, `citrix_hdxrtme`, `vmwareviewclient`, `microsoft_edge` + FPMs `mirror_server`, `ica_selfservice`, `ica_webview`, `ctxext_ucselfservice`, `ctxext_ucselfservice_theme`, `ica_msteams`, `ica_usbrdr`, `ica_mmrdr`, `ica_browserrdr`, `ica_h264` | ~2,7 GB | Todas as OUs, menos TV |
| `populos-elux7-v5` | v4 + EPM `nvidia_driver` (580.173.02; `nvidia_driver_base` + `kernel_nvidia_modules`) | ~2,95 GB | OU TV Projetos |

Comando da v5 (a v4 é o mesmo sem `nvidia_driver`):
```powershell
$fp=@('mirror_server','ica_selfservice','ica_webview','ctxext_ucselfservice','ctxext_ucselfservice_theme','ica_msteams','ica_usbrdr','ica_mmrdr','ica_browserrdr','ica_h264')
.\scripts\montar-idf.ps1 -Nome 'populos-elux7-v5' -AddEpms @('ica','citrix_extensions','citrix_hdxrtme','vmwareviewclient','microsoft_edge','nvidia_driver') -AddFpms $fp -Saida C:\ScoutSetup\diag\idf-populos-v5.json
```

> **Tamanho:** a partição de atualização do eLux tem 3,75 GB. Imagens acima de ~3 GB falharam no meio (códigos 257/259). O Firefox (275 MB) saiu da imagem por isso.
>
> **Pacotes que já vêm na v4 e importam:** `userauth`/`userauthldap`/`kerberos_config`/`openldap`/`pam` (login AD), `mirror_server`, `xorg_utilities` (`xrandr`), `python3` não está incluído.

---

## Fase 7 — Registrar os eLux e entregar firmware

### Registro do eLux no Scout

Escolha uma forma:
1. **Manual**, no assistente do eLux (primeiro boot): servidor Scout = IP do servidor.
2. **DHCP**: opção **222** = IP do Scout, opção **223** = ID da OU.
3. **DNS**: registro `ScoutSrv` apontando para o servidor; o eLux procura esse nome sozinho.

Novos eLux caem na OU **Lost & Found**; mova-os pelo Scout Board.

### Firmware das OUs

No banco (Fase 8): `Server` com `ServerTypeID=7` e o IP do servidor; `Firmware` com `Protocol=0` (HTTP; FTP 1, HTTPS 3, FTPS 4), `Path=ELIAS/UC_RP6_X64`; `Setup.ImageFile=<imagem>.idf`.

Deixe **`Firmware.AutoCheckUpdate=0`** e **`FormatBeforeUpdate=0`**:
- `FormatBeforeUpdate=1` apagou a partição `custom` (onde ficam Edge, Citrix e Horizon), e o eLux parou com "The idf has not been fully downloaded before formatting".
- Com a verificação automática desligada, a atualização acontece quando você manda.

### Aplicar uma imagem nova

1. Scout Board → dispositivo → **Deliver software**. Marque **Complete software image delivered** se o eLux estiver com sobras de tentativas antigas. A entrega baixa só a diferença.
2. Scout Board → **Update software**. O eLux reinicia e **instala no boot, sem rede**. A tela de boot fica parada por **até ~20 min**, e o `Device.UpdateInfo` mostra `261` até terminar com `0`. **Não desligue nesse período.**

**Validação:** `Device.OSVersion` = versão da imagem; `UpdateInfo` começando com `4,...,0`; `ConfigDataID = ConfigDataIDToHave`.

---

## Fase 8 — Como alterar o Scout pelo banco

Use o Scout Board sempre que der. Quando não der (automação, itens que a interface não expõe), altere o banco seguindo estas regras.

### Ciclo de uma alteração

1. Backup (`...-pre-<assunto>.bak`).
2. Transação com todas as gravações.
3. `UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=<OU>`.
4. Reinicie o eLux (2x para temas e monitores).
5. **Confira o que o Scout gerou de verdade**: a configuração enviada ao eLux fica em `ClientConfig.ClientData`, apontada por `Device.ConfigDataIDToHave`. O conteúdo é legível como `/setup/terminal.ini <seção> <chave> <valor>`:
   ```powershell
   # extrai e busca uma chave na configuração gerada do DeviceID 2
   $cn=[System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open()
   $z=$cn.CreateCommand(); $z.CommandText="SELECT c.ClientData FROM Device d JOIN ClientConfig c ON c.ClientConfigID=d.ConfigDataIDToHave WHERE d.DeviceID=2"
   $s=[Text.Encoding]::GetEncoding(28591).GetString([byte[]]$z.ExecuteScalar()); $cn.Close()
   [regex]::Matches($s,'Security.Mirror.[a-z]+') | % Value
   ```
   A configuração só é regenerada quando o eLux faz contato com os flags marcados.

### Padrões de gravação

| Item | Como |
|---|---|
| IDs não identity (`ApplicationID`, `FileEntryID`, `IniEntryID`, `SetupID`, `GroupID`...) | `MAX(...)+1` com `WITH (UPDLOCK, HOLDLOCK)` dentro da transação |
| Identity (`UCFTID`, `AuthDomainID`, `PowerManagementProfileID`, `ScreenID`, `ScreenSettingsID`, `MultimediaID`) | Insira sem o ID e use `SCOPE_IDENTITY()` |
| Arquivo para o eLux | `UCFT` (conteúdo, `MemberType=1`, `MemberID=<OU>`, `FileType=0`, `FileMode=0`, `TimeModified` UTC) + `FileEntry` (`FileDestination` = caminho no eLux, `UCFTID`) |
| Chave de INI no eLux | `IniEntry` (`IniFile`, `IniSection`, `IniKey`, `IniValue`); vale por OU e sobrepõe o que o Scout gera |
| OU nova | Copie as colunas de uma OU existente (`INSERT ... SELECT`) mudando `GroupID`, `Name`, `DeviceCount=0`; OUs na raiz têm `LocationID=-1` |

### Herança de configuração

- Toda OU com `Groups.UseParent=1` usa o **setup 0** (configuração base).
- Uma OU com configuração própria tem `UseParent=0` e um `SetupID` só dela. Para criar, **clone o setup 0** e todas as tabelas ligadas a ele (lista em [DB-REFERENCE.md](DB-REFERENCE.md)). Os scripts `kiosk-sem-ad.ps1`, `ad-e-nondomain.ps1`, `criar-ou-tv-projetos.ps1` e `criar-ou-populos-dev.ps1` fazem esse clone.
- **Atenção:** depois de clonado, o setup não recebe mais as mudanças da base. Uma imagem nova, por exemplo, precisa ser aplicada em cada setup.

---

## Fase 9 — Temas por OU

Arquivos do tema eLux 7 (guia Citrix "Theming guide"):

| Arquivo | Onde aparece |
|---|---|
| `config.json` | Nome do tema, `accentColor`, lista de imagens, `welcomeBackgroundLayout` |
| `desktopBackgroundImage.jpg` | Papel de parede |
| `productImage.png` | **Tela de boot** (quadro 304x304, `contain`) e tela de entrada |
| `brandImage.png` | Logo do botão Iniciar e das telas de entrada (o original é o logo "unicon", no pacote `elux_theme`) |
| `welcomeBackgroundImage.png` | Opcional: fundo da tela de entrada |

Publicação: `scripts/publicar-tema.ps1` grava os arquivos em `/setup/elux/themes/<nome>/` e a `IniEntry` `/setup/terminal.ini [Layout] CurrentTheme=<nome>`.

Regras:
- **Toda troca de imagem → tema com nome novo.**
- **Toda OU precisa de tema próprio.** Um eLux que passa por uma OU sem tema perde o papel de parede; ao voltar, atualize o `TimeModified` dos arquivos.
- Use PNG com fundo transparente para `productImage` e `brandImage`.
- A animação de boot do firmware, antes de o eLux carregar, não é personalizável pelo tema.

Temas prontos em `assets/themes/` (Populos, Populos OU, Bom Jesus).

---

## Fase 10 — Aplicativos

Modelo SQL: `scripts/sql/apps-exemplo.sql`. Ícones: PNG 32x32 em `UCFT` global (`MemberType=-1`, `MemberID=-1`, `FileType=1`, `FileMode=-1`, `FileName=<icone>.png`), referenciados por `Application.IconName` sem extensão. Prontos em `assets/icons/` (outlook, teams, citrix, onedrive, vscode).

| App | Tipo | Configuração |
|---|---|---|
| Outlook | Local (`AppTypeID 5`) | `Local.Type='CUSTOM'`, `Parameter='/usr/bin/microsoft-edge --app=https://outlook.office.com --no-first-run'` |
| Teams | Local | idem com `https://teams.microsoft.com` |
| OneDrive | Local | idem com `https://<tenant>-my.sharepoint.com` (OneDrive corporativo; leva ao OneDrive de quem logou). **Não use** `microsoft365.com/onedrive`: depois do login dá "The page you're looking for doesn't exist" |
| VS Code | Local | idem com `https://vscode.dev`. Não existe VS Code nativo no catálogo do eLux |
| Citrix Workspace | StoreFront (`AppTypeID 17`) | `Storefront.Stores='https://<loja>'`. Precisa dos FPMs de Self-Service na imagem. Sem loja, use local `/usr/bin/selfservice` |
| Horizon | Omnissa (`AppTypeID 15`) | Linha em `VDA` (`Server`, `UseSSL=1`) |

Observações:
- O Firefox não tem `--app`; para janela de app use o Edge.
- Modelos globais (`GroupID -1`, `AppLevel 6`) aparecem em todas as OUs com `UseParentApps=1`. No projeto, o modelo "Citrix" foi apagado e ficaram "Chromium" e "RDP". Para uma OU sem esses modelos, `Groups.UseParentApps=0`.
- `AutoStart=1` abre o app ao iniciar; `TM=1` reabre se fechado.

---

## Fase 11 — Login AD nos eLux

Objetivo: o usuário entra no eLux com a conta do domínio. Foram necessários quatro ajustes; **faça todos de uma vez**, porque cada um escondia o seguinte e todos davam o mesmo "unknown error. Please contact your administrator".

### 11.1 Hora do controlador de domínio

O Kerberos recusa diferença de relógio acima de 5 minutos. No laboratório, o DC estava 8 min atrasado: o serviço W32Time nem estava registrado, e uma GPO forçava `Type=NT5DS`, que no PDC raiz significa "usar o relógio local".

No DC, como Domain Admin:
```powershell
w32tm /register; Set-Service w32time -StartupType Automatic; Start-Service w32time
$g = "Default Domain Controllers Policy"
Set-GPRegistryValue -Name $g -Key "HKLM\SOFTWARE\Policies\Microsoft\W32Time\Parameters" -ValueName Type -Type String -Value "NTP"
Set-GPRegistryValue -Name $g -Key "HKLM\SOFTWARE\Policies\Microsoft\W32Time\Parameters" -ValueName NtpServer -Type String -Value "a.ntp.br,0x8 b.ntp.br,0x8"
gpupdate /force; Restart-Service w32time; w32tm /resync /rediscover; w32tm /query /status   # Source: a.ntp.br,0x8
New-NetFirewallRule -DisplayName "NTP (UDP 123)" -Direction Inbound -Protocol UDP -LocalPort 123 -Action Allow
# DC virtual no Hyper-V: não sincronizar com o host
Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\VMICTimeProvider -Name Enabled -Value 0
```
Altere a GPO só se ela estiver ligada à OU Domain Controllers; `NT5DS` é o correto para os outros computadores.

Conferir o relógio do DC sem credencial (RootDSE):
```powershell
Add-Type -AssemblyName System.DirectoryServices.Protocols
$c=[System.DirectoryServices.Protocols.LdapConnection]::new([System.DirectoryServices.Protocols.LdapDirectoryIdentifier]::new('<DC_IP>',389))
$c.AuthType='Anonymous'; $c.SessionOptions.ProtocolVersion=3
$r=$c.SendRequest([System.DirectoryServices.Protocols.SearchRequest]::new('', '(objectClass=*)','Base',[string[]]@('currentTime')))
$r.Entries[0].Attributes['currenttime'].GetValues([string])   # compare com [DateTime]::UtcNow
```

### 11.2 Hora dos eLux

`scripts/ntp-elux.ps1` grava servidores de horário em **todos** os setups (`Server.ServerTypeID=4` + `ServerList` com `Instance=0`). Sem isso, o eLux trata o relógio do BIOS (hora local) como UTC e fica 3 h errado.

### 11.3 Tipo de autenticação

`scripts/ad-e-nondomain.ps1` (ou o Scout Board, Configuração → Autenticação → Active Directory):
- `Setup.AuthType=3` (Active Directory), `DefaultDomain=<dominio>`, `DomainFieldStatus=0` (campo de domínio editável);
- linha em `AuthDomain` (`Name=<dominio>`, `ServerList=<DC FQDN>`, `SearchBase`).

### 11.4 Localizar o KDC sem depender do DNS do DHCP

O Kerberos do eLux procura o KDC **só por registro SRV no DNS** (`_kerberos._udp.<REALM>`). Se o DHCP da rede dos eLux entrega o DNS do roteador, falha com "No KDC entries found". O `/setup/hosts` não resolve isso, porque não responde SRV.

O `/etc/krb5.conf` do eLux tem `includedir /setup/krb5.conf.d/`. `scripts/krb5-elux.ps1` entrega `/setup/krb5.conf.d/populos.conf` nas OUs com AD:
```ini
[libdefaults]
    default_realm = POPULOS.LOCAL
    dns_lookup_kdc = false
    dns_lookup_realm = false
    rdns = false
    dns_canonicalize_hostname = false
[realms]
    POPULOS.LOCAL = {
        kdc = <DC_IP>
        admin_server = <DC_IP>
    }
[domain_realm]
    .populos.local = POPULOS.LOCAL
    populos.local = POPULOS.LOCAL
```
`scripts/hosts-ad-elux.ps1` (entradas em `/setup/hosts` para o DC) também foi aplicado; ajuda o LDAP, mas sozinho não basta.

**Solução definitiva:** o DHCP da rede dos eLux entregar o DNS do AD e o sufixo do domínio.

**Login no eLux:** só o usuário (`nome.sobrenome`), com o domínio no campo de domínio.

**Diagnóstico:** no pacote de diagnóstico do eLux, `tmp/krb5.log` e as linhas `pam_krb5` em `tmp/systemd-journal.log` (ver [Operação](#operação-e-diagnóstico)).

---

## Fase 12 — OUs com configuração própria

Estrutura final do laboratório:

| OU | GroupID | Setup | Login | Apps e particularidades |
|---|---|---|---|---|
| Lost & Found | 0, 1 | 0 | AD | Destino de eLux novos |
| Enterprise | 2 | 2 | AD | Tema `populos-theme-v3`; criada pela instalação |
| FollowMeDesktop | 3 | 1 | AD | Criada pela instalação |
| Populos | 4 | 0 | AD | Outlook, Teams, Citrix, Horizon; tema `populos-ou-v1` |
| POC-BCR | 5 | 0 | AD | — |
| Bom Jesus | 6 | 0 | AD | Mesmos apps da Populos; tema `bomjesus-v4` |
| Modo Kiosk | 7 | 4 | **sem AD** | Só Citrix em autostart (Fase 14) |
| Populos NonDomain | 8 | 3 | **sem AD** | Mesmos apps e tema da Populos |
| TV Projetos | 9 | 5 | **sem AD** | Parede de 6 TVs (Fase 16) |
| Populos Dev | 10 | 6 | AD | Apps da Populos + VS Code + OneDrive; home persistente (Fase 15) |

Scripts:

| Script | O que faz |
|---|---|
| `scripts/ad-e-nondomain.ps1` | Liga AD nos setups 0/1/2 e cria a OU sem AD com setup clonado (`AuthType=0`), apps e tema da Populos |
| `scripts/kiosk-sem-ad.ps1` | Dá setup próprio sem AD a uma OU que usava a base |
| `scripts/criar-ou-tv-projetos.ps1` | OU da parede de TVs |
| `scripts/criar-ou-populos-dev.ps1` | OU de desenvolvimento com home persistente |

> Os scripts usam os IDs do laboratório (OU 4, setup 0, OU 9...) como parâmetros padrão. Em outro ambiente, confira os IDs com `SELECT GroupID, Name, SetupID, UseParent FROM Groups` e passe os parâmetros.

---

## Fase 13 — Mirror, energia, monitores e barra de tarefas

### Mirror (ver a tela do eLux pelo Scout Board)

`Setup.Mirror` é um campo de bits; o bit **0x1 (ativo)** precisa estar ligado, senão o serviço `webrtcify` do eLux diz "mirror not enabled" e o Scout Board não conecta. Exige o FPM `mirror_server` na imagem.

| Objetivo | SQL |
|---|---|
| Ligar | `UPDATE Setup SET Mirror = Mirror \| 1` |
| Sem pedir permissão ao usuário | `UPDATE Setup SET Mirror = Mirror & ~4` |
| Com controle de mouse e teclado | `UPDATE Setup SET Mirror = Mirror & ~2` |

Valor final do projeto: **16393** (ativo, com controle, sem confirmação). Sem confirmação, quem tem acesso ao Scout Board vê a tela do usuário sem ele saber: avalie a LGPD e avise os usuários.

### Tela sempre ativa

`scripts/tela-sempre-ativa.ps1`: para cada setup e cada um dos 4 perfis de energia (Eco, Eco expediente, Performance, Performance expediente), desliga bloqueio de tela, desligamento do monitor e suspensão, com e sem login; perfil ativo = Performance. Nos perfis padrão do eLux a tela bloqueava em 60 s e o eLux suspendia em 10 min.

### Monitores

- Dois monitores clonados (a mesma imagem): `Screen` Monitor_2 com `LayoutPos=0` e `LayoutNext=1`, `ScreenSettings.ScreenCount=2`.
- Estendidos: `LayoutNext` = monitor de referência, `LayoutPos` 1 abaixo, 2 à direita, 3 à esquerda, 4 acima.

### Barra de tarefas

`Setup.ShowTaskbar=0` (esconder) e `TaskbarAutoHide=1`. Usado só na OU TV.

---

## Fase 14 — Quiosque Citrix

OU onde o eLux abre o Citrix Workspace sozinho, em tela cheia, no desktop publicado:
- `Groups.UseParentApps=0` (não herdar os modelos Chromium/RDP);
- app StoreFront com `AutoStart=1`, `TM=1`, `Storefront.AutostartResources='<nome do desktop>'`, `DesktopsUseFullscreen=1`;
- setup próprio **sem AD** (`scripts/kiosk-sem-ad.ps1`), senão o eLux pede login AD antes do Citrix.

Limitação: com loja **Citrix Cloud** o login é web (Entra), e o repasse de usuário e senha do eLux (`Storefront.Username/Pass/Domain`) não funciona; ele funciona com StoreFront local. Não grave a senha pessoal de alguém num quiosque: use uma conta de serviço restrita ao desktop. Para login realmente automático, avaliar o Citrix Desktop Lock (exige o FPM `ica_desktoplock` e funciona melhor com StoreFront local).

---

## Fase 15 — Home persistente (OU de desenvolvimento)

`Setup.PersistentHomeApplications` guarda a configuração do usuário (perfis de navegador, logins) entre reinícios:
- `'ALL'` = manter todos os apps;
- lista separada por vírgula para escolher (opções do Scout Board: Chrome, Firefox, sessões ICA, Edge, GNOME Keyring, áudio);
- `NULL` = desligado.

É uma opção **por setup**, então a OU precisa de setup próprio (`scripts/criar-ou-populos-dev.ps1`).

Limitação: os dados ficam no próprio thin client, numa partição pequena (256 MB no eLux Portable usado). Perfis grandes de navegador podem não caber; arquivos do usuário devem ir para OneDrive ou pasta de rede.

---

## Fase 16 — Parede de 6 TVs

Detalhes e arquivos em [`tv-projetos/`](../tv-projetos/README.md). Aqui está a sequência de implantação.

### Hardware

PC com **duas NVIDIA Quadro P620** (4 saídas cada) e 6 TVs 1920x1080. O eLux roda de pendrive (eLux Portable) ou instalado.

### Passos

1. **Usuário de leitura no site** que as TVs vão mostrar (no projeto, um usuário local "TV" no PopulosHub, perfil "telas"). Senha no `credenciais.txt`.
2. **Proxy no IIS** (porta 8090), porque o Edge do eLux bloqueia toda extensão (`ExtensionInstallBlocklist ["*"]` em `/usr/setup/microsoft-edge/managed/`, somente leitura):
   - pasta `C:\inetpub\tvprojetos` com `tv-projetos/iis/web.config` e `tv-projetos/iis/tv/tv.js`;
   - site IIS "TV Projetos" na porta 8090, pool próprio, firewall TCP 8090;
   - `HTTP_ACCEPT_ENCODING` e `HTTP_X_ORIGINAL_ACCEPT_ENCODING` em `allowedServerVariables` (nível APPHOST);
   - o `web.config` injeta o `tv.js` logo após `<head>` e tira o `Secure` do cookie de sessão (o proxy é HTTP).
3. **O que o `tv.js` faz:** lê a configuração do hash da URL (`#tv&d=<página>&u=&p=&pg=<aba>`); faz o login quando a sessão cai e volta para a página certa (sem sessão o site redireciona para `/`); vai para a aba do portfólio; simula a tela cheia e aciona o botão "Tela cheia" da própria página (o navegador só aceita tela cheia real com clique, e as páginas só atualizam os dados sozinhas em tela cheia); recarrega a cada 5 min se o site responder.
4. **Teste sem o eLux** (Edge headless no servidor):
   ```powershell
   & "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu --no-first-run `
     --user-data-dir=C:\dg\teste --window-size=1920,1080 --enable-logging=stderr --v=0 `
     'http://<servidor>:8090/portfolio-projetos.html#tv&d=/portfolio-projetos.html&u=<usuario>&p=<senha>&pg=2' 2> C:\dg\log.txt
   # depois de ~30 s: Select-String C:\dg\log.txt '\[tv\]'  → "tela cheia", "aba 2/3"
   ```
5. **Imagem v5** (com `nvidia_driver`) no setup da OU. Sem o driver, o eLux usa `nouveau` sem aceleração e só acende as 3 TVs da primeira placa.
6. **OU e arquivos:** `scripts/criar-ou-tv-projetos.ps1` cria OU, setup sem AD, monitores e o app local `/bin/bash /setup/tv/start-tv.sh` (`AutoStart=1`, `TM=1`). Antes, ajuste `tv-projetos/start-tv.example.sh` (usuário, senha codificada para URL, endereço do proxy, `TELAS`, `LAYOUT`) e salve como `C:\ScoutSetup\tv-projetos\start-tv.sh`. `scripts/tv-projetos-arquivos.ps1` entrega `start-tv.sh` e `20-tv-mosaic.conf`.
7. **Xorg Base Mosaic:** com o driver NVIDIA, a segunda placa entra como GPU auxiliar e também não acende. `tv-projetos/20-tv-mosaic.conf` vai para `/setup/X11/xorg.conf.d/` (o eLux copia esse diretório sem alterar para `/etc/X11/xorg.conf.d`): `AutoAddGPU false`, `BaseMosaic True` na primeira placa e `MetaModes` com as 6 saídas numa área de 5760x2160.
8. **Esconder a barra de tarefas** e desligar o ajuste automático de layout na OU: `Setup.ShowTaskbar=0`, `TaskbarAutoHide=1`, `IniEntry /setup/terminal.ini [Screen] AutomaticLayoutAdjustment=false`.
9. Atualize o eLux para a v5 (Fase 7), reinicie e confira.

### Particularidade: TVs idênticas

As 6 TVs LG SIGNAGE informam EDID idêntico, inclusive o número de série. O serviço de monitores do eLux as trata como **um monitor só** (mesmo UUID em `/setup/myscreens.xml`) e as clona em 0,0 sempre que reconfigura as telas (no boot e quando chega configuração nova). O `start-tv.sh`:
- espera 15 s, posiciona as saídas com `xrandr` conforme `LAYOUT` e abre as janelas nas posições de `TELAS`;
- a cada 20 s confere a posição real de cada saída; se o eLux clonou, refaz a grade (no máximo a cada 40 s) e reabre as janelas;
- registra tudo em `/tmp/tv-projetos.log`.

Alternativa de hardware: emulador de EDID por saída, ou TVs de modelos diferentes.

### Ajustar a ordem das telas

A ordem fica em `TELAS` (posição `x,y` → página e aba) no `start-tv.sh`. Edite, rode `scripts/tv-projetos-arquivos.ps1` e reinicie o PC das TVs. Mudanças no `tv.js` valem sem reiniciar (só suba o `?v=` no `web.config`).

---

## Fase 17 — Acesso de fora da rede (opcional)

Testado no laboratório e **desativado no fim**. O que se aprendeu:

| Necessidade | Solução testada | Observação |
|---|---|---|
| Scout Board e ELIAS pela internet | Cloudflare Tunnel + Cloudflare Access (Entra ID) | O túnel precisa de saída na porta **7844**; uma das redes bloqueava (erro 530) |
| eLux de fora registrando no Scout | DNS público (A, sem proxy) + NAT TCP 22125 no roteador + DDNS | Registro, configuração e firmware funcionam porque partem do eLux |
| Comandos do Scout para eLux de fora (reiniciar, mirror) | OpenVPN no servidor (TCP 1194; o eLux 7 já tem cliente OpenVPN) | O Scout precisa abrir conexão até o eLux; CGNAT bloqueia sem VPN |
| eLux na LAN usando o nome público | Split DNS no servidor | Sem isso, NAT loopback faz o Scout conectar em si mesmo (`SSL_Accept failed`) |

A solução oficial da Citrix para eLux fora da rede é o **Scout Cloud Gateway** (Linux, 4 CPU, 8 GB, AD ou Keycloak).

---

## Operação e diagnóstico

### Onde olhar

| O quê | Onde |
|---|---|
| Diagnóstico de um eLux | Scout Board → dispositivo → arquivo de diagnóstico. O arquivo cai em `C:\Users\Public\Documents\Unicon\Scout\Server\diag\<nome>_<ip>_<data>_diag.zip`. Extraia com `tar -xf <zip> -C C:\dg` (o `Expand-Archive` falha com nomes inválidos no Windows) |
| Dentro do diagnóstico | `tmp/systemd-journal.log` (geral), `tmp/krb5.log` (Kerberos), `var/log/unicon/*.log` (login, monitores, Xorg), `var/log/X11/Xorg.0.log`, `setup/screens.ini`, `setup/myscreens.xml`, `tmp/tv-projetos.log` |
| O que o Scout mandou ao eLux | `ClientConfig.ClientData` (Fase 8) |
| Estado do dispositivo | `Device`: `LastContact` (epoch UTC), `IP_Address`, `OSVersion`, `UpdateInfo`, `ScreenInfo`, `MonitorInfo`, `ActiveUser` |
| Downloads de firmware | Logs do IIS em `C:\inetpub\logs\LogFiles\W3SVC1` (rode `netsh http flush logbuffer` antes de ler) |
| Log do Scout Server | `C:\Users\Public\Documents\Unicon\Scout\Server\eluxd.log` (nível em `eluxd.ini` `Debug=`; 1 em produção) |
| Log do ELIAS 18 | `C:\Windows\System32\config\systemprofile\AppData\Roaming\ELIAS\` |
| Pacotes eLux (`.fpm`) | Cabeçalho "Lexu" + gzip + cpio; `scripts/extrair-fpm.ps1 -Pacote <fpm> -OffsetGzip <offset do primeiro 1F 8B 08> -Destino <pasta>` |

### Backup e restauração

- Backup completo: `BACKUP DATABASE [ScoutEnterprise] TO DISK=N'...' WITH INIT, COPY_ONLY`. Agende um diário além dos backups pontuais.
- Restauração: pare `ScoutServer`, `ScoutBoard`, `ScoutBoardDBLayer`, `ScoutKeepAlive`; `RESTORE DATABASE [ScoutEnterprise] FROM DISK=N'...' WITH REPLACE`; suba na ordem ScoutServer → DBLayer → Board → Keep Alive.
- Guarde fora do servidor: `credenciais.txt`, `.env` do Scout Board, `config.json` do ELIAS, `C:\inetpub\tvprojetos`, os temas e ícones.

---

## Tabela de problemas e soluções

| Sintoma | Causa | Solução |
|---|---|---|
| Gravei no banco e o eLux não mudou | Flags não marcados | `SetupChanged=1, ApplicationsChanged=1` e reiniciar |
| Arquivo novo não chega ao eLux | `TimeModified` igual ao anterior | Gravar `TimeModified` UTC atual |
| Tema não muda | Cache do eLux | Nome de tema novo |
| eLux perdeu o papel de parede | Passou por OU sem tema | Tema em toda OU; atualizar `TimeModified` |
| Atualização falha com 257/259 | Imagem grande demais ou partição `custom` apagada | Imagem < 3 GB; `FormatBeforeUpdate=0`; Deliver software com imagem completa |
| Tela de boot parada por muitos minutos | Instalação offline da imagem no boot | Esperar (até ~20 min); `UpdateInfo` 261 → 0 |
| Citrix Workspace não abre | Faltam FPMs de Self-Service ou a URL da loja | Incluir FPMs; preencher `Storefront.Stores` |
| Login AD: "unknown error" | Hora (eLux ou DC), ou KDC não encontrado | Fase 11 inteira |
| Mirror não conecta | Bit 0x1 de `Setup.Mirror` desligado | `Mirror = Mirror \| 1` |
| Tela apaga ou bloqueia sozinha | Perfis de energia padrão | `scripts/tela-sempre-ativa.ps1` |
| Só metade das TVs acende (2 placas NVIDIA) | Sem driver ou sem Base Mosaic | Imagem com `nvidia_driver` + `20-tv-mosaic.conf` |
| TVs mostram a mesma imagem | eLux clonou as saídas (EDID idêntico) | `start-tv.sh` refaz a grade; ou emulador de EDID |
| Página da TV pisca o tempo todo | Verificação de tela em loop fechando janelas | Comparar posição real e limitar a frequência (versão atual do script) |
| Scout Board: "A system error has occurred" | DB Layer perdeu o Scout Server, ou login AD sem LDAPS | Reiniciar na ordem; usar Entra ID |
| Scout Board não abre a porta | DB Layer com "Cannot start ZMQ broker" | Reiniciar DB Layer → Board |
| Comandos do Scout não chegam a eLux de fora | Scout precisa abrir conexão até o eLux | VPN ou Scout Cloud Gateway |
| `sqlcmd` não conecta | ODBC 18 exige certificado confiável | `sqlcmd -C` |

---

## Validação final

- [ ] Serviços: `Get-Service ScoutServer,ScoutBoard,ScoutBoardDBLayer,ScoutKeepAlive,'MSSQL$SQLEXPRESS',ELIAS,MongoDB,W3SVC,'Citrix Licensing'`
- [ ] Licença ativa (`hasLicense: 0->1`; portas 22123/22125 em escuta)
- [ ] Login no Scout Board com Entra ID; administradores cadastrados
- [ ] ELIAS 18 acessível; imagem publicada sem conflitos; `.idf` baixa por HTTP (`/ELIAS/<container>/<imagem>.idf` → 200)
- [ ] eLux registrado, na OU certa, com `OSVersion` da imagem e `ConfigDataID = ConfigDataIDToHave`
- [ ] Tema e ícones aparecendo; apps abrindo (Outlook, Teams, OneDrive, VS Code, Citrix, Horizon)
- [ ] Login AD no eLux; OUs sem AD entrando direto
- [ ] Relógio do DC e dos eLux sincronizados (diferença < 1 min)
- [ ] Mirror pelo Scout Board com controle
- [ ] Tela não apaga nem bloqueia
- [ ] Parede de TVs: 6 telas distintas, logadas, na aba certa, recarregando a cada 5 min
- [ ] Backup diário do banco agendado; `credenciais.txt` copiado para um cofre

---

## Pendências e riscos conhecidos

| Item | Situação no laboratório | Recomendação |
|---|---|---|
| Login `scoutdb` é `sysadmin` | Pendente | Reduzir para `db_owner` em `ScoutEnterprise` |
| Certificado autoassinado no Scout Board | Pendente | Certificado da AC interna se mais gente for usar |
| Senhas e tokens que passaram pelo chat no projeto original | Recomendado trocar | Nunca enviar segredos em chat; trocar os expostos |
| Mapeamento dos perfis de energia 1–3 (Eco, Eco expediente, Performance) | Gravado; só o tipo 4 confirmado na configuração gerada | Conferir as seções `PowerManagement*` do `terminal.ini` gerado |
| DHCP da rede dos eLux sem DNS do AD | Contornado com `krb5.conf.d` e `hosts` | Configurar o DHCP para entregar o DNS do AD |
| eLux com EDID idêntico na parede de TVs | Contornado por script | Emuladores de EDID |
| Imagem nova não chega às OUs com setup próprio | Por desenho | Atualizar `ImageFile` em todos os setups ao trocar de imagem |
| Home persistente em partição pequena | A validar | Monitorar; arquivos no OneDrive |
| Scout Agent for Windows | Sem link de download na Citrix | Pedir ao suporte se for gerenciar PCs Windows |
| GLPI | Sem agente para eLux | Integrar exportando os dados de `Device` do Scout para o inventário nativo do GLPI |

---

## Mapa dos scripts

| Script | Fase | Função |
|---|---|---|
| `scripts/montar-idf.ps1` | 6 | Monta a IDF a partir do catálogo do ELIAS, resolvendo dependências |
| `scripts/extrair-fpm.ps1` | Diagnóstico | Extrai arquivos de um pacote eLux |
| `scripts/publicar-tema.ps1` | 9 | Publica um tema numa OU |
| `scripts/sql/apps-exemplo.sql` | 10 | Modelos de apps (Edge `--app`, StoreFront, Horizon) |
| `scripts/sql/admin-entra.sql` | 5 | Cadastra administrador do Scout Board |
| `scripts/ad-e-nondomain.ps1` | 11, 12 | AD nos setups com domínio + OU sem AD |
| `scripts/ntp-elux.ps1` | 11 | Servidores de horário em todos os setups |
| `scripts/krb5-elux.ps1` | 11 | `krb5.conf.d` com KDC fixo |
| `scripts/hosts-ad-elux.ps1` | 11 | Entradas do DC em `/setup/hosts` |
| `scripts/kiosk-sem-ad.ps1` | 12, 14 | Setup próprio sem AD para uma OU |
| `scripts/tela-sempre-ativa.ps1` | 13 | Desliga bloqueio, desligamento de monitor e suspensão |
| `scripts/criar-ou-tv-projetos.ps1` | 16 | Cria a OU da parede de TVs |
| `scripts/tv-projetos-arquivos.ps1` | 16 | Reentrega `start-tv.sh` e a configuração do Xorg |
| `scripts/criar-ou-populos-dev.ps1` | 15 | OU com home persistente, VS Code e OneDrive |
| `scripts/sql/desfazer-*.sql` | — | Desfazer temas/apps e AD/NonDomain |
| `scripts/verificar-segredos.ps1` | — | Rode antes de todo `git push` |
