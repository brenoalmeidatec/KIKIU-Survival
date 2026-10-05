# Instruções para o Claude Code neste repositório

Este repo é trabalhado por várias sessões do Claude ao mesmo tempo: o Claude do Breno e o Claude do Alisson, que roda em
**duas máquinas** (PC e notebook). Elas não compartilham conversa nem memória, e **o único canal entre elas é o GitHub**.
As regras gerais estão no `README.md` (seção "Regras para manter o repositório atualizado") e o histórico, no `LOGBOOK.md`.

## Ao começar uma sessão
1. `git fetch --all --prune` e `git switch main && git pull --ff-only`.
2. Leia no fim do `LOGBOOK.md` as entradas novas desde a última com a sua assinatura e procure linhas
   **"Para o Claude do Alisson:"** / **"Para o Claude do Breno:"**.
3. `gh pr list` e `gh issue list` (repo `brenoalmeidatec/Jogao-gamer`): veja PRs abertos, issues novas e comentários recentes.
4. Antes de pegar uma tarefa, **reserve**: comente na issue ("pegando o item X, máquina PC") ou abra logo um PR em rascunho.
   Se a outra máquina já reservou, escolha outra coisa ou continue na branch dela (`git switch <branch>` e `git pull`).

## Ao terminar (ou quando o contexto estiver perto do limite)
1. **Nenhum trabalho fica só numa máquina:** faça commit e `git push` da branch mesmo se estiver pela metade, e abra o PR
   como rascunho (`gh pr create --draft`) se não estiver pronto.
2. Acrescente uma entrada no fim do `LOGBOOK.md` (feito / pendente / próximo, e recados).
3. Assine com a máquina: `Claude do Alisson (PC)` ou `Claude do Alisson (notebook)`. Assim a outra sessão sabe onde
   procurar algo que não chegou ao GitHub.

## O que não vai aqui
Fatos que só valem para uma máquina (caminho do Godot 4.4.1, configurações do git) ficam no `CLAUDE.local.md` dessa
máquina, que está fora do Git. A memória do Claude (`~/.claude/...`) também é de uma máquina só: o que a outra sessão
precisar saber vai no `LOGBOOK.md`, numa issue ou num PR.
