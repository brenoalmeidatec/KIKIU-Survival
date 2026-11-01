# Calibração com o robô (ECO-8), 01/11/2026

Duas rodadas no mesmo dia. **A primeira (07:17 às 07:47) é inválida para o Difícil** e a segunda (08:22 às 08:45) é a que vale. Relatórios e JSON brutos ficam fora do repo: `notas/o6_logs/eco-8/` (rodada 1) e `notas/o6_logs/eco-8f/lote/` (rodada 2).

Só um herói (Hazaki) e uma semente (1). O comando do plano é 3 heróis x 4 mapas x sementes 1-3 por dificuldade (108 partidas); aqui foram 12. **O que sai daqui é indício, não calibração.**

## Por que a rodada 1 do Difícil é inválida

O robô (`v2/roteiro.gd`, `_pt_escolher_carta`) escolhia a carta de maior raridade, e no Difícil cheio (limite de 12 bônus) a carta mais rara era a TROCA. `progresso.escolher` numa TROCA só abre o painel de troca, então o robô repetia o pedido a cada quadro até o limite de 8,9 s da tela de cartas e nunca largava um bônus. No JSON bruto da rodada 1 isso aparece como blocos de exatamente 533 quadros com a mesma carta: **11 no Laboratório, 21 na Cidade e 37 na Ruínas** (Floresta Difícil, Fácil e Médio: zero). O build do robô no Difícil não era o de um jogador, e as vitórias, os chefões e a derrota do Laboratório Difícil da rodada 1 **não valem**: nem para desvio da tabela, nem para o gatilho do plano B (ECO-7).

Conserto (este PR): o robô prefere a carta mais rara que **não** é troca; só com mão toda de troca ele larga o bônus mais recente (`progresso.trocar`). Teste novo `v2_roteiro_robo` (falha 7 vezes com o código antigo, passa com o novo). O relatório agora marca "MEDIÇÃO INVÁLIDA" quando o JSON mostra 50 ou mais escolhas iguais e seguidas.

Erros de fato da rodada 1 que ficam corrigidos aqui (a versão anterior deste texto, o corpo do PR e o LOGBOOK diziam outra coisa):

- **Ruínas Fácil não estourou o teto.** Foi derrota aos 3:35, com 23% do mapa, para o mini-chefe de nível 10 (nasceu aos 198 s). Na rodada 2 a mesma combinação (Hazaki, Ruínas, Fácil, semente 1) deu vitória aos 15:32. Mesma semente, resultados opostos: **a semente 1 não repete a partida de uma rodada para outra**, e uma partida só não diz nada sobre o mapa.
- Chefões do Difícil na rodada 1: 20 s (Cidade), 45 s (Ruínas) e 96 s (Floresta). Não eram "8 a 45 s", e "o Difícil derruba mais rápido" não vale (Floresta passa de 60 s). Cidade e Ruínas são das partidas contaminadas.

## Rodada 2: resultado das 12 partidas (teto de 1200 s, uma por vez pela fila)

| Mapa | Fácil | Médio | Difícil |
|---|---|---|---|
| Floresta | vitória 5:33 (nível 22) | vitória 5:02 (nível 27) | vitória 4:47 (nível 46) |
| Laboratório | vitória 8:34 (nível 38) | vitória 10:49 (nível 47) | vitória 8:24 (nível 50) |
| Cidade | vitória 13:11 (nível 48) | vitória 10:48 (nível 57) | vitória 12:03 (nível 64) |
| Ruínas (`medio`) | vitória 15:32 (nível 59) | vitória 15:53 (nível 65) | **derrota 18:59** (nível 78, no chefão final) |

11 vitórias e 1 derrota. 0 travas, 0 sem JSON, 0 SCRIPT ERROR, nenhum bloco de escolha repetida (maior sequência igual: abaixo de 50 em todas). O robô fez 0 trocas: com a preferência por carta que não é troca, nunca sobrou mão só de troca.

## Desvios da tabela (tolerância 20%), rodada 2

Tempo de vitória: só **Laboratório Médio** desvia (10,8 min contra 7,9, +37%). Os outros 10 ficam em -4% a +17%.

Chefão do último nível (faixa de 35 a 60 s; o desvio agora sai com sinal):

