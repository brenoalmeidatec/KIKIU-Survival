# Calibração com o robô (ECO-8), 01/11/2026

Matriz 1 herói x 4 mapas x 1 semente x 3 dificuldades, rodada pela fila do Godot (`notas/godot_fila.ps1`), uma partida por vez, `--fixed-fps 60`, teto de 900 s de jogo por partida. Herói: Hazaki. Semente: 1. Tempo real do lote: 30 min (07:17 às 07:47). Relatórios e JSON brutos ficam fora do repo, em `notas/o6_logs/eco-8/` (`facil/`, `medio/`, `dificil/`).

**Nenhum dado foi alterado neste PR.** Os desvios abaixo são para decidir depois.

## Resultado das 12 partidas

| Mapa | Fácil | Médio | Difícil |
|---|---|---|---|
| Floresta | vitória 5:52 (nível 24) | derrota 3:54 (nível 24) | vitória 4:59 (nível 32) |
| Laboratório | vitória 11:17 (nível 49) | vitória 8:09 (nível 44) | derrota 7:36 (nível 49) |
| Cidade | teto 15:00, sem chefão final (nível 49) | vitória 12:31 (nível 56) | vitória 10:13 (nível 62) |
| Ruínas (medio) | derrota 3:35 (nível 20) | teto 15:00, sem chefão final (nível 64) | vitória 14:27 (nível 73) |

Travas: 0. Partidas sem JSON: 0. SCRIPT ERROR (`erros_script`): 0.

## Desvios da tabela (tolerância 20%)

Tempo de vitória, comparado com `tabela_esperada.json`:

- Floresta Fácil: 5,9 min contra 4,8 esperados, **+22%, DESVIA** (1 partida).
- Laboratório Fácil: 11,3 min contra 7,9, **+43%, DESVIA** (1 partida).
- Laboratório Médio: 8,1 contra 7,9, +3%, ok.
- Cidade Médio: 12,5 contra 11,3, +11%, ok.
- Floresta Difícil: 5,0 contra 4,8, +4%, ok.
- Cidade Difícil: 10,2 contra 11,3, -10%, ok.
- Ruínas Difícil: 14,4 contra 15,2, -5%, ok.

Sem vitória para comparar: Cidade Fácil e Ruínas Fácil e Médio (estouraram o teto de 15 min), Floresta Médio e Laboratório Difícil (derrota).

Tempo do chefão do último nível (faixa esperada de 35 a 60 s; o relatório mostra a magnitude fora da faixa, sem sinal):

- Floresta Fácil: 127 s, **fora, +111%** (acima de 60).
- Laboratório Fácil: 140 s, **fora, +133%** (acima de 60).
- Floresta Difícil: 96 s, **fora, +60%** (acima de 60).
- Cidade Difícil: 20 s, **fora, 42%** (abaixo de 35).
- Laboratório Médio: 31 s, dentro da tolerância (12% abaixo de 35).
- Cidade Médio: 30 s, dentro da tolerância (13% abaixo de 35).
- Ruínas Difícil: 45 s, dentro da faixa.

## Gatilhos do plano B (ECO-7)

- Médio: derrotas antes de 60% do mapa = 0 de 4 (0%). Limite 25%: **não aciona**.
- Difícil: derrotas antes de 60% do mapa = 0 de 4 (0%). **Não aciona**.
- Dano sofrido Médio sobre Fácil = 1,28. Limite 1,4: **não aciona**.

Cada dificuldade tem só 4 partidas e uma semente, então estes números não bastam para decidir o plano B.

## Achados

1. **O teto de 900 s de jogo corta medições.** A tabela espera 15,2 min para Ruínas, e o teto é 15 min. Cidade Fácil também estourou o teto antes do chefão. Para a próxima rodada, usar `--max 1200`.
2. **Chefões do Fácil demoram mais que o esperado, e os do Difícil, menos.** A vida máxima dos chefes é igual nas três dificuldades (4500, 1430, 1650 e 2200), então a diferença vem da produção de dano do robô na hora do chefe, e não do HP. Não há explicação medida ainda.
3. **Guarda do save real acusou em Médio e Difícil (código de saída 4).** Arquivos `foto_ed_personagens.cfg`, `foto_ed_pp1.cfg` e `.bak` foram criados às 07:30 na raiz do save real (`%APPDATA%\kikiu`), e o `.recovery_mode_lock` foi apagado durante o Difícil. Nada no repo grava esses nomes. O robô grava em `user://playtest/`. Não dá para atribuir a mudança ao robô com os dados que temos; conferir antes da próxima rodada, com o jogo real fechado.

## Próximos passos (sem mexer em dado agora)

- Repetir Fácil e Difícil com sementes 2 e 3, e `--max 1200`, antes de qualquer ajuste de chefão.
- Investigar por que o robô mata o chefão no Fácil mais devagar que no Difícil (build e dano na hora do chefe).
- Conferir a guarda do save real com o jogo fechado.
- Só então decidir sobre o plano B (ECO-7) e sobre a afinação do chefão (CAR-5 depende da medição de escolhas por mapa).
