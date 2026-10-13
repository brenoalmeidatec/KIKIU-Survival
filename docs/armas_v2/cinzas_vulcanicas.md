# Cinzas Vulcânicas (cinzas_vulcanicas)
**Tipo:** nuvem. **Ícone:** icone_u_tocha_ardente.
**O que faz:** Uma nuvem grande de cinza cai sobre um inimigo perto do herói e sufoca quem fica dentro, em pulsos seguidos.
**Na prática:** Procura inimigos num alcance de 220 (no código, 352 px, mas a lista de inimigos próximos só vai até 340 px, então o alcance real é 340 px na horizontal e cerca de 218 px na vertical). Recarga de 3,5 s entre uma nuvem e outra. A nuvem fica no chão por 3 s. Dá 4 de dano a cada 0,3 s, ou seja, 10 pulsos e cerca de 40 de dano no total para quem fica dentro o tempo todo. Raio de 80 px (160 px de diâmetro). Sem lentidão. A nuvem cai no inimigo mais perto do herói.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 4, recarga 3,5 s, duração 3 s, pulso a cada 0,3 s, raio 80 |
| 2 | +2 de dano. Dano por pulso passa para 6. |
| 3 | Pulsa mais rápido: intervalo cai 0,05 s (passa para 0,25 s). |
| 4 | Dura mais e nuvem maior: duração +1 s (4 s) e raio +10 (90 px). |
| 5 | +3 de dano e cai antes. Efeito acumulado: dano 9 por pulso, pulso a cada 0,25 s, duração 4 s, raio 90 (180 px de diâmetro), recarga 3,1 s. |

**Fusões e evoluções:** Sem fusão hoje.
**Erupção (proposta):** Cinzas Vulcânicas nível 3 + Bola de Fogo nível 3. As duas somem e nasce um golpe em que cada explosão da bola de fogo deixa uma nuvem de cinzas no lugar.

**Animação e efeitos:** Hoje aparece só o placeholder: um círculo cinza escuro translúcido, que some no fim. As brasas ainda não aparecem.
Especificação do campo "arte" do JSON, para o Alisson substituir:
- Visual: uma nuvem cinza-escura, grande e turva, cai no chão com brasas apagadas girando dentro. Referência de tela 960x540.
- Cores: cinza-escuro, cinza-carvão, laranja apagado nas brasas.
- Tamanho: nuvem de 160 px de diâmetro; brasas de 3 px.
- Duração: fade de 0,5 s no fim.

