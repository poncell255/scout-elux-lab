# Lições aprendidas (o que quebrou e como evitar)

1. **Gravou no banco e o eLux não pegou** → faltou `Device.SetupChanged/ApplicationsChanged=1`.
2. **Trocou imagem do tema e o eLux continuou com a antiga** → publique com nome novo (`tema-v2`).
3. **eLux trocou de OU e perdeu o papel de parede** → toda OU precisa de tema próprio; ao voltar, atualize `UCFT.TimeModified`.
4. **`Firmware.FormatBeforeUpdate=1` apagou a partição `custom`** (onde ficam Edge/Citrix/Horizon) e a atualização quebrou ("The idf has not been fully downloaded before formatting"). Não use; para limpar, Scout Board → Deliver software → *Complete software image delivered*.
5. **Partição update do eLux tem 3,75 GB**: imagens > ~3 GB falham no meio (erro 257/259). Tire o que não usa (ex.: Firefox se o Edge resolve).
6. **Citrix Workspace não abre**: precisa dos FPMs opcionais de Self-Service na imagem e da URL da loja; sem loja, use local `/usr/bin/selfservice`.
7. **Firefox não tem `--app`**: para apps web em janela própria use Edge (`--app=URL`).
8. **NAT loopback**: eLux na mesma rede usando o nome público → o Scout tenta o IP público e conecta em si mesmo (`SSL_Accept failed`). Solução: DNS local (split DNS).
9. **eLux fora da rede** (4G/CGNAT): registra e recebe config, mas comandos do Scout (reiniciar, mirror) não chegam sem VPN ou Scout Cloud Gateway.
10. **Roteador Vivo grava regra de porta como TCP** mesmo escolhendo UDP → use VPN em TCP.
11. **Cloudflare Tunnel exige saída 7844**; algumas redes bloqueiam (erro 530).
12. **Login OIDC do Scout Board não dá para fazer por script**: o navegador usa o código (uso único) ao abrir o callback.
13. **ELIAS 18 instalado em silêncio** deixa `server.json` com `server: Empty`.
14. **Scout Keep Alive** usa o banco do Scout, não um banco próprio.
15. **Mirror pelo Scout Board não respondia**: `webrtcify` no eLux dizia "mirror not enabled". `Setup.Mirror` é campo de bits e faltava o bit 0x1 (ativo). Ver DB-REFERENCE. Exige o pacote `mirror_server`.
16. **Nunca** cole senhas/tokens no chat de uma IA: foram expostos e precisaram ser revogados.
17. **Login AD no eLux com "unknown error"** teve três causas empilhadas, uma escondendo a outra: (a) eLux sem NTP com o relógio 3 h errado; (b) o **DC** 8 min atrasado (W32Time nem registrado e uma GPO forçando `NT5DS` no PDC raiz); (c) o Kerberos do eLux procura o KDC **só por SRV no DNS**, e o DHCP do Wi-Fi entregava o DNS do roteador. `/setup/hosts` não resolve (c); a solução foi `/setup/krb5.conf.d/populos.conf` com `kdc` fixo. Diagnóstico: `tmp/krb5.log` e `pam_krb5` no journal do pacote de diagnóstico.
18. **Diagnósticos do eLux** (comando do Scout Board) ficam no servidor em `C:\Users\Public\Documents\Unicon\Scout\Server\diag\`. Extraia com `tar -xf` (o `Expand-Archive` falha com nomes inválidos no Windows).
19. **Configuração que o Scout mandou de verdade**: `ClientConfig.ClientData` do `Device.ConfigDataIDToHave` (texto legível com `/setup/terminal.ini <seção> <chave> <valor>`). Melhor que adivinhar.
20. **Edge do eLux bloqueia toda extensão** (`ExtensionInstallBlocklist ["*"]` em `/usr/setup/microsoft-edge/managed/`, somente leitura). Para mexer em páginas de terceiros, use um proxy reverso que injeta script (IIS + ARR + URL Rewrite).
21. **Tela cheia por script**: o navegador só aceita `requestFullscreen()` com clique. O modo quiosque ocupa a tela, mas `document.fullscreenElement` fica vazio; se a página depende dele, simule (sobrescreva `fullscreenElement`/`requestFullscreen`).
22. **Duas placas NVIDIA no eLux**: com `nouveau` não há aceleração e a segunda placa não acende; com `nvidia_driver` a segunda entra como GPU auxiliar e também não acende. Precisa de `/setup/X11/xorg.conf.d/*.conf` com `BaseMosaic` (o eLux copia esse diretório sem alterar). Atualização com pacotes já entregues instala **no boot, offline**: a tela de boot fica ~20 min parada e o `UpdateInfo` mostra `261` até terminar.
23. **Monitores idênticos (mesmo EDID e serial) viram um só no eLux**: o serviço de monitores dá o mesmo UUID às 6 saídas e as clona em 0,0 sempre que reconfigura as telas. Solução de software: um script que refaz a grade com `xrandr` e reabre as janelas; de hardware: emulador de EDID por saída.
24. **Script vigiando a tela pode virar pisca-pisca**: se a verificação acusa erro sempre e a correção fecha janelas, fica em loop. Compare a posição real de cada saída e limite a frequência das correções.
25. **Home persistente e Edge**: o próprio pacote do Edge apaga `~/.config/microsoft-edge` no logout, antes de a home persistente ser gravada; além disso, a imagem precisa do FPM opcional `baseos_persistent_home`. Corrigido com pacote próprio (`uniconos-sdk/`).
26. **SDK da Unicon (`epkg`)** permite pacotes próprios: o ZIP vem por e-mail da Unicon; roda em Docker (WSL2 + Ubuntu 22.04 serve). Importação no ELIAS 18 por ZIP na API `/import/`.
27. **A home do UniconOS não executa programas**: extensões do VS Code com executável próprio (ex.: Claude Code) precisam de um wrapper em `/usr/bin`.
28. **SQL Express em "automático atrasado"** sobe depois do Scout Server no boot: o Scout fica preso iniciando. Deixe o SQL em automático sem atraso.
29. **Partições do eLux são fixas**: o tamanho vem da instalação (pendrive → `custom` de 3,75 GB). Confira `Device.PartitionInfo` antes de pôr pacotes grandes.
