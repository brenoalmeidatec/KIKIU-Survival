# Raio Meteórico (raio_meteorico)
**Tipo:** meteoro. **Ícone:** icone_centelha.
**O que faz:** De tempos em tempos, um raio elétrico cai num ponto distante, em cima de um inimigo perto do herói. O aviso no chão é curto.
**Na prática:** dano 13 (multiplicado pelo bônus de dano do herói). Recarga de 2,5 s. Cai 1 raio de cada vez. Raio da queda: 60 px. Aviso no chão: 0,8 s. Ele cai sobre um inimigo perto do herói, escolhido ao acaso. Alcance da arma: 300 px (o código não usa esse valor, ver pontos de atenção). Cartas de raridade maior somam dano a mais nesta arma (raro +18%, épico +40%, lendário +80%).
**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) |
| 2 | +4 de dano (passa a 17) |
| 3 | +15 de raio (passa a 75 px) |
| 4 | Aviso 0,2 s menor (passa a 0,6 s) |
| 5 | +6 de dano e +1 raio (um raio a mais por queda, passa a cair 2 de cada vez). Lendário sobe 2 níveis de uma vez. Com tudo somado: dano 23, recarga 2,5 s, 2 raios, raio 75 px, aviso 0,6 s. |

**Fusões e evoluções:** Sem fusão hoje.
**(proposta)** Tempestade Glacial, com Cometa Gelado. Condição: Raio Meteórico no nível 3 e Cometa Gelado no nível 3. As duas somem e nasce a nova arma. Ideia: o raio elétrico cai junto com o cometa e o gelo se espalha pelo chão.

**Animação e efeitos:**
Hoje (placeholder do código): no chão, aparece um círculo da cor da arma que pisca e encolhe durante o aviso, com um miolo que cresce dentro. Uma bola da cor da arma, com um ponto branco no centro, desce do alto até o ponto de queda, durante todo o tempo do aviso. Na queda, aparece um estouro achatado que cresce um pouco e some em 0,3 s. Não há faísca, zigue-zague nem anel elétrico.

Especificação do campo arte (para o Alisson trocar o placeholder):
- Visual: meteoro elétrico azul-violeta com faíscas, descendo do céu até o chão. No impacto, um anel elétrico se espalha em volta do ponto de queda.
- Cores: azul elétrico, violeta, branco.
- Tamanho: meteoro de 30 px com faíscas. Anel de impacto de 60 px de raio.
- Duração: queda de 0,3 s e anel de 0,3 s. (A queda, no código, dura o aviso inteiro. Ver pontos de atenção.)

**Mudanças em relação ao desenho original:** Nenhuma: segue o desenho original do PR #192.

**Pontos de atenção:**
- Nível 5: o texto "+1 raio" pode ser lido como raio de área. Na verdade é "um raio a mais". Vale trocar a frase do texto para não confundir (decisão de texto, não mexi no dado).
- A arte pede um anel elétrico no impacto e faíscas no meteoro. O código não tem nenhum dos dois: é o estouro genérico.
- A queda dura o aviso inteiro (0,8 s). Os 0,3 s da arte não existem no código.
- O campo alcance (300 px) não aparece no código do meteoro. Os alvos saem da lista de monstros perto do herói (até 340 px). O valor não faz nada: o meteoro não lê o alcance (o alvo sai dos 340 px fixos).
- O ponto de queda é escolhido no disparo e não segue o monstro. A lista de alvos traz só monstros vivos e não morrendo (filtro em _juntar_perto, armas.gd). Depois do sorteio o alvo pode morrer; o estouro acerta quem estiver vivo na área.

