# Bolas de Chumbo (bolas_chumbo)
**Tipo:** projétil. **Ícone:** icone_u_marreta_enferrujada.
**O que faz:** Atira bolas de chumbo pesadas e lentas no inimigo mais perto. Cada bola é a arma de mais dano de uma vez, com explosão de chão que racha.
**Na prática:**
- Alcance para escolher o alvo: 180 px. A bola é a mais lenta e voa até 1,6 s (cerca de 290 px). Se o inimigo fugir, ela erra.
- Dano direto: 22. Explosão: área de raio 24 px (48 px de diâmetro). Recarga: 4,5 s. Balas: 1 por disparo.
- Alvo: o inimigo mais perto dentro de 180 px. Explode no primeiro inimigo que tocar.
- Se não encostar em ninguém, some sem explodir.
- Não perfura.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base): 22 de dano, recarga 4,5 s, explosão de raio 24 px. |
| 2 | +6 de dano: 28 de dano direto. |
| 3 | +1 bola: 2 bolas por disparo. |
| 4 | Impacto mais forte: explosão de raio 32 px (64 px de diâmetro). |
| 5 | +8 de dano e mais rápida: 36 de dano, recarga 4,0 s. Lendário sobe 2 níveis de uma vez. Acumulado no nível 5: 2 bolas, 36 de dano direto, explosão de raio 32 px, recarga 4,0 s. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** **Cometa Fundido**: Bolas de Chumbo nível 3 + Bola de Fogo nível 3. Consome as duas. Mesma proposta da Bola de Fogo.

**Animação e efeitos:**
- Hoje (placeholder): mesmo desenho das outras armas de projétil: rastro de 4 px, risco branco de 1,5 px e brilho de 14 px. Não há pó no rastro. A bola não tem peso visual diferente das outras.
- Especificação do campo "arte": bola de chumbo cinza-escuro, pesada, que voa devagar com um pequeno rastro de poeira. No impacto, o chão racha num círculo de poeira que se espalha e some. Cores: chumbo cinza-escuro, cinza-claro, marrom-poeira. Tamanho: bola de 14 px; impacto de 48 px de diâmetro. Duração do impacto: 0,35 s.

**Mudanças em relação ao desenho original:** Nenhum número mudou. Duração da explosão: a arte pede 0,35 s, mas o efeito que o código usa (explodir) dura 0,25 s no anel e na luz.

**Pontos de atenção:**
- A explosão usa o efeito já existente de explodir(): raio 24 px (48 px de diâmetro), anel e luz de 0,25 s. A arte pede 0,35 s.
- Resolvido no código: o inimigo tocado é excluído da explosão. A explosão usa o mesmo dano direto (22 no nível 1), sem redução.
- A cor de pó, o peso e o rastro da arte não estão no placeholder.
- O texto "provisorio" do JSON (3 pontos de poeira e anel marrom de 48 px) não bate com o desenho atual. Ajustar um dos dois.
- O campo "arte" é só documentação: o código não o lê.
- Com recarga de 4,5 s e a bola lenta, se o inimigo mais perto estiver fora do alcance de 180 px, o tiro é perdido sem aviso.
- O pool de projéteis tem 48 vagas e é compartilhado: se estiver cheio, a bola é descartada sem aviso.

