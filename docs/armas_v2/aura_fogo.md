# Aura de Fogo (aura_fogo)
**Tipo:** aura. **Ícone:** icone_brasa_viva.

**O que faz:** Um círculo de fogo em volta do herói queima e empurra quem chega perto.

**Na prática:** Dano 5 a cada pulso, e um pulso a cada 0,6 s. O círculo tem 58 px de raio em volta do herói (no chão, é uma elipse achatada). Atinge todos os monstros que estiverem dentro, de uma vez, sem escolher alvo. Empurra com impulso de 40 px/s (cerca de 4 px de deslocamento). Também deixa o monstro queimando: 3 de dano por segundo, por 2 s. No código, cada tique de 0,5 s é arredondado para inteiro (1,5 vira 2), então o efeito real é de 4 por segundo nos níveis 1 a 4. O dano sobe com a raridade da carta (raro +18%, épico +40%, lendário +80%).

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | Base: círculo de 58 px, 5 de dano a cada 0,6 s, empurra 40, queima 3 por segundo por 2 s |
| 2 | +10 de raio (68). Também empurra 15 a mais (55), mas o texto só fala do raio |
| 3 | +3 de dano (8) |
| 4 | Pulsa mais rápido: de 0,6 s para 0,5 s |
| 5 | +4 de dano (12) e queima mais forte (6 por segundo). Acumulado: círculo de 68 px, 12 de dano, pulso a cada 0,5 s, queima 6 por segundo por 2 s, empurra 55 |

Carta lendária sobe 2 níveis de uma vez; comum, rara e épica sobem 1.

**Fusões e evoluções:** Entra em uma evolução: **Anel de Brasas**, com peças Aura de Fogo (nível 3) e Lâminas Rodopiantes (nível 3). A aura some como arma separada: vira o anel de fogo de 56 px do Anel de Brasas, que causa 9 de dano. A evolução também ganha as lâminas em brasa (ver o arquivo de Lâminas Rodopiantes).

**Animação e efeitos:** Hoje, no código, o círculo é um único desenho com um shader: um anel de chama laranja que gira, com língua de fogo subindo em volta. A chama fica mais forte por um instante a cada pulso que acerta, e a borda pulsa. Usa mistura aditiva (soma a luz). Há uma luz laranja no herói, que oscila de leve. Cada pulso solta até 3 faíscas de brasa que sobem e caem, e toca o som de fogo quando acerta alguém. O tamanho do círculo acompanha o raio.

**Mudanças em relação ao desenho original:** Nenhuma: são as armas originais da v2 (leva 3), portadas da v1. Correção pela esquemática (código): o empurrão é impulso (40 px/s; 55 px/s no nível 2 em diante), não distância. Na queimadura, o arredondamento de cada tique faz sair 4 por segundo nos níveis 1 a 4 (e 6 no nível 5, que dá 3 por tique).

**Pontos de atenção:**
- O texto do nível 2 esconde o empurrão a mais (+15).
- A queima não empilha. Reaplicar só renova, e vale o maior valor de dano por segundo e de tempo. Por isso, o nível 5 só aparece se a aura for a fonte de queima.
- A área acerta todos os monstros de uma vez, então o valor cresce com a quantidade de monstros no círculo, e não só com o nível.

## Esquemática
- **Gatilho:** contínuo: pulsa a cada 0,6 s (níveis 1 a 3) e a cada 0,5 s (níveis 4 e 5). Pulsa mesmo sem monstro. A velocidade de ataque do herói (m_vel_ataque, 1,0 por padrão) divide o intervalo.
- **Alvo:** nenhum. Todo monstro dentro do círculo leva o pulso.
- **Trajetória e alcance:** sem trajetória. O círculo fica centrado no herói e é achatado no chão (y vale 62% de x). Alcance real: raio do círculo + raio do monstro.
- **Área:** elipse de 58 x 36 px no nível 1; 68 x 42 px do nível 2 em diante. O bônus de área do herói conta em 60%.
- **Dano por nível:**

| Nível | Dano (base) | Como muda |
|---|---|---|
| 1 | 5 | círculo de 58 px, pulso de 0,6 s, empurra 40, queima 3/s por 2 s |
| 2 | 5 | raio de 68 px, empurra 55 |
| 3 | 8 | +3 de dano |
| 4 | 8 | pulso de 0,5 s |
| 5 | 12 | +4 de dano, queima 6/s |

  Raridade: o dano base é multiplicado por (1 + bônus da raridade): comum x1,00, raro x1,18, épico x1,40, lendário x1,80, e arredonda para inteiro na hora de aplicar. No nível 1: 5, 6, 7 e 9. O m_dano do herói é 1,0 por padrão (o meta pode somar bônus).
- **Como aplica:** por tique: cada monstro dentro do círculo leva o pulso uma vez a cada intervalo. A queimadura não empilha: reaplicar mantém o maior dano por segundo e o maior tempo.
- **Efeitos de status:**
  - Empurrão: impulso de 40 px/s (55 px/s no nível 2 em diante), dividido pelo peso e amortecido: deslocamento de cerca de 4 px (nível 1) e de 6 px (nível 2 em diante), para peso 1.
  - Atordoamento: 0,08 s.
  - Lentidão: nenhum.
  - Queimadura: 3 por segundo (níveis 1 a 4) ou 6 por segundo (nível 5), por 2 s. O código aplica um tique de metade do valor a cada 0,5 s, começando na hora, e arredonda cada tique. Com 3 por segundo, cada tique tira 2: 4 tiques, total de 8 (4 por segundo). Com 6, cada tique tira 3: total de 12.
- **Limites na tela:** um círculo só (uma aura por vez). Sem teto de monstros: quanto mais monstros no círculo, maior o dano por pulso.
- **Sequência de animação (60 fps):**
  - Antecipação: nenhuma.
  - Disparo (pulso): o pulso começa em 1 e cai 3 por segundo, zerando em 0,33 s (20 quadros). Nesse tempo a chama fica mais forte.
  - Viagem: a chama gira sem parar (shader, sem quadros fixos). Um pulso a cada 0,6 s (36 quadros) ou 0,5 s (30 quadros).
  - Impacto: flash de 0,08 s (5 quadros) nos monstros atingidos. Até 3 faíscas de brasa por pulso (ajustado pela opção de partículas), com 0,3 a 0,6 s de vida e velocidade inicial de 14 a 34 px/s para cima.
  - Fim: a chama não termina. As faíscas somem ao fim da vida.
  - Sprite: quadrado de 2,3 x raio de lado na tela, achatado em y: 133 x 83 px no nível 1 e 156 x 97 px no nível 2 em diante. Textura base de 4 x 4 px com shader.
