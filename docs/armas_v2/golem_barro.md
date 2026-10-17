# Golem de Barro (golem_barro)
**Tipo:** aliado. **Ícone:** icone_u_marreta_enferrujada.
**O que faz:** Chama um golem de barro lento que persegue o inimigo mais perto e o esmaga. Dura bastante, mas anda devagar.
**Na prática:** Cada toque dá 11 de dano. Chama 1 golem a cada 4 s, se houver inimigo a até 340 px do herói (o bônus de velocidade de ataque deixa a recarga menor). O golem fica 7 s e anda 90 px por segundo, o segundo mais lento do grupo. Quando chega a 30 px do inimigo, para e bate no chão com os dois punhos a cada 0,8 s (o golpe leva 0,72 s e o dano cai no quadro da pancada, 0,35 s depois de o golpe começar). Sem inimigo por perto, tenta girar em volta do herói. Conta de média, sem bônus: cerca de 1,75 golem na tela no nível 1 e cerca de 2,4 no nível 5.

**Níveis:**
| Nível | O que muda |
|---|---|
| 1 | (base) |
| 2 | +4 de dano (dano 15) |
| 3 | +1,5 s de duração (dura 8,5 s) |
| 4 | +20 de velocidade (110 px por segundo) |
| 5 | +4 de dano e recarga 0,4 s menor. Acumulado no nível 5: 1 golem por vez, dano 19, dura 8,5 s, recarga 3,6 s, velocidade 110, intervalo 0,8 s. Nível máximo: uma carta lendária pula de 3 para 5 de uma vez. |

**Fusões e evoluções:** Sem fusão hoje. **Colosso de Pedra (proposta):** Golem de Barro nível 3 + Guardião de Pedra nível 3. As duas somem e entra um golpe de aliado mais pesado, com o dano do guardião e a velocidade do golem. Números a combinar.

**Animação e efeitos:** O golem é 3D pré-renderizado (`fonte_arte/blender_golem/gerar_golem.py`), 5 vistas (frente, 3/4, perfil, 3/4 costas, costas, o lado esquerdo é o espelho), quadro de 86x104 px. Anda de verdade: 8 quadros de passo, apoio duplo nos quadros 2 e 6, o corpo desce a cada pisada, o pé de apoio não escorrega (o ciclo por vista, 36 / 45 / 52 / 45 / 36 px, é medido nos pixels do pé e gravado no .json). Cada pisada solta poeira rasteira e um torrão, com tremor leve de câmera perto do herói. A pancada deixa rachaduras com brasa por 1,8 s, torrões e pedras que quicam e ficam ~1,5 s no chão, poeira clara em bafos e tremor de 1,6 px. Ao desmoronar (últimos 0,6 s de vida) solta uma rajada de torrões, que continua no chão depois que o golem some.
Especificação do campo "arte" (já feita): um golem feito de barro marrom-avermelhado, com torrões que se soltam a cada passo. Anda pesado e, ao chegar perto, bate no chão com os dois punhos espalhando terra. Cores: marrom-avermelhado, barro escuro, terra clara nos torrões, brasa laranja no peito. Tamanho: quadro de 86x104 px (o golem tem uns 64 px de largura); torrões de 4 a 6 px; rachaduras do tamanho do raio da pancada (42 px). Duração: rachaduras 1,8 s, torrões ~1,5 s.

**Mudanças em relação ao desenho original:** O golpe deixou de ser um toque em alvo único e virou pancada em área (raio 42 px, achatado como o chão; todo alvo dentro leva o mesmo dano), com antecipação. Empurrão (30) e atordoamento (0,05 s) por alvo são os do golpe antigo; a cadência continua o tique da carta (0,8 s no Golem, 1,0 s no Colosso). O alcance subiu de 12 para 30 px: o punho da arte, no quadro da pancada, chega a 23 px de perfil, e a pancada cai a 22,5 px à frente do pé. Números de dano, recarga, duração e velocidade: os do JSON.

**Pontos de atenção:**
- Um golem encostado dá 14 de dano por segundo no nível 1 e 24 no nível 5. Sozinho, é um dos aliados mais fracos em dano por segundo, mas dura 8,5 s no nível 5.
- Com 90 px/s, ele quase não alcança inimigos que se afastam. Só o nível 4 ajuda a velocidade, e ainda assim é pouco.
- O espírito só enxerga inimigos a até 340 px do herói. O alcance de 400 px do código é fixo e não está no JSON.
- O empurrão (30) e a pausa (0,05 s) de cada pancada, por alvo, são valores fixos no código, não sobem com o nível.
- O campo "provisorio" do JSON descreve o desenho antigo; o código usa a folha 3D, e o desenho antigo só aparece se a folha faltar.
- O bônus de raridade entra no dano (armas.gd, definir_golpe): cada carta de golpe soma o bonus_arma da própria raridade ao bônus do golpe, e o total multiplica o dano. Ver Esquemática.

