#!/bin/sh
# #72 marcos 3 e 4: duas instâncias reais (anfitrião e cliente). Cada uma declara uma mochila (--mochila=); o anfitrião confere e aceita,
# os robôs usam consumíveis, e o cliente trapaceia (--trapaca: pede mais do que tem) pra o anfitrião recusar o excesso.
# Depois uma terceira rodada com mochila grande demais: o anfitrião tem que recusar.
# Uso: GODOT=<console.exe> sh testes/online_preparo.sh   (dentro de jogos/hordas/projeto)
G=${GODOT:-E:/Dev/Godot_4.4.1/Godot_v4.4.1-stable_win64_console.exe}
T=${TMPDIR:-/tmp}
H="Brutus/orc/guerreiro/manco/3,2,0,0,0/4,1,2"
C="Lyra/elfo_sombrio/mago//0,1,2,3,2/5,2,5"
timeout 120 "$G" --headless --path . -- --online=host --jogadores=2 --bot --ficha=$H --mochila=pocao_cura:2,bomba,pergaminho_gelo,amuleto_corvo --semente=7 --fase=2 --sair=40 --topico=prepteste > "$T/prep_host.log" 2>&1 &
sleep 6
timeout 120 "$G" --headless --path . -- --online=join --endereco=127.0.0.1:7777 --bot --ficha=$C --mochila=pocao_cura:2,pocao_vigor,amuleto_ferro --trapaca --semente=7 --fase=2 --sair=40 > "$T/prep_join.log" 2>&1 &
wait
f=0
# 1) o anfitrião aceitou as duas mochilas
grep -q "MOCHILA aceita: peer=1 " "$T/prep_host.log" || { echo "falta: mochila do anfitrião aceita"; f=$((f+1)); }
grep -q "MOCHILA aceita: peer=[0-9][0-9][0-9]" "$T/prep_host.log" || { echo "falta: mochila do cliente aceita"; f=$((f+1)); }
# 2) os dois usaram consumíveis e o anfitrião conferiu
grep -q "CONSUMIVEL ok: peer=1 " "$T/prep_host.log" || { echo "falta: uso do anfitrião"; f=$((f+1)); }
grep -q "CONSUMIVEL ok: peer=[0-9][0-9][0-9]" "$T/prep_host.log" || { echo "falta: uso do cliente conferido"; f=$((f+1)); }
grep -q "CONSUMIVEL usou pocao_cura" "$T/prep_join.log" || { echo "falta: o cliente aplicou o efeito no corpo dele"; f=$((f+1)); }
# 3) a trapaça do cliente (pediu mais do que declarou) foi recusada
grep -q "CONSUMIVEL recusado: peer=[0-9][0-9][0-9]" "$T/prep_host.log" || { echo "falta: excesso do cliente recusado"; f=$((f+1)); }
# o cliente nunca aplicou mais poções do que declarou (2)
n=$(grep -c "CONSUMIVEL usou pocao_cura" "$T/prep_join.log")
[ "$n" -le 2 ] || { echo "o cliente aplicou $n poções (declarou 2)"; f=$((f+1)); }
# 4) sem erro de script em nenhum dos dois
e=$(cat "$T/prep_host.log" "$T/prep_join.log" | grep -c "SCRIPT ERROR")
[ "$e" -eq 0 ] || { echo "SCRIPT ERROR: $e"; f=$((f+1)); }
# 5) mochila grande demais: recusada
timeout 60 "$G" --headless --path . -- --online=host --jogadores=2 --bot --ficha=$H --mochila=pocao_cura:2 --semente=7 --sair=25 --topico=prepteste > "$T/prep_host2.log" 2>&1 &
sleep 6
timeout 60 "$G" --headless --path . -- --online=join --endereco=127.0.0.1:7777 --bot --ficha=$C --mochila=bomba:2,pocao_cura:3 --semente=7 --sair=25 > "$T/prep_join2.log" 2>&1 &
wait
grep -q "MOCHILA recusada: peer=[0-9][0-9][0-9]" "$T/prep_host2.log" || { echo "falta: mochila grande demais recusada"; f=$((f+1)); }
echo "ONLINE_PREPARO falhas=$f"
