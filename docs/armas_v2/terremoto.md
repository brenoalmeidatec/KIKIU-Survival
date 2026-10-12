# Terremoto (terremoto)
**Tipo:** anel de choque. **Ícone:** icone_u_machado_guerra.
**O que faz:** Um anel marrom, rente ao chão, racha o solo de tempos em tempos. Quem ele toca leva muito dano e quase não é empurrado.
**Na prática:**
- Dano: 22 por inimigo tocado, o maior dano por golpe entre os anéis deste lote.
- Recarga: 4,5 segundos entre um tremor e outro.
- Raio: o anel para em 75 px.
- Velocidade de expansão: 220 px por segundo. Chega à borda em cerca de 0,34 s.
- Empurrão: 10 (impulso em px/s, que cai rápido; o monstro anda cerca de 1,1 px). Quase não empurra.
- Cada inimigo leva o golpe uma vez por tremor.
- O anel sai de você e anda com você enquanto cresce.
- Só dispara quando há inimigo perto (até cerca de 340 px). Sem inimigo, ele espera e não gasta a recarga.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 22, recarga 4,5 s, raio 75, empurrão 10 |
| 2 | +6 de dano (28) |
| 3 | +15 de raio (90) |
| 4 | Recarga 0,4 s mais curta (4,1 s) |
| 5 | +8 de dano e +10 de empurrão. Total: dano 36, raio 90, recarga 4,1 s, empurrão 20 |

Nível 5 mostra o total dos quatro aprimoramentos. Uma carta lendária sobe dois níveis de uma vez. A raridade também soma dano: raro +18%, épico +40%, lendário +80%.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta) Chão Congelado:** Terremoto no nível 3 + Anel Gelado no nível 3. As duas somem e vira um anel só, que congela o chão onde cai. Usa só o tipo anel.

**Animação e efeitos:**
- Hoje: um círculo achatado (altura igual a 62% da largura), na cor da arma. A borda de fora tem 3 px e fica mais fraca conforme cresce. Por dentro, um filete branco de 1,5 px acompanha a borda, 4 px para dentro. Não há poeira nem pedras.
- Especificação do campo "arte" do JSON, para o Alisson substituir:
  - Visual: na tela de 960x540, uma elipse marrom achatada, como poeira e pedras levantadas rente ao chão. Só a base aparece, sem altura, com pedras que saltam na borda.
  - Cores: marrom-terra, cinza-pedra.
  - Tamanho: elipse achatada de borda 5 px; pedras de 4 px.
  - Duração: 0,6 s.
  - Provisório: elipse marrom achatada de 5 px que cresce e some, com três pontos de poeira.