| Mapa | Fácil | Médio | Difícil |
|---|---|---|---|
| Floresta | 108 s (+79%) | 87 s (+45%) | 84 s (+39%) |
| Laboratório | 27 s (-22%) | 109 s (+81%) | 38 s (ok) |
| Cidade | 58 s (ok) | 11 s (-68%) | 83 s (+38%) |
| Ruínas | 31 s (-13%, ok) | 28 s (-21%) | não caiu (derrota) |

Leitura honesta: **só a Floresta é consistente** (84 a 108 s nas três dificuldades, acima de 60 s). Nos outros mapas o mesmo chefão varia de 11 s a 109 s entre dificuldades (Laboratório: 27, 109, 38; Cidade: 58, 11, 83), e isso é ruído de uma partida só, não efeito da dificuldade. A vida máxima do chefe é a mesma nas três dificuldades.

## Gatilhos do plano B (ECO-7)

- Médio: derrotas antes de 60% do mapa = 0 de 4. Difícil: 0 de 4. Limite 25%: **não acionam**.
- Dano sofrido Médio sobre Fácil = 0,64 (limite 1,4): **não aciona**.

Com 4 partidas por dificuldade, 1 herói e 1 semente, **não decide o plano B**. Também ainda não existe, no plano, a amostra que o gatilho exige: isso fica para o Alisson definir.

## Nenhum dado foi ajustado (desvio do plano, a confirmar)

O plano manda "ajustar o que desviar mais de 20%". Este PR **não ajustou nada**, de propósito: metade do que desvia é a Floresta (consistente, mas é um mapa e um herói) e o resto muda de sinal de uma dificuldade para outra com a mesma vida de chefe, e a própria rodada 1 mostrou que a mesma semente dá derrota num dia e vitória no outro. Ajustar dado de mapa ou de chefão em cima disso seria chute. Esta decisão está no LOGBOOK e precisa da confirmação do Alisson. A tabela `tabela_esperada.json` usa **o mesmo** tempo de vitória e a mesma faixa de chefão para as três dificuldades (o plano não dá um por dificuldade).

## Guarda do save real (código 4 na rodada 1)

Na rodada 1 a guarda acusou em Médio e Difícil: `foto_ed_personagens.cfg`, `foto_ed_pp1.cfg` e `.bak` criados às 07:30 e `.recovery_mode_lock` apagado. A guarda mede a raiz de `user://` (`%APPDATA%\kikiu`), e **o robô usa a mesma raiz do jogo real**: "o robô grava em `user://playtest/`" isola o save, mas não a raiz, que é compartilhada com todo Godot da máquina. O que se sabe:

- Nenhum arquivo do repo (nem de outras worktrees em `jogos/`) grava `foto_ed_*`. Quem criou foi outro processo Godot da máquina às 07:30 (há vários agentes e capturas rodando; a raiz também tem `captura_piscadas_opcoes.cfg` e `zz_captura_def1_*.cfg` de outras sessões).
- `.recovery_mode_lock` é arquivo de controle do **editor** do Godot, criado e apagado a cada `--import`/`--editor`. Ele existe de novo agora (08:08), sem robô nenhum rodando.
- **Prova de que o robô não escreve na raiz:** a rodada 2 rodou com `APPDATA` apontando para uma pasta vazia só dela (`notas/o6_appdata/eco-8f`). Depois das 12 partidas a árvore tinha só `kikiu/playtest/` (vazia, os `meta_<pid>.cfg` foram apagados). Nenhum arquivo na raiz, nem `.recovery_mode_lock`. A guarda daquela rodada ficou "pulada" (a pasta não existia no começo), então a prova é a listagem da pasta, não a guarda.
- Os arquivos de outras sessões **não foram apagados** (não são deste PR).

Para as próximas rodadas, com agentes em paralelo: rodar com `APPDATA` isolado (`set APPDATA=<pasta só do lote>`) e criar a pasta `kikiu` antes, para a guarda ficar ligada e sem falso positivo.

## Próximos passos

- Rodar a matriz cheia numa invocação só: `--herois hazaki,nicao,lucas --sementes 1-3 --dificuldades facil,medio,dificil --max 1200` (108 partidas, cerca de 3 h a 2 min por partida), de preferência fora do horário de jogo do Breno e do Isac. Uma invocação só dá a matriz cruzada, os chefes e o gatilho de dano no mesmo relatório.
- Só então decidir ajuste de chefão (CAR-5) e plano B (ECO-7). Floresta é o primeiro candidato.
