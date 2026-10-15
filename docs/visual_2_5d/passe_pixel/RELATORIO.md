# Passe pixel no perfil Alto — PR #258

## Entrega e limite

Passe real no SubViewport 960x540: quantização RGB de 5 bits (32 níveis por canal) com Bayer 4x4 estático e discreto. O shader amostra centros de pixel e usa nearest. Não usa relógio, não captura mouse e não altera o upscale sharp bilinear.

Apenas `Config.g_perfil() == "alto"` ativa o passe. Baixo, Médio e Personalizado ocultam o retângulo e removem o material de screen texture. A escolha de Personalizado desligado segue o pedido de efeito somente no Alto; não há nova opção gravada.

O canvas usa camada 3 e sublayer -1 explícito via RenderingServer; a ordem é reaplicada após mudanças nos filhos do SubViewport. Assim ele fica depois de mundo/glow e antes da vinheta e das camadas 4+ da interface. A criação primeiro, sozinha, não garante ordem entre camadas de mesmo índice: [CanvasLayer Godot 4.4](https://docs.godotengine.org/en/4.4/classes/class_canvaslayer.html#class-canvaslayer-property-layer). A API de sublayer é documentada em [RenderingServer](https://docs.godotengine.org/en/4.4/classes/class_renderingserver.html#class-renderingserver-method-viewport-set-canvas-stacking).

**Bloom seletivo ainda não foi implementado.** O renderer atual Compatibility no Godot 4.4 não oferece HDR 2D, conforme a [matriz oficial](https://docs.godotengine.org/en/4.4/tutorials/rendering/renderers.html). Precisamos do contrato de máscara de emissão apenas para portal, magia, olhos e tochas, mais downsample 240x135/blur/composição, encaminhado ao Claude no PR. Não aplicamos threshold na imagem inteira nem afirmamos que a quantização equivale a bloom. Item 5 parcial, PR em rascunho.

## QA real

Godot 4.4.1, OpenGL Compatibility na Intel Iris Xe, janela oculta. `QA258_POS falhas=0`, código 0 e sem SCRIPT ERROR/SHADER ERROR. Confere perfil inicial Alto, troca para Baixo/Médio/Personalizado, volta para Alto, viewport 960x540 e material do upscale preservado. Desligado significa sem material de screen texture.

O teste também cria uma cor sentinela opaca na camada 3 e move o passe para o começo/fim da árvore: ela permanece sem quantização, comprovando o sublayer após reordenação. A sentinela não está nos prints do produto.

Comparação das capturas do mesmo mundo congelado, desligando/ligando apenas o passe: 1.680 pixels opacos conhecidos da barra de vida do HUD, nenhum alterado; 233.529 pixels alterados na área amostrada do mundo. Isso verifica os pixels amostrados e a posição de composição; não é uma prova de todos os estados de todas as telas. Painéis translúcidos naturalmente mostram o mundo processado por baixo.

## Desempenho medido no Iris Xe

Renderer real, sem headless, sem outro Godot simultâneo. Perfil Alto, alvo 500 monstros vivos, build cheia, mesma semente 144; --medir com 2 s de aquecimento e 6 s de coleta. O laço usa delta real e escolhas automáticas, portanto a cena não é bit a bit idêntica entre rodadas. A base tem o mesmo projeto antes do passe, árvore bd8b5c034992a24dba265b1ef9e390d39141801a. Os logs completos registram carga, atores, chamadas e GPU/CPU.

| Par final alternado | Base FPS | Passe FPS |
|---|---:|---:|
| 1 | 78,9 | 80,0 |
| 2 | 82,3 | 75,9 |
| 3 | 79,6 | 65,1 |
| Mediana | 79,6 | 75,9 |

Queda de 4,65% na mediana final. A última rodada caiu mais e a GPU variou bastante; não prometer custo estável nem ganho. GPU mundo mediana final: 5,79 ms base e 9,35 ms com passe. Série exploratória antes da correção de ordem: medianas 83,2 e 84,1 FPS; GPU 5,72 e 6,39 ms. Ambos os conjuntos foram preservados; não descartamos a série final mais lenta. Bloom não foi medido porque não foi implementado.

## Testes de regressão

v2_hud, v2_fontes, v2_pausa, v2_esc, v2_partida, v2_morte, v2_mapas, v2_minimapa e v2_santuario: todos código 0, falhas=0 e sem SCRIPT ERROR. gdformat em scripts/testes/v2: 231 arquivos limpos. CI remoto não inicia por cobrança/limite da conta (#249); sem merge ou nova build/atalho até CI e Release verdes.

Os harnesses estão nesta pasta. Passe `--script` com seu caminho absoluto e `--path jogos/hordas/projeto`. `qa_258_pos.gd -- --saida=PASTA` valida e captura; `qa_medida_visual.gd -- --medir --duracao=6 --perfil=alto --estresse=500 --imortal --build --sem_vsync` mede. Saves de meta temporários, opções de perfil só na memória, sem escrita nas opções reais.
