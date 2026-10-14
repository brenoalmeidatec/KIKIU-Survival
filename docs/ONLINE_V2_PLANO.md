# Online da v2 (coop): estudo e plano em etapas

Estudo de arquitetura, sem código do jogo. Escrito em 2026-10-14 pelo Claude do Breno (Sonnet 5.5) para o Claude do Alisson, dono de sistemas e integração. Base: `origin/main` em `a90b1fd`, Godot 4.4.1. Decisão do Alisson: **o coop online vem antes da arena**. Hoje a v2 (`jogos/hordas/projeto/v2/`) é só solo. Relaciona-se com a issue #133 (Marco 9), que pedia o online da v1 de volta.

Tudo o que está marcado como *medir* é estimativa de conta, não de teste real. Nada aqui foi rodado em duas casas.

## 1. O que já existe e o que dá para portar

**Transporte e sala (v1 e Cairu).** Tudo é ENet sobre UDP, porta 7777, até 6 pessoas, o anfitrião é o servidor (`ENetMultiplayerPeer.create_server`, igual em `jogos/cairu/projeto/scripts/rede.gd` e em `jogos/hordas/projeto/scripts/hordas/rede.gd`, que já é autoload `Rede` no `project.godot`). Não há WebRTC, UPnP nem servidor de relay no repositório (a única ocorrência de "relay" é um comentário do canal de voz). Como o jogo passa pela internet:

| Peça | Onde está | Estado |
|---|---|---|
| Sala, lista de jogadores, recusa de sala cheia | `Rede` (v1) | Pronto, mas acoplado ao herói/ficha/mochila da v1 |
| Endereço digitado `ip:porta` ou `nome:porta` | `Rede.entrar` | Pronto |
| NAT entre casas | túnel gratuito **playit.gg** (`jogos/cairu/ferramentas/abrir_tunel_playit.bat`, só o anfitrião usa) | Nunca testado em duas casas (LOGBOOK: "Ninguém fez ainda") |
| Lista de salas na rede local | `Salas`: broadcast UDP na 7778 a cada 2 s | Pronto na v1 |
| Lista de salas na internet | `Salas`: anúncio HTTPS no ntfy.sh, tópico `kikiu-survival-salas-v1`, opt-in do anfitrião | Pronto na v1 |
| Foto da horda compacta | `online.gd` `compactar`: 12 B de cabeçalho + 11 B por vírus + 9 B por tiro, 15 Hz, raio 420, teto 220 por foto | Pronto, **é a base certa** |
| Acertos do cliente em lote, morte avisada, recompensa pessoal, reviver, "todos caídos" | `online.gd` | Pronto na v1, acoplado a `arena.gd` |
| Testes de 2 instâncias | `testes/online_*.sh` (5 scripts, `--online=host/join --bot --sair=N`) | Prontos na v1 |

**O que a v2 não tem:** nada de rede. `mundo.gd` tem um herói só (`mundo.heroi`, usado 90 vezes em 21 arquivos), `combate.gd` assume esse herói, e a horda não é a da v1 (`inimigos.gd`): é um `Monstro` por bicho, desenhado em MultiMesh por `horda.gd`.

**Decisão sobre o que portar.** Não copiar `online.gd` (562 linhas presas a `arena.gd`). Portar **o desenho e o formato de pacote**, que já foram validados, num módulo novo da v2. Para o transporte, criar `v2/coop_rede.gd` (nó, não autoload; a v1 fica intacta) com a casca de `Rede`: criar sala, entrar, lista, sair, sinais de queda. A Cairu continua só como referência de leitura.

**WebRTC não vale.** No Godot 4 desktop ele exige a extensão `webrtc-native`, mais um servidor de sinalização, mais TURN para os casos em que o furo de NAT falha. É mais superfície de falha que o playit, que já funciona como "endereço público para a porta 7777" sem mudar o código do jogo.

**Risco assumido do playit.** É serviço de terceiros e a latência extra do relay deles para o Brasil não foi medida (*medir* na etapa 9). Plano B sem código: ZeroTier/Tailscale/Radmin (rede virtual, o endereço vira IP privado) e, para quem tem IP público, abrir a 7777/UDP no roteador. Na etapa 9 o jogo só precisa **dizer com clareza** quando a conexão falha e sugerir essas saídas.