## Esquemática
- **Gatilho:** a cada 2,5 s no nível 1 (recarga real = recarga / velocidade de ataque do herói; o padrão é 1,0). Dispara quando a recarga zera e há monstro vivo a até 340 px do herói. Sem monstro, espera 0,3 s e não gasta a recarga.
- **Alvo:** cada meteoro do lote sorteia, ao acaso e de forma independente, um monstro vivo e não morrendo a até 340 px do herói (distância simples, sem achatar). O mesmo monstro pode ser sorteado de novo. O ponto de queda é fixado no sorteio: se o monstro andar ou morrer, o ponto não acompanha.
- **Trajetória e alcance:** sem trajetória no chão: a bola desce na vertical, de 80 px acima do ponto até o ponto, durante o aviso inteiro (no nível 1, cerca de 100 px/s). O campo alcance (300 px no nível 1) não existe no meteoro: o código não lê esse valor (não existe hoje). O alvo sai dos 340 px fixos.
- **Área:** círculo no chão de raio 60 px no nível 1 (na tela, elipse com a altura em 62%), mais o raio de cada monstro atingido.
- **Dano por nível:** dano base do código, sem a raridade. O dano que aparece no jogo é esse valor vezes (1 + a soma do bônus de cada carta de golpe desta arma: raro +18%, épico +40%, lendário +80%). Cada carta soma o seu bônus. O dano do herói (m_dano) é 1,0 por padrão. Obs.: carta lendária de golpe novo entra direto no nível 2 (cartas.gd, montar_carta: sobe 2 níveis a partir do 0), e o cartão mostra só "Novo golpe".

| Nível | Dano | Como muda |
|---|---|---|
| 1 | 13 | Base: 1 raio, recarga 2,5 s, raio 60 px, aviso 0,8 s. |
| 2 | 17 | +4 de dano. |
| 3 | 17 | Raio passa a 75 px. |
| 4 | 17 | Aviso cai para 0,6 s. |
| 5 | 23 | +6 de dano; passa a 2 raios por queda (o "+1 raio" do cartão é quantidade, não raio). Recarga segue 2,5 s. |

- **Como aplica:** uma vez por inimigo por explosão. Cada meteoro que cai dá o dano a todo monstro vivo dentro da área no instante do impacto (ferir arredonda para inteiro, mínimo 1). Sem tique, sem perfuração.
- **Efeitos de status:** empurrão 120 (impulso do código, dividido pelo peso do monstro, para longe do centro do impacto); atordoamento 0,2 s. Lentidão: nenhuma. Queimadura: nenhuma.
- **Limites na tela:** pool de 48 slots (armas_novas.gd, MAX) dividido com todos os golpes novos. Cada meteoro ocupa 1 slot por A + 0,3 s. Com velocidade de ataque 1,0: no máximo 1 meteoro(s) ao mesmo tempo no nível 1 e 2 no nível 5. Se o pool acabar, o lote perde o que não coube, sem aviso.
- **Sequência de animação (quadro a quadro, 60 fps):** sprite de 64x64 px por quadro, 4 quadros em linha (1 e 2 de voo, 3 e 4 de impacto).
  - Antecipação: 0,5 s = 30 quadros (aviso menos queda, no nível 1). Só o círculo no chão, que pisca e encolhe.
  - Queda: 0,3 s = 18 quadros. A bola desce do alto até o ponto.
  - Impacto: 0,3 s = 18 quadros. Estouro achatado (quadros 3 e 4).
  - Fim: some no último quadro do impacto.
  - Hoje no código: a bola desce durante o aviso inteiro (0,8 s), sem antecipação separada, e o estouro dura 0,3 s (18 quadros).
- **Obs.:** No nível 5 o cartão diz "+1 raio", mas o que sobe é a quantidade de raios (2 por queda). Trocar a frase é decisão de texto; o dado não foi mexido.
- **Mudanças:** nenhum número mudou: as tabelas batem com dados/v2_cartas.json (golpes) e com v2/armas_novas.gd. Corrigido em Pontos de atenção: o alvo (a lista já traz só monstros vivos e não morrendo, filtro em v2/armas.gd) e o alcance (confirmado: o meteoro não lê esse valor).
