# Mecha do LightWolf (folha final por script, LW-7)

Robô blindado azul com orelhas de lobo, visor ciano, pods de mísseis nos ombros e canhões nos antebraços, feito por script a partir da referência
`notas/artes_chatgpt/A15_lightwolf_mecha_ref.png` (3 vistas). Parte do rig do Nicão (`../nicao/`: mesmos ossos, IK das mãos, quadro 64x96, 38 colunas x 8 direções,
mesmas animações e mesmo JSON), então o jogo troca a folha provisória sem mudar código. Só o `modelo.py` é novo; os outros .py são cópia do Nicão (renomeados).
Sem arma de mão (A15): nada de marreta, cabo ou machado; o osso `marreta` ficou sem geometria e a poeira de impacto do combo foi desligada. Canhões embutidos nos antebraços (cano escuro, boca ciano).

```
blender -b -t 6 -P gerar.py            # ~1 min: quadros/<anim>/... (não versionados) e lightwolf_mecha_rig.blend
python montar_folha.py                 # lightwolf_mecha_final_{albedo,normal}.png, .json e prévia x3
python medir.py combo                  # largura/altura por direção e se algo encosta na borda (mesmo critério do Nicão)
```
Depois copie `lightwolf_mecha_final_albedo.png`, `_normal.png` e `.json` para `projeto/prototipos/cara_nova/sprites/` como `lightwolf_mecha_albedo.png`, `_normal.png` e `.json`.

Quadro 64x96, sem aumentá-lo. Poses próprias do mecha (sem IK de cabo): parado com bracos soltos e canhoes para a frente/baixo, andar pesado, combo = dois tiros (canhao esquerdo e depois direito, bracos estendidos para a frente, clarao ciano na boca do cano no quadro 1 de cada tiro, que e o `acerto_em` 0,2 do v2_herois.json), escudo com os antebracos cruzados, dano, rolamento e morte sem arma de mao.
O clarao e geometria emissiva (`Olho clarao ...` no modelo.py; ossos.zerar esconde, anim_combo liga). Borda (`medir.py`): andar, parado, combo, escudo, dano e morte nao encostam; o rolamento encosta em 4 direcoes (poucos pixels).
Paleta escura do jogo, contorno no tom escuro da própria cor.