## Esquemática
- **Gatilho:** a cada recarga: 4,5 s no nível 1 e 4 s no nível 5. A recarga é dividida por m_vel_ataque (1,0 por padrão). Sem inimigo a 340 px do herói, espera 0,3 s e não gasta a recarga. Com inimigo a 340 px, mas nenhum dentro do alcance de alvo, a recarga é gasta e nada sai.
- **Alvo:** o inimigo vivo mais perto dentro de 180 px, medido no plano achatado (y ÷ 0,62), na hora do disparo. Sem mira antecipada.
- **Trajetória e alcance:** sai 14 px acima do herói, em linha reta para a posição do alvo no momento do disparo. Velocidade 180 px/s; voa até 1,6 s, ou seja, até 288 px, ou até acertar. Não para no alcance nem no alvo, e não faz curva. Só acerta inimigos a até 340 px do herói (a lista de perto). Leque: 8° entre disparos vizinhos; com 2 disparos (nível 5), a abertura total é de 8°, com o primeiro e o último nas pontas.
- **Área:** explosão em círculo no chão (elipse na tela), medido no plano achatado (y ÷ 0,62): raio 24 px nos níveis 1 a 3 (48 px de diâmetro) e 32 px no nível 4 em diante (64 px). Acerto direto pontual, como nas outras armas.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 22 | (base). Fica: 1 bola, recarga 4,5 s, explosão de raio 24 px. |
| 2 | 28 | +6 de dano. Fica: 1 bola, recarga 4,5 s, explosão de raio 24 px. |
| 3 | 28 | +1 bola. Fica: 2 bolas, recarga 4,5 s, explosão de raio 24 px. |
| 4 | 28 | impacto mais forte. Fica: 2 bolas, recarga 4,5 s, explosão de raio 32 px. |
| 5 | 36 | +8 de dano, mais rápida. Fica: 2 bolas, recarga 4 s, explosão de raio 32 px. |

Dano = (base + soma dos níveis) × (1 + bônus acumulado). Cada carta do golpe soma o bonus_arma da sua raridade (raro +18%, épico +40%, lendário +80%), então com raro a tabela vai por 1,18; épico 1,40; lendário 1,80 (e mais, se houver mais cartas dessa arma). A tabela é a comum (bônus 0). m_dano é 1,0 por padrão; ele sobe com a meta (bônus de dano) e com cartas de atributo de dano; a tabela usa 1,0. Carta lendária sobe 2 níveis de uma vez; num golpe novo, entra direto no nível 2.
- **Como aplica:** acerto direto: uma vez no inimigo que a esfera tocou, com o dano cheio. Explosão: uma vez em cada outro inimigo cujo centro esteja a menos de raio + raio do inimigo do ponto de impacto, com o mesmo dano cheio (sem redução). O inimigo tocado é excluído da explosão. Sem perfura: a esfera some no primeiro toque.
- **Efeitos de status:** acerto direto: empurrão de 40 px e atordoamento de 0,1 s no inimigo tocado. Explosão nos vizinhos: empurrão de 120 px a partir do centro e atordoamento de 0,2 s. Sem lentidão e sem queimadura.
- **Limites na tela:** Pool de 48 compartilhado com nuvem, anel, meteoro e aliado (armas novas). Se o pool estiver cheio, o tiro é descartado sem aviso, e o resto do leque também. Esta arma: até 1 ao mesmo tempo no nível 1 e até 2 no nível 5 (2 por disparo a cada 4 s, com 1,6 s de voo).
- **Sequência de animação (quadro a quadro, a 60 fps):**
- **Disparo (quadro 0):** o projétil nasce 14 px acima do herói. Não há efeito de disparo hoje.
- **Viagem (até o quadro 96):** anda 3 px por quadro (180 px/s). Termina no quadro do acerto, ou ao completar 1,6 s (96 quadros).
- **Impacto direto (quadro do acerto):** o inimigo pisca por 0,08 s (5 quadros) e sai o número do dano.
- **Explosão (quadro do acerto):** anel na cor da arma que cresce até o raio do nível (40 ou 52 px, ou 24 ou 32 px) em 0,25 s (15 quadros), desacelerando; luz da cor por 0,25 s (15 quadros); cerca de 8 partículas que somem entre 0,3 e 0,55 s (18 a 33 quadros). Som de explosão.
- **Fim:** após 0,55 s (33 quadros), nada mais na tela.
- **Giro:** não existe hoje. O desenho segue a direção do voo, sem girar.
- **Sprite:** hoje, o desenho genérico tem rastro de 9 px, linha branca de 6 px e brilho de 14×14 px, na cor da arma. Sprite previsto no pacote: 16×16 px, 1 quadro.
