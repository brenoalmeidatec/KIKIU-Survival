# Anel Gelado (anel_gelado)
**Tipo:** anel de choque. **Ícone:** icone_u_bastao_cristal.
**O que faz:** Um anel de gelo sai de você. Ele é fraco, mas dispara sem parar. Quem ele toca leva dano e é empurrado de leve.
**Na prática:**
- Dano: 5 por inimigo tocado.
- Recarga: 1,6 segundo entre um anel e outro.
- Raio: o anel para em 60 px.
- Velocidade de expansão: 240 px por segundo. Chega à borda em cerca de 0,25 s.
- Empurrão: 25 (impulso em px/s, que cai rápido; o monstro anda cerca de 2,8 px).
- Cada inimigo leva o golpe uma vez por anel.
- O anel sai de você e anda com você enquanto cresce.
- Só dispara quando há inimigo perto (até cerca de 340 px). Sem inimigo, ele espera e não gasta a recarga.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 5, recarga 1,6 s, raio 60, empurrão 25 |
| 2 | +2 de dano (7) |
| 3 | +12 de raio (72) |
| 4 | Recarga 0,3 s mais curta (1,3 s) |
| 5 | +3 de dano e +10 de empurrão. Total: dano 10, raio 72, recarga 1,3 s, empurrão 35. O texto diz "deixa lento", mas nada disso está no código (ver pontos de atenção) |

Nível 5 mostra o total dos quatro aprimoramentos. Uma carta lendária sobe dois níveis de uma vez. A raridade também soma dano: raro +18%, épico +40%, lendário +80%.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta) Chão Congelado:** Anel Gelado no nível 3 + Terremoto no nível 3. As duas somem e vira um anel só, que congela o chão onde cai. Usa só o tipo anel.

**Animação e efeitos:**
- Hoje: um círculo achatado (altura igual a 62% da largura), na cor da arma. A borda de fora tem 3 px e fica mais fraca conforme cresce. Por dentro, um filete branco de 1,5 px acompanha a borda, 4 px para dentro. Não há cristais nem gelo nos inimigos.
- Especificação do campo "arte" do JSON, para o Alisson substituir:
  - Visual: na tela de 960x540, um anel azul-gelo com cristais brancos na borda. Quem é tocado ganha uma camada de gelo nos pés, anda devagar e o gelo racha ao sumir.
  - Cores: azul-gelo, branco.
  - Tamanho: borda de 3 px; cristais de 4 px.
  - Duração: 0,4 s de expansão; o gelo dura o tempo do encontro.
  - Provisório: círculo azul de 3 px com quatro traços brancos na borda que cresce e some.

