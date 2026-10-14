# Armadilha de Troncos (armadilha_troncos)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** dois troncos atravessados numa trilha, com estacas e um cordão. Quando um monstro pisa, os troncos caem e batem. O herói monta a armadilha antes.

**Como aparece no mapa:** objeto de 48 x 32 px (3 x 2 células), ocupa a faixa estreita de uma trilha. Sugestão: no corredor entre o pilar de fogo e o baú do centro, onde os monstros passam em fila (validar).

```
   ____________      ← tronco de cima
  |##|##|##|##|      ← estacas (faixa de dano)
   ____________      ← tronco de baixo
  ◉ herói: zona de 40 px para montar
```

## O que o jogador faz
- Entra na zona de 40 px e fica parado 2 s para montar (sem tecla).
- A armadilha fica pronta e some da visão do herói (só o minimapa mostra).

## O que acontece
- Quando um monstro entra na faixa de 48 x 32 px, a armadilha dispara: 12 de dano e lentidão de 50% por 0,5 s.
- Cada armadilha dispara 4 vezes. Depois, quebra.

## Números propostos
| Item | Valor |
|---|---|
| Montagem | 2 s parado, zona de 40 px |
| Faixa | 48 x 32 px |
| Dano | 12 por disparo |
| Efeito | lentidão de 50% por 0,5 s |
| Disparos | 4 por armadilha |
| Armadilhas por partida | 2 |
| Recarga entre montagens | 20 s |

## Custo e risco
- 2 s parado no caminho dos monstros, e o herói precisa passar perto para montar.
- A armadilha não diferencia monstro de herói: se o herói pisar, leva 12. Por isso fica fora do caminho do herói. Validar no código se a faixa acerta só monstro (recomendado).
- Limite de 2 armadilhas por partida: não dá para ficar montando a cada segundo.

## Recarga e limite
- 2 armadilhas por partida, 20 s entre uma montagem e outra. Cada armadilha tem 4 disparos.

## Como a horda reage
- Os monstros não desviam: o jogo não tem IA de desvio, então a armadilha pega quem passa. Isso é honesto: é uma armadilha de corredor.

## Sinais visuais e sonoros
- Ao montar: a corda estica (som de madeira rangendo).
- Ao disparar: tronco cai (som de madeira batendo) e um clarão branco de 0,1 s na faixa.
- Anúncio: "ARMADILHA!" (só na primeira ativação).

## Nota de desempenho
- Sprite estático 48 x 32 px, mais um quadro de disparo (2 quadros).
- O teste de faixa usa a lista de monstros que já existe (sem varredura extra): só compara posição na faixa.

## Prompt de arte para o GPT Astra
**Sprites:** dois troncos atravessados com estacas e cordão, 48 x 32 px, vista 2.5D de cima. Dois quadros: armada e disparada (troncos caídos).
**Animação:** troncos caindo, 4 quadros de 48 x 16 px (sheet de 192 x 16 px), em loop curto no disparo.
**Paleta:** madeira escura #4A3424, madeira média #6B4A2C, madeira clara #8A6238, corda #6B4A2C, branco do impacto #FFFFFF.

> Pixel art sprite of two wooden logs laid across a path with sharp stakes between them, seen from a top-down 2.5D view, 48 by 32 pixels: frame 1 the logs standing ready, frame 2 the logs fallen flat. Use only these colors: dark wood #4A3424, mid wood #6B4A2C, light wood #8A6238, rope #6B4A2C, impact white #FFFFFF. Transparent background. Two frames in one row, each exactly 48 x 32 pixels, total sheet 96 x 32 pixels. No text, no border, no frame. Second asset: a fall animation, 4 frames in one row, each exactly 48 x 16 pixels, total sheet 192 x 16 pixels, logs dropping and a small white flash on impact, transparent background.

## Pontos de atenção
- O herói não pode ser atingido pela própria armadilha. Confirmar no código antes de ligar.
- Se o Breno achar forte, 3 disparos em vez de 4.
