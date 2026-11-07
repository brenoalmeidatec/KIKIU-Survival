#!/usr/bin/env bash
# Imprime o nome do AppImage: KIKIU-<config/version>-build-<AAAA-MM-DD>-<commit>-x86_64.AppImage (#590).
# Uso: nome.sh [project.godot]. KIKIU_DATA e KIKIU_COMMIT existem so para o teste fixar data e commit.
set -euo pipefail

aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
projeto="$(realpath "${1:-$aqui/../../jogos/hordas/projeto/project.godot}")"
versao="$(sed -n 's/^config\/version="\([^"]*\)".*/\1/p' "$projeto" | head -n1)"
[[ "$versao" =~ ^[0-9]+(\.[0-9]+){2,3}$ ]] || { echo "config/version invalido: '$versao'" >&2; exit 1; }
data="${KIKIU_DATA:-$(date -u +%Y-%m-%d)}"
commit="${KIKIU_COMMIT:-$(git -C "$aqui" rev-parse --short HEAD 2>/dev/null || echo local)}"
# O trecho build-<data>-<commit> e o mesmo sufixo do tag da Release; a versao vem na frente para o arquivo dizer qual versao do jogo e.
echo "KIKIU-$versao-build-$data-$commit-x86_64.AppImage"
