# HUD e menus na direção 2.5D

Documento de análise (V1 para o HUD, V6 para os menus). Fonte: `docs/imagens/referencia_2_5d.webp`, 1672x941. Lido antes: `docs/visual_2_5d/README.md`. Nada de código foi alterado. Cores em `paleta.json` (mesma pasta).

**Como as medidas foram tiradas.** Recortes ampliados com ffmpeg (3x, lanczos) e leitura visual para achar as bordas de cada elemento. As posições são de olho, a partir desses recortes, com precisão de cerca de 3 a 5 px na imagem original (cerca de 0,2% a 0,3% da tela). Não é medição por pixel. Os percentuais são de x e y em relação ao canto superior esquerdo, e de largura e altura em relação à tela inteira. A referência é uma imagem-conceito, então o HUD dela é uma composição, não um print do jogo: use as proporções, não as pixels exatas.

## 1. Mapa do HUD

Os valores estão em % da tela (x, y, largura, altura). Os px de referência (em 1672x941) estão entre parênteses para conferência.

| Elemento | x % | y % | larg. % | alt. % | O que mostra |
|---|---|---|---|---|---|
| Retrato do herói | 1,8 | 2,3 | 5,4 | 9,6 | Rosto do Hazaki, moldura de canto fina (30,22 / 90x90 px) |
| Nome | 8,0 | 2,3 | 5,7 | 3,0 | "Hazaki", branco, sem contorno pesado (133,22 / 95x28 px) |
| Barra de vida | 8,0 | 5,3 | 14,1 | 2,7 | Vermelha, texto "95/100" à direita dentro da barra (133,50 / 235x25 px) |
| Barra de fragmentos | 8,0 | 8,5 | 13,8 | 2,7 | Azul, ícone à esquerda, "FRAGMENTOS 2/3" (133,80 / 230x25 px) |
| Nível do herói | 2,0 | 12,0 | 3,3 | 2,3 | "Nv 5" em caixa sob o retrato (33,113 / 55x22 px) |
| Slots de armas pequenos | 7,4 | 12,0 | 11,4 | 4,9 | Quatro quadrados com ícone de arma; número de nível embaixo à esquerda e um "1" à direita. Um deles tem selo dourado (124,113 / 190x46 px) |
| Faixa do topo | 28,7 | 1,1 | 43,1 | 4,0 | Faixa com a região à esquerda ("FLORESTA SOMBRIA") e a subárea à direita ("RIACHO NEGRO") (480,10 / 720x38 px) |
| Subárea | 57,1 | 1,9 | 11,1 | 3,0 | "RIACHO NEGRO", azul-claro (955,18 / 185x28 px) |
| n/5 (fase) | 48,7 | 1,1 | 3,3 | 3,6 | "1/5", branco, centralizado na faixa (815,10 / 55x34 px) |
| Cronômetro (painel) | 43,1 | 4,8 | 13,8 | 5,8 | Painel hexagonal escuro, com entalhe no topo (720,45 / 230x55 px) |
| Ampulheta | 44,7 | 5,8 | 1,8 | 3,7 | Ampulheta dourada e branca, à esquerda do número (748,55 / 30x35 px) |
| Cronômetro (número) | 47,2 | 5,3 | 7,7 | 5,0 | "07:32", número grande, branco quente, com brilho (790,50 / 128x47 px) |
| Ouro e Almas | 80,6 | 3,0 | 9,4 | 7,7 | Painel com "Ouro" e ícone de moeda; "Almas" e ícone de chama roxa (1347,28 / 158x72 px) |
| "Nv" do canto | 95,6 | 0,5 | 3,3 | 2,7 | "Nv 1", dourado, no canto superior direito (1598,5 / 55x25 px). Significado em dúvida, ver seção 6 |
| Minimapa | 89,5 | 6,2 | 9,3 | 16,7 | Círculo com anel verde-água fino, "N" em cima, seta branca no centro, pontos vermelhos de inimigos (1497,58 / 156x157 px) |
| Painel de Objetivo | 1,2 | 19,7 | 17,8 | 9,4 | Losango amarelo com ponto, título "Objetivo" em dourado, texto branco e "(2/3)" embaixo. Uma linha vertical liga o losango ao texto (20,185 / 298x88 px) |
| Losango do Objetivo | 1,7 | 20,2 | 1,9 | 3,4 | Losango dourado com fundo escuro e miolo dourado (28,190 / 32x32 px) |
| Notificação "PORTAL ABERTO" | 61,6 | 22,5 | 23,6 | 6,7 | Painel roxo: ícone de portal à esquerda, título em roxo e linha de texto branco embaixo (1030,212 / 395x63 px) |
| Ícone do portal | 62,2 | 23,2 | 2,5 | 4,9 | Espiral roxa dentro de círculo (1040,218 / 42x46 px) |
| Indicador de voz | 1,5 | 71,0 | 16,3 | 5,5 | Ícone de microfone, "E você?" e "Segure V para falar" (25,668 / 273x52 px). Só entra com o chat de voz (Marco 9) |
| Barra de habilidades | 1,5 | 81,8 | 23,0 | 12,8 | Faixa com 5 slots quadrados. Slot 1 selecionado com borda dourada e brilho (25,770 / 385x120 px) |
| Slot 1 (selecionado) | 2,6 | 83,4 | 4,7 | 8,2 | Espada prateada, borda dourada grossa, brilho amarelo, losango de marcação acima (43,785 / 79x77 px) |
| Slot 2 | 7,7 | 83,4 | 3,8 | 8,2 | Espada de fogo, borda azul-acinzentada (128,785 / 64x77 px) |
| Slot 3 | 12,0 | 83,4 | 3,9 | 8,2 | Espada de gelo, azul (200,785 / 65x77 px) |
| Slot 4 | 16,3 | 83,4 | 3,9 | 8,2 | Veneno, verde (272,785 / 65x77 px) |
| Slot 5 | 20,5 | 83,4 | 3,9 | 8,2 | Arcano, roxo (343,785 / 65x77 px) |
| Tecla do slot | (por slot) | 92,5 | (por slot) | 2,5 | Número embaixo de cada slot, branco, com seta pequena à esquerda (1, 2, 4, 5) |
| Tecla Q | 1,7 | 93,3 | 1,8 | 2,6 | Caixa pequena à esquerda da barra, "Q" dourado (28,878 / 30x24 px) |
| Barra de progresso da fase | 35,8 | 94,0 | 27,9 | 2,3 | Barra horizontal fina com setas nas pontas. Preenchimento dourado até cerca de 2/3 (598,885 / 467x22 px) |
| Marcos da fase (5) | 44,6 | 90,9 | 10,2 | 3,2 | Cinco losangos com ícones acima da barra (745,855 / 170x30 px). O atual fica destacado em azul |
| Painel de FPS, ping e online | 90,3 | 85,9 | 7,8 | 10,4 | Caixa escura: "FPS 58", "PING 32ms", "ONLINE" com bolinha verde, "Fase 1" com ícone de cabeça. Ping e online entram no Marco 9 (1510,808 / 130x98 px) |

