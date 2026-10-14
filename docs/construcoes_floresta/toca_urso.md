# Toca do Urso (toca_urso)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** uma toca em barranco com um urso adormecido e um baú de couro ao lado. Para pegar o baú, o herói precisa derrotar o urso, que é um elite.

**Como aparece no mapa:** objeto de 80 x 56 px (5 x 3,5 células), com colisão de barranco. Sugestão: no lado oeste da rota, perto do baú trancado, antes do mini-chefe 2 (validar).

```
   ____________
  /  (zzz)     \   ← toca, o urso dorme dentro
 |   [bau]      |  ← baú de couro, ao lado
  \____________/
   ◉ herói: zona de 140 px
```

## O que o jogador faz
- Entra na zona de 140 px: o urso acorda (aviso de 2 s, com grunhido).
- Mata o urso (elite). Ao cair, o baú aparece ao lado da toca.
- Pega o baú entrando no raio do baú (400 px, igual aos outros baús do mapa).

## O que acontece
- Urso da Toca: elite com 360 de vida, 18 de dano, velocidade 40 px/s, 60 XP (6 almas) e um baú de 2 cartas.
- Ao acordar, 6 monstros comuns nascem em volta da toca (raio 300 px).

## Números propostos
| Item | Valor |
|---|---|
| Vida do urso | 360 |
| Dano do urso | 18 |
| XP ao abater | 60 |
| Baú | 2 cartas (forcar 2) |
| Monstros ao acordar | 6 (raio 300 px) |
| Usos por partida | 1 |

## Custo e risco
- O urso é um elite: sai do teto de elite (máx. 2 vivos), e leva cerca de 20 s para morrer com a arma de meio de partida.
- Os 6 monstros que nascem em volta são a pressão principal. O herói luta contra o urso e o anel ao mesmo tempo.
- O baú de 2 cartas (e não 3) é o prêmio: menos que um baú comum do mapa médio.

## Recarga e limite
- 1 toca por partida. Depois de morto o urso, não volta.

## Como a horda reage
- O anel de 6 nasce no ato de acordar, e não depois. O urso, uma vez acordado, não volta a dormir.

## Sinais visuais e sonoros
- Aviso de 2 s: grunhido grave e a luz da toca fica vermelha (luz "magia_roxa" reduzida a 0,8 de energia).
- Ao cair: baú abre (som de madeira) e a luz vermelha some.
- Anúncio: "O URSO ACORDOU!" e "BAÚ DO URSO!".

## Nota de desempenho
- Urso é um monstro comum com vida alta, usa o mesmo sistema de elite já existente (sem código novo de luta).
- A toca é um sprite estático. O aviso é uma luz que pulsa, de 2 s.

## Prompt de arte para o GPT Astra
**Sprites:** toca de barranco com um urso dormindo, 80 x 56 px, vista 2.5D de cima. Dois quadros: urso dormindo dentro e urso fora, em pé.
**Animação:** respiração do urso dormindo, 4 quadros de 32 x 32 px (sheet de 128 x 32 px), em loop lento; o urso acordado tem um grunhido de 4 quadros (sheet de 128 x 32 px).
**Paleta:** barranco #3A2E24, terra #5A4632, urso marrom #4A3424, pelo claro #8A6238, olho vermelho #C23B2A, musgo #3F6B3A.

> Pixel art sprite of a bear den dug into a dirt bank, seen from a top-down 2.5D view, 80 by 56 pixels: a dark cave mouth in the earth with a sleeping brown bear inside in frame 1, and the bear standing outside with a red eye in frame 2. Use only these colors: dark earth #3A2E24, dirt #5A4632, bear brown #4A3424, light fur #8A6238, red eye #C23B2A, moss green #3F6B3A. Transparent background. Two frames in one row, each exactly 80 x 56 pixels, total sheet 160 x 56 pixels. No text, no border, no frame. Second asset: a sleeping bear breathing, 4 frames in one row, each exactly 32 x 32 pixels, total sheet 128 x 32 pixels, transparent background.

## Pontos de atenção
- O urso é um elite de 360 de vida: o valor exato precisa de teste com a arma inicial (katana 12 a 26 de dano).
- O baú de 2 cartas é um pouco menor que o baú comum de 3: se o Breno achar pouco, 3 cartas, mas só com o urso morto e sem o anel.