**Issue #133.** Pede: estado de mapa/baús/relíquias/missão por semente, scripts `online_*.sh` verdes com 2 instâncias, duelo por região, espectador, nomes na tela, partida real de 4 pessoas. Os TODOs de `missao_chefe.gd` e `loja.gd` são da v1; na v2 o equivalente é o estado dos `_marcadores`, baús e mercador (etapa 7). O duelo e o espectador ficam **depois** do coop da v2.

## 2. Modelo de rede

### O que o código da v2 impõe

- A simulação anda com `dt` variável: `mundo._process` chama `avancar(minf(delta, 0.1))`. Só os testes usam passo fixo.
- `combate.passo_tempo` devolve 0 no hit-stop (`parada_t`, relógio real), na câmera lenta e em `pausado` (carta, baú, morte, resultado). O mundo inteiro para.
- Há 81 chamadas de `randf/randi` globais em `cartas`, `elites`, `monstro`, `mundo` e `diretor`, mais `rng` por monstro. O `diretor` zera o seu `rng` para a semente fixa 7777. Os mapas são JSON estáticos (semente 11 só para o `_rng` do mundo), então o **mapa já é igual nas duas máquinas** sem sincronizar nada.
- O teto do diretor é **84 monstros vivos** (`teto` em `dados/v2_combate.json`, `cap_fim` 70, ondas de 18+6 por onda). "Centenas" só existem no `--estresse=N`. O dimensionamento abaixo cobre 84 (normal), 220 (o teto de foto da v1) e 300 (estresse).
- Velocidade do monstro: `VEL_CACA = 54 px/s`.
- A IA do monstro recebe **uma posição de alvo** (`Monstro.atualizar(dt, heroi_pos, heroi_raio)`); a escolha do alvo é fácil de generalizar.

### Opções

| | A. Host autoritativo + snapshot + interpolação | B. Lockstep determinístico | C. Híbrido (semente local, só eventos) |
|---|---|---|---|
| Idéia | O anfitrião simula monstros; clientes recebem foto 15 Hz e interpolam. Cada um é dono do próprio herói e dos próprios golpes | Todos simulam tudo, trocam só entradas | Cada um simula a horda com a mesma semente; só mortes, danos e spawns viajam |
| Banda por cliente | 84 monstros: 12+11·84 = 936 B x 15 = **14 KB/s** (115 kbps). 220: 2,4 KB x 15 = **36 KB/s**. 300 (cortado em 220): igual | Desprezível (entradas, 1 KB/s) | Baixa, mas cresce com as correções |
| Banda do anfitrião (3 clientes) | 42 KB/s a 108 KB/s, mais ~2 KB/s de posições e hits | ~3 KB/s | ~5 a 20 KB/s |
| Latência | Cliente vê a horda ~100 a 130 ms atrasada (buffer de 2 fotos). Com 54 px/s são ~7 px de erro, menos de 1 corpo. O herói próprio responde sem atraso | O jogo inteiro anda na velocidade do pior RTT + atraso de entrada. Máquina fraca (i5-3470) segura todos | Sem atraso visível, até desincronizar |
| Mudança no código | **Média**: monstros "fantoche" no cliente, `heroi` vira lista, hit-stop/pausa locais. Reuso do pacote da v1 | **Muito alta**: passo fixo, banir o relógio real, trocar os 81 `randf`, ordem de iteração da grade hash, `sin/cos` iguais em CPUs diferentes, cartas pausando todos | **Alta** e enganosa: monstro persegue jogadores diferentes e leva golpes diferentes em cada máquina, então diverge no primeiro segundo e vira A com mais bugs |
| Falha típica | Elite/chefe piscando se a foto cortar por ordem | Um desvio de 1 bit e as telas divergem para sempre; um jogador lento trava todos | Monstro fantasma, vida diferente, morte duplicada |
| Queda do anfitrião | Fim da sala (como na v1) | Fim da sala | Fim da sala |

### Recomendação

**A, no modelo que a v1 já provou:**

