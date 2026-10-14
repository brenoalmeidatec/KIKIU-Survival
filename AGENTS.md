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

## Divisão de trabalho (decisão do Alisson, 2026-10-14)
A mesma tabela está no fim do `CLAUDE.md`; quem mudar uma muda a outra.

| Quem | Fica com | Área de arquivos |
|---|---|---|
| **Codex do Alisson (você)** | Frente visual inteira, da imagem até funcionar no jogo: folhas de sprite, arte de título, ícones, recorte, ligar sprites, efeitos (Ruptura, escudo, golpes), animações, bloom, polimento de UI e paleta. Builds, ZIP e o atalho de teste do Alisson. | `assets/`, `jogos/hordas/fonte_arte/`, `jogos/hordas/prototipos/cara_nova/objetos/`, desenho/efeito/UI em `v2/` (`armas*.gd` na parte de desenho, `hud*.gd`, `telas.gd`, `status.gd`, `pausa.gd`, `menu_principal.gd`, `altar.gd` na parte visual), `docs/visual_2_5d/` |
| **Claude do Alisson** | Sistemas e arquitetura: coop online, heróis e habilidades (E, Q, secundário por herói), save, desempenho, CI e testes. **Integração**: resolve conflito entre PRs, revisa e mescla o que se cruza. Docs de processo. | `v2/combate.gd`, `v2/heroi.gd`, `v2/meta.gd`, `v2/mundo.gd`, `v2/entrada.gd`, `dados/` de regras, `.github/`, `ferramentas/`, `testes/` |
| **Claude do Breno** | Leve (plano Pro): números e textos em `dados/*.json`, conteúdo dos amigos, testes da Release no i5-3470, decisões do Breno, admin do GitHub. | `dados/*.json` (números e textos), issues |

**Regras para ninguém pisar no outro**
1. **Reserve antes de começar:** PR em rascunho ou comentário na issue ("pegando X"). Quem reservou primeiro fica com a tarefa.
2. **Fique na sua área de arquivos.** Precisou mexer na área de outro agente? Mudança pequena e localizada, e avise no corpo do PR qual arquivo e por quê.
3. **Uma só mão integra.** Quando dois PRs se cruzam, quem resolve o conflito é o Claude do Alisson. Não resolva conflito, não faça rebase nem reescreva o PR de outro agente sem avisar no PR.
4. **Mescle só os próprios PRs**, com CI verde no mesmo commit. PR de outro agente: comente; quem mescla é o dono ou o integrador.
5. Precisa de algo do Breno? **Uma pergunta curta e fechada** na issue (sim/não, ou A, B, C) com um padrão já escolhido; sem resposta, siga pelo padrão.

## Arte (a sua frente)
- Antes de mexer em menu ou UI da v2, leia `jogos/hordas/projeto/v2/DESIGN.md` (quando estiver na main) e `docs/visual_2_5d/README.md`.
- Arte gerada por você ou pelo Alisson é arte própria: registre a origem em `docs/LICENCAS_ARTE.md`. Arte de terceiros só de livre uso, conferida no dia e registrada.
- Pipelines existentes: folhas em fundo branco ou preto passam por `jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py` (recorte, downscale BOX, quantização sem dither, normal map); objetos de mapa saem do Blender por script (`jogos/hordas/fonte_arte/mapas_v2/`). Reaproveite antes de criar outro.
- Mostre antes/depois com print do viewport do Godot no PR (nunca captura da área de trabalho).
