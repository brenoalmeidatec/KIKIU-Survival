# Nuvem de Esporos (nuvem_espora)
**Tipo:** nuvem. **Ícone:** icone_u_baluarte_espinhoso.
**O que faz:** Uma nuvem de esporos dourados cai sobre um inimigo perto do herói e fica no chão por muito tempo, batendo forte em quem está dentro.
**Na prática:** Procura inimigos num alcance de 200 (no código, 320 px, porque o número é multiplicado por 1,6). Recarga de 4,5 s entre uma nuvem e outra, empatada com a Cortina de Sangue como a mais lenta do lote. A nuvem fica no chão por 7 s. Dá 10 de dano a cada 0,8 s, ou seja, 9 pulsos e 90 de dano no total para quem fica dentro o tempo todo. Raio de 60 px (120 px de diâmetro). Sem lentidão. A nuvem cai no inimigo mais perto do herói.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 10, recarga 4,5 s, duração 7 s, pulso a cada 0,8 s, raio 60 |
| 2 | +3 de dano. Dano por pulso passa para 13. |
| 3 | Dura mais: +1,5 s (duração 8,5 s). |
| 4 | Cai mais rápido: recarga cai 0,4 s (passa para 4,1 s). |
| 5 | +4 de dano e nuvem maior. Efeito acumulado: dano 17 por pulso, duração 8,5 s, recarga 4,1 s, raio 72 (144 px de diâmetro). |

**Fusões e evoluções:** Sem fusão hoje.
**Peste de Esporos (proposta):** Nuvem de Esporos nível 3 + Nuvem Venenosa nível 3. As duas somem e nasce uma nuvem só, longa e de dano alto, com o veneno dentro.

**Animação e efeitos:** Hoje aparece só o placeholder: um círculo marrom-dourado translúcido, que some no fim. Os grãos ainda não aparecem.
Especificação do campo "arte" do JSON, para o Alisson substituir:
- Visual: uma nuvem marrom-dourada de esporos, com grãos pequenos girando lentamente e caindo para o chão. Referência de tela 960x540.
- Cores: marrom-dourado, bege, âmbar.
- Tamanho: nuvem de 120 px de diâmetro; grãos de 2 a 4 px.
- Duração: grãos caem por toda a duração; fade de 0,7 s no fim.

**Mudanças em relação ao desenho original:** Nenhuma no desenho (segue o PR #192). **Números corrigidos (código):** 9 pulsos e 90 de dano (não 8 a 9 e 80 a 90); a recarga de 4,5 s é empatada com a Cortina de Sangue.

**Pontos de atenção:**
- A descrição diz "cai perto de você", mas o código põe a nuvem sobre o inimigo mais perto. Um dos dois precisa mudar.
- Com 7 s de duração e 17 de dano por pulso no nível 5, esta é uma das nuvens mais fortes. Checar no teste contra a Cortina de Sangue.
- O fade é fixo no código (0,3 s para entrar e 0,6 s para sair), e não usa os 0,7 s do campo "arte".

## Esquemática
- **Gatilho:** a cada recarga, quando há monstro a até 340 px do herói. Recarga de 4,5 s no nível 1; no nível 4 passa para 4,1 s. A recarga é dividida pelo vel_ataque do herói (1,0 por padrão). Sem monstro a 340 px, espera 0,3 s e não gasta a recarga. Se há monstro a 340 px mas nenhum dentro do alcance do alvo, a recarga é gasta e nenhuma nuvem sai.
- **Alvo:** o monstro mais perto do herói dentro do alcance (distância no plano achatado: y ÷ 0,62). Não escolhe por vida nem por tipo. A nuvem nasce sobre o alvo e não acompanha ele.
- **Trajetória e alcance:** nenhuma trajetória. A nuvem nasce parada no chão, sobre o alvo (velocidade 0). Alcance: 320 px no plano achatado (alcance 200 × 1,6). Na prática: 320 px na horizontal e 198 px na vertical, porque a lista de monstros próximos corta em 340 px.
- **Área:** Círculo no chão, visto como elipse (y × 0,62). Raio 60 px no nível 1 (120 px de diâmetro), e 72 px no nível 5 (144 px de diâmetro). Acerta quem está com o centro a menos de raio + raio do corpo do monstro (varia por tipo).
- **Dano por nível:**

| Nível | Dano por tique | Como muda |
|---|---|---|
| 1 | 10 | base: recarga 4,5 s, duração 7 s, pulso a cada 0,8 s, raio 60 px. 9 pulsos, total 90 se o alvo ficar dentro. |
| 2 | 13 | Dano +3 por tique (passa para 13). 9 pulsos, total 117 se o alvo ficar dentro. |
| 3 | 13 | Duração +1,5 s (passa para 8,5 s). 11 pulsos, total 143 se o alvo ficar dentro. |
| 4 | 13 | Recarga -0,4 s (passa para 4,1 s). 11 pulsos, total 143 se o alvo ficar dentro. |
| 5 | 17 | Dano +4 por tique (passa para 17); raio +12 px (passa para 72 px, 144 px de diâmetro). 11 pulsos, total 187 se o alvo ficar dentro. |

Raridade: o dano de cada nível é multiplicado por (1 + bônus), e o bônus é a soma dos bônus de todas as cartas desse golpe (comum 0%, raro +18%, épico +40%, lendário +80%). No nível 5, o dano por tique fica 17 comum, 20 raro, 24 épico e 31 lendário. O dano de cada tique é arredondado para inteiro (mínimo 1). O multiplicador de dano do herói (m_dano) é 1,0 por padrão; as cartas e o meta podem aumentá-lo.
- **Como aplica:** por tique. A cada 0,8 s (o primeiro vem 0,05 s depois de a nuvem nascer), todos os monstros dentro da área levam o dano do tique. Cada nuvem tem seu próprio tique, então nuvens sobrepostas no mesmo monstro somam. Cada tique mostra o número de dano sobre o monstro. Com o monstro dentro o tempo todo: 9 pulsos no nível 1 e 11 no nível 5.
- **Efeitos de status:** empurrão: impulso 30 a cada tique, dividido pelo peso do monstro (não são 30 px fixos). Atordoamento: nenhum. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** o pool de golpes novos tem 48 slots (armas_novas.gd), divididos com projéteis, anéis, meteoros e aliados de todos os golpes novos. Se o pool estiver cheio, a nuvem não nasce e a recarga já foi gasta. Por golpe, no máximo 2 nuvens ao mesmo tempo no nível 1 e 3 nuvens no nível 5 (duração ÷ recarga, com vel_ataque 1,0).
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe hoje (0 s).
  - Disparo (entrada): alfa de 0 a 100% em 0,3 s, 18 quadros. O tamanho já é o final.
  - Viagem: não existe hoje (0 s). A nuvem nasce parada.
  - Impacto (permanência): 6,1 s no nível 1 (366 quadros), com pulso contínuo do raio entre 85% e 100% (período de 1,05 s, cerca de 63 quadros) e tiques a cada 0,8 s.
  - Fim: alfa de 100% a 0 em 0,6 s, 36 quadros.
  - Duração total: 7 s no nível 1 e 8,5 s no nível 5 (420 e 510 quadros).
  - Tamanho do sprite: diâmetro de 120 px no nível 1 (144 px no nível 5), altura da elipse = 0,62 × largura. Desenho aditivo (camada no_brilho).
