#!/bin/bash
# Mede o fps da cena do protótipo (janela real, sem V-Sync) com 1, 3 e 6 luzes e 25 e 250 sprites (+ o herói), com e sem normal map,
# 3 repetições de cada (o notebook oscila uns 20% de uma rodada pra outra; use a mediana).
# Uso: ./medir_fps.sh [caminho do godot console] ; saída: linhas "MEDIDA ..." em fps.txt (6 s de medição cada, 1,5 s de aquecimento)
cd "$(dirname "$0")/../../projeto" || exit 1
GODOT="${1:-/c/Dev/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe}"
SAIDA="../prototipos/cara_nova/fps.txt"
: > "$SAIDA"
for rep in 1 2 3; do
  for normal in "" "--sem_normal"; do
    for sprites in 25 250; do
      for luzes in 1 3 6; do
        timeout 60 "$GODOT" --path . res://prototipos/cara_nova.tscn -- --medir --luzes=$luzes --sprites=$sprites --duracao=6 $normal 2>&1 | grep MEDIDA >> "$SAIDA"
      done
    done
  done
done
cat "$SAIDA"
