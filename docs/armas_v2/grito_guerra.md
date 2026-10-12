# Grito de Guerra (grito_guerra)
**Tipo:** anel de choque. **Ícone:** icone_u_sino_ferro.
**O que faz:** Um anel vermelho, grosso e lento, sai de você de tempos em tempos e se espalha até uma área grande. Quem ele toca leva muito dano e é empurrado com força.
**Na prática:**
- Dano: 14 por inimigo tocado.
- Recarga: 4,0 segundos entre um grito e outro.
- Raio: o anel para em 100 px, a segunda maior do lote, atrás só do Anel Lunar (110).
- Velocidade de expansão: 160 px por segundo. É o mais lento: chega à borda em cerca de 0,63 s.
- Empurrão: 60 (impulso em px/s, que cai rápido; o monstro anda cerca de 6,7 px).
- Cada inimigo leva o golpe uma vez por grito.
- O anel sai de você e anda com você enquanto cresce.
- Só dispara quando há inimigo perto (até cerca de 340 px). Sem inimigo, ele espera e não gasta a recarga.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) dano 14, recarga 4,0 s, raio 100, empurrão 60 |
| 2 | +5 de dano (19) |
| 3 | +10 de raio (110) e +20 de empurrão (80) |
| 4 | +7 de dano e recarga 0,4 s mais curta (3,6 s) |
| 5 | +5 de dano e +10 de empurrão. Total: dano 31, raio 110, recarga 3,6 s, empurrão 90 |

Nível 5 mostra o total dos quatro aprimoramentos. Uma carta lendária sobe dois níveis de uma vez. A raridade também soma dano: raro +18%, épico +40%, lendário +80%.

**Fusões e evoluções:** Sem fusão hoje.
**(proposta) Grito de Caça:** Grito de Guerra no nível 3 + Fôlego de caçador no nível 2. Consome só o Grito de Guerra; o modificador fica. Cada abate do grito devolve fôlego. Precisa de código novo, porque hoje o anel não avisa a katana de abates.

**Animação e efeitos:**
- Hoje: um círculo achatado (altura igual a 62% da largura), na cor da arma. A borda de fora tem 3 px e fica mais fraca conforme cresce. Por dentro, um filete branco de 1,5 px acompanha a borda, 4 px para dentro.
- Especificação do campo "arte" do JSON, para o Alisson substituir:
  - Visual: na tela de 960x540, um anel vermelho grosso e lento que se espalha como onda de grito, com linhas de vento vermelho por dentro. Expande devagar até a borda da área.
  - Cores: vermelho, carmim.
  - Tamanho: borda de 6 px; linhas internas de 2 px.
  - Duração: 0,8 s de expansão.
  - Provisório: círculo vermelho de 6 px de espessura que cresce devagar e some.

