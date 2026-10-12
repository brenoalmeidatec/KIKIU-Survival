# Estrelas Cadentes (estrelas_cadentes)
**Tipo:** meteoro. **Ícone:** icone_u_estrela_matutina.
**O que faz:** De tempos em tempos, um par de estrelas amarelas cai em pontos perto de inimigos que estão perto de você. Cada uma avisa antes onde vai cair.
**Na prática:** dano 12 (multiplicado pelo bônus de dano do herói). Recarga de 2,2 s. Cai 2 estrelas de cada vez. Raio da queda: 40 px. Aviso no chão: 1,0 s. Cada estrela cai sobre um inimigo perto do herói, escolhido ao acaso. Duas estrelas podem cair no mesmo inimigo. Cartas de raridade maior somam dano a mais nesta arma (raro +18%, épico +40%, lendário +80%).
**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) |
| 2 | +3 de dano (passa a 15) |
| 3 | +1 estrela por queda (passa a cair 3 de cada vez) |
| 4 | +10 de raio (passa a 50 px) |
| 5 | +4 de dano e recarga 0,4 s menor. Lendário sobe 2 níveis de uma vez. Com tudo somado: dano 19, recarga 1,8 s, 3 estrelas, raio 50 px, aviso 1,0 s. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** Eclipse Estelar, com Cometa Negro. Condição: Estrelas Cadentes no nível 3 e Cometa Negro no nível 3. As duas somem e nasce a nova arma. Ideia: a estrela cai dentro da sombra do cometa e explode em luz.

**Animação e efeitos:**
Hoje (placeholder do código): no chão, aparece um círculo da cor da arma que pisca e encolhe durante o aviso, com um miolo que cresce dentro. Uma bola da cor da arma, com um ponto branco no centro, desce do alto até o ponto de queda, durante todo o tempo do aviso. Na queda, aparece um estouro achatado que cresce um pouco e some em 0,3 s. Não há rastro nem faísca.

Especificação do campo arte (para o Alisson trocar o placeholder):
- Visual: estrelas amarelas com rastro brilhante, caindo do alto da tela, duas de cada vez, sobre pontos perto do herói. No chão, cada impacto solta faíscas douradas.
- Cores: amarelo, branco, dourado.
- Tamanho: estrela de 16 px com rastro de 24 px. Impacto de 40 px de raio.
- Duração: queda de 0,3 s e faísca de 0,25 s no impacto. (A queda, no código, dura o aviso inteiro. Ver pontos de atenção.)

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- A arte pede estrela com rastro e faíscas douradas no impacto. O código não tem rastro nem faíscas: a estrela é a mesma bola dos outros meteoros, com o estouro genérico.
- A arte diz "sobre pontos perto do herói". O código joga sobre inimigos perto do herói.
- A queda dura o aviso inteiro (1,0 s). Os 0,3 s da arte não existem no código.
- O campo alcance (200 px) não aparece no código do meteoro. Os alvos saem da lista de monstros perto do herói (até 340 px). O valor não faz nada: o meteoro não lê o alcance (o alvo sai dos 340 px fixos).
- O ponto de queda é escolhido no disparo e não segue o monstro. A lista de alvos traz só monstros vivos e não morrendo (filtro em _juntar_perto, armas.gd). Depois do sorteio o alvo pode morrer; o estouro acerta quem estiver vivo na área.

## Esquemática
- **Gatilho:** a cada 2,2 s no nível 1 (recarga real = recarga / velocidade de ataque do herói; o padrão é 1,0). Dispara quando a recarga zera e há monstro vivo a até 340 px do herói. Sem monstro, espera 0,3 s e não gasta a recarga.
- **Alvo:** cada meteoro do lote sorteia, ao acaso e de forma independente, um monstro vivo e não morrendo a até 340 px do herói (distância simples, sem achatar). O mesmo monstro pode ser sorteado de novo. O ponto de queda é fixado no sorteio: se o monstro andar ou morrer, o ponto não acompanha.
- **Trajetória e alcance:** sem trajetória no chão: a bola desce na vertical, de 80 px acima do ponto até o ponto, durante o aviso inteiro (no nível 1, cerca de 80 px/s). O campo alcance (200 px no nível 1) não existe no meteoro: o código não lê esse valor (não existe hoje). O alvo sai dos 340 px fixos.
- **Área:** círculo no chão de raio 40 px no nível 1 (na tela, elipse com a altura em 62%), mais o raio de cada monstro atingido.
- **Dano por nível:** dano base do código, sem a raridade. O dano que aparece no jogo é esse valor vezes (1 + a soma do bônus de cada carta de golpe desta arma: raro +18%, épico +40%, lendário +80%). Cada carta soma o seu bônus. O dano do herói (m_dano) é 1,0 por padrão. Obs.: carta lendária de golpe novo entra direto no nível 2 (cartas.gd, montar_carta: sobe 2 níveis a partir do 0), e o cartão mostra só "Novo golpe".

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 12 | Base: 2 estrelas, recarga 2,2 s, raio 40 px, aviso 1,0 s. |
| 2 | 15 | +3 de dano. |
| 3 | 15 | +1 estrela: passa a 3 por queda. |
| 4 | 15 | Raio passa a 50 px. |
| 5 | 19 | +4 de dano; recarga cai para 1,8 s. |

- **Como aplica:** uma vez por inimigo por explosão. Cada meteoro que cai dá o dano a todo monstro vivo dentro da área no instante do impacto (ferir arredonda para inteiro, mínimo 1). Sem tique, sem perfuração.
- **Efeitos de status:** empurrão 120 (impulso do código, dividido pelo peso do monstro, para longe do centro do impacto); atordoamento 0,2 s. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** pool de 48 slots (armas_novas.gd, MAX) dividido com todos os golpes novos. Cada meteoro ocupa 1 slot por A + 0,3 s. Com velocidade de ataque 1,0: no máximo 2 meteoro(s) ao mesmo tempo no nível 1 e 3 no nível 5. Se o pool acabar, o lote perde o que não coube, sem aviso.
- **Sequência de animação (quadro a quadro, 60 fps):** sprite de 24x24 px por quadro, 4 quadros em linha (1 e 2 de voo, 3 e 4 de impacto).
  - Antecipação: 0,7 s = 42 quadros (aviso menos queda, no nível 1). Só o círculo no chão, que pisca e encolhe.
  - Queda: 0,3 s = 18 quadros. A bola desce do alto até o ponto.
  - Impacto: 0,25 s = 15 quadros. Estouro achatado (quadros 3 e 4).
  - Fim: some no último quadro do impacto.
  - Hoje no código: a bola desce durante o aviso inteiro (1,0 s), sem antecipação separada, e o estouro dura 0,3 s (18 quadros).
- **Obs.:** Rastro e faíscas douradas não existem hoje: a estrela é a bola genérica do meteoro.
- **Mudanças:** nenhum número mudou: as tabelas batem com dados/v2_cartas.json (golpes) e com v2/armas_novas.gd. Corrigido em Pontos de atenção: o alvo (a lista já traz só monstros vivos e não morrendo, filtro em v2/armas.gd) e o alcance (confirmado: o meteoro não lê esse valor).
