# Fase 21 — uberAgent enviando para dois servidores

Objetivo: todos os eLux enviam métricas e eventos do uberAgent **ao mesmo tempo** para dois servidores independentes, compatíveis com o Splunk HTTP Event Collector (HEC).

| | Servidor A | Servidor B |
|---|---|---|
| Nome no `uberAgent.conf` | PopulosUXM | PopulosAnalytics |
| Endereço | `http://10.30.0.99:3001` | `http://10.5.1.4:3001` |
| Aplicação | Populos uberAgent UXM (produção) | Populos Analytics |
| Token | `uberAgent HEC 10.30.0.99` no `credenciais.txt` | `uberAgent HEC 10.5.1.4` no `credenciais.txt` (valor de `HEC_TOKEN` em `C:\Program Files\Populos Analytics\app\.env` nessa máquina) |

## 21.1 Testar os receptores antes

Da rede dos eLux (ou do servidor Scout):
```powershell
curl.exe -s http://10.30.0.99:3001/services/collector/health   # {"text":"HEC is healthy","code":17}
curl.exe -s http://10.5.1.4:3001/services/collector/health
# token: 200 = aceito, 401 = token errado
curl.exe -s -H "Authorization: Splunk <TOKEN>" -d '{"time":0,"host":"TESTE-UNICON","sourcetype":"uberAgent:Test:Probe","event":{"ok":1}}' http://<servidor>:3001/services/collector/event
```
No projeto, o token do servidor B que constava na documentação estava errado (401); o valor certo foi lido do `.env` do servidor. O teste grava um evento com o host `TESTE-UNICON`.

## 21.2 Pacote

O agente **não precisa ser empacotado**: o catálogo do ELIAS já tem o EPM oficial `uberagent` 8.0.7535 (FPM `uberagent_base`, 34 MB, serviço `uberAgent.service`). No UniconOS a licença vem do próprio sistema: **não** distribua `uberAgent.lic` nem `provisiontoken.blob`.

Imagens derivadas com o pacote:
```powershell
.\scripts\imagem-derivada.ps1 -De v12 -Nome populos-elux7-v18 -MaisEpms uberagent -Publicar
.\scripts\imagem-derivada.ps1 -De v13 -Nome populos-elux7-v19 -MaisEpms uberagent -Publicar   # TV
.\scripts\imagem-derivada.ps1 -De v16 -Nome populos-elux7-v20 -MaisEpms uberagent -Publicar   # Porto
.\scripts\imagem-derivada.ps1 -De v17 -Nome populos-elux7-v21 -MaisEpms uberagent -Publicar   # Populos Dev
```

## 21.3 Configuração

No eLux, o uberAgent lê a configuração em **`/setup/uberAgent/`**; os arquivos são entregues pelo Scout, já descompactados (documentação Citrix: *uberAgent → Configuration through config file*).

1. Baixe o pacote de configuração do servidor A (`config.tar.gz`, endereço interno) e extraia em `C:\ScoutSetup\uberagent\base\x\` com `tar -xzf`.
2. Grave os tokens no `credenciais.txt`:
   ```
   uberAgent HEC 10.30.0.99 / <token do servidor A>
   uberAgent HEC 10.5.1.4 / <token do servidor B>
   ```
3. Rode `scripts\uberagent-todas-ous.ps1`. Ele:
   - copia os 31 arquivos `.conf` (sem os de licença);
   - troca a seção `[Receiver]` (só as linhas reais, na coluna 1; o exemplo tem `[Receiver]` dentro de comentários) por **duas** seções, uma por servidor:
     ```ini
     [Receiver]
     Name = PopulosUXM
     Type = Splunk
     Protocol = HTTP
     Servers = http://10.30.0.99:3001
     RESTToken = <token A>

     [Receiver]
     Name = PopulosAnalytics
     Type = Splunk
     Protocol = HTTP
     Servers = http://10.5.1.4:3001
     RESTToken = <token B>
     ```
   - faz backup do banco e grava os arquivos como FileEntry `/setup/uberAgent/<arquivo>` em **todas** as OUs;
   - troca a imagem dos setups e marca os dispositivos para atualizar.
   Com `-SoMontar`, só gera os arquivos em `C:\ScoutSetup\uberagent\elux\` (essa pasta contém os tokens: não a coloque no Git).

Regras do `uberAgent.conf`:
- **Uma seção `[Receiver]` por servidor.** Dois endereços no mesmo `Servers =` fazem balanceamento/failover: cada evento vai para um só.
- Os nomes (`Name =`) precisam ser diferentes: cada receptor tem a própria fila persistente (`/setup/uberAgent/OutputQueue`).
- Se algum timer usar `Receivers =`, inclua os dois nomes.

## 21.4 Aplicar e validar

1. Em cada eLux: **Deliver software** → **Update software** → reiniciar. A configuração chega antes ("config em dia"), mas o programa só entra com a imagem.
2. No diagnóstico do eLux, `/var/log/uberAgent/uberAgent.log` deve ter:
   - `Initializing receiver(s)...` com **dois** receptores;
   - nenhuma linha `Unknown value in line <...>` (receptor fora de seção);
   - nenhum `failed with (code: 401)` (token errado) nem erro de conexão.
3. Em alguns minutos o aparelho aparece nos dois painéis (`https://10.30.0.99:3001` e `https://10.5.1.4:3001`, certificado autoassinado).

> **Atenção ao servidor B:** o IP 10.5.1.4 é o mesmo do Notebook-Wagner quando ele roda o eLux; o servidor B é o lado Windows desse notebook dual-boot. Com o notebook no eLux, o servidor B fica fora do ar e os eLux guardam os eventos na fila até ele voltar. Para produção, coloque o servidor B numa máquina sempre ligada com IP fixo e rode o script de novo com o endereço novo (`-Receptores`).
