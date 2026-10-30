# Comece aqui — recriar este projeto em outro ambiente (para agentes de IA)

> Este é o ponto de entrada para um agente de IA, ou uma pessoa, que precisa **recriar o projeto do zero** num ambiente novo, ou **continuar** o laboratório. Ele explica o projeto, a ordem de leitura e o modelo mental. Os passos detalhados ficam nos documentos citados.
>
> Estado descrito: **30/10/2026**. Laboratório original: POPULOS, servidor `SCOUTBOARD` (10.5.0.166).

---

## 1. O projeto em uma página

O projeto gerencia **thin clients Citrix UniconOS (eLux 7.2609)** a partir de um único Windows Server com:

- **Citrix UniconOS Management (Scout Enterprise 15.2609):** registro dos aparelhos, OUs, configuração, apps e comandos. Fica no SQL Server Express, banco `ScoutEnterprise`.
- **ELIAS 18:** monta as **imagens de firmware** (`.idf`) a partir do catálogo de pacotes (EPM/FPM) e as serve por IIS.
- **SDK da Unicon (`epkg`, em Docker no WSL2):** pacotes próprios (`populos_*`), por exemplo digital, GLPI Agent, Teams for Linux, Netskope e os sistemas locais.
- **Serviços de apoio no WSL/Docker do mesmo servidor:**
  - GLPI (inventário);
  - site da sala de provas;
  - simulador HAPVIDA;
  - **Populos UniconOS SDK** (conversor web de `.deb`/drivers para EPM/FPM, que também cria imagens).

Resultado entregue:
- 16 OUs, cada uma com tema (papel de parede e logo no boot), apps e login próprios (AD/Kerberos, sem login, ou digital).
- Quiosque Citrix e parede de 6 TVs com NVIDIA Base Mosaic.
- Sala de provas com digital.
- Sistemas "locais" que rodam **dentro do eLux**, sem servidor: HAPVIDA Local, BTG e Porto, com Flask em loopback, câmera e digital.
- Netskope, uberAgent com dois receptores, GLPI Agent, Chrome, Edge, Teams for Linux, Word/Excel/PowerPoint web e AVD.

---

## 2. Modelo mental (leia antes de mexer em qualquer coisa)

```
                 ┌──────────── o que o aparelho TEM (software) ────────────┐
 SDK epkg ──► EPM/FPM ──import──► ELIAS 18 ──monta──► imagem vN.idf ──IIS──► eLux (Deliver + Update)
                                                          ▲
                 ┌──────────── o que o aparelho FAZ (configuração) ────────┐
 Script PowerShell ──SQL──► banco ScoutEnterprise ──Scout Server──► eLux (no boot/refresh)
   (Setup, Groups, Application, Local, UCFT/FileEntry)    Setup.ImageFile diz qual vN.idf a OU usa
```

1. **Software e configuração são caminhos separados.**
   - Um programa só existe no eLux se o pacote estiver **na imagem** da OU.
   - Um app (atalho), um arquivo em `/setup/...`, o tema, o tipo de login e a imagem a usar vêm do **banco do Scout**.
2. **Quase tudo foi feito direto no banco**, porque o login OIDC do Scout Board não pode ser automatizado. Cada alteração segue o mesmo ciclo:
   1. backup;
   2. uma transação;
   3. `UPDATE Device SET SetupChanged=1, ApplicationsChanged=1 WHERE GroupID=<OU>`;
   4. reiniciar o eLux.

   As tabelas estão em [DB-REFERENCE.md](DB-REFERENCE.md).
3. **Arquivos para o eLux** ficam no banco: `UCFT` guarda o conteúdo e `FileEntry` o destino. Mudar o arquivo no disco do servidor não muda nada no aparelho.
4. **O eLux é quase todo somente leitura:**
   - `/opt`, `/etc`, `/var` e `/home/elux` ficam em RAM e se perdem no reboot;
   - **`/setup` é persistente**, mas pequeno;
   - a home não executa programas;
   - o shell é busybox;
   - a raiz instalada por pendrive ou dual-boot tem **~3.700 MB**, e uma imagem maior que isso falha (erro 254).
