#!/usr/bin/env bash
# Executa o binario exportado, sem acesso ao projeto-fonte nem ao save de outra execucao.
set -euo pipefail

binario="$(realpath "${1:?informe o executavel Linux exportado}")"
log="$(realpath -m "${2:?informe o caminho do log}")"
test -s "$binario"
chmod +x "$binario"
file "$binario"
file "$binario" | grep -Eq 'ELF 64-bit LSB.*x86-64'
# ldd retorna 1 para um executavel estatico; dependencias dinamicas ausentes continuam sendo erro.
dependencias="$(ldd "$binario" 2>&1 || true)"
printf '%s\n' "$dependencias"
if grep -q 'not found' <<< "$dependencias"; then
  echo 'Dependencia dinamica ausente no runner Linux.' >&2
  exit 1
fi

isolado="$(mktemp -d)"
trap 'rm -rf -- "$isolado"' EXIT
mkdir -p "$(dirname "$log")" "$isolado/dados" "$isolado/config" "$isolado/cache" "$isolado/pacote"
# Copiar somente o executavel confirma que o PCK esta embutido como pede o preset.
cp "$binario" "$isolado/pacote/KIKIU.x86_64"
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
timeout --signal=TERM --kill-after=10s 90s ./KIKIU.x86_64 --headless --quit-after 120 --log-file "$log" > "$log.stdout" 2>&1
codigo=$?
set -e
cat "$log.stdout"
test -f "$log" && cat "$log"
if [ "$codigo" -ne 0 ]; then
  echo "Smoke Linux falhou: codigo $codigo (124 indica timeout)." >&2
  exit "$codigo"
fi
test -s "$log"
grep -q 'Godot Engine v4.4.1.stable' "$log"
# O --quit-after encerra no meio da cena e o motor reclama de recurso ainda em uso na saida: isso nao e erro do pacote.
if cat "$log" "$log.stdout" | grep -Eiv 'resources still in use at exit' |
  grep -Eiq '(^|[[:space:]])ERROR:|SCRIPT ERROR|Parse Error|Failed loading resource|Error loading resource|Cannot open file|no valid main pack'; then
  echo 'Smoke Linux encontrou erro do motor, script ou recurso no pacote exportado.' >&2
  exit 1
fi
# Migracao do save (scripts/hordas/migracao_save.gd): copiou para a pasta propria, gravou o marcador e deixou a antiga intacta.
test -f "$nova/migrado_da_pasta_godot.txt"
grep -q 'mostrar_fps=true' "$nova/opcoes.cfg"
test "$hash_antiga" = "$(sha256sum "$antiga/opcoes.cfg")"
echo 'Smoke Linux: ELF x86_64 executou a cena principal com PCK embutido, save isolado e migracao do save antigo.'
