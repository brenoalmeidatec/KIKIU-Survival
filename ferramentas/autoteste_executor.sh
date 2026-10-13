#!/usr/bin/env bash
# Autoteste isolado: usa o executor real com um substituto, sem importar o Godot.
# Rodar da raiz: bash ferramentas/autoteste_executor.sh
set -eu
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
PASTA=$(mktemp -d)
trap 'rm -rf "$PASTA"' EXIT
mkdir -p "$PASTA/bin" "$PASTA/logs"
export GODOT="$PASTA/godot-falso" LOGS="$PASTA/logs"
export TIMEOUT_REAL
TIMEOUT_REAL=$(command -v timeout)
cat > "$GODOT" <<'PROGRAMA'
#!/usr/bin/env bash
case "${!#}" in
  */sucesso.tscn|*/regras_armas.tscn) echo 'teste falhas=0' ;;
  */codigo7.tscn) echo 'teste falhas=0'; exit 7 ;;
  */timeout.tscn) echo 'teste falhas=0'; sleep 10 ;;
  */crash.tscn) echo 'teste falhas=0'; kill -SEGV $$ ;;
  */script.tscn) echo 'teste falhas=0'; echo 'SCRIPT ERROR: simulado' ;;
  */incompleta.tscn) echo 'sem resultado' ;;
  */marca_invalida.tscn) echo 'teste falhas=00' ;;
esac
PROGRAMA
# Reduz somente o timeout do caso substituto. Confere os limites da producao.
cat > "$PASTA/bin/timeout" <<'PROGRAMA'
#!/usr/bin/env bash
set -eu
if [[ "${!#}" == */regras_armas.tscn ]]; then
  [ "$1" = 300 ] || exit 99
else
  [ "$1" = 120 ] || exit 99
fi
if [[ "${!#}" == */timeout.tscn ]]; then
  shift
  exec "$TIMEOUT_REAL" 0.2 "$@"
fi
exec "$TIMEOUT_REAL" "$@"
PROGRAMA
chmod +x "$GODOT" "$PASTA/bin/timeout"
export PATH="$PASTA/bin:$PATH"
falhas=0
conferir() {
  local cena="$1" esperado="$2" resultado
  bash "$RAIZ/ferramentas/testes_ci.sh" --uma "$cena"
  resultado=$(cat "$LOGS/$cena.res")
  if [[ "$resultado" == "$esperado"* ]]; then
    printf 'ok %s: %s\n' "$cena" "$resultado"
  else
    printf 'FALHOU %s: esperado=%s obtido=%s\n' "$cena" "$esperado" "$resultado"
    falhas=$((falhas + 1))
  fi
  grep -q 'EXECUTOR:' "$LOGS/$cena.log" || falhas=$((falhas + 1))
}
conferir sucesso ok
conferir codigo7 'falha do processo (codigo 7)'
conferir timeout 'timeout (codigo 124'
conferir crash 'crash/sinal (codigo 139'
conferir script 'SCRIPT ERROR'
conferir incompleta "sem 'falhas=0'"
conferir marca_invalida "sem 'falhas=0'"
conferir regras_armas ok
echo "autoteste_executor falhas=$falhas"
[ "$falhas" -eq 0 ]
