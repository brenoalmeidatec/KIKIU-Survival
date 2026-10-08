#!/bin/sh
# #72 marco 5: duas instâncias reais. O anfitrião queima/congela com as armas de elemento; o cliente tem que ver os estados
# (bits 32, 64, 128 e lento da foto) e contar os marcados. Uso: GODOT=<console.exe> sh testes/online_elementos.sh (dentro de jogos/hordas/projeto)
G=${GODOT:-E:/Dev/Godot_4.4.1/Godot_v4.4.1-stable_win64_console.exe}
T=${TMPDIR:-/tmp}
timeout 120 "$G" --headless --path . -- --online=host --jogadores=2 --bot --heroi=joao --semente=7 --fase=2 --sair=40 --topico=elemteste > "$T/elem_host.log" 2>&1 &
sleep 6
timeout 120 "$G" --headless --path . -- --online=join --endereco=127.0.0.1:7777 --bot --heroi=lucas --semente=7 --fase=2 --sair=40 > "$T/elem_join.log" 2>&1 &
wait
h=$(grep "elementos:" "$T/elem_host.log" | tail -3 | grep -oE "estados=[0-9]+" | tail -1)
mh=$(grep "elementos:" "$T/elem_host.log" | grep -oE "marcados=[0-9]+" | sort -t= -k2 -n | tail -1 | cut -d= -f2)
mc=$(grep "elementos:" "$T/elem_join.log" | grep -oE "marcados=[0-9]+" | sort -t= -k2 -n | tail -1 | cut -d= -f2)
vc=$(grep "elementos:" "$T/elem_join.log" | grep -oE "vistos=[0-9]+" | sort -t= -k2 -n | tail -1 | cut -d= -f2)
erros=$(cat "$T/elem_host.log" "$T/elem_join.log" | grep -c "SCRIPT ERROR")
echo "host marcados=$mh | cliente marcados=$mc vistos(max)=$vc | SCRIPT ERROR=$erros"
if [ "${mh:-0}" -gt 0 ] && [ "${mc:-0}" -gt 0 ] && [ "${vc:-0}" -gt 0 ] && [ "$erros" = "0" ]; then echo "ELEM_ONLINE falhas=0"; else echo "ELEM_ONLINE falhas=1"; fi
