# Vornak: tempos e números de combate (rascunho para a v3)

Fonte dos números: folha conceitual do Vornak (referencias/vornak_folha_conceitual.png, quadro "Estatísticas sugeridas" e "Ataques"). Os tempos de cada golpe vêm dos clipes em `sprites/vornak_sprites.json` (fps 12) e de `v3/godot/chefes/vornak.gd`.

## Números da folha

| Estatística | Valor sugerido | Observação |
|---|---|---|
| Vida | 1200 a 1600 | o protótipo 2D usa 1100; o 3D usa 1400 (ver abaixo) |
| Dano | 20 a 40 por golpe | o protótipo 2D usa 8 a 10; o 3D usa 20 a 35 (ver abaixo) |
| Alcance | corpo a corpo | golpes de área, ver a tabela |
| Velocidade de movimento | 1,2 a 1,8 | andar e correr |
| Tempo de ataque | 1,0 a 2,5 s | duração total de cada golpe |
| Recarga | 2,0 a 4,0 s | intervalo entre golpes |

## Golpes: aviso, impacto, recuperação

| Golpe | Clipe | Quadros (fps 12) | Aviso | Impacto | Recuperação | Janela de interrupção |
|---|---|---|---|---|---|---|
| 1. Raízes corrompidas | attack_01 | 62 | 0,9 s (marca no chão) | 2 quadros de segura | 0,6 s | não |
| 2. Golpe de raízes | attack_02 | 19 | 0,7 s (cone frontal) | 2 quadros de segura | 0,6 s | não |
| 3. Absorção de vida | attack_03 | 23 | 1,2 s (marcação com 4 pontos) | no fim (cura) | 0,8 s | sim, nos primeiros 0,6 s |
| 4. Segunda forma: raízes longas | attack_04_segunda_forma | 25 | 0,6 s | 2 quadros de segura | 0,5 s | não |
| Stagger (ao levar golpe forte) | stagger | 14 | — | — | 1,2 s | — |
| Transição de fase (40%) | phase_transition | 25 | — | — | 2,0 s, invulnerável | — |
| Grito (antes da segunda forma) | grito | 36 | — | — | 3,0 s | — |
| Morte | death | 25 | — | — | — | — |

## Indicadores no chão

- **Raízes corrompidas:** círculo de 3 m de raio com dois anéis; aparece no aviso e some no impacto.
- **Golpe de raízes:** setor de 90 graus à frente, 2,2 m de alcance.
- **Absorção:** marcação com 4 pontos ao redor do chefe; o jogador pode interromper nos primeiros 0,6 s.

Sprites dos indicadores: D:/dev/kikiu_chefes_tmp/indicadores/ (gerados pelo agente da rodada de aparência; copiar para docs/v3/chefes/indicadores/ ao fechar).

## Conflito a decidir (com o Breno)

Vida 1200 e dano de 20 a 40 por golpe fazem o Vornak mais forte do que o balanceamento atual (`BALANCEAMENTO.md`, que usa o herói de 100 de vida e dano de 8 a 10 para o Vornak). Se a folha for seguida ao pé da letra, o chefe tira o herói de 100 de vida em 3 a 4 golpes. Antes de mudar `CONFIG` em `vornak.gd`, é preciso decidir qual herói de referência vale (o da v2 tem 100; a v3 ainda não tem herói próprio).

## Protótipo 3D (`v3/godot/cena_3d/vornak_combate.gd`): números aplicados

**PROVISÓRIO até a v3 ter herói próprio.** Tudo fica no bloco de balanço do topo de `vornak_combate.gd` e na tabela `ATAQUES` do mesmo arquivo. `chefes/vornak.gd` (protótipo 2D) não mudou.

| Número | Valor no protótipo 3D | Folha |
|---|---|---|
| Vida do chefe | 1400 | 1200 a 1600 |
| Dano: raízes corrompidas | 30 | 20 a 40 |
| Dano: golpe de raízes | 20 | 20 a 40 |
| Dano: absorção | 0 (só cura o chefe em 60 se acertar; teto de 180 na luta) | — |
| Dano: raízes longas (fase 2) | 35 | 20 a 40 |
| Dano: tempestade (fase 2, ataque extra do protótipo) | 25 | 20 a 40 |
| Velocidade do chefe | andar 1,5 m/s; correr 1,8 m/s (topo da faixa) | 1,2 a 1,8 |
| Velocidade do herói de teste | 1,5 m/s | 1,2 a 1,8 |
| Recarga de cada golpe | raízes 3,0 s; golpe 2,5 s; absorção 4,0 s; raízes longas 3,0 s; tempestade 3,5 s. Na fase 2, 15% menor, nunca abaixo de 2,5 s | 2,0 a 4,0 s |
| Escolha do ataque | entre os prontos e no alcance, o usado há mais tempo (rodízio); na fase 2 os ataques da fase 2 vêm antes | — |
| Vida do herói de teste | **900** (o herói da v2 tem 100) | — |
| Golpe do herói de teste | **10** de dano, no máximo 1 golpe a cada 0,5 s (espaço) | — |