5. **Imagem nova** é sempre "imagem anterior + pacotes − pacotes" (`scripts/imagem-derivada.ps1`). No Scout Board, rode **Deliver software**, espere terminar, depois **Update software** e reinicie.
6. **Importar qualquer pacote no ELIAS quebra as imagens que já existem:** elas passam a dar 404. Rode `scripts/reparar-idfs.ps1` logo depois (Fase 26 do guia).

---

## 3. Ordem de leitura

| # | Documento | Para quê |
|---|---|---|
| 1 | Este arquivo | Visão, modelo mental, mapa |
| 2 | [GUIA-IMPLANTACAO.md](GUIA-IMPLANTACAO.md) | **Passo a passo completo**, fases 1–31, com validação e problemas |
| 3 | [LICOES.md](LICOES.md) | Armadilhas (leia todas antes de começar: cada uma custou horas) |
| 4 | [DB-REFERENCE.md](DB-REFERENCE.md) | Tabelas e códigos do banco do Scout, que a Citrix não documenta |
| 5 | READMEs dos subprojetos | `uniconos-sdk/`, `conversor/`, `apps-locais/*/`, `apps-servidor/hapvida/`, `provas/`, `tv-projetos/` |
| 6 | [CONTINUAR-COM-CODEX.md](CONTINUAR-COM-CODEX.md) | Estado vivo do laboratório original: IDs, imagens, aparelhos, pendências |
| 7 | [HISTORICO.md](HISTORICO.md) | Diário completo, com cada tentativa e erro (consulte quando um passo do guia falhar) |
| — | [RUNBOOK.md](RUNBOOK.md) | Versão curta do guia |

---

## 4. Mapa do repositório

| Pasta | Conteúdo |
|---|---|
| `scripts/` | PowerShell que grava no banco do Scout e no ELIAS: OUs, apps, temas, imagens, AD, NTP, uberAgent, Office, reparo de imagens. `continuar.ps1` é o canivete de operação |
| `uniconos-sdk/` | Fontes e scripts `NN-*.sh` (rodam no WSL) dos pacotes `populos_digital`, `populos_ajustes`, `populos_glpi`, `populos_teams` e `populos_vscode`, além do GLPI em Docker e do manual |
| `conversor/` | **Populos UniconOS SDK**: Flask + waitress no WSL (porta 3200, IIS `/conversor`). Converte `.deb`/`.AppImage`/`.run`/`.tar` em EPM/FPM, analisa drivers e cria a imagem no ELIAS |
| `apps-locais/hapvida-local`, `btg-local`, `porto-local` | Sistemas que rodam no eLux: Flask em `127.0.0.1:3131/3132/3133`, telas GTK de digital, launchers, systemd, build/import/criação da OU |
| `apps-locais/netskope-elux` | Netskope Client empacotado do `.run` oficial, com persistência do cadastro em `/setup` |
| `apps-servidor/hapvida` | Simulador de saúde HAPVIDA no servidor (Docker `hapvida`, IIS `/hapvida`) usado pela OU HAPVIDA |
| `provas/` | Site da sala de provas (Docker, IIS `/provas`) e o `prova.sh` do eLux |
| `tv-projetos/` | Parede de 6 TVs: proxy IIS 8090, `start-tv.sh`, Xorg Base Mosaic |
| `assets/themes/`, `assets/icons/` | Temas eLux (`config.json` + 4 PNGs) e ícones 32x32 |
| `manual/` | Manual Word/PDF e suas fontes |
| `config/parametros.example.ps1` | Valores que mudam de um ambiente para outro |
| `docs/` | Este guia, o guia completo, as lições, a referência do banco, o runbook e o histórico |

---

## 5. Recriar: do zero ao projeto completo

Siga o [guia](GUIA-IMPLANTACAO.md) na ordem. A tabela mostra o que cada bloco entrega e o que ele exige antes.

