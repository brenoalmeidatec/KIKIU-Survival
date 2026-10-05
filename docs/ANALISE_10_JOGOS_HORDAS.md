# 10 jogos parecidos com o K.I.K.I.U: o que os faz bons e o que roubar

Continuação de `docs/analise_jogos_de_hordas.md`, que já cobre **Vampire Survivors, Megabonk e Risk of Rain 2** (loop, XP, diretor de dificuldade, builds). Aqui não repito esses três. Os 10 abaixo foram escolhidos por ensinarem algo diferente para o que o K.I.K.I.U já tem ou ainda precisa: corrida de 10 fases, mapa de escolhas entre fases, tela de ganhos, chefes com entrada, build com equipamentos, santuários e habilidades raras, online até 6 e duelo final.

Observação: a análise vem de conhecimento geral dos jogos (e de guias públicos); números exatos de cada jogo podem variar por versão. Servem como inspiração, não como especificação.

## Resumo rápido

| # | Jogo | O que ensina | Serve para |
|---|------|--------------|-----------|
| 1 | Brotato | Loja entre ondas, etiquetas de arma, risco/recompensa | tela de ganhos e loja |
| 2 | 20 Minutes Till Dawn | Mira própria, recarga, melhorias que mudam a arma | combate com peso |
| 3 | Halls of Torment | Equipamento com raridade, atmosfera sombria, chefes | fase de horror, loot |
| 4 | Deep Rock Galactic: Survivor | Classes com papel claro, biomas, objetivos na fase | variedade de fase, classes |
| 5 | Soulstone Survivors | Habilidades ativas, runas e combos, chefes grandes | habilidades "quebradas" |
| 6 | Death Must Die | Deuses e dádivas, escolha de chefe/trilha | santuários e mapa |
| 7 | HoloCure | Ataque especial, colaborações, personalidade dos heróis | identidade dos amigos |
| 8 | Hades | Dádivas combináveis, calor (dificuldade escolhida), narrativa curta | santuários e riscos |
| 9 | Slay the Spire | Mapa de nós com escolhas | mapa entre fases |
| 10 | Archero | Escolha de talento a cada sala, anjo/demônio | o mapa e as ofertas raras |

---

## 1. Brotato

**O que é.** Arena fechada, ondas curtas (20 a 90 s), até 6 armas ao mesmo tempo, loja entre as ondas.

**Por que é bom.**
- A **loja entre ondas** é o centro do jogo: você ganha material na onda e decide na loja. A tensão "gasto ou guardo" mantém a cabeça ocupada fora do combate.
- **Ondas curtas e limpas** deixam o ritmo claro: começa, aperta, acaba, loja.
- **Itens com custo no atributo** (mais dano, menos vida) criam builds com identidade em vez de "tudo sobe".
- As armas têm **tipos e etiquetas**, o que faz o jogador montar um conjunto (só facas, só armas de fogo).

**Mecânicas interessantes.** Travar (trancar) itens da loja para a próxima rodada; refazer a loja pagando; juntar duas armas iguais para subir de nível.

