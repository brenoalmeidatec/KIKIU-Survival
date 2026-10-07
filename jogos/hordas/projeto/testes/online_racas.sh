#!/bin/sh
# #72 marco 6: duas instâncias reais. O CLIENTE é um Cogumelo Andante (gancho de mundo: esporos que envenenam); o anfitrião
# joga com um humano (guerreiro, lança: SEM elemento nenhum). Se o anfitrião marcar inimigos com veneno, foi ele aplicando a aura do cliente
# (a raça sai do herói validado) e o cliente tem que ver o estado na foto. Uso: GODOT=<console.exe> sh testes/online_racas.sh
# (dentro de jogos/hordas/projeto). Os dois são heróis criados por ficha (--ficha=), que o anfitrião valida.
G=${GODOT:-E:/Dev/Godot_4.4.1/Godot_v4.4.1-stable_win64_console.exe}
T=${TMPDIR:-/tmp}
H="Pedro/humano/guerreiro//0,0,0,0,0/0,0,0"
C="Cogu/cogumelo/guerreiro//0,0,0,0,0/9,3,3"
timeout 120 "$G" --headless --path . -- --online=host --jogadores=2 --bot --ficha=$H --semente=7 --fase=2 --sair=60 --topico=racateste > "$T/raca_host.log" 2>&1 &
sleep 6
timeout 120 "$G" --headless --path . -- --online=join --endereco=127.0.0.1:7777 --bot --ficha=$C --semente=7 --fase=2 --sair=60 > "$T/raca_join.log" 2>&1 &
wait
mh=$(grep "elementos:" "$T/raca_host.log" | grep -oE "marcados=[0-9]+" | sort -t= -k2 -n | tail -1 | cut -d= -f2)
mc=$(grep "elementos:" "$T/raca_join.log" | grep -oE "marcados=[0-9]+" | sort -t= -k2 -n | tail -1 | cut -d= -f2)
vc=$(grep "elementos:" "$T/raca_join.log" | grep -oE "vistos=[0-9]+" | sort -t= -k2 -n | tail -1 | cut -d= -f2)
gc=$(grep "ganchos:" "$T/raca_host.log" | tail -1)
erros=$(cat "$T/raca_host.log" "$T/raca_join.log" | grep -c "SCRIPT ERROR")
echo "host marcados=$mh | cliente marcados=$mc vistos(max)=$vc | $gc | SCRIPT ERROR=$erros"
if [ "${mh:-0}" -gt 0 ] && [ "${mc:-0}" -gt 0 ] && [ "$erros" = "0" ]; then echo "RACAS_ONLINE falhas=0"; else echo "RACAS_ONLINE falhas=1"; fi
