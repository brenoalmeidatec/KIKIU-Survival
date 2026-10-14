# Ponte Quebrada (ponte_quebrada)

**Status:** protótipo para revisão do Breno. Decisão pendente: integrar ao atalho da alavanca (recomendado).

**O que é:** uma ponte de tábua sobre um fosso, quebrada no meio. O herói conserta a ponte e ganha um atalho.

**Sobreposição:** o mapa médio já tem alavancas que abrem um atalho até o portão (`marcadores`: alavanca, atalho, portao). Uma ponte que abre atalho é a mesma mecânica. Recomendado: a ponte é o próprio atalho, sem alavanca nova.

## O que o jogador faz
- Fica parado 6 s na zona de 100 px, consertando a ponte (sem tecla).
- Ao terminar, a ponte vira passagem: encurta a rota entre duas áreas.

## O que acontece
- A ponte fica aberta para o herói e para os monstros (a ponte é caminho para os dois).
- Encurta a rota em cerca de 200 px. Não dá carta nem XP.

## Números propostos
| Item | Valor |
|---|---|
| Conserto | 6 s parado, zona de 100 px |
| Encurtamento | ~200 px de rota |
| Usos | 1 (ponte fica aberta depois) |

## Custo e risco
- 6 s parado no meio da rota.
- Os monstros também usam o atalho: a horda chega mais rápido ao chefe da área.
- Sem recompensa direta: é um atalho, o prêmio é o tempo.

## Como a horda reage
- Nada de novo nasce. Os monstros que já estão perto usam a ponte.

## Sinais visuais e sonoros
- Ponte se fecha com tábuas batendo (som de madeira).
- Anúncio: "PONTE CONSERTADA: ATALHO ABERTO".

## Nota de desempenho
- Sprite estático de 96 x 48 px (2 quadros: quebrada e inteira). Sem física.
- A colisão da ponte é um retângulo, não varredura nova.

## Prompt de arte para o GPT Astra
**Sprites:** ponte de tábua quebrada sobre fosso, 96 x 48 px, vista 2.5D de cima. Dois quadros: quebrada e inteira.
**Animação:** tábuas se encaixando, 4 quadros de 96 x 12 px (sheet de 96 x 48 px), em loop curto.
**Paleta:** madeira escura #4A3424, madeira média #6B4A2C, água #1B2A3A, espuma #7FC8FF.

> Pixel art sprite of a wooden plank bridge over a dark ditch, seen from a top-down 2.5D view, 96 by 48 pixels: frame 1 the bridge broken in the middle with loose planks, frame 2 the bridge repaired and whole. Use only these colors: dark wood #4A3424, mid wood #6B4A2C, dark water #1B2A3A, foam #7FC8FF. Transparent background. Two frames in one row, each exactly 96 x 48 pixels, total sheet 192 x 48 pixels. No text, no border, no frame. Second asset: planks being fitted, 4 frames in one row, each exactly 96 x 12 pixels, total sheet 96 x 48 pixels, transparent background.

## Pontos de atenção
- Integrar à alavanca evita duplicar. Se o Breno quiser a ponte separada, ela precisa de colisão nova no mapa (testes/v2_mapas).
