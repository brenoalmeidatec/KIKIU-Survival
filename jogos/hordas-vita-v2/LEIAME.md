# Port da v2 para PS Vita: o caminho das pedras

**Estado:** só o esqueleto. Nada aqui roda ainda, e o port **não começa antes do lançamento da v2** (RC em 13/11, lançamento
na semana de 16/11). Pedido do Alisson em 05/11/2026: "só o esqueleto básico, não precisa começar o projeto agora, mas já
deixa tudo pronto para começar". Escrito pelo Claude do Alisson (PC), para quem chegar sem contexto.

## Em uma frase

Não existe Godot 4 no Vita. O caminho é o mesmo que a v1 já provou na branch `alisson/vita-piloto`: **converter o
GDScript 4 para Godot 3** (fork godot-vita do SonicMastr, GLES2), **trocar luz, shader e normal map** pelo que o GLES2
aguenta e **tirar o laço quente da horda do GDScript** (módulo C++ já compilado e medido). A v2 é menor nesses riscos que
a v1 em quase tudo, menos nos shaders e nas luzes.

## O que já existe (não refazer)

Tudo na branch `alisson/vita-piloto`, pasta `jogos/hordas-vita/` (a v1), com o `STATUS.md` completo:

| Peça | Onde | Serve para a v2? |
|---|---|---|
| Medições no Vita real (piloto 1 e 2) | `medicoes/*.csv`, `STATUS.md` | **Sim.** Gargalo é CPU do GDScript (~0,1 ms por inimigo); GPU sobra; cada draw call custa ~45 µs, então atlas é obrigatório |
| Módulo C++ da horda (`HordaVita`) e do hardware (`VitaHW`: touch traseiro, giroscópio, bateria) | `modulo/horda_vita/` | Sim, a lógica muda, o esqueleto do módulo fica |
| Build do template próprio (VitaSDK no WSL, distro `vita-build`) | `compilar/LEIAME.md`, `build_vita.sh`, `patches_motor.py` | Sim, igual |
| Conversor GDScript 4 → 3 (`conversor.py`, `lambdas.py`, ponte `g4.gd`, `verificar.py`, `testar.py`) | `conversor/` | Sim, é a base; a v2 vai pedir regras novas (tabela abaixo) |
| Exportar `.vpk` e o conserto do `param.sfo` | `exportar.sh`, `conserta_sfo.py` | Sim, igual |
| Ferramentas (editor 3.5-rc5-vita e template) | `E:\Dev\KIKIU-Vita\ferramentas\` no PC, fora do Git | Sim |

Lições da v1 que valem ouro: `PackedFloat64Array` virando float de 32 bits quebrou a ordem de desenho; `==` entre
dicionários muda de sentido; `create_timer` ignorando `time_scale`; o exportador grava o TITLE_ID errado às vezes; FTP
com a tela do Vita apagada trunca o arquivo.

## O que muda na v2 (medido)

Rode `python jogos/hordas-vita-v2/inventario.py --md` para os números de hoje. Em 05/11/2026 (branch `alisson/rc1-lightwolf`):
122 scripts e shaders, 48 mil linhas. Os riscos que pesam:

- **A favor:** a v2 desenha numa grade de **960x540 em 1x** (decisão da grade de pixel, #611 a #618), e a tela do Vita é
  **960x544**. É 1:1 com 2 px de faixa em cima e embaixo, sem escala fracionária. A v1 precisava de 640x360 a 1,5x.
  Só 6 `await` e 35 lambdas (a v1 tinha 217 e 106). Sem rede (`@rpc` zero).
- **Contra:** 21 arquivos com shader (77 usos), 7 com `Light2D`/`PointLight2D`, 4 com `CanvasTexture` (normal map das
  folhas de herói e monstro). O GLES2 do fork não tem nada disso do mesmo jeito. As folhas têm `_albedo` e `_normal`;
  no Vita fica só o albedo, com uma luz falsa (a luz BUFFER do piloto) e as cores já assadas.
- **Desconhecido:** o fill-rate em 960x544 (o piloto mediu até 640x360). É a primeira coisa a medir.

## As fases (cada uma termina com um número medido no aparelho)

**Fase 0, preparar (meio dia, sem aparelho).** Juntar a `alisson/vita-piloto` em `jogos/hordas-vita/` na main só com as
ferramentas (conversor, compilar, exportar, módulo), sem o piloto e sem os CSVs grandes, ou trabalhar numa worktree
dela. Conferir que o build do template ainda sai (`compilar/LEIAME.md`, ~17 min do zero).

**Fase 1, piloto da v2 (1 dia).** O piloto da v1 com as folhas da v2 (monstros da Floresta, o Hazaki e o mecha do
LightWolf) em **960x544**, horda pelo `HordaVita` C++, luz BUFFER. Rampa de 100 a 400 monstros.
Critério: 200 monstros na tela a 30 fps em 960x544. Se não der, repetir em 480x272 (2x inteiro, a grade continua inteira).
Se nem 100 segurarem 30 fps, **propor abandonar** (decisão do Alisson).

**Fase 2, conversor da v2 (2 a 3 dias).** `exportar_jogo.sh` apontando para `jogos/hordas/projeto` com a v2 como cena
principal. Regras novas do conversor, em ordem de custo: `Packed*Array` (451 usos, o mais trabalhoso por causa do Float64),
`Time.get_ticks` e `FileAccess` (a ponte G4 já existe), `y_sort_enabled` (vira nó `YSort`), `CanvasTexture` (vira só a
textura albedo), `create_tween`. Meta: os scripts da v2 **carregam** no 3.5 (`verificar.py`) e a suíte de testes da v2
passa no projeto gerado (`testar.py`), como a v1 chegou a 41 de 48.

**Fase 3, visual no GLES2 (2 dias).** Um perfil `vita` em `dados/` (como o `baixa` da v1): sem `Light2D`, sem normal
map, partículas no mínimo, sem `SubViewport` extra. Reescrever à mão só os shaders que ficam (o resto desliga no perfil).
A grade de pixel continua inteira: nada de escala fracionária.

**Fase 4, horda em C++ (3 a 5 dias, o grosso).** Ligar o laço de movimento, separação e desenho dos monstros da v2 ao
`HordaVita`, mantendo a lógica de jogo (ataques, elites, chefes) em GDScript. Na v1 essa foi a decisão que ficou
pendente; na v2 o pool de monstros já é fixo, o que ajuda.

**Fase 5, controles e entrega.** Botões do Vita (os índices do fork estão no `STATUS.md` da v1), touch frontal como mouse
(menus e mira), touch traseiro para o impulso ou a esquiva, LiveArea, `.vpk` com TITLE_ID próprio (a v1 usou KIKU00001 a
KIKU00004; a v2 começa em KIKU00010).

## Regras que continuam valendo

- A v2 do PC **não muda por causa do Vita**: tudo que for só do Vita fica no conversor, na ponte `G4` ou no perfil `vita`.
- Arte: só a do projeto ou livre (`docs/LICENCAS_ARTE.md`). O Vita alvo é desbloqueado (HENkaku/Ensō); não há loja oficial.
- Nenhum binário de ferramenta no Git (editor e template ficam em `E:\Dev\KIKIU-Vita\ferramentas\`).
- Cada fase ganha uma entrada no `LOGBOOK.md` com o número medido.

## Primeira tarefa quando for começar

1. Abrir uma issue "Vita v2: fase 0 e 1" com este arquivo como plano.
2. `git worktree add ../KIKIU-Vita-v2 alisson/vita-piloto` e ler o `jogos/hordas-vita/STATUS.md` inteiro.
3. Rodar `inventario.py` de novo e atualizar a seção "O que muda na v2" se os números mudaram.