**Mudanças em relação ao desenho original:** Nenhuma no desenho (segue o PR #192). **Números corrigidos (código):** o alcance vertical é cerca de 218 px, não 340; ver Esquemática.

**Pontos de atenção:**
- A descrição diz "cai perto de você", mas o código põe a nuvem sobre o inimigo mais perto. Um dos dois precisa mudar.
- O alcance de 220 dá 352 px pela regra do código, mas a lista de inimigos próximos corta em 340 px (medidos em px reais). Na prática: 340 px na horizontal e cerca de 218 px na vertical.
- Pulsa a cada 0,25 s no nível 5, e com 9 de dano por pulso chega perto de 36 de dano por segundo para quem fica dentro. Checar no teste se é forte demais.
- O fade é fixo no código (0,3 s para entrar e 0,6 s para sair), e não usa os 0,5 s do campo "arte".

## Esquemática
- **Gatilho:** a cada recarga, quando há monstro a até 340 px do herói. Recarga de 3,5 s no nível 1; no nível 5 passa para 3,1 s. A recarga é dividida pelo vel_ataque do herói (1,0 por padrão). Sem monstro a 340 px, espera 0,3 s e não gasta a recarga. Se há monstro a 340 px mas nenhum dentro do alcance do alvo, a recarga é gasta e nenhuma nuvem sai.
- **Alvo:** o monstro mais perto do herói dentro do alcance (distância no plano achatado: y ÷ 0,62). Não escolhe por vida nem por tipo. A nuvem nasce sobre o alvo e não acompanha ele.
- **Trajetória e alcance:** nenhuma trajetória. A nuvem nasce parada no chão, sobre o alvo (velocidade 0). Alcance: 352 px no plano achatado (alcance 220 × 1,6). Na prática: 340 px na horizontal e 218 px na vertical, porque a lista de monstros próximos corta em 340 px.
- **Área:** Círculo no chão, visto como elipse (y × 0,62). Raio 80 px no nível 1 (160 px de diâmetro), e 90 px no nível 5 (180 px de diâmetro). Acerta quem está com o centro a menos de raio + raio do corpo do monstro (varia por tipo).
- **Dano por nível:**

| Nível | Dano por tique | Como muda |
|---|---|---|
| 1 | 4 | base: recarga 3,5 s, duração 3 s, pulso a cada 0,3 s, raio 80 px. 10 pulsos, total 40 se o alvo ficar dentro. |
| 2 | 6 | Dano +2 por tique (passa para 6). 10 pulsos, total 60 se o alvo ficar dentro. |
| 3 | 6 | Pulso a cada 0,25 s (era 0,3 s). 12 pulsos, total 72 se o alvo ficar dentro. |
| 4 | 6 | Duração +1 s (passa para 4 s); raio +10 px (passa para 90 px, 180 px de diâmetro). 16 pulsos, total 96 se o alvo ficar dentro. |
| 5 | 9 | Dano +3 por tique (passa para 9); recarga -0,4 s (passa para 3,1 s). 16 pulsos, total 144 se o alvo ficar dentro. |

Raridade: o dano de cada nível é multiplicado por (1 + bônus), e o bônus é a soma dos bônus de todas as cartas desse golpe (comum 0%, raro +18%, épico +40%, lendário +80%). No nível 5, o dano por tique fica 9 comum, 11 raro, 13 épico e 16 lendário. O dano de cada tique é arredondado para inteiro (mínimo 1). O multiplicador de dano do herói (m_dano) é 1,0 por padrão; as cartas e o meta podem aumentá-lo.
- **Como aplica:** por tique. A cada 0,3 s (o primeiro vem 0,05 s depois de a nuvem nascer), todos os monstros dentro da área levam o dano do tique. Cada nuvem tem seu próprio tique, então nuvens sobrepostas no mesmo monstro somam. Cada tique mostra o número de dano sobre o monstro. Com o monstro dentro o tempo todo: 10 pulsos no nível 1 e 16 no nível 5.
- **Efeitos de status:** empurrão: impulso 30 a cada tique, dividido pelo peso do monstro (não são 30 px fixos). Atordoamento: nenhum. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** o pool de golpes novos tem 48 slots (armas_novas.gd), divididos com projéteis, anéis, meteoros e aliados de todos os golpes novos. Se o pool estiver cheio, a nuvem não nasce e a recarga já foi gasta. Por golpe, no máximo 1 nuvem ao mesmo tempo no nível 1 e 2 nuvens no nível 5 (duração ÷ recarga, com vel_ataque 1,0).
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe hoje (0 s).
  - Disparo (entrada): alfa de 0 a 100% em 0,3 s, 18 quadros. O tamanho já é o final.
  - Viagem: não existe hoje (0 s). A nuvem nasce parada.
  - Impacto (permanência): 2,1 s no nível 1 (126 quadros), com pulso contínuo do raio entre 85% e 100% (período de 1,05 s, cerca de 63 quadros) e tiques a cada 0,3 s.
  - Fim: alfa de 100% a 0 em 0,6 s, 36 quadros.
  - Duração total: 3 s no nível 1 e 4 s no nível 5 (180 e 240 quadros).
  - Tamanho do sprite: diâmetro de 160 px no nível 1 (180 px no nível 5), altura da elipse = 0,62 × largura. Desenho aditivo (camada no_brilho).
