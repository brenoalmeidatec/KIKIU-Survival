# Efeitos do pixelfx no jogo

O [pixelfx](https://github.com/patch-gg/pixelfx) (MIT, Copyright (c) 2026 Patch e Hugo Duprez) gera efeitos em pixel art por código. Aqui usamos só as **folhas** (PNG + JSON) que ele exporta, tocadas por `jogos/hordas/projeto/v2/fx_folha.gd`. O jogo não depende de Node nem do clone: só dos PNG em `assets/v2/pixelfx/<categoria>/` e do registro `dados/v2_pixelfx.json`.

## Tocar um efeito (`combate.fx_folha`)

- `tocar(id, pos, opcoes := {})`: efeito único em `pos` (coordenada do mundo; o pivô da folha cai nela). Volta ao pool sozinho no último quadro.
- `prender(id, alvo: Node2D, desl := Vector2.ZERO, opcoes := {}) -> int`: loop que segue o nó, até `soltar(alca)`. Devolve a alça (0 = recusou). Pedir o mesmo id no mesmo alvo devolve a alça que já existe.
- `soltar(alca)` devolve ao pool; `vivo(alca)` diz se ainda vale.
- `opcoes`: `escala` (INTEIRA: fração mistura pixels de tamanhos diferentes e o `fx_folha` arredonda com aviso) e `cor` (trocam as do registro). Precisa de outro tamanho? Gere uma folha nova já nesse tamanho com `jogos/hordas/fonte_arte/pixelfx/gerar_folhas.py` e registre com outro id (`spawn-portal`, `spawn-portal-mini`, `spawn-portal-chefe`). Tudo é pool de tamanho fixo (`MAX`), sem nó por disparo; cada id tem `limite` de cópias vivas. Perfil Baixo (`Anim.suave` desligado): `decorativo` não nasce e some do ar.

## Regenerar uma folha

No clone do pixelfx (`C:\Dev\KIKIU\notas\pixelfx`): `node tools/render.mjs <categoria>/<efeito> --sheet --no-actor --out <pasta>` gera `<pasta>/<categoria>/<efeito>/<efeito>.png` e `.json`. O `meta.pixelfx` do JSON traz `fps`, `loop`, `frames`, `frameSize`, `pivot` e `columns`, que são os números do registro. Olhe o PNG antes de usar: alguns efeitos de status pintam também o corpo do boneco padrão, e isso não pode aparecer sobre os nossos monstros. As folhas de `weather` são gigantes (até 4800x4320) e não entram como folha.

## Registrar um efeito novo

1. Pixel art não tem alfa gradual: a folha original do pixelfx traz 250 níveis de transparência e dezenas de milhares de cores. Ponha a original em `fonte_arte/pixelfx/originais/<categoria>/`, acrescente-a em `UM_PARA_UM` (ou em `FOLHAS`, se precisar de outro tamanho) de `fonte_arte/pixelfx/gerar_folhas.py` e rode o script: ele grava em `assets/v2/pixelfx/` com o alfa em 6 degraus e a paleta enxuta (`fonte_arte/quantizar_alfa.py`; o `testes/v2_alfa_pixel.tscn` falha com folha de alfa gradual). Copie o PNG para `assets/v2/pixelfx/<categoria>/` e abra o projeto uma vez no Godot (`--headless --import`) para gerar o `.import`; versione os dois.
2. Acrescente a entrada em `dados/v2_pixelfx.json`, em `efeitos`, usando como id o nome do efeito. Obrigatórios: `arquivo` (relativo a `assets/v2/pixelfx/`), `quadro` [w,h], `colunas`, `quadros`, `fps`, `pivo` [x,y]. Opcionais: `loop`, `escala` (inteira), `cor` (`[r,g,b,a]` ou `"#rrggbb"`, multiplica a folha), `camada` (`glow`, padrão, ou `mundo`), `aditivo`, `passo` (2 pula um quadro por tick), `limite` (8), `intervalo` (s entre dois `tocar` do mesmo id), `decorativo` (true) e `clarao` (o alfa segue "Tremor e clarões"). Corte os quadros vazios do fim em `quadros`.
3. Chame `fx_folha.tocar`/`prender` de onde o efeito acontece, e `soltar` ao acabar (o `limpar_partida` já devolve tudo).
4. Registre o PNG no fim de `docs/LICENCAS_ARTE.md` (origem pixelfx MIT e o efeito de origem). Cubra o uso novo em `testes/v2_fx_folha.gd` ou num teste do módulo.

## Status visíveis (`combate.fx_status`, v2/fx_status.gd)

Chama (`queima_t`), relógio (`slowed`, `lento_t`) e estrelas (`stunned`, `atordoa_t`) sobre o monstro; o relógio também sobre o herói na teia da Rainha Tecelã (`chefes.heroi_lento()`). Congelado, envenenado e sangrando não existem como mecânica no jogo, então não têm efeito. O fogo tem duas camadas: o corpo escurecido e a borda de brasa vêm do shader do sprite (`v2/status_corpo.gd`), e a **chama alta** é uma folha animada presa às costas do monstro: 3 tamanhos (`chama_p`, `chama_m`, `chama_g`, quadros de 40x48, 72x88 e 104x128, 12 quadros a 14 fps em loop), escolhidos pela altura (`alt`) do monstro em `dados/v2_pixelfx.json` > `status.fogo.faixas`. Cada quadro já traz várias línguas com fase e harmônica diferentes e as brasas soltas subindo; cada monstro começa num ponto diferente da volta (`opcoes.fase`). A arte é procedural: `jogos/hordas/fonte_arte/chama/gerar_chama.py`. O monstro comum é desenhado em lote e não tem nó: o efeito prende numa âncora de um pool fixo (`status.max_monstros` = 12, das quais `reserva_elite` = 2 só para elite e chefe) que segue o monstro. Quem tem status é achado varrendo uma fatia da lista de monstros por quadro; só desenha o que está na tela. Limites por tipo (`status.limite`): 12 chamas, 6 relógios, 6 estrelas. O atordoamento só acende estrelas se for de 0,4 s ou mais (o corte comum de 0,3 s não). **Reduzir piscadas:** a chama toca a 1,5 quadro por segundo (`fps_calmo` do registro), então nenhum pixel troca mais de 2 vezes por segundo. Perfil Baixo: nenhum sprite de status é desenhado, e o tingimento do corpo (`monstro.gd`) segue avisando. As folhas do relógio e das estrelas vêm de `jogos/hordas/fonte_arte/pixelfx_status/preparar_status.py` (recorta o boneco fora). Testes: `testes/v2_fx_status.gd` (o pool) e `testes/v2_chama_sprites.gd` (a arte, as trocas por segundo e o desenho em janela).

## Clima por mapa (`v2/clima.gd`)
Os efeitos de `weather` e o `scifi/glitch` não entram como folha (são gigantes): a lógica foi portada para código e desenhada em espaço de tela, com quantidade fixa, num CanvasLayer 1 do mundo (acima do cenário, abaixo do brilho dos projéteis). Quais efeitos cada mapa tem, e quantos, fica em `dados/v2_clima.json` (o `_ajuda` de lá explica os campos). Perfil Baixo desliga tudo; Médio usa metade; o glitch segue "Tremor e clarões". Teste: `testes/v2_clima.tscn`.

## Impactos das armas
Os impactos das armas no estilo do pixelfx não passam pelo `fx_folha`: são folhas de `assets/v2/armas_anim/` (`indice_pixelfx.json`), tocadas por `armas_novas.tocar_fx`. Guia: `docs/visual_2_5d/estilo_pixelfx.md`.
