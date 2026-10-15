# Análise das fusões da v2 e como elas devem funcionar

Pedido do Breno (14/10): "peguei tudo, mas nada aconteceu, não senti que a arma ficou incrível". Este documento inventaria as 9 fusões de `docs/armas_v2/fusao_*.md` mais as 16 novas em `dados/v2_cartas.json`, mostra como cada uma aparece na tela e compara as duas opções dele. Nenhum código foi alterado além do branch `claude/fusoes-claras` já existente.

Números em "peça nv3" são o nível da arma base quando o jogador já a tem no nível que a receita pede.

## 1. Inventário (9 fusões das fichas)

| Fusão | Peças (nível pedido) | Vira | Mudança real de poder e forma | Diferença visível da base |
|---|---|---|---|---|
| Anel de Brasas | Aura de Fogo nv3 + Lâminas nv3 | órbita de 6 lâminas + aura com dano 9 | Lâminas nv3 são 3 com dano 14; viram 6 com dano 17, e a aura sobe de 8 para 9. Pelas contas, o dano total das lâminas sobe perto de 2,4× (estimativa) | Média: mais lâminas e halo maior (agora) |
| Revoada de Trovões | Corvos nv3 + Raio nv3 | 7 corvos elétricos, cada bicada solta raio | Mais corvos e arco elétrico. Ganho real, a confirmar em simulação | Baixa: os corvos são desenhados pelo mesmo código; só a quantidade muda |
| Círculo Rúnico | Runa nv3 + Crítico explosivo nv2 | runas com explosão 66 px e lentidão | Explosão grande e lentidão. Ganho alto, a confirmar | Média: runas maiores, mesmo desenho |
| Ventania Cortante | Corte ondulante nv2 + Estocada nv2 | não cria arma: onda 2,4× e 3 lanças | Onda de 80% x 2,4 = 192% do corte (antes 152%) | Baixa: só a largura muda (34 → 68 px) |
| Caçada Espiritual | Lobo nv3 + Raposa nv3 | 1 aliado com dano 12 | Troca dois aliados por um. Ganho a confirmar | Baixa: aliados usam o mesmo desenho de espírito |
| Dragão de Brasa | Dragãozinho nv3 + Serpente nv3 | 3 espíritos de brasa, dano 14 | Mesma coisa: troca dois por um, a confirmar | Baixa: espírito genérico com cor laranja |
| Exército Esquecido | Esqueleto nv3 + Fantasma nv3 | 4 aliados, dano 13 | Mais aliados, a confirmar | Baixa: espírito genérico |
| Colosso de Pedra | Golem nv3 + Guardião nv3 | 1 colosso, dano 30, 1 golpe por s | Mais dano, um só alvo | Baixa: sem desenho de colosso próprio |
| Urso Solar | Espírito Urso nv3 + Raio Solar nv3 | 2 feixes que atravessam 4 | Atravessa vários inimigos. Ganho a confirmar | Baixa: projétil genérico com cor dourada |

As 16 fusões novas seguem o mesmo padrão: uma arma nova com números próprios, sem diferença visual específica.

## 2. Como o ataque aparece hoje

- **Nenhuma fusão tem sprite próprio no repositório.** Em `assets/` só há ícones (`icone_revoada.png` é o único de fusão). O `docs/armas_v2/PACOTE_ALISSON.md` já tem as especificações de sprite das 9 fusões (ex.: Anel de Brasas, 26 x 11 px, 4 quadros), mas nada foi entregue.
- **Desenho em código (placeholder):** lâminas (`armas.gd`), corvos e runas (`armas.gd`), aliados e projéteis genéricos (`armas_novas.gd`). A fusão troca números e cor, não a forma.
- **O que a fusão mudou na tela, de fato:** o Anel ganhou halo maior (já no branch); a Ventania, onda mais larga (já no branch). As outras soam e se parecem com a arma base.
- **Momento da fusão:** antes do branch, só uma faixa de 16 px por 1,2 s. Agora: cartão grande, parada de 0,1 s e câmera lenta de 0,6 s. Mas a fusão ainda acontece sem o jogador escolher, ao clicar a última carta da receita.

Falta pedir ao Alisson: sprites das 9 fusões (já especificados), mais os 16 novos, e um desenho de colosso e de espírito de fogo que se distinga do espírito base.

## 3. As duas opções

**A. Fusão na partida com carta própria de FUSÃO.** Quando a receita está completa, a carta FUSÃO aparece entre as 3 opções do level-up, mostrando as duas armas e o resultado. O jogador escolhe fundir.
- Pró: é a fusão no ritmo da partida, onde a escolha de build já é o centro do jogo. Clareza alta: o jogador lê a receita e escolhe. Custo de desempenho baixo (é uma carta a mais).
- Contra: a carta FUSÃO compete com as outras duas. Para não ser fácil, a fusão deve custar a própria escolha (quem funde não pega outra melhoria naquele nível).
- Balanceamento: a fusão continua exigindo as peças nos níveis pedidos, então o jogo não fica fácil.

**B. Forja na cidade (hub da #242).** Um ferreiro funde armas entre partidas, se o herói tiver as peças e pagar almas ou ouro.
- Pró: clareza máxima, porque a receita fica numa tela de menu.
- Contra: tira a fusão da partida, que é onde ele quer sentir o efeito. Vira progressão de meta, o que a faz parecer pronta antes de jogar. Exige peças guardadas entre partidas, o que muda o modelo de build (hoje cada partida começa do zero). Conflita com a #242, que ainda não está no `main`. Desempenho ok.

**Híbrido (recomendo, se for mexer em B depois).** A fusão acontece na partida pela carta FUSÃO (A). A forja na cidade só serve para refazer ou desbloquear receitas, com custo em almas. Assim o momento de sentir a arma continua na partida, e a cidade ganha um motivo para voltar.

## 4. Recomendação

Ir por **A** agora: é a que resolve a queixa dele (não sentir a fusão), não exige mudar o modelo de partida e não depende da #242. Ajustes de código: trocar a fusão automática por uma carta FUSÃO com as duas armas e o resultado; manter o cartão grande, a parada e a câmera lenta; dar sprites próprios (pedido ao Alisson). Ajustes de número: fazer uma simulação das 9 fusões contra a base antes de qualquer número novo. Desempenho: nada a mais que uma carta e uma tween.

Deixar **B** como possível camada depois da #242, não como substituto.

## 5. Pendências

- Números de Revoada, Círculo, Caçada, Dragão, Exército, Colosso e Urso precisam de simulação de dano; eu só confirmei os números de Anel e Ventania.
- Nenhum sprite de fusão existe no repositório.
- Verificar a #242 antes de decidir B.
