#!/usr/bin/env bash
# Exporta o piloto para .vpk.
#   ./exportar.sh              -> build/kikiu_piloto.vpk     (template oficial do godot-vita; horda em GDScript; KIKU00001)
#   VARIANTE=cpp ./exportar.sh -> build/kikiu_piloto_cpp.vpk (template próprio com o módulo C++ HordaVita/VitaHW; KIKU00002)
#   VARIANTE=diag ./exportar.sh -> build/kikiu_diag.vpk      (template próprio SEM o módulo; KIKU00003; só diagnóstico)
# Os dois têm TITLE_ID diferente e convivem no Vita.
# GODOT_VITA = editor godot-vita 3.5-rc5-vita1 com o template oficial instalado (ver STATUS.md).
# TEMPLATE_CPP = zip do template próprio (compilar/build_vita.sh + compilar/empacotar.sh).
# Pegadinhas resolvidas aqui:
# - o exportador ignora o caminho pedido e grava "<param_sfo/title>.vpk" no diretório atual (o --path do Godot troca
#   para a pasta do projeto), então o arquivo é movido depois;
# - o exportador grava TITLE_ID com ponteiro solto (às vezes sai o título): conserta_sfo.py regrava e confere;
# - o 1º `-e -q` pode sair antes de importar arquivo novo: roda duas vezes.
set -euo pipefail
unset MSYS_NO_PATHCONV   # o editor é .exe do Windows: precisa que o Git Bash converta /e/... para E:/...
aqui="$(cd "$(dirname "$0")" && pwd)"
proj="$aqui/piloto"
godot="${GODOT_VITA:-/e/Dev/KIKIU-Vita/ferramentas/Godot_v3.5-rc5-vita.exe}"
tpl_dir="$(dirname "$godot")/editor_data/templates/3.5.rc5"
variante="${VARIANTE:-gd}"
titulo_preset="$(sed -n 's/^param_sfo\/title="\(.*\)"/\1/p' "$proj/export_presets.cfg")"
[ -f "$tpl_dir/vita_release_oficial.zip" ] || cp "$tpl_dir/vita_release.zip" "$tpl_dir/vita_release_oficial.zip"
if [ "$variante" = "cpp" ]; then
	saida="${1:-$aqui/build/kikiu_piloto_cpp.vpk}"
	title_id="KIKU00002"
	titulo="KIKIU Piloto C++"
	cp -f "${TEMPLATE_CPP:-$(dirname "$godot")/vita_release_horda.zip}" "$tpl_dir/vita_release.zip"
	trap 'cp -f "$tpl_dir/vita_release_oficial.zip" "$tpl_dir/vita_release.zip"' EXIT
elif [ "$variante" = "diag" ]; then
	# diagnóstico: template compilado com o SDK novo mas SEM o módulo (separa problema do SDK de problema do módulo)
	saida="${1:-$aqui/build/kikiu_diag.vpk}"
	title_id="KIKU00003"
	titulo="KIKIU Diag"
	cp -f "${TEMPLATE_DIAG:-$(dirname "$godot")/vita_release_diag.zip}" "$tpl_dir/vita_release.zip"
	trap 'cp -f "$tpl_dir/vita_release_oficial.zip" "$tpl_dir/vita_release.zip"' EXIT
else
	saida="${1:-$aqui/build/kikiu_piloto.vpk}"
	title_id="$(sed -n 's/^param_sfo\/title_id="\(.*\)"/\1/p' "$proj/export_presets.cfg")"
	titulo="$titulo_preset"
	cp -f "$tpl_dir/vita_release_oficial.zip" "$tpl_dir/vita_release.zip"
fi
rm -f "$proj/$titulo_preset.vpk"
for _ in 1 2; do "$godot" --no-window -e -q --path "$proj" >/dev/null 2>&1 || true; done   # garante os .import
"$godot" --no-window --path "$proj" --export "PlayStation Vita" "$proj/$titulo_preset.vpk"
mkdir -p "$(dirname "$saida")"
mv -f "$proj/$titulo_preset.vpk" "$saida"
python "$aqui/conserta_sfo.py" "$saida" "$title_id" "$titulo"
ls -l "$saida"
