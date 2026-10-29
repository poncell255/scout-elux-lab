<#
  continuar.ps1 - comandos para continuar o laboratório Scout + ELIAS + UniconOS (eLux) da POPULOS.
  Leia antes: C:\Users\Administrator\Downloads\CONTINUAR-COM-CODEX.md

  Uso (PowerShell como Administrador):
    .\continuar.ps1                      # = status
    .\continuar.ps1 status               # serviços, WSL, containers, site de provas, GLPI, leitor, eLux
    .\continuar.ps1 wsl                  # liga o WSL/Docker (tarefa "WSL GLPI") e o leitor (tarefa "Leitor digital no WSL")
    .\continuar.ps1 leitor               # anexa o leitor de digital (05ba:000a) ao WSL agora
    .\continuar.ps1 diag -Dispositivo Notebook-Wagner     # extrai o diagnóstico mais novo e mostra os logs úteis
    .\continuar.ps1 arquivo -Ou 12 -Destino /setup/provas/prova.sh -Arquivo C:\ScoutSetup\provas\elux\prova.sh
                                         # regrava um arquivo de uma OU no banco do Scout (com backup) e marca os eLux
    .\continuar.ps1 sync                 # copia tudo para o repositório, regenera o HISTORICO saneado e procura segredos
    .\continuar.ps1 push -Mensagem "..." # sync + commit + push (só se a busca de segredos não achar nada)
    .\continuar.ps1 manual               # remonta e gera o manual em Word e PDF (cópia em Downloads)
#>
param(
    [Parameter(Position = 0)][ValidateSet('status', 'wsl', 'leitor', 'diag', 'arquivo', 'sync', 'push', 'manual')][string]$Acao = 'status',
    [string]$Dispositivo, [int]$Ou = -1, [string]$Destino, [string]$Arquivo, [string]$Mensagem
)
$ErrorActionPreference = 'Continue'
$WSL = 'C:\Program Files\WSL\wsl.exe'
$USBIPD = 'C:\Program Files\usbipd-win\usbipd.exe'
$REPO = 'C:\ScoutSetup\repo-github'
$MD = 'C:\Users\Administrator\Downloads\SCOUT-ELUX-GLOBAL.md'
$CRED = 'C:\ScoutSetup\credenciais.txt'

function Segredo($padrao) { $l = Get-Content $CRED | Where-Object { $_ -match $padrao } | Select-Object -First 1; if ($l) { ($l -split ' / ', 2)[1].Trim() } }
function Titulo($t) { "`n== $t" }
function Sql($q) { sqlcmd -S localhost -d ScoutEnterprise -E -C -W -s '|' -Q "SET NOCOUNT ON; $q" | Out-String -Width 300 }

function Status {
    Titulo 'Serviços'
    Get-Service ScoutServer, ScoutBoardDBLayer, ScoutBoard, ScoutKeepAlive, 'MSSQL$SQLEXPRESS', ELIAS, W3SVC -ErrorAction SilentlyContinue | Format-Table Name, Status -AutoSize | Out-String
    Titulo 'WSL e containers (glpi, glpi-db, provas)'
    & $WSL -l -v
    & $WSL -d Ubuntu-22.04 -u root -- docker ps --format '{{.Names}}  {{.Status}}'
    Titulo 'Sites'
    foreach ($u in 'http://10.5.0.166/provas/', 'http://10.5.0.166:8088/', 'http://10.5.0.166/ELIAS/', 'https://localhost:22160/') {
        $c = curl.exe -s -k -o NUL -m 10 -w '%{http_code}' $u; "{0,-34} HTTP {1}" -f $u, $c }
    Titulo 'Leitor de digital (usbipd)'
    if (Test-Path $USBIPD) { & $USBIPD list | Select-String '05ba|BUSID' } else { 'usbipd-win não instalado' }
    Titulo 'Tarefas agendadas'
    Get-ScheduledTask | Where-Object TaskName -in 'WSL GLPI', 'Leitor digital no WSL' | Format-Table TaskName, State -AutoSize | Out-String
    Titulo 'OUs e imagens'
    Sql "SELECT g.GroupID, g.Name, g.SetupID, s.AuthType, s.ImageFile FROM Groups g LEFT JOIN Setup s ON s.SetupID=g.SetupID ORDER BY g.GroupID"
    Titulo 'eLux'
    Sql "SELECT DeviceID, Name, GroupID, IP_Address, DeliveryImage, CASE WHEN ConfigDataID=ConfigDataIDToHave THEN 'em dia' ELSE 'pendente' END config, DATEADD(s,LastContact,'1970-01-01') contato_utc FROM Device"
    Titulo 'Repositório'
    git -C $REPO log --oneline -1; git -C $REPO status --short | Measure-Object | ForEach-Object { "alterações não enviadas no repositório: $($_.Count) (rode 'sync' para trazer as do servidor)" }
}