1. **Cada cliente é dono do próprio herói**: anda, esquiva, usa golpes e armas localmente (resposta imediata). Manda posição/animação a ~20 Hz (`unreliable_ordered`, ~16 B).
2. **O anfitrião é dono dos monstros**: IA, vida, spawn, elites, chefes, avisos de ataque. Escolhe o herói mais perto como alvo de cada monstro.
3. **Foto da horda 15 Hz**, só dos monstros no raio de cada cliente (+ chefes), no formato `compactar` da v1, ordenados por distância (não pela ordem da lista, senão o monstro pisca; a v1 já aprendeu isso). IDs **por nascimento**, não por instância do pool (o pool da v2 reaproveita o mesmo `Monstro`).
4. **Acertos** do cliente em lote `[id, dano, empurrão, índice da arma]`, o anfitrião aplica. Não revalida posição; confia no cliente (jogo entre amigos).
5. **Mortes** viajam como evento `[id, x, y, tipo, elite]`; cada um cria os próprios orbes e sorteios (zero tráfego de orbe).
6. **Dano de contato** é calculado no anfitrião e mandado ao dono do herói atingido, que aplica em `sofrer` (dash do cliente continua desviando).
7. **Interpolação** no cliente com buffer de ~100 ms; `Monstro` com flag `fantoche` (sem IA, sem colisão), desenhado pelo mesmo `horda.gd`. Elite e chefe (que têm nó) também viram fantoche.
8. Armas dos outros jogadores só aparecem como o dano nos monstros; eventos leves de golpe (índice da arma + posição) ficam como melhoria depois (o `ONLINE_KIKIU.md` já anotava isso).

### Banda total (conta, a confirmar na etapa 2)

| Cenário | Cada cliente (descida) | Anfitrião (subida), 2 / 3 / 4 jogadores |
|---|---|---|
| 84 monstros | ~15 KB/s | 15 / 30 / 45 KB/s |
| 220 monstros | ~37 KB/s | 37 / 74 / 111 KB/s |

Contando cabeçalhos UDP/ENet (~40 B por pacote). A subida de uma casa brasileira comum (10 a 40 Mbps = 1.250 a 5.000 KB/s) sobra. O gargalo previsível é **CPU do anfitrião** (i5-3470 é a máquina de teste do Breno), não a banda: a v2 já mede `c_separar`, `c_contato` no `--medir`, e a etapa 2 precisa acrescentar o custo de montar a foto.

**Latência entre casas no Brasil** (estimativa; *medir*): 20 a 60 ms de RTT entre capitais pelo caminho direto; o relay do playit pode somar algumas dezenas de ms. Com buffer de 100 ms o jogo deve ficar confortável até ~150 ms de RTT; acima disso o dano dos monstros "chega atrasado" e é aí que se consideraria predição.

### O que muda no código atual

| Ponto | Hoje | Coop |
|---|---|---|
| `mundo.heroi` (90 usos, 21 arquivos) | um herói | manter `mundo.heroi` = o local; criar `mundo.herois` (lista, com os remotos). Etapa 0 só adiciona a lista sem mudar comportamento |
| `Monstro.atualizar(dt, heroi_pos, raio)` | alvo único | o anfitrião passa o alvo mais perto (função `mundo.alvo_mais_perto(pos)`); cliente não chama |
| `combate._contato(h)` | contato com um herói | anfitrião varre todos os heróis e manda o dano ao dono |
| `combate.passo_tempo` / `hit_stop` / `camera_lenta` / `pausado` | **param o mundo todo** | viram **locais**: o hit-stop congela só a animação e o clarão do herói que bateu (sensação de impacto mantida), a câmera lenta de nível/morte vale só para a tela de quem subiu/morreu. O relógio e os monstros do anfitrião nunca param |
| `progresso.abrir_escolha` (carta) | pausa o mundo | não pausa (ver 3) |
| `diretor` | `rng` semente 7777, nasce em volta do herói | só no anfitrião; nasce em volta de um jogador sorteado; teto e taxa escalam (ver 3) |
| `randf/randi` globais | espalhados | **não precisa mudar** na opção A. É o motivo principal de escolher A: cada máquina sorteia o que é só dela (críticos, drops, cartas) |
| `Meta`/almas | save local | cada um grava o seu |
| Entrada | `Entrada` único | sem mudança (cada instância tem o seu teclado) |

