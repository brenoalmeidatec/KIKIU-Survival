# Martelo do Trovão (martelo_trovao)
**Tipo:** anel de choque. **Ícone:** icone_u_martelo_forjagelo.
**O que faz:** Um anel amarelo, estreito e muito rápido sai de você com um estalo. Quem ele toca leva dano e é empurrado um pouco.
**Na prática:**
- Dano: 18 por inimigo tocado.
- Recarga: 2,2 segundos entre um estalo e outro.
- Raio: o anel para em 45 px, o menor do lote.
- Velocidade de expansão: 520 px por segundo. Chega à borda em cerca de 0,09 s. É quase um clarão.
- Empurrão: 35 (impulso em px/s, que cai rápido; o monstro anda cerca de 3,9 px).
- Cada inimigo leva o golpe uma vez por anel.
- O anel sai de você e anda com você enquanto cresce.
- Só dispara quando há inimigo perto (até cerca de 340 px). Sem inimigo, ele espera e não gasta a recarga.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 18, recarga 2,2 s, raio 45, velocidade 520 px/s |
| 2 | +6 de dano (24) |
| 3 | +12 de raio (57) |
| 4 | Recarga 0,4 s mais curta (1,8 s) |
| 5 | +7 de dano e +80 de velocidade. Total: dano 31, raio 57, recarga 1,8 s, velocidade 600 px/s, chega à borda em cerca de 0,095 s |

Nível 5 mostra o total dos quatro aprimoramentos. Uma carta lendária sobe dois níveis de uma vez. A raridade também soma dano: raro +18%, épico +40%, lendário +80%.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta) Tempestade de Anéis:** Martelo do Trovão no nível 3 + Rajada de Vento no nível 3. As duas somem e vira um anel só, rápido e forte. Usa só o tipo anel.

**Animação e efeitos:**
- Hoje: um círculo achatado (altura igual a 62% da largura), na cor da arma. A borda de fora tem 3 px e fica mais fraca conforme cresce. Por dentro, um filete branco de 1,5 px acompanha a borda, 4 px para dentro. Não há faíscas.
- Especificação do campo "arte" do JSON, para o Alisson substituir:
  - Visual: na tela de 960x540, um anel amarelo estreito e rápido com faíscas elétricas que estalam na borda, e riscos brancos curtos ao lado.
  - Cores: amarelo, branco-azulado.
  - Tamanho: borda de 4 px; faíscas de 2 px.
  - Duração: 0,25 s.
  - Provisório: círculo amarelo estreito de 3 px com dois riscos brancos curtos.

