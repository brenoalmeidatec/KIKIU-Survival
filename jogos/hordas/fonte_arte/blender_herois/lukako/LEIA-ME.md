# Lukako: folha Blender com o TESSEN (leque de ferro) (PER-4)

Mesmo rig, câmera, luz, contorno e animações do Hazaki (`../hazaki/`). Só muda o perfil (`perfil.py`): modelo, paleta (haori azul-petróleo, cabelo preto curto, pele marrom, calça clara, botas escuras) e a ARMA. A katana vira um leque: **fechado** na mão no parado e nas demais animações; **aberto em meia-lua** (semicírculo com o lado reto na mão) em todos os quadros do combo. O rastro de lâmina do combo não é desenhado (o vento é efeito do jogo).

```
blender -b -t 6 -P gerar.py                      # ~1 min: quadros/<anim>/... e lukako_rig.blend
python ../hazaki/montar_folha.py . lukako        # lukako_final_{albedo,normal}.png, lukako_final.json, prévia x4
python medir.py combo                            # borda do quadro (mesmo critério do Hazaki)
```

Copiado para o jogo: `prototipos/cara_nova/sprites/lukako{.json,_albedo.png,_normal.png}`, e `"sprite": "lukako"` no nome Lukako de `dados/v2_salao.json` (o herói continua o de `v2_herois.json`, que não mudou).

Ganchos no `../hazaki/gerar.py`, só com `--perfil` (sem perfil, o Hazaki sai igual): `perfil.quadro(nome, q, n)` esconde o leque (escala zero, também na casca de contorno) conforme a animação; `perfil.efeito(nome, efeito)` troca ou tira o rastro.

Medição (`medir.py`): combo sem nenhuma borda tocada em todas as 8 direções; parado sem toque; andar toca a borda em `baixo_esq` e `cima_dir` (como as outras folhas). Nenhuma largura passa de 32 px.

Revisão: prévia ampliada e captura real em partida (`FOLHA lukako` no log) vistas; o leque aberto lê como arco em meia-lua, sem varetas (não cabe em 32 px). Ver o PR para o que não foi visto.
