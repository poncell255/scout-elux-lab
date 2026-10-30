# Continuação do projeto — Scout + ELIAS 18 + UniconOS (eLux 7) da POPULOS

> Documento de passagem para outro agente de IA (Codex). Estado em **28/10/2026**.
> Antes de qualquer coisa: leia este arquivo inteiro, rode `C:\ScoutSetup\continuar.ps1 status` e leia o **fim** de `C:\Users\Administrator\Downloads\SCOUT-ELUX-GLOBAL.md` (seção 7.13, a mais recente).

## 1. Quem e o quê

- **Dono:** Wagner (POPULOS). Fala português do Brasil; responda e documente em português.
- **Servidor:** `SCOUTBOARD`, Windows Server 2025, domínio `populos.local` (DC POPAD01, 10.20.0.10), IP **10.5.0.166**, 8 GB RAM. Tudo roda nele.
- **Projeto:** gerenciar thin clients **Citrix UniconOS (eLux 7.2609)** com **Citrix UniconOS Management (Scout Enterprise 15.2609)**, imagens montadas no **ELIAS 18**, pacotes próprios feitos com o **SDK da Unicon** (`epkg`), e integrações (GLPI, uberAgent, site de provas).

## 2. Regras que não podem ser quebradas

1. **Senhas e tokens só em `C:\ScoutSetup\credenciais.txt`** (uma linha por item: `Nome / valor`; ACL só Administradores/SYSTEM). Nunca no MD, no repositório, em documentos ou em mensagens. Leia com `(... -split ' / ',2)[1]`. Linhas usadas: `SQL sa`, `ELIAS 18`, `GLPI DB`, `GLPI admin`, `GLPI inventario`, `uberAgent HEC 10.30.0.99`, `uberAgent HEC 10.5.1.4`, `Provas admin`, `Provas chave dos eLux`.
2. **Documento vivo:** registre cada passo em `C:\Users\Administrator\Downloads\SCOUT-ELUX-GLOBAL.md` (em português, seção 7.13, sem senhas).
3. **Banco do Scout (`ScoutEnterprise`):** backup antes (`BACKUP DATABASE ... TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-<assunto>.bak' WITH INIT, COPY_ONLY`), uma transação, e no fim `UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=<OU>`.
4. **GitHub** (`C:\ScoutSetup\repo-github` → github.com/poncell255/scout-elux-lab): só envie quando o Wagner pedir; antes rode a busca de segredos (`continuar.ps1 sync`; `push` já faz). O histórico publicado é o MD saneado (`docs/HISTORICO.md`).
5. **Ações difíceis de desfazer ou visíveis para fora** (formatar/reinstalar eLux, apagar dados, expor portas, tarefas agendadas, publicar): confirme com o Wagner antes.
6. **Não invente resultado:** se não testou num eLux de verdade, diga que não testou.

## 3. Mapa: o que está onde

