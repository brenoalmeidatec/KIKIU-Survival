# Bumerangue de Ferro (bumerangue_ferro)
**Tipo:** projétil. **Ícone:** icone_u_disco_cortante.
**O que faz:** Lança um disco de ferro no inimigo mais perto. O disco atravessa inimigos e, na descrição, volta para o herói. Hoje ele não volta.
**Na prática:**
- Alcance para escolher o alvo: 230 px. O disco voa até 1,6 s (cerca de 510 px).
- Dano: 13 por acerto. Recarga: 2,2 s. Balas: 1 por disparo.
- Alvo: o inimigo mais perto dentro de 230 px. Atravessa inimigos no caminho.
- Perfura 2 no nível 1: passa por dois inimigos e para no terceiro. Ou seja, acerta 3 inimigos, não 2 como diz a descrição.
- Não tem explosão.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base): 13 de dano, recarga 2,2 s, 1 disco, perfura 2 (acerta até 3). |
| 2 | +4 de dano: 17 por acerto. |
| 3 | +1 bumerangue: 2 discos por disparo. |
| 4 | Perfura mais 1 inimigo: perfura 3 (acerta até 4). |
| 5 | +5 de dano e volta rápido: 22 de dano, recarga 1,9 s. Lendário sobe 2 níveis de uma vez. Acumulado no nível 5: 2 discos, 22 de dano, recarga 1,9 s, perfura 3. |

Obs.: o "volta rápido" do nível 5 só mexe na recarga. Não há volta no código.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** **Disco de Gelo**: Bumerangue de Ferro nível 3 + Lança de Geada nível 3. Consome as duas. Ideia: o disco sai coberto de gelo e, ao voltar, congela quem toca de novo.
Obs.: a Lança de Geada também aparece na proposta **Lança do Amanhecer**. Escolher uma das duas.

**Animação e efeitos:**
- Hoje (placeholder): mesmo desenho das outras armas de projétil: rastro de 4 px, risco branco de 1,5 px e brilho de 14 px. Não gira, não volta e não tem faísca no impacto.
- Especificação do campo "arte": disco de ferro ferrugento, que gira no próprio eixo e corta o ar em arco de ida. Ao acertar, risca faíscas laranja. Depois, a mesma peça volta girando no sentido contrário. Cores: ferrugem, cinza-ferro, laranja. Tamanho: disco de 16 px de diâmetro; impacto de 16 px. Duração do impacto: 0,2 s.

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- A volta do disco não existe no código. A descrição e a arte dizem que ele volta; hoje ele some no fim do voo. Precisa de código novo (por exemplo, uma segunda passada no sentido contrário, com a lista de acertados zerada), ou a descrição muda.
- O número de acertos não bate com a descrição: a descrição diz "atravessa dois inimigos" e o código acerta três. Decidir qual está certo.
- O giro e as faíscas da arte não estão no placeholder.
- O texto "provisorio" do JSON (círculo girando e 3 faíscas) não bate com o desenho atual. Ajustar um dos dois.
- O campo "arte" é só documentação: o código não o lê.
- O pool de projéteis tem 48 vagas e é compartilhado: se estiver cheio, o disco é descartado sem aviso.

## Esquemática
- **Gatilho:** a cada recarga: 2,2 s no nível 1 e 1,9 s no nível 5. A recarga é dividida por m_vel_ataque (1,0 por padrão). Sem inimigo a 340 px do herói, espera 0,3 s e não gasta a recarga. Com inimigo a 340 px, mas nenhum dentro do alcance de alvo, a recarga é gasta e nada sai.
- **Alvo:** o inimigo vivo mais perto dentro de 230 px, medido no plano achatado (y ÷ 0,62), na hora do disparo. Sem mira antecipada.
- **Trajetória e alcance:** sai 14 px acima do herói, em linha reta para a posição do alvo no momento do disparo. Velocidade 320 px/s; voa até 1,6 s, ou seja, até 512 px, ou até acertar. Não para no alcance nem no alvo, e não faz curva. Só acerta inimigos a até 340 px do herói (a lista de perto). Leque: 8° entre disparos vizinhos; com 2 disparos (nível 5), a abertura total é de 8°, com o primeiro e o último nas pontas.
- **Área:** pontual. O acerto conta um círculo de 10 px mais o raio do inimigo, no plano achatado (y ÷ 0,62). Não há área.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 13 | (base). Fica: 1 disco, recarga 2,2 s, perfura 2. |
| 2 | 17 | +4 de dano. Fica: 1 disco, recarga 2,2 s, perfura 2. |
| 3 | 17 | +1 bumerangue. Fica: 2 discos, recarga 2,2 s, perfura 2. |
| 4 | 17 | perfura mais 1 inimigo. Fica: 2 discos, recarga 2,2 s, perfura 3. |
| 5 | 22 | +5 de dano, volta rápido. Fica: 2 discos, recarga 1,9 s, perfura 3. |

Dano = (base + soma dos níveis) × (1 + bônus acumulado). Cada carta do golpe soma o bonus_arma da sua raridade (raro +18%, épico +40%, lendário +80%), então com raro a tabela vai por 1,18; épico 1,40; lendário 1,80 (e mais, se houver mais cartas dessa arma). A tabela é a comum (bônus 0). m_dano é 1,0 por padrão; ele sobe com a meta (bônus de dano) e com cartas de atributo de dano; a tabela usa 1,0. Carta lendária sobe 2 níveis de uma vez; num golpe novo, entra direto no nível 2.
- **Como aplica:** uma vez por inimigo e por projétil. Cada ponto de perfura soma 1 inimigo atingido (perfura N acerta N+1 inimigos). Sem perfura, o projétil some no primeiro acerto. A volta não existe: o disco some no fim do voo, sem segunda passada.
- **Efeitos de status:** acerto: empurrão de 40 px (dividido pelo peso do inimigo) e atordoamento de 0,1 s (multiplicado pelo fator de atordoamento do inimigo; chefe não atordoa). Sem lentidão, sem queimadura e sem explosão.
- **Limites na tela:** Pool de 48 compartilhado com nuvem, anel, meteoro e aliado (armas novas). Se o pool estiver cheio, o tiro é descartado sem aviso, e o resto do leque também. Esta arma: até 1 ao mesmo tempo no nível 1 e até 2 no nível 5 (2 por disparo a cada 1,9 s, com 1,6 s de voo).
- **Sequência de animação (quadro a quadro, a 60 fps):**
- **Disparo (quadro 0):** o projétil nasce 14 px acima do herói. Não há efeito de disparo hoje.
- **Viagem (até o quadro 96):** anda 5,3 px por quadro (320 px/s). Termina no quadro do acerto, ou ao completar 1,6 s (96 quadros).
- **Impacto (1 quadro):** o projétil some. O inimigo pisca por 0,08 s (5 quadros) e sai o número do dano. Não há efeito próprio de impacto.
- **Fim:** nada mais na tela.
- **Giro:** não existe hoje. O disco não gira no código.
- **Sprite:** hoje, o desenho genérico tem rastro de 9 px, linha branca de 6 px e brilho de 14×14 px, na cor da arma. Sprite previsto no pacote: 16×16 px, 4 quadros de giro.
