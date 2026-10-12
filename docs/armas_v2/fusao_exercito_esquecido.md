# Exército Esquecido (fusão exercito_esquecido)

**Peças:** Esqueleto Guerreiro (nível 3) + Fantasma da Mata (nível 3). Fichas: esqueleto_guerreiro.md, fantasma_mata.md.

**Vira:** quatro espíritos aliados (esqueletos e fantasmas, um golpe secundário novo) que saem juntos. Substituem o Esqueleto e o Fantasma, que saem do sorteio.

**O que faz:** esqueletos e fantasmas saem do chão juntos e perseguem o inimigo mais perto, ferindo ao tocar.

**Como liberar:** pegue 3 cartas de Esqueleto Guerreiro e 3 de Fantasma da Mata. Quando as duas estão no nível 3, a fusão acontece na hora (anúncio EVOLUÇÃO) e as duas peças saem do sorteio. Enquanto falta uma delas, a que falta aparece com o rodapé "Evolui: Exército Esquecido" e pesa mais no sorteio.

## Esquemática
- **Gatilho:** a cada 2,8 s, dividido pela velocidade de ataque do herói (com 1,0 são 2,8 s). Invoca 4 espíritos de uma vez. Só dispara com inimigo a até 340 px do herói. Sem inimigo, espera 0,3 s e não gasta a recarga.
- **Alvo:** cada espírito persegue o inimigo mais perto dele, dentro de 400 px, e reescolhe a cada quadro. Vários podem ir para o mesmo inimigo. Sem inimigo por perto, o espírito gira em volta do herói a 50 px.
- **Trajetória e alcance:** voa reto em direção ao alvo a 180 px/s. Nasce em volta do herói (até 30 px para os lados e 20 px para cima ou para baixo). Dura 5 s, sem limite de distância.
- **Área:** nenhuma. O contato é um raio de 12 px mais o raio do inimigo (achatado no chão).
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 5 (fixo) | 13 por toque | Base do registro. O bônus de raridade (cada carta de peça soma o bônus da sua raridade: raro +18%, épico +40%, lendário +80%; a fusão usa o maior bônus entre as peças consumidas) multiplica o dano: 13 comum, 15 raro, 18 épico, 23 lendário. |

  O multiplicador de dano do herói (m_dano) é 1,0 por padrão, e o dano final é esse número vezes m_dano.
- **Como aplica:** por tique de 0,5 s por espírito, enquanto ele encosta no alvo. O primeiro toque é imediato. Cada espírito tem o seu próprio tique.
- **Efeitos de status:** empurrão de 30 px e atordoamento de 0,05 s. Queimadura: nenhuma. Lentidão: nenhuma.
- **Limites na tela:** 4 espíritos por invocação, e cada um dura 5 s. Com recarga de 2,8 s, o normal são 2 invocações juntas, ou seja, até 8 espíritos. Eles dividem o pool de 48 golpes novos com os outros golpes novos.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: nenhuma no código (no desenho previsto, o esqueleto sai do chão; hoje o espírito aparece direto).
  - Disparo: nenhum (sai no quadro da invocação).
  - Viagem: voo reto até o alvo, a 180 px/s. Balanço de 2 px, com período de 1,05 s (63 quadros).
  - Impacto: cada tique de 0,5 s (30 quadros). No contato, o espírito fica no inimigo e bate de novo quando o tique zera.
  - Fim: nos últimos 0,5 s (30 quadros) de vida, o brilho cai de 100% para 0%.
  - Tamanho do sprite: 24 x 28 px (o brilho atual tem 20 x 20 px).

**Mudanças:** Implementada sem balanço fino: os números são os do registro (dados/v2_cartas.json), sem ajuste de teste.
