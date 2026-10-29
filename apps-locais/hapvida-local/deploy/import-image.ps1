$ErrorActionPreference='Stop'
$src='C:\Users\Administrator\Downloads\hapvida-local'
$api='http://localhost/ELIAS/api/UC_RP6_X64/v1.0'
$line=[IO.File]::ReadAllLines('C:\ScoutSetup\credenciais.txt') | Where-Object {$_ -match '^ELIAS 18'} | Select-Object -First 1
$pwd=($line -split ' / ',2)[1].Trim()
$body=@{user='admin';password=$pwd;domain=''} | ConvertTo-Json -Compress
$login=Invoke-WebRequest -UseBasicParsing -Uri "$api/authenticate/" -Method Post -ContentType 'application/json' -Body $body -SessionVariable session
if(-not(($login.Content | ConvertFrom-Json).success)){throw 'Autenticacao ELIAS falhou'}
function GetJson($path){$r=Invoke-WebRequest -UseBasicParsing -Uri "$api/$path" -WebSession $session -TimeoutSec 45; $j=$r.Content | ConvertFrom-Json;if($j.message -eq 'Failed to authenticate token.'){throw 'Sessao ELIAS expirou'};return $j}
$archive="$src\saida\populos-hapvida-local-1.0.0.zip"
if(-not(Test-Path -LiteralPath $archive)){Compress-Archive -Path "$src\saida\*.epm","$src\saida\*.fpm" -DestinationPath $archive}
$boundary='HapvidaUpload'+[guid]::NewGuid().ToString('N')
$prefix=[Text.Encoding]::ASCII.GetBytes("--$boundary`r`nContent-Disposition: form-data; name=`"file`"; filename=`"populos-hapvida-local-1.0.0.zip`"`r`nContent-Type: application/zip`r`n`r`n")
$suffix=[Text.Encoding]::ASCII.GetBytes("`r`n--$boundary--`r`n")
$memory=[IO.MemoryStream]::new();$memory.Write($prefix,0,$prefix.Length);$zipBytes=[IO.File]::ReadAllBytes($archive);$memory.Write($zipBytes,0,$zipBytes.Length);$memory.Write($suffix,0,$suffix.Length)
$response=Invoke-WebRequest -UseBasicParsing -Uri "$api/import/populos-hapvida-local-1.0.0.zip" -WebSession $session -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $memory.ToArray() -TimeoutSec 120
$memory.Dispose()
$uuid=$response.Headers['UUID']
if(-not $uuid){throw 'ELIAS nao retornou UUID de importacao'}
$finished=$false
for($i=0;$i -lt 40;$i++){
    $check=(GetJson "checkimport/$uuid") | ConvertTo-Json -Depth 8

    $status=$check | ConvertFrom-Json
    if(($check -join '') -match 'finished'){$finished=$true;break}
    Start-Sleep -Seconds 2
}
if(-not $finished){throw 'Importacao ainda nao concluida; nao repetir importacao'}
'Importacao do pacote concluida no ELIAS.'
$cache='C:\ScoutSetup\diag'
foreach($name in 'epms','fpms'){
    $raw=(GetJson $name) | ConvertTo-Json -Depth 16
    $parsed=$raw | ConvertFrom-Json
    if(-not $parsed){throw 'Catalogo ELIAS vazio'}
    [IO.File]::WriteAllText("$cache\elias-$name.json",($raw -join "`n"),[Text.UTF8Encoding]::new($false))
}
& 'C:\ScoutSetup\scripts\imagem-derivada.ps1' -De v29 -Nome populos-elux7-v30 -MaisEpms populos_hapvida_local,python3 -MaisFpms python3_flask
$old=Get-Content -LiteralPath "$cache\idf-populos-v29.json" -Raw | ConvertFrom-Json
$new=Get-Content -LiteralPath "$cache\idf-populos-v30.json" -Raw | ConvertFrom-Json
foreach($epm in $old.epms){if(-not($new.epms | Where-Object id -eq $epm.id)){throw "Versao de pacote da base mudou: $($epm.name)"}}
if($new.conflicted -or $new.hasMissing -or $new.imageSize -gt 3700MB){throw 'Imagem com conflito, falta ou tamanho excessivo'}
if(-not($new.epms | Where-Object name -eq 'populos_hapvida_local')){throw 'Pacote HAPVIDA ausente da imagem'}
$known=GetJson 'idfs'
if($known | Where-Object {$_.name -eq 'populos-elux7-v30'}){throw 'Imagem v30 ja existe; preservada para inspecao'}
$now=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.000Z')
foreach($p in @(@('id','populos-elux7-v30.idf'),@('created',$now),@('modified',$now))){$new | Add-Member -NotePropertyName $p[0] -NotePropertyValue $p[1] -Force}
$post="$src\saida\idf-post-v30.json"
[IO.File]::WriteAllText($post,('{"idf":'+($new | ConvertTo-Json -Depth 10)+'}'),[Text.UTF8Encoding]::new($false))
$saved=(Invoke-WebRequest -UseBasicParsing -Uri "$api/idfs" -WebSession $session -ContentType 'application/json' -Method Post -Body ([IO.File]::ReadAllBytes($post)) -TimeoutSec 180).Content | ConvertFrom-Json
if($saved.conflicted -or $saved.hasMissing -or -not $saved.id){throw 'ELIAS recusou ou nao confirmou a imagem'}
"Imagem publicada no ELIAS: $($saved.id), conflito=$($saved.conflicted), faltando=$($saved.hasMissing), tamanho=$([math]::Round($saved.imageSize/1MB,2)) MB. Sem comando de instalacao nos eLux."
