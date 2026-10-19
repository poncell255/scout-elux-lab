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
15. **Mirror pelo Scout Board** usa WebRTC; nos testes o eLux não respondeu à oferta SDP (ainda em investigação). O Scout exige o pacote `mirror_server` no eLux.
16. **Nunca** cole senhas/tokens no chat de uma IA: foram expostos e precisaram ser revogados.
