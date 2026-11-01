# Efeitos do pixelfx no jogo

O [pixelfx](https://github.com/patch-gg/pixelfx) (MIT, Copyright (c) 2026 Patch e Hugo Duprez) gera efeitos em pixel art por código. Aqui usamos só as **folhas** (PNG + JSON) que ele exporta, tocadas por `jogos/hordas/projeto/v2/fx_folha.gd`. O jogo não depende de Node nem do clone: só dos PNG em `assets/v2/pixelfx/<categoria>/` e do registro `dados/v2_pixelfx.json`.

## Tocar um efeito (`combate.fx_folha`)

- `tocar(id, pos, opcoes := {})`: efeito único em `pos` (coordenada do mundo; o pivô da folha cai nela). Volta ao pool sozinho no último quadro.
- `prender(id, alvo: Node2D, desl := Vector2.ZERO, opcoes := {}) -> int`: loop que segue o nó, até `soltar(alca)`. Devolve a alça (0 = recusou). Pedir o mesmo id no mesmo alvo devolve a alça que já existe.
- `soltar(alca)` devolve ao pool; `vivo(alca)` diz se ainda vale.
- `opcoes`: `escala` e `cor` (trocam as do registro). Tudo é pool de tamanho fixo (`MAX`), sem nó por disparo; cada id tem `limite` de cópias vivas. Perfil Baixo (`Anim.suave` desligado): `decorativo` não nasce e some do ar.

## Regenerar uma folha

No clone do pixelfx (`C:\Dev\KIKIU\notas\pixelfx`): `node tools/render.mjs <categoria>/<efeito> --sheet --no-actor --out <pasta>` gera `<pasta>/<categoria>/<efeito>/<efeito>.png` e `.json`. O `meta.pixelfx` do JSON traz `fps`, `loop`, `frames`, `frameSize`, `pivot` e `columns`, que são os números do registro. Olhe o PNG antes de usar: alguns efeitos de status pintam também o corpo do boneco padrão, e isso não pode aparecer sobre os nossos monstros. As folhas de `weather` são gigantes (até 4800x4320) e não entram como folha.

## Registrar um efeito novo

1. Copie o PNG para `assets/v2/pixelfx/<categoria>/` e abra o projeto uma vez no Godot (`--headless --import`) para gerar o `.import`; versione os dois.
2. Acrescente a entrada em `dados/v2_pixelfx.json`, em `efeitos`, usando como id o nome do efeito. Obrigatórios: `arquivo` (relativo a `assets/v2/pixelfx/`), `quadro` [w,h], `colunas`, `quadros`, `fps`, `pivo` [x,y]. Opcionais: `loop`, `escala`, `cor` (`[r,g,b,a]` ou `"#rrggbb"`, multiplica a folha), `camada` (`glow`, padrão, ou `mundo`), `aditivo`, `passo` (2 pula um quadro por tick), `limite` (8), `intervalo` (s entre dois `tocar` do mesmo id), `decorativo` (true) e `clarao` (o alfa segue "Tremor e clarões"). Corte os quadros vazios do fim em `quadros`.
3. Chame `fx_folha.tocar`/`prender` de onde o efeito acontece, e `soltar` ao acabar (o `limpar_partida` já devolve tudo).
4. Registre o PNG no fim de `docs/LICENCAS_ARTE.md` (origem pixelfx MIT e o efeito de origem). Cubra o uso novo em `testes/v2_fx_folha.gd` ou num teste do módulo.

## Status visíveis (`combate.fx_status`, v2/fx_status.gd)

Chama (`burning`, `queima_t`), relógio (`slowed`, `lento_t`) e estrelas (`stunned`, `atordoa_t`) sobre o monstro; o relógio também sobre o herói na teia da Rainha Tecelã (`chefes.heroi_lento()`). Congelado, envenenado e sangrando não existem como mecânica no jogo, então não têm efeito. O monstro comum é desenhado em lote e não tem nó: o efeito prende numa âncora de um pool fixo (`MAX_MONSTROS` = 10) que segue o monstro. Quem tem status é achado varrendo uma fatia da lista de monstros por quadro; só desenha o que está na tela. Limites por tipo: 6 chamas, 4 relógios, 4 estrelas. O atordoamento só acende estrelas se for de 0,4 s ou mais (o corte comum de 0,3 s não). Perfil Baixo: nada é desenhado, e o tingimento do corpo (`monstro.gd`) segue avisando. As folhas vêm de `jogos/hordas/fonte_arte/pixelfx_status/preparar_status.py` (recorta o boneco fora e desenha a chama). Teste: `testes/v2_fx_status.gd`.

