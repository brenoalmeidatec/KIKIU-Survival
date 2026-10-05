# JOGO: ideias de Pokémon (GBA) e Metal Slug para deixar o visual menos tosco

Pesquisa feita em 2026-10-02 a partir do estado atual (jogo/antes_depois.png, jogo/mapas_visao/, LEIA-ME).
Só proposta: quem mexe no código é a thread "Base do jogo em Godot".

## O que deixa o jogo com cara de tosco hoje (diagnóstico)

A parte técnica já está certa: viewport 480x270, escala inteira, filtro "nearest", snap de pixel ligado
(project.godot). Os personagens também já estão na proporção certa (32x48 numa tela de 480x270 é quase a
mesma proporção do Pokémon no GBA, 16x32 numa tela de 240x160). O problema está nos **cenários**:

1. **Chão chapado e sem perspectiva.** Pokémon mostra a parede de frente (3/4): você vê a face da parede,
   rodapé, janela, quadro. Nos nossos mapas o chão é um xadrez grande e liso e as paredes quase não aparecem
   (Sala 204, Pátio, Corredor).
2. **Salas grandes e vazias.** Os objetos são poucos, pequenos e repetidos (as carteiras da 204 todas iguais,
   o Pátio com 5 mesas no meio do nada). Em Pokémon cada canto tem um vaso, uma lixeira, uma estante, um tapete.
3. **Nada encosta no chão.** Personagens e móveis não têm sombra de contato, então parecem colados por cima.
4. **Cores sem família.** Azul puro, branco puro e marrom saturado lado a lado. Cada mapa tem uma paleta
   diferente e os rostos (foto pixelada) têm outra. O bloom/tinta ajuda o clima mas não resolve a base.
5. **Tudo parado.** Metal Slug é lindo porque tudo mexe: gente no fundo, fumaça, papel voando. Aqui só as
   partículas se mexem.

## As 8 melhores ideias, em ordem

| # | Ideia | O que muda no jogo | Esforço | Licença / custo |
|---|-------|--------------------|---------|-----------------|
| 1 | **Mapas montados com um tileset de verdade, em perspectiva 3/4** | Paredes com face visível, piso com textura sutil, rodapé, janelas, quadros, móveis com volume. É a mudança que mais pesa. | Alto (refazer 7 mapas), mas o pipeline atual aguenta: os geradores em jogo/fonte_mapas/ podem colar tiles do pacote no PNG e nos "objetos", sem mudar o jogo. | Recomendado: **Modern Interiors (LimeZu)**, tem sala de aula, escritório, computadores, biblioteca, em 16/32/48 px. Pago a partir de US$ 1,50, pode usar em projeto comercial ou não, pode editar, exige crédito, não pode redistribuir o pacote. Tem versão grátis menor. |
| 2 | **Sombra de contato + contorno escuro** | Elipse escura sob cada personagem, NPC e móvel; contorno de 1 px nos objetos; faixa de sombra onde a parede encontra o chão. Tudo "pousa" no chão. | Baixo (código + JSON, já existe "luzes": sombra) | Nenhuma |
| 3 | **Uma paleta única para o jogo inteiro** | Escolher uma paleta de 32 a 64 cores (Lospec, ex. Endesga 32/64 ou Resurrect 64) e converter mapas, móveis e personagens para ela. Dá a cara de "um jogo só", como o GBA fazia por limitação. Cada sala varia só o "visual" (tinta) por cima. | Médio (script de conversão nos geradores; os rostos podem ficar com mais cores) | Paletas do Lospec são livres para usar |
| 4 | **Cenário vivo (o segredo do Metal Slug)** | Tiles animados (monitor piscando, ventilador de teto, relógio, folha de árvore, porta abrindo em 3 quadros), alunos figurantes sentados ou passando no corredor e no pátio, poeirinha no pé ao andar, papel no quadro de avisos balançando. | Médio | Nenhuma (o Modern Interiors já traz móveis animados) |
| 5 | **Animação estilo Metal Slug nos personagens** | Idle com respiração (2 a 4 quadros), antecipação antes do pulo, "estica e amassa" no !pular e no susto, quadro de borrão (smear) em movimentos rápidos, reação ao bater na parede. Faz cada fala parecer encenada. | Médio (rig.py da thread de arte + leitura no jogo) | Nenhuma |
| 6 | **Caixa de diálogo e fonte estilo GBA** | Caixa com borda dupla e cantos arredondados (tipo FireRed), seta piscando, nome em "aba"; trocar a Press Start 2P (larga, cansa em texto longo) por uma fonte pixel mais estreita e com acentos; **som de fala com tom diferente para cada personagem** (Nicão grave e lento, Lucas agudo e rápido). | Baixo a médio | Fonte: escolher uma com licença livre (OFL/CC0) e conferir acentos antes |
| 7 | **Entrada de "batalha" antes dos minijogos** | Clarão + transição por máscara (uma imagem em tons de cinza define o padrão: espiral, persianas, Pokébola) + tela "VS" com os dois rostos deslizando, como o treinador no Pokémon. Perfeito para o humor das histórias ("Breno VS PC do Núcleo"). | Baixo (um shader serve para dezenas de transições; já existe a "cortina") | Técnica livre; exemplos no godotshaders.com |
| 8 | **Ferramentas para retocar à mão** | **Pixelorama** (grátis, código aberto, feito em Godot) ou **Aseprite** (US$ 19,99, ou grátis compilando o código) para ajustar tiles e sprites; **Better Terrain** (plugin Godot, Unlicense) se um dia os mapas virarem TileMap em vez de PNG. | Baixo | Como indicado |

