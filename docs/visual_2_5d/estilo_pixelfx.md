# Estilo pixelfx nas armas da v2

Guia para repetir, nas armas, o estilo de https://patch-gg.github.io/pixelfx/. Como tocar e registrar as folhas do pixelfx original (baú, nível, portal, status, clima) está em `docs/PIXELFX.md`; este arquivo trata só dos impactos das armas.

## O que é o pixelfx
- Biblioteca com mais de 240 efeitos de pixel art, cada um escrito como código pequeno, sem imagens. O repositório é `patch-gg/pixelfx`.
- **Licença:** MIT (Copyright (c) 2026 Patch e Hugo Duprez). Pode usar, mudar e vender o jogo, mantendo o aviso. Parte do núcleo vem de código MIT do Sprite Fusion, de Hugo Duprez. A fonte Patch Pixel, em `gallery/fonts`, **não** é MIT e não deve ser usada.
- **Como gera:** não é shader nem partícula da engine. Uma simulação em JavaScript desenha cada quadro em dois buffers, um de cor e um de luz aditiva, e exporta uma folha de sprites. A física anda a 120 Hz, então o movimento não depende dos fps. A aleatoriedade tem semente, então a folha sai sempre igual.
- **Números originais:** 30 fps, célula de 96 a 320 px, impactos de 0,3 a 0,9 s e explosões de até 5 s. Paletas em rampas de 7 a 9 tons, do escuro ao branco, com a sombra puxando para frio ou fundo.

## O que faz o estilo funcionar
1. **Linhas e luz, não preenchimento.** Aros de 1 px, faíscas e rastros; branco no núcleo, cor no meio, cor funda só na sombra.
2. **Fases.** Clarão de 1 a 2 quadros, abertura, sustentação e queda longa. Ataque rápido, saída lenta.
3. **Física de verdade.** A faísca estica com a velocidade, cai e quica. O fogo sobe, esfria na rampa e vira fumaça. Tudo tem arrasto: sai rápido e depois flutua.
4. **Volumes macios.** Fumaça e poeira são discos translúcidos com o topo aceso, nunca xadrez pontilhado.
5. **Muitos eventos pequenos.** Tamanho, velocidade e vida variam em cada peça.
6. **Lê em 1x.** Um ponto de foco claro, sem chuvisco por dentro das formas.

## O que mudamos para o KIKIU
| pixelfx | KIKIU |
|---|---|
| Node e célula grande | `gerar_pixelfx.py`, em Python, sem rede e sem clone |
| Efeito longo (até 5 s) | Até 0,6 s: a horda dispara muitos ao mesmo tempo |
| 30 quadros ou mais | 5 a 13 quadros nos impactos, a 24 ou 30 fps |
| Alfa livre e halo suave | Alfa em 6 degraus; luz fraca é cortada para não virar pixel solto |
| Paleta livre | 10 a 19 cores por folha |
| Escala à vontade | 1 px do mundo: a folha já nasce do tamanho da área da arma |

## As famílias
Tudo sai de `jogos/hordas/fonte_arte/armas_anim/gerar_pixelfx.py`. Cada arma é uma linha numa tabela: família, tema de cor e tamanho.

| Família | Quem usa | O que acontece |
|---|---|---|
| `acerto` | projéteis (adagas, flechas, lanças, dardos, discos) | cruz com losango branco e cone de faíscas e lascas para o lado do golpe |
| `explosao` | bolas, meteoros de fogo, runas, crítico explosivo, cabaça | clarão, frente de choque, chamas que esfriam, fumaça, faíscas e lascas |
| `eletrico` | Raio, Raio Meteórico | nó de ziguezagues, samambaia queimada, faíscas em trancos |
| `pontas` | Cometa Gelado, Cometa Duplo, Chuva de Espinhos | pontas que brotam e quebram em cacos, vapor rente ao chão |
| `terra` | Chuva de Pedras, pancada do golem | rachadura, torrões, poeira, sem luz |
| `anel` | anéis de choque e fusões | frente no chão que levanta poeira, faíscas, pontas ou rachaduras |
| `nuvem` | nuvens, fusões e auras | puffs em ciclo, com gotas, flocos, bolhas ou cinzas |

