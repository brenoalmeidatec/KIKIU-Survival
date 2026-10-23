# Fixture dos testes da v2

Cada cena `v2_*.tscn` roda em um processo próprio e herda `isolamento_v2.gd` (Node) ou
`isolamento_v2_control.gd` (Control). A base chama `ambiente_v2.gd` antes do `_ready` do teste.
Meta, índice de personagens, prefixo dos slots, save antigo e opções apontam para
`user://testes_v2/<nome_da_cena>/`. Os nomes temporários particulares dos testes continuam
dentro dessa pasta. Um teste novo também precisa herdar a base adequada.

O bootstrap recarrega as opções, remove os temporários do Config, fixa o perfil Alto e
restaura os volumes. Reiniciar o Mundo ou passar por morte, resultado e salão continua
usando os caminhos da fixture; não se restaura o caminho do jogador ao terminar.

## Gancho inicial do Config

A base não chega antes dos autoloads. `Config._ready` chama
`Ambiente.preparar_config(self)` antes de `recarregar`, que lê opções e pode gravar
migrações. O helper só é carregado quando a linha de comando ou o ambiente do filho
identifica uma cena de teste da v2, fora do editor e com o recurso de testes presente.
Assim, as opções são redirecionadas antes da primeira leitura ou migração. O trecho
compartilhado foi liberado pelo Claude na issue #348 em 21/10/2026.

O helper identifica a cena `.tscn` na linha de comando. Processos filhos herdam
`KIKIU_TESTE_V2_CENA` e `KIKIU_TESTE_V2_DONO`; o filho usa um subdiretório `processo_<pid>`.
Não executar duas instâncias da mesma cena no mesmo diretório `user://`, nem carregar
várias cenas de teste sucessivas em um único processo. O estado estático foi desenhado
para um teste por processo. Se um teste adicionar `_init` ou `_exit_tree`, preserve a
chamada da base com `super`; os testes atuais não sobrescrevem esses métodos.

## Limpeza e erros

A limpeza inicial e final inclui diretórios e arquivos ocultos, `.bak` e `.tmp`. Cada
remoção é conferida, incluindo a remoção da raiz. Erro de acesso falha a execução; os
caminhos já foram redirecionados antes da primeira operação de limpeza/criação, portanto
uma falha não faz o bootstrap voltar aos arquivos do jogador. `v2_isolamento` cobre saves,
opções, subpastas e resíduos ocultos, além de recusar a limpeza da raiz `user://` ou das
fixtures de outras cenas. Uma morte forçada do processo pode impedir o `_exit_tree`;
a próxima execução limpa os resíduos antes de começar.

## Subprocesso do playtest

Sem `KIKIU_GODOT_FILA`, `v2_playtest` usa o Godot nativo, como no CI Linux. No notebook,
o runner define essa variável com o script PowerShell da fila e também abre o processo
pai por esse wrapper. Rodar a cena sozinha: pai e filho precisam das duas vagas. O
helper registra o PID real do Godot filho; o PID do PowerShell não serve para conferir
o save temporário nem encerrar a partida.

A espera pela fila não gasta o prazo de jogo. No timeout, só o Godot identificado é
encerrado; o wrapper termina normalmente e libera sua vaga. Não matar o wrapper por
timeout externo. Se o filho não chegar ao hook e não produzir o marcador de PID, o
teste aguarda sua saída e falha com diagnóstico; esse caso ainda exige coordenação do
runner para não deixar um processo travado.

O robô de produção mantém `user://playtest/meta_<pid>.cfg` e remove seu `.tmp`/`.bak` ao
terminar. Essa é a exceção explícita ao diretório por cena. Logs e marcadores do teste
ficam na fixture da cena.

## Prova com save sujo

Usar uma cópia estável de um backup em um diretório de QA exclusivo; nunca apontar o
Godot para o save vivo. Resolver e conferir o `user://` do projeto de QA antes de copiar
os arquivos. Não usar links/junctions para o original. A cópia usada na execução deve
ser gravável, para revelar uma gravação indevida em vez de escondê-la por permissão.

Guardar fora do `user://` um manifesto ordenado com caminho relativo, tamanho e SHA-256
dos arquivos protegidos, incluindo opções, índice, slots e backups. Todos os logs do
Godot devem ter `--log-file` exclusivo fora da cópia. Comparar arquivos alterados,
removidos e novos fora das pastas temporárias esperadas, e conferir a ausência das
fixtures ao terminar. Manter também o manifesto do backup original para confirmar que
ele ficou intacto.

Essa prova cobre o inventário completo de cenas da v2, incluindo novas cenas trazidas
da main. O executor `ferramentas/testes_ci.sh` também roda a v1: o CI completo é uma
validação separada, em outro diretório de QA. O helper da v2 não afirma isolar a v1.
SHA-256 inalterado prova preservação de conteúdo; sozinho não prova ausência de leitura.
Para revelar o antigo problema de Config, uma segunda cópia pode conter opções antigas
que exigiriam migração, com o manifesto calculado depois dessa preparação.

## Resultado da prova de 21/10/2026

A continuação no commit `dcde5a53c1d627cc3597faccfa6d5d89dfdb1002` concluiu as 76 cenas
em série e `v2_playtest` sozinho nas duas variantes graváveis (base e migrável).
Os quatro probes confirmaram o diretório QA; cada processo terminou com código 0,
`falhas=0`, sem `SCRIPT ERROR` e sem resíduos da fixture. SHA-256 e tamanho dos CFG
na origem, golden e QA permaneceram iguais após cada processo. Evidência sanitizada:
[resumo e anexo histórico](../../../../docs/qa/save_real_2026_10_21.md). O relatório histórico
pendente da preparação foi preservado.

A execução headless não comprova composição visual nem experiência humana. Ferramentas
como `v2_controle_fotos`, `v2_fontes_prints`, `v2_icones_prints` e `v2_fontes_folha`,
sem `--fotos` ou `--spec`, exercitam inicialização e limpeza, sem produzir capturas;
outras cenas também pulam partes visuais em headless. Hashes finais iguais não provam
ausência de leitura nem de escrita transitória restaurada. O CI integral permanece
uma verificação separada, inclusive para as cenas v1.

## Compatibilidade com os geradores do PR #394

Config conserva também o guard específico de matheus_gif e heroi_gif do #394.
As opções de GIF são apontadas antes de recarregar(), sem interferir na fixture
das cenas v2_*. O guard só atua com a cena de captura explícita e existente,
fora do editor; jogo normal e export sem helpers mantêm o comportamento original.

Na integração, preservar os dois guards antes de recarregar(). O arquivo deste
PR já contém essa união. Se houver conflito no início de _ready, manter a chamada
_isolar_captura_gif() e o bloco da fixture, nesta ordem. O item de acessibilidade
do #389 fica no catálogo e também deve ser mantido. Esta compatibilidade recebe
nova prova de caminhos/isolamento com as duas cópias sujas e CI no commit enviado;
a prova completa anterior continua identificada pelo seu commit no relatório.
