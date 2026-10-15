# Dissolve no efeito de morte — PR #253

## Escopo e pendências

O flash de morte dos monstros usa agora uma máscara estável por texel, seguindo o progresso do tempo de jogo. O pool continua com24 slots; dano e rastro de esquiva não dissolvem. Não usamos TIME nem novos nós. A emissão/reutilização do slot sempre reinicia o uniform.

Este é o componente visual disponível pelo gancho existente, não a entrega completa do item4. O corpo do herói ainda precisa de integração do Claude em heroi.gd; a horda precisa de contrato de fase/velocidade/relógio por instância e sincronia de corpo/olhos/sombra. Não duplicamos controladores nem sobrescrevemos transformações de sistemas. Antecipação, avanço, squash de ataque/carga e esquiva já existem no herói.

## Medição real no Iris Xe

Godot4.4.1, OpenGL Compatibility, viewport960x540, janela oculta, sem headless e sem outros processos Godot simultâneos. Base e depois têm o mesmo projeto antes da mudança (`bd8b5c034992a24dba265b1ef9e390d39141801a`); única diferença de runtime:efeitos.gd. Perfil Médio, alvo300 monstros vivos, build cheia, mesma semente144; aquecimento2s e coleta6s pelo --medir existente.

O laço usa delta real: a semente é igual, mas a simulação e as escolhas automáticas não são bit a bit idênticas entre rodadas. Não é um ensaio de laboratório nem evidência de ganho de FPS. Os logs preservam número de atores, chamadas, carga e métricas GPU/CPU.

Primeira série, três antes seguidos de três depois:95,8/91,4/90,2 FPS antes e67,8/92,9/95,5 depois; medianas91,4 e92,9. A primeira rodada depois teve queda; sua causa não foi isolada. Por essa variação, fizemos uma comparação adicional em pares intercalados, sem eliminar os resultados iniciais.

| Par intercalado | Base (FPS) | Dissolve (FPS) |
|---|---:|---:|
|1|117,6|118,3|
|2|114,2|118,9|
|3|92,8|119,3|
|Mediana|114,2|118,9|

A mediana intercalada não mostrou queda maior que5%; o efeito foi mantido. A variação observada impede prometer ganho. GPU mundo mediana nos pares:5,87ms base e5,71ms depois. Logs individuais completos em medidas/; métricas de headless não foram usadas como FPS.

Comando reproduzível, usando harness externo que só fixa semente, save temporário e tamanho da janela antes de abrir mundo.tscn:

```text
godot --path jogos/hordas/projeto --script CAMINHO/qa_medida_visual.gd -- --medir --duracao=6 --perfil=medio --estresse=300 --imortal --build --sem_vsync
```

## QA

Godot real antes/depois: QA253_DISSOLVE falhas=0, código0 e sem SCRIPT ERROR. No depois verificamos início0, progresso0,5 no meio, estabilidade sem avançar jogo, reset do mesmo slot para dano/esquiva e pool24. Seis prints de viewport960x540 registram25/50/75% da duração, com três silhuetas de fixture em escala2 para inspecionar os pixels.

v2_morte,v2_combate,v2_partida passaram código0/falhas=0/sem SCRIPT ERROR. gdformat scripts/testes/v2:230 arquivos limpos. CI remoto permanece bloqueado pela conta (#249); sem merge até CI verde e sem nova build pelo atalho até Release verde.
