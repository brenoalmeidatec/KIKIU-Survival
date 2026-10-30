# Espectro Uivante das Ruínas (#449)

`medio/espectro_uivante` usa a folha própria `inimigo_espectro`, em vez do lobo recolorido. O modelo encapuzado, sem pernas, flutua com o manto e as mangas animados. A tinta do elenco e todos os números do lobo anterior foram preservados; nenhum outro tipo muda de aparência neste PR.

Fonte própria já existente: `jogos/hordas/fonte_arte/modelos3d/horror.py`, função `espectro`. Reproduzir a partir de `jogos/hordas/prototipos/cara_nova` com Blender 4.5 LTS:

```text
blender -b -P gerar_cara_nova.py -- monstro horror espectro
```

Saem JSON e três folhas (albedo, normal e emissão), cinco vistas por quatro quadros, com espelhamento para oito direções. O gerador mede todas as poses antes de enquadrar a folha: quadro 38×55, pé em y=53.

## Pool

O pool reserva **182** instâncias. É um limite conservador de vivos possíveis, não uma extrapolação da média do sorteio:

- Diretor: `round(84 × 1,5 × 1,3) = 164`, com Difícil e Pesadelo. Esse teto já inclui os moradores iniciais e as ondas fortes.
- Duas elites podem nascer acima do teto do diretor.
- A única defesa das Ruínas dura 30 s, solta dois monstros na entrada e a cada quatro segundos: `ceil(30/4) × 2 = 16`, também fora do teto.
- Total: `164 + 2 + 16 = 182`. Nas Ruínas, invocações de elite são larvas/esqueletos; os filhotes de chefe também não usam o espectro. O pico adota o caso extremo de todos os sorteios elegíveis escolherem este tipo.

`v2_espectro_ruinas` deriva o limite dos dados, faz nascer todo o pico simultaneamente, confere que a quantidade de objetos e nós não cresceu e repete após devolver a leva inteira ao pool. Isso prova capacidade/reuso, não FPS no i5. O teste também cobre a folha, oito direções, atlas, uso restrito ao tipo das Ruínas e igualdade dos números de combate.
