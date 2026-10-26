---
title: "Manual de Implantação"
subtitle: "Citrix UniconOS Management (Scout Enterprise) + ELIAS 18 + UniconOS/eLux 7 — do download à operação"
author: "POPULOS — Infraestrutura"
date: "Outubro de 2026"
lang: pt-BR
---

# Apresentação

Este manual descreve, passo a passo, como montar do zero o ambiente de gerenciamento de thin clients **UniconOS (eLux 7)** que a POPULOS implantou no servidor **SCOUTBOARD** entre 15 e 23/10/2026. Ele cobre desde o download das mídias até tudo o que está em produção hoje: imagens de firmware, login no Active Directory, OUs com configuração própria, quiosque Citrix, parede de 6 TVs, pacotes próprios feitos com o SDK da Unicon (digital, ajustes, GLPI Agent), inventário no GLPI, Google Chrome e uberAgent enviando para dois servidores.

## Para quem é

Analista de infraestrutura que vai repetir a implantação em outro servidor ou dar manutenção neste. O manual pressupõe familiaridade com Windows Server, SQL Server, IIS, Active Directory e PowerShell. Não pressupõe conhecimento prévio de Scout, ELIAS ou eLux.

## Como usar

1. Leia os capítulos 1 a 3 (visão geral, downloads e estado final) para entender o que vai montar.
2. Execute as fases na ordem. Cada fase traz o objetivo, os passos, a validação e as armadilhas que já aconteceram.
3. Antes de alterar qualquer coisa, leia as **Regras de trabalho** (capítulo 6). Elas evitaram a maior parte do retrabalho no projeto original.
4. Quando algo der errado, vá direto à **Tabela de problemas e soluções** e às **Lições aprendidas** (anexos).

## Convenções

| Convenção | Significado |
|---|---|
| `<ASSIM>` | Valor que muda de um ambiente para outro (senha, IP, ID). Nunca escreva senhas em documentos |
| `C:\ScoutSetup\credenciais.txt` | Único lugar onde ficam as senhas e tokens, uma linha por item no formato `Nome / valor`, acesso só de Administradores e SYSTEM |
| Scripts `scripts\*.ps1` | Ficam em `C:\ScoutSetup\scripts` no servidor e na pasta `scripts/` do repositório GitHub `poncell255/scout-elux-lab` |
| Scripts `NN-*.sh` | Rodam no Linux do WSL; ficam em `C:\UniconSDK\scripts` (no repositório, `uniconos-sdk/scripts/`) |
| Valores do laboratório | Aparecem como exemplo (servidor 10.5.0.166, domínio populos.local). Troque pelos do seu ambiente |

## Onde estão os arquivos de apoio

| O quê | Onde |
|---|---|
| Repositório com scripts, temas, ícones e fontes | `C:\ScoutSetup\repo-github` (GitHub `poncell255/scout-elux-lab`) |
| Documento vivo da implantação (diário completo) | `C:\Users\Administrator\Downloads\SCOUT-ELUX-GLOBAL.md` |
| Fontes dos pacotes do SDK | `C:\UniconSDK\pkgs\`, saídas em `C:\UniconSDK\saida\` |
| Temas eLux | `C:\eLuxContainer\theme\<tema>\` |
| Backups do banco do Scout | `C:\ScoutSetup\backup\` |
