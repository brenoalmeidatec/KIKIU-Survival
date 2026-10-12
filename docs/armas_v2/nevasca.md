# Nevasca (nevasca)
**Tipo:** nuvem. **Ícone:** icone_geada.
**O que faz:** Uma nuvem branca e longa cai sobre um inimigo perto do herói e atrasa quem fica nela. Dura bastante.
**Na prática:** Procura inimigos num alcance de 200 (no código, 320 px, porque o número é multiplicado por 1,6). Recarga de 4 s entre uma nuvem e outra. A nevasca fica no chão por 6 s, a mais longa do lote. Dá 4 de dano a cada 0,6 s, ou seja, 10 pulsos e cerca de 40 de dano no total para quem fica dentro o tempo todo. Raio de 65 px (130 px de diâmetro). Lentidão de 0,35 (duração do efeito por tique, não fração): quem está dentro anda a 45% da velocidade, e o efeito dura 0,35 s depois de cada tique. A nevasca cai no inimigo mais perto do herói.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 4, recarga 4 s, duração 6 s, pulso a cada 0,6 s, raio 65, lentidão 0,35 |
| 2 | +2 de dano. Dano por pulso passa para 6. |
| 3 | Dura mais: +1,5 s (duração 7,5 s). |
| 4 | Mais lenta ao monstro: lentidão sobe 0,1 (passa para 0,45). |
| 5 | +2 de dano e mais frio. Efeito acumulado: dano 8 por pulso, duração 7,5 s, lentidão 0,55, recarga 4 s, raio 65. |

**Fusões e evoluções:** Sem fusão hoje.
**Tempestade Glacial (proposta):** Nevasca nível 3 + Nevoeiro Gelado nível 3. As duas somem e nasce uma nuvem fria que congela mais forte e dura mais, com pulsos rápidos.

**Animação e efeitos:** Hoje aparece só o placeholder: um círculo branco translúcido, que some no fim. Os flocos ainda não caem.
Especificação do campo "arte" do JSON, para o Alisson substituir:
- Visual: uma nuvem branca e alta, com flocos de neve caindo do centro para fora, ocupando uma área longa no chão. Referência de tela 960x540.
- Cores: branco, branco-gelo, cinza-azulado claro.
- Tamanho: nuvem de 130 px de diâmetro; flocos de 3 a 5 px.
- Duração: flocos caem por toda a duração; fade de 0,8 s no fim.

