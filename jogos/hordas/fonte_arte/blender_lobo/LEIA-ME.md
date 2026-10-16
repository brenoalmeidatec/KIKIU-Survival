# Lobo Espiritual (corrida)

Fonte: `referencia_run_breno.png`, a folha de 16 poses que o Breno mandou em 15/10/2026 (lobo azul). O jogo usa a versão branca.

```
blender -b -P gerar_lobo_corre.py [-- <pasta_para_os_quadros_soltos>]
```

Gera `projeto/assets/v2/armas/lobo_espiritual_corre.png`: 16 quadros de 82x42 em linha, olhando para a direita, pés na linha 40
e corpo centrado na coluna 48 (o código usa esse ponto como o chão). Roda em poucos segundos e refaz os quadros aprovados pelo Breno sem diferença.

Processo e o que evitar: `docs/visual_2_5d/sprites_por_referencia.md`.
