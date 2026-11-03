#!/bin/bash
# Gera todos os sprites do protótipo da cara nova (herói + monstros), em paralelo. Uso: ./gerar_tudo.sh [caminho do blender.exe]
cd "$(dirname "$0")" || exit 1
BLENDER="${1:-/c/Dev/Tools/Blender/blender-4.5.14-windows-x64/blender.exe}"
mkdir -p sprites logs
rodar() { "$BLENDER" -b -P gerar_cara_nova.py -- "$@" > "logs/$(echo "$@" | tr ' ' '_').log" 2>&1; }
rodar heroi samurai &
rodar heroi &
rodar monstro horror cao_ossos &
rodar monstro horror cavaleiro_oco &
rodar monstro floresta aranha_tecela &
rodar monstro floresta lobo_sombrio &
rodar monstro floresta espantalho &
wait
# folhas grandes de elite (2x) e chefes (mini1 2x, mini2 3x, chefe 4x): o mesmo modelo com N vezes mais pixels, desenhado em 1x no jogo
grande() { CARA_NOVA_MULT=$3 "$BLENDER" -b -P gerar_cara_nova.py -- monstro "$1" "$2" > "logs/$2_x$3.log" 2>&1; }
grande horror cao_ossos 2 &
grande horror cavaleiro_oco 2 &
grande floresta aranha_tecela 2 &
grande floresta aranha_tecela 3 &
grande floresta lobo_sombrio 2 &
grande floresta espantalho 2 &
grande floresta espantalho 4 &
wait
grep -h "CARA_NOVA OK\|HEROI caixa\|Error\|Traceback" logs/*.log
