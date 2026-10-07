#!/usr/bin/env bash
# Escreve projeto/dados/versao.json com a data e o commit atuais. Rode ANTES de exportar o .exe (README > "Gerar o executável"):
# o título do jogo mostra "v<application/config/version> · <data> · <commit>" no canto, pra saber de que build é o .exe.
# Sem este arquivo o jogo mostra "dev". O arquivo é gerado (fica no .gitignore), não vai pro Git.
set -e
cd "$(dirname "$0")"
commit=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then commit="$commit+"; fi   # "+" = tinha mudança sem commit
data=$(date +%Y-%m-%d)
printf '{"data": "%s", "commit": "%s"}\n' "$data" "$commit" > projeto/dados/versao.json
echo "projeto/dados/versao.json: $data $commit"
