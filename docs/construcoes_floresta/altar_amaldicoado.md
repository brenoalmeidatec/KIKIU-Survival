# Altar Amaldiçoado (altar_amaldicoado)

**Status:** protótipo para revisão do Breno. Decisão pendente: integrar ao santuário que já existe (recomendado).

**O que é:** a proposta era um altar de sacrifício na mata. Mas o mapa já tem o santuário (`fase.json` > `santuarios`, tomadas no mapa, e o altar do meta em `v2/altar.gd`). Um altar amaldiçoado é uma variação de santuário.

**Recomendação: integrar como opção do santuário.** Quando o herói ativa um santuário, ele escolhe entre a bênção normal (já existente) ou o altar amaldiçoado. Sem objeto novo: é uma escolha a mais na tela do santuário.

## O que o jogador faz
- Ativa o santuário como hoje.
- Escolhe "bênção sombria" (altar amaldiçoado) ou a bênção normal.

## O que acontece (opção sombria)
- Perde 15% da vida máxima na hora (não mata: a vida fica pelo menos em 10).
- Por 60 s, dano +20%. Monstros a até 300 px andam +20% mais rápido.

## Números propostos
| Item | Valor |
|---|---|
| Custo | 15% da vida máxima (mínimo de 10 de vida restante) |
| Ganho | +20% de dano por 60 s |
| Custo extra | +20% de velocidade dos monstros a 300 px, por 60 s |
| Usos por partida | 1 (revisão: eram 2, e 2 usos tirariam até 30% da vida máxima) |
| Recarga | não se aplica (1 uso) |

## Custo e risco
- Vida máxima perdida é permanente na partida, não é só durante o efeito. Esse é o preço principal.
- O +20% de velocidade dos monstros pesa mais quando a horda já está em volta.

## Recarga e limite
- 1 uso por partida, e só no santuário que o jogador escolher. A bênção normal continua como está.

## Como a horda reage
- Monstros a 300 px ficam mais rápidos por 60 s. Não nasce ninguém a mais.

## Sinais visuais e sonoros
- Altar com chama roxa (luz "magia_roxa" de floresta.json, e 2.65).
- Som: coro baixo de 2 s.
- Anúncio: "BÊNÇÃO SOMBRIA: +20% DANO".

## Nota de desempenho
- Não cria objeto novo. Reusa o santuário e a luz que já existem.

## Prompt de arte para o GPT Astra
**Não há arte nova** se a integração for aprovada. Se o Breno preferir um altar separado:

**Sprites:** altar de pedra com chama roxa, 48 x 48 px, vista 2.5D de cima. 1 quadro.
**Animação:** chama roxa, 4 quadros de 16 x 16 px (sheet de 64 x 16 px), em loop.
**Paleta:** pedra #5A5A5A, chama roxa #B273FF, brilho #E6CCFF, sangue escuro #5A1A1A.

> Pixel art sprite of a small stone altar with a purple flame, seen from a top-down 2.5D view, 48 by 48 pixels: a square stone slab with a dark stain and a purple flame on top. Use only these colors: stone grey #5A5A5A, purple flame #B273FF, pale glow #E6CCFF, dark blood #5A1A1A. Transparent background. One frame, exact size 48 x 48 pixels. No text, no border, no frame. Second asset: purple flame, 4 frames in one row, each exactly 16 x 16 pixels, total sheet 64 x 16 pixels, transparent background.

## Pontos de atenção
- Integrar evita um objeto novo e um sistema novo. Se o Breno quiser separado, a ficha vira um objeto de 48 x 48 px.
- Verificar no código do santuário se a escolha da bênção já existe (está como ideia, não como código).
