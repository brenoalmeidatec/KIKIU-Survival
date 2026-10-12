# Runa Explosiva (runa)
**Tipo:** runa. **Ícone:** icone_runas.

**O que faz:** Risca runas no chão. Quando um monstro chega perto, a runa explode.

**Na prática:** A cada 2,5 s, nascem 2 runas. Quando há monstro a até 340 px do herói, em 65% das vezes nascem perto de um monstro. Caso contrário (inclusive sem monstro por perto), caem de 46 a 120 px do herói. Cada runa dura 8 s. Só fica armada depois de 0,5 s, e dispara quando um monstro entra numa elipse de 16 px mais o raio do monstro. A explosão causa 30 de dano num círculo de 42 px (mais o raio do monstro, achatado no chão), empurra com impulso de 160 px/s (cerca de 17 px de deslocamento) e atordoa por 0,3 s. Acerta todos os monstros dentro da área. O dano sobe com a raridade da carta (raro +18%, épico +40%, lendário +80%).

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | Base: 2 runas a cada 2,5 s, 30 de dano, explosão de 42 px, duram 8 s |
| 2 | +1 runa (3 por vez) |
| 3 | +10 de dano (40) e explosão maior (50 px) |
| 4 | +1 runa (4 por vez) |
| 5 | +15 de dano (55) e recarga mais rápida (2,1 s). Acumulado: 4 runas a cada 2,1 s, 55 de dano, explosão de 50 px, duram 8 s |

Carta lendária sobe 2 níveis de uma vez; comum, rara e épica sobem 1.

**Fusões e evoluções:** Entra em uma evolução: **Círculo Rúnico**, com peças Runa Explosiva (nível 3) e Explosão (o modificador de crítico da katana, nível 2). Só a runa some: o modificador continua. O Círculo Rúnico vira runas com 58 de dano, a cada 1,6 s, 5 por vez, duram 9 s, gatilho de 20 px e explosão de 66 px. Quem sobrar na área fica lento por 1,6 s.

**Animação e efeitos:** Hoje, no código, a runa é um anel branco-azulado e um triângulo girando, ambos achatados no chão, com um halo da cor da arma em volta. O anel cresce em 0,3 s. Antes de armar, fica apagada (50%). Depois, pulsa. Some com esmaecimento nos últimos 0,8 s. Ao explodir, aparece um anel de onda da cor da arma, 12 partículas de estouro, uma luz de 2,6 vezes o raio e um tremor de câmera. Ao ser riscada, toca um som.

**Mudanças em relação ao desenho original:** Nenhuma: são as armas originais da v2 (leva 3), portadas da v1. Correção pela esquemática (código): o empurrão é impulso de 160 px/s (cerca de 17 px), não 160 px. A runa só nasce perto de um monstro se houver monstro a até 340 px do herói. A explosão alcança 42 px mais o raio do monstro.

**Pontos de atenção:**
- Há um teto de 14 runas vivas no código. O Círculo Rúnico (5 a cada 1,6 s, 9 s de vida) passa de 28 runas ao mesmo tempo. Com o teto, as novas deixam de nascer sem aviso.
- O impulso de 160 px/s e o atordoamento de 0,3 s estão fixos no código, não nos dados.
- Se 5 tentativas de achar um lugar livre falharem, a runa nasce perto do herói sem checar parede.
- O texto diz "quando alguém pisa", mas o gatilho é por proximidade: um monstro que passa de raspão também dispara.

## Esquemática
- **Gatilho:** recarga de 2,5 s no nível 1 e de 2,1 s no nível 5 (a velocidade de ataque do herói divide o tempo). Nascem 2 runas (3 no nível 2, 4 no nível 4). Cada runa só dispara depois de 0,5 s armada.
- **Alvo:** nenhum alvo fixo. A runa nasce perto de um monstro (65% das vezes, se houver monstro a até 340 px do herói) ou num anel de 46 a 120 px do herói (achatado no chão). Dispara quando um monstro entra na elipse de 16 px + raio do monstro.
- **Trajetória e alcance:** parada no chão. Dura 8 s. Se a vida acabar sem ninguém pisar, some sem explodir.
- **Área:** elipse no chão de 42 px de raio (nível 1 e 2) ou 50 px (nível 3 em diante), no eixo x, com y achatado (62% de x), mais o raio do monstro. Ex.: 42 x 26 px no nível 1.
- **Dano por nível:**

| Nível | Dano (base) | Como muda |
|---|---|---|
| 1 | 30 | 2 runas a cada 2,5 s, explosão de 42 px |
| 2 | 30 | +1 runa (3) |
| 3 | 40 | +10 de dano, explosão de 50 px |
| 4 | 40 | +1 runa (4) |
| 5 | 55 | +15 de dano, recarga de 2,1 s |

  Raridade: o dano base é multiplicado por (1 + bônus da raridade): comum x1,00, raro x1,18, épico x1,40, lendário x1,80, e arredonda para inteiro na hora de aplicar. No nível 1: 30, 35, 42 e 54. O m_dano do herói é 1,0 por padrão (o meta pode somar bônus).
- **Como aplica:** por explosão: cada runa explode uma vez e acerta de uma vez todos os monstros dentro da área. Não há limite de alvos.
- **Efeitos de status:** empurrão: impulso de 160 px/s (cerca de 17 px de deslocamento). Atordoamento: 0,3 s. Lentidão: nenhum (só na evolução). Queimadura: nenhum.
- **Limites na tela:** 14 runas vivas (MAX_RUNAS). Quando lota, a runa nova não nasce, sem aviso.
- **Sequência de animação (60 fps):**
  - Antecipação: surgimento de 0,3 s (18 quadros): a escala vai de 0 a 1 e o alfa sobe. Antes de armar (0,5 s, 30 quadros), a runa fica com 50% de alfa.
  - Disparo: a explosão começa no quadro do gatilho: 12 partículas, tremor de câmera de 0,12 s (7 quadros) e som.
  - Viagem: nenhuma. A runa fica parada.
  - Impacto: anel de onda na cor da runa, do tamanho da explosão, em 0,3 s (18 quadros). Luz de 2,6 vezes o raio por 0,3 s (18 quadros).
  - Fim: enquanto está armada, a runa gira 1,3 rad/s e pulsa (período de 1,05 s, 63 quadros). Nos últimos 0,8 s (48 quadros), o alfa cai até zero.
  - Sprite: glifo (triângulo) e anel, cada um de 64 x 64 px, desenhados na escala (explosão x 0,42 / 29,5, cerca de 0,6 no nível 1): anel de cerca de 35 x 22 px na tela.
