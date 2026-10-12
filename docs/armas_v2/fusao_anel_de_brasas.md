# Anel de Brasas (fusão anel_de_brasas)

**Peças:** Aura de Fogo (nível 3) + Lâminas Rodopiantes (nível 3). Fichas: aura_fogo.md, laminas.md.

**Vira:** uma órbita só de 6 lâminas de brasa, com a aura de fogo junto. Ela aparece no lugar da Aura de Fogo e das Lâminas (as duas saem do sorteio). As lâminas ficam com o brilho mais forte que o normal.

**O que faz:** seis lâminas em brasa giram em volta do herói e queimam quem encosta. Ao mesmo tempo, a aura de fogo queima e empurra quem chega perto.

**Como liberar:** pegue 3 cartas de Aura de Fogo e 3 de Lâminas Rodopiantes. Quando as duas estão no nível 3, a fusão acontece na hora (anúncio EVOLUÇÃO) e as duas peças saem do sorteio. Enquanto falta uma delas, a outra aparece com o rodapé "Evolui: Anel de Brasas" e pesa mais no sorteio.

## Esquemática
- **Gatilho:** não tem. A órbita começa a girar assim que a fusão acontece e não tem recarga. A aura dá um tique a cada 0,5 s (dividido pela velocidade de ataque do herói; com 1,0 são 0,5 s).
- **Alvo:** nenhum. As lâminas giram em volta do herói e acertam quem encostar. Só contam os inimigos a até 340 px do herói.
- **Trajetória e alcance:** as 6 lâminas ficam num círculo de raio 62 px em volta do herói (o centro fica 3 px acima dos pés). O círculo é achatado no chão (y vale 62% do x). Giro de 3,6 rad/s: uma volta a cada 1,75 s (105 quadros). Cada lâmina varre do meio do círculo até a ponta. A aura tem raio 56 px (mesma forma achatada).
- **Área:** a órbita é uma faixa de 62 px de raio; a aura é um círculo de 56 px de raio no chão (elipse de 112 x 70 px na tela). Com área 1,0 (padrão).
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 5 (fixo) | 17 por acerto de lâmina; 9 por tique da aura | Base do registro. O bônus de raridade (cada carta de peça soma o bônus da sua raridade: raro +18%, épico +40%, lendário +80%; a fusão usa o maior bônus entre as peças consumidas) multiplica só o dano da lâmina: 17 comum, 20 raro, 24 épico, 31 lendário. O dano da aura não recebe bônus (ver "Como aplica"). |

  O multiplicador de dano do herói (m_dano) é 1,0 por padrão, e o dano final é esse número vezes m_dano.
- **Como aplica:** lâminas: por tique, cada inimigo leva no máximo um golpe de lâmina a cada 0,35 s (dividido pela velocidade de ataque). Aura: por tique de 0,5 s, em todo inimigo dentro do círculo. Obs. do código: `adicionar_evoluida` multiplica só `dano`, então o `aura_dano` (9) não recebe o bônus de raridade.
- **Efeitos de status:**
  - Lâmina: empurrão 45 px; atordoamento 0,1 s; queimadura de 7 por s durante 2,5 s (renovada a cada acerto).
  - Aura: empurrão 40 px; atordoamento 0,08 s; queimadura de 7 por s durante 2,5 s (renovada a cada tique).
  - Lentidão: nenhuma.
- **Limites na tela:** 6 lâminas e 1 aura, fixos. A fusão não usa o pool de 48 golpes novos nem os limites de corvos, runas, ondas ou raios.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: nenhuma (a órbita aparece já girando).
  - Disparo: nenhum (é contínuo).
  - Viagem (giro): 1 volta = 1,75 s = 105 quadros; as lâminas ficam separadas por 60°.
  - Impacto (tique da aura, a cada 30 quadros): o pulso da aura vale 1 e cai em 20 quadros (0,33 s). Por tique da aura saem até 3 faíscas de brasa, de 18 a 36 quadros (0,3 a 0,6 s). Lâmina acertada: o número de dano sobe e o inimigo pisca 0,08 s (feito por `ferir`); não há faísca própria da lâmina. O mesmo inimigo só leva nova lâmina depois de 0,35 s (21 quadros).
  - Fim: nenhum. A órbita dura a partida inteira.
  - Tamanho do sprite: lâmina de 26 x 11 px (textura atual). Aura: círculo de 112 x 70 px na tela.

**Mudanças:** Nenhuma.
