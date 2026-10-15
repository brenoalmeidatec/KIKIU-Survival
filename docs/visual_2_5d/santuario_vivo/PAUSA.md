# Salão vivo — checkpoint de pausa,14/10/2026

**PAUSADO por solicitação explícita do Alisson. Não pronto para integração.**

## Base e responsabilidade
Frente visual devolvida pelo pedido direto do Alisson e PR264 (ainda aberto ao iniciar). Lido fim do LOGBOOK da branch alisson/divisao-volta, AGENTS restaurado e referência docs/imagens/referencia_2_5d.webp. Adotada a implementação opcional263, headf38d857, empilhada sobre261/a748476 e242. Não integramos main ou PRs alheios. User pediu: sala viva com oito itens, sem perder conceito260,nearest e legibilidade, limites2/6/10luzes e20/45/80partículas, pausa/painel congelam efeitos, Meta só leitura. Entrega exige prints960x540 e10quadros/GIF Baixo/Médio, Médio>=120FPS e queda<=15%, testes salão/menu/meta/santuário.

## Feito nesta retomada
- Reserva de trabalho no PR263: https://github.com/brenoalmeidatec/KIKIU-Survival/pull/263#issuecomment-6175761067 . Workflow com agentesGPT6.1Sol leve.
- Revisada base do Claude: chamas/halos/poças, PointLight2D via luzes.gd, sombra via sombras.gd, shader de portal/névoa, CPUParticles2D, respiração/reação e runas por níveis. Sem nova arte imagegen: fontes aprovadas do261 preservadas.
- salao_vivo.gd: prioridade de processamento1 após o movimento; direção do prompt só redesenha quando muda; rótulos movidos para camada sem CanvasModulate; speed_scale0 explícito nas partículas durante congelamento; assinatura visual de Config.graficos_mudou com reconstrução adiada ao fechar painel/pausa. Não alterados save/compras/heróis/fluxo.
- v2_salao_vivo ampliado com avanço/congelamento/retorno do shader, contagem de partículas inclusive compras máximas, personalizado sem partículas/névoa, hashes de saves/opções, comparação gráfica de pixels (esta parte ainda NÃO executada comGPU).
- Novo bench_salao_vivo portátil: sem limite deFPS/VSync, prime dos dois casos, aquecimento3s/amostra3s, ordemAB/BA por par, saves isolados,CSV/JSON,capturasfora da medição. Baseline é script salao.gd do261 passado por --baseline=CAMINHO; --out=PASTA e --pairs=3. Não é comparação de builds completas; restante do projeto é compartilhado.

## Evidência preliminar — NÃO aprovação
Godot4.4.1 real,Compatibility/OpenGL3.3,IntelIrisXe,viewport960x540,janela oculta. Um único par exploratório, não medição final:

| Perfil/cenário | AntesFPS | DepoisFPS | Queda |
|---|---:|---:|---:|
| Baixo parado |1935,72|1206,43|37,68%|
| Médio parado |1746,12|1102,48|36,86%|
| Baixo movimento inicial |1930,56|1090,86|43,50%|
| Médio movimento inicial |1915,04|1074,52|43,89%|

**O limite de queda15% NÃO foi atendido.** Os casos de movimento iniciais deslocavam posição sem animar passos: não usar para aceitação. Harness já corrigido para ações de movimento reais; ainda não reexecutado. Não limitar artificialmente baseline para esconder queda. Monitores CPU noCSV são exploratórios, não prometer métricasGPU que não foram medidas.

Teste v2_salao_vivo ampliado em headless: código0/falhas=0/semSCRIPTERROR. Persistem avisos de materialRID/shaderRID/ObjectDB e3resources ao encerrar (logs preservados); não chamar execução limpa de avisos. Não rodada a suíte final de salão/menu/meta/santuário nesta etapa, nem CI do checkpoint, nem comparações gráficas novas de pausa. Os resultados verdes do261 e do rascunho original não substituem essa validação final.

CSV/JSON/saídas QA estão em qa_inicial/.40PNG960x540 e logs completos permanecem na pasta local de análise, registrados no checkpoint local. Não são entrega visual final. Nenhuma janela/teste deixado rodando.

## Próximos passos ao retomar
1. Atualizar refs,ler AGENTS/LOGBOOK e confirmar que263 não mudou com outro agente. Rever este checkpoint antes de editar.
2. Otimizar custo real: ainda NÃO aplicados controle30Hz de efeitos, recorte de áreas iluminadas, redraw do herói só quando muda quadro/direção, nem suspensão de redraw das chamas ocultas. Medir cada escolha sem falsificar baseline. Cortar névoa opcional se necessário.
3. Remover ciclo RefCounted Portal.info ↔ Dictionary.portal não utilizado; investigar vazamentos. Usar nearest nas sombras do salão (módulo sombras.gd usaLINEAR), sem alterar sistema compartilhado.
4. Conferir reaplicação real de perfil/personalizado ao fechar Ajustes; modulação suave atualc8cbe0 precisa comparação de brilho, não escurecer sala inteira. Confirmar limites/partículas e legibilidade no máximo de melhorias.
5. Executar pares alternados finais (mínimo3), parado e andando, Médio<=15%queda e>=120FPS. Compararcapturas,salvar antes/depois e10quadros Baixo/Médio ouGIF. Rodar os testes afetados e formatação global; CI no head final.
6. Atualizar PR263 com evidências finais e comentário começando "Para o Claude do Alisson:". Claude integra. Nada de merge/Release/build/atalho nesta pausa.

Acompanhamento periódico da integração também foi PAUSADO por ordem do Alisson; não retomar automaticamente.

_Codex do Alisson_
