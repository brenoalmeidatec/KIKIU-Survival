#!/usr/bin/env bash
# Formata os scripts GDScript do K.I.K.I.U com gdformat (gdtoolkit 4.x).
# Uso:  jogos/hordas/formatar.sh            -> reescreve os arquivos
#       jogos/hordas/formatar.sh --check    -> so confere (sai com 1 se algo mudaria)
# Precisa de: pip install "gdtoolkit==4.*"  (Python 3.12 recomendado)
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
ALVO=("$RAIZ/jogos/hordas/projeto/scripts" "$RAIZ/jogos/hordas/projeto/testes")
if ! command -v gdformat >/dev/null 2>&1; then
  echo "gdformat nao encontrado. Instale com: pip install \"gdtoolkit==4.*\"" >&2
  exit 2
fi
if [ "${1:-}" = "--check" ]; then
  gdformat --check "${ALVO[@]}"
else
  gdformat "${ALVO[@]}"
fi
