# Poço Antigo (poco_antigo)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** um poço de pedra coberto de musgo, com corda podre. Quem joga na água sacrifica o próprio progresso de nível e recebe algo do fundo: uma carta de melhoria, com chance maior de raridade alta.

**Como aparece no mapa:** objeto de 40 x 40 px (2,5 x 2,5 células). Ocupa a colisão do poço (1 célula). Sugestão de posição: perto do fragmento do mapa médio no lado do pilar de terra (perto de 900, 780; validar).

```
     ____
    /____\     ← borda de pedra, com musgo
   |  ~~  |    ← água escura (sprite animado)
    \____/     ← corda caída
     ◉ herói: zona de 90 px
```

## O que o jogador faz
- Entra na zona de 90 px e fica parado 2 s (sem tecla).
- Ao completar, o poço pede o sacrifício: o XP da barra atual vai embora (a barra volta a zero, sem perder o nível).

## O que acontece
- O herói recebe 1 carta de melhoria, com o sorteio de raridade do baú com bônus 0,5 (menos que o baú normal, que é bônus 1 e 3 cartas).
- Em vez de carta, pode sair um espectro (chance de 1 em 4), que nasce no poço. Ele é um inimigo comum (espectro, 20 de vida, 7 de dano).

## Números propostos
| Item | Valor |
|---|---|
| Tempo parado | 2 s |
| Zona | 90 px |
| Custo | barra de XP atual zerada (até 1 nível de XP, entre 5 e 28 de XP) |
| Recompensa | 1 carta de melhoria (raridade com bônus 0,5) |
| Chance de espectro | 1 em 4 (no lugar da carta) |
| Usos por partida | 1 |
| Recarga | sem recarga (uso único) |

## Custo e risco
- Perder a barra de XP é perder cerca de 1 nível de XP inteiro na pior hora. Se o jogador acabou de subir de nível, o custo é baixo; se a barra está quase cheia, é alto. Esse é o tradeoff.
- Chance de espectro: é um inimigo ao lado de um herói com vida baixa, o que pode matar.
- Uso único: não há como repetir.

## Recarga e limite
- 1 uso por partida. Depois de usado, o poço vira decoração e não tem texto.

## Como a horda reage
- Nada direto. Só o espectro (1 em 4) entra como inimigo normal.

## Sinais visuais e sonoros
- A água brilha em azul frio (luz "magia_azul_fixa", e 2.3, raio 170, reduzida para 0,4 de energia antes do uso, porque o poço é apagado depois).
- Som: eco de gota dentro do poço. Se for espectro: um grito abafado.
- Anúncio: "O POÇO DEVOLVE ALGO" (carta) ou "O POÇO DESPERTOU" (espectro).

## Nota de desempenho
- Sprite estático de 40 x 40 px. A água é um sprite de 4 quadros de 40 x 16 px (troca de quadro a cada 0,3 s).
- Sem partículas. A luz do poço é a única fonte extra, e some depois do uso.

## Prompt de arte para o GPT Astra
**Sprites:** poço de pedra com musgo, 40 x 40 px, vista 2.5D de cima. Dois estados: ativo (água azul) e usado (água escura, sem brilho).
**Animação:** água com ondulação, 4 quadros de 40 x 16 px (sheet de 160 x 16 px), em loop.
**Paleta:** pedra #6E6E68, musgo #3F6B3A, água escura #1B2A3A, brilho azul-frio #7FC8FF, corda #6B4A2C.

> Pixel art sprite of an old stone well with moss on its rim, seen from a top-down 2.5D view, 40 by 40 pixels: a grey stone ring, a dark water surface in the centre and a broken rope lying on the edge. Use only these colors: stone grey #6E6E68, moss green #3F6B3A, dark water #1B2A3A, cold blue highlight #7FC8FF, rope brown #6B4A2C. Transparent background. Two frames in one row, each exactly 40 x 40 pixels, total sheet 80 x 40 pixels: frame 1 water glowing blue, frame 2 water dark and dull (used). No text, no border, no frame. Second asset: water ripple, 4 frames in one row, each exactly 40 x 16 pixels, total sheet 160 x 16 pixels, light blue highlights on a dark surface, transparent background.

## Pontos de atenção
- O custo "barra de XP zerada" é fácil de explicar mas precisa de um teste: verificar que a barra zera sem mudar o nível.
- Se o Breno achar forte demais, a carta pode sair com bônus 0,25 (menos raridade alta).
