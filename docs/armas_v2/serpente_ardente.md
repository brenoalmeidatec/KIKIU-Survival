# Serpente Ardente (serpente_ardente)
**Tipo:** aliado. **Ícone:** icone_u_frasco_incendiario.
**O que faz:** Chama uma serpente de fogo que desliza até o inimigo mais perto e o atinge a cada toque. Não queima: não há fogo que continue depois do toque.
**Na prática:** Cada toque dá 9 de dano. Chama 1 serpente a cada 3 s, se houver inimigo a até 340 px do herói (o bônus de velocidade de ataque deixa a recarga menor). A serpente fica 5 s e anda 140 px por segundo. Enquanto estiver encostada no inimigo, toca a cada 0,5 s. Sem inimigo por perto, tenta girar em volta do herói. Conta de média, sem bônus: cerca de 1,7 serpente na tela no nível 1 e cerca de 4,3 no nível 5.

> **Tempo de vida (aliado temporário, 18/10):** dura **35 s** e some; só depois que o último da leva sumiu a recarga de **25 s** começa a contar, então nunca fica indefinidamente nem se acumula. Cada nível que mexe na duração soma 5 s (e a recarga cai uns 3 s nas melhorias de cadência). Marca de amigo: anel verde no chão e barrinha verde pequena de tempo sobre a cabeça (pisca nos últimos 5 s). **Onde este arquivo citar duração ou recarga de 2 a 8 s, vale o número desta caixa**; as contas de "quantos na tela" ficam bem menores, porque a recarga agora corre só depois que a leva some.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) |
| 2 | +3 de dano (dano 12) |
| 3 | +1,5 s de duração (dura 6,5 s) |
| 4 | +1 serpente por invocação (2 por vez) |
| 5 | +4 de dano e bate mais: intervalo de 0,1 s menor (0,4 s). Acumulado no nível 5: 2 serpentes por vez, dano 16, dura 6,5 s, recarga 3 s, velocidade 140, intervalo 0,4 s. Nível máximo: uma carta lendária pula de 3 para 5 de uma vez. |

**Fusões e evoluções:** Sem fusão hoje. **Dragão de Brasa (proposta):** Serpente Ardente nível 3 + Dragãozinho nível 3. As duas somem e entra um golpe de fogo que chama serpente e dragão juntos. Números a combinar.

**Animação e efeitos:** Hoje, o placeholder é um brilho na cor da arma (a textura de brilho do jogo, a 60% da cor) com um pontinho branco de 5 px por cima. A serpente flutua 10 px acima do chão, balança 2 px e some nos últimos 0,5 s de vida. Não há corpo ondulado, rastro de chamas nem faíscas.
Especificação do campo "arte" (para o Alisson substituir): uma serpente longa feita de fogo, com corpo ondulado e cabeça de brasa, que rasteja pelo chão deixando um rastro de chamas baixas. No contato, a cabeça estala e solta faíscas. Cores: laranja-vivo, vermelho-brasa, amarelo no centro. Tamanho: serpente de 40 px de comprimento; rastro de 10 px; faíscas de 4 px. Duração: o rastro some em 0,4 s.

**Mudanças em relação ao desenho original:** Nenhuma no desenho. Números conferidos com o código e com dados/v2_cartas.json: sem diferença. Texto corrigido: 'O que faz' dizia que a serpente queima e continua queimando, mas o aliado não tem queimadura no código. A descrição do JSON ('e o queima') também está fora do código; o ajuste de texto fica para o Alisson, se quiser, em v2_cartas.json.

**Pontos de atenção:**
- Uma serpente encostada dá 18 de dano por segundo no nível 1 e 40 no nível 5. É uma das mais fortes por espírito.
- O "queimar" de que fala a descrição não tem nada extra no código: é só dano em intervalos, como os outros aliados. Se a intenção é fogo que continua depois que a serpente sai, isso ainda não existe.
- O espírito só enxerga inimigos a até 340 px do herói. O alcance de 400 px do código é fixo e não está no JSON.
- O empurrão (30) e a pausa (0,05 s) de cada toque são valores fixos no código, não sobem com o nível.
- O campo "provisorio" do JSON descreve uma sequência de círculos laranja que o código não desenha: o que aparece é o brilho com pontinho.
- O bônus de raridade entra no dano (armas.gd, definir_golpe): cada carta de golpe soma o bonus_arma da própria raridade ao bônus do golpe, e o total multiplica o dano. Ver Esquemática.

