# v3: chefes da Floresta (protótipo isolado)

Pasta nova, **fora da v2**: nada aqui é carregado pelo jogo atual. A cena de teste roda sozinha.

- `chefes/chefe_base.gd`: lógica compartilhada de chefe (vida, fase, estados andar, aviso, impacto, recupera, transição e morte). Só dados e sinais, sem nó.
- `chefes/vornak.gd`: dados do Vornak (vida, ataques, fase 2 abaixo de 40%). Cada ataque aponta o clipe da folha.
- `chefes/vornak_visual.gd`: desenho do Vornak a partir das folhas de 8 direções em `assets/v3/chefes/`.
- `chefes/cena_vornak.gd` + `testes/v3_vornak_cena.tscn`: cena de teste. Tecla D = 100 de dano, R = reinicia.

## Rodar

Testes (imprime `v3_vornak falhas=0`):

    godot --headless --path jogos/hordas/projeto -s res://testes/v3_vornak.gd

Cena de teste:

    godot --path jogos/hordas/projeto res://testes/v3_vornak_cena.tscn

## O que foi testado de verdade

- Lógica do chefe: aviso antes do dano, dano uma vez por golpe, recarga, rodízio, fase 2 e transição, cura limitada, morte sem golpes depois.
- Folhas: cada animação tem o número de quadros do `.json`, com 8 direções.
- Cena: roda 400 quadros sem erro e desenha o Vornak (captura conferida).

## O que não foi testado

- Ajuste de jogo (vida, dano, recargas): valores iniciais, sem medição.
- Arte final: o Vornak é blockout do Blender (ver `docs/v3/chefes/`). Os efeitos de chão e de absorção só existem nas folhas do Blender, não na cena Godot.
- Nythrax e Maltherion: ainda não começados.
