# Monta o Markdown do manual (manual.md) a partir do guia do repositório + partes novas (src\) + anexos.
param([string]$Repo = 'C:\ScoutSetup\repo-github', [string]$Src = 'C:\ScoutSetup\manual\src', [string]$Saida = 'C:\ScoutSetup\manual\manual.md')
$utf8 = [Text.UTF8Encoding]::new($false)
$g = [IO.File]::ReadAllLines("$Repo\docs\GUIA-IMPLANTACAO.md", $utf8)
function Linha($texto) { for ($i = 0; $i -lt $g.Count; $i++) { if ($g[$i] -eq $texto) { return $i } }; throw "linha nao encontrada: $texto" }
function Trecho($de, $ate) { $a = Linha $de; $b = if ($ate) { (Linha $ate) - 1 } else { $g.Count - 1 }; $g[$a..$b] -join "`n" }
function Src($n) { [IO.File]::ReadAllText("$Src\$n", $utf8).TrimEnd() }

# rebaixa os títulos do guia um nível (## -> #), sem mexer em blocos de código
function Rebaixa($t) {
    $dentro = $false
    ($t -split "`n" | ForEach-Object {
        if ($_ -match '^```') { $dentro = -not $dentro; $_ }
        elseif (-not $dentro -and $_ -match '^(#{2,4}) ') { $_.Substring(1) }
        else { $_ } }) -join "`n"
}

$cap1  = Trecho '## 1. Visão geral e arquitetura' '## 2. Decisões de projeto'
$dec   = (Trecho '## 2. Decisões de projeto' '## 3. Pré-requisitos') -replace '^## 2\. ', '## 4. '
$par   = (Trecho '## 4. Parâmetros do ambiente' '## 5. Regras de trabalho') -replace '^## 4\. ', '## 5. '
$reg   = (Trecho '## 5. Regras de trabalho' '## Fase 1 — Servidor base') -replace '^## 5\. ', '## 6. '
$f1a17 = Trecho '## Fase 1 — Servidor base' '## Fase 18 — Pacotes próprios com o SDK (digital, VS Code nativo, ajustes)'
$f19e20 = Trecho '## Fase 19 — OU só com digital, sem AD (OU "Porto")' '## Operação e diagnóstico'
$fim   = Trecho '## Operação e diagnóstico' $null

# atualizações pontuais no texto do guia
$f1a17 = $f1a17.Replace('| Populos Dev | 10 | 6 | AD | Apps da Populos + VS Code + OneDrive; home persistente (Fase 15) |',
    "| Populos Dev | 10 | 6 | AD | Apps da Populos + VS Code + OneDrive; home persistente (Fase 15); digital como 2º fator (Fase 18) |`n| Porto | 11 | 7 | **só digital** | Apps da Populos Dev + CXone + leitor de PDF (Fase 19) |")
$fim = $fim.Replace('| `scripts/sql/desfazer-*.sql` | — |', "| ``scripts/uberagent-todas-ous.ps1`` | 21 | Configuração do uberAgent com dois receptores e imagens em todas as OUs |`n| ``scripts/sql/desfazer-*.sql`` | — |")
$fim = $fim.Replace('| Portable01 (TV) com Chrome |', "| Servidor uberAgent B (10.5.1.4) | É o Windows do Notebook-Wagner (dual-boot, IP por DHCP) | Máquina sempre ligada com IP fixo; rodar ``uberagent-todas-ous.ps1`` com o endereço novo |`n| Portable01 (TV) com Chrome |")

