# Esqueleto Guerreiro (esqueleto_guerreiro)
**Tipo:** aliado. **Ícone:** icone_u_espada_treino.
**O que faz:** Chama dois esqueletos que saem do chão e perseguem o inimigo mais perto. No contato, fazem um corte com a espada curta.
**Na prática:** Cada corte dá 9 de dano. Chama 2 esqueletos a cada 3 s, se houver inimigo a até 340 px do herói (o bônus de velocidade de ataque deixa a recarga menor). Cada esqueleto fica 5 s e anda 130 px por segundo. Enquanto estiver encostado no inimigo, corta a cada 0,6 s. Sem inimigo por perto, tenta girar em volta do herói. Conta de média, sem bônus: cerca de 3,3 esqueletos na tela no nível 1 e cerca de 6,9 no nível 5.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) |
| 2 | +3 de dano (dano 12) |
| 3 | +1 esqueleto por invocação (3 por vez) |
| 4 | +1 s de duração (dura 6 s) |
| 5 | +4 de dano e recarga 0,4 s menor. Acumulado no nível 5: 3 esqueletos por vez, dano 16, dura 6 s, recarga 2,6 s, velocidade 130, intervalo 0,6 s. Nível máximo: uma carta lendária pula de 3 para 5 de uma vez. |

**Fusões e evoluções:** Sem fusão hoje. **Exército Esquecido (proposta):** Esqueleto Guerreiro nível 3 + Fantasma da Mata nível 3. As duas somem e entra um golpe que chama esqueletos e fantasmas juntos. Números a combinar.

**Animação e efeitos:** Hoje, o placeholder é um brilho na cor da arma (a textura de brilho do jogo, a 60% da cor) com um pontinho branco de 5 px por cima. O esqueleto flutua 10 px acima do chão, balança 2 px e some nos últimos 0,5 s de vida. Não há nuvem de terra saindo do chão nem arco de corte.
Especificação do campo "arte" (para o Alisson substituir): esqueleto humanoide de ossos brancos-amarelados, com uma espada curta na mão, que sai do chão em meio a uma nuvem de terra e corre até o inimigo. No contato, faz um corte em arco. Cores: branco-osso, bege, cinza nos vãos dos ossos. Tamanho: esqueleto de 30x44 px; arco de corte de 30 px. Duração: o arco de corte dura 0,2 s.

**Mudanças em relação ao desenho original:** Nenhuma no desenho: segue o desenho original do PR #192. Números da ficha conferidos com armas_novas.gd e dados/v2_cartas.json (2026-10-12): sem diferença.

**Pontos de atenção:**
- Um esqueleto encostado dá 15 de dano por segundo no nível 1 e 27 no nível 5. Com 3 esqueletos no mesmo alvo, o nível 5 chega perto de 80 por segundo.
- Como o grupo tem muitos corpos na tela, vale checar se o limite de 48 itens do pool (dividido com projéteis, nuvens e os outros golpes) estoura em partidas cheias. Quando o pool enche, a invocação é descartada sem aviso.
- O espírito só enxerga inimigos a até 340 px do herói. O alcance de 400 px do código é fixo e não está no JSON.
- O empurrão (30) e a pausa (0,05 s) de cada corte são valores fixos no código, não sobem com o nível.
- O campo "provisorio" do JSON descreve um bastão com arco fino que o código não desenha: o que aparece é o brilho com pontinho.
- O bônus de raridade entra no dano (armas.gd, definir_golpe): cada carta de golpe soma o bonus_arma da própria raridade ao bônus do golpe, e o total multiplica o dano. Ver Esquemática.

