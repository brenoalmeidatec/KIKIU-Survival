#!/bin/bash
# Mede o fps da v2 parado no meio do santuario (herói no circulo, ~13 luzes ligadas, ~80 atores com sombra, 20 monstros vagando),
# sem V-Sync, com sombra media e alta, 3 repeticoes intercaladas (a maquina oscila: use a mediana). 2 s de aquecimento + 6 s medidos.
# Uso: v2/medir_fps.sh [caminho do godot console] ; saida: linhas "MEDIDA ..." em v2/fps.txt e a mediana de cada modo no fim.
cd "$(dirname "$0")/.." || exit 1
GODOT="${1:-/c/Dev/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe}"
SAIDA="v2/fps.txt"
: > "$SAIDA"
for rep in 1 2 3; do
  for modo in media alta; do
    timeout 90 "$GODOT" --path . res://v2/mundo.tscn -- --medir --sombra=$modo --duracao=6 2>&1 | grep -E "MEDIDA|SCRIPT ms" >> "$SAIDA"
  done
done
echo "--- mediana de 3 (minimo a maximo) ---" >> "$SAIDA"
for modo in media alta; do
  grep "sombra=$modo " "$SAIDA" | sed 's/.*fps=\([0-9.]*\).*/\1/' | sort -n | awk -v m=$modo '{a[NR]=$1} END {printf "sombra=%s mediana=%.0f (%.0f a %.0f)\n", m, a[2], a[1], a[3]}' >> "$SAIDA"
done
cat "$SAIDA"
