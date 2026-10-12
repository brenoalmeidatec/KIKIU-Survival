#!/usr/bin/env bash
# Roda as cenas de teste do jogo (jogos/hordas/projeto/testes/*.tscn) em paralelo.
#
# Uso (a partir da raiz do repo): bash ferramentas/testes_ci.sh <godot> [paralelas]
#   paralelas: padrao 4 (cada cena e um processo Godot headless).
#
# Criterio de falha (o mesmo de antes do paralelismo): a saida da cena tem
# "SCRIPT ERROR", ou nao tem "falhas=0". Cena que estoura 120 s tambem falha (regras_armas, que e lenta, tem 300 s).
# bench_* ficam de fora. criacao e criacao2 gravam o mesmo arquivo de heroi
# (user://teste_heroi_criado.json e user://teste_criacao2.json), por isso rodam
# em sequencia dentro da mesma unidade, nunca em paralelo.
# Logs completos de cada cena ficam em $LOGS (pasta temporaria).

set -u

# Modo interno, chamado pelo xargs: roda as cenas da unidade, uma apos a outra.
# Recebe GODOT, LOGS (exportados) e o diretorio atual = jogos/hordas/projeto.
rodar_uma() {
  local n="$1" saida limite=120
  # regras_armas (v1) leva de 100 a 290 s: passa ou estoura os 120 s conforme a carga da maquina, e bloqueava todo PR.
  [ "$n" = "regras_armas" ] && limite=300
  saida=$(timeout "$limite" "$GODOT" --headless --path . "res://testes/$n.tscn" 2>&1) || true
  printf '%s\n' "$saida" > "$LOGS/$n.log"
  if grep -q "SCRIPT ERROR" <<<"$saida"; then
    echo "SCRIPT ERROR" > "$LOGS/$n.res"
  elif grep -q "falhas=0" <<<"$saida"; then
    echo "ok" > "$LOGS/$n.res"
  else
    echo "sem 'falhas=0' (timeout ou saida incompleta)" > "$LOGS/$n.res"
  fi
}

if [ "${1:-}" = "--uma" ]; then
  for n in $2; do rodar_uma "$n"; done
  exit 0
fi

GODOT=$(readlink -f "${1:?uso: testes_ci.sh <godot> [paralelas]}")
P="${2:-4}"
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
SELF=$(readlink -f "$0")
cd "$RAIZ/jogos/hordas/projeto" || exit 1
LOGS="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/testes-logs"
rm -rf "$LOGS" && mkdir -p "$LOGS"
export GODOT LOGS

mapfile -t todas < <(ls testes/*.tscn | sed 's#^testes/##; s#\.tscn$##' | sort)
cenas=()
bench=0
for n in "${todas[@]}"; do
  case "$n" in
    bench_*) bench=$((bench + 1)); continue ;;
  esac
  cenas+=("$n")
done
total=${#cenas[@]}

# Unidades de trabalho: uma cena, ou criacao + criacao2 em sequencia.
unidades=()
for n in "${cenas[@]}"; do
  case "$n" in
    criacao2) ;;                                  # ja vai junto com criacao
    criacao) unidades+=("criacao criacao2") ;;
    *) unidades+=("$n") ;;
  esac
done

echo "Cenas: $total para rodar (de ${#todas[@]} .tscn; bench_* fora: $bench). Paralelas: $P. Unidades: ${#unidades[@]}."
inicio=$SECONDS
printf '%s\n' "${unidades[@]}" | xargs -d '\n' -P "$P" -I{} bash "$SELF" --uma {}
dur=$((SECONDS - inicio))

ok=0
falhas=0
for n in "${cenas[@]}"; do
  res=$(cat "$LOGS/$n.res" 2>/dev/null || echo "sem resultado (a cena nao rodou)")
  if [ "$res" = "ok" ]; then
    echo "ok   $n"
    ok=$((ok + 1))
  else
    falhas=$((falhas + 1))
    echo "::error::$n: $res"
    echo "::group::saida de $n"
    if [ "$res" = "SCRIPT ERROR" ]; then
      grep -A3 "SCRIPT ERROR" "$LOGS/$n.log" | head -20
    else
      tail -25 "$LOGS/$n.log" 2>/dev/null
    fi
    echo "::endgroup::"
  fi
done

rodadas=$(ls "$LOGS"/*.res 2>/dev/null | wc -l)
echo "Resumo: cenas $total | rodadas $rodadas | ok $ok | falhas $falhas | ${dur}s"
if [ "$rodadas" -ne "$total" ]; then
  echo "::error::a contagem nao bate: $rodadas resultados para $total cenas"
  exit 1
fi
[ "$falhas" -eq 0 ]
