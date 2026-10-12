# Onda de Choque (onda_choque)
**Tipo:** anel de choque. **Ícone:** icone_u_cetro_astral.
**O que faz:** Um anel branco sai de você e cresce para fora. Quem ele toca leva dano e é empurrado para longe.
**Na prática:**
- Dano: 12 por inimigo tocado.
- Recarga: 2,4 segundos entre um anel e outro.
- Raio: o anel para em 70 px.
- Velocidade de expansão: 260 px por segundo. Chega à borda em cerca de 0,27 s.
- Empurrão: 120 (impulso em px/s, que cai rápido; o monstro anda cerca de 13,3 px).
- Cada inimigo leva o golpe uma vez por anel.
- O anel sai de você e anda com você enquanto cresce.
- Só dispara quando há inimigo perto (até cerca de 340 px). Sem inimigo, ele espera e não gasta a recarga.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 12, recarga 2,4 s, raio 70, empurrão 120 |
| 2 | +4 de dano (16) |
| 3 | +20 de raio (90) |
| 4 | Recarga 0,3 s mais curta (2,1 s) |
| 5 | +6 de dano e +30 de empurrão. Total: dano 22, raio 90, recarga 2,1 s, empurrão 150 |

Nível 5 mostra o total dos quatro aprimoramentos. Uma carta lendária sobe dois níveis de uma vez. A raridade também soma dano: raro +18%, épico +40%, lendário +80%.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta) Maré Lunar:** Onda de Choque no nível 3 + Anel Lunar no nível 3. As duas somem e vira um anel só, mais forte. Usa só o tipo anel, então não precisa de código novo.

**Animação e efeitos:**
- Hoje: um círculo achatado (altura igual a 62% da largura), na cor da arma. A borda de fora tem 3 px e fica mais fraca conforme cresce. Por dentro, um filete branco de 1,5 px acompanha a borda, 4 px para dentro. Não há partículas.
- Especificação do campo "arte" do JSON, para o Alisson substituir:
  - Visual: na tela de 960x540, um anel branco brilhante nasce sob o herói e cresce para fora, com um clarão na frente da onda. Quem é tocado recua.
  - Cores: branco, azul-claro.
  - Tamanho: borda do anel de 4 px que cresce; clarão de 12 px de largura.
  - Duração: 0,5 s de expansão; some em 0,2 s.
  - Provisório: círculo de linha branca de 3 px que cresce e some, sem sprite.