## A física
- **Gravidade e inércia:** faíscas e lascas seguem trajetória balística, a 950 px/s², com arrasto do ar.
- **Quique e atrito:** cada peça perde energia ao bater, freia no chão e assenta (`Cacos`).
- **Profundidade:** cada peça cai no seu lugar do chão, então a de trás bate mais alto na tela.
- **Direção do golpe:** a folha de acerto não tem lado; as faíscas saem em tempo real (`efeitos.faiscas`) na direção exata do golpe, com gravidade e quique no chão.
- **Fumaça e fogo:** sobem por empuxo, incham e se dissipam.
- **Luz:** apaga em decaimento exponencial.
- **Gotas e flocos:** a gota acelera e respinga; o floco cai devagar e balança.

## Como fazer outro
1. Acrescente a folha em `IMPACTOS`, `ANEIS` ou `NUVENS`. A chave é o nome da folha no índice antigo. Efeito sem arma vai em `SOLTOS`, com id `fx_*`.
2. Meteoro: use `_meteoro`, que faz a célula do tamanho da área para o jogo não ampliar.
3. Tudo tem que sumir antes do último quadro, e a nuvem precisa de ciclos inteiros para não ter emenda.
4. Rode `python jogos/hordas/fonte_arte/armas_anim/gerar_pixelfx.py --previa docs/combate_v2/previas`, olhe os GIFs, conserte o pior e repita.
5. Rode `godot --headless --import` e o teste `testes/v2_fx_armas_pixelfx.tscn`. Confira no jogo com `testes/fotos/golpes_gif.tscn`, porque o fundo do mapa muda a leitura.

## Como funciona no jogo
`indice_pixelfx.json` é lido por último em `Anim.GRUPOS` e troca só as animações refeitas, repetindo as outras. As folhas antigas continuam no lugar. O código tocava camadas por cima (estouro "cristal", ondas, explosão de shader, fumaça); elas saíram de `armas.explodir`, `_cair_raio`, `_explodir_runa`, dos anéis, dos meteoros, da cabaça, do golem e dos aliados. A luz, o tremor, o som e a marca no chão ficaram.

## Status no corpo
Fogo, gelo, veneno, choque e sangue são desenhados pelo shader do próprio sprite (`v2/status_corpo.gd`), lendo o alfa do quadro atual. Por isso cobrem a silhueta inteira em toda direção e quadro, sem nó nem limite de monstros. A chama sai do contorno e o contorno escuro do bicho fica, para ele continuar legível.
- No lote da horda, o estado vai no alfa da instância, porque o custom data do renderizador de compatibilidade é float16. Elite e chefe usam `StatusCorpo.material_no`.
- Fogo vem de `queima_t` e gelo de `lento_t`. Veneno, choque e sangue são só desenho: a tabela `marcas` de `dados/v2_pixelfx.json` diz qual arma deixa qual marca.
- Perfil Baixo: sem shader de status, fica a tinta antiga.

## Trilhas, marcas e o resto
- `rastro` mantém o desenho do projétil e acrescenta atrás um rastro que esfria e cai. Projétil que gira nos quadros (`gira`) não tem rastro, porque a folha não sabe a direção do voo.
- `marca` refaz as manchas no chão, com rachaduras acesas que esfriam.
- Morte (`fx_morte`), dano no herói (`fx_dano_heroi`), cura (`fx_cura`) e acerto da katana (`fx_aliado`, tingido) são folhas soltas.
- O traço do raio tem halo, corpo e núcleo em pixel inteiro, galhos e brilho em degraus.
- Baú, nível, coleta, portal e invocação já usavam folhas do pixelfx desde 01/11.

## Katana, fusão, HUD e giratórios
- **Cortes da katana:** `fonte_arte/blender_corte/corte_pfx.py` parte da folha do Blender e acrescenta o rastro largo que esfria e as faíscas que a lâmina arranca; depois `girar_corte.py` gera as 16 direções. As folhas `corte_hazaki*` continuam no repositório, sem uso no jogo.
- **Fusão, ápice, morte do chefe e queda do herói:** folhas `fx_fusao` (tingida) e `fx_queda_heroi` no lugar das ondas.
- **Projétil que gira:** as faíscas de rastro saem em tempo real (`armas_novas._mover_projetil`), porque a folha não sabe a direção do voo.
- **HUD:** `v2/fx_ui.gd` toca `fx_ui_anuncio` atrás do letreiro e `fx_ui_pronta` no slot da ultimate e na barra de nível. Não toca com "Reduzir piscadas" nem no perfil Baixo.

## O que ficou de fora
- A tela de título e os menus: o título já tem partículas próprias (`titulo_vivo.gd`), que não mudaram.
- Os perigos dos chefes e dos inimigos (`perigo_*`) não são armas.
- O crítico de projétil toca o impacto em escala 2, como antes, então tem pixel dobrado.
