# Espantalho de Guarda (espantalho_guarda)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson. Exige código novo: hoje o jogo não tem "alvo de desvio".

**O que é:** um espantalho que o herói planta. Os monstros da área passam a mirar nele por um tempo, e não no herói.

**Como aparece no mapa:** objeto de 32 x 64 px (2 x 4 células), colisão de 1 célula na base. Sugestão: na frente da defesa de ponto, para proteger o herói na hora da defesa (validar).

```
    (o)       ← cabeça de palha
   /|__|\     ← braços abertos
     ||        ← estaca
```

## O que o jogador faz
- Fica parado 2 s na zona de 60 px para plantar (sem tecla).
- O espantalho fica de pé por 15 s.

## O que acontece
- Monstros a até 200 px do herói passam a mirar no espantalho por 15 s.
- O espantalho tem 120 de vida. Quando cai, o efeito acaba.

## Números propostos
| Item | Valor |
|---|---|
| Plantio | 2 s parado |
| Duração | 15 s ou até 120 de vida |
| Área de atração | 200 px do herói |
| Usos por partida | 3 |
| Recarga | 60 s |

## Custo e risco
- 2 s parado, e o espantalho é alvo: os monstros o destroem em segundos se estiverem em cima.
- O custo real é o uso: 3 espantalhos por partida, 60 s entre um e outro.

## Recarga e limite
- 3 usos por partida, 60 s entre um e outro.

## Como a horda reage
- Os monstros mudam de alvo. O desvio não mata nada: só segura o dano por 15 s.

## Sinais visuais e sonoros
- Espantalho com palha voando (2 quadros).
- Som: vento e palha.
- Anúncio: "ESPANTALHO DE GUARDA".

## Nota de desempenho
- Sprite de 32 x 64 px, 2 quadros (de pé e caído). Sem partículas.
- A troca de alvo é um campo a mais no monstro (código novo, mas barato).

## Prompt de arte para o GPT Astra
**Sprites:** espantalho de palha com cabeça de saco, 32 x 64 px, vista 2.5D de cima. Dois quadros: de pé e caído.
**Animação:** palha balançando, 4 quadros de 16 x 16 px (sheet de 64 x 16 px), em loop.
**Paleta:** palha #C9A24A, palha escura #8A6238, madeira #4A3424, saco #8A7A5A, costura #1C1F24.

> Pixel art sprite of a straw scarecrow on a wooden stake, seen from a top-down 2.5D view, 32 by 64 pixels: a sack head, arms out, straw sticking out, standing in frame 1 and fallen in frame 2. Use only these colors: straw gold #C9A24A, dark straw #8A6238, wood #4A3424, sack tan #8A7A5A, stitch black #1C1F24. Transparent background. Two frames in one row, each exactly 32 x 64 pixels, total sheet 64 x 64 pixels. No text, no border, no frame. Second asset: straw swaying, 4 frames in one row, each exactly 16 x 16 pixels, total sheet 64 x 16 pixels, transparent background.

## Pontos de atenção
- Atenção: o jogo já tem um monstro chamado espantalho (inimigo com 70 de vida). O espantalho de guarda é um objeto, com outro nome técnico (`espantalho_guarda`), para não confundir.
- A troca de alvo é código novo. Se não couber, o espantalho vira só dano parado (não recomendado).
