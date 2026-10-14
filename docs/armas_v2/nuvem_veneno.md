# Nuvem Venenosa (nuvem_veneno)
**Tipo:** nuvem. **Ícone:** icone_u_pocao_corrosiva.
**O que faz:** Uma nuvem verde cai sobre um inimigo perto do herói e envenena quem fica dentro dela. Quem sai da nuvem para de levar dano.
**Na prática:** Procura inimigos num alcance de 180 (no código, 288 px, porque o número é multiplicado por 1,6). Recarga de 3 s entre uma nuvem e outra. A nuvem fica no chão por 4 s. Dá 5 de dano a cada 0,5 s, ou seja, 8 pulsos e cerca de 40 de dano no total para quem fica dentro o tempo todo. Raio de 50 px (a nuvem tem 100 px de diâmetro). Sem lentidão. A nuvem cai no inimigo mais perto do herói.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 5, recarga 3 s, duração 4 s, pulso a cada 0,5 s, raio 50 |
| 2 | +2 de dano. Dano por pulso passa para 7. |
| 3 | A nuvem dura mais: +1,5 s (duração 5,5 s). |
| 4 | Cai mais rápido: recarga cai 0,6 s (passa para 2,4 s). |
| 5 | +3 de dano e nuvem maior. Efeito acumulado: dano 10 por pulso, duração 5,5 s, recarga 2,4 s, raio 62 (124 px de diâmetro). |

**Fusões e evoluções:** Sem fusão hoje.
**Peste de Esporos (proposta):** Nuvem Venenosa nível 3 + Nuvem de Esporos nível 3. As duas somem e nasce uma nuvem só, longa e de dano alto, com o veneno dentro.

**Animação e efeitos:** Hoje aparece só o placeholder: um círculo verde translúcido, achatado para parecer chão, que pulsa devagar e some no fim. Ainda não tem as bolhas.
Especificação do campo "arte" do JSON, para o Alisson substituir:
- Visual: uma nuvem verde-tóxica, densa e com bolhas, cai do alto no chão perto do herói e fica parada, com partículas subindo. Referência de tela 960x540.
- Cores: verde-limão, verde musgo, bolhas claras.
- Tamanho: nuvem de 100 px de diâmetro no chão; bolhas de 3 a 6 px.
- Duração: a nuvem some com fade nos últimos 0,5 s.

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- A descrição diz "cai perto de você", mas o código põe a nuvem sobre o inimigo mais perto (até 288 px). Um dos dois precisa mudar.
- O código ignora a duração do campo "arte": o fade é fixo (entra em 0,3 s e some nos últimos 0,6 s). O arte pede 0,5 s.
- No nível 5 chega a 10 por pulso e 5,5 s de nuvem. Vale checar no teste se fica forte demais.

## Esquemática
- **Gatilho:** a cada recarga, quando há monstro a até 340 px do herói. Recarga de 3 s no nível 1; no nível 4 passa para 2,4 s. A recarga é dividida pelo vel_ataque do herói (1,0 por padrão). Sem monstro a 340 px, espera 0,3 s e não gasta a recarga. Se há monstro a 340 px mas nenhum dentro do alcance do alvo, a recarga é gasta e nenhuma nuvem sai.
- **Alvo:** o monstro mais perto do herói dentro do alcance (distância no plano achatado: y ÷ 0,62). Não escolhe por vida nem por tipo. A nuvem nasce sobre o alvo e não acompanha ele.
- **Trajetória e alcance:** nenhuma trajetória. A nuvem nasce parada no chão, sobre o alvo (velocidade 0). Alcance: 288 px no plano achatado (alcance 180 × 1,6). Na prática: 288 px na horizontal e 179 px na vertical, porque a lista de monstros próximos corta em 340 px.
- **Área:** Círculo no chão, visto como elipse (y × 0,62). Raio 50 px no nível 1 (100 px de diâmetro), e 62 px no nível 5 (124 px de diâmetro). Acerta quem está com o centro a menos de raio + raio do corpo do monstro (varia por tipo).
- **Dano por nível:**

| Nível | Dano por tique | Como muda |
|---|---|---|
| 1 | 5 | base: recarga 3 s, duração 4 s, pulso a cada 0,5 s, raio 50 px. 8 pulsos, total 40 se o alvo ficar dentro. |
| 2 | 7 | Dano +2 por tique (passa para 7). 8 pulsos, total 56 se o alvo ficar dentro. |
| 3 | 7 | Duração +1,5 s (passa para 5,5 s). 11 pulsos, total 77 se o alvo ficar dentro. |
| 4 | 7 | Recarga -0,6 s (passa para 2,4 s). 11 pulsos, total 77 se o alvo ficar dentro. |
| 5 | 10 | Dano +3 por tique (passa para 10); raio +12 px (passa para 62 px, 124 px de diâmetro). 11 pulsos, total 110 se o alvo ficar dentro. |

Raridade: o dano de cada nível é multiplicado por (1 + bônus), e o bônus é a soma dos bônus de todas as cartas desse golpe (comum 0%, raro +18%, épico +40%, lendário +80%). No nível 5, o dano por tique fica 10 comum, 12 raro, 14 épico e 18 lendário. O dano de cada tique é arredondado para inteiro (mínimo 1). O multiplicador de dano do herói (m_dano) é 1,0 por padrão; as cartas e o meta podem aumentá-lo.
- **Como aplica:** por tique. A cada 0,5 s (o primeiro vem 0,05 s depois de a nuvem nascer), todos os monstros dentro da área levam o dano do tique. Cada nuvem tem seu próprio tique, então nuvens sobrepostas no mesmo monstro somam. Cada tique mostra o número de dano sobre o monstro. Com o monstro dentro o tempo todo: 8 pulsos no nível 1 e 11 no nível 5.
- **Efeitos de status:** empurrão: impulso 30 a cada tique, dividido pelo peso do monstro (não são 30 px fixos). Atordoamento: nenhum. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** o pool de golpes novos tem 48 slots (armas_novas.gd), divididos com projéteis, anéis, meteoros e aliados de todos os golpes novos. Se o pool estiver cheio, a nuvem não nasce e a recarga já foi gasta. Por golpe, no máximo 2 nuvens ao mesmo tempo no nível 1 e 3 nuvens no nível 5 (duração ÷ recarga, com vel_ataque 1,0).
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe hoje (0 s).
  - Disparo (entrada): alfa de 0 a 100% em 0,3 s, 18 quadros. O tamanho já é o final.
  - Viagem: não existe hoje (0 s). A nuvem nasce parada.
  - Impacto (permanência): 3,1 s no nível 1 (186 quadros), com pulso contínuo do raio entre 85% e 100% (período de 1,05 s, cerca de 63 quadros) e tiques a cada 0,5 s.
  - Fim: alfa de 100% a 0 em 0,6 s, 36 quadros.
  - Duração total: 4 s no nível 1 e 5,5 s no nível 5 (240 e 330 quadros).
  - Tamanho do sprite: diâmetro de 100 px no nível 1 (124 px no nível 5), altura da elipse = 0,62 × largura. Desenho aditivo (camada no_brilho).
