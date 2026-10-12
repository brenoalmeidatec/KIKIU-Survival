# Névoa Espectral (nevoa_espectral)
**Tipo:** nuvem. **Ícone:** icone_u_lanterna_fantasma.
**O que faz:** Uma nuvem fantasmagórica surge perto do herói e assombra quem chega perto. Fica no chão assombrando os monstros que passam por ela.
**Na prática:** Procura inimigos num alcance de 120 (no código, 192 px, porque o número é multiplicado por 1,6). Recarga de 2,8 s entre uma névoa e outra. A névoa fica no chão por 4 s. Dá 8 de dano a cada 0,5 s, ou seja, 8 pulsos e cerca de 64 de dano no total para quem fica dentro o tempo todo. Raio de 50 px (100 px de diâmetro). Sem lentidão. A névoa cai no inimigo mais perto do herói, dentro de 192 px.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 8, recarga 2,8 s, duração 4 s, pulso a cada 0,5 s, raio 50 |
| 2 | +3 de dano. Dano por pulso passa para 11. |
| 3 | Assombra mais rápido: pulso cai 0,1 s (passa para 0,4 s). |
| 4 | Dura mais: +1 s (duração 5 s). |
| 5 | +4 de dano e cai antes. Efeito acumulado: dano 15 por pulso, pulso a cada 0,4 s, duração 5 s, recarga 2,4 s, raio 50. |

**Fusões e evoluções:** Sem fusão hoje.
**Sono Eterno (proposta):** Névoa Espectral nível 3 + Fumaça Sonolenta nível 3. As duas somem e nasce uma névoa que faz quem fica dentro dormir de vez: o monstro quase para e leva dano em pulsos.

**Animação e efeitos:** Hoje aparece só o placeholder: um círculo branco-azulado translúcido, com um brilho leve que pulsa. Os rostos ainda não aparecem.
Especificação do campo "arte" do JSON, para o Alisson substituir:
- Visual: uma névoa branco-azulada, meio transparente, com rostos muito difusos dentro, surge perto do herói e fica flutuando no chão. Referência de tela 960x540.
- Cores: branco-azulado, azul-pálido, ciano claro.
- Tamanho: névoa de 100 px de diâmetro; rostos difusos de 12 px.
- Duração: aparece com fade de 0,3 s e some com fade de 0,6 s.

**Mudanças em relação ao desenho original:** Nenhuma no desenho (segue o PR #192). **Comportamento corrigido (código):** a recarga é gasta mesmo sem alvo no alcance; ver Esquemática.

**Pontos de atenção:**
- A descrição diz "surge ao seu lado" e o arte diz "perto do herói", mas o código põe a névoa sobre o inimigo mais perto (até 192 px). Um dos dois precisa mudar.
- O alcance é o menor do lote (120, ou 192 px no código). Se nenhum inimigo estiver dentro desse raio, a névoa não sai, mas a recarga é gasta do mesmo jeito (o código zera a recarga antes de procurar o alvo). A recarga só não gasta quando não há nenhum monstro a 340 px.
- O fade é fixo no código (0,3 s para entrar e 0,6 s para sair). Bate com o campo "arte".

## Esquemática
- **Gatilho:** a cada recarga, quando há monstro a até 340 px do herói. Recarga de 2,8 s no nível 1; no nível 5 passa para 2,4 s. A recarga é dividida pelo vel_ataque do herói (1,0 por padrão). Sem monstro a 340 px, espera 0,3 s e não gasta a recarga. Se há monstro a 340 px mas nenhum dentro do alcance do alvo, a recarga é gasta e nenhuma nuvem sai.
- **Alvo:** o monstro mais perto do herói dentro do alcance (distância no plano achatado: y ÷ 0,62). Não escolhe por vida nem por tipo. A nuvem nasce sobre o alvo e não acompanha ele.
- **Trajetória e alcance:** nenhuma trajetória. A nuvem nasce parada no chão, sobre o alvo (velocidade 0). Alcance: 192 px no plano achatado (alcance 120 × 1,6). Na prática: 192 px na horizontal e 119 px na vertical, porque a lista de monstros próximos corta em 340 px.
- **Área:** Círculo no chão, visto como elipse (y × 0,62). Raio 50 px no nível 1 (100 px de diâmetro). Acerta quem está com o centro a menos de raio + raio do corpo do monstro (varia por tipo).
- **Dano por nível:**

| Nível | Dano por tique | Como muda |
|---|---|---|
| 1 | 8 | base: recarga 2,8 s, duração 4 s, pulso a cada 0,5 s, raio 50 px. 8 pulsos, total 64 se o alvo ficar dentro. |
| 2 | 11 | Dano +3 por tique (passa para 11). 8 pulsos, total 88 se o alvo ficar dentro. |
| 3 | 11 | Pulso a cada 0,4 s (era 0,5 s). 10 pulsos, total 110 se o alvo ficar dentro. |
| 4 | 11 | Duração +1 s (passa para 5 s). 13 pulsos, total 143 se o alvo ficar dentro. |
| 5 | 15 | Dano +4 por tique (passa para 15); recarga -0,4 s (passa para 2,4 s). 13 pulsos, total 195 se o alvo ficar dentro. |

Raridade: o dano de cada nível é multiplicado por (1 + bônus), e o bônus é a soma dos bônus de todas as cartas desse golpe (comum 0%, raro +18%, épico +40%, lendário +80%). No nível 5, o dano por tique fica 15 comum, 18 raro, 21 épico e 27 lendário. O dano de cada tique é arredondado para inteiro (mínimo 1). O multiplicador de dano do herói (m_dano) é 1,0 por padrão; as cartas e o meta podem aumentá-lo.
- **Como aplica:** por tique. A cada 0,5 s (o primeiro vem 0,05 s depois de a nuvem nascer), todos os monstros dentro da área levam o dano do tique. Cada nuvem tem seu próprio tique, então nuvens sobrepostas no mesmo monstro somam. Cada tique mostra o número de dano sobre o monstro. Com o monstro dentro o tempo todo: 8 pulsos no nível 1 e 13 no nível 5.
- **Efeitos de status:** empurrão: impulso 30 a cada tique, dividido pelo peso do monstro (não são 30 px fixos). Atordoamento: nenhum. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** o pool de golpes novos tem 48 slots (armas_novas.gd), divididos com projéteis, anéis, meteoros e aliados de todos os golpes novos. Se o pool estiver cheio, a nuvem não nasce e a recarga já foi gasta. Por golpe, no máximo 2 nuvens ao mesmo tempo no nível 1 e 3 nuvens no nível 5 (duração ÷ recarga, com vel_ataque 1,0).
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe hoje (0 s).
  - Disparo (entrada): alfa de 0 a 100% em 0,3 s, 18 quadros. O tamanho já é o final.
  - Viagem: não existe hoje (0 s). A nuvem nasce parada.
  - Impacto (permanência): 3,1 s no nível 1 (186 quadros), com pulso contínuo do raio entre 85% e 100% (período de 1,05 s, cerca de 63 quadros) e tiques a cada 0,5 s.
  - Fim: alfa de 100% a 0 em 0,6 s, 36 quadros.
  - Duração total: 4 s no nível 1 e 5 s no nível 5 (240 e 300 quadros).
  - Tamanho do sprite: diâmetro de 100 px no nível 1 (100 px no nível 5), altura da elipse = 0,62 × largura. Desenho aditivo (camada no_brilho).