| O quê | Onde |
|---|---|
| Diário completo | `C:\Users\Administrator\Downloads\SCOUT-ELUX-GLOBAL.md` |
| Script de continuidade | `C:\ScoutSetup\continuar.ps1` (seção 11) |
| Populos UniconOS SDK / Conversor Unicon (Ubuntu → EPM/FPM; áreas Software e Drivers) | http://10.5.0.166/conversor/ (senha "Conversor Unicon admin"); código `C:\ScoutSetup\conversor`; serviço WSL `conversor-unicon` (porta 3200) |
| Repositório (cópia sem senhas) | `C:\ScoutSetup\repo-github` (guia `docs/GUIA-IMPLANTACAO.md` fases 1–23, `docs/LICOES.md` 1–40, `docs/DB-REFERENCE.md`) |
| Manual Word/PDF | `C:\ScoutSetup\manual\` (+ cópia em Downloads); gerar com `continuar.ps1 manual` |
| Scripts do Scout (PowerShell) | `C:\ScoutSetup\scripts\` |
| SDK (pacotes próprios) | fontes `C:\UniconSDK\pkgs\`, scripts `C:\UniconSDK\scripts\NN-*.sh` (rodam no WSL), saídas `C:\UniconSDK\saida\` |
| Site de provas | `C:\ScoutSetup\provas\app\` (código), `C:\ScoutSetup\provas\elux\prova.sh` (vai para o eLux) |
| Temas eLux | `C:\eLuxContainer\theme\<tema>\` |
| Ícones | `C:\ScoutSetup\icons\` |
| Backups do banco | `C:\ScoutSetup\backup\` |
| Diagnósticos dos eLux | `C:\Users\Public\Documents\Unicon\Scout\Server\diag\` (extrair com `tar -xf`, não `Expand-Archive`) |
| Catálogo do ELIAS (cache local) | `C:\ScoutSetup\diag\elias-epms.json`, `elias-fpms.json`, `idf-populos-v<N>.json` |
| Configuração do uberAgent pronta (tem tokens; fora do Git) | `C:\ScoutSetup\uberagent\elux\` |

**Arquivos entregues aos eLux:** o Scout guarda uma cópia no banco (`UCFT` = conteúdo, `FileEntry` = destino no eLux, por OU com `MemberType=1, MemberID=<GroupID>`). Mudar o arquivo no disco **não** chega ao eLux: regrave no banco com `continuar.ps1 arquivo -Ou <id> -Destino <caminho> -Arquivo <local>` (atualiza `TimeModified` em epoch UTC).

## 4. Serviços, portas e endereços

| Componente | Endereço | Observação |
|---|---|---|
| Scout Board | `https://<servidor>:22160` | Login Entra ID; não dá para automatizar o login (OIDC) |
| ELIAS 18 | `http://10.5.0.166/ELIAS/` | API `.../ELIAS/api/UC_RP6_X64/v1.0/` (login `POST authenticate/`, cookie em `C:\ScoutSetup\elias_cj.txt`) |
| Firmware para eLux | `http://10.5.0.166/ELIAS/UC_RP6_X64/<arquivo>` | `.idf`, `.epm`, `.fpm` |
| GLPI 12 | `http://10.5.0.166:8088` | Docker `glpi` + `glpi-db` no WSL (porta 8080 → portproxy 8088) |
| Site de provas | `http://10.5.0.166/provas` (admin em `/provas/admin`) | Docker `provas` no WSL (3100), IIS reescreve `/provas` → `localhost:3100` |
| TV Projetos (proxy) | `http://10.5.0.166:8090` | IIS + ARR, `C:\inetpub\tvprojetos` |
| Scout ↔ eLux | TCP/UDP 22123, TCP 22125, 22124 | |

