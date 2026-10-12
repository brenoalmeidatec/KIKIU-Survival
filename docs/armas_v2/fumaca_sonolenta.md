# Fumaça Sonolenta (fumaca_sonolenta)
**Tipo:** nuvem. **Ícone:** icone_u_cajado_eremita.
**O que faz:** Uma névoa roxa cai sobre um inimigo perto do herói e deixa os monstros dentro dela lentos e sonolentos.
**Na prática:** Procura inimigos num alcance de 180 (no código, 288 px, porque o número é multiplicado por 1,6). Recarga de 3 s entre uma nuvem e outra. A fumaça fica no chão por 4 s. Dá 4 de dano a cada 0,6 s, ou seja, 7 pulsos e 28 de dano no total para quem fica dentro o tempo todo. Raio de 55 px (110 px de diâmetro). Lentidão de 0,5 (duração do efeito por tique, não fração): quem está dentro anda a 45% da velocidade, e o efeito dura 0,5 s depois de cada tique. É a maior duração do lote. A fumaça cai no inimigo mais perto do herói.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 4, recarga 3 s, duração 4 s, pulso a cada 0,6 s, raio 55, lentidão 0,5 |
| 2 | +2 de dano. Dano por pulso passa para 6. |
| 3 | Sono mais pesado: lentidão sobe 0,05 (passa para 0,55). |
| 4 | A nuvem dura mais: +1,5 s (duração 5,5 s). |
| 5 | +2 de dano e cai antes. Efeito acumulado: dano 8 por pulso, lentidão 0,55, duração 5,5 s, recarga 2,5 s, raio 55. |

**Fusões e evoluções:** Sem fusão hoje.
**Sono Eterno (proposta):** Fumaça Sonolenta nível 3 + Névoa Espectral nível 3. As duas somem e nasce uma névoa que faz quem fica dentro dormir de vez: o monstro quase para e leva dano em pulsos.

**Animação e efeitos:** Hoje aparece só o placeholder: um círculo lilás translúcido, que some no fim. Os "z" ainda não aparecem.
Especificação do campo "arte" do JSON, para o Alisson substituir:
- Visual: uma fumaça roxa-clara, suave e lenta, cai e se espalha no chão com pequenas letras "z" flutuando para cima. Referência de tela 960x540.
- Cores: roxo-claro, lilás, branco-lavanda.
- Tamanho: fumaça de 110 px de diâmetro; "z" de 8 px.
- Duração: fade suave de 0,6 s no fim.

