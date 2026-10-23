#!/usr/bin/env bash
# Monta o AppDir a partir do ELF exportado e gera KIKIU-<versao>-x86_64.AppImage.
# Uso: montar.sh <KIKIU.x86_64> <pasta-de-saida> [project.godot]
set -euo pipefail

aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
binario="$(realpath "${1:?informe o executavel Linux exportado}")"
saida="$(realpath -m "${2:?informe a pasta de saida}")"
projeto="$(realpath "${3:-$aqui/../../jogos/hordas/projeto/project.godot}")"

# appimagetool fixado: tag 1.9.1 (2025-11-18), SHA-256 publicado pelo GitHub no asset.
TOOL_URL='https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage'
TOOL_SHA256='ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0'

versao="$(sed -n 's/^config\/version="\([^"]*\)".*/\1/p' "$projeto" | head -n1)"
[[ "$versao" =~ ^[0-9]+(\.[0-9]+){2,3}$ ]] || { echo "config/version invalido: '$versao'" >&2; exit 1; }
test -s "$binario"

trabalho="$(mktemp -d)"
trap 'rm -rf -- "$trabalho"' EXIT
curl -fsSL -o "$trabalho/appimagetool" "$TOOL_URL"
echo "$TOOL_SHA256  $trabalho/appimagetool" | sha256sum -c -
chmod +x "$trabalho/appimagetool"

appdir="$trabalho/KIKIU.AppDir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps"
install -m 755 "$binario" "$appdir/usr/bin/KIKIU.x86_64"
install -m 755 "$aqui/AppRun" "$appdir/AppRun"
install -m 644 "$aqui/kikiu.desktop" "$appdir/kikiu.desktop"
install -m 644 "$aqui/kikiu.desktop" "$appdir/usr/share/applications/kikiu.desktop"
install -m 644 "$aqui/kikiu.png" "$appdir/kikiu.png"
install -m 644 "$aqui/kikiu.png" "$appdir/usr/share/icons/hicolor/256x256/apps/kikiu.png"
ln -s kikiu.png "$appdir/.DirIcon"

mkdir -p "$saida"
arquivo="$saida/KIKIU-$versao-x86_64.AppImage"
# O runner nao tem FUSE: o proprio appimagetool tambem roda extraido.
ARCH=x86_64 "$trabalho/appimagetool" --appimage-extract-and-run "$appdir" "$arquivo"
test -s "$arquivo"
chmod +x "$arquivo"
ls -la "$arquivo"
echo "AppImage gerado: $arquivo"
