# Golpes do vídeo KiKiu na v2: proposta

Base: `docs/visual_2_5d/referencia_kikiu/ANALISE.md` (PR #304). Leitura e propostas feitas por um workflow (4 leitores Haiku, 1 designer Sonnet, 3 revisores Sonnet que conferiram cada proposta contra o código), e as folhas de efeito foram feitas no Blender 5.2 (scripts e folhas em `jogos/hordas/fonte_arte/blender_efeitos/`). **Nenhum código do jogo mudou ainda:** falta o Alisson aprovar a implementação e escolher a cor da marca (item 2).

## Folhas de efeito feitas no Blender (estudo, ainda fora do jogo)

Mesmo formato do corte ciano do Hazaki (`fonte_arte/blender_corte/corte_hazaki_ciano.py`): render 64x64 só com emissão, 4 tons de alfa e 4 de calor, dobrado para 128x128 (pixel de 2 px). RGB = calor e A = intensidade, então o shader do jogo dá a cor. Cada uma renderiza em cerca de 1 s.

| Folha | Vídeo | Quadros | O que faz |
|---|---|---|---|
| `efeito_cristal_folha.png` | M6 | 14 | bola branca com halo, estouro de 16 espinhos (longos e curtos alternados) em 1 quadro, anel fino e poeira |
| `efeito_estrela_folha.png` | A2/M3 | 9 | estrela de 4 pontas que nasce cheia e afina, anel curto e lascas |
| `efeito_anel_folha.png` | M2 | 18 | esfera carregando, núcleo que estoura, **anel duplo** que cresce até ~2x em 4 quadros, fica pulsando com partículas orbitando e se desfaz |
| `efeito_espiral_folha.png` | V1 | 12 | 3 arcos de vento achatados no chão, que giram, abrem e somem (esquiva) |

Prévia: `todos.gif` e `tiras.png` (mesma conta do shader: `mix(cor, branco, calor*0.55)`, blend add). Para refazer: `python efeitos_kikiu.py -- <pasta> [cristal estrela anel espiral]` com o módulo `bpy` 5.2, ou `blender -b -P efeitos_kikiu.py -- <pasta>`, e depois `python previa_efeitos.py <pasta>`.

## Os 3 golpes de maior impacto

### 1. Explosão de cristal em toda explosão (P)
Hoje toda explosão (`armas.explodir`, runa, crítico explosivo, meteoro) é um anel só, mais fagulhas. Com a folha `cristal` desenhada por cima, tingida com a cor da arma e escalada ao raio real, o jogador lê o alcance pelo tamanho dos espinhos.
- `efeitos.gd`: um pool pequeno (6) de "efeito de folha" que reaproveita o shader do corte (`folha`, `quadros`, cor) e é achatado em 0,62 no Y, como o chão.
- Ligar em `armas.gd` `explodir()` (l.~842) e, à parte, em `_explodir_runa` (l.~813), que **não** passa por `explodir()`. Meteoro, adagas, ruptura e crítico já passam por ele.
- **Não** mexer em `onda()`, que tem 21 chamadas.
- Risco: o crítico explosivo em horda densa recicla o pool. Ignorar uma explosão nova a menos de 20 px de outra com menos de 0,05 s.

### 2. Impacto em 3 camadas em todo acerto (M)
Centelha de 2 quadros (folha `estrela`) em todo acerto, e **marca sustentada** (silhueta chapada por 0,3 a 0,6 s) só em golpe forte: crítico, estocada e pancada, no máximo 2 marcas por vez.
- `efeitos.gd` `flash()`: modo 3 "marca", sustentado, que o pisca branco seguinte não sobrescreve e que o round-robin pula.
- `combate.gd` `golpear()` (l.~518): chama a marca no golpe forte.
- **Decisão de cor:** o vídeo usa vermelho, mas hoje o vermelho é o dano que o herói sofre. O padrão é marca **branca**, e o vermelho só entra se o Alisson aprovar e se for registrado no DESIGN.md.
- Conferir se o efeito usa o tempo local durante o hit-stop.

### 3. Telégrafo do chefe em duas camadas (M)
Durante o aviso de ataque, o chefe incha (+6%) e clareia até ficar branco, e um retículo laranja (anel e cruz) gira sobre o herói. O golpe sai com o estouro de cristal.
- `monstro.gd`: `var carga` (0 a 1) que multiplica `sprite.scale` em `_visual_no()`.
- `chefe.gd` `_comecar_ataque()`: liga a carga e a zera em investida, recuperação, morte e `zerar`.
- Silhueta branca pelo `tinta` do sprite (sem slot de flash, sem conflito com a piscada de dano).
- Retículo: desenho em `avisos.gd`, só com o chefe vivo.

## Próximos (ficaram de fora)
- Espiral de vento na esquiva: barata (`combate.gd` l.~640, `esquiva_comecou`), e a folha já está pronta.
- Anel duplo como aura ou magia, chuva de lanças do chefe (precisa de projéteis e arte novos) e lens flare só em momentos raros.
