# Estruturas do Marco 4 — fontes de arte

Pedido: issue #244, contexto #128. Arte própria gerada no Codex; sem código, recorte, colisão ou integração.

fonte_estruturas.png: **1774×887**, disposição **4×2** sobre branco. O gerador não entregou a dimensão solicitada de 2048×1024. Para recorte com células inteiras iguais, o Claude pode acrescentar 2 px brancos à direita e 1 px embaixo, formando 1776×888 e células 444×444. Fonte original preservada; não normalizada aqui.

| Célula | Linha | Coluna | Peça | Leitura / integração |
|---|---|---|---|---|
| 1 | 1 | 1 | Ruína | Arco quebrado com passagem central; paredes nas laterais |
| 2 | 1 | 2 | Altar | Base de pedra, degraus e cristal violeta; objeto de interesse |
| 3 | 1 | 3 | Ponte | Madeira e corda, duas extremidades abertas; sem rio pintado |
| 4 | 1 | 4 | Passagem estreita | Corredor de chão entre duas paredes rochosas |
| 5 | 2 | 1 | Platô | Terraço baixo com escada frontal e topo livre |
| 6 | 2 | 2 | Portão | Pilares com duas folhas abertas e tochas |
| 7 | 2 | 3 | Torre | Silhueta vertical com braseiro no topo |
| 8 | 2 | 4 | Mirante | Plataforma sem teto, com parapeito e escada; distinto da torre |

A issue #244 lista sete peças e observa que o mirante ainda é marcador: ele entra como oitava peça. Nem #244 nem #128 especificam dimensões de fonte; a grade acima é a convenção desta entrega, não um requisito atribuído à issue.

A câmera é 3/4 elevada, materiais escuros de pedra/ferro/madeira, sombras frias e fogo quente. As células têm margens, incluindo a chama da torre após revisão. Os objetos foram ajustados ao espaço de cada célula: definir escala física no mapa durante a integração; não assumir que torre e altar possuem a mesma altura.

Para o Claude do Alisson: remover o branco, recortar, ajustar pivôs no chão e escala, associar colisão/rotas pelos dados existentes. Passagens e escadas desenhadas não implementam navegação. Prints dos três mapas, conectividade e desempenho pedidos pela issue permanecem pendentes da integração; esta folha não é screenshot do jogo. Não fechar a issue somente com este PR.
