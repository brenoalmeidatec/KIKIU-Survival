# Acampamento de Goblins (acampamento_goblins)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson. Exige arte nova de goblins (o jogo não tem goblin).

**O que é:** um acampamento com três tendas e um baú de saque. Para pegar o saque, o herói precisa derrubar as tendas. Os goblins defendem.

**Como aparece no mapa:** conjunto de 3 tendas, cada uma de 48 x 48 px, num raio de 160 px, com um baú no centro. Sugestão: fora da rota principal, no lado sul, depois do minuto 6 (validar).

```
     [T1]        ← tenda 1 (300 de vida)
  [T2]   [T3]    ← tendas 2 e 3 (300 de vida cada)
     [bau]       ← baú de saque no centro
```

## O que o jogador faz
- Entra no acampamento (raio de 220 px): os goblins acordam (aviso de 3 s).
- Destrói as 3 tendas (katana). Cada uma tem 300 de vida.
- Pega o baú (raio de 400 px, igual aos outros baús).

## O que acontece
- Ao acordar, 12 monstros nascem em duas ondas de 6 (lobo_sombrio e cogumelo_errante), a 240 px do centro.
- As tendas não atacam. Os goblins são os monstros.
- O baú dá 2 cartas (forcar 2) e 60 XP (6 almas).

## Números propostos
| Item | Valor |
|---|---|
| Tendas | 3 x 300 de vida |
| Monstros ao acordar | 12 (2 ondas de 6, 30 s entre elas) |
| Baú | 2 cartas, 60 XP |
| Usos por partida | 1 |

## Custo e risco
- 12 monstros e um acampamento para destruir (3 x 300 = 900 de vida). Dá para durar uns 60 s de luta.
- Com a arma do meio de partida, a luta não é difícil, mas com a horda já em volta é um risco.
- O baú de 2 cartas é o prêmio, e não passa do baú comum de 3 cartas.

## Recarga e limite
- 1 acampamento por partida, depois do minuto 6 (a fase inicial não tem).

## Como a horda reage
- 12 monstros entram pelo teto normal de 250 vivos. A segunda onda só nasce se a primeira já não estiver em cima do herói (para não passar do teto).

## Sinais visuais e sonoros
- Fogueira pequena no centro (luz "fogueira" de floresta.json).
- Ao acordar: gritos de goblin (3 s) e batidas de tambor.
- Anúncio: "ACAMPAMENTO DESPERTO!".

## Nota de desempenho
- 3 tendas e 1 baú, todos com sprites estáticos de 48 x 48 px e 1 quadro cada.
- As 12 criaturas usam a horda normal (MultiMesh). Não há goblin com código novo: usa monstro comum com outro sprite.

## Prompt de arte para o GPT Astra
**Sprites:** tenda de pano de goblin, 48 x 48 px, vista 2.5D de cima. 1 quadro. Três variações (cores levemente diferentes).
**Animação:** fogueira pequena, 4 quadros de 16 x 16 px (sheet de 64 x 16 px), em loop.
**Paleta:** lona marrom #6B4A2C, lona suja #8A6238, pele de goblin verde #5A7A3A, madeira #4A3424, fogo #FF9E42.

> Pixel art sprite of a small goblin camp tent made of dirty brown canvas on sticks, seen from a top-down 2.5D view, 48 by 48 pixels, one frame. Use only these colors: canvas brown #6B4A2C, dirty canvas #8A6238, goblin green #5A7A3A, wood #4A3424, flame orange #FF9E42. Transparent background. One frame, exact size 48 x 48 pixels. No text, no border, no frame, no shadow outside the sprite. Second asset: small campfire, 4 frames in one row, each exactly 16 x 16 pixels, total sheet 64 x 16 pixels, flame orange, transparent background. Third asset: a goblin monster sprite is needed, 16 x 16 px, 4 frames of walking, to be described in a separate brief.

## Pontos de atenção
- Goblin é um inimigo novo, precisa de sprite e de ficha de inimigo. Isto fica fora do pacote de construção.
- 12 monstros é o maior pico da lista. Se o Breno achar forte, 8 (duas ondas de 4).
