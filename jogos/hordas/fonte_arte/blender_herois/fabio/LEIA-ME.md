# Fabian (arqueiro, YUMI): folha própria no Blender

Mesmo rig e mesmas animações do Hazaki (`../hazaki/`), com o modelo, as cores e o ARCO do `perfil.py` desta pasta. A katana sai; o arco
ENCURTADO (~0,9 m) fica preso ao tronco, do lado esquerdo da tela. Nos quadros de repouso a mão esquerda segura o arco; no combo o braço esquerdo
estica até a pega e o direito puxa a corda até o rosto. O combo é o `anim_combo.py` desta pasta: 3 golpes x 6 quadros, o 3º é o tiro duplo.

```
blender -b -t 6 -P gerar.py                     # ~30 s: quadros/<anim>/<direcao>_<i>_{cor,normal}.png + fabio_rig.blend
blender -b -t 6 -P gerar.py -- --anim=combo     # só o combo
python ../hazaki/montar_folha.py . fabio        # fabio_final_{albedo,normal}.png + fabio_final.json (+ prévia x4)
```

O `gerar.py` do Hazaki aceita `anim_<nome>.py` na pasta do perfil: ela SUBSTITUI a do Hazaki com o mesmo nome (não acrescenta animação nova); sem isso nada muda.

## Limites
- Corda é uma linha fixa (não curva no tiro); não há flecha no quadro (a flecha é o projétil do jogo).
- Parado, andar, rolamento, escudo, dano e morte são as do Hazaki, com o arco no lugar da katana: não têm poses próprias.
- Largura real medida (`HAZAKI_LARGURA=1`): máximo 32,3 px, em 2 quadros de mira (0,3 px além do quadro).

## No jogo
`prototipos/cara_nova/sprites/fabio{.json,_albedo.png,_normal.png}` (cópia da folha final) e `"sprite": "fabio"` no nome Fabian de `dados/v2_salao.json`.
O herói `fabio` em `dados/v2_herois.json` continua com `"sprite": "hazaki_samurai"` (não foi mexido).
