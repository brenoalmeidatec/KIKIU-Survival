# DESIGN da UI da v2

Guia visual dos menus e da interface da v2 (`jogos/hordas/projeto/v2/`). Leia antes de mexer em menu, HUD, cartas ou santuário. Cada cor e fonte traz `arquivo:linha` do código do `main`. Se o código mudar, atualize este arquivo no mesmo PR.

**Regras de ouro**
- Tudo cabe em 960x540, e o essencial fica dentro da área segura (seção 1).
- Texto corrido só em Spleen 16 px. Títulos só em Jersey 19, 37 ou 56. Números em Press Start 2P (seção 3).
- Use as cores da seção 2 antes de criar uma. Cor nova entra na tabela.
- Pouco texto: barra, pip, ícone e número grande antes de palavra.
- Antes de subir, rode os testes da seção 7.

## 1. Resolução, escala e área segura

| Onde | Desenho | Escala |
|---|---|---|
| Partida: HUD, pausa, SUA BUILD, escolha, baú, resultado | SubViewport 960x540 (`apresentacao.gd:9-10, 28-33`) | `KEEP_ASPECT_COVERED` (`apresentacao.gd:40`), sharp bilinear (`:49-66`) |
| Santuário (`altar.gd`) | direto na janela, sem SubViewport; a pausa fica na raiz (`v2/LEIA-ME.md:26`) | `CANVAS_ITEMS` 960x540 + `ASPECT_KEEP`, com faixas pretas (`altar.gd:120-125`) |

- `project.godot` declara 640x360 e stretch viewport (`:40-45`), mas a v2 troca o modo em tempo de execução (`altar.gd:123-125`, `apresentacao.gd:27`).
- O mouse da partida passa pelo mesmo corte (`apresentacao.gd:69-73`). Controles dentro do SubViewport não recebem mouse, então os botões são retângulos (`v2/LEIA-ME.md:26`).
- Corte da partida: escala = `max(janela_w/960, janela_h/540)`. Corte por lado, em px do mundo: `480 - janela_w/(2·escala)` em x e `270 - janela_h/(2·escala)` em y.

| Janela | Corte | Área segura no mundo |
|---|---|---|
| 16:9 (1280x720) | nenhum | x 0-960, y 0-540 |
| 16:10 (1280x800) | ~48 px em x | x 48-912 |
| 4:3 (1024x768) | ~120 px em x | x 120-840 |
| 21:9 (2560x1080) | ~68 px em y | y 68-472 |

## 2. Paleta

Hex arredondado. O valor exato é o `Color(...)` citado.

| Papel | Cor | Onde |
|---|---|---|
| Painel de pedra (fundo) | `#01030b` a 0,80 | `v2/hud/gerar_molduras.py:41, 50` |
| Véu da pausa / do santuário | `#01030b` a 0,72 / `#030509` a 0,80 | `pausa.gd:41, 108`; `altar.gd:146` |
| Cartão da escolha (normal / selecionado) | `#12111a` / `#211f2b` | `telas.gd:124` |
| Borda do cartão sem raridade | `#5c5773` | `telas.gd:122` |
| Texto / texto apagado | `#ebe6f5` / `#8c8fa3` | `pausa.gd:39`; `altar.gd:20-21` |
| Cabeçalho de seção / rótulo do card | `#9e99b8` / `#b8b3d4` | `pausa.gd:40`; `status.gd:59` |
| Destaque: seleção e títulos (foco de texto `#fff7cc`) | `#ffdb6b` | `pausa.gd:38`; `altar.gd:19, 23`; `resultado_meta.gd:16`; `status.gd:58` |
| Ouro do HUD (marcos, relógio, evolução) | `#f1b10e` | `hud.gd:16, 293-294` |
| Almas | `#cca8ff` | `altar.gd:24`; `resultado_meta.gd:17` |
| Raridade comum / raro / épico / lendário | `#ccd1db` / `#59a8ff` / `#bd66ff` / `#ffbd33` | `dados/v2_cartas.json:4-7` |
| Fusão lendária (faixa e rodapé) | magenta `#ff73d9` | `telas.gd:17, 249, 253` |
| Barras do HUD: vida / XP / fôlego / fantasma do chefe | `#b9212d` / `#e0bc48` / `#4aa3d9` / `#ecceb0` | `gerar_molduras.py:30, 33, 36, 43` (usos em `:162-168`) |
| Card SUA BUILD: vida / XP / fôlego | `#db3840` / `#73bfff` / `#8cf29e` | `status.gd:894-896` |
| Piscadas: vida / fôlego cansado | `#ff6666` / `#ff5933` | `hud.gd:23, 21` |
| Perigo: onda / vinheta / dano no herói | `#ff544d` / `#ff1a1a` / `#ff5252` | `hud.gd:32, 24`; `combate.gd:25` |
| Anúncios: elite / nível / crítico | `#bf73ff` / `#d1ebff` / `#ffbd33` | `hud.gd:33-34`; `combate.gd:24` |
| Números de dano | `#fff5d6` | `combate.gd:23` |
| Card: valor / santuário / dica | `#ffeda8` / `#d1adff` / `#99ccfa` | `status.gd:60, 62, 63` |
| Seleção de linha na pausa | ouro a 0,14 + borda ouro 2 px | `pausa.gd:136-140` |

