# Referência do banco `ScoutEnterprise` (descoberto por engenharia reversa)

A Citrix não documenta estas tabelas. Valores obtidos lendo o código do Scout Board, DBLayer, Scout Server e Scout Console. Faça backup antes de gravar.

## Propagação para o eLux
- `Device.ConfigDataID` (versão que o eLux tem) × `Device.ConfigDataIDToHave` (versão que deveria ter). O Scout Server só regenera quando `SetupChanged=1 OR SetupUserChanged=1 OR ApplicationsChanged=1`. **Sempre** marque esses campos após gravar e reinicie o eLux.
- Arquivos transferidos são reenviados só quando `UCFT.TimeModified` muda (use epoch **UTC**: `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()`; `Get-Date -UFormat %s` no PS 5.1 dá horário local).

## Códigos
| Campo | Valores |
|---|---|
| `MemberType` (FileEntry/IniEntry/UCFT/MouseKB…) | 1 = OU (`Groups.GroupID`), 4 = dispositivo, 5 = setup, -1 = global, -2 = modelos |
| `Application.AppTypeID` | browser 3, local 5, rdp 10, omnissa 15, storefront 17, avd 19 |
| `Browser.BrowserType` | firefox 3, chromium 4, builtin 5, chrome 6, edge 7 |
| `Application.AppLevel` | 1 = OU (usado), 6 = modelos globais (`GroupID -1`) |
| `Application.AutoStart` / `TM` | 1 = iniciar automaticamente / 1 = reabrir se fechado |
| `Firmware.Protocol` | HTTP 0, FTP 1, HTTPS 3, FTPS 4 |
| `Server.ServerTypeID` | 7 = servidor de firmware |
| `TimeZone` | 195 America/Sao_Paulo, 267 US/Eastern |
| `Setup.AuthType` | None 0, Active Directory 3, AD+smartcard 5, Evidian 10, Entra ID 11, OpenID 12, Citrix 13, Imprivata 14, SAML 15 (domínios em `AuthDomain`: Name, ServerList, SearchBase, SetupID; `DefaultDomain` = Name) |
| `Setup.DomainFieldStatus` | 0 editável, 1 não editável, 2 oculto |
| OU com setup próprio | `Groups.UseParent=0` + `SetupID` novo; clonar Setup, ScreenSaver, ComPort, NetworkProfile, PowerManagementProfile, Multimedia/ScreenSettings(+Screen) `MemberType=5` |
| `NetworkProfile` VPN | `NetworkType=7`, `VpnType=1` (OpenVPN), `VpnConfig=<nome sem .ovpn>` |
| `Setup.Mirror` (bits) | 0x1 ativo, 0x2 somente visualização, 0x4 pedir confirmação no eLux, 0x8 DMCP, 0x4000 (?). Ex.: 16393 = ativo + controle + sem confirmação |
| `Server.ServerTypeID` 4 | servidor de horário (NTP); ligado ao setup por `ServerList(ServerListID, SetupID, ServerID, Instance=0)`; gera `terminal.ini [Network] TimeServer1..n` |
| Hosts | `Host(HostID, IPAddress, Name)` + `HostList(HostListID, SetupID, HostID)` → `/setup/hosts` |
| `Setup.PowerManagementProfileType` | 0 automático, 1 Eco, 2 Performance |
| `PowerManagementProfile` (`SetupID` × `ProfileType` 1–4 = Eco, Eco expediente, Performance, Performance expediente) | `DPMS` → DisplayOffTimerEnabled, `S3` → IdleTimerEnabled (suspender), `S3NoLogin` → IdleTimerNoLoginEnabled, `ScreenSaver` → DisplayLockTimerEnabled (bloqueio); prazos `*Delay` em segundos (5999940 = máximo); `ActionOnS3` 3 = suspender |
| `Screen` (monitores; `ScreenSettings.ScreenCount`) | `LayoutNext` = monitor de referência (0 = o primeiro); `LayoutPos` 1 abaixo, 2 à direita, 3 à esquerda, 4 acima, **0 com LayoutNext≠0 = clone**; `Options` bit 0x1 = principal |
| `Setup.ShowTaskbar` / `TaskbarAutoHide` | 0/1 → `terminal.ini [Layout] ShowTaskbar/TaskbarAutoHide` |

## Tabelas usadas
- **UCFT**: conteúdo de arquivos (`FileContent` varbinary). Tema: `FileType=0`, `FileMode=0`, `MemberType=1/MemberID=<OU>`. Ícone de app: `FileType=1`, `FileMode=-1`, `MemberType=-1`, `FileName=<IconName>.png` (32x32), entregue em `/setup/icons/<w>x<h>/`.
- **FileEntry**: `FileEntryID` (não identity: use MAX+1), `MemberType`, `MemberID`, `FileSource`, `FileDestination`, `Description`, `UCFTID`.
- **IniEntry**: `IniEntryID` (MAX+1), `IniFile`, `IniSection`, `IniKey`, `IniValue`.
- **Application** (`ApplicationID` MAX+1, `GroupID`, `IconName` sem extensão) + **Browser** / **Local** (`Type='CUSTOM'`, `Parameter`=comando) / **Storefront** (`Stores`, `AutostartResources`, `DesktopsUseFullscreen`) / **VDA** (`Server`).
- **Groups** (OU): sem coluna de pai; OUs na raiz com `LocationID=-1`; `UseParent`, `UseParentApps`, `SetupID`.
- **Setup**: `FirmwareID`, `ImageFile`, `TimeZoneID`, `Mirror`, `MirrorAcceptTimeout`.
- **Administrator**: `Name` = conta Windows ou e-mail Entra; `AdministratorID` MAX+1.
- **PowerManagementProfile**: campos obrigatórios `BrightnessLevel`, `ActionOn*`; `PowerManagementProfileID` é identity. Para "tela sempre ativa" ver `scripts/tela-sempre-ativa.ps1`.
- **ClientConfig**: `ClientData` (varbinary) = configuração gerada para o eLux; o `Device.ConfigDataIDToHave` aponta para ela.
- **AuthDomain**: `AuthDomainID` identity; `Name`, `ServerList` (servidores separados por espaço), `SearchBase`, `SetupID`.
- Tabelas com `SetupID` (clonar para criar setup próprio): Setup, ScreenSaver, ComPort, NetworkProfile, EluxVarList, HostList, NetDrive, Printer, ServerList, AuthDomain, PowerManagementProfile, UpdateDevice; e `MemberType=5` em Multimedia e ScreenSettings (+ `Screen` por `ScreenSettingsID`). Exemplo: `scripts/criar-ou-tv-projetos.ps1`.

## Pacotes eLux (.fpm/.epm)
Cabeçalho "Lexu" + payload gzip + cpio newc. `scripts/extrair-fpm.ps1 -Pacote <fpm> -OffsetGzip <n>` extrai (offset = primeiro `1F 8B 08`). Flags de FPM no `rpmDescription` (`$FPMn=idx,arquivo,KB,FLAGS,n$`): bit 2 = obrigatório, bit 1 = pré-selecionado.
