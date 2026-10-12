# Chuva de Pedras (chuva_pedras)
**Tipo:** meteoro. **Ícone:** icone_pedra_amolar.
**O que faz:** De tempos em tempos, um grupo de pedras cai em pontos perto de inimigos que estão perto de você. Cada pedra avisa antes onde vai cair.
**Na prática:** dano 7 (multiplicado pelo bônus de dano do herói). Recarga de 2,0 s. Cai 3 pedras de cada vez. Raio da queda: 30 px. Aviso no chão: 0,8 s. Cada pedra cai sobre um inimigo perto do herói, escolhido ao acaso. Duas pedras podem cair no mesmo inimigo. Cartas de raridade maior somam dano a mais nesta arma (raro +18%, épico +40%, lendário +80%).
**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) |
| 2 | +1 pedra por queda (passa a 4) |
| 3 | +3 de dano (passa a 10) |
| 4 | +10 de raio (passa a 40 px) |
| 5 | +1 pedra e recarga 0,3 s menor. Lendário sobe 2 níveis de uma vez. Com tudo somado: dano 10, recarga 1,7 s, 5 pedras, raio 40 px, aviso 0,8 s. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** Avalanche Vulcânica, com Pedras Vulcânicas. Condição: Chuva de Pedras no nível 3 e Pedras Vulcânicas no nível 3. As duas somem e nasce a nova arma. Ideia: a avalanche cai em um ponto só, com pedras em cadeia.

**Animação e efeitos:**
Hoje (placeholder do código): no chão, aparece um círculo da cor da arma que pisca e encolhe durante o aviso, com um miolo que cresce dentro. Uma bola da cor da arma, com um ponto branco no centro, desce do alto até o ponto de queda, durante todo o tempo do aviso. Na queda, aparece um estouro achatado que cresce um pouco e some em 0,3 s. Não há cauda, poeira nem rastro.

Especificação do campo arte (para o Alisson trocar o placeholder):
- Visual: pedras cinzentas caem do alto da tela em pontos perto do herói, cada uma com um pequeno aviso no chão. Elas somem ao bater.
- Cores: cinza, marrom, areia.
- Tamanho: pedra de 8x8 px. Impacto de 30 px de raio.
- Duração: queda de 0,3 s e impacto de 0,2 s. (A queda, no código, dura o aviso inteiro. Ver pontos de atenção.)

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- A descrição diz "em volta de você", mas o código joga as pedras sobre inimigos perto do herói, não em um anel ao redor dele. Escolher qual vale.
- A arte diz que a pedra "some ao bater". No código, o estouro fica 0,3 s (a arte diz 0,2 s).
- A queda dura o aviso inteiro (0,8 s). Os 0,3 s da arte não existem no código.
- O campo alcance (180 px) não aparece no código do meteoro. Os alvos saem da lista de monstros perto do herói (até 340 px). O valor não faz nada: o meteoro não lê o alcance (o alvo sai dos 340 px fixos).
- O ponto de queda é escolhido no disparo e não segue o monstro. A lista de alvos traz só monstros vivos e não morrendo (filtro em _juntar_perto, armas.gd). Depois do sorteio o alvo pode morrer; o estouro acerta quem estiver vivo na área.

## Esquemática
- **Gatilho:** a cada 2,0 s no nível 1 (recarga real = recarga / velocidade de ataque do herói; o padrão é 1,0). Dispara quando a recarga zera e há monstro vivo a até 340 px do herói. Sem monstro, espera 0,3 s e não gasta a recarga.
- **Alvo:** cada meteoro do lote sorteia, ao acaso e de forma independente, um monstro vivo e não morrendo a até 340 px do herói (distância simples, sem achatar). O mesmo monstro pode ser sorteado de novo. O ponto de queda é fixado no sorteio: se o monstro andar ou morrer, o ponto não acompanha.
- **Trajetória e alcance:** sem trajetória no chão: a bola desce na vertical, de 80 px acima do ponto até o ponto, durante o aviso inteiro (no nível 1, cerca de 100 px/s). O campo alcance (180 px no nível 1) não existe no meteoro: o código não lê esse valor (não existe hoje). O alvo sai dos 340 px fixos.
- **Área:** círculo no chão de raio 30 px no nível 1 (na tela, elipse com a altura em 62%), mais o raio de cada monstro atingido.
- **Dano por nível:** dano base do código, sem a raridade. O dano que aparece no jogo é esse valor vezes (1 + a soma do bônus de cada carta de golpe desta arma: raro +18%, épico +40%, lendário +80%). Cada carta soma o seu bônus. O dano do herói (m_dano) é 1,0 por padrão. Obs.: carta lendária de golpe novo entra direto no nível 2 (cartas.gd, montar_carta: sobe 2 níveis a partir do 0), e o cartão mostra só "Novo golpe".

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 7 | Base: 3 pedras por queda, recarga 2,0 s, raio 30 px, aviso 0,8 s. |
| 2 | 7 | +1 pedra: passa a 4 por queda. |
| 3 | 10 | +3 de dano. |
| 4 | 10 | Raio passa a 40 px. |
| 5 | 10 | +1 pedra (5 por queda); recarga cai para 1,7 s. |

- **Como aplica:** uma vez por inimigo por explosão. Cada meteoro que cai dá o dano a todo monstro vivo dentro da área no instante do impacto (ferir arredonda para inteiro, mínimo 1). Sem tique, sem perfuração.
- **Efeitos de status:** empurrão 120 (impulso do código, dividido pelo peso do monstro, para longe do centro do impacto); atordoamento 0,2 s. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** pool de 48 slots (armas_novas.gd, MAX) dividido com todos os golpes novos. Cada meteoro ocupa 1 slot por A + 0,3 s. Com velocidade de ataque 1,0: no máximo 3 meteoro(s) ao mesmo tempo no nível 1 e 5 no nível 5. Se o pool acabar, o lote perde o que não coube, sem aviso.
- **Sequência de animação (quadro a quadro, 60 fps):** sprite de 16x16 px por quadro, 4 quadros em linha (1 e 2 de voo, 3 e 4 de impacto).
  - Antecipação: 0,5 s = 30 quadros (aviso menos queda, no nível 1). Só o círculo no chão, que pisca e encolhe.
  - Queda: 0,3 s = 18 quadros. A bola desce do alto até o ponto.
  - Impacto: 0,2 s = 12 quadros. Estouro achatado (quadros 3 e 4).
  - Fim: some no último quadro do impacto.
  - Hoje no código: a bola desce durante o aviso inteiro (0,8 s), sem antecipação separada, e o estouro dura 0,3 s (18 quadros).
- **Obs.:** Duas pedras podem cair no mesmo monstro (sorteio independente).
- **Mudanças:** nenhum número mudou: as tabelas batem com dados/v2_cartas.json (golpes) e com v2/armas_novas.gd. Corrigido em Pontos de atenção: o alvo (a lista já traz só monstros vivos e não morrendo, filtro em v2/armas.gd) e o alcance (confirmado: o meteoro não lê esse valor).
