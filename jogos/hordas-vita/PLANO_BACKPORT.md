# Plano do backport do KIKIU Survival para o PS Vita

Escrito em 2026-10-08 (noite) pelo Claude do Alisson (PC), a partir de um levantamento dos 88 scripts da `main`
(`748e0c8`, 24 577 linhas), feito por quatro agentes e revisado. O piloto já provou o motor: ver `STATUS.md`.

## A regra que guia tudo

A `main` muda ~20 PRs por dia. Converter à mão seria correr atrás de um alvo em movimento. Por isso o port é
**gerado**: um conversor automático (`conversor/`) transforma os scripts do Godot 4 em Godot 3 e pode ser rodado de
novo a cada atualização da `main`. O que o conversor não resolve vira (a) uma função de compatibilidade em
`conversor/g4.gd` (autoload) ou (b) um arquivo escrito à mão em `jogo_vita/manual/`, que tem prioridade sobre o gerado.
Os dados (`dados/*.json`) e os sprites são usados como estão.

## O que existe e o que não existe no GDScript 3.5

Existe (não precisa mexer): `var x: T`, `-> T`, `static func`, `class_name`, `match`, `is_instance_valid`,
`get_tree().create_timer`, `create_tween()` (SceneTreeTween foi portado para o 3.5), nomes únicos `%No`, `lerp_angle`,
`move_toward`, `posmod`, `wrapi`, `limit_length`.

Não existe (o conversor troca): arrays tipados `Array[T]`, `static var`, lambdas, `await`, `sinal.emit()`,
`obj.sinal.connect(callable)`, `super()`, `@export/@onready/@tool`, `Packed*Array`, `Vector2i/Rect2i`, `Time.*`,
`queue_redraw`, `clampi/maxf/mini/...`, `deg_to_rad`, `randf_range/randi_range`, `snapped`, `is_empty`, `Color.WHITE`
(no 3 é `Color.white`), `RefCounted`, `RenderingServer`, `FileAccess/DirAccess`, `JSON.parse_string/stringify`,
`sep.join(arr)`, `angle_to_point` (sinal invertido), `draw_string` (assinatura diferente), `set_shader_parameter`,
`add_theme_*_override`, `KEY/MOUSE_BUTTON/JOY_*` renomeados, `event.keycode`.

## Divisão por destino (levantamento)

| Destino | Arquivos | Linhas |
|---|---|---|
| Converter para GDScript 3 | 47 | 11 242 |
| Converter + otimizar (laços por quadro, `_draw` grandes) | 19 | 5 923 |
| **C++ no módulo** | 10 | 3 677 |
| Fora da v1 (online) | 6 | 1 961 |
| Simplificar/cortar no Vita | 6 | 1 774 |

- **C++:** `inimigos.gd`, `diretor_hordas.gd`, `armas.gd` (o laço de efeitos ativos), `armas/elemental.gd`,
  `armas/corvos.gd`, `elementos.gd`, `coleta.gd`, `efeitos.gd` (partículas, números, halos), `animacao_monstros.gd`,
  `visual.gd` (o bake de sombras por pixel sai: no Vita a sombra já vem assada no atlas, como no piloto).
  O `HordaVita` do piloto é a base; ganha vida/dano/estados/elementos, coleta de gemas e um lote de efeitos.
- **Fora da v1:** `rede.gd`, `online.gd`, `salas.gd`, `chat.gd`, `voz.gd`, `remoto.gd` (o Vita tem Wi-Fi, mas o online
  com ENet/ntfy/playit fica para depois de o jogo solo rodar).
- **Simplificar:** `mortes.gd` (morte em pedaços recalcula polígonos por quadro: trocar por 2–3 variantes baratas),
  `finalizacao.gd` (11 golpes finais → 2–3), `ambiente.gd` (partículas e bichos do chão: perfil `vita` corta),
  `escuridao.gd` (troca pela luz em buffer do piloto), `transicao.gd`, `armas/aura_energia.gd`.
- **Mais difíceis de converter:** `main.gd` (1 940 linhas, 80 `await`, 16 lambdas, 63 timers), `arena.gd` (1 409,
  16 `await`, 13 lambdas), `duelo.gd` (13 lambdas), `hud.gd` (~43 `draw_*` por quadro).

## Perfil gráfico `vita`

Derivado do `baixa` de `dados/qualidade.json`: `escuro_luzes` 8 (igual à luz do piloto), sem halo/névoa/sombra
projetada/vinheta, partículas a 0,25. Resolução 480×272 (2× inteiro). Atlas único por região.

## Ordem de trabalho

1. Conversor + `g4.gd` até os 66 scripts "converter" passarem no parser do Godot 3 (`--check-only`).
2. Cenas: converter o formato 3 → 2 (o jogo monta quase tudo por código; poucas cenas).
3. Horda real no C++ (vida, dano, elementos, coleta), ligada ao `arena.gd` convertido.
4. Primeiro "jogável" no Vita: uma fase solo, um herói, armas básicas. Medir.
5. O resto das telas (criação, loja, mapa, cartas) e o perfil `vita`.
