# DESIGN da UI da v2

Guia visual dos menus e da interface da v2 (`jogos/hordas/projeto/v2/`). Leia antes de mexer em menu, HUD, cartas ou santuário. As cores e os tamanhos de fonte vêm de `v2/paleta.gd`; as referências de código abaixo localizam seus usos. Se o código mudar, atualize este arquivo no mesmo PR.

**Regras de ouro**
- Todo layout é desenhado no bloco de 960x540 e ancorado ao bloco ou ao canvas da UI (seção 1); nada de posição em px de janela nem de fundo com tamanho fixo.
- Texto corrido só em Spleen 16 px. Títulos só em Jersey 19, 37 ou 56. Números em Press Start 2P (seção 3).
- Use as cores da seção 2 antes de criar uma. Cor nova entra em `v2/paleta.gd` e na tabela.
- Pouco texto: barra, pip, ícone e número grande antes de palavra.
- Antes de subir, rode os testes da seção 7.

## 1. Resolução, escala e área segura

Toda a UI é desenhada num **bloco de 960x540** ("UI px"). O que muda com a janela é o **fator** (px de janela por UI px) e o **canvas** da UI (janela / fator), que fica maior que o bloco quando o fator é menor que o de encaixe. É o "GUI Scale" do Minecraft: opção em Ajustes > Gráficos, **Tamanho da interface: Automático / Pequeno / Médio / Grande** (`Config` chave `tamanho_ui`, padrão Automático; conta pura em `v2/escala_ui.gd`).

