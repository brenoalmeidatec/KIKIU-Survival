# Lâminas Rodopiantes (laminas)
**Tipo:** órbita. **Ícone:** icone_laminas.

**O que faz:** Lâminas giram em volta do herói, como um anel. Quem encosta nelas leva um corte.

**Na prática:** Dano 9 por corte. Cada monstro leva no máximo um corte a cada 0,45 s, não importa quantas lâminas passem por ele. São 2 lâminas num anel de 46 px em volta do herói (no chão, o anel é achatado). Uma volta completa leva cerca de 2 s. Não escolhe alvo: pega qualquer monstro que encostar no anel. Empurra com impulso de 30 px/s (cerca de 3 px de deslocamento). O dano sobe com a raridade da carta (raro +18%, épico +40%, lendário +80%).

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | Base: 2 lâminas, 9 de dano, anel de 46 px, giro de 3,2, corte a cada 0,45 s |
| 2 | +1 lâmina (3 lâminas) |
| 3 | +5 de dano (14) |
| 4 | +1 lâmina (4 lâminas) |
| 5 | +8 de dano (22) e giro mais rápido (+0,6, chega a 3,8). Acumulado: 4 lâminas, 22 de dano, giro 3,8 |

Carta lendária sobe 2 níveis de uma vez; comum, rara e épica sobem 1.

**Fusões e evoluções:** Entra em uma evolução: **Anel de Brasas**, com peças Aura de Fogo (nível 3) e Lâminas Rodopiantes (nível 3). As duas somem e viram Anel de Brasas: seis lâminas em brasa que giram dentro de um anel de fogo. Dano 17, anel de 62 px, giro 3,6, corte a cada 0,35 s, queima 7 por segundo por 2,5 s, e um anel de fogo de 56 px em volta do herói que causa 9 de dano.

**Animação e efeitos:** Hoje, no código, cada lâmina é uma faixa branca e azul-clara (26 x 11 px) que gira na direção do anel, com dois rastros de brilho atrás. Cada lâmina tem um brilho azul-claro em volta e uma sombra escura no chão. Há uma luz azul-clara só na primeira lâmina, e não uma por lâmina. Quando acerta, a cor passada ao acerto é a cor da arma clareada (45% para branco). Não há partículas próprias.

**Mudanças em relação ao desenho original:** Nenhuma: são as armas originais da v2 (leva 3), portadas da v1. Correção pela esquemática (código): o empurrão é um impulso de 30 px/s, e não 30 px. O deslocamento real é de cerca de 3 px.

**Pontos de atenção:**
- Mais lâminas não dão mais dano num mesmo monstro: cada monstro leva um corte por intervalo, não um por lâmina. Lâminas extras só cobrem mais área e mais monstros. Vale checar se o "+1 lâmina" está com valor suficiente.
- O anel cresce com o stat Arco largo, na proporção de 60% do bônus de área.
- O impulso de 30 px/s não muda com os níveis.

## Esquemática
- **Gatilho:** contínuo, sem recarga: o anel está sempre girando. O corte de cada monstro tem intervalo de 0,45 s, que não muda com o nível. A velocidade de ataque do herói (m_vel_ataque, 1,0 por padrão) divide esse intervalo.
- **Alvo:** nenhum. Qualquer monstro vivo a até 340 px do herói que encoste no anel leva o corte.
- **Trajetória e alcance:** anel fixo em volta do herói, com centro 3 px acima dos pés, raio de 46 px (o bônus de área do herói conta em 60%) e achatado no chão (y vale 62% de x). Giro de 3,2 rad/s no nível 1 (uma volta em 1,96 s) e 3,8 rad/s no nível 5 (uma volta em 1,65 s). Velocidade da ponta: 147 px/s no nível 1 e 175 px/s no nível 5. Acerta quando o trecho da lâmina de 30% a 100% do raio passa a menos de 10 px + raio do monstro do centro dele.
- **Área:** uma faixa (linha) por lâmina, do meio do anel até a ponta. Número de lâminas: 2 no nível 1, 3 no nível 2 e 3, 4 nos níveis 4 e 5.
- **Dano por nível:**

| Nível | Dano (base) | Como muda |
|---|---|---|
| 1 | 9 | 2 lâminas, anel de 46 px, giro de 3,2 rad/s |
| 2 | 9 | +1 lâmina (3) |
| 3 | 14 | +5 de dano |
| 4 | 14 | +1 lâmina (4) |
| 5 | 22 | +8 de dano e giro +0,6 (3,8 rad/s) |

  Raridade: o dano base é multiplicado por (1 + bônus da raridade): comum x1,00, raro x1,18, épico x1,40, lendário x1,80, e arredonda para inteiro na hora de aplicar. No nível 1: 9, 11, 13 e 16. O multiplicador de dano do herói (m_dano) é 1,0 por padrão; o meta (meta.gd) pode somar bônus a ele.
- **Como aplica:** por tique: cada monstro leva no máximo um corte a cada 0,45 s, mesmo que várias lâminas passem por ele.
- **Efeitos de status:** empurrão: impulso de 30 px/s, dividido pelo peso do monstro e amortecido (cai com exp(-9 t)): deslocamento total de cerca de 3 px (peso 1). Atordoamento: 0,1 s. Lentidão: nenhum. Queimadura: nenhum (só na evolução Anel de Brasas).
- **Limites na tela:** sem teto. São sempre 2 a 4 lâminas (6 na evolução), num anel só.
- **Sequência de animação (60 fps):**
  - Antecipação: nenhuma (0 s).
  - Disparo: nenhum (0 s).
  - Viagem (giro, em loop): 1,96 s por volta, ou seja 118 quadros no nível 1; 1,65 s, ou 99 quadros, no nível 5.
  - Impacto: flash branco no monstro por 0,08 s (5 quadros), junto com o número de dano. Sem partícula própria.
  - Fim: nenhum. A lâmina só some se a arma for removida.
  - Sprite: faixa de 26 x 11 px, desenhada na escala 1,15 (cerca de 30 x 13 px na tela); halo de 34 x 34 px; dois rastros de 16 x 16 px atrás.
