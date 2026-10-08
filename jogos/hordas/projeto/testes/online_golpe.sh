#!/bin/sh
# Duas instâncias reais: o CLIENTE é o João (Café Quente, poça de fogo); o anfitrião é o Lucas (Pendrive, sem elemento).
# Se o anfitrião contar golpes com arma e marcar inimigos com fogo pelo golpe do cliente (`elemento_do_cliente`), o id da arma chegou.
# Uso: GODOT=<console.exe> sh testes/online_golpe.sh (dentro de jogos/hordas/projeto)
G=${GODOT:-E:/Dev/Godot_4.4.1/Godot_v4.4.1-stable_win64_console.exe}
T=${TMPDIR:-/tmp}
timeout 120 "$G" --headless --path . -- --online=host --jogadores=2 --bot --heroi=lucas --semente=7 --fase=2 --sair=40 --topico=golpeteste > "$T/golpe_host.log" 2>&1 &
sleep 6
timeout 120 "$G" --headless --path . -- --online=join --endereco=127.0.0.1:7777 --bot --heroi=joao --semente=7 --fase=2 --sair=40 > "$T/golpe_join.log" 2>&1 &
wait
g=$(grep "golpes_remotos:" "$T/golpe_host.log" | tail -1)
rec=$(echo "$g" | grep -oE "recebidos=[0-9]+" | cut -d= -f2)
arm=$(echo "$g" | grep -oE "com_arma=[0-9]+" | cut -d= -f2)
el=$(echo "$g" | grep -oE "elemento_do_cliente=[0-9]+" | cut -d= -f2)
erros=$(cat "$T/golpe_host.log" "$T/golpe_join.log" | grep -c "SCRIPT ERROR")
echo "host: $g | SCRIPT ERROR=$erros"
grep "banda:" "$T/golpe_host.log" | tail -1
grep "banda:" "$T/golpe_join.log" | tail -1
if [ "${rec:-0}" -gt 0 ] && [ "${arm:-0}" -gt 0 ] && [ "${el:-0}" -gt 0 ] && [ "$erros" = "0" ]; then echo "GOLPE_ONLINE falhas=0"; else echo "GOLPE_ONLINE falhas=1"; fi
