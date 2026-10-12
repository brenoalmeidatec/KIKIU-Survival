# Revoada de Trovões (fusão revoada_de_trovoes)

**Peças:** Corvos Famintos (nível 3) + Raio em Cadeia (nível 3). Fichas: corvos.md, raio.md.

**Vira:** um bando de 7 corvos elétricos, no lugar dos Corvos e do Raio em Cadeia (as duas peças saem do sorteio). Cada bicada solta um arco elétrico no inimigo vizinho.

**O que faz:** o bando de corvos caça os inimigos perto do herói. Cada bicada também solta um raio no inimigo mais perto do que foi bicado.

**Como liberar:** pegue 3 cartas de Corvos Famintos e 3 de Raio em Cadeia. Quando as duas estão no nível 3, a fusão acontece na hora (anúncio EVOLUÇÃO) e as duas peças saem do sorteio. Enquanto falta uma delas, a outra aparece com o rodapé "Evolui: Revoada de Trovões" e pesa mais no sorteio.

## Esquemática
- **Gatilho:** a cada 3,0 s, dividido pela velocidade de ataque do herói (com 1,0 são 3,0 s). Só dispara com inimigo a até 340 px do herói. Sem inimigo, espera 0,3 s e não gasta a recarga. Cada disparo solta 7 corvos.
- **Alvo:** cada corvo escolhe o inimigo mais perto dele, dentro de 300 px do herói (um pequeno desvio por corvo evita que todos vão para o mesmo). Reescolhe a cada 0,3 s. Sem alvo, o corvo circula o herói a 44 px.
- **Trajetória e alcance:** o corvo voa a 270 px/s (com suavização). A altura varia: 34 px ao nascer, 30 px sobrevoando e 9 px ao bicar.
- **Área:** nenhuma para a bicada (um alvo por bicada). O arco elétrico vai até 64 px do alvo da bicada.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 5 (fixo) | 14 por bicada; 8 pelo arco elétrico (60% da bicada) | Base do registro. O bônus de raridade (cada carta de peça soma o bônus da sua raridade: raro +18%, épico +40%, lendário +80%; a fusão usa o maior bônus entre as peças consumidas) multiplica a bicada e o arco: bicada 14 comum, 17 raro, 20 épico, 25 lendário; arco 8, 10, 12 e 15. |

  O multiplicador de dano do herói (m_dano) é 1,0 por padrão, e o dano final é esse número vezes m_dano.
- **Como aplica:** por corvo, uma bicada a cada 0,35 s enquanto o alvo estiver dentro de 16 px + raio do inimigo. O intervalo é fixo: a velocidade de ataque não encurta. O arco elétrico sai uma vez por bicada, em um único inimigo vizinho (sem encadear).
- **Efeitos de status:**
  - Bicada: empurrão 20 px; atordoamento 0,12 s.
  - Arco elétrico: empurrão 30 px; atordoamento 0,1 s.
  - Queimadura, lentidão: nenhum.
- **Limites na tela:** 16 corvos ao mesmo tempo (MAX_CORVOS, o mesmo pool dos corvos comuns, que somem com a fusão). Cada disparo traz 7 e cada corvo dura 6,5 s. Como o disparo cabe em 3 ciclos, o teto de 16 juntos é atingido na prática: o último disparo traz só o que couber.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: nenhuma. O corvo nasce em volta do herói, 34 px acima do chão; sai uma faísca roxa de 0,3 s (18 quadros).
  - Disparo: nenhum (o corvo sai direto do nascimento).
  - Viagem: voo até o alvo. Com 300 px de distância, cerca de 1,1 s (66 quadros). Asas em 3 quadros (cima, meio, baixo), trocados pela fase do bater de asas (17 rad/s).
  - Impacto: a bicada sobe o corvo 6 px e faz 3 faíscas roxas. O intervalo de 0,35 s dá 21 quadros entre bicadas.
  - Fim: aos 6,5 s, o corvo some com partículas de 0,3 s (18 quadros).
  - Tamanho do sprite: 22 x 18 px por quadro, 3 quadros (textura atual, 66 x 18 px).

**Mudanças:** Nenhuma.
