#!/usr/bin/env bash
# Gera o jogo convertido a partir da main e exporta para .vpk (template próprio com o módulo; KIKU00004).
#   ./exportar_jogo.sh [ref_git=origin/main]
# Precisa: editor godot-vita (GODOT_VITA) e o template próprio (TEMPLATE_CPP), como no exportar.sh.
set -euo pipefail
unset MSYS_NO_PATHCONV
aqui="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$aqui/../.." && pwd)"
ref="${1:-origin/main}"
base="${KIKIU_VITA:-/e/Dev/KIKIU-Vita}"
godot="${GODOT_VITA:-$base/ferramentas/Godot_v3.5-rc5-vita.exe}"
tpl_dir="$(dirname "$godot")/editor_data/templates/3.5.rc5"
fonte="$base/fonte_main"
proj="$base/jogo_vita"
saida="$aqui/build/kikiu_vita.vpk"
rm -rf "$fonte" && mkdir -p "$fonte"
git -C "$repo" archive "$ref" jogos/hordas/projeto | tar -x -C "$fonte"
python "$aqui/conversor/gerar.py" "$fonte/jogos/hordas/projeto" "$proj"
python "$aqui/conversor/verificar.py" "$godot" "$proj" | head -3
[ -f "$tpl_dir/vita_release_oficial.zip" ] || cp "$tpl_dir/vita_release.zip" "$tpl_dir/vita_release_oficial.zip"
cp -f "${TEMPLATE_CPP:-$(dirname "$godot")/vita_release_horda.zip}" "$tpl_dir/vita_release.zip"
trap 'cp -f "$tpl_dir/vita_release_oficial.zip" "$tpl_dir/vita_release.zip"' EXIT
rm -f "$proj/KIKIU Vita.vpk"
"$godot" --no-window --path "$proj" --export "PlayStation Vita" "$proj/KIKIU Vita.vpk" > "$proj/export.log" 2>&1
mkdir -p "$(dirname "$saida")"
mv -f "$proj/KIKIU Vita.vpk" "$saida"
python "$aqui/conserta_sfo.py" "$saida" "KIKU00004" "KIKIU Vita"
ls -l "$saida"
