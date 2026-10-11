#!/bin/bash
# Mede o fps da cena do protótipo por modo de sombra (nenhuma, baixa, media, alta), com 6 luzes e 25 e 250 monstros (+ o herói),
# 3 repetições de cada, intercaladas (a máquina oscila de uma rodada para outra; use a mediana). 6 s de medição, 1,5 s de aquecimento, sem V-Sync.
# Uso: ./medir_sombras.sh [caminho do godot console] ; saída: linhas "MEDIDA ..." em fps_sombras.txt e a mediana de cada célula no fim.
cd "$(dirname "$0")/../../projeto" || exit 1
GODOT="${1:-/c/Dev/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe}"
SAIDA="../prototipos/cara_nova/fps_sombras.txt"
: > "$SAIDA"
for rep in 1 2 3; do
  for sprites in 25 250; do
    for modo in nenhuma baixa media alta; do
      timeout 60 "$GODOT" --path . res://prototipos/cara_nova.tscn -- --medir --sprites=$sprites --sombra=$modo --duracao=6 2>&1 | grep MEDIDA >> "$SAIDA"
    done
  done
done
echo "--- mediana de 3 (minimo a maximo) ---" >> "$SAIDA"
for sprites in 26 251; do
  for modo in nenhuma baixa media alta; do
    grep "sombra=$modo " "$SAIDA" | grep "sprites=$sprites " | sed 's/.*fps=\([0-9.]*\).*/\1/' | sort -n | awk -v m=$modo -v s=$sprites '{a[NR]=$1} END {printf "sprites=%d sombra=%s mediana=%.0f (%.0f a %.0f)\n", s, m, a[2], a[1], a[3]}' >> "$SAIDA"
  done
done
cat "$SAIDA"
