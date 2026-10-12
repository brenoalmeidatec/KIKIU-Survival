# Anel Lunar (anel_luar)
**Tipo:** anel de choque. **Ícone:** icone_u_estrela_matutina.
**O que faz:** Um anel prateado enorme se abre ao seu redor de tempos em tempos. É o maior do lote e pega inimigos bem longe. Quem ele toca leva dano e é empurrado um pouco.
**Na prática:**
- Dano: 13 por inimigo tocado.
- Recarga: 4,2 segundos entre um anel e outro.
- Raio: o anel para em 110 px, o maior do lote.
- Velocidade de expansão: 200 px por segundo. Chega à borda em cerca de 0,55 s.
- Empurrão: 40 (impulso em px/s, que cai rápido; o monstro anda cerca de 4,4 px).
- Cada inimigo leva o golpe uma vez por anel.
- O anel sai de você e anda com você enquanto cresce.
- Só dispara quando há inimigo perto (até cerca de 340 px). Sem inimigo, ele espera e não gasta a recarga.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 13, recarga 4,2 s, raio 110, velocidade 200 px/s, empurrão 40 |
| 2 | +4 de dano (17) |
| 3 | Recarga 0,4 s mais curta (3,8 s) |
| 4 | +6 de dano e +60 de velocidade (260 px/s) |
| 5 | +5 de dano e +20 de empurrão. Total: dano 28, raio 110, recarga 3,8 s, velocidade 260 px/s, empurrão 60 |

Nível 5 mostra o total dos quatro aprimoramentos. Uma carta lendária sobe dois níveis de uma vez. A raridade também soma dano: raro +18%, épico +40%, lendário +80%.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta) Maré Lunar:** Anel Lunar no nível 3 + Onda de Choque no nível 3. As duas somem e vira um anel só, com o maior alcance do lote. Usa só o tipo anel.

**Animação e efeitos:**
- Hoje: um círculo achatado (altura igual a 62% da largura), na cor da arma. A borda de fora tem 3 px e fica mais fraca conforme cresce. Por dentro, um filete branco de 1,5 px acompanha a borda, 4 px para dentro. Não há estrelas nem brilho externo.
- Especificação do campo "arte" do JSON, para o Alisson substituir:
  - Visual: na tela de 960x540, um anel prateado enorme e tênue, com brilho de lua e pequenas estrelas na borda. Some devagar, como um halo que se abre.
  - Cores: prateado, azul-noite.
  - Tamanho: borda de 3 px; halo cobre a área de alcance; estrelas de 3 px.
  - Duração: 0,9 s de expansão; 0,3 s para sumir.
  - Provisório: círculo prateado de 3 px com brilho externo mais fraco que cresce e some.