**WSL (Ubuntu-22.04):** Docker com `glpi`, `glpi-db`, `provas` e a imagem do SDK `citrix/uniconos7-sdk-epkg:7.2609.0-5`. Fica ligado pela tarefa **"WSL GLPI"** (`27-wsl-manter-ligado.sh`; `.wslconfig` com `vmIdleTimeout=-1`). Rode os scripts assim:
```powershell
& 'C:\Program Files\WSL\wsl.exe' -d Ubuntu-22.04 -u root -- bash /mnt/c/UniconSDK/scripts/<script>.sh
```
Não passe comandos com aspas/`$` por `wsl -- bash -c` a partir do PowerShell (quebra): escreva um `.sh` em `C:\UniconSDK\scripts\` e rode-o. No Git Bash, prefixe `MSYS_NO_PATHCONV=1`.

**Leitor de digital do servidor** (U.are.U 4500, `05ba:000a`): passado ao WSL pelo **usbipd-win 5.3.0**; tarefa **"Leitor digital no WSL"** (`usbipd attach --wsl --hardware-id 05ba:000a --auto-attach`). Se o cadastro no site disser "leitor de digital não encontrado": `continuar.ps1 leitor` (e confira se está plugado: em 28/10 ele não aparecia no `usbipd list`).

## 5. OUs, setups e imagens (28/10/2026)

| OU | GroupID | Setup | Login | Imagem | Notas |
|---|---|---|---|---|---|
| Lost & Found | 0, 1 | 0 | AD | v22 | Destino de eLux novos |
| Enterprise / FollowMeDesktop | 2 / 3 | 2 / 1 | AD | — | Sem aparelhos, sem imagem |
| Populos | 4 | 12 (cópia do 0, desde 29/10) | AD | v43 | Apps padrão + Teams for Linux + **Netskope** (populos_netskope 142.1.0.2831.4, Downloads\netskope-elux; cadastro por `/setup/netskope/instalador`) |
| POC-BCR, Bom Jesus | 5, 6 | 0 | AD | v22 | Apps padrão + Teams for Linux |
| Modo Kiosk | 7 | 4 | sem AD | v22 | Citrix em tela cheia |
| Populos NonDomain | 8 | 3 | sem AD | v22 | |
| TV Projetos | 9 | 5 | sem AD | v19 | 6 TVs, NVIDIA, **sem Teams** |
| Populos Dev | 10 | 6 | AD + digital (2º fator) | v24 | Home persistente |
| Porto | 11 | 7 | sem AD; digital só nos apps (desde 29/10) | v36 | Entra direto (`DESATIVADO`); tema porto-v2; apps locais "Meu Seguro Porto" e "Cadastro de Segurados Porto" (populos_porto_local 1.0.0, Downloads\porto-local, porta 3133) |
| Provas | 12 | 8 | digital (sala de provas) | v27 | App único "Prova" |
| HAPVIDA | 13 | 9 | AD, sem digital no login | v44 | Sistema de saúde no servidor + **Netskope** (mesmo instalador da OU Populos) |
| HAPVIDA Local | 14 | 10 | sem AD, dados por aparelho | v46 (v45 + gnome-keyring para o Citrix; Netskope .4, sem Horizon) | Cadastro, câmera, digital e prontuário no próprio eLux; tema hapvida-v4 (papel de parede "Hapvida Secure Endpoint Branding Scene", Downloads\hapvida-v4) |
| BTG | 15 | 11 | sem AD, dados por aparelho | v35 | Clone da HAPVIDA Local com tema btg-v1, AVD (ms_avd_client) e app local BTG (populos_btg_local 1.0.1, Downloads\btg-local) |

Imagens (todas no ELIAS, sem conflitos; tamanho = espaço instalado):

| Imagem | Base + | Tamanho |
|---|---|---|
| v22 | v18 (Citrix, Horizon, Edge, Chrome, GLPI, uberAgent) + Teams | 3.627 MB |
| v19 | v18 + `nvidia_driver` (TV) | 3.590 MB |
| v24 | v21 (digital, ajustes, home persistente) + Teams | 3.628 MB |
| v27 | v26 (= v20 Porto sem Teams) + digital 1.2.2 | 3.351 MB |
| v28 | v23 (Porto com Teams) + digital 1.2.2 | 3.630 MB |
| v40 | v22 + populos_netskope .3 (sem nsdiag; ip6tables, CA em /var, agente espera o serviço, status no diag) + systemlibs_libindicator3 + libdbusmenu (OU Populos) | 3.694 MB |
| v41 | v29 (HAPVIDA) + populos_netskope .3 + systemlibs_libindicator3 + libdbusmenu (OU HAPVIDA) | 3.695 MB |
| v42 | v31 (HAPVIDA Local) − vmwareviewclient + populos_netskope .3 + libindicator3 + libdbusmenu | 3.654 MB |

**Limite:** eLux instalado por pendrive ou dual-boot tem raiz de ~3.700 MB; acima disso o update falha com "image size will exceed media size" (254). Confira o tamanho antes de publicar.

Dispositivos:

| Dispositivo | OU | IP | Observação |
|---|---|---|---|
| Portable01 | TV Projetos (9) | 10.5.0.14 | Pendrive; ainda na v5 (não recebeu v19) |
| PortableCinza (antes eLux9252, Dell) | Porto (11) | 10.5.0.177 | v28 entregue |
| Notebook-Wagner | Provas (12) | 10.5.1.4 | Dual-boot com Windows + TPM; v27 entregue; o lado Windows dele é o servidor uberAgent B |

## 6. Como alterar o Scout pelo banco

Use `sqlcmd -S localhost -d ScoutEnterprise -E -C ...` ou `System.Data.SqlClient` com o `sa`. Padrões (detalhes em `docs/DB-REFERENCE.md`):

- IDs não-identity (`ApplicationID`, `FileEntryID`, `SetupID`, `GroupID`): `MAX()+1 WITH (UPDLOCK, HOLDLOCK)` na transação. Identity (`UCFTID`...): `SCOPE_IDENTITY()`.
- Arquivo para o eLux: `UCFT` (`MemberType=1, MemberID=<OU>, FileType=0, FileMode=0, TimeModified=<epoch UTC>`) + `FileEntry` (`FileDestination`). Ícone global: `UCFT` com `MemberType=-1, MemberID=-1, FileType=1, FileMode=-1`.
- App local: `Application` (`AppTypeID=5`, `AutoStart`, `TM`, **`AppOnDesktop=1`** — com 0 o eLux não abre o app sozinho) + `Local` (`Type='CUSTOM'`, `Parameter`).
- OU com configuração própria: `Groups.UseParent=0` + setup clonado (ver `scripts\criar-ou-provas.ps1`, função de clone completa). `Groups.UseParentApps=0` para não herdar apps globais.
- `Setup.AuthType`: 0 sem login, 3 AD. `ShowTaskbar`, `TaskbarAutoHide`, `PersistentHomeApplications` ('ALL' ou NULL), `ImageFile` (`<nome>.idf`), `Mirror` (bits; 16393 no projeto).
- O que o Scout mandou de verdade: `ClientConfig.ClientData` do `Device.ConfigDataIDToHave`; leia como bytes Latin-1 (`[Text.Encoding]::GetEncoding(28591)`), não UTF-8.

## 7. Pacotes próprios (SDK) e imagens

Fluxo:
1. Fonte em `C:\UniconSDK\pkgs\<pacote>\`; build com o script `NN-build-*.sh <versão>` (gera `.epm/.fpm` em `C:\UniconSDK\saida\`).
2. ZIP com os dois arquivos → `POST /ELIAS/api/UC_RP6_X64/v1.0/import/<nome>.zip` (multipart, campo `file`) → cabeçalho `UUID` → `GET .../checkimport/<uuid>` até `finished`. Atualize o cache `elias-epms.json`/`elias-fpms.json` (`GET .../epms`, `.../fpms`). Exemplo completo: qualquer bloco de importação no fim do MD.
3. Imagem nova: `scripts\imagem-derivada.ps1 -De v<N> -Nome populos-elux7-v<M> [-MaisEpms x,y] [-MenosEpms z] -Publicar` (mantém a lista da imagem anterior; pega a versão mais nova de cada EPM).
4. Scout: `UPDATE Setup SET ImageFile='populos-elux7-v<M>.idf' WHERE SetupID=<s>`; no Scout Board, **Deliver software, esperar terminar, depois Update software** (Update antes do fim da entrega não instala).

| Pacote | Versão | Build | O que é |
|---|---|---|---|
| `populos_digital` | **1.2.2** | `17-build-digital.sh` (agora compila sempre via `04-compilar-digital.sh`) | GTK3 + libfprint: modos `portao <usuario>` (2º fator AD), `entrada` (só digital, ativado por `/setup/populos-digital/MODO_LOCAL`), `cadastrar-local`, `prova <pasta>` (sala de provas). Saídas: 0 ok, 1 encerrar sessão, 3 desligar, 4 pasta vazia, 5 reiniciar. `login.d/25-populos-digital` trata 3/5 |
| `populos_ajustes` | 1.0.2 | `15-build-ajustes.sh` | Edge mantém perfil com home persistente; wrapper do Claude Code |
| `populos_glpi` | 1.21.0 | `22-glpi-agent-baixar.sh` + `24-build-glpi.sh` | GLPI Agent (AppImage extraído) + timer; senha em `/setup/glpi-agent/auth` |
| `populos_teams` | 2.27.0 | `36`/`37`/`38`/`40-*.sh` | Teams for Linux (comunitário, não oficial), 274 MB |
| `populos_vscode` | 1.0 | `12-build-vscode.sh` | VS Code nativo — fora das imagens (não cabe) |

## 8. Subprojetos

- **Sala de provas (OU Provas)** — ver `C:\ScoutSetup\repo-github\provas\README.md`.
  - Site Flask em Docker `provas` (`42-provas-servidor.sh` recria; código montado somente leitura, `docker restart provas` aplica mudanças); dados em `/root/provas/data` (`provas.db`, `digitais/<id>.fpr`). Provas em `app/questoes/{citrix,nutanix}.json` (60 questões cada, 6 domínios, 60 min, 70%).
  - Cadastro: `/provas/admin` → aluno + prova → "Capturar digital" (5 leituras no leitor do servidor).
  - eLux: app "Prova" roda `/setup/provas/prova.sh`: baixa `/provas/api/galeria` (cabeçalho `X-Provas-Chave`), `populos-digital prova`, `POST /provas/api/sessao` → token → Edge `--kiosk` → volta à digital quando o aluno clica Encerrar (ou 2 min após o resultado). Log no eLux: `/tmp/provas.log`.
  - Alunos cadastrados (28/10): Diego Cardoso (Citrix; recadastrar a digital, a última captura falhou por o leitor ter desconectado), Pedro Andrade (Citrix), Wagner Poncell (Nutanix).
  - Verificar digitais: `44-provas-digitais.sh` (todas `driver=uru4000 device_id=0`, compatíveis com qualquer U.are.U 4500). Testar identificação no servidor: `43-provas-teste-digital.sh` (Xvfb).
- **GLPI:** inventário dos eLux (3–8 min após o boot e a cada 4 h). Validado com o Notebook-Wagner em 22/10.
- **uberAgent:** EPM oficial 8.0.7535; configuração em `/setup/uberAgent/` (31 `.conf`) com dois receptores Splunk HEC: PopulosUXM `http://10.30.0.99:3001` e PopulosAnalytics `http://10.5.1.4:3001`. Script `scripts\uberagent-todas-ous.ps1`. O receptor B é o Windows do Notebook-Wagner (fica fora quando o notebook está no eLux).
- **TV Projetos:** ver `repo-github\tv-projetos\README.md`.
- **Manual:** `continuar.ps1 manual` (WSL: pandoc + LibreOffice); fontes `C:\ScoutSetup\manual\src\*.md` + guia do repositório.

