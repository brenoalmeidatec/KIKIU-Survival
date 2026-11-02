# John: aparência própria e naginata (mesmo rig, mesmas animações do Hazaki)

Personagem "John" (`dados/v2_salao.json`, `"sprite": "joao"`), herói `joao` (NAGINATA). Mesmo padrão do `../matheus/`: `perfil.py` troca só o modelo e as cores, o resto é o `../hazaki/gerar.py`.

```
blender -b -t 6 -P gerar.py                 # ~30 s: quadros/<anim>/<direcao>_<i>_{cor,normal}.png + joao_rig.blend
blender -b -t 6 -P gerar.py -- --anim=andar # só uma animação
python ../hazaki/montar_folha.py . joao     # joao_final_{albedo,normal}.png + joao_final.json (+ prévia x4)
python medir.py combo                       # largura/altura e se algo encosta na borda do quadro (mesmo critério do Hazaki)
```

Cópia para o jogo: `prototipos/cara_nova/sprites/joao{.json,_albedo.png,_normal.png}` (cópia de `joao_final*`).

## O que é do John (`perfil.py`)
- Cores tiradas de `assets/personagens/joao/rosto.png`: camisa azul (no lugar do casaco vermelho), pele morena, cabelo escuro, barba e bigode escuros.
- Cabelo curto com a testa mais alta (`fonte()`), barba e bigode (`Cabeça barba` e `Cabeça bigode`, que seguem a escala da cabeça), sem lenço.
- Naginata na mão direita da tela: haste curta de madeira e lâmina curva em arco para fora. Ficou 40% mais curta que a katana do Hazaki (ponta a ~0,7 da mão, contra ~1,2) para caber no quadro de 32x44.
  - Os nomes `Guarda da katana` e `Ponta da katana` são mantidos porque `ossos.guarda_ponta` os usa como referência da arma nas animações.
  - A haste sai mais para fora do corpo que a katana (eixo `d`), para aparecer na silhueta.
- A mão esquerda segue a pose de cada animação. O rig deste pipeline não tem IK de duas mãos para a haste, então a naginata é segurada só com a direita (a opção de duas mãos "se o rig deixar" não foi possível sem mexer em todas as animações).

## Medição (combo, contra o Hazaki)
Encostes no quadro: combo 2 direções (Hazaki 7), andar 6 (Hazaki 6). Prévia e captura real ficam fora do repo (`notas/o9_previas/per4-joao/`).

## Padrão do elenco (issue #586)
Perfil no padrão novo: camisa laranja queimado (cor-assinatura do John), cabeça 1,42 (massa ~38% da altura), naginata 1,5x mais comprida/mais clara com a haste de pé no parado, andar e dano (ARMA_DIRECAO como o Brendan), contorno escuro + rim light e retrato 64x64 em `assets/personagens/joao/retrato.png`.
