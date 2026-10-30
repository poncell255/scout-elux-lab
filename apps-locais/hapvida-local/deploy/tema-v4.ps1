$ErrorActionPreference = 'Stop'
# OU HAPVIDA Local (GroupID 14): troca o tema pelo hapvida-v4 (papel de parede "Hapvida Secure Endpoint Branding Scene", Downloads\hapvida-v4).
# A OU HAPVIDA (13) continua com o hapvida-v2.
$Ou = 14; $Tema = 'hapvida-v4'; $pastaTema = 'C:\Users\Administrator\Downloads\hapvida-v4'
$cn = [Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True'); $cn.Open()
$backup = 'C:\ScoutSetup\backup\ScoutEnterprise-pre-hapvida-local-tema-v4-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.bak'
$z = $cn.CreateCommand(); $z.CommandTimeout = 600; $z.CommandText = 'BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM'; [void]$z.Parameters.AddWithValue('@p', $backup); [void]$z.ExecuteNonQuery(); $z.CommandText = 'RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM'; [void]$z.ExecuteNonQuery(); "Backup verificado: $backup"
$tx = $cn.BeginTransaction(); $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql, $p = @{}) { $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandTimeout = 600; $z.CommandText = $sql; foreach ($k in $p.Keys) { $v = $p[$k]; if ($v -is [byte[]]) { $q = $z.Parameters.Add($k, [Data.SqlDbType]::VarBinary, -1); $q.Value = $v } else { [void]$z.Parameters.AddWithValue($k, $v) } }; $z.ExecuteScalar() }
function Arquivo($nome, $destino, $desc, [byte[]]$bytes) {
    $u = X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou' = $Ou; '@n' = $nome; '@tm' = $now; '@fc' = $bytes }
    [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou' = $Ou; '@n' = $nome; '@d' = $destino; '@ds' = $desc; '@u' = $u }) }
try {
    if ((X "SELECT COUNT(*) FROM Groups WHERE GroupID=@ou AND Name='HAPVIDA Local'" @{'@ou' = $Ou }) -ne 1) { throw 'OU HAPVIDA Local nao confere' }
    $velhos = X "SELECT STRING_AGG(CAST(UCFTID AS varchar(12)),',') FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND FileDestination LIKE '/setup/elux/themes/%'" @{'@ou' = $Ou }
    [void](X "DELETE FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND FileDestination LIKE '/setup/elux/themes/%'" @{'@ou' = $Ou })
    if ($velhos) { [void](X "DELETE FROM UCFT WHERE UCFTID IN ($velhos) AND NOT EXISTS (SELECT 1 FROM FileEntry f WHERE f.UCFTID=UCFT.UCFTID)") }
    foreach ($f in Get-ChildItem $pastaTema -File) { Arquivo $f.Name "/setup/elux/themes/$Tema/$($f.Name)" 'Tema HAPVIDA Local' ([IO.File]::ReadAllBytes($f.FullName)) }
    $n = X "UPDATE IniEntry SET IniValue=@t WHERE MemberType=1 AND MemberID=@ou AND IniFile='/setup/terminal.ini' AND IniSection='Layout' AND IniKey='CurrentTheme'; SELECT @@ROWCOUNT" @{'@ou' = $Ou; '@t' = $Tema }
    if ($n -ne 1) { throw "CurrentTheme: $n linhas" }
    [void](X 'UPDATE Device SET SetupChanged=1,ApplicationsChanged=1 WHERE GroupID=@ou' @{'@ou' = $Ou })
    $tx.Commit(); "COMMIT OK: OU $Ou tema=$Tema (UCFT antigos removidos: $velhos)"
} catch { if ($tx.Connection) { $tx.Rollback() }; throw } finally { $cn.Close() }
