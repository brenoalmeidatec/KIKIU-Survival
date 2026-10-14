# Círculo Rúnico (fusão circulo_runico)

**Peças:** Runa Explosiva (nível 3) + Crítico explosivo (nível 2, modificador da katana). Fichas: runa.md. O Crítico explosivo é um modificador da katana, sem ficha própria em armas_v2 (o efeito vem de dados/v2_cartas.json, "explode").

**Vira:** runas explosivas maiores, que explodem em área grande e deixam os inimigos lentos. Elas aparecem no lugar da Runa Explosiva (que sai do sorteio). O Crítico explosivo não é consumido: continua no sorteio.

**O que faz:** muitas runas caem no chão. Quando um inimigo pisa em uma delas, ela explode em área grande, empurra quem está perto e deixa os sobreviventes lentos.

**Como liberar:** pegue 3 cartas de Runa Explosiva e 2 de Crítico explosivo. Quando as duas peças chegam ao nível pedido, a fusão acontece na hora (anúncio EVOLUÇÃO). Só a Runa sai do sorteio. Enquanto falta uma delas, a que falta aparece com o rodapé "Evolui: Círculo Rúnico" e pesa mais no sorteio.

## Esquemática
- **Gatilho:** a cada 1,6 s, dividido pela velocidade de ataque do herói (com 1,0 são 1,6 s). Solta 5 runas de cada vez. Só dispara com inimigo a até 340 px do herói. Sem inimigo, espera 0,3 s e não gasta a recarga. A runa fica armada 0,5 s depois de cair: antes disso não explode.
- **Alvo:** cada runa cai em um de dois lugares. Em 65% das vezes, perto de um inimigo sorteado (até 340 px do herói), com um desvio de 16 px em x e 10 px em y. Nos outros 35%, em um anel de 46 a 120 px em volta do herói. A posição precisa ser andável (até 5 tentativas).
- **Trajetória e alcance:** a runa não se move. Fica no chão do ponto em que caiu.
- **Área:** o gatilho é um círculo de 20 px de raio mais o raio do inimigo (achatado no chão). A explosão é um círculo de 66 px de raio (elipse de 132 x 82 px na tela), com área 1,0.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 5 (fixo) | 58 por explosão | Base do registro. O bônus de raridade (cada carta de peça soma o bônus da sua raridade: raro +18%, épico +40%, lendário +80%; a fusão usa o maior bônus entre as peças consumidas) multiplica o dano: 58 comum, 68 raro, 81 épico, 104 lendário. |

  O multiplicador de dano do herói (m_dano) é 1,0 por padrão, e o dano final é esse número vezes m_dano.
- **Como aplica:** por explosão. Cada runa explode uma vez, quando um inimigo entra no gatilho. Todo inimigo dentro da área leva o dano uma vez. Se a runa vence sem ninguém pisar (9 s), some sem dano.
- **Efeitos de status:**
  - Empurrão de 160 (valor do código; o peso do inimigo reduz o efeito).
  - Atordoamento de 0,3 s.
  - Lentidão de 1,6 s: o inimigo fica com cerca de metade da velocidade enquanto dura (o código reduz a 45% ou 50%, conforme o tipo de movimento).
  - Queimadura: nenhuma.
- **Limites na tela:** 14 runas ao mesmo tempo (MAX_RUNAS). Cada disparo traz 5 e cada runa dura 9 s, então o teto de 14 é atingido com facilidade.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: surgimento de 0,3 s (18 quadros): o glifo cresce até o tamanho cheio. A runa fica armada aos 0,5 s (30 quadros); até lá, a luz é 50%.
  - Disparo: nenhum (a runa está parada no chão).
  - Viagem: nenhuma. A runa fica no lugar, com pulso de período 1,05 s (63 quadros).
  - Impacto (explosão, 1 vez): estouro de 12 partículas, onda no chão de 0,3 s (18 quadros) até o raio de 66 px, luz rápida de 0,3 s e tremor de câmera de 0,12 s.
  - Fim: a runa some em 0,8 s (48 quadros) quando acaba a duração; se explodiu, some na hora.
  - Tamanho do sprite: glifo de 64 x 64 px (textura atual: 64 x 64 px, desenhado com 63 px).

**Mudanças:** Nenhuma.
