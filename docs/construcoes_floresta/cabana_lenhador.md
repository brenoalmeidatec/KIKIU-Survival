# Cabana do Lenhador (cabana_lenhador)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** uma cabana de tábua com lenha empilhada e um tronco com machado. O herói para na frente, o lenhador (fora da tela, só fumaça e som) corta lenha, e em troca dá uma carta de melhoria. Não cura.

**Como aparece no mapa:** objeto de 96 x 64 px (6 x 4 células de 16 px), ocupa colisão de parede nos 3 lados de trás. Fica na rota, logo depois do santuário, no meio do caminho entre o pilar de terra e o baú do centro (perto de 1100, 1420 do mapa médio; validar com testes/v2_mapas).

```
  +--------+
  |  ####  |   ← telhado de tábua (cor da madeira)
  | [lenha]|   ← pilha de lenha no lado de fora
  |  o  ^  |   ← tronco e machado (ponto de interação)
  +--------+
     ▲ herói fica aqui (zona de 120 px)
```

## O que o jogador faz
- Entra na zona de 120 px da cabana e fica parado 3 s (sem tecla nova: igual aos marcadores do mapa, que disparam ao entrar no raio).
- Se sair antes de 3 s, o contador zera.
- Ao completar, a cabana recebe o pedido: uma carta de melhoria (stat, comum ou rara) é oferecida pela tela de escolha normal.

## O que acontece
- Sorteio da carta: comum 70%, rara 30%. Usa a tela de escolha de cartas da v2 (cartas.gd), com 1 carta.
- Custa 25% da vida atual do herói. Esse custo não pode matar: se a vida ficar abaixo de 10, a cabana não aceita o pedido e avisa "vida baixa demais".

## Números propostos
| Item | Valor |
|---|---|
| Tempo parado | 3 s |
| Zona | 120 px |
| Carta | 1 (comum 70%, rara 30%) |
| Custo | 25% da vida atual (mínimo de 10 de vida restante) |
| Usos por partida | 2 |
| Recarga | 90 s entre usos |
| Lobos ao usar | 2 lobo_sombrio, a 260 px do herói |

## Custo e risco
- 3 s parado no meio da rota (a horda chega).
- 25% da vida atual: com 100 de vida, são 25. Mais ou menos dois golpes de trojan.
- Os dois lobos nascem perto do herói e correm a 70 px/s, então é preciso se afastar ou lutar.

## Recarga e limite
- 2 usos por partida, 90 s entre um e outro. O segundo uso só vale depois do primeiro lobo morto (regra opcional, validar).

## Como a horda reage
- Cada uso chama 2 lobo_sombrio perto do herói (fora da contagem de elite).
- Não muda o diretor: esses dois entram no teto normal de 250 vivos.

## Sinais visuais e sonoros
- Fumaça de serragem (6 partículas por 2 s), só na tela.
- Som: duas batidas de machado e o barulho de tora caindo.
- Luz: tocha pequena (tipo "tocha" de floresta.json), sem sombra extra.
- Ao acabar o custo, o herói ouve "CARTA DO LENHADOR" e a carta aparece.

## Nota de desempenho
- Uma sprite estática (96 x 64) e 1 emissor de fumaça de 6 partículas, só enquanto a cabana está na tela.
- Sem física extra: os lobos usam o sistema de horda normal (MultiMesh).
- Custo estimado: baixo. Não ocupa o orçamento de sombras (é objeto de colisão com sombra base).

## Prompt de arte para o GPT Astra
**Sprites:** cabana de madeira 96 x 64 px, vista de cima 2.5D, telhado de tábua, pilha de lenha ao lado, tronco com machado. 1 quadro.
**Animação:** fumaça de serragem, 6 quadros de 16 x 16 px (sheet de 96 x 16 px).
**Paleta:** madeira escura #4A3424, madeira média #6B4A2C, madeira clara #8A6238, musgo #3F6B3A, fumaça #9AA7A0.

> Pixel art sprite of a small wooden woodcutter's cabin, seen from a top-down 2.5D view, 96 by 64 pixels: a plank roof, a stacked pile of firewood beside it, and a tree stump with an axe stuck in it, matching the style of a 2.5D top-down dark forest survival game. Use only these colors: dark wood #4A3424, mid wood #6B4A2C, light wood #8A6238, moss green #3F6B3A, smoke grey #9AA7A0. Transparent background. One frame, exact size 96 x 64 pixels. No text, no border, no frame. Second asset: a smoke puff animation, 6 frames in a single row, each frame exactly 16 x 16 pixels, total sheet 96 x 16 pixels, grey smoke #9AA7A0 with a lighter edge, transparent background.

## Pontos de atenção
- A regra "não pode matar" (vida abaixo de 10) evita que a cabana seja suicídio.
- Se o Breno quiser mais risco, subir o custo para 35% ou a chance de rara para 40%, não os lobos.
