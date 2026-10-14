# Raio Solar (raio_solar)
**Tipo:** projétil. **Ícone:** icone_u_estrela_matutina.
**O que faz:** Dispara um feixe dourado, muito rápido e de longe, no inimigo mais perto. O feixe vai reto e pode atravessar inimigos.
**Na prática:**
- Alcance para escolher o alvo: 300 px, o maior do lote. O feixe é o mais rápido e voa até 1,6 s (cerca de 1.120 px).
- Dano: 12 por feixe. Recarga: 1,4 s. Balas: 1 por disparo.
- Alvo: o inimigo mais perto dentro de 300 px. Acerta o primeiro inimigo que cruzar o caminho, não só o alvo.
- No nível 1 não perfura: para no primeiro inimigo. Não tem explosão.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base): 12 de dano, recarga 1,4 s, 1 feixe. |
| 2 | Perfura 1 inimigo: atravessa um e para no próximo. |
| 3 | +4 de dano: 16 por feixe. |
| 4 | +1 feixe e recarga menor: 2 feixes, recarga 1,2 s. |
| 5 | +5 de dano e perfura mais: 21 de dano, perfura 2. Lendário sobe 2 níveis de uma vez. Acumulado no nível 5: 2 feixes, 21 de dano, recarga 1,2 s, perfura 2 (atravessa dois e pode acertar até três). |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** **Lança do Amanhecer**: Raio Solar nível 3 + Lança de Geada nível 3. Consome as duas. Ideia: um feixe de sol que sai com gelo e atravessa.
Obs.: a Lança de Geada também aparece na proposta **Disco de Gelo**. Escolher uma das duas.

**Animação e efeitos:**
- Hoje (placeholder): um rastro dourado de 4 px, meio transparente, atrás do feixe; um risco branco de 1,5 px; e um brilho de 14 px. O rastro é curto, de 9 px, e não tem o comprimento do feixe da arte. Não há brilho especial ao atravessar nem cruz no impacto.
- Especificação do campo "arte": feixe dourado fino e reto, que sai do herói em direção ao inimigo. Ao atravessar um inimigo, continua o caminho com um brilho de sol. No impacto, um flash dourado em cruz. Cores: dourado, amarelo-claro, branco. Tamanho: feixe de 40x3 px; impacto de 18 px. Duração do impacto: 0,15 s.

**Mudanças em relação ao desenho original:** Nenhum número mudou. Alcance de acerto limitado a 340 px do herói (a ficha dizia que o feixe podia acertar algo bem longe).

**Pontos de atenção:**
- O feixe da arte tem 40 px de comprimento, mas o placeholder desenha só 9 px. Para a arte ficar certa, o rastro precisa ser maior. Isso só muda o desenho, não o dano.
- O brilho ao atravessar e a cruz no impacto não estão no código.
- O texto "provisorio" do JSON (linha de 3 px e cruz de 18 px) não bate com o desenho atual. Ajustar um dos dois.
- O campo "arte" é só documentação: o código não o lê.
- O feixe só acerta inimigos a até 340 px do herói (lista de perto), mesmo com voo de 1.120 px. Fora disso, ele passa sem acertar.
- O pool de projéteis tem 48 vagas e é compartilhado: se estiver cheio, o feixe é descartado sem aviso.

## Esquemática
- **Gatilho:** a cada recarga: 1,4 s no nível 1 e 1,2 s no nível 5. A recarga é dividida por m_vel_ataque (1,0 por padrão). Sem inimigo a 340 px do herói, espera 0,3 s e não gasta a recarga. Com inimigo a 340 px, mas nenhum dentro do alcance de alvo, a recarga é gasta e nada sai.
- **Alvo:** o inimigo vivo mais perto dentro de 300 px, medido no plano achatado (y ÷ 0,62), na hora do disparo. Sem mira antecipada.
- **Trajetória e alcance:** sai 14 px acima do herói, em linha reta para a posição do alvo no momento do disparo. Velocidade 700 px/s; voa até 1,6 s, ou seja, até 1120 px, ou até acertar. Não para no alcance nem no alvo, e não faz curva. Só acerta inimigos a até 340 px do herói (a lista de perto). Leque: 8° entre disparos vizinhos; com 2 disparos (nível 5), a abertura total é de 8°, com o primeiro e o último nas pontas.
- **Área:** pontual. O acerto conta um círculo de 10 px mais o raio do inimigo, no plano achatado (y ÷ 0,62). Não há área.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 12 | (base). Fica: 1 feixe, recarga 1,4 s. |
| 2 | 12 | perfura 1 inimigo. Fica: 1 feixe, recarga 1,4 s, perfura 1. |
| 3 | 16 | +4 de dano. Fica: 1 feixe, recarga 1,4 s, perfura 1. |
| 4 | 16 | +1 feixe e recarga menor. Fica: 2 feixes, recarga 1,2 s, perfura 1. |
| 5 | 21 | +5 de dano, perfura mais. Fica: 2 feixes, recarga 1,2 s, perfura 2. |

Dano = (base + soma dos níveis) × (1 + bônus acumulado). Cada carta do golpe soma o bonus_arma da sua raridade (raro +18%, épico +40%, lendário +80%), então com raro a tabela vai por 1,18; épico 1,40; lendário 1,80 (e mais, se houver mais cartas dessa arma). A tabela é a comum (bônus 0). m_dano é 1,0 por padrão; ele sobe com a meta (bônus de dano) e com cartas de atributo de dano; a tabela usa 1,0. Carta lendária sobe 2 níveis de uma vez; num golpe novo, entra direto no nível 2.
- **Como aplica:** uma vez por inimigo e por projétil. Cada ponto de perfura soma 1 inimigo atingido (perfura N acerta N+1 inimigos). Sem perfura, o projétil some no primeiro acerto.
- **Efeitos de status:** acerto: empurrão de 40 px (dividido pelo peso do inimigo) e atordoamento de 0,1 s (multiplicado pelo fator de atordoamento do inimigo; chefe não atordoa). Sem lentidão, sem queimadura e sem explosão.
- **Limites na tela:** Pool de 48 compartilhado com nuvem, anel, meteoro e aliado (armas novas). Se o pool estiver cheio, o tiro é descartado sem aviso, e o resto do leque também. Esta arma: até 2 ao mesmo tempo no nível 1 e até 4 no nível 5 (2 por disparo a cada 1,2 s, com 1,6 s de voo).
- **Sequência de animação (quadro a quadro, a 60 fps):**
- **Disparo (quadro 0):** o projétil nasce 14 px acima do herói. Não há efeito de disparo hoje.
- **Viagem (até o quadro 96):** anda 11,7 px por quadro (700 px/s). Termina no quadro do acerto, ou ao completar 1,6 s (96 quadros).
- **Impacto (1 quadro):** o projétil some. O inimigo pisca por 0,08 s (5 quadros) e sai o número do dano. Não há efeito próprio de impacto.
- **Fim:** nada mais na tela.
- **Giro:** não há giro: o feixe é uma linha reta.
- **Sprite:** hoje, o desenho genérico tem rastro de 9 px, linha branca de 6 px e brilho de 14×14 px, na cor da arma. Sprite previsto no pacote: 48×8 px, 1 quadro.
