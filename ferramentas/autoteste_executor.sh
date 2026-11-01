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
export SLEEP_REAL
SLEEP_REAL=$(command -v sleep)
cat > "$GODOT" <<'PROGRAMA'
#!/usr/bin/env bash
case "${!#}" in
  */sucesso.tscn|*/regras_armas.tscn) echo 'teste falhas=0' ;;
  */codigo7.tscn) echo 'teste falhas=0'; exit 7 ;;
  */timeout.tscn) echo 'teste falhas=0'; sleep 10 ;;
  */crash.tscn) echo 'teste falhas=0'; kill -SEGV $$ ;;
  */kill.tscn) echo 'teste falhas=0'; kill -KILL $$ ;;
  */ignora_term.tscn|*/interrompida.tscn) trap '' TERM; echo 'teste falhas=0'; while :; do sleep 0.05; done ;;
  */script.tscn) echo 'teste falhas=0'; echo 'SCRIPT ERROR: simulado' ;;
  */incompleta.tscn) echo 'sem resultado' ;;
  */marca_invalida.tscn) echo 'teste falhas=00' ;;
  */lenta.tscn) echo 'parcial antes da espera'; sleep 0.5; echo 'teste falhas=0' ;;
esac
PROGRAMA
# Reduz somente o timeout do caso substituto. Confere os limites da producao.
cat > "$PASTA/bin/timeout" <<'PROGRAMA'
#!/usr/bin/env bash
set -eu
[ "$1" = --verbose ] && [ "$2" = --kill-after=5 ] || exit 99
shift 2
if [[ "${!#}" == */regras_armas.tscn ]]; then
  [ "$1" = 300 ] || exit 99
else
  [ "$1" = 120 ] || exit 99
fi
if [[ "${!#}" == */interrompida.tscn ]]; then
  shift
  exec "$TIMEOUT_REAL" --verbose --kill-after=0.1 5 "$@"
fi
if [[ "${!#}" == */timeout.tscn || "${!#}" == */ignora_term.tscn ]]; then
  shift
  exec "$TIMEOUT_REAL" --verbose --kill-after=0.1 0.2 "$@"
fi
exec "$TIMEOUT_REAL" --verbose --kill-after=5 "$@"
PROGRAMA
# Acelera apenas o aviso de 30 s; limites do executor continuam verificados acima.
cat > "$PASTA/bin/sleep" <<'PROGRAMA'
#!/usr/bin/env bash
if [ "$1" = 30 ]; then
  exec "$SLEEP_REAL" 0.05
fi
exec "$SLEEP_REAL" "$@"
PROGRAMA
chmod +x "$GODOT" "$PASTA/bin/timeout" "$PASTA/bin/sleep"
export PATH="$PASTA/bin:$PATH"
falhas=0
conferir() {
  local cena="$1" esperado="$2" resultado pid observou=0
  if [ "$cena" = lenta ]; then
    bash "$RAIZ/ferramentas/testes_ci.sh" --uma "$cena" > "$PASTA/$cena.progresso" &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
      if grep -q '^EM EXECUCAO lenta;' "$PASTA/$cena.progresso" &&
        grep -q 'parcial antes da espera' "$LOGS/$cena.log" && [ ! -e "$LOGS/$cena.res" ]; then
        observou=1
        break
      fi
      sleep 0.01
    done
    wait "$pid"
    [ "$observou" -eq 1 ] || falhas=$((falhas + 1))
  else
    bash "$RAIZ/ferramentas/testes_ci.sh" --uma "$cena" > "$PASTA/$cena.progresso"
  fi
  resultado=$(cat "$LOGS/$cena.res")
  if [[ "$resultado" == "$esperado"* ]]; then
    printf 'ok %s: %s\n' "$cena" "$resultado"
  else
    printf 'FALHOU %s: esperado=%s obtido=%s\n' "$cena" "$esperado" "$resultado"
    falhas=$((falhas + 1))
  fi
  grep -q 'EXECUTOR:' "$LOGS/$cena.log" || falhas=$((falhas + 1))
  grep -q "^INICIO $cena; limite=" "$PASTA/$cena.progresso" || falhas=$((falhas + 1))
  grep -q "^FIM $cena; .*duracao=[0-9]*s$" "$PASTA/$cena.progresso" || falhas=$((falhas + 1))
  # Nenhum monitor pode continuar escrevendo depois do FIM, nem manter o stdout aberto.
  [ "$(tail -1 "$PASTA/$cena.progresso")" = "$(grep '^FIM ' "$PASTA/$cena.progresso")" ] || falhas=$((falhas + 1))
}
conferir sucesso ok
conferir codigo7 'falha do processo (codigo 7)'
conferir timeout 'timeout (codigo 124'
conferir crash 'crash/sinal (codigo 139'
conferir kill 'crash/sinal (codigo 137'
conferir ignora_term 'timeout forcado (codigo 137'
conferir script 'SCRIPT ERROR'
conferir incompleta "sem 'falhas=0'"
conferir marca_invalida "sem 'falhas=0'"
conferir regras_armas ok
conferir lenta ok
grep -q '^EM EXECUCAO lenta; decorrido=' "$PASTA/lenta.progresso" || falhas=$((falhas + 1))
grep -q 'parcial antes da espera' "$LOGS/lenta.log" || falhas=$((falhas + 1))
# Aguarda mais de um intervalo simulado: monitor nao pode sobreviver ao encerramento.
cp "$PASTA/lenta.progresso" "$PASTA/lenta.antes"
sleep 0.15
cmp -s "$PASTA/lenta.antes" "$PASTA/lenta.progresso" || falhas=$((falhas + 1))

# Interromper o executor tambem limpa o monitor; nao publica resultado incompleto.
bash "$RAIZ/ferramentas/testes_ci.sh" --uma interrompida > "$PASTA/interrompida.progresso" &
pid=$!
while kill -0 "$pid" 2>/dev/null && ! grep -q '^EM EXECUCAO interrompida;' "$PASTA/interrompida.progresso"; do
  sleep 0.01
done
kill "$pid" 2>/dev/null || falhas=$((falhas + 1))
codigo=0
wait "$pid" || codigo=$?
[ "$codigo" -eq 143 ] || falhas=$((falhas + 1))
[ ! -e "$LOGS/interrompida.res" ] || falhas=$((falhas + 1))
cp "$PASTA/interrompida.progresso" "$PASTA/interrompida.antes"
sleep 0.15
cmp -s "$PASTA/interrompida.antes" "$PASTA/interrompida.progresso" || falhas=$((falhas + 1))
echo "autoteste_executor falhas=$falhas"
[ "$falhas" -eq 0 ]
