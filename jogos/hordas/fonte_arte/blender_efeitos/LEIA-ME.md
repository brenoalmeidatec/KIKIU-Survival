# Efeitos do vídeo KiKiu no Blender (estudo)

Arte própria, feita do zero no Blender 5.2 a partir da **análise de movimento** de `docs/visual_2_5d/referencia_kikiu/ANALISE.md`, sem nada do vídeo. O jogo **ainda não usa** estas folhas; a proposta de uso está em `docs/visual_2_5d/referencia_kikiu/PROPOSTA_GOLPES.md`.

```
blender -b -P efeitos_kikiu.py -- <pasta> [cristal estrela anel espiral]   # ~1 s cada: efeito_<nome>_folha.png + .blend
python previa_efeitos.py <pasta>                                           # GIFs e tiras, mesma conta do shader do corte
```
Também roda com o módulo `bpy` 5.2 do PyPI (`python efeitos_kikiu.py -- <pasta>`), útil onde não dá para baixar o Blender.

Formato igual ao do corte ciano (`../blender_corte/corte_hazaki_ciano.py`): render 64x64 só com emissão, 4 tons de alfa e 4 de calor, dobrado para 128x128 (pixel de 2 px), quadros em linha. RGB = calor e A = intensidade; o shader tinge com `mix(cor, branco, calor*0.55)` em blend add.

| Folha | Vídeo | Quadros |
|---|---|---|
| `efeito_cristal_folha.png` | M6, explosão de cristal | 14 |
| `efeito_estrela_folha.png` | A2/M3, estrela de impacto | 9 |
| `efeito_anel_folha.png` | M2, anel duplo da magia | 18 |
| `efeito_espiral_folha.png` | V1, espiral de vento da esquiva | 12 |
