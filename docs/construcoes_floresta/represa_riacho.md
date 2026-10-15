# Represa do Riacho (represa_riacho)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** uma barragem de pedra e tronco num riacho. Ao fechar a comporta, a água se espalha e atrasa quem está na margem.

**Sobreposição:** o braseiro antigo (`v2_floresta.json`, braseiro_antigo) já deixa monstros lentos numa área. A represa é parecida em efeito, por isso o número é menor e o efeito dura menos.

**Como aparece no mapa:** objeto de 96 x 64 px (6 x 4 células). Sugestão: no riacho que corta o mapa, perto de 1600, 1040 (validar).

## O que o jogador faz
- Fica parado 8 s na zona de 80 px, fechando a comporta (sem tecla).
- Depois, a represa fica ativa e a área de água alaga.

## O que acontece
- Por 20 s, monstros dentro de 200 px da represa andam 30% mais devagar.
- Não causa dano nem empurra ninguém.

## Números propostos
| Item | Valor |
|---|---|
| Tempo de ativação | 8 s parado, zona de 80 px |
| Área | 200 px |
| Efeito | -30% de velocidade dos monstros por 20 s |
| Usos por partida | 2 |
| Recarga | 120 s |

## Custo e risco
- 8 s parado é longo: a horda se aproxima.
- O efeito é menor que o braseiro (60%): é de propósito, para não somar com ele.

## Recarga e limite
- 2 usos, 120 s entre um e outro.

## Como a horda reage
- Nada nasce. A lentidão afeta os que já estão na área.

## Sinais visuais e sonoros
- Água sobe e espalha em azul (luz "aura" de floresta.json, e 0,7, raio 120).
- Som: comporta rangendo, e água correndo.
- Anúncio: "REPRESA ATIVA: MONSTROS LENTOS".

## Nota de desempenho
- Sprite estático de 96 x 64 px com 2 quadros (fechada e aberta). A água é uma faixa animada de 4 quadros.
- A lentidão é um multiplicador de velocidade, sem varredura extra.

## Prompt de arte para o GPT Astra
**Sprites:** represa de pedra e tronco num riacho, 96 x 64 px, vista 2.5D de cima. Dois quadros: comporta fechada e comporta aberta.
**Animação:** água correndo sobre a barragem, 4 quadros de 96 x 16 px (sheet de 384 x 16 px), em loop.
**Paleta:** pedra #5A5A5A, tronco #4A3424, água #2E5A7A, espuma #7FC8FF, musgo #3F6B3A.

> Pixel art sprite of a small stone and log dam across a stream, seen from a top-down 2.5D view, 96 by 64 pixels: a sluice gate closed in frame 1 and open in frame 2 with water running through. Use only these colors: stone grey #5A5A5A, log brown #4A3424, water blue #2E5A7A, foam #7FC8FF, moss green #3F6B3A. Transparent background. Two frames in one row, each exactly 96 x 64 pixels, total sheet 192 x 64 pixels. No text, no border, no frame. Second asset: water flowing over a dam, 4 frames in one row, each exactly 96 x 16 pixels, total sheet 384 x 16 pixels, transparent background.

## Pontos de atenção
- Confirmar que a represa não duplica o braseiro antigo (mesmo tipo de efeito). Se o Breno achar igual, cortar uma das duas.
