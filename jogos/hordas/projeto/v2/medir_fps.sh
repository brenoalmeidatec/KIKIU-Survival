#!/bin/bash
# Mede o fps da v2 sem V-Sync em dois cenarios: "santuario" (heroi parado no circulo, ~13 luzes ligadas, ~80 atores com sombra, 20 monstros
# vagando) e "horda" (--estresse=100 --imortal: 100 monstros cacando o heroi, ~167 atores na tela). Sombra baixa, media e alta, 3 repeticoes
# intercaladas (a maquina oscila: use a mediana). 2 s de aquecimento + 6 s medidos. Antes, confira com `tasklist` se nao ha outro Godot rodando.
# Uso: v2/medir_fps.sh [caminho do godot console] [arquivo de saida]
# Saida: linhas "<cenario> MEDIDA ..." (e SCRIPT ms, PERFIL) no arquivo (padrao v2/fps.txt) e a mediana de cada cenario e modo no fim.
cd "$(dirname "$0")/.." || exit 1
GODOT="${1:-/c/Dev/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe}"
SAIDA="${2:-v2/fps.txt}"
: > "$SAIDA"
for rep in 1 2 3; do
  for cenario in santuario horda; do
    extra=""
    [ "$cenario" = "horda" ] && extra="--estresse=100 --imortal"
    for modo in baixa media alta; do
      timeout 120 "$GODOT" --path . res://v2/mundo.tscn -- --medir --sombra=$modo --duracao=6 $extra 2>&1 \
        | grep -E "MEDIDA|SCRIPT ms|PERFIL" | sed "s/^/$cenario /" >> "$SAIDA"
    done
  done
done
echo "--- mediana de 3 (minimo a maximo) ---" >> "$SAIDA"
for cenario in santuario horda; do
  for modo in baixa media alta; do
    grep "^$cenario MEDIDA sombra=$modo " "$SAIDA" | sed 's/.*fps=\([0-9.]*\).*/\1/' | sort -n \
      | awk -v c=$cenario -v m=$modo '{a[NR]=$1} END {printf "%s sombra=%s mediana=%.0f (%.0f a %.0f)\n", c, m, a[2], a[1], a[3]}' >> "$SAIDA"
  done
done
tail -7 "$SAIDA"