# o diagrama ASCII quebra na largura da página: vira tabela de fluxos
$fluxos = @'
| Origem | Destino | Porta | Para quê |
|---|---|---|---|
| Administradores | Scout Board → DB Layer (22150/22151) → Scout Server | HTTPS 22160 | Gerência pela web, login Entra ID |
| Administradores | IIS → ARR → ELIAS 18 (22130) → MongoDB (27017, local) | HTTP 80 (`/ELIAS`) | Montagem e publicação de imagens |
| eLux | Scout Server → SQL Express (`ScoutEnterprise`) | TCP/UDP 22123, TCP 22125 | Registro, configuração e comandos |
| eLux | Scout Keep Alive → SQL Express | TCP 22124 | Estado online |
| eLux | IIS: `/ELIAS/<container>/<arquivo>` | HTTP 80 | Download das imagens e pacotes |
| eLux da OU TV | IIS site "TV Projetos" → ARR → PopulosHub (internet) | HTTP 8090 | Páginas da parede de TVs |
| eLux | Controlador de domínio | Kerberos 88, LDAP 389 | Login AD |
| eLux | a.ntp.br / b.ntp.br | UDP 123 | Hora |
| eLux | GLPI no WSL (portproxy 8088 → 8080) | HTTP 8088 | Inventário (Fase 20) |
| eLux | Servidores uberAgent A e B | HTTP 3001 | Métricas e eventos (Fase 21) |
| Citrix License Server (27000, 7279, 8083) | LAS na Citrix Cloud | HTTPS | Licença do Scout |
'@
$cap1 = [regex]::Replace($cap1, '(?s)```\r?\n\s+┌.*?```', $fluxos.Replace('$', '$$'))
$cap1 = $cap1.Replace('Um único Windows Server hospeda tudo.', 'Um único Windows Server hospeda tudo (o GLPI e o SDK rodam no WSL2 do mesmo servidor).')

$guia = Rebaixa (@($cap1, '<<ESTADO>>', '<<DOWNLOADS>>', $dec, $par, $reg, $f1a17, '<<F18>>', $f19e20, '<<F21>>', $fim) -join "`n`n")
$guia = $guia.Replace('<<ESTADO>>', (Src '02-estado-final.md')).Replace('<<DOWNLOADS>>', (Src '03-downloads.md')).Replace('<<F18>>', (Src '18-sdk.md')).Replace('<<F21>>', (Src '21-uberagent.md'))

# anexos
$lic = [IO.File]::ReadAllText("$Repo\docs\LICOES.md", $utf8) -replace '^# .*\r?\n', "# Anexo A — Lições aprendidas`n`nArmadilhas encontradas no projeto, na ordem em que apareceram, e como evitá-las.`n"
$db  = [IO.File]::ReadAllText("$Repo\docs\DB-REFERENCE.md", $utf8) -replace '^# .*\r?\n', "# Anexo B — Referência do banco do Scout`n`nTabelas e códigos do banco ``ScoutEnterprise`` descobertos durante o projeto (não documentados pela Citrix).`n"

$t = @((Src '00-inicio.md'), $guia, $lic, $db) -join "`n`n"
# links para outros .md e âncoras internas viram texto simples
$t = [regex]::Replace($t, '\[([^\]]+)\]\((?:\.\./)?[^)\s]*\.md(?:#[^)]*)?\)', '$1')
$t = [regex]::Replace($t, '\[([^\]]+)\]\(#[^)]*\)', '$1')
$t = [regex]::Replace($t, '\[`([^`\]]+)`\]\(\.\./[^)]*\)', '`$1`')
$t = $t -replace "`r`n", "`n"
# separadores '---' fora de código: o título de capítulo já tem linha
# (os dois primeiros delimitam o bloco de metadados YAML e ficam)
$dentro = $false; $yaml = 0
$t = ($t -split "`n" | Where-Object {
    if ($_ -match '^```') { $dentro = -not $dentro }
    if ($_ -eq '---' -and $yaml -lt 2) { $yaml++; return $true }
    $dentro -or $_ -ne '---' }) -join "`n"
[IO.File]::WriteAllText($Saida, $t, $utf8)
"manual.md: {0:N0} linhas" -f ($t -split "`n").Count
Select-String $Saida -Pattern '^# ' | ForEach-Object { $_.Line }
