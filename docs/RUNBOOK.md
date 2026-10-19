# RUNBOOK — recriar o ambiente Scout + ELIAS 18 + eLux 7

Ordem de execução testada. Valores entre `<>` vêm de `config/parametros.example.ps1`. Senhas: gere com um gerador forte e guarde **só** em `C:\ScoutSetup\credenciais.txt` (ACL Administradores/SYSTEM).

Pré-requisitos: Windows Server 2022/2025 com internet, conta Citrix com direito a licenças **Citrix Unicon (eLux/Scout)**, tenant Entra ID com Administrador Global, mídias: `ScoutInstaller.exe` 15.2609, `msodbcsql.msi` (ODBC 18), `CitrixLicensing 11.17.2`, `ELIAS_18.26032`, `eLux-7.2609.0_AllPackages.zip`, `eLux-certs-2025.0.zip`.

---

## 1. Banco de dados

1. ODBC: `msiexec /i msodbcsql.msi IACCEPTMSODBCSQLLICENSETERMS=YES /qn`
2. SQL Express: baixe o SSEI (`https://go.microsoft.com/fwlink/p/?linkid=2216019`), `SSEI /ACTION=Download /MEDIAPATH=… /MEDIATYPE=Core /QUIET`, extraia com `SQLEXPR_x64_ENU.exe /Q /X:<pasta>` e instale:
   ```
   setup.exe /Q /ACTION=Install /FEATURES=SQLEngine /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT="NT Service\MSSQL$SQLEXPRESS" /SQLSYSADMINACCOUNTS="BUILTIN\Administrators" /SECURITYMODE=SQL /SAPWD="<SENHA_SQL_SA>" /TCPENABLED=1 /BROWSERSVCSTARTUPTYPE=Automatic /UPDATEENABLED=0 /IACCEPTSQLSERVERLICENSETERMS
   ```
3. Porta fixa 1433: registro `HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL*.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp\IPAll` → `TcpPort=1433`, `TcpDynamicPorts=""`; reinicie o serviço. Firewall TCP 1433 / UDP 1434.
4. Login do Scout: `CREATE LOGIN [scoutdb] WITH PASSWORD=N'<SENHA_SQL_SCOUT>'; ALTER SERVER ROLE [sysadmin] ADD MEMBER [scoutdb];` (reduza para `db_owner` depois).

## 2. Scout Enterprise (instalação silenciosa)

O instalador é um bundle WiX Burn com BA próprio: **use `/s` e `/v"CHAVE=valor"`** (não use `-layout`, trava).
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
- O Keep Alive usa o **mesmo banco** do Scout (tabela `Entity`): `UCPROP_SCOUTKEEPALIVE_DBNAME=ScoutEnterprise`.
- O instalador ignora `UCPROP_TIMEZONE`: corrija depois (`Setup.TimeZoneID` 267 US/Eastern → 195 America/Sao_Paulo).
- Firewall (grupo "Scout eLux"): TCP+UDP 22123, TCP 22125, 22124, 22160 (ou 443), UDP 69, TCP 80.

## 3. Licença (Citrix License Server + LAS)

Desde 15/04/2026 só há licença via **LAS**. `CitrixLicensing.exe /quiet /l <log>` (funciona no WS 2025; portas 27000, 7279, 8083). Em `https://localhost:8083` → Settings → Citrix Cloud → **Register** → código em citrix.cloud.com (Licensing → License Servers → Add). No Scout Board, tela de licença → modo Citrix License Server. Validação: `eluxd.log` com `hasLicense: 0->1`.

## 4. Scout Board com Entra ID (OIDC)

1. App registration single-tenant; redirect URI = `https://<HOST_NAME>[:porta]/api/v1/auth/callback` (o Scout Board monta com `HOST_NAME` + `PORT` do `.env`; porta 443 omitida). Permissões delegadas Graph: openid, profile, email, offline_access, User.Read, GroupMember.Read.All, Directory.Read.All + **admin consent**. Enterprise app com *Assignment required* e só os usuários autorizados.
2. `C:\Program Files\Unicon\Scout\ScoutBoard\.env`: `AUTH_TYPE=ENTRAID_OIDC`, `OIDC_ISSUER=https://login.microsoftonline.com/<TENANT_ID>/v2.0`, `OIDC_CLIENT_ID=<APP_ID>`, `OIDC_CLIENT_SECRET=<SEGREDO>`, `HOST_NAME=<IP ou FQDN>`, `PORT=22160`. ACL do `.env` só Admins/SYSTEM.
3. Autorização: o e-mail/UPN do token precisa existir em `Administrator.Name` (copie `Rights/Type/ID/ProfileType` do administrador inicial) — ver `scripts/sql/admin-entra.sql`.
4. Sem AD o login padrão do Scout Board falha (`LDAPS_UNREACHABLE`): Entra ID é obrigatório nesse cenário.
5. Se o Scout Board não abrir a porta: reinicie **DBLayer → Scout Board** (o DBLayer às vezes sobe com "Cannot start ZMQ broker").

## 5. ELIAS 18

