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
Os resultados de testes e do robô serão acrescentados aqui depois da validação.
