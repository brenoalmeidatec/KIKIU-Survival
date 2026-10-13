# Lança de Geada (lanca_geada)
**Tipo:** projétil. **Ícone:** icone_u_lanca_cacada.
**O que faz:** Arremessa uma lança de gelo no inimigo mais perto a cada poucos segundos. Poucos tiros, mas cada um pesa.
**Na prática:**
- Alcance para escolher o alvo: 200 px. A lança voa até 1,6 s (cerca de 480 px).
- Dano: 14 por lança. Recarga: 3,0 s. Balas: 1 por disparo.
- Alvo: o inimigo mais perto dentro de 200 px. Acerta o primeiro inimigo que cruzar o caminho.
- No nível 1 não perfura: para no primeiro inimigo. Não tem explosão.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base): 14 de dano, recarga 3,0 s, 1 lança. |
| 2 | +4 de dano: 18 por lança. |
| 3 | Perfura 1 inimigo: atravessa um e para no próximo. |
| 4 | +1 lança: 2 lanças por disparo. |
| 5 | +6 de dano e mais rápida: 24 de dano, recarga 2,5 s. Lendário sobe 2 níveis de uma vez. Acumulado no nível 5: 2 lanças, 24 de dano, recarga 2,5 s, perfura 1. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** **Lança do Amanhecer**: Lança de Geada nível 3 + Raio Solar nível 3. Consome as duas. Ideia: um feixe de sol que sai congelado e atravessa.
Obs.: esta arma também aparece na proposta **Disco de Gelo** (ver Bumerangue de Ferro). Escolher uma das duas.

**Animação e efeitos:**
- Hoje (placeholder): rastro azul-gelo de 4 px, meio transparente, atrás da lança; um risco branco de 1,5 px; e um brilho de 14 px na ponta. Não gira, não solta cristais e não tem efeito de estilhaço no impacto.
- Especificação do campo "arte": lança azul-gelo com ponta cristalina, que avança girando devagar e deixa um rastro de cristais de gelo. Ao atravessar um inimigo, solta flocos brancos. No impacto, racha em estilhaços de gelo. Cores: azul-gelo, branco, azul-claro. Tamanho: lança de 18x4 px; impacto de 22 px. Duração do impacto: 0,3 s.

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- Os efeitos de flocos ao atravessar e de estilhaços no impacto não estão no código. Falta também o giro.
- O texto "provisorio" do JSON (linha de 3 px e 4 pontos brancos) não bate com o desenho atual. Ajustar um dos dois.
- O campo "arte" é só documentação: o código não o lê.
- Com recarga de 3 s, se o inimigo mais perto estiver fora do alcance de 200 px, mas dentro de 340 px, a arma perde o tiro sem avisar.
- Pool de projéteis compartilhado (48 vagas): se estiver cheio, a lança é descartada sem aviso.

## Esquemática
- **Gatilho:** a cada recarga: 3 s no nível 1 e 2,5 s no nível 5. A recarga é dividida por m_vel_ataque (1,0 por padrão). Sem inimigo a 340 px do herói, espera 0,3 s e não gasta a recarga. Com inimigo a 340 px, mas nenhum dentro do alcance de alvo, a recarga é gasta e nada sai.
- **Alvo:** o inimigo vivo mais perto dentro de 200 px, medido no plano achatado (y ÷ 0,62), na hora do disparo. Sem mira antecipada.
- **Trajetória e alcance:** sai 14 px acima do herói, em linha reta para a posição do alvo no momento do disparo. Velocidade 300 px/s; voa até 1,6 s, ou seja, até 480 px, ou até acertar. Não para no alcance nem no alvo, e não faz curva. Só acerta inimigos a até 340 px do herói (a lista de perto). Leque: 8° entre disparos vizinhos; com 2 disparos (nível 5), a abertura total é de 8°, com o primeiro e o último nas pontas.
- **Área:** pontual. O acerto conta um círculo de 10 px mais o raio do inimigo, no plano achatado (y ÷ 0,62). Não há área.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 14 | (base). Fica: 1 lança, recarga 3 s. |
| 2 | 18 | +4 de dano. Fica: 1 lança, recarga 3 s. |
| 3 | 18 | perfura 1 inimigo. Fica: 1 lança, recarga 3 s, perfura 1. |
| 4 | 18 | +1 lança. Fica: 2 lanças, recarga 3 s, perfura 1. |
| 5 | 24 | +6 de dano, mais rápida. Fica: 2 lanças, recarga 2,5 s, perfura 1. |

Dano = (base + soma dos níveis) × (1 + bônus acumulado). Cada carta do golpe soma o bonus_arma da sua raridade (raro +18%, épico +40%, lendário +80%), então com raro a tabela vai por 1,18; épico 1,40; lendário 1,80 (e mais, se houver mais cartas dessa arma). A tabela é a comum (bônus 0). m_dano é 1,0 por padrão; ele sobe com a meta (bônus de dano) e com cartas de atributo de dano; a tabela usa 1,0. Carta lendária sobe 2 níveis de uma vez; num golpe novo, entra direto no nível 2.
- **Como aplica:** uma vez por inimigo e por projétil. Cada ponto de perfura soma 1 inimigo atingido (perfura N acerta N+1 inimigos). Sem perfura, o projétil some no primeiro acerto.
- **Efeitos de status:** acerto: empurrão de 40 px (dividido pelo peso do inimigo) e atordoamento de 0,1 s (multiplicado pelo fator de atordoamento do inimigo; chefe não atordoa). Sem lentidão, sem queimadura e sem explosão.
- **Limites na tela:** Pool de 48 compartilhado com nuvem, anel, meteoro e aliado (armas novas). Se o pool estiver cheio, o tiro é descartado sem aviso, e o resto do leque também. Esta arma: até 1 ao mesmo tempo no nível 1 e até 2 no nível 5 (2 por disparo a cada 2,5 s, com 1,6 s de voo).
- **Sequência de animação (quadro a quadro, a 60 fps):**
- **Disparo (quadro 0):** o projétil nasce 14 px acima do herói. Não há efeito de disparo hoje.
- **Viagem (até o quadro 96):** anda 5 px por quadro (300 px/s). Termina no quadro do acerto, ou ao completar 1,6 s (96 quadros).
- **Impacto (1 quadro):** o projétil some. O inimigo pisca por 0,08 s (5 quadros) e sai o número do dano. Não há efeito próprio de impacto.
- **Fim:** nada mais na tela.
- **Giro:** não existe hoje. O desenho segue a direção do voo, sem girar.
- **Sprite:** hoje, o desenho genérico tem rastro de 9 px, linha branca de 6 px e brilho de 14×14 px, na cor da arma. Sprite previsto no pacote: 24×24 px, 4 quadros de giro.