**Mudanças em relação ao desenho original:** o desenho não mudou (segue o PR #192). Número corrigido: o empurrão era lido como px, mas no código ele é um impulso em px/s que cai com exp(-9 t), então o monstro anda cerca de 13,3 px no nível 1 e 16,7 px no nível 5 (peso 1,0), não 120 px. A tabela de níveis usa os valores do código e não mudou.

**Pontos de atenção:**
- Duração: o arte diz 0,5 s de expansão e 0,2 s para sumir. No código, o anel dura o tempo de chegar ao raio (0,27 s no nível 1, 0,35 s no nível 5). Ele não tem o "sumir" depois: some ao chegar à borda.
- O clarão na frente da onda não existe no código.
- Empurrão de 120 no nível 1 é o maior do lote, e chega a 150 no nível 5. Vale confirmar que é o desejado.
- Dano por segundo, com um inimigo só (base): 5,0.
- Nome parecido: o modificador "Corte ondulante" (onda) não é este golpe. A evolução Ventania usa o modificador, não o Onda de Choque.

## Esquemática
- **Gatilho:** dispara quando há pelo menos um inimigo vivo a até 340 px do herói (distância reta). Recarga por nível (1 a 5): 2,4 / 2,4 / 2,4 / 2,1 / 2,1 s, dividida pelo vel_ataque do herói (1,0 por padrão). Sem inimigo, espera 0,3 s e não gasta a recarga. O primeiro disparo sai 0,4 s depois que a arma entra.
- **Alvo:** nenhum. O anel nasce na posição do herói e não mira. O inimigo só serve como condição para disparar.
- **Trajetória e alcance:** nasce no herói e anda com ele. Cresce a 260 px/s (nível 1) e 260 px/s (nível 5) até o raio, que é o alcance: 70 px no nível 1 e 90 px no nível 5 (o campo "alcance" não vale para anel). Chega à borda em 0,27 s (nível 1) e 0,35 s (nível 5), e então some.
- **Área:** faixa em anel achatado: raio horizontal de 70 a 90 px, e vertical de 62% disso. Quem está a até 14 px + o raio do próprio monstro (6 a 9 px nos comuns) da linha do anel leva o golpe. Ou seja, a faixa de acerto tem de 40 a 46 px de largura, bem mais que o traço de 3 px que aparece na tela.
- **Dano por nível:** dano base de cada nível, nas quatro raridades (comum / raro / épico / lendário). A raridade multiplica o dano: raro +18%, épico +40%, lendário +80%, arredondado ao inteiro mais próximo. O multiplicador m_dano do herói é 1,0 por padrão.

| Nível | Dano (comum / raro / épico / lendário) | Como muda |
|---|---|---|
| 1 | 12 / 14 / 17 / 22 | (base) recarga 2,4 s; raio 70 px; velocidade 260 px/s; empurrão 120 px/s |
| 2 | 16 / 19 / 22 / 29 | +4 de dano. Agora: recarga 2,4 s; raio 70 px; velocidade 260 px/s; empurrão 120 px/s |
| 3 | 16 / 19 / 22 / 29 | +20 de raio. Agora: recarga 2,4 s; raio 90 px; velocidade 260 px/s; empurrão 120 px/s |
| 4 | 16 / 19 / 22 / 29 | dispara mais rápido. Agora: recarga 2,1 s; raio 90 px; velocidade 260 px/s; empurrão 120 px/s |
| 5 | 22 / 26 / 31 / 40 | +6 de dano e empurra. Agora: recarga 2,1 s; raio 90 px; velocidade 260 px/s; empurrão 150 px/s |

- **Como aplica:** uma vez por inimigo por anel (o anel guarda quem já foi tocado). Sem tique, sem perfuração, sem explosão.
- **Efeitos de status:**
  - Empurrão: impulso de 120 px/s no nível 1 e 150 px/s no nível 5 (o campo do código). O impulso cai com exp(-9 t), então o monstro anda cerca de 13,3 px (nível 1) e 16,7 px (nível 5), para peso 1,0. Monstro mais pesado anda na razão do peso (o cavaleiro oco, peso 2,6, anda 2,6 vezes menos).
  - Atordoamento: 0,15 s (zero no chefe).
  - Lentidão: nenhuma.
  - Queimadura: nenhuma.
- **Limites na tela:** 1 anel vivo por vez por arma, com vel_ataque 1,0. Só aparece mais de um vivo com vel_ataque acima de 5,3x (menor limite entre os níveis). Os golpes novos dividem um pool de 48 slots (projétil, nuvem, anel, meteoro e aliado). Se o pool estiver cheio, o anel não sai, mas a recarga é gasta do mesmo jeito.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe. 0 s, 0 quadros. O anel nasce já no disparo.
  - Disparo: 1 quadro (0,02 s), raio 0, ainda invisível.
  - Viagem: de 0,27 s (16 quadros) no nível 1 a 0,35 s (21 quadros) no nível 5. A cada quadro o raio cresce 4,3 px (nível 1) ou 4,3 px (nível 5). A opacidade cai junto com o raio (1 − raio/raio máximo).
  - Impacto: por inimigo tocado, flash branco de 0,08 s (5 quadros) e número de dano na cor da arma. O inimigo recua e fica atordoado por 0,15 s (9 quadros). O anel não muda no impacto.
  - Fim: 0 quadros. Some ao chegar ao raio, sem fase de sumir.
  - Tamanho do sprite: hoje não há sprite (o anel é desenhado por arco). Para o pacote: 32x20 px por quadro, 6 quadros. Na tela, a largura vai de 140 a 180 px (2 × raio).