**Duplicação (cor espalhada):**
- O ouro tem pelo menos 5 valores. `COR_OURO` está copiado em `pausa.gd`, `altar.gd`, `resultado_meta.gd` e `status.gd`.
- O roxo de alma tem 3 valores: `#cca8ff`, `#d1adff` (card) e `#d06df2` (paleta de arte).
- O vermelho de perigo tem 6 variantes (`#db3840`, `#ff5252`, `#ff544d`, `#ff6666`, `#ff5933`, `#ff1a1a`).
- Sugestão, não feita aqui: um único arquivo de constantes de cor para a v2.

## 3. Tipografia

| Fonte (`scripts/hordas/dados.gd`) | Uso | Tamanhos (onde) |
|---|---|---|
| Jersey 10 (`fonte_titulo`, `:20-22`) | títulos, nomes, botões grandes | 56: títulos (`pausa.gd:22`, `altar.gd:151`, `telas.gd:22`). 37: nomes e saldo (`telas.gd:23`, `altar.gd:154`). 19: botões e linhas (`pausa.gd:23`), trava (`telas.gd:26`), cabeçalhos (`status.gd:35`) |
| Spleen 8x16 (`fonte_texto`, `:23-25`) | texto corrido, valores, ajuda | 16 (`pausa.gd:24-27`, `telas.gd:25`) |
| Press Start 2P (`fonte`, `:15-19`) | números, HUD, lista do santuário | 8 (`hud.tscn:24`, `altar.gd:156, 172`, `pausa.gd:162`). 16 em números grandes (`status.gd:891`) |

- Spleen só em 16 ou 32 px (`dados.gd:10`, `v2/LEIA-ME.md:39`). Títulos só em 19, 37 ou 56.
- A lista densa do santuário em Press Start 8 px é exceção aprovada (`altar.gd:6`, `v2/LEIA-ME.md:39`).
- O 5 não pode parecer S. Dígitos e acentos são conferidos nos prints (`testes/v2_fontes_prints.tscn`).
- As três fontes saem sem ligaduras (`dados.gd:19, 22, 25`).
- O tema padrão do projeto é Press Start 2P (`project.godot:49`). Label sem override cai nela.
- Fonte nova: licença livre, texto da licença junto, linha em `docs/LICENCAS_ARTE.md` e nos Créditos.

## 4. Componentes

