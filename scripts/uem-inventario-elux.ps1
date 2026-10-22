# Inventário dos eLux do Scout no Omnissa Workspace ONE UEM (só inventário: o UEM não gerencia o eLux).
# Cada eLux vira um "dispositivo registrado" (pré-cadastro) do usuário técnico do UEM, com série, nome e patrimônio.
#
# Modo padrão = TESTE: lê o Scout e mostra o que seria enviado, sem chamar o UEM.
#   .\uem-inventario-elux.ps1
# Conferir a conexão com o UEM:
#   .\uem-inventario-elux.ps1 -ApiUrl https://asXXXX.awmdm.com -OgId <id do Organization Group> -Testar-Conexao
# Enviar:
#   .\uem-inventario-elux.ps1 -ApiUrl https://asXXXX.awmdm.com -OgId <id> -Executar
#
# Credenciais (só em C:\ScoutSetup\credenciais.txt, nunca aqui), uma das duas formas:
#   UEM OAuth / <client_id>|<client_secret>|<url do token, ex. https://na.uemauth.workspaceone.com/connect/token>
#   UEM Basic / <usuario_admin>|<senha>|<API key (aw-tenant-code)>
param(
    [string]$ApiUrl,
    [int]$OgId,
    [string]$OgNome,                # alternativa ao -OgId: nome do Organization Group (ex.: servicos)
    [string]$UsuarioTecnico = 'elux-inventario',
    [int]$PlatformId = 21,          # Linux no enum de plataformas do UEM (confirmar no tenant com -TestarConexao)
    [string]$Estado = 'C:\ScoutSetup\uem\estado.json',
    [switch]$TestarConexao,
    [switch]$Executar
)
$ErrorActionPreference = 'Stop'
$cred = Get-Content C:\ScoutSetup\credenciais.txt
$sa = (($cred | Where-Object { $_ -match '^SQL sa' }) -split ' / ', 2)[1].Trim()

# --- eLux no Scout ---
$cn = [System.Data.SqlClient.SqlConnection]::new("Server=localhost,1433;Database=ScoutEnterprise;User ID=sa;Password=$sa;TrustServerCertificate=True"); $cn.Open()
$z = $cn.CreateCommand()
$z.CommandText = @"
SELECT d.DeviceID, d.Name, d.SerialNumber, d.Mac_Address, d.IP_Address, d.Supplier, d.DeviceType, d.OSVersion,
       d.ActiveUser, g.Name AS OU, DATEADD(s, d.LastContact, '1970-01-01') AS UltimoContatoUtc
FROM Device d LEFT JOIN Groups g ON g.GroupID = d.GroupID ORDER BY d.DeviceID
"@
$tb = [System.Data.DataTable]::new(); [void][System.Data.SqlClient.SqlDataAdapter]::new($z).Fill($tb); $cn.Close()

function Texto($v) { if ($v -is [DBNull] -or $null -eq $v) { '' } else { "$v".Trim() } }
$elux = foreach ($r in $tb.Rows) {
    $serie = Texto $r.SerialNumber
    if (-not $serie) { $serie = 'MAC-' + (Texto $r.Mac_Address) }   # sem série: usa o MAC
    [pscustomobject]@{
        DeviceID     = $r.DeviceID
        Serie        = $serie
        Nome         = Texto $r.Name
        Patrimonio   = "SCOUT-$($r.DeviceID)"
        Fabricante   = Texto $r.Supplier
        Modelo       = Texto $r.DeviceType
        Versao       = Texto $r.OSVersion
        IP           = Texto $r.IP_Address
        Usuario      = Texto $r.ActiveUser
        OU           = Texto $r.OU
        UltimoContato= "$($r.UltimoContatoUtc)"
        Amigavel     = ("eLux {0} | {1} {2} | {3} | OU {4}" -f (Texto $r.Name), (Texto $r.Supplier), (Texto $r.DeviceType), (Texto $r.OSVersion), (Texto $r.OU))
    }
}
# série repetida (ex.: pendrive eLux Portable que já rodou no mesmo notebook) → sufixo com o ID do Scout
$elux | Group-Object Serie | Where-Object Count -gt 1 | ForEach-Object { $_.Group | Select-Object -Skip 1 | ForEach-Object { $_.Serie = "$($_.Serie)-SCOUT$($_.DeviceID)" } }

if (-not $TestarConexao -and -not $Executar) {
    "MODO TESTE: nada é enviado ao UEM. $($elux.Count) eLux no Scout:"
    $elux | Format-Table DeviceID, Nome, Serie, Patrimonio, Modelo, Versao, IP, Usuario, OU -AutoSize | Out-String -Width 250
    'Registro que seria criado para o primeiro eLux:'
    $e = $elux | Select-Object -First 1
    @{ LocationGroupId = '<OgId>'; FriendlyName = $e.Amigavel; Ownership = 'C'; PlatformId = $PlatformId; SerialNumber = $e.Serie; AssetNumber = $e.Patrimonio } | ConvertTo-Json
    return
}

