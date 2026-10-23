# FPS no perfil Baixo: main e heróis integrados

Medição de 21/10/2026, com 24 execuções renderizadas e um único Godot na máquina durante toda a janela. Este diretório guarda a evidência compacta,
sem caminhos pessoais, logs brutos ou a lista extensa de tempos de cada quadro.

- **Baseline:** `dc497dd0e21788c4a30fa56ee0ffb2ff471deba5` (main).
- **Produto benchmarkado:** `4b73d157daed8f132ee105f1bfc6bbe2ce157f4e` (PR #394, antes deste commit documental).
- **Harness idêntico nas duas refs:** [benchmark.gd](benchmark.gd), SHA256 `8f4e315644129ab8f44d15f5473c4082154c729c2f430412cd843c0fb6c63cb5`.
- **Dados:** [medicoes.json](medicoes.json), 24 sumários individuais com FPS, quantidade de quadros, duração real, p50/p95, condições e folha efetivamente usada.
- **Conferência por repetição:** [repeticoes.md](repeticoes.md), com os dois resultados de cada par. Nenhuma amostra foi descartada.

O commit que acrescenta estes arquivos apenas publica a evidência. Ele não foi o produto medido e não motivou repetir o benchmark.

## Condições e carga

Godot 4.4.1 oficial, renderer Compatibility/OpenGL, Intel Iris Xe. Janela real de 960x540, perfil Baixo aplicado só na memória, VSync desligado e
`Engine.max_fps = 0`. Não foram usados `--headless`, `--fixed-fps` ou relógio de simulação fixo. Os processos passaram pela fila do Godot,
serialmente; as outras sessões suspenderam seus Godots durante a janela. Cada execução recebeu APPDATA próprio e personagens/progresso descartáveis.
O baseline já tinha um override local apenas de diretório de usuário; nenhum override de render ou de regras de jogo foi usado.

Cada processo criou um personagem ativo: Breno/Hazaki, Matheus/Hazaki, Lucas ou Nicão. Sem forçar a folha por parâmetro: o caminho normal escolheu a
folha do personagem. O harness confere o nome no cache de tipos que entregou o mesmo dicionário/textura ao ator e registra também o SHA256 dos pixels
importados. Por isso Matheus aparece como `hazaki_samurai` na main e como `matheus` na branch; isso é o comportamento real de cada ref.

A carga foi a mesma: seed 7, oitenta cães de ossos com vida alta, diretor desligado, herói imortal com movimento e ataque contínuos, E e Q alternados
a cada seis segundos. Cada execução teve cinco segundos de aquecimento e quinze segundos de coleta; os oitenta monstros continuaram vivos em todas.
O herói e o combate avançaram pelo delta real de cada quadro, limitado a 0,1 s para saltos do relógio. A medição usou os intervalos de relógio monotônico
entre quadros renderizados: FPS médio = número de intervalos / duração real; p50 e p95 vêm desses intervalos ordenados, em milissegundos.

Foram três repetições por personagem e por ref: 4 × 2 × 3 = 24 processos. Em cada repetição a ordem dos personagens foi Hazaki, Matheus, Lucas, Nicão.
Nos pares, r1 e r3 executaram main e depois branch; r2 inverteu para branch e depois main. Os cinco segundos de aquecimento ficaram fora dos resultados.
As execuções de smoke técnico anteriores também ficaram fora dessas 24 amostras.

## Resultados

FPS abaixo é a **mediana das três médias de FPS**. p95 é a mediana dos três p95 individuais, não um percentil combinado de todas as execuções.
Variação = `(FPS branch / FPS main − 1) × 100`.

| Personagem | Folha main → branch | FPS main | FPS branch | Variação | p95 main / branch (ms) |
|---|---|---:|---:|---:|---:|
| Hazaki | hazaki_samurai → hazaki_samurai | 250,7 | 258,2 | +3,0% | 4,938 / 4,677 |
| Matheus | hazaki_samurai → matheus | 263,1 | 262,3 | −0,3% | 4,464 / 4,484 |
| Lucas | lucas → lucas | 241,0 | 236,4 | −1,9% | 5,110 / 5,209 |
| Nicão | nicao → nicao | 252,9 | 263,9 | +4,3% | 4,781 / 4,543 |

A variação entre repetições foi maior que esses deltas medianos. Não há regressão consistente detectada nessa carga, nem evidência suficiente para
atribuir ganho às mudanças. O último Nicão/branch caiu para **215,7 FPS**, com p95 de **6,663 ms**; as duas primeiras amostras deram 266,4 e 263,9 FPS.
Essa terceira amostra está preservada no JSON e na tabela por repetição. Não houve erro de script nem mudança nas condições verificadas; a causa da
queda isolada não foi determinada. Nicão/main variou de 243,6 a 261,2 FPS; Lucas/main, de 221,2 a 243,1 FPS.

O resultado vale para este notebook, estas refs e esta carga sintética de oitenta monstros. Ele não mede o PC alvo i5-3470, partidas longas, todas as
armas ou todas as resoluções; tampouco substitui uma partida humana. Três repetições e a variação observada não sustentam diferenças pequenas como
regressão ou melhoria conclusiva. Mensagens conhecidas de caches/RID ainda vivos no encerramento apareceram; erros de execução invalidariam a amostra.

## Reprodução portátil

Use o mesmo `benchmark.gd` e [benchmark.tscn](benchmark.tscn), juntos num diretório externo, para as duas refs. A cena referencia o script por caminho
relativo. Importe previamente os assets de cada checkout. Reserve uma janela sem outros Godots, use APPDATA novo por execução e lance a cena pela fila
da máquina, apontando `--path` para o projeto de cada ref. Não copie nem altere fontes no checkout da main.

Exemplo de argumentos para o wrapper da fila (substitua os caminhos entre `<...>`; não acrescente `--headless` nem `--fixed-fps`):

```text
--path <checkout>/jogos/hordas/projeto --position 0,0 <diretorio-externo>/benchmark.tscn -- --janela=960x540 --perfil=baixo --sem_vsync --personagem=matheus --saida_bench=<arquivo-absoluto.json>
```

Repita com `hazaki`, `matheus`, `lucas`, `nicao`, três vezes para cada ref e na ordem descrita acima. Não reutilize APPDATA entre processos, para não
acumular personagens. O harness conserva os padrões de cinco segundos de aquecimento e quinze de coleta, grava um JSON por execução e encerra.
Para comparar, valide perfil `baixo`, janela `[960,540]`, `vsync=0`, `max_fps=0`, `monstros_finais=80` e a folha registrada; confira também ausência de
erros de execução. Os JSONs completos gerados incluem tempos por quadro; nesta publicação foram removidos somente esses vetores extensos.
