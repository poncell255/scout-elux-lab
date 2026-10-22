# Scout Enterprise + eLux — Documento Global da Implantação

> Documento vivo. Atualizado a cada etapa executada nesta máquina.
> Última atualização: 2026-10-20

---

## 1. Servidor

| Item | Valor |
|---|---|
| Hostname | SCOUTBOARD (antes WIN-8TMD3MHIPVG) |
| SO | Windows Server 2025 Datacenter Evaluation (10.0.26100) |
| Domínio | populos.local (DC POPAD01, 10.20.0.10) — desde 2026-10-20 |
| IP | 192.168.15.25/24 (Wi-Fi, perfil de rede **Public**) |
| RAM / CPU | 8 GB / 12 núcleos lógicos |
| Disco C: livre | ~475 GB |
| Usuário admin | Administrator (local) |

> **Recomendação:** fixe o IP 192.168.15.25 (estático ou reserva DHCP no roteador). Os eLux vão apontar para esse IP.

---

## 2. Status atual

| Componente | Status | Detalhe |
|---|---|---|
| SQL Server 2025 Express | OK | Instância `SQLEXPRESS`, TCP 1433 fixa, autenticação mista |
| ODBC Driver 18 | OK | 18.7.1.1 |
| Scout Server | Rodando | **Sem licença**: portas de dispositivo 22123/22125 só abrem depois da licença |
| Scout Console | Instalada | Menu Iniciar > Scout Enterprise Management Suite |
| ELIAS (designer de imagens) | Instalado | |
| Scout Report / Recovery | Instalados | |
| Scout Board (web) | Rodando, **Entra ID configurado** (seção 7.6) | Acessar **neste servidor** em https://localhost:22160 (a URL de retorno registrada é localhost). Login com conta POPULOS (Entra ID) |
| Scout Board DB Layer | Rodando | 22150/22151 (somente local) |
| Scout Keep Alive | Rodando | 22124 (corrigido: ver seção 6) |
| Scout TFTP | Rodando | UDP 69 (Recovery/PXE) |
| IIS (container eLux) | OK | http://192.168.15.25/eluxng/UC_RPM/ |
| Firewall | OK | Grupo de regras "Scout eLux" |
| **Licença Scout** | **PENDENTE** | Ação sua: seção 7 |

---

## 3. Mídias (C:\Users\Administrator\Downloads)

| Arquivo | O que é | Status |
|---|---|---|
| Scout-15.2609-3\ScoutInstaller.exe | Scout Enterprise Management Suite 15.2609 (v26.9.0), WiX Burn, assinado (Citrix) | Instalado |
| Scout-15.2609-3.zip / (1).zip | Cópias do mesmo instalador | Duplicadas, pode apagar uma |
| msodbcsql.msi | ODBC Driver 18 for SQL Server 18.7.1.1 | Instalado |
| eLux-certs-2025.0.zip | Certificados de assinatura de pacotes eLux 2025 | Extraído e publicado no container |
| Unconfirmed 97787.crdownload | ZIP **incompleto** (1,2 GB) do **container de pacotes eLux 7 (2603)** (`*.UC_ELUX7-1.0.fpm/.epm` + `.sig`) | Baixar de novo e extrair em `C:\eLuxContainer\eluxng\UC_RPM` |

Pasta de trabalho: `C:\ScoutSetup` (logs, mídia do SQL, certificados extraídos, credenciais).

---

## 4. Arquitetura

```
 Clientes eLux ──TCP/UDP 22123, TCP 22125──► Scout Server ──► SQL Express (ScoutEnterprise)
       │                                          ▲
       ├──HTTP 80──► IIS /eluxng/UC_RPM           │ Scout Console / ELIAS (local)
       ├──TCP 22124──► Scout Keep Alive           │
       └──UDP 69──► Scout TFTP (Recovery/PXE)     Scout Board (web, 22160) ─► DB Layer (22150/22151)
```

### Caminhos importantes

