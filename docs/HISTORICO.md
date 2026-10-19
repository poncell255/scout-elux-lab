# Scout Enterprise + eLux â€” Documento Global da ImplantaÃ§Ã£o

> Documento vivo. Atualizado a cada etapa executada nesta mÃ¡quina.
> Ãšltima atualizaÃ§Ã£o: 2026-10-15

---

## 1. Servidor

| Item | Valor |
|---|---|
| Hostname | WIN-8TMD3MHIPVG |
| SO | Windows Server 2025 Datacenter Evaluation (10.0.26100) |
| DomÃ­nio | Nenhum (WORKGROUP) |
| IP | 192.168.15.25/24 (Wi-Fi, perfil de rede **Public**) |
| RAM / CPU | 8 GB / 12 nÃºcleos lÃ³gicos |
| Disco C: livre | ~475 GB |
| UsuÃ¡rio admin | Administrator (local) |

> **RecomendaÃ§Ã£o:** fixe o IP 192.168.15.25 (estÃ¡tico ou reserva DHCP no roteador). Os eLux vÃ£o apontar para esse IP.

---

## 2. Status atual

| Componente | Status | Detalhe |
|---|---|---|
| SQL Server 2025 Express | OK | InstÃ¢ncia `SQLEXPRESS`, TCP 1433 fixa, autenticaÃ§Ã£o mista |
| ODBC Driver 18 | OK | 18.7.1.1 |
| Scout Server | Rodando | **Sem licenÃ§a**: portas de dispositivo 22123/22125 sÃ³ abrem depois da licenÃ§a |
| Scout Console | Instalada | Menu Iniciar > Scout Enterprise Management Suite |
| ELIAS (designer de imagens) | Instalado | |
| Scout Report / Recovery | Instalados | |
| Scout Board (web) | Rodando, **Entra ID configurado** (seÃ§Ã£o 7.6) | Acessar **neste servidor** em https://localhost:22160 (a URL de retorno registrada Ã© localhost). Login com conta POPULOS (Entra ID) |
| Scout Board DB Layer | Rodando | 22150/22151 (somente local) |
| Scout Keep Alive | Rodando | 22124 (corrigido: ver seÃ§Ã£o 6) |
| Scout TFTP | Rodando | UDP 69 (Recovery/PXE) |
| IIS (container eLux) | OK | http://192.168.15.25/eluxng/UC_RPM/ |
| Firewall | OK | Grupo de regras "Scout eLux" |
| **LicenÃ§a Scout** | **PENDENTE** | AÃ§Ã£o sua: seÃ§Ã£o 7 |

---

## 3. MÃ­dias (C:\Users\Administrator\Downloads)

| Arquivo | O que Ã© | Status |
|---|---|---|
| Scout-15.2609-3\ScoutInstaller.exe | Scout Enterprise Management Suite 15.2609 (v26.9.0), WiX Burn, assinado (Citrix) | Instalado |
| Scout-15.2609-3.zip / (1).zip | CÃ³pias do mesmo instalador | Duplicadas, pode apagar uma |
| msodbcsql.msi | ODBC Driver 18 for SQL Server 18.7.1.1 | Instalado |
| eLux-certs-2025.0.zip | Certificados de assinatura de pacotes eLux 2025 | ExtraÃ­do e publicado no container |
| Unconfirmed 97787.crdownload | ZIP **incompleto** (1,2 GB) do **container de pacotes eLux 7 (2603)** (`*.UC_ELUX7-1.0.fpm/.epm` + `.sig`) | Baixar de novo e extrair em `C:\eLuxContainer\eluxng\UC_RPM` |

Pasta de trabalho: `C:\ScoutSetup` (logs, mÃ­dia do SQL, certificados extraÃ­dos, credenciais).

---

## 4. Arquitetura

```
 Clientes eLux â”€â”€TCP/UDP 22123, TCP 22125â”€â”€â–º Scout Server â”€â”€â–º SQL Express (ScoutEnterprise)
       â”‚                                          â–²
       â”œâ”€â”€HTTP 80â”€â”€â–º IIS /eluxng/UC_RPM           â”‚ Scout Console / ELIAS (local)
       â”œâ”€â”€TCP 22124â”€â”€â–º Scout Keep Alive           â”‚
       â””â”€â”€UDP 69â”€â”€â–º Scout TFTP (Recovery/PXE)     Scout Board (web, 22160) â”€â–º DB Layer (22150/22151)
```

### Caminhos importantes

