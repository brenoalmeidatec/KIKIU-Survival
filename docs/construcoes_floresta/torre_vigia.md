# Torre de Vigia (torre_vigia)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** uma torre de madeira alta, com escada e um sino. Quem sobe vê a mata inteira por um minuto: monstros e baús aparecem no minimapa. O custo é ficar exposto lá em cima.

**Como aparece no mapa:** objeto de 32 x 96 px (2 x 6 células), com colisão só na base (2 células). Sugestão: no centro da rota, entre o baú do meio e a defesa de ponto (perto de 1380, 1080; validar).

```
    _____
   |  ◉  |    ← plataforma no topo (herói aparece aqui)
   |_____|
   |  |  |    ← escada
   |  |  |
   |__|__|    ← base com colisão
```

## O que o jogador faz
- Entra na zona de 60 px e fica parado 5 s (subida).
- Ao chegar, o herói fica no topo por 60 s: pode andar em volta, mas não sai do topo sem descer (andar para fora da zona de 60 px faz descer e perde o efeito).

## O que acontece
- Por 60 s, o minimapa mostra monstros e baús num raio de 600 px (um ícone a mais, sem seta).
- Enquanto o herói está no topo, monstros a até 500 px ganham +10% de velocidade por 15 s. Eles "veem" a torre.

## Números propostos
| Item | Valor |
|---|---|
| Subida | 5 s parado |
| Tempo no topo | 60 s |
| Revelação | monstros e baús a 600 px |
| Custo | +10% de velocidade dos monstros a 500 px, por 15 s |
| Usos por partida | 2 |
| Recarga | 150 s |

## Custo e risco
- Os 5 s de subida, mais o topo, deixam o herói exposto a elite e a horda que vem.
- O +10% de velocidade é o custo principal: é mais rápido para a horda chegar. Não dá dano nem mais monstros.
- Não dá vantagem de combate, só informação. É o tipo de construção que o jogador usa para decidir a rota, então não pode ser barata demais.

## Recarga e limite
- 2 usos por partida, 150 s entre um e outro. Uma torre serve às duas ativações.

## Como a horda reage
- Não nasce nenhum monstro novo. A horda só acelera (+10%) perto da torre, por 15 s.

## Sinais visuais e sonoros
- O sino da torre toca 2 vezes ao subir (som curto).
- No topo, o herói fica iluminado por uma tocha pequena (tipo "tocha" de floresta.json, e 1.9, raio 290).
- Anúncio: "TORRE DE VIGIA: VOCÊ VÊ A MATA".

## Nota de desempenho
- Sprite estático de 32 x 96 px. A revelação no minimapa é só desenho de ícones (sem física e sem partículas).
- A aceleração da horda é um multiplicador, não um novo sistema.

## Prompt de arte para o GPT Astra
**Sprites:** torre de vigia de madeira com escada e sino, 32 x 96 px, vista 2.5D de cima, com a plataforma no topo. 1 quadro.
**Animação:** sino balançando, 4 quadros de 8 x 8 px (sheet de 32 x 8 px), em loop curto.
**Paleta:** madeira #4A3424 e #6B4A2C, madeira clara #8A6238, corda #6B4A2C, sino dourado #C9A24A, musgo #3F6B3A.

> Pixel art sprite of a small wooden lookout tower with a ladder and a bell, seen from a top-down 2.5D view, 32 by 96 pixels: a square platform on top, a narrow ladder and a short base. Use only these colors: dark wood #4A3424, mid wood #6B4A2C, light wood #8A6238, rope #6B4A2C, gold bell #C9A24A, moss green #3F6B3A. Transparent background. One frame, exact size 32 x 96 pixels. No text, no border, no frame, no shadow outside the sprite. Second asset: a bell swinging, 4 frames in one row, each exactly 8 x 8 pixels, total sheet 32 x 8 pixels, gold #C9A24A, transparent background.

## Pontos de atenção
- A velocidade de +10% é a única penalidade. Se o Breno achar pouca, o próximo passo é +10% de dano para os monstros que veem a torre, não mais monstros.
- O minimapa precisa de um ícone de baú e de monstro extra: validar que a legibilidade do minimapa não piora (texto pequeno não se lê).
