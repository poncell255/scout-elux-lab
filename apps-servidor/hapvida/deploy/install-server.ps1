$ErrorActionPreference='Stop'
$src='C:\Users\Administrator\Downloads\hapvida-saude'
$target='C:\ScoutSetup\hapvida'
if(Test-Path -LiteralPath $target){throw 'Destino HAPVIDA ja existe; preservado.'}
New-Item -ItemType Directory -Path $target | Out-Null
Copy-Item -LiteralPath "$src\app" -Destination "$target\app" -Recurse
Copy-Item -LiteralPath "$src\elux" -Destination "$target\elux" -Recurse
Copy-Item -LiteralPath "$src\native" -Destination "$target\native" -Recurse
Copy-Item -LiteralPath "$src\deploy" -Destination "$target\deploy" -Recurse
$cred='C:\ScoutSetup\credenciais.txt'
$lines=[IO.File]::ReadAllLines($cred)
function Credential($label){
    $line=$lines | Where-Object { $_.StartsWith($label+' / ') } | Select-Object -First 1
    if($line){return ($line -split ' / ',2)[1].Trim()}
    $bytes=New-Object byte[] 32
    $rng=[Security.Cryptography.RandomNumberGenerator]::Create();$rng.GetBytes($bytes);$rng.Dispose()
    $value=([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
    [IO.File]::AppendAllText($cred,"`r`n$label / $value`r`n",[Text.UTF8Encoding]::new($false))
    return $value
}
$admin=Credential 'HAPVIDA admin'
$key=Credential 'HAPVIDA chave dos eLux'
$payload=@{HAPVIDA_ADMIN=$admin;HAPVIDA_CHAVE=$key} | ConvertTo-Json -Compress
$payload | & 'C:\Program Files\WSL\wsl.exe' -d Ubuntu-22.04 -u root -- python3 /mnt/c/ScoutSetup/hapvida/deploy/server.py
if($LASTEXITCODE -ne 0){throw 'Falha ao iniciar servidor HAPVIDA'}
$web='C:\inetpub\hapvida'
if(Test-Path -LiteralPath $web){throw 'Diretorio IIS existente; preservado.'}
New-Item -ItemType Directory -Path $web | Out-Null
Copy-Item -LiteralPath "$src\deploy\web.config" -Destination "$web\web.config"
$appcmd="$env:windir\system32\inetsrv\appcmd.exe"
& $appcmd add backup ('pre-hapvida-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
if($LASTEXITCODE -ne 0){throw 'Backup do IIS falhou'}
& $appcmd add vdir '/app.name:Default Web Site/' '/path:/hapvida' "/physicalPath:$web"
if($LASTEXITCODE -ne 0){throw 'Falha ao criar diretorio virtual HAPVIDA'}
$code=curl.exe -s -o NUL -m 15 -w '%{http_code}' 'http://10.5.0.166/hapvida/'
if($code -ne '200'){throw "Verificacao IIS falhou: HTTP $code"}
'HAPVIDA instalado: http://10.5.0.166/hapvida/ (HTTP 200). Admin em /hapvida/admin. Senha apenas no credenciais.txt.'
