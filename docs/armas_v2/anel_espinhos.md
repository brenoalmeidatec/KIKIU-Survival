# Anel de Espinhos (anel_espinhos)
**Tipo:** anel de choque. **Ícone:** icone_u_clava_espinhos.
**O que faz:** Um anel verde-escuro, cheio de espinhos, fere quem está perto de você. Quem ele toca leva dano e é empurrado muito pouco.
**Na prática:**
- Dano: 12 por inimigo tocado.
- Recarga: 2,0 segundos entre um anel e outro.
- Raio: o anel para em 60 px.
- Velocidade de expansão: 280 px por segundo. Chega à borda em cerca de 0,21 s.
- Empurrão: 12 (impulso em px/s, que cai rápido; o monstro anda cerca de 1,3 px). Quase não empurra.
- Cada inimigo leva o golpe uma vez por anel.
- O anel sai de você e anda com você enquanto cresce.
- Só dispara quando há inimigo perto (até cerca de 340 px). Sem inimigo, ele espera e não gasta a recarga.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 12, recarga 2,0 s, raio 60, empurrão 12 |
| 2 | +4 de dano (16) |
| 3 | +15 de raio (75) |
| 4 | Recarga 0,4 s mais curta (1,6 s) |
| 5 | +6 de dano e +10 de raio. Total: dano 22, raio 85, recarga 1,6 s, empurrão 12 |

Nível 5 mostra o total dos quatro aprimoramentos. Uma carta lendária sobe dois níveis de uma vez. A raridade também soma dano: raro +18%, épico +40%, lendário +80%.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta) Coroa Espinhosa:** Anel de Espinhos no nível 3 + Pulso Sagrado no nível 3. As duas somem e vira um anel só, com espinhos e luz. Usa só o tipo anel.

**Animação e efeitos:**
- Hoje: um círculo achatado (altura igual a 62% da largura), na cor da arma. A borda de fora tem 3 px e fica mais fraca conforme cresce. Por dentro, um filete branco de 1,5 px acompanha a borda, 4 px para dentro. Não há espinhos desenhados.
- Especificação do campo "arte" do JSON, para o Alisson substituir:
  - Visual: na tela de 960x540, um anel verde-escuro com espinhos saindo para fora. Cada espinho se parte ao tocar um inimigo e deixa um pedaço de planta no chão.
  - Cores: verde-escuro, marrom-musgo.
  - Tamanho: borda de 3 px; espinhos de 6 px.
  - Duração: 0,35 s.
  - Provisório: círculo verde-escuro de 3 px com oito traços curtos apontando para fora.

