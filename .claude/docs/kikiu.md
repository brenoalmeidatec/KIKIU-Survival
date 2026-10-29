# Contexto do KIKIU para os agentes do Claude

Este arquivo é o contexto de projeto que os agentes e skills de `.claude/` leem antes de agir. Ele vale ao lado do `CLAUDE.md` da raiz (que continua sendo a regra principal de trabalho) e não o substitui. Se houver conflito, vale o `CLAUDE.md` e o `AGENTS.md`.

## O jogo

- **KIKIU** (repo `kikiu-survival`), jogo de sobrevivência em hordas feito no **Godot 4.4.1** com **GDScript**.
- A **v1 está pausada e vai ser aposentada**: nada de recurso novo nem refino nela. Só entra correção de bug grave.
- A **v2** é 2.5D: o jogo roda 2D por dentro e os personagens são sprites pixelados em 8 direções. Código e dados da v2 ficam em `jogos/hordas/projeto/v2/` e `jogos/hordas/projeto/dados/v2_*.json`.
- O PC do Breno é fraco. Desempenho (medido, não chutado) conta em toda decisão de código e de arte.
- Texto na tela precisa ser legível. Fonte pixelada pequena não se lê.

## Divisão de trabalho (não pisar no outro)

Fonte: `CLAUDE.md` e `AGENTS.md`, seção "Divisão de trabalho". Em caso de dúvida, siga o `CLAUDE.md`.

| Quem | Fica com |
|---|---|
| **Claude do Alisson** | Código do jogo: sistemas, heróis, habilidades, save, desempenho, coop, CI, testes, efeitos e shaders em código, UI, integração e merges. **Todo o trabalho de mapas** (Marco 4, regiões, santuários, exploração). |
| **Codex do Alisson** | Geração de imagem (folhas de sprite, cenário, ícones) quando o Alisson pedir. |
| **Claude do Breno** | Animações e arte no Blender (pipeline em `docs/animacoes_armas_v2.md` e `docs/corte_hazaki_blender/`), números em `dados/*.json`, textos, testes de Release e relatos em issue. |

Regras para qualquer agente:

1. **Reserve antes de começar:** PR em rascunho ou comentário na issue ("pegando X").
2. **Fique na sua área.** Mexer na área de outro agente só com mudança pequena e localizada, avisada no corpo do PR com arquivo e motivo.
3. **Mapas: não mexa.** Nada de arquivo de mapa, região ou santuário, a não ser que o Alisson peça na issue.
4. **Travas de arquivo:** antes de editar código ou `dados/` da v2, confira a issue de travas aberta (no momento, a **#348**). Arquivo travado está com outro agente: não edite.
5. **Não sobrescreva arte existente do Alisson.** Arte nova vai em arquivo novo.
6. **`LOGBOOK.md`, `docs/LICENCAS_ARTE.md` e `docs/LICENCAS_AUDIO.md`:** só acrescente no fim, nunca edite o que já está lá.
7. **Nada de merge na `main` sem o "pode mergear" do Alisson** (ou do Breno, quando for o dono do PR) e CI verde no mesmo commit.

## Modelos

- **Arte e animação:** `claude-opus-5-5` (agentes `technical-artist` e `art-director`).
- **Código, revisão, planejamento e design de sistema:** `claude-sonnet-5-5` em esforço médio (demais agentes deste pacote).
- **Tarefas simples e repetitivas** (renomear, listar, conferir um campo): `claude-haiku-5-5`.

## Idioma e padrões

- Respostas, documentos e relatos em **português do Brasil**.
- Nomes de variáveis, funções e arquivos seguem o código que já existe no repo (que mistura português e inglês de forma consistente, como `cursor_forma`). Não renomeie por estilo.
- Commits e títulos de PR no padrão do repo, com prefixo de versão ou área, como `v2: ...`, e corpo com o contexto. Ver o `git log` antes de escrever.
- Valor de gameplay vem de dado externo (`dados/*.json`), nunca fixo no código.
- Medição antes e depois de otimização, com números anotados.

## Arte, licenças e evidência

- Arte, som, fonte ou ícone de terceiro só entra com licença de uso comercial, redistribuição e modificação, e cada item é registrado em `docs/LICENCAS_ARTE.md` (ou `docs/LICENCAS_AUDIO.md` para som). Em dúvida, não use e pergunte.
- Evidência de QA (JSON de robô, relatório grande, GIF de prova) **não vai para o repositório**. Vai como artefato do CI ou anexo, com um resumo curto no PR. Nada de QA dentro de `jogos/hordas/projeto/`, porque essa pasta entra no export.

## Ambiente

- O caminho do Godot e outras configurações de máquina ficam em `CLAUDE.local.md`, que está fora do Git. Nunca escreva caminho pessoal no repo.
- Nenhuma senha, chave ou token no repositório. Nada pago sem o Breno.
- Não reescreva o histórico da `main` e não faça force-push.
