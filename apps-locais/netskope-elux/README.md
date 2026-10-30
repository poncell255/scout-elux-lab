# Netskope Client no eLux (OU Populos)

Pacote **populos_netskope 142.1.0.2831.3**, gerado do instalador oficial `NSClient_*.run` 142.1.0.2831. Vai na imagem **populos-elux7-v40** (3.694 MB = v22 + `populos_netskope` + `systemlibs_libindicator3` + `libdbusmenu`). Está só na OU **Populos** (GroupID 4), que ganhou o **setup 12**, uma cópia do setup 0.

- **Cadastro:** o nome do `.run` traz o tenant e o token de convite de **um usuário**. Ele não está no pacote: vai como arquivo da OU em `/setup/netskope/instalador`, e o mesmo valor fica em `C:\ScoutSetup\credenciais.txt` (rótulo "Netskope instalador OU Populos").
- **Persistência:** `/opt` é RAM no eLux, então o cadastro é guardado em `/setup/netskope-estado`:
  - na parada do `stagentd`;
  - pelo `netskope-salvar.timer`.
  No boot seguinte ele é restaurado, e o aparelho não se cadastra de novo.
- **Na tela:** ícone da Netskope na bandeja do MATE.
  - Colorido = ativo; cinza = desativado.
  - Clicando, mostra o status. O comando `nsclient` também está disponível.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `elux/stagentd.service` | Serviço com `ExecCondition` (só roda com instalador ou estado), restauração/cadastro antes e salvamento depois |
| `elux/netskope-estado.sh` | `preparar` (restaura ou cadastra, até 24 tentativas de 5 s) e `salvar` |
| `elux/netskope-salvar.{service,timer}` | Salva o cadastro 3 min depois do boot e a cada 10 min (só grava se mudou) |
| `elux/diag-netskope` | Vai para `/usr/share/diagnostic/commands.d/populos_netskope-status`: status, rede, iptables e os logs do Netskope no diagnóstico do Scout |
| `elux/stagentapp.desktop`, `elux/stagentui.desktop`, `elux/iniciar-usuario.sh` | Autostart do agente do usuário e do ícone (no lugar do `systemctl --user` do instalador); esperam o `stagentd` e o socket `svc`, senão o serviço não vê a sessão e não habilita |
| `deploy/build-package.sh [versão]` | Extrai o `.run`, monta e compila o EPM/FPM no WSL e confere que o token não foi para o pacote |
| `deploy/test-package.sh [versão]` | Confere o FPM (executáveis, serviço e timer habilitados, autostart, sem token) |
| `deploy/import-package.ps1` | Importa no ELIAS |
| `deploy/configurar-ou-populos.ps1` | Aplicado em 29/10/2026 (backup antes): setup 12 para a OU Populos, imagem v37, arquivo do instalador. Não roda de novo |

Ajustes de eLux (.2): `ip6tables` → `xtables-nft-multi` (o eLux só traz iptables) e `/usr/local/share/ca-certificates` → `/var/lib/netskope/ca-certificates` (`/usr` é somente leitura). O `nsdiag` (coleta de logs para o suporte Netskope) ficou fora para a imagem caber em 3.700 MB.

## Testar num aparelho

1. Mova o eLux para a OU **Populos** no Scout.
2. Clique em **Deliver software**, espere terminar e clique em **Update software**.
3. Reinicie. Em 1 a 2 minutos o ícone da Netskope aparece na bandeja.
4. Confira o aparelho no console da Netskope (Devices).

Se o ícone não aparecer ou o cliente não habilitar, gere um diagnóstico. O que olhar:
- `var/log/unicon/diags-*/diagnostic-commands/populos_netskope-status.log`;
- `journalctl -u stagentd`, com as linhas `netskope-estado:`;
- `/opt/netskope/stagent/logs/`.
