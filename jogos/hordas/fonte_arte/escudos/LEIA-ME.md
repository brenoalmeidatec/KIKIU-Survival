# Escudos de verdade (v2)

Um escudo por personagem, em pixel art, no lugar do campo translúcido de antes. Arte própria, desenhada por script (Python + Pillow); sem imagem de terceiros.

```
python gerar_escudos.py                      # grava ../../projeto/assets/v2/escudos/<id>.png e imprime os centros dos pedaços (JSON)
python gerar_escudos.py --previa previa.png  # também grava uma folha de conferência ampliada 5x
```

Cada `<id>.png` é uma faixa 256x32 com 8 células de 32x32, centro do escudo em (16,16):
`0 frente`, `1 lado` (3/4, estreito; o jogo espelha para a esquerda), `2 costas` (tábuas, tiras de ferro e alça), `3 rachado`, `4..7` os quatro pedaços da quebra
(na mesma posição da frente, para a quebra "desmontar" o escudo no lugar).

| id | quem usa | escudo |
|---|---|---|
| `hazaki` | Hazaki (samurai) | tate de madeira laqueada vermelha, aro e tiras de ferro, mon dourado |
| `nicao` | Nicão (guardião) | redondo de ferro rebitado, amassado (um bocado arrancado) e com ferrugem |
| `lucas` | Lucas (adagueiro) | broquel pequeno de couro com aro de bronze e uma gema roxa |
| `matheus` | personagem Matheus (joga com o kit do Hazaki, folha própria) | escudo em gota de laca azul, aro de aço, sino dourado |

O jogo escolhe pelo nome da folha de sprites do personagem (`matheus`), senão pela chave do herói (`v2/escudo.gd`, `_estilo_de`). Os centros dos pedaços e os tempos da
animação ficam em `dados/v2_secundario.json > escudo > visual`; se mudar a arte, rode o script de novo e cole os centros novos lá.
A animação (erguer, tremer ao aparar, rachar, quebrar em 4 pedaços e voltar reforjado) é toda em código, em `v2/escudo.gd`.
