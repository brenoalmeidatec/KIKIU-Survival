# Flechas Sombrias (flechas_sombrias)
**Tipo:** projétil. **Ícone:** icone_u_arco_sussurro.
**O que faz:** Dispara flechas roxas e rápidas no inimigo mais perto, em linha reta. Cada flecha some ao acertar, a não ser que perfure.
**Na prática:**
- Alcance para escolher o alvo: 220 px. A flecha voa até 1,6 s (cerca de 670 px) e não para no alcance.
- Dano: 8 por flecha. Recarga: 1,8 s. Balas: 1 por disparo.
- Alvo: o inimigo mais perto dentro de 220 px. A flecha não faz mira antecipada e acerta o primeiro inimigo que cruzar o caminho.
- Não perfura no nível 1: para no primeiro inimigo. Não tem explosão.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base): 8 de dano, recarga 1,8 s, 1 flecha. |
| 2 | +1 flecha: 2 flechas por disparo, em leque curto. |
| 3 | +3 de dano: 11 por flecha. |
| 4 | Perfura 1 inimigo: atravessa um e para no próximo. |
| 5 | +5 de dano e mais rápida: 16 de dano, recarga 1,5 s. Lendário sobe 2 níveis de uma vez. Acumulado no nível 5: 2 flechas, 16 de dano, recarga 1,5 s, perfura 1. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** **Flechas Envenenadas**: Flechas Sombrias nível 3 + Dardos Peçonhentos nível 3. Consome as duas. Ideia: a flecha que acerta deixa veneno no inimigo.

**Animação e efeitos:**
- Hoje (placeholder): um rastro roxo de 4 px, meio transparente, atrás da flecha; um risco branco fino de 1,5 px; e um brilho roxo de 14 px na ponta. O impacto não tem efeito próprio: aparece o efeito de dano padrão, na cor da arma.
- Especificação do campo "arte" (para o Alisson substituir): flecha roxo-escura de ponta afiada, com rastro fino de fumaça escura, voando em linha reta. No impacto, um pequeno estalo de sombra roxa. Cores: roxo escuro, lilás, preto. Tamanho: projétil de 12x3 px; impacto de 14 px. Duração do impacto: 0,2 s.

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- O texto "provisorio" do JSON (linha de 2 px e círculo de 14 px) não bate com o que o código desenha (rastro de 4 px, risco de 1,5 px, brilho de 14 px). Ajustar um dos dois.
- O campo "arte" é só documentação: o código não o lê.
- Se o inimigo mais perto estiver entre 220 px e 340 px, a recarga corre e nenhuma flecha sai. O mesmo vale para as outras armas de projétil.
- As duas flechas saem com 8 graus de abertura entre elas. O pool de projéteis tem 48 vagas para todas as armas novas; se estiver cheio, a flecha é descartada sem aviso.

## Esquemática
- **Gatilho:** a cada recarga: 1,8 s no nível 1 e 1,5 s no nível 5. A recarga é dividida por m_vel_ataque (1,0 por padrão). Sem inimigo a 340 px do herói, espera 0,3 s e não gasta a recarga. Com inimigo a 340 px, mas nenhum dentro do alcance de alvo, a recarga é gasta e nada sai.
- **Alvo:** o inimigo vivo mais perto dentro de 220 px, medido no plano achatado (y ÷ 0,62), na hora do disparo. Sem mira antecipada.
- **Trajetória e alcance:** sai 14 px acima do herói, em linha reta para a posição do alvo no momento do disparo. Velocidade 420 px/s; voa até 1,6 s, ou seja, até 672 px, ou até acertar. Não para no alcance nem no alvo, e não faz curva. Só acerta inimigos a até 340 px do herói (a lista de perto). Leque: 8° entre disparos vizinhos; com 2 disparos (nível 5), a abertura total é de 8°, com o primeiro e o último nas pontas.
- **Área:** pontual. O acerto conta um círculo de 10 px mais o raio do inimigo, no plano achatado (y ÷ 0,62). Não há área.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 8 | (base). Fica: 1 flecha, recarga 1,8 s. |
| 2 | 8 | +1 flecha. Fica: 2 flechas, recarga 1,8 s. |
| 3 | 11 | +3 de dano. Fica: 2 flechas, recarga 1,8 s. |
| 4 | 11 | perfura 1 inimigo. Fica: 2 flechas, recarga 1,8 s, perfura 1. |
| 5 | 16 | +5 de dano e mais rápida. Fica: 2 flechas, recarga 1,5 s, perfura 1. |

Dano = (base + soma dos níveis) × (1 + bônus acumulado). Cada carta do golpe soma o bonus_arma da sua raridade (raro +18%, épico +40%, lendário +80%), então com raro a tabela vai por 1,18; épico 1,40; lendário 1,80 (e mais, se houver mais cartas dessa arma). A tabela é a comum (bônus 0). m_dano é 1,0 por padrão; ele sobe com a meta (bônus de dano) e com cartas de atributo de dano; a tabela usa 1,0. Carta lendária sobe 2 níveis de uma vez; num golpe novo, entra direto no nível 2.
- **Como aplica:** uma vez por inimigo e por projétil. Cada ponto de perfura soma 1 inimigo atingido (perfura N acerta N+1 inimigos). Sem perfura, o projétil some no primeiro acerto.
- **Efeitos de status:** acerto: empurrão de 40 px (dividido pelo peso do inimigo) e atordoamento de 0,1 s (multiplicado pelo fator de atordoamento do inimigo; chefe não atordoa). Sem lentidão, sem queimadura e sem explosão.
- **Limites na tela:** Pool de 48 compartilhado com nuvem, anel, meteoro e aliado (armas novas). Se o pool estiver cheio, o tiro é descartado sem aviso, e o resto do leque também. Esta arma: até 1 ao mesmo tempo no nível 1 e até 4 no nível 5 (2 por disparo a cada 1,5 s, com 1,6 s de voo).
- **Sequência de animação (quadro a quadro, a 60 fps):**
- **Disparo (quadro 0):** o projétil nasce 14 px acima do herói. Não há efeito de disparo hoje.
- **Viagem (até o quadro 96):** anda 7 px por quadro (420 px/s). Termina no quadro do acerto, ou ao completar 1,6 s (96 quadros).
- **Impacto (1 quadro):** o projétil some. O inimigo pisca por 0,08 s (5 quadros) e sai o número do dano. Não há efeito próprio de impacto.
- **Fim:** nada mais na tela.
- **Giro:** não existe hoje. O desenho segue a direção do voo, sem girar.
- **Sprite:** hoje, o desenho genérico tem rastro de 9 px, linha branca de 6 px e brilho de 14×14 px, na cor da arma. Sprite previsto no pacote: 16×16 px, 1 quadro.
