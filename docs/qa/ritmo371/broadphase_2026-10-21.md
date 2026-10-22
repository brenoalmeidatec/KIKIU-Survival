# Adendo: candidatos das adagas no alcance composto

A revisão do produto `808f096c3cc58dbc8b2a8646ffd07fb486282d12` encontrou um corte
fixo de candidatos a 560 px do herói. O Q final do Lucas, nível 20 com seis cartas
Arco largo comuns (`m_area=1,72`), já voa 584,793 px. A lâmina podia atravessar
um alvo alcançável a 575 px sem aplicar dano.

A regressão executou o Q real, avançou até sua rodada final e posicionou o alvo
na trajetória lançada. No produto anterior, falhou exatamente duas vezes: alvo
a 575 px com herói perto e depois com herói afastado da origem. O controle a
620 px, fora do alcance composto, permaneceu intacto nos dois casos. Fonte e
saída vermelha anteriores foram preservadas externamente; o teste versionado
reproduz o cenário sem modificar dados de produção.

A correção substitui o círculo centrado no herói por uma AABB que une os segmentos
ativos do quadro, expandida pelo raio de cada adaga. A seleção cruza essa caixa
com o corpo do monstro no mesmo centro do narrowphase (`pos + (0,-6)`). Não há
limite fixo de distância ao herói nem varredura adagas × monstros na busca.

Com Chuva ativa e lâmina principal, a caixa recebe margem conservadora do maior
raio de monstro vivo, diferença de 2 px entre peito e origem da extra, mais os
120 px de alcance da extra. Assim cobre a extra criada e processada ainda no
mesmo quadro, mesmo quando o peito do monstro grande está fora da caixa inicial.
A extra não gera outras. A seleção custa O(MAX + 2N), com MAX=96; sem Chuva,
O(MAX + N). O narrowphase, a ordem relativa dos candidatos e a perfuração não mudaram. A busca não consome RNG; novos acertos válidos podem naturalmente mudar sorteios posteriores.

A prova focada passou com zero falhas após a correção: Q real a 575 px, herói
longe da origem, controle fora do alcance, corpo grande, extra real acertando
fora da caixa inicial na mesma atualização, pool fixo e busca sem consumo de RNG.
O pool e os contadores mantêm os mesmos limites.

A matriz histórica de seis pares em `robo_2026-10-21.json` permanece intacta e
identifica seu código anterior. Esta correção muda o produto: é necessária nova
fase DEPOIS com o mesmo controlador e APPDATA exclusivo. Este adendo é prova
local da regressão, não substitui essa matriz nem comprova equilíbrio humano.

Validação local Godot 4.4.1 pela fila, APPDATA exclusivo de QA: `v2_ritmo`,
`v2_especial`, `v2_raio_por_nivel`, `v2_partida`, `v2_combate`, `v2_herois` e
`v2_status` terminaram com código 0, `falhas=0` e sem SCRIPT ERROR. Formatação
160 e diff-check passaram. A cena solicitada `v2_adagas.tscn` não existe nesta
base: a tentativa saiu com código 1 por arquivo ausente, sem constituir teste
aprovado; o cenário de adagas e extra é exercitado pelo teste focado acima.
