# Espírito Raposa (folha de 8 direções)

```
blender -b -P gerar_raposa.py                              # a folha final
blender -b -P gerar_raposa.py -- previa <png> [a|t|todas]  # prévia: a = só andar, t = só ataque
blender -b -P gerar_raposa.py -- diag                      # sem render: o chão e as patas em cada quadro
```

Gera `projeto/assets/v2/armas/raposa_espiritual_dir.png` (16 colunas x 5 linhas: andar 0-7 em trote, ataque 8-15 com o bote no 12; linhas frente,
3/4 frente, perfil, 3/4 costas, costas) e o `.json` ao lado com o pé, a passada medida em pixels por vista e o alcance da pata (`alcance_pata_px`).
No ataque o corpo vai para a frente dentro do quadro (o bicho não anda durante o golpe). O jogo usa a ficha `espirito_raposa` de
`projeto/v2/andante.gd` (os números do `.json` copiados no código) e o teste `testes/v2_andante` confere que os dois batem. Mesmo esquema do Urso
(`../blender_urso/`) e do Golem (`../blender_golem/`).