Observações sobre o mapa. A barra de vida e a de fragmentos ocupam a mesma largura e ficam uma sobre a outra, ancoradas no retrato. Os quatro slots pequenos de armas ficam embaixo do painel do herói, alinhados à esquerda do retrato. Ouro e Almas, o minimapa e o "Nv" do canto formam uma coluna à direita, sem sobrepor a faixa do topo.

## 2. Linguagem visual

**Painéis.** Fundo quase preto com toque azulado, bem translúcido. A floresta e os monstros aparecem por trás, com pouca lavagem. O hex médio amostrado no painel do objetivo é `#01030b`, mas isso é a média com a floresta, então a opacidade real é alta (algo perto de 0,75 a 0,85). Os painéis de Ouro e Almas e do herói são um pouco mais claros que o fundo (`#242730` na média, com brilho de borda).

**Bordas.** Linha fina de 1 a 2 px, em cinza-azulado claro (`#86898f` medido, que deve ser um pouco mais claro na imagem real), com um brilho sutil. Os cantos são ornamentados: entalhes em forma de chevron nas pontas (barra de fase, cronômetro) e cortes diagonais no painel do herói. Esses cortes são o detalhe que mais define a linguagem. Na barra de habilidades, a borda tem um losango pequeno no meio do topo e pontas de seta nas duas extremidades.

**Destaque do selecionado.** O slot 1 tem moldura dourada grossa (cerca de 4 px) com brilho amarelo ao redor (`#f1b10e` como cor de preenchimento na barra de fase, e moldura mais forte visualmente). O marco atual da fase fica em azul-claro com borda luminosa. Os slots não selecionados têm borda azul-acinzentada, sem brilho.

**Sombras.** Quase nenhuma sombra de painel. O destaque vem de brilho (glow) em torno de ícones e de texto importante, não de drop shadow.

