#!/usr/bin/env bash
# Smoke do AppImage: executa a cena principal sem FUSE, sem projeto-fonte e com save isolado.
# Uso: testar.sh <KIKIU-x.y.z-x86_64.AppImage> <log>
set -euo pipefail

appimage="$(realpath "${1:?informe o AppImage}")"
log="$(realpath -m "${2:?informe o caminho do log}")"
test -s "$appimage"
chmod +x "$appimage"
file "$appimage"

isolado="$(mktemp -d)"
trap 'rm -rf -- "$isolado"' EXIT
mkdir -p "$(dirname "$log")" "$isolado/dados" "$isolado/config" "$isolado/cache" "$isolado/pacote"
cp "$appimage" "$isolado/pacote/KIKIU.AppImage"
cd "$isolado/pacote"
export XDG_DATA_HOME="$isolado/dados"
export XDG_CONFIG_HOME="$isolado/config"
export XDG_CACHE_HOME="$isolado/cache"
# Save de uma versao antiga na pasta padrao do Godot: o jogo exportado deve copiar para a pasta propria (kikiu) sem mexer na antiga.
antiga="$isolado/dados/godot/app_userdata/K.I.K.I.U"
nova="$isolado/dados/kikiu"
mkdir -p "$antiga"
printf '[opcoes]
mostrar_fps=true
' > "$antiga/opcoes.cfg"
hash_antiga="$(sha256sum "$antiga/opcoes.cfg")"
set +e
timeout --signal=TERM --kill-after=10s 120s ./KIKIU.AppImage --appimage-extract-and-run --headless --quit-after 120 --log-file "$log" > "$log.stdout" 2>&1
codigo=$?
set -e
cat "$log.stdout"
test -f "$log" && cat "$log"
if [ "$codigo" -ne 0 ]; then
  echo "Smoke do AppImage falhou: codigo $codigo (124 indica timeout)." >&2
  exit "$codigo"
fi
test -s "$log"
grep -q 'Godot Engine v4.4.1.stable' "$log"
# Mesmo filtro do smoke do ELF: --quit-after encerra no meio da cena e o motor reclama de recurso em uso na saida.
if cat "$log" "$log.stdout" | grep -Eiv 'resources still in use at exit' |
  grep -Eiq '(^|[[:space:]])ERROR:|SCRIPT ERROR|Parse Error|Failed loading resource|Error loading resource|Cannot open file|no valid main pack'; then
  echo 'Smoke do AppImage encontrou erro do motor, script ou recurso.' >&2
  exit 1
fi
# Migracao do save (scripts/hordas/migracao_save.gd): copiou para a pasta propria, gravou o marcador e deixou a antiga intacta.
test -f "$nova/migrado_da_pasta_godot.txt"
grep -q 'mostrar_fps=true' "$nova/opcoes.cfg"
test "$hash_antiga" = "$(sha256sum "$antiga/opcoes.cfg")"
echo 'Smoke do AppImage: executou a cena principal via AppRun com PCK embutido, save isolado e migracao do save antigo.'
