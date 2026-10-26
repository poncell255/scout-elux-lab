# Sala de provas com impressão digital (OU "Provas")

O aluno coloca a digital no eLux e a prova dele abre em quiosque, com nome, tempo de 60 minutos e nota no fim. As digitais são cadastradas antes, pelo site, no leitor do servidor. Passo a passo de implantação: Fase 23 do [guia](../docs/GUIA-IMPLANTACAO.md).

## Estrutura

| Caminho | O que é |
|---|---|
| `app/app.py` | Site (Flask + waitress): administração, API do eLux e a prova |
| `app/questoes/*.json` | Provas: Citrix DaaS/CVAD e Nutanix, 60 questões cada, em 6 domínios (`d` domínio, `q` enunciado, `o` opções, `c` índices corretos) |
| `app/web/` | Páginas: `admin.html` (cadastro, captura da digital, resultados), `prova.html` (prova), `inicio.html` |
| `app/cadastro/cadastrar-digital.c` | Captura pela libfprint (mesmo formato do `populos-digital` no eLux): id em `username`, nome em `description` |
| `app/cadastro/ler-digital.c` | Mostra driver, device id, id e nome de um `.fpr` |
| `app/Dockerfile` | Ubuntu 22.04 + libfprint 1.94.3 + Flask |
| `elux/prova.sh` | Ciclo no eLux, entregue pelo Scout em `/setup/provas/prova.sh` |

## Rotas

| Rota | Quem usa | Proteção |
|---|---|---|
| `/provas/admin` e `/provas/admin/api/...` | Administrador | HTTP Basic (`admin` + `PROVAS_ADMIN`) |
| `GET /provas/api/galeria` | eLux: `.tar.gz` com `<id>.fpr` dos alunos com prova pendente | Cabeçalho `X-Provas-Chave` |
| `POST /provas/api/sessao` (`aluno`, `dispositivo`) | eLux: devolve o token da prova (retoma a que estiver aberta) | `X-Provas-Chave` |
| `GET /provas/api/sessao/<token>/estado` | eLux: `aberta`, `andamento`, `finalizada` ou `sair` | `X-Provas-Chave` |
| `/provas/p/<token>` (+ `/dados`, `/iniciar`, `/responder`, `/finalizar`, `/sair`) | Navegador do aluno | Token aleatório da sessão |

Regras da prova: questões e alternativas embaralhadas por aluno; o tempo é do servidor (a prova é corrigida sozinha quando acaba); aprovação 70% (`aprovacao` no JSON); quem terminou não abre de novo até o administrador clicar "Liberar nova tentativa".

## Segredos

`PROVAS_ADMIN` e `PROVAS_CHAVE` ficam no `credenciais.txt` do servidor e em `/root/provas/.env` no WSL (fora do Git). A chave vai para os eLux por FileEntry (`/setup/provas/chave`), nunca na imagem.