**Fontes.** Três papéis, com tamanhos aproximados medidos na altura da letra em relação à altura da tela:
- **Títulos** ("Objetivo", "PORTAL ABERTO", "FLORESTA SOMBRIA"): serifa humanista, caixa-alta com espaçamento largo nos nomes de região. Altura de maiúscula cerca de 2,2% da tela (uns 20 px em 941 de altura).
- **Número grande do cronômetro** ("07:32"): cerca de 5% da altura da tela (uns 47 px), branco quente, com brilho, com fonte de números de traço grosso.
- **Texto pequeno** (rótulos, FPS, texto do objetivo, "Segure V para falar"): cerca de 1,6% a 2% da altura (15 a 19 px), sans-serif limpa, cinza-claro.
- **Números de vida e de nível** ("95/100", "Nv 5"): cerca de 2,5% (23 px), branco, com contorno leve.

**Contorno do texto.** Texto com contorno escuro fino (1 px) nos números de dano e no cronômetro. Os títulos de painel não têm contorno, só cor.

**Ícones.** Pintados em pixel art com contorno escuro, no mesmo estilo dos sprites, mas com mais detalhe e mais liso que o resto do jogo. Exemplos: a ampulheta, a moeda de ouro, a chama roxa, a espada dos slots, o microfone e o losango do Objetivo. Os ícones de slot de habilidade (arcano, veneno, gelo, fogo) são ilustrações completas dentro do quadrado, não pictogramas.

**Números de dano.** Mesmo tratamento: fonte pixel-serif de traço grosso, com a cor do elemento, contorno escuro. Ver `paleta.json`, grupo `dano`.

**Atenção a um defeito da referência.** Na imagem, o rótulo "FRAGMENTOS" aparece com um erro de geração na letra A ("FR GMENTOS"). O texto correto é "FRAGMENTOS", e não é para copiar o defeito.

## 3. Como isso vira código no Godot

**Estado atual.** O HUD está em `jogos/hordas/projeto/cenas/hud.tscn`, com o tema `cenas/tema_hud.tres` (Marco 1). O tema é quase todo `StyleBoxFlat`: `painel` com fundo `Color(0.04, 0.035, 0.07, 0.72)` e borda de 1 px, e `barra_fundo` e `barra_cheia` para as barras. A fonte é a PressStart2P em todo o HUD, com `default_font_size = 8` e `LabelGrande` em 16. A árvore tem `Raiz` com `Esq` (Heroi, Build), `Dir` (Ouro e Almas), `Topo` (Regiao, Tempo, Sub, Objetivo, Missao), `Chefe`, `Msgs`, `Anuncio`, `Banner`, `Inferior` (Buffs, Habilidades, Provisoes), `Minimapa`, `Fps`, `Duelo` e `Pausa`. A árvore já tem quase todos os blocos da referência. O trabalho é trocar o visual, não reconstruir a estrutura.

**Proposta de Theme novo.** Criar `cenas/tema_hud_2_5d.tres` (ou substituir `tema_hud.tres` depois de validar), com:
- **Molduras de painel: `StyleBoxTexture` com 9-patch.** Uma textura de moldura (ver seção 5) com `texture_margin_*` de 12 a 16 px no tamanho de fonte nativo e `region_rect` apontando para a moldura. Assim o canto ornamentado não estica. Usar o mesmo 9-patch para o painel do herói, o de Objetivo, o de Ouro e Almas, o de notificação e o de voz. A variação de cor fica por `modulate_color` do próprio `StyleBoxTexture`, não com textura nova para cada cor.
- **Painéis de fundo: `StyleBoxFlat`.** Fundo `#01030b` com alfa 0,78, borda de 1 px em `#86898f` com alfa 0,6, `corner_radius` pequeno (2 px) e `shadow_size = 0`. Esse estilo serve para o painel de FPS e para os painéis que não precisam de ornamento. É a mesma técnica de hoje, só com cor e alfa novos.
- **Barras: `StyleBoxTexture` no preenchimento, com `StyleBoxFlat` no fundo.** O preenchimento de vida e de fragmentos usa `StyleBoxFlat` com gradiente feito em textura pequena, ou uma textura 1x3 px com gradiente vermelho e azul. Escolher uma das duas na implementação.
- **Slots de habilidade e de arma.** `StyleBoxTexture` para a moldura de cada slot, com dois estados (normal e selecionado). O selecionado usa uma moldura própria com brilho dourado, não um `modulate` da normal, porque o brilho precisa ser pintado.
- **Fontes.** Duas fontes: uma serifada (títulos e cronômetro) e uma sans limpa (texto corrido). A PressStart2P fica só no HUD de debug e nos menus que já a usam como identidade. Escolher fontes com licença que permita o jogo (OFL ou similar) e registrar em `LICENCAS` ou equivalente. A escolha exata fica em aberto, ver seção 6.