| O quÃª | Caminho |
|---|---|
| BinÃ¡rios Scout | `C:\Program Files\Unicon\Scout` |
| Config/logs Scout Server | `C:\Users\Public\Documents\Unicon\Scout\Server` (`eluxd.ini`, `eluxd.log`) |
| Pasta de licenÃ§a on-prem | `C:\Users\Public\Documents\Unicon\Scout\Server\config\` (`scout-license.jwt`) |
| Config/log Keep Alive | `C:\Users\Public\Documents\Unicon\Scout\ScoutKeepAlive` |
| ELIAS (certificados) | `C:\Users\Public\Documents\Unicon\Elias\Security` |
| Container eLux (fÃ­sico) | `C:\eLuxContainer\eluxng\UC_RPM` |
| Certificados para os dispositivos | `C:\eLuxContainer\certs` â†’ http://192.168.15.25/certs/ |
| Credenciais | `C:\ScoutSetup\credenciais.txt` (acesso restrito a Administradores) |

### Banco de dados

| Item | Valor |
|---|---|
| Servidor | `localhost\SQLEXPRESS` / `WIN-8TMD3MHIPVG,1433` |
| Banco | `ScoutEnterprise` (119 tabelas, versÃ£o 26.09.0) â€” usado pelo Scout Server **e** pelo Keep Alive |
| Login do Scout | `scoutdb` (SQL auth), atualmente **sysadmin** |
| Admin SQL | `sa` + grupo local `BUILTIN\Administrators` |
| UsuÃ¡rio inicial do Scout | `WIN-8TMD3MHIPVG\Administrator` |

> Senhas no arquivo `C:\ScoutSetup\credenciais.txt`, nunca neste MD.

### Portas (firewall de entrada, grupo "Scout eLux")

| Porta | Uso |
|---|---|
| TCP+UDP 22123 | Scout Server â†” dispositivos eLux |
| TCP 22125 | Scout Server, canal seguro |
| TCP 22124 | Scout Keep Alive |
| TCP 22160 | Scout Board (HTTPS) |
| UDP 69 | TFTP (Recovery/PXE) |
| TCP 80 | Container eLux (IIS) |
| TCP 1433 / UDP 1434 | SQL Server / SQL Browser |
| ICMP Echo | Ping |

---

## 5. Log de execuÃ§Ã£o

| Data | Etapa | Resultado |
|---|---|---|
| 2026-10-15 | Levantamento do servidor e das mÃ­dias | OK |
| 2026-10-15 | AnÃ¡lise do instalador (Burn v3.14; pacotes VC++ 2017, ReportViewer, Scout, ScoutBoard, KeepAlive; .NET 4.8 presente). SÃ³ suporta MS SQL | OK |
| 2026-10-15 | ODBC Driver 18 instalado (`msiexec /qn`) | OK |
| 2026-10-15 | SQL Server Express instalado via SSEI (o link 2022 entregou a **2025 Express 17.0.1000.7**), TCP 1433 fixa, firewall 1433/1434 | OK |
| 2026-10-15 | Login `scoutdb` criado | OK |
| 2026-10-15 | Scout instalado em modo silencioso (comando na seÃ§Ã£o 8), exit 0x0 | OK |
| 2026-10-15 | Keep Alive parou: banco `ScoutKeepAlive` nÃ£o existia. Corrigido apontando para `ScoutEnterprise` | OK |
| 2026-10-15 | Scout Server: "Scout Enterprise server started", modo on-prem, **sem licenÃ§a** | Pendente licenÃ§a |
| 2026-10-15 | IIS + container `/eluxng` e `/certs` (listagem de diretÃ³rio, MIME `application/octet-stream` para tudo, double-escaping liberado para nomes com `+`) | OK, testado HTTP 200 |
| 2026-10-15 | Firewall: regras "Scout eLux". Grupo "File and Printer Sharing" foi habilitado por engano e depois reduzido: sÃ³ Echo (ping) e SMB-In ficaram ativos na entrada | OK |
| 2026-10-15 | Scout Board responde em https://â€¦:22160 (HTTP 308 â†’ login) | OK |

---

## 6. Problemas encontrados e correÃ§Ãµes

1. **Layout do Burn trava** â€” `ScoutInstaller.exe -layout` fica preso no BA customizado. Use sÃ³ `/s` para instalaÃ§Ã£o silenciosa.
2. **Keep Alive "Cannot open database ScoutKeepAlive"** â€” o parÃ¢metro `UCPROP_SCOUTKEEPALIVE_DBNAME` deve ser o **mesmo banco do Scout**, porque o Keep Alive usa a tabela `Entity`. CorreÃ§Ã£o: `scoutkeepalive.ini` â†’ `[Database] Name=ScoutEnterprise` (backup em `scoutkeepalive.ini.bak`).
3. **Fuso horÃ¡rio padrÃ£o dos dispositivos** ficou `US/Eastern` (o BA ignorou `UCPROP_TIMEZONE`). Ajustar na Console (seÃ§Ã£o 7).
4. **Scout Board: "A system error has occurred" no login** (2026-10-15)
   - Causa 1: o DB Layer perdeu a conexÃ£o com o Scout Server depois que o ScoutServer foi reiniciado. CorreÃ§Ã£o: reiniciar na ordem `ScoutServer` â†’ `ScoutBoardDBLayer` â†’ `ScoutBoard`.
   - Causa 2 (definitiva): a autenticaÃ§Ã£o padrÃ£o do Scout Board Ã© **AD via LDAPS (porta 636)**. Sem domÃ­nio, a API responde `AD authentication failed / LDAPS_UNREACHABLE`. Contas locais nÃ£o funcionam.
   - Testei `DOMAINS=["WIN-8TMD3MHIPVG"]` no `.env` e nÃ£o resolve. Revertido ao original (backup em `C:\ScoutSetup\scoutboard.env.bak`).
   - OpÃ§Ãµes: (a) usar sÃ³ a Scout Console (recomendado agora); (b) configurar Entra ID ou Okta (OIDC/SAML) reinstalando com `UCPROP_SCOUTBOARD_AUTH_TYPE=ENTRAID_OIDC` + issuer/client id/secret/initial user; (c) ter um AD com LDAPS.
   - Aviso tambÃ©m no log: `ELIAS_TARGET` nÃ£o definido, entÃ£o a seÃ§Ã£o Software do Scout Board nÃ£o aparece. SÃ³ importa se o Scout Board for usado.

---

## 7. PrÃ³ximos passos (aÃ§Ãµes suas)

### 7.1 LicenÃ§a do Scout (bloqueante)
Contexto (2026-10-15): o licenciamento por arquivo (perpÃ©tuo/Enterprise Subscription) chegou ao **fim de vida em 15/04/2026**. Desde entÃ£o o Scout (15 2508 LTSR ou mais novo) sÃ³ licencia via **Citrix License Server ativado pelo LAS** (License Activation Service, na Citrix Cloud). O Scout Board mostra "Legacy licenses expired" e redireciona para `/licenseSwitch`.

DecisÃ£o: **License Server local nesta mÃ¡quina** (o servidor estava fora da rede da empresa).
- [x] Wagner baixou `Citrix_Licensing_11.17.2.0_BUILD_56200.zip` (assinatura Citrix vÃ¡lida, extraÃ­do em `C:\ScoutSetup\licensing`).
- [x] License Server instalado (`CitrixLicensing.exe /quiet`, exit 0). **Funciona no Windows Server 2025.** ServiÃ§os: Citrix Licensing, Citrix Web Services for Licensing, Citrix Licensing Support Service. Portas: 27000 (lmgrd), 7279 (vendor daemon CITRIX), 8083 (Licensing Manager, HTTPS).
- [x] Firewall: regras criadas pelo instalador (Citrix Licensing, Vendor Daemon, Web Services). Como o Scout Ã© local, dÃ¡ para restringir depois.
- [ ] Registrar na Citrix Cloud: https://localhost:8083 > Settings > Citrix Cloud > Register > cÃ³digo em citrix.cloud.com (Wagner).
- [ ] Scout Board > tela de licenÃ§a: modo Citrix License Server, servidor `localhost` (Wagner).
- Ferramenta de ativaÃ§Ã£o offline disponÃ­vel, se um dia o servidor ficar sem internet: `C:\Program Files (x86)\Citrix\Licensing\LS\ctxLasOfflineActivationTool.exe`.
- [ ] `Restart-Service ScoutServer` e confirmar 22123/22125: `Get-NetTCPConnection -State Listen -LocalPort 22123,22125`
- [ ] Conferir na Citrix Cloud: Licensing > Licensed deployments > License Servers > Citrix Unicon.

### 7.2 Scout Console (primeiro acesso)
- [ ] Abrir **Scout Console** (Menu Iniciar), logado como `Administrator`.
- [ ] **ConfiguraÃ§Ã£o base** (Base configuration): fuso `America/Sao_Paulo`, teclado/idioma `pt_BR`.
- [ ] Criar a estrutura de OUs (ex.: `Matriz/Lab`).
- [ ] **Firmware** da OU: servidor `192.168.15.25`, protocolo **HTTP**, container `eluxng/UC_RPM`.
- [ ] Senha de dispositivo: jÃ¡ definida no instalador (`credenciais.txt`).

### 7.3 Imagem eLux
- [ ] Baixar de novo a imagem/pacotes eLux (o `.crdownload` estÃ¡ incompleto).
- [ ] Extrair o conteÃºdo do container em `C:\eLuxContainer\eluxng\UC_RPM`.
- [ ] No **ELIAS**: Certificate Library > Import dos 3 certificados (`C:\ScoutSetup\elux-certs\eLux-certificates-2025\â€¦`: Root, Intermediate, Issuer).
- [ ] No ELIAS: criar o IDF (definiÃ§Ã£o de imagem) com os pacotes necessÃ¡rios (Citrix Workspace, RDP, browser, etc.).
- [ ] Atribuir o IDF Ã  OU na Console.
- [ ] Para atualizar firmware com validaÃ§Ã£o de assinatura: transferir os certificados para os eLux em `/setup/cacerts` (estÃ£o em http://192.168.15.25/certs/).

### 7.3.1 Estado do ELIAS (verificado em 2026-10-15)
- ELIAS desktop 26.09.0.718 instalado (`C:\Program Files\Unicon\Scout\elias.exe`), com Recovery eLux 7 / eLux RP6 em `C:\Users\Public\Documents\Unicon\Elias`.
- `elias.ini` â†’ `ContainerPath=C:\eLuxContainer\eluxng\UC_RPM\` (antes: pasta padrÃ£o; backup `C:\ScoutSetup\elias.ini.bak`).
- Certificados eLux 2025 **nÃ£o estavam** no repositÃ³rio (`Elias\Security`). Importar pelo ELIAS: Security > Manage certificates (Root â†’ Trusted Root CA, Intermediate â†’ Intermediate CA, Issuer â†’ Trusted Issuer). O Issuer `Citrix Systems` venceu em 2026-07-01; importar mesmo assim (a Citrix recomenda manter os vencidos para validar pacotes antigos).
- **ELIAS 18 (web)** nÃ£o instalado: Ã© um download separado. Sem ele, o Scout Board nÃ£o mostra a seÃ§Ã£o Software (`ELIAS_TARGET` vazio no `.env`).

### 7.3.2 ELIAS 18 (web) â€” instalado em 2026-10-15
- MÃ­dia: `ELIAS_18.26032_RC6.zip` â†’ `EliasInstaller.exe` 26.3.2.1136 (assinado Citrix). ExtraÃ­do em `C:\ScoutSetup\elias18`.
- InstalaÃ§Ã£o silenciosa (formato `/v"CHAVE=valor"`, igual ao Scout): `/s /v"INSTALLMONGODB=1" /v"ELIASDATABASE=ELIAS" /v"IISCONFIG=1" /v"IISROOT=Default Web Site" /v"ELIASPATH=ELIAS" /v"ELIASPORT=22130" /v"HASAD=0" /v"HASKEYCLOAK=0" /v"ADMINPASSWORD=..."`. Log: `C:\ScoutSetup\elias18-install.log`.
- Componentes: MongoDB 7.0.28 (serviÃ§o `MongoDB`, sÃ³ em 127.0.0.1:27017), serviÃ§o `ELIAS` (API em 22130), IIS com URL Rewrite + ARR, aplicaÃ§Ã£o `/ELIAS` no Default Web Site (proxy reverso para 127.0.0.1:22130).
- Login: `admin` + senha em `credenciais.txt` (sem AD e sem Keycloak).
- **Bug do instalador silencioso:** `server.json` ficou com `"server": "Empty"` (erro `getaddrinfo ENOTFOUND empty`). Corrigido para `localhost:27017` (backup `C:\ScoutSetup\elias-server.json.bak`).
- Logs do serviÃ§o: `C:\Windows\System32\config\systemprofile\AppData\Roaming\ELIAS\` (`elias.log`, `error.log`). O aviso "keycloak.json does not exist" Ã© inofensivo.
- Acesso local: http://localhost/ELIAS/
- **Acesso externo (decisÃ£o do Wagner, 2026-10-15): publicado com Cloudflare Access + Entra ID.**
  - TÃºnel: regra de bloqueio `^/ELIAS` (403) removida; `elux.populosplataform.com.br` â†’ IIS 80 inteiro.
  - Cloudflare Access (IdP jÃ¡ existente "Azure AD", tenant POPULOS, id `624aa2c3-ce69-4f8a-af7c-39bbeee925d7`):
    - App **"ELIAS 18 - interface"** (`elux.populosplataform.com.br/ELIAS`, id `08685fe8-5a4d-4d57-9009-af04f1ffdfb5`): sÃ³ `<email-admin>`, sessÃ£o 8h.
    - App **"ELIAS 18 - API admin"** (`elux.populosplataform.com.br/ELIAS/api/*/v1.0`, id `5db99273-7f8c-4881-bb82-126c7246b4dd`): idem.
    - App **"ELIAS 18 - downloads eLux (bypass)"** (`elux.populosplataform.com.br/ELIAS/api/*`, polÃ­tica "eLux sem login" Bypass/Everyone, id `6502497a-27d3-4019-83d8-479458eba41f`): criado pelo Wagner no painel (o Claude Code bloqueou a criaÃ§Ã£o via API).
    - Teste de 2026-10-15: `/ELIAS/` e `/ELIAS/api/*/v1.0/*` â†’ login Entra; `/ELIAS/api/<container>/<arquivo>.idf|.epm|.fpm.sig` â†’ passa direto para o ELIAS (404 em arquivo inexistente). **Validar com um eLux real** se ele usa sÃ³ esses caminhos.
  - `config.json`: o ELIAS migra a config para o MongoDB na instalaÃ§Ã£o (original em `config.json.migrated`). Um reinÃ­cio posterior falhou ("Config service initialization failedâ€¦ Unexpected end of JSON input") e o serviÃ§o caiu em defaults errados (api `localhost:22130`, AD ligado). Recriado a partir do `.migrated` com `api=elux.populosplataform.com.br`, `protocol=https`, `port=443`, `allowedOrigins` = pÃºblico + WIN-8TMD3MHIPVG + localhost + 192.168.15.25. Backup do original: `C:\ScoutSetup\elias-config.json.bak`.
  - Senha do `admin`: Wagner escolheu `<SENHA>` (fraca e exposta no chat). Trocar pela interface do ELIAS (Profile); o Claude Code bloqueou a alteraÃ§Ã£o pelo arquivo.
  - Log 2026-10-15 21:26â€“21:29: 5 logins `admin` com senha invÃ¡lida vindos de 127.0.0.1 (provavelmente teste local).

### 7.3.3 Imagem `populos-elux7` (ELIAS 18, 2026-10-16)
- Container ELIAS: **`UC_RP6_X64`** (versÃ£o `UC_ELUX7-1.0-1`), 76 EPMs / 403 FPMs importados pelo Wagner (`eLux-7.2609.0_AllPackages-1.zip`).
- Imagem criada pela API do ELIAS (`POST /ELIAS/api/UC_RP6_X64/v1.0/idfs`, corpo `{idf:{â€¦, id:"populos-elux7.idf"}}`), a partir da imagem oficial Unicon **`migration-system-7.2609.0-5`** (17 EPMs) + `ica`, `citrix_extensions`, `citrix_hdxrtme`, `vmwareviewclient`, `firefox` + FPM `mirror_server` (no EPM `xorg`). DependÃªncias resolvidas pelo script `C:\ScoutSetup\scripts\montar-idf.ps1` (acrescentou eluxrdp, baseprinter, audiolibs, videolibs, gtk2, libnss, libffmpeg etc.). Resultado: **26 EPMs, 118 FPMs, ~2,2 GB, conflicted=false, hasMissing=false**. NÃ£o assinada (`isVerified:false`).
- Flags dos FPMs no `rpmDescription` (`$FPMn=idx,arquivo,KB,FLAGS,n$`): bit 2 = obrigatÃ³rio, bit 1 = prÃ©-selecionado, 0 = opcional.
- API de login: `POST /ELIAS/api/<container>/v1.0/authenticate/` `{user,domain,password}` (cookie). A senha do `admin` ainda Ã© a do `credenciais.txt`: `<SENHA>` nÃ£o foi aplicada.
- **URL de download dos eLux:** `/ELIAS/UC_RP6_X64/<arquivo>` (ex.: `/ELIAS/UC_RP6_X64/populos-elux7.idf`, `.epm`, `.fpm`). A API (`/ELIAS/api/â€¦/v1.0/â€¦`) sÃ³ devolve metadados.
- **PendÃªncia Cloudflare:** a regra de bypass cobre sÃ³ `/ELIAS/api/*`; `/ELIAS/UC_RP6_X64/*` cai na regra "ELIAS 18 - interface" (login Entra) â†’ eLux de fora seriam barrados. Adicionar o destino `elux.populosplataform.com.br/ELIAS/UC_RP6_X64/*` Ã  aplicaÃ§Ã£o "ELIAS 18 - downloads eLux (bypass)".
- **PendÃªncia Scout:** firmware da OU Enterprise pelo Scout Board (configuraÃ§Ã£o direta no banco nÃ£o chega ao eLux).

### 7.4 Registrar os dispositivos eLux no Scout
Sem domÃ­nio nem DNS prÃ³prio, existem trÃªs opÃ§Ãµes:
1. **Manual** no assistente do eLux (primeiro boot / Setup > Scout): servidor `192.168.15.25`.
2. **DHCP** (se o roteador permitir opÃ§Ãµes customizadas): opÃ§Ã£o **222** = `192.168.15.25` (Scout server), opÃ§Ã£o **223** = ID da OU.
3. **DNS**: criar o alias `ScoutSrv` â†’ 192.168.15.25 no DNS da rede; o eLux procura esse nome automaticamente.

### 7.6 Scout Board com Entra ID (configurado em 2026-10-15)

| Item | Valor |
|---|---|
| Tenant | POPULOS (`<TENANT_ID>`) |
| App registration | `Scout Board - WIN-8TMD3MHIPVG`, appId `<APP_ID>`, single-tenant |
| Redirect URI | `https://localhost:22160/api/v1/auth/callback` |
| PermissÃµes delegadas (Graph) | openid, profile, email, offline_access, User.Read, GroupMember.Read.All, Directory.Read.All |
| Segredo | Em `credenciais.txt`, **expira em 2027-10-15** (renovar e atualizar `OIDC_CLIENT_SECRET`) |
| Config Scout Board | `.env`: `AUTH_TYPE=ENTRAID_OIDC`, `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` (ACL sÃ³ Administradores/SYSTEM). Backups: `C:\ScoutSetup\scoutboard.env.bak` (original), `scoutboard.env.pre-entra.bak` |
| AutorizaÃ§Ã£o | O Scout Board compara o e-mail/UPN do token com `Administrator.Name` no banco (ou com nomes de grupos) |

- [x] Consentimento de administrador para POPULOS (feito pelo Wagner, verificado: `AllPrincipals`).
- [x] `<email-admin>` cadastrado como administrador do Scout (tabela `Administrator`, AdministratorID 2, mesmos direitos do AdministratorID 1).
- [x] Enterprise application com **Assignment required = Yes**; Ãºnico usuÃ¡rio atribuÃ­do: Wagner Poncell.
- Para dar acesso a outra pessoa: atribuÃ­-la ao app no Entra ID **e** cadastrÃ¡-la como administrador do Scout com o e-mail dela.
- **2026-10-16:** liberados **Thiago Alves** (`<email-usuario>`, id `c29b2d46-â€¦`) e **Arthur Sabino** (`<email-usuario>`, id `8f647f8f-â€¦`): atribuÃ­dos ao app no Entra ID e cadastrados em `Administrator` (IDs 3 e 4) com os mesmos direitos do Wagner. Acesso: https://scoutboard.populosplataform.com.br. Eles **nÃ£o** tÃªm acesso ao ELIAS 18 (a polÃ­tica do Cloudflare Access libera sÃ³ o Wagner).
- [ ] Para acessar por outros computadores: adicionar a redirect URI `https://WIN-8TMD3MHIPVG:22160/api/v1/auth/callback` (ou um FQDN) e mudar `HOST_NAME` no `.env`.

Azure CLI instalado em `C:\Program Files\Microsoft SDKs\Azure\CLI2` (deslogado apÃ³s a configuraÃ§Ã£o; para mexer de novo: `az login --use-device-code --allow-no-subscriptions`).

### 7.7 Acesso externo (internet) â€” 2026-10-15

Objetivo: registrar/gerenciar eLux fora da rede, sÃ³ com internet.

**Por que nÃ£o Ã© "tudo pelo Cloudflare":** o eLux fala com o Scout por **TCP puro (22125, TLS Unicon)**. O Cloudflare no plano Free sÃ³ proxia HTTP/HTTPS; TCP arbitrÃ¡rio exige Spectrum (Enterprise) ou cloudflared no cliente (impossÃ­vel no eLux). EntÃ£o:

| Nome pÃºblico | Tipo | Destino | Uso |
|---|---|---|---|
| `scout.populosplataform.com.br` | A, **DNS only**, TTL 60, DDNS | IP pÃºblico â†’ roteador â†’ 192.168.15.25:**22125** | eLux â†” Scout Server |
| `scoutboard.populosplataform.com.br` | CNAME proxied â†’ Tunnel | https://localhost:443 (noTLSVerify) | Scout Board (login Entra ID) |
| `elux.populosplataform.com.br` | CNAME proxied â†’ Tunnel | http://localhost:80 (IIS) | Container de imagens/firmware e `/certs` |

Componentes:
- Zona Cloudflare: `populosplataform.com.br` (zoneId `<CF_ZONE_ID>`, conta `<CF_ACCOUNT_ID>`, plano Free). Registros preexistentes (`uberagent`, `loja`) nÃ£o foram tocados.
- Token Cloudflare (Tunnel:Edit, DNS:Edit, Zone:Read): `C:\ScoutSetup\cf-token.txt` (ACL Administradores/SYSTEM). **Foi exposto no chat: gerar outro e substituir o arquivo.**
- DDNS: `C:\ScoutSetup\ddns\update-cf-dns.ps1`, tarefa agendada **"Scout - DDNS Cloudflare"** (SYSTEM, a cada 5 min + no boot), log `C:\ScoutSetup\ddns\ddns.log`.
- Tunnel: `scout-WIN-8TMD3MHIPVG` (id `fc691a00-f0ed-42f6-8136-4394551cb522`, configurado remotamente no painel), serviÃ§o Windows **cloudflared** 2026.10.1.
- Scout Board: `.env` â†’ `PORT=443`, `HOST_NAME=scoutboard.populosplataform.com.br` (backup `C:\ScoutSetup\scoutboard.env.pre-tunnel.bak`). Firewall 443 sÃ³ LocalSubnet. **Uma atualizaÃ§Ã£o do Scout pode sobrescrever o `.env`: reaplicar.**
- Entra ID: redirect URI `https://scoutboard.populosplataform.com.br/api/v1/auth/callback` adicionada ao app (confirmado). A antiga `https://localhost:22160/...` ficou registrada mas nÃ£o Ã© mais usada (o Scout Board saiu da 22160); pode ser removida.

PendÃªncias (Wagner):
- [x] Roteador Vivo (192.168.15.1, firmware Broadcom): WAN Internet `ppp0.1` PPPoE = **186.215.14.23** â†’ **sem CGNAT** (verificado sÃ³ lendo `wancfg.cmd`). Interfaces `veip0.2` (VoIP, 10.254.34.251) e `veip0.3` (Mediaroom/TV) nÃ£o sÃ£o usadas.
- [ ] Roteador: ConfiguraÃ§Ãµes > Jogos & Aplicativos (NAT â€“ Virtual Servers): **TCP 22125 â†’ 192.168.15.25:22125, WAN ppp0.1** (Wagner cria; em 2026-10-15 a lista estava vazia).
- [ ] Roteador: reservar o IP 192.168.15.25 para o WIN-8TMD3MHIPVG no DHCP.
- [ ] Teste de fora (4G): `Test-NetConnection scout.populosplataform.com.br -Port 22125`.
- [ ] Scout Console: polÃ­tica para novos dispositivos irem para uma OU de quarentena.
- [ ] Firmware dos eLux externos: servidor `elux.populosplataform.com.br`, protocolo **HTTPS**, caminho `ELIAS/api/<container>` (ELIAS 18) ou `eluxng/UC_RPM` (container estÃ¡tico).
- [ ] Rotacionar o token Cloudflare e as chaves R2 expostas no chat.

LimitaÃ§Ãµes conhecidas:
- O container `elux.` Ã© pÃºblico (o eLux nÃ£o consegue mandar o cabeÃ§alho do Cloudflare Access).
- AÃ§Ãµes do Scout que dependem de o **servidor abrir conexÃ£o atÃ© o dispositivo** podem falhar para eLux atrÃ¡s de NAT. Para isso a Unicon tem o **Scout Cloud Gateway** (portas 22125/22129), avaliar depois.

### 7.8 Primeiro eLux e tema POPULOS (2026-10-15)
- Roteador: regra NAT Virtual Server `Scout eLux` TCP 22125 â†’ 192.168.15.25 (refeita na interface correta, **ppp0.1**; a primeira tentativa ficou em veip0.2/VoIP). O reinÃ­cio do roteador trocou o IP pÃºblico para **177.215.113.251** e o DDNS atualizou (a execuÃ§Ã£o durante a queda falhou e se recuperou sozinha).
- **Primeiro eLux registrado:** `Portable`, eLux 7.2609.0-12, OU **Enterprise** (GroupID 2), IP local 192.168.15.11, conectando via `scout.populosplataform.com.br` (Scout vÃª a origem 177.215.113.251 â†’ NAT loopback do roteador Vivo funciona).
- OUs existentes: Lost & Found, Enterprise, FollowMeDesktop.
- MÃ­dia nova: `eLux-7.2609.0_AllPackages-1.zip` (3,7 GB) em Downloads, a importar no ELIAS.
- **Tema `populos-theme`** (guia Citrix "Theming guide", eLux 7): arquivos em `C:\eLuxContainer\theme\populos-theme\`:
  - `desktopBackgroundImage.jpg` â† "Astronauta no Lobby Workspace Moderno.png" (1536x1024)
  - `welcomeBackgroundImage.png` â† "Futuristic Citrix Astronaut Brand Poster.png" (1122x1402), layout `leftImage`
  - `productImage.png` â† recorte sÃ³ do astronauta (400x600), no lugar do logo eLux
  - `brandImage.png` â† logo POPULOS recortado do rodapÃ© do pÃ´ster (404x91). **ObrigatÃ³rio** pelo guia (junto com config.json, desktopBackgroundImage.jpg e productImage.png); o `welcomeBackgroundImage` Ã© opcional.
  - `config.json` â†’ `accentColor #6B2FBF`, com as 4 imagens declaradas e `welcomeBackgroundLayout: leftImage`
  - Destino no eLux: `/setup/elux/themes/populos-theme/`; ativaÃ§Ã£o: `/setup/terminal.ini` [Layout] `CurrentTheme=populos-theme`; reiniciar 2x.
  - LimitaÃ§Ã£o: o guia **nÃ£o** cobre a animaÃ§Ã£o de boot (antes do sistema carregar), sÃ³ as telas de boas-vindas/login/bloqueio e o desktop.
  - **Aplicado na OU Enterprise direto no banco** (autorizado pelo Wagner), em 2026-10-15, numa transaÃ§Ã£o Ãºnica:
    - Backup antes: `C:\ScoutSetup\backup\ScoutEnterprise-pre-tema.bak`.
    - `UCFT` IDs 10â€“14 (conteÃºdo dos 5 arquivos, MemberType 1 / MemberID 2, FileType 0) + `FileEntry` (destino `/setup/elux/themes/populos-theme/<arquivo>`, Description "Tema POPULOS") + `IniEntry` (`/setup/terminal.ini` [Layout] `CurrentTheme=populos-theme`).
    - CÃ³digos usados: MemberType **1 = OU** (inferido: o Scout Board usa ContextType 1 = OU e 4 = dispositivo; `MouseKB` do eLux Portable = 4/1). O Scout Server entrega `FileEntry` + `UCFT` pelo `UCFTID`, sem filtrar `FileType`.
    - Desfazer: `C:\ScoutSetup\desfazer-tema-populos.sql`, ou restaurar o backup.
    - **Validado em 2026-10-15:** apÃ³s reinÃ­cio manual, o eLux "Portable" aplicou o papel de parede e o astronauta no lugar do logo da tela inicial â†’ MemberType 1 = OU estÃ¡ correto.
    - CorreÃ§Ã£o: `TimeModified` tinha sido gravado 3h adiantado (o `Get-Date -UFormat %s` do PowerShell 5.1 usa o horÃ¡rio local); corrigido para UTC Ã s 23:26:56.
    - `brandImage.png` trocado pelo astronauta (pedido do Wagner: ele aparece na tela de boot). Logo POPULOS guardado em `brandImage-populos-logo.png.bak`. A validar no prÃ³ximo reinÃ­cio.
    - **Fuso horÃ¡rio dos eLux corrigido (2026-10-15):** `Setup` 0 (base, herdado pela OU Enterprise) e 1 (FollowMeDesktop) estavam em US/Eastern (TimeZoneID 267), o padrÃ£o do instalador; alterados para **America/Sao_Paulo (195)**. Valor anterior em `C:\ScoutSetup\backup\timezone-antes.txt`. Vale a partir do prÃ³ximo reinÃ­cio.
    - **ReinÃ­cio pelo Scout nÃ£o chegava ao eLux: causa confirmada (23:33:26).** O Scout envia comandos conectando ao eLux na porta 22125, usando o IP de origem registrado (`PeerIPAddress` = 177.215.113.251, o IP pÃºblico, porque o eLux da LAN conecta pelo nome pÃºblico via NAT loopback). O roteador devolve essa conexÃ£o ao prÃ³prio Scout (regra 22125) â†’ o Scout conversa consigo mesmo â†’ `SSL_Accept failed`. Capturado: `192.168.15.25:59868 â†’ 177.215.113.251:22125` e `192.168.15.25:22125 â† 177.215.113.251:59868`, mesmo processo.
    - CorreÃ§Ã£o aplicada sÃ³ no "Portable" (eLux da LAN): `Device.UsePeerIP` NULL â†’ **0**, para o Scout usar o IP informado pelo eLux (192.168.15.11). Desfazer: `UPDATE Device SET UsePeerIP=NULL WHERE DeviceID=1`. A validar com um novo reinÃ­cio pelo Scout.
    - **LimitaÃ§Ã£o para eLux fora da rede:** comandos iniciados pelo Scout (reiniciar, espelhar, etc.) precisam abrir conexÃ£o atÃ© o eLux, e isso nÃ£o atravessa o roteador do outro local. Registro, configuraÃ§Ã£o, tema e atualizaÃ§Ã£o funcionam porque partem do eLux. Para comandos remotos fora da rede, a soluÃ§Ã£o da Citrix Ã© o **Scout Cloud Gateway (SCG)**.
    - `UsePeerIP=0` **nÃ£o resolveu**, nem com reinÃ­cio do Scout Server (`SSL_Accept failed` de novo Ã s 23:45:53). Fica gravado, mas nÃ£o Ã© a soluÃ§Ã£o.
    - **Scout Cloud Gateway avaliado e descartado nesta mÃ¡quina:** sÃ³ Linux (.deb Ubuntu 24.04 ou .ova), 4 CPU / 8 GB RAM / 24 GB, login via AD ou Keycloak; o host tem 7,7 GB no total e ~0,8 GB livres.
    - **SoluÃ§Ã£o escolhida (Wagner): DNS local (split DNS).** FunÃ§Ã£o DNS Server instalada neste servidor; encaminhadores 1.1.1.1 e 8.8.8.8; zona primÃ¡ria `scout.populosplataform.com.br` com `@ A 192.168.15.25` (TTL 1 min). SÃ³ esse nome Ã© sobrescrito: o resto (`elux.`, `scoutboard.`, internet) resolve normalmente. Firewall: entrada do DNS sÃ³ `LocalSubnet`. Testado: scout â†’ 192.168.15.25; google.com e login.microsoftonline.com OK.
    - **DNS do roteador alterado (Wagner):** Rede Local > DHCP > Servidor DNS EspecÃ­fico = 192.168.15.25. Confirmado Ã s 23:58:33: o eLux passou a conectar com origem **192.168.15.11** (IP local), nÃ£o mais o pÃºblico.
    - **Tema republicado como `populos-theme-v2` (2026-10-16 00:0x):** mesmo depois de trocar o conteÃºdo de `productImage`/`brandImage` na UCFT, o eLux continuava com o astronauta com fundo (cache: as entradas de transferÃªncia nÃ£o mudaram, entÃ£o ele nÃ£o baixou de novo). Mudados os 5 destinos para `/setup/elux/themes/populos-theme-v2/`, `config.json` com `name: populos-theme-v2` e `CurrentTheme=populos-theme-v2`. Para publicar novas mudanÃ§as de imagem no futuro, repetir esse padrÃ£o (v3, v4â€¦).
    - Pendente (Wagner): no roteador, reservar o IP 192.168.15.25 para o WIN-8TMD3MHIPVG.
    - **ReinÃ­cio pelo Scout validado (Wagner, 2026-10-16)** depois do DNS local.
    - **Qual imagem aparece onde** (descoberto extraindo os pacotes `elux_theme` e `splashscreen` do `eLux-7.2609.0_AllPackages-1.zip`; o formato `.fpm` Ã© cabeÃ§alho "Lexu" + gzip + cpio newc; script `C:\ScoutSetup\scripts\extrair-fpm.ps1`):
      - **Tela de boot** (`ucsplash`, prÃ©-carregamento): `/setup/elux/theme_active/productImage.png`, num quadro de 304x304, `contain`. O `theme_active` Ã© atualizado quando o tema Ã© ativado, entÃ£o a mudanÃ§a aparece **no boot seguinte**.
      - **BotÃ£o Iniciar / logotipo nas telas de entrada:** `brandImage` (o original Ã© o logotipo "unicon").
      - **Tela de entrada:** `welcomeBackgroundImage`, conforme `welcomeBackgroundLayout`.
      - Tema original da Unicon extraÃ­do em `C:\ScoutSetup\elux-pkgs\elux_theme\usr\share\elux\themes\unicon_default\` (`accentColor #154EC7`).
    - **Tema `populos-theme-v3`:** `brandImage` = logotipo **unicon original** (pedido do Wagner); `productImage` = astronauta sem fundo (tela de boot); `desktopBackgroundImage` = recepÃ§Ã£o POPULOS; `welcomeBackgroundImage` = pÃ´ster. Backup do brand anterior: `brandImage-astronauta.png.bak`. Risco aceito: se este servidor desligar, a rede de casa fica sem DNS (voltar o DNS do roteador para automÃ¡tico resolve).
    - `brandImage.png` final: astronauta com **fundo transparente** (recorte por cor + maior componente conectado), `C:\ScoutSetup\astronauta-transparente.png`, gravado na UCFTID 13. Depois substituÃ­do pela versÃ£o do Wagner sem fundo (`311d31a7-â€¦-removebg-preview.png`, cortada para 175x417) em **brandImage (UCFTID 13) e productImage (UCFTID 12)**. O astronauta com fundo que continuava aparecendo era o `productImage` (backup em `productImage-com-fundo.png.bak`).
    - AnimaÃ§Ã£o de boot do firmware (antes do eLux carregar): nÃ£o Ã© coberta pelo tema; sÃ³ via branding OEM da Citrix/Unicon. O `grub/splash.png` do Scout Ã© sÃ³ do Recovery (PXE).

### 7.9 VPN OpenVPN para comandos do Scout em eLux remotos (2026-10-16)

**Problema:** com o eLux no 4G (IP 10.63.152.216 da operadora, saindo como 189.40.74.252), registro, configuraÃ§Ã£o e tema funcionam, mas o reinÃ­cio pelo Scout nÃ£o chega: o Scout precisa abrir conexÃ£o atÃ© o eLux (porta 22125), e o CGNAT da operadora bloqueia. SÃ³ funciona quando o eLux estÃ¡ na mesma rede.

**SoluÃ§Ã£o escolhida (Wagner): OpenVPN neste servidor** (o eLux 7 jÃ¡ traz o OpenVPN 2.5; o Scout Cloud Gateway nÃ£o cabe aqui).

| Item | Valor |
|---|---|
| Servidor | OpenVPN 2.7.8 (MSI oficial, assinado OpenVPN Inc.), componentes OpenVPN + Service + TAP-Windows6 + OpenSSL |
| Config | `C:\Program Files\OpenVPN\config-auto\scout-vpn-server.ovpn` (chaves embutidas; ACL Admins/SYSTEM/`NT SERVICE\OpenVPNService`) |
| ServiÃ§o | `OpenVPNService` (conta `NT SERVICE\OpenVPNService`), log `C:\ProgramData\OpenVPN\Log\scout-vpn-server.log` |
| Rede | UDP 1194, `tun`, `topology subnet`, **10.8.0.0/24**, servidor **10.8.0.1** (adaptador "OpenVPN TAP-Windows6"), `duplicate-cn` (um certificado para todos os eLux), sem rota padrÃ£o |
| PKI | `C:\ScoutSetup\openvpn-pki\` (CA RSA 3072 "POPULOS Scout VPN CA" atÃ© 2036; servidor e cliente `elux-enterprise` RSA 2048 atÃ© 2031; `tc.key` tls-crypt). **A `ca.key` fica aqui: proteger/backup.** |
| DNS | Push `dhcp-option DNS 10.8.0.1`; polÃ­tica no DNS do Windows: sub-rede cliente `RedeVPN` 10.8.0.0/24 â†’ escopo `EscopoVPN` â†’ `scout.populosplataform.com.br = 10.8.0.1`. Rede local continua recebendo 192.168.15.25. |
| Perfil eLux | `C:\ScoutSetup\openvpn-pki\populos.ovpn` (remote `scout.populosplataform.com.br 1194`), distribuÃ­do na OU Enterprise â†’ `/setup/openvpn/populos.ovpn` (UCFTID 17, FileEntry "VPN POPULOS") |
| Firewall | Regra "OpenVPN eLux (UDP 1194)" |

LiÃ§Ãµes: o serviÃ§o roda como `NT SERVICE\OpenVPNService` e nÃ£o lia arquivos em `C:\ScoutSetup` ("Cannot pre-load keyfile"); resolvido embutindo as chaves na config. `windows-driver` e `persist-key` estÃ£o obsoletos no 2.7.

**Validado na rede local (2026-10-16 10:21):** perfil VPN criado no Scout Board (OU Enterprise > Rede > VPN: "OpenVPN", tipo OpenVPN, configuraÃ§Ã£o `populos`, conectar automaticamente; gravado em `NetworkProfile` ID 4, `VpnType=1`). O eLux conectou (TLS 1.3, AES-256-GCM), recebeu **10.8.0.2** e o DNS 10.8.0.1, e o Scout passou a registrar `IP_Address = PeerIPAddress = 10.8.0.2`. Scout â†’ eLux 10.8.0.2:22125 aberto. **O DNS entregue pela VPN funciona no eLux.**
- Efeito colateral: ao salvar a VPN, o Scout Board criou o **setup 2** prÃ³prio da OU Enterprise (`UseParent=0`), copiado da base, com fuso America/Sao_Paulo (conferido).
- O eLux pede **usuÃ¡rio e senha** na tela "Accessing OpenVPN" porque `NetworkProfile.Username/Pass` estÃ¡ vazio. O servidor autentica sÃ³ por certificado e ignora o que for digitado (`elux`/`elux` funcionou). O Scout Board nÃ£o mostra esses campos (sÃ³ proxy em Advanced), e a senha Ã© gravada criptografada pelo Scout â†’ preencher pela **Scout Console**.

PendÃªncias (Wagner):
- [ ] Roteador: Redirecionar Portas â†’ **UDP 1194 â†’ 192.168.15.25**, interface **ppp0.1**. **Problema:** o roteador Vivo grava a regra como **TCP** mesmo com UDP escolhido (duas tentativas). OpÃ§Ãµes: regra com "TCP/UDP", se existir; ou trocar a VPN para TCP 1194 (servidor `proto tcp-server` + perfil novo `populos-tcp.ovpn` + `VpnConfig=populos-tcp`). A troca foi bloqueada pelo classificador de permissÃµes do Claude Code ("Modify Shared Resources") e aguarda decisÃ£o do Wagner. Backup previsto da config UDP: `C:\ScoutSetup\backup\scout-vpn-server-udp.ovpn`.
- Roteador em 2026-10-16: regra Scout 22125 TCP recriada (nome "OpenVPNeLux") e regra 1194 TCP.
- **VPN passada para TCP 1194 (2026-10-16 10:43, autorizado pelo Wagner):** servidor `proto tcp-server` (backup UDP em `C:\ScoutSetup\backup\scout-vpn-server-udp.ovpn`), firewall "OpenVPN eLux (TCP 1194)", perfil novo `populos-tcp.ovpn` (`proto tcp-client`) na OU Enterprise â†’ `/setup/openvpn/populos-tcp.ovpn` (UCFTID 18), `NetworkProfile` 4 `VpnConfig` = `populos-tcp`. O `populos.ovpn` (UDP) continua no eLux, sem uso.
- Teste no 4G antes da troca: o eLux falava com o Scout (origem 181.77.138.37, IP 10.246.23.216 da operadora), mas a VPN nÃ£o conectava (UDP bloqueado no roteador).
- [ ] Scout Console: OU Enterprise > Setup > Rede > VPN > perfil OpenVPN â†’ usuÃ¡rio `elux` / senha `elux`, para o eLux parar de pedir.
- [ ] Teste no 4G: o eLux deve aparecer no Scout com origem 10.8.0.x e aceitar reinÃ­cio pelo Scout. **Risco:** se o eLux nÃ£o aplicar o DNS recebido pela VPN, ele continua falando com o Scout pelo IP pÃºblico, e o plano precisa de ajuste.

### 7.10 MudanÃ§a para modo LOCAL, sem Cloudflare e sem VPN (2026-10-19)

**Contexto:** servidor levado para outra rede (Wi-Fi, IP **10.5.0.166/22**, gateway 10.5.0.1, IP pÃºblico 179.191.87.86). Essa rede **bloqueia a saÃ­da na porta 7844 (UDP e TCP)**, a Ãºnica que o Cloudflare Tunnel usa â†’ Scout Board pÃºblico devolvia 530. Wagner removeu a VPN (o serviÃ§o OpenVPN nÃ£o existe mais) e pediu: **sem Cloudflare, Entra ID local, sÃ³ acesso local**.

Feito:
- **AtualizaÃ§Ã£o (2026-10-19):** o Wagner trocou as redirect URIs do Entra ID para `https://10.5.0.166:22160/api/v1/auth/callback` (+ a pÃºblica). O `.env` foi para `HOST_NAME=10.5.0.166` (backup `scoutboard.env.localhost.bak`) e o ELIAS `api=10.5.0.166`, para outras mÃ¡quinas da rede acessarem: **Scout Board https://10.5.0.166:22160**, **ELIAS http://10.5.0.166/ELIAS/**. Firewall 22160 e 80 liberados (perfil de rede Public).
- **Scout Board em modo local:** `.env` â†’ `PORT=22160`, `HOST_NAME=localhost` (Entra ID mantido; a redirect URI `https://localhost:22160/api/v1/auth/callback` jÃ¡ estava registrada). Backup do modo pÃºblico: `C:\ScoutSetup\backup\scoutboard.env.modo-publico.bak`. **Acesso: https://localhost:22160** (sÃ³ neste servidor).
- DBLayer tinha subido com "Cannot start ZMQ broker" e nÃ£o respondia (Scout Board parava antes de abrir a porta). Reiniciar DBLayer â†’ Scout Board resolveu.
- **Cloudflare removido da mÃ¡quina:** serviÃ§o `cloudflared` desinstalado (`cloudflared service uninstall` + MSI), pasta `C:\ProgramData\cloudflared` (token do tÃºnel) apagada, tarefa **"Scout - DDNS Cloudflare"** removida.
- **ELIAS em modo local:** `config.json` â†’ `api=WIN-8TMD3MHIPVG`, `http`, porta 80, `allowedOrigins` = WIN-8TMD3MHIPVG, localhost, 10.5.0.166. Backup do modo pÃºblico: `C:\ScoutSetup\backup\elias-config.modo-publico.json`. Acesso: http://localhost/ELIAS/. Download dos eLux: `http://10.5.0.166/ELIAS/UC_RP6_X64/populos-elux7.idf` (testado 200).

Para eLux nesta rede:
- Scout: servidor **`10.5.0.166`** (os nomes `scout.populosplataform.com.br` e WIN-8TMD3MHIPVG nÃ£o resolvem nesta rede).
- Firmware: protocolo **HTTP**, servidor `10.5.0.166`, caminho `ELIAS/UC_RP6_X64`, IDF `populos-elux7.idf`.
- O IP 10.5.0.166 Ã© por DHCP; se mudar, reconfigurar.

Sobras na nuvem (nÃ£o afetam a mÃ¡quina; apagar no painel se nÃ£o for voltar a usar): tÃºnel `scout-WIN-8TMD3MHIPVG`, registros DNS `scout`/`scoutboard`/`elux.populosplataform.com.br`, 4 aplicaÃ§Ãµes Access do ELIAS, token de API (`C:\ScoutSetup\cf-token.txt`, **revogar**), redirect URI pÃºblica no app do Entra ID. Ainda instalados e sem uso nesta rede: funÃ§Ã£o DNS Server (zona `scout.populosplataform.com.br` â†’ 192.168.15.25), License Server (precisa de internet para o LAS, que continua funcionando).

### 7.11 OU Populos: Outlook, Teams e logo POPULOS no boot (2026-10-19)
- OU **Populos** = `Groups.GroupID 4` (criada pelo Wagner; herda o setup base, `UseParentApps=1`). Nenhum eLux nela ainda.
- Login no Scout Board por linha de comando **nÃ£o funciona**: quando o navegador do usuÃ¡rio abre o callback, o Scout Board jÃ¡ tenta trocar o cÃ³digo (uso Ãºnico), e a segunda tentativa recebe `AADSTS70008`. Tudo foi feito direto no banco (backup `C:\ScoutSetup\backup\ScoutEnterprise-pre-populos-ou.bak`).
- **CÃ³digos descobertos no Scout Board:** `AppTypeID` browser=3, local=5, rdp=10, omnissa=15, storefront=17, avd=19; `BrowserType` firefox=3, chromium=4, builtin=5, chrome=6, edge=7; AppMode normal=0, kiosk=1. O Scout Server entrega os apps por `Application.GroupID` (OU) + `AppLevel` (usado 1 = OU; os modelos globais sÃ£o GroupID -1 / AppLevel 6).
- **Ãcones de aplicativo:** `UCFT` com `FileType=1`, `FileMode=-1`, global (-1/-1), `FileName=<IconName>.png`, 32x32; o Scout Server entrega em `/setup/icons/<w>x<h>/`. Gravados `outlook.png` (UCFTID 26) e `teams.png` (UCFTID 27), a partir de `microsoft_office_outlook_logo_icon_145721.png` / `microsoft_office_teams_logo_icon_145726.png`.
- **Apps (Firefox, na Ã¡rea de trabalho):** Outlook (ApplicationID 4, `https://outlook.office.com`), Teams (ApplicationID 5, `https://teams.microsoft.com`). NÃ£o hÃ¡ cliente nativo de Outlook/Teams para eLux; o Teams no navegador Ã© o caminho suportado pela Microsoft em Linux.
- **Tema `populos-ou-v1`** na OU Populos (UCFTID 21â€“25, FileEntry "Tema POPULOS OU", `CurrentTheme=populos-ou-v1`): igual ao da Enterprise, mas `productImage` (tela de boot) = sÃ­mbolo POPULOS sem fundo (`images-removebg-preview.png`, cortado em 357x356).
- **Firmware e mudanÃ§a de OU (2026-10-19, direto no banco; backup `ScoutEnterprise-pre-firmware.bak`):** `Server` 1 (tipo 7) = `10.5.0.166`; `Firmware` 1 â†’ `Protocol=0` (HTTP; cÃ³digos FTP=1, FTPS=4, HTTP=0, HTTPS=3), `Path=ELIAS/UC_RP6_X64`, `AutoCheckUpdate=1`; `Setup` 0 (herdado pela OU Populos, Lost & Found e FollowMeDesktop, que tambÃ©m usa o firmware 1) â†’ `ImageFile=populos-elux7.idf`. eLux **Portable01** (DeviceID 2, 10.5.1.4, eLux 7.2603.1000-3) movido para a OU Populos (`GroupID 4`). O eLux renomeado ganhou um DeviceID novo (o DeviceID 1 "Portable" nÃ£o existe mais).
- Resultado 14:44â€“15:04: **Ã­cones do Outlook/Teams apareceram no eLux** (formato de Application/UCFT validado). **Firmware nÃ£o aplicado:** nenhuma requisiÃ§Ã£o do eLux ao IIS â†’ como a VPN, configuraÃ§Ã£o de firmware gravada direto no banco nÃ£o dispara a atualizaÃ§Ã£o; precisa do Scout Board (Apply + comando Update). O eLux oscilou entre OU 4 e 2 Ã s 14:46â€“14:47.
- **Imagem `populos-elux7-v2`** (ELIAS, 28 EPMs, ~2,8 GB, sem conflitos) = v1 + `microsoft_edge`. `Setup` 0 `ImageFile` â†’ `populos-elux7-v2.idf`.
- **Outlook/Teams viraram aplicativo local** (`AppTypeID=5`, linhas `Browser` removidas, `Local.Type=CUSTOM`): `/usr/bin/microsoft-edge --app=https://outlook.office.com --no-first-run` e idem para `https://teams.microsoft.com`. Abrem como janela de aplicativo (sem barra de endereÃ§o). **Dependem do Edge, que sÃ³ existe depois de o eLux atualizar para a v2.** O Firefox nÃ£o tem `--app` (sÃ³ `--kiosk`).
- **AtualizaÃ§Ã£o para a v2 travando (2026-10-19 ~15:00):** o eLux baixou o `populos-elux7-v2.idf` (a mudanÃ§a de `Setup.ImageFile` feita pelo banco **chegou**) e parte dos pacotes (44 Ã s 14:54â€“14:55; ~20 Ã s 15:03â€“15:04, depois de reiniciar), todos HTTP 200, sem pedir `.sig`, e parou. `Device.UpdateInfo` = `-1,0,â€¦,257,-2147483648,â€¦` (falha; o cÃ³digo 257 nÃ£o estÃ¡ documentado publicamente). O Portable01 roda de um **pendrive SanDisk 58 GB** com partiÃ§Ãµes fixas: system1 3,75 GB (0,7 usado), system2 3,75 GB, **update 3,75 GB com 3,0 GB ocupados**. HipÃ³tese: falta de espaÃ§o na partiÃ§Ã£o update (sobras de tentativas). AÃ§Ã£o: `Firmware.FormatBeforeUpdate=1` (firmware 1), equivalente Ã  opÃ§Ã£o "formatar a partiÃ§Ã£o de update antes da entrega" do comando Delivery do Scout.
- **AtualizaÃ§Ã£o concluÃ­da:** Ã s 15:19 o Portable01 voltou como **7.2609.0-12** (127 downloads do IIS). **Outlook e Teams via Edge `--app` validados pelo Wagner.**
- **Mirror:** `Setup.Mirror=16398`, `MirrorAcceptTimeout=10` (pede confirmaÃ§Ã£o no eLux); porta 5900 aberta no eLux, mas nÃ£o manda o banner RFB numa conexÃ£o VNC comum. O mirror do **Scout Board** usa WebRTC (`COMMAND.MIRROR_SDP_OFFER` / `MIRROR_ICE_CANDIDATE` Ã s 18:27 UTC) e o eLux **nÃ£o respondeu** (nenhuma resposta SDP nos logs); o `.env` nÃ£o tem TURN. PrÃ³ximo teste: mirror pela **Scout Console** (mÃ©todo clÃ¡ssico).
- **Citrix Workspace** (ApplicationID 6, `AppTypeID 17` StoreFront, valores do modelo Citrix, `Stores` vazio) e **Horizon** (ApplicationID 7, `AppTypeID 15` Omnissa; `VDA`: Server vazio, `UseSSL=1`, `ShowLastUser=1`, `Protocol=0`, `AllowH264=1`; valores de Protocol/Options **assumidos**, sem modelo para copiar) criados na OU Populos, na Ã¡rea de trabalho, sem Ã­cone prÃ³prio. Faltam as URLs da loja Citrix e do servidor Horizon.
- **Por que mudanÃ§as gravadas no banco Ã s vezes nÃ£o chegam ao eLux (descoberto 2026-10-19):** cada `Device` tem `ConfigDataID` (versÃ£o que o eLux tem) e `ConfigDataIDToHave` (versÃ£o que deveria ter). Iguais = o eLux nÃ£o baixa nada. O Scout Server sÃ³ regenera a configuraÃ§Ã£o quando `SetupChanged=1 OR SetupUserChanged=1 OR ApplicationsChanged=1` (o Scout Board marca isso no **Apply**). Explica a VPN e o Citrix/Horizon que nÃ£o apareceram. **Regra daqui em diante:** depois de gravar configuraÃ§Ã£o/aplicativos no banco, marcar `UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=<OU>` e reiniciar o eLux. Feito para o Portable01 Ã s 15:36 (as marcas ficam pendentes atÃ© o prÃ³ximo contato).
- **Horizon validado (abriu).** Citrix Workspace nÃ£o abriu: os FPMs opcionais de Self-Service nÃ£o estavam na imagem. **Imagem `populos-elux7-v3`** (30 EPMs, ~3,0 GB, sem conflitos) = v2 + `ica_selfservice`, `ica_webview`, `ctxext_ucselfservice`, `ctxext_ucselfservice_theme`, `ica_msteams`, `ica_usbrdr`, `ica_mmrdr`, `ica_browserrdr`, `ica_h264`. `Setup` 0 â†’ `populos-elux7-v3.idf`.
- Mirror pelo Scout Board: o Scout Board abre `/mirror?host=10.5.1.4:5902` (no eLux sÃ³ a 5900 estÃ¡ aberta). O ScoutServer tem logs `mirrorSdpOffer`/`mirrorIceCandidate`, mas nada apareceu â†’ `eluxd.ini` `Debug=1` â†’ **5** (backup `C:\ScoutSetup\backup\eluxd.ini.bak`; voltar a 1 depois do diagnÃ³stico) e reinÃ­cio de ScoutServer/DBLayer/ScoutBoard Ã s 15:58.
- **PapÃ©is de parede sumiram depois de o Wagner mover o eLux entre OUs** (passou pela OU nova **POC-BCR**, GroupID 5, sem tema). HipÃ³tese: o eLux apaga os arquivos do tema ao entrar numa OU sem tema, e o Scout nÃ£o reenvia arquivos que considera jÃ¡ entregues (compara a data). CorreÃ§Ã£o: `TimeModified` dos 10 arquivos de tema (OUs 2 e 4) = agora + `SetupChanged/ApplicationsChanged=1`.
- **Erro na atualizaÃ§Ã£o para a v3 (16:16):** download ok (37 arquivos, 53 MB, todos 200), mas a instalaÃ§Ã£o falhou (`UpdateInfo` â€¦`,259,-2147483648`). A **partiÃ§Ã£o `custom` caiu de 1,9 GB para 0**: Ã© onde ficam os pacotes que nÃ£o cabem em system1 (Edge, Firefox, Citrix, Horizonâ€¦). Causa provÃ¡vel: **`Firmware.FormatBeforeUpdate=1`, que eu tinha ligado**, apagou mais que a Ã¡rea temporÃ¡ria. **Desligado (`FormatBeforeUpdate=0`) Ã s 16:18** + `SetupChanged=1` para repetir a atualizaÃ§Ã£o. LiÃ§Ã£o: nÃ£o ligar essa opÃ§Ã£o sem documentaÃ§Ã£o do que ela formata.
- **16:23â€“16:36:** tela do eLux "The idf has not been fully downloaded before formatting. eLux halted due to an error" (o eLux nÃ£o apaga o sistema com download incompleto). Ele baixa sÃ³ o `.idf` e desiste (erro 259): restos incompletos na partiÃ§Ã£o update (2,2 GB) e a `custom` vazia. **O sÃ­mbolo POPULOS apareceu na tela de boot (tema da OU Populos validado).** Para sair do ciclo: `Firmware.AutoCheckUpdate=0` (16:37). PrÃ³ximo passo: comando **Delivery** do Scout Board com "formatar partiÃ§Ã£o de update" (documentado: sÃ³ a update) e depois **Update**; se falhar, reinstalar o pendrive (Recovery).
- O Scout Board desta versÃ£o nÃ£o tem "formatar partiÃ§Ã£o de update" no comando **Deliver software**; tem **"Complete software image delivered"** (entrega a imagem inteira, nÃ£o sÃ³ a diferenÃ§a).
- **Imagem `populos-elux7-v4`** (29 EPMs, **~2,7 GB**, sem conflitos) = v3 **sem Firefox** (275 MB; o Outlook/Teams usam o Edge), para caber com folga na partiÃ§Ã£o update (3,75 GB). Maiores pacotes: Edge 616 MB, desktop_environment 425, ica 364, xorg 344, baseos 228, wlandrivers 173. `Setup` 0 â†’ `populos-elux7-v4.idf`.
- **AtualizaÃ§Ã£o para a v4 concluÃ­da (Wagner, via Deliver software com imagem completa + Update).** Citrix Workspace ainda nÃ£o abria: o tipo StoreFront (`/usr/bin/ucselfservice`) precisa da URL da loja em `Storefront.Stores`, que estÃ¡ vazia. Troca provisÃ³ria: app 6 â†’ **local `/usr/bin/selfservice`** (Self-Service nativo da Citrix, abre a tela de adicionar conta). A linha `Storefront` do app 6 foi mantida; para voltar ao StoreFront com loja: `AppTypeID=17`, apagar a linha `Local` 6 e preencher `Stores`.
- **Self-Service nativo validado** (abriu). Depois, com a loja informada pelo Wagner, o app 6 voltou ao **StoreFront** (`AppTypeID=17`, linha `Local` 6 removida, `Storefront.Stores='https://populosntx.cloud.com'`; o Scout Server converte em `StoreUrl0`â€¦ para o eLux) com Ã­cone **`citrix`** (UCFT FileType 1, a partir de `bfe68db6â€¦_icon.ico`, 32x32). Se o StoreFront nÃ£o abrir, voltar ao local `/usr/bin/selfservice`.
- **Modelo global "Citrix" removido** (ApplicationID 2 + linha Storefront 2; aparecia em todas as OUs por heranÃ§a, `UseParentApps=1`). Ficaram os modelos Chromium (1) e RDP (3).
- **OU Bom Jesus criada** (`GroupID 6`, cÃ³pia das colunas da OU Populos, raiz `LocationID -1`; backup `ScoutEnterprise-pre-bomjesus.bak`). Apps copiados: Outlook (8), Teams (9), Citrix Workspace (10, mesma loja), Horizon (11). **Tema `bomjesus-v1`**: papel de parede `colegio bom jesus.jpg` (sÃ³ 547x365, fica esticado), tela de boot = `bom_jesus-removebg-preview.png` (cortado em 297x337), brand = unicon, `accentColor #005020` (verde do logo), `welcomeBackgroundLayout none` (sem o pÃ´ster do astronauta).
- **Papel de parede da Bom Jesus trocado** para `bomjesus2.png` (1914x1044, prÃ©dio do ColÃ©gio Bom Jesus Aurora; salvo como JPG q92) â†’ tema **`bomjesus-v2`** (destinos `/setup/elux/themes/bomjesus-v2/`, `CurrentTheme=bomjesus-v2`). Backup do anterior: `desktopBackgroundImage-v1.jpg.bak`.
- **Papel de parede da Bom Jesus trocado de novo** para o pÃ´ster `71863f23-1cfa-451d-bfd7-8e5dd81064f1.png` ("ColÃ©gio Bom Jesus â€“ EducaÃ§Ã£o e tecnologia florescendo juntas", com POPULOS | Citrix | Unicon). Como Ã© vertical (1122x1402), foi montado em **1920x1080**: pÃ´ster inteiro centralizado e laterais com o prÃ³prio pÃ´ster ampliado e desfocado (prÃ©via `C:\ScoutSetup\diag\preview-bomjesus-v3.png`). Tema **`bomjesus-v3`**. Backup do anterior: `desktopBackgroundImage-v2.jpg.bak`.
- **Papel de parede final da Bom Jesus:** `549aa68b-bbfe-43ca-a209-50a721b7554b.png` (versÃ£o horizontal do pÃ´ster, 1672x941) ampliado para 1920x1080, com **faixa escura em gradiente na lateral esquerda** (300 px, verde muito escuro com atÃ© 80% de opacidade, sumindo antes do tÃ­tulo) para os nomes brancos dos Ã­cones ficarem legÃ­veis. PrÃ©via com Ã­cones simulados: `C:\ScoutSetup\diag\preview-bomjesus-v4.png`. Tema **`bomjesus-v4`**; backup do anterior `desktopBackgroundImage-v3.jpg.bak`.
- **OU Modo Kiosk** (`GroupID 7`, cÃ³pia da Populos, `UseParentApps=0` para nÃ£o herdar os modelos Chromium/RDP; backup `ScoutEnterprise-pre-kiosk.bak`): sÃ³ o **Citrix Workspace** (ApplicationID 12, StoreFront, mesma loja, Ã­cone citrix) com `AutoStart=1` (abre ao ligar), `TM=1` (reabre se fechado), `AutostartResources='POPULOS LOCAL'` (abre esse desktop depois do login) e `DesktopsUseFullscreen=1`. Tema da Populos copiado (FileEntry "Tema Kiosk", `CurrentTheme=populos-ou-v1`).
  - **Login automÃ¡tico nÃ£o configurado de propÃ³sito:** (1) seria a senha pessoal do Wagner gravada num quiosque, e qualquer um entraria como ele; o certo Ã© uma conta de serviÃ§o sÃ³ com acesso ao "POPULOS LOCAL"; (2) a loja Ã© **Citrix Cloud** (`populosntx.cloud.com`), com login web/Entra, e o repasse de usuÃ¡rio/senha do eLux (`Storefront.Username/Pass/Domain`, a senha Ã© gravada criptografada pelo Scout) funciona com StoreFront local, nÃ£o com Citrix Cloud. A senha do Wagner apareceu no chat: recomendado trocar.
  - Mapeamentos: `Application.AutoStart` 1 = iniciar automaticamente; `Application.TM` 1 = reiniciar o app se fechado (UI "restartApp").
- **Descanso de tela/energia (pedido do Wagner: a tela apaga rÃ¡pido):** `ScreenSaver` 1 e 2 = modo `blank` apÃ³s 0:05:00; `PowerManagementProfile` vazio (o eLux usa os padrÃµes). Tentativa de criar perfis pelo banco desfeita (ROLLBACK): os campos `ActionOn*`/`BrightnessLevel` sÃ£o obrigatÃ³rios e nÃ£o deu para confirmar o nÃºmero de cada aÃ§Ã£o (`actionNone/Suspend/DisplayOff/Shutdown/Reboot/Ask/Logoff`); um valor errado pode desativar o botÃ£o de energia. **Fazer pelo Scout Board** (configuraÃ§Ã£o base + Enterprise + FollowMeDesktop): monitor/suspensÃ£o/descanso desativados.
- Mensagem do Scout encontrada: "Client has no mirror package installed, request aborted" â†’ o mirror exige o pacote no eLux (a v4 tem `mirror_server`).
- A validar: os dois apps aparecerem na OU Populos no Scout Board; um eLux movido para a OU recebendo apps, Ã­cones e tema (2 reinÃ­cios para o tema; o Firefox precisa estar na imagem do eLux, e a `populos-elux7` jÃ¡ tem).

### 7.5 Endurecimento (depois que tudo estiver funcionando)
- [ ] Reduzir `scoutdb` de sysadmin para `db_owner` no `ScoutEnterprise`.
- [ ] Trocar o certificado autoassinado do Scout Board, se for expor para outros usuÃ¡rios.
- [ ] Mudar o perfil da rede para Private, ou restringir as regras ao escopo `LocalSubnet`.
- [ ] Rotina de backup do banco `ScoutEnterprise` (o Express nÃ£o tem SQL Agent: usar Agendador de Tarefas + `sqlcmd`/PowerShell).
- [ ] Ativar o Windows Server (o Evaluation expira).

---

## 8. ReferÃªncia: comando de instalaÃ§Ã£o silenciosa usado

```powershell
ScoutInstaller.exe /s /l C:\ScoutSetup\scout-install.log `
 /v"UCPROP_DBTYPE=2" /v"UCPROP_DBSERVER=localhost\SQLEXPRESS" /v"UCPROP_DBNAME=ScoutEnterprise" `
 /v"DB_SCOUT_DB_AUTHENTICATION=SQL Server Authentication" /v"UCPROP_DBUSER=scoutdb" /v"UCPROP_DBPASSWORD=<senha>" `
 /v"UCPROP_ENCRYPT=0" /v"UCPROP_TRUSTSERVERCERTIFICATE=1" /v"UCPROP_DBCREATE=1" `
 /v"UCPROP_INITIAL_SCOUT_USER=WIN-8TMD3MHIPVG\Administrator" /v"DEVICE_PASSWORD=<senha>" `
 /v"LS=0" /v"ADDLOCAL=CommonFeature,Server,Console,Recovery,Elias,Report" `
 /v"INSTALL_SCOUT_FEATURE=1" /v"INSTALL_SCOUTBOARD_FEATURE=1" /v"INSTALL_SCOUTKEEPALIVE_FEATURE=1" `
 /v"UCPROP_SCOUTKEEPALIVE_DBSERVER=localhost\SQLEXPRESS" /v"UCPROP_SCOUTKEEPALIVE_DBNAME=ScoutEnterprise" `
 /v"UCPROP_SCOUTKEEPALIVE_AUTHENTICATION=SQL Server" /v"UCPROP_SCOUTKEEPALIVE_DBUSER=scoutdb" `
 /v"UCPROP_SCOUTKEEPALIVE_DBPASSWORD=<senha>" /v"UCPROP_SCOUTKEEPALIVE_TRUSTSERVERCERTIFICATE=1"
```
> JÃ¡ corrigido aqui: `UCPROP_SCOUTKEEPALIVE_DBNAME=ScoutEnterprise`.
> Desinstalar: `ScoutInstaller.exe /s /uninstall`

### VerificaÃ§Ã£o rÃ¡pida de saÃºde
```powershell
Get-Service ScoutServer,ScoutKeepAlive,ScoutBoard,ScoutBoardDBLayer,TFTP,'MSSQL$SQLEXPRESS',W3SVC | ft Name,Status
Get-NetTCPConnection -State Listen | ? LocalPort -in 80,1433,22123,22124,22125,22160 | ft LocalPort,OwningProcess
Get-Content C:\Users\Public\Documents\Unicon\Scout\Server\eluxd.log -Tail 20
```

### DocumentaÃ§Ã£o oficial
- InstalaÃ§Ã£o silenciosa: https://docs.citrix.com/en-us/unicon-elux-scout/2605/short_guides/installation/install_scout_suite/install_scout_unattended
- InstalaÃ§Ã£o assistida: https://docs.citrix.com/en-us/unicon-elux-scout/short_guides/installation/install_scout_suite/install_scout_attended
