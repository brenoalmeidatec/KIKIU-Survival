# Instruções para o Claude Code neste repositório

Este repo é trabalhado por várias sessões do Claude ao mesmo tempo: o Claude do Breno e o Claude do Alisson, que roda em
**duas máquinas** (PC e notebook). Elas não compartilham conversa nem memória, e **o único canal entre elas é o GitHub**.
As regras gerais estão no `CONTRIBUTING.md` e o histórico, no `LOGBOOK.md`. O `README.md` da raiz é só a vitrine do jogo
(sem detalhe técnico nem processo interno); o técnico fica no README de cada pasta.

## Ao começar uma sessão
1. `git fetch --all --prune` e `git switch main && git pull --ff-only`.
2. Leia no fim do `LOGBOOK.md` as entradas novas desde a última com a sua assinatura e procure linhas
   **"Para o Claude do Alisson:"** / **"Para o Claude do Breno:"**.
3. `gh pr list` e `gh issue list` (repo `brenoalmeidatec/KIKIU-Survival`, antigo `Jogao-gamer`: o GitHub redireciona o nome velho): veja PRs abertos, issues novas e comentários recentes.
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

## Autonomia total (ordem do Breno, 2026-10-05)
O Claude do Alisson (PC e notebook) **trabalha sozinho neste repositório**. O Breno e o Claude dele só testam e delegam tarefas novas.
- Pode **criar branches, abrir e mergear os próprios PRs** na `main`, e seguir a fila de tarefas (issue #32, #21 e o que sobrar de `docs/ANALISE_10_JOGOS_HORDAS.md`) **sem pedir aprovação a cada passo**.
- Pode **propor e abrir issues novas** com o que achar que falta no jogo, e decidir design, arte, mecânicas, arquitetura e ordem de trabalho.
- A revisão do Claude do Breno **deixa de ser um portão**: ele só comenta e avisa se algo quebrar o build.
- Registre cada marco no `LOGBOOK.md`. A cada marco novo, o Breno gera o zip para testar.
- **Limites que continuam:** nada de senhas, chaves ou credenciais no repositório; não apagar o repositório nem reescrever o histórico da `main` (sem force-push); nada pago sem o Breno; a Cairu fica como está, a menos que seja preciso mexer na engine compartilhada.

## Divisão de trabalho entre os Claudes (combinado em 2026-10-10)
Os dois Claudes têm limites muito diferentes: o **Claude do Breno** roda no plano Pro (US$ 20, pouco uso por janela) e o **Claude do Alisson** no plano Max (US$ 100 ou mais, uso alto, agentes em paralelo). Para render o máximo dos dois, cada um fica com o que o outro não consegue fazer bem.

**Claude do Breno: decisões, testes e conteúdo (pouco token, muito valor)**
- **Testar a Release** mais nova na máquina de testes (i5-3470) e relatar numa issue: o que sentiu, o que travou, o que o F3 mostra e prints da tela. Esse é o retorno mais valioso para o projeto, porque o notebook e o PC não reproduzem a máquina fraca.
- **Decidir com o Breno e registrar em uma linha** na issue: aprovar ou recusar propostas, escolher entre opções e dar o OK de marco ("aprovado", "não", "quero a opção 2"). Não precisa reescrever o plano.
- **Conteúdo que só o Breno sabe:** histórias e falas dos amigos, nomes, piadas internas, o que cada herói tem de cada um. Pode mandar em texto solto: o Claude do Alisson transforma em dados.
- **Ajustes pequenos de números** em `jogos/hordas/projeto/dados/*.json` (preço, vida, dano), direto num PR curto, depois de jogar.
- **Ações de admin do GitHub** que só a conta do Breno faz: configurações do repositório (#95), criar repositórios (#106) e dar acesso.
- **Evitar:** rodar a bateria inteira de testes, gerar arte no Blender, refatorar, ler o LOGBOOK inteiro (leia só o fim) e abrir sessões longas. Isso estoura o limite do plano Pro.

**Claude do Alisson: implementação e trabalho pesado**
- Implementar os marcos (código, arte no Blender, dados), com testes, CI, PR e merge, inclusive com agentes em paralelo.
- Medir desempenho, gerar o executável, o instalador e as Releases.
- Transformar o retorno do Breno (testes, decisões, histórias) em mudanças no jogo.
- Manter o LOGBOOK, as issues e o painel em dia.
- Sempre que precisar de algo do Breno, deixar **uma pergunta curta e fechada** na issue (sim ou não, ou opção A, B ou C) com um padrão já escolhido, e seguir com o padrão se não houver resposta.

**Ritmo:** a cada marco, o Claude do Alisson avisa na issue o que testar (no máximo 3 itens) e o Claude do Breno responde depois de jogar. Sem resposta, o trabalho segue pelo padrão.
