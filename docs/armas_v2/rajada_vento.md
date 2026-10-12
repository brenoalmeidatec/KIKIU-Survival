# Rajada de Vento (rajada_vento)
**Tipo:** anel de choque. **Ícone:** icone_u_disco_cortante.
**O que faz:** Anéis verdes saem o tempo todo. Cada um passa rápido e empurra os inimigos para longe. O dano é pequeno.
**Na prática:**
- Dano: 5 por inimigo tocado.
- Recarga: 0,6 segundo entre um anel e outro. É a mais curta do lote.
- Raio: o anel para em 50 px.
- Velocidade de expansão: 700 px por segundo. Chega à borda em cerca de 0,07 s.
- Empurrão: 90 (impulso em px/s, que cai rápido; o monstro anda cerca de 10,0 px). É o segundo maior do lote.
- Cada inimigo leva o golpe uma vez por anel.
- O anel sai de você e anda com você enquanto cresce.
- Só dispara quando há inimigo perto (até cerca de 340 px). Sem inimigo, ele espera e não gasta a recarga.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 5, recarga 0,6 s, raio 50, velocidade 700 px/s, empurrão 90 |
| 2 | +2 de dano (7) |
| 3 | +12 de raio (62) |
| 4 | +30 de empurrão (120) |
| 5 | +3 de dano e +120 de velocidade. Total: dano 10, raio 62, recarga 0,6 s, velocidade 820 px/s, empurrão 120 |

Nível 5 mostra o total dos quatro aprimoramentos. Uma carta lendária sobe dois níveis de uma vez. A raridade também soma dano: raro +18%, épico +40%, lendário +80%.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta) Tempestade de Anéis:** Rajada de Vento no nível 3 + Martelo do Trovão no nível 3. As duas somem e vira um anel só, rápido e forte. Usa só o tipo anel.

**Animação e efeitos:**
- Hoje: um círculo achatado (altura igual a 62% da largura), na cor da arma. A borda de fora tem 3 px e fica mais fraca conforme cresce. Por dentro, um filete branco de 1,5 px acompanha a borda, 4 px para dentro. Não há rastro de vento nem folhas.
- Especificação do campo "arte" do JSON, para o Alisson substituir:
  - Visual: na tela de 960x540, um anel verde-claro quase transparente, com rastros de vento atrás. Passa rápido, empurra os inimigos e solta folhas.
  - Cores: verde-claro, branco.
  - Tamanho: borda de 2 px com rastro de 14 px; folhas de 3 px.
  - Duração: 0,2 s.
  - Provisório: círculo verde-claro de 2 px que cresce rápido e some, com dois traços de vento.

