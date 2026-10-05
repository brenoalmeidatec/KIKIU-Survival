# K.I.K.I.U: visual

Decisão do Breno na #6: **modelos 3D renderizados como pixel art, com volume e luz, sem câmera 3D**. O Alisson quer o jogo **claro** (paleta luminosa) e, mais pra frente, **isométrico**. Antes disso vem o refino do pixel art que já existe, com truques de "3D disfarçado" que continuam valendo quando a arte mudar pro tema de cavaleiros.

## Regra de ouro: uma luz só
Toda profundidade falsa depende de **uma direção de luz igual pra cena inteira**. Aqui ela vem **de cima, à esquerda**. Sombra pra baixo e pra direita, brilho de borda em cima e à esquerda. Os números ficam em `scripts/hordas/visual.gd` (`ACHATA`, `INCLINA`, `COR`).

## Técnicas (pesquisa) e onde cada uma entra

| # | Técnica | O que faz | Etapa |
|---|---|---|---|
| 1 | Sombra projetada | silhueta do sprite achatada e deitada no chão, oposta à luz | **feito** |
| 2 | Sombra de contato (oclusão) | mancha escura no pé, "gruda" no chão | **feito** |
| 3 | Luz de borda + auto-sombra | 1 px claro do lado da luz, 1 px escuro do outro (shader) | próxima |
| 4 | Altura com sombra no chão | projétil e gema flutuam e a sombra fica embaixo | próxima |
| 5 | Reflexo | sprite espelhado e transparente em poças e piso brilhante | depois |
| 6 | Normal maps + luz 2D do Godot | volume de verdade com luz; vem "de graça" quando a arte sair de modelos 3D | com a arte nova |
| 7 | Isométrico com render 3D | câmera fixa 2:1, modelos 3D renderizados em sprites ou com shader de pixelização | plano próprio |

## Como a sombra foi feita (e por quê)
- Cada sombra é **calculada pixel a pixel, uma vez por quadro de animação**: cada pixel opaco do sprite vai pra `altura x ACHATA` abaixo do pé e `altura x INCLINA` pra direita. Inclinar a textura na hora dava degraus irregulares; calculando pixel a pixel, os degraus ficam limpos, como desenhados à mão.
- Todas as sombras ficam num **atlas único** (1024×1024, junto com a mancha de contato), e as do jogo inteiro cabem nele. Assim o Godot desenha as sombras dos 500 vírus num lote só.
- **Custo medido** com 500 vírus: 164–196 fps com sombras, contra 171–196 sem. A primeira versão (círculos + chave de texto por vírus) derrubava pra ~50 fps.
- Objeto que flutua (tomada) usa `altura`: a sombra fica no chão e encolhe quando ele sobe (calculada na hora, porque muda a cada quadro).

## Referências
- [Godot: 2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html) (normal maps, `CanvasModulate`, filtro de sombra "None" pra pixel art)
- [Catlike Coding: True Top-Down 2D, Light and Shadow](https://catlikecoding.com/godot/true-top-down-2d/4-light-and-shadow/) (luz com altura, sombra só no chão, cuidado com sombra "fantasma" de 1 px)
- [Lighting a 2D action game without washing out silhouettes](https://gamineai.com/blog/lighting-2d-action-game-silhouettes-rim-ambient-shader-basics-2026) (luz de borda, ambiente como tom e não como brilho)
- [GDQuest: lighting with 2D normal maps](https://www.gdquest.com/tutorial/godot/2d/lighting-with-normal-maps/)
- [Sprite stacking em Godot](https://www.connorwolf.com/post/sprite-stacking-in-godot) (fatias empilhadas: alternativa de "3D" pra objetos que giram)
- [Project Shadowglass: pixel art "3D"](https://80.lv/articles/interview-how-project-shadowglass-creates-its-impossible-fully-3d-pixel-art-look) (referência de onde o isométrico com render 3D pode chegar)
