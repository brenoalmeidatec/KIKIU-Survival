# Chuva Ácida (chuva_acida)
**Tipo:** nuvem. **Ícone:** icone_u_estrela_matutina.
**O que faz:** Gotas ácidas caem numa área longe do herói e corroem quem estiver nela. É a nuvem mais forte de dano por pulso e a que cai de mais longe.
**Na prática:** Procura inimigos num alcance de 300 (no código, 480 px, mas a lista de inimigos próximos só vai até 340 px, então o alcance real é 340 px na horizontal e cerca de 298 px na vertical). Recarga de 1,8 s entre uma chuva e outra. A chuva fica no chão por 2,5 s. Dá 8 de dano a cada 0,5 s, ou seja, 5 pulsos e cerca de 40 de dano no total para quem fica dentro o tempo todo. Raio de 70 px (140 px de diâmetro). Sem lentidão. A chuva cai no inimigo mais perto do herói.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 8, recarga 1,8 s, duração 2,5 s, pulso a cada 0,5 s, raio 70 |
| 2 | +3 de dano. Dano por pulso passa para 11. |
| 3 | Área maior: raio +12 (82 px, ou 164 px de diâmetro). |
| 4 | Recarrega mais rápido: recarga cai 0,3 s (passa para 1,5 s). |
| 5 | +4 de dano e dura mais. Efeito acumulado: dano 15 por pulso, duração 3,5 s, recarga 1,5 s, raio 82 (164 px de diâmetro). |

**Fusões e evoluções:** Sem fusão hoje.
**Chuva de Sangue (proposta):** Chuva Ácida nível 3 + Cortina de Sangue nível 3. As duas somem e nasce uma chuva vermelha que corrói e deixa o monstro sangrando por mais tempo depois que sai da área.

**Animação e efeitos:** Hoje aparece só o placeholder: um círculo amarelo translúcido, que some no fim. As gotas ainda não caem.
Especificação do campo "arte" do JSON, para o Alisson substituir:
- Visual: várias gotas amarelo-esverdeadas caem de cima dentro de uma área no chão, com fumaça fina subindo onde batem. Referência de tela 960x540.
- Cores: amarelo-ácido, verde-amarelado, fumaça clara.
- Tamanho: área de 140 px de diâmetro; gotas de 3 x 6 px.
- Duração: as gotas caem em 0,3 s e a área some com fade.

**Mudanças em relação ao desenho original:** Nenhuma no desenho (segue o PR #192). **Números corrigidos (código):** o alcance vertical é cerca de 298 px, não 340; ver Esquemática.

**Pontos de atenção:**
- A descrição diz "longe de você", e o código acerta nisso: a chuva cai no inimigo mais perto, dentro do limite de 340 px. Mas o número 300 do alcance não é o que o jogador vê, já que o teto é 340 px na horizontal (cerca de 298 px na vertical).
- No nível 5 são 15 de dano a cada 0,5 s, a maior dose por pulso do lote. Checar no teste se fica forte.
- O fade é fixo no código (0,3 s para entrar e 0,6 s para sair), e não usa o campo "arte".

## Esquemática
- **Gatilho:** a cada recarga, quando há monstro a até 340 px do herói. Recarga de 1,8 s no nível 1; no nível 4 passa para 1,5 s. A recarga é dividida pelo vel_ataque do herói (1,0 por padrão). Sem monstro a 340 px, espera 0,3 s e não gasta a recarga. Se há monstro a 340 px mas nenhum dentro do alcance do alvo, a recarga é gasta e nenhuma nuvem sai.
- **Alvo:** o monstro mais perto do herói dentro do alcance (distância no plano achatado: y ÷ 0,62). Não escolhe por vida nem por tipo. A nuvem nasce sobre o alvo e não acompanha ele.
- **Trajetória e alcance:** nenhuma trajetória. A nuvem nasce parada no chão, sobre o alvo (velocidade 0). Alcance: 480 px no plano achatado (alcance 300 × 1,6). Na prática: 340 px na horizontal e 298 px na vertical, porque a lista de monstros próximos corta em 340 px.
- **Área:** Círculo no chão, visto como elipse (y × 0,62). Raio 70 px no nível 1 (140 px de diâmetro), e 82 px no nível 5 (164 px de diâmetro). Acerta quem está com o centro a menos de raio + raio do corpo do monstro (varia por tipo).
- **Dano por nível:**

| Nível | Dano por tique | Como muda |
|---|---|---|
| 1 | 8 | base: recarga 1,8 s, duração 2,5 s, pulso a cada 0,5 s, raio 70 px. 5 pulsos, total 40 se o alvo ficar dentro. |
| 2 | 11 | Dano +3 por tique (passa para 11). 5 pulsos, total 55 se o alvo ficar dentro. |
| 3 | 11 | Raio +12 px (passa para 82 px, 164 px de diâmetro). 5 pulsos, total 55 se o alvo ficar dentro. |
| 4 | 11 | Recarga -0,3 s (passa para 1,5 s). 5 pulsos, total 55 se o alvo ficar dentro. |
| 5 | 15 | Dano +4 por tique (passa para 15); duração +1 s (passa para 3,5 s). 7 pulsos, total 105 se o alvo ficar dentro. |

Raridade: o dano de cada nível é multiplicado por (1 + bônus), e o bônus é a soma dos bônus de todas as cartas desse golpe (comum 0%, raro +18%, épico +40%, lendário +80%). No nível 5, o dano por tique fica 15 comum, 18 raro, 21 épico e 27 lendário. O dano de cada tique é arredondado para inteiro (mínimo 1). O multiplicador de dano do herói (m_dano) é 1,0 por padrão; as cartas e o meta podem aumentá-lo.
- **Como aplica:** por tique. A cada 0,5 s (o primeiro vem 0,05 s depois de a nuvem nascer), todos os monstros dentro da área levam o dano do tique. Cada nuvem tem seu próprio tique, então nuvens sobrepostas no mesmo monstro somam. Cada tique mostra o número de dano sobre o monstro. Com o monstro dentro o tempo todo: 5 pulsos no nível 1 e 7 no nível 5.
- **Efeitos de status:** empurrão: impulso 30 a cada tique, dividido pelo peso do monstro (não são 30 px fixos). Atordoamento: nenhum. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** o pool de golpes novos tem 48 slots (armas_novas.gd), divididos com projéteis, anéis, meteoros e aliados de todos os golpes novos. Se o pool estiver cheio, a nuvem não nasce e a recarga já foi gasta. Por golpe, no máximo 2 nuvens ao mesmo tempo no nível 1 e 3 nuvens no nível 5 (duração ÷ recarga, com vel_ataque 1,0).
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe hoje (0 s).
  - Disparo (entrada): alfa de 0 a 100% em 0,3 s, 18 quadros. O tamanho já é o final.
  - Viagem: não existe hoje (0 s). A nuvem nasce parada.
  - Impacto (permanência): 1,6 s no nível 1 (96 quadros), com pulso contínuo do raio entre 85% e 100% (período de 1,05 s, cerca de 63 quadros) e tiques a cada 0,5 s.
  - Fim: alfa de 100% a 0 em 0,6 s, 36 quadros.
  - Duração total: 2,5 s no nível 1 e 3,5 s no nível 5 (150 e 210 quadros).
  - Tamanho do sprite: diâmetro de 140 px no nível 1 (164 px no nível 5), altura da elipse = 0,62 × largura. Desenho aditivo (camada no_brilho).
