param([Parameter(Mandatory)][string]$De, [Parameter(Mandatory)][string]$Nome, [string[]]$MaisEpms = @(), [string[]]$MaisFpms = @(), [string[]]$MenosEpms = @(), [switch]$Publicar)
# Cria uma imagem nova a partir de outra ja montada (diag\idf-populos-<De>.json): mesmos EPMs/FPMs escolhidos + extras.
# Ex.: imagem-derivada.ps1 -De v4 -Nome populos-elux7-v12 -MaisEpms google_chrome,populos_glpi -Publicar
$d = 'C:\ScoutSetup\diag'
$old = Get-Content "$d\idf-populos-$De.json" -Raw | ConvertFrom-Json
$base = @((Get-Content "$d\elias-idfs.json" -Raw | ConvertFrom-Json) | ForEach-Object { $_ }) | Where-Object { $_.name -like 'migration-system*' } | Select-Object -First 1
$baseEpms = @($base.epms | ForEach-Object { $_.id })
$epms = @($old.epms | Where-Object { $_.id -notin $baseEpms } | ForEach-Object { $_.name } | Where-Object { $_ -notin $MenosEpms }) + $MaisEpms | Select-Object -Unique
$fpms = @($old.epms | Where-Object { $_.name -notin $MenosEpms } | ForEach-Object { $_.fpms } | Where-Object { $_.selected -and -not $_.isMandatory -and -not $_.isPreselected } | ForEach-Object { $_.name }) + $MaisFpms | Select-Object -Unique
"EPMs extras: $($epms -join ', ')"
"FPMs opcionais: $($fpms -join ', ')"
& C:\ScoutSetup\scripts\montar-idf.ps1 -Nome $Nome -AddEpms $epms -AddFpms $fpms -Saida "$d\idf-populos-$($Nome -replace '^populos-elux7-','').json" | Where-Object { $_ -match '^(EPMs|FPMs)|NAO RESOLV|^\s' }
if (-not $Publicar) { return }
$jar = 'C:\ScoutSetup\elias_cj.txt'; $api = 'http://localhost/ELIAS/api/UC_RP6_X64/v1.0'
$j = Get-Content "$d\idf-populos-$($Nome -replace '^populos-elux7-','').json" -Raw | ConvertFrom-Json
$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z')
foreach ($p in @(@('id', "$Nome.idf"), @('created', $now), @('modified', $now))) { $j | Add-Member -NotePropertyName $p[0] -NotePropertyValue $p[1] -Force }
$post = "$d\idf-post-$Nome.json"; [IO.File]::WriteAllText($post, '{"idf":' + ($j | ConvertTo-Json -Depth 8) + '}')
$s = (curl.exe -s -m 300 -b $jar -H 'Content-Type: application/json' -X POST "$api/idfs" --data-binary "@$post") | ConvertFrom-Json
"ELIAS: {0} conflito={1} faltando={2} tamanho={3:N0} MB" -f $s.id, $s.conflicted, $s.hasMissing, ($s.imageSize / 1MB)
