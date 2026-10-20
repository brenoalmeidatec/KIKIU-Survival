# Espírito do Urso (folha de 8 direções)

```
blender -b -P gerar_urso.py                    # a folha final
blender -b -P gerar_urso.py -- previa <png>    # prévia para ajustar o modelo
blender -b -P gerar_urso.py -- diag            # sem render: o chão e as patas em cada quadro de andar
```

Gera `projeto/assets/v2/armas/urso_espiritual_dir.png` (16 colunas x 5 linhas de 72x80: andar 0-7, ataque 8-15, patada no 12; linhas frente,
3/4 frente, perfil, 3/4 costas, costas) e o `.json` ao lado com o pé, a passada medida em pixels por vista e o alcance da pata. O jogo usa a
ficha `espirito_urso` de `projeto/v2/andante.gd` (os números do `.json` copiados no código; o `.json` não vai na exportação) e o teste
`testes/v2_andante` confere que os dois batem. Mesmo esquema do Golem (`../blender_golem/`).