**Resolução do HUD.** A regra da V1 é "texto nítido acima do mundo pixelado". Para isso, o HUD não pode ser desenhado na mesma resolução baixa do mundo. O caminho proposto:
- O mundo (heróis, monstros, cenário) continua numa resolução de base baixa, pixelada, com filtro nearest. Ele é renderizado no `SubViewport` ou na viewport principal, como já for hoje.
- O HUD fica num `CanvasLayer` com `layer` acima do mundo, e usa a resolução nativa da janela, com layout em âncoras e percentuais. O texto e as molduras são sorteados na resolução cheia, então ficam nítidos.
- Para isso, a configuração de esticamento precisa ser `canvas_items` (o HUD escala junto com a janela) e não `viewport` (que escala o HUD junto com o mundo e borra o texto). Confirmar a configuração atual em `project.godot`, que não foi lida nesta análise.
- Molduras e ícones são desenhados em 2x a resolução do mundo (ver seção 5), para caberem nítidos na tela cheia sem aliasing.

**Estrutura de nós, pequenos ajustes em relação a hoje.**
- Manter `Raiz` como `Control` com âncoras full rect, e os blocos por âncora: `Esq` (canto superior esquerdo), `Topo` (centro superior), `Dir` (canto superior direito), `Inferior` (canto inferior) e `Fps` (canto inferior direito).
- Acrescentar `Raiz/Topo/Regiao` como faixa com o nome da região à esquerda e da subárea à direita, separados pelo "n/5" no centro. Hoje o "n/5" e a subárea estão em `Sub`, então a mudança é separar em dois `Label` na mesma linha.
- Ouro e Almas: manter `Dir/Linhas`, acrescentar um `TextureRect` de ícone antes de cada número. Não é novo bloco.
- Minimapa: trocar `Panel` por um `TextureRect` com máscara circular ou um `Control` com `_draw` (círculo, anel e pontos). O "N" é um `Label` fixo em cima.
- Notificação do portal: `Banner` com o `StyleBoxTexture` roxo e um `TextureRect` de ícone à esquerda. Mesmo bloco, só visual.
- Habilidades: `Inferior/Linha/Habilidades` com cinco slots; cada slot ganha `TextureRect` de ícone e `Label` de tecla. Hoje são só `Hab1` e `Hab2`, então é preciso acrescentar os outros três. Essa é a mudança com mais trabalho de nó.
- Marcos da fase: `Inferior` com `HBoxContainer` de cinco `TextureRect` em losango, acima da `ProgressBar` de fase. Hoje essa barra de fase não existe como nó separado, então é novo.

Não implementar agora. Esta seção é só para a V1.

## 4. Menus

Todas as telas usam hoje a mesma base (fundo azul-escuro chapado, PressStart2P, títulos em amarelo ou azul, painéis com borda de 1 px). Pelo `build/menus/menus_todos.png`, as telas são: título, escolha de herói, criar herói, preparo, calor, mapa, pausa, status, opções e créditos. A referência não mostra menu. Então a linguagem vem dos painéis e das bordas do HUD, e não de uma tela de referência. Os itens abaixo dizem o que muda em cada uma.