**Mudanças em relação ao desenho original:** o desenho não mudou (segue o PR #192). Número corrigido: o empurrão era lido como px, mas no código ele é um impulso em px/s que cai com exp(-9 t), então o monstro anda cerca de 3,9 px no nível 1 e 3,9 px no nível 5 (peso 1,0), não 35 px. A tabela de níveis usa os valores do código e não mudou.

**Pontos de atenção:**
- Duração: o arte pede 0,25 s, mas o código dura 0,09 s no nível 1 e cerca de 0,095 s no nível 5. Quase não dá para ver o anel crescer; vira um estalo. Decidir se é isso que se quer ou se a velocidade deve baixar.
- O nível 5 chega a 600 px por segundo, então o anel fica ainda mais rápido. Conferir se a leitura visual ainda funciona.
- As faíscas elétricas e os riscos brancos não existem no código.
- Dano por segundo, com um inimigo só (base): 8,2. É um dos mais altos do lote.

## Esquemática
- **Gatilho:** dispara quando há pelo menos um inimigo vivo a até 340 px do herói (distância reta). Recarga por nível (1 a 5): 2,2 / 2,2 / 2,2 / 1,8 / 1,8 s, dividida pelo vel_ataque do herói (1,0 por padrão). Sem inimigo, espera 0,3 s e não gasta a recarga. O primeiro disparo sai 0,4 s depois que a arma entra.
- **Alvo:** nenhum. O anel nasce na posição do herói e não mira. O inimigo só serve como condição para disparar.
- **Trajetória e alcance:** nasce no herói e anda com ele. Cresce a 520 px/s (nível 1) e 600 px/s (nível 5) até o raio, que é o alcance: 45 px no nível 1 e 57 px no nível 5 (o campo "alcance" não vale para anel). Chega à borda em 0,09 s (nível 1) e 0,10 s (nível 5), e então some.
- **Área:** faixa em anel achatado: raio horizontal de 45 a 57 px, e vertical de 62% disso. Quem está a até 14 px + o raio do próprio monstro (6 a 9 px nos comuns) da linha do anel leva o golpe. Ou seja, a faixa de acerto tem de 40 a 46 px de largura, bem mais que o traço de 3 px que aparece na tela.
- **Dano por nível:** dano base de cada nível, nas quatro raridades (comum / raro / épico / lendário). A raridade multiplica o dano: raro +18%, épico +40%, lendário +80%, arredondado ao inteiro mais próximo. O multiplicador m_dano do herói é 1,0 por padrão.

| Nível | Dano (comum / raro / épico / lendário) | Como muda |
|---|---|---|
| 1 | 18 / 21 / 25 / 32 | (base) recarga 2,2 s; raio 45 px; velocidade 520 px/s; empurrão 35 px/s |
| 2 | 24 / 28 / 34 / 43 | +6 de dano. Agora: recarga 2,2 s; raio 45 px; velocidade 520 px/s; empurrão 35 px/s |
| 3 | 24 / 28 / 34 / 43 | +12 de raio. Agora: recarga 2,2 s; raio 57 px; velocidade 520 px/s; empurrão 35 px/s |
| 4 | 24 / 28 / 34 / 43 | recarga mais curta. Agora: recarga 1,8 s; raio 57 px; velocidade 520 px/s; empurrão 35 px/s |
| 5 | 31 / 37 / 43 / 56 | +7 de dano e mais veloz. Agora: recarga 1,8 s; raio 57 px; velocidade 600 px/s; empurrão 35 px/s |

- **Como aplica:** uma vez por inimigo por anel (o anel guarda quem já foi tocado). Sem tique, sem perfuração, sem explosão.
- **Efeitos de status:**
  - Empurrão: impulso de 35 px/s no nível 1 e 35 px/s no nível 5 (o campo do código). O impulso cai com exp(-9 t), então o monstro anda cerca de 3,9 px (nível 1) e 3,9 px (nível 5), para peso 1,0. Monstro mais pesado anda na razão do peso (o cavaleiro oco, peso 2,6, anda 2,6 vezes menos).
  - Atordoamento: 0,15 s (zero no chefe).
  - Lentidão: nenhuma.
  - Queimadura: nenhuma.
- **Limites na tela:** 1 anel vivo por vez por arma, com vel_ataque 1,0. Só aparece mais de um vivo com vel_ataque acima de 11,3x (menor limite entre os níveis). Os golpes novos dividem um pool de 48 slots (projétil, nuvem, anel, meteoro e aliado). Se o pool estiver cheio, o anel não sai, mas a recarga é gasta do mesmo jeito.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe. 0 s, 0 quadros. O anel nasce já no disparo.
  - Disparo: 1 quadro (0,02 s), raio 0, ainda invisível.
  - Viagem: de 0,09 s (5 quadros) no nível 1 a 0,10 s (6 quadros) no nível 5. A cada quadro o raio cresce 8,7 px (nível 1) ou 10,0 px (nível 5). A opacidade cai junto com o raio (1 − raio/raio máximo).
  - Impacto: por inimigo tocado, flash branco de 0,08 s (5 quadros) e número de dano na cor da arma. O inimigo recua e fica atordoado por 0,15 s (9 quadros). O anel não muda no impacto.
  - Fim: 0 quadros. Some ao chegar ao raio, sem fase de sumir.
  - Tamanho do sprite: hoje não há sprite (o anel é desenhado por arco). Para o pacote: 32x20 px por quadro, 5 quadros. Na tela, a largura vai de 90 a 114 px (2 × raio).
