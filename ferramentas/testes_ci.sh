#!/usr/bin/env bash
# Roda as cenas de teste do jogo (jogos/hordas/projeto/testes/*.tscn) em paralelo.
#
# Uso (a partir da raiz do repo): bash ferramentas/testes_ci.sh <godot> [paralelas] [i/N]
#   paralelas: padrao 4 (cada cena e um processo Godot headless).
#   i/N: opcional; roda so o shard i de N (1 <= i <= N). Sem ele, roda tudo.
#   bash ferramentas/testes_ci.sh --listar i/N   so lista as cenas do shard (sem Godot).
# Shards: as unidades sao distribuidas de forma deterministica e gulosa pelo tempo
# (maior primeiro, para o shard com menos tempo acumulado; empate: menor indice),
# lendo ferramentas/tempos_testes.txt ("nome segundos"); cena ausente vale $PADRAO_S s.
#
# Uma cena passa apenas com codigo 0, "falhas=0" e sem "SCRIPT ERROR".
# Timeout (124), crash (sinal) e falha comum ficam distintos no resultado e no log.
# Limite: 120 s por cena; regras_armas, que e lenta, tem 300 s.
# bench_* ficam de fora. criacao e criacao2 gravam o mesmo arquivo de heroi
# (user://teste_heroi_criado.json e user://teste_criacao2.json), por isso rodam
# em sequencia dentro da mesma unidade, nunca em paralelo.
# SOZINHAS: cenas que conferem que os arquivos reais do jogo (save, opcoes.cfg,
# online.json) nao mudaram durante elas; com outra cena gravando em user:// ao
# mesmo tempo, acusam falso positivo. Rodam no fim do shard, uma por vez, com
# nada em paralelo.
SOZINHAS=" v2_playtest v2_status "
# Logs completos de cada cena ficam em $LOGS (pasta temporaria).

set -u

# Modo interno, chamado pelo xargs: roda as cenas da unidade, uma apos a outra.
# Recebe GODOT, LOGS (exportados) e o diretorio atual = jogos/hordas/projeto.
rodar_uma() {
  local n="$1" saida codigo limite=120 resultado
  # regras_armas (v1) leva de 100 a 290 s: passa ou estoura os 120 s conforme a carga da maquina, e bloqueava todo PR.
  [ "$n" = "regras_armas" ] && limite=300
  if saida=$(timeout "$limite" "$GODOT" --headless --path . "res://testes/$n.tscn" 2>&1); then
    codigo=0
  else
    codigo=$?
  fi
  printf '%s\n' "$saida" > "$LOGS/$n.log"
  if [ "$codigo" -eq 124 ]; then
    resultado="timeout (codigo 124, limite ${limite}s)"
  elif [ "$codigo" -gt 128 ]; then
    resultado="crash/sinal (codigo $codigo, sinal $((codigo - 128)))"
  elif [ "$codigo" -ne 0 ]; then
    resultado="falha do processo (codigo $codigo)"
  elif grep -q "SCRIPT ERROR" <<<"$saida"; then
    resultado="SCRIPT ERROR (codigo 0)"
  elif grep -Eq '(^|[[:space:]])falhas=0([[:space:]]|$)' <<<"$saida"; then
    resultado="ok"
  else
    resultado="sem 'falhas=0' (codigo 0, saida incompleta)"
  fi
  printf '%s\n' "$resultado" > "$LOGS/$n.res"
  printf '\nEXECUTOR: %s; codigo=%s; limite=%ss\n' "$resultado" "$codigo" "$limite" >> "$LOGS/$n.log"
}

if [ "${1:-}" = "--uma" ]; then
  for n in $2; do rodar_uma "$n"; done
  exit 0
fi

PADRAO_S=15
LISTAR=0
if [ "${1:-}" = "--listar" ]; then
  LISTAR=1
  SHARD="${2:?uso: testes_ci.sh --listar i/N}"
else
  GODOT=$(readlink -f "${1:?uso: testes_ci.sh <godot> [paralelas] [i/N]}")
  P="${2:-4}"
  SHARD="${3:-}"
fi
if [ -n "$SHARD" ]; then
  if ! [[ "$SHARD" =~ ^([0-9]+)/([0-9]+)$ ]] || [ "${BASH_REMATCH[1]}" -lt 1 ] ||
    [ "${BASH_REMATCH[1]}" -gt "${BASH_REMATCH[2]}" ]; then
    echo "shard invalido: '$SHARD' (use i/N, com 1 <= i <= N)" >&2
    exit 2
  fi
  SH_I=${BASH_REMATCH[1]}
  SH_N=${BASH_REMATCH[2]}
