# Dragãozinho (folha de 8 direções)

```
blender -b -P gerar_dragao.py                    # a folha final
blender -b -P gerar_dragao.py -- previa <png>    # prévia para ajustar o modelo
```

Gera `projeto/assets/v2/armas/dragao_filhote_dir.png` (16 colunas x 5 linhas de 60x60: bater de asas 0-7, ataque 8-15, sopro no 12; linhas frente,
3/4 frente, perfil, 3/4 costas, costas) e o `.json` ao lado. Ele VOA: o "andar" é o bater de asas contado no relógio (`ciclo_s` da ficha
`dragao_filhote` em `projeto/v2/andante.gd`, com `altura` e `balanco`), e o ponto do `.json` é o centro do corpo, não o chão. O fogo do sopro não está
na folha (é feito em código no quadro do impacto); a folha mostra a boca abrindo e o corpo recuando.
