param([string]$Pacote, [int]$OffsetGzip, [string]$Destino, [string]$Filtro = '.')
# Extrai o payload gzip+cpio (newc) de um pacote eLux .fpm, só leitura do pacote.
$b  = [IO.File]::ReadAllBytes($Pacote)
$len = $b.Length - $OffsetGzip
$ms = [IO.MemoryStream]::new($b, $OffsetGzip, $len)
$gz = [IO.Compression.GZipStream]::new($ms, [IO.Compression.CompressionMode]::Decompress)
$out = [IO.MemoryStream]::new()
$gz.CopyTo($out); $gz.Close()
$p = $out.ToArray()
"payload: $($p.Length) bytes, magic: " + [Text.Encoding]::ASCII.GetString($p, 0, 6)
$i = 0
while ($i -lt $p.Length - 110) {
    $h = [Text.Encoding]::ASCII.GetString($p, $i, 110)
    if (-not $h.StartsWith('07070')) { break }
    $mode = [Convert]::ToInt32($h.Substring(14, 8), 16)
    $fsz  = [Convert]::ToInt32($h.Substring(54, 8), 16)
    $nsz  = [Convert]::ToInt32($h.Substring(94, 8), 16)
    $name = [Text.Encoding]::ASCII.GetString($p, $i + 110, $nsz - 1)
    $d = $i + 110 + $nsz; $d += (4 - ($d % 4)) % 4
    if ($name -eq 'TRAILER!!!') { break }
    if ($fsz -gt 0 -and $name -match $Filtro) {
        "{0,9}  {1}" -f $fsz, $name
        if ($Destino -and (($mode -band 0xF000) -eq 0x8000)) {
            $t = Join-Path $Destino ($name.TrimStart('.', '/') -replace '/', '\')
            New-Item -ItemType Directory -Force (Split-Path $t) | Out-Null
            $buf = New-Object byte[] $fsz; [Array]::Copy($p, $d, $buf, 0, $fsz); [IO.File]::WriteAllBytes($t, $buf)
        }
    }
    $i = $d + $fsz; $i += (4 - ($i % 4)) % 4
}
