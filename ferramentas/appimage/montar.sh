#!/usr/bin/env bash
# Monta o AppDir a partir do ELF exportado e gera KIKIU-<versao>-build-<data>-<commit>-x86_64.AppImage (o nome sai do nome.sh).
# Uso: montar.sh <KIKIU.x86_64> <pasta-de-saida> [project.godot]
set -euo pipefail

aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
binario="$(realpath "${1:?informe o executavel Linux exportado}")"
saida="$(realpath -m "${2:?informe a pasta de saida}")"
projeto="$(realpath "${3:-$aqui/../../jogos/hordas/projeto/project.godot}")"

# appimagetool fixado: tag 1.9.1 (2025-11-18), SHA-256 publicado pelo GitHub no asset.
TOOL_URL='https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage'
TOOL_SHA256='ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0'
# Runtime fixado pela release datada 20251108 (o asset 'continuous' muda sozinho; o 1.9.1 baixa dele sem checagem).
# O 1.9.1 aceita --runtime-file, entao baixamos aqui e conferimos o SHA-256 antes.
RUNTIME_URL='https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64'
RUNTIME_SHA256='2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d'

# Nome do arquivo e validacao do config/version ficam no nome.sh (coberto por teste_nome.sh).
nome_arquivo="$(bash "$aqui/nome.sh" "$projeto")"
test -s "$binario"

trabalho="$(mktemp -d)"
trap 'rm -rf -- "$trabalho"' EXIT
curl -fsSL -o "$trabalho/appimagetool" "$TOOL_URL"
echo "$TOOL_SHA256  $trabalho/appimagetool" | sha256sum -c -
chmod +x "$trabalho/appimagetool"
curl -fsSL -o "$trabalho/runtime-x86_64" "$RUNTIME_URL"
echo "$RUNTIME_SHA256  $trabalho/runtime-x86_64" | sha256sum -c -

appdir="$trabalho/KIKIU.AppDir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps" "$appdir/usr/share/metainfo"
install -m 755 "$binario" "$appdir/usr/bin/KIKIU.x86_64"
install -m 755 "$aqui/AppRun" "$appdir/AppRun"
# .desktop e metainfo com o nome do <id> do AppStream: o appimagetool acha o metainfo pelo nome do .desktop e o
# appstreamcli reprova se o nome do metainfo não for o <id> (metainfo-filename-cid-mismatch)
cid=io.github.brenoalmeidatec.kikiu
install -m 644 "$aqui/kikiu.desktop" "$appdir/$cid.desktop"
install -m 644 "$aqui/kikiu.desktop" "$appdir/usr/share/applications/$cid.desktop"
install -m 644 "$aqui/kikiu.appdata.xml" "$appdir/usr/share/metainfo/$cid.appdata.xml"
install -m 644 "$aqui/kikiu.png" "$appdir/kikiu.png"
install -m 644 "$aqui/kikiu.png" "$appdir/usr/share/icons/hicolor/256x256/apps/kikiu.png"
ln -s kikiu.png "$appdir/.DirIcon"

mkdir -p "$saida"
arquivo="$saida/$nome_arquivo"
# O runner nao tem FUSE: o proprio appimagetool tambem roda extraido.
ARCH=x86_64 "$trabalho/appimagetool" --appimage-extract-and-run --runtime-file "$trabalho/runtime-x86_64" "$appdir" "$arquivo"
test -s "$arquivo"
chmod +x "$arquivo"
ls -la "$arquivo"
echo "AppImage gerado: $arquivo"