**Mudanças em relação ao desenho original:** Nenhuma no desenho (segue o PR #192). **Números corrigidos (código):** 7 pulsos e 28 de dano (não 6 a 7 e 24 a 28); a lentidão é duração por tique (0,5 s), não fração de velocidade.

**Pontos de atenção:**
- A descrição diz "cai perto de você", mas o código põe a fumaça sobre o inimigo mais perto. Um dos dois precisa mudar.
- A lentidão existe no código: cada tique chama `deixar_lento`, e o monstro anda a 45% da velocidade (chefe, 50%). O campo "lentidão" é a duração em s, não a força: subir +0,1 só estende o efeito em 0,1 s. Se a força precisar subir de verdade, é mudança de código.
- O fade é fixo no código (0,3 s para entrar e 0,6 s para sair), e não usa os 0,6 s do campo "arte".

## Esquemática
- **Gatilho:** a cada recarga, quando há monstro a até 340 px do herói. Recarga de 3 s no nível 1; no nível 5 passa para 2,5 s. A recarga é dividida pelo vel_ataque do herói (1,0 por padrão). Sem monstro a 340 px, espera 0,3 s e não gasta a recarga. Se há monstro a 340 px mas nenhum dentro do alcance do alvo, a recarga é gasta e nenhuma nuvem sai.
- **Alvo:** o monstro mais perto do herói dentro do alcance (distância no plano achatado: y ÷ 0,62). Não escolhe por vida nem por tipo. A nuvem nasce sobre o alvo e não acompanha ele.
- **Trajetória e alcance:** nenhuma trajetória. A nuvem nasce parada no chão, sobre o alvo (velocidade 0). Alcance: 288 px no plano achatado (alcance 180 × 1,6). Na prática: 288 px na horizontal e 179 px na vertical, porque a lista de monstros próximos corta em 340 px.
- **Área:** Círculo no chão, visto como elipse (y × 0,62). Raio 55 px no nível 1 (110 px de diâmetro). Acerta quem está com o centro a menos de raio + raio do corpo do monstro (varia por tipo).
- **Dano por nível:**

| Nível | Dano por tique | Como muda |
|---|---|---|
| 1 | 4 | base: recarga 3 s, duração 4 s, pulso a cada 0,6 s, raio 55 px, lentidão 0,5 s. 7 pulsos, total 28 se o alvo ficar dentro. |
| 2 | 6 | Dano +2 por tique (passa para 6). 7 pulsos, total 42 se o alvo ficar dentro. |
| 3 | 6 | Lentidão +0,05 s de efeito (passa para 0,55 s). 7 pulsos, total 42 se o alvo ficar dentro. |
| 4 | 6 | Duração +1,5 s (passa para 5,5 s). 10 pulsos, total 60 se o alvo ficar dentro. |
| 5 | 8 | Dano +2 por tique (passa para 8); recarga -0,5 s (passa para 2,5 s). 10 pulsos, total 80 se o alvo ficar dentro. |

Raridade: o dano de cada nível é multiplicado por (1 + bônus), e o bônus é a soma dos bônus de todas as cartas desse golpe (comum 0%, raro +18%, épico +40%, lendário +80%). No nível 5, o dano por tique fica 8 comum, 9 raro, 11 épico e 14 lendário. O dano de cada tique é arredondado para inteiro (mínimo 1). O multiplicador de dano do herói (m_dano) é 1,0 por padrão; as cartas e o meta podem aumentá-lo.
- **Como aplica:** por tique. A cada 0,6 s (o primeiro vem 0,05 s depois de a nuvem nascer), todos os monstros dentro da área levam o dano do tique. Cada nuvem tem seu próprio tique, então nuvens sobrepostas no mesmo monstro somam. Cada tique mostra o número de dano sobre o monstro. Com o monstro dentro o tempo todo: 7 pulsos no nível 1 e 10 no nível 5.
- **Efeitos de status:** empurrão: impulso 30 a cada tique, dividido pelo peso do monstro (não são 30 px fixos). Atordoamento: nenhum. Lentidão: o monstro anda a 45% da velocidade (chefe, 50%) enquanto o efeito durar. O campo "lentidão" é a duração do efeito por tique, não a força: 0,5 s no nível 1 e 0,55 s no nível 5. Com tique de 0,6 s, fica lento cerca de 83% do tempo dentro da nuvem no nível 1 e 92% no nível 5. Depois de sair, continua lento por até 0,55 s. Queimadura: nenhuma.
- **Limites na tela:** o pool de golpes novos tem 48 slots (armas_novas.gd), divididos com projéteis, anéis, meteoros e aliados de todos os golpes novos. Se o pool estiver cheio, a nuvem não nasce e a recarga já foi gasta. Por golpe, no máximo 2 nuvens ao mesmo tempo no nível 1 e 3 nuvens no nível 5 (duração ÷ recarga, com vel_ataque 1,0).
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe hoje (0 s).
  - Disparo (entrada): alfa de 0 a 100% em 0,3 s, 18 quadros. O tamanho já é o final.
  - Viagem: não existe hoje (0 s). A nuvem nasce parada.
  - Impacto (permanência): 3,1 s no nível 1 (186 quadros), com pulso contínuo do raio entre 85% e 100% (período de 1,05 s, cerca de 63 quadros) e tiques a cada 0,6 s.
  - Fim: alfa de 100% a 0 em 0,6 s, 36 quadros.
  - Duração total: 4 s no nível 1 e 5,5 s no nível 5 (240 e 330 quadros).
  - Tamanho do sprite: diâmetro de 110 px no nível 1 (110 px no nível 5), altura da elipse = 0,62 × largura. Desenho aditivo (camada no_brilho).