**Mudanças em relação ao desenho original:** o desenho não mudou (segue o PR #192). Número corrigido: o empurrão era lido como px, mas no código ele é um impulso em px/s que cai com exp(-9 t), então o monstro anda cerca de 1,1 px no nível 1 e 2,2 px no nível 5 (peso 1,0), não 10 px. A tabela de níveis usa os valores do código e não mudou.

**Pontos de atenção:**
- Ele já é desenhado achatado, então parece chão. A poeira e as pedras são o que falta.
- O "racha o solo" da descrição não existe no código. Não há rachadura nem efeito no chão.
- Duração: o arte pede 0,6 s, mas o código dura 0,34 s no nível 1 (0,41 s no nível 5, com raio 90 e velocidade 220).
- Empurrão 10 no nível 1, mas 20 no nível 5. Junto com o Anel de Espinhos, é um dos que quase não empurram; vale confirmar se é a intenção.
- Dano por segundo, com um inimigo só (base): 4,9.

## Esquemática
- **Gatilho:** dispara quando há pelo menos um inimigo vivo a até 340 px do herói (distância reta). Recarga por nível (1 a 5): 4,5 / 4,5 / 4,5 / 4,1 / 4,1 s, dividida pelo vel_ataque do herói (1,0 por padrão). Sem inimigo, espera 0,3 s e não gasta a recarga. O primeiro disparo sai 0,4 s depois que a arma entra.
- **Alvo:** nenhum. O anel nasce na posição do herói e não mira. O inimigo só serve como condição para disparar.
- **Trajetória e alcance:** nasce no herói e anda com ele. Cresce a 220 px/s (nível 1) e 220 px/s (nível 5) até o raio, que é o alcance: 75 px no nível 1 e 90 px no nível 5 (o campo "alcance" não vale para anel). Chega à borda em 0,34 s (nível 1) e 0,41 s (nível 5), e então some.
- **Área:** faixa em anel achatado: raio horizontal de 75 a 90 px, e vertical de 62% disso. Quem está a até 14 px + o raio do próprio monstro (6 a 9 px nos comuns) da linha do anel leva o golpe. Ou seja, a faixa de acerto tem de 40 a 46 px de largura, bem mais que o traço de 3 px que aparece na tela.
- **Dano por nível:** dano base de cada nível, nas quatro raridades (comum / raro / épico / lendário). A raridade multiplica o dano: raro +18%, épico +40%, lendário +80%, arredondado ao inteiro mais próximo. O multiplicador m_dano do herói é 1,0 por padrão.

| Nível | Dano (comum / raro / épico / lendário) | Como muda |
|---|---|---|
| 1 | 22 / 26 / 31 / 40 | (base) recarga 4,5 s; raio 75 px; velocidade 220 px/s; empurrão 10 px/s |
| 2 | 28 / 33 / 39 / 50 | +6 de dano. Agora: recarga 4,5 s; raio 75 px; velocidade 220 px/s; empurrão 10 px/s |
| 3 | 28 / 33 / 39 / 50 | +15 de raio. Agora: recarga 4,5 s; raio 90 px; velocidade 220 px/s; empurrão 10 px/s |
| 4 | 28 / 33 / 39 / 50 | recarrega mais rápido. Agora: recarga 4,1 s; raio 90 px; velocidade 220 px/s; empurrão 10 px/s |
| 5 | 36 / 42 / 50 / 65 | +8 de dano e empurra. Agora: recarga 4,1 s; raio 90 px; velocidade 220 px/s; empurrão 20 px/s |

- **Como aplica:** uma vez por inimigo por anel (o anel guarda quem já foi tocado). Sem tique, sem perfuração, sem explosão.
- **Efeitos de status:**
  - Empurrão: impulso de 10 px/s no nível 1 e 20 px/s no nível 5 (o campo do código). O impulso cai com exp(-9 t), então o monstro anda cerca de 1,1 px (nível 1) e 2,2 px (nível 5), para peso 1,0. Monstro mais pesado anda na razão do peso (o cavaleiro oco, peso 2,6, anda 2,6 vezes menos).
  - Atordoamento: 0,15 s (zero no chefe).
  - Lentidão: nenhuma.
  - Queimadura: nenhuma.
- **Limites na tela:** 1 anel vivo por vez por arma, com vel_ataque 1,0. Só aparece mais de um vivo com vel_ataque acima de 8,9x (menor limite entre os níveis). Os golpes novos dividem um pool de 48 slots (projétil, nuvem, anel, meteoro e aliado). Se o pool estiver cheio, o anel não sai, mas a recarga é gasta do mesmo jeito.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe. 0 s, 0 quadros. O anel nasce já no disparo.
  - Disparo: 1 quadro (0,02 s), raio 0, ainda invisível.
  - Viagem: de 0,34 s (20 quadros) no nível 1 a 0,41 s (25 quadros) no nível 5. A cada quadro o raio cresce 3,7 px (nível 1) ou 3,7 px (nível 5). A opacidade cai junto com o raio (1 − raio/raio máximo).
  - Impacto: por inimigo tocado, flash branco de 0,08 s (5 quadros) e número de dano na cor da arma. O inimigo recua e fica atordoado por 0,15 s (9 quadros). O anel não muda no impacto.
  - Fim: 0 quadros. Some ao chegar ao raio, sem fase de sumir.
  - Tamanho do sprite: hoje não há sprite (o anel é desenhado por arco). Para o pacote: 40x24 px por quadro, 6 quadros. Na tela, a largura vai de 150 a 180 px (2 × raio).
