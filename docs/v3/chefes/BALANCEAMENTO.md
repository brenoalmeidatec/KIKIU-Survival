# Chefes da Floresta (v3): balanceamento inicial

Medição simples, feita com `jogos/hordas/projeto/testes/v3_balanco.gd` (Godot 4.4.1, headless). Nada aqui é medido com jogador de verdade: o jogador é um dano constante por segundo que **não esquiva** (pior caso). O número de vida do herói não está no protótipo, então a leitura é pelo tempo e pela pressão dos golpes, não pela porcentagem.

## Tempo de luta (jogador parado)

| Chefe | Vida | 80 de dano/s | 150 de dano/s | 250 de dano/s | Golpes em 80/s | Dano em 80/s |
|---|---|---|---|---|---|---|
| Vornak | 1100 | 15 s | 7 s | 4 s | 5 | 104 |
| Nythrax | 1600 | 20 s | 11 s | 6 s | 7 | 124 |
| Maltherion | 9000 | 112 s | 60 s | 36 s | 22 | 600 |

## Janelas de esquiva (tempo de aviso antes do dano)

- **Vornak:** raízes 0,9 s, golpe de raízes 0,7 s, absorção 1,2 s (sem dano), raízes longas 0,6 s, tempestade 0,5 s.
- **Nythrax:** investida 0,6 s, névoa 0,5 s (sem dano), golpe em arco 0,8 s, ilusões 0,4 s (sem dano), investida dupla 0,4 s, garras de caça 0,5 s.
- **Maltherion:** raízes gigantes 1,4 s, invocação 1,0 s (sem dano), garras 0,9 s, tempestade 1,0 s, Coração da Floresta 2,2 s (com janela de contra-ataque de 2,4 s).

## O que chama atenção

1. **Vornak e Nythrax estão leves para quem para.** Parado, o jogador perde 104 a 124 de dano em 15 a 20 s. Se o herói tem menos vida que isso, a luta é injusta; se tem mais, é fácil. Falta o número do herói para decidir.
2. **Janelas de 0,4 a 0,6 s são curtas.** Nythrax (investida dupla, ilusões) e a tempestade do Vornak ficam perto do limite de reação humana. Sugestão inicial: não ir abaixo de 0,6 s para golpe de dano.
3. **Maltherion dura muito a 80 de dano/s (112 s).** É chefão, mas a luta longa precisa de um ponto de pausa (ex.: a transição de fase já dá isso) e de mais pressão na fase 3.
4. **Invocações e ilusões não dão dano.** Isso faz o chefe parecer mais difícil do que é. Se a arena for pequena, o limite de 3 invocações pode lotar o campo: teste isso com a arena viva.

## Próximos números a testar (no jogo de verdade)

- Vida do herói (para a conta virar porcentagem).
- Dano por golpe do Vornak e do Nythrax: testar +50% (ex.: 28 → 42).
- Janela mínima de 0,6 s para todos os golpes de dano.

Todos esses números são iniciais e ajustáveis em `v3/chefes/*.gd` (`CONFIG`).
