#!/bin/sh
# Coop da v2, etapa 1: duas instâncias headless na mesma máquina (anfitrião e cliente, porta 7777). Cada uma roda o bot (anda, golpeia, anda
# de volta e para) e registra no fim a própria posição e o contador de golpes (`coop: local_final`) e o que viu do outro (`coop: remoto_final`).
# Passa se, nas duas direções, a posição bate (< 1 px, o herói parou nos últimos 2 s) e a contagem de golpes vistos é igual à de golpes dados
# (e maior que zero), e se não houve SCRIPT ERROR. Imprime a banda em KB/s de cada ponta e "COOP_MOVIMENTO falhas=0" no fim.
# Uso (dentro de jogos/hordas/projeto): GODOT=<console.exe> sh testes/coop_movimento.sh   (leva uns 20 s; ferramentas/testes_ci.sh não o roda)
G=${GODOT:-C:/Dev/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe}
T=${TMPDIR:-/tmp}
rm -f "$T/coop_host.log" "$T/coop_join.log"
timeout 120 "$G" --headless --path . res://v2/mundo.tscn -- --coop=host --bot --sair=8 --nome=Host > "$T/coop_host.log" 2>&1 &
i=0
while ! grep -q "coop: sala aberta" "$T/coop_host.log" 2> /dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 200 ]; then break; fi
  sleep 0.2
done
timeout 120 "$G" --headless --path . res://v2/mundo.tscn -- --coop=join --endereco=127.0.0.1:7777 --bot --sair=8 --nome=Cliente > "$T/coop_join.log" 2>&1 &
wait
campo() { echo "$1" | grep -oE "$2=[-0-9.]+" | head -1 | cut -d= -f2; }
h_local=$(grep "coop: local_final" "$T/coop_host.log" | tail -1)
c_local=$(grep "coop: local_final" "$T/coop_join.log" | tail -1)
h_ve=$(grep "coop: remoto_final" "$T/coop_host.log" | tail -1)
c_ve=$(grep "coop: remoto_final" "$T/coop_join.log" | tail -1)
echo "host   : $h_local"
echo "cliente: $c_local"
echo "host vê o cliente : $h_ve"
echo "cliente vê o host : $c_ve"
falhas=0
conferir() { # nome, x_dono, y_dono, golpes_dono, x_visto, y_visto, golpes_vistos
  if [ -z "$2" ] || [ -z "$5" ]; then
    echo "FALHOU: $1 sem dados"
    falhas=$((falhas + 1))
    return
  fi
  dx=$(awk -v a="$2" -v b="$5" 'BEGIN{d=a-b; if(d<0)d=-d; print d}')
  dy=$(awk -v a="$3" -v b="$6" 'BEGIN{d=a-b; if(d<0)d=-d; print d}')
  perto=$(awk -v dx="$dx" -v dy="$dy" 'BEGIN{print (dx<1.0 && dy<1.0) ? 1 : 0}')
  if [ "$perto" != "1" ]; then
    echo "FALHOU: $1 posição difere (dx=$dx dy=$dy)"
    falhas=$((falhas + 1))
  fi
  if [ "${4:-0}" -le 0 ] || [ "$4" != "$7" ]; then
    echo "FALHOU: $1 golpes dados=$4 vistos=$7"
    falhas=$((falhas + 1))
  fi
}
conferir "host vê o cliente" "$(campo "$c_local" x)" "$(campo "$c_local" y)" "$(campo "$c_local" golpes)" "$(campo "$h_ve" x)" "$(campo "$h_ve" y)" "$(campo "$h_ve" golpes_vistos)"
conferir "cliente vê o host" "$(campo "$h_local" x)" "$(campo "$h_local" y)" "$(campo "$h_local" golpes)" "$(campo "$c_ve" x)" "$(campo "$c_ve" y)" "$(campo "$c_ve" golpes_vistos)"
erros=$(cat "$T/coop_host.log" "$T/coop_join.log" | grep -c "SCRIPT ERROR")
if [ "$erros" != "0" ]; then
  echo "FALHOU: SCRIPT ERROR=$erros"
  falhas=$((falhas + 1))
fi
grep "coop: banda" "$T/coop_host.log" | tail -1 | sed 's/^/host    /'
grep "coop: banda" "$T/coop_join.log" | tail -1 | sed 's/^/cliente /'
echo "COOP_MOVIMENTO falhas=$falhas"
