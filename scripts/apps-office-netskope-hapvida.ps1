$ErrorActionPreference = 'Stop'
# 1) Word, Excel e PowerPoint (Microsoft 365 web, Edge --app como o Outlook) em todas as OUs de uso, com ícones globais.
#    Ficam de fora: Lost & Found (0, 1), Enterprise (2, raiz herdada) e Provas (12, só a prova).
# 2) Netskope na OU HAPVIDA (13): setup 9 -> v41 (v29 + populos_netskope .3) e arquivo /setup/netskope/instalador copiado da OU Populos.
# Recusa rodar duas vezes (apps já existentes).
$Ous = 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15
$Icones = 'C:\ScoutSetup\icons'
$Apps = @(
    @{ n = 'Word'; i = 'word'; u = 'https://word.cloud.microsoft' },
    @{ n = 'Excel'; i = 'excel'; u = 'https://excel.cloud.microsoft' },
    @{ n = 'PowerPoint'; i = 'powerpoint'; u = 'https://powerpoint.cloud.microsoft' })
$cn = [Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True'); $cn.Open()
$backup = 'C:\ScoutSetup\backup\ScoutEnterprise-pre-office-netskope-hapvida-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.bak'
$z = $cn.CreateCommand(); $z.CommandTimeout = 600; $z.CommandText = 'BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM'; [void]$z.Parameters.AddWithValue('@p', $backup); [void]$z.ExecuteNonQuery(); $z.CommandText = 'RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM'; [void]$z.ExecuteNonQuery(); "Backup verificado: $backup"
$tx = $cn.BeginTransaction(); $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql, $p = @{}) { $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandTimeout = 600; $z.CommandText = $sql; foreach ($k in $p.Keys) { $v = $p[$k]; if ($v -is [byte[]]) { $q = $z.Parameters.Add($k, [Data.SqlDbType]::VarBinary, -1); $q.Value = $v } else { [void]$z.Parameters.AddWithValue($k, $v) } }; $z.ExecuteScalar() }
function Cols($t, $excl) { $l = ($excl | ForEach-Object { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }
try {
    if ((X "SELECT COUNT(*) FROM Application WHERE Name IN ('Word','Excel','PowerPoint')") -ne 0) { throw 'Apps Office ja existem' }
    # Modelo: Outlook web da OU Populos (app 4)
    $modelo = 4
    if ((X "SELECT COUNT(*) FROM Local WHERE ApplicationID=@m AND Parameter LIKE '/usr/bin/microsoft-edge --app=https://outlook.office.com%'" @{'@m' = $modelo }) -ne 1) { throw 'Modelo Outlook (app 4) nao confere' }
    foreach ($a in $Apps) {
        $png = [IO.File]::ReadAllBytes("$Icones\$($a.i).png"); $f = "$($a.i).png"
        $ico = X "SELECT TOP 1 UCFTID FROM UCFT WHERE MemberType=-1 AND MemberID=-1 AND FileType=1 AND FileName=@f" @{'@f' = $f }
        if ($ico) { [void](X 'UPDATE UCFT SET FileContent=@fc, TimeModified=@tm WHERE UCFTID=@u' @{'@fc' = $png; '@tm' = $now; '@u' = $ico }) }
        else { [void](X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (-1,-1,1,@f,-1,0,@tm,@fc)" @{'@f' = $f; '@tm' = $now; '@fc' = $png }) }
    }
    $ka = Cols 'Application' @('ApplicationID', 'GroupID'); $kl = Cols 'Local' @('ApplicationID'); $criados = @()
    foreach ($ou in $Ous) {
        foreach ($a in $Apps) {
            $id = X 'SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK,HOLDLOCK)'
            [void](X "INSERT INTO Application (ApplicationID,GroupID,$ka) SELECT @id,@ou,$ka FROM Application WHERE ApplicationID=@m" @{'@id' = $id; '@ou' = $ou; '@m' = $modelo })
            [void](X "INSERT INTO Local (ApplicationID,$kl) SELECT @id,$kl FROM Local WHERE ApplicationID=@m" @{'@id' = $id; '@m' = $modelo })
            $p = "/usr/bin/microsoft-edge --app=$($a.u) --no-first-run --user-data-dir=/home/elux/.config/microsoft-edge/app-$($a.i) --class=$($a.n)"
            [void](X "UPDATE Local SET Parameter=@p WHERE ApplicationID=@id; UPDATE Application SET Name=@n, DisplayName=@n, IconName=@i, AutoStart=0, AppOnDesktop=1 WHERE ApplicationID=@id" @{'@id' = $id; '@p' = $p; '@n' = $a.n; '@i' = $a.i })
            $criados += "$ou/$($a.n)=$id"
        }
    }
    "Apps: $($criados -join ', ')"
    # Netskope na OU HAPVIDA
    if ((X "SELECT COUNT(*) FROM Groups WHERE GroupID=13 AND Name='HAPVIDA' AND SetupID=9") -ne 1) { throw 'OU HAPVIDA/setup 9 nao conferem' }
    if ((X 'SELECT COUNT(*) FROM Groups WHERE SetupID=9') -ne 1) { throw 'Setup 9 usado por outra OU' }
    [void](X "UPDATE Setup SET ImageFile='populos-elux7-v41.idf' WHERE SetupID=9")
    if ((X "SELECT COUNT(*) FROM FileEntry WHERE MemberType=1 AND MemberID=13 AND FileDestination='/setup/netskope/instalador'") -eq 0) {
        $u = X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) SELECT 1,13,FileType,FileName,FileMode,0,@tm,FileContent FROM UCFT WHERE UCFTID=(SELECT UCFTID FROM FileEntry WHERE MemberType=1 AND MemberID=4 AND FileDestination='/setup/netskope/instalador'); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@tm' = $now }
        if (-not $u) { throw 'Arquivo instalador da OU Populos nao encontrado' }
        [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, 13, 'instalador', '/setup/netskope/instalador', 'Netskope: nome do instalador com o token de cadastro (OU HAPVIDA)', @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@u' = $u })
    }
    $ouList = ($Ous -join ',')
    $n = X "UPDATE Device SET SetupChanged=1,ApplicationsChanged=1 WHERE GroupID IN ($ouList); SELECT @@ROWCOUNT"
    $tx.Commit(); "COMMIT OK: $($criados.Count) apps; OU HAPVIDA -> v41 + instalador Netskope; $n dispositivos marcados"
} catch { if ($tx.Connection) { $tx.Rollback() }; throw } finally { $cn.Close() }