| O quê | Caminho |
|---|---|
| Binários Scout | `C:\Program Files\Unicon\Scout` |
| Config/logs Scout Server | `C:\Users\Public\Documents\Unicon\Scout\Server` (`eluxd.ini`, `eluxd.log`) |
| Pasta de licença on-prem | `C:\Users\Public\Documents\Unicon\Scout\Server\config\` (`scout-license.jwt`) |
| Config/log Keep Alive | `C:\Users\Public\Documents\Unicon\Scout\ScoutKeepAlive` |
| ELIAS (certificados) | `C:\Users\Public\Documents\Unicon\Elias\Security` |
| Container eLux (físico) | `C:\eLuxContainer\eluxng\UC_RPM` |
| Certificados para os dispositivos | `C:\eLuxContainer\certs` → http://192.168.15.25/certs/ |
| Credenciais | `C:\ScoutSetup\credenciais.txt` (acesso restrito a Administradores) |

### Banco de dados

| Item | Valor |
|---|---|
| Servidor | `localhost\SQLEXPRESS` / `WIN-8TMD3MHIPVG,1433` |
| Banco | `ScoutEnterprise` (119 tabelas, versão 26.09.0) — usado pelo Scout Server **e** pelo Keep Alive |
| Login do Scout | `scoutdb` (SQL auth), atualmente **sysadmin** |
| Admin SQL | `sa` + grupo local `BUILTIN\Administrators` |
| Usuário inicial do Scout | `WIN-8TMD3MHIPVG\Administrator` |

> Senhas no arquivo `C:\ScoutSetup\credenciais.txt`, nunca neste MD.

### Portas (firewall de entrada, grupo "Scout eLux")

| Porta | Uso |
|---|---|
| TCP+UDP 22123 | Scout Server ↔ dispositivos eLux |
| TCP 22125 | Scout Server, canal seguro |
| TCP 22124 | Scout Keep Alive |
| TCP 22160 | Scout Board (HTTPS) |
| UDP 69 | TFTP (Recovery/PXE) |
| TCP 80 | Container eLux (IIS) |
| TCP 1433 / UDP 1434 | SQL Server / SQL Browser |
| ICMP Echo | Ping |

---

## 5. Log de execução

| Data | Etapa | Resultado |
|---|---|---|
| 2026-10-15 | Levantamento do servidor e das mídias | OK |
| 2026-10-15 | Análise do instalador (Burn v3.14; pacotes VC++ 2017, ReportViewer, Scout, ScoutBoard, KeepAlive; .NET 4.8 presente). Só suporta MS SQL | OK |
| 2026-10-15 | ODBC Driver 18 instalado (`msiexec /qn`) | OK |
| 2026-10-15 | SQL Server Express instalado via SSEI (o link 2022 entregou a **2025 Express 17.0.1000.7**), TCP 1433 fixa, firewall 1433/1434 | OK |
| 2026-10-15 | Login `scoutdb` criado | OK |
| 2026-10-15 | Scout instalado em modo silencioso (comando na seção 8), exit 0x0 | OK |
| 2026-10-15 | Keep Alive parou: banco `ScoutKeepAlive` não existia. Corrigido apontando para `ScoutEnterprise` | OK |
| 2026-10-15 | Scout Server: "Scout Enterprise server started", modo on-prem, **sem licença** | Pendente licença |
| 2026-10-15 | IIS + container `/eluxng` e `/certs` (listagem de diretório, MIME `application/octet-stream` para tudo, double-escaping liberado para nomes com `+`) | OK, testado HTTP 200 |
| 2026-10-15 | Firewall: regras "Scout eLux". Grupo "File and Printer Sharing" foi habilitado por engano e depois reduzido: só Echo (ping) e SMB-In ficaram ativos na entrada | OK |
| 2026-10-15 | Scout Board responde em https://…:22160 (HTTP 308 → login) | OK |

---

## 6. Problemas encontrados e correções

1. **Layout do Burn trava** — `ScoutInstaller.exe -layout` fica preso no BA customizado. Use só `/s` para instalação silenciosa.
2. **Keep Alive "Cannot open database ScoutKeepAlive"** — o parâmetro `UCPROP_SCOUTKEEPALIVE_DBNAME` deve ser o **mesmo banco do Scout**, porque o Keep Alive usa a tabela `Entity`. Correção: `scoutkeepalive.ini` → `[Database] Name=ScoutEnterprise` (backup em `scoutkeepalive.ini.bak`).
3. **Fuso horário padrão dos dispositivos** ficou `US/Eastern` (o BA ignorou `UCPROP_TIMEZONE`). Ajustar na Console (seção 7).
4. **Scout Board: "A system error has occurred" no login** (2026-10-15)
   - Causa 1: o DB Layer perdeu a conexão com o Scout Server depois que o ScoutServer foi reiniciado. Correção: reiniciar na ordem `ScoutServer` → `ScoutBoardDBLayer` → `ScoutBoard`.
   - Causa 2 (definitiva): a autenticação padrão do Scout Board é **AD via LDAPS (porta 636)**. Sem domínio, a API responde `AD authentication failed / LDAPS_UNREACHABLE`. Contas locais não funcionam.
   - Testei `DOMAINS=["WIN-8TMD3MHIPVG"]` no `.env` e não resolve. Revertido ao original (backup em `C:\ScoutSetup\scoutboard.env.bak`).
   - Opções: (a) usar só a Scout Console (recomendado agora); (b) configurar Entra ID ou Okta (OIDC/SAML) reinstalando com `UCPROP_SCOUTBOARD_AUTH_TYPE=ENTRAID_OIDC` + issuer/client id/secret/initial user; (c) ter um AD com LDAPS.
   - Aviso também no log: `ELIAS_TARGET` não definido, então a seção Software do Scout Board não aparece. Só importa se o Scout Board for usado.

---

## 7. Próximos passos (ações suas)

### 7.1 Licença do Scout (bloqueante)
Contexto (2026-10-15): o licenciamento por arquivo (perpétuo/Enterprise Subscription) chegou ao **fim de vida em 15/04/2026**. Desde então o Scout (15 2508 LTSR ou mais novo) só licencia via **Citrix License Server ativado pelo LAS** (License Activation Service, na Citrix Cloud). O Scout Board mostra "Legacy licenses expired" e redireciona para `/licenseSwitch`.

Decisão: **License Server local nesta máquina** (o servidor estava fora da rede da empresa).
- [x] Wagner baixou `Citrix_Licensing_11.17.2.0_BUILD_56200.zip` (assinatura Citrix válida, extraído em `C:\ScoutSetup\licensing`).
- [x] License Server instalado (`CitrixLicensing.exe /quiet`, exit 0). **Funciona no Windows Server 2025.** Serviços: Citrix Licensing, Citrix Web Services for Licensing, Citrix Licensing Support Service. Portas: 27000 (lmgrd), 7279 (vendor daemon CITRIX), 8083 (Licensing Manager, HTTPS).
- [x] Firewall: regras criadas pelo instalador (Citrix Licensing, Vendor Daemon, Web Services). Como o Scout é local, dá para restringir depois.
- [ ] Registrar na Citrix Cloud: https://localhost:8083 > Settings > Citrix Cloud > Register > código em citrix.cloud.com (Wagner).
- [ ] Scout Board > tela de licença: modo Citrix License Server, servidor `localhost` (Wagner).
- Ferramenta de ativação offline disponível, se um dia o servidor ficar sem internet: `C:\Program Files (x86)\Citrix\Licensing\LS\ctxLasOfflineActivationTool.exe`.
- [ ] `Restart-Service ScoutServer` e confirmar 22123/22125: `Get-NetTCPConnection -State Listen -LocalPort 22123,22125`
- [ ] Conferir na Citrix Cloud: Licensing > Licensed deployments > License Servers > Citrix Unicon.

### 7.2 Scout Console (primeiro acesso)
- [ ] Abrir **Scout Console** (Menu Iniciar), logado como `Administrator`.
- [ ] **Configuração base** (Base configuration): fuso `America/Sao_Paulo`, teclado/idioma `pt_BR`.
- [ ] Criar a estrutura de OUs (ex.: `Matriz/Lab`).
- [ ] **Firmware** da OU: servidor `192.168.15.25`, protocolo **HTTP**, container `eluxng/UC_RPM`.
- [ ] Senha de dispositivo: já definida no instalador (`credenciais.txt`).

### 7.3 Imagem eLux
- [ ] Baixar de novo a imagem/pacotes eLux (o `.crdownload` está incompleto).
- [ ] Extrair o conteúdo do container em `C:\eLuxContainer\eluxng\UC_RPM`.
- [ ] No **ELIAS**: Certificate Library > Import dos 3 certificados (`C:\ScoutSetup\elux-certs\eLux-certificates-2025\…`: Root, Intermediate, Issuer).
- [ ] No ELIAS: criar o IDF (definição de imagem) com os pacotes necessários (Citrix Workspace, RDP, browser, etc.).
- [ ] Atribuir o IDF à OU na Console.
- [ ] Para atualizar firmware com validação de assinatura: transferir os certificados para os eLux em `/setup/cacerts` (estão em http://192.168.15.25/certs/).

### 7.3.1 Estado do ELIAS (verificado em 2026-10-15)
- ELIAS desktop 26.09.0.718 instalado (`C:\Program Files\Unicon\Scout\elias.exe`), com Recovery eLux 7 / eLux RP6 em `C:\Users\Public\Documents\Unicon\Elias`.
- `elias.ini` → `ContainerPath=C:\eLuxContainer\eluxng\UC_RPM\` (antes: pasta padrão; backup `C:\ScoutSetup\elias.ini.bak`).
- Certificados eLux 2025 **não estavam** no repositório (`Elias\Security`). Importar pelo ELIAS: Security > Manage certificates (Root → Trusted Root CA, Intermediate → Intermediate CA, Issuer → Trusted Issuer). O Issuer `Citrix Systems` venceu em 2026-07-01; importar mesmo assim (a Citrix recomenda manter os vencidos para validar pacotes antigos).
- **ELIAS 18 (web)** não instalado: é um download separado. Sem ele, o Scout Board não mostra a seção Software (`ELIAS_TARGET` vazio no `.env`).

### 7.3.2 ELIAS 18 (web) — instalado em 2026-10-15
- Mídia: `ELIAS_18.26032_RC6.zip` → `EliasInstaller.exe` 26.3.2.1136 (assinado Citrix). Extraído em `C:\ScoutSetup\elias18`.
- Instalação silenciosa (formato `/v"CHAVE=valor"`, igual ao Scout): `/s /v"INSTALLMONGODB=1" /v"ELIASDATABASE=ELIAS" /v"IISCONFIG=1" /v"IISROOT=Default Web Site" /v"ELIASPATH=ELIAS" /v"ELIASPORT=22130" /v"HASAD=0" /v"HASKEYCLOAK=0" /v"ADMINPASSWORD=..."`. Log: `C:\ScoutSetup\elias18-install.log`.
- Componentes: MongoDB 7.0.28 (serviço `MongoDB`, só em 127.0.0.1:27017), serviço `ELIAS` (API em 22130), IIS com URL Rewrite + ARR, aplicação `/ELIAS` no Default Web Site (proxy reverso para 127.0.0.1:22130).
- Login: `admin` + senha em `credenciais.txt` (sem AD e sem Keycloak).
- **Bug do instalador silencioso:** `server.json` ficou com `"server": "Empty"` (erro `getaddrinfo ENOTFOUND empty`). Corrigido para `localhost:27017` (backup `C:\ScoutSetup\elias-server.json.bak`).
- Logs do serviço: `C:\Windows\System32\config\systemprofile\AppData\Roaming\ELIAS\` (`elias.log`, `error.log`). O aviso "keycloak.json does not exist" é inofensivo.
- Acesso local: http://localhost/ELIAS/
- **Acesso externo (decisão do Wagner, 2026-10-15): publicado com Cloudflare Access + Entra ID.**
  - Túnel: regra de bloqueio `^/ELIAS` (403) removida; `elux.populosplataform.com.br` → IIS 80 inteiro.
  - Cloudflare Access (IdP já existente "Azure AD", tenant POPULOS, id `624aa2c3-ce69-4f8a-af7c-39bbeee925d7`):
    - App **"ELIAS 18 - interface"** (`elux.populosplataform.com.br/ELIAS`, id `08685fe8-5a4d-4d57-9009-af04f1ffdfb5`): só `<email-admin>`, sessão 8h.
    - App **"ELIAS 18 - API admin"** (`elux.populosplataform.com.br/ELIAS/api/*/v1.0`, id `5db99273-7f8c-4881-bb82-126c7246b4dd`): idem.
    - App **"ELIAS 18 - downloads eLux (bypass)"** (`elux.populosplataform.com.br/ELIAS/api/*`, política "eLux sem login" Bypass/Everyone, id `6502497a-27d3-4019-83d8-479458eba41f`): criado pelo Wagner no painel (o Claude Code bloqueou a criação via API).
    - Teste de 2026-10-15: `/ELIAS/` e `/ELIAS/api/*/v1.0/*` → login Entra; `/ELIAS/api/<container>/<arquivo>.idf|.epm|.fpm.sig` → passa direto para o ELIAS (404 em arquivo inexistente). **Validar com um eLux real** se ele usa só esses caminhos.
  - `config.json`: o ELIAS migra a config para o MongoDB na instalação (original em `config.json.migrated`). Um reinício posterior falhou ("Config service initialization failed… Unexpected end of JSON input") e o serviço caiu em defaults errados (api `localhost:22130`, AD ligado). Recriado a partir do `.migrated` com `api=elux.populosplataform.com.br`, `protocol=https`, `port=443`, `allowedOrigins` = público + WIN-8TMD3MHIPVG + localhost + 192.168.15.25. Backup do original: `C:\ScoutSetup\elias-config.json.bak`.
  - Senha do `admin`: Wagner escolheu `<SENHA>` (fraca e exposta no chat). Trocar pela interface do ELIAS (Profile); o Claude Code bloqueou a alteração pelo arquivo.
  - Log 2026-10-15 21:26–21:29: 5 logins `admin` com senha inválida vindos de 127.0.0.1 (provavelmente teste local).

### 7.3.3 Imagem `populos-elux7` (ELIAS 18, 2026-10-16)
- Container ELIAS: **`UC_RP6_X64`** (versão `UC_ELUX7-1.0-1`), 76 EPMs / 403 FPMs importados pelo Wagner (`eLux-7.2609.0_AllPackages-1.zip`).
- Imagem criada pela API do ELIAS (`POST /ELIAS/api/UC_RP6_X64/v1.0/idfs`, corpo `{idf:{…, id:"populos-elux7.idf"}}`), a partir da imagem oficial Unicon **`migration-system-7.2609.0-5`** (17 EPMs) + `ica`, `citrix_extensions`, `citrix_hdxrtme`, `vmwareviewclient`, `firefox` + FPM `mirror_server` (no EPM `xorg`). Dependências resolvidas pelo script `C:\ScoutSetup\scripts\montar-idf.ps1` (acrescentou eluxrdp, baseprinter, audiolibs, videolibs, gtk2, libnss, libffmpeg etc.). Resultado: **26 EPMs, 118 FPMs, ~2,2 GB, conflicted=false, hasMissing=false**. Não assinada (`isVerified:false`).
- Flags dos FPMs no `rpmDescription` (`$FPMn=idx,arquivo,KB,FLAGS,n$`): bit 2 = obrigatório, bit 1 = pré-selecionado, 0 = opcional.
- API de login: `POST /ELIAS/api/<container>/v1.0/authenticate/` `{user,domain,password}` (cookie). A senha do `admin` ainda é a do `credenciais.txt`: `<SENHA>` não foi aplicada.
- **URL de download dos eLux:** `/ELIAS/UC_RP6_X64/<arquivo>` (ex.: `/ELIAS/UC_RP6_X64/populos-elux7.idf`, `.epm`, `.fpm`). A API (`/ELIAS/api/…/v1.0/…`) só devolve metadados.
- **Pendência Cloudflare:** a regra de bypass cobre só `/ELIAS/api/*`; `/ELIAS/UC_RP6_X64/*` cai na regra "ELIAS 18 - interface" (login Entra) → eLux de fora seriam barrados. Adicionar o destino `elux.populosplataform.com.br/ELIAS/UC_RP6_X64/*` à aplicação "ELIAS 18 - downloads eLux (bypass)".
- **Pendência Scout:** firmware da OU Enterprise pelo Scout Board (configuração direta no banco não chega ao eLux).

### 7.4 Registrar os dispositivos eLux no Scout
Sem domínio nem DNS próprio, existem três opções:
1. **Manual** no assistente do eLux (primeiro boot / Setup > Scout): servidor `192.168.15.25`.
2. **DHCP** (se o roteador permitir opções customizadas): opção **222** = `192.168.15.25` (Scout server), opção **223** = ID da OU.
3. **DNS**: criar o alias `ScoutSrv` → 192.168.15.25 no DNS da rede; o eLux procura esse nome automaticamente.

### 7.6 Scout Board com Entra ID (configurado em 2026-10-15)

| Item | Valor |
|---|---|
| Tenant | POPULOS (`<TENANT_ID>`) |
| App registration | `Scout Board - WIN-8TMD3MHIPVG`, appId `<APP_ID>`, single-tenant |
| Redirect URI | `https://localhost:22160/api/v1/auth/callback` |
| Permissões delegadas (Graph) | openid, profile, email, offline_access, User.Read, GroupMember.Read.All, Directory.Read.All |
| Segredo | Em `credenciais.txt`, **expira em 2027-10-15** (renovar e atualizar `OIDC_CLIENT_SECRET`) |
| Config Scout Board | `.env`: `AUTH_TYPE=ENTRAID_OIDC`, `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` (ACL só Administradores/SYSTEM). Backups: `C:\ScoutSetup\scoutboard.env.bak` (original), `scoutboard.env.pre-entra.bak` |
| Autorização | O Scout Board compara o e-mail/UPN do token com `Administrator.Name` no banco (ou com nomes de grupos) |

- [x] Consentimento de administrador para POPULOS (feito pelo Wagner, verificado: `AllPrincipals`).
- [x] `<email-admin>` cadastrado como administrador do Scout (tabela `Administrator`, AdministratorID 2, mesmos direitos do AdministratorID 1).
- [x] Enterprise application com **Assignment required = Yes**; único usuário atribuído: Wagner Poncell.
- Para dar acesso a outra pessoa: atribuí-la ao app no Entra ID **e** cadastrá-la como administrador do Scout com o e-mail dela.
- **2026-10-16:** liberados **Thiago Alves** (`<email-usuario>`, id `c29b2d46-…`) e **Arthur Sabino** (`<email-usuario>`, id `8f647f8f-…`): atribuídos ao app no Entra ID e cadastrados em `Administrator` (IDs 3 e 4) com os mesmos direitos do Wagner. Acesso: https://scoutboard.populosplataform.com.br. Eles **não** têm acesso ao ELIAS 18 (a política do Cloudflare Access libera só o Wagner).
- [ ] Para acessar por outros computadores: adicionar a redirect URI `https://WIN-8TMD3MHIPVG:22160/api/v1/auth/callback` (ou um FQDN) e mudar `HOST_NAME` no `.env`.

Azure CLI instalado em `C:\Program Files\Microsoft SDKs\Azure\CLI2` (deslogado após a configuração; para mexer de novo: `az login --use-device-code --allow-no-subscriptions`).

### 7.7 Acesso externo (internet) — 2026-10-15

Objetivo: registrar/gerenciar eLux fora da rede, só com internet.

**Por que não é "tudo pelo Cloudflare":** o eLux fala com o Scout por **TCP puro (22125, TLS Unicon)**. O Cloudflare no plano Free só proxia HTTP/HTTPS; TCP arbitrário exige Spectrum (Enterprise) ou cloudflared no cliente (impossível no eLux). Então:

| Nome público | Tipo | Destino | Uso |
|---|---|---|---|
| `scout.populosplataform.com.br` | A, **DNS only**, TTL 60, DDNS | IP público → roteador → 192.168.15.25:**22125** | eLux ↔ Scout Server |
| `scoutboard.populosplataform.com.br` | CNAME proxied → Tunnel | https://localhost:443 (noTLSVerify) | Scout Board (login Entra ID) |
| `elux.populosplataform.com.br` | CNAME proxied → Tunnel | http://localhost:80 (IIS) | Container de imagens/firmware e `/certs` |

Componentes:
- Zona Cloudflare: `populosplataform.com.br` (zoneId `<CF_ZONE_ID>`, conta `<CF_ACCOUNT_ID>`, plano Free). Registros preexistentes (`uberagent`, `loja`) não foram tocados.
- Token Cloudflare (Tunnel:Edit, DNS:Edit, Zone:Read): `C:\ScoutSetup\cf-token.txt` (ACL Administradores/SYSTEM). **Foi exposto no chat: gerar outro e substituir o arquivo.**
- DDNS: `C:\ScoutSetup\ddns\update-cf-dns.ps1`, tarefa agendada **"Scout - DDNS Cloudflare"** (SYSTEM, a cada 5 min + no boot), log `C:\ScoutSetup\ddns\ddns.log`.
- Tunnel: `scout-WIN-8TMD3MHIPVG` (id `fc691a00-f0ed-42f6-8136-4394551cb522`, configurado remotamente no painel), serviço Windows **cloudflared** 2026.10.1.
- Scout Board: `.env` → `PORT=443`, `HOST_NAME=scoutboard.populosplataform.com.br` (backup `C:\ScoutSetup\scoutboard.env.pre-tunnel.bak`). Firewall 443 só LocalSubnet. **Uma atualização do Scout pode sobrescrever o `.env`: reaplicar.**
- Entra ID: redirect URI `https://scoutboard.populosplataform.com.br/api/v1/auth/callback` adicionada ao app (confirmado). A antiga `https://localhost:22160/...` ficou registrada mas não é mais usada (o Scout Board saiu da 22160); pode ser removida.

Pendências (Wagner):
- [x] Roteador Vivo (192.168.15.1, firmware Broadcom): WAN Internet `ppp0.1` PPPoE = **186.215.14.23** → **sem CGNAT** (verificado só lendo `wancfg.cmd`). Interfaces `veip0.2` (VoIP, 10.254.34.251) e `veip0.3` (Mediaroom/TV) não são usadas.
- [ ] Roteador: Configurações > Jogos & Aplicativos (NAT – Virtual Servers): **TCP 22125 → 192.168.15.25:22125, WAN ppp0.1** (Wagner cria; em 2026-10-15 a lista estava vazia).
- [ ] Roteador: reservar o IP 192.168.15.25 para o WIN-8TMD3MHIPVG no DHCP.
- [ ] Teste de fora (4G): `Test-NetConnection scout.populosplataform.com.br -Port 22125`.
- [ ] Scout Console: política para novos dispositivos irem para uma OU de quarentena.
- [ ] Firmware dos eLux externos: servidor `elux.populosplataform.com.br`, protocolo **HTTPS**, caminho `ELIAS/api/<container>` (ELIAS 18) ou `eluxng/UC_RPM` (container estático).
- [ ] Rotacionar o token Cloudflare e as chaves R2 expostas no chat.

Limitações conhecidas:
- O container `elux.` é público (o eLux não consegue mandar o cabeçalho do Cloudflare Access).
- Ações do Scout que dependem de o **servidor abrir conexão até o dispositivo** podem falhar para eLux atrás de NAT. Para isso a Unicon tem o **Scout Cloud Gateway** (portas 22125/22129), avaliar depois.

### 7.8 Primeiro eLux e tema POPULOS (2026-10-15)
- Roteador: regra NAT Virtual Server `Scout eLux` TCP 22125 → 192.168.15.25 (refeita na interface correta, **ppp0.1**; a primeira tentativa ficou em veip0.2/VoIP). O reinício do roteador trocou o IP público para **177.215.113.251** e o DDNS atualizou (a execução durante a queda falhou e se recuperou sozinha).
- **Primeiro eLux registrado:** `Portable`, eLux 7.2609.0-12, OU **Enterprise** (GroupID 2), IP local 192.168.15.11, conectando via `scout.populosplataform.com.br` (Scout vê a origem 177.215.113.251 → NAT loopback do roteador Vivo funciona).
- OUs existentes: Lost & Found, Enterprise, FollowMeDesktop.
- Mídia nova: `eLux-7.2609.0_AllPackages-1.zip` (3,7 GB) em Downloads, a importar no ELIAS.
- **Tema `populos-theme`** (guia Citrix "Theming guide", eLux 7): arquivos em `C:\eLuxContainer\theme\populos-theme\`:
  - `desktopBackgroundImage.jpg` ← "Astronauta no Lobby Workspace Moderno.png" (1536x1024)
  - `welcomeBackgroundImage.png` ← "Futuristic Citrix Astronaut Brand Poster.png" (1122x1402), layout `leftImage`
  - `productImage.png` ← recorte só do astronauta (400x600), no lugar do logo eLux
  - `brandImage.png` ← logo POPULOS recortado do rodapé do pôster (404x91). **Obrigatório** pelo guia (junto com config.json, desktopBackgroundImage.jpg e productImage.png); o `welcomeBackgroundImage` é opcional.
  - `config.json` → `accentColor #6B2FBF`, com as 4 imagens declaradas e `welcomeBackgroundLayout: leftImage`
  - Destino no eLux: `/setup/elux/themes/populos-theme/`; ativação: `/setup/terminal.ini` [Layout] `CurrentTheme=populos-theme`; reiniciar 2x.
  - Limitação: o guia **não** cobre a animação de boot (antes do sistema carregar), só as telas de boas-vindas/login/bloqueio e o desktop.
  - **Aplicado na OU Enterprise direto no banco** (autorizado pelo Wagner), em 2026-10-15, numa transação única:
    - Backup antes: `C:\ScoutSetup\backup\ScoutEnterprise-pre-tema.bak`.
    - `UCFT` IDs 10–14 (conteúdo dos 5 arquivos, MemberType 1 / MemberID 2, FileType 0) + `FileEntry` (destino `/setup/elux/themes/populos-theme/<arquivo>`, Description "Tema POPULOS") + `IniEntry` (`/setup/terminal.ini` [Layout] `CurrentTheme=populos-theme`).
    - Códigos usados: MemberType **1 = OU** (inferido: o Scout Board usa ContextType 1 = OU e 4 = dispositivo; `MouseKB` do eLux Portable = 4/1). O Scout Server entrega `FileEntry` + `UCFT` pelo `UCFTID`, sem filtrar `FileType`.
    - Desfazer: `C:\ScoutSetup\desfazer-tema-populos.sql`, ou restaurar o backup.
    - **Validado em 2026-10-15:** após reinício manual, o eLux "Portable" aplicou o papel de parede e o astronauta no lugar do logo da tela inicial → MemberType 1 = OU está correto.
    - Correção: `TimeModified` tinha sido gravado 3h adiantado (o `Get-Date -UFormat %s` do PowerShell 5.1 usa o horário local); corrigido para UTC às 23:26:56.
    - `brandImage.png` trocado pelo astronauta (pedido do Wagner: ele aparece na tela de boot). Logo POPULOS guardado em `brandImage-populos-logo.png.bak`. A validar no próximo reinício.
    - **Fuso horário dos eLux corrigido (2026-10-15):** `Setup` 0 (base, herdado pela OU Enterprise) e 1 (FollowMeDesktop) estavam em US/Eastern (TimeZoneID 267), o padrão do instalador; alterados para **America/Sao_Paulo (195)**. Valor anterior em `C:\ScoutSetup\backup\timezone-antes.txt`. Vale a partir do próximo reinício.
    - **Reinício pelo Scout não chegava ao eLux: causa confirmada (23:33:26).** O Scout envia comandos conectando ao eLux na porta 22125, usando o IP de origem registrado (`PeerIPAddress` = 177.215.113.251, o IP público, porque o eLux da LAN conecta pelo nome público via NAT loopback). O roteador devolve essa conexão ao próprio Scout (regra 22125) → o Scout conversa consigo mesmo → `SSL_Accept failed`. Capturado: `192.168.15.25:59868 → 177.215.113.251:22125` e `192.168.15.25:22125 ← 177.215.113.251:59868`, mesmo processo.
    - Correção aplicada só no "Portable" (eLux da LAN): `Device.UsePeerIP` NULL → **0**, para o Scout usar o IP informado pelo eLux (192.168.15.11). Desfazer: `UPDATE Device SET UsePeerIP=NULL WHERE DeviceID=1`. A validar com um novo reinício pelo Scout.
    - **Limitação para eLux fora da rede:** comandos iniciados pelo Scout (reiniciar, espelhar, etc.) precisam abrir conexão até o eLux, e isso não atravessa o roteador do outro local. Registro, configuração, tema e atualização funcionam porque partem do eLux. Para comandos remotos fora da rede, a solução da Citrix é o **Scout Cloud Gateway (SCG)**.
    - `UsePeerIP=0` **não resolveu**, nem com reinício do Scout Server (`SSL_Accept failed` de novo às 23:45:53). Fica gravado, mas não é a solução.
    - **Scout Cloud Gateway avaliado e descartado nesta máquina:** só Linux (.deb Ubuntu 24.04 ou .ova), 4 CPU / 8 GB RAM / 24 GB, login via AD ou Keycloak; o host tem 7,7 GB no total e ~0,8 GB livres.
    - **Solução escolhida (Wagner): DNS local (split DNS).** Função DNS Server instalada neste servidor; encaminhadores 1.1.1.1 e 8.8.8.8; zona primária `scout.populosplataform.com.br` com `@ A 192.168.15.25` (TTL 1 min). Só esse nome é sobrescrito: o resto (`elux.`, `scoutboard.`, internet) resolve normalmente. Firewall: entrada do DNS só `LocalSubnet`. Testado: scout → 192.168.15.25; google.com e login.microsoftonline.com OK.
    - **DNS do roteador alterado (Wagner):** Rede Local > DHCP > Servidor DNS Específico = 192.168.15.25. Confirmado às 23:58:33: o eLux passou a conectar com origem **192.168.15.11** (IP local), não mais o público.
    - **Tema republicado como `populos-theme-v2` (2026-10-16 00:0x):** mesmo depois de trocar o conteúdo de `productImage`/`brandImage` na UCFT, o eLux continuava com o astronauta com fundo (cache: as entradas de transferência não mudaram, então ele não baixou de novo). Mudados os 5 destinos para `/setup/elux/themes/populos-theme-v2/`, `config.json` com `name: populos-theme-v2` e `CurrentTheme=populos-theme-v2`. Para publicar novas mudanças de imagem no futuro, repetir esse padrão (v3, v4…).
    - Pendente (Wagner): no roteador, reservar o IP 192.168.15.25 para o WIN-8TMD3MHIPVG.
    - **Reinício pelo Scout validado (Wagner, 2026-10-16)** depois do DNS local.
    - **Qual imagem aparece onde** (descoberto extraindo os pacotes `elux_theme` e `splashscreen` do `eLux-7.2609.0_AllPackages-1.zip`; o formato `.fpm` é cabeçalho "Lexu" + gzip + cpio newc; script `C:\ScoutSetup\scripts\extrair-fpm.ps1`):
      - **Tela de boot** (`ucsplash`, pré-carregamento): `/setup/elux/theme_active/productImage.png`, num quadro de 304x304, `contain`. O `theme_active` é atualizado quando o tema é ativado, então a mudança aparece **no boot seguinte**.
      - **Botão Iniciar / logotipo nas telas de entrada:** `brandImage` (o original é o logotipo "unicon").
      - **Tela de entrada:** `welcomeBackgroundImage`, conforme `welcomeBackgroundLayout`.
      - Tema original da Unicon extraído em `C:\ScoutSetup\elux-pkgs\elux_theme\usr\share\elux\themes\unicon_default\` (`accentColor #154EC7`).
    - **Tema `populos-theme-v3`:** `brandImage` = logotipo **unicon original** (pedido do Wagner); `productImage` = astronauta sem fundo (tela de boot); `desktopBackgroundImage` = recepção POPULOS; `welcomeBackgroundImage` = pôster. Backup do brand anterior: `brandImage-astronauta.png.bak`. Risco aceito: se este servidor desligar, a rede de casa fica sem DNS (voltar o DNS do roteador para automático resolve).
    - `brandImage.png` final: astronauta com **fundo transparente** (recorte por cor + maior componente conectado), `C:\ScoutSetup\astronauta-transparente.png`, gravado na UCFTID 13. Depois substituído pela versão do Wagner sem fundo (`311d31a7-…-removebg-preview.png`, cortada para 175x417) em **brandImage (UCFTID 13) e productImage (UCFTID 12)**. O astronauta com fundo que continuava aparecendo era o `productImage` (backup em `productImage-com-fundo.png.bak`).
    - Animação de boot do firmware (antes do eLux carregar): não é coberta pelo tema; só via branding OEM da Citrix/Unicon. O `grub/splash.png` do Scout é só do Recovery (PXE).

### 7.9 VPN OpenVPN para comandos do Scout em eLux remotos (2026-10-16)

**Problema:** com o eLux no 4G (IP 10.63.152.216 da operadora, saindo como 189.40.74.252), registro, configuração e tema funcionam, mas o reinício pelo Scout não chega: o Scout precisa abrir conexão até o eLux (porta 22125), e o CGNAT da operadora bloqueia. Só funciona quando o eLux está na mesma rede.

**Solução escolhida (Wagner): OpenVPN neste servidor** (o eLux 7 já traz o OpenVPN 2.5; o Scout Cloud Gateway não cabe aqui).

| Item | Valor |
|---|---|
| Servidor | OpenVPN 2.7.8 (MSI oficial, assinado OpenVPN Inc.), componentes OpenVPN + Service + TAP-Windows6 + OpenSSL |
| Config | `C:\Program Files\OpenVPN\config-auto\scout-vpn-server.ovpn` (chaves embutidas; ACL Admins/SYSTEM/`NT SERVICE\OpenVPNService`) |
| Serviço | `OpenVPNService` (conta `NT SERVICE\OpenVPNService`), log `C:\ProgramData\OpenVPN\Log\scout-vpn-server.log` |
| Rede | UDP 1194, `tun`, `topology subnet`, **10.8.0.0/24**, servidor **10.8.0.1** (adaptador "OpenVPN TAP-Windows6"), `duplicate-cn` (um certificado para todos os eLux), sem rota padrão |
| PKI | `C:\ScoutSetup\openvpn-pki\` (CA RSA 3072 "POPULOS Scout VPN CA" até 2036; servidor e cliente `elux-enterprise` RSA 2048 até 2031; `tc.key` tls-crypt). **A `ca.key` fica aqui: proteger/backup.** |
| DNS | Push `dhcp-option DNS 10.8.0.1`; política no DNS do Windows: sub-rede cliente `RedeVPN` 10.8.0.0/24 → escopo `EscopoVPN` → `scout.populosplataform.com.br = 10.8.0.1`. Rede local continua recebendo 192.168.15.25. |
| Perfil eLux | `C:\ScoutSetup\openvpn-pki\populos.ovpn` (remote `scout.populosplataform.com.br 1194`), distribuído na OU Enterprise → `/setup/openvpn/populos.ovpn` (UCFTID 17, FileEntry "VPN POPULOS") |
| Firewall | Regra "OpenVPN eLux (UDP 1194)" |

Lições: o serviço roda como `NT SERVICE\OpenVPNService` e não lia arquivos em `C:\ScoutSetup` ("Cannot pre-load keyfile"); resolvido embutindo as chaves na config. `windows-driver` e `persist-key` estão obsoletos no 2.7.

**Validado na rede local (2026-10-16 10:21):** perfil VPN criado no Scout Board (OU Enterprise > Rede > VPN: "OpenVPN", tipo OpenVPN, configuração `populos`, conectar automaticamente; gravado em `NetworkProfile` ID 4, `VpnType=1`). O eLux conectou (TLS 1.3, AES-256-GCM), recebeu **10.8.0.2** e o DNS 10.8.0.1, e o Scout passou a registrar `IP_Address = PeerIPAddress = 10.8.0.2`. Scout → eLux 10.8.0.2:22125 aberto. **O DNS entregue pela VPN funciona no eLux.**
- Efeito colateral: ao salvar a VPN, o Scout Board criou o **setup 2** próprio da OU Enterprise (`UseParent=0`), copiado da base, com fuso America/Sao_Paulo (conferido).
- O eLux pede **usuário e senha** na tela "Accessing OpenVPN" porque `NetworkProfile.Username/Pass` está vazio. O servidor autentica só por certificado e ignora o que for digitado (`elux`/`elux` funcionou). O Scout Board não mostra esses campos (só proxy em Advanced), e a senha é gravada criptografada pelo Scout → preencher pela **Scout Console**.

Pendências (Wagner):
- [ ] Roteador: Redirecionar Portas → **UDP 1194 → 192.168.15.25**, interface **ppp0.1**. **Problema:** o roteador Vivo grava a regra como **TCP** mesmo com UDP escolhido (duas tentativas). Opções: regra com "TCP/UDP", se existir; ou trocar a VPN para TCP 1194 (servidor `proto tcp-server` + perfil novo `populos-tcp.ovpn` + `VpnConfig=populos-tcp`). A troca foi bloqueada pelo classificador de permissões do Claude Code ("Modify Shared Resources") e aguarda decisão do Wagner. Backup previsto da config UDP: `C:\ScoutSetup\backup\scout-vpn-server-udp.ovpn`.
- Roteador em 2026-10-16: regra Scout 22125 TCP recriada (nome "OpenVPNeLux") e regra 1194 TCP.
- **VPN passada para TCP 1194 (2026-10-16 10:43, autorizado pelo Wagner):** servidor `proto tcp-server` (backup UDP em `C:\ScoutSetup\backup\scout-vpn-server-udp.ovpn`), firewall "OpenVPN eLux (TCP 1194)", perfil novo `populos-tcp.ovpn` (`proto tcp-client`) na OU Enterprise → `/setup/openvpn/populos-tcp.ovpn` (UCFTID 18), `NetworkProfile` 4 `VpnConfig` = `populos-tcp`. O `populos.ovpn` (UDP) continua no eLux, sem uso.
- Teste no 4G antes da troca: o eLux falava com o Scout (origem 181.77.138.37, IP 10.246.23.216 da operadora), mas a VPN não conectava (UDP bloqueado no roteador).
- [ ] Scout Console: OU Enterprise > Setup > Rede > VPN > perfil OpenVPN → usuário `elux` / senha `elux`, para o eLux parar de pedir.
- [ ] Teste no 4G: o eLux deve aparecer no Scout com origem 10.8.0.x e aceitar reinício pelo Scout. **Risco:** se o eLux não aplicar o DNS recebido pela VPN, ele continua falando com o Scout pelo IP público, e o plano precisa de ajuste.

### 7.10 Mudança para modo LOCAL, sem Cloudflare e sem VPN (2026-10-19)

**Contexto:** servidor levado para outra rede (Wi-Fi, IP **10.5.0.166/22**, gateway 10.5.0.1, IP público 179.191.87.86). Essa rede **bloqueia a saída na porta 7844 (UDP e TCP)**, a única que o Cloudflare Tunnel usa → Scout Board público devolvia 530. Wagner removeu a VPN (o serviço OpenVPN não existe mais) e pediu: **sem Cloudflare, Entra ID local, só acesso local**.

Feito:
- **Atualização (2026-10-19):** o Wagner trocou as redirect URIs do Entra ID para `https://10.5.0.166:22160/api/v1/auth/callback` (+ a pública). O `.env` foi para `HOST_NAME=10.5.0.166` (backup `scoutboard.env.localhost.bak`) e o ELIAS `api=10.5.0.166`, para outras máquinas da rede acessarem: **Scout Board https://10.5.0.166:22160**, **ELIAS http://10.5.0.166/ELIAS/**. Firewall 22160 e 80 liberados (perfil de rede Public).
- **Scout Board em modo local:** `.env` → `PORT=22160`, `HOST_NAME=localhost` (Entra ID mantido; a redirect URI `https://localhost:22160/api/v1/auth/callback` já estava registrada). Backup do modo público: `C:\ScoutSetup\backup\scoutboard.env.modo-publico.bak`. **Acesso: https://localhost:22160** (só neste servidor).
- DBLayer tinha subido com "Cannot start ZMQ broker" e não respondia (Scout Board parava antes de abrir a porta). Reiniciar DBLayer → Scout Board resolveu.
- **Cloudflare removido da máquina:** serviço `cloudflared` desinstalado (`cloudflared service uninstall` + MSI), pasta `C:\ProgramData\cloudflared` (token do túnel) apagada, tarefa **"Scout - DDNS Cloudflare"** removida.
- **ELIAS em modo local:** `config.json` → `api=WIN-8TMD3MHIPVG`, `http`, porta 80, `allowedOrigins` = WIN-8TMD3MHIPVG, localhost, 10.5.0.166. Backup do modo público: `C:\ScoutSetup\backup\elias-config.modo-publico.json`. Acesso: http://localhost/ELIAS/. Download dos eLux: `http://10.5.0.166/ELIAS/UC_RP6_X64/populos-elux7.idf` (testado 200).

Para eLux nesta rede:
- Scout: servidor **`10.5.0.166`** (os nomes `scout.populosplataform.com.br` e WIN-8TMD3MHIPVG não resolvem nesta rede).
- Firmware: protocolo **HTTP**, servidor `10.5.0.166`, caminho `ELIAS/UC_RP6_X64`, IDF `populos-elux7.idf`.
- O IP 10.5.0.166 é por DHCP; se mudar, reconfigurar.

Sobras na nuvem (não afetam a máquina; apagar no painel se não for voltar a usar): túnel `scout-WIN-8TMD3MHIPVG`, registros DNS `scout`/`scoutboard`/`elux.populosplataform.com.br`, 4 aplicações Access do ELIAS, token de API (`C:\ScoutSetup\cf-token.txt`, **revogar**), redirect URI pública no app do Entra ID. Ainda instalados e sem uso nesta rede: função DNS Server (zona `scout.populosplataform.com.br` → 192.168.15.25), License Server (precisa de internet para o LAS, que continua funcionando).

### 7.11 OU Populos: Outlook, Teams e logo POPULOS no boot (2026-10-19)
- OU **Populos** = `Groups.GroupID 4` (criada pelo Wagner; herda o setup base, `UseParentApps=1`). Nenhum eLux nela ainda.
- Login no Scout Board por linha de comando **não funciona**: quando o navegador do usuário abre o callback, o Scout Board já tenta trocar o código (uso único), e a segunda tentativa recebe `AADSTS70008`. Tudo foi feito direto no banco (backup `C:\ScoutSetup\backup\ScoutEnterprise-pre-populos-ou.bak`).
- **Códigos descobertos no Scout Board:** `AppTypeID` browser=3, local=5, rdp=10, omnissa=15, storefront=17, avd=19; `BrowserType` firefox=3, chromium=4, builtin=5, chrome=6, edge=7; AppMode normal=0, kiosk=1. O Scout Server entrega os apps por `Application.GroupID` (OU) + `AppLevel` (usado 1 = OU; os modelos globais são GroupID -1 / AppLevel 6).
- **Ícones de aplicativo:** `UCFT` com `FileType=1`, `FileMode=-1`, global (-1/-1), `FileName=<IconName>.png`, 32x32; o Scout Server entrega em `/setup/icons/<w>x<h>/`. Gravados `outlook.png` (UCFTID 26) e `teams.png` (UCFTID 27), a partir de `microsoft_office_outlook_logo_icon_145721.png` / `microsoft_office_teams_logo_icon_145726.png`.
- **Apps (Firefox, na área de trabalho):** Outlook (ApplicationID 4, `https://outlook.office.com`), Teams (ApplicationID 5, `https://teams.microsoft.com`). Não há cliente nativo de Outlook/Teams para eLux; o Teams no navegador é o caminho suportado pela Microsoft em Linux.
- **Tema `populos-ou-v1`** na OU Populos (UCFTID 21–25, FileEntry "Tema POPULOS OU", `CurrentTheme=populos-ou-v1`): igual ao da Enterprise, mas `productImage` (tela de boot) = símbolo POPULOS sem fundo (`images-removebg-preview.png`, cortado em 357x356).
- **Firmware e mudança de OU (2026-10-19, direto no banco; backup `ScoutEnterprise-pre-firmware.bak`):** `Server` 1 (tipo 7) = `10.5.0.166`; `Firmware` 1 → `Protocol=0` (HTTP; códigos FTP=1, FTPS=4, HTTP=0, HTTPS=3), `Path=ELIAS/UC_RP6_X64`, `AutoCheckUpdate=1`; `Setup` 0 (herdado pela OU Populos, Lost & Found e FollowMeDesktop, que também usa o firmware 1) → `ImageFile=populos-elux7.idf`. eLux **Portable01** (DeviceID 2, 10.5.1.4, eLux 7.2603.1000-3) movido para a OU Populos (`GroupID 4`). O eLux renomeado ganhou um DeviceID novo (o DeviceID 1 "Portable" não existe mais).
- Resultado 14:44–15:04: **ícones do Outlook/Teams apareceram no eLux** (formato de Application/UCFT validado). **Firmware não aplicado:** nenhuma requisição do eLux ao IIS → como a VPN, configuração de firmware gravada direto no banco não dispara a atualização; precisa do Scout Board (Apply + comando Update). O eLux oscilou entre OU 4 e 2 às 14:46–14:47.
- **Imagem `populos-elux7-v2`** (ELIAS, 28 EPMs, ~2,8 GB, sem conflitos) = v1 + `microsoft_edge`. `Setup` 0 `ImageFile` → `populos-elux7-v2.idf`.
- **Outlook/Teams viraram aplicativo local** (`AppTypeID=5`, linhas `Browser` removidas, `Local.Type=CUSTOM`): `/usr/bin/microsoft-edge --app=https://outlook.office.com --no-first-run` e idem para `https://teams.microsoft.com`. Abrem como janela de aplicativo (sem barra de endereço). **Dependem do Edge, que só existe depois de o eLux atualizar para a v2.** O Firefox não tem `--app` (só `--kiosk`).
- **Atualização para a v2 travando (2026-10-19 ~15:00):** o eLux baixou o `populos-elux7-v2.idf` (a mudança de `Setup.ImageFile` feita pelo banco **chegou**) e parte dos pacotes (44 às 14:54–14:55; ~20 às 15:03–15:04, depois de reiniciar), todos HTTP 200, sem pedir `.sig`, e parou. `Device.UpdateInfo` = `-1,0,…,257,-2147483648,…` (falha; o código 257 não está documentado publicamente). O Portable01 roda de um **pendrive SanDisk 58 GB** com partições fixas: system1 3,75 GB (0,7 usado), system2 3,75 GB, **update 3,75 GB com 3,0 GB ocupados**. Hipótese: falta de espaço na partição update (sobras de tentativas). Ação: `Firmware.FormatBeforeUpdate=1` (firmware 1), equivalente à opção "formatar a partição de update antes da entrega" do comando Delivery do Scout.
- **Atualização concluída:** às 15:19 o Portable01 voltou como **7.2609.0-12** (127 downloads do IIS). **Outlook e Teams via Edge `--app` validados pelo Wagner.**
- **Mirror:** `Setup.Mirror=16398`, `MirrorAcceptTimeout=10` (pede confirmação no eLux); porta 5900 aberta no eLux, mas não manda o banner RFB numa conexão VNC comum. O mirror do **Scout Board** usa WebRTC (`COMMAND.MIRROR_SDP_OFFER` / `MIRROR_ICE_CANDIDATE` às 18:27 UTC) e o eLux **não respondeu** (nenhuma resposta SDP nos logs); o `.env` não tem TURN. Próximo teste: mirror pela **Scout Console** (método clássico).
- **Citrix Workspace** (ApplicationID 6, `AppTypeID 17` StoreFront, valores do modelo Citrix, `Stores` vazio) e **Horizon** (ApplicationID 7, `AppTypeID 15` Omnissa; `VDA`: Server vazio, `UseSSL=1`, `ShowLastUser=1`, `Protocol=0`, `AllowH264=1`; valores de Protocol/Options **assumidos**, sem modelo para copiar) criados na OU Populos, na área de trabalho, sem ícone próprio. Faltam as URLs da loja Citrix e do servidor Horizon.
- **Por que mudanças gravadas no banco às vezes não chegam ao eLux (descoberto 2026-10-19):** cada `Device` tem `ConfigDataID` (versão que o eLux tem) e `ConfigDataIDToHave` (versão que deveria ter). Iguais = o eLux não baixa nada. O Scout Server só regenera a configuração quando `SetupChanged=1 OR SetupUserChanged=1 OR ApplicationsChanged=1` (o Scout Board marca isso no **Apply**). Explica a VPN e o Citrix/Horizon que não apareceram. **Regra daqui em diante:** depois de gravar configuração/aplicativos no banco, marcar `UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=<OU>` e reiniciar o eLux. Feito para o Portable01 às 15:36 (as marcas ficam pendentes até o próximo contato).
- **Horizon validado (abriu).** Citrix Workspace não abriu: os FPMs opcionais de Self-Service não estavam na imagem. **Imagem `populos-elux7-v3`** (30 EPMs, ~3,0 GB, sem conflitos) = v2 + `ica_selfservice`, `ica_webview`, `ctxext_ucselfservice`, `ctxext_ucselfservice_theme`, `ica_msteams`, `ica_usbrdr`, `ica_mmrdr`, `ica_browserrdr`, `ica_h264`. `Setup` 0 → `populos-elux7-v3.idf`.
- Mirror pelo Scout Board: o Scout Board abre `/mirror?host=10.5.1.4:5902` (no eLux só a 5900 está aberta). O ScoutServer tem logs `mirrorSdpOffer`/`mirrorIceCandidate`, mas nada apareceu → `eluxd.ini` `Debug=1` → **5** (backup `C:\ScoutSetup\backup\eluxd.ini.bak`; voltar a 1 depois do diagnóstico) e reinício de ScoutServer/DBLayer/ScoutBoard às 15:58.
- **Papéis de parede sumiram depois de o Wagner mover o eLux entre OUs** (passou pela OU nova **POC-BCR**, GroupID 5, sem tema). Hipótese: o eLux apaga os arquivos do tema ao entrar numa OU sem tema, e o Scout não reenvia arquivos que considera já entregues (compara a data). Correção: `TimeModified` dos 10 arquivos de tema (OUs 2 e 4) = agora + `SetupChanged/ApplicationsChanged=1`.
- **Erro na atualização para a v3 (16:16):** download ok (37 arquivos, 53 MB, todos 200), mas a instalação falhou (`UpdateInfo` …`,259,-2147483648`). A **partição `custom` caiu de 1,9 GB para 0**: é onde ficam os pacotes que não cabem em system1 (Edge, Firefox, Citrix, Horizon…). Causa provável: **`Firmware.FormatBeforeUpdate=1`, que eu tinha ligado**, apagou mais que a área temporária. **Desligado (`FormatBeforeUpdate=0`) às 16:18** + `SetupChanged=1` para repetir a atualização. Lição: não ligar essa opção sem documentação do que ela formata.
- **16:23–16:36:** tela do eLux "The idf has not been fully downloaded before formatting. eLux halted due to an error" (o eLux não apaga o sistema com download incompleto). Ele baixa só o `.idf` e desiste (erro 259): restos incompletos na partição update (2,2 GB) e a `custom` vazia. **O símbolo POPULOS apareceu na tela de boot (tema da OU Populos validado).** Para sair do ciclo: `Firmware.AutoCheckUpdate=0` (16:37). Próximo passo: comando **Delivery** do Scout Board com "formatar partição de update" (documentado: só a update) e depois **Update**; se falhar, reinstalar o pendrive (Recovery).
- O Scout Board desta versão não tem "formatar partição de update" no comando **Deliver software**; tem **"Complete software image delivered"** (entrega a imagem inteira, não só a diferença).
- **Imagem `populos-elux7-v4`** (29 EPMs, **~2,7 GB**, sem conflitos) = v3 **sem Firefox** (275 MB; o Outlook/Teams usam o Edge), para caber com folga na partição update (3,75 GB). Maiores pacotes: Edge 616 MB, desktop_environment 425, ica 364, xorg 344, baseos 228, wlandrivers 173. `Setup` 0 → `populos-elux7-v4.idf`.
- **Atualização para a v4 concluída (Wagner, via Deliver software com imagem completa + Update).** Citrix Workspace ainda não abria: o tipo StoreFront (`/usr/bin/ucselfservice`) precisa da URL da loja em `Storefront.Stores`, que está vazia. Troca provisória: app 6 → **local `/usr/bin/selfservice`** (Self-Service nativo da Citrix, abre a tela de adicionar conta). A linha `Storefront` do app 6 foi mantida; para voltar ao StoreFront com loja: `AppTypeID=17`, apagar a linha `Local` 6 e preencher `Stores`.
- **Self-Service nativo validado** (abriu). Depois, com a loja informada pelo Wagner, o app 6 voltou ao **StoreFront** (`AppTypeID=17`, linha `Local` 6 removida, `Storefront.Stores='https://populosntx.cloud.com'`; o Scout Server converte em `StoreUrl0`… para o eLux) com ícone **`citrix`** (UCFT FileType 1, a partir de `bfe68db6…_icon.ico`, 32x32). Se o StoreFront não abrir, voltar ao local `/usr/bin/selfservice`.
- **Modelo global "Citrix" removido** (ApplicationID 2 + linha Storefront 2; aparecia em todas as OUs por herança, `UseParentApps=1`). Ficaram os modelos Chromium (1) e RDP (3).
- **OU Bom Jesus criada** (`GroupID 6`, cópia das colunas da OU Populos, raiz `LocationID -1`; backup `ScoutEnterprise-pre-bomjesus.bak`). Apps copiados: Outlook (8), Teams (9), Citrix Workspace (10, mesma loja), Horizon (11). **Tema `bomjesus-v1`**: papel de parede `colegio bom jesus.jpg` (só 547x365, fica esticado), tela de boot = `bom_jesus-removebg-preview.png` (cortado em 297x337), brand = unicon, `accentColor #005020` (verde do logo), `welcomeBackgroundLayout none` (sem o pôster do astronauta).
- **Papel de parede da Bom Jesus trocado** para `bomjesus2.png` (1914x1044, prédio do Colégio Bom Jesus Aurora; salvo como JPG q92) → tema **`bomjesus-v2`** (destinos `/setup/elux/themes/bomjesus-v2/`, `CurrentTheme=bomjesus-v2`). Backup do anterior: `desktopBackgroundImage-v1.jpg.bak`.
- **Papel de parede da Bom Jesus trocado de novo** para o pôster `71863f23-1cfa-451d-bfd7-8e5dd81064f1.png` ("Colégio Bom Jesus – Educação e tecnologia florescendo juntas", com POPULOS | Citrix | Unicon). Como é vertical (1122x1402), foi montado em **1920x1080**: pôster inteiro centralizado e laterais com o próprio pôster ampliado e desfocado (prévia `C:\ScoutSetup\diag\preview-bomjesus-v3.png`). Tema **`bomjesus-v3`**. Backup do anterior: `desktopBackgroundImage-v2.jpg.bak`.
- **Papel de parede final da Bom Jesus:** `549aa68b-bbfe-43ca-a209-50a721b7554b.png` (versão horizontal do pôster, 1672x941) ampliado para 1920x1080, com **faixa escura em gradiente na lateral esquerda** (300 px, verde muito escuro com até 80% de opacidade, sumindo antes do título) para os nomes brancos dos ícones ficarem legíveis. Prévia com ícones simulados: `C:\ScoutSetup\diag\preview-bomjesus-v4.png`. Tema **`bomjesus-v4`**; backup do anterior `desktopBackgroundImage-v3.jpg.bak`.
- **OU Modo Kiosk** (`GroupID 7`, cópia da Populos, `UseParentApps=0` para não herdar os modelos Chromium/RDP; backup `ScoutEnterprise-pre-kiosk.bak`): só o **Citrix Workspace** (ApplicationID 12, StoreFront, mesma loja, ícone citrix) com `AutoStart=1` (abre ao ligar), `TM=1` (reabre se fechado), `AutostartResources='POPULOS LOCAL'` (abre esse desktop depois do login) e `DesktopsUseFullscreen=1`. Tema da Populos copiado (FileEntry "Tema Kiosk", `CurrentTheme=populos-ou-v1`).
  - **Login automático não configurado de propósito:** (1) seria a senha pessoal do Wagner gravada num quiosque, e qualquer um entraria como ele; o certo é uma conta de serviço só com acesso ao "POPULOS LOCAL"; (2) a loja é **Citrix Cloud** (`populosntx.cloud.com`), com login web/Entra, e o repasse de usuário/senha do eLux (`Storefront.Username/Pass/Domain`, a senha é gravada criptografada pelo Scout) funciona com StoreFront local, não com Citrix Cloud. A senha do Wagner apareceu no chat: recomendado trocar.
  - Mapeamentos: `Application.AutoStart` 1 = iniciar automaticamente; `Application.TM` 1 = reiniciar o app se fechado (UI "restartApp").
- **Descanso de tela/energia (pedido do Wagner: a tela apaga rápido):** `ScreenSaver` 1 e 2 = modo `blank` após 0:05:00; `PowerManagementProfile` vazio (o eLux usa os padrões). Tentativa de criar perfis pelo banco desfeita (ROLLBACK): os campos `ActionOn*`/`BrightnessLevel` são obrigatórios e não deu para confirmar o número de cada ação (`actionNone/Suspend/DisplayOff/Shutdown/Reboot/Ask/Logoff`); um valor errado pode desativar o botão de energia. **Fazer pelo Scout Board** (configuração base + Enterprise + FollowMeDesktop): monitor/suspensão/descanso desativados.
- Mensagem do Scout encontrada: "Client has no mirror package installed, request aborted" → o mirror exige o pacote no eLux (a v4 tem `mirror_server`).
- A validar: os dois apps aparecerem na OU Populos no Scout Board; um eLux movido para a OU recebendo apps, ícones e tema (2 reinícios para o tema; o Firefox precisa estar na imagem do eLux, e a `populos-elux7` já tem).

### 7.12 Repositório para recriar o ambiente (2026-10-19)
- Preparado em `C:\ScoutSetup\repo-github\` (31 arquivos, ~6,4 MB): `README.md`, `docs/RUNBOOK.md` (passo a passo), `docs/DB-REFERENCE.md` (códigos do banco), `docs/LICOES.md`, `docs/HISTORICO.md` (este MD sem e-mails/IDs/senhas), `scripts/` (extrair-fpm, montar-idf, publicar-tema, verificar-segredos, SQLs), `assets/themes` (populos-theme, populos-ou, bomjesus), `assets/icons`, `config/parametros.example.ps1`, `.gitignore`.
- Verificação: nenhum valor real de senha/token/chave nos arquivos.
- O envio ao GitHub ficou com o Wagner: o Claude Code bloqueou o push com o token colado no chat ("Data Exfiltration"). **Esse token foi exposto e deve ser revogado.** Depois o Wagner enviou: https://github.com/poncell255/scout-elux-lab.

### 7.13 Domínio populos.local, login AD nos eLux e OU Populos NonDomain (2026-10-20)
- Servidor colocado pelo Wagner no domínio **populos.local** e renomeado para **SCOUTBOARD** (antes WIN-8TMD3MHIPVG). IP 10.5.0.166, DNS 10.20.0.10. DC **POPAD01.populos.local** (10.20.0.10), portas 88/389/636 abertas a partir do servidor. `dblayer.ini` já usa `ScoutServer=scoutboard.populos.local`.
- **Códigos descobertos no Scout Board** (`Setup.AuthType`): None 0, **Active Directory (LDAP) 3**, AD + smartcard (WINDOWS) 5, Evidian 10, Entra ID 11, OpenID 12, Citrix 13, Imprivata 14, SAML 15. `DomainFieldStatus`: 0 editável, 1 não editável, 2 oculto. Lista de domínios = tabela `AuthDomain` (`Name`, `ServerList` separado por espaço, `SearchBase`, `SetupID`; `AuthDomainID` identity). `DefaultDomain` deve ser igual ao `Name` de uma linha.
- A imagem `populos-elux7-v4` já tem o login AD (`userauth` com `userauthldap`, `openldap`, `kerberos_config`, `pam`).
- **Feito direto no banco** (backup `C:\ScoutSetup\backup\ScoutEnterprise-pre-ad.bak`; script `C:\ScoutSetup\scripts\ad-e-nondomain.ps1`; desfazer: `C:\ScoutSetup\desfazer-ad-nondomain.sql`):
  - **AD ligado** nos setups **0** (configuração base: Populos, Bom Jesus, Modo Kiosk, POC-BCR, Lost & Found), **1** (FollowMeDesktop) e **2** (Enterprise): `AuthType=3`, `DefaultDomain=populos.local`, `DomainFieldStatus=0`, `AuthDomain` = `populos.local` / `POPAD01.populos.local` / `DC=populos,DC=local`.
  - **OU Populos NonDomain** (`GroupID 8`, raiz) com **setup próprio 3** (`UseParent=0`), clone do setup 0 **sem AD** (`AuthType=0`): mesma imagem v4, rede, descanso de tela, portas COM, energia, multimídia e tela. Apps copiados da Populos: Outlook (13), Teams (14), Citrix Workspace (15, loja populosntx.cloud.com), Horizon (16). Tema `populos-ou-v1` copiado (FileEntry "Tema Populos NonDomain"). Entra direto na área de trabalho, sem login.
  - `SetupChanged=1, ApplicationsChanged=1` em todos os dispositivos. O Portable01 está na **Bom Jesus** → no próximo boot pede login AD (`usuário` + senha do domínio, domínio populos.local).
- **Modo Kiosk sem AD (pedido do Wagner):** OU 7 com **setup próprio 4** (`UseParent=0`), clone do setup 3 (sem AD, `AuthType=0`): abre direto, sem login, e o Citrix inicia sozinho como antes. Backup `ScoutEnterprise-pre-kiosk-sem-ad.bak`; script `C:\ScoutSetup\scripts\kiosk-sem-ad.ps1`. Para desfazer: `UPDATE Groups SET UseParent=1, SetupID=0 WHERE GroupID=7` e apagar as linhas do setup 4 (mesmas tabelas do `desfazer-ad-nondomain.sql`).
- **Primeiro teste de login AD (Bom Jesus): "unknown error. Please contact your administrator".** O relógio do eLux estava **3 h atrasado** (06:55 com hora real 09:55): sem servidor de horário, o eLux trata a hora do BIOS (local) como UTC. O Kerberos recusa diferença maior que 5 min. O DC (10.20.0.10) **não responde NTP** (UDP 123, timeout a partir do servidor); `a.ntp.br` responde (diferença de -1 s em relação a este servidor).
  - **Correção:** servidores de horário `a.ntp.br` e `b.ntp.br` em **todos os setups (0–4)**. No banco: `Server.ServerTypeID=4` (`SERVERTYPE_TIME`, ServerID 3 e 4) + `ServerList` (`SetupID`, `ServerID`, `Instance=0`). Backup `ScoutEnterprise-pre-ntp.bak`; script `C:\ScoutSetup\scripts\ntp-elux.ps1`. Melhor depois: liberar NTP no POPAD01 e usá-lo como fonte.
- **Hora corrigida no eLux, mas o login AD continuou com "unknown error".** A configuração gerada (`ClientConfig.ClientData` do `Device.ConfigDataIDToHave`) está certa: `Security.AuthType=3`, `AuthServer=POPAD01.populos.local`, `AuthBase=DC=populos,DC=local`, `DefaultDomain=populos.local`, `[Authserver_populos.local]`, `Network.TimeServer1=a.ntp.br`. O Scout Board não usa `AuthVersion` (fica `<NULL>`).
  - **Nova hipótese: DNS.** O servidor usa DNS fixo 10.20.0.10. O eLux está no Wi-Fi `Populos_Tec` com DHCP, e o DHCP não entrega domínio (`ELUX_DOMAIN` vazio); provavelmente entrega um DNS que não conhece `populos.local`.
  - **Correção:** entradas de hosts no eLux (`/setup/hosts`) nos setups 0, 1, 2: `10.20.0.10` → `POPAD01.populos.local`, `POPAD01`, `populos.local`. No banco: `Host(HostID, IPAddress, Name)` + `HostList(HostListID, SetupID, HostID)`. Backup `ScoutEnterprise-pre-hosts.bak`; script `C:\ScoutSetup\scripts\hosts-ad-elux.ps1`. Solução definitiva: o DHCP do `Populos_Tec` entregar DNS 10.20.0.10 e domínio populos.local.
- **Hosts entregues (confirmado no `ClientConfig`), mas o erro continuou.** **Causa encontrada: o relógio do DC POPAD01 está ~8 min atrasado** (RootDSE `currentTime` 12:59:27Z × hora real 13:07:44Z; este servidor está a -1 s do a.ntp.br). Com o eLux agora na hora certa (a.ntp.br), a diferença para o DC passa de 5 min e o Kerberos recusa (KRB_AP_ERR_SKEW → "unknown error"). Antes do NTP o eLux estava 3 h errado; os dois erros mascararam um ao outro.
  - DC: nível funcional 7 (2016), SASL GSSAPI/GSS-SPNEGO/EXTERNAL/DIGEST-MD5, SRV `_kerberos._tcp.populos.local` → popad01:88.
  - **Feito pelo Wagner no POPAD01 (2026-10-20 ~10:16):** o serviço W32Time **não existia** (`w32tm /register`, início automático). Hora acertada à mão (`Set-Date +495 s`). Ao voltar o W32Time, o SCOUTBOARD passou a seguir o DC (NT5DS) e também atrasou 8 min, até o acerto. A configuração local não pegava porque uma GPO forçava `Type=NT5DS` (no PDC raiz isso = relógio local). Correção: **Default Domain Controllers Policy** → `HKLM\SOFTWARE\Policies\Microsoft\W32Time\Parameters` `Type=NTP`, `NtpServer=a.ntp.br,0x8 b.ntp.br,0x8`; firewall de entrada UDP 123. Resultado: `Source: a.ntp.br,0x8`, stratum 3. O DC é VM Hyper-V (`VMICTimeProvider` ligado): recomendado desligar (`Enabled=0`).
  - Comandos de referência (no POPAD01, com administrador do domínio): sincronizar o PDC com NTP externo e liberar UDP 123 — `w32tm /config /manualpeerlist:"a.ntp.br,0x8 b.ntp.br,0x8" /syncfromflags:manual /reliable:yes /update`, `Restart-Service w32time`, `w32tm /resync /force`, e regra de firewall de entrada UDP 123. Depois, opcional: trocar o NTP dos eLux para 10.20.0.10.
- **Diagnóstico do eLux (`diags_Portable01.zip`, 10:21) — causa real do "unknown error":** `/tmp/krb5.log`: `DNS lookup failed domain: _kerberos._udp.POPULOS.LOCAL` … `No KDC entries found for POPULOS.LOCAL`; journal: `pam_krb5(eluxauth:auth): authentication failure; logname=wagner.poncell`; `dhcp4 (wlan0): nameserver '10.5.0.1'` (o roteador do `Populos_Tec` não conhece populos.local). O Kerberos do eLux acha o KDC **só por SRV no DNS**; o `/setup/hosts` não basta. (`AuthManager: failed to read credentials from eluxd` aparece junto, é consequência.)
  - O `/etc/krb5.conf` do eLux (pacote `kerberos_config`) é só `includedir /setup/krb5.conf.d/` + `includedir /etc/krb5.conf.d/`.
  - **Correção:** arquivo `/setup/krb5.conf.d/populos.conf` (realm POPULOS.LOCAL, `kdc = 10.20.0.10`, `dns_lookup_kdc = false`, `rdns = false`) entregue por FileEntry/UCFT ("Kerberos POPULOS") nas OUs 0–6 (todas com AD). Backup `ScoutEnterprise-pre-krb5.bak`; script `C:\ScoutSetup\scripts\krb5-elux.ps1`. Solução definitiva: DHCP do `Populos_Tec` entregando DNS 10.20.0.10.
  - Para ler os diagnósticos: `tar -xf diags_<nome>.zip -C C:\dg1` (o Expand-Archive falha com nomes inválidos no Windows).
- **Login AD no eLux VALIDADO pelo Wagner (2026-10-20)**, depois do `populos.conf` de Kerberos.
- **Mirror — causa encontrada no diagnóstico:** `webrtcify[2365]: mirror not enabled` (serviço que leva o VNC do eLux por WebRTC até o Scout Board, termina com 255). A configuração enviada tinha `Security.Mirror=false`. `Setup.Mirror` é um campo de bits: 16398 = 0x400E (somente visualização 0x2, confirmação 0x4, DMCP 0x8, 0x4000 ?); **bit 0x1 = mirror ativo** estava desligado. Corrigido: `Mirror = Mirror | 1` → **16399** nos setups 0–4 + flags. Pacote `mirror_server` já está na v4; `x0vncserver.socket` ativo. **Mirror pelo Scout Board VALIDADO pelo Wagner.**
- **Mirror sem pedir permissão (acesso não supervisionado, pedido do Wagner):** bit 0x4 (`MirrorDialog`, confirmação no eLux) desligado → `Setup.Mirror=16395` nos setups 0–4. Validado pelo Wagner (abriu sem pedir). Depois, a pedido dele, **somente visualização desligado** (bit 0x2) → `Setup.Mirror=16393`: controle de mouse/teclado. Atenção: sem confirmação, quem tem acesso ao Scout Board vê a tela do usuário sem ele saber; avaliar LGPD/aviso aos usuários.
- **2 monitores clonados (espelhados) em todas as OUs (pedido do Wagner):** `Screen` Monitor_2 (`MonitorNumber 2`, `LayoutPos 0`, `LayoutNext 1` = duplicado do monitor 1, `Options` = do monitor 1 sem o bit 0x1) + `ScreenSettings.ScreenCount=2` nos setups 0–4 (MemberType 5). Codificação do Scout Board: `LayoutNext=0` = monitor de referência; `LayoutPos` 1 abaixo, 2 à direita, 3 à esquerda, 4 acima, **0 com LayoutNext≠0 = clone**. O significado exato dos bits de `Options` (7 no principal) não foi confirmado: conferir o `screens.ini` gerado. Backup `ScoutEnterprise-pre-2monitores.bak`. O Portable01 tem um `ScreenSettings` próprio (MemberType 4), mas usa o da OU (`UseParentScreenSettings=1`).
- **Tela sempre ativa em todas as OUs (pedido do Wagner, 2026-10-21):** a gestão de energia do eLux tem 4 perfis em `terminal.ini` (`PowerManagementEco`, `…EcoWorking`, `…Performance`, `…PerformanceWorking`); os não customizados vinham com **bloqueio de tela em 60 s, monitor desligado em 60 s e suspensão (ação 3) em 10 min**. Feito: `PowerManagementProfile` para **cada setup × ProfileType 1–4** com `DPMS=0` (desligar monitor), `S3=0` (suspender com login), `S3NoLogin=0` (sem login), `ScreenSaver=0` (bloqueio de tela) e prazos no máximo (5999940); `BrightnessLevel=100` nas linhas novas; `Setup.PowerManagementProfileType=2` (Performance; 0 automático, 1 Eco). Mapeamento das colunas confirmado pela seção PerformanceWorking (tipo 4); **tipos 1–3 = Eco/EcoWorking/Performance ainda a confirmar** na próxima configuração gerada. Backup `ScoutEnterprise-pre-tela-ativa.bak`; script `C:\ScoutSetup\scripts\tela-sempre-ativa.ps1`. O descanso de tela (`ScreenSaver.Mode=blank`) só aparece pelo `DisplayLockTimer`, que ficou desligado. `Setup.IdleTimeout` é de rede, não de tela.
- **Novo eLux** `eLux9252-5843-1894` (DeviceID 3) apareceu na OU Populos NonDomain (2026-10-21), mesmo IP 10.5.0.177 do Portable01: verificar se é outra máquina.
- **OU TV Projetos (2026-10-21, pedido do Wagner)** — `GroupID 9`, **setup próprio 5** (clone do setup 4 do Modo Kiosk: **sem AD**, NTP, energia desligada, mirror), `UseParentApps=0`, tema `populos-ou-v1`. Backup `ScoutEnterprise-pre-tv-projetos.bak`; script `C:\ScoutSetup\scripts\criar-ou-tv-projetos.ps1`.
  - **Hardware:** um PC com placa de vídeo e adaptadores para 6 telas (um eLux, 6 monitores **estendidos**). Scout: `ScreenSettings.ScreenCount=6`, grade 3×2 (`LayoutPos` 1 = abaixo, 2 = à direita): `1 3 5` em cima / `2 4 6` embaixo.
  - **Telas:** 1 portfólio aba 1/3, 2 time-projetos, 3 portfólio aba 2/3, 4 consultor-viagem, 5 portfólio aba 3/3, 6 mapa-calor-projetos (`https://populoshub.populos.com.br/…`). Usuário local do hub **TV** (perfil "telas"; senha em `credenciais.txt`). Sessão do hub dura 12 h (cookie `populos_planner_sid`).
  - **Por que um proxy:** a política da Unicon no Edge do eLux é `ExtensionInstallBlocklist: ["*"]` em `/usr/setup/microsoft-edge/managed/` (somente leitura), então extensão/userscript não dá. O botão "Tela cheia" das páginas chama `document.documentElement.requestFullscreen()`, que o navegador só aceita com clique, e **as páginas só atualizam os dados sozinhas com `document.fullscreenElement` preenchido**. Sem sessão o hub redireciona no servidor para `/`.
  - **Proxy reverso no IIS deste servidor:** site **"TV Projetos"**, porta **8090** (pool TVProjetos, firewall "TV Projetos proxy (8090)"), pasta `C:\inetpub\tvprojetos`. `web.config`: tudo → `https://populoshub.populos.com.br/` (ARR), menos `/tv/`; injeta `<script src="/tv/tv.js">` logo após `<head>`; tira `Secure` do `Set-Cookie` (proxy HTTP); `HTTP_ACCEPT_ENCODING` vazio para permitir a reescrita (variáveis liberadas no APPHOST).
  - **`/tv/tv.js`:** lê `#tv&d=<página>&u=&p=&pg=<aba>`, guarda na sessionStorage e limpa o hash; loga via `/api/login` quando `/api/me` diz que caiu e volta para a página `d`; confere a sessão a cada 5 min; no portfólio clica `#nextBtn` até a aba pedida (`#pageText` = "2/3"); simula a tela cheia (sobrescreve `fullscreenElement`/`requestFullscreen`/`exitFullscreen`) e chama o `toggleFullscreen()` da página; recarrega a cada 6 h. **Testado com Edge headless neste servidor:** as 6 URLs logam, abrem a página certa, ligam a tela cheia e o portfólio vai para 2/3 e 3/3 (print `C:\ScoutSetup\tv-projetos\preview-portfolio-aba2.png`).
  - **No eLux:** `/setup/tv/start-tv.sh` (FileEntry "TV Projetos - 6 telas"; fonte `C:\ScoutSetup\tv-projetos\start-tv.sh`) abre 6 Edge (`/opt/microsoft/msedge/microsoft-edge --kiosk`, perfil próprio em `/tmp/tv-perfil-N`, `--window-position/--window-size` do monitor lido em `xrandr --listactivemonitors`, ordem por x e depois y), `xset s off -dpms`, e reabre a janela que fechar (a cada 15 s). Log `/tmp/tv-projetos.log`. App local **"TV Projetos"** (ApplicationID 17, `/bin/bash /setup/tv/start-tv.sh`, `AutoStart=1`, `TM=1`).
  - **Primeiro teste no PC das 6 telas (Portable01 no PC, 2026-10-21 15:08): só 3 telas.** Diagnóstico (`diags_Portable01 (1).zip`): placa-mãe B360M AORUS Gaming 3, **duas NVIDIA `10de:1cb6` (Quadro P620, 4 saídas cada; PCI 1:0:0 e 2:0:0)**, monitores LG SIGNAGE 1920x1080. O eLux usou `nouveau`/modesetting **sem aceleração** (`Refusing to try glamor on llvmpipe`, `nvc0_screen_create … Base screen init failed: -19`): placa 1 = DP-2/3/4 (as 3 que acendem); placa 2 = DP-1-6/7/8 com `Failed to get free crtc output can not be turned on`. O `start-tv.sh` funcionou: `xrandr` presente, 3 monitores ativos, telas 4–6 abriram em cima das 1–3.
  - **Correção: imagem `populos-elux7-v5`** = v4 + EPM **`nvidia_driver` 580.173.02** (`nvidia_driver_base` + `kernel_nvidia_modules`), ~2,95 GB, sem conflitos (`C:\ScoutSetup\diag\idf-populos-v5.json`). Só o **setup 5 (TV Projetos)** usa a v5; os outros seguem na v4. Como `Firmware.AutoCheckUpdate=0`, a atualização precisa do comando no Scout Board (Deliver software com imagem completa + Update).
  - **v5 instalada (18:20–18:44 UTC; a entrega foi diferencial, 160 MB, e a instalação ocorre no boot, offline — a tela de boot parece travada ~20 min; o `UpdateInfo` passa por `261` durante e termina em `0`).** Diagnóstico pós-v5: o Scout guarda cada diagnóstico em `C:\Users\Public\Documents\Unicon\Scout\Server\diag\<nome>_<ip>_<data>_diag.zip`. Driver `nvidia` 580 nas duas placas, mas a placa 2 entra como GPU auxiliar (`NVIDIA(G0)`, MetaModes "NULL"); `xrandr`: DP-1/5/7 ligados (5760x2160), DP-1-1/1-5/1-7 conectados sem CRTC. NVIDIA não serve de saída "PRIME" para outra NVIDIA.
  - **Correção 2: Xorg Base Mosaic.** O eLux copia `/setup/X11/xorg.conf.d/*` sem alterar para `/etc/X11/xorg.conf.d` (`/usr/share/X11/prepare.d/01-copy-user-config.sh`); `/setup/X11/xorg.override.conf.d/*.conf` é outro formato (XML `GraphicCardInfos`, opções de Device, mesclado pelo `ucxorgconf` em `01_override.conf`). Entregue `20-tv-mosaic.conf` (OU 9; fonte `C:\ScoutSetup\tv-projetos\20-tv-mosaic.conf`): `AutoAddGPU false`, Device nvidia `PCI:1:0:0`, Screen `BaseMosaic True` + `MetaModes` GPU-0.DFP-1/5/7 em cima e GPU-1.DFP-1/5/7 embaixo (5760x2160), ServerLayout. `start-tv.sh` passou a dividir um monitor grande em blocos 1920x1080. Script de entrega `C:\ScoutSetup\scripts\tv-projetos-arquivos.ps1` (atualiza conteúdo + TimeModified). Se o X não subir: entregar o mesmo arquivo vazio (o eLux mantém o arquivo em `/setup`).
  - **Base Mosaic funcionou: as 6 TVs acenderam (Wagner, ~15:57)**, mas todas com a mesma imagem: `ScreenInfo` com as 6 saídas (`GPU-0.DP-1/5/7`, `GPU-1.DP-1/5/7`) em 0,0 — o serviço de monitores do eLux não casa esses nomes com o `screens.ini` e empilha tudo (clone), e o `start-tv.sh` abriu as 6 janelas em 0,0. **Correção 3:** o `start-tv.sh` espera 10 s, posiciona as saídas com `xrandr --output … --mode 1920x1080 --pos` (grade `LAYOUT`: GPU-0 em cima, GPU-1 embaixo), abre as janelas, e a cada 15 s refaz a grade e reabre as janelas se detectar monitores na mesma posição.
  - **Grade validada (6 telas distintas)**, com 3 ajustes pedidos pelo Wagner: (1) **nova ordem** por posição na área 5760x2160 — em cima: x0 portfólio 3/3, x1920 mapa de calor, x3840 time; embaixo: x0 viagens, x1920 portfólio 2/3, x3840 portfólio 1/3 (interpretação de uma instrução repetida na mensagem: a TV do portfólio 2/3 virou mapa de calor); (2) **tela piscando**: o script detectava "monitores empilhados" e fechava/reabria as 6 janelas a cada 15 s (briga com o serviço de monitores do eLux). Agora `TELAS` fixa a posição de cada página, a verificação compara a posição real de cada saída no `xrandr`, nunca fecha janelas e reposiciona no máximo 1x/min (log em `/tmp/tv-projetos.log`); IniEntry da OU 9 `/setup/terminal.ini [Screen] AutomaticLayoutAdjustment=false`; (3) **barra de tarefas** no monitor principal: setup 5 `ShowTaskbar=0`, `TaskbarAutoHide=1`.
  - **Clonou de novo após atualização de configuração (16:22) e ao reiniciar.** Log do script (`Portable01_10.5.0.14_20261021_162334_diag.zip`): 16:21:18 grade aplicada e 6 janelas abertas; 16:22:04 as 6 saídas voltaram para 0,0; 16:22:12 grade refeita, mas as janelas já tinham sido puxadas para 0,0 (só uma TV com conteúdo). **Causa raiz:** em `/setup/myscreens.xml` as 6 saídas `GPU-x.DP-y` têm o **mesmo UUID** — as 6 TVs LG SIGNAGE têm EDID idêntico (inclusive serial 16843009), então o serviço de monitores do eLux as vê como um monitor só e as clona sempre que reconfigura as telas. **Correção 4 (`start-tv.sh`):** espera 15 s, aplica a grade e registra o resultado; a cada 20 s, se a grade estiver errada, refaz (no máximo a cada 40 s) e, se pegar, fecha e reabre as 6 janelas; erros do `xrandr` vão para o log. Alternativas se continuar: usar TVs/monitores com EDID distinto, ou um adaptador/emulador de EDID por saída.
  - **Correção 4 validada pelo Wagner (2026-10-21): 6 TVs certas.** Pedido seguinte: **recarga a cada 5 min** → `tv.js` v5 faz `HEAD` na página e só recarrega se o hub responder (sem rede, mantém a tela); depois da recarga refaz login, aba e tela cheia. `start-tv.sh` com `--enable-offline-auto-reload` (Edge recarrega sozinho uma página de erro quando a rede volta). Repositório GitHub atualizado com tudo até 2026-10-21 (docs, scripts, `tv-projetos/`).
  - Risco: o eLux precisa montar uma área de trabalho única com as duas placas NVIDIA; se só usar a primeira, avaliar 4 telas na placa 1 + 2 na placa 2 ou uma placa com 6 saídas.
  - A validar no PC das 6 telas: posição das janelas por monitor (se a ordem física não bater, trocar cabos ou mudar a grade em `Screen`); `--kiosk` do Edge Linux; o `xrandr` existir na imagem.
- **OU Populos Dev (2026-10-22, pedido do Wagner)** — `GroupID 10`, **setup próprio 6** (clone do setup 0: **com AD**, NTP, hosts, energia, 2 monitores clonados, mirror; `AuthDomain` copiado) com **home persistente**: `Setup.PersistentHomeApplications='ALL'` (Scout Board "Persistent Home" → manter todos os apps; o valor também aceita lista separada por vírgula). Apps copiados da Populos (Outlook 18, Teams 19, Citrix 20, Horizon 21) + **VS Code** (22, `microsoft-edge --app=https://vscode.dev`) + **OneDrive** (23, `--app=https://www.microsoft365.com/onedrive`). Ícones novos desenhados com System.Drawing (`C:\ScoutSetup\icons\vscode.png` e `onedrive.png`, 32x32, prévia `preview-icones.png`), gravados como UCFT globais. Tema `populos-ou-v1` e `/setup/krb5.conf.d/populos.conf` copiados. Backup `ScoutEnterprise-pre-populos-dev.bak`; script `C:\ScoutSetup\scripts\criar-ou-populos-dev.ps1`. Não há VS Code nativo no catálogo do ELIAS (76 EPMs; só via vscode.dev, VDI ou empacotando com `epkg`).
  - **OneDrive corrigido (2026-10-22):** `microsoft365.com/onedrive` dava "Oops! The page you're looking for doesn't exist" depois do login (Wagner). Trocado para o OneDrive corporativo do tenant, **`https://populos-my.sharepoint.com`** (app 23; testado: redireciona para o login da SharePoint/Entra). eLux `DESKTOP-2N9TIRL` já está na Populos Dev.
  - A validar: home persistente mantendo o perfil do Edge (logins do vscode.dev/OneDrive) depois de reiniciar; a partição `setup` do eLux é pequena (256 MB no Portable01), então perfis grandes de navegador podem não caber.
- **Guia de implantação do zero (2026-10-22):** `docs/GUIA-IMPLANTACAO.md` no repositório GitHub (17 fases, parâmetros, regras de trabalho, operação e diagnóstico, tabela de problemas, validação, pendências e mapa dos scripts); `config/parametros.example.ps1` ganhou domínio, DC, NTP, imagens e parede de TVs. `eluxd.ini` `Debug` voltou de 5 para **1** (vale no próximo reinício do Scout Server). Repositório enviado com a OU Populos Dev, os ícones novos e o guia.
- **Resumo:** com AD = setups 0, 1, 2, 6 (Populos Dev) (Populos, Bom Jesus, POC-BCR, Lost & Found, Enterprise, FollowMeDesktop). Sem AD = setup 3 (Populos NonDomain), setup 4 (Modo Kiosk) e setup 5 (TV Projetos). Mudanças na configuração base **não chegam** mais às OUs NonDomain e Kiosk: elas têm cópias próprias, então altere as três quando for o caso (ex.: imagem nova).
- A validar: login AD no eLux (precisa alcançar o POPAD01 em 88/389 pela rede do eLux, 10.5.1.x); OU NonDomain aparecendo no Scout Board com apps e tema; se o login falhar com o nome curto, trocar `ServerList` para `10.20.0.10` ou testar LDAPS.

### 7.5 Endurecimento (depois que tudo estiver funcionando)
- [ ] Reduzir `scoutdb` de sysadmin para `db_owner` no `ScoutEnterprise`.
- [ ] Trocar o certificado autoassinado do Scout Board, se for expor para outros usuários.
- [ ] Mudar o perfil da rede para Private, ou restringir as regras ao escopo `LocalSubnet`.
- [ ] Rotina de backup do banco `ScoutEnterprise` (o Express não tem SQL Agent: usar Agendador de Tarefas + `sqlcmd`/PowerShell).
- [ ] Ativar o Windows Server (o Evaluation expira).

---

## 8. Referência: comando de instalação silenciosa usado

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
> Já corrigido aqui: `UCPROP_SCOUTKEEPALIVE_DBNAME=ScoutEnterprise`.
> Desinstalar: `ScoutInstaller.exe /s /uninstall`

### Verificação rápida de saúde
```powershell
Get-Service ScoutServer,ScoutKeepAlive,ScoutBoard,ScoutBoardDBLayer,TFTP,'MSSQL$SQLEXPRESS',W3SVC | ft Name,Status
Get-NetTCPConnection -State Listen | ? LocalPort -in 80,1433,22123,22124,22125,22160 | ft LocalPort,OwningProcess
Get-Content C:\Users\Public\Documents\Unicon\Scout\Server\eluxd.log -Tail 20
```

### Documentação oficial
- Instalação silenciosa: https://docs.citrix.com/en-us/unicon-elux-scout/2605/short_guides/installation/install_scout_suite/install_scout_unattended
- Instalação assistida: https://docs.citrix.com/en-us/unicon-elux-scout/short_guides/installation/install_scout_suite/install_scout_attended
