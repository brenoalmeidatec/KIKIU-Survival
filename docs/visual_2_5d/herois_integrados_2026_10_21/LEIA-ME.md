# Heróis do Blender integrados (Hazaki, Matheus, Lucas, Nicão), 21/10/2026

Fotos reais (janela do jogo, 1280x720, perfil padrão) tiradas com `jogos/hordas/projeto/testes/fotos/herois_fotos.gd`:

- `hud_retrato_4_herois.png`: o retrato do HUD na partida. Em cima Hazaki e Matheus, embaixo Lucas e Nicão: todos centrados na moldura de 90x108, escala inteira (2x), sem passar da borda.
- `salao_4_herois_parado_e_andando.png`: o Santuário, de cada herói parado (esquerda) e andando (direita), com a folha do personagem (Matheus) ou a do herói (Hazaki, Lucas, Nicão).
- `escolha_personagem_4_herois.png`: a escolha de personagem sem `rosto.png`: o quadro parado da folha do personagem, não mais sempre o do Hazaki.

Como refazer: `godot --path jogos/hordas/projeto --position -3000,0 res://testes/fotos/herois_fotos.tscn -- --fotos=PASTA`.

## Q do Nicão: causa da palidez e correção

`nicao_q_oclusao_antes_depois.png` compara recortes reais do mesmo instante após o Q (40 capturas de dois passos de 1/60 s), ampliados 4x sem suavizar.
O cenário é o de `testes/fotos/nicao_gifs.gd`: dez cavaleiros ocos numa roda de 66x40 px, parados e com vida alta. Use APPDATA de QA ao reproduzir.

A palidez era a silhueta de oclusão desenhada por cima do herói. O detector contava o vazio do quadro 64x96 do Nicão como corpo: os dois cavaleiros
expulsos para os lados ainda o "cobriam". Antes, o alfa da silhueta continuava 1 após terminar o Q; escondendo só a silhueta, as cores normais voltavam.
Depois, o alfa volta a 0 com o corpo livre, sem mudar a cor nem a invulnerabilidade do especial.

`oclusao.gd` usa o recorte explícito `retrato.regiao` quando a folha o oferece: no Nicão, 38x42 px delimitam o corpo sem o vazio e a marreta.
Esse recorte serve também à detecção de cobertura: se a composição do retrato mudar, preserve os limites do corpo. Folhas sem recorte mantêm a
aproximação anterior. `v2_oclusao` cobre a roda após o Q e um cavaleiro realmente na frente, que continua ativando a silhueta.

## Isolamento dos helpers GIF

`matheus_gif` e `heroi_gif` usam caminhos próprios de Config, Meta e Personagens antes de criar Mundo, e o perfil Alto só na memória.
Config reconhece essas duas cenas explícitas antes de carregar/migrar opções no autoload; isso evita gravar até um `opcoes.cfg` antigo.
Os helpers recarregam suas próprias opções para não herdar o estado do jogador. Editor e jogo normal mantêm o comportamento anterior.

`ferramentas/teste_gifs_isolados.ps1 -AppDataQA PASTA_QA -FilaGodot CAMINHO_DA_FILA` executa os dois helpers com APPDATA descartável,
captura o HUD e compara SHA256 de opções antigas migráveis, índice de personagens e dois saves de progresso. Também confere que nenhum
save real novo apareceu. Como controle negativo, abre o jogo normal na cópia descartável e confirma que a migração normal continua funcionando.
