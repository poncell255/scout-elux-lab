# uberAgent em todas as OUs: configuracao em /setup/uberAgent/ (FileEntry do Scout) com DOIS receptores Splunk HEC
# e imagem com o EPM oficial "uberagent". Base: pacote de configuracao publicado pelo servidor A (ver uberagent-uniconos-dois-receptores.md).
# Tokens no credenciais.txt: "uberAgent HEC 10.30.0.99 / <token>" e "uberAgent HEC 10.5.1.4 / <token>".
param([string]$Base = 'C:\ScoutSetup\uberagent\base\x', [string]$Saida = 'C:\ScoutSetup\uberagent\elux',
      [object[]]$Receptores = @(@{Nome='PopulosUXM'; Servidor='10.30.0.99'}, @{Nome='PopulosAnalytics'; Servidor='10.5.1.4'}),
      [hashtable]$Imagens = @{ 0='populos-elux7-v18.idf'; 3='populos-elux7-v18.idf'; 4='populos-elux7-v18.idf'; 5='populos-elux7-v19.idf'; 6='populos-elux7-v21.idf'; 7='populos-elux7-v20.idf' },
      [switch]$SoMontar)
$c = Get-Content C:\ScoutSetup\credenciais.txt
function Token($ip) { $l = $c | Where-Object { $_ -match "^uberAgent HEC $([regex]::Escape($ip)) " }; if (-not $l) { throw "falta 'uberAgent HEC $ip / <token>' no credenciais.txt" }; ($l -split ' / ', 2)[1].Trim() }

# 1) monta a pasta de configuracao: todos os .conf da base, sem licenca (no UniconOS a licenca vem do sistema)
Remove-Item $Saida -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $Saida | Out-Null
$bloco = ($Receptores | ForEach-Object { "[Receiver]`nName = $($_.Nome)`nType = Splunk`nProtocol = HTTP`nServers = http://$($_.Servidor):3001`nRESTToken = $(Token $_.Servidor)`n" }) -join "`n"
foreach ($f in Get-ChildItem $Base -Filter *.conf -File) {
    $t = [IO.File]::ReadAllText($f.FullName)
    # troca cada secao [Receiver] real (coluna 1, ate a proxima linha de comentario ou secao) pelo bloco com os dois receptores; so a primeira recebe o bloco
    $rx = [regex]'(?m)^\[Receiver\][^\[#]*'
    $n = 0; $t = $rx.Replace($t, { param($m) $script:n++; if ($script:n -eq 1) { "$bloco`n" } else { '' } })
    [IO.File]::WriteAllText("$Saida\$($f.Name)", ($t -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}
"configuracao montada em ${Saida}: $((Get-ChildItem $Saida).Count) arquivos"
Select-String "$Saida\uberAgent.conf" -Pattern '^\[Receiver\]|^Name = Populos|^Servers' | ForEach-Object { "  $($_.Line)" }
if ($SoMontar) { return }

# 2) Scout: FileEntries em todas as OUs + imagens
$sa = (($c | Where-Object { $_ -match '^SQL sa' }) -split ' / ', 2)[1].Trim()
$m = [System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x = $m.CreateCommand(); $x.CommandTimeout = 600
$x.CommandText = "BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-uberagent.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close(); "backup ok"
$cn = [System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open(); $tx = $cn.BeginTransaction(); $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function X($sql, $p = @{}) { $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandTimeout = 600; $z.CommandText = $sql; foreach ($k in $p.Keys) { $v = $p[$k]; if ($v -is [byte[]]) { $q = $z.Parameters.Add($k, [Data.SqlDbType]::VarBinary, -1); $q.Value = $v } else { [void]$z.Parameters.AddWithValue($k, $v) } }; $z.ExecuteScalar() }
try {
    $z = $cn.CreateCommand(); $z.Transaction = $tx; $z.CommandText = "SELECT GroupID FROM Groups ORDER BY GroupID"; $r = $z.ExecuteReader(); $ous = @(); while ($r.Read()) { $ous += $r.GetInt32(0) }; $r.Close()
    $arqs = Get-ChildItem $Saida -File
    foreach ($ou in $ous) {
        $novos = 0; $atual = 0
        foreach ($a in $arqs) {
            $dest = "/setup/uberAgent/$($a.Name)"; $bytes = [IO.File]::ReadAllBytes($a.FullName)
            $u = X "SELECT TOP 1 UCFTID FROM FileEntry WHERE MemberType=1 AND MemberID=@ou AND FileDestination=@d" @{'@ou' = $ou; '@d' = $dest }
            if ($u) { [void](X "UPDATE UCFT SET FileContent=@fc, TimeModified=@tm WHERE UCFTID=@u" @{'@fc' = $bytes; '@tm' = $now; '@u' = $u }); $atual++ }
            else {
                $u = X "INSERT INTO UCFT (MemberType, MemberID, FileType, FileName, FileMode, FTResult, TimeModified, FileContent) VALUES (1,@ou,0,@n,0,0,@tm,@fc); SELECT CAST(SCOPE_IDENTITY() AS int)" @{'@ou' = $ou; '@n' = $a.Name; '@tm' = $now; '@fc' = $bytes }
                [void](X "INSERT INTO FileEntry (FileEntryID, MemberType, MemberID, FileSource, FileDestination, Description, UCFTID) SELECT ISNULL(MAX(FileEntryID),0)+1, 1, @ou, @n, @d, 'uberAgent: configuracao (2 receptores)', @u FROM FileEntry WITH (UPDLOCK, HOLDLOCK)" @{'@ou' = $ou; '@n' = $a.Name; '@d' = $dest; '@u' = $u }); $novos++ }
        }
        "  OU ${ou}: $novos novos, $atual atualizados" }
    foreach ($s in $Imagens.Keys) { [void](X "UPDATE Setup SET ImageFile=@i WHERE SetupID=@s" @{'@i' = $Imagens[$s]; '@s' = [int]$s }); "  setup ${s}: $($Imagens[$s])" }
    [void](X "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1")
    $tx.Commit(); "COMMIT OK"
} catch { $tx.Rollback(); "ROLLBACK: $($_.Exception.Message)" }
$cn.Close()
