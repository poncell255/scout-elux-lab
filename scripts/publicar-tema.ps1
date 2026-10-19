param(
    [Parameter(Mandatory)][int]$OuId,                 # Groups.GroupID
    [Parameter(Mandatory)][string]$Pasta,             # pasta com config.json e imagens
    [Parameter(Mandatory)][string]$NomeTema,          # ex.: populos-ou-v2 (troque o sufixo a cada mudança de imagem)
    [Parameter(Mandatory)][string]$SqlSaPassword,
    [string]$Descricao = "Tema $NomeTema",
    [string]$SqlServer = 'localhost,1433'
)
# Publica um tema eLux 7 numa OU do Scout (UCFT + FileEntry + IniEntry) e marca os eLux para receber.
# Substitui o tema anterior da OU (mesma Description não é exigida: remove todo FileEntry em /setup/elux/themes/ da OU).
$ErrorActionPreference = 'Stop'
$cfgPath = Join-Path $Pasta 'config.json'
$cfg = (Get-Content $cfgPath -Raw) -replace '"name":\s*"[^"]+"', ('"name": "' + $NomeTema + '"')
[IO.File]::WriteAllText($cfgPath, $cfg)
$arquivos = Get-ChildItem $Pasta -File | Where-Object { $_.Name -in 'config.json','desktopBackgroundImage.jpg','productImage.png','brandImage.png','welcomeBackgroundImage.png' }

$cn = New-Object System.Data.SqlClient.SqlConnection("Server=$SqlServer;Database=ScoutEnterprise;User ID=sa;Password=$SqlSaPassword;TrustServerCertificate=True")
$cn.Open(); $tx = $cn.BeginTransaction(); $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql, $p = @{}) { $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandText = $sql
    foreach ($k in $p.Keys) { $v = $p[$k]; if ($v -is [byte[]]) { $q = $z.Parameters.Add($k, [Data.SqlDbType]::VarBinary, -1); $q.Value = $v } else { [void]$z.Parameters.AddWithValue($k, $v) } }
    $z.ExecuteScalar() }
try {
    [void](X "DELETE FROM UCFT WHERE UCFTID IN (SELECT UCFTID FROM FileEntry WHERE MemberType=1 AND MemberID=@o AND FileDestination LIKE '/setup/elux/themes/%')" @{'@o' = $OuId})
    [void](X "DELETE FROM FileEntry WHERE MemberType=1 AND MemberID=@o AND FileDestination LIKE '/setup/elux/themes/%'" @{'@o' = $OuId})
    [void](X "DELETE FROM IniEntry WHERE MemberType=1 AND MemberID=@o AND IniKey='CurrentTheme'" @{'@o' = $OuId})
    foreach ($a in $arquivos) {
        $u = X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@o,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@o' = $OuId; '@n' = $a.Name; '@tm' = $now; '@fc' = [IO.File]::ReadAllBytes($a.FullName)}
        [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @o, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@o' = $OuId; '@n' = $a.Name; '@d' = "/setup/elux/themes/$NomeTema/$($a.Name)"; '@ds' = $Descricao; '@u' = $u})
    }
    [void](X "INSERT INTO IniEntry (IniEntryID, MemberType, MemberID, IniFile, IniSection, IniKey, IniValue) SELECT ISNULL(MAX(IniEntryID),0)+1, 1, @o, '/setup/terminal.ini', 'Layout', 'CurrentTheme', @t FROM IniEntry WITH (UPDLOCK, HOLDLOCK)" @{'@o' = $OuId; '@t' = $NomeTema})
    [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=@o" @{'@o' = $OuId})
    $tx.Commit(); "Tema $NomeTema publicado na OU $OuId ($($arquivos.Count) arquivos). Reinicie os eLux 2x."
} catch { $tx.Rollback(); throw } finally { $cn.Close() }