| Fases | Entrega | Depende de |
|---|---|---|
| 1–5 | Windows Server, SQL Express, Scout, licença Citrix (LAS), Scout Board com Entra ID | Mídias da Citrix, tenant Entra |
| 6–7 | ELIAS 18, primeira imagem, primeiro eLux registrado | Fases 1–5, `eLux-7.2609.0_AllPackages` importado |
| 8 | **Como gravar no banco** (base de todo o resto) | — |
| 9–10 | Temas por OU; apps (Edge `--app`, Citrix StoreFront, Horizon) | 8 |
| 11–12 | Login AD/Kerberos nos eLux; OUs com setup próprio (sem AD, quiosque) | Servidor no domínio, NTP no DC |
| 13–17 | Mirror, energia, monitores, quiosque, home persistente, 6 TVs, acesso externo | 8–12 |
| 18 | **Ambiente do SDK** (WSL2 + Docker + `epkg`) e pacotes próprios | SDK enviado pela Unicon por e-mail |
| 19–23 | OU só com digital, GLPI + Chrome, uberAgent, Teams for Linux, sala de provas | 18 |
| 24–25 | Simulador HAPVIDA no servidor; Netskope | 18 |
| 26 | **Reparo das imagens depois de importar pacote** (rotina obrigatória) | 6 |
| 27 | Sistemas locais no eLux (HAPVIDA Local, BTG, Porto) | 18, 26 |
| 28 | Word/Excel/PowerPoint web em todas as OUs | 10 |
| 29 | Citrix Workspace com home persistente (gnome-keyring) | 15 |
| 30 | **Populos UniconOS SDK** (conversor web + criação de imagem) | 18, 26 |
| 31 | Operação: `continuar.ps1`, mapa de imagens, GitHub sem segredos | — |

**Adaptar ao ambiente novo:**
- Os scripts têm valores do laboratório: IP `10.5.0.166`, container ELIAS `UC_RP6_X64`, domínio `populos.local`, DC `10.20.0.10`, caminhos `C:\ScoutSetup`, `C:\UniconSDK` e `C:\eLuxContainer`, e **GroupID/SetupID fixos** (por exemplo, OU 14 = HAPVIDA Local).
- Antes de rodar um script num banco novo:
  - leia o cabeçalho do script;
  - troque os IDs pelos que a sua criação de OU devolveu;
  - confira os `ApplicationID` (`MAX()+1`).
- Os scripts que criam OU recusam rodar duas vezes. Não "force".
- Os parâmetros gerais ficam em `config/parametros.example.ps1`.

---

## 6. Segredos

- Nenhuma senha, token ou chave está no repositório. Eles viraram marcadores `<ASSIM>`.
- No servidor, todos ficam em **`C:\ScoutSetup\credenciais.txt`**: uma linha `Rótulo / valor` por item, com ACL só para Administradores e SYSTEM. Os scripts leem pelo rótulo, por exemplo `(... -split ' / ',2)[1]`.
- Rótulos usados:

  | Grupo | Rótulos |
  |---|---|
  | Banco, ELIAS e Scout | `SQL sa`, `ELIAS 18 (web)` |
  | GLPI | `GLPI DB`, `GLPI admin`, `GLPI inventario` |
  | uberAgent | `uberAgent HEC 10.30.0.99`, `uberAgent HEC 10.5.1.4` |
  | Sala de provas | `Provas admin`, `Provas chave dos eLux` |
  | HAPVIDA | `HAPVIDA admin`, `HAPVIDA chave dos eLux`, `HAPVIDA Local admin` |
  | BTG e Porto | `BTG Local admin`, `Porto Local admin` |
  | Netskope | `Netskope instalador OU Populos` |
  | SDK | `Conversor Unicon admin` |

  No ambiente novo, gere valores novos e grave com os mesmos rótulos.
- `C:\ScoutSetup\saneamento.txt` (fora do Git) tem pares `regex => troca`. O `continuar.ps1 sync` usa esses pares para tirar e-mails, IDs do tenant e valores sensíveis do diário antes de publicar, e procura esses valores em todo o repositório.
- Segredo **nunca vai na imagem**. Vai como arquivo da OU (`FileEntry`), por exemplo `/setup/glpi-agent/auth`, `/setup/netskope/instalador` ou `/setup/provas/chave`. Senha de admin dos sistemas locais vai como verificador PBKDF2, nunca em texto.
- **Nunca cole segredo no chat de uma IA.** No projeto original isso aconteceu e os segredos tiveram de ser trocados.

---

## 7. Regras de trabalho para o agente

