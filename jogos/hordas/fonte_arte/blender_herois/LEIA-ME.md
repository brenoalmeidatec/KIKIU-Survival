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
