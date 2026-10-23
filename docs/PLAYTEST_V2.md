# Robô de playtest da v2 (#301)

O robô joga uma partida inteira da v2 sozinho, sem ninguém no teclado, e no fim imprime uma linha `PLAYTEST_JSON: {...}` com o
desfecho e os números da partida. Ele serve para duas coisas: achar **travas** (o jogo parar de andar, uma tela que não fecha, o
herói preso num canto) em todos os heróis e mapas sem precisar de alguém jogando, e medir **custo e ritmo** (nível, abates, dano,
`proc_ms`) de forma repetível. O código do robô são as funções `_pt_*` do
`jogos/hordas/projeto/v2/roteiro.gd` (ligadas por `--playtest`). O runner do lote é o `ferramentas/playtest_v2.py`.

## O que o robô faz

A cada quadro ele escolhe um destino nesta ordem: um **baú no chão** a até 700 px, senão um **orbe** de experiência a até 320 px,
senão um **ponto aleatório** do mapa, que troca a cada 14 s ou quando ele chega lá. O movimento junta a ida ao destino com uma
**fuga** dos monstros a menos de 150 px, que pesa o dobro. Ele mira o monstro mais perto e **golpeia** quando há um a até 78 px.
Quando 5 ou mais monstros estão colados (46 px), ou o chefe está a menos de 70 px, ou ele está dentro de um ataque anunciado
(círculo ou faixa de `combate.avisos`), ele **esquiva**, no máximo uma vez por segundo. Do chefe ele foge mais cedo (260 px, peso 2),
sai das áreas anunciadas e, perto da borda do mapa, corre ao longo dela em vez de ficar prensado. Na tela de **cartas**, espera 20
quadros e pega sempre a de **maior raridade** (no empate, a primeira). Na tela de **baú**, espera 20 quadros e fecha.

O herói é mortal (`imortal = false`). A partida termina em vitória, morte, no teto de tempo de jogo (`--playtest_max`, padrão 900 s)
ou numa trava. O save é temporário (`user://playtest/meta_<pid>.cfg`, que o `mundo.gd` troca no lugar do save do jogador) e o robô
apaga esse arquivo no fim. A `--semente` fixa o sorteio global do jogo, o das cartas e o do robô. No headless com `--fixed-fps 60`, a
mesma semente repetiu a mesma partida nas medições de 2026-10-15: duas rodadas de 120 s de jogo (Hazaki, Cidade, semente 1) deram
números de jogo idênticos, incluindo cartas, build e linha do tempo, e só o `proc_ms` mudou. Partidas inteiras de 15 min, com
chefes e elites, ainda não foram conferidas. Se isso se confirmar, a diferença entre duas versões do jogo com a mesma semente vem
da mudança, não do acaso. No modo `--janela` o passo de tempo varia e a partida não se repete.

## Uma partida

A partir de `jogos/hordas/projeto`, sempre com o Godot **4.4.1** (outra versão reescreve o `project.godot` e os `.uid`):

```bash
timeout 600 "<Godot 4.4.1 console>" --headless --fixed-fps 60 --path . res://v2/mundo.tscn -- \
  --playtest --heroi=hazaki --mapa=floresta --semente=1
```

As opções do jogo vão depois do `--`: `--heroi=hazaki|nicao|lucas`, `--mapa=floresta|laboratorio|cidade|medio`, `--semente=N`,
`--playtest_max=S` (teto de tempo de jogo, padrão 900) e `--playtest_trava=cartas|bau` (depuração: o robô para de responder àquela
tela, para provar que o vigia de trava pega). No headless o jogo corre várias vezes mais rápido que o tempo real (60 s de jogo em
~8 s no PC do Alisson, um Ryzen 5600X com 12 threads, com a máquina livre; com 2 partidas em paralelo e outras partidas rodando ao fundo, 60 s levaram 13-14 s; conte com o dobro do tempo quando o PC estiver carregado), então uma partida de 15 min de jogo leva de 2 a 4 min. Saídas: `PLAYTEST t=...` a cada 60 s de jogo, `TRAVA: ...` se travar e `PLAYTEST_JSON: {...}` no fim.
O código de saída é 0 no fim normal e 3 na trava (o `_console.exe` repassa o 3). Os avisos de RID vazado que o Godot imprime ao
fechar são ruído.

