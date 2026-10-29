$ErrorActionPreference = 'Stop'
# Atualiza a OU Porto existente (GroupID 11, setup 7): imagem v36 (v28 + python3 + populos_porto_local), tema porto-v2
# (papel de parede no modelo BTG), apps locais Porto com ícone global porto.png e arquivos do serviço local. Recusa rodar duas vezes.
$Ou = 11; $Setup = 7; $Imagem = 'populos-elux7-v36.idf'; $Tema = 'porto-v2'
$src = 'C:\Users\Administrator\Downloads\porto-local'; $pastaTema = 'C:\eLuxContainer\theme\porto'
$cred = 'C:\ScoutSetup\credenciais.txt'
$line = [IO.File]::ReadAllLines($cred) | Where-Object { $_.StartsWith('Porto Local admin / ') } | Select-Object -First 1
if ($line) { $pwd = ($line -split ' / ', 2)[1].Trim() } else {
    $pwd = -join ((1..20) | ForEach-Object { 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'[(Get-Random -Maximum 55)] })
    [IO.File]::AppendAllText($cred, "`r`nPorto Local admin / $pwd`r`n", [Text.UTF8Encoding]::new($false))
}
$salt = New-Object byte[] 16; $rng = [Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($salt); $rng.Dispose()
$derive = [Security.Cryptography.Rfc2898DeriveBytes]::new($pwd, $salt, 210000, [Security.Cryptography.HashAlgorithmName]::SHA256)
$hash = $derive.GetBytes(32); $derive.Dispose()
$auth = @{ salt = ([BitConverter]::ToString($salt)).Replace('-', '').ToLowerInvariant(); iterations = 210000; digest = ([BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant() } | ConvertTo-Json -Compress
$cn = [Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True'); $cn.Open()
$backup = 'C:\ScoutSetup\backup\ScoutEnterprise-pre-porto-local-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.bak'
$z = $cn.CreateCommand(); $z.CommandTimeout = 600; $z.CommandText = 'BACKUP DATABASE ScoutEnterprise TO DISK=@p WITH COPY_ONLY,CHECKSUM'; [void]$z.Parameters.AddWithValue('@p', $backup); [void]$z.ExecuteNonQuery(); $z.CommandText = 'RESTORE VERIFYONLY FROM DISK=@p WITH CHECKSUM'; [void]$z.ExecuteNonQuery(); "Backup verificado: $backup"
$tx = $cn.BeginTransaction(); $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql, $p = @{}) { $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandTimeout = 600; $z.CommandText = $sql; foreach ($k in $p.Keys) { $v = $p[$k]; if ($v -is [byte[]]) { $q = $z.Parameters.Add($k, [Data.SqlDbType]::VarBinary, -1); $q.Value = $v } else { [void]$z.Parameters.AddWithValue($k, $v) } }; $z.ExecuteScalar() }
function Cols($t, $excl) { $l = ($excl | ForEach-Object { "'$_'" }) -join ','; X "SELECT STRING_AGG(QUOTENAME(name),',') FROM sys.columns WHERE object_id=OBJECT_ID('$t') AND is_identity=0 AND is_computed=0 AND name NOT IN ($l)" }
function Arquivo($nome, $destino, $desc, [byte[]]$bytes) {
    $u = X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou' = $Ou; '@n' = $nome; '@tm' = $now; '@fc' = $bytes }
    [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, @ds, @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou' = $Ou; '@n' = $nome; '@d' = $destino; '@ds' = $desc; '@u' = $u }) }
try {
    if ((X "SELECT COUNT(*) FROM Groups WHERE GroupID=@ou AND Name='Porto' AND SetupID=@s" @{'@ou' = $Ou; '@s' = $Setup }) -ne 1) { throw 'OU Porto/setup 7 nao conferem' }
    if ((X "SELECT COUNT(*) FROM Groups WHERE SetupID=@s" @{'@s' = $Setup }) -ne 1) { throw 'Setup 7 usado por outra OU' }
    if ((X "SELECT COUNT(*) FROM Local l JOIN Application a ON a.ApplicationID=l.ApplicationID WHERE a.GroupID=@ou AND l.Parameter LIKE '/usr/bin/porto-local-%'" @{'@ou' = $Ou }) -ne 0) { throw 'Apps Porto Local ja existem; preservados' }
    [void](X 'UPDATE Setup SET ImageFile=@img WHERE SetupID=@s' @{'@img' = $Imagem; '@s' = $Setup })
    # Ícone global (logo Porto sem fundo), entregue em /setup/icons/<w>x<h>/porto.png
    $ico = X "SELECT TOP 1 UCFTID FROM UCFT WHERE MemberType=-1 AND MemberID=-1 AND FileType=1 AND FileName='porto.png'"
    $icoBytes = [IO.File]::ReadAllBytes("$src\saida\imagens\porto.png")
    if ($ico) { [void](X 'UPDATE UCFT SET FileContent=@fc, TimeModified=@tm WHERE UCFTID=@u' @{'@fc' = $icoBytes; '@tm' = $now; '@u' = $ico }) }
    else { $ico = X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (-1,-1,1,'porto.png',-1,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@tm' = $now; '@fc' = $icoBytes } }
    # Apps locais (cópia do app local Google Chrome da própria OU)
    $modelo = X "SELECT a.ApplicationID FROM Application a JOIN Local l ON l.ApplicationID=a.ApplicationID WHERE a.GroupID=@ou AND a.Name='Google Chrome'" @{'@ou' = $Ou }
    $ka = Cols 'Application' @('ApplicationID', 'GroupID'); $ids = @()
    foreach ($app in @(@{n = 'Meu Seguro Porto'; p = '/usr/bin/porto-local-cliente' }, @{n = 'Cadastro de Segurados Porto'; p = '/usr/bin/porto-local-admin' })) {
        $id = X 'SELECT MAX(ApplicationID)+1 FROM Application WITH (UPDLOCK,HOLDLOCK)'
        [void](X "INSERT INTO Application (ApplicationID,GroupID,$ka) SELECT @id,@ou,$ka FROM Application WHERE ApplicationID=@old" @{'@id' = $id; '@ou' = $Ou; '@old' = $modelo })
        $kl = Cols 'Local' @('ApplicationID'); [void](X "INSERT INTO Local (ApplicationID,$kl) SELECT @id,$kl FROM Local WHERE ApplicationID=@old" @{'@id' = $id; '@old' = $modelo })
        [void](X "UPDATE Local SET Parameter=@p WHERE ApplicationID=@id; UPDATE Application SET Name=@n, DisplayName=@n, IconName='porto', AutoStart=0, AppOnDesktop=1 WHERE ApplicationID=@id" @{'@id' = $id; '@p' = $app.p; '@n' = $app.n })
        $ids += $id }
    # Tema porto-v2 no lugar do porto-v1 (nome novo porque o eLux guarda o tema em cache)
    $velhos = X "SELECT STRING_AGG(CAST(UCFTID AS varchar(12)),',') FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND FileDestination LIKE '/setup/elux/themes/%'" @{'@ou' = $Ou }
    [void](X "DELETE FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND FileDestination LIKE '/setup/elux/themes/%'" @{'@ou' = $Ou })
    if ($velhos) { [void](X "DELETE FROM UCFT WHERE UCFTID IN ($velhos) AND NOT EXISTS (SELECT 1 FROM FileEntry f WHERE f.UCFTID=UCFT.UCFTID)") }
    foreach ($f in Get-ChildItem $pastaTema -File) { Arquivo $f.Name "/setup/elux/themes/$Tema/$($f.Name)" 'Tema Porto' ([IO.File]::ReadAllBytes($f.FullName)) }
    [void](X "UPDATE IniEntry SET IniValue=@t WHERE MemberType=1 AND MemberID=@ou AND IniFile='/setup/terminal.ini' AND IniSection='Layout' AND IniKey='CurrentTheme'" @{'@ou' = $Ou; '@t' = $Tema })
    # Configuração do serviço local Porto
    $utf = [Text.UTF8Encoding]::new($false)
    Arquivo 'admin-auth.json' '/setup/porto-local/admin-auth.json' 'Porto Local: verificador PBKDF2 administrativo, sem senha em texto' ($utf.GetBytes($auth))
    Arquivo 'logo.png' '/setup/porto-local/logo.png' 'Porto Local: logo da tela da digital' ([IO.File]::ReadAllBytes("$src\app\web\static\logo.png"))
    Arquivo 'cor-fundo' '/setup/porto-local/cor-fundo' 'Porto Local: cor da tela da digital' ($utf.GetBytes("#F3F7FF`n"))
    [void](X 'UPDATE Device SET SetupChanged=1,ApplicationsChanged=1 WHERE GroupID=@ou' @{'@ou' = $Ou })
    $tx.Commit(); "COMMIT OK: OU Porto=$Ou setup=$Setup imagem=$Imagem tema=$Tema apps=$($ids -join ',') icone UCFT=$ico"
} catch { if ($tx.Connection) { $tx.Rollback() }; throw } finally { $cn.Close() }
