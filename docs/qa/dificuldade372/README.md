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

## Pendências do repasse

- Repetir o robô versionado nas três dificuldades no código final. A rodada Médio
  não chegou a executar; não contar espera da fila como teste aprovado.
- Comparar Nicão/Fácil/Floresta/semente 1 na main e na branch, com teto inicial
  de 200 s. Uma rodada anterior marcou `heroi_preso` em 166,8 s. Colisão, mapa e
  robô são iguais na main; o detector compara apenas as extremidades de 30 s,
  portanto a causa continua inconclusiva. Não alterar o detector para esconder a
  ocorrência.
- Gerar e conferir fotos de cinco e seis conquistas por
  `testes/v2_meta.tscn -- --fotos=PASTA`, em um user_dir de QA.

`ensaios_anteriores.json` preserva os cinco casos de desenvolvimento que produziram
PLAYTEST_JSON, com quatro vitórias e uma trava. São anteriores à correção XP/moeda
e à integração de main; não substituem o robô no commit final. O lote completo
não terminou, e não se afirma código de saída de casos sem relatório final.

As repetições locais restantes foram retiradas enquanto só aguardavam vaga, sem
iniciar Godot. Nenhum processo próprio de Godot ficou ativo. O processo de teste
de outra sessão foi preservado, conforme decisão do Alisson; a coordenação da fila
está na issue #348. O PR permanece em rascunho até concluir essas pendências.