## O lote

```bash
python ferramentas/playtest_v2.py --godot "<Godot 4.4.1 console>"                    # 3 heróis x 4 mapas, semente 1
python ferramentas/playtest_v2.py --herois hazaki --mapas floresta,cidade --sementes 1-3 --max 300
python ferramentas/playtest_v2.py --godot "<Godot>" --simular                        # só mostra os comandos
```

Roda a partir da raiz do repo, só com a biblioteca padrão do Python 3. Cada partida é um processo Godot, e elas rodam em paralelo.

| Opção | Padrão | O que faz |
|---|---|---|
| `--godot` | variável `GODOT` | caminho do Godot 4.4.1 (o `_console.exe` no Windows). Outra versão é recusada |
| `--herois` | `hazaki,nicao,lucas` | lista separada por vírgula (conferida com `dados/v2_herois.json`) |
| `--mapas` | os 4 mapas | lista separada por vírgula (conferida com a `LISTA` do `v2/mapas.gd`) |
| `--sementes` | `1` | `1`, `1,2,3`, `1-5` ou misturado (`1-3,8`) |
| `--paralelas` | metade dos núcleos | partidas ao mesmo tempo. O PC do Alisson (Ryzen 5600X, 12 threads) aguenta ~8 headless |
| `--max` | 900 do robô | teto de tempo de **jogo** em s (vira `--playtest_max`) |
| `--timeout` | 1200 | limite de tempo **real** por partida em s. Passou disso, a árvore do processo morre |
| `--saida` | `ferramentas/saida_playtest/<data-hora>` | pasta dos logs e relatórios (fora do Git pelo `.gitignore`) |
| `--janela` | desligado | modo FPS: sem `--headless` e sem `--fixed-fps`, uma partida por vez (abre janela) |
| `--simular` | desligado | imprime o comando de cada partida e sai, sem rodar nem criar pasta |

Tudo depois de um `--` sozinho vai para o jogo, no fim da linha de cada partida. Por exemplo,
`-- --playtest_trava=cartas` força a trava, `-- --playtest_fim=morte` leva a partida ao caminho real de morte (robô parado, com 1 de vida, até um monstro matar; é o que grava a meta no save temporário), e `-- --sem_vsync --sombra=baixa` serve no modo `--janela`.

O código de saída é 0 quando não houve trava, crash nem timeout, e 1 quando houve algum. Erro de uso (Godot ausente ou de outra
versão, herói ou mapa desconhecido, semente mal escrita) dá 2, antes de rodar qualquer coisa. Ctrl+C mata as partidas em andamento,
escreve o relatório parcial e sai com 130. O código **4** quer dizer que o save real mudou durante o lote (veja a guarda abaixo); ele
vale mais que o 1 e o 130, para ninguém tomar um lote que mexeu no save do jogador por um lote limpo.

### A guarda do save real

