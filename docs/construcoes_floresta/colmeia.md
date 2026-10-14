# Colmeia (colmeia)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** uma colmeia pendurada numa árvore baixa. Golpes na colmeia fazem as abelhas saírem em nuvem. Quem fica perto da nuvem leva ferroadas, e os monstros também.

**Como aparece no mapa:** objeto de 40 x 40 px (2,5 x 2,5 células), na copa de uma árvore. Sugestão: perto de uma árvore da rota, longe das trilhas principais (validar).

```
     ___
    (   )    ← colmeia pendurada
     \_/     ← ponto de golpe (katana)
      ◉      ← nuvem de abelhas (raio 120 px)
```

## O que o jogador faz
- Acerta a colmeia com a katana 3 vezes (a colmeia tem 3 de vida; cada golpe conta 1).
- Ao cair a 3ª vez, as abelhas saem em nuvem.

## O que acontece
- A nuvem tem raio de 120 px e dura 6 s.
- Dentro da nuvem: monstros levam 12 de dano por segundo; o herói leva 3 por segundo (ferroada).
- A nuvem fica no lugar da colmeia (não segue o herói).

## Números propostos
| Item | Valor |
|---|---|
| Golpes para derrubar | 3 |
| Nuvem | raio 120 px, 6 s |
| Dano nos monstros | 12 por segundo |
| Dano no herói | 3 por segundo, dentro da nuvem |
| Usos por partida | 1 |

## Custo e risco
- O herói pode ficar dentro da nuvem e perder vida: 3 por segundo, 18 no total se ficar as 6 s. Não mata por si, mas tira um pedaço.
- Monstros de 8 a 12 de vida morrem na nuvem em um segundo. Ainda é dano em área alto, por isso só 1 uso.
- Revisão: a primeira versão tinha 20 por segundo. Caiu para 12 porque 20 limpava a horda inteira em área de 120 px.

## Recarga e limite
- 1 colmeia por partida.

## Como a horda reage
- Nada de novo nasce. A nuvem mata quem entra nela, então a horda evita a área (não é IA: é o dano por segundo).

## Sinais visuais e sonoros
- Abelhas em zumbido (som de voo) desde a queda.
- Nuvem amarela-clara que gira (sprite de 4 quadros).
- Anúncio: "COLMEIA! FUJA DAS ABELHAS".

## Nota de desempenho
- Colmeia é sprite estático com 2 quadros (inteira e caída).
- A nuvem é um sprite de 4 quadros de 48 x 48 px. As abelhas não são partículas: são um único sprite girando.

## Prompt de arte para o GPT Astra
**Sprites:** colmeia de palha pendurada num galho, 40 x 40 px, vista 2.5D de cima. Dois quadros: inteira e caída, rachada.
**Animação:** nuvem de abelhas girando, 4 quadros de 48 x 48 px (sheet de 192 x 48 px), amarelo e preto, em loop.
**Paleta:** palha #C9A24A, palha escura #8A6238, abelha preta #1C1F24, nuvem amarela #E6CC4A, asas #E8E8E8.

> Pixel art sprite of a straw beehive hanging from a branch, seen from a top-down 2.5D view, 40 by 40 pixels: a rounded straw hive in frame 1 and a cracked hive in frame 2 with a few dots spilled. Use only these colors: straw gold #C9A24A, dark straw #8A6238, bee black #1C1F24, cloud yellow #E6CC4A, wing white #E8E8E8. Transparent background. Two frames in one row, each exactly 40 x 40 pixels, total sheet 80 x 40 pixels. No text, no border, no frame. Second asset: a swarm cloud, 4 frames in one row, each exactly 48 x 48 pixels, total sheet 192 x 48 pixels, yellow and black bee dots swirling in a circle, transparent background.

## Pontos de atenção
- Com 12 por segundo, a nuvem ainda mata monstros pequenos. Se o Breno achar forte, raio de 100 px.
- A nuvem precisa de verificação: não pode dar dano no herói sem o herói estar dentro da zona.
