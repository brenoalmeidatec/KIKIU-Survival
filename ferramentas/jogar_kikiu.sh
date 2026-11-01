#!/usr/bin/env bash
# Lançador de teste do K.I.K.I.U com atualização automática (Linux; o par do jogar_kikiu.ps1 do Windows).
#
# Toda vez que abre, pergunta ao GitHub qual é a build mais nova (a Release "Latest" que o CI publica a cada merge na main).
# Se for diferente da que está na máquina, baixa o AppImage e abre o jogo. Sem internet, abre o último baixado.
# Tudo fica em ~/KIKIU-Teste (builds/<tag>.AppImage, atual.txt, ultimo_log.txt); guarda a build atual e a anterior.
#
# Instalar o atalho na área de trabalho e no menu de aplicativos (uma vez):
#   curl -fsSL https://raw.githubusercontent.com/brenoalmeidatec/KIKIU-Survival/main/ferramentas/jogar_kikiu.sh -o /tmp/jogar_kikiu.sh
#   bash /tmp/jogar_kikiu.sh --instalar
# Depois é só clicar em "KIKIU (teste)". Passo a passo e problemas comuns: ferramentas/appimage/LEIA-ME.md, seção "Atalho do testador".

set -u
REPO="brenoalmeidatec/KIKIU-Survival"
BASE="$HOME/KIKIU-Teste"
BUILDS="$BASE/builds"
ARQ_ATUAL="$BASE/atual.txt"
mkdir -p "$BUILDS"

instalar=0
sem_abrir=0  # --sem-abrir: só baixa e confere (teste)
for a in "$@"; do
	case "$a" in
		--instalar) instalar=1 ;;
		--sem-abrir) sem_abrir=1 ;;
	esac
done

# o atalho não tem terminal: tudo o que acontece vai para ultimo_log.txt (menos na instalação, que roda no terminal)
[ "$instalar" = 0 ] && exec >"$BASE/ultimo_log.txt" 2>&1

avisar() {
	echo "$1"
	if command -v notify-send >/dev/null 2>&1; then notify-send "KIKIU (teste)" "$1"
	elif command -v zenity >/dev/null 2>&1; then zenity --info --title "KIKIU (teste)" --text "$1"
	elif command -v kdialog >/dev/null 2>&1; then kdialog --title "KIKIU (teste)" --msgbox "$1"
	fi
}

if [ "$instalar" = 1 ]; then
	destino="$BASE/jogar_kikiu.sh"
	[ "$(readlink -f "$0")" != "$(readlink -f "$destino" 2>/dev/null)" ] && cp -f "$0" "$destino"
	chmod +x "$destino"
	# ícone: o do AppImage; vem do repo quando o script roda de dentro dele, senão do GitHub
	icone="$BASE/kikiu.png"
	local_png="$(dirname "$(readlink -f "$0")")/appimage/kikiu.png"
	if [ -f "$local_png" ]; then cp -f "$local_png" "$icone"
	else curl -fsSL "https://raw.githubusercontent.com/$REPO/main/ferramentas/appimage/kikiu.png" -o "$icone" || true
	fi
	entrada="[Desktop Entry]
Type=Application
Name=KIKIU (teste)
Comment=K.I.K.I.U: baixa a build mais nova do GitHub e abre o jogo
Exec=\"$destino\"
Icon=$icone
Terminal=false
Categories=Game;"
	menu="$HOME/.local/share/applications/kikiu-teste.desktop"
	mkdir -p "$(dirname "$menu")"
	printf '%s\n' "$entrada" >"$menu"
	chmod +x "$menu"
	# área de trabalho: a pasta do usuário (xdg-user-dir dá o nome certo em qualquer idioma)
	mesa="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
	[ -z "$mesa" ] && mesa="$HOME/Desktop"
	if [ -d "$mesa" ]; then
		atalho="$mesa/kikiu-teste.desktop"
		printf '%s\n' "$entrada" >"$atalho"
		chmod +x "$atalho"
		# GNOME e afins só abrem atalho da área de trabalho marcado como confiável; no KDE basta o chmod +x
		command -v gio >/dev/null 2>&1 && gio set "$atalho" metadata::trusted true 2>/dev/null || true
		echo "Atalho 'KIKIU (teste)' criado em $atalho e no menu de aplicativos."
	else
		echo "Atalho 'KIKIU (teste)' criado no menu de aplicativos ($menu). Não achei a pasta da área de trabalho."
	fi
	command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
	exit 0
fi

# 1) Qual é a build mais nova?
tag=""
url=""
if json="$(curl -fsSL --max-time 10 -H "User-Agent: kikiu-lancador" "https://api.github.com/repos/$REPO/releases/latest")"; then
	tag="$(printf '%s' "$json" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')"
	url="$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*\.AppImage"' | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')"
	[ -z "$url" ] && tag=""
else
	echo "Sem resposta do GitHub; vou abrir a última build baixada."
fi

atual=""
[ -f "$ARQ_ATUAL" ] && atual="$(tr -d '[:space:]' <"$ARQ_ATUAL")"

# 2) Baixa se for nova
if [ -n "$tag" ] && { [ "$tag" != "$atual" ] || [ ! -f "$BUILDS/$tag.AppImage" ]; }; then
	echo "Baixando a build $tag ..."
	tmp="$BUILDS/$tag.AppImage.tmp"
	if curl -L --fail --retry 3 --silent --show-error -o "$tmp" "$url"; then
		chmod +x "$tmp"
		mv -f "$tmp" "$BUILDS/$tag.AppImage"
		printf '%s\n' "$tag" >"$ARQ_ATUAL"
		# guarda só a build atual e a anterior
		for f in "$BUILDS"/*.AppImage; do
			n="$(basename "$f" .AppImage)"
			[ "$n" != "$tag" ] && [ "$n" != "$atual" ] && rm -f "$f"
		done
		atual="$tag"
	else
		rm -f "$tmp"
		echo "Falhou o download."
	fi
fi

# 3) Abre o jogo
app="$BUILDS/$atual.AppImage"
if [ -z "$atual" ] || [ ! -f "$app" ]; then
	avisar "Não consegui baixar o jogo e não há nenhuma build guardada. Confira a internet e tente de novo. Log: $BASE/ultimo_log.txt"
	exit 1
fi
if [ "$sem_abrir" = 1 ]; then
	echo "Pronto para jogar: $app"
	exit 0
fi
cd "$BUILDS" || exit 1
# o AppImage precisa do FUSE 2 (no Arch: sudo pacman -S fuse2); sem ele, roda extraindo numa pasta temporária (mais lento)
if command -v fusermount >/dev/null 2>&1; then
	exec "$app"
else
	echo "Sem fusermount (pacote fuse2): abrindo com --appimage-extract-and-run."
	exec "$app" --appimage-extract-and-run
fi
