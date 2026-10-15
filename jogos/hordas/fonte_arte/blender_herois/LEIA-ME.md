# Heróis no Blender (piloto: Hazaki samurai andando)

Modelo e rig por script (`../modelos3d/hazaki.py`, articulações = empties) + funções de paleta/normal/contorno de `prototipos/cara_nova/gerar_cara_nova.py`.
Sem modelar à mão. Câmera ortográfica a 45°, 1 m = 24,5 px, quadro 32x44 (igual à folha atual do herói da v2).

```
blender -b -t 6 -P gerar_heroi_andar.py        # ~53 s: hazaki_samurai_blender_{albedo,normal}.png + .json + .blend
python previa_gif.py                            # GIFs em docs/visual_2_5d/blender_herois/
```

Formato = o de `v2/sprites.gd`/`v2/heroi.gd`: 8 linhas (baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir) x colunas
`[parado, andar0..andar5]` (7 colunas; `heroi.gd` já usa `colunas.size() - 1` quadros de andar). O jogo ainda NÃO usa esta folha.
Obs.: `PASSO_ANIM` em `heroi.gd` é 0,13 s/quadro (feito para 4 quadros); com 6 quadros o ciclo fica 50% mais longo, e o ideal é ~0,09 s.

Render: 4x com antialias (EEVEE, 8 amostras) -> média BOX ponderada pelo alfa -> alfa binário, paleta do Hazaki (`hz_neutro`, `hz_pele`, `hz_sangue`, `ouro`) e contorno de 1 px.
Ciclo: contato, descida, passagem, contato oposto, descida, passagem (60° de fase por quadro), com braço oposto à perna, quadril/ombros girando em contra-fase,
pé subindo no balanço, sobe-e-desce do corpo e cabeça atrasada um quadro.

## Estudo: herói do Blender no estilo do jogo (2026-10-15)
`gerar_heroi_estilo.py` junta o MODELO e a TÉCNICA de render do estudo do Codex do Alisson (`codex_estudo/criar_estudo.py` e `criar_pixel_art.py`, cópias sem mudança do que está em
`ChatGPT/KIKIU/output/blender_estudo/`, arte própria do Codex no Blender, registrada em `docs/LICENCAS_ARTE.md`) com a cara do jogo. É um estudo para aprovação: o jogo NÃO usa esta folha.
```
blender -b -t 6 -P gerar_heroi_estilo.py       # 1 s: estudo_estilo/hazaki_blender_estilo_albedo.png + .json + .blend
```
Mantido do Codex: geometria (rosto, cabelo espetado, lenço, cinto, botas, katana), materiais em 4 faixas por emissão, contorno por casca invertida, render Cycles em pixel nativo (1 amostra, filtro BOX mínimo, sem suavização, sem bloom).
Trocado para o estilo do jogo: paleta escura e fechada (traje vinho `#7a2a32` em vez de vermelho vivo, calça azul-carvão, pele `#9a7360`/`#b78c74` menos laranja, aço sem ciano neon, fio da lâmina frio e fosco);
sombra fria azulada e lado iluminado quente; luz principal = tocha lateral (esquerda, um pouco à frente) + um degrau de contraluz frio atrás/à direita; contorno no tom escuro da PRÓPRIA cor (não preto puro);
render direto no quadro do jogo (32x44, 45 graus, 24,5 px/m, pé na linha 42) em vez de 128x128. Exagerado para ler em 44 px: cabeça 1,22x, mechas mais grossas, olhos e sobrancelhas maiores, franja e boca removidas;
lenço mais curto e katana apontada para baixo e menor (a do estudo estouraria os 32 px). Herói estreitado a 95% da largura.
Formato: 8 linhas x 7 colunas como o do piloto; só há o quadro PARADO (repetido onde faltaria andar), sem normal.
Para ver no salão: `qa/qa_heroi_estilo.gd` (cena de QA que troca só a textura do herói no print; precisa do Salão da v2, que está na main e ainda não nesta branch).
Prints (960x540, janela oculta) e a comparação ficam em `estudo_estilo/`.

## Framework de animação (2026-10-15)
A base para as animações do herói (rig com joelho/cotovelo, um módulo por animação, cor + normal em 8 direções) está em `hazaki/` (ver `hazaki/LEIA-ME.md`). Exemplos prontos: parado (4 quadros) e andar (6).
O **Nicão** (anão de marreta, modelado por script a partir da referência do Codex, com IK das duas mãos no cabo e quadro 64x96) usa a mesma estrutura em `nicao/` (ver `nicao/LEIA-ME.md`): parado, andar, rolamento, combo de 2 golpes (batida e pancada no chão), defesa, dano e morte, já ligados no jogo.
