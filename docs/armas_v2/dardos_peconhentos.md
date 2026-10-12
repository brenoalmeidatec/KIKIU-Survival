# Dardos Peçonhentos (dardos_peconhentos)
**Tipo:** projétil. **Ícone:** icone_u_dardo_primitivo.
**O que faz:** Atira dardos verdes de dano baixo no inimigo mais perto, bem seguidos. O nome sugere veneno, mas hoje o dano é direto, sem veneno.
**Na prática:**
- Alcance para escolher o alvo: 200 px. O dardo voa até 1,6 s (cerca de 580 px).
- Dano: 5 por dardo. Recarga: 0,9 s. Balas: 1 por disparo.
- Alvo: o inimigo mais perto dentro de 200 px. Acerta o primeiro inimigo que cruzar o caminho.
- Não perfura e não explode.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base): 5 de dano, recarga 0,9 s, 1 dardo. |
| 2 | +2 de dano: 7 por dardo. |
| 3 | Dardo mais rápido: recarga 0,8 s. |
| 4 | +1 dardo: 2 dardos por disparo. |
| 5 | +3 de dano e mais rápidos: 10 de dano, recarga 0,7 s. Lendário sobe 2 níveis de uma vez. Acumulado no nível 5: 2 dardos, 10 de dano, recarga 0,7 s, alcance 200 px. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** **Flechas Envenenadas**: Dardos Peçonhentos nível 3 + Flechas Sombrias nível 3. Consome as duas. A mesma proposta da Flecha Sombria. Ideia: o veneno vem daqui.

**Animação e efeitos:**
- Hoje (placeholder): rastro verde de 4 px, meio transparente, na cor da arma; risco branco de 1,5 px; brilho de 14 px. Não há gotas e não há nuvem no impacto.
- Especificação do campo "arte": dardo curto verde-limão com ponta escura, que voa reto e pinga gotas verdes no rastro. No impacto, uma pequena nuvem verde de veneno que some rápido. Cores: verde-limão, verde-escuro, preto. Tamanho: dardo de 8x2 px; impacto de 12 px. Duração do impacto: 0,2 s.

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- Veneno não existe hoje nesta arma. Se a ideia é veneno de verdade, precisa de regra nova: por exemplo, dano ao longo do tempo, como a queima da Aura de Fogo. Sem isso, o nome engana.
- As gotas e a nuvem da arte não estão no código.
- O texto "provisorio" do JSON (2 gotas e círculo de 12 px) não bate com o desenho atual. Ajustar um dos dois.
- O campo "arte" é só documentação: o código não o lê.
- Com recarga de 0,9 s e dano baixo, o pool de projéteis (48 vagas, compartilhado) é o que mais enche. Dardos podem ser descartados sem aviso quando houver muitas armas ativas.

## Esquemática
- **Gatilho:** a cada recarga: 0,9 s no nível 1 e 0,7 s no nível 5. A recarga é dividida por m_vel_ataque (1,0 por padrão). Sem inimigo a 340 px do herói, espera 0,3 s e não gasta a recarga. Com inimigo a 340 px, mas nenhum dentro do alcance de alvo, a recarga é gasta e nada sai.
- **Alvo:** o inimigo vivo mais perto dentro de 200 px, medido no plano achatado (y ÷ 0,62), na hora do disparo. Sem mira antecipada.
- **Trajetória e alcance:** sai 14 px acima do herói, em linha reta para a posição do alvo no momento do disparo. Velocidade 360 px/s; voa até 1,6 s, ou seja, até 576 px, ou até acertar. Não para no alcance nem no alvo, e não faz curva. Só acerta inimigos a até 340 px do herói (a lista de perto). Leque: 8° entre disparos vizinhos; com 2 disparos (nível 5), a abertura total é de 8°, com o primeiro e o último nas pontas.
- **Área:** pontual. O acerto conta um círculo de 10 px mais o raio do inimigo, no plano achatado (y ÷ 0,62). Não há área.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 5 | (base). Fica: 1 dardo, recarga 0,9 s. |
| 2 | 7 | +2 de dano. Fica: 1 dardo, recarga 0,9 s. |
| 3 | 7 | dardo mais rápido. Fica: 1 dardo, recarga 0,8 s. |
| 4 | 7 | +1 dardo. Fica: 2 dardos, recarga 0,8 s. |
| 5 | 10 | +3 de dano, mais rápidos. Fica: 2 dardos, recarga 0,7 s. |

Dano = (base + soma dos níveis) × (1 + bônus acumulado). Cada carta do golpe soma o bonus_arma da sua raridade (raro +18%, épico +40%, lendário +80%), então com raro a tabela vai por 1,18; épico 1,40; lendário 1,80 (e mais, se houver mais cartas dessa arma). A tabela é a comum (bônus 0). m_dano é 1,0 por padrão; ele sobe com a meta (bônus de dano) e com cartas de atributo de dano; a tabela usa 1,0. Carta lendária sobe 2 níveis de uma vez; num golpe novo, entra direto no nível 2.
- **Como aplica:** uma vez por inimigo e por projétil. Cada ponto de perfura soma 1 inimigo atingido (perfura N acerta N+1 inimigos). Sem perfura, o projétil some no primeiro acerto.
- **Efeitos de status:** acerto: empurrão de 40 px (dividido pelo peso do inimigo) e atordoamento de 0,1 s (multiplicado pelo fator de atordoamento do inimigo; chefe não atordoa). Sem lentidão, sem queimadura e sem explosão.
- **Limites na tela:** Pool de 48 compartilhado com nuvem, anel, meteoro e aliado (armas novas). Se o pool estiver cheio, o tiro é descartado sem aviso, e o resto do leque também. Esta arma: até 2 ao mesmo tempo no nível 1 e até 6 no nível 5 (2 por disparo a cada 0,7 s, com 1,6 s de voo).
- **Sequência de animação (quadro a quadro, a 60 fps):**
- **Disparo (quadro 0):** o projétil nasce 14 px acima do herói. Não há efeito de disparo hoje.
- **Viagem (até o quadro 96):** anda 6 px por quadro (360 px/s). Termina no quadro do acerto, ou ao completar 1,6 s (96 quadros).
- **Impacto (1 quadro):** o projétil some. O inimigo pisca por 0,08 s (5 quadros) e sai o número do dano. Não há efeito próprio de impacto.
- **Fim:** nada mais na tela.
- **Giro:** não existe hoje. O desenho segue a direção do voo, sem girar.
- **Sprite:** hoje, o desenho genérico tem rastro de 9 px, linha branca de 6 px e brilho de 14×14 px, na cor da arma. Sprite previsto no pacote: 16×16 px, 1 quadro.
