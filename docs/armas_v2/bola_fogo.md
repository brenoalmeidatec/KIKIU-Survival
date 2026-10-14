# Bola de Fogo (bola_fogo)
**Tipo:** projétil. **Ícone:** icone_u_frasco_incendiario.
**O que faz:** Esfera de fogo lenta que explode em área no inimigo mais perto. Dá dano no alvo e nos vizinhos da explosão.
**Na prática:**
- Alcance para escolher o alvo: 260 px, o maior do lote entre as armas lentas. A esfera voa devagar, até 1,6 s (cerca de 320 px).
- Dano direto: 18. Explosão: área de raio 40 px (80 px de diâmetro). Recarga: 2,6 s. Balas: 1 por disparo.
- Alvo: o inimigo mais perto dentro de 260 px. Explode no primeiro inimigo que tocar.
- Se a esfera não encostar em ninguém (o alvo se mexeu), some sem explodir.
- Não perfura.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base): 18 de dano, recarga 2,6 s, explosão de raio 40 px. |
| 2 | +6 de dano: 24 de dano direto. |
| 3 | Explosão maior: raio 52 px (104 px de diâmetro). |
| 4 | +1 esfera: 2 esferas por disparo. |
| 5 | +8 de dano e mais rápida: 32 de dano, recarga 2,2 s. Lendário sobe 2 níveis de uma vez. Acumulado no nível 5: 2 esferas, 32 de dano direto, explosão de raio 52 px, recarga 2,2 s. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** **Cometa Fundido**: Bola de Fogo nível 3 + Bolas de Chumbo nível 3. Consome as duas. Ideia: uma bola de fogo com bolas de chumbo dentro, que cai e explode com área maior.

**Animação e efeitos:**
- Hoje (placeholder): rastro laranja de 4 px, meio transparente, atrás da esfera; um risco branco de 1,5 px; e um brilho de 14 px na esfera. A explosão usa o efeito já existente de explodir(): anel que cresce em 0,25 s, luz de 0,25 s e partículas (ver Esquemática).
- Especificação do campo "arte": esfera de fogo laranja com núcleo amarelo, que sai devagar e deixa faíscas caindo atrás. Ao chegar ao alvo, explode num círculo de fogo que se abre no chão e some em seguida. Cores: laranja, amarelo, vermelho. Tamanho: esfera de 16 px; explosão de 80 px de diâmetro. Duração: 0,4 s na explosão.

**Mudanças em relação ao desenho original:** Nenhum número mudou. Duração da explosão: a arte pede 0,4 s, mas o efeito que o código já usa (explodir) dura 0,25 s no anel e na luz. Raio e exclusão do alvo confirmados no código.

**Pontos de atenção:**
- Resolvido no código: o campo de explosão é raio (40 px, ou 80 px de diâmetro), como diz a arte.
- Resolvido no código: o inimigo tocado é excluído da explosão (ele só leva o dano direto). A explosão usa o mesmo dano cheio, sem redução.
- As faíscas da arte não estão no placeholder.
- O texto "provisorio" do JSON (3 faíscas amarelas e anel de 80 px) não bate com o desenho do rastro. Ajustar um dos dois.
- O campo "arte" é só documentação: o código não o lê.
- O pool de projéteis tem 48 vagas e é compartilhado: se estiver cheio, a esfera é descartada sem explodir e sem aviso.

