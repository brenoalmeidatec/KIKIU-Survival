# Ruínas com Runas (ruinas_runas)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** um círculo de pedras com runas gravadas. Quem entra faz um pacto: uma carta épica garantida em troca de uma maldição temporária que tira vida máxima.

**Como aparece no mapa:** objeto de 96 x 80 px (6 x 5 células), com colisão só nas pedras da borda. Sugestão: perto do altar e das runas que já existem no mapa médio (validar; não duplicar o objeto `runa` de decoração).

```
   _  _  _
  ( ᚱ   ᚨ )   ← 4 runas nas pedras (sprite)
   ◉ centro: zona de 100 px
  (_ ᚲ  ᚠ _)
```

## O que o jogador faz
- Entra na zona de 100 px e fica parado 2 s (sem tecla).
- Ao completar, o pacto é oferecido: uma carta épica garantida. A maldição vem junto.

## O que acontece
- Sorteio: 50% carta épica (bônus de 40%), 50% carta rara. Sem roleta. A versão anterior dava épica garantida; a revisão baixou para 50% porque a épica garantida com maldição de 90 s era a melhor carta do jogo.
- Maldição de 90 s: vida máxima -15%. Se a vida atual passar do novo máximo, cai para o máximo.

## Números propostos
| Item | Valor |
|---|---|
| Tempo parado | 2 s |
| Zona | 100 px |
| Recompensa | 1 carta: épica (50%) ou rara (50%) |
| Maldição | -15% de vida máxima por 90 s |
| Usos por partida | 1 |

## Custo e risco
- A maldição tira vida máxima: o herói não pode morrer pela maldição (a vida atual é ajustada para o novo máximo sem matar).
- Mesmo com 50% de épica, a ruína é a construção mais cara da lista (maldição + uso único).

## Recarga e limite
- 1 uso por partida. As ruínas viram decoração depois.

## Como a horda reage
- Nada. A maldição não chama monstro.

## Sinais visuais e sonoros
- As runas brilham roxas enquanto o pacto está aberto (luz "magia_roxa", e 2.65, raio 230, reduzida a 1.0 no uso).
- Som: canto baixo de 2 s.
- Anúncio: "PACTO FEITO: CARTA ÉPICA. MALDIÇÃO: -15% VIDA MÁX".

## Nota de desempenho
- Sprite estático de 96 x 80 px. As runas brilham com o próprio sprite (2 quadros), sem partículas.

## Prompt de arte para o GPT Astra
**Sprites:** círculo de ruínas de pedra com 4 runas gravadas, 96 x 80 px, vista 2.5D de cima. Dois quadros: runas apagadas e runas roxas acesas.
**Animação:** brilho das runas, 4 quadros de 24 x 24 px (sheet de 96 x 24 px), em loop lento.
**Paleta:** pedra #5A5A5A, pedra clara #7A7A74, musgo #3F6B3A, runa roxa #B273FF, brilho #E6CCFF.

> Pixel art sprite of a ring of old stone ruins with four carved runes, seen from a top-down 2.5D view, 96 by 80 pixels: grey broken stones forming a circle with four glyphs on them, dark in frame 1 and glowing purple in frame 2. Use only these colors: stone grey #5A5A5A, light stone #7A7A74, moss green #3F6B3A, rune purple #B273FF, glow pale #E6CCFF. Transparent background. Two frames in one row, each exactly 96 x 80 pixels, total sheet 192 x 80 pixels. No text, no border, no frame. Second asset: glowing runes, 4 frames in one row, each exactly 24 x 24 pixels, total sheet 96 x 24 pixels, purple pulse, transparent background.

## Pontos de atenção
- O sorteio 50/50 de épica ou rara precisa de código próprio (não usa o sorteio de baú). Confirmar com o código de cartas.
- Se a maldição parecer pouca, subir para -20%. Não subir a chance de épica.