**Mudanças em relação ao desenho original:** o desenho não mudou (segue o PR #192). Número corrigido: o empurrão era lido como px, mas no código ele é um impulso em px/s que cai com exp(-9 t), então o monstro anda cerca de 1,3 px no nível 1 e 1,3 px no nível 5 (peso 1,0), não 12 px. A tabela de níveis usa os valores do código e não mudou.

**Pontos de atenção:**
- O nível 4 diz "+6 de dano e alcance", mas o aumento é no raio (+10). Trocar o texto para "raio" ou "área", para ficar igual aos outros anéis.
- Os espinhos não existem no código. Não há pedaço de planta deixado no chão.
- Duração: o arte pede 0,35 s, mas o código dura 0,21 s no nível 1 (cerca de 0,30 s no nível 5, com raio 85).
- O empurrão é de 12, então o anel é um golpe de contato, não de afastamento. Está de acordo com a ideia de espinhos.
- Dano por segundo, com um inimigo só (base): 6,0.

## Esquemática
- **Gatilho:** dispara quando há pelo menos um inimigo vivo a até 340 px do herói (distância reta). Recarga por nível (1 a 5): 2,0 / 2,0 / 2,0 / 1,6 / 1,6 s, dividida pelo vel_ataque do herói (1,0 por padrão). Sem inimigo, espera 0,3 s e não gasta a recarga. O primeiro disparo sai 0,4 s depois que a arma entra.
- **Alvo:** nenhum. O anel nasce na posição do herói e não mira. O inimigo só serve como condição para disparar.
- **Trajetória e alcance:** nasce no herói e anda com ele. Cresce a 280 px/s (nível 1) e 280 px/s (nível 5) até o raio, que é o alcance: 60 px no nível 1 e 85 px no nível 5 (o campo "alcance" não vale para anel). Chega à borda em 0,21 s (nível 1) e 0,30 s (nível 5), e então some.
- **Área:** faixa em anel achatado: raio horizontal de 60 a 85 px, e vertical de 62% disso. Quem está a até 14 px + o raio do próprio monstro (6 a 9 px nos comuns) da linha do anel leva o golpe. Ou seja, a faixa de acerto tem de 40 a 46 px de largura, bem mais que o traço de 3 px que aparece na tela.
- **Dano por nível:** dano base de cada nível, nas quatro raridades (comum / raro / épico / lendário). A raridade multiplica o dano: raro +18%, épico +40%, lendário +80%, arredondado ao inteiro mais próximo. O multiplicador m_dano do herói é 1,0 por padrão.

| Nível | Dano (comum / raro / épico / lendário) | Como muda |
|---|---|---|
| 1 | 12 / 14 / 17 / 22 | (base) recarga 2,0 s; raio 60 px; velocidade 280 px/s; empurrão 12 px/s |
| 2 | 16 / 19 / 22 / 29 | +4 de dano. Agora: recarga 2,0 s; raio 60 px; velocidade 280 px/s; empurrão 12 px/s |
| 3 | 16 / 19 / 22 / 29 | +15 de raio. Agora: recarga 2,0 s; raio 75 px; velocidade 280 px/s; empurrão 12 px/s |
| 4 | 16 / 19 / 22 / 29 | recarga mais curta. Agora: recarga 1,6 s; raio 75 px; velocidade 280 px/s; empurrão 12 px/s |
| 5 | 22 / 26 / 31 / 40 | +6 de dano e alcance. Agora: recarga 1,6 s; raio 85 px; velocidade 280 px/s; empurrão 12 px/s |

- **Como aplica:** uma vez por inimigo por anel (o anel guarda quem já foi tocado). Sem tique, sem perfuração, sem explosão.
- **Efeitos de status:**
  - Empurrão: impulso de 12 px/s no nível 1 e 12 px/s no nível 5 (o campo do código). O impulso cai com exp(-9 t), então o monstro anda cerca de 1,3 px (nível 1) e 1,3 px (nível 5), para peso 1,0. Monstro mais pesado anda na razão do peso (o cavaleiro oco, peso 2,6, anda 2,6 vezes menos).
  - Atordoamento: 0,15 s (zero no chefe).
  - Lentidão: nenhuma.
  - Queimadura: nenhuma.
- **Limites na tela:** 1 anel vivo por vez por arma, com vel_ataque 1,0. Só aparece mais de um vivo com vel_ataque acima de 4,5x (menor limite entre os níveis). Os golpes novos dividem um pool de 48 slots (projétil, nuvem, anel, meteoro e aliado). Se o pool estiver cheio, o anel não sai, mas a recarga é gasta do mesmo jeito.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe. 0 s, 0 quadros. O anel nasce já no disparo.
  - Disparo: 1 quadro (0,02 s), raio 0, ainda invisível.
  - Viagem: de 0,21 s (13 quadros) no nível 1 a 0,30 s (18 quadros) no nível 5. A cada quadro o raio cresce 4,7 px (nível 1) ou 4,7 px (nível 5). A opacidade cai junto com o raio (1 − raio/raio máximo).
  - Impacto: por inimigo tocado, flash branco de 0,08 s (5 quadros) e número de dano na cor da arma. O inimigo recua e fica atordoado por 0,15 s (9 quadros). O anel não muda no impacto.
  - Fim: 0 quadros. Some ao chegar ao raio, sem fase de sumir.
  - Tamanho do sprite: hoje não há sprite (o anel é desenhado por arco). Para o pacote: 40x26 px por quadro, 6 quadros. Na tela, a largura vai de 120 a 170 px (2 × raio).