## 9. Armadilhas já encontradas (resumo de `docs/LICOES.md`)

- O shell do eLux é **busybox**: `tr` não entende `[:space:]` (apaga letras). Escreva `tr -d ' \t\r\n'`.
- Login.d do eLux é lido com `source`: use `return`, não `exit`. A home do eLux não executa programas; `/setup` é persistente e do root.
- PowerShell 5.1 lê `.ps1` sem BOM como ANSI: scripts com acentos precisam ser salvos em **UTF-8 com BOM**. `-replace a,b` dentro de chamada de método vira dois argumentos: calcule antes.
- `python` no Windows é só o atalho da Microsoft Store: use o Python do WSL.
- Notebook-Wagner é dual-boot com partição criptografada no TPM: já deu "Could not unseal alternate partition set" (v9). Mexer no GRUB/menu de boot pode impedir o boot.
- Monitores com EDID idêntico, NVIDIA Base Mosaic, Edge que apaga perfil, FormatBeforeUpdate apagando `custom`: ver LICOES 4, 22–25.
- Permissões: no Claude Code, criar tarefas agendadas, abrir portas e instalar software externo exigiu aprovação do Wagner. Peça antes de fazer.

## 10. Pendências (em ordem)

1. **Testar a sala de provas no Notebook-Wagner** (OU 12, v27 entregue em 27/10): confirmar no diagnóstico (`continuar.ps1 diag -Dispositivo Notebook-Wagner`) que `current.idf` é a v27 e que `/tmp/provas.log` mostra "digital: saída 0, aluno 'N'"; depois a prova deve abrir em quiosque com o nome. Se a v27 não instalou: Update software de novo (após o Deliver terminar).
2. **Recadastrar a digital do Diego Cardoso** em `/provas/admin` (com o leitor plugado no servidor e `continuar.ps1 leitor`).
3. **Enviar ao GitHub** o que mudou depois do commit `71c0d85`: botão Reiniciar (digital 1.2.2, `prova.sh`, `25-populos-digital`), Porto sem digital, anexo automático do leitor, `continuar.ps1`, este documento, lições/guia correspondentes. Use `continuar.ps1 push -Mensagem "..."` só quando o Wagner pedir.
4. **Portable01 (TV)** ainda na v5: entregar v19 e verificar espaço (partição `custom` de 2,1 GB; Chrome + uberAgent podem não caber).
5. **Menu do dual boot personalizado** (pedido de 28/10, foto de um cliente com "Choose how to start" / "Enterprise OS"): é o tema GRUB do pacote `bootloader` em `/boot/grub/themes/dualboot/` (`theme.txt`, `background.png`, `icons/{windows,elux}.png`, `select_*.png`); nomes das entradas e `set theme` vêm de `/usr/share/unicon/shell-lib/dualboot` (sed sobre `menuentry "Start eLux Normally"`). Pacote extraído em `C:\ScoutSetup\dualboot\x\`. Tempo/padrão oficiais: `/usr/sbin/dualboot-set-menu --default uniconos --timeout 20` (Scout) ou `UniconOSDualBoot.exe boot-menu --default uniconos --timeout 20` (Windows). **Risco:** o boot é medido no TPM (PCR 8/9); trocar os arquivos do GRUB pode impedir a abertura da partição criptografada. Aguardando o Wagner decidir (perguntar à Citrix/cliente; se seguir, testar só num aparelho reinstalável) e mandar marca, textos, imagem e tempo.
6. **SAP no UniconOS** (pergunta de 26/10, sem decisão): opções web (WebGUI/Fiori, sem espaço), Citrix (SAP GUI publicado) ou SAP GUI for Java empacotado (250–300 MB; não cabe sem tirar algo). Aguardando dados do SAP.
7. **Manutenção:** reinstalar o Notebook-Wagner sem dual-boot (resolve TPM e espaço); reduzir `scoutdb` de sysadmin; trocar senhas que passaram por chat no início do projeto; backup diário agendado do banco.

## 11. Script `C:\ScoutSetup\continuar.ps1`

| Comando | O que faz |
|---|---|
| `.\continuar.ps1` ou `status` | Serviços, WSL e containers, sites (provas, GLPI, ELIAS, Scout Board), leitor, tarefas, OUs/imagens, eLux, estado do repositório |
| `wsl` | Liga o WSL/Docker e o anexo do leitor (inicia as duas tarefas agendadas) |
| `leitor` | Anexa o leitor ao WSL agora e testa a abertura no container |
| `diag -Dispositivo <nome>` | Extrai o diagnóstico mais novo do eLux e mostra imagem em uso, logs de update, `provas.log`, uberAgent e journal |
| `arquivo -Ou <id> -Destino <caminho> -Arquivo <local>` | Regrava um arquivo de uma OU no banco (backup antes) e marca os eLux |
| `sync` | Copia scripts, site, manual, pacotes e este documento para o repositório, regenera o HISTORICO saneado e procura segredos (não envia) |
| `push -Mensagem "..."` | `sync` + commit + push, recusando se achar segredo |
| `manual` | Remonta e gera o manual em Word e PDF |

> **Atualização da retomada Codex — 28/10/2026:** status consultado no servidor: Notebook-Wagner atualmente na **Populos Dev (OU 10), DeliveryImage v24**, configuração em dia. Wagner pediu manter nessa OU por enquanto; teste Provas/v27 adiado. O diagnóstico disponível de 26/10 mostra v23 e falha antiga de galeria, sem comprovar a imagem instalada hoje. Galeria atual autenticada HTTP 200 e gzip íntegro; sete digitais cadastradas (IDs 2–8), todas uru4000/device_id 0, sem teste de identificação. Leitor USB do servidor ausente. Não houve alterações no banco nem envio ao GitHub. Detalhes registrados na seção 7.13 do diário.
> **OU HAPVIDA criada em 28/10/2026:** GroupID 13, SetupID 9, AD populos.local, imagem v22 e mesmos sete apps próprios/herança da Populos. Tema hapvida-v1 usa logo e wallpaper fornecidos. Fontes e script em Downloads. Backup verificado; nenhum dispositivo movido. Validar login e tema num eLux quando Wagner indicar o equipamento. Detalhes na seção 7.13 do diário.

> **Cores HAPVIDA (28/10):** tema atual hapvida-v2, accentColor #FF9800 (laranja dourado), gravado e verificado no Scout com backup prévio. Dois dispositivos atualmente na OU 13 marcados para receber; nenhum reinício enviado. Validar botão Logon e barra do boot após receber/ativar tema. Fontes em Downloads\hapvida-v2.

> **Simulador de saúde HAPVIDA (28/10):** instalado em http://10.5.0.166/hapvida/admin (admin; senha apenas no rótulo HAPVIDA admin do credenciais.txt). Código C:\ScoutSetup\hapvida, dados WSL /root/hapvida/data, container hapvida/3101. OU13/setup9: AD sem digital na entrada (DESATIVADO), dois apps de saúde: Cadastro de Pacientes (80) e Exames e Prontuário (79); sete apps anteriores mantidos. Imagem v29 pronta (v22+populos_hapvida 1.0.0, 3.627,86 MB); precisa Deliver completo seguido de Update no aparelho, sem comandos enviados pelo Codex. Cadastro com foto/digital própria e seis documentos fictícios automáticos. Backend e interface testados; reconhecimento físico e ciclo no eLux pendentes por ausência do leitor do servidor. README no projeto, detalhes no diário 7.13. Sync ainda não contempla novas fontes.

> **Cadastro HAPVIDA atualizado (28/10):** senha admin alterada a pedido do Wagner e aplicada/testada no container, sem valor no documento. Novo botão de câmera no cadastro novo e em pacientes existentes, com prévia/refazer/confirmar. No servidor usar http://localhost/hapvida/admin; no eLux, atalho administrativo recebeu exceção somente para origem interna no perfil separado para permitir câmera via HTTP. Cadastro/portal testados com câmera sintética; webcam real pendente. Há divergência observada entre chave central de aparelhos e chave de runtime; rotação de senha preservou runtime sem alterar chave dos eLux. Detalhes no diário 7.13.

> **Camera no UniconOS (28/10):** bloqueio HTTP relatado; ClientConfig ainda sem excecao e aparelhos pendentes de receber configuracao. App Cadastro (80) passou a usar perfil novo app-hapvida-camera, com excecao so para origem interna. Backup verificado antes. Receber configuracao/reiniciar eLux e reabrir o atalho para testar camera real; nenhum reboot enviado pelo Codex.

> **HAPVIDA Local criada (28/10):** OU14/setup10, sem AD por confirmação do Wagner, imagem v30 pronta no ELIAS (3.657,51 MB, sem conflitos/faltantes). Apps Cadastro de Pacientes (89) e Exames e Prontuário (88) executam no eLux com backend loopback 127.0.0.1:3131 e dados em /setup/hapvida-local/dados. Cada aparelho tem sua base; não houve cópia dos pacientes do servidor. Credencial inicial no rótulo HAPVIDA Local admin do arquivo central; aparelho recebe somente verificador PBKDF2. Testes offline e persistência passaram em ambiente isolado com Python oficial e payload do FPM; boot/leitor/webcam reais pendentes. Nenhum dispositivo movido. Para uso: mover escolhido à OU14, Deliver completo v30 e depois Update, recebendo a configuração. Fontes/README em C:\ScoutSetup\hapvida-local. Detalhes no diário 7.13.

> **OU BTG criada (29/10/2026):** OU 15/setup 11, imagem v35, sem Horizon. Detalhes, backup e testes na seção 7.13 do SCOUT-ELUX-GLOBAL.md. Senha do cadastro no rótulo BTG Local admin do credenciais.txt.

> **Word, Excel e PowerPoint web (30/10):** apps Edge --app para `{word,excel,powerpoint}.cloud.microsoft` com ícones globais `word/excel/powerpoint.png` em todas as OUs de uso (3–11, 13–15); fora: Lost & Found, Enterprise e Provas. Script `C:\ScoutSetup\scripts\apps-office-netskope-hapvida.ps1`.

> **Depois de importar qualquer pacote no ELIAS, rode `C:\ScoutSetup\scripts\reparar-idfs.ps1`.** A importação invalida as imagens já criadas, e os aparelhos recebem 404 no Update. Netskope atual: pacote 142.1.0.2831.4 nas imagens v43 (Populos), v44 (HAPVIDA) e v45 (HAPVIDA Local).
