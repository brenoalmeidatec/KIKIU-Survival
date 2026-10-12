#!/bin/bash
# Mede o fps da v2 sem V-Sync em dois cenarios: "santuario" (heroi parado no circulo, ~13 luzes ligadas, ~80 atores com sombra, 20 monstros
# vagando) e "horda" (--estresse=100 --imortal: 100 monstros cacando o heroi, ~167 atores na tela). Modos: sombra baixa, media e alta (so a
# opcao de sombras) e "baixo" (o perfil Baixo inteiro: sombra baixa, particulas poucas e orcamento de luzes). 3 repeticoes intercaladas (a
# maquina oscila: use a mediana). 2 s de aquecimento + 6 s medidos. ANTES, confira com `tasklist` se nao ha outro Godot rodando: a maquina e
# compartilhada e um teste de outro agente rodando ao lado baixa o fps em 30% ou mais.
# Uso: v2/medir_fps.sh [caminho do godot console] [arquivo de saida]
# Saida: linhas "<cenario> <modo> MEDIDA ..." (e SCRIPT ms, PERFIL, RENDER) no arquivo (padrao v2/fps.txt) e a mediana de cada cenario e modo no fim.
cd "$(dirname "$0")/.." || exit 1
GODOT="${1:-/c/Dev/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe}"
SAIDA="${2:-v2/fps.txt}"
: > "$SAIDA"
flags_modo() {
  case "$1" in
    baixo) echo "--perfil=baixo --sombra=baixa --particulas=poucas" ;;
    *) echo "--sombra=$1" ;;
  esac
}
for rep in 1 2 3; do
  for cenario in santuario horda; do
    extra=""
    [ "$cenario" = "horda" ] && extra="--estresse=100 --imortal"
    for modo in baixa media alta baixo; do
      # uma rodada que nao imprime MEDIDA (o Godot nao subiu com a maquina carregada, por exemplo) e repetida ate 3 vezes
      for tentativa in 1 2 3; do
        saida_run=$(timeout 120 "$GODOT" --path . res://v2/mundo.tscn -- --medir $(flags_modo $modo) --duracao=6 $extra 2>&1 | grep -E "MEDIDA|SCRIPT ms|PERFIL|RENDER")
        if echo "$saida_run" | grep -q MEDIDA; then
          echo "$saida_run" | sed "s/^/$cenario $modo /" >> "$SAIDA"
          break
        fi
      done
    done
  done
done
echo "--- mediana de 3 (minimo a maximo) ---" >> "$SAIDA"
for cenario in santuario horda; do
  for modo in baixa media alta baixo; do
    grep "^$cenario $modo MEDIDA " "$SAIDA" | sed 's/.*fps=\([0-9.]*\).*/\1/' | sort -n \
      | awk -v c=$cenario -v m=$modo '{a[NR]=$1} END {printf "%s %s mediana=%.0f (%.0f a %.0f)\n", c, m, a[int((NR+1)/2)], a[1], a[NR]}' >> "$SAIDA"
  done
done
tail -8 "$SAIDA"