**Mudanças em relação ao desenho original:** o desenho não mudou (segue o PR #192). Número corrigido: o empurrão era lido como px, mas no código ele é um impulso em px/s que cai com exp(-9 t), então o monstro anda cerca de 6,7 px no nível 1 e 10,0 px no nível 5 (peso 1,0), não 60 px. A tabela de níveis usa os valores do código e não mudou.

**Pontos de atenção:**
- A borda do desenho hoje é de 3 px, e o arte pede 6 px. Quem decide é o Alisson, na arte.
- As "linhas de vento vermelho" não existem. Hoje há um filete branco só.
- Duração: o arte pede 0,8 s, e o código dura 0,63 s no nível 1 (0,69 s no nível 5, com raio 110 e velocidade 160).
- Dano por segundo, com um inimigo só (base): 3,5. Quem o grito pega fica com a área grande, então o valor real depende de quantos inimigos entram no anel.

## Esquemática
- **Gatilho:** dispara quando há pelo menos um inimigo vivo a até 340 px do herói (distância reta). Recarga por nível (1 a 5): 4,0 / 4,0 / 4,0 / 3,6 / 3,6 s, dividida pelo vel_ataque do herói (1,0 por padrão). Sem inimigo, espera 0,3 s e não gasta a recarga. O primeiro disparo sai 0,4 s depois que a arma entra.
- **Alvo:** nenhum. O anel nasce na posição do herói e não mira. O inimigo só serve como condição para disparar.
- **Trajetória e alcance:** nasce no herói e anda com ele. Cresce a 160 px/s (nível 1) e 160 px/s (nível 5) até o raio, que é o alcance: 100 px no nível 1 e 110 px no nível 5 (o campo "alcance" não vale para anel). Chega à borda em 0,62 s (nível 1) e 0,69 s (nível 5), e então some.
- **Área:** faixa em anel achatado: raio horizontal de 100 a 110 px, e vertical de 62% disso. Quem está a até 14 px + o raio do próprio monstro (6 a 9 px nos comuns) da linha do anel leva o golpe. Ou seja, a faixa de acerto tem de 40 a 46 px de largura, bem mais que o traço de 3 px que aparece na tela.
- **Dano por nível:** dano base de cada nível, nas quatro raridades (comum / raro / épico / lendário). A raridade multiplica o dano: raro +18%, épico +40%, lendário +80%, arredondado ao inteiro mais próximo. O multiplicador m_dano do herói é 1,0 por padrão.

| Nível | Dano (comum / raro / épico / lendário) | Como muda |
|---|---|---|
| 1 | 14 / 17 / 20 / 25 | (base) recarga 4,0 s; raio 100 px; velocidade 160 px/s; empurrão 60 px/s |
| 2 | 19 / 22 / 27 / 34 | +5 de dano. Agora: recarga 4,0 s; raio 100 px; velocidade 160 px/s; empurrão 60 px/s |
| 3 | 19 / 22 / 27 / 34 | +10 de raio e empurra. Agora: recarga 4,0 s; raio 110 px; velocidade 160 px/s; empurrão 80 px/s |
| 4 | 26 / 31 / 36 / 47 | +7 de dano e recarrega. Agora: recarga 3,6 s; raio 110 px; velocidade 160 px/s; empurrão 80 px/s |
| 5 | 31 / 37 / 43 / 56 | +5 de dano e empurra. Agora: recarga 3,6 s; raio 110 px; velocidade 160 px/s; empurrão 90 px/s |

- **Como aplica:** uma vez por inimigo por anel (o anel guarda quem já foi tocado). Sem tique, sem perfuração, sem explosão.
- **Efeitos de status:**
  - Empurrão: impulso de 60 px/s no nível 1 e 90 px/s no nível 5 (o campo do código). O impulso cai com exp(-9 t), então o monstro anda cerca de 6,7 px (nível 1) e 10,0 px (nível 5), para peso 1,0. Monstro mais pesado anda na razão do peso (o cavaleiro oco, peso 2,6, anda 2,6 vezes menos).
  - Atordoamento: 0,15 s (zero no chefe).
  - Lentidão: nenhuma.
  - Queimadura: nenhuma.
- **Limites na tela:** 1 anel vivo por vez por arma, com vel_ataque 1,0. Só aparece mais de um vivo com vel_ataque acima de 4,9x (menor limite entre os níveis). Os golpes novos dividem um pool de 48 slots (projétil, nuvem, anel, meteoro e aliado). Se o pool estiver cheio, o anel não sai, mas a recarga é gasta do mesmo jeito.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: não existe. 0 s, 0 quadros. O anel nasce já no disparo.
  - Disparo: 1 quadro (0,02 s), raio 0, ainda invisível.
  - Viagem: de 0,62 s (38 quadros) no nível 1 a 0,69 s (41 quadros) no nível 5. A cada quadro o raio cresce 2,7 px (nível 1) ou 2,7 px (nível 5). A opacidade cai junto com o raio (1 − raio/raio máximo).
  - Impacto: por inimigo tocado, flash branco de 0,08 s (5 quadros) e número de dano na cor da arma. O inimigo recua e fica atordoado por 0,15 s (9 quadros). O anel não muda no impacto.
  - Fim: 0 quadros. Some ao chegar ao raio, sem fase de sumir.
  - Tamanho do sprite: hoje não há sprite (o anel é desenhado por arco). Para o pacote: 48x30 px por quadro, 6 quadros. Na tela, a largura vai de 200 a 220 px (2 × raio).
