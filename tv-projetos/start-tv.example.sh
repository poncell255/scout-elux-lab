#!/bin/bash
# TV Projetos (OU do Scout): 6 janelas do Edge em quiosque, uma por TV.
# Entregue pelo Scout em /setup/tv/start-tv.sh; o app "TV Projetos" roda: /bin/bash /setup/tv/start-tv.sh
# Hardware: 2x NVIDIA Quadro P620 em Base Mosaic (/setup/X11/xorg.conf.d/20-tv-mosaic.conf), ??rea 5760x2160.
# As p??ginas passam pelo proxy do IIS no Scout (porta 8090), que injeta /tv/tv.js:
# login autom??tico, aba do portf??lio e bot??o "Tela cheia".
PROXY="http://10.5.0.166:8090"
CRED="u=<usuario>&p=<senha-url-encoded>"
EDGE=/opt/microsoft/msedge/microsoft-edge

# Posi????o de cada sa??da: placa 1 (GPU-0) em cima, placa 2 (GPU-1) embaixo.
# As 6 TVs LG SIGNAGE t??m o mesmo EDID (at?? o n??mero de s??rie), ent??o o servi??o de monitores do eLux as trata
# como um monitor s?? (mesmo UUID em /setup/myscreens.xml) e as clona em 0,0 sempre que reconfigura as telas.
# O script refaz a grade e reabre as janelas quando isso acontece.
LAYOUT=(
  "GPU-0.DP-1 0x0"    "GPU-0.DP-5 1920x0"    "GPU-0.DP-7 3840x0"
  "GPU-1.DP-1 0x1080" "GPU-1.DP-5 1920x1080" "GPU-1.DP-7 3840x1080"
)
# O que cada TV mostra, pela posi????o na ??rea de 5760x2160: "x,y|p??gina|aba do portf??lio"
TELAS=(
  "0,0|portfolio-projetos.html|3"
  "0,1080|consultor-viagem.html|1"
  "1920,0|mapa-calor-projetos.html|1"
  "1920,1080|portfolio-projetos.html|2"
  "3840,0|time-projetos.html|1"
  "3840,1080|portfolio-projetos.html|1"
)
exec >>/tmp/tv-projetos.log 2>&1

# tela sempre ligada, mesmo sem ningu??m mexendo
xset s off -dpms s noblank 2>/dev/null

arrumarTelas() {
  local item saida pos
  local -a args=()
  for item in "${LAYOUT[@]}"; do
    saida="${item% *}"; pos="${item#* }"
    xrandr | grep -q "^$saida connected" || continue
    args+=(--output "$saida" --mode 1920x1080 --pos "$pos")
  done
  (( ${#args[@]} )) || { echo "$(date '+%F %T') nenhuma sa??da da grade conectada"; return 1; }
  if xrandr "${args[@]}"; then echo "$(date '+%F %T') layout aplicado"; else echo "$(date '+%F %T') xrandr falhou ($?)"; return 1; fi
}

fecharTodas() {
  local i
  for i in 0 1 2 3 4 5; do [[ -n ${PIDS[$i]} ]] && kill "${PIDS[$i]}" 2>/dev/null; done
  sleep 3
  PIDS=()
}

layoutCorreto() {
  # cada sa??da conectada precisa estar com 1920x1080 na posi????o da grade
  local item saida pos linha
  local estado
  estado="$(xrandr)"
  for item in "${LAYOUT[@]}"; do
    saida="${item% *}"; pos="${item#* }"
    linha="$(grep "^$saida connected" <<< "$estado")" || continue
    [[ $linha == *"1920x1080+${pos/x/+}"* ]] || return 1
  done
}

declare -a PIDS
abrir() {
  local i=$1
  local pos="${TELAS[$i]%%|*}" resto="${TELAS[$i]#*|}"
  local pag="${resto%|*}" aba="${resto#*|}"
  rm -rf "/tmp/tv-perfil-$i"
  "$EDGE" --user-data-dir="/tmp/tv-perfil-$i" --kiosk --no-first-run --no-default-browser-check \
    --noerrdialogs --disable-session-crashed-bubble --disable-features=Translate --password-store=basic \
    --enable-offline-auto-reload \
    --window-position="$pos" --window-size=1920,1080 \
    "$PROXY/$pag#tv&d=/$pag&$CRED&pg=$aba" &
  PIDS[$i]=$!
  echo "$(date '+%F %T') TV em $pos: $pag aba $aba (pid ${PIDS[$i]})"
}

# espera o servi??o de monitores do eLux terminar e ent??o aplica a grade
echo "$(date '+%F %T') in??cio do script"
sleep 15
layoutCorreto || { arrumarTelas; sleep 3; }
layoutCorreto && echo "$(date '+%F %T') grade ok" || { echo "$(date '+%F %T') grade ainda errada:"; xrandr | grep ' connected'; }
for i in 0 1 2 3 4 5; do abrir "$i"; sleep 2; done

# a cada 20 s: reabre a janela que fechar; se o eLux clonar as telas de novo, refaz a grade e reabre as janelas
# (quando as telas ficam clonadas a ??rea encolhe para 1920x1080 e o Edge puxa todas as janelas para 0,0)
ultimoAjuste=-999
while sleep 20; do
  if ! layoutCorreto && (( SECONDS - ultimoAjuste >= 40 )); then
    ultimoAjuste=$SECONDS
    echo "$(date '+%F %T') layout fora da grade:"; xrandr | grep ' connected'
    if arrumarTelas && sleep 3 && layoutCorreto; then
      echo "$(date '+%F %T') grade refeita, reabrindo as janelas"
      fecharTodas
    else
      echo "$(date '+%F %T') n??o consegui refazer a grade"
    fi
  fi
  for i in 0 1 2 3 4 5; do
    kill -0 "${PIDS[$i]}" 2>/dev/null || abrir "$i"
  done
done
