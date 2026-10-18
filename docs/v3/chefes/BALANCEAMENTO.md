# Chefes da Floresta (v3): balanceamento inicial

**PROVISÓRIO.** Os números usam o herói da v2 como referência (Hazaki, 100 de vida: `jogos/hordas/projeto/dados/v2_combate.json` > `heroi.vida`). Quando a v3 tiver herói próprio, refaça a conta com a vida dele.

Medição feita por `jogos/hordas/projeto/testes/v3_balanco.gd` (Godot 4.4.1, headless). A luta é simulada com um jogador que tira 80 de dano por segundo e **não esquiva** (pior caso). Não modela reação humana.

## Meta (pedido do coordenador)

- Mini-chefes (Vornak, Nythrax): ficar parado custa 30 a 40% da vida do herói na luta inteira.
- Maltherion: um pouco mais, 40 a 60%.
- Janela de esquiva: aviso de no mínimo 0,5 s em todo golpe que causa dano.

## Resultado atual

| Chefe | Vida | Tempo de luta | Golpes parado | Dano parado | % da vida do herói | Meta |
|---|---|---|---|---|---|---|
| Vornak | 1100 | 15 s | 5 | 36 | 36% | 30 a 40% ✓ |
| Nythrax | 1600 | 20 s | 7 | 34 | 34% | 30 a 40% ✓ |
| Maltherion | 5000 | 62 s | 12 | 45 | 45% | 40 a 60% ✓ |

Os testes conferem essas metas e a janela mínima. A vida do Maltherion baixou de 9000 para 5000 para a luta não passar de um minuto no pior caso (antes: 112 s a 80 de dano/s, 600 de dano parado, o que daria mais de 600% da vida do herói).

## Janelas de esquiva (tempo de aviso)

- **Vornak:** raízes 0,9 s, golpe de raízes 0,7 s, absorção 1,2 s (sem dano), raízes longas 0,6 s, tempestade 0,5 s.
- **Nythrax:** investida 0,6 s, névoa 0,5 s (sem dano), golpe em arco 0,8 s, ilusões 0,5 s (sem dano), investida dupla 0,5 s, garras de caça 0,5 s.
- **Maltherion:** raízes gigantes 1,4 s, invocação 1,0 s (sem dano), garras 0,9 s, tempestade 1,0 s, Coração da Floresta 2,2 s (com janela de contra-ataque de 2,4 s).

## Danos por golpe (atuais)

- Vornak: raízes 10, golpe de raízes 8, raízes longas 10, tempestade 8.
- Nythrax: investida 7, golpe em arco 6, investida dupla 7, garras de caça 7.
- Maltherion: raízes gigantes 5, garras 4, tempestade 4, Coração da Floresta 8.

## O que ainda falta medir (no jogo de verdade)

- Vida do herói da v3, para a conta virar com o herói próprio.
- Dano por golpe com um jogador que esquiva (a conta acima é de quem para).
- Se a janela de 0,5 s é justa com o controle e a câmera do jogo.

Todos os números são iniciais e ajustáveis em `v3/chefes/*.gd` (`CONFIG`).
