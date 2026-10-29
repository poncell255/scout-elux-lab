$ErrorActionPreference = 'Stop'
# Cria a OU "BTG" como cópia da OU 14 (HAPVIDA Local, setup 10): mesmos apps e arquivos, sem Horizon (fora da imagem),
# tema btg-v1, apps locais BTG no lugar dos de saúde e um app Azure Virtual Desktop (AppTypeID 19). Nenhum aparelho é movido.
$SetupOrigem = 10; $OuOrigem = 14; $Nome = 'BTG'; $Imagem = 'populos-elux7-v34.idf'; $Tema = 'btg-v1'
$src = 'C:\Users\Administrator\Downloads\btg-local'; $pastaTema = 'C:\eLuxContainer\theme\btg'
$AvdFeed = 'https://rdweb.wvd.microsoft.com/api/arm/feeddiscovery'
$cred = 'C:\ScoutSetup\credenciais.txt'
$line = [IO.File]::ReadAllLines($cred) | Where-Object { $_.StartsWith('BTG Local admin / ') } | Select-Object -First 1
if ($line) { $pwd = ($line -split ' / ', 2)[1].Trim() } else {
    $pwd = -join ((1..20) | ForEach-Object { 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'[(Get-Random -Maximum 55)] })
    [IO.File]::AppendAllText($cred, "`r`nBTG Local admin / $pwd`r`n", [Text.UTF8Encoding]::new($false))
}
$salt = New-Object byte[] 16; $rng = [Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($salt); $rng.Dispose()
$derive = [Security.Cryptography.Rfc2898DeriveBytes]::new($pwd, $salt, 210000, [Security.Cryptography.HashAlgorithmName]::SHA256)
$hash = $derive.GetBytes(32); $derive.Dispose()
$auth = @{ salt = ([BitConverter]::ToString($salt)).Replace('-', '').ToLowerInvariant(); iterations = 210000; digest = ([BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant() } | ConvertTo-Json -Compress
$cn = [Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True'); $cn.Open()
$backup = 'C:\ScoutSetup\backup\ScoutEnterprise-pre-ou-btg-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.bak'
$z = $cn.CreateCommand(); $z.CommandTimeout = 600; $z.CommandText = 'BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM'; [void]$z.Parameters.AddWithValue('@p', $backup); [void]$z.ExecuteNonQuery(); $z.CommandText = 'RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM'; [void]$z.ExecuteNonQuery(); "Backup verificado: $backup"
$tx = $cn.BeginTransaction(); $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql, $p = @{}) { $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandTimeout = 600; $z.CommandText = $sql; foreach ($k in $p.Keys) { $v = $p[$k]; if ($v -is [byte[]]) { $q = $z.Parameters.Add($k, [Data.SqlDbType]::VarBinary, -1); $q.Value = $v } else { [void]$z.Parameters.AddWithValue($k, $v) } }; $z.ExecuteScalar() }
function Cols($t, $excl) { $l = ($excl | ForEach-Object { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }
function Rows($sql) { $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandText = $sql; $tb = [Data.DataTable]::new(); $da = [Data.SqlClient.SqlDataAdapter]::new($z); [void]$da.Fill($tb); return , $tb }
function Arquivo($ou, $nome, $destino, $desc, [byte[]]$bytes) {
    $u = X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou' = $ou; '@n' = $nome; '@tm' = $now; '@fc' = $bytes }
    [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou' = $ou; '@n' = $nome; '@d' = $destino; '@ds' = $desc; '@u' = $u }) }
try {
    if ((X "SELECT COUNT(*) FROM Groups WITH (UPDLOCK,HOLDLOCK) WHERE Name=@n" @{'@n' = $Nome }) -ne 0) { throw 'OU BTG ja existe; preservada' }
    # Setup (cópia completa do setup 10 e tabelas filhas)
    $s = X "SELECT MAX(SetupID)+1 FROM Setup WITH (UPDLOCK, HOLDLOCK)"
    $k = Cols 'Setup' @('SetupID'); [void](X "INSERT INTO Setup (SetupID,$k) SELECT @s,$k FROM Setup WHERE SetupID=@src" @{'@s' = $s; '@src' = $SetupOrigem })
    foreach ($t in @(@{t = 'ScreenSaver'; pk = 'ScreenSaverID' }, @{t = 'ComPort'; pk = 'ComPortID' }, @{t = 'NetworkProfile'; pk = 'NetworkProfileID' }, @{t = 'EluxVarList'; pk = 'EluxVarListID' }, @{t = 'HostList'; pk = 'HostListID' }, @{t = 'NetDrive'; pk = 'NetDriveID' }, @{t = 'Printer'; pk = 'PrinterID' }, @{t = 'ServerList'; pk = 'ServerListID' })) {
        $k = Cols $t.t @($t.pk, 'SetupID')
        [void](X "INSERT INTO [$($t.t)] ([$($t.pk)],SetupID,$k) SELECT mx.v+ROW_NUMBER() OVER(ORDER BY o.[$($t.pk)]),@s,$k FROM [$($t.t)] o CROSS JOIN (SELECT ISNULL(MAX([$($t.pk)]),0) v FROM [$($t.t)] WITH (UPDLOCK, HOLDLOCK)) mx WHERE o.SetupID=@src" @{'@s' = $s; '@src' = $SetupOrigem }) }
    $k = Cols 'PowerManagementProfile' @('SetupID'); [void](X "INSERT INTO PowerManagementProfile (SetupID,$k) SELECT @s,$k FROM PowerManagementProfile WHERE SetupID=@src" @{'@s' = $s; '@src' = $SetupOrigem })
    $k = Cols 'Multimedia' @('MemberType', 'MemberID'); [void](X "INSERT INTO Multimedia (MemberType,MemberID,$k) SELECT 5,@s,$k FROM Multimedia WHERE MemberType=5 AND MemberID=@src" @{'@s' = $s; '@src' = $SetupOrigem })
    $k = Cols 'ScreenSettings' @('MemberType', 'MemberID'); $ss = X "INSERT INTO ScreenSettings (MemberType,MemberID,$k) SELECT 5,@s,$k FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src; SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@s' = $s; '@src' = $SetupOrigem }
    $old = X "SELECT ScreenSettingsID FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src" @{'@src' = $SetupOrigem }
    $k = Cols 'Screen' @('ScreenSettingsID'); [void](X "INSERT INTO Screen (ScreenSettingsID,$k) SELECT @n,$k FROM Screen WHERE ScreenSettingsID=@o" @{'@n' = $ss; '@o' = $old })
    [void](X "UPDATE Setup SET AuthType=0,DefaultDomain=NULL,DomainFieldStatus=NULL,ImageFile=@img,PersistentHomeApplications='ALL' WHERE SetupID=@s" @{'@s' = $s; '@img' = $Imagem })
    # OU
    $ou = X 'SELECT MAX(GroupID)+1 FROM Groups WITH (UPDLOCK,HOLDLOCK)'; $k = Cols 'Groups' @('GroupID', 'Name', 'DeviceCount', 'UseParent', 'SetupID')
    [void](X "INSERT INTO Groups (GroupID,Name,DeviceCount,UseParent,SetupID,$k) SELECT @ou,@n,0,0,@s,$k FROM Groups WHERE GroupID=@o" @{'@ou' = $ou; '@n' = $Nome; '@s' = $s; '@o' = $OuOrigem })
    # Apps (menos Horizon)
    $ka = Cols 'Application' @('ApplicationID', 'GroupID'); $apps = Rows "SELECT ApplicationID,Name,AppTypeID FROM Application WHERE GroupID=$OuOrigem AND AppTypeID<>15 ORDER BY ApplicationID"
    $cliente = 0; $cadastro = 0; $citrix = 0
    foreach ($a in $apps.Rows) {
        $id = X 'SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK,HOLDLOCK)'
        [void](X "INSERT INTO Application (ApplicationID,GroupID,$ka) SELECT @id,@ou,$ka FROM Application WHERE ApplicationID=@old" @{'@id' = $id; '@ou' = $ou; '@old' = $a.ApplicationID })
        foreach ($t in 'Browser', 'Local', 'RDP', 'Storefront', 'VDA', 'AVD') { $k = Cols $t @('ApplicationID'); [void](X "INSERT INTO [$t] (ApplicationID,$k) SELECT @id,$k FROM [$t] WHERE ApplicationID=@old" @{'@id' = $id; '@old' = $a.ApplicationID }) }
        if ($a.Name -eq 'Exames e Prontuário') { $cliente = $id; [void](X "UPDATE Local SET Parameter='/usr/bin/btg-local-cliente' WHERE ApplicationID=@id; UPDATE Application SET Name=N'Minha Conta BTG', DisplayName=N'Minha Conta BTG' WHERE ApplicationID=@id" @{'@id' = $id }) }
        if ($a.Name -eq 'Cadastro de Pacientes') { $cadastro = $id; [void](X "UPDATE Local SET Parameter='/usr/bin/btg-local-admin' WHERE ApplicationID=@id; UPDATE Application SET Name=N'Cadastro de Clientes BTG', DisplayName=N'Cadastro de Clientes BTG' WHERE ApplicationID=@id" @{'@id' = $id }) }
        if ($a.AppTypeID -eq 17) { $citrix = $a.ApplicationID }
    }
    if (-not $cliente -or -not $cadastro -or -not $citrix) { throw 'Apps de origem nao encontrados' }
    # Azure Virtual Desktop (cliente oficial ms_avd_client da imagem v34)
    $avd = X 'SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK,HOLDLOCK)'
    [void](X "INSERT INTO Application (ApplicationID,GroupID,$ka) SELECT @id,@ou,$ka FROM Application WHERE ApplicationID=@old" @{'@id' = $avd; '@ou' = $ou; '@old' = $citrix })
    [void](X "UPDATE Application SET AppTypeID=19, Name=N'Azure Virtual Desktop', DisplayName=N'Azure Virtual Desktop', IconName='', AutoStart=0, AppOnDesktop=1 WHERE ApplicationID=@id" @{'@id' = $avd })
    [void](X "INSERT INTO AVD (ApplicationID,AVDFeedUrl,SharedFolderPaths,FullscreenMode,AutostartResources) VALUES (@id,@f,'',1,'')" @{'@id' = $avd; '@f' = $AvdFeed })
    # Arquivos da OU 14, menos tema e dados HAPVIDA Local
    $files = Rows "SELECT f.FileSource,f.FileDestination,f.Description,u.FileContent FROM FileEntry f JOIN UCFT u ON f.UCFTID=u.UCFTID WHERE f.MemberType=1 AND f.MemberID=$OuOrigem AND f.FileDestination NOT LIKE '/setup/elux/themes/%' AND f.FileDestination NOT LIKE '/setup/hapvida-local/%'"
    foreach ($r in $files.Rows) { Arquivo $ou $r.FileSource $r.FileDestination $r.Description ([byte[]]$r.FileContent) }
    $ki = Cols 'IniEntry' @('IniEntryID', 'MemberID'); $ini = Rows "SELECT IniEntryID FROM IniEntry WHERE MemberType=1 AND MemberID=$OuOrigem AND IniKey<>'CurrentTheme'"
    foreach ($r in $ini.Rows) { $id = X 'SELECT ISNULL(MAX(IniEntryID),0)+1 FROM IniEntry WITH (UPDLOCK,HOLDLOCK)'; [void](X "INSERT INTO IniEntry (IniEntryID,MemberID,$ki) SELECT @id,@ou,$ki FROM IniEntry WHERE IniEntryID=@old" @{'@id' = $id; '@ou' = $ou; '@old' = $r.IniEntryID }) }
    # Tema BTG (wallpaper + logo de boot = productImage)
    foreach ($f in Get-ChildItem $pastaTema -File) { Arquivo $ou $f.Name "/setup/elux/themes/$Tema/$($f.Name)" 'Tema BTG' ([IO.File]::ReadAllBytes($f.FullName)) }
    [void](X "INSERT INTO IniEntry (IniEntryID, MemberType, MemberID, IniFile, IniSection, IniKey, IniValue) SELECT ISNULL(MAX(IniEntryID),0)+1, 1, @o, '/setup/terminal.ini', 'Layout', 'CurrentTheme', @t FROM IniEntry WITH (UPDLOCK, HOLDLOCK)" @{'@o' = $ou; '@t' = $Tema })
    # Configuração dos apps locais BTG
    $utf = [Text.UTF8Encoding]::new($false)
    Arquivo $ou 'admin-auth.json' '/setup/btg-local/admin-auth.json' 'BTG Local: verificador PBKDF2 administrativo, sem senha em texto' ($utf.GetBytes($auth))
    Arquivo $ou 'logo.png' '/setup/btg-local/logo.png' 'BTG Local: logo da tela da digital' ([IO.File]::ReadAllBytes("$src\app\web\static\logo.png"))
    Arquivo $ou 'cor-fundo' '/setup/btg-local/cor-fundo' 'BTG Local: cor da tela da digital' ($utf.GetBytes("#F3F7FF`n"))
    [void](X 'UPDATE Device SET SetupChanged=1,ApplicationsChanged=1 WHERE GroupID=@ou' @{'@ou' = $ou })
    $tx.Commit(); "COMMIT OK: OU BTG=$ou Setup=$s imagem=$Imagem tema=$Tema cliente=$cliente cadastro=$cadastro avd=$avd apps=$($apps.Rows.Count + 1) arquivos copiados=$($files.Rows.Count). Nenhum dispositivo movido."
} catch { if ($tx.Connection) { $tx.Rollback() }; throw } finally { $cn.Close() }