function Wsl {
    Start-ScheduledTask 'WSL GLPI' -ErrorAction SilentlyContinue
    Start-ScheduledTask 'Leitor digital no WSL' -ErrorAction SilentlyContinue
    Start-Sleep 8; & $WSL -d Ubuntu-22.04 -u root -- docker ps --format '{{.Names}}  {{.Status}}'
}

function Leitor {
    & $USBIPD attach --wsl --hardware-id 05ba:000a
    Start-Sleep 3; & $USBIPD list | Select-String '05ba'
    & $WSL -d Ubuntu-22.04 -u root -- docker exec provas timeout 5 cadastrar-digital /tmp/t.fpr 0 teste
}

function Diag {
    if (-not $Dispositivo) { throw 'informe -Dispositivo (nome do eLux no Scout)' }
    $z = Get-ChildItem 'C:\Users\Public\Documents\Unicon\Scout\Server\diag' -Filter "$Dispositivo*_diag.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $z) { throw "nenhum diagnóstico de $Dispositivo (gere pelo Scout Board)" }
    $d = "C:\dg\$Dispositivo"; Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $d | Out-Null
    tar -xf $z.FullName -C $d 2>$null
    Titulo "$($z.Name) extraído em $d"
    Titulo 'Imagem em uso'; Select-String "$d\setup\eluxman\current.idf" -Pattern '^Name=' -ErrorAction SilentlyContinue | ForEach-Object Line
    Titulo 'Última atualização (boot.update.log)'; Get-Content "$d\setup\logs\boot.update.log" -Tail 8 -ErrorAction SilentlyContinue
    $u = Get-ChildItem "$d\setup\eluxman" -Filter 'update.*.log' -ErrorAction SilentlyContinue | Sort-Object { [int]($_.BaseName -replace '\D', '') } | Select-Object -Last 1
    if ($u) { Titulo $u.Name; Get-Content $u.FullName -Tail 12 }
    foreach ($l in 'tmp\provas.log', 'tmp\tv-projetos.log', 'var\log\uberAgent\uberAgent.log') {
        if (Test-Path "$d\$l") { Titulo $l; Get-Content "$d\$l" -Tail 15 } }
    Titulo 'journal: populos / glpi / uberAgent'
    Select-String "$d\tmp\systemd-journal.log" -Pattern 'populos-digital|populos-glpi|uberAgent' -ErrorAction SilentlyContinue | Select-Object -Last 15 | ForEach-Object { $_.Line.Substring(0, [Math]::Min(200, $_.Line.Length)) }
}

