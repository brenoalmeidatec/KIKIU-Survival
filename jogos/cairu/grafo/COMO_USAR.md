# Grafo do JOGO (Graphify)

Mapa de conhecimento do jogo gerado com o Graphify (github.com/Graphify-Labs/graphify,
pacote `graphifyy` 0.9.75, licença Apache-2.0, tudo local, sem chave nem conta).

Cobre: scripts GDScript (projeto/scripts, projeto/minijogos), capítulos (cenas, NPCs,
gatilhos, requer, !minijogo, !se), mapas (portas e pontos) e os geradores Python
(fonte_mapas, fonte_audio). O Graphify não lê GDScript, então `ferramenta/extrair_jogo.py`
faz essa parte no mesmo formato. Não altera nada do jogo.

## Para as threads (Claude)

    pip install -q graphifyy          # uma vez por sessão (o container é novo a cada vez)
    G=/mnt/project-files/jogo/grafo/graph.json
    graphify query "como o diretor roda uma cena" --graph $G --budget 1500
    graphify explain "cena h4_matheus" --graph $G       # vizinhos de um nó, com arquivo:linha
    graphify explain "diretor.gd" --graph $G
    graphify path "mapa recepcao" "minijogo digitar" --graph $G
    graphify affected "dialogo.gd" --graph $G           # o que quebra se mexer nisso
    graphify god-nodes --graph $G

Nomes dos nós: arquivos (`mundo.gd`), funções (`_passo()`), `cena <id>`, `mapa <id>`,
`personagem <id>`, `minijogo <id>`, `capítulo <título>`. Resumo geral em GRAPH_REPORT.md;
graph.html abre no navegador.

## Atualizar depois de mexer no jogo

    python3 /mnt/project-files/jogo/grafo/ferramenta/construir_grafo.py

Leva poucos segundos. Arestas INFERRED (chamadas entre arquivos deduzidas pelo nome)
podem ter falso positivo; confira no arquivo antes de confiar.
