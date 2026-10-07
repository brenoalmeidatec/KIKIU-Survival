#!/usr/bin/env bash
# Gera a arte do assistente do instalador Inno Setup, em BMP 24 bits, com arte REAL do jogo (gerar_arte.gd monta a cena
# no Godot: Hazaki em camadas, monstros, piso e árvores da Floresta Sombria, brasas, luz e a fonte do jogo) e o ffmpeg
# converte os PNG para BMP. Saída nesta pasta: wizard_164x314.bmp, wizard_328x628.bmp, small_55x58.bmp, small_110x116.bmp.
# Precisa do Godot 4.4.1 (GODOT=... se não estiver em /c/Dev/Tools/Godot) e do ffmpeg no PATH.
# O gerar_arte.gd não roda em --headless: abre uma janelinha por um instante e fecha sozinho.
set -e
cd "$(dirname "$0")"
GODOT="${GODOT:-/c/Dev/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

"$GODOT" --headless --path ../projeto --import >/dev/null 2>&1 || true   # garante as texturas importadas
"$GODOT" --path ../projeto --script "$(pwd -W)/gerar_arte.gd" -- "$(cygpath -w "$TMP")"

for n in wizard_164x314 wizard_328x628 small_55x58 small_110x116; do
	[ -f "$TMP/$n.png" ] || { echo "o Godot não gerou $n.png" >&2; exit 1; }
	ffmpeg -hide_banner -loglevel error -y -i "$TMP/$n.png" -pix_fmt bgr24 "$n.bmp"
	# cópia legível (PNG) das prévias, pra olhar e versionar em ../prints
	cp "$TMP/$n.png" "../prints/instalador_$n.png"
done
ls -l wizard_164x314.bmp wizard_328x628.bmp small_55x58.bmp small_110x116.bmp
