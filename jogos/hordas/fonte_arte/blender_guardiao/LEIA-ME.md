# Guardião de Pedra (folha de 8 direções)

```
blender -b -P gerar_guardiao.py                    # a folha final
blender -b -P gerar_guardiao.py -- previa <png>    # prévia para ajustar o modelo
blender -b -P gerar_guardiao.py -- diag            # sem render: o chão e os pés em cada quadro de andar
```

Gera `projeto/assets/v2/armas/guardiao_pedra_dir.png` (16 colunas x 5 linhas de 77x93: andar 0-7, ataque 8-15, pancada com os dois punhos no 12; linhas
frente, 3/4 frente, perfil, 3/4 costas, costas) e o `.json` ao lado com o pé, a passada medida em pixels por vista e o alcance dos punhos. O jogo usa
a ficha `guardiao_pedra` de `projeto/v2/andante.gd` (os números do `.json` copiados no código) e o teste `testes/v2_andante` confere que os dois batem.
Mesmo esqueleto e mesmo andar do Golem (`../blender_golem/`), mas de pedra cinza, quadrado, com rachaduras e musgo.
