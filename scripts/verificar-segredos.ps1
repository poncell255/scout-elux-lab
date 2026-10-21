# Procura senhas/tokens/chaves antes do git push. Saída vazia = ok.
param([string]$Raiz = (Split-Path $PSScriptRoot -Parent))
$padroes = @(
    'github_pat_[A-Za-z0-9_]{20,}', 'ghp_[A-Za-z0-9]{20,}', 'cfat_[A-Za-z0-9]{20,}',
    '-----BEGIN [A-Z ]*PRIVATE KEY-----', 'OpenVPN Static key', '(?i)password\s*[=:]\s*["'']?[^<$\s"''][^\s"'';]{5,}',
    '(?i)(secret|senha|pwd)\s*[=:]\s*["'']?[^<$\s"''][^\s"'';]{5,}', '[A-Za-z0-9~_.-]{34,}~[A-Za-z0-9_.-]*'
)
# valores que começam com $ são variáveis do PowerShell (lidas de credenciais.txt), não segredos
$achou = $false
Get-ChildItem $Raiz -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Extension -notin '.png','.jpg','.jpeg','.ico' -and $_.FullName -ne $PSCommandPath } | ForEach-Object {
    $f = $_; $t = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue; if (-not $t) { return }
    foreach ($p in $padroes) { foreach ($m in [regex]::Matches($t, $p)) { $achou = $true; "{0}: {1}" -f $f.FullName.Replace($Raiz,''), $m.Value.Substring(0, [Math]::Min(60, $m.Value.Length)) } }
}
if (-not $achou) { 'Nenhum segredo encontrado.' }