**Mudanças em relação ao desenho original:** Nenhuma no desenho (segue o PR #192). **Números corrigidos (código):** a lentidão é duração por tique (0,35 s), não fração de velocidade.

**Pontos de atenção:**
- A descrição diz "cai perto de você", mas o código põe a nuvem sobre o inimigo mais perto. Um dos dois precisa mudar.
- A lentidão existe no código: cada tique chama `deixar_lento`, e o monstro anda a 45% da velocidade (chefe, 50%). O campo "lentidão" é a duração em s, não a força: subir +0,1 só estende o efeito em 0,1 s. Se a força precisar subir de verdade, é mudança de código.
- A nevasca é a única que o desenho pede "longa", mas o código desenha um círculo. Se a forma longa for querida, é mudança de código, não de arte.
- O fade é fixo no código (0,3 s para entrar e 0,6 s para sair), e não usa os 0,8 s do campo "arte".

## Esquemática
- **Gatilho:** a cada recarga, quando há monstro a até 340 px do herói. Recarga de 4 s, igual em todos os níveis. A recarga é dividida pelo vel_ataque do herói (1,0 por padrão). Sem monstro a 340 px, espera 0,3 s e não gasta a recarga. Se há monstro a 340 px mas nenhum dentro do alcance do alvo, a recarga é gasta e nenhuma nuvem sai.
- **Alvo:** o monstro mais perto do herói dentro do alcance (distância no plano achatado: y ÷ 0,62). Não escolhe por vida nem por tipo. A nuvem nasce sobre o alvo e não acompanha ele.
- **Trajetória e alcance:** nenhuma trajetória. A nuvem nasce parada no chão, sobre o alvo (velocidade 0). Alcance: 320 px no plano achatado (alcance 200 × 1,6). Na prática: 320 px na horizontal e 198 px na vertical, porque a lista de monstros próximos corta em 340 px.
- **Área:** Círculo no chão, visto como elipse (y × 0,62). Raio 65 px no nível 1 (130 px de diâmetro). Acerta quem está com o centro a menos de raio + raio do corpo do monstro (varia por tipo).
- **Dano por nível:**

| Nível | Dano por tique | Como muda |
|---|---|---|
| 1 | 4 | base: recarga 4 s, duração 6 s, pulso a cada 0,6 s, raio 65 px, lentidão 0,35 s. 10 pulsos, total 40 se o alvo ficar dentro. |
| 2 | 6 | Dano +2 por tique (passa para 6). 10 pulsos, total 60 se o alvo ficar dentro. |
| 3 | 6 | Duração +1,5 s (passa para 7,5 s). 13 pulsos, total 78 se o alvo ficar dentro. |
| 4 | 6 | Lentidão +0,1 s de efeito (passa para 0,45 s). 13 pulsos, total 78 se o alvo ficar dentro. |
| 5 | 8 | Dano +2 por tique (passa para 8); lentidão +0,1 s de efeito (passa para 0,55 s). 13 pulsos, total 104 se o alvo ficar dentro. |

Raridade: o dano de cada nível é multiplicado por (1 + bônus), e o bônus é a soma dos bônus de todas as cartas desse golpe (comum 0%, raro +18%, épico +40%, lendário +80%). No nível 5, o dano por tique fica 8 comum, 9 raro, 11 épico e 14 lendário. O dano de cada tique é arredondado para inteiro (mínimo 1). O multiplicador de dano do herói (m_dano) é 1,0 por padrão; as cartas e o meta podem aumentá-lo.
- **Como aplica:** por tique. A cada 0,6 s (o primeiro vem 0,05 s depois de a nuvem nascer), todos os monstros dentro da área levam o dano do tique. Cada nuvem tem seu próprio tique, então nuvens sobrepostas no mesmo monstro somam. Cada tique mostra o número de dano sobre o monstro. Com o monstro dentro o tempo todo: 10 pulsos no nível 1 e 13 no nível 5.
- **Efeitos de status:** empurrão: impulso 30 a cada tique, dividido pelo peso do monstro (não são 30 px fixos). Atordoamento: nenhum. Lentidão: o monstro anda a 45% da velocidade (chefe, 50%) enquanto o efeito durar. O campo "lentidão" é a duração do efeito por tique, não a força: 0,35 s no nível 1 e 0,55 s no nível 5. Com tique de 0,6 s, fica lento cerca de 58% do tempo dentro da nuvem no nível 1 e 92% no nível 5. Depois de sair, continua lento por até 0,55 s. Queimadura: nenhuma.
- **Limites na tela:** o pool de golpes novos tem 48 slots (armas_novas.gd), divididos com projéteis, anéis, meteoros e aliados de todos os golpes novos. Se o pool estiver cheio, a nuvem não nasce e a recarga já foi gasta. Por golpe, no máximo 2 nuvens ao mesmo tempo no nível 1 e 2 nuvens no nível 5 (duração ÷ recarga, com vel_ataque 1,0).
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe hoje (0 s).
  - Disparo (entrada): alfa de 0 a 100% em 0,3 s, 18 quadros. O tamanho já é o final.
  - Viagem: não existe hoje (0 s). A nuvem nasce parada.
  - Impacto (permanência): 5,1 s no nível 1 (306 quadros), com pulso contínuo do raio entre 85% e 100% (período de 1,05 s, cerca de 63 quadros) e tiques a cada 0,6 s.
  - Fim: alfa de 100% a 0 em 0,6 s, 36 quadros.
  - Duração total: 6 s no nível 1 e 7,5 s no nível 5 (360 e 450 quadros).
  - Tamanho do sprite: diâmetro de 130 px no nível 1 (130 px no nível 5), altura da elipse = 0,62 × largura. Desenho aditivo (camada no_brilho).
