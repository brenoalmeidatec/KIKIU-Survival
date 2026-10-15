# Corte do Hazaki (Blender)

Efeito do golpe de katana feito por nós no Blender 5.2 (nada de arte de terceiros). Refazer:

```
blender -b -P corte_hazaki.py            # gera corte_hazaki.blend e corte_hazaki_folha.png (16 quadros 128x128, quantizada)
blender -b -P previa.py -- corte_hazaki_folha.png previa_corte.gif   # prévia sobre fundo escuro
```

Depois copie `corte_hazaki_folha.png` para `projeto/assets/v2/efeitos/corte_hazaki.png` (o jogo lê de lá, em `v2/efeitos.gd`).
Render leve: Cycles só com emissão, 12 amostras, ~3 s no total. A folha guarda RGB = calor (0..1) e A = intensidade; o shader do jogo tinge
com a cor do golpe (`dados/v2_combate.json`, `passos[].cor`) e espelha para `lado = -1`.

`gif_jogo.py` monta o GIF antes x depois a partir de `projeto/testes/captura_corte.gd` (captura do jogo, 60 fps fixos).
Só o **corte** usa a folha; a **estocada** continua no shader procedural antigo.
