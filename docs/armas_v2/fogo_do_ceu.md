# Fogo do Céu (fogo_do_ceu)
**Tipo:** meteoro. **Ícone:** icone_u_tocha_ardente.
**O que faz:** De tempos em tempos, colunas de fogo descem do céu em pontos perto de inimigos que estão perto de você. Cada coluna avisa antes onde vai bater.
**Na prática:** dano 16 (multiplicado pelo bônus de dano do herói). Recarga de 2,8 s. Cai 2 colunas de cada vez. Raio da queda: 45 px. Aviso no chão: 1,0 s. Cada coluna cai sobre um inimigo perto do herói, escolhido ao acaso. Duas colunas podem cair no mesmo inimigo. Cartas de raridade maior somam dano a mais nesta arma (raro +18%, épico +40%, lendário +80%).
**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) |
| 2 | +5 de dano (passa a 21) |
| 3 | +1 coluna por queda (passa a cair 3 de cada vez) |
| 4 | +12 de raio (passa a 57 px) |
| 5 | +6 de dano e recarga 0,4 s menor. Lendário sobe 2 níveis de uma vez. Com tudo somado: dano 27, recarga 2,4 s, 3 colunas, raio 57 px, aviso 1,0 s. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** Chuva de Brasas Celestes, com Meteoro Flamejante. Condição: Fogo do Céu no nível 3 e Meteoro Flamejante no nível 3. As duas somem e nasce a nova arma. Ideia: a queda deixa um rastro de fogo no chão por um tempo curto.

**Animação e efeitos:**
Hoje (placeholder do código): no chão, aparece um círculo da cor da arma que pisca e encolhe durante o aviso, com um miolo que cresce dentro. Uma bola da cor da arma, com um ponto branco no centro, desce do alto até o ponto de queda, durante todo o tempo do aviso. Na queda, aparece um estouro achatado que cresce um pouco e some em 0,3 s. Não há coluna nem chama.

Especificação do campo arte (para o Alisson trocar o placeholder):
- Visual: colunas de fogo vermelho e amarelo descem do alto da tela e batem no chão em pontos perto do herói, com um círculo vermelho piscando antes.
- Cores: vermelho, amarelo, laranja.
- Tamanho: coluna de 24x80 px. Círculo de aviso do tamanho do raio.
- Duração: queda de 0,3 s e chama de 0,4 s no impacto. (A queda, no código, dura o aviso inteiro. Ver pontos de atenção.)

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- A arte pede coluna de 24x80 px e chama de 0,4 s. O código não tem coluna nem chama: desenha a bola genérica e o estouro achatado. Esta é a diferença visual mais forte entre a arte e o código.
- A queda dura o aviso inteiro (1,0 s). Os 0,3 s da arte não existem no código.
- O campo alcance (230 px) não aparece no código do meteoro. Os alvos saem da lista de monstros perto do herói (até 340 px). O valor não faz nada: o meteoro não lê o alcance (o alvo sai dos 340 px fixos).
- O ponto de queda é escolhido no disparo e não segue o monstro. A lista de alvos traz só monstros vivos e não morrendo (filtro em _juntar_perto, armas.gd). Depois do sorteio o alvo pode morrer; o estouro acerta quem estiver vivo na área.

## Esquemática
- **Gatilho:** a cada 2,8 s no nível 1 (recarga real = recarga / velocidade de ataque do herói; o padrão é 1,0). Dispara quando a recarga zera e há monstro vivo a até 340 px do herói. Sem monstro, espera 0,3 s e não gasta a recarga.
- **Alvo:** cada meteoro do lote sorteia, ao acaso e de forma independente, um monstro vivo e não morrendo a até 340 px do herói (distância simples, sem achatar). O mesmo monstro pode ser sorteado de novo. O ponto de queda é fixado no sorteio: se o monstro andar ou morrer, o ponto não acompanha.
- **Trajetória e alcance:** sem trajetória no chão: a bola desce na vertical, de 80 px acima do ponto até o ponto, durante o aviso inteiro (no nível 1, cerca de 80 px/s). O campo alcance (230 px no nível 1) não existe no meteoro: o código não lê esse valor (não existe hoje). O alvo sai dos 340 px fixos.
- **Área:** círculo no chão de raio 45 px no nível 1 (na tela, elipse com a altura em 62%), mais o raio de cada monstro atingido.
- **Dano por nível:** dano base do código, sem a raridade. O dano que aparece no jogo é esse valor vezes (1 + a soma do bônus de cada carta de golpe desta arma: raro +18%, épico +40%, lendário +80%). Cada carta soma o seu bônus. O dano do herói (m_dano) é 1,0 por padrão. Obs.: carta lendária de golpe novo entra direto no nível 2 (cartas.gd, montar_carta: sobe 2 níveis a partir do 0), e o cartão mostra só "Novo golpe".

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 16 | Base: 2 colunas, recarga 2,8 s, raio 45 px, aviso 1,0 s. |
| 2 | 21 | +5 de dano. |
| 3 | 21 | +1 coluna: passa a 3 por queda. |
| 4 | 21 | Raio passa a 57 px. |
| 5 | 27 | +6 de dano; recarga cai para 2,4 s. |

- **Como aplica:** uma vez por inimigo por explosão. Cada meteoro que cai dá o dano a todo monstro vivo dentro da área no instante do impacto (ferir arredonda para inteiro, mínimo 1). Sem tique, sem perfuração.
- **Efeitos de status:** empurrão 120 (impulso do código, dividido pelo peso do monstro, para longe do centro do impacto); atordoamento 0,2 s. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** pool de 48 slots (armas_novas.gd, MAX) dividido com todos os golpes novos. Cada meteoro ocupa 1 slot por A + 0,3 s. Com velocidade de ataque 1,0: no máximo 2 meteoro(s) ao mesmo tempo no nível 1 e 3 no nível 5. Se o pool acabar, o lote perde o que não coube, sem aviso.
- **Sequência de animação (quadro a quadro, 60 fps):** sprite de 24x80 px por quadro, 4 quadros em linha (1 e 2 de voo, 3 e 4 de impacto).
  - Antecipação: 0,7 s = 42 quadros (aviso menos queda, no nível 1). Só o círculo no chão, que pisca e encolhe.
  - Queda: 0,3 s = 18 quadros. A bola desce do alto até o ponto.
  - Impacto: 0,4 s = 24 quadros. Estouro achatado (quadros 3 e 4).
  - Fim: some no último quadro do impacto.
  - Hoje no código: a bola desce durante o aviso inteiro (1,0 s), sem antecipação separada, e o estouro dura 0,3 s (18 quadros).
- **Obs.:** A coluna 24x80 px da arte não existe hoje: o meteoro é a bola genérica e o estouro é o achatado.
- **Mudanças:** nenhum número mudou: as tabelas batem com dados/v2_cartas.json (golpes) e com v2/armas_novas.gd. Corrigido em Pontos de atenção: o alvo (a lista já traz só monstros vivos e não morrendo, filtro em v2/armas.gd) e o alcance (confirmado: o meteoro não lê esse valor).
