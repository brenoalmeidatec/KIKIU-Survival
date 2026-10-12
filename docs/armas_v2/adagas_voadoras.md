# Adagas Voadoras (adagas_voadoras)
**Tipo:** projétil. **Ícone:** icone_u_adaga_sombria.
**O que faz:** Atira adagas de aço em leque curto no inimigo mais perto, sem parar. É a arma de tiro rápido de curto alcance.
**Na prática:**
- Alcance para escolher o alvo: 150 px, o menor do lote. A adaga voa até 1,6 s (cerca de 610 px).
- Dano: 7 por adaga. Recarga: 1,2 s. Balas: 2 por disparo, em leque de cerca de 8 graus.
- Alvo: o inimigo mais perto dentro de 150 px. Acerta o primeiro inimigo que cruzar o caminho.
- Não perfura e não explode.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base): 7 de dano, recarga 1,2 s, 2 adagas. |
| 2 | +2 de dano: 9 por adaga. |
| 3 | +1 adaga: 3 adagas por disparo. |
| 4 | +30 de alcance: alcance para escolher o alvo sobe para 180 px. |
| 5 | +3 de dano e mais rápida: 12 de dano, recarga 1,0 s. Lendário sobe 2 níveis de uma vez. Acumulado no nível 5: 3 adagas, 12 de dano, recarga 1,0 s, alcance 180 px. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** **Tempestade de Aço**: Adagas Voadoras nível 3 + Estrelas de Sombra nível 3. Consome as duas. Ideia: as duas armas de lâmina juntas, com chuva de aço em área curta.

**Animação e efeitos:**
- Hoje (placeholder): mesmo desenho das outras armas de projétil. Um rastro de 4 px, meio transparente, na cor da arma; um risco branco de 1,5 px; e um brilho de 14 px. A adaga não gira: o desenho segue a direção do voo. Sem faísca própria no impacto.
- Especificação do campo "arte": adaga de aço cinza-claro que gira no ar sobre o próprio eixo, com brilho metálico no giro. Duas saem juntas em leque curto. No impacto, uma faísca branca. Cores: aço cinza-claro, branco, cinza-azulado. Tamanho: adaga de 10x4 px; impacto de 12 px. Duração do impacto: 0,2 s.

**Mudanças em relação ao desenho original:** Leque de 3 adagas corrigido na ficha: de 8 para 16 graus no total (o código abre 8 graus entre adagas vizinhas). O desenho segue o PR #192.

**Pontos de atenção:**
- Ponto mais sensível do lote: com alcance de 150 px, se o inimigo mais perto estiver entre 150 px e 340 px, a arma gasta a recarga e não atira. Pode ser preciso aumentar o alcance base ou a faixa de busca.
- O texto "provisorio" do JSON (losango girando) não existe no código: não há giro nem losango. Ajustar o JSON ou o código.
- O campo "arte" é só documentação: o código não o lê.
- As 3 adagas (a partir do nível 3) abrem em leque de 16 graus no total, com 8 graus entre uma adaga e a vizinha. O pool de projéteis tem 48 vagas para todas as armas novas; se estiver cheio, a adaga é descartada sem aviso.

## Esquemática
- **Gatilho:** a cada recarga: 1,2 s no nível 1 e 1 s no nível 5. A recarga é dividida por m_vel_ataque (1,0 por padrão). Sem inimigo a 340 px do herói, espera 0,3 s e não gasta a recarga. Com inimigo a 340 px, mas nenhum dentro do alcance de alvo, a recarga é gasta e nada sai.
- **Alvo:** o inimigo vivo mais perto dentro de 150 px no nível 1 (sobe para 180 px no nível 4), medido no plano achatado (y ÷ 0,62), na hora do disparo. Sem mira antecipada.
- **Trajetória e alcance:** sai 14 px acima do herói, em linha reta para a posição do alvo no momento do disparo. Velocidade 380 px/s; voa até 1,6 s, ou seja, até 608 px, ou até acertar. Não para no alcance nem no alvo, e não faz curva. Só acerta inimigos a até 340 px do herói (a lista de perto). Leque: 8° entre disparos vizinhos; com 3 disparos (nível 5), a abertura total é de 16°, com o primeiro e o último nas pontas.
- **Área:** pontual. O acerto conta um círculo de 10 px mais o raio do inimigo, no plano achatado (y ÷ 0,62). Não há área.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 7 | (base). Fica: 2 adagas, recarga 1,2 s. |
| 2 | 9 | +2 de dano. Fica: 2 adagas, recarga 1,2 s. |
| 3 | 9 | +1 adaga. Fica: 3 adagas, recarga 1,2 s. |
| 4 | 9 | +30 de alcance. Fica: 3 adagas, recarga 1,2 s, alcance 180 px. |
| 5 | 12 | +3 de dano e mais rápido. Fica: 3 adagas, recarga 1 s. |

Dano = (base + soma dos níveis) × (1 + bônus acumulado). Cada carta do golpe soma o bonus_arma da sua raridade (raro +18%, épico +40%, lendário +80%), então com raro a tabela vai por 1,18; épico 1,40; lendário 1,80 (e mais, se houver mais cartas dessa arma). A tabela é a comum (bônus 0). m_dano é 1,0 por padrão; ele sobe com a meta (bônus de dano) e com cartas de atributo de dano; a tabela usa 1,0. Carta lendária sobe 2 níveis de uma vez; num golpe novo, entra direto no nível 2.
- **Como aplica:** uma vez por inimigo e por projétil. Cada ponto de perfura soma 1 inimigo atingido (perfura N acerta N+1 inimigos). Sem perfura, o projétil some no primeiro acerto.
- **Efeitos de status:** acerto: empurrão de 40 px (dividido pelo peso do inimigo) e atordoamento de 0,1 s (multiplicado pelo fator de atordoamento do inimigo; chefe não atordoa). Sem lentidão, sem queimadura e sem explosão.
- **Limites na tela:** Pool de 48 compartilhado com nuvem, anel, meteoro e aliado (armas novas). Se o pool estiver cheio, o tiro é descartado sem aviso, e o resto do leque também. Esta arma: até 4 ao mesmo tempo no nível 1 e até 6 no nível 5 (3 por disparo a cada 1 s, com 1,6 s de voo).
- **Sequência de animação (quadro a quadro, a 60 fps):**
- **Disparo (quadro 0):** o projétil nasce 14 px acima do herói. Não há efeito de disparo hoje.
- **Viagem (até o quadro 96):** anda 6,3 px por quadro (380 px/s). Termina no quadro do acerto, ou ao completar 1,6 s (96 quadros).
- **Impacto (1 quadro):** o projétil some. O inimigo pisca por 0,08 s (5 quadros) e sai o número do dano. Não há efeito próprio de impacto.
- **Fim:** nada mais na tela.
- **Giro:** não existe hoje. O desenho segue a direção do voo, sem girar.
- **Sprite:** hoje, o desenho genérico tem rastro de 9 px, linha branca de 6 px e brilho de 14×14 px, na cor da arma. Sprite previsto no pacote: 16×16 px, 4 quadros de giro.
