param([string]$Nome = 'populos-elux7', [string[]]$AddEpms = @('ica','citrix_extensions','citrix_hdxrtme','vmwareviewclient','firefox'), [string[]]$AddFpms = @('mirror_server'), [string]$Saida = 'C:\ScoutSetup\diag\idf-populos.json')
# Monta uma IDF a partir da imagem oficial migration-system + pacotes extras, resolvendo dependencias.
$epms = @((Get-Content C:\ScoutSetup\diag\elias-epms.json -Raw | ConvertFrom-Json) | ForEach-Object { $_ })
$fpms = @((Get-Content C:\ScoutSetup\diag\elias-fpms.json -Raw | ConvertFrom-Json) | ForEach-Object { $_ })
$base = @((Get-Content C:\ScoutSetup\diag\elias-idfs.json -Raw | ConvertFrom-Json) | ForEach-Object { $_ }) | Where-Object { $_.name -like 'migration-system*' } | Select-Object -First 1

$epmById = @{}; foreach ($e in $epms) { $epmById[$e.id] = $e }
$fpmById = @{}; foreach ($f in $fpms) { $fpmById[$f.id] = $f }
function EpmOfFpm($fid) { foreach ($e in $epms) { if (@($e.fpms) -contains $fid) { return $e.id } }; $null }

# capacidade -> provedores
$prov = @{}
function AddProv($cap, $obj) { if (-not $prov.ContainsKey($cap)) { $prov[$cap] = New-Object System.Collections.ArrayList }; [void]$prov[$cap].Add($obj) }
foreach ($e in $epms) { AddProv $e.name @{kind='epm'; id=$e.id}; foreach ($p in @($e.provideNames)) { if ($p) { AddProv $p @{kind='epm'; id=$e.id} } } }
foreach ($f in $fpms) { AddProv $f.name @{kind='fpm'; id=$f.id}; foreach ($p in @($f.provideNames)) { if ($p) { AddProv $p @{kind='fpm'; id=$f.id} } }; foreach ($fn in @($f.filenames)) { if ($fn -in '/bin/sh','/bin/bash') { AddProv $fn @{kind='fpm'; id=$f.id} } } }

$selEpm = [ordered]@{}; $selFpm = @{}; $motivo = @{}
foreach ($e in @($base.epms)) { $selEpm[$e.id] = $true; foreach ($f in @($e.fpms)) { if ($f.selected) { $selFpm[$f.id] = $true } } }
function SelectEpm($eid, $why) {
    if (-not $selEpm.Contains($eid)) { $selEpm[$eid] = $true; $motivo[$eid] = $why
        foreach ($fid in @($epmById[$eid].fpms)) { $f = $fpmById[$fid]; if ($f -and ($f.isMandatory -or $f.isPreselected)) { $selFpm[$fid] = $true } } }
}
foreach ($n in $AddEpms) { $e = $epms | Where-Object name -eq $n | Select-Object -First 1; if ($e) { SelectEpm $e.id 'pedido' } else { Write-Warning "EPM nao encontrado: $n" } }
foreach ($n in $AddFpms) { $f = $fpms | Where-Object name -eq $n | Select-Object -First 1; if ($f) { $selFpm[$f.id] = $true; $motivo[$f.id] = 'pedido'; $eid = EpmOfFpm $f.id; if ($eid) { SelectEpm $eid "contem $n" } } else { Write-Warning "FPM nao encontrado: $n" } }