### O que pesquisei e NÃO recomendo agora
- **Dialogic 2** (diálogos) e **Phantom Camera** (câmera, MIT, Godot 4.4+): são ótimos, mas o jogo já tem diretor de
  cenas, câmera, zoom e barras próprios, com o formato curto que o Breno edita no Bloco de Notas. Trocar
  custaria reescrever sem ganho visível.
- **PixelPerfectSmoother** (MIT): só vale se aparecer tremidinha na câmera; hoje o snap já está ligado.
- Pacotes LPC (OpenGameArt): licença CC-BY-SA/GPL e estilo medieval, não combina com a Cairu.

## O que fazer primeiro

Fazer **uma sala só** (sugiro a Sala 204, a mais "tosca" hoje) com as ideias 1 + 2 + 3 juntas e mostrar
antes/depois ao Breno. Se ele gostar, aplicar nas outras salas e depois seguir com 4, 6 e 7, que são as que
mais dão vida pelo menor esforço. A 5 vai para a thread de arte dos personagens.

Decisão que é do Breno: gastar US$ 1,50 no Modern Interiors (arte feita por um artista humano, não IA) ou
continuar com cenários desenhados em código. Recomendação: comprar; nenhum gerador em código chega perto
daquele nível de detalhe, e dá para recolorir na paleta do jogo para combinar com os personagens.

## Fontes
- Modern Interiors (LimeZu): https://limezu.itch.io/moderninteriors
- Better Terrain: https://github.com/Portponky/better-terrain
- Phantom Camera: https://github.com/ramokz/phantom-camera
- PixelPerfectSmoother: https://godotengine.org/asset-library/asset/4846
- Transições Pokémon com um shader: https://phaser.io/news/2025/08/how-to-create-pokemon-battle-transitions-with-one-shader
- Shader de transição com padrões: https://godotshaders.com/shader/transition-shader-with-patterns/
- Gradient map (GDQuest): https://gdquest.com/tutorial/godot/shaders/gradient-map/
- Cor e perspectiva em pixel art: https://admiralalex.itch.io/tower-of-zazel/devlog/942884/dev-diary-3-coloring-and-perspective
- Sub-pixel animation: https://tinywarriorgames.com/2019/01/04/game-development-pixel-art-sub-pixel-animation/
- Interior tileset 16x16 (OpenGameArt): https://opengameart.org/content/interior-tileset-16x16
- Roguelike indoor pack (Kenney, CC0): https://opengameart.org/content/roguelike-indoor-pack
