# DESIGN da UI da v2

Guia visual dos menus e da interface da v2 (`jogos/hordas/projeto/v2/`). Leia antes de mexer em menu, HUD, cartas ou santuário. As cores e os tamanhos de fonte vêm de `v2/paleta.gd`; as referências de código abaixo localizam seus usos. Se o código mudar, atualize este arquivo no mesmo PR.

**Regras de ouro**
- Tudo cabe em 960x540, e o essencial fica dentro da área segura (seção 1).
- Texto corrido só em Spleen 16 px. Títulos só em Jersey 19, 37 ou 56. Números em Press Start 2P (seção 3).
- Use as cores da seção 2 antes de criar uma. Cor nova entra em `v2/paleta.gd` e na tabela.
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

A fonte única da UI é `v2/paleta.gd`, com constantes GDScript. HUD, SUA BUILD, pausa, cartas, resultado, menu e Santuário usam as constantes por papel; o gerador Python `hud/gerar_molduras.py` lê esse mesmo arquivo para gerar as texturas. Transparência e animação podem variar sem criar outra cor semântica. Luz e sombra da textura de pedra/metal são materiais, não cores de estado.

| Papel | Constante | Cor |
|---|---|---|
| Vida | VIDA | `#b9212d` |
| XP | XP | `#e0bc48` |
| Fôlego | FOLEGO | `#4aa3d9` |
| Dano recente do chefe | FANTASMA_CHEFE | `#ecceb0` |
| Destaque, título e ouro da UI | OURO | `#ffdb6b` |
| Almas | ALMA | `#cca8ff` |
| Perigo | PERIGO | `#ff544d` |
| Fusão | FUSAO | `#ff73d9` (magenta) |
| Texto / secundário / apagado | TEXTO / TEXTO_SECUNDARIO / TEXTO_APAGADO | `#ebe6f5` / `#b8b3d4` / `#8c8fa3` |
| Painel / cartão / selecionado | PAINEL / CARTAO / CARTAO_SELECIONADO | `#01030b` / `#12111a` / `#211f2b` |
| Raridades | RARIDADES | comum `#ccd1db`, raro `#59a8ff`, épico `#bd66ff`, lendário `#ffbd33` |

XP dourado e ouro de seleção são papéis distintos. Fusão magenta continua distinta de raridade lendária. Não alterar os dados de sorteio para mudar apenas a cor da UI. Novas cores de estado entram na fonte única antes do uso. `docs/visual_2_5d/paleta.json` aponta para ela e preserva somente estudos de arte de elementos/dano.

## 3. Tipografia

