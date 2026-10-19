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
| `NetworkProfile` VPN | `NetworkType=7`, `VpnType=1` (OpenVPN), `VpnConfig=<nome sem .ovpn>` |

## Tabelas usadas
- **UCFT**: conteúdo de arquivos (`FileContent` varbinary). Tema: `FileType=0`, `FileMode=0`, `MemberType=1/MemberID=<OU>`. Ícone de app: `FileType=1`, `FileMode=-1`, `MemberType=-1`, `FileName=<IconName>.png` (32x32), entregue em `/setup/icons/<w>x<h>/`.
- **FileEntry**: `FileEntryID` (não identity: use MAX+1), `MemberType`, `MemberID`, `FileSource`, `FileDestination`, `Description`, `UCFTID`.
- **IniEntry**: `IniEntryID` (MAX+1), `IniFile`, `IniSection`, `IniKey`, `IniValue`.
- **Application** (`ApplicationID` MAX+1, `GroupID`, `IconName` sem extensão) + **Browser** / **Local** (`Type='CUSTOM'`, `Parameter`=comando) / **Storefront** (`Stores`, `AutostartResources`, `DesktopsUseFullscreen`) / **VDA** (`Server`).
- **Groups** (OU): sem coluna de pai; OUs na raiz com `LocationID=-1`; `UseParent`, `UseParentApps`, `SetupID`.
- **Setup**: `FirmwareID`, `ImageFile`, `TimeZoneID`, `Mirror`, `MirrorAcceptTimeout`.
- **Administrator**: `Name` = conta Windows ou e-mail Entra; `AdministratorID` MAX+1.
- **PowerManagementProfile**: campos obrigatórios `BrightnessLevel`, `ActionOn*` (valores numéricos de `actionNone/Suspend/DisplayOff/Shutdown/Reboot/Ask/Logoff` não confirmados) → configure pelo Scout Board.

## Pacotes eLux (.fpm/.epm)
Cabeçalho "Lexu" + payload gzip + cpio newc. `scripts/extrair-fpm.ps1 -Pacote <fpm> -OffsetGzip <n>` extrai (offset = primeiro `1F 8B 08`). Flags de FPM no `rpmDescription` (`$FPMn=idx,arquivo,KB,FLAGS,n$`): bit 2 = obrigatório, bit 1 = pré-selecionado.
