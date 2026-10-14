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

## Arte e licenças (decisão do Alisson, 2026-10-12)
**Nada de arte com direitos autorais.** Arte, som, fonte e ícone de terceiros de **livre uso** podem e devem ser usados quando economizam esforço e são compatíveis com o nosso contexto (licença que permite uso comercial, redistribuição no jogo e modificação; estilo, escala e luz do jogo). O que vale, o que é proibido e o **registro obrigatório** de cada item (fonte, autor, licença, mudanças) estão em `docs/LICENCAS_ARTE.md` (a música e os sons seguem também o `docs/LICENCAS_AUDIO.md`).
- Antes de usar: confira a licença na página do arquivo **no dia**, registre no `docs/LICENCAS_ARTE.md` e ponha o crédito na tela de Créditos quando a licença pedir.
- Em dúvida (licença copyleft, "só uso pessoal", sem licença declarada), **não use**: pergunte ao Alisson. Pack pago só com o Breno.
- O pipeline do Blender continua sendo o caminho para heróis, monstros e cenários próprios; arte livre complementa e acelera.

## Divisão de trabalho entre os três agentes (decisão do Alisson, 2026-10-14)
Três agentes trabalham no repositório: o **Claude do Alisson** (plano Max, agentes em paralelo), o **Codex do Alisson** (tem gerador de imagem embutido) e o **Claude do Breno** (plano Pro, pouco uso por janela). Cada um fica com o que faz melhor. A mesma divisão está no `AGENTS.md`, que é o arquivo que o Codex lê; quem mudar uma muda a outra.

| Quem | Fica com | Área de arquivos |
|---|---|---|
| **Claude do Alisson** | Sistemas e arquitetura: coop online, heróis e habilidades (E, Q, secundário por herói), save, desempenho, CI e testes. **Integração**: resolver conflito entre PRs, revisar o que os outros mandam e mesclar o que se cruza. Docs de processo. | `v2/combate.gd`, `v2/heroi.gd`, `v2/meta.gd`, `v2/mundo.gd`, `v2/entrada.gd`, `dados/` de regras, `.github/`, `ferramentas/`, `testes/` |
| **Codex do Alisson** | Frente visual inteira, da imagem até funcionar no jogo: folhas de sprite, arte de título, ícones, recorte, ligar sprites, efeitos (Ruptura, escudo, golpes), animações, bloom, polimento de UI e paleta. Builds, ZIP e o atalho de teste do Alisson. | `assets/`, `jogos/hordas/fonte_arte/`, `jogos/hordas/prototipos/cara_nova/objetos/`, desenho/efeito/UI em `v2/` (`armas*.gd` na parte de desenho, `hud*.gd`, `telas.gd`, `status.gd`, `pausa.gd`, `menu_principal.gd`, `altar.gd` na parte visual), `docs/visual_2_5d/` |
| **Claude do Breno** | Leve: ajuste de números em `dados/*.json` depois de jogar, textos e descrições, conteúdo dos amigos (falas, nomes, piadas internas), testar a Release no i5-3470 e relatar numa issue (o que sentiu, o que travou, o F3, prints), decisões do Breno em uma linha, ações de admin do GitHub que só a conta dele faz (#95, #106). **Evitar:** bateria inteira de testes, arte, refatoração, ler o LOGBOOK inteiro e sessões longas. | `dados/*.json` (números e textos), issues |

**Regras para ninguém pisar no outro**
1. **Reserve antes de começar:** abra um PR em rascunho ou comente na issue ("pegando X"). Quem reservou primeiro fica com a tarefa; se já estiver reservada, escolha outra coisa ou combine na issue.
2. **Fique na sua área de arquivos.** Precisou mexer na área de outro agente? Mudança pequena e localizada, e avise no corpo do PR qual arquivo e por quê.
3. **Uma só mão integra.** Quando dois PRs se cruzam, quem resolve o conflito é o Claude do Alisson. Ninguém resolve conflito, faz rebase ou reescreve o PR de outro agente sem avisar no PR.
4. **Mescle só os próprios PRs**, com CI verde no mesmo commit. PR de outro agente: comente; quem mescla é o dono ou o integrador.
5. Precisa de algo do Breno? Deixe **uma pergunta curta e fechada** na issue (sim/não, ou A, B, C) com um padrão já escolhido, e siga pelo padrão se não houver resposta.

**Ritmo:** a cada marco, quem fez avisa na issue o que testar (no máximo 3 itens) e o Claude do Breno responde depois de jogar. Sem resposta, o trabalho segue pelo padrão.