**Mudanças em relação ao desenho original:** o desenho não mudou (segue o PR #192). Número corrigido: o empurrão era lido como px, mas no código ele é um impulso em px/s que cai com exp(-9 t), então o monstro anda cerca de 2,8 px no nível 1 e 3,9 px no nível 5 (peso 1,0), não 25 px. A tabela de níveis usa os valores do código e não mudou.

**Pontos de atenção:**
- Lentidão não existe no anel. O nível 5 diz "deixa lento" e o arte fala em gelo nos pés, mas o código do anel não aplica lentidão. A única lentidão do código está nas nuvens. Hoje o nível 5 só dá dano e empurrão. Decidir: ou tirar o "deixa lento" do texto, ou criar a lentidão para o anel (é código novo).
- Duração: o arte pede 0,4 s, mas o código dura 0,25 s no nível 1 e 0,30 s no nível 5.
- Cristais e gelo que racha não existem no código.
- Dano por segundo, com um inimigo só (base): 3,1. É um dos mais fracos do lote de anéis.

## Esquemática
- **Gatilho:** dispara quando há pelo menos um inimigo vivo a até 340 px do herói (distância reta). Recarga por nível (1 a 5): 1,6 / 1,6 / 1,6 / 1,3 / 1,3 s, dividida pelo vel_ataque do herói (1,0 por padrão). Sem inimigo, espera 0,3 s e não gasta a recarga. O primeiro disparo sai 0,4 s depois que a arma entra.
- **Alvo:** nenhum. O anel nasce na posição do herói e não mira. O inimigo só serve como condição para disparar.
- **Trajetória e alcance:** nasce no herói e anda com ele. Cresce a 240 px/s (nível 1) e 240 px/s (nível 5) até o raio, que é o alcance: 60 px no nível 1 e 72 px no nível 5 (o campo "alcance" não vale para anel). Chega à borda em 0,25 s (nível 1) e 0,30 s (nível 5), e então some.
- **Área:** faixa em anel achatado: raio horizontal de 60 a 72 px, e vertical de 62% disso. Quem está a até 14 px + o raio do próprio monstro (6 a 9 px nos comuns) da linha do anel leva o golpe. Ou seja, a faixa de acerto tem de 40 a 46 px de largura, bem mais que o traço de 3 px que aparece na tela.
- **Dano por nível:** dano base de cada nível, nas quatro raridades (comum / raro / épico / lendário). A raridade multiplica o dano: raro +18%, épico +40%, lendário +80%, arredondado ao inteiro mais próximo. O multiplicador m_dano do herói é 1,0 por padrão.

| Nível | Dano (comum / raro / épico / lendário) | Como muda |
|---|---|---|
| 1 | 5 / 6 / 7 / 9 | (base) recarga 1,6 s; raio 60 px; velocidade 240 px/s; empurrão 25 px/s |
| 2 | 7 / 8 / 10 / 13 | +2 de dano. Agora: recarga 1,6 s; raio 60 px; velocidade 240 px/s; empurrão 25 px/s |
| 3 | 7 / 8 / 10 / 13 | +12 de raio. Agora: recarga 1,6 s; raio 72 px; velocidade 240 px/s; empurrão 25 px/s |
| 4 | 7 / 8 / 10 / 13 | dispara mais rápido. Agora: recarga 1,3 s; raio 72 px; velocidade 240 px/s; empurrão 25 px/s |
| 5 | 10 / 12 / 14 / 18 | +3 de dano e "deixa lento" (no código só sobe o empurrão, +10; lentidão não existe). Agora: recarga 1,3 s; raio 72 px; velocidade 240 px/s; empurrão 35 px/s |

- **Como aplica:** uma vez por inimigo por anel (o anel guarda quem já foi tocado). Sem tique, sem perfuração, sem explosão.
- **Efeitos de status:**
  - Empurrão: impulso de 25 px/s no nível 1 e 35 px/s no nível 5 (o campo do código). O impulso cai com exp(-9 t), então o monstro anda cerca de 2,8 px (nível 1) e 3,9 px (nível 5), para peso 1,0. Monstro mais pesado anda na razão do peso (o cavaleiro oco, peso 2,6, anda 2,6 vezes menos).
  - Atordoamento: 0,15 s (zero no chefe).
  - Lentidão: nenhuma no código (o anel não tem campo de lentidão). O texto "deixa lento" do nível 5 não tem efeito: ver Mudanças.
  - Queimadura: nenhuma.
- **Limites na tela:** 1 anel vivo por vez por arma, com vel_ataque 1,0. Só aparece mais de um vivo com vel_ataque acima de 3,7x (menor limite entre os níveis). Os golpes novos dividem um pool de 48 slots (projétil, nuvem, anel, meteoro e aliado). Se o pool estiver cheio, o anel não sai, mas a recarga é gasta do mesmo jeito.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe. 0 s, 0 quadros. O anel nasce já no disparo.
  - Disparo: 1 quadro (0,02 s), raio 0, ainda invisível.
  - Viagem: de 0,25 s (15 quadros) no nível 1 a 0,30 s (18 quadros) no nível 5. A cada quadro o raio cresce 4,0 px (nível 1) ou 4,0 px (nível 5). A opacidade cai junto com o raio (1 − raio/raio máximo).
  - Impacto: por inimigo tocado, flash branco de 0,08 s (5 quadros) e número de dano na cor da arma. O inimigo recua e fica atordoado por 0,15 s (9 quadros). O anel não muda no impacto.
  - Fim: 0 quadros. Some ao chegar ao raio, sem fase de sumir.
  - Tamanho do sprite: hoje não há sprite (o anel é desenhado por arco). Para o pacote: 32x20 px por quadro, 6 quadros. Na tela, a largura vai de 120 a 144 px (2 × raio).