## Esquemática
- **Gatilho:** a cada 3 s no nível 1 (2,6 s no nível 5, com os cortes de recarga). Quando a recarga zera e há monstro a até 340 px do herói (distância simples, sem achatar), invoca de uma vez a quantidade do nível (2 no nível 1, 3 no nível 5). Os espíritos nascem perto do herói (sorteado: até 30 px para os lados e 20 px para cima ou para baixo). Sem monstro nessa faixa, a recarga não gasta: tenta de novo em 0,3 s. A primeira tentativa vem 0,4 s depois de a carta entrar. A velocidade de ataque do herói (1,0 por padrão) divide a recarga.
- **Alvo:** a cada quadro, o espírito escolhe o monstro mais perto dele entre os que estão a até 340 px do herói (distância simples). A escolha mede no plano achatado (y dividido por 0,62), com limite de 400 px a partir do espírito. Monstro morrendo não conta. Sem alvo, o espírito gira em volta do herói a 50 px. O ponto da volta anda a 300 px/s, mais rápido que qualquer espírito deste lote (o mais rápido, o dragão no nível 5, faz 210 px/s), então ele não acompanha o ponto e fica perto do herói. Precisa ver na tela.
- **Trajetória e alcance:** anda em linha reta até o alvo, a 130 px/s no nível 1. Velocidade em px do mundo. Não há arco, zigue-zague nem pulo no código. Na prática, persegue só quem está a até 340 px do herói.
- **Área:** nenhuma. Cada toque é em um alvo só. O contato vale a até 12 px + raio do monstro, no plano achatado.
- **Dano por nível:** dano comum, sem bônus de raridade e com o multiplicador do herói em 1,0 (o padrão). O bônus de raridade multiplica o total do dano: cada carta de golpe soma o bonus_arma da própria raridade (raro +18%, épico +40%, lendário +80%), e a soma das cartas desse golpe vale como um bônus só. Ex.: duas cartas raras dão ×1,36. Cada toque sai arredondado para inteiro (mínimo 1).

| Nível | Dano (comum) | Como muda | Acumulado: quantidade · duração · recarga · velocidade · intervalo |
|---|---|---|---|
| 1 | 9 | (base) | 2 · 5 s · 3 s · 130 px/s · 0,6 s |
| 2 | 12 | +3 de dano | 2 · 5 s · 3 s · 130 px/s · 0,6 s |
| 3 | 12 | +1 esqueleto | 3 · 5 s · 3 s · 130 px/s · 0,6 s |
| 4 | 12 | +1 s de duração | 3 · 6 s · 3 s · 130 px/s · 0,6 s |
| 5 | 16 | +4 dano e recarga menor | 3 · 6 s · 2,6 s · 130 px/s · 0,6 s |

- **Como aplica:** por tique, por espírito. Ao tocar o alvo, dá o dano e espera 0,6 s para tocar de novo (a espera corre mesmo fora de contato, e o primeiro toque é imediato). Um espírito toca um alvo por vez. Sem perfuração e sem área. Vários espíritos podem tocar o mesmo alvo. A velocidade de ataque encurta só a recarga, não o intervalo do toque.
- **Efeitos de status:** empurrão 30 (valor fixo do código, dividido pelo peso do monstro); atordoamento 0,05 s (vezes o multiplicador do monstro; chefe não para); lentidão: nenhum; queimadura: nenhum (não existe para aliado).
- **Limites na tela:** o pool de golpes novos tem 48 slots (MAX em armas_novas.gd), dividido com projétil, nuvem, anel, meteoro e os outros aliados. Esta arma: média de 3,3 espíritos no nível 1 e 6,9 no nível 5. Pico teórico (cadência regular) = quantidade × ceil(duração ÷ recarga): 4 no nível 1 e 9 no nível 5. Invocação sem slot livre é descartada sem aviso.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação e disparo: não existem. O espírito aparece pronto no quadro da invocação (0 quadros).
  - Viagem: até o alvo. 100 px levam 0,77 s (46 quadros) no nível 1. O sprite repete em loop de 4 quadros, cada um de 16 quadros de jogo (64 quadros, 1,07 s por ciclo, perto do balanço de 1,05 s que o código já tem).
  - Impacto: o espírito não tem quadro próprio. O monstro pisca 0,08 s (5 quadros) e para 0,05 s (3 quadros). O próximo toque vem em 0,6 s (36 quadros).
  - Fim: últimos 0,5 s de vida (30 quadros), com alfa caindo de 1 a 0.
  - Tamanho do sprite: 30x44 px por quadro, 4 quadros em linha (ver _pacote). Hoje o código desenha um brilho de 20x20 px com pontinho de 5 px.
