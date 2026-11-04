# Lobo do LightWolf (LW-7, #509): folha final no rig do Luke

Folha da forma "lobo" (depois que o mecha cai), no MESMO formato da provisoria (`../lightwolf_provisorio/`): quadro 32x44, 8 direcoes x 38 colunas, cor + normal,
as mesmas animacoes do Luke (parado, andar, rolamento, combo de 3 golpes, escudo, dano, morte). Substitui `prototipos/cara_nova/sprites/lightwolf_lobo.*` (mesmo nome).

```
blender -b -t 6 -P gerar.py                  # ~30 s: quadros/<anim>/... + lobo_rig.blend
python montar_folha.py                       # lightwolf_lobo_{albedo,normal}.png + lightwolf_lobo.json + previa x4
python medir.py andar                        # borda do quadro (mesmo criterio do Luke)
cp lightwolf_lobo_{albedo,normal}.png lightwolf_lobo.json ../../../projeto/prototipos/cara_nova/sprites/
```

`gerar.py` e `montar_folha.py` rodam os do `../lucas/` trocando so o modelo (`modelo_lobo.py`), a paleta e a pasta de saida; rig, camera, luz, contorno, normal e poses sao as do Luke.

## O modelo (de `notas/artes_chatgpt/A16_lightwolf_lobo_ref.png`)
A referencia e uma loba antropomorfica (duas pernas), entao o rig humanoide serve: cabeca de lobo (focinho, nariz escuro, orelhas pontudas com o dentro roxo-acinzentado,
olhos ciano, juba branca), gola de pelo, macacao azul com jaqueta curta, ombreiras e joelheiras brancas, luvas escuras, botas brancas com listra ciano, cauda grande e fofa atras
e uma pistola de energia branca com ponta ciano em cada mao. A pistola ocupa o lugar da adaga do Luke (mesmos nomes de peca): o arremesso do combo vira "tiro".
Cabeca 1,18x (a do Luke e 1,32x) para as orelhas caberem nos 44 px. Sem rosto detalhado em 32x44: orelhas, focinho e olhos ciano dao a identidade.

## Limites
- O quadro NAO cresceu: as orelhas foram baixadas ate caberem (topo na linha 1 a 6). Nas poses de golpe e nas diagonais o braco com a pistola encosta na borda, como no Luke (`medir.py`).
- Nao ha pose propria de "andar de quatro": e um piloto agil de pe, com tracos de lobo.
