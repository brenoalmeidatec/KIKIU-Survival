# Evidências da dificuldade (#372)

Capturas reais do componente `v2/escolha_dificuldade.gd`, no Godot 4.4.1 do
notebook em 21/10/2026. O helper `testes/fotos/dificuldade_fotos.tscn` renderiza um
SubViewport de 960×540 ou 1920×1080; isso garante as dimensões mesmo quando a
janela não cabe no monitor. O processo usa a fila compartilhada e um diretório de
QA, sem o save do jogador.

Há uma imagem de cada dificuldade em cada resolução e uma com os glifos Xbox.
São as capturas finais, após corrigir o tamanho mínimo dos Labels: descrições,
avisos de calor, bônus e botões cabem nas caixas. A escolha abre no portal do
salão, bloqueia caminhada e interações e só salva/entra após a confirmação.

Os testes de regras e do fluxo real ficam em `testes/v2_dificuldade.tscn`; o
componente, em `testes/v2_escolha_dificuldade.tscn`; o hook, em `testes/v2_salao.tscn`.
O CI completo do código em `4e4725e` passou nas três baterias Godot 4.4.1,
formatação, lint, Python e ortografia:
https://github.com/brenoalmeidatec/KIKIU-Survival/actions/runs/39607462385.
Isso inclui geometria de quatro, cinco e seis conquistas no resultado, confirmação
do portal e o contrato visual atualizado. Localmente, `v2_dificuldade` terminou
com saída 0, falhas=0 e sem SCRIPT ERROR, incluindo monstro, orbes, XP, Status,
mercador, crédito único e reinício nas seis combinações dificuldade/Pesadelo.

## Validação final de 21/10

O runner versionado ferramentas/playtest_v2.py foi executado com um adaptador
externo que prefixa o wrapper da fila, sem alterar o fonte do robô. APPDATA
exclusivo por worktree, Godot 4.4.1, Floresta, Hazaki, semente 1: Fácil, Médio e
Difícil terminaram com vitória, código 0 e nenhum erro de script ou trava.
O relatório sanitizado robo_final_2026-10-21.json guarda os três casos completos,
o commit do jogo e um hash dos fontes/dados, sem caminhos da máquina.

A investigação de Nicão/Fácil usou o mesmo mapa e semente na main dc497dd e na
branch 0553f9c. Ambas reproduziram heroi_preso em 166,8 s, posição (1394,1417),
alvo (1442,1380), com mesma build, nível 16 e 284 abates. Os dois runners saíram
com código 1; não são aprovados. A igualdade demonstra comportamento anterior à
dificuldade, mas não distingue imobilidade real de falso positivo do vigia.
Ocorrência registrada na issue #137; detector e colisão não foram modificados.

As capturas resultado/resultado_cinco_conquistas.png e
resultado/resultado_seis_conquistas.png foram geradas pelo caminho real de
combate/resultado no helper v2_meta, em janela renderizada e APPDATA de QA.
Inspeção visual: três linhas completas, sem tocar no saldo ou CONTINUAR.
O helper confere os nomes/margens durante a captura e agora imprime seu total
de falhas e devolve código não zero se uma conferência falhar. Na execução final:
v2_meta fotos falhas=0, código 0, sem SCRIPT ERROR/FALHOU. O encerramento ainda
registra avisos de recursos/RIDs de renderização já observados nos vizinhos.

`ensaios_anteriores.json` preserva os cinco casos de desenvolvimento que produziram
PLAYTEST_JSON, com quatro vitórias e uma trava. São anteriores à correção XP/moeda
e à integração de main; não substituem o robô no commit final. O lote completo
não terminou, e não se afirma código de saída de casos sem relatório final.

Este ensaio usa um mapa/semente por dificuldade e não substitui balanceamento
humano nem uma matriz exaustiva de personagens. Não se mede FPS real em headless
com fixed-fps; o custo de lógica e o desfecho são as métricas úteis dessa rodada.
Todos os processos dessas execuções terminaram; a coordenação da fila está na #348.
