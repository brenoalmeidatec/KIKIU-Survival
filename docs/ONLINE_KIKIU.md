# K.I.K.I.U online: o que fazer (para o Alisson)

O Breno quer testar o online do K.I.K.I.U com o Alisson, de casas diferentes. Esta é a tarefa, com o desenho que já pensei depois de ler o código. **Nada disso foi construído ainda**; o que existe hoje é a corrida de 10 fases e o duelo final contra robôs (PR #1).

Código do jogo: `jogos/hordas/projeto/scripts/hordas/`. Rede pronta para reaproveitar (com a sua validação): `jogos/cairu/projeto/scripts/rede.gd`. Túnel: `abrir_tunel_playit.bat` (está em `/mnt/project-files/jogo/build/` e deve ir no zip do K.I.K.I.U). Meta: até 6 jogadores, o anfitrião é o servidor (ENet, UDP 7777).

## 1. Sala e menu
- Copiar `rede.gd` para o projeto de hordas como autoload `Rede` (no `project.godot`). Tirar as partes de mundo/cenas da Cairu e manter: criar sala, entrar por endereço, lista de jogadores, escolha de herói sem repetir, `sair`, sinais, validação.
- Menu do título: Jogar sozinho / Criar sala / Entrar em sala / Sair. Entrar pede o endereço (campo de texto desenhado em `main.gd` com `_input`, aceita Ctrl+V e lembra o último endereço). Sala mostra quem entrou e o herói de cada um; só o anfitrião aperta Enter para começar.
- Heróis da sala: os 8 de `pvp.elenco` (cada um só uma pessoa).
- Flags de teste para 2 instâncias: `--online=host`, `--online=join --endereco=127.0.0.1:7777`, junto com `--bot`.

## 2. Horda juntos (o anfitrião manda nos vírus)
- Só o anfitrião roda `diretor_hordas.gd` e a IA dos vírus (`inimigos.gd`). Os clientes recebem uma foto ~15 vezes por segundo, só dos vírus perto de cada um (raio ~420 + chefes): `PackedFloat32Array` com `[id, tipo_idx, x, y, hp_frac, flags]` por vírus, mais os tiros dos vírus. Cliente cria/atualiza/remove os `V` por id e suaviza a posição; não roda IA.
- Cada um roda as próprias armas (`armas.gd`) contra a lista local de vírus. `inimigos.ferir` no cliente tira vida local (número, brilho) e manda ao anfitrião, em lotes, `[id, dano, kx, ky]`. O anfitrião aplica de verdade.
- Quando um vírus morre, o anfitrião avisa todos (`[id, x, y, tipo, elite]`) e **cada um** cria as próprias gemas e sorteia os próprios drops (XP, baú e tomada são pessoais).
- IA dos vírus: escolher o jogador mais perto entre o do anfitrião e os remotos (posição vem do pacote de posição). Dano de contato e de tiro em remoto: o anfitrião manda `_dano(valor, fonte)` ao cliente, que aplica em `jogador.sofrer` (assim o dash do cliente continua desviando).
- `arena.jogadores()` passa a devolver o número de pessoas (já escala a dificuldade: +30% por jogador extra). `_ponto_fora()` e os eventos "anel/enxame" do diretor usam um jogador sorteado.
- Posição de cada um: `_pos` unreliable a 15 Hz (x, y, direção, andando, vida, caído). Jogadores remotos aparecem como sprite com nome e barra de vida.

## 2b. Fases juntos
- O chefe da fase cai no anfitrião, que manda `fase_completa`. Todos fazem o descanso local (limpa tela, puxa XP, cura 50%, baú) e mandam `pronto`. Quando todos estão prontos (ou 60 s), o anfitrião manda `proxima_fase` e todos chamam `chao.nova_fase()`.
- O chefe final (Tela Azul) leva ao duelo (seção 4).

## 3. Reviver (decisão do Breno)
- Quem morre na horda não sai: vira corpo no lugar e fica esperando. Volta na próxima fase ou quando um aliado vivo ficar perto do corpo (~40 px) por alguns segundos.
- Tempo de reviver = base / `reviver` do herói de quem está ajudando. Adicionar `"reviver": 1.0` em `herois.json` e dar um valor maior para a classe "médica" (sugestão: Nicão 2.0, o calmo e grandão).
- Cada cliente confere o próprio corpo (proximidade vem do `_pos` dos outros) e se revive sozinho com 50% de vida. Todos os corpos voltam ao fim da fase.
- Se todos estiverem caídos ao mesmo tempo, o anfitrião manda `fim_corrida` (mostra até que fase chegaram).

## 4. Duelo final entre as pessoas
Reaproveitar `duelo.gd`: no lugar dos robôs (`rival.gd`), cada outra pessoa vira um `Lutador` com um nó "remoto" (posição vem do `_pos`; `receber()` manda o golpe pela rede).
- O anfitrião manda `duelo_iniciar` (centro, ângulo inicial, lista de pessoas). Cada um posiciona todos no círculo.
- Equilíbrio: cada um calcula a própria "força" (`Construcao.dps_por_tipo` x eficiência, igual a `_equilibrar`) e manda a todos. Com todas as forças, cada um calcula o próprio multiplicador `mult` com a mesma fórmula do `pvp.json`. O anfitrião manda `luta` quando todos mandaram.
- Golpes: quem ataca detecta o acerto nas armas dele contra o lutador remoto e manda `_golpe(alvo, dano, empurrao, nome)`. **Quem apanha decide** (vida, invencibilidade de 0,12 s, dash) usando `jogador.receber`. O anel (`_atualizar_anel`) é calculado por cada um só para si, com o relógio da luta que o anfitrião inicia.
- Quando alguém cai, avisa o anfitrião, que dá o lugar (`vivos` na hora da queda) e manda `eliminado(peer, lugar, quem)` para todos. Quando sobra 1 (ou passa `tempo_max`), o anfitrião manda `duelo_fim` com o ranking e todos mostram a tela de resultado.

## 5. Entrega para testar
- Zip do K.I.K.I.U com `abrir_tunel_playit.bat` e um LEIA-ME curto: como criar a sala, como o amigo entra (endereço do túnel `nome.gl.at.ply.gg:porta`), o que fazer se não conectar.
- Testar antes com 2 instâncias na mesma máquina (`--online=host` e `--online=join --endereco=127.0.0.1:7777`, ambas com `--bot`): corrida de 10 fases até o duelo.
- Atualizar `CairuVirus_prototipo.zip` no mesmo lugar (regra do projeto) e levar tudo por PR.

## 6. Riscos
- CPU do anfitrião com 6 jogadores e 500 vírus: hoje o laço leva 3 a 5 ms com 1 jogador, precisa medir.
- Tráfego do anfitrião: ~60 KB/s por cliente com a foto de vírus; limitar a ~120 vírus por cliente se a internet de casa não aguentar.
- As armas dos outros jogadores não aparecem na tela de quem assiste (só o dano nos vírus). Ver depois se vale mandar eventos leves de tiro.
