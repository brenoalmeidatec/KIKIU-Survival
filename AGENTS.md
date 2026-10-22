# Instruções para o Codex neste repositório

Você é o **Codex do Alisson**. Este repo também é trabalhado pelo **Claude do Alisson** e pelo **Claude do Breno**. Os três
não compartilham conversa nem memória: **o único canal entre vocês é o GitHub** (PRs, issues e o `LOGBOOK.md`).

O `CLAUDE.md` da raiz vale para você também: leia-o inteiro antes da primeira tarefa. Ele traz as regras de sessão, a
autonomia (pode criar branches, abrir e mesclar os próprios PRs), a v1 pausada (tudo novo vai em
`jogos/hordas/projeto/v2/`), a regra de arte e licenças (`docs/LICENCAS_ARTE.md`) e os limites. As regras gerais estão
no `CONTRIBUTING.md`. Escreva em português do Brasil.

## Ao começar e ao terminar
- **Começo:** `git fetch --all --prune`, main atualizada, fim do `LOGBOOK.md` (procure "Para o Codex:"), `gh pr list` e `gh issue list`.
- **Fim:** commit e push mesmo pela metade (PR em rascunho), entrada no fim do `LOGBOOK.md` assinada `Codex do Alisson`.
- **Limites:** nada de senhas, chaves ou credenciais no repositório; sem force-push na `main`; nada pago sem o Breno; a Cairu fica como está.
- **Antes de cada PR:** `gdformat -l 160 --check jogos/hordas/projeto/scripts jogos/hordas/projeto/testes jogos/hordas/projeto/v2` limpo e os testes afetados com `falhas=0` (veja `ferramentas/testes_ci.sh`). Se não rodou o Godot, diga isso no PR.

