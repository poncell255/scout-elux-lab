$ErrorActionPreference = 'Stop'
# Netskope só na OU Populos (GroupID 4). O setup 0 é compartilhado com Lost & Found, POC-BCR e Bom Jesus, então a OU Populos
# ganha um setup próprio (cópia completa do setup 0, inclusive o domínio AD) com a imagem v37 (v22 + populos_netskope).
# O nome do instalador (com o token) vai como arquivo da OU em /setup/netskope/instalador e fica em credenciais.txt.
# Nenhum aparelho é movido. Recusa rodar duas vezes.
$Ou = 4; $SetupOrigem = 0; $Imagem = 'populos-elux7-v37.idf'
$cred = 'C:\ScoutSetup\credenciais.txt'; $rotulo = 'Netskope instalador OU Populos / '
$line = [IO.File]::ReadAllLines($cred) | Where-Object { $_.StartsWith($rotulo) } | Select-Object -First 1
if ($line) { $instalador = ($line -split ' / ', 2)[1].Trim() } else {
    $instalador = (Get-ChildItem C:\Users\Administrator\Downloads -Filter 'NSClient_*.run' | Select-Object -First 1).Name
    if (-not $instalador) { throw 'Instalador NSClient_*.run nao encontrado em Downloads' }
    [IO.File]::AppendAllText($cred, "`r`n$rotulo$instalador`r`n", [Text.UTF8Encoding]::new($false))
}
if ($instalador -notmatch '^NSClient_[^/\\ ]+_\.run$') { throw 'Nome do instalador fora do formato NSClient_..._.run' }
$cn = [Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True'); $cn.Open()
$backup = 'C:\ScoutSetup\backup\ScoutEnterprise-pre-netskope-populos-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.bak'
$z = $cn.CreateCommand(); $z.CommandTimeout = 600; $z.CommandText = 'BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM'; [void]$z.Parameters.AddWithValue('@p', $backup); [void]$z.ExecuteNonQuery(); $z.CommandText = 'RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM'; [void]$z.ExecuteNonQuery(); "Backup verificado: $backup"
$tx = $cn.BeginTransaction(); $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql, $p = @{}) { $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandTimeout = 600; $z.CommandText = $sql; foreach ($k in $p.Keys) { $v = $p[$k]; if ($v -is [byte[]]) { $q = $z.Parameters.Add($k, [Data.SqlDbType]::VarBinary, -1); $q.Value = $v } else { [void]$z.Parameters.AddWithValue($k, $v) } }; $z.ExecuteScalar() }
function Cols($t, $excl) { $l = ($excl | ForEach-Object { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }
function Arquivo($nome, $destino, $desc, [byte[]]$bytes) {
    $u = X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou' = $Ou; '@n' = $nome; '@tm' = $now; '@fc' = $bytes }
    [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou' = $Ou; '@n' = $nome; '@d' = $destino; '@ds' = $desc; '@u' = $u }) }
try {
    if ((X "SELECT COUNT(*) FROM Groups WITH (UPDLOCK,HOLDLOCK) WHERE GroupID=@ou AND Name='Populos' AND SetupID=@s" @{'@ou' = $Ou; '@s' = $SetupOrigem }) -ne 1) { throw 'OU Populos nao esta no setup 0 (ja configurada?); nada alterado' }
    if ((X "SELECT COUNT(*) FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND FileDestination LIKE '/setup/netskope/%'" @{'@ou' = $Ou }) -ne 0) { throw 'Arquivo Netskope ja existe na OU Populos' }
    # Setup próprio (cópia completa do setup 0 e tabelas filhas, como nas OUs BTG/HAPVIDA, mais o domínio AD)
    $s = X "SELECT MAX(SetupID)+1 FROM Setup WITH (UPDLOCK, HOLDLOCK)"
    $k = Cols 'Setup' @('SetupID'); [void](X "INSERT INTO Setup (SetupID,$k) SELECT @s,$k FROM Setup WHERE SetupID=@src" @{'@s' = $s; '@src' = $SetupOrigem })
    foreach ($t in @(@{t = 'ScreenSaver'; pk = 'ScreenSaverID' }, @{t = 'ComPort'; pk = 'ComPortID' }, @{t = 'NetworkProfile'; pk = 'NetworkProfileID' }, @{t = 'EluxVarList'; pk = 'EluxVarListID' }, @{t = 'HostList'; pk = 'HostListID' }, @{t = 'NetDrive'; pk = 'NetDriveID' }, @{t = 'Printer'; pk = 'PrinterID' }, @{t = 'ServerList'; pk = 'ServerListID' })) {
        $k = Cols $t.t @($t.pk, 'SetupID')
        [void](X "INSERT INTO [$($t.t)] ([$($t.pk)],SetupID,$k) SELECT mx.v+ROW_NUMBER() OVER(ORDER BY o.[$($t.pk)]),@s,$k FROM [$($t.t)] o CROSS JOIN (SELECT ISNULL(MAX([$($t.pk)]),0) v FROM [$($t.t)] WITH (UPDLOCK, HOLDLOCK)) mx WHERE o.SetupID=@src" @{'@s' = $s; '@src' = $SetupOrigem }) }
    $k = Cols 'AuthDomain' @('SetupID'); [void](X "INSERT INTO AuthDomain (SetupID,$k) SELECT @s,$k FROM AuthDomain WHERE SetupID=@src" @{'@s' = $s; '@src' = $SetupOrigem })
    $k = Cols 'PowerManagementProfile' @('SetupID'); [void](X "INSERT INTO PowerManagementProfile (SetupID,$k) SELECT @s,$k FROM PowerManagementProfile WHERE SetupID=@src" @{'@s' = $s; '@src' = $SetupOrigem })
    $k = Cols 'Multimedia' @('MemberType', 'MemberID'); [void](X "INSERT INTO Multimedia (MemberType,MemberID,$k) SELECT 5,@s,$k FROM Multimedia WHERE MemberType=5 AND MemberID=@src" @{'@s' = $s; '@src' = $SetupOrigem })
    $k = Cols 'ScreenSettings' @('MemberType', 'MemberID'); $ss = X "INSERT INTO ScreenSettings (MemberType,MemberID,$k) SELECT 5,@s,$k FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src; SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@s' = $s; '@src' = $SetupOrigem }
    $old = X "SELECT ScreenSettingsID FROM ScreenSettings WHERE MemberType=5 AND MemberID=@src" @{'@src' = $SetupOrigem }
    $k = Cols 'Screen' @('ScreenSettingsID'); [void](X "INSERT INTO Screen (ScreenSettingsID,$k) SELECT @n,$k FROM Screen WHERE ScreenSettingsID=@o" @{'@n' = $ss; '@o' = $old })
    [void](X 'UPDATE Setup SET ImageFile=@img WHERE SetupID=@s' @{'@s' = $s; '@img' = $Imagem })
    [void](X 'UPDATE Groups SET SetupID=@s WHERE GroupID=@ou' @{'@s' = $s; '@ou' = $Ou })
    # Nome do instalador (o cliente lê tenant e token dele no primeiro boot; depois usa /setup/netskope-estado)
    Arquivo 'instalador' '/setup/netskope/instalador' 'Netskope: nome do instalador com o token de cadastro (OU Populos)' ([Text.UTF8Encoding]::new($false).GetBytes("$instalador`n"))
    [void](X 'UPDATE Device SET SetupChanged=1,ApplicationsChanged=1 WHERE GroupID=@ou' @{'@ou' = $Ou })
    $tx.Commit(); "COMMIT OK: OU Populos=$Ou agora no setup $s (copia do setup $SetupOrigem) com imagem $Imagem e /setup/netskope/instalador. Nenhum aparelho movido."
} catch { if ($tx.Connection) { $tx.Rollback() }; throw } finally { $cn.Close() }
