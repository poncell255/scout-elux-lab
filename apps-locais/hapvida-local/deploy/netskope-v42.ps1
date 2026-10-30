$ErrorActionPreference = 'Stop'
# OU HAPVIDA Local (14, setup 10): imagem v42 (v31 - vmwareviewclient + populos_netskope .3 + libindicator3 + libdbusmenu),
# arquivo /setup/netskope/instalador copiado da OU Populos e app Horizon (84) removido, porque o cliente saiu da imagem.
$Ou = 14; $Setup = 10; $Imagem = 'populos-elux7-v42.idf'; $Horizon = 84
$cn = [Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True'); $cn.Open()
$backup = 'C:\ScoutSetup\backup\ScoutEnterprise-pre-netskope-hapvida-local-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.bak'
$z = $cn.CreateCommand(); $z.CommandTimeout = 600; $z.CommandText = 'BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM'; [void]$z.Parameters.AddWithValue('@p', $backup); [void]$z.ExecuteNonQuery(); $z.CommandText = 'RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM'; [void]$z.ExecuteNonQuery(); "Backup verificado: $backup"
$tx = $cn.BeginTransaction(); $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql, $p = @{}) { $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandTimeout = 600; $z.CommandText = $sql; foreach ($k in $p.Keys) { [void]$z.Parameters.AddWithValue($k, $p[$k]) }; $z.ExecuteScalar() }
try {
    if ((X 'SELECT COUNT(*) FROM Groups WHERE GroupID=@ou AND Name=''HAPVIDA Local'' AND SetupID=@s' @{'@ou' = $Ou; '@s' = $Setup }) -ne 1) { throw 'OU HAPVIDA Local/setup 10 nao conferem' }
    if ((X 'SELECT COUNT(*) FROM Groups WHERE SetupID=@s' @{'@s' = $Setup }) -ne 1) { throw 'Setup 10 usado por outra OU' }
    [void](X 'UPDATE Setup SET ImageFile=@i WHERE SetupID=@s' @{'@i' = $Imagem; '@s' = $Setup })
    if ((X "SELECT COUNT(*) FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND FileDestination='/setup/netskope/instalador'" @{'@ou' = $Ou }) -eq 0) {
        $u = X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) SELECT 1,@ou,FileType,FileName,FileMode,0,@tm,FileContent FROM UCFT WHERE UCFTID=(SELECT UCFTID FROM FileEntry WHERE MemberType=1 AND MemberID=4 AND FileDestination='/setup/netskope/instalador'); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou' = $Ou; '@tm' = $now }
        if (-not $u) { throw 'Arquivo instalador da OU Populos nao encontrado' }
        [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, 'instalador', '/setup/netskope/instalador', 'Netskope: nome do instalador com o token de cadastro (OU HAPVIDA Local)', @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou' = $Ou; '@u' = $u })
    }
    if ((X "SELECT COUNT(*) FROM Application WHERE ApplicationID=@a AND GroupID=@ou AND Name='Horizon'" @{'@a' = $Horizon; '@ou' = $Ou }) -eq 1) {
        [void](X 'DELETE FROM VDA WHERE ApplicationID=@a; DELETE FROM Application WHERE ApplicationID=@a' @{'@a' = $Horizon })
    }
    [void](X 'UPDATE Device SET SetupChanged=1,ApplicationsChanged=1 WHERE GroupID=@ou' @{'@ou' = $Ou })
    $tx.Commit(); "COMMIT OK: OU $Ou -> $Imagem, instalador Netskope, Horizon removido"
} catch { if ($tx.Connection) { $tx.Rollback() }; throw } finally { $cn.Close() }
