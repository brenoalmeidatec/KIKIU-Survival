# Ultra/Max: plano de protótipo para o PC

Pedido do Alisson em 01/11/2026. Este PR é somente o plano: **a opção Ultra/Max ainda não foi implementada e não há build nova para testar**. O primeiro PR de implementação deverá entregar uma comparação jogável com o Alto atual. Não há promessa de ray tracing real ou de equivalência ao Unreal.

## Resultado pretendido

Dar mais profundidade e presença ao KIKIU sem perder o pixel art, a leitura das hordas ou as opções de acessibilidade. Nome proposto no menu: **Ultra (experimental)**; Max é o nome informal deste mesmo perfil, não um segundo perfil duplicado. Baixo, Médio e Alto mantêm seus padrões.

## Base conferida e escopo inicial

O projeto usa Godot 4.4.1 com Compatibility/OpenGL. `v2/luzes.gd` já cria PointLight2D, limita luzes por orçamento e desliga as que saem da tela. `v2/sombras.gd` projeta silhuetas a partir das luzes. `v2/pos_visual.gd` aplica o pós-processamento somente quando o perfil é literalmente `alto`: auditar esse tipo de comparação antes de acrescentar um perfil, para Ultra não desligar efeitos por acidente.

Primeiro protótipo, em branch separada, mantendo o renderizador atual:

1. **Luz principal:** direção/cor coerentes por mapa; luz fria de lua contra fontes quentes, usando as normais existentes e preservando a silhueta do jogador.
2. **Luzes de combate:** clarões locais curtos de tiros, fogo e explosões, com pool e limite simultâneo; agrupar impactos próximos. Sem criar uma luz por monstro ou por fragmento.
3. **Brilho seletivo:** metal/água/energia com resposta especular e halos discretos, protegendo contornos e HUD. Pesquisar um passe próprio de brilho apenas se os halos aditivos não bastarem; não assumir que o glow HDR funciona em 2D no renderizador atual.
4. **Atmosfera:** névoa em poucas camadas e fachos localizados; parâmetros por mapa, sem esconder ataques anunciados, chão ou coleta.
5. **Sombras de cenário:** comparar oclusores simplificados em obstáculos selecionados com o sistema atual. Sombras suavizadas só nas poucas luzes de maior influência, nunca em toda a horda indiscriminadamente.

Implementar em etapas para medir custo isolado. O primeiro comparativo deve usar a Vila com Nicão e LightWolf, incluindo uma horda, o Q e a transformação mecha/lobo. Depois validar os quatro mapas. Evitar transformar todos os efeitos em uma única mudança difícil de comparar.

## Guardas de implementação

- Efeitos configuráveis em dados, com orçamento fixo de luzes/partículas e descarte fora da câmera; nenhum ajuste de dano, hitbox, spawn, coleta ou velocidade.
- Reduzir piscadas, Tremor e clarões desligado e pausas continuam valendo. UI e telegráficos não recebem o pós-processamento do mundo.
- Troca de perfil durante combate, pausa e resize não deixa material, luz ou nó do perfil anterior ativo. Sem acumular objetos ao reiniciar.
- Auditar todas as comparações com `alto` e os valores persistidos de perfil; preservar compatibilidade das configurações existentes. Qualquer necessidade de mudar save, export ou project.godot deve ser explicitada e aprovada no PR correspondente.
- Não trocar automaticamente para Forward+/Vulkan. HDR, reflexos avançados ou outra arquitetura exigem experimento separado, medição no PC e decisão explícita antes de virar dependência da versão.

## Roteiro reproduzível no PC, a partir das 19h

1. Registrar SHA, Godot 4.4.1, sistema, CPU, GPU, driver, resolução, VSync e opções de acessibilidade. Começar em 1280×720 e repetir na resolução nativa; registrar ambas, sem mudar durante um par de comparações.
2. Na mesma build experimental, alternar Alto atual/Ultra com a mesma semente, herói, mapa, percurso e quantidade de inimigos. Usar o robô existente ou fixture reproduzível, sempre com APPDATA QA isolada. Não usar o save pessoal.
3. Aquecer 30 s; medir três execuções de 90 s para cada perfil/cenário. Separar carga/importação da medição. Gravar tempo de quadro mediano, p95, p99, FPS, pico de memória e, quando disponível, CPU/GPU e VRAM. Informar instrumento e limitações; FPS médio sozinho não aprova.
4. Cobrir cena parada, movimento, pico de horda, ataques/ult, transformação LightWolf, pausa/carta/baú e troca de resolução/perfil. Repetir nos quatro mapas e comparar também Baixo para detectar regressão na base.
5. Capturar janelas reais antes/depois com mesmo enquadramento. Conferir contornos, sombras, luz em metal/água, telegráficos, HUD e acessibilidade. Headless valida lógica, não visual. No notebook, qualquer Godot continua pela fila; o notebook serve para protótipo, não para prometer desempenho no PC.

## Critérios propostos para aceitar o protótipo

- No PC de referência documentado: alvo de 60 FPS, p95 de quadro até 16,7 ms e p99 até 25 ms nos cenários reproduzíveis. São metas de aceite, ainda não resultados medidos.
- Custo adicional do Ultra deve ser mostrado contra o Alto com números e imagens; se o alvo falhar, reduzir primeiro orçamento de luzes, sombras e passes. Ultra permanece experimental até passar.
- Baixo/Médio/Alto sem regressão funcional ou visual e sem novos efeitos ativos fora do perfil escolhido. Nenhum teste aprovado por simples espera na fila.
- Testes afetados com falhas=0, gdformat limpo e CI completo no próprio SHA. Revisão independente por quem não escreveu o código. Sem merge pelo Codex.
- Relatórios brutos, vídeos, fotos e JSONs como anexos/artefatos, nunca dentro do projeto exportado. Resumo curto no PR com visto, não visto, equipamento e limitações.

## Entregas para o Claude retomar

1. PR pequeno com seleção experimental e o primeiro comparativo jogável da Vila, sem trocar renderizador.
2. PRs seguintes por efeito, cada um com medição isolada, captura real e revisão independente.
3. Validar no PC antes de disponibilizar Ultra como opção normal. Tags, Release e decisão de integração ficam com Claude/Alisson.

Neste PR documental não foi executado Godot e nenhum efeito novo foi visto. O ganho visual e o custo do Ultra estão **por medir**.

Referências técnicas oficiais do Godot 4.4: [luzes, sombras, normais e especular em 2D](https://docs.godotengine.org/en/4.4/tutorials/2d/2d_lights_and_shadows.html), [HDR 2D e pós-processamento](https://docs.godotengine.org/en/4.4/tutorials/3d/environment_and_post_processing.html).