$naoResolvido = @{}
for ($it = 0; $it -lt 30; $it++) {
    $mudou = $false
    $caps = @{}
    foreach ($eid in $selEpm.Keys) { $e = $epmById[$eid]; $caps[$e.name] = 1; foreach ($p in @($e.provideNames)) { if ($p) { $caps[$p] = 1 } } }
    foreach ($fid in @($selFpm.Keys)) { $f = $fpmById[$fid]; if (-not $f) { continue }; $caps[$f.name] = 1; foreach ($p in @($f.provideNames)) { if ($p) { $caps[$p] = 1 } }; foreach ($fn in @($f.filenames)) { if ($fn -in '/bin/sh','/bin/bash') { $caps[$fn] = 1 } } }
    $reqs = @()
    foreach ($eid in $selEpm.Keys) { foreach ($r in @($epmById[$eid].requireNames)) { if ($r) { $reqs += ,@($r, $eid) } } }
    foreach ($fid in @($selFpm.Keys)) { $f = $fpmById[$fid]; if ($f) { foreach ($r in @($f.requireNames)) { if ($r) { $reqs += ,@($r, $fid) } } } }
    foreach ($rq in $reqs) {
        $cap = $rq[0]; if ($caps.ContainsKey($cap) -or $cap -like 'rpmlib(*') { continue }
        $cands = $prov[$cap]
        if (-not $cands) { $naoResolvido[$cap] = $rq[1]; continue }
        $c = ($cands | Where-Object { $_.kind -eq 'fpm' -and $fpmById[$_.id].isMandatory } | Select-Object -First 1); if (-not $c) { $c = $cands | Select-Object -First 1 }
        if ($c.kind -eq 'epm') { SelectEpm $c.id "requer $cap ($($rq[1]))" }
        else { $selFpm[$c.id] = $true; $motivo[$c.id] = "requer $cap ($($rq[1]))"; $eid = EpmOfFpm $c.id; if ($eid) { SelectEpm $eid "contem $($c.id)" } }
        $caps[$cap] = 1; $mudou = $true
    }
    if (-not $mudou) { break }
}

# monta o objeto IDF no formato do ELIAS
$epmList = @(); $pkg = New-Object System.Collections.ArrayList; $size = 0
foreach ($eid in $selEpm.Keys) {
    $e = $epmById[$eid]; [void]$pkg.Add($eid)
    $baseEpm = @($base.epms) | Where-Object id -eq $eid | Select-Object -First 1
    $fl = @()
    foreach ($fid in @($e.fpms)) {
        $f = $fpmById[$fid]; if (-not $f) { continue }
        $sel = [bool]$selFpm[$fid]; if ($sel) { [void]$pkg.Add($fid); $size += [long]$f.packageSize }
        $bf = if ($baseEpm) { @($baseEpm.fpms) | Where-Object id -eq $fid | Select-Object -First 1 } else { $null }
        $fl += [ordered]@{ id=$fid; available=$true; selected=$sel; summary=$f.summary; name=$f.name; version=$f.version; release=@($f.release); size=[long]$f.packageSize
                           isUserSelected=($(if ($bf) { [bool]$bf.isUserSelected } else { $sel -and -not $f.isMandatory })); isMandatory=[bool]$f.isMandatory; isPreselected=[bool]$f.isPreselected }
    }
    $epmList += [ordered]@{ id=$eid; copyright=$e.copyright; version=$e.version; name=$e.name; available=$true; isUserSelected=$true; summary=$e.summary; release=@($e.release); fpms=$fl }
}
$idf = [ordered]@{ name=$Nome; version=$base.version; author='POPULOS'; container=$base.container; copyright=$base.copyright; description="$Nome.idf"; isTemplate=$false; selfContained=$base.selfContained; legacyIDF=$false; conflicted=$false; hasMissing=$false; conflicts=@(); imageSize=$size; packageList=@($pkg); epms=$epmList }
[IO.File]::WriteAllText($Saida, ($idf | ConvertTo-Json -Depth 8))
"EPMs na imagem: $($selEpm.Count) (base Unicon: $(@($base.epms).Count))"
"FPMs selecionados: $(@($selFpm.Keys).Count) | tamanho: {0:N0} MB" -f ($size/1MB)
"--- adicionados e motivo:"; foreach ($k in $motivo.Keys) { "  $k <- $($motivo[$k])" }
if ($naoResolvido.Count) { "--- NAO RESOLVIDOS:"; foreach ($k in $naoResolvido.Keys) { "  $k (exigido por $($naoResolvido[$k]))" } } else { "--- todas as dependencias resolvidas" }
