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

## Pipeline: modelos 3D → pixel art (dark fantasy)
Direção de arte nova: **dark fantasy, mantendo a cultura do pixel art**. Os personagens saem de modelos 3D simples renderizados no Blender e viram pixel art no próprio script:

```
blender -b -P jogos/hordas/fonte_arte/modelos3d/cavaleiro.py
```
(Blender 4.5 LTS portátil, grátis: baixar o zip em download.blender.org e descompactar; não precisa instalar.)

- `pixel3d.py`: a base. Render no tamanho final sem antialiasing, material toon (3 faixas), luz de cima/esquerda/trás (igual às sombras do jogo) + preenchimento fraco da câmera, paleta fixa dark fantasy (rampas: aço, sangue, couro, ouro velho, musgo, osso), luz de borda de 1 px (sobe um degrau na rampa do próprio material) e contorno escuro de 1 px.
- `cavaleiro.py`: o modelo (primitivas: elmo, tabardo, capa, espada, escudo) + ciclo de andar. Sai no formato que o jogo já usa: `andando_8.png` (9×4 quadros de 44×60; linhas baixo, esquerda, direita, cima) e `rosto.png` (52×52).
- Pra um modelo novo: copie o `cavaleiro.py`, troque o `montar()` e as cores. Passe `paleta=px3.paleta_sem(...)` pra tirar rampas que o material não usa.

Armadilhas que custaram tempo (já resolvidas no código):
1. **Cor em linear.** Os nós do Blender esperam cor linear; passar o hexa direto deixa tudo lavado (vermelho vira marrom). Use `px3.cor("hexa")`.
2. **Pendurar peça mantendo o lugar** (`pendurar()`), senão a posição soma duas vezes e a peça flutua.
3. **Sombra própria desligada** nas luzes: em 44 px ela vira chiado.
4. **Sinal do `shift_y`:** a linha da imagem cresce pra baixo, e o `shift_y` pra cima.

## Cenários (Blender → pixel art)
Três cenários, gerados por `jogos/hordas/fonte_arte/modelos3d/cenarios.py` (`blender -b -P cenarios.py [-- nome]`, ~2 min os três):

| Cenário | Piso | Enfeites | Luz |
|---|---|---|---|
| 🧪 **Laboratório** (alquimia) | ladrilhos escuros com respingos de poção | mesa de poções, caldeirão, estante, jarra com espécime, candelabro | verde (poções) e vela |
| 🏰 **Masmorra** | lajes de pedra com musgo e trincas | tocha, barril, ossos, caixote, coluna quebrada, grilhão | tocha |
| 🌃 **Cidade** (à noite) | **cruzamento de 512 px** que repete: asfalto, faixa de pedestre, faixa tracejada, calçada, bueiro | poste (fixo nas 4 esquinas), lixeira, hidrante, cone, caixote, barril | lâmpada de sódio |

- **Piso "pré-renderizado"** (técnica de Donkey Kong Country / Diablo): Cycles com luz e sombra reais, 4× maior, reduzido pela média e posto na paleta com pontilhado ordenado. O azulejo é renderizado cercado de 8 cópias dele, então a sombra também repete sem emenda.
- **Enfeites** no mesmo estilo do cavaleiro (toon + paleta + contorno + luz de borda), num atlas com o ponto do pé de cada um.
- **No jogo** (`scripts/hordas/cenario.gd` + `chao.gd`): tom de ambiente (`CanvasModulate`) e halos de luz somados (blend ADD), com cintilação. Só sprites: roda em qualquer PC. 500 vírus: ~160–300 fps nos três.
- **Qual cenário em qual fase:** `dados/cenarios.json` (`por_fase`). Lista vazia volta pro chão antigo.
- Enfeite com `peso` 0 só aparece nos lugares fixos do cenário (`fixos` no `cenario.json`, ex.: postes nas esquinas).
