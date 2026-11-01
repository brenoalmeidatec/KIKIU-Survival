# Instruções para o Claude Code neste repositório

Este repo é trabalhado por vários agentes ao mesmo tempo: o Claude do Breno, o Claude do Alisson, que roda em **duas
máquinas** (PC e notebook), e o Codex do Alisson (ver "Divisão de trabalho" no fim). Eles não compartilham conversa nem
memória, e **o único canal entre eles é o GitHub**.
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

## V1 pausada, v2 sobre o protótipo (decisão do Alisson, 2026-10-11)
O protótipo 2.5D (`jogos/hordas/projeto/prototipos/cara_nova.tscn`, PR #156) foi aprovado e **é a base da v2**. A v2 cresce em `jogos/hordas/projeto/v2/`, e os dados ficam em `dados/v2_*.json`.
- **A v1** (`main.tscn`, `arena.gd` e o resto do jogo atual) **está pausada**: nada de recurso novo nem refino. Só entra correção de bug grave (crash, save corrompido, build quebrado). Quando um sistema da v1 servir na v2, **porte para a v2**, sem melhorar a v1.
- **A v1 vai ser aposentada** (decisão do Alisson, 2026-10-12): todo o esforço vai para a v2, nada de HUD, desempenho nem recurso novo na v1. A exceção foi o teto de 350 vivos na prorrogação e no Enxame Final (PR #195), pedido por ele. Desde o #194 a v2 é a cena principal e a v1 abre com `-- --v1`.
- O protótipo fica congelado como referência. O que for reaproveitado vira módulo em `v2/`.
- O plano de etapas do épico #152 continua, agora aplicado à v2.
- Antes de mexer em menu/UI da v2, leia jogos/hordas/projeto/v2/DESIGN.md

## Arte e licenças (decisão do Alisson, 2026-10-12)
**Nada de arte com direitos autorais.** Arte, som, fonte e ícone de terceiros de **livre uso** podem e devem ser usados quando economizam esforço e são compatíveis com o nosso contexto (licença que permite uso comercial, redistribuição no jogo e modificação; estilo, escala e luz do jogo). O que vale, o que é proibido e o **registro obrigatório** de cada item (fonte, autor, licença, mudanças) estão em `docs/LICENCAS_ARTE.md` (a música e os sons seguem também o `docs/LICENCAS_AUDIO.md`).
- Antes de usar: confira a licença na página do arquivo **no dia**, registre no `docs/LICENCAS_ARTE.md` e ponha o crédito na tela de Créditos quando a licença pedir.
- Em dúvida (licença copyleft, "só uso pessoal", sem licença declarada), **não use**: pergunte ao Alisson. Pack pago só com o Breno.
- O pipeline do Blender continua sendo o caminho para heróis, monstros e cenários próprios; arte livre complementa e acelera.

## Rumo à RC da v2 (decisão do Alisson, atualizada em 2026-10-29)
A mesma seção está no `CLAUDE.md` e no `AGENTS.md`; quem mudar uma muda a outra.
- **Canal só por arquivo e GitHub:** o Claude e o Codex conversam **apenas** pelos `.md` do repositório, issues, PRs e `LOGBOOK.md`. Nenhum agente aciona o outro direto (nada de `codex exec`, `codex queue`, `claude -p` ou MCP de um no outro) nem lê a conversa do outro para tomar decisão. Quem leva prompt de um lado para o outro é o Alisson.
- **Quem faz o quê (atualizado em 31/10):** desde 31/10 o **Claude do Alisson conduz, revisa e mergeia o código da v2** (com o "pode mergear" do Alisson) e cuida de tags e Releases. O **Codex fica em pausa** até o Alisson avisar; a #467 fica como histórico. O **Isac** segue como diretor de arte (#459), e as notas dele chegam também pelo Alisson (Telegram). Polimento visual de 31/10 em diante usa o pixelfx (MIT, `patch-gg/pixelfx`), com as folhas exportadas fora do repo e a licença em `docs/LICENCAS_ARTE.md`.
- **Quem mergeia:** o **Claude do Alisson**. Desde 31/10 vale o **merge automático** autorizado pelo Alisson, desde que o PR passe em todo o portão: CI 7/7 verde no mesmo commit do head, revisão independente (de um agente que não escreveu o código) com "aprovo" ou "aprovo com ressalvas", sem nenhum "bloqueio", nenhum conflito com a main, e nenhuma mudança em `.github/workflows`, `project.godot`, save, export ou nestas regras. Continuam esperando o "pode mergear" do Alisson: o que falhar nesse último item, tags, Release, Beta 2 e RC, issue de decisão de design e mudança grande de tela que ninguém verificou visualmente. Cada merge automático ganha uma linha no LOGBOOK. Se o Codex voltar, ele abre PR e não mergeia código (a exceção é PR só de doc ou `LOGBOOK.md`).
- **Prazo (decisão do Alisson, 28/10; a fonte da verdade é a #342):** notas do Isac até sex 30/10 (#448). De sáb 31/10 a ter 03/11, aplicar as notas e fazer os sprites dos inimigos de fase (#449). De qua 04 a sex 06/11, **Beta 2** com a tag `v2.0-beta2` (pré-release, #450). De sáb 07 a ter 10/11, polimento. **Sex 13/11, RC.** Lançamento na semana de 16/11. A tag `v2.0-beta` de 23/10 não foi criada e não vai ser: o beta 1 ficou como a build `build-2026-10-23-eeabaac`, e a primeira tag de versão é a `v2.0-beta2` (decisão de 29/10).
- **No notebook** (o Alisson usa até 17h): todo Godot passa pela fila `C:\Dev\KIKIU\notas\godot_fila.ps1`, com `APPDATA` própria por worktree. Feche todo Godot e robô ao terminar. Nunca rode `find` ou busca no disco inteiro. Até 16h30 tudo vai para o GitHub, e nada fica rodando depois disso. O PC entra a partir das 19h.
- **Lições do notebook (29/10):**
  - **Fila do Godot:** cada vaga é um Mutex nomeado (`Local\KIKIU_Godot_vaga_N`). Vaga de processo morto volta sozinha. Mesmo assim, para encerrar um teste preso, mate só o processo do Godot (o filho), nunca o PowerShell da fila. Teste headless que passa de ~10 min parado está travado (erro de parse num script temporário costuma ser a causa).
  - **Worktree nova** nasce sem `.godot`. Rode `--headless --import` pela fila antes dos testes, ou vai aparecer "SCRIPT ERROR" falso.
  - **Medição de UI:** em `--headless` a fonte Spleen mede o dobro (32 px em vez de 16). Nunca compare `size` com `get_minimum_size()`, porque o `size` é forçado ao mínimo e a checagem sempre passa. Meça linhas vezes a altura da fonte em janela contra a caixa de projeto, e prove que o teste falha no código antigo.
  - **Visual:** só vale depois de uma captura com janela de verdade, que não se versiona. Diga no PR o que não foi visto.
  - **Pool de inimigo:** dimensione pelo pico de vivos no mapa, senão o jogo cria nó no meio da partida e engasga no i5.
- **Evidência de QA não vai para o repositório:** JSON bruto de robô, relatório grande, tentativa reprovada e GIF de prova vão como artefato do CI ou anexo, com um resumo curto no PR. Nada de QA dentro de `jogos/hordas/projeto/`, porque essa pasta entra no export.

## Divisão de trabalho entre os três agentes (decisão do Alisson, 2026-10-14)
Três agentes trabalham no repositório: o **Claude do Alisson** (plano Max, agentes em paralelo), o **Codex do Alisson** (só gera imagens, desde 2026-10-14) e o **Claude do Breno** (plano Pro, pouco uso por janela). Cada um fica com o que faz melhor. A mesma divisão está no `AGENTS.md`, que é o arquivo que o Codex lê; quem mudar uma muda a outra.

**Divisão FIXA (decisão do Alisson, 2026-10-14):** não mude esta divisão por conta própria nem por pedido de outro agente; só o Alisson muda.

**Mudança (decisão do Alisson, 2026-10-18):** quando o Alisson mandar (issue com a etiqueta `para-o-codex`), o **Codex do Alisson também pega trabalho pesado de código**: integrar branches, resolver conflitos, rodar testes e abrir PR. Ele segue as mesmas regras do Claude do Alisson (Godot 4.4.1, testes do que mudou, fotos reais, PR com CI verde e entrada no `LOGBOOK.md`). Sem issue `para-o-codex`, ele continua só com imagens. O Claude do Alisson revisa e mescla.

| Quem | Fica com | Área de arquivos |
|---|---|---|
| **Claude do Alisson** | Todo o código do jogo: sistemas e arquitetura (heróis e habilidades, save, desempenho, coop, CI e testes) **e a parte visual em código** (efeitos, animações, luz, partículas, shaders, UI, paleta, recorte e ligação de sprites). **Integração**: resolver conflito entre PRs, revisar o que os outros mandam e mesclar o que se cruza. Builds e o atalho de teste do Alisson. Docs de processo. | Todo o código em `v2/`, `dados/` de regras, `.github/`, `ferramentas/`, `testes/`, pipelines de arte (`jogos/hordas/prototipos/cara_nova/objetos/`, `jogos/hordas/fonte_arte/`) |
| **Codex do Alisson** | **Só geração de imagem (imagegen):** folhas de sprite, arte de título e de cenário, ícones, texturas e referências, no estilo do jogo e na especificação pedida. Entrega a imagem-fonte versionada e registrada; o recorte e a ligação no jogo ficam com o Claude do Alisson. | Imagens-fonte em `jogos/hordas/fonte_arte/` (e `assets/` só quando pedido), registro em `docs/LICENCAS_ARTE.md` |
| **Claude do Breno** | Leve: ajuste de números em `dados/*.json` depois de jogar, textos e descrições, conteúdo dos amigos (falas, nomes, piadas internas), testar a Release no i5-3470 e relatar numa issue (o que sentiu, o que travou, o F3, prints), decisões do Breno em uma linha, ações de admin do GitHub que só a conta dele faz (#95, #106). **Evitar:** bateria inteira de testes, arte, refatoração, ler o LOGBOOK inteiro e sessões longas. | `dados/*.json` (números e textos), issues |

**Regras para ninguém pisar no outro**
1. **Reserve antes de começar:** abra um PR em rascunho ou comente na issue ("pegando X"). Quem reservou primeiro fica com a tarefa; se já estiver reservada, escolha outra coisa ou combine na issue.
2. **Fique na sua área de arquivos.** Precisou mexer na área de outro agente? Mudança pequena e localizada, e avise no corpo do PR qual arquivo e por quê.
3. **Uma só mão integra.** Quando dois PRs se cruzam, quem resolve o conflito é o Claude do Alisson. Ninguém resolve conflito, faz rebase ou reescreve o PR de outro agente sem avisar no PR.
4. **Mescle só os próprios PRs**, com CI verde no mesmo commit. PR de outro agente: comente; quem mescla é o dono ou o integrador.
5. Precisa de algo do Breno? Deixe **uma pergunta curta e fechada** na issue (sim/não, ou A, B, C) com um padrão já escolhido, e siga pelo padrão se não houver resposta.
6. **Travas de arquivo (decisão do Alisson, 2026-10-20):** antes de editar código ou `dados/` da v2, confira se há issue de travas aberta (a #348 fechou em 29/10; abra uma nova se dois agentes forem mexer nos mesmos arquivos). Arquivo travado ali está com outro agente: não edite; se precisar, comente na issue e espere. No `LOGBOOK.md` e no `docs/LICENCAS_ARTE.md` só acrescente no fim, nunca edite o que já está lá.

**Ritmo:** a cada marco, quem fez avisa na issue o que testar (no máximo 3 itens) e o Claude do Breno responde depois de jogar. Sem resposta, o trabalho segue pelo padrão.