**Mudanças em relação ao desenho original:** o desenho não mudou (segue o PR #192). Número corrigido: o empurrão era lido como px, mas no código ele é um impulso em px/s que cai com exp(-9 t), então o monstro anda cerca de 10,0 px no nível 1 e 13,3 px no nível 5 (peso 1,0), não 90 px. A tabela de níveis usa os valores do código e não mudou.

**Pontos de atenção:**
- Duração: o arte pede 0,2 s, mas o código dura 0,07 s no nível 1. Como o anel some quase de imediato, o efeito visual some quase todo.
- Rastro de vento e folhas não existem no código. Também a borda do arte é de 2 px, e o código desenha 3 px.
- Pergunta de balanço: a arma dispara a cada 0,6 s e empurra 90 px, então pode manter os inimigos longe do herói o tempo todo. Vale testar se isso deixa o jogo fácil demais.
- Dano por segundo, com um inimigo só (base): 8,3. Com dano por golpe de só 5, ela depende da frequência para render.

## Esquemática
- **Gatilho:** dispara quando há pelo menos um inimigo vivo a até 340 px do herói (distância reta). Recarga por nível (1 a 5): 0,6 / 0,6 / 0,6 / 0,6 / 0,6 s, dividida pelo vel_ataque do herói (1,0 por padrão). Sem inimigo, espera 0,3 s e não gasta a recarga. O primeiro disparo sai 0,4 s depois que a arma entra.
- **Alvo:** nenhum. O anel nasce na posição do herói e não mira. O inimigo só serve como condição para disparar.
- **Trajetória e alcance:** nasce no herói e anda com ele. Cresce a 700 px/s (nível 1) e 820 px/s (nível 5) até o raio, que é o alcance: 50 px no nível 1 e 62 px no nível 5 (o campo "alcance" não vale para anel). Chega à borda em 0,07 s (nível 1) e 0,08 s (nível 5), e então some.
- **Área:** faixa em anel achatado: raio horizontal de 50 a 62 px, e vertical de 62% disso. Quem está a até 14 px + o raio do próprio monstro (6 a 9 px nos comuns) da linha do anel leva o golpe. Ou seja, a faixa de acerto tem de 40 a 46 px de largura, bem mais que o traço de 3 px que aparece na tela.
- **Dano por nível:** dano base de cada nível, nas quatro raridades (comum / raro / épico / lendário). A raridade multiplica o dano: raro +18%, épico +40%, lendário +80%, arredondado ao inteiro mais próximo. O multiplicador m_dano do herói é 1,0 por padrão.

| Nível | Dano (comum / raro / épico / lendário) | Como muda |
|---|---|---|
| 1 | 5 / 6 / 7 / 9 | (base) recarga 0,6 s; raio 50 px; velocidade 700 px/s; empurrão 90 px/s |
| 2 | 7 / 8 / 10 / 13 | +2 de dano. Agora: recarga 0,6 s; raio 50 px; velocidade 700 px/s; empurrão 90 px/s |
| 3 | 7 / 8 / 10 / 13 | +12 de raio. Agora: recarga 0,6 s; raio 62 px; velocidade 700 px/s; empurrão 90 px/s |
| 4 | 7 / 8 / 10 / 13 | empurra mais forte. Agora: recarga 0,6 s; raio 62 px; velocidade 700 px/s; empurrão 120 px/s |
| 5 | 10 / 12 / 14 / 18 | +3 de dano e mais veloz. Agora: recarga 0,6 s; raio 62 px; velocidade 820 px/s; empurrão 120 px/s |

- **Como aplica:** uma vez por inimigo por anel (o anel guarda quem já foi tocado). Sem tique, sem perfuração, sem explosão.
- **Efeitos de status:**
  - Empurrão: impulso de 90 px/s no nível 1 e 120 px/s no nível 5 (o campo do código). O impulso cai com exp(-9 t), então o monstro anda cerca de 10,0 px (nível 1) e 13,3 px (nível 5), para peso 1,0. Monstro mais pesado anda na razão do peso (o cavaleiro oco, peso 2,6, anda 2,6 vezes menos).
  - Atordoamento: 0,15 s (zero no chefe).
  - Lentidão: nenhuma.
  - Queimadura: nenhuma.
- **Limites na tela:** 1 anel vivo por vez por arma, com vel_ataque 1,0. Só aparece mais de um vivo com vel_ataque acima de 4,3x (menor limite entre os níveis). Os golpes novos dividem um pool de 48 slots (projétil, nuvem, anel, meteoro e aliado). Se o pool estiver cheio, o anel não sai, mas a recarga é gasta do mesmo jeito.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe. 0 s, 0 quadros. O anel nasce já no disparo.
  - Disparo: 1 quadro (0,02 s), raio 0, ainda invisível.
  - Viagem: de 0,07 s (4 quadros) no nível 1 a 0,08 s (5 quadros) no nível 5. A cada quadro o raio cresce 11,7 px (nível 1) ou 13,7 px (nível 5). A opacidade cai junto com o raio (1 − raio/raio máximo).
  - Impacto: por inimigo tocado, flash branco de 0,08 s (5 quadros) e número de dano na cor da arma. O inimigo recua e fica atordoado por 0,15 s (9 quadros). O anel não muda no impacto.
  - Fim: 0 quadros. Some ao chegar ao raio, sem fase de sumir.
  - Tamanho do sprite: hoje não há sprite (o anel é desenhado por arco). Para o pacote: 32x20 px por quadro, 4 quadros. Na tela, a largura vai de 100 a 124 px (2 × raio).