function ArquivoOu {
    if ($Ou -lt 0 -or -not $Destino -or -not (Test-Path $Arquivo)) { throw 'informe -Ou <GroupID> -Destino <caminho no eLux> -Arquivo <arquivo local>' }
    $sa = Segredo '^SQL sa'
    $bytes = [IO.File]::ReadAllBytes($Arquivo)
    if ($Arquivo -match '\.(sh|conf|ini|txt)$') { $bytes = [Text.UTF8Encoding]::new($false).GetBytes(([IO.File]::ReadAllText($Arquivo)) -replace "`r`n", "`n") }
    $m = [System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=master;User ID=sa;Password=$sa;TrustServerCertificate=True"); $m.Open(); $x = $m.CreateCommand(); $x.CommandTimeout = 600
    $x.CommandText = "BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-arquivo.bak' WITH INIT, COPY_ONLY"; [void]$x.ExecuteNonQuery(); $m.Close()
    $cn = [System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open()
    $z = $cn.CreateCommand(); $z.CommandText = "UPDATE u SET FileContent=@fc, TimeModified=@tm FROM UCFT u JOIN FileEntry f ON f.UCFTID=u.UCFTID WHERE f.MemberType=1 AND f.MemberID=@ou AND f.FileDestination=@d; SELECT @@ROWCOUNT"
    $q = $z.Parameters.Add('@fc', [Data.SqlDbType]::VarBinary, -1); $q.Value = $bytes
    [void]$z.Parameters.AddWithValue('@tm', [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()); [void]$z.Parameters.AddWithValue('@ou', $Ou); [void]$z.Parameters.AddWithValue('@d', $Destino)
    $n = $z.ExecuteScalar()
    if ($n -gt 0) { $z = $cn.CreateCommand(); $z.CommandText = "UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=$Ou"; [void]$z.ExecuteNonQuery(); "atualizado ($n). Reinicie os eLux da OU $Ou." }
    else { "nenhum FileEntry com destino $Destino na OU $Ou (para criar um novo, veja a função Arquivo em scripts\criar-ou-provas.ps1)" }
    $cn.Close()
}

function Sync {
    Titulo 'Copiando para o repositório'
    $scripts = 'ad-e-nondomain', 'kiosk-sem-ad', 'ntp-elux', 'hosts-ad-elux', 'krb5-elux', 'tela-sempre-ativa', 'criar-ou-tv-projetos', 'tv-projetos-arquivos',
               'montar-idf', 'extrair-fpm', 'criar-ou-populos-dev', 'edge-todas-ous', 'uem-inventario-elux', 'criar-ou-porto', 'imagem-derivada',
               'chrome-glpi-todas-ous', 'uberagent-todas-ous', 'teams-todas-ous', 'criar-ou-provas'
    foreach ($s in $scripts) { if (Test-Path "C:\ScoutSetup\scripts\$s.ps1") { Copy-Item "C:\ScoutSetup\scripts\$s.ps1" "$REPO\scripts\" -Force } }
    Copy-Item $PSCommandPath "$REPO\scripts\continuar.ps1" -Force
    robocopy C:\ScoutSetup\provas "$REPO\provas" /E /XD __pycache__ /XF *.pyc *.env /NJH /NJS /NFL /NDL | Out-Null
    robocopy C:\ScoutSetup\manual "$REPO\manual" /E /XD previa /XF manual.md /NJH /NJS /NFL /NDL | Out-Null
    foreach ($p in 'populos_digital', 'populos_glpi', 'populos_ajustes') { robocopy "C:\UniconSDK\pkgs\$p" "$REPO\uniconos-sdk\pkgs\$p" /E /XF *.deb *.fpr /XD output build /NJH /NJS /NFL /NDL | Out-Null }
    Copy-Item C:\UniconSDK\scripts\*.sh "$REPO\uniconos-sdk\scripts\" -Force
    # Apps locais e Netskope: só o código (sem saida/ com pacotes e binários de terceiros, sem dados)
    foreach ($p in 'hapvida-local', 'btg-local', 'porto-local', 'netskope-elux') { if (Test-Path "C:\Users\Administrator\Downloads\$p") { robocopy "C:\Users\Administrator\Downloads\$p" "$REPO\apps-locais\$p" /E /XD saida dados __pycache__ .git /XF *.db *.pyc *.fpm *.epm *.zip *.idf *.run *.env /NJH /NJS /NFL /NDL | Out-Null } }
    if (Test-Path C:\Users\Administrator\Downloads\CONTINUAR-COM-CODEX.md) { Copy-Item C:\Users\Administrator\Downloads\CONTINUAR-COM-CODEX.md "$REPO\docs\CONTINUAR-COM-CODEX.md" -Force }
    # HISTORICO = MD vivo sem e-mails, IDs do tenant e valores sensíveis já conhecidos
    $h = Get-Content $MD -Raw -Encoding UTF8
    $h = $h -replace 'Wagner\.poncell@populos\.com\.br', '<email-admin>' -replace '(?i)[a-z]+\.[a-z]+@populos\.com\.br', '<email-usuario>' -replace 'f2c41670-cc12-4596-8c6f-c7a4ca8a7552', '<TENANT_ID>' -replace 'e55fd3ae-eeeb-49ab-937f-c331d78dc678', '<APP_ID>' -replace 'f47613bf343754d4f1c54b20d0d0be09', '<CF_ACCOUNT_ID>' -replace 'e7cf8d199c737d5ffde0deaa1cff7f89', '<CF_ZONE_ID>' -replace 'Plefir@2', '<SENHA>' -replace 'Populos(@|%40)2026', '<SENHA_TV>' -replace 'aabc98c28f524b87ab5e', '<CHAVE_DOWNLOAD_UBERAGENT>' -replace 'e11bfc54-9381-4dea-98a7-202bf7698aeb', '<TOKEN_HEC>'
    [IO.File]::WriteAllText("$REPO\docs\HISTORICO.md", $h, [Text.UTF8Encoding]::new($false))
    Titulo 'Busca de segredos'
    & "$REPO\scripts\verificar-segredos.ps1" -Raiz $REPO
    $vals = Get-Content $CRED | ForEach-Object { ($_ -split ' / ')[-1].Trim() } | Where-Object { $_.Length -ge 8 -and $_ -notmatch '^0{8}-' }
    $achou = 0
    Get-ChildItem $REPO -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Extension -notin '.png', '.jpg' } | ForEach-Object {
        $t = [IO.File]::ReadAllText($_.FullName); foreach ($v in $vals) { if ($t.Contains($v)) { Write-Host "SEGREDO em $($_.FullName)" -ForegroundColor Red; $achou++ } } }
    "valores do credenciais.txt encontrados no repositório: $achou"
    git -C $REPO status --short
    $script:SegredosAchados = $achou
}

function Push {
    if (-not $Mensagem) { throw 'informe -Mensagem "descrição do commit"' }
    Sync
    if ($script:SegredosAchados -ne 0) { throw 'há segredos no repositório: corrija antes de enviar' }
    $env:GIT_TERMINAL_PROMPT = '0'; $env:GCM_INTERACTIVE = 'never'
    $f = "$env:TEMP\msg-commit.txt"; [IO.File]::WriteAllText($f, "$Mensagem`n")
    git -C $REPO add -A
    git -C $REPO -c user.name='poncell255' -c user.email='Wagner.poncell@populos.com.br' commit -q -F $f
    git -C $REPO push origin HEAD
    git -C $REPO log --oneline -1
}

function Manual {
    & C:\ScoutSetup\manual\montar-manual.ps1
    & $WSL -d Ubuntu-22.04 -u root -- bash /mnt/c/UniconSDK/scripts/35-gerar-manual.sh
    Copy-Item C:\ScoutSetup\manual\Manual-Implantacao-Scout-eLux-POPULOS.* C:\Users\Administrator\Downloads\ -Force
}

switch ($Acao) {
    'status' { Status } 'wsl' { Wsl } 'leitor' { Leitor } 'diag' { Diag }
    'arquivo' { ArquivoOu } 'sync' { Sync } 'push' { Push } 'manual' { Manual }
}
