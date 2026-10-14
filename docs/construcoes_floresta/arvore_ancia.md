# Árvore Anciã Oca (arvore_ancia)

**Status:** protótipo para revisão do Breno. Ainda não vai ao Alisson.

**O que é:** uma árvore velha e oca. Ela guarda almas: as bolinhas de XP que caem perto dela são guardadas dentro, e o herói pode liberar esse pacote depois.

**Como aparece no mapa:** objeto de 64 x 96 px (4 x 6 células), com colisão só na base. O id técnico é `arvore_ancia`, sem acento, para o código e os arquivos de arte. Sugestão: na beira leste da rota, perto do baú da segunda metade (validar).

```
    ___
   (___)     ← copa seca
   |   |     ← tronco oco (abertura de 16 px)
   |___|     ← base com raízes
   ◉ herói: zona de 150 px para guardar almas
```

## O que o jogador faz
- Fica a até 150 px da árvore: as almas (orbes de XP) que caem nesse raio são puxadas para dentro (até 3 pacotes).
- Para liberar um pacote, o herói fica parado 1 s na zona de 60 px (sem tecla).

## O que acontece
- Cada pacote guardado vale 30 XP (3 almas). Liberado, cai como orbe de XP grande.
- Ao liberar, o herói fica com velocidade de andar -10% por 10 s (as raízes prendem o pé).
- Liberar um pacote com a barra cheia não muda o nível: só entrega a alma guardada.

## Números propostos
| Item | Valor |
|---|---|
| Guarda | até 3 pacotes |
| Pacote | 30 XP (3 almas) |
| Liberação | 1 s parado, zona de 60 px |
| Custo | -10% de velocidade por 10 s |
| Recarga | 30 s entre liberações |
| Usos por partida | 3 pacotes no total |

## Custo e risco
- O custo é lentidão de 10% por 10 s: pequeno, mas no meio de uma horda pesa.
- Ela só guarda almas que já estariam no chão. Não aumenta o XP total: só adia o ganho. Isso é o que impede a árvore de ser o melhor caminho de XP.

## Recarga e limite
- 3 pacotes por partida. Cada liberação precisa de 30 s de intervalo.

## Como a horda reage
- Nada. A árvore não atrai monstro.

## Sinais visuais e sonoros
- Abertura do tronco brilha em verde quando tem pacote (luz pequena, 0,3 de energia).
- Som: sussurro baixo ao guardar, e um estalo ao liberar.
- Anúncio: "ALMAS LIBERADAS: +30 XP".

## Nota de desempenho
- Sprite estático com 2 quadros (vazia e com pacote). Só troca de quadro ao guardar ou liberar.
- A atração das almas é a mesma do ímã (orbes.gd), sem custo novo.

## Prompt de arte para o GPT Astra
**Sprites:** árvore velha e oca com tronco aberto, 64 x 96 px, vista 2.5D de cima. Dois quadros: abertura escura (vazia) e abertura com brilho verde (com pacote).
**Animação:** brilho verde pulsando dentro do tronco, 4 quadros de 16 x 16 px (sheet de 64 x 16 px), em loop lento.
**Paleta:** casca #4A3424, casca clara #6B4A2C, musgo #3F6B3A, brilho verde #9FFF8A, interior escuro #1C1F24.

> Pixel art sprite of an ancient hollow tree with a split trunk and a dry crown, seen from a top-down 2.5D view, 64 by 96 pixels: a wide dark opening in the trunk, empty in frame 1 and glowing green inside in frame 2. Use only these colors: bark dark #4A3424, bark light #6B4A2C, moss green #3F6B3A, glow green #9FFF8A, hollow dark #1C1F24. Transparent background. Two frames in one row, each exactly 64 x 96 pixels, total sheet 128 x 96 pixels. No text, no border, no frame, no shadow outside the sprite. Second asset: a green glow pulse, 4 frames in one row, each exactly 16 x 16 pixels, total sheet 64 x 16 pixels, transparent background.

## Pontos de atenção
- O nome com acento no arquivo quebra no código. Usar sempre `arvore_ancia` no nome técnico.
- A árvore não cria XP novo: é só um cofre. Mantém o balanço, mas o Breno pode achar pouco. Opção: 40 XP por pacote, com a mesma limitação.
