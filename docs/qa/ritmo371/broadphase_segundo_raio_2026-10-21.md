# Chuva: margem do segundo raio

Reprodução anterior à correção em `5f132dc0b34c87d33edf70259d94327dadc458cf`: `v2_ritmo` registrou exatamente **1 falha**, no acerto do segundo alvo. O alvo além do alcance real permaneceu intacto.

A prova aplica seis cartas lendárias de área e quatro de Mira e Chuva pelos métodos reais de cartas: área 3,304, Mira 192%. Inicia Q de Lucas e lança uma lâmina pela rodada real. Envelhece a lâmina sem alvos, em passos de no máximo 0,1 s, até restar aproximadamente 1 px. Reutiliza esse estado alcançável nas tentativas do sorteio, sem substituir o RNG ou o narrowphase. A semente 149 gera uma extra quase horizontal, velocidade 1.284,8 px/s e raio 7,270763. O cão de ossos usa seu raio real de 7 px.

O primeiro corpo toca a extremidade do segmento primário. A extra nasce e percorre seus 120 px no mesmo quadro. O segundo corpo fica inteiro fora da AABB anterior, mas a menos de um raio composto da extremidade da extra. Ambos ficam a menos de 560 px do herói. Um terceiro corpo, 1 px além do alcance composto, não recebe dano.

A margem soma agora o maior raio das lâminas primárias ativas, calculado no mesmo passe limitado a 96 entradas. O raio que já estava na união foi gasto no primeiro contato; o segundo cobre o corpo da extra. A seleção continua O(MAX + 2N); pool, narrowphase e RNG não mudam.

Após a correção, a mesma prova passa (`v2_ritmo falhas=0`), inclusive os controles de direção/seed, corpo fora da caixa antiga, alvo externo e pool fixo. A suíte também conserva a prova anterior de que o broadphase não consome RNG. Os logs headless mantêm avisos de recursos do renderer na saída; isso não é uma prova de ausência de vazamentos gráficos.

Esta é uma prova localizada de geometria. Os relatórios comparativos anteriores permanecem históricos; uma nova matriz AFTER será registrada separadamente pelo responsável pela comparação.

Validação local: v2_ritmo, v2_especial, v2_raio_por_nivel, v2_combate, v2_herois, v2_status e v2_partida encerraram com código 0 e falhas=0, sem SCRIPT ERROR. gdformat -l 160 --check no escopo scripts/testes/v2: 329 arquivos limpos; git diff --check limpo.
