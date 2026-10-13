# Pulso Sagrado (pulso_sagrado)
**Tipo:** anel de choque. **Ícone:** icone_u_egide_dourada.
**O que faz:** Um anel dourado sai de você a cada pouco mais de um segundo. Quem ele toca leva dano e é empurrado um pouco.
**Na prática:**
- Dano: 6 por inimigo tocado.
- Recarga: 1,2 segundo entre um pulso e outro.
- Raio: o anel para em 55 px.
- Velocidade de expansão: 300 px por segundo. Chega à borda em cerca de 0,18 s.
- Empurrão: 20 (impulso em px/s, que cai rápido; o monstro anda cerca de 2,2 px).
- Cada inimigo leva o golpe uma vez por pulso.
- O pulso sai de você e anda com você enquanto cresce.
- Só dispara quando há inimigo perto (até cerca de 340 px). Sem inimigo, ele espera e não gasta a recarga.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 6, recarga 1,2 s, raio 55, empurrão 20 |
| 2 | +2 de dano (8) |
| 3 | +15 de raio (70) |
| 4 | Recarga 0,3 s mais curta (0,9 s) |
| 5 | +3 de dano e +10 de raio. Total: dano 11, raio 80, recarga 0,9 s, empurrão 20 |

Nível 5 mostra o total dos quatro aprimoramentos. Uma carta lendária sobe dois níveis de uma vez. A raridade também soma dano: raro +18%, épico +40%, lendário +80%.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta) Coroa Espinhosa:** Pulso Sagrado no nível 3 + Anel de Espinhos no nível 3. As duas somem e vira um anel só, com espinhos e luz. Usa só o tipo anel.

**Animação e efeitos:**
- Hoje: um círculo achatado (altura igual a 62% da largura), na cor da arma. A borda de fora tem 3 px e fica mais fraca conforme cresce. Por dentro, um filete branco de 1,5 px acompanha a borda, 4 px para dentro. Não há partículas nem faíscas.
- Especificação do campo "arte" do JSON, para o Alisson substituir:
  - Visual: na tela de 960x540, um anel dourado com pequenas faíscas que sobem. Ao expandir, solta partículas douradas e some devagar.
  - Cores: dourado, amarelo-claro.
  - Tamanho: borda de 3 px; faíscas de 3 px.
  - Duração: 0,35 s.
  - Provisório: círculo dourado de 3 px que cresce e se apaga, com quatro pontos brilhantes que sobem.

