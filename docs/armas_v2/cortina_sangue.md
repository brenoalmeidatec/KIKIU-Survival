# Cortina de Sangue (cortina_sangue)
**Tipo:** nuvem. **Ícone:** icone_u_retalhador_sangrento.
**O que faz:** Uma névoa vermelha de dano alto aparece sobre um inimigo perto do herói, em intervalos longos. Quem fica dentro leva uma pancada forte e repetida.
**Na prática:** Procura inimigos num alcance de 150 (no código, 240 px, porque o número é multiplicado por 1,6). Recarga de 4,5 s entre uma cortina e outra. A névoa fica no chão por 3 s. Dá 18 de dano a cada 0,5 s, ou seja, 6 pulsos e cerca de 108 de dano no total para quem fica dentro o tempo todo. Raio de 35 px (70 px de diâmetro), a menor área do lote. Sem lentidão. A névoa aparece sobre o inimigo mais perto do herói.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 18, recarga 4,5 s, duração 3 s, pulso a cada 0,5 s, raio 35 |
| 2 | +3 de dano. Dano por pulso passa para 21. |
| 3 | Cai mais rápido: recarga cai 0,4 s (passa para 4,1 s). |
| 4 | +3 de dano e área maior: dano 24 por pulso, raio +8 (43 px, ou 86 px de diâmetro). |
| 5 | +4 de dano e dura mais. Efeito acumulado: dano 28 por pulso, duração 4 s, recarga 4,1 s, raio 43 (86 px de diâmetro). |

**Fusões e evoluções:** Sem fusão hoje.
**Chuva de Sangue (proposta):** Cortina de Sangue nível 3 + Chuva Ácida nível 3. As duas somem e nasce uma chuva vermelha que corrói e deixa o monstro sangrando por mais tempo depois que sai da área.

**Animação e efeitos:** Hoje aparece só o placeholder: um círculo vermelho translúcido, que some no fim. As gotas ainda não escorrem.
Especificação do campo "arte" do JSON, para o Alisson substituir:
- Visual: uma névoa vermelho-sangue densa, com gotas escorrendo de dentro, aparece de uma vez no chão ao lado do herói. Referência de tela 960x540.
- Cores: vermelho-sangue, vermelho escuro, rosa-vivo nas bordas.
- Tamanho: névoa de 70 px de diâmetro; gotas de 3 x 5 px.
- Duração: surge com flash de 0,15 s e some com fade no fim.

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- O arte diz "ao lado do herói", e a descrição diz "perto de você", mas o código põe a névoa sobre o inimigo mais perto. Um dos dois precisa mudar.
- É o golpe de maior dano por pulso, e com 6 pulsos chega a 108 de dano total no nível 1 para quem fica dentro. No nível 5, 28 por pulso. Balanço a checar com cuidado.
- O fade é fixo no código (0,3 s para entrar e 0,6 s para sair), e não usa o flash de 0,15 s do campo "arte".

## Esquemática
- **Gatilho:** a cada recarga, quando há monstro a até 340 px do herói. Recarga de 4,5 s no nível 1; no nível 3 passa para 4,1 s. A recarga é dividida pelo vel_ataque do herói (1,0 por padrão). Sem monstro a 340 px, espera 0,3 s e não gasta a recarga. Se há monstro a 340 px mas nenhum dentro do alcance do alvo, a recarga é gasta e nenhuma nuvem sai.
- **Alvo:** o monstro mais perto do herói dentro do alcance (distância no plano achatado: y ÷ 0,62). Não escolhe por vida nem por tipo. A nuvem nasce sobre o alvo e não acompanha ele.
- **Trajetória e alcance:** nenhuma trajetória. A nuvem nasce parada no chão, sobre o alvo (velocidade 0). Alcance: 240 px no plano achatado (alcance 150 × 1,6). Na prática: 240 px na horizontal e 149 px na vertical, porque a lista de monstros próximos corta em 340 px.
- **Área:** Círculo no chão, visto como elipse (y × 0,62). Raio 35 px no nível 1 (70 px de diâmetro), e 43 px no nível 5 (86 px de diâmetro). Acerta quem está com o centro a menos de raio + raio do corpo do monstro (varia por tipo).
- **Dano por nível:**

| Nível | Dano por tique | Como muda |
|---|---|---|
| 1 | 18 | base: recarga 4,5 s, duração 3 s, pulso a cada 0,5 s, raio 35 px. 6 pulsos, total 108 se o alvo ficar dentro. |
| 2 | 21 | Dano +3 por tique (passa para 21). 6 pulsos, total 126 se o alvo ficar dentro. |
| 3 | 21 | Recarga -0,4 s (passa para 4,1 s). 6 pulsos, total 126 se o alvo ficar dentro. |
| 4 | 24 | Dano +3 por tique (passa para 24); raio +8 px (passa para 43 px, 86 px de diâmetro). 6 pulsos, total 144 se o alvo ficar dentro. |
| 5 | 28 | Dano +4 por tique (passa para 28); duração +1 s (passa para 4 s). 8 pulsos, total 224 se o alvo ficar dentro. |

Raridade: o dano de cada nível é multiplicado por (1 + bônus), e o bônus é a soma dos bônus de todas as cartas desse golpe (comum 0%, raro +18%, épico +40%, lendário +80%). No nível 5, o dano por tique fica 28 comum, 33 raro, 39 épico e 50 lendário. O dano de cada tique é arredondado para inteiro (mínimo 1). O multiplicador de dano do herói (m_dano) é 1,0 por padrão; as cartas e o meta podem aumentá-lo.
- **Como aplica:** por tique. A cada 0,5 s (o primeiro vem 0,05 s depois de a nuvem nascer), todos os monstros dentro da área levam o dano do tique. Cada nuvem tem seu próprio tique, então nuvens sobrepostas no mesmo monstro somam. Cada tique mostra o número de dano sobre o monstro. Com o monstro dentro o tempo todo: 6 pulsos no nível 1 e 8 no nível 5.
- **Efeitos de status:** empurrão: impulso 30 a cada tique, dividido pelo peso do monstro (não são 30 px fixos). Atordoamento: nenhum. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** o pool de golpes novos tem 48 slots (armas_novas.gd), divididos com projéteis, anéis, meteoros e aliados de todos os golpes novos. Se o pool estiver cheio, a nuvem não nasce e a recarga já foi gasta. Por golpe, no máximo 1 nuvem ao mesmo tempo no nível 1 e 1 nuvem no nível 5 (duração ÷ recarga, com vel_ataque 1,0).
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe hoje (0 s).
  - Disparo (entrada): alfa de 0 a 100% em 0,3 s, 18 quadros. O tamanho já é o final.
  - Viagem: não existe hoje (0 s). A nuvem nasce parada.
  - Impacto (permanência): 2,1 s no nível 1 (126 quadros), com pulso contínuo do raio entre 85% e 100% (período de 1,05 s, cerca de 63 quadros) e tiques a cada 0,5 s.
  - Fim: alfa de 100% a 0 em 0,6 s, 36 quadros.
  - Duração total: 3 s no nível 1 e 4 s no nível 5 (180 e 240 quadros).
  - Tamanho do sprite: diâmetro de 70 px no nível 1 (86 px no nível 5), altura da elipse = 0,62 × largura. Desenho aditivo (camada no_brilho).
