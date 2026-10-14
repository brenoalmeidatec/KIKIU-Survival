# Corvos Famintos (corvos)
**Tipo:** corvos. **Ícone:** icone_corvos.

**O que faz:** Corvos saem do herói, caçam os monstros mais próximos e os bicam até os corvos sumirem.

**Na prática:** A cada 4 s, nascem 2 corvos perto do herói, mas só se houver monstro a até 340 px. Sem monstro, a tentativa se repete a cada 0,3 s, em vez de esperar os 4 s. Cada corvo dura 5 s. Escolhe o monstro mais perto dele, desde que esteja a até 260 px do herói. Voa a 220 px/s. Bica a cada 0,5 s: 7 de dano e impulso de 20 px/s (cerca de 2 px de deslocamento). Sem monstro por perto, gira em volta do herói, a 44 px. Dois corvos podem bicar o mesmo monstro. O dano sobe com a raridade da carta (raro +18%, épico +40%, lendário +80%).

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | Base: 2 corvos a cada 4 s, duram 5 s, 7 de dano, bicada a cada 0,5 s |
| 2 | +1 corvo (3 por vez) |
| 3 | +3 de dano (10) e dura mais (+1 s, total 6 s) |
| 4 | +2 corvos (5 por vez) |
| 5 | +4 de dano (14) e bica mais rápido (a cada 0,4 s). Acumulado: 5 corvos a cada 4 s, 14 de dano, duram 6 s, bicada a cada 0,4 s |

Carta lendária sobe 2 níveis de uma vez; comum, rara e épica sobem 1.

**Fusões e evoluções:** Entra em uma evolução: **Revoada de Trovões**, com peças Corvos Famintos (nível 3) e Raio em Cadeia (nível 3). As duas somem e viram sete corvos elétricos: dano 14, nascem a cada 3 s, duram 6,5 s, voam a 270 px/s, bicam a cada 0,35 s e alcançam 300 px. Cada bicada também solta um raio no monstro vizinho mais perto (até 64 px), com 60% do dano.

**Animação e efeitos:** Hoje, no código, o corvo é uma figura de 3 quadros (asa para cima, no meio e para baixo), de 22 x 18 px, desenhada em 33 x 27 px. Troca de quadro enquanto voa, e vira para o lado do movimento. Tem sombra escura no chão e um brilho roxo em volta (azul-elétrico na Revoada). Sobe a altura quando voa e desce quando ataca. Ao bicar, dá um pequeno pulo de 6 px. Ao nascer e ao morrer, solta uma partícula roxa que sobe. Quando o tempo acaba, o corvo some de uma vez, sem esmaecer.

**Mudanças em relação ao desenho original:** Nenhuma: são as armas originais da v2 (leva 3), portadas da v1. Correção pela esquemática (código): o empurrão é impulso de 20 px/s (cerca de 2 px), não 20 px. Sem monstro por perto, a tentativa de nascer se repete a cada 0,3 s.

**Pontos de atenção:**
- Há um teto de 16 corvos vivos no código. Na Revoada (7 corvos a cada 3 s, 6,5 s de vida), a conta dá perto de 15. Quando lota, a nova leva não nasce e não há aviso.
- Corvos não escolhem alvo diferente um do outro: todos podem ir para o mesmo monstro. Por isso, mais corvos aumentam o dano no mesmo alvo.
- O impulso de 20 px/s é fixo no código, não está nos dados.
- Como o corvo some de uma vez, ele não tem efeito de saída.

## Esquemática
- **Gatilho:** recarga de 4,0 s, que não muda com o nível; a velocidade de ataque do herói (m_vel_ataque, 1,0 por padrão) divide o tempo. Nascem 2 corvos (3 no nível 2, 5 no nível 4). Só nasce se houver monstro a até 340 px do herói; sem monstro, tenta de novo em 0,3 s, então os corvos nascem logo que um monstro aparece.
- **Alvo:** cada corvo escolhe o monstro mais perto dele que esteja a até 260 px do herói. Reescolhe a cada 0,3 s, ou quando o alvo morre ou sai dos 260 px. Dois corvos podem escolher o mesmo alvo. Sem alvo, gira em volta do herói.
- **Trajetória e alcance:** nasce a 12 px do herói, a 34 px de altura. Voa a 220 px/s (acelera com suavização). Altura: 30 px no voo e 9 px perto do alvo. Bica quando está a até 16 px + raio do monstro. Sem alvo, orbita o herói a 44 px, com 1,6 rad/s.
- **Área:** ponto (a bicada). Não há área.
- **Dano por nível:**

| Nível | Dano (base) | Como muda |
|---|---|---|
| 1 | 7 | 2 corvos, duram 5 s, bicada a cada 0,5 s |
| 2 | 7 | +1 corvo (3) |
| 3 | 10 | +3 de dano, duram 6 s |
| 4 | 10 | +2 corvos (5) |
| 5 | 14 | +4 de dano, bicada a cada 0,4 s |

  Raridade: o dano base é multiplicado por (1 + bônus da raridade): comum x1,00, raro x1,18, épico x1,40, lendário x1,80, e arredonda para inteiro na hora de aplicar. No nível 1: 7, 8, 10 e 13. O m_dano do herói é 1,0 por padrão (o meta pode somar bônus).
- **Como aplica:** por bicada: cada corvo tem o próprio relógio de bicada (0,5 s; 0,4 s no nível 5), começando em 0,25 s + 0,05 s x ordem na leva. Cada bicada acerta um monstro. Não há limite de alvos.
- **Efeitos de status:** empurrão: impulso de 20 px/s (cerca de 2 px). Atordoamento: 0,12 s. Lentidão: nenhum. Queimadura: nenhum.
- **Limites na tela:** 16 corvos vivos (MAX_CORVOS). Quando lota, a leva nova não nasce, sem aviso.
- **Sequência de animação (60 fps):**
  - Antecipação: nenhuma. O nascimento tem uma partícula roxa de 0,3 s (18 quadros), que sobe 20 px.
  - Disparo: o corvo aparece a 34 px de altura.
  - Viagem: a asa troca de quadro a cada 0,092 s (cerca de 5,5 quadros). O ciclo de 4 passos dura 0,37 s (cerca de 22 quadros). Vira para o lado do movimento.
  - Impacto: pulo de 6 px ao bicar, que volta à altura do voo em cerca de 0,1 s. Flash de 0,08 s (5 quadros) no monstro e 3 faíscas roxas.
  - Fim: quando a duração acaba (5 s = 300 quadros; 6 s = 360 quadros), o corvo some de uma vez, sem esmaecer, com uma partícula roxa de 0,3 s.
  - Sprite: quadro de 22 x 18 px, desenhado a 33 x 27 px (escala 1,5); 3 quadros em linha (sheet de 66 x 18 px). Sombra de 16 x 7 px no chão.
