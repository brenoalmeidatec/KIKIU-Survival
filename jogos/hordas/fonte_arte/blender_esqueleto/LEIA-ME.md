# Esqueleto Guerreiro (folha de 8 direções)

```
blender -b -P gerar_esqueleto.py                              # a folha final
blender -b -P gerar_esqueleto.py -- previa <png> [a|t|todas]  # prévia: a = só andar, t = só ataque
blender -b -P gerar_esqueleto.py -- diag                      # sem render: o chão e os pés em cada quadro, o alcance da espada
```

Gera `projeto/assets/v2/armas/esqueleto_guerreiro_dir.png` (16 colunas x 5 linhas: andar 0-7 em corrida, ataque 8-15 com o corte em arco no 12;
linhas frente, 3/4 frente, perfil, 3/4 costas, costas) e o `.json` ao lado com o pé, a passada medida em pixels por vista e o alcance da espada
(`alcance_pata_px`). O jogo usa a ficha `esqueleto_guerreiro` de `projeto/v2/andante.gd` (os números do `.json` copiados no código) e o teste
`testes/v2_andante` confere que os dois batem. Mesmo esquema do Golem (`../blender_golem/`) e do Urso (`../blender_urso/`).
