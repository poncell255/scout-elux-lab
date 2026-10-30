$ErrorActionPreference='Stop'
$root='C:\Users\Administrator\Downloads\hapvida-saude'
$profile=Join-Path $root ('previa\edge-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $profile -Force | Out-Null
$browser='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$process=Start-Process -FilePath $browser -ArgumentList @('--headless=new','--disable-gpu','--no-first-run','--remote-debugging-port=0','--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--unsafely-treat-insecure-origin-as-secure=http://10.5.0.166',"--user-data-dir=$profile",'about:blank') -WindowStyle Hidden -PassThru
$socket=$null
try{
 $portFile=Join-Path $profile 'DevToolsActivePort'
 for($i=0;$i -lt 60 -and -not(Test-Path -LiteralPath $portFile);$i++){Start-Sleep -Milliseconds 250}
 if(-not(Test-Path -LiteralPath $portFile)){throw 'Edge headless nao iniciou'}
 $port=(Get-Content -LiteralPath $portFile -TotalCount 1).Trim()
 $targets=Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/list"
 $target=$targets | Where-Object type -eq 'page' | Select-Object -First 1
 $socket=[Net.WebSockets.ClientWebSocket]::new();$socket.ConnectAsync([uri]$target.webSocketDebuggerUrl,[Threading.CancellationToken]::None).GetAwaiter().GetResult()
 $script:nextId=0;$script:jsErrors=0
 function Cdp($method,$parameters=@{}){
  $script:nextId++;$id=$script:nextId
  $payload=@{id=$id;method=$method;params=$parameters} | ConvertTo-Json -Depth 30 -Compress
  $bytes=[Text.Encoding]::UTF8.GetBytes($payload)
  $socket.SendAsync([ArraySegment[byte]]::new($bytes),[Net.WebSockets.WebSocketMessageType]::Text,$true,[Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
  do{
   $stream=[IO.MemoryStream]::new();$buffer=New-Object byte[] 65536
   do{$r=$socket.ReceiveAsync([ArraySegment[byte]]::new($buffer),[Threading.CancellationToken]::None).GetAwaiter().GetResult();$stream.Write($buffer,0,$r.Count)}while(-not $r.EndOfMessage)
   $message=[Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json;$stream.Dispose()
   if($message.method -eq 'Runtime.exceptionThrown'){$script:jsErrors++}
  }while($message.id -ne $id)
  if($message.error){throw "Falha CDP: $method"}
  return $message.result
 }
 [void](Cdp 'Page.enable');[void](Cdp 'Network.enable');[void](Cdp 'Runtime.enable')
 [void](Cdp 'Emulation.setDeviceMetricsOverride' @{width=1440;height=1000;deviceScaleFactor=1;mobile=$false})
 $line=[IO.File]::ReadAllLines('C:\ScoutSetup\credenciais.txt') | Where-Object {$_.StartsWith('HAPVIDA admin / ')} | Select-Object -First 1
 $pwd=($line -split ' / ',2)[1].Trim();$authorization=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('admin:'+$pwd))
 [void](Cdp 'Network.setExtraHTTPHeaders' @{headers=@{Authorization='Basic '+$authorization}})
 [void](Cdp 'Page.navigate' @{url='http://10.5.0.166/hapvida/admin'})
 for($i=0;$i -lt 30;$i++){
  Start-Sleep -Milliseconds 200
  $state=Cdp 'Runtime.evaluate' @{expression="document.querySelector('#total')?.textContent || ''";returnByValue=$true}
  if($state.result.value -match 'paciente'){break}
 }
 if($state.result.value -notmatch 'paciente'){throw 'Cadastro nao carregou no navegador'}
 $shot=Cdp 'Page.captureScreenshot' @{format='png'};[IO.File]::WriteAllBytes("$root\previa\cadastro.png",[Convert]::FromBase64String($shot.data))
 'Navegador: cadastro carregou e executou a listagem de pacientes.'
 [void](Cdp 'Runtime.evaluate' @{expression="document.querySelector('#open-camera').click();"})
 for($i=0;$i -lt 50;$i++){
  Start-Sleep -Milliseconds 100
  $cameraState=Cdp 'Runtime.evaluate' @{expression="document.querySelector('#camera-video').videoWidth>0 && !document.querySelector('#camera-capture').disabled";returnByValue=$true}
  if($cameraState.result.value){break}
 }
 if(-not $cameraState.result.value){throw 'Camera sintetica nao abriu'}
 [void](Cdp 'Runtime.evaluate' @{expression="document.querySelector('#camera-capture').click();"})
 for($i=0;$i -lt 20;$i++){
  Start-Sleep -Milliseconds 100
  $cameraState=Cdp 'Runtime.evaluate' @{expression="!document.querySelector('#camera-shot').hidden";returnByValue=$true}
  if($cameraState.result.value){break}
 }
 if(-not $cameraState.result.value){throw 'Captura de foto nao gerou previa'}
 [void](Cdp 'Runtime.evaluate' @{expression="document.querySelector('#camera-retake').click();document.querySelector('#camera-capture').click();"})
 Start-Sleep -Milliseconds 200
 [void](Cdp 'Runtime.evaluate' @{expression="document.querySelector('#camera-use').click();"})
 Start-Sleep -Milliseconds 100
 $cameraState=Cdp 'Runtime.evaluate' @{expression="document.querySelector('#foto').files[0]?.type==='image/jpeg' && !document.querySelector('#photo-preview').hidden && !document.querySelector('#camera-dialog').open && cameraStream===null";returnByValue=$true}
 if(-not $cameraState.result.value){throw 'Confirmacao da foto ou liberacao da camera falhou'}
 [void](Cdp 'Runtime.evaluate' @{expression="document.querySelector('#remove-photo').click();"})
 'Navegador: camera sintetica abriu, capturou, refez e anexou JPEG ao formulario; stream encerrado. Nenhum paciente cadastrado no teste.'
 [void](Cdp 'Page.navigate' @{url='http://10.5.0.166/hapvida/'})
 for($i=0;$i -lt 30;$i++){
  Start-Sleep -Milliseconds 100
  $ready=Cdp 'Runtime.evaluate' @{expression="location.pathname==='/hapvida/' && document.readyState==='complete'";returnByValue=$true}
  if($ready.result.value){break}
 }
 # Renderiza o portal com dados sinteticos em memoria, sem criar registros no banco de producao.
 $fixture=@{paciente=@{id=100;nome='Marina Oliveira';nascimento='1988-04-18';foto=$false};csrf='fixture-visual-sem-acesso';expira=([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+900);documentos=@(
 @{id=1;tipo='exame';titulo='Hemograma completo';data='2026-10-26';especialidade='Analises clinicas';resumo='Resultado disponivel · 18 parametros';conteudo=@{texto='Laudo sintetico de demonstracao.';itens=@(,@('Hemoglobina','14,2','g/dL','12,0 - 17,5'))}},
 @{id=2;tipo='exame';titulo='Perfil metabolico';data='2026-10-20';especialidade='Analises clinicas';resumo='Glicemia e perfil lipidico';conteudo=@{texto='Resultados ficticios.'}},
 @{id=3;tipo='exame';titulo='Radiografia de torax';data='2026-10-13';especialidade='Diagnostico por imagem';resumo='Laudo demonstrativo de imagem';conteudo=@{texto='Exame simulado.'}},
 @{id=4;tipo='prontuario';titulo='Consulta de check-up';data='2026-10-27';especialidade='Clinica medica';resumo='Avaliacao ambulatorial · Unidade Asa Sul';conteudo=@{texto='Atendimento ficticio.';secoes=@(,@('Evolucao','Consulta demonstrativa.'))}},
 @{id=5;tipo='prontuario';titulo='Avaliacao de enfermagem';data='2026-10-20';especialidade='Enfermagem';resumo='Triagem e sinais vitais simulados';conteudo=@{texto='Dados ilustrativos.'}},
 @{id=6;tipo='prontuario';titulo='Primeiro atendimento';data='2026-09-28';especialidade='Clinica medica';resumo='Historico inicial da demonstracao';conteudo=@{texto='Registro ficticio.'}}
 )} | ConvertTo-Json -Depth 15 -Compress
 $html=[IO.File]::ReadAllText("$root\app\web\portal.html") | ConvertTo-Json -Compress
 $expr="window.fetch=async()=>new Response(JSON.stringify($fixture),{status:200,headers:{'Content-Type':'application/json'}});document.open();document.write($html);document.close();"
 [void](Cdp 'Runtime.evaluate' @{expression=$expr})
 for($i=0;$i -lt 30;$i++){
  Start-Sleep -Milliseconds 200
  $state=Cdp 'Runtime.evaluate' @{expression="document.querySelectorAll('.document').length";returnByValue=$true}
  if($state.result.value -eq 6){break}
 }
 if($state.result.value -ne 6){throw 'Portal nao renderizou seis documentos sinteticos'}
 $shot=Cdp 'Page.captureScreenshot' @{format='png'};[IO.File]::WriteAllBytes("$root\previa\portal.png",[Convert]::FromBase64String($shot.data))
 $state=Cdp 'Runtime.evaluate' @{expression="document.querySelector('.doc-foot button').click();document.querySelector('#report').open";returnByValue=$true}
 if(-not $state.result.value){throw 'Documento nao abriu no portal'}
 'Navegador: portal renderizou seis documentos e abriu o laudo (fixture visual isolada).'
 [void](Cdp 'Runtime.evaluate' @{expression="document.querySelector('#report').close();document.querySelector('.tabs button[data-filter=exame]').click();"})
 $state=Cdp 'Runtime.evaluate' @{expression="document.querySelectorAll('.document').length";returnByValue=$true}
 if($state.result.value -ne 3){throw 'Filtro de exames falhou'}
 if($script:jsErrors -gt 0){throw 'Erros JavaScript detectados na verificacao visual'}
 'Navegador: filtro de exames funcionou; nenhum erro JavaScript detectado.'
}finally{
 if($socket -and $socket.State -eq [Net.WebSockets.WebSocketState]::Open){try{[void](Cdp 'Browser.close')}catch{}}
 if($socket){$socket.Dispose()}
}
