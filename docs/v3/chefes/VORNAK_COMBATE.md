# Vornak: tempos e números de combate (rascunho para a v3)

Fonte dos números: folha conceitual do Vornak (referencias/vornak_folha_conceitual.png, quadro "Estatísticas sugeridas" e "Ataques"). Os tempos de cada golpe vêm dos clipes em `sprites/vornak_sprites.json` (fps 12) e de `v3/godot/chefes/vornak.gd`.

## Números da folha

| Estatística | Valor sugerido | Observação |
|---|---|---|
| Vida | 1200 a 1600 | o protótipo usa 1100; ajustar para 1200 se o Breno aprovar |
| Dano | 20 a 40 por golpe | o protótipo usa 8 a 10; ver o conflito abaixo |
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

## Estado

- Números da folha: documentados aqui; não aplicados em `vornak.gd` ainda.
- Tempos: os da tabela são os dos clipes; se os clipes mudarem, atualizar esta tabela.