- **Título.** Trocar o fundo chapado por uma cena escura com névoa e floresta em profundidade, na mesma paleta do HUD. O título "K.I.K.I.U" sai da fonte pixel e passa para a serifada, com contorno e brilho azul-claro. O subtítulo e o menu ganham painel de moldura 9-patch. Botões: a opção selecionada tem a moldura dourada e o losango de seleção, no lugar do ">" de texto.
- **Escolha de herói.** Os três cards ganham a moldura 9-patch do painel do herói (canto ornamentado). O selecionado tem a borda dourada grossa, como o slot 1 da barra de habilidades. Retratos: ver seção 5, com moldura de retrato (`marco_retrato`) e o retrato em 128x128 no lugar dos atuais.
- **Criar herói.** Painel de atributos e painel de prévia com moldura 9-patch. Os campos de texto e as barras de atributo ganham a barra azul-acinzentada do HUD. Os seletores de cor (pele, cabelo, roupa) ficam em quadrados com a borda fina clara. Mais difícil de ler hoje, então o tamanho da fonte pequena passa para a sans limpa.
- **Preparo.** Lista de itens com a faixa dourada da seleção (já existe, só muda o visual). Os painéis de mochila e de ficha ganham moldura. Os botões "Voltar" e "Começar" viram botões 9-patch, com "Começar" em verde (`#18df50` da referência, como o "ONLINE").
- **Calor.** Lista de modificadores com a faixa vermelho-alaranjada da seleção, e os pontos de calor em losango no lugar dos quadradinhos. Número de bônus ("+1", "+2") em laranja, com a cor de dano correspondente.
- **Mapa.** Painel 9-patch em volta do mapa, com o nó atual em dourado e os nós concluídos apagados. Nó de chefe com moldura vermelha. O painel de "CHEFE" ganha o mesmo estilo do PORTAL ABERTO (ícone à esquerda, título colorido, linha de texto).
- **Pausa.** Escurecer o mundo com o `ColorRect` atual, mas com `#01030b` a 0,7 de alfa em vez de preto puro. O título "PAUSADO" vira a fonte serifada. O menu central ganha moldura 9-patch, com a seleção dourada.
- **Status.** Painel grande com moldura 9-patch e seções separadas por uma linha fina clara. Os títulos de seção ("Armas", "Equipamentos", "Atributos") em dourado. Os valores alinhados à direita, em branco. Ícones pequenos ao lado de cada arma.
- **Opções.** Cabeçalhos de grupo (JOGABILIDADE, ACESSIBILIDADE, ...) em dourado e a seleção em barra azul com moldura. Pode manter o layout de lista, que já funciona, e trocar só o visual. Atenção ao tamanho da fonte: o próprio item "Tamanho da fonte do HUD" deve passar a valer para a fonte nova.
- **Créditos.** Títulos de crédito em cores de elemento (azul para o criador, verde para o artista, dourado para a ferramenta) com a fonte serifada. Texto corrido na sans limpa. Rodapé com a mensagem final em rosa, como hoje.

## 5. Lista de artes de UI a produzir

Tamanhos em pixel de fonte. "Nativo" é o tamanho em que o jogo desenha o item na tela de referência (1672x941). "Fonte" é o tamanho do arquivo a produzir, com 2x o nativo para ficar nítido em tela cheia. Todas as molduras são 9-patch, com a região de canto de cerca de 16 px.

**Molduras 9-patch (StyleBoxTexture)**

| Arte | Nativo (px) | Fonte (px) | Margem do 9-patch | Usada em |
|---|---|---|---|---|
| `painel_heroi` | 298x104 | 596x208 | 16 | Retrato e nome, barra de vida, fragmentos |
| `painel_objetivo` | 298x88 | 596x176 | 16 | Painel do Objetivo |
| `painel_ouro` | 158x72 | 316x144 | 16 | Ouro e Almas |
| `painel_notificacao` | 395x63 | 790x126 | 16 | PORTAL ABERTO (variante roxa) |
| `painel_voz` | 273x52 | 546x104 | 14 | Indicador de voz |
| `faixa_regiao` | 720x38 | 1440x76 | 14 | Faixa do topo com região e subárea |
| `hex_cronometro` | 230x55 | 460x110 | 16 | Painel do cronômetro |
| `barra_habilidades` | 385x120 | 770x240 | 16 | Base das cinco habilidades |
| `slot_normal` | 64x77 | 128x154 | 10 | Slots de habilidade e de arma (normal) |
| `slot_selecionado` | 79x77 | 158x154 | 10 | Slot 1 (com brilho dourado) |
| `barra_fundo` | 235x25 | 470x50 | 8 | Fundo das barras de vida e fragmentos (1 variante por cor) |
| `barra_fase` | 467x22 | 934x44 | 10 | Barra de progresso da fase com setas |
| `painel_fps` | 130x98 | 260x196 | 12 | FPS, ping, online e fase |
| `marco_retrato` | 96x96 | 192x192 | 12 | Moldura dos retratos (HUD e escolha de herói) |
| `botao_menu` | 240x48 | 480x96 | 12 | Botões de menu (normal, selecionado, pressionado) |
| `painel_menu` | 320x200 | 640x400 | 16 | Painéis grandes de menu (criar herói, status, mapa) |

**Ícones (pixel art com contorno escuro)**

