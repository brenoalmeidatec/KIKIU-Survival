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


# O ícone e os metadados (nome do produto, versão) entram no .exe pelo rcedit (application/modify_resources=true no
# export_presets.cfg). Sem o rcedit o Godot NÃO falha: só avisa e entrega um .exe com o ícone do Godot. Aqui a gente confere
# antes e avisa alto. Como instalar: README, seção "Gerar o executável" (rcedit-x64.exe + Editor > Configurações do editor >
# Exportar > Windows > rcedit).
RCEDIT=""
CFG="${APPDATA:-$HOME/AppData/Roaming}/Godot/editor_settings-4.4.tres"
if [ -f "$CFG" ]; then
	RCEDIT=$(grep -E '^export/windows/rcedit *=' "$CFG" | head -1 | cut -d'"' -f2)
fi
if { [ -z "$RCEDIT" ] || [ ! -f "$RCEDIT" ]; } && ! command -v rcedit >/dev/null 2>&1; then
	cat >&2 <<AVISO
!!! ATENÇÃO: rcedit não configurado neste computador.
!!! O .exe e o instalador vão sair SEM o ícone do K.I.K.I.U (com o ícone do Godot) e sem nome/versão nos detalhes do arquivo.
!!! Baixe o rcedit-x64.exe em https://github.com/electron/rcedit/releases e aponte o Godot pra ele em
!!! Editor > Configurações do editor > Exportar > Windows > rcedit. Detalhes no jogos/hordas/README.md.
AVISO
	sleep 3
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