## Esquemática
- **Gatilho:** a cada recarga: 2,6 s no nível 1 e 2,2 s no nível 5. A recarga é dividida por m_vel_ataque (1,0 por padrão). Sem inimigo a 340 px do herói, espera 0,3 s e não gasta a recarga. Com inimigo a 340 px, mas nenhum dentro do alcance de alvo, a recarga é gasta e nada sai.
- **Alvo:** o inimigo vivo mais perto dentro de 260 px, medido no plano achatado (y ÷ 0,62), na hora do disparo. Sem mira antecipada.
- **Trajetória e alcance:** sai 14 px acima do herói, em linha reta para a posição do alvo no momento do disparo. Velocidade 200 px/s; voa até 1,6 s, ou seja, até 320 px, ou até acertar. Não para no alcance nem no alvo, e não faz curva. Só acerta inimigos a até 340 px do herói (a lista de perto). Leque: 8° entre disparos vizinhos; com 2 disparos (nível 5), a abertura total é de 8°, com o primeiro e o último nas pontas.
- **Área:** explosão em círculo no chão (elipse na tela), medido no plano achatado (y ÷ 0,62): raio 40 px no nível 1 e 2, e 52 px do nível 3 em diante (80 e 104 px de diâmetro). Acerto direto pontual, como nas outras armas.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 18 | (base). Fica: 1 esfera, recarga 2,6 s, explosão de raio 40 px. |
| 2 | 24 | +6 de dano. Fica: 1 esfera, recarga 2,6 s, explosão de raio 40 px. |
| 3 | 24 | explosão maior. Fica: 1 esfera, recarga 2,6 s, explosão de raio 52 px. |
| 4 | 24 | +1 esfera. Fica: 2 esferas, recarga 2,6 s, explosão de raio 52 px. |
| 5 | 32 | +8 de dano e mais rápida. Fica: 2 esferas, recarga 2,2 s, explosão de raio 52 px. |

Dano = (base + soma dos níveis) × (1 + bônus acumulado). Cada carta do golpe soma o bonus_arma da sua raridade (raro +18%, épico +40%, lendário +80%), então com raro a tabela vai por 1,18; épico 1,40; lendário 1,80 (e mais, se houver mais cartas dessa arma). A tabela é a comum (bônus 0). m_dano é 1,0 por padrão; ele sobe com a meta (bônus de dano) e com cartas de atributo de dano; a tabela usa 1,0. Carta lendária sobe 2 níveis de uma vez; num golpe novo, entra direto no nível 2.
- **Como aplica:** acerto direto: uma vez no inimigo que a esfera tocou, com o dano cheio. Explosão: uma vez em cada outro inimigo cujo centro esteja a menos de raio + raio do inimigo do ponto de impacto, com o mesmo dano cheio (sem redução). O inimigo tocado é excluído da explosão. Sem perfura: a esfera some no primeiro toque.
- **Efeitos de status:** acerto direto: empurrão de 40 px e atordoamento de 0,1 s no inimigo tocado. Explosão nos vizinhos: empurrão de 120 px a partir do centro e atordoamento de 0,2 s. Sem lentidão e sem queimadura.
- **Limites na tela:** Pool de 48 compartilhado com nuvem, anel, meteoro e aliado (armas novas). Se o pool estiver cheio, o tiro é descartado sem aviso, e o resto do leque também. Esta arma: até 1 ao mesmo tempo no nível 1 e até 2 no nível 5 (2 por disparo a cada 2,2 s, com 1,6 s de voo).
- **Sequência de animação (quadro a quadro, a 60 fps):**
- **Disparo (quadro 0):** o projétil nasce 14 px acima do herói. Não há efeito de disparo hoje.
- **Viagem (até o quadro 96):** anda 3,3 px por quadro (200 px/s). Termina no quadro do acerto, ou ao completar 1,6 s (96 quadros).
- **Impacto direto (quadro do acerto):** o inimigo pisca por 0,08 s (5 quadros) e sai o número do dano.
- **Explosão (quadro do acerto):** anel na cor da arma que cresce até o raio do nível (40 ou 52 px, ou 24 ou 32 px) em 0,25 s (15 quadros), desacelerando; luz da cor por 0,25 s (15 quadros); cerca de 8 partículas que somem entre 0,3 e 0,55 s (18 a 33 quadros). Som de explosão.
- **Fim:** após 0,55 s (33 quadros), nada mais na tela.
- **Giro:** não existe hoje. O desenho segue a direção do voo, sem girar.
- **Sprite:** hoje, o desenho genérico tem rastro de 9 px, linha branca de 6 px e brilho de 14×14 px, na cor da arma. Sprite previsto no pacote: 16×16 px, 1 quadro.