Por que o herói de teste tem 900: com o dano da folha (20 a 35 por golpe) e o chefe atacando a cada 2 s em média, o herói de 100 da v2 cai em uns 8 s parado. Para a luta "herói parado, apanhando e batendo" durar 60 a 90 s, o herói de teste precisa de 900 de vida, e o golpe dele ficou em 10 (a 0,5 s, 20 de dano por segundo) para o chefe de 1400 durar esse tempo.

**Medição (teste `vornak_3d_teste.gd`, luta simulada a 60 quadros por segundo):** herói parado a 1,5 m à frente do chefe, batendo sempre que pode. Luta de **76,5 s**; o chefe morre; o herói termina com 115 de 900; a fase 2 começa aos 47,8 s; 34 ataques do chefe; dano recebido: raízes 210, golpe 120, raízes longas 280, tempestade 175. A absorção não acertou nenhuma vez (os 4 pontos ficam nas diagonais e o herói estava de frente), então o chefe não curou. O teste falha se a luta sair de 60 a 90 s.

O stagger (150 de dano em 3 s) não acontece com esse herói (ele dá 20 por segundo, 60 em 3 s); só um golpe mais forte do herói de verdade vai abrir essa janela.

## Tempos de aviso e recuperação no protótipo 3D

Cada ataque tem `aviso` e `recupera` na tabela `ATAQUES`, com os tempos da tabela acima. Para o impacto cair exatamente no fim do aviso, o clipe toca reescalado (`AnimationPlayer.speed_scale`) e a recuperação toca mais rápido e, se não couber, é cortada:

| Golpe | Quadro de impacto (tempo no clipe) | Aviso | Velocidade no aviso | Impacto | Recuperação | Velocidade na recuperação | Cortado do clipe |
|---|---|---|---|---|---|---|---|
| Raízes (Attack_01) | 22 (1,75 s) | 0,9 s | 1,94x | 2 quadros, 1x | 0,6 s | 2,0x (teto) | 1,97 s do fim |
| Golpe (Attack_02) | 8 (0,58 s) | 0,7 s | 0,83x | 2 quadros, 1x | 0,6 s | 1,25x | nada |
| Absorção (Attack_03) | 9 (0,67 s) | 1,2 s | 0,56x | 2 quadros, 1x | 0,8 s | 1,25x | nada |
| Raízes longas (Attack_04) | 14 (1,08 s) | 0,6 s | 1,81x | 2 quadros, 1x | 0,5 s | 1,5x | nada |
| Tempestade (Ability) | 12 (0,92 s) | 0,9 s (sem valor na folha) | 1,02x | 2 quadros, 1x | 0,4 s | 1,46x | nada |

O teste confere, para os 4 ataques da folha, o aviso e a recuperação com erro de no máximo 1 quadro (1/60 s) e que a posição do clipe no início do impacto está a menos de 2 quadros do quadro de impacto (medido: 1,72 contra 1,75 s nas raízes).

O que não coube:
- **Attack_01:** 3,17 s de clipe depois do impacto não cabem em 0,6 s nem a 2x. Tocar a 5x ficaria um borrão, então a recuperação toca a 2x e o resto (1,97 s: o recolher das raízes) é cortado, com uma mistura de 0,3 s para o Idle. Se o recolher for importante, o certo é refazer o clipe no Blender com a recuperação mais curta.
- **Attack_01 e Attack_04 no aviso:** quase 2x mais rápidos que o clipe (antecipação mais seca). **Attack_02 e Attack_03:** mais lentos (0,83x e 0,56x); a absorção fica arrastada no aviso. Se incomodar, refazer os clipes com o quadro de impacto no tempo da folha.
- **Janela de interrupção da absorção (primeiros 0,6 s):** ainda não existe no protótipo 3D.

## Estado

- Números da folha: aplicados no protótipo 3D (acima); não aplicados em `chefes/vornak.gd` (2D).
- Tempos: os da tabela são os da folha; o protótipo 3D reescala os clipes para eles.
