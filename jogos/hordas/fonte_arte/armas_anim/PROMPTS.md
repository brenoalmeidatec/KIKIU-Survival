# Prompts das folhas de voo dos projéteis do herói (PER-2b)

Gerados no ChatGPT logado do Alisson em 01/11/2026, com os prompts da seção 5.2 de `notas/plano_2026-11-01.md` (sufixo S incluído). Os arquivos-fonte estão ao lado deste arquivo.

## Sufixo S (fim de todo prompt)

> Crisp hard-edged pixel art, limited palette, no anti-aliasing, no gradients, no blur, no text, no grid lines, no cast shadow, transparent PNG background (or flat solid #FF00FF if transparency is not possible).

## A06 shuriken (`A06_shuriken_voo.png`, 1536x1024, 4 colunas x 2 linhas)

> the SAME four-pointed steel throwing star (shuriken), seen from above, centered, filling about 70% of its cell, rotated exactly 45 degrees more in every next frame so the loop is seamless. Pale steel blades with a darker blue-gray edge, a small bright white glint on the leading point, a tiny round center hole, crisp dark 1-pixel outline, chunky shapes, no thin lines, readable at 14x14. Bright steel, clearly different from a black shuriken. (S)

## A07 kunai (`A07_kunai_voo.png`, 1536x1024, 2 colunas x 2 linhas)

> ONE Japanese KUNAI flying, seen from the side, pointing exactly to the RIGHT, horizontal, centered: leaf-shaped dark steel blade with a bright edge highlight, short wrapped cord handle, round ring pommel at the back (left), plus a short faint steel-blue motion streak behind it in the left third. The 4 frames are almost identical, only the glint and the streak length flicker slightly. Readable at 24x10. (S)

## A08 flecha (`A08_flecha_voo.png`, 1536x1024, 2 colunas x 2 linhas)

> ONE long arrow flying, seen from the side, pointing exactly to the RIGHT, horizontal, filling about 80% of the cell width: bamboo-colored shaft, narrow steel arrowhead on the right with a bright glint, three white feathers as fletching on the left, a very short pale trail behind them. 4 almost identical frames, only the glint and trail flicker. Readable at 28x8. (S)

## Estado das fontes (verificado em 01/11/2026)

Os três PNG saíram **opacos**: o canal alfa é 255 em todos os pixels e o fundo é um gradiente escuro com brilho ao redor do objeto. A nota do `LEIA-ME.md` das artes (que fala em fundo transparente) não confere com os arquivos. Antes de reduzir para o tamanho do jogo, é preciso tirar o fundo; isso ainda não foi resolvido.
