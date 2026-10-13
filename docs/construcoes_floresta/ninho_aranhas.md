# Ninho de Aranhas (ninho_aranhas)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** um ninho de teia num tronco caído. Enquanto está de pé, solta aranhas. Quando o herói destrói o ninho, três aranhas aliadas passam a lutar por ele por um tempo.

**Como aparece no mapa:** objeto de 48 x 48 px (3 x 3 células), com colisão de 1 célula (o tronco). Sugestão: entre o baú do centro e o espinhos (validar).

```
   /\/\/\      ← teia (sprite)
  ( ◉◉◉ )      ← ninho com 2 aranhas por cima
   \____/      ← tronco de base
```

## O que o jogador faz
- Ataca o ninho (80 de vida) com a katana: o ninho é um alvo como um monstro parado.
- Destruir o ninho dá 3 aranhas aliadas por 25 s.

## O que acontece
- Enquanto de pé, o ninho solta 2 aranhas inimigas (aranha_tecela, 18 de vida, 6 de dano) a cada 6 s, em volta do ninho (raio 120 px).
- Morto o ninho: 3 aranhas aliadas (18 de vida, 60% do dano da aranha original) lutam por 25 s e somem.

## Números propostos
| Item | Valor |
|---|---|
| Vida do ninho | 80 |
| Aranhas inimigas | 2 a cada 6 s, enquanto o ninho está de pé |
| Aranhas aliadas | 3 por 25 s |
| Vida da aliada | 18 |
| Dano da aliada | 60% de 6 (3,6 por golpe) |
| Usos por partida | 1 |

## Custo e risco
- Enquanto o ninho está de pé, cada 6 s são 2 aranhas inimigas. Se o herói demorar 30 s para destruir, são 10 aranhas. O custo é tempo parado e pressão.
- As aliadas duram 25 s: são curtas. Não criam defesa permanente.

## Recarga e limite
- 1 ninho por partida. Depois de destruído, não volta.

## Como a horda reage
- As aranhas inimigas do ninho entram no teto normal de 250 vivos.

## Sinais visuais e sonoros
- Teia que brilha branca (luz pequena, 0,4 de energia) enquanto o ninho está de pé.
- Som: estalo de teia a cada nascimento de aranha.
- Anúncio: "NINHO DESTRUÍDO: 3 ALIADAS".

## Nota de desempenho
- Ninho é um alvo estático com 2 quadros (de pé e destruído).
- As aranhas aliadas usam o sistema de aliados (armas_novas.gd, ligado ao pool de 48 slots): ocupam slots do pool de golpes. Validar que o pool não estoura.

## Prompt de arte para o GPT Astra
**Sprites:** ninho de aranha num tronco caído, 48 x 48 px, vista 2.5D de cima. Dois quadros: ninho de pé e ninho destruído.
**Animação:** teia que balança, 4 quadros de 48 x 16 px (sheet de 192 x 16 px); aranhas saindo, 4 quadros de 16 x 16 px.
**Paleta:** teia branca #E8E8E8, tronco #4A3424, casca #6B4A2C, aranha #1C1F24, olhos #C23B2A, musgo #3F6B3A.

> Pixel art sprite of a spider nest made of white silk webs on a fallen log, seen from a top-down 2.5D view, 48 by 48 pixels: a silk nest with two small dark spiders on top in frame 1, and the nest torn open in frame 2. Use only these colors: silk white #E8E8E8, log bark #4A3424, log light #6B4A2C, spider black #1C1F24, spider eye red #C23B2A, moss green #3F6B3A. Transparent background. Two frames in one row, each exactly 48 x 48 pixels, total sheet 96 x 48 pixels. No text, no border, no frame. Second asset: a spider walking, 4 frames in one row, each exactly 16 x 16 pixels, total sheet 64 x 16 pixels, dark spider with legs moving, transparent background.

## Pontos de atenção
- A aranha aliada precisa de um sprite de aliado (o que existe é inimigo). Confirmar com o Breno se ele quer reusar o sprite de inimigo com outra cor.
- 80 de vida no ninho pede uns 5 golpes de katana; é tempo parado, o que é o custo.
