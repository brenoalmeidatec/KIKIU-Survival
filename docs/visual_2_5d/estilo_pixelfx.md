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
| 30 quadros ou mais | 5 a 13 quadros, a 24 ou 30 fps |
| Alfa livre e halo suave | Alfa em 6 degraus; luz fraca é cortada para não virar pixel solto |
| Paleta livre | 10 a 19 cores por folha |
| Escala à vontade | 1 px do mundo: a folha já nasce do tamanho da área da arma |

## Os efeitos desta prova
| Arma | Folha | Célula | Animação | O que acontece |
|---|---|---|---|---|
| Bola de Fogo | `pfx_bola_fogo_impacto.png` | 112x96 | 13 quadros, 24 fps | clarão, onda no chão, chamas que esfriam em fumaça, faíscas e brasas |
| Raio em Cadeia | `pfx_raio_impacto.png` | 64x56 | 10 quadros, 30 fps | nó de ziguezagues, queimadura em samambaia, faíscas que mudam de rumo |
| Adagas Voadoras | `pfx_adaga_aco_impacto.png` | 48x40 | 5 quadros, 30 fps | cruz torta com losango branco e lascas quentes |
| Cometa Gelado | `pfx_cometa_gelo_impacto.png` | 128x104 | 12 quadros, 24 fps | pontas de gelo que brotam e quebram, geada e vapor frio |
| Chuva de Pedras | `pfx_pedra_cinza_impacto.png` | 72x64 | 9 quadros, 24 fps | rachadura, terra jogada para cima e poeira rente ao chão, sem luz |

## Como fazer outro
1. Em `jogos/hordas/fonte_arte/armas_anim/gerar_pixelfx.py`, escreva uma função que devolve `(ps, quadro)`: as partículas e o desenho do tempo `t`. Use `bola_fogo` como modelo. Tudo tem que sumir antes do último quadro.
2. Acrescente a arma em `EFEITOS` e `ANTIGOS`. A chave é o nome da folha no índice antigo.
3. Meteoro: a célula precisa ter a largura do diâmetro da área, senão o código amplia a folha (`armas_novas.gd`, a conta de `tocar_fx`).
4. Rode `python jogos/hordas/fonte_arte/armas_anim/gerar_pixelfx.py --previa docs/combate_v2/previas`, olhe os GIFs, conserte o pior e repita pelo menos três vezes.
5. Rode `godot --headless --import` e o teste `testes/v2_fx_armas_pixelfx.tscn`. Confira no jogo com `testes/fotos/golpes_gif.tscn`, porque o fundo do mapa muda a leitura.

## Como funciona no jogo
`indice_pixelfx.json` é lido por último em `Anim.GRUPOS` e troca só o `impacto` das cinco armas, repetindo as outras animações. As folhas antigas continuam no lugar. **Para voltar atrás, basta tirar `"pixelfx"` de `GRUPOS`.**

## Limites conhecidos
- As camadas antigas continuam por cima da folha nova: em `armas.explodir`, o estouro "cristal", a onda e a fumaça; em `_cair_raio`, a onda e a explosão. Elas abafam parte do estilo. Tirá-las é o próximo passo natural, e mexe em código do Claude do Alisson.
- O traço do raio que cai do céu continua sendo o de `_raio_visual`. Só o estalo no alvo mudou.
- O crítico de projétil toca o impacto em escala 2, como antes, então tem pixel dobrado.
