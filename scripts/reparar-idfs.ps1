param([string[]]$Versoes = @())
# Depois de importar pacote no ELIAS, as imagens já existentes passam a dar 404 em /ELIAS/UC_RP6_X64/<imagem>.idf
# ("Legacy IDF failed; IDF not found or invalid"). Este script remonta cada imagem em uso (Setup.ImageFile) com a mesma
# seleção e grava no mesmo registro (PUT idf/<_id>). Não grava se a seleção de EPM/FPM mudar.
# Uso: reparar-idfs.ps1            (todas as imagens dos setups)
#      reparar-idfs.ps1 -Versoes v31,v35
$ErrorActionPreference = 'Stop'
$api = 'http://localhost/ELIAS/api/UC_RP6_X64/v1.0'; $jar = 'C:\ScoutSetup\elias_cj.txt'; $d = 'C:\ScoutSetup\diag'
$l = [IO.File]::ReadAllLines('C:\ScoutSetup\credenciais.txt') | Where-Object { $_ -like 'ELIAS 18 (web)*' } | Select-Object -First 1
$tmp = [IO.Path]::GetTempFileName(); [IO.File]::WriteAllText($tmp, (@{ user = 'admin'; domain = ''; password = ($l -split ' / ', 2)[1].Trim() } | ConvertTo-Json -Compress))
[void](curl.exe -s -m 60 -c $jar -H 'Content-Type: application/json' -X POST "$api/authenticate/" --data-binary "@$tmp"); Remove-Item $tmp
if (-not $Versoes) {
    $cn = [Data.SqlClient.SqlConnection]::new('Server=localhost,1433;Database=ScoutEnterprise;Integrated Security=True;TrustServerCertificate=True'); $cn.Open()
    $c = $cn.CreateCommand(); $c.CommandText = "SELECT DISTINCT ImageFile FROM Setup WHERE ImageFile LIKE 'populos-elux7-v%.idf'"; $r = $c.ExecuteReader()
    $Versoes = @(while ($r.Read()) { $r[0] -replace '^populos-elux7-(v\d+)\.idf$', '$1' }); $cn.Close()
}
function Sel($j) { @($j.epms | ForEach-Object { $_.id }) + @($j.epms | ForEach-Object { $_.fpms } | Where-Object selected | ForEach-Object { $_.id }) }
function Baixa($v) { try { (Invoke-WebRequest "http://localhost/ELIAS/UC_RP6_X64/populos-elux7-$v.idf" -UseBasicParsing -TimeoutSec 20).StatusCode } catch { $_.Exception.Response.StatusCode.value__ } }
$carimbo = [DateTime]::Now.ToString('yyyyMMdd-HHmmss')
foreach ($v in $Versoes) {
    if ((Baixa $v) -eq 200) { "$v : já entregue (200)"; continue }
    if (-not (Test-Path "$d\idf-populos-$v.json")) { "$v : sem $d\idf-populos-$v.json; pulado"; continue }
    $bak = "C:\ScoutSetup\backup\idf-populos-$v-antes-$carimbo.json"; Copy-Item "$d\idf-populos-$v.json" $bak -Force
    $a = Get-Content $bak -Raw | ConvertFrom-Json
    & C:\ScoutSetup\scripts\imagem-derivada.ps1 -De $v -Nome "populos-elux7-$v" *> $null
    $b = Get-Content "$d\idf-populos-$v.json" -Raw | ConvertFrom-Json
    $dif = @(Compare-Object (Sel $a) (Sel $b))
    if ($dif.Count) { Copy-Item $bak "$d\idf-populos-$v.json" -Force; "$v : seleção mudaria ($($dif.Count) itens: $(($dif | ForEach-Object { "$($_.SideIndicator)$($_.InputObject)" }) -join ', ')); NÃO gravado"; continue }
    $cur = @((curl.exe -s -m 60 -b $jar "$api/idfs" | ConvertFrom-Json) | ForEach-Object { $_ }) | Where-Object id -eq "populos-elux7-$v.idf"
    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z')
    foreach ($p in @(@('id', "populos-elux7-$v.idf"), @('_id', $cur._id), @('created', $cur.created), @('modified', $now))) { $b | Add-Member -NotePropertyName $p[0] -NotePropertyValue $p[1] -Force }
    $f = "$d\idf-put-$v.json"; [IO.File]::WriteAllText($f, '{"idf":' + ($b | ConvertTo-Json -Depth 8) + ',"silent":true,"overwrite":true}')
    $x = (curl.exe -s -m 300 -b $jar -H 'Content-Type: application/json' -X PUT "$api/idf/$($cur._id)" --data-binary "@$f") | ConvertFrom-Json
    "{0} : regravada; conflito={1} faltando={2} {3:N0} MB; download={4}" -f $v, $x.conflicted, $x.hasMissing, ($x.imageSize / 1MB), (Baixa $v)
}