## 3. Regras de jogo do coop (decisões do Alisson)

**Aprovado pelo Alisson em 2026-10-14:** os padrões dos itens 1, 2, 3, 4, 6 e 7, e hit-stop e câmera lenta **locais** (só na tela de quem bateu ou subiu de nível; ele vai jogar para confirmar a sensação). O item 5 segue o padrão até alguém pedir outra coisa.

1. **Escolha de cartas.** Cada um escolhe a sua, na hora que sobe de nível. *Proposto:* **o mundo não pausa**; o jogador que escolhe fica numa bolha (invencível e parado), com tempo limite de 15 s, depois escolhe sozinho a primeira carta; as outras pessoas continuam jogando e veem o aliado dentro da bolha. É a decisão que a v1 já tomou ("cartas e Esc não pausam"). Alternativa mais fácil de implementar mas ruim de jogar: pausar todos (um chato com 4 pessoas trava os outros 3). *Esc e pausa:* no coop o menu de pausa abre por cima mas a partida continua.
2. **XP e almas.** *Proposto:* **orbes pessoais** (cada cliente cria os seus quando recebe a morte, 100% do XP para quem pegou, sem tráfego de rede), nível e cartas por jogador. **Almas por jogador**, cada um grava as suas (`almas_partida` = XP coletado / 10, como hoje). Um pequeno bônus de equipe nas almas (sugestão: +10% por aliado vivo no fim) só se o Alisson quiser incentivar ficar junto.
3. **Morte e reviver.** *Proposto (igual à v1, decisão que já foi do Breno):* quem morre vira corpo no lugar; um aliado vivo segura **E** perto (~40 px) por 3 s dividido pelo `reviver` do herói de quem ajuda; volta com 50% de vida. Todos os corpos voltam quando o chefe da fase cair (se a v2 tiver fases) ou no próximo marco da partida. Todos caídos por 1 s = derrota para todos. A câmera lenta da morte só vale quando é a última pessoa; antes, a tela do caído segue um aliado vivo.
4. **Escala da horda.** *Proposto:* para cada jogador extra, **+60% na taxa de nascimento e no teto** (`taxa_*`, `cap_*`, `teto` de `v2_combate.json`), **+25% na vida** dos monstros e **+50% na vida dos chefes**; o dano não muda. O teto absoluto de monstros vivos fica em 220 (o que cabe na foto). Os spawns acontecem em volta de um jogador sorteado, não do centro do grupo, para não nascer monstro no meio de dois. É a regra "+30% por jogador" da v1, mais forte porque a v2 tem menos monstros por tela.
5. **Quem escolhe o mapa e o herói.** *Proposto:* só o anfitrião escolhe o mapa; cada um escolhe o seu herói e pode repetir (a v1 proibia repetir, mas na v2 o herói define só o visual e o secundário).
6. **Quando o anfitrião cai.** *Proposto:* fim da sala para todos, com a mensagem clara e as almas ganhas até ali creditadas. Migração de anfitrião fica fora do escopo.
7. **Máximo de jogadores.** *Proposto:* 4 no começo (2 a 4 é o foco do estudo), 6 como limite técnico depois de medir CPU.

## 4. Plano em etapas

Cada etapa é **1 PR pequeno e testável**. Todas mantêm o solo funcionando e o `CI` verde. Teste de 2 instâncias headless segue o padrão de `testes/online_golpe.sh`: anfitrião e cliente na mesma máquina, `--coop=host` e `--coop=join --endereco=127.0.0.1:7777`, `--bot`, `--sair=N`, e o script lê as linhas `coop:` dos logs e conta `SCRIPT ERROR`.