**Mudanças em relação ao desenho original:** o desenho não mudou (segue o PR #192). Número corrigido: o empurrão era lido como px, mas no código ele é um impulso em px/s que cai com exp(-9 t), então o monstro anda cerca de 2,2 px no nível 1 e 2,2 px no nível 5 (peso 1,0), não 20 px. A tabela de níveis usa os valores do código e não mudou.

**Pontos de atenção:**
- A descrição do jogo diz "a cada poucos segundos", mas a recarga é 1,2 s. Ou muda a descrição ("a cada segundo") ou a recarga.
- Duração: o arte pede 0,35 s, mas o código dura 0,18 s no nível 1 e 0,27 s no nível 5 (raio 80, velocidade 300). Confirmar o número que vale.
- As faíscas e partículas douradas não existem no código. Só o anel e o filete branco.
- Dano por segundo, com um inimigo só (base): 5,0. Com a recarga de 0,9 s no nível 5, sobe para cerca de 12,2.

## Esquemática
- **Gatilho:** dispara quando há pelo menos um inimigo vivo a até 340 px do herói (distância reta). Recarga por nível (1 a 5): 1,2 / 1,2 / 1,2 / 0,9 / 0,9 s, dividida pelo vel_ataque do herói (1,0 por padrão). Sem inimigo, espera 0,3 s e não gasta a recarga. O primeiro disparo sai 0,4 s depois que a arma entra.
- **Alvo:** nenhum. O anel nasce na posição do herói e não mira. O inimigo só serve como condição para disparar.
- **Trajetória e alcance:** nasce no herói e anda com ele. Cresce a 300 px/s (nível 1) e 300 px/s (nível 5) até o raio, que é o alcance: 55 px no nível 1 e 80 px no nível 5 (o campo "alcance" não vale para anel). Chega à borda em 0,18 s (nível 1) e 0,27 s (nível 5), e então some.
- **Área:** faixa em anel achatado: raio horizontal de 55 a 80 px, e vertical de 62% disso. Quem está a até 14 px + o raio do próprio monstro (6 a 9 px nos comuns) da linha do anel leva o golpe. Ou seja, a faixa de acerto tem de 40 a 46 px de largura, bem mais que o traço de 3 px que aparece na tela.
- **Dano por nível:** dano base de cada nível, nas quatro raridades (comum / raro / épico / lendário). A raridade multiplica o dano: raro +18%, épico +40%, lendário +80%, arredondado ao inteiro mais próximo. O multiplicador m_dano do herói é 1,0 por padrão.

| Nível | Dano (comum / raro / épico / lendário) | Como muda |
|---|---|---|
| 1 | 6 / 7 / 8 / 11 | (base) recarga 1,2 s; raio 55 px; velocidade 300 px/s; empurrão 20 px/s |
| 2 | 8 / 9 / 11 / 14 | +2 de dano. Agora: recarga 1,2 s; raio 55 px; velocidade 300 px/s; empurrão 20 px/s |
| 3 | 8 / 9 / 11 / 14 | +15 de raio. Agora: recarga 1,2 s; raio 70 px; velocidade 300 px/s; empurrão 20 px/s |
| 4 | 8 / 9 / 11 / 14 | recarga mais curta. Agora: recarga 0,9 s; raio 70 px; velocidade 300 px/s; empurrão 20 px/s |
| 5 | 11 / 13 / 15 / 20 | +3 de dano e mais raio. Agora: recarga 0,9 s; raio 80 px; velocidade 300 px/s; empurrão 20 px/s |

- **Como aplica:** uma vez por inimigo por anel (o anel guarda quem já foi tocado). Sem tique, sem perfuração, sem explosão.
- **Efeitos de status:**
  - Empurrão: impulso de 20 px/s no nível 1 e 20 px/s no nível 5 (o campo do código). O impulso cai com exp(-9 t), então o monstro anda cerca de 2,2 px (nível 1) e 2,2 px (nível 5), para peso 1,0. Monstro mais pesado anda na razão do peso (o cavaleiro oco, peso 2,6, anda 2,6 vezes menos).
  - Atordoamento: 0,15 s (zero no chefe).
  - Lentidão: nenhuma.
  - Queimadura: nenhuma.
- **Limites na tela:** 1 anel vivo por vez por arma, com vel_ataque 1,0. Só aparece mais de um vivo com vel_ataque acima de 2,8x (menor limite entre os níveis). Os golpes novos dividem um pool de 48 slots (projétil, nuvem, anel, meteoro e aliado). Se o pool estiver cheio, o anel não sai, mas a recarga é gasta do mesmo jeito.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe. 0 s, 0 quadros. O anel nasce já no disparo.
  - Disparo: 1 quadro (0,02 s), raio 0, ainda invisível.
  - Viagem: de 0,18 s (11 quadros) no nível 1 a 0,27 s (16 quadros) no nível 5. A cada quadro o raio cresce 5,0 px (nível 1) ou 5,0 px (nível 5). A opacidade cai junto com o raio (1 − raio/raio máximo).
  - Impacto: por inimigo tocado, flash branco de 0,08 s (5 quadros) e número de dano na cor da arma. O inimigo recua e fica atordoado por 0,15 s (9 quadros). O anel não muda no impacto.
  - Fim: 0 quadros. Some ao chegar ao raio, sem fase de sumir.
  - Tamanho do sprite: hoje não há sprite (o anel é desenhado por arco). Para o pacote: 32x20 px por quadro, 6 quadros. Na tela, a largura vai de 110 a 160 px (2 × raio).