| Arte | Nativo (px) | Fonte (px) | Usado em |
|---|---|---|---|
| `icone_ouro` | 22x22 | 44x44 | Ouro |
| `icone_alma` | 22x26 | 44x52 | Almas (chama roxa) |
| `icone_ampulheta` | 30x35 | 60x70 | Cronômetro |
| `icone_objetivo` | 32x32 | 64x64 | Losango do Objetivo (dourado com miolo) |
| `icone_portal` | 42x46 | 84x92 | PORTAL ABERTO (espiral roxa) |
| `icone_microfone` | 28x28 | 56x56 | Indicador de voz |
| `icone_fragmento` | 20x20 | 40x40 | Barra de fragmentos |
| `icone_fase_marco` | 30x30 | 60x60 | Cinco marcos da fase (estados: passado, atual, futuro) |
| `icone_mapa_norte` | 12x12 | 24x24 | "N" do minimapa (seta de norte, se não for texto) |
| `icone_ping_online` | 12x12 | 24x24 | Bolinha verde e ícone de Fase 1 (Marco 9) |

**Retratos (pintados em pixel)**

| Arte | Nativo (px) | Fonte (px) | Observação |
|---|---|---|---|
| `retrato_hazaki` | 90x90 | 128x128 | Retrato do HUD |
| `retrato_hazaki_grande` | 96x96 | 192x192 | Escolha de herói, com moldura |
| `retrato_nicao`, `retrato_lucas` | 96x96 | 192x192 | Mesmo tamanho nas outras telas |
| `retrato_base_generico` | 90x90 | 128x128 | Para heróis novos, até o Marco 8 |

**Ícones de habilidade (ilustrados, 64x64 nativo, 128x128 fonte):** espada prateada (slot 1), espada de fogo, espada de gelo, veneno verde, arcano roxo. As cinco são ilustrações com fundo colorido e moldura, não ícone sobre transparência. Se o pipeline não gerar ilustração, o fallback é o ícone base sobre a moldura `slot_normal`.

**Ícones de arma pequenos (slots do herói):** 24x24 nativo, 48x48 fonte. Quatro variantes, com número de nível embaixo.

**Total.** Dezesseis molduras, dez ícones, quatro retratos base e cinco ícones de habilidade, mais os de arma. Para a V1 só o HUD: molduras de painel, faixa, barra de habilidades, slots e os ícones de ouro, alma, ampulheta, objetivo e portal. Retratos e ícones de habilidade são da V4 e V5.

## 6. Dúvidas

1. **Resolução base e esticamento.** `project.godot` não foi lido. A decisão de `canvas_items` contra `viewport` depende da configuração atual, e isso muda o tamanho de todas as molduras.
2. **"Nv 1" do canto superior direito.** Não está claro se é o nível da partida, o da horda ou o da sala. O "Nv 5" do herói é o nível do personagem. Confirmar com o Breno antes de criar o ícone de "Nv" de canto.
3. **Teclas dos slots.** Embaixo dos slots aparecem "1", "1", "2", "4", "5". O primeiro slot é a tecla 1, mas o segundo também aparece como "1". Pode ser erro da imagem ou um detalhe de design (por exemplo, a espada de fogo sendo o "1" de outra camada). Confirmar a regra de teclas.
4. **Números nos slots de arma.** Os quatro slots pequenos mostram "7", "2" e um "1" à direita. Não está claro se são nível, munição ou contagem de acertos. Confirmar o significado antes de desenhar.
5. **Fonte.** A referência não usa a PressStart2P no HUD. Ela usa uma serifada para títulos e uma sans para texto, com números de traço grosso. Precisa escolher as duas fontes com licença compatível, e isso muda o tamanho de texto em toda a UI. Decisão do Breno.
6. **Escopo do Marco 1 e dos blocos futuros.** A referência mostra chat de voz, ping e online, minimapa, almas e marcos da fase. O README diz que voz e ping/online são do Marco 9, minimapa do Marco 4 e almas do Marco 7. Na V1 é possível desenhar esses blocos como espaço reservado ou não desenhá-los. Não é para criar a funcionalidade agora.
7. **Cores de número de dano.** Não tem amostra limpa de número verde. Na `paleta.json` usei a cor do veneno como aproximação. Confirmar no jogo.
8. **Medidas.** As posições são de olho em recortes ampliados, com cerca de 0,3% de erro. Para o layout final, é melhor refazer as medidas numa captura de tela real do jogo, depois que a V1 estiver rodando.