## Esquemática
- **Gatilho:** a cada 4 s no nível 1 (3,6 s no nível 5, com os cortes de recarga). Quando a recarga zera e há monstro a até 340 px do herói (distância simples, sem achatar), invoca de uma vez a quantidade do nível (1 no nível 1, 1 no nível 5). Os espíritos nascem perto do herói (sorteado: até 30 px para os lados e 20 px para cima ou para baixo). Sem monstro nessa faixa, a recarga não gasta: tenta de novo em 0,3 s. A primeira tentativa vem 0,4 s depois de a carta entrar. A velocidade de ataque do herói (1,0 por padrão) divide a recarga.
- **Alvo:** a cada quadro, o espírito escolhe o monstro mais perto dele entre os que estão a até 340 px do herói (distância simples). A escolha mede no plano achatado (y dividido por 0,62), com limite de 400 px a partir do espírito. Monstro morrendo não conta. Sem alvo, o espírito gira em volta do herói a 50 px. O ponto da volta anda a 300 px/s, mais rápido que qualquer espírito deste lote (o mais rápido, o dragão no nível 5, faz 210 px/s), então ele não acompanha o ponto e fica perto do herói. Precisa ver na tela.
- **Trajetória e alcance:** anda em linha reta até o alvo, a 90 px/s no nível 1 (110 px/s no nível 5). Velocidade em px do mundo. Não há arco, zigue-zague nem pulo no código. Na prática, persegue só quem está a até 340 px do herói.
- **Área:** a pancada cai a 22,5 px à frente do pé do golem (ponto guardado no começo do golpe) e pega todo monstro dentro de uma elipse de 42 px de raio + raio do monstro (achatada pelo chão, y x 0,62). O golem para a 30 px + raio do alvo, no plano achatado.
- **Dano por nível:** dano comum, sem bônus de raridade e com o multiplicador do herói em 1,0 (o padrão). O bônus de raridade multiplica o total do dano: cada carta de golpe soma o bonus_arma da própria raridade (raro +18%, épico +40%, lendário +80%), e a soma das cartas desse golpe vale como um bônus só. Ex.: duas cartas raras dão ×1,36. Cada toque sai arredondado para inteiro (mínimo 1).

| Nível | Dano (comum) | Como muda | Acumulado: quantidade · duração · recarga · velocidade · intervalo |
|---|---|---|---|
| 1 | 11 | (base) | 1 · 7 s · 4 s · 90 px/s · 0,8 s |
| 2 | 15 | +4 de dano | 1 · 7 s · 4 s · 90 px/s · 0,8 s |
| 3 | 15 | +1,5 s de duração | 1 · 8,5 s · 4 s · 90 px/s · 0,8 s |
| 4 | 15 | +20 de velocidade | 1 · 8,5 s · 4 s · 110 px/s · 0,8 s |
| 5 | 19 | +4 dano e recarga menor | 1 · 8,5 s · 3,6 s · 110 px/s · 0,8 s |

- **Como aplica:** por tique, por espírito. Em alcance, para e começa o golpe (0,72 s); o dano cai uma vez no quadro da pancada, em área. O ciclo inteiro é o tique da carta (0,8 s; nunca menos que o golpe + 0,08 s). O primeiro golpe começa assim que ele chega ao alcance. Vários espíritos podem tocar o mesmo alvo. A velocidade de ataque encurta só a recarga, não o intervalo do toque.
- **Efeitos de status:** empurrão 30 por alvo (valor fixo do código, dividido pelo peso do monstro); atordoamento 0,05 s (vezes o multiplicador do monstro; chefe não para); lentidão: nenhum; queimadura: nenhum (não existe para aliado).
- **Limites na tela:** o pool de golpes novos tem 48 slots (MAX em armas_novas.gd), dividido com projétil, nuvem, anel, meteoro e os outros aliados. Esta arma: média de 1,8 espíritos no nível 1 e 2,4 no nível 5. Pico teórico (cadência regular) = quantidade × ceil(duração ÷ recarga): 2 no nível 1 e 3 no nível 5. Invocação sem slot livre é descartada sem aviso.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação e disparo: não existem. O espírito aparece pronto no quadro da invocação (0 quadros).
  - Viagem: até o alvo. 100 px levam 1,11 s (67 quadros) no nível 1 (0,91 s no nível 5). O sprite repete em loop de 4 quadros, cada um de 16 quadros de jogo (64 quadros, 1,07 s por ciclo, perto do balanço de 1,05 s que o código já tem).
  - Impacto: o espírito não tem quadro próprio. O monstro pisca 0,08 s (5 quadros) e para 0,05 s (3 quadros). O próximo toque vem em 0,8 s (48 quadros).
  - Fim: últimos 0,5 s de vida (30 quadros), com alfa caindo de 1 a 0.
  - Tamanho do sprite: 86x104 px por quadro, 16 colunas (8 de andar, 8 de ataque) x 5 linhas (vistas), pé em (40, 83).