| Fonte (`scripts/hordas/dados.gd`) | Uso | Tamanhos (onde) |
|---|---|---|
| Jersey 10 (`fonte_titulo`) | títulos, nomes, botões grandes | `Paleta.TITULO_GRANDE` (56), `TITULO_MEDIO` (37) e `TITULO_PEQUENO` (19); logo do menu: 2 × `TITULO_GRANDE` (112) |
| Spleen 8x16 (`fonte_texto`) | texto corrido, valores, ajuda | `Paleta.TEXTO_TAMANHO` (16) ou `TEXTO_GRANDE` (32) |
| Press Start 2P (`fonte` e tema padrão) | números, HUD, lista do santuário e habilidades | `Paleta.NUMERO_PEQUENO` (8) ou `NUMERO_GRANDE` (16); rótulos e teclas de `hud_habilidades.gd`: 8 |

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
- **Molduras do HUD (arte do Codex, #290)**: três 9-slice de pedra e ferro em `v2/hud/` (`moldura_retrato.png` borda de 6 px e margem 17; `moldura_barra.png` e `moldura_habilidade.png` borda de 4 px e margem 11; margens também em `molduras_codex.json`), geradas por `gerar_objetos.py hud` a partir de `fonte_arte/hud_molduras/`, centro transparente e desenhadas POR CIMA do conteúdo. Retrato: quadro parado do herói da partida (32x44) sobre `PAINEL`, no canto superior esquerdo (6,6, 44x56). Vida e fôlego dividem uma só moldura (54,6, 150x30): vida 14 px de altura, fôlego 6 px, as cores de `Paleta.VIDA` e `Paleta.FOLEGO` vêm das barras e não da pedra. Slots E e Q (`hud_habilidades.gd`): moldura de pedra em volta do card de 86x74, em 9-slice por `RenderingServer.canvas_item_add_nine_patch`; desabilitado = a mesma moldura a 0,75 de alfa; o estado (pronto, recarga, negado, perfeito) continua no quadro de 1 px do ícone e nas cores da paleta, nunca na pedra. O selo da tecla (E, Q) fica sobre a borda de baixo. Texto continua Press Start 2P em 8 px. Moldura da faixa de XP, do tempo, dos abates e do chefe segue `moldura_pedra.png`.
- **Barras do HUD**: PNG de 3 px com degradê (`gerar_molduras.py:102-108, 161-168`). Vida pisca abaixo de 25% (`hud.gd:238`, `v2/LEIA-ME.md:31`). XP acende no pico (`hud.gd:20, 215`). **Barras do SUA BUILD**: borda de 1 px `#0a0814`, fundo `#29263d`, faixa de 2 px no topo mais clara (`status.gd:897-898, 1030-1036`).
- **Pips** (`status.gd:1040-1050`): quadradinhos de 8 px com 3 px de espaço; fração vira pip parcial. Nível usa pips de 5 px; evoluído ganha estrela dourada (`status.gd:1141, 1156`).
- **Ícones 8x8** (`status.gd:899-915`): `#` cor, `o` brilho (cor clareada 55%), `.` vazio. Desenhados por código a 2x (16 px) por `_icone8` (`status.gd:1013-1022`). Cartas usam o ícone próprio do ID (`assets/v2/icones_cartas`): 32x32 na escolha, no baú e nos slots da HUD; 16x16 na linha do SUA BUILD (`v2/LEIA-ME.md`).
- **Avisos** (`hud_anuncios.gd`): uma faixa no centro alto, fila de até 5, moldura `moldura_faixa.png` tingida por tipo (`hud.gd:32-34, 293-294`). Não há balão de fala; os avisos de ataque no chão (`avisos.gd`) são do mundo.
- **Cartão da FUSÃO** (`hud.gd`, `_montar_fusao`): 600 x 200, moldura `assets/v2/fusoes/moldura.png` em 9-slice (`NinePatchRect`, borda de 12 px; o miolo estica e é liso). Um halo 48 x 48 de cada lado do título, tingido pela cor da evolução (campo `cor` em `dados/v2_cartas.json`), com o ícone de junção 16 x 16 mostrado em 2x (`fusoes/icone.png`). O texto corrido tem 28 px de recuo, dentro da borda. No SUA BUILD, a linha de peça já fundida (nível "evoluída", `status.gd`, `_fundida`) leva o mesmo ícone depois do nível. A onda da Ventania é `assets/v2/fusoes/ventania.png` (64 x 32), entregue por `v2/armas_novas.gd`; o halo das lâminas evoluídas (`v2/armas.gd`) é `fusoes/halo.png`.

## 5. Comportamento

- **Esc e Start** abrem e fecham a pausa; dentro de Ajustes voltam um nível. Esc nunca fecha o jogo; Sair pede confirmação (`pausa.gd:3-4, 251-252, 314, 329-334`). No santuário, Esc abre direto a confirmação de sair (`pausa.gd:217-223`). Não abre na câmera lenta da morte e da vitória nem no resultado (`v2/LEIA-ME.md:26`).
- **Trava das cartas**: 3 s em tempo real (`dados/v2_cartas.json:10`, `espera_s`); 0,8 s após rerrolar ou banir (`rerrolar_espera_s`); baú 1,5 s (`dados/v2_cartas.json:304`, `telas.gd:461`). Clique, tecla e botão são descartados, e a contagem pulsa. Esc passa para a pausa. A trava congela com a pausa aberta (`telas.gd:7-9`). Cartas apagadas usam `#737373` (`telas.gd:27, 665`).
- **Foco inicial**: a pausa abre em "Continuar" (`pausa.gd:245` põe "Não" nas confirmações); o santuário, em ENTRAR (`altar.gd:77`); a escolha, na carta 1 (`telas.gd:35`).
- **Sons de UI**: fora da partida, a pausa usa `Som.ui("cursor")` (-6 dB) e `Som.ui("confirmar")` (-4 dB) (`scripts/hordas/som.gd:68-73`). Na partida, usa os sons de jogo `carta` e `escolher` (`pausa.gd:572-583`). Não existem `ui_cursor` nem `ui_confirmar`.
- **TAB** alterna visual/detalhes do SUA BUILD na pausa e no painel central. **Q/E** mudam as páginas de conteúdo em ambos os layouts. No HUD compacto, **PgUp/PgDn** ou a roda sobre uma coluna mudam a página; a roda fora do card segue livre. **C** liga/desliga o card. A tabela de detalhes quebra rótulos, valores e bônus em linhas e preserva dicas completas; cada coluna informa sua página atual/total. Teclado é necessário para Tab/Q/E; equivalência no controle permanece uma tarefa separada (#257).

## 6. Regras de conteúdo

- Nada com direitos autorais: arte e fonte de terceiros precisam de licença livre e de registro em `docs/LICENCAS_ARTE.md` e nos Créditos (`CLAUDE.md:43-47`).
- `docs/visual_2_5d/hud_menus.md` é a direção da V1 ("Não implementar agora", linha 97). Não é especificação da v2, que usa Jersey e Spleen (`v2/LEIA-ME.md:39`).
- O estudo de paleta de arte está em `docs/visual_2_5d/paleta.json`; a UI tem fonte única em `v2/paleta.gd`, também lida pelo gerador de molduras.

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
| `v2_fusoes` | arte da fusão: tamanhos (600 x 200, 48, 16, 64 x 32), borda de 12 px e a Ventania no registro de armas |

Mexeu em cor ou fonte: rode `v2_fontes` e `v2_status`. Mexeu em estado de tela: rode `v2_esc` e `v2_pausa`.

## 8. Validação de cor e fonte

O PR de paleta unifica vida/XP/fôlego, ouro/almas e cores de tela. Spleen deve usar 16 ou 32 px; Jersey, 19, 37 ou 56 px; o logo de 112 px equivale a 2 × 56. Press Start 2P usa 8 ou 16 px, inclusive nos rótulos compactos das habilidades. Os tamanhos vêm das constantes de `v2/paleta.gd`. O teste `v2_fontes` verifica a grade, incluindo os tamanhos adaptativos dos nomes e o card SUA BUILD. Aumentar fonte exige medir novamente largura e altura, sem esconder atributos para fazer o teste passar.

**Regressão do layout:** a fonte de 16 px expôs18 falhas de largura/altura. A tabela agora distribui conteúdo em páginas, sem apagar bônus, atributos ou dicas para caber. `v2_status` mantém a matriz de layouts e adiciona cobertura de todos os IDs/trechos/dicas nas páginas, com 50 golpes e build extrema/Santuário completo; a entrada real confere Q/E, Tab, PgUp/PgDn e roda dentro/fora das colunas, inclusive com janela ampliada. O diagnóstico mede o plano usado no desenho; prints reais do viewport continuam necessários para conferir a composição. Capturas com `--fotos` não executam as assertions da bateria. Integração com main/#245 continua com o Claude do Alisson.

Continuam duas diferenças de composição: cartões usam painel próprio sem moldura de pedra; o Santuário tem faixas pretas e a partida usa corte. Isso não muda neste trabalho de paleta. Os números de dano no mundo e os dados de raridade continuam sob responsabilidade de sistemas; mudar sua origem exige coordenação com o Claude do Alisson.

## 9. Antes de mexer em menu

1. Confira a seção 2 antes de criar cor. Se criar, registre aqui.
2. Texto novo: fonte pela seção 3, tamanho na grade.
3. Confira a área segura (seção 1) em 16:9 e em 4:3.
4. Rode os testes da seção 7.
5. Atualize este arquivo no mesmo PR se mudar cor, fonte ou comportamento.
