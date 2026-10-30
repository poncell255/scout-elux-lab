$ErrorActionPreference = 'Stop'
# Grava C:\ScoutSetup\diag\imagens-uso.json: que OUs (e quantos aparelhos) usam cada imagem populos-elux7-vX.
# O Populos UniconOS SDK (conversor, no WSL) lê o arquivo para nomear as imagens. Roda pela tarefa "Imagens em uso (SDK)".
$cn = [Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True'); $cn.Open()
$c = $cn.CreateCommand()
$c.CommandText = "SELECT s.ImageFile, g.Name, (SELECT COUNT(*) FROM Device d WHERE d.GroupID=g.GroupID) FROM Groups g JOIN Setup s ON s.SetupID=g.SetupID WHERE s.ImageFile LIKE 'populos-elux7-v%.idf' AND g.Name <> 'Lost & Found' ORDER BY g.Name"
$r = $c.ExecuteReader(); $uso = [ordered]@{}
while ($r.Read()) {
    $v = $r[0] -replace '^populos-elux7-(v\d+)\.idf$', '$1'
    if (-not $uso.Contains($v)) { $uso[$v] = @() }
    $uso[$v] += [ordered]@{ ou = $r[1]; aparelhos = [int]$r[2] }
}
$cn.Close()
$json = [ordered]@{ gerado = (Get-Date).ToString('yyyy-MM-dd HH:mm'); imagens = $uso } | ConvertTo-Json -Depth 5
$tmp = 'C:\ScoutSetup\diag\imagens-uso.json.tmp'
[IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding $false)); Move-Item $tmp 'C:\ScoutSetup\diag\imagens-uso.json' -Force
