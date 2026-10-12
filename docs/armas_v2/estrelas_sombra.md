# Estrelas de Sombra (estrelas_sombra)
**Tipo:** projétil. **Ícone:** icone_u_kunai_corvo.
**O que faz:** Atira estrelas pretas bem seguidas no inimigo mais perto, sem parar. Cada estrela faz pouco dano, mas o número de estrelas cresce.
**Na prática:**
- Alcance para escolher o alvo: 180 px. A estrela voa até 1,6 s (cerca de 640 px).
- Dano: 4 por estrela. Recarga: 0,9 s. Balas: 1 por disparo.
- Alvo: o inimigo mais perto dentro de 180 px. Acerta o primeiro inimigo que cruzar o caminho.
- Não perfura e não explode.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base): 4 de dano, recarga 0,9 s, 1 estrela. |
| 2 | +1 estrela: 2 estrelas por disparo. |
| 3 | +1 de dano e mais rápidas: 5 de dano, recarga 0,8 s. |
| 4 | +1 estrela: 3 estrelas por disparo. |
| 5 | +3 de dano e 4ª estrela: 8 de dano, 4 estrelas por disparo. Lendário sobe 2 níveis de uma vez. Acumulado no nível 5: 4 estrelas, 8 de dano, recarga 0,8 s, alcance 180 px. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** **Tempestade de Aço**: Estrelas de Sombra nível 3 + Adagas Voadoras nível 3. Consome as duas. Mesma proposta da Adaga Voadora.

**Animação e efeitos:**
- Hoje (placeholder): rastro de 4 px, meio transparente, na cor da arma; um risco branco de 1,5 px; e um brilho de 14 px. A estrela não gira. No impacto, não há clarão próprio.
- Especificação do campo "arte": shuriken preta de quatro pontas, girando rápido no ar em direção ao inimigo. Rastro curto cinza-escuro. No impacto, um pequeno clarão cinza. Cores: preto, cinza-escuro, cinza-claro. Tamanho: shuriken de 8x8 px; impacto de 10 px. Duração do impacto: 0,15 s.

**Mudanças em relação ao desenho original:** Trajetória corrigida na ficha: a estrela não para no último ponto de mira; voa até acertar ou até 1,6 s. O desenho segue o PR #192.

**Pontos de atenção:**
- As estrelas que já saíram seguem reto até acertar um inimigo ou até 1,6 s, mesmo que o alvo morra. Não param no ponto de mira. Podem acertar outro inimigo no caminho, mas só dentro de 340 px do herói.
- Com 4 estrelas no nível 5, a abertura do leque é de cerca de 24 graus (de um lado ao outro, 12 para cada lado). Confirmar se é o visual que se quer.
- O texto "provisorio" do JSON (quadrado girando e risco cinza) não bate com o desenho atual (sem giro). Ajustar um dos dois.
- O campo "arte" é só documentação: o código não o lê.
- O pool de projéteis tem 48 vagas e é dividido por todas as armas novas. Com 4 estrelas por disparo e recarga curta, o pool pode encher e descartar estrelas sem aviso.

## Esquemática
- **Gatilho:** a cada recarga: 0,9 s no nível 1 e 0,8 s no nível 5. A recarga é dividida por m_vel_ataque (1,0 por padrão). Sem inimigo a 340 px do herói, espera 0,3 s e não gasta a recarga. Com inimigo a 340 px, mas nenhum dentro do alcance de alvo, a recarga é gasta e nada sai.
- **Alvo:** o inimigo vivo mais perto dentro de 180 px, medido no plano achatado (y ÷ 0,62), na hora do disparo. Sem mira antecipada.
- **Trajetória e alcance:** sai 14 px acima do herói, em linha reta para a posição do alvo no momento do disparo. Velocidade 400 px/s; voa até 1,6 s, ou seja, até 640 px, ou até acertar. Não para no alcance nem no alvo, e não faz curva. Só acerta inimigos a até 340 px do herói (a lista de perto). Leque: 8° entre disparos vizinhos; com 4 disparos (nível 5), a abertura total é de 24°, com o primeiro e o último nas pontas.
- **Área:** pontual. O acerto conta um círculo de 10 px mais o raio do inimigo, no plano achatado (y ÷ 0,62). Não há área.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 4 | (base). Fica: 1 estrela, recarga 0,9 s. |
| 2 | 4 | +1 estrela. Fica: 2 estrelas, recarga 0,9 s. |
| 3 | 5 | +1 de dano, mais rápidas. Fica: 2 estrelas, recarga 0,8 s. |
| 4 | 5 | +1 estrela. Fica: 3 estrelas, recarga 0,8 s. |
| 5 | 8 | +3 de dano, 4ª estrela. Fica: 4 estrelas, recarga 0,8 s. |

Dano = (base + soma dos níveis) × (1 + bônus acumulado). Cada carta do golpe soma o bonus_arma da sua raridade (raro +18%, épico +40%, lendário +80%), então com raro a tabela vai por 1,18; épico 1,40; lendário 1,80 (e mais, se houver mais cartas dessa arma). A tabela é a comum (bônus 0). m_dano é 1,0 por padrão; ele sobe com a meta (bônus de dano) e com cartas de atributo de dano; a tabela usa 1,0. Carta lendária sobe 2 níveis de uma vez; num golpe novo, entra direto no nível 2.
- **Como aplica:** uma vez por inimigo e por projétil. Cada ponto de perfura soma 1 inimigo atingido (perfura N acerta N+1 inimigos). Sem perfura, o projétil some no primeiro acerto.
- **Efeitos de status:** acerto: empurrão de 40 px (dividido pelo peso do inimigo) e atordoamento de 0,1 s (multiplicado pelo fator de atordoamento do inimigo; chefe não atordoa). Sem lentidão, sem queimadura e sem explosão.
- **Limites na tela:** Pool de 48 compartilhado com nuvem, anel, meteoro e aliado (armas novas). Se o pool estiver cheio, o tiro é descartado sem aviso, e o resto do leque também. Esta arma: até 2 ao mesmo tempo no nível 1 e até 8 no nível 5 (4 por disparo a cada 0,8 s, com 1,6 s de voo).
- **Sequência de animação (quadro a quadro, a 60 fps):**
- **Disparo (quadro 0):** o projétil nasce 14 px acima do herói. Não há efeito de disparo hoje.
- **Viagem (até o quadro 96):** anda 6,7 px por quadro (400 px/s). Termina no quadro do acerto, ou ao completar 1,6 s (96 quadros).
- **Impacto (1 quadro):** o projétil some. O inimigo pisca por 0,08 s (5 quadros) e sai o número do dano. Não há efeito próprio de impacto.
- **Fim:** nada mais na tela.
- **Giro:** não existe hoje. O desenho segue a direção do voo, sem girar.
- **Sprite:** hoje, o desenho genérico tem rastro de 9 px, linha branca de 6 px e brilho de 14×14 px, na cor da arma. Sprite previsto no pacote: 12×12 px, 4 quadros de giro.