- **Painel de pedra** (santuário, pausa, SUA BUILD, HUD): `moldura_pedra.png` 20x20 em `StyleBoxTexture`, margem de textura 5 px e de conteúdo 4 px, tingida por `modulate` (`altar.gd:256-265`, `pausa.gd:116-117`, `status.gd:26`, `hud.tscn:33`). Sem sombra.
- **Cartão** (escolha, baú, resultado): `StyleBoxFlat` quadrado, borda de 2 px (+1 em épico ou lendário, +1 se selecionado), brilho externo a partir de raro (`telas.gd:122-132`). Moldura do ícone: fundo `#08060d` a 0,95 e borda de 2 px (`telas.gd:266-272`).
- **Botão do santuário** (`altar.gd:268-280`): normal = moldura cinza-azulada, texto `#ebe6f5`. Foco ou hover = moldura ouro, texto `#fff7cc`. Pressionado = moldura mais escura. Desabilitado = moldura a 0,75 de alfa, texto `#8c8fa3`.
- **Botão da escolha** (`telas.gd:275-285`, `:403-404`): painel 240x28, texto de 16 px. Não tem foco; fica com alfa 0,4 quando não pode rerrolar ou banir.
- **Lista da pausa** (`pausa.gd:34, 510-516, 136-140, 534`): 5 linhas visíveis, rolagem acompanha a seleção. Linha selecionada: ouro a 0,14, borda ouro 2 px, rótulo ouro. Cabeçalho não é selecionável.
- **Entrada da lista e da escolha:**
  - teclado: setas e Enter (`pausa.gd:316-324`); Esc abre e fecha a pausa (`pausa.gd:314, 329-334`); na escolha, 1-2-3, Enter, Espaço, E, R rerrolar, B banir (`telas.gd:5-6, 783-844`);
  - controle: stick e setas mudam a seleção, A confirma, B volta, Start abre a pausa (`pausa.gd:312-334`; `altar.gd:25`);
  - mouse: passar o cursor seleciona, roda rola, clique aciona ao soltar (`pausa.gd:291-303`; `telas.gd:741`).
- **Barras do HUD**: PNG de 3 px com degradê (`gerar_molduras.py:102-108, 161-168`). Vida pisca abaixo de 25% (`hud.gd:238`, `v2/LEIA-ME.md:31`). XP acende no pico (`hud.gd:20, 215`). **Barras do SUA BUILD**: borda de 1 px `#0a0814`, fundo `#29263d`, faixa de 2 px no topo mais clara (`status.gd:897-898, 1030-1036`).
- **Pips** (`status.gd:1040-1050`): quadradinhos de 8 px com 3 px de espaço; fração vira pip parcial. Nível usa pips de 5 px; evoluído ganha estrela dourada (`status.gd:1141, 1156`).
- **Ícones 8x8** (`status.gd:899-915`): `#` cor, `o` brilho (cor clareada 55%), `.` vazio. Desenhados por código a 2x (16 px) por `_icone8` (`status.gd:1013-1022`). Cartas usam o ícone 16x16 da v1 em 2x (`v2/LEIA-ME.md:41`).
- **Avisos** (`hud_anuncios.gd`): uma faixa no centro alto, fila de até 5, moldura `moldura_faixa.png` tingida por tipo (`hud.gd:32-34, 293-294`). Não há balão de fala; os avisos de ataque no chão (`avisos.gd`) são do mundo.

## 5. Comportamento

- **Esc e Start** abrem e fecham a pausa; dentro de Ajustes voltam um nível. Esc nunca fecha o jogo; Sair pede confirmação (`pausa.gd:3-4, 251-252, 314, 329-334`). No santuário, Esc abre direto a confirmação de sair (`pausa.gd:217-223`). Não abre na câmera lenta da morte e da vitória nem no resultado (`v2/LEIA-ME.md:26`).
- **Trava das cartas**: 3 s em tempo real (`dados/v2_cartas.json:10`, `espera_s`); 0,8 s após rerrolar ou banir (`rerrolar_espera_s`); baú 1,5 s (`dados/v2_cartas.json:304`, `telas.gd:461`). Clique, tecla e botão são descartados, e a contagem pulsa. Esc passa para a pausa. A trava congela com a pausa aberta (`telas.gd:7-9`). Cartas apagadas usam `#737373` (`telas.gd:27, 665`).
- **Foco inicial**: a pausa abre em "Continuar" (`pausa.gd:245` põe "Não" nas confirmações); o santuário, em ENTRAR (`altar.gd:77`); a escolha, na carta 1 (`telas.gd:35`).
- **Sons de UI**: fora da partida, a pausa usa `Som.ui("cursor")` (-6 dB) e `Som.ui("confirmar")` (-4 dB) (`scripts/hordas/som.gd:68-73`). Na partida, usa os sons de jogo `carta` e `escolher` (`pausa.gd:572-583`). Não existem `ui_cursor` nem `ui_confirmar`.
- **TAB** troca a página do SUA BUILD na pausa (`pausa.gd:287-290`) e o detalhe no painel central (`status.gd:136-137`). **C** liga e desliga o card (`status.gd:141`).

