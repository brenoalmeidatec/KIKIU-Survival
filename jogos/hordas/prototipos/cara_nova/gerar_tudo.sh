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
grep -h "CARA_NOVA OK\|HEROI caixa\|Error\|Traceback" logs/*.log