## Esquemática
- **Gatilho:** a cada 3 s no nível 1 (3 s no nível 5, com os cortes de recarga). Quando a recarga zera e há monstro a até 340 px do herói (distância simples, sem achatar), invoca de uma vez a quantidade do nível (1 no nível 1, 2 no nível 5). Os espíritos nascem perto do herói (sorteado: até 30 px para os lados e 20 px para cima ou para baixo). Sem monstro nessa faixa, a recarga não gasta: tenta de novo em 0,3 s. A primeira tentativa vem 0,4 s depois de a carta entrar. A velocidade de ataque do herói (1,0 por padrão) divide a recarga.
- **Alvo:** a cada quadro, o espírito escolhe o monstro mais perto dele entre os que estão a até 340 px do herói (distância simples). A escolha mede no plano achatado (y dividido por 0,62), com limite de 400 px a partir do espírito. Monstro morrendo não conta. Sem alvo, o espírito gira em volta do herói a 50 px. O ponto da volta anda a 300 px/s, mais rápido que qualquer espírito deste lote (o mais rápido, o dragão no nível 5, faz 210 px/s), então ele não acompanha o ponto e fica perto do herói. Precisa ver na tela.
- **Trajetória e alcance:** anda em linha reta até o alvo, a 140 px/s no nível 1. Velocidade em px do mundo. Não há arco, zigue-zague nem pulo no código. Na prática, persegue só quem está a até 340 px do herói.
- **Área:** nenhuma. Cada toque é em um alvo só. O contato vale a até 12 px + raio do monstro, no plano achatado.
- **Dano por nível:** dano comum, sem bônus de raridade e com o multiplicador do herói em 1,0 (o padrão). O bônus de raridade multiplica o total do dano: cada carta de golpe soma o bonus_arma da própria raridade (raro +18%, épico +40%, lendário +80%), e a soma das cartas desse golpe vale como um bônus só. Ex.: duas cartas raras dão ×1,36. Cada toque sai arredondado para inteiro (mínimo 1).

| Nível | Dano (comum) | Como muda | Acumulado: quantidade · duração · recarga · velocidade · intervalo |
|---|---|---|---|
| 1 | 9 | (base) | 1 · 5 s · 3 s · 140 px/s · 0,5 s |
| 2 | 12 | +3 de dano | 1 · 5 s · 3 s · 140 px/s · 0,5 s |
| 3 | 12 | +1,5 s de duração | 1 · 6,5 s · 3 s · 140 px/s · 0,5 s |
| 4 | 12 | +1 serpente | 2 · 6,5 s · 3 s · 140 px/s · 0,5 s |
| 5 | 16 | +4 de dano e bate mais | 2 · 6,5 s · 3 s · 140 px/s · 0,4 s |

- **Como aplica:** por tique, por espírito. Ao tocar o alvo, dá o dano e espera 0,5 s para tocar de novo (a espera corre mesmo fora de contato, e o primeiro toque é imediato). Um espírito toca um alvo por vez. Sem perfuração e sem área. Vários espíritos podem tocar o mesmo alvo. A velocidade de ataque encurta só a recarga, não o intervalo do toque.
- **Efeitos de status:** empurrão 30 (valor fixo do código, dividido pelo peso do monstro); atordoamento 0,05 s (vezes o multiplicador do monstro; chefe não para); lentidão: nenhum; queimadura: nenhum (não existe para aliado).
- **Limites na tela:** o pool de golpes novos tem 48 slots (MAX em armas_novas.gd), dividido com projétil, nuvem, anel, meteoro e os outros aliados. Esta arma: média de 1,7 espíritos no nível 1 e 4,3 no nível 5. Pico teórico (cadência regular) = quantidade × ceil(duração ÷ recarga): 2 no nível 1 e 6 no nível 5. Invocação sem slot livre é descartada sem aviso.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação e disparo: não existem. O espírito aparece pronto no quadro da invocação (0 quadros).
  - Viagem: até o alvo. 100 px levam 0,71 s (43 quadros) no nível 1. O sprite repete em loop de 4 quadros, cada um de 16 quadros de jogo (64 quadros, 1,07 s por ciclo, perto do balanço de 1,05 s que o código já tem).
  - Impacto: o espírito não tem quadro próprio. O monstro pisca 0,08 s (5 quadros) e para 0,05 s (3 quadros). O próximo toque vem em 0,5 s (30 quadros); no nível 5, 0,4 s (24 quadros).
  - Fim: últimos 0,5 s de vida (30 quadros), com alfa caindo de 1 a 0.
  - Tamanho do sprite: 40x16 px por quadro, 4 quadros em linha (ver _pacote). Hoje o código desenha um brilho de 20x20 px com pontinho de 5 px.