| Onde | Desenho | Escala |
|---|---|---|
| Partida: HUD, minimapa, pausa, SUA BUILD, escolha, baú, resultado | SubViewport próprio da UI (`mundo.ui`), transparente, do tamanho do canvas (`apresentacao.gd`) | por cima do mundo, com o mesmo sharp bilinear (blend pré-multiplicado); o mundo continua 960x540 em `KEEP_ASPECT_COVERED` |
| Título, santuário, escolha de personagem | direto na janela (`ui_janela.gd`) | `CANVAS_ITEMS`, base 960x540, aspecto `EXPAND` (sem faixas), `content_scale_factor = fator / encaixe` |
| Salão (`salao.gd`) | cena de 960x540 (a sala e o personagem), não UI | `UiJanela` fixa em "grande" (aspecto `EXPAND`): não segue o tamanho da interface. A sala é desenhada pelo `salao_vivo.gd` nas CanvasLayers -2 (cena) e -1 (brilho), **abaixo** da camada padrão onde ficam barras e painel; o chão escuro das sobras fora de 16:9 fica na camada -3. Nada opaco do tamanho da tela pode ir na camada padrão (tapa a sala: foi o "santuário vazio" do #320). As três camadas seguem o bloco (`offset = desloc`, `salao.ui_reencaixar`). No painel de estruturas o saldo ("ALMAS N") fica no cabeçalho, ao lado do VOLTAR, e o COMPRAR desligado não tem fundo, fica apagado, não pega foco e diz o motivo (SEM ALMAS, BLOQUEADA, NO MÁXIMO). O painel (ESTÁTUAS, ALTAR, CÓDICE) é: ícone da estrutura (`Icones.textura(id)` a 48 px, 2x da arte de 24 px; nunca a arte da sala) + título, ALMAS no cabeçalho; à esquerda a lista (ícone de 32 px por item, `assets/v2/icones_santuario/<id>.png`, via `v2/icones_santuario.gd`); à direita ícone do item (48 px, 2x) + nome, UMA frase de uma linha (campo `frase` de cada melhoria e de cada conquista em `dados/v2_meta.json`) e o card de barrinhas (`v2/card_santuario.gd`: NÍVEL em segmentos, EFEITO agora -> próximo, CUSTO x saldo; no códice, CÓDICE, META e RECOMPENSA com ícone). Sem bloco de texto solto e sem botão DETALHES. O herói anda no santuário a 208 px/s (1,6x da primeira sala) |

- **Fator**: cada opção é um canvas-alvo, e o fator é o maior passo (mínimo 1) que ainda deixa o canvas com pelo menos esse tamanho, limitado ao encaixe do bloco (`min(w/960, h/540)`): nunca corta nada. Pequeno = 1600x900, Médio = 1280x720 e Grande = 960x540 andam em passos de 0,5. O **Automático é o do Minecraft: o maior tamanho que cabe** (alvo 960x540) em passos de 0,25, então acompanha a janela de perto e, de 1280x720 para cima, é sempre maior que o Médio; coincide com o Grande onde o passo de 0,5 já encaixa (1920x1080, 3840x2160). O salão ignora a opção e fica sempre encaixado em "grande" (a sala 960x540 é cena, não menu).

| Janela | Automático | Pequeno | Médio | Grande |
|---|---|---|---|---|
| 1280x720 | 1,25 (canvas 1024x576) | 1 | 1 | 1 |
| 1920x1080 | 2 (960x540) | 1 (1920x1080) | 1,5 (1280x720) | 2 (960x540) |
| 2560x1440 | 2,5 (1024x576) | 1,5 | 2 | 2,5 |
| 3840x2160 | 4 (960x540) | 2 | 3 | 4 |

- **O bloco fica no centro do canvas** (deslocamento `EscalaUi.desloc_atual`, em px inteiros). Telas modais (cartas, baú, resultado, pausa, Ajustes, SUA BUILD, título, santuário, personagens) mantêm as coordenadas do bloco: a CanvasLayer da UI tem `offset = desloc`. O que é de borda **gruda no canvas**: HUD (`hud.gd`, tabela `ANCORAS`: retrato e barras no canto de cima à esquerda, relógio, abates, combo e chefe no topo, XP e slots E/Q embaixo), minimapa (canto de cima à direita), contador de fps (canto de baixo à esquerda) e a faixa de dica do título.
- **Fundo, escurecedor e vinheta cobrem o canvas, não o bloco**: `EscalaUi.cobrir(controle)` (e o grupo `ui_cobrir`, refeito a cada mudança). Nunca dimensione um fundo com `Vector2(LARG, ALT)`.
- Nó que precisa refazer o layout quando a janela ou a opção mudam entra no grupo `ui_escala` e implementa `ui_reencaixar(canvas, desloc)` (o `Config.tamanho_ui_mudou` e o `size_changed` da janela disparam).
- **Mouse**: o SubViewport da UI não recebe a entrada da janela (como o do mundo): pausa, cartas e SUA BUILD leem `mundo.ap.mouse_ui()` / `pos_ui()`, que devolvem coordenadas do bloco (negativas ou acima de 960x540 nas margens). A mira no mundo segue `mouse_na_tela()` (corte do mundo).
- `project.godot` declara 640x360 e stretch viewport, mas a v2 troca o modo em tempo de execução (`apresentacao.gd`, `ui_janela.gd`).
- Testes: `EscalaUi.janela_forcada` troca o tamanho da janela; em headless a janela vale 960x540 (fator 1, deslocamento zero), então os testes antigos não mudam.
- Corte do mundo (só ele): escala = `max(janela_w/960, janela_h/540)`; a área segura do mundo na tabela abaixo vale para o que é desenhado NO mundo. A UI não precisa dela: o HUD gruda no canvas, que é a janela inteira.

| Janela | Corte do mundo | Área segura no mundo |
|---|---|---|
| 16:9 (1280x720) | nenhum | x 0-960, y 0-540 |
| 16:10 (1280x800) | ~48 px em x | x 48-912 |
| 4:3 (1024x768) | ~120 px em x | x 120-840 |
| 21:9 (2560x1080) | ~68 px em y | y 68-472 |

## 1b. Grade dos menus (960x540, o bloco de canvas)

Regra provisória: até aqui o DESIGN não tinha valores para margens, colunas e rodapé. Os números abaixo são os que o código usa desde esta mudança (padrão adotado nesta entrega; a confirmar com o Alisson).

- **Margem lateral de 36 px**: o conteúdo de tela inteira (santuário, personagens) vai de x 36 a x 924. Painel centrado (pausa, cartas) segue o próprio eixo.
- **Colunas**: quando duas colunas dividem a tela, a da direita começa 24 px depois da esquerda e as bordas direitas coincidem. No santuário, MELHORIAS/MAPA/detalhes ficam em 36 a 608, CONQUISTAS, a caixa ALMAS e o VOLTAR terminam em 924.
- **Eixo da ficha** (personagens): retrato, nome e linhas de atributo são centrados no mesmo eixo, x 682 (centro do painel de pedra de x 440 a 924). A lista (x 36-416) rola dentro de y 100-490 e o foco puxa a rolagem; o foco é uma borda ouro de 2 px por dentro do botão (a rolagem corta o que sai da caixa). O retrato é um quadro só (primeiro quadro de `rosto.png`, que é uma tira), em escala inteira: o rosto em 2x e o herói parado em 3x (96x132). A ficha vai de y 105 a 485, dentro da pedra: nome (61), retrato (132), duas linhas de 32 px (70) e o detalhe de até 6 linhas de 16 px (114). O aviso de erro fica entre o título e a ficha (y 80 a 100).
- **Texto de ajuda e de crédito** (Ajustes, Créditos, Gráficos): começa na coluna do texto das linhas (margem 24 do painel + 10 da linha, x 34 do painel).
- **Rodapé de teclas** (`Glifos.dica`): caixa de 22 px com o glifo de 16 px centrado; a caixa termina 8 px acima da borda inferior do bloco (y 510 a 532). Os controles da tela terminam pelo menos 12 px acima dela (santuário: botões até y 498).
- **Linha de base**: o texto e o glifo de uma mesma linha compartilham a linha de base (`Dica` e `Glifos.desenhar_acao` usam a métrica da fonte do texto).
- **Título de tela**: o alinhamento vertical segue cada tela (santuário e personagens ainda usam posições próprias; padronizar só com decisão do Alisson).

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

**Vermelho é só perigo para o jogador.** `PERIGO` marca o que machuca o herói: o dano que ele leva (número `COR_DANO_HEROI` e faíscas em `combate.gd`, vinheta `VERMELHO_VINHETA`), a derrota, a barra de vida do inimigo e o aviso do que vai atingi-lo (o Explosivo em `dados/v2_cartas.json`, o anúncio de FÚRIA do chefe). A barra de vida do herói (`VIDA`) segue vermelha, porque é o que o jogador perde. Efeito, arma, aliado e andante do herói não usam vermelho: fogo e armas do herói saem em dourado (`OURO`, `#ffdb6b`) ou âmbar, o anel do Grito de Guerra e os Fogos de Festival em ciano (`#80f2ff`), névoa e bandeiras em verde-menta (`#8cf29e`, `BONUS`), o Golem em ocre e o Dragãozinho em verde. Laranja e âmbar contam como fogo, não como vermelho. As cores de efeito de cada arma e aliado ficam em `cor` dos `golpes` e das `evolucoes` de `dados/v2_cartas.json`, que é o que o jogo lê (os `dados/v2_armas/lote_*.json` são só registro, com os mesmos valores), e as de fichas do andante em `v2/andante.gd`. Os PNGs dos aliados que tinham vermelho foram recoloridos no próprio arquivo, trocando só o matiz e mantendo saturação e brilho (script de uma linha: matiz de 330 a 35 graus vai para 120 graus no Dragãozinho e para 40 graus no Golem): `assets/v2/armas/dragao_filhote_dir.png` e `assets/v2/armas/golem_barro_dir.png`. Se a arte for gerada de novo (`fonte_arte/blender_golem/gerar_golem.py`), a troca de matiz tem de ser refeita. `testes/v2_cores_perigo.gd` confere que nenhuma dessas cores cai na faixa de vermelho (matiz de 0 a 16 graus, saturado e claro), que nenhum pixel visível dos dois PNGs cai em vermelho ou terracota (até 30 graus), que Dragãozinho e Lobo Espiritual têm tons diferentes e que o aviso do Explosivo cai na faixa de vermelho. Trocas do lote cores-perigo: Fogo do Céu, Pedras Vulcânicas e nó da Cabaça em dourado; Juízo Final em dourado âmbar; Cortina de Sangue em verde-menta; Golem de Barro em ocre com poeira dourada; Dragãozinho em verde; Fogos de Festival em ciano; bandeiras da Sentinela em verde; olho do Corvo em dourado; Dragão de Brasa com mistura dourada; sopro de fogo terminando em âmbar. O título da seção HERÓI do Status (`SECAO_HEROI`, salmão claro) é cabeçalho, não aviso, e fica.

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
- **Botões da escolha** (`telas.gd`, `_botao`, `BTN_L`): três painéis de 200x28 com 14 px entre eles, texto de 16 px: Rerrolar, **Automático** (no centro exato da tela, borda de ouro, tecla Q, Y no controle) e Banir. Abaixo, a linha de 16 px que explica o Automático. Sem foco; alfa 0,4 quando não pode (ou na trava). O Automático (`cartas.escolha_automatica`) completa fusão, sobe golpe que já tem e cobre o que falta, mas com a raridade rebaixada (teto rara: `auto_raridade_max`, `auto_queda` em `dados/v2_cartas.json`). Controle na escolha: A escolhe, X rerrola, Y automático, LB bane.
- **Lista da pausa** (`pausa.gd:34, 510-516, 136-140, 534`): 5 linhas visíveis, rolagem acompanha a seleção. Linha selecionada: ouro a 0,14, borda ouro 2 px, rótulo ouro. Cabeçalho não é selecionável.
- **Entrada da lista e da escolha:**
  - teclado: setas e Enter (`pausa.gd:316-324`); Esc abre e fecha a pausa (`pausa.gd:314, 329-334`); na escolha, 1-2-3, Enter, Espaço, E, R rerrolar, Q automático, B banir (`telas.gd:5-7, 771-861`);
  - controle: stick e setas mudam a seleção, A confirma, B volta, Start abre a pausa (`pausa.gd:312-334`; `altar.gd:25`);
  - mouse: passar o cursor seleciona, roda rola, clique aciona ao soltar (`pausa.gd:291-303`; `telas.gd:741`).
- **Molduras do HUD (arte do Codex, #290)**: três 9-slice de pedra e ferro em `v2/hud/` (`moldura_retrato.png` borda de 6 px e margem 17; `moldura_barra.png` e `moldura_habilidade.png` borda de 4 px e margem 11; margens também em `molduras_codex.json`), geradas por `gerar_objetos.py hud` a partir de `fonte_arte/hud_molduras/`, centro transparente e desenhadas POR CIMA do conteúdo. Retrato: quadro parado do herói da partida (32x44) sobre `PAINEL`, no canto superior esquerdo (6,6, 44x56). Vida e fôlego dividem uma só moldura (54,6, 150x30 no máximo de partida; ela cresce com a barra mais comprida, ver "Comprimento das barras" abaixo): vida 14 px de altura, fôlego 6 px, as cores de `Paleta.VIDA` e `Paleta.FOLEGO` vêm das barras e não da pedra. Slots E e Q (`hud_habilidades.gd`): moldura de pedra em volta do card de 86x74, em 9-slice por `RenderingServer.canvas_item_add_nine_patch`; desabilitado = a mesma moldura a 0,75 de alfa; o estado (pronto, recarga, negado, perfeito) continua no quadro de 1 px do ícone e nas cores da paleta, nunca na pedra. O selo da tecla (E, Q) fica sobre a borda de baixo. Texto continua Press Start 2P em 8 px. Moldura da faixa de XP, do tempo, dos abates e do chefe segue `moldura_pedra.png`.
- **Placa do NÍVEL DO MAPA** (`hud_nivel.gd`, nó `Raiz/Nivel`, montada por `hud.gd`): moldura de pedra igual à do relógio (9-slice, borda de 5 px) em x 312 a 424, y 38 a 64, abaixo das barras expansíveis e à esquerda dos abates (x 428 a 532). Texto "NÍVEL 7/30" centrado (fonte do tema, 8 px, contorno preto) e embaixo a barra do mapa inteiro, do nível 1 ao último (ouro de `XP`, brilho `VALOR`). Uma marca por nível de chefe: losango laranja (`CARGA_LARANJA`) = mini-chefe, caveira 5x5 vermelha (`PERIGO`) = chefão, no fim da barra; as já vencidas apagam. Com o chefe do nível em campo o nível está TRAVADO: o texto fica vermelho e a ponta da barra pisca. Só aparece se o mundo tem `combate.diretor` com os níveis (`dados/v2_niveis.json`). Foto real: `testes/v2_hud.tscn -- --fotos=PASTA`.
- **Faixa de GOLPES do HUD** (`hud_golpes.gd`, nó `Raiz/Golpes`): um quadradinho pequeno por golpe automático ganho (lê `combate.armas.ativas`), ancorado no canto inferior esquerdo da Raiz do HUD (margem de 6 px; sem coordenada absoluta de tela, para seguir o HUD se ele mudar de viewport), 8 por linha e até 24 (o excedente vira "+N"), antes do selo de nível. Caixa de 26 px (cerca de 70% da primeira versão) com o ícone da carta reduzido de 32 para 24 (filtro linear) e moldura de 1 px na cor do golpe (dourada na peça fundida), fundo `PAINEL` a 0,88 e 5 pips de nível de 4x3 px logo abaixo (evoluída: pips dourados cheios). Só três leituras: ícone, pips e UMA linha fina de recarga de 2 px no pé do ícone, visível só enquanto recarrega (corvos, raio, runa, projétil, nuvem, anel, meteoro e aliado; lâmina e aura não têm). Não há barra de fusão: quando falta só UM nível para fundir uma receita, um losango magenta (`FUSAO`) pisca no canto do ícone. Parada, a faixa fica translúcida (`modulate.a` 0,72); ao ganhar golpe, subir nível ou fundir ela fica opaca por 1,5 s e volta a esmaecer. Golpe novo: pop curto 0,6 a 1,10 a 1,0, anel e 6 faíscas que ficam na folga de 3 px entre as caixas; nível novo: pulso de 7% em que o ícone CLAREIA (multiplicador acima de 1, nunca escurece), 4 faíscas e o pip novo pisca; fusão: o mesmo em `FUSAO`. Quem anima é desenhado por último, por cima dos vizinhos. Só lê o combate a 20 Hz e só redesenha quando a chave muda ou há animação (a translucidez é o `modulate` e não redesenha). Esconde-se com o card da build aberto (C, coluna da esquerda) e no menu principal da pausa (o card aparece ao lado); em Ajustes e Sair ela fica desenhada sob o fundo escuro, parada. Escondida, a animação em curso espera. Receita com peça já consumida por outra fusão não conta. Cores só da paleta; sem texto (pip e ícone antes de palavra). Foto real: `--roteiro=hud_golpes` (v2/roteiro.gd).
- **Comprimento das barras de vida e fôlego** (`hud.gd`, `_barras`, constantes `BARRA_*`): o alvo segue o máximo atual do herói, não o atual. No máximo de partida (`cfg.heroi.vida` e `cfg.folego.max` do combate; sem combate, 100 e 3) a barra mede 142 px; cada ponto de vida máxima acima da base soma 1,2 px e cada carga de fôlego, 47 px (o bônus do meta entra por cima da base, em `meta.gd`). Piso de 64 px (cabe `999/999` em 8 px) e teto de 320 px, que segura a moldura antes do relógio (x 428). A barra desliza até o alvo (suavização exponencial de 7/s, cola a menos de 0,5 px) e fica parada com a escolha de carta ou o baú na tela, cresce quando a HUD volta. A moldura de pedra é a barra mais comprida + 8 px (4 de cada lado), e o texto da vida tem a largura da barra. O deslocamento do bloco move a caixa e nunca muda o comprimento. Teste `v2_hud_barras`; foto real com `--fotos=PASTA`.
- **Barras do HUD**: PNG de 3 px com degradê (`gerar_molduras.py:102-108, 161-168`). Vida pisca abaixo de 25% (`hud.gd`, `_vida_baixa`, `LIMIAR_VIDA_BAIXA`; `v2/LEIA-ME.md:31`). XP acende no pico (`hud.gd`, `BRILHO_XP`). **Barras do SUA BUILD**: borda de 1 px `#0a0814`, fundo `#29263d`, faixa de 2 px no topo mais clara (`status.gd:897-898, 1030-1036`).
- **Marca de AMIGO nos aliados temporários** (`armas_novas.gd::_marca_amigo`, desenhada por `desenhar_sprites` em andante, golem, torre e aliado simples): um anel verde achatado no chão (raio do corpo; inimigo e perigo são vermelhos, então verde nunca é ameaça) e uma barrinha VERDE pequena (18x3 px, moldura escura de 1 px) sobre a cabeça que esvazia com o tempo de vida que falta (`it.vida / st.duracao`; na torre, descontado o tempo de desmontar). Nos últimos 5 s tudo pisca (alfa 1,0 / 0,35 a 2,5 Hz): vai sumir. `Andante.topo/raio_marca` e `Golem.topo` dão a altura da cabeça e o raio. Todo aliado ou torre dura de 30 a 60 s (`duracao` em `dados/v2_cartas.json`) e a recarga só corre depois que o último da leva sumiu (`a.ate`). Foto real: `v2_sentinela.tscn -- --fotos_aliados=PASTA`.
- **Pips** (`status.gd:1040-1050`): quadradinhos de 8 px com 3 px de espaço; fração vira pip parcial. Nível usa pips de 5 px; evoluído ganha estrela dourada (`status.gd:1141, 1156`).
- **Ícones 8x8** (`status.gd:899-915`): `#` cor, `o` brilho (cor clareada 55%), `.` vazio. Desenhados por código a 2x (16 px) por `_icone8` (`status.gd:1013-1022`). Cartas usam o ícone próprio do ID (`assets/v2/icones_cartas`): 32x32 na escolha, no baú e nos slots da HUD; 16x16 na linha do SUA BUILD (`v2/LEIA-ME.md`).
- **Avisos** (`hud_anuncios.gd`): uma faixa no centro alto, fila de até 5, moldura `moldura_faixa.png` tingida por tipo (`hud.gd:32-34, 293-294`). Não há balão de fala; os avisos de ataque no chão (`avisos.gd`) são do mundo.
- **Cartão da FUSÃO** (`hud.gd`, `_montar_fusao`): 600 x 200, moldura `assets/v2/fusoes/moldura.png` em 9-slice (`NinePatchRect`, borda de 12 px; o miolo estica e é liso). Um halo 48 x 48 de cada lado do título, tingido pela cor da evolução (campo `cor` em `dados/v2_cartas.json`), com o ícone de junção 16 x 16 mostrado em 2x (`fusoes/icone.png`). O texto corrido tem 28 px de recuo, dentro da borda. No SUA BUILD, a linha de peça já fundida (nível "evoluída", `status.gd`, `_fundida`) leva o mesmo ícone depois do nível. A onda da Ventania é `assets/v2/fusoes/ventania.png` (64 x 32), entregue por `v2/armas_novas.gd`; o halo das lâminas evoluídas (`v2/armas.gd`) é `fusoes/halo.png`.
- **Trancados no salão** (`salao_visual.gd`, `salao.gd`; regras em `dados/v2_progressao.json`, lidas por `progressao.gd`): portal ou estrutura trancada aparece com o nome apagado (`TEXTO_APAGADO`), a imagem escurecida e **uma linha com cadeado de pixel (dourado, 2x) e a condição curta** (Spleen 16, "Vença a Floresta", "1 conquista"); a estrutura ganha também um cadeado grande (3x) sobre ela. O prompt e o portal começam com "Trancado" ("Trancado: <condição>"; a estrutura avisa "<Nome> trancado. <condição>"), e Enter ou clique só mostra o aviso completo (caixa `PAINEL`/`BORDA` de 3 s, ajustada ao texto, com o que falta). Hoje só a Floresta e as Estátuas abrem no começo; o Laboratório, a Cidade e as Ruínas abrem em cadeia ao vencer o mapa anterior, o Altar ao vencer a Floresta e o Códice na 1ª conquista. Save de antes das travas, com progresso, fica tudo aberto.
- **Mapa vencido** (`v2/meta.gd`): estado único na conquista `vence_<id>` (`dados/v2_meta.json`, com "mapa"). `mapa_vencido(id, cf)` lê esse estado; `marcar_mapa_vencido(id, cf)` altera a transação do chamador e, sem `cf`, grava direto na vitória do combate. `mapas_vencidos()` deriva a lista das mesmas conquistas. Saves antigos com `[mapas_vencidos]` migram na leitura e gravam só o estado canônico. A vitória guarda `mapa_vencido_agora` no resultado para anunciar a conquista uma vez; portais, Altar e Códice leem esse mesmo progresso. Testes: `v2_meta`, `v2_progressao`, `v2_chefe`.

## 5. Comportamento

- **Esc e Start** abrem e fecham a pausa; dentro de Ajustes voltam um nível. Esc nunca fecha o jogo; Sair pede confirmação (`pausa.gd:3-4, 251-252, 314, 329-334`). No santuário, Esc abre direto a confirmação de sair (`pausa.gd:217-223`). Não abre na câmera lenta da morte e da vitória nem no resultado (`v2/LEIA-ME.md:26`).
- **Cartas (escolha e baú)**: o nome da carta tem UM tamanho só, Jersey 19 (`Telas.TAM_NOME`), para comum, rara, épica e lendária, centrado na caixa entre o ícone e a descrição; nada de tamanho por largura do nome. A linha "Sua build" é uma linha só: o que não cabe em 920 px vira "e mais N" (`_texto_build`).
- **Trava das cartas**: 3 s em tempo real (`dados/v2_cartas.json:10`, `espera_s`); 0,8 s após rerrolar ou banir (`rerrolar_espera_s`); baú 1,5 s (`dados/v2_cartas.json:304`, `telas.gd:461`). Clique, tecla e botão são descartados, e a contagem pulsa. Esc passa para a pausa. A trava congela com a pausa aberta (`telas.gd:7-9`). Cartas apagadas usam `#737373` (`telas.gd:27, 665`).
- **Foco inicial**: a pausa abre em "Continuar" (`pausa.gd:245` põe "Não" nas confirmações); o santuário, em ENTRAR (`altar.gd:77`); a escolha, na carta 1 (`telas.gd:35`).
- **Sons de UI**: fora da partida, a pausa usa `Som.ui("cursor")` (-6 dB) e `Som.ui("confirmar")` (-4 dB) (`scripts/hordas/som.gd:68-73`). Na partida, usa os sons de jogo `carta` e `escolher` (`pausa.gd:572-583`). Não existem `ui_cursor` nem `ui_confirmar`.
- **TAB** alterna visual/detalhes do SUA BUILD na pausa e no painel central. **Q/E** mudam as páginas de conteúdo em ambos os layouts. No HUD compacto, **PgUp/PgDn** ou a roda sobre uma coluna mudam a página; a roda fora do card segue livre. **C** liga/desliga o card. A tabela de detalhes quebra rótulos, valores e bônus em linhas e preserva dicas completas; cada coluna informa sua página atual/total. No controle: **Y** alterna visual/detalhes (o Tab), **LB/RB** mudam a página (Q/E) e **Select** liga o card (C).
- **Glifos de controle** (`v2/glifos.gd`, módulo ÚNICO): o jogo detecta o último dispositivo usado (teclado e mouse, Xbox ou PlayStation, pelo `Input.get_joy_name`; qualquer controle desconhecido cai no layout do Xbox) e troca NA HORA os rótulos de todas as telas para só o botão certo (Esc no teclado, B no Xbox, bola no PlayStation). Nenhuma tela escreve "Esc/B" ou "Enter ou A" no texto: pede o papel (`confirmar`, `voltar`, `rerrolar`, `banir`, `abas`, `detalhes`, `navegar`...) e a tabela `TABELA` do módulo diz o que desenhar. `Glifos.dica(gerador)` devolve a faixa de rodapé (glifo de 16 px + texto Spleen 16, refeita sozinha na troca), `Glifos.glifo(acao)` um glifo só (dentro de botão, como o VOLTAR do salão), `Glifos.texto(acao)` só o texto curto (selo E/Q da HUD, linhas de navegação) e `Glifos.desenhar_acao(ci, acao, pos)` o glifo dentro de um desenho por código (cabeçalho da SUA BUILD: "detalhes" e "fecha"). Baú e resultado usam `Glifos.dica` (glifo + "para continuar" / "para jogar de novo"), nunca um Label com o nome do botão. Fotos antes (origin/main, edaa0f95) e depois desta entrega: `docs/visual_2_5d/controle/` (tela por tela, com o dispositivo no nome). O "Mouse também" some no controle. Para foto ou teste: `-- --controle=xbox|ps|teclado` trava o dispositivo. Controle: A/cruz confirma, B/bola volta, X/quadrado rerrola, Y/triângulo escolhe AUTOMÁTICO e LB/L1 bane na escolha de cartas, Y alterna os detalhes do SUA BUILD e LB/RB mudam a página. Teste: `v2_glifos`.

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
| `v2_glifos` | dispositivo (teclado, Xbox, PS) pelo evento e pelo nome, troca na hora, dica refeita, título sem o mouse no controle |
| `v2_controle_nav` | trava o Xbox no próprio teste: X rerrola, Y escolhe automático e LB bane nas cartas, A fecha o baú, A e B mapeados em personagens e salão (apertos pela janela) |
| `v2_controle_fotos` | ferramenta de foto, com janela: `-- --fotos=PASTA --prefixo=X --controle=xbox\|ps\|teclado` (título, Ajustes, Créditos, santuário, personagens, salão, HUD, pausa, SUA BUILD, cartas, baú, resultado); sem `--fotos` sai com `falhas=0` |
| `v2_esc` | Esc em todos os estados, pela entrada da janela (`:55`) |
| `v2_cartas_espera` | trava de 3 s, 0,8 s e clique segurado (`:57`) |
| `v2_status` | cada número do SUA BUILD, nos três modos (`:61`, ~35 s) |
| `v2_hud_golpes` | faixa de golpes do HUD: aparece ao ganhar, nível sobe e anima, recarga, fusão troca as peças pela evolução, parada não redesenha, 10 golpes sem cruzar o HUD |
| `v2_hud` | barras, combo, nível, chefe, vinheta, anúncios (cabeçalho de `testes/v2_hud.gd`) |
| `v2_hud_barras` | comprimento das barras de vida e fôlego: base do herói, máximo com bônus, deslize, teto, moldura, sem combate e deslocamento do bloco; `--fotos=PASTA` tira o HUD real (cabeçalho de `testes/v2_hud_barras.gd`) |
| `v2_partida` | cartas, raridade, baú, resultado (`:51`) |
| `v2_diretor` | níveis do mapa: sobe a cada `duracao_nivel`, o chefe nasce no nível dele e trava o nível, a barra do mapa, o fim no último nível |
| `v2_chefe` | mini-chefes e o chefão: anúncio, ataques avisados, baú, matar o mini não é vitória, vitória e o mapa vencido no save |
| `v2_meta` | santuário e meta-progressão (`:51`) |
| `v2_progressao` | travas dos portais e estruturas, aviso, cadeado e save antigo (`testes/v2_progressao.gd`; fotos com `-- --prints=<pasta>`) |
| `v2_musica` | música de cada tela (`:59`) |
| `v2_escala_ui` | fator por janela e opção (tabela), canvas, opção em Ajustes que gira e salva, HUD/minimapa/fundos/mouse no canvas, troca ao vivo |
| `v2_fusoes` | arte da fusão: tamanhos (600 x 200, 48, 16, 64 x 32), borda de 12 px e a Ventania no registro de armas |

Mexeu em cor ou fonte: rode `v2_fontes` e `v2_status`. Mexeu em estado de tela: rode `v2_esc` e `v2_pausa`.

## 8. Validação de cor e fonte

O PR de paleta unifica vida/XP/fôlego, ouro/almas e cores de tela. Spleen deve usar 16 ou 32 px; Jersey, 19, 37 ou 56 px; o logo de 112 px equivale a 2 × 56. Press Start 2P usa 8 ou 16 px, inclusive nos rótulos compactos das habilidades. Os tamanhos vêm das constantes de `v2/paleta.gd`. O teste `v2_fontes` verifica a grade, incluindo os tamanhos adaptativos dos nomes e o card SUA BUILD. Aumentar fonte exige medir novamente largura e altura, sem esconder atributos para fazer o teste passar.

**Regressão do layout:** a fonte de 16 px expôs18 falhas de largura/altura. A tabela agora distribui conteúdo em páginas, sem apagar bônus, atributos ou dicas para caber. `v2_status` mantém a matriz de layouts e adiciona cobertura de todos os IDs/trechos/dicas nas páginas, com 50 golpes e build extrema/Santuário completo; a entrada real confere Q/E, Tab, PgUp/PgDn e roda dentro/fora das colunas, inclusive com janela ampliada. O diagnóstico mede o plano usado no desenho; prints reais do viewport continuam necessários para conferir a composição. Capturas com `--fotos` não executam as assertions da bateria. Integração com main/#245 continua com o Claude do Alisson.

Continuam duas diferenças de composição: cartões usam painel próprio sem moldura de pedra; o Santuário tem faixas pretas e a partida usa corte. Isso não muda neste trabalho de paleta. Os números de dano no mundo e os dados de raridade continuam sob responsabilidade de sistemas; mudar sua origem exige coordenação com o Claude do Alisson.

## 9. Antes de mexer em menu

1. Confira a seção 2 antes de criar cor. Se criar, registre aqui.
2. Texto novo: fonte pela seção 3, tamanho na grade.
3. Confira a seção 1: o que é de borda grudado no canvas, fundos com `EscalaUi.cobrir`, e olhe o resultado em 1280x720 e 1920x1080 (Automático e Pequeno; `--tamanho_ui=` nas fotos).
4. Rode os testes da seção 7.
5. Atualize este arquivo no mesmo PR se mudar cor, fonte ou comportamento.

## Ajustes > Gráficos (perfil Dinâmico e Avançado)
A tela Gráficos tem só o essencial: **Perfil** (Baixo, Médio, Alto, **Dinâmico**), com o ícone **?** ao lado do nome, Detectar pela máquina, Tela cheia, Mostrar FPS, Tamanho da interface e **Avançado**. Dinâmico = Alto com a baixa e a subida automáticas pelo fps medido (opção `qualidade_auto`, `v2/qualidade_auto.gd`: 8 s abaixo de 40 fps desce um degrau; 30 s firmes sobe, com a espera dobrando se subiu e travou em menos de 60 s). Com o limite de fps em 30, o "travado" passa a ser abaixo de 27,6 (92% do limite): rodar no próprio limite não desce o perfil. Abaixo do Perfil aparece a linha curta "Começa no Alto e ajusta pelo FPS", e o rodapé explica o Perfil por extenso quando a linha tem o foco ou o mouse em cima (é o que o ícone **?** indica). Escolher Baixo, Médio ou Alto desliga o Dinâmico; mexer numa opção vira Personalizado (o Dinâmico não age). A tela **Avançado** (`itens_avancado`) separa as opções em CPU e GPU e só lista o que a v2 lê (`LIDAS_NA_V2`). Na CPU: Partículas simuladas (`particulas_sim`) e Cálculo dos monstros (`combate._passo_sep()`: a separação recalcula a cada 2, 3 ou 6 quadros). O Máximo de inimigos vivos saiu desta tela: com a faixa de 150 a 500 não tinha efeito na v2 (o teto de dados é 84 e o nascimento para no cap de vivos, de 14 a 70), então `diretor.teto()` não lê a opção (ela segue na v1). Ficam de fora, por não terem efeito na v2 ainda: Detalhe do movimento longe da câmera (o quique só é calculado para quem está na tela) e Tempo dos restos no chão (a v2 não tem manchas de morte). Na GPU ficam de fora brilhos e halos, vinheta, efeitos das armas que crescem e escala de render. Ao abrir o Avançado, o foco cai na 1ª opção (o cabeçalho da seção CPU não recebe foco). ESC volta Avançado, Gráficos, Ajustes.


O perfil Dinâmico mede só a jogabilidade ativa: cartas, baús, resultado e pausa interrompem as janelas de FPS, preservando a espera contra oscilações. Chefes de nível aguardam um mini-chefe de exploração terminar antes de nascer.

### Conferência da integração de 18/10

Fotos reais da integração em [`docs/visual_2_5d/lote_2026_10_18/`](../../../../docs/visual_2_5d/lote_2026_10_18/): barras no teto com a placa do nível livre, quatro conquistas no resultado, marcas verdes de aliados, cartas com Xbox/PlayStation e Gráficos Dinâmico. As imagens Xbox, HUD e resultado têm 1280x720; a captura PlayStation solicitada em 1920x1080 ficou em 1918x1078 pela janela disponível (dimensão preservada no nome). A matriz de testes de escala cobre 1920x1080. São fotos paradas; o ritmo do combate e o balanço das recargas ainda precisam de uma partida humana.
