#!/usr/bin/env bash
# Teste do nome do AppImage (#590): tem de levar o config/version e o sufixo build-<data>-<commit>.
# Uso: teste_nome.sh   (sem rede, sem Godot)
set -euo pipefail
aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

printf '[application]\nconfig/name="K.I.K.I.U"\nconfig/version="2.0.0"\n' > "$tmp/project.godot"
nome="$(KIKIU_DATA=2026-11-06 KIKIU_COMMIT=1ed0b56 bash "$aqui/nome.sh" "$tmp/project.godot")"
test "$nome" = "KIKIU-2.0.0-build-2026-11-06-1ed0b56-x86_64.AppImage" || { echo "nome errado: $nome" >&2; exit 1; }

# quatro componentes tambem valem (mesma regra do .exe)
printf 'config/version="2.1.3.4"\n' > "$tmp/project.godot"
nome="$(KIKIU_DATA=2026-11-06 KIKIU_COMMIT=abc1234 bash "$aqui/nome.sh" "$tmp/project.godot")"
test "$nome" = "KIKIU-2.1.3.4-build-2026-11-06-abc1234-x86_64.AppImage" || { echo "nome errado: $nome" >&2; exit 1; }

# versao invalida reprova
printf 'config/version="v2"\n' > "$tmp/project.godot"
if bash "$aqui/nome.sh" "$tmp/project.godot" 2>/dev/null; then echo "aceitou versao invalida" >&2; exit 1; fi

# o montar.sh tem de usar o nome.sh (nao reconstruir o nome por conta propria) e o glob do workflow ainda casar
grep -q 'nome.sh' "$aqui/montar.sh" || { echo "montar.sh nao usa nome.sh" >&2; exit 1; }
case "KIKIU-2.0.0-build-2026-11-06-1ed0b56-x86_64.AppImage" in KIKIU-*-x86_64.AppImage) ;; *) exit 1 ;; esac
echo "teste_nome: ok"
