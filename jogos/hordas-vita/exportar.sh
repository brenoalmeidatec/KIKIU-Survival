#!/usr/bin/env bash
# Exporta o piloto para .vpk. Uso: GODOT_VITA=/caminho/Godot_v3.5-rc5-vita.exe ./exportar.sh [saida.vpk]
# O editor tem que ser o do godot-vita 3.5-rc5-vita1 com o template instalado (ver STATUS.md).
# Pegadinha do exportador: ele ignora o caminho pedido e grava "<param_sfo/title>.vpk" no diretório atual, que o
# --path do Godot troca para a pasta do projeto. Por isso o script move o arquivo depois.
set -euo pipefail
aqui="$(cd "$(dirname "$0")" && pwd)"
proj="$aqui/piloto"
saida="${1:-$aqui/build/kikiu_piloto.vpk}"
godot="${GODOT_VITA:-/e/Dev/KIKIU-Vita/ferramentas/Godot_v3.5-rc5-vita.exe}"
titulo="$(sed -n 's/^param_sfo\/title="\(.*\)"/\1/p' "$proj/export_presets.cfg")"
rm -f "$proj/$titulo.vpk"
"$godot" --no-window -e -q --path "$proj" >/dev/null 2>&1 || true    # garante os .import
"$godot" --no-window --path "$proj" --export "PlayStation Vita" "$proj/$titulo.vpk"
mkdir -p "$(dirname "$saida")"
mv -f "$proj/$titulo.vpk" "$saida"
ls -l "$saida"
