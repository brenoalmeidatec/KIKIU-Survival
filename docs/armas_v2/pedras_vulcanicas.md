# Pedras Vulcânicas (pedras_vulcanicas)
**Tipo:** meteoro. **Ícone:** icone_terremoto.
**O que faz:** De tempos em tempos, pedras quentes caem bem perto de você, em pontos perto de inimigos. Cada pedra avisa antes onde vai cair.
**Na prática:** dano 5 (multiplicado pelo bônus de dano do herói). Recarga de 1,6 s. Cai 4 pedras de cada vez. Raio da queda: 25 px. Aviso no chão: 0,7 s. Cada pedra cai sobre um inimigo perto do herói, escolhido ao acaso. Alcance da arma: 120 px (o código não usa esse valor, ver pontos de atenção). Cartas de raridade maior somam dano a mais nesta arma (raro +18%, épico +40%, lendário +80%).
**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) |
| 2 | +2 de dano (passa a 7) |
| 3 | +1 pedra por queda (passa a cair 5 de cada vez) |
| 4 | +40 de alcance (passa a 160 px no papel) |
| 5 | +1 pedra e recarga 0,3 s menor. Lendário sobe 2 níveis de uma vez. Com tudo somado: dano 7, recarga 1,3 s, 6 pedras, raio 25 px, aviso 0,7 s. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** Avalanche Vulcânica, com Chuva de Pedras. Condição: Pedras Vulcânicas no nível 3 e Chuva de Pedras no nível 3. As duas somem e nasce a nova arma. Ideia: a avalanche cai em um ponto só, com pedras em cadeia.

**Animação e efeitos:**
Hoje (placeholder do código): no chão, aparece um círculo da cor da arma que pisca e encolhe durante o aviso, com um miolo que cresce dentro. Uma bola da cor da arma, com um ponto branco no centro, desce do alto até o ponto de queda, durante todo o tempo do aviso. Na queda, aparece um estouro achatado que cresce um pouco e some em 0,3 s. Não há brilho laranja nem rastro.

Especificação do campo arte (para o Alisson trocar o placeholder):
- Visual: pedras escuras com brilho laranja caem em volta do herói, bem perto, cada uma com um círculo de aviso vermelho-escuro no chão.
- Cores: marrom escuro, laranja, vermelho escuro.
- Tamanho: pedra de 10x10 px. Impacto de 25 px de raio.
- Duração: queda de 0,25 s e brilho de 0,2 s no impacto. (A queda, no código, dura o aviso inteiro. Ver pontos de atenção.)

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- O nível 4 diz "+40 de alcance", mas o código do meteoro não usa o alcance. A carta não vai fazer nada além de mudar o número. Esta é a maior dúvida desta arma.
- A descrição diz "bem perto", mas o código joga as pedras sobre inimigos perto do herói, sem limite de distância menor. Se a lista de monstros for de 340 px, a pedra pode cair longe do herói.
- A arte pede brilho laranja e círculo vermelho-escuro. O código usa o estouro genérico, na cor da arma.
- A queda dura o aviso inteiro (0,7 s). Os 0,25 s da arte não existem no código.
- O ponto de queda é escolhido no disparo e não segue o monstro. A lista de alvos traz só monstros vivos e não morrendo (filtro em _juntar_perto, armas.gd). Depois do sorteio o alvo pode morrer; o estouro acerta quem estiver vivo na área.

## Esquemática
- **Gatilho:** a cada 1,6 s no nível 1 (recarga real = recarga / velocidade de ataque do herói; o padrão é 1,0). Dispara quando a recarga zera e há monstro vivo a até 340 px do herói. Sem monstro, espera 0,3 s e não gasta a recarga.
- **Alvo:** cada meteoro do lote sorteia, ao acaso e de forma independente, um monstro vivo e não morrendo a até 340 px do herói (distância simples, sem achatar). O mesmo monstro pode ser sorteado de novo. O ponto de queda é fixado no sorteio: se o monstro andar ou morrer, o ponto não acompanha.
- **Trajetória e alcance:** sem trajetória no chão: a bola desce na vertical, de 80 px acima do ponto até o ponto, durante o aviso inteiro (no nível 1, cerca de 114 px/s). O campo alcance (120 px no nível 1) não existe no meteoro: o código não lê esse valor (não existe hoje). O alvo sai dos 340 px fixos.
- **Área:** círculo no chão de raio 25 px no nível 1 (na tela, elipse com a altura em 62%), mais o raio de cada monstro atingido.
- **Dano por nível:** dano base do código, sem a raridade. O dano que aparece no jogo é esse valor vezes (1 + a soma do bônus de cada carta de golpe desta arma: raro +18%, épico +40%, lendário +80%). Cada carta soma o seu bônus. O dano do herói (m_dano) é 1,0 por padrão. Obs.: carta lendária de golpe novo entra direto no nível 2 (cartas.gd, montar_carta: sobe 2 níveis a partir do 0), e o cartão mostra só "Novo golpe".

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 5 | Base: 4 pedras, recarga 1,6 s, raio 25 px, aviso 0,7 s. |
| 2 | 7 | +2 de dano. |
| 3 | 7 | +1 pedra: passa a 5 por queda. |
| 4 | 7 | Alcance +40 (de 120 para 160 px): não faz nada, o meteoro não lê o alcance. Dano, pedras e raio não mudam. |
| 5 | 7 | +1 pedra (6 por queda); recarga cai para 1,3 s. |

- **Como aplica:** uma vez por inimigo por explosão. Cada meteoro que cai dá o dano a todo monstro vivo dentro da área no instante do impacto (ferir arredonda para inteiro, mínimo 1). Sem tique, sem perfuração.
- **Efeitos de status:** empurrão 120 (impulso do código, dividido pelo peso do monstro, para longe do centro do impacto); atordoamento 0,2 s. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** pool de 48 slots (armas_novas.gd, MAX) dividido com todos os golpes novos. Cada meteoro ocupa 1 slot por A + 0,3 s. Com velocidade de ataque 1,0: no máximo 4 meteoro(s) ao mesmo tempo no nível 1 e 6 no nível 5. Se o pool acabar, o lote perde o que não coube, sem aviso.
- **Sequência de animação (quadro a quadro, 60 fps):** sprite de 16x16 px por quadro, 4 quadros em linha (1 e 2 de voo, 3 e 4 de impacto).
  - Antecipação: 0,45 s = 27 quadros (aviso menos queda, no nível 1). Só o círculo no chão, que pisca e encolhe.
  - Queda: 0,25 s = 15 quadros. A bola desce do alto até o ponto.
  - Impacto: 0,2 s = 12 quadros. Estouro achatado (quadros 3 e 4).
  - Fim: some no último quadro do impacto.
  - Hoje no código: a bola desce durante o aviso inteiro (0,7 s), sem antecipação separada, e o estouro dura 0,3 s (18 quadros).
- **Obs.:** O nível 4 não tem efeito no jogo hoje (ver Pontos de atenção).
- **Mudanças:** nenhum número mudou: as tabelas batem com dados/v2_cartas.json (golpes) e com v2/armas_novas.gd. Corrigido em Pontos de atenção: o alvo (a lista já traz só monstros vivos e não morrendo, filtro em v2/armas.gd) (o alcance já estava anotado: o meteoro não lê esse valor).