| # | Etapa | Entrega | Teste |
|---|---|---|---|
| 0 | **Preparar o solo** | `mundo.herois` (lista com o herói local), `alvo_mais_perto`, hit-stop/câmera lenta/pausa separados em "do mundo" e "local" sem mudar nada no solo. Flag `--coop` lida e ignorada | Os testes v2 atuais iguais; teste novo: com 2 heróis na lista o monstro persegue o mais perto |
| 1 | **Duas pessoas na rede local: movimento e golpe** | `v2/coop_rede.gd` (sala ENet, 7777), flags `--coop=host/join`, herói remoto desenhado (nome, animação, golpe) a 20 Hz. Sem monstros ainda | `coop_movimento.sh`: o host vê o cliente andar e golpear (posição e contagem de golpes batem), banda logada |
| 2 | **Horda do anfitrião vista pelo cliente** | Foto 15 Hz (`compactar` portado), `Monstro` fantoche, interpolação, ids por nascimento. Teto 84 | `coop_horda.sh`: a contagem e as posições do cliente ficam a menos de X px do host por 30 s; imprime KB/s por cliente e `c_foto` em µs. Teste de `compactar/descompactar` em unidade |
| 3 | **Golpes e mortes** | Acertos do cliente em lote, morte avisada, orbes pessoais, dano de contato mandado ao dono | `coop_golpe.sh`: o host conta os golpes recebidos do cliente; abates iguais nos dois |
| 4 | **Escala e elites/chefes** | Diretor com a escala por jogador (regra 4), alvo mais perto, elites e chefes como fantoches, avisos de ataque por evento | `coop_escala.sh`: com 2 jogadores o `teto` vira o esperado; chefe aparece nos dois |
| 5 | **Progressão sem pausa** | XP/nível/cartas por jogador, bolha da escolha (regra 1), hit-stop e câmera lenta locais | `coop_cartas.sh`: o cliente sobe de nível e o host segue andando sem parar; o tempo de partida do host não congela |
| 6 | **Morte, reviver, fim** | Corpo, reviver (regra 3), todos caídos, resultado e almas por jogador, anfitrião saindo no meio | `coop_morte.sh`: cliente morre, host revive, depois os dois morrem e ambos mostram o resultado |
| 7 | **Estado do mundo** | Baús, marcadores (alavancas, pilares, fragmentos), braseiros, mercador por evento do anfitrião | `coop_mundo.sh`: baú aberto no host some no cliente; fragmentos somam para todos |
| 8 | **Menu e sala** | "Jogar com amigos" no título, lobby (herói, nome, mapa), lista de salas na rede local (broadcast da `Salas`) e por endereço | Teste de UI do menu em headless; `coop_lobby.sh` com 3 instâncias |
| 9 | **Internet** | Túnel playit documentado e empacotado, mensagens claras de falha com saídas (ZeroTier, porta), medidor de ping/KB/s no F3, lista de salas via ntfy (opt-in) | Teste real do Breno e do Alisson de casas diferentes; resultado no LOGBOOK (ping, KB/s, quedas, CPU do anfitrião) |

**Estimativa de tamanho.** Etapas 0, 1 e 8 são pequenas; 2, 3, 5 e 6 são médias; 4, 7 e 9 são médias com risco de ajuste fino. Ordem de grandeza: **10 PRs, 3 deles grandes** (2, 3 e 5, porque tocam combate e mundo). A etapa 1 já entrega "dois jogadores se vendo na rede local" e a etapa 3 já é jogável.

## 5. Depois do online: tela dividida (pedido do Alisson, 2026-10-14)

Coop local na mesma máquina, com a tela dividida em 2 (e depois 4), cada jogador num controle. Fica para depois da etapa 9, mas as etapas 0 a 6 devem deixar o caminho aberto: `mundo.herois` com N heróis locais, entrada por dispositivo (`v2/entrada.gd` por jogador) e câmera, HUD e hit-stop "locais" por jogador, não globais. Com isso, a tela dividida vira um SubViewport por jogador sobre o mesmo mundo, sem rede. Medir o custo de dois SubViewports de 960x540 no Iris Xe antes de prometer.

## 6. Riscos e o que ficou aberto

- **CPU do anfitrião** com 4 jogadores e 220 monstros: precisa de medição na etapa 2, em especial na máquina fraca.
- **Elites e chefes** têm nós e efeitos próprios (`avisos.gd`, `elites.gd`, `chefe.gd`): o fantoche deles é o ponto mais delicado.
- **Hit-stop local** muda a sensação do golpe: o Alisson precisa jogar para aprovar.
- **Faltam dados**: latência real Brasil e custo do relay do playit; só a etapa 9 tira isso do campo da estimativa.
- **Fora do escopo agora**: arena/duelo (vem depois do coop), espectador, migração de anfitrião, predição de monstros no cliente.