1. Instalação silenciosa (mesmo formato do Scout):
   ```
   EliasInstaller.exe /s /log <log> /v"INSTALLMONGODB=1" /v"ELIASDATABASE=ELIAS" /v"IISCONFIG=1" /v"IISROOT=Default Web Site" /v"ELIASPATH=ELIAS" /v"ELIASPORT=22130" /v"HASAD=0" /v"HASKEYCLOAK=0" /v"ADMINPASSWORD=<SENHA_ELIAS_ADMIN>"
   ```
2. **Bug:** `server.json` fica com `"server": "Empty"` → corrija para `"localhost:27017"` e reinicie o serviço `ELIAS`.
3. `config.json`: o ELIAS migra para o MongoDB e deixa `config.json.migrated`; se a config sumir, recrie a partir dele. Ajuste `api` (IP/host que os navegadores e eLux alcançam), `protocol`, `port`, `allowedOrigins`.
4. Importe o container eLux 7 pela UI (cria o container `UC_RP6_X64` com versão `UC_ELUX7-1.0`).
5. **Imagens pela API**: login `POST /ELIAS/api/<container>/v1.0/authenticate/` `{user,domain,password}`; dados em `GET …/epms`, `…/fpms`, `…/idfs` → `scripts/montar-idf.ps1` monta a IDF partindo de `migration-system-*` e resolvendo dependências → `POST …/idfs` com `{idf:{…, id:"<nome>.idf"}}`.
6. **URL de download dos eLux**: `http://<servidor>/ELIAS/<container>/<arquivo>` (ex.: `/ELIAS/UC_RP6_X64/populos-elux7-v4.idf`). A API `…/v1.0/…` só devolve metadados.
7. Imagem final usada (`populos-elux7-v4`, ~2,7 GB): base `migration-system` + `ica`, `citrix_extensions`, `citrix_hdxrtme`, `vmwareviewclient`, `microsoft_edge` + FPMs `mirror_server`, `ica_selfservice`, `ica_webview`, `ctxext_ucselfservice`, `ctxext_ucselfservice_theme`, `ica_msteams`, `ica_usbrdr`, `ica_mmrdr`, `ica_browserrdr`, `ica_h264`. Mantenha < ~3 GB (partição update do eLux = 3,75 GB).

## 6. Firmware das OUs

`Server` (tipo 7) = IP do servidor; `Firmware`: `Protocol=0` (HTTP; FTP=1, FTPS=4, HTTPS=3), `Path=ELIAS/<container>`; `Setup.ImageFile=<imagem>.idf`. **Depois de qualquer gravação no banco:** `UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=<OU>`. Para aplicar: no Scout Board, **Deliver software** (marque *Complete software image delivered*) e depois **Update software**. Não ligue `FormatBeforeUpdate` (apagou a partição `custom`).

## 7. Temas por OU (papel de parede e logo da tela de boot)

Arquivos (guia Citrix "Theming guide"): `config.json`, `desktopBackgroundImage.jpg`, `productImage.png` (**é o que aparece na tela de boot**, 304x304 contain), `brandImage.png` (logo do botão Iniciar; o original "unicon" está no pacote `elux_theme`), `welcomeBackgroundImage.png` (opcional). Publicação na OU: `scripts/publicar-tema.ps1` (UCFT + FileEntry para `/setup/elux/themes/<nome>/` + IniEntry `/setup/terminal.ini [Layout] CurrentTheme=<nome>`). **Toda troca de imagem → nome novo (`-v2`, `-v3`…)**, senão o eLux mantém a cópia em cache. Reinicie o eLux 2x.

## 8. Aplicativos por OU

Ver `docs/DB-REFERENCE.md` e `scripts/sql/apps-*.sql`:
- Outlook/Teams: tipo local `CUSTOM`, `/usr/bin/microsoft-edge --app=https://outlook.office.com --no-first-run` (idem Teams), ícones na `UCFT` `FileType=1`.
- Citrix Workspace: StoreFront (`AppTypeID 17`), `Storefront.Stores='https://<loja>'`, precisa dos FPMs de Self-Service na imagem.
- Horizon: `AppTypeID 15` + linha `VDA`.
- Quiosque: `AutoStart=1`, `TM=1`, `Storefront.AutostartResources='<desktop>'`, `DesktopsUseFullscreen=1`, `Groups.UseParentApps=0`.

## 9. Acesso remoto (opcional)

Testado e documentado em `docs/HISTORICO.md`: Cloudflare Tunnel (precisa de saída TCP/UDP **7844**; bloqueado em algumas redes), DDNS no Cloudflare, OpenVPN no Windows para comandos do Scout a eLux atrás de CGNAT (o roteador Vivo só grava regra TCP → VPN em TCP 1194). Para eLux de fora da rede receberem comandos do Scout é preciso VPN ou Scout Cloud Gateway (Linux, 8 GB).

## 10. Validação final

- `Get-Service ScoutServer,ScoutBoard,ScoutBoardDBLayer,ScoutKeepAlive,'MSSQL$SQLEXPRESS',ELIAS,MongoDB,W3SVC,'Citrix Licensing'`
- Scout Board: login Entra → dashboard; eLux aparece na OU certa.
- `Device.OSVersion` = versão da imagem; `ConfigDataID = ConfigDataIDToHave`.