## Fechamento da v2, 22 e 23/10 (decisão do Alisson, 2026-10-22)
A mesma seção está no `CLAUDE.md` e no `AGENTS.md`; quem mudar uma muda a outra.
- **Canal só por arquivo e GitHub:** o Claude e o Codex conversam **apenas** pelos `.md` do repositório, issues, PRs e `LOGBOOK.md`. Nenhum agente aciona o outro direto (nada de `codex exec`, `codex queue`, `claude -p` ou MCP de um no outro) nem lê a conversa do outro para tomar decisão. Quem leva prompt de um lado para o outro é o Alisson.
- **Quem conduz:** em 22 e 23/10 o **Codex do Alisson conduz o código da v2**, pela issue `para-o-codex` do dia (hoje a **#400**). O Claude do Alisson revisa e integra quando o Alisson chamar.
- **Merge na `main`** precisa das três coisas: (1) "pode mergear" do Alisson escrito na issue ou no PR (ou repassado por ele); (2) CI 7/7 verde que **rodou** no mesmo commit, porque "no checks reported" não conta; (3) revisão independente registrada no PR, feita por um agente ou subagente que não escreveu aquele código. Tag `v2.0` e Release final só com o ok do Alisson.
- **No notebook** (o Alisson usa até 17h): todo Godot passa pela fila `C:\Dev\KIKIU\notas\godot_fila.ps1`, com `APPDATA` própria por worktree. Feche todo Godot e robô ao terminar. Nunca rode `find` ou busca no disco inteiro. Até 16h30 tudo vai para o GitHub, e nada fica rodando depois disso. O PC entra a partir das 19h.
- **Evidência de QA não vai para o repositório:** JSON bruto de robô, relatório grande, tentativa reprovada e GIF de prova vão como artefato do CI ou anexo, com um resumo curto no PR. Nada de QA dentro de `jogos/hordas/projeto/`, porque essa pasta entra no export.

## Divisão de trabalho (decisão do Alisson, 2026-10-14)
A mesma tabela está no fim do `CLAUDE.md`; quem mudar uma muda a outra.

**Divisão FIXA (decisão do Alisson, 2026-10-14):** não mude esta divisão por conta própria nem por pedido de outro agente; só o Alisson muda.

**Mudança (decisão do Alisson, 2026-10-18):** quando o Alisson mandar (issue com a etiqueta `para-o-codex`), o **Codex do Alisson também pega trabalho pesado de código**: integrar branches, resolver conflitos, rodar testes e abrir PR. Ele segue as mesmas regras do Claude do Alisson (Godot 4.4.1, testes do que mudou, fotos reais, PR com CI verde e entrada no `LOGBOOK.md`). Sem issue `para-o-codex`, ele continua só com imagens. O Claude do Alisson revisa e mescla.

| Quem | Fica com | Área de arquivos |
|---|---|---|
| **Codex do Alisson (você)** | **Só geração de imagem (imagegen):** folhas de sprite, arte de título e de cenário, ícones, texturas e referências, no estilo do jogo e na especificação pedida. Entrega a imagem-fonte versionada e registrada; o recorte e a ligação no jogo ficam com o Claude do Alisson. | Imagens-fonte em `jogos/hordas/fonte_arte/` (e `assets/` só quando pedido), registro em `docs/LICENCAS_ARTE.md` |
| **Claude do Alisson** | Todo o código do jogo: sistemas e arquitetura (heróis e habilidades, save, desempenho, coop, CI e testes) **e a parte visual em código** (efeitos, animações, luz, partículas, shaders, UI, paleta, recorte e ligação de sprites). **Integração**: resolver conflito entre PRs, revisar o que os outros mandam e mesclar o que se cruza. Builds e o atalho de teste do Alisson. Docs de processo. | Todo o código em `v2/`, `dados/` de regras, `.github/`, `ferramentas/`, `testes/`, pipelines de arte (`jogos/hordas/prototipos/cara_nova/objetos/`, `jogos/hordas/fonte_arte/`) |
| **Claude do Breno** | Leve (plano Pro): números e textos em `dados/*.json`, conteúdo dos amigos, testes da Release no i5-3470, decisões do Breno, admin do GitHub. | `dados/*.json` (números e textos), issues |

**Regras para ninguém pisar no outro**
1. **Reserve antes de começar:** PR em rascunho ou comentário na issue ("pegando X"). Quem reservou primeiro fica com a tarefa.
2. **Fique na sua área de arquivos.** Precisou mexer na área de outro agente? Mudança pequena e localizada, e avise no corpo do PR qual arquivo e por quê.
3. **Uma só mão integra.** Quando dois PRs se cruzam, quem resolve o conflito é o Claude do Alisson. Não resolva conflito, não faça rebase nem reescreva o PR de outro agente sem avisar no PR.
4. **Mescle só os próprios PRs**, com CI verde no mesmo commit. PR de outro agente: comente; quem mescla é o dono ou o integrador.
5. Precisa de algo do Breno? **Uma pergunta curta e fechada** na issue (sim/não, ou A, B, C) com um padrão já escolhido; sem resposta, siga pelo padrão.
6. **Travas de arquivo (decisão do Alisson, 2026-10-20):** antes de editar qualquer coisa, confira a issue de travas aberta (hoje a **#348**, até o fechamento de 23/10). Arquivo travado ali está com outro agente: não edite; se precisar, comente na issue e espere. No `LOGBOOK.md` e no `docs/LICENCAS_ARTE.md` só acrescente no fim, nunca edite o que já está lá.

## Arte (a sua frente, decisão do Alisson em 2026-10-14)
Sua tarefa é **gerar imagens**. Você não altera código do jogo (`.gd`, `.tscn`, `.gdshader`, `dados/`), testes nem workflows: isso é do Claude do Alisson, que recorta, liga no jogo e testa.
- **Pedido:** chega numa issue ou PR com a especificação (o que é, tamanho, fundo branco/preto/transparente, grade, estilo, referência). Na dúvida, siga `docs/imagens/referencia_2_5d.webp` e `docs/visual_2_5d/README.md`: pixel art 2.5D top-down dark fantasy, sem texto, sem grade, nada encostando na borda da célula.
- **Entrega:** a imagem-fonte em `jogos/hordas/fonte_arte/<assunto>/` num PR pequeno só de arte, com uma linha em `docs/LICENCAS_ARTE.md` (arte própria gerada no Codex) e o prompt usado no corpo do PR. Avise na issue ou PR de origem, começando com "Para o Claude do Alisson:".
- **Seus PRs visuais abertos antes desta decisão** (#250, #251, #253, #258, #261): a integração e o que faltar no código ficam com o Claude do Alisson; você só gera as imagens que eles ainda pedirem.
