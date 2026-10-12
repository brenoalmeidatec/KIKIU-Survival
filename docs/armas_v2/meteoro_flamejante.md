# Meteoro Flamejante (meteoro_flamejante)
**Tipo:** meteoro. **Ícone:** icone_u_frasco_incendiario.
**O que faz:** De tempos em tempos, um meteoro de fogo cai perto de um inimigo que está perto de você. Antes da queda, o chão mostra o ponto onde ele vai bater.
**Na prática:** dano 22 (multiplicado pelo bônus de dano do herói). Recarga de 3,0 s. Cai 1 meteoro de cada vez. Raio da queda: 50 px. Aviso no chão: 1,2 s. Ele cai sobre um inimigo perto do herói, escolhido ao acaso. Cartas de raridade maior somam dano a mais nesta arma (raro +18%, épico +40%, lendário +80%).
**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) |
| 2 | +5 de dano (passa a 27) |
| 3 | +1 meteoro por queda (passa a cair 2 de cada vez) |
| 4 | +10 de raio (passa a 60 px) e aviso 0,2 s menor (passa a 1,0 s) |
| 5 | +8 de dano e recarga 0,5 s menor. Lendário sobe 2 níveis de uma vez. Com tudo somado: dano 35, recarga 2,5 s, 2 meteoros, raio 60 px, aviso 1,0 s. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** Chuva de Brasas Celestes, com Fogo do Céu. Condição: Meteoro Flamejante no nível 3 e Fogo do Céu no nível 3. As duas somem e nasce a nova arma. Ideia: a queda deixa um rastro de fogo no chão por um tempo curto.

**Animação e efeitos:**
Hoje (placeholder do código): no chão, aparece um círculo da cor da arma que pisca e encolhe durante o aviso, com um miolo que cresce dentro. Uma bola da cor da arma, com um ponto branco no centro, desce do alto até o ponto de queda, durante todo o tempo do aviso. Na queda, aparece um estouro achatado que cresce um pouco e some em 0,3 s. Não há cauda, faísca nem rastro.

Especificação do campo arte (para o Alisson trocar o placeholder):
- Visual: meteoro de fogo com cauda laranja, descendo do alto da tela. Antes de cair, aparece no chão um círculo laranja-avermelhado que pisca.
- Cores: laranja, vermelho, amarelo.
- Tamanho: meteoro de 28 px com cauda. Círculo de aviso do tamanho do raio.
- Duração: queda de 0,4 s e impacto de 0,3 s. (A queda, no código, dura o aviso inteiro. Ver pontos de atenção.)

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- A arte pede cauda e meteoro de 28 px. O código desenha uma bola de 18 px com ponto branco, sem cauda.
- A queda dura o aviso inteiro (1,2 s, depois 1,0 s no nível 4). Os 0,4 s da arte não existem no código.
- O campo alcance (220 px) não aparece no código do meteoro. Os alvos saem da lista de monstros perto do herói (até 340 px). O valor não faz nada: o meteoro não lê o alcance (o alvo sai dos 340 px fixos).
- O ponto de queda é escolhido no disparo e não segue o monstro. Se ele andar durante o aviso, a queda pode cair no vazio.
- A lista de alvos traz só monstros vivos e não morrendo (filtro em _juntar_perto, armas.gd). Depois do sorteio o alvo pode morrer; o estouro acerta quem estiver vivo na área.

## Esquemática
- **Gatilho:** a cada 3,0 s no nível 1 (recarga real = recarga / velocidade de ataque do herói; o padrão é 1,0). Dispara quando a recarga zera e há monstro vivo a até 340 px do herói. Sem monstro, espera 0,3 s e não gasta a recarga.
- **Alvo:** cada meteoro do lote sorteia, ao acaso e de forma independente, um monstro vivo e não morrendo a até 340 px do herói (distância simples, sem achatar). O mesmo monstro pode ser sorteado de novo. O ponto de queda é fixado no sorteio: se o monstro andar ou morrer, o ponto não acompanha.
- **Trajetória e alcance:** sem trajetória no chão: a bola desce na vertical, de 80 px acima do ponto até o ponto, durante o aviso inteiro (no nível 1, cerca de 67 px/s). O campo alcance (220 px no nível 1) não existe no meteoro: o código não lê esse valor (não existe hoje). O alvo sai dos 340 px fixos.
- **Área:** círculo no chão de raio 50 px no nível 1 (na tela, elipse com a altura em 62%), mais o raio de cada monstro atingido.
- **Dano por nível:** dano base do código, sem a raridade. O dano que aparece no jogo é esse valor vezes (1 + a soma do bônus de cada carta de golpe desta arma: raro +18%, épico +40%, lendário +80%). Cada carta soma o seu bônus. O dano do herói (m_dano) é 1,0 por padrão. Obs.: carta lendária de golpe novo entra direto no nível 2 (cartas.gd, montar_carta: sobe 2 níveis a partir do 0), e o cartão mostra só "Novo golpe".

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 22 | Base: 1 meteoro por queda, recarga 3,0 s, raio 50 px, aviso 1,2 s. |
| 2 | 27 | +5 de dano. |
| 3 | 27 | +1 meteoro: passa a 2 por queda. |
| 4 | 27 | Raio passa a 60 px; aviso cai para 1,0 s. |
| 5 | 35 | +8 de dano; recarga cai para 2,5 s. |

- **Como aplica:** uma vez por inimigo por explosão. Cada meteoro que cai dá o dano a todo monstro vivo dentro da área no instante do impacto (ferir arredonda para inteiro, mínimo 1). Sem tique, sem perfuração.
- **Efeitos de status:** empurrão 120 (impulso do código, dividido pelo peso do monstro, para longe do centro do impacto); atordoamento 0,2 s. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** pool de 48 slots (armas_novas.gd, MAX) dividido com todos os golpes novos. Cada meteoro ocupa 1 slot por A + 0,3 s. Com velocidade de ataque 1,0: no máximo 1 meteoro(s) ao mesmo tempo no nível 1 e 2 no nível 5. Se o pool acabar, o lote perde o que não coube, sem aviso.
- **Sequência de animação (quadro a quadro, 60 fps):** sprite de 32x32 px por quadro, 4 quadros em linha (1 e 2 de voo, 3 e 4 de impacto).
  - Antecipação: 0,8 s = 48 quadros (aviso menos queda, no nível 1). Só o círculo no chão, que pisca e encolhe.
  - Queda: 0,4 s = 24 quadros. A bola desce do alto até o ponto.
  - Impacto: 0,3 s = 18 quadros. Estouro achatado (quadros 3 e 4).
  - Fim: some no último quadro do impacto.
  - Hoje no código: a bola desce durante o aviso inteiro (1,2 s), sem antecipação separada, e o estouro dura 0,3 s (18 quadros).
- **Mudanças:** nenhum número mudou: as tabelas batem com dados/v2_cartas.json (golpes) e com v2/armas_novas.gd. Corrigido em Pontos de atenção: o alvo (a lista já traz só monstros vivos e não morrendo, filtro em v2/armas.gd) e o alcance (confirmado: o meteoro não lê esse valor).