# --- UEM ---
if (-not $ApiUrl -or (-not $OgId -and -not $OgNome)) { throw 'Informe -ApiUrl e -OgId (ou -OgNome).' }
$ApiUrl = $ApiUrl.TrimEnd('/')
$headers = @{ Accept = 'application/json;version=1'; 'Content-Type' = 'application/json' }
$oauth = $cred | Where-Object { $_ -match '^UEM OAuth' } | Select-Object -First 1
$basic = $cred | Where-Object { $_ -match '^UEM Basic' } | Select-Object -First 1
if ($oauth) {
    $id, $segredo, $tokenUrl = (($oauth -split ' / ', 2)[1].Trim()) -split '\|'
    $tok = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body @{ grant_type = 'client_credentials'; client_id = $id; client_secret = $segredo }
    $headers.Authorization = "Bearer $($tok.access_token)"
} elseif ($basic) {
    $u, $s, $chave = (($basic -split ' / ', 2)[1].Trim()) -split '\|'
    $headers.Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${u}:${s}"))
    $headers['aw-tenant-code'] = $chave
} else { throw 'Faltam as credenciais do UEM no credenciais.txt (linha "UEM OAuth / ..." ou "UEM Basic / ...").' }
function Uem($metodo, $caminho, $corpo) {
    $p = @{ Method = $metodo; Uri = "$ApiUrl/API/$caminho"; Headers = $headers }
    if ($corpo) { $p.Body = ($corpo | ConvertTo-Json -Depth 5) }
    Invoke-RestMethod @p
}

if (-not $OgId) {
    $grupos = @((Uem Get "system/groups/search?name=$([uri]::EscapeDataString($OgNome))").LocationGroups)
    $og = $grupos | Where-Object { $_.Name -eq $OgNome -or $_.GroupId -eq $OgNome } | Select-Object -First 1
    if (-not $og) { $og = $grupos | Select-Object -First 1 }
    if (-not $og) { throw "Organization Group '$OgNome' não encontrado." }
    $OgId = $og.Id.Value
    "Organization Group: $($og.Name) (GroupId $($og.GroupId), Id $OgId)"
}

if ($TestarConexao) {
    'Versão do UEM:'; Uem Get 'system/info' | Format-List | Out-String
    'Organization Group:'; Uem Get "system/groups/$OgId" | Select-Object Id, Name, GroupId, LocationGroupType | Format-List | Out-String
    return
}

# usuário técnico (criado uma vez)
$busca = Uem Get "system/users/search?username=$UsuarioTecnico"
$user = @($busca.Users) | Where-Object { $_.UserName -eq $UsuarioTecnico } | Select-Object -First 1
if (-not $user) {
    $novo = Uem Post 'system/users/adduser' @{ UserName = $UsuarioTecnico; FirstName = 'Inventario'; LastName = 'eLux'; Email = "$UsuarioTecnico@invalid.local"; SecurityType = 1; LocationGroupId = $OgId; Role = 'Basic Access'; Status = $true; Password = [guid]::NewGuid().ToString('N') + 'Aa1!' }
    $userId = $novo.Value
    "Usuário técnico criado: $UsuarioTecnico (id $userId)"
} else { $userId = $user.Id.Value; "Usuário técnico: $UsuarioTecnico (id $userId)" }

# estado local: DeviceID do Scout → já registrado
New-Item -ItemType Directory (Split-Path $Estado) -Force | Out-Null
$feitos = @{}; if (Test-Path $Estado) { (Get-Content $Estado -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $feitos[$_.Name] = $_.Value } }
foreach ($e in $elux) {
    $chave = "$($e.DeviceID)"
    if ($feitos.ContainsKey($chave)) { "  já registrado: $($e.Nome) ($($e.Serie))"; continue }
    try {
        [void](Uem Post "system/users/$userId/registerdevice" @{ LocationGroupId = $OgId; FriendlyName = $e.Amigavel; Ownership = 'C'; PlatformId = $PlatformId; SerialNumber = $e.Serie; AssetNumber = $e.Patrimonio; MessageType = -1 })
        $feitos[$chave] = @{ Nome = $e.Nome; Serie = $e.Serie; Registrado = (Get-Date).ToString('s') }
        "  registrado: $($e.Nome) ($($e.Serie))"
    } catch { "  ERRO em $($e.Nome): $($_.Exception.Message) $($_.ErrorDetails.Message)" }
}
$feitos | ConvertTo-Json -Depth 3 | Set-Content $Estado -Encoding UTF8