fi
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
SELF=$(readlink -f "$0")
cd "$RAIZ/jogos/hordas/projeto" || exit 1

mapfile -t todas < <(ls testes/*.tscn | sed 's#^testes/##; s#\.tscn$##' | LC_ALL=C sort)
cenas_todas=()
bench=0
for n in "${todas[@]}"; do
  case "$n" in
    bench_*) bench=$((bench + 1)); continue ;;
  esac
  cenas_todas+=("$n")
done

# Unidades de trabalho: uma cena, ou criacao + criacao2 em sequencia.
unidades=()
for n in "${cenas_todas[@]}"; do
  case "$n" in
    criacao2) ;;                                  # ja vai junto com criacao
    criacao) unidades+=("criacao criacao2") ;;
    *) unidades+=("$n") ;;
  esac
done

if [ -n "$SHARD" ]; then
  # Guloso deterministico: custo da unidade = soma dos tempos das cenas (em decimos de s).
  mapfile -t unidades < <(printf '%s\n' "${unidades[@]}" | awk -v i="$SH_I" -v n="$SH_N" -v pad="$PADRAO_S" \
    -v arq="$RAIZ/ferramentas/tempos_testes.txt" '
    BEGIN { while ((getline l < arq) > 0) { if (l ~ /^#/ || l == "") continue; split(l, c, " "); t[c[1]] = c[2] } }
    { u[NR] = $0; custo = 0; k = split($0, cs, " ")
      for (j = 1; j <= k; j++) custo += (cs[j] in t) ? t[cs[j]] : pad
      ct[NR] = int(custo * 10 + 0.5) }
    END {
      m = NR
      for (a = 1; a <= m; a++) ord[a] = a
      # ordena por custo desc, depois nome asc (insercao: m < 200)
      for (a = 2; a <= m; a++) { x = ord[a]; b = a - 1
        while (b >= 1 && (ct[ord[b]] < ct[x] || (ct[ord[b]] == ct[x] && u[ord[b]] > u[x]))) { ord[b + 1] = ord[b]; b-- }
        ord[b + 1] = x }
      for (s = 1; s <= n; s++) soma[s] = 0
      for (a = 1; a <= m; a++) { x = ord[a]; best = 1
        for (s = 2; s <= n; s++) if (soma[s] < soma[best]) best = s
        soma[best] += ct[x]
        if (best == i) print u[x] }
      printf "%.1f\n", soma[i] / 10 > "/dev/stderr"
    }' 2>"${TMPDIR:-/tmp}/testes_ci_shard_$$.txt")
  estimado=$(cat "${TMPDIR:-/tmp}/testes_ci_shard_$$.txt")
  rm -f "${TMPDIR:-/tmp}/testes_ci_shard_$$.txt"
fi

# Cenas deste shard (ou todas), na ordem alfabetica, para o relatorio.
cenas=()
for n in "${cenas_todas[@]}"; do
  for un in "${unidades[@]}"; do
    for c in $un; do [ "$c" = "$n" ] && cenas+=("$n"); done
  done
done
total=${#cenas[@]}

if [ "$LISTAR" -eq 1 ]; then
  printf '%s\n' "${cenas[@]}"
  exit 0
fi

# Confere a classificacao do executor antes da bateria; --uma e --listar nao entram aqui.
bash "$RAIZ/ferramentas/autoteste_executor.sh" || exit 1
LOGS="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/testes-logs"
rm -rf "$LOGS" && mkdir -p "$LOGS"
export GODOT LOGS

[ -n "$SHARD" ] && echo "Shard $SHARD: ${#unidades[@]} unidades, tempo somado estimado ${estimado}s (de ${#cenas_todas[@]} cenas no total)."
echo "Cenas: $total para rodar (de ${#todas[@]} .tscn; bench_* fora: $bench). Paralelas: $P. Unidades: ${#unidades[@]}."
inicio=$SECONDS
paralelas=()
sozinhas=()
for un in "${unidades[@]}"; do
  if [[ "$SOZINHAS" == *" $un "* ]]; then sozinhas+=("$un"); else paralelas+=("$un"); fi
done
if [ ${#paralelas[@]} -gt 0 ]; then
  printf '%s\n' "${paralelas[@]}" | xargs -d '\n' -P "$P" -I{} bash "$SELF" --uma {}
fi
for un in "${sozinhas[@]}"; do
  bash "$SELF" --uma "$un"
done
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
    if [[ "$res" == "SCRIPT ERROR"* ]]; then
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
