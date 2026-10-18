# Fantasma da Mata (folha de 8 direções)

```
blender -b -P gerar_fantasma.py                    # a folha final
blender -b -P gerar_fantasma.py -- previa <png>    # prévia para ajustar o modelo
```

Gera `projeto/assets/v2/armas/fantasma_mata_dir.png` (16 colunas x 5 linhas: flutuar 0-7, ataque 8-15, bote no 12; linhas frente, 3/4 frente, perfil,
3/4 costas, costas) e o `.json` ao lado com o quadro, o pé e o alcance do bote. O fantasma não tem pernas: o "andar" é o manto ondulando, num ciclo
que fecha em período 8 e o jogo roda no relógio (`ciclo_s` da ficha `fantasma_mata` em `projeto/v2/andante.gd`, junto com `altura`). A transparência
é assada no png (corpo meio transparente, mais ralo na barra; olhos e contorno firmes). Mesmo esquema do Urso (`../blender_urso/`).