1. Responda e documente em **português do Brasil**.
2. **Backup do banco antes de cada alteração:**
   ```sql
   BACKUP DATABASE [ScoutEnterprise] TO DISK=N'C:\ScoutSetup\backup\ScoutEnterprise-pre-<assunto>-<data>.bak' WITH INIT, COPY_ONLY, CHECKSUM
   ```
   Depois rode `RESTORE VERIFYONLY`. Faça uma transação por alteração e marque os aparelhos no fim.
3. **Registre cada passo num diário vivo.** No laboratório é `Downloads\SCOUT-ELUX-GLOBAL.md`, seção 7.13, que vira `docs/HISTORICO.md` saneado.
4. **Confirme com o dono antes de ações difíceis de desfazer ou visíveis para fora:**
   - formatar ou reinstalar eLux;
   - apagar dados;
   - abrir portas;
   - criar tarefas agendadas;
   - publicar no GitHub;
   - mover aparelhos.
5. **Não invente resultado.** Se não testou num eLux de verdade, diga "não testado no aparelho". Prévia em Xvfb ou teste com `--network none` não prova hardware.
6. **GitHub** só quando o dono pedir, sempre por `continuar.ps1 push -Mensagem "..."`. Ele faz `sync`, procura segredos e se recusa a enviar se achar algum.
7. **Arquivos e scripts:**
   - `.ps1` com acento deve ser salvo em UTF-8 **com BOM** (o PowerShell 5.1 lê sem BOM como ANSI);
   - `.sh` que vai para o Linux deve usar LF;
   - não passe comandos com aspas ou `$` por `wsl -- bash -c`: escreva um `.sh` e rode com `wsl -d Ubuntu-22.04 -u root -- bash /mnt/c/.../x.sh`.

---

## 8. As armadilhas que mais custaram (lista completa em LICOES.md)

1. Gravou no banco e nada mudou: faltou `SetupChanged/ApplicationsChanged=1`, ou o arquivo ficou com o mesmo `UCFT.TimeModified` (epoch **UTC**).
2. O tema não troca: o eLux usa cache, então toda troca precisa de **nome de tema novo** (`-v2`, `-v3`...).
3. Imagem acima de ~3.700 MB falha com o erro 254. Some o tamanho no ELIAS antes de publicar.
4. Rodar **Update antes de o Deliver terminar** não instala nada.
5. Importar pacote no ELIAS deixa todas as imagens antigas em 404. Rode `reparar-idfs.ps1` (Fase 26).
6. `FormatBeforeUpdate=1` apaga a partição `custom` e quebra o eLux.
7. Login AD com "unknown error" tem três causas empilhadas:
   - a hora do eLux;
   - a hora do DC;
   - o KDC, que só é achado por SRV no DNS (use `krb5.conf.d` com `kdc` fixo).
8. App local com `AppOnDesktop=0` não abre sozinho.
9. O Edge do pacote apaga o perfil no logout. Com home persistente, use o pacote `populos_ajustes`.
10. O `tr` do busybox não entende `[:space:]`.
11. `login.d` é lido com `source`: use `return`, não `exit`.
12. WSL desliga quando fica ocioso e derruba Docker, GLPI, provas e conversor. Use `.wslconfig vmIdleTimeout=-1` e uma tarefa no boot com `sleep infinity`.
13. A interoperabilidade Windows (`powershell.exe`) **não funciona** dentro de serviços systemd do WSL. Por isso o SDK fala com a API do ELIAS em Python.
14. No `epkg`, o nome do FPM ≠ nome do EPM, `.install` lista arquivo por arquivo, e não use `%` nos nomes.
15. `.run`/`postinst` não rodam no eLux. Instale a árvore em `/opt` e adapte os scripts, como foi feito no Netskope.
16. Programas que gravam em `/usr` ou `/opt` em tempo de execução precisam de outro caminho persistente: `/setup/...` com `tmpfiles.d`, ou restaurar e salvar como o Netskope faz.
17. O Citrix Workspace com home persistente parece precisar do Secret Service, o FPM `desktop_environment_gnome_keyring` (Fase 29, **ainda não validado no aparelho**).
18. Câmera em página HTTP remota é bloqueada. Use loopback (sistemas locais) ou HTTPS. A exceção `--unsafely-treat-insecure-origin-as-secure` só para a origem interna.
19. Diagnóstico do eLux: extraia com `tar -xf`, não com `Expand-Archive`. A configuração real que o Scout mandou está em `ClientConfig.ClientData`, lido como Latin-1.