**Mudanças em relação ao desenho original:** o desenho não mudou (segue o PR #192). Número corrigido: o empurrão era lido como px, mas no código ele é um impulso em px/s que cai com exp(-9 t), então o monstro anda cerca de 4,4 px no nível 1 e 6,7 px no nível 5 (peso 1,0), não 40 px. A tabela de níveis usa os valores do código e não mudou.

**Pontos de atenção:**
- Duração: o arte pede 0,9 s de expansão e 0,3 s para sumir. O código dura 0,55 s no nível 1 e cerca de 0,42 s no nível 5, e não tem a fase de sumir: o anel some sozinho ao chegar a 110 px.
- O anel já desaparece aos poucos conforme cresce, então no fim da expansão ele está quase invisível. Se a intenção é um halo que some devagar, o código precisa de ajuste.
- As estrelas e o brilho externo não existem no código.
- Dano por segundo, com um inimigo só (base): 3,1. O valor real é maior, porque a área é a maior do jogo e pega vários inimigos.

## Esquemática
- **Gatilho:** dispara quando há pelo menos um inimigo vivo a até 340 px do herói (distância reta). Recarga por nível (1 a 5): 4,2 / 4,2 / 3,8 / 3,8 / 3,8 s, dividida pelo vel_ataque do herói (1,0 por padrão). Sem inimigo, espera 0,3 s e não gasta a recarga. O primeiro disparo sai 0,4 s depois que a arma entra.
- **Alvo:** nenhum. O anel nasce na posição do herói e não mira. O inimigo só serve como condição para disparar.
- **Trajetória e alcance:** nasce no herói e anda com ele. Cresce a 200 px/s (nível 1) e 260 px/s (nível 5) até o raio, que é o alcance: 110 px no nível 1 e 110 px no nível 5 (o campo "alcance" não vale para anel). Chega à borda em 0,55 s (nível 1) e 0,42 s (nível 5), e então some.
- **Área:** faixa em anel achatado: raio horizontal de 110 a 110 px, e vertical de 62% disso. Quem está a até 14 px + o raio do próprio monstro (6 a 9 px nos comuns) da linha do anel leva o golpe. Ou seja, a faixa de acerto tem de 40 a 46 px de largura, bem mais que o traço de 3 px que aparece na tela.
- **Dano por nível:** dano base de cada nível, nas quatro raridades (comum / raro / épico / lendário). A raridade multiplica o dano: raro +18%, épico +40%, lendário +80%, arredondado ao inteiro mais próximo. O multiplicador m_dano do herói é 1,0 por padrão.

| Nível | Dano (comum / raro / épico / lendário) | Como muda |
|---|---|---|
| 1 | 13 / 15 / 18 / 23 | (base) recarga 4,2 s; raio 110 px; velocidade 200 px/s; empurrão 40 px/s |
| 2 | 17 / 20 / 24 / 31 | +4 de dano. Agora: recarga 4,2 s; raio 110 px; velocidade 200 px/s; empurrão 40 px/s |
| 3 | 17 / 20 / 24 / 31 | recarga mais curta. Agora: recarga 3,8 s; raio 110 px; velocidade 200 px/s; empurrão 40 px/s |
| 4 | 23 / 27 / 32 / 41 | +6 de dano e mais veloz. Agora: recarga 3,8 s; raio 110 px; velocidade 260 px/s; empurrão 40 px/s |
| 5 | 28 / 33 / 39 / 50 | +5 de dano e empurra. Agora: recarga 3,8 s; raio 110 px; velocidade 260 px/s; empurrão 60 px/s |

- **Como aplica:** uma vez por inimigo por anel (o anel guarda quem já foi tocado). Sem tique, sem perfuração, sem explosão.
- **Efeitos de status:**
  - Empurrão: impulso de 40 px/s no nível 1 e 60 px/s no nível 5 (o campo do código). O impulso cai com exp(-9 t), então o monstro anda cerca de 4,4 px (nível 1) e 6,7 px (nível 5), para peso 1,0. Monstro mais pesado anda na razão do peso (o cavaleiro oco, peso 2,6, anda 2,6 vezes menos).
  - Atordoamento: 0,15 s (zero no chefe).
  - Lentidão: nenhuma.
  - Queimadura: nenhuma.
- **Limites na tela:** 1 anel vivo por vez por arma, com vel_ataque 1,0. Só aparece mais de um vivo com vel_ataque acima de 6,3x (menor limite entre os níveis). Os golpes novos dividem um pool de 48 slots (projétil, nuvem, anel, meteoro e aliado). Se o pool estiver cheio, o anel não sai, mas a recarga é gasta do mesmo jeito.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe. 0 s, 0 quadros. O anel nasce já no disparo.
  - Disparo: 1 quadro (0,02 s), raio 0, ainda invisível.
  - Viagem: de 0,55 s (33 quadros) no nível 1 a 0,42 s (25 quadros) no nível 5. A cada quadro o raio cresce 3,3 px (nível 1) ou 4,3 px (nível 5). A opacidade cai junto com o raio (1 − raio/raio máximo).
  - Impacto: por inimigo tocado, flash branco de 0,08 s (5 quadros) e número de dano na cor da arma. O inimigo recua e fica atordoado por 0,15 s (9 quadros). O anel não muda no impacto.
  - Fim: 0 quadros. Some ao chegar ao raio, sem fase de sumir.
  - Tamanho do sprite: hoje não há sprite (o anel é desenhado por arco). Para o pacote: 48x30 px por quadro, 6 quadros. Na tela, a largura vai de 220 a 220 px (2 × raio).
