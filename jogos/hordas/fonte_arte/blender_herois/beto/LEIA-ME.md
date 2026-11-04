# Bert: folha própria (KUSARIGAMA), mesmo rig e mesmas animações do Hazaki

Bert é o personagem "Bert" (herói `beto` em `dados/v2_herois.json`). Esta pasta gera a folha de sprites dele, no mesmo formato da do Hazaki e do Matheus. Só muda a aparência: o perfil troca o modelo, as cores e a arma. Regras, números e animações continuam os do herói.

```
blender -b -t 6 -P gerar.py                     # ~60 s: quadros/<anim>/<direcao>_<i>_{cor,normal}.png + beto_rig.blend
python ../hazaki/montar_folha.py . beto         # beto_final_{albedo,normal}.png + beto_final.json (+ prévia x4)
python medir.py combo                           # largura/altura por direção e se algo encosta na borda do quadro
```

- `perfil.py`: `PALETA` (casaco verde-oliva, cabelo castanho), `ajustar()` (tira a katana e o lenço; põe a foice na mão direita da tela, a corrente de 3 elos acima da mão e a bandoleira de couro; mangas escuras).
- A foice usa os nomes `Guarda da katana` e `Ponta da katana` de propósito: `hazaki/ossos.py` (`guarda_ponta`, rastro do golpe no combo) procura essas peças. Assim a foice segue o mesmo contrato da katana, sem mudar o `ossos.py` compartilhado.
- Sem física: a corrente é só geometria, presa ao antebraço.
- No jogo: `prototipos/cara_nova/sprites/beto{.json,_albedo.png,_normal.png}` (cópia da folha final) e `"sprite": "beto"` no nome Bert de `dados/v2_salao.json`. O herói (`v2_herois.json`) não muda.
- Sem referência de arte do Bert no repo; a aparência segue a descrição do herói em `dados/v2_herois.json`.