---

## 9. Estado do laboratório em 30/10/2026

| OU (GroupID) | Setup | Login | Imagem | Destaques |
|---|---|---|---|---|
| Lost & Found (0/1) | 0 | AD | v22 | Destino de eLux novos |
| Enterprise (2), FollowMeDesktop (3) | 2 / 1 | AD | — | Raiz herdada, sem aparelhos |
| Populos (4) | 12 | AD | v43 | Apps padrão, Teams for Linux, **Netskope** |
| POC-BCR (5), Bom Jesus (6) | 0 | AD | v22 | Apps padrão |
| Modo Kiosk (7) | 4 | sem | v22 | Citrix em tela cheia |
| Populos NonDomain (8) | 3 | sem | v22 | — |
| TV Projetos (9) | 5 | sem | v19 | 6 TVs, NVIDIA |
| Populos Dev (10) | 6 | AD + digital | v33 | Home persistente, VS Code, OneDrive |
| Porto (11) | 7 | sem | v36 | Tema porto-v2, CXone, sistema local Porto (3133) |
| Provas (12) | 8 | digital | v32 | App único "Prova" |
| HAPVIDA (13) | 9 | AD | v44 | Simulador HAPVIDA no servidor, Netskope |
| HAPVIDA Local (14) | 10 | sem | v46 | Sistema local (3131), tema hapvida-v4, Netskope, gnome-keyring para o Citrix |
| BTG (15) | 11 | sem | v35 | Tema btg-v1, AVD, sistema local BTG (3132) |

O que ainda **não foi validado num aparelho**, e por isso não deve ser dado como funcionando:
- Citrix na HAPVIDA Local com a v46;
- a digital física nos sistemas locais (o leitor do servidor esteve ausente);
- a webcam real;
- o pacote LibreOffice (o primeiro ficou quebrado e precisa ser convertido de novo, e não cabe sem tirar Chrome ou Teams).

A lista viva está em [CONTINUAR-COM-CODEX.md](CONTINUAR-COM-CODEX.md), seção 10.

---

## 10. Prompt sugerido para iniciar outro agente

```text
Você vai recriar (ou continuar) o projeto Scout Enterprise + ELIAS 18 + UniconOS (eLux 7) descrito no repositório
scout-elux-lab. Leia docs/COMECE-AQUI-IA.md inteiro, depois docs/LICOES.md e a fase do docs/GUIA-IMPLANTACAO.md que for
executar. Regras: responda em português; segredos só em C:\ScoutSetup\credenciais.txt (nunca no chat, nos docs ou no Git);
backup do banco ScoutEnterprise antes de cada alteração, uma transação, e marque SetupChanged/ApplicationsChanged;
confirme comigo antes de ações difíceis de desfazer; registre cada passo no diário; não diga que funcionou sem testar no
eLux. Ambiente novo: <IP do servidor>, <domínio/DC>, <container ELIAS>, <tenant Entra>. Comece pela Fase <N>.
```

---

## 11. Verificação rápida de um ambiente recriado

- [ ] `continuar.ps1 status` mostra:
  - os serviços do Scout, SQL, ELIAS, MongoDB e IIS;
  - WSL e Docker com os containers `glpi`, `glpi-db`, `provas` e `hapvida`;
  - o serviço systemd `conversor-unicon` no WSL.
- [ ] O Scout Board abre com Entra ID; o ELIAS 18 abre; `GET /ELIAS/<container>/<imagem>.idf` responde 200 para **cada** imagem em uso (`reparar-idfs.ps1` diz "já entregue (200)").
- [ ] Um eLux registra, cai na OU certa, recebe tema e apps, e `Device.ConfigDataID = ConfigDataIDToHave`.
- [ ] O login AD funciona numa OU com AD, e uma OU sem AD entra direto.
- [ ] O GLPI recebe o inventário em até 8 minutos e o uberAgent aparece nos dois receptores.
- [ ] `http://<servidor>/conversor/` converte um `.deb` pequeno de ponta a ponta (`conversor/tests/teste_fluxo.py`).
- [ ] `continuar.ps1 sync` informa "valores do credenciais.txt encontrados no repositório: 0".