**Ideias para o K.I.K.I.U.**
- Tela de ganhos da fase (issue #32 item 7) pode virar **mini-loja**: o grupo gasta o ouro da fase antes do mapa. Cada um gasta o próprio.
- **Trancar item** e **rolar de novo** pagando: barato de fazer em dados e dá escolha real.
- **Etiquetas de equipamento** (fogo, aço, arcano...) com bônus por conjunto, ligando aos equipamentos em camadas do #19.

---

## 2. 20 Minutes Till Dawn

**O que é.** Sobrevivência de 20 minutos, mira com mouse, recarga manual, vira uma noite de monstros.

**Por que é bom.**
- A **mira manual** e a **recarga** dão habilidade ao jogador (não é só andar).
- As **melhorias mudam como a arma funciona** (tiro que perfura, que explode, que atravessa), não só número.
- **Runas** antes da partida dão um empurrão pequeno e um motivo para repetir.
- O **relógio até o amanhecer** deixa a meta clara sem pontuação.

**Mecânicas interessantes.** Cartas de nível com **efeito de comportamento**; escolha de arma e runa antes da corrida; monstros que mudam por minuto (invocadores, atiradores).

**Ideias.**
- No K.I.K.I.U, nas cartas, misturar **números** (dano) com **mudanças de comportamento** ("a lâmina agora volta", "o tiro racha em 2"). Isso é o que faz parecer "build" e não "fazer conta".
- **Fase 10 como "amanhecer"**: um contador visível de quanto falta para o chefe final dá sensação de final de filme.

---

## 3. Halls of Torment

**O que é.** Estilo Diablo clássico em horda: dungeon sombria, personagens com classe, **equipamentos que caem** com raridade.

**Por que é bom.**
- **Atmosfera**: luz, escuridão, sons graves. A mesma mecânica de Vampire Survivors vira outro jogo só pelo clima.
- **Loot de equipamento** (capacete, peitoral, botas...) com raridade dá o sabor de RPG de ação sem inventário pesado.
- **Chefes com padrão** e mapas diferentes por região, com objetivo (matar o chefe, não só sobreviver).

**Mecânicas interessantes.** Itens que **trocam atributos fixos por estilo**; passivos de classe que combinam com certas armas; progressão de dificuldade escolhida pelo jogador.

**Ideias.**
- Para a **fase de horror** pedida no #32: escurecer o mapa, luz só ao redor do herói e de tochas/santuários, inimigos que aparecem no escuro. Custo baixo em Godot (luz 2D e `CanvasModulate`).
- Raridade de equipamento por **cor da borda** (comum, raro, épico, lendário) e o equipamento aparecendo **no sprite**.

---

## 4. Deep Rock Galactic: Survivor

**O que é.** Versão em horda do jogo cooperativo de mineração: 4 classes (cada uma com papel), mapa com **recursos para minerar** e objetivo por fase.

**Por que é bom.**
- **Classes muito diferentes** (uma cuida de torretas, outra de mobilidade, etc.) fazem cada partida soar outra.
- **A fase tem tarefa**, não só tempo: minerar, defender um ponto, coletar. Isso quebra a monotonia.
- **Biomas** com inimigos e perigos próprios.
- Personalidade e humor nas falas.

**Mecânicas interessantes.** Armas com **melhorias alternativas** (cada arma tem opções que escolhem um caminho); recursos do mapa que viram upgrade permanente; bônus de equipe.

**Ideias.**
- As fases 1 a 9 hoje só alternam dois chefes. Dar a cada fase **um objetivo próprio** (defender o servidor X por 60 s, carregar uma "bateria" até um ponto, destruir 3 geradores) antes do chefe.
- No online, **papéis de equipe**: o Nicão que revive mais rápido já é um começo; criar mais um papel por herói (um que puxa vírus, um que dá escudo).
- Cada fase com **bioma/clima** próprio (a cor de `corrida.json` já ajuda).

---

## 5. Soulstone Survivors

**O que é.** Horda com **habilidades ativas**, runas que modificam tudo, e itens "de pedra" que mudam o estilo.

**Por que é bom.**
- **Habilidades ativas** (você aperta e algo grande acontece) dão picos de emoção que a horda automática não dá.
- **Runas** viram um segundo nível de build: cada habilidade tem encaixes.
- **Combos entre tipos** (fogo + área + projétil) criam explosões de poder: o momento "quebrado" que o jogador procura.
- Chefes enormes e telas cheias.

**Mecânicas interessantes.** Skill com tipos/etiquetas que as runas leem ("aumenta todo projétil", "aumenta toda área"); escolha de habilidade na partida.

**Ideias.**
- Para as **"habilidades únicas, super raras e quebradas"** do #32: cada uma é um modificador de regra, não um bônus (ex.: "todo kill solta uma bomba", "o dash deixa um rastro de fogo"). Funciona com um sistema de **etiquetas** que as raras leem.
- Um **botão de habilidade ativa por herói** (cooldown longo) além da arma automática.

---

## 6. Death Must Die

**O que é.** Mistura Hades com horda: heróis diferentes, **deuses que dão dádivas**, escolha de caminhos, chefes com mecânica.

**Por que é bom.**
- A **escolha de deuses/dádivas** dá identidade à corrida em segundos ("este run é do deus do fogo").
- **Trilhas escolhidas** entre fases mostram o que vem (recompensa antes de ir) e fazem o jogador planejar.
- Heróis com **estilo fixo** que se combinam com as dádivas.
- Chefes que pedem leitura de padrão, não só dano.

**Ideias.**
- Os **santuários** (3 por fase, 4 na última) podem oferecer **2 a 3 dádivas de um "deus" da fase**, com tema (Firewall, Antivírus, Nuvem). Isso já existe em parte; falta o **tema** e os **pares** (duas dádivas de deuses diferentes liberam uma terceira, como no Hades).
- Mostrar no **mapa** o que cada destino dá (ícone da recompensa) antes de escolher.

---

## 7. HoloCure

**O que é.** Fã-jogo gratuito de horda com personagens de vtubers: **ataque especial** com cooldown, **colaborações** (duas armas viram uma), "stamps" de progressão.

**Por que é bom.**
- **Personalidade**: cada personagem tem arma, especial e frase própria. O jogador joga por afeto, não só pelo número.
- **Especial** com recarga: um botão que dá pico de poder.
- **Colaborações**: combinação de duas armas gera uma nova, o que ensina o jogador a experimentar.
- Muito conteúdo e **humor** nas referências.

**Ideias.**
- Esta é a **mais próxima do K.I.K.I.U com os seus amigos**: cada herói (Nicão, Lucas, João, Matheus, Beto, Lukako, Fábio, Breno) com **especial próprio**, frase de entrada e piada. O Lucas, por exemplo, teria um especial caótico; o Nicão, lento e forte.
- **Colaborações** (evoluções) hoje existem em `evolucoes.json`; pensar em **pares de heróis** no online: se dois amigos usam o especial juntos, sai um combo.
- Frases curtas na **entrada do personagem** (#32 item 6) com humor da turma.

---

## 8. Hades

**O que é.** Ação com corrida (run) curta, **dádivas de deuses** com raridade, **duo** (dois deuses combinam), e **calor** (o jogador liga dificuldades extras).

**Por que é bom.**
- **Escolha entre 3 dádivas, cada uma de um deus** a cada sala: a decisão é fácil de entender e rica.
- **Raridade e melhoria** da mesma dádiva ao longo da corrida.
- **Duo**: o jogador caça uma combinação específica, o que cria objetivo dentro da corrida.
- **Calor**: o jogo oferece dificuldade escolhida em troca de recompensa; resolve o problema de "fácil demais" para quem melhora.
- **Narrativa curta e constante** entre salas (cada morte avança a história).

**Ideias.**
- **Calor no K.I.K.I.U**: um menu antes da corrida em que o grupo liga "modificadores" (inimigos mais rápidos, sem cura entre fases, chefe com mais vida) em troca de mais ouro/XP. Dados em JSON, fácil.
- **Narrativa**: uma frase de cada amigo no fim da fase (lore/"Lory"!) em vez de texto longo.
- **Duo de dádivas** nos santuários (ver Death Must Die).

---

## 9. Slay the Spire

**O que é.** Jogo de cartas, mas o que importa aqui é o **mapa de nós**: a cada ato você escolhe um caminho entre combate, elite, loja, descanso, evento e chefe.

**Por que é bom.**
- O mapa mostra **toda a rota** e deixa o jogador **planejar** (arriscar elite por relíquia ou descansar antes do chefe).
- Cada tipo de nó tem **função clara**: combate = recurso, elite = risco, descanso = cura/melhoria, loja = gasto, evento = surpresa.
- **Poucas escolhas, cada uma importante**, e a corrida nunca tem o mesmo desenho.
- O **descanso** pede decisão (curar ou melhorar), então até o nó "calmo" tem tensão.

**Ideias para o mapa de fases (#32 item 8).**
- Mapa de **camadas**: depois de cada fase aparecem 2 a 3 destinos; as 10 fases viram 10 camadas e a última é sempre o chefe Tela Azul.
- Tipos de destino, em `dados/mapa.json`: **Fase normal** (pode mudar o tema/objetivo), **Fase de elite** (mais perigosa, mais ouro/raro), **Descanso** (cura ou melhora um equipamento), **Loja**, **Evento** (história/escolha com risco), **Santuário raro** (habilidade quebrada).
- Mostrar o **ícone da recompensa** antes de escolher.
- **Online**: o anfitrião mostra o mapa para todos; cada um **vota** e o mais votado vale (empate: o anfitrião decide). Votar é barato de implementar com a rede atual (uma mensagem `voto_destino`).
- Guardar a rota gerada com uma **semente** (seed), para que todos vejam o mesmo mapa e o mesmo código funcione no solo e no online.

---

## 10. Archero

**O que é.** Jogo mobile de salas: você anda, para para atirar, e a cada sala escolhe **1 entre 3 talentos**; às vezes aparece o **anjo** (oferta de cura/talento) e o **demônio** (poder em troca de vida).

**Por que é bom.**
- **Uma escolha por sala**: ritmo rápido e fácil de entender.
- **Demônio**: trocar vida por poder é o risco-recompensa mais simples que existe.
- **Anjo** aparece depois do chefe e funciona como "recompensa de descanso".
- Padrões de projéteis dos inimigos (desviar) criam habilidade sem mira.

**Ideias.**
- Nó de mapa **"Troca"** (demônio): oferece um poder forte por vida máxima, uma maldição ou um item. Dá a graça das habilidades raras sem inflar o jogo.
- **Anjo** como destino raro depois de chefe: cura o grupo e **revive** quem caiu (liga ao revive do K.I.K.I.U).
- Inimigos com **padrões de tiro legíveis** nas fases altas (círculos, leques), em vez de só mais vida.

---

## Padrões que se repetem nos jogos bons

1. **Escolha pequena e frequente.** 3 opções, entendidas em 2 segundos (Brotato, Hades, Archero, VS). O K.I.K.I.U já tem; manter cartas legíveis (ícone, nome, uma linha).
2. **Picos de poder previsíveis.** Algo que o jogador **espera e caça**: evolução (VS), duo (Hades), colaboração (HoloCure), combo de runas (Soulstone). Falta um alvo claro de "build quebrada" por herói.
3. **Risco opcional pago em recompensa.** Calor (Hades), demônio (Archero), elite (StS). Põe dificuldade na mão do jogador.
4. **Fases com identidade.** Clima, inimigos e **objetivo** diferentes (DRG, Halls). Hoje as fases 1 a 9 só mudam cor e duração.
5. **Personalidade acima do número.** HoloCure vence por afeto. O K.I.K.I.U tem um trunfo que nenhum desses tem: **amigos reais**. Frases, especial e entrada de cada um valem mais que mais um passivo.
6. **Descanso é decisão.** O nó "calmo" ainda pede escolha (StS, Brotato).
7. **Informação antes da escolha.** Mostrar o que cada destino/oferta dá (StS, DMD).
8. **Fim de fase com respiro e resumo.** Tela de ganhos como momento de prazer (Brotato).

## Plano sugerido (ordem para o Alisson, pequeno de cada vez)

1. **Tela de ganhos + mini-loja** (Brotato): 1 PR.
2. **Entradas e frases dos heróis** (HoloCure): reaproveitar a entrada do chefe.
3. **Mapa de nós em `dados/mapa.json`** com Fase, Elite, Descanso, Loja, Evento, Troca (StS + Archero + DMD). Votação no online.
4. **Especial por herói** com botão próprio (HoloCure + Soulstone).
5. **Etiquetas** em armas/equipamentos e **bônus de conjunto** (Brotato + Soulstone), base das habilidades raras.
6. **Dádivas de santuário com tema e duo** (Hades + DMD).
7. **Objetivo próprio por fase** (DRG), começando pelas fases 3, 5 e 7.
8. **Fase de horror**: escuro + luz ao redor do herói + inimigos tenebrosos (Halls).
9. **Calor** (Hades): modificadores opcionais antes da corrida.
10. **Cartas com mudança de comportamento** (20 Minutes), aos poucos.

## Perguntas que valem fazer ao Breno

- Quer **especial por herói** (botão) ou o jogo continua 100% automático?
- O mapa deve **mostrar toda a rota** (StS) ou só os 2 a 3 próximos destinos (mais surpresa)?
- Quer **dificuldade escolhida (calor)** logo na primeira versão?
- Qual das fases vira a **fase de horror**?
