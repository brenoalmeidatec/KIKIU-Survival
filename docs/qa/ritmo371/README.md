# Ritmo da v2 — comparação de 21/10/2026

Seis pares executados pelo runner versionado `ferramentas/playtest_v2.py`, com adaptador externo que encaminha toda engine pela fila do notebook. Godot 4.4.1, APPDATA exclusivo do robô separado dos testes unitários, uma partida por vez em cada fase; a fila global limita a duas engines. Floresta/Fácil, sementes 1 e 2, três arquétipos, teto300 segundos de jogo, `--playtest_q` nas duas fases. Os consertos de direção/vigia do robô foram aplicados de forma idêntica nos dois lados. O fonte inteiro de roteiro é igual após remover somente a linha de telemetria do ritmo; SHA256 comum `a0cc4e265e49d6617d7f7ccb3a60e4d4b4cb6c026b18835ace9aa14bd008d487`. Hazaki e Matheus compartilham regras; o quarto visual é validado no #394. O E de ruptura do Hazaki não é acionado pela política existente.

Referência sem as curvas novas: `3681c15043879bb1d2b2bdcbff10653a1b28abb0`, baseada no #390 e com o robô corrigido. Código novo medido: `4c221cb362eb12eefff081987b4e1e68e4bf5c82`. Os hashes de todos os fontes de `v2/` e `dados/` foram capturados antes de abrir o lote e comparados ao conteúdo entregue. O relatório sanitizado preserva números de jogo, códigos e hashes; não inclui saves, caminhos de máquina nem comandos com diretórios absolutos.

A guarda externa de arquivos foi **pulada nos dois lotes**, pois a pasta QA de `user://` ainda não existia ao iniciar. Isso não conta como prova de hashes preservados. Os APPDATA eram exclusivos de QA e nenhuma engine recebeu o perfil real. A prova de save sujo com hashes é separada, no #391.

| Arquétipo | Semente | Nível antes → depois | Abates | Q usados | Dano sofrido | Pico de vivos |
|---|---:|---:|---:|---:|---:|---:|
| hazaki | 1 | 26 → 25 | 615 → 487 | 3 → 3 | 71 → 53 | 83 → 84 |
| hazaki | 2 | 26 → 29 | 670 → 721 | 4 → 3 | 15 → 17 | 81 → 83 |
| nicao | 1 | 27 → 27 | 665 → 700 | 4 → 3 | 19 → 10 | 81 → 84 |
| nicao | 2 | 28 → 30 | 684 → 771 | 3 → 4 | 18 → 11 | 80 → 84 |
| lucas | 1 | 25 → 29 | 606 → 679 | 4 → 3 | 32 → 32 | 84 → 84 |
| lucas | 2 | 27 → 29 | 659 → 656 | 4 → 3 | 17 → 24 | 75 → 78 |

Os 12 casos encerraram com código 0 e sem SCRIPT ERROR ou trava. Desfechos registrados: `{'tempo': 12}`. Atingir o teto de300s não é vitória. Os disparos efetivos e seus instantes estão no JSON, assim como os recursos soltos/coletados, cura efetiva e almas atraídas da fase nova. Os ensaios antigos do #390 sem Q/E não entram nesta comparação.

Um controle adicional do #397 repetiu Nicão/Floresta/Fácil/semente1 **sem Q**, na referência sem curvas. Chegou a300s, nível26 e666 abates, código0, sem SCRIPT ERROR nem trava. Nesse controle a pasta QA foi criada antes: a guarda de `user://` foi conferida e permaneceu inalterada. O caso antigo parava em166,8s tanto na main quanto no #390 original; continua registrado como falha histórica. O controle novo prova a regressão desse caso específico do robô, sem declarar vitória ou conserto geral de colisão do jogo.

A primeira tentativa, com o controlador antigo, teve cinco casos no teto e uma trava do Nicão, além de interferência de arquivos de fixture no APPDATA QA compartilhado. Ela permanece em `tentativa_inicial_nao_aprovada.json`, incluindo amostras/sondas sanitizadas do diagnóstico. Não foi reclassificada como sucesso. O detector antigo comparava só os extremos e chamou imobilidade depois de uma excursão de70px; os consertos do robô têm regressões positivas de trava e não alteram os limiares6px/30s. Esta comparação usa ambos os lados corrigidos para separar o efeito da IA das regras novas.

Esta amostra verifica execução e mostra o efeito conjunto das regras. Não isola qual curva causou cada diferença nem comprova equilíbrio geral. Falta experiência humana nos quatro mapas/dificuldades. `proc_ms` mede lógica headless, com ruído da execução concorrente; não é FPS de render nem substitui o teste no i5. O sorteador de drops é próprio e deriva de `--semente`, sem consumir o sorteio global; após trajetórias divergirem, cartas e encontros também podem divergir.

Os testes focados verificam dano/alcance reais dos três Q nos níveis 1, 20 e 500, snapshot e repetição, cura, chances, pool e limites, conservação de XP, recorte visível com câmera em 16:9/4:3/ultrawide, pausa/reinício e descarte dos recursos. Os testes não substituem a partida humana.
