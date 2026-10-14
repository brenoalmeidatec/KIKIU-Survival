# Fogueira de Acampamento (fogueira_acampamento)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** uma fogueira de pedras com lenha, montada pelo herói. Enquanto queima, aquece quem está perto: o dano sobe. Quem acende também chama a mata.

**Como aparece no mapa:** objeto de 48 x 40 px (3 x 2,5 células). Ocupa 1 célula de colisão (a pedra). É diferente do objeto `fogueira` de decoração que já existe no mapa: esta é uma construção que o jogador acende, e pode reutilizar a arte da fogueira de decoração. Sugestão de posição: perto dos pilares de fogo e água, entre o baú do centro e o mini-chefe (perto de 1450, 980; validar).

```
   ( ( )  )      ← chama (sprite animado, 6 quadros)
   [=====]       ← pedra e lenha
     ◉ herói: zona de 150 px
```

## O que o jogador faz
- Entra na zona de 150 px e fica parado 4 s para acender (sem tecla nova).
- Levar dano não interrompe. O acendimento só zera se o herói sair da zona.

## O que acontece
- Acesa, a fogueira dá +15% de dano a todo herói dentro de 150 px, por 25 s.
- Ao acender, 6 monstros nascem em anel de 420 px em volta do ponto (cogumelo_errante e lobo_sombrio, por sorteio).

## Números propostos
| Item | Valor |
|---|---|
| Tempo para acender | 4 s parado |
| Zona de efeito | 150 px |
| Buff | +15% de dano por 25 s |
| Anel de monstros | 6 (4 cogumelo_errante e 2 lobo_sombrio), raio 420 px |
| Usos por partida | 3 |
| Recarga | 100 s |

## Custo e risco
- 4 s parado e o anel de 6 monstros. Com o buff dura 25 s, então é preciso ficar na zona e lutar.
- O buff não aumenta a vida, a velocidade nem a área. Só dano.
- Os monstros do anel entram no teto normal de 250 vivos e não contam como elite.

## Recarga e limite
- 3 usos por partida, 100 s entre um e outro. Um uso é apagado quando o buff acaba (não dá para reacender enquanto a fogueira está acesa).

## Como a horda reage
- O anel de 6 nasce fora da tela (420 px), então o herói vê chegar.
- A fogueira não atrai ninguém depois de apagada. Só o ato de acender chama.

## Sinais visuais e sonoros
- Chama de 6 quadros (sprite) e a luz "fogueira" de floresta.json (e 1.4, raio 170), com a mesma cor.
- Faíscas: 4 partículas a cada 0,5 s (só enquanto acesa).
- Som: crepitar, e um grito curto quando o anel chega.
- Anúncio na tela: "FOGUEIRA ACESA! +15% DANO".

## Nota de desempenho
- Reusa o emissor de chama da fogueira de decoração: não cria efeito novo.
- Partículas limitadas a 4 a cada 0,5 s, e só se a fogueira estiver na tela.
- O anel de 6 monstros usa o sistema de horda (MultiMesh), sem custo extra.

## Prompt de arte para o GPT Astra
**Sprites:** fogueira de acampamento de pedras com lenha, 48 x 40 px, vista 2.5D de cima, 1 quadro apagado (cinza) e um quadro de brasa.
**Animação:** chama de 6 quadros, 16 x 24 px cada (sheet de 96 x 24 px), chama laranja que sobe e se apaga em loop.
**Paleta:** pedra #5A5A5A, brasa #FF5A1F, chama #FF9E42, amarelo quente #FFE673, lenha #4A3424.

> Pixel art sprite of a small campfire ring of grey stones with a stack of logs, seen from a top-down 2.5D view, 48 by 40 pixels: unlit state with dark ash, and a lit state with glowing embers. Use only these colors: stone grey #5A5A5A, ember red-orange #FF5A1F, flame orange #FF9E42, hot yellow #FFE673, wood brown #4A3424. Transparent background. Two frames in one row, each exactly 48 x 40 pixels, total sheet 96 x 40 pixels. No text, no border, no frame. Second asset: a flame animation, 6 frames in one horizontal row, each frame exactly 16 x 24 pixels, total sheet 96 x 24 pixels, flame tongues rising and flickering, orange and yellow, transparent background.

## Pontos de atenção
- A fogueira de decoração do mapa é só enfeite. Antes de ligar esta construção, decidir se a decoração vira a construção (um objeto só) ou se fica separada.
- O buff é só de dano, de propósito: não há cura nem invencibilidade.
