param([string]$Versao = '1.0.0')
# Importa o populos_porto_local no ELIAS e atualiza o cache do catálogo (C:\ScoutSetup\diag\elias-epms.json / elias-fpms.json).
$ErrorActionPreference = 'Stop'
$src = 'C:\Users\Administrator\Downloads\porto-local'
$api = 'http://localhost/ELIAS/api/UC_RP6_X64/v1.0'
$line = [IO.File]::ReadAllLines('C:\ScoutSetup\credenciais.txt') | Where-Object { $_ -match '^ELIAS 18' } | Select-Object -First 1
$pwd = ($line -split ' / ', 2)[1].Trim()
$body = @{ user = 'admin'; password = $pwd; domain = '' } | ConvertTo-Json -Compress
$login = Invoke-WebRequest -UseBasicParsing -Uri "$api/authenticate/" -Method Post -ContentType 'application/json' -Body $body -SessionVariable session
if (-not (($login.Content | ConvertFrom-Json).success)) { throw 'Autenticacao ELIAS falhou' }
function GetJson($path) { $r = Invoke-WebRequest -UseBasicParsing -Uri "$api/$path" -WebSession $session -TimeoutSec 45; $r.Content | ConvertFrom-Json }
$nome = "populos-porto-local-$Versao.zip"
$archive = "$src\saida\$nome"
if (-not (Test-Path -LiteralPath $archive)) { Compress-Archive -Path "$src\saida\populos_porto_local*-$Versao-*.epm", "$src\saida\populos_porto_local_app-$Versao-*.fpm" -DestinationPath $archive }
$boundary = 'PortoUpload' + [guid]::NewGuid().ToString('N')
$prefix = [Text.Encoding]::ASCII.GetBytes("--$boundary`r`nContent-Disposition: form-data; name=`"file`"; filename=`"$nome`"`r`nContent-Type: application/zip`r`n`r`n")
$suffix = [Text.Encoding]::ASCII.GetBytes("`r`n--$boundary--`r`n")
$m = [IO.MemoryStream]::new(); $m.Write($prefix, 0, $prefix.Length); $zip = [IO.File]::ReadAllBytes($archive); $m.Write($zip, 0, $zip.Length); $m.Write($suffix, 0, $suffix.Length)
$resp = Invoke-WebRequest -UseBasicParsing -Uri "$api/import/$nome" -WebSession $session -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $m.ToArray() -TimeoutSec 120
$m.Dispose()
$uuid = $resp.Headers['UUID']; if (-not $uuid) { throw 'ELIAS nao retornou UUID de importacao' }
$ok = $false
for ($i = 0; $i -lt 40; $i++) { if (((GetJson "checkimport/$uuid") | ConvertTo-Json -Depth 8) -match 'finished') { $ok = $true; break }; Start-Sleep 2 }
if (-not $ok) { throw 'Importacao ainda nao concluida; nao repetir' }
"Importado no ELIAS: $nome"
foreach ($n in 'epms', 'fpms') { $raw = (GetJson $n) | ConvertTo-Json -Depth 16; [IO.File]::WriteAllText("C:\ScoutSetup\diag\elias-$n.json", $raw, [Text.UTF8Encoding]::new($false)) }
$e = @((Get-Content C:\ScoutSetup\diag\elias-epms.json -Raw | ConvertFrom-Json) | ForEach-Object { $_ }) | Where-Object name -eq 'populos_porto_local'
"Catalogo: populos_porto_local $($e.version) ($($e.id))"
