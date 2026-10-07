#!/usr/bin/env bash
# Gera o .exe do K.I.K.I.U e o instalador Windows de uma vez: carimbo de versão, importação, exportação do Godot e
# compilação do Inno Setup (instalador/kikiu.iss). Saídas em jogos/hordas/build/ (fora do Git, veja o .gitignore):
#   build/KIKIU.exe                        o jogo (ícone embutido, pck dentro do .exe)
#   build/instalador/KIKIU-Setup-<versão>.exe   o instalador
# Pré-requisitos: Godot 4.4.1 com os modelos de exportação 4.4.1 em %APPDATA%/Godot/export_templates/4.4.1.stable/
# e o Inno Setup 6 (winget install --id JRSoftware.InnoSetup -e). Veja o README, seção "Gerar o executável".
# Caminhos de outra máquina: GODOT=... e ISCC=... no ambiente, ou no CLAUDE.local.md dessa máquina.
set -e
cd "$(dirname "$0")"

GODOT="${GODOT:-/c/Dev/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe}"
ISCC="${ISCC:-}"
if [ -z "$ISCC" ]; then
	for p in "/c/Users/Dell/AppData/Local/Programs/Inno Setup 6/ISCC.exe" "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" "/c/Program Files/Inno Setup 6/ISCC.exe"; do
		if [ -f "$p" ]; then ISCC="$p"; break; fi
	done
fi
if [ -z "$ISCC" ] || [ ! -f "$ISCC" ]; then
	echo "ISCC.exe (Inno Setup 6) não achado: instale com winget ou defina ISCC=..." >&2
	exit 1
fi

VERSAO=$(grep -E '^config/version=' projeto/project.godot | cut -d'"' -f2)
echo "Versão: $VERSAO"

./gerar_versao.sh

mkdir -p build/instalador
SAIDA="$(pwd -W)/build/KIKIU.exe"

"$GODOT" --headless --path projeto --import
"$GODOT" --headless --path projeto --export-release "Windows Desktop" "$SAIDA"
echo "Exportado: build/KIKIU.exe ($(du -h build/KIKIU.exe | cut -f1))"

# o commit vem do dados/versao.json que a exportação acabou de escrever (o addon kikiu_versao; "+" = mudança sem commit)
COMMIT=$(grep -o '"commit": *"[^"]*"' projeto/dados/versao.json | cut -d'"' -f4 | sed 's/+$/-mod/')
NOME="KIKIU-Setup-$VERSAO-$COMMIT"

# MSYS_NO_PATHCONV: o Git Bash trocaria /DVERSAO=... por um caminho do Windows e o ISCC veria dois scripts
MSYS_NO_PATHCONV=1 "$ISCC" "/DVERSAO=$VERSAO" "/DCOMMIT=$COMMIT" instalador/kikiu.iss
echo "Instalador: build/instalador/$NOME.exe ($(du -h "build/instalador/$NOME.exe" | cut -f1))"