## 6. Regras de conteúdo

- Nada com direitos autorais: arte e fonte de terceiros precisam de licença livre e de registro em `docs/LICENCAS_ARTE.md` e nos Créditos (`CLAUDE.md:43-47`).
- `docs/visual_2_5d/hud_menus.md` é a direção da V1 ("Não implementar agora", linha 97). Não é especificação da v2, que usa Jersey e Spleen (`v2/LEIA-ME.md:39`).
- A paleta de arte é `docs/visual_2_5d/paleta.json`. Nenhum código a lê (seção 8).

## 7. Testes de UI

Comando: `godot --path jogos/hordas/projeto res://testes/<nome>.tscn`. A maioria imprime `<nome> falhas=0` quando passa.

| Teste | Confere |
|---|---|
| `v2_fontes` | fontes do Dados, grade, dígitos, caixas (`v2/LEIA-ME.md:53`) |
| `v2_pausa` | 4 itens, Esc e Start, Ajustes, Sair com confirmação (`:51`) |
| `v2_esc` | Esc em todos os estados, pela entrada da janela (`:55`) |
| `v2_cartas_espera` | trava de 3 s, 0,8 s e clique segurado (`:57`) |
| `v2_status` | cada número do SUA BUILD, nos três modos (`:61`, ~35 s) |
| `v2_hud` | barras, combo, nível, chefe, vinheta, anúncios (cabeçalho de `testes/v2_hud.gd`) |
| `v2_partida` | cartas, raridade, baú, resultado (`:51`) |
| `v2_meta` | santuário e meta-progressão (`:51`) |
| `v2_musica` | música de cada tela (`:59`) |

Mexeu em cor ou fonte: rode `v2_fontes` e `v2_status`. Mexeu em estado de tela: rode `v2_esc` e `v2_pausa`.

## 8. Dívidas de cor e fonte

1. SUA BUILD em Spleen 12 px, fora da grade (`status.gd:32`; pendência em `status.gd:7-10`). `v2_fontes` confere só telas e pausa (`testes/v2_fontes.gd:99-101`).
2. Nome longo de carta em Jersey 28 px, fora da grade e sem teste (`telas.gd:24`).
3. Comentário errado: `telas.gd:248` diz "ouro da fusão", mas a cor é magenta (`telas.gd:17`).
4. Lendário em dois sentidos: raridade ouro `#ffbd33` (`dados/v2_cartas.json:7`) e fusão magenta. O crítico também é `#ffbd33` (`combate.gd:24`).
5. XP e fôlego com cores trocadas entre HUD (`gerar_molduras.py:33, 36`) e SUA BUILD (`status.gd:895-896`).
6. Vida: `#b9212d` no HUD e `#db3840` no card (`gerar_molduras.py:30`; `status.gd:894`).
7. `docs/visual_2_5d/paleta.json` diz vida `#b9212d`, ouro `#e0bc48`, almas `#d06df2`. O código usa outros valores (seção 2).
8. Dois tipos de painel: cartões sem moldura de pedra (`telas.gd:122-132`).
9. Enquadramento: santuário com faixas pretas, partida cortada (seção 1).
10. O comentário de `gerar_molduras.py:27` diz `#86898f`, mas o valor é `#7d8690`.

## 9. Antes de mexer em menu

1. Confira a seção 2 antes de criar cor. Se criar, registre aqui.
2. Texto novo: fonte pela seção 3, tamanho na grade.
3. Confira a área segura (seção 1) em 16:9 e em 4:3.
4. Rode os testes da seção 7.
5. Atualize este arquivo no mesmo PR se mudar cor, fonte ou comportamento.
