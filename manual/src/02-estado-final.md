# 2. Estado final do ambiente (23/10/2026)

Este capítulo é o "retrato" do que existe hoje. Use-o como referência durante a implantação e na manutenção.

## 2.1 Servidor SCOUTBOARD

| Item | Valor |
|---|---|
| Sistema | Windows Server 2025 Datacenter (10.0.26100), 8 GB RAM, 12 núcleos lógicos |
| Nome / domínio / IP | SCOUTBOARD / populos.local (DC POPAD01, 10.20.0.10) / 10.5.0.166 |
| Banco | SQL Server 2025 Express, instância `SQLEXPRESS`, TCP 1433, banco `ScoutEnterprise` |
| Scout | Scout Enterprise Management Suite 15.2609; Scout Board em `https://<servidor>:22160` com login Entra ID |
| Licença | Citrix License Server 11.17.2 ativado pela Citrix Cloud (LAS) |
| Imagens | ELIAS 18 em `http://<servidor>/ELIAS/`, container `UC_RP6_X64` |
| Linux auxiliar | WSL2 com Ubuntu 22.04: Docker com o SDK `epkg` da Unicon e o GLPI |
| GLPI | GLPI 12.0.0 em Docker no WSL, publicado em `http://10.5.0.166:8088` (portproxy → 8080), tarefa agendada "WSL GLPI" mantém o WSL ligado |
| Site extra no IIS | "TV Projetos", porta 8090 (proxy das páginas da parede de TVs) |

## 2.2 OUs

| OU | GroupID | Setup | Login | Imagem | Destaques |
|---|---|---|---|---|---|
| Lost & Found | 0, 1 | 0 | AD | v18 | Destino de eLux novos |
| Enterprise | 2 | 2 | AD | — | Criada pela instalação |
| FollowMeDesktop | 3 | 1 | AD | — | Criada pela instalação |
| Populos | 4 | 0 | AD | v18 | Outlook, Teams, Citrix, Horizon, Edge, Chrome; tema `populos-ou-v1` |
| POC-BCR | 5 | 0 | AD | v18 | — |
| Bom Jesus | 6 | 0 | AD | v18 | Mesmos apps da Populos; tema `bomjesus-v4` |
| Modo Kiosk | 7 | 4 | sem AD | v18 | Citrix em tela cheia, abre sozinho |
| Populos NonDomain | 8 | 3 | sem AD | v18 | Mesmos apps da Populos |
| TV Projetos | 9 | 5 | sem AD | v19 | Parede de 6 TVs, driver NVIDIA |
| Populos Dev | 10 | 6 | AD + digital | v21 | Home persistente, VS Code (web), OneDrive, digital como 2º fator |
| Porto | 11 | 7 | **só digital** | v20 | CXone, leitor de PDF, tema Porto, logo na tela do leitor |

Em todas as OUs: Microsoft Edge, Google Chrome, GLPI Agent (inventário), uberAgent (dois receptores), NTP, tela sempre ativa, 2 monitores clonados, mirror com controle e sem pedir permissão.

## 2.3 Imagens (ELIAS 18)

| Imagem | Composição | Tamanho | Setups |
|---|---|---|---|
| `populos-elux7-v18` | `migration-system` + Citrix (`ica`, `citrix_extensions`, `citrix_hdxrtme` e FPMs de Self-Service/Teams/USB/HDX) + Horizon + Edge + Chrome + `populos_glpi` + `uberagent` | 3.348 MB | 0, 3, 4 |
| `populos-elux7-v19` | v18 + `nvidia_driver` | 3.590 MB | 5 (TV) |
| `populos-elux7-v20` | v18 + `populos_digital` + `populos_ajustes` + `baseos_persistent_home` + `document_viewer` | 3.351 MB | 7 (Porto) |
| `populos-elux7-v21` | v18 + `populos_digital` + `populos_ajustes` + `baseos_persistent_home` | 3.349 MB | 6 (Populos Dev) |

Histórico: v4/v5 (base e TV), v7–v9 (pacotes do SDK), v11 (Porto), v12–v17 (Chrome e GLPI; v16/v17 sem o VS Code nativo, que não cabia), v18–v21 (uberAgent).

> **Limite de tamanho:** eLux instalado por pendrive ou em notebook dual-boot tem a raiz com cerca de 3,7 GB. Imagens acima de ~3,6 GB falham com "image size will exceed media size" (erro 254). Confira sempre o tamanho que o ELIAS informa antes de publicar.

## 2.4 Pacotes próprios (SDK da Unicon)

| EPM | Versão | O que faz |
|---|---|---|
| `populos_digital` | 1.1.1 | Impressão digital (leitor DigitalPersona U.are.U 4500): 2º fator depois do AD, ou entrada só com a digital nas OUs sem AD; logo e cor por OU |
| `populos_ajustes` | 1.0.2 | Edge mantém o perfil com home persistente; wrapper para a extensão do Claude Code no VS Code |
| `populos_vscode` | 1.0 | VS Code nativo (fora das imagens atuais por falta de espaço) |
| `populos_glpi` | 1.21.0 | GLPI Agent 1.21 com timer de inventário |

## 2.5 Integrações

| Integração | Como funciona | Onde conferir |
|---|---|---|
| Inventário GLPI | Agente no eLux envia 3–8 min após o boot e a cada 4 h para `http://10.5.0.166:8088`, autenticação Basic (usuário `elux`) | GLPI → Ativos → Computadores |
| uberAgent | Envia cada evento para dois receptores Splunk HEC: PopulosUXM (`http://10.30.0.99:3001`) e PopulosAnalytics (`http://10.5.1.4:3001`) | Painéis `https://10.30.0.99:3001` e `https://10.5.1.4:3001` |
| Entra ID | Login do Scout Board | Portal Entra → Enterprise Applications |
| Citrix Cloud | Licença (LAS) e loja Citrix Workspace | citrix.cloud.com |

## 2.6 Dispositivos de referência

| Dispositivo | OU | Observação |
|---|---|---|
| Portable01 (10.5.0.14) | TV Projetos | eLux de pendrive; partição pequena |
| eLux9252-5843-1894 (10.5.0.177) | Populos NonDomain | Dell com disco grande |
| Notebook-Wagner (10.5.1.4) | Porto | Dual-boot com Windows e partição criptografada no TPM; o lado Windows é o servidor uberAgent B |