O robô joga com um save temporário (`user://playtest/meta_<pid>.cfg`) e não deveria tocar em nada da raiz de `user://`. Para provar
isso a cada lote, o runner tira um retrato (sha256) dos arquivos regulares da **raiz** de `user://` antes e depois do lote inteiro
(Windows: `%APPDATA%\kikiu\`, a `custom_user_dir_name` do `project.godot`). As subpastas, `playtest/` e `logs/` entre elas, não entram, e só o **conteúdo**
conta: um arquivo regravado igual (mtime novo) não acusa. Se um arquivo mudou, foi criado ou foi apagado, o relatório ganha a seção
"SAVE REAL ALTERADO" com o mtime de cada um (dizendo se caiu dentro da janela do lote) e a saída é 4. Duas causas possíveis: o jogo
real estava aberto durante o lote (o normal) ou o robô escreveu onde não devia (bug: confira o desvio `Meta.caminho_save` no `mundo.gd`).
`--sem-guarda-save` desliga a conferência, para depurar. Fora do Windows, ou se a pasta não existir, a guarda é pulada com um aviso (e uma
linha no relatório). A cena `testes/v2_playtest.gd` confere o mesmo por dentro do Godot (md5 do save, do índice e dos slots, do
`opcoes.cfg` e dos `.json` da v1), e o `ferramentas/teste_guarda_save.py` (sem Godot, roda no CI) prova que a guarda acusa byte
alterado, arquivo criado e arquivo apagado e não acusa `playtest/`, `logs/` nem mtime sozinho.

Medido em 2026-10-16 no PC do Alisson: abrir o jogo normal (cena principal, sem partida) por 600 quadros em `--headless` e por 900
quadros com janela não mudou nada na raiz de `user://` (nem `opcoes.cfg`). Não se mediu uma partida jogada à mão até o fim, que grava
recordes e save: se o jogo real for aberto durante um lote, o código 4 é esperado.

Limites conhecidos da guarda: (1) ela só vê o que a partida grava, e a meta só é gravada no fim por morte, vitória ou abandono; um lote
só de partidas curtas que acabam no teto (`--max`) não grava save, então não prova o desvio (a prova é a cena `v2_playtest`, que roda
uma partida até a morte com `--playtest_fim=morte`; com o desvio quebrado ela falha, conferido em 2026-10-16). (2) Arquivo que não deu
para ler (travado) acusa como "ilegível", na dúvida. (3) Com um `opcoes.cfg` de formato antigo, o `Config.recarregar()` do jogo migra
e regrava o arquivo ao abrir, também no robô: a primeira rodada depois de uma atualização pode dar código 4 sem bug do robô.

## Como ler o relatório

A pasta de saída tem o `relatorio.md`, o `relatorio.json` e `logs/<heroi>_<mapa>_s<semente>.log` com a saída bruta de cada partida, mais `logs/<heroi>_<mapa>_s<semente>.godot.log`, o log do motor (`--log-file` próprio, para não girar o `user://logs/godot.log` do jogo real).
Cada partida termina num destes desfechos:

| Desfecho | O que é |
|---|---|
| `vitoria` | o robô venceu |
| `derrota` | o herói morreu (ou a partida foi abandonada) |
| `tempo` | chegou ao teto de tempo de jogo vivo |
| `trava` | o vigia pegou uma trava (linha `TRAVA:`) |
| `sem_json` | o processo não terminou limpo: acabou sem `PLAYTEST_JSON` (crash, com o código de saída no motivo) ou estourou o timeout; também cobre o JSON impresso seguido de crash ou timeout (o JSON é guardado, mas a partida conta como problema) |

O `relatorio.md` traz uma tabela por partida (desfecho, tempo de jogo, nível, abates, dano sofrido, golpes tomados, vida final, baús,
elites, chefes, `proc_ms` p95 e p99, trava), depois as médias por herói e por mapa. No fim vêm a lista de travas, com a linha `TRAVA`
completa e o comando para reproduzir, e a lista de partidas sem JSON, com o fim do log. Linhas `SCRIPT ERROR` nos logs aparecem em
"Observações". O `relatorio.json` é a lista de resultados crus: o `PLAYTEST_JSON` inteiro de cada partida em `json` (com build,
cartas, evoluções e linha do tempo minuto a minuto), mais `codigo`, `motivo`, `comando` e o caminho do log.

O `proc_ms` é o tempo do `_process` do mundo por quadro, em ms: a lógica do jogo em GDScript, incluindo o próprio robô, **sem** o
render. O p95 diz que 95% dos quadros gastaram até aquilo. É o número de custo que vale no modo headless.

## Tipos de trava

- **`relogio_parado`**: o jogo está em "jogando", sem pausa, sem parada de impacto e sem câmera lenta, e o relógio da partida não
  anda por 600 quadros (10 s). Indica um estado preso na lógica (um contador que não volta, uma pausa que não sai).
- **`tela_<estado>`**: a mesma tela fica aberta por 1200 quadros (20 s). Na prática aparece como `tela_escolha` (cartas) ou
  `tela_bau`. Morte, vitória e abandono encerram a partida antes dessa checagem. Com `--playtest_trava=cartas` ou `=bau` ela aparece
  de propósito.
- **`heroi_preso pos=(x, y) alvo=(x, y) bau=true|false fuga=(x, y)`**: o herói quer andar, mas fica a menos de 6 px do mesmo lugar
  por 30 s de jogo. `pos` é onde ele está e `alvo` é para onde queria ir. `bau=true` diz que o alvo era um baú no chão; com `false`, o
  alvo era um orbe ou o ponto aleatório. `fuga` é o empurrão de fuga dos monstros: perto de `(0, 0)` com o alvo longe quer dizer
  parede ou árvore no caminho; uma fuga grande quer dizer que o herói ficou cercado ou que a fuga anulou a ida ao alvo.

## Limites conhecidos

O robô **não tem rota**: anda reto até o destino. Quando fica parado por 1,5 s, ele sorteia outro ponto e passa 3 s sem perseguir
baú nem orbe, para dar a volta no obstáculo. Um `heroi_preso` pode, então, ser falta de rota do robô e não defeito do mapa: confira a
posição no mapa antes de culpar a colisão. Ele escolhe **sempre a carta de maior raridade**, por isso não explora builds. Ele **não
usa habilidades ativas** (ruptura e as outras teclas), só golpe e esquiva. Não joga bem: os números mostram um jogador fraco e
constante, servem para comparar versões e achar travas, não para fechar o balanço sozinhos.

O vigia e o robô contam **quadros**, não segundos: 600 quadros de relógio parado, 1200 de tela aberta, 90 para o "preso curto",
60 entre esquivas e 20 antes de escolher carta ou fechar baú. Os segundos citados acima valem a 60 FPS, ou seja, no headless com
`--fixed-fps 60` e na janela com V-Sync de 60 Hz. No `--janela -- --sem_vsync` a 300 FPS, por exemplo, uma `tela_escolha` vira
trava em ~4 s e o robô desvia e esquiva em outro ritmo, então o desfecho dessas partidas não se compara com o do headless.

A partida que o runner mata por timeout não chega a apagar o save temporário. Fica um `meta_<pid>.cfg` órfão em `user://playtest/`
(no Windows, `%APPDATA%\kikiu\playtest\`). O runner apaga, no **início** de cada lote, os `meta_*.cfg*` dali com mais de 1 hora (os mais novos podem ser de um lote
paralelo ainda vivo, então ficam). Fora do Windows essa limpeza não roda.

## FPS: o headless é teto, o alvo é o i5-3470

No headless com `--fixed-fps 60` não há render e o passo de tempo é fixo, então o `quadro_ms` do JSON dá sempre 16,67 e não diz nada
sobre FPS. Lá, o custo é o `proc_ms`. E o FPS do PC do Alisson (Ryzen 5600X com RX 7600 XT) é **teto**, não alvo. O alvo é o
**i5-3470 do Breno**.

Para medir o FPS real, rode o modo `--janela` **na máquina alvo**, com o Python 3 instalado:

```bash
python ferramentas/playtest_v2.py --godot "<Godot 4.4.1 console>" --janela --herois hazaki --mapas cidade --max 600
python ferramentas/playtest_v2.py --godot "<Godot 4.4.1 console>" --janela --herois hazaki --mapas cidade --max 600 -- --sem_vsync
```

Nesse modo a partida anda em tempo real, uma por vez, e o timeout sobe sozinho para cobrir o teto de tempo de jogo. A janela do jogo abre
e é redimensionada pelo próprio jogo (não deixe nada importante atrás dela), e o áudio vai para o driver `Dummy` (sem som no alto-falante). O relatório
ganha a seção "FPS de render", com o FPS médio, o FPS no p95 e o `quadro_ms` (média, p50, p95, p99 e máximo) de cada partida. Com
o V-Sync ligado, o normal do jogador, a pergunta é se o p95 e o p99 ficam em 16,7 ms (60 FPS). Com `--sem_vsync`, aparece a folga.
Sem o Python, dá para rodar o comando de uma partida sem `--headless` e sem `--fixed-fps` e ler o `quadro_ms` no `PLAYTEST_JSON`.
