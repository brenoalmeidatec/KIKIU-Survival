# Serpente Ardente (folha de 8 direções)

```
blender -b -P gerar_serpente.py                    # a folha final
blender -b -P gerar_serpente.py -- previa <png>    # prévia para ajustar o modelo
```

Gera `projeto/assets/v2/armas/serpente_ardente_dir.png` (16 colunas x 5 linhas: rastejar 0-7, ataque 8-15, bote no 12; linhas frente, 3/4 frente, perfil,
3/4 costas, costas) e o `.json` ao lado com o quadro, o pé e o alcance do bote (a ponta da cabeça). O corpo tem comprimento fixo: a linha central
(onda lateral e vertical, pescoço erguido) é refeita a cada quadro e as esferas ficam a passos iguais de arco. O "andar" é a onda do corpo, num ciclo que
fecha em período 8 e o jogo roda no relógio (`ciclo_s` da ficha `serpente_ardente` em `projeto/v2/andante.gd`). Mesmo esquema do Urso (`../blender_urso/`).
