# Raio em Cadeia (raio)
**Tipo:** raio. **Ícone:** icone_raio.

**O que faz:** Um raio cai no monstro mais perto e depois salta para os vizinhos.

**Na prática:** A cada 2 s, um raio cai num monstro a até 230 px do herói. Causa 20 de dano e salta para 2 vizinhos. Cada salto fica a até 74 px do alvo anterior, e perde 15% do dano (o segundo salto recebe 85% do primeiro, e assim por diante). Todos os raios do disparo caem no mesmo instante, em alvos diferentes. Escolhe o mais perto do herói, com um pouco de sorteio. O dano sobe com a raridade da carta (raro +18%, épico +40%, lendário +80%).

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | Base: 1 raio a cada 2 s, 20 de dano, 2 saltos, alcance de 230 px |
| 2 | +1 raio (2 por vez, em alvos diferentes) |
| 3 | +8 de dano (28) |
| 4 | Cai mais rápido: de 2,0 s para 1,7 s |
| 5 | +12 de dano (40) e +1 salto (3 saltos). Acumulado: 2 raios, 40 de dano, a cada 1,7 s, 3 saltos |

Carta lendária sobe 2 níveis de uma vez; comum, rara e épica sobem 1.

**Fusões e evoluções:** Entra em uma evolução: **Revoada de Trovões**, com peças Raio em Cadeia (nível 3) e Corvos Famintos (nível 3). O raio some como arma separada. Os corvos viram sete corvos elétricos que soltam um raio a cada bicada (ver o arquivo de Corvos Famintos).

**Animação e efeitos:** Hoje, no código, o raio é uma linha torta que desce de 280 px acima do alvo e passa pelos saltos. Fica visível por 0,2 s, com três camadas: um halo azul transparente de 7 px, um núcleo azul-claro de 3 px e um centro branco de 1 px. Quando cai, há uma luz azul-clara de 150 px no primeiro alvo (0,22 s), um anel de onda azul-claro de 26 px no impacto, e um som de raio com tom variado. Cada raio também chama um tremor leve de câmera.

**Mudanças em relação ao desenho original:** Nenhuma: são as armas originais da v2 (leva 3), portadas da v1. Correção pela esquemática (código): o disparo derruba todos os raios juntos (2 por disparo a partir do nível 2), e não um por vez. O corte de 15% por salto é fixo no código; o alcance de 74 px dos saltos vem de raio em dados/v2_cartas.json.

**Pontos de atenção:**
- Os saltos procuram vizinhos a partir do alvo anterior, entre os monstros que estão perto do herói (até 340 px). Por isso, a cadeia pode sair dos 230 px do lançamento.
- Cada raio chama o tremor da câmera. Com 2 raios, são 2 tremores por disparo.
- O corte de 15% por salto está fixo no código, não nos dados. O alcance de 74 px dos saltos vem do campo raio dos dados.

## Esquemática
- **Gatilho:** recarga de 2,0 s no nível 1 e de 1,7 s a partir do nível 4 (a velocidade de ataque do herói divide o tempo). Só dispara se houver monstro a até 230 px do herói; sem alvo, tenta de novo em 0,25 s.
- **Alvo:** o monstro mais perto do herói dentro de 230 px, com sorteio de até cerca de 30 px. Cada raio do disparo pega um alvo diferente. Cada salto vai para o monstro mais perto do alvo anterior, a até 74 px, que ainda não foi tocado nesta cadeia. Os saltos aceitam monstros até 340 px do herói.
- **Trajetória e alcance:** sem viagem: o raio aparece na hora. A linha desce de 280 px acima do alvo (com x sorteado em ±26 px) até o alvo e depois passa pelos saltos. Alcance do disparo: 230 px do herói. Entre alvos da cadeia: até 74 px.
- **Área:** um ponto por raio (o alvo e cada salto). Não há área.
- **Dano por nível:**

| Nível | Dano (base) | Como muda |
|---|---|---|
| 1 | 20 | 1 raio a cada 2,0 s, 2 saltos |
| 2 | 20 | +1 raio (2 por disparo) |
| 3 | 28 | +8 de dano |
| 4 | 28 | recarga de 1,7 s |
| 5 | 40 | +12 de dano, 3 saltos |

  Cada salto recebe 85% do dano do salto anterior: no nível 1, o alvo leva 20, o primeiro salto 17 e o segundo 14. Raridade: o dano base é multiplicado por (1 + bônus da raridade): comum x1,00, raro x1,18, épico x1,40, lendário x1,80, e arredonda para inteiro na hora de aplicar. O m_dano do herói é 1,0 por padrão (o meta pode somar bônus).
- **Como aplica:** uma vez por inimigo por disparo: o alvo e cada salto levam um golpe. O mesmo monstro não é tocado duas vezes na mesma cadeia.
- **Efeitos de status:** empurrão: nenhum no alvo inicial; nos saltos, impulso de 40 px/s (cerca de 4 px). Atordoamento: 0,2 s no alvo inicial e 0,15 s nos saltos. Lentidão: nenhum. Queimadura: nenhum.
- **Limites na tela:** 6 linhas de raio desenhadas ao mesmo tempo (MAX_RAIOS); a 7ª troca a mais antiga. Isso só afeta o desenho, não os acertos.
- **Sequência de animação (60 fps):**
  - Antecipação: nenhuma (0 s).
  - Disparo: no quadro 0, a linha inteira aparece e a luz azul começa.
  - Viagem: nenhuma. A linha não se move; aparece pronta.
  - Impacto: flash de 0,08 s (5 quadros) no alvo, com o número. Luz azul-clara de 150 px por 0,22 s (13 quadros). Anel de onda de 26 px por 0,2 s (12 quadros). Tremor de câmera de 0,1 s (6 quadros) por raio.
  - Fim: a linha some de forma linear em 0,2 s (12 quadros), em três camadas: halo de 7 px, núcleo de 3 px e centro de 1 px.
  - Sprite: não há sprite. A linha é desenhada por código, com trechos de cerca de 26 px e desvio de ±7 px; a altura é de 280 px acima do alvo.
