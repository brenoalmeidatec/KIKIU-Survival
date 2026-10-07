#!/bin/sh
# #63: duas instâncias reais (anfitrião e cliente) e o estado do objetivo tem que sair igual nos dois logs.
# Uso: GODOT=<console.exe> sh testes/online_objetivo.sh   (dentro de jogos/hordas/projeto)
G=${GODOT:-E:/Dev/Godot_4.4.1/Godot_v4.4.1-stable_win64_console.exe}
T=${TMPDIR:-/tmp}
timeout 120 "$G" --headless --path . -- --online=host --jogadores=2 --bot --heroi=hazaki --semente=7 --fase=2 --sair=45 --topico=objteste > "$T/obj_host.log" 2>&1 &
sleep 6
timeout 120 "$G" --headless --path . -- --online=join --endereco=127.0.0.1:7777 --bot --heroi=hazaki --semente=7 --fase=2 --sair=45 > "$T/obj_join.log" 2>&1 &
wait
# compara só id, alvo, seq e marcas (o relógio "resta" difere em décimos)
f() { grep "objetivo:" "$1" | sed -E 's/"resta": [0-9.]+, //' ; }
n=$(f "$T/obj_host.log" | wc -l)
if [ "$n" -gt 3 ] && [ "$(f "$T/obj_host.log")" = "$(f "$T/obj_join.log")" ]; then echo "OBJ_ONLINE falhas=0 (linhas=$n)"; else echo "OBJ_ONLINE falhas=1 (linhas=$n)"; fi
