# Totem de Madeira (totem_madeira)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** um totem de tronco talhado, com olhos pintados de carvão. Ao ser ativado, abençoa a área em volta: quem abate ali ganha mais almas. Os monstros da área também ficam mais duros.

**Como aparece no mapa:** objeto de 40 x 64 px (2,5 x 4 células), com colisão de 1 célula na base. Sugestão: antes do mini-chefe 1 (cavaleiro rubro, 3 min), perto de 760, 1000 (validar).

```
     __
    (oo)     ← rosto talhado (olhos ligados quando ativo)
    |  |
    |__|     ← base com colisão
     ◉ herói: zona de 60 px
```

## O que o jogador faz
- Entra na zona de 60 px e fica parado 1 s (ativação, sem tecla).
- Depois, ao sair, o totem continua ativo pelo tempo do efeito.

## O que acontece
- Por 60 s, cada abate a até 200 px do totem vale +25% de XP (almas).
- Os monstros a até 200 px do totem ganham +15% de vida por 60 s. A vida é aplicada na hora que o monstro entra na área, e não muda quando sai.

## Números propostos
| Item | Valor |
|---|---|
| Ativação | 1 s parado |
| Duração | 60 s |
| Área | 200 px |
| Bônus | +25% de XP nos abates da área |
| Custo | +15% de vida dos monstros que entram na área |
| Usos por partida | 2 |
| Recarga | 120 s |

## Custo e risco
- O custo é vida dos monstros: mais dano para o herói também, porque eles demoram mais para morrer.
- O bônus de XP pode virar mais almas e mais cartas, se a horda ficar parada perto do totem.
- A vida extra só vale para monstros que entram depois da ativação (não muda os que já estão lá, para não ter pico).

## Recarga e limite
- 2 usos por partida, 120 s entre um e outro.

## Como a horda reage
- Nada de novo nasce. Os monstros que chegam ficam mais duros.

## Sinais visuais e sonoros
- Os olhos do totem acendem em laranja (luz "tocha" de floresta.json, e 1.9, raio 290, reduzida a 0,6 quando ativa).
- Som: tambor de madeira (uma batida a cada 2 s, enquanto ativo).
- Anúncio: "TOTEM DESPERTO: +25% XP".

## Nota de desempenho
- Sprite de 40 x 64 px, com 2 quadros (olhos apagados e acesos). Só troca de quadro ao ativar.
- O bônus de XP e de vida é um multiplicador por monstro, sem custo extra por quadro.

## Prompt de arte para o GPT Astra
**Sprites:** totem de tronco talhado com rosto, 40 x 64 px, vista 2.5D de cima. Dois quadros: olhos apagados e olhos acesos.
**Animação:** brilho dos olhos e fumaça de carvão, 4 quadros de 16 x 16 px (sheet de 64 x 16 px), em loop.
**Paleta:** madeira #4A3424, madeira clara #8A6238, carvão #1C1F24, olhos laranja #FF9E42, brilho #FFE673, musgo #3F6B3A.

> Pixel art sprite of a carved wooden totem pole with a face, seen from a top-down 2.5D view, 40 by 64 pixels: a carved wooden head with dark charcoal eyes in one frame and glowing orange eyes in the second frame. Use only these colors: dark wood #4A3424, light wood #8A6238, charcoal #1C1F24, eye orange #FF9E42, glow yellow #FFE673, moss green #3F6B3A. Transparent background. Two frames in one row, each exactly 40 x 64 pixels, total sheet 80 x 64 pixels. No text, no border, no frame. Second asset: a glow pulse, 4 frames in one row, each exactly 16 x 16 pixels, total sheet 64 x 16 pixels, orange and yellow, transparent background.

## Pontos de atenção
- O totem é um dos poucos que dá XP em troca de risco. Se o Breno achar forte, baixar o bônus de XP para +15%.
- O +15% de vida afeta também os mini-chefes? Não: a área só pega monstros comuns (não chefe nem elite). Validar no código.
