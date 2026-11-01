# Prompts dos ícones do LightWolf (LW-3)

Gerados no ChatGPT logado do Alisson em 01/11/2026, com os prompts da seção 5.2 de `notas/plano_2026-11-01.md` (base de A19 a A22: 1024x1024, paleta azul claro `#bfe4ff / #8cc6f0 / #3b6fa6`, branco, ciano `#7ff3ff`, contorno marinho `#1d2c4a`, sem brilho difuso; sufixo S no fim). As fontes saíram 1254x1254, RGBA com fundo transparente. `reduzir_icones.py` gera os ícones de 32x32 do jogo.

## Sufixo S (fim de todo prompt)

> Crisp hard-edged pixel art, limited palette, no anti-aliasing, no gradients, no blur, no text, no grid lines, no cast shadow, transparent PNG background (or flat solid #FF00FF if transparency is not possible).

## A19 E Mísseis (`A19_lw_misseis.png`) -> `assets/v2/habilidade_e/lightwolf.png` (ligado no LW-4)

> a fan of FIVE small chunky micro-missiles with white-and-sky-blue bodies and bright cyan flame tips flying up and to the right from the lower-left, each with a short crisp cyan smoke trail, one tiny orange-white burst at the upper right. (S)

## A22 Secundário, Matriz (`A22_lw_matriz.png`) -> `assets/v2/secundario_s/lightwolf.png`

> a curved arc-shaped energy barrier made of interlocking light sky-blue hexagon panels with thin white highlights and a cyan edge, seen slightly from above, with three small cyan sparks where it deflects impacts. (S)

## A23 Cartas do LightWolf (`A23_lw_cartas.png`) -> `assets/v2/icones_cartas/{sifao,ampla,cabo,aurora_lunar}.png` (LW-6)

Folha 1448x1086 (grade 4x3 pedida, só as 4 primeiras células preenchidas; os desenhos não caem na grade, então `reduzir_cartas.py` os acha pelas colunas com alfa). Gerada no ChatGPT logado do Alisson em 01/11/2026, prompt da seção 5 do plano (A23), sufixo S incluído:

> Icon sheet for a dark fantasy roguelike card game: 1448x1086 canvas, a 4-column by 3-row invisible grid (cells 362x362), real alpha transparency, ONLY the first four cells (left to right, top row) contain an icon, the other eight are completely empty. Each icon is ONE compact centered motif with generous padding, chunky hard pixel clusters, few flat tones, deep navy outline (#1d2c4a), readable at 32x32. Palette: light sky-blue (#bfe4ff, #8cc6f0, #3b6fa6), white, cyan (#7ff3ff), small warm green-gold heal sparkles. Cell 1 'Siphon': a hexagonal panel barrier with a glowing green-gold stream flowing from it into a small heart. Cell 2 'Wide Matrix': two nested hexagonal arcs, the outer clearly larger, with small outward arrows. Cell 3 'Rescue Cable': a coiled cable with a cyan hook descending from above onto a tiny white wolf paw print. Cell 4 'Lunar Dawn' (evolution, more ornate): a large crescent moon embracing a glowing hexagon barrier with radiating light and a heart at its center. (S)
