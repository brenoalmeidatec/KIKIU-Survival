# Laboratório: planta proposta (18/10/2026)

Desenho de um agente (Opus) a pedido do Alisson ("não dá pra seguir uma lógica de arrumação e disposição de objetos?"). Implementada no PR #324 (veja "Como ficou" no fim): o gerador `fonte_arte/mapas_v2/def_laboratorio.py` monta as 9 salas por receita.

**Planta lógica do Laboratório: proposta só de desenho, nenhum arquivo foi editado.**

O mapa tem 2880×1620 e a área andável vai de 150 a 2730 em x e de 150 a 1470 em y. A bagunça vem de três blocos de `fonte_arte/mapas_v2/def_laboratorio.py` (linhas 224–496):

- **Objetos soltos:** o laço `soltos` espalha 26 caixas, barris, mesas, pilares e armários em posições sorteadas pelo miolo, com só `livre()` como regra. São justamente as peças isoladas que aparecem no print 6 (barril, armário e mesa no meio do nada).
- **Manchas:** são 95 sorteadas no mapa inteiro. O `if/else` que testa o retângulo `prib` faz a mesma coisa nos dois ramos, então hoje ele não tem efeito nenhum.
- **Áreas sem sala:** as oito áreas têm pontos de âncora fixos, mas não têm paredes em volta. Só "triagem" e "operações" ganham um trecho de muro. O resultado são ilhas de objetos sobre um piso contínuo, e o olho não percebe sala nenhuma.

## Planta (coordenadas em px do mapa)

A ideia é uma grade de 3×3 salas separadas por **dois corredores horizontais e dois verticais**, todos com **160 px de largura** (o herói tem raio de ~14 px e um grupo de 4–5 monstros passa lado a lado):

- **Corredor horizontal norte:** y 560–720
- **Corredor horizontal sul:** y 1000–1160
- **Corredor vertical oeste:** x 1000–1160
- **Corredor vertical leste:** x 1720–1880

Assim os 8 nascimentos de monstros atuais caem dentro dos corredores ou na boca deles: (620,560), (2330,560), (540,1060), (2360,1060), (1130,620), (1760,1060), (940,1000) e (1960,650). Os dois últimos ficam a 60–80 px da quina, então o círculo `raio+vaga` deles vira **zona proibida** para objetos.

| Sala | Retângulo (x0,y0–x1,y1) | Conteúdo e arrumação |
|---|---|---|
| NO **Servidores** | 150,150–1000,560 | Duas fileiras de `rack_servidores` com passo de 90, encostadas na parede norte (y≈200) e numa fileira de costas a y≈380 (corredor frio entre elas). Consoles nas pontas da fileira. Cabos e grade de dreno no corredor entre os racks. |
| N **Comando** | 1160,150–1720,560 | Arco de `console` voltado para o sul (5 a 7 peças, a y≈260, centrado em x 1440), uma `mesa_lab` com papéis atrás e luz `tela_ciano` em cada console. |
| NE **Espécimes** | 1880,150–2730,560 | Fileira de `tanque_alto` com passo de 170 a y≈260 (um quebrado com poça de ácido embaixo). Gaiolas em fila a y≈450 encostadas na parede sul da sala, macas em par. Sangue só embaixo das macas e gaiolas. |
| O **Depósito** | 150,720–1000,1000 | Blocos 2×3 de `caixa_empilhada`/`caixa_suprimentos` encostados na parede oeste (x≈220–400). Barris agrupados em quadrado de 2×2 ou 3×2 sobre `faixa_perigo`. Armários em fileira na parede norte. Óleo e papéis só perto dos barris e caixas. |
| Centro **Contenção** | 1160,720–1720,1000 | Selo central, 4 tanques em quadrado simétrico (que já existe) e consoles alinhados. O herói nasce em (1430,808). As faixas de perigo marcam as bocas das 4 portas. |
| L **Criogenia** | 1880,720–2730,1000 | `capsula_cripto` em fileira de 5 com passo de 125, encostada na parede norte da sala (y≈760). Bancadas em ilha de 2 a y≈920. Canos na parede leste. |
| SO **Geradores** | 150,1160–1000,1470 | 2 a 3 `gerador` alinhados a y≈1300 com `faixa_perigo_g` embaixo de cada um. Canos encostados na parede oeste, barris em grupo num canto. Óleo só junto dos geradores. |
| S **Pesquisa** | 1160,1160–1720,1470 | Ilhas de bancadas: 2 ilhas de 2 `bancada_lab` de costas (x 1300 e 1580, y≈1300), macas em fileira encostadas na parede sul. Papéis e cacos ao lado das bancadas. |
| SE **Ruínas** | 1880,1160–2730,1470 | Única sala "quebrada": paredes com falhas (`parede_lab_c`), tanques e consoles quebrados. Mesmo aqui os objetos ficam na grade, só faltam peças. Rachaduras e ácido concentrados nela. |

## Paredes e portas

- **Onde ficam as paredes:** cada sala é cercada por `parede_lab_a/b` (passo de 92, pé na linha do limite), exceto onde a sala encosta na borda do mapa, que já é fechada.
- **Portas:** cada lado de sala virado para um corredor tem **pelo menos uma abertura de 2 módulos (~190 px)**. Toda sala tem **no mínimo 2 aberturas em lados diferentes**, para não existir beco. A contenção central tem 4 aberturas, uma por lado. Um `porta_blindada` (de enfeite) ladeia cada abertura.
- **Esquinas:** um `pilar_lab` em cada cruzamento de corredor (quina das paredes), nunca dentro do corredor.
- **Corredores:** ficam vazios de objetos sólidos, com `faixa_perigo_p` nas bocas das portas, `seta_chao` apontando para a contenção e `lampada_emergencia` **encostada na parede** com passo fixo de 320 px (ritmo de luz). Os cabos correm ao longo da parede.

## Regras de posicionamento (para o gerador)

1. **Grade:** todo objeto sólido cai numa grade de 32 px. As fileiras usam o passo do tipo (rack 90, tanque 170, cápsula 125, parede 92).
2. **Encostar:** um objeto "alto" (rack, armário, tanque, cápsula, cano) só existe encostado numa parede da sala (a 40–60 px da linha). Ilha (bancada, mesa, maca) só no miolo da sala, em par ou em fileira, com ≥ 96 px de folga para as paredes.
3. **Corredores sem sólidos:** zero objeto sólido nos corredores e nos círculos de nascimento (`raio+vaga`). Entulho sem colisão (`cacos`, `lixo`) só nos cantos das salas.
4. **Decalques com dono:** todo decalque tem um objeto ou função por perto. Poça de ácido fica a até 80 px de tanque ou barril, óleo perto de gerador, barril ou cano, papéis junto de mesa, bancada ou console, sangue junto de maca, gaiola ou `restos_cobaia`. Cabo liga console a rack ou gerador, rachadura vai em ruína ou corredor. **Remove-se o laço das 95 manchas aleatórias.** Nos corredores ficam só, no máximo, 1 mancha por 300 px.
5. **Simetria por sala:** cada sala é montada a partir de uma "receita" (uma função com espelho opcional), então ruído aleatório só existe em jitter de ±4 px e na escolha da variante (a/b/c).

## Desempenho

O total de objetos e decalques fica igual ou menor. Hoje são 376 objetos, e a planta usa cerca de 70 paredes internas a mais e cerca de 26 soltos a menos. Para não passar, as paredes internas podem ser **contadas no lugar** de parte das fileiras de borda (sul e leste têm duas fileiras cada, e dá para tirar uma). Decalques: de ~210 para ~150.

## Como implementar

Recomendo **mudar o gerador, não o JSON**. Assim o resultado fica reproduzível e o `_ajuda` continua verdadeiro. Os passos:

1. Em `def_laboratorio.py`, trocar o bloco de "áreas ao redor" por uma tabela `SALAS = {nome: (x0,y0,x1,y1, portas, receita)}` e uma função `paredes_da_sala(sala)`, que coloca módulos de 92 px no perímetro pulando as portas (lista de lados mais o centro da abertura).
2. Escrever uma função `receita_<sala>(x0,y0,x1,y1)` para cada sala, usando os helpers `fileira(nome, x, y, n, passo)` e `ilha(...)` e decalques relativos a cada objeto (`perto(obj, tipo)`).
3. Apagar o laço `soltos` e o laço das 95 manchas. Pôr no lugar o ritmo dos corredores (luzes, faixas e setas com passo fixo).
4. Manter a borda, os temas, a semente, `nascimento` e `tam`. Regerar com `python jogos/hordas/fonte_arte/gerar_v2_mapas.py laboratorio --previa ...` e conferir a prévia.
5. Validar no Godot com o `v2/passagens.gd`, com `relatorio()` a partir de (1430,808) e o centro dos 8 nascimentos. A conferência tem três partes: `bolsoes` vazio, `becos` sem profundidade maior que 6 células, todos os pontos alcançáveis. A seguir vêm as fotos reais em `--roteiro`, olhando as 9 salas.

Editar o JSON à mão serviria só como teste rápido de uma sala. Ele seria sobrescrito na próxima regeração.

## Como ficou (PR #324, 18/10/2026)

Implementado em `def_laboratorio.py` (tabelas `COL`, `LIN`, `SALAS`, `PAREDES_S`, `ABERTURA_V`, `QUINA` e uma receita por sala dentro de `montar`) e conferido com
`v2/passagens.gd` (`testes/v2_mapas`: corredores livres de ponta a ponta, centro das 9 salas alcançável, sem beco) e com fotos reais das 9 salas. Regerar:
`python jogos/hordas/fonte_arte/gerar_v2_mapas.py laboratorio --so-mapa` (reaproveita o atlas e a colisão de `assets/v2/mapas/laboratorio/`, não precisa do Blender).
A colisão é por TIPO (atlas), então mexer a posição de um objeto aqui move o desenho e a colisão juntos.

Onde o desenho se afastou da planta (e por quê):

- **Paredes só na frente das salas do norte e do meio** (y=560 e y=1000, com portas de 190 a 240 px), não nos quatro lados. A câmera olha de frente: uma parede esconde
  os 85 px que ficam atrás dela. Na frente de cima da sala essa faixa cai dentro da sala; uma parede em y=720 ou y=1160 esconderia o corredor. Os lados de cima das salas
  do meio e do sul ficam abertos para o corredor, definidos pelo próprio equipamento da sala.
- **Lados verticais abertos**: não existe sprite de parede vertical (os módulos `parede_lab` são de frente). Cada lado que dá para V1/V2 tem só uma coluna curta de equipamento
  no canto (`QUINA`) e uma abertura larga no meio (190 a 320 px).
- **Orçamento**: 363 objetos (era 376) e 119 decalques (era 209). A borda perdeu uma fileira no sul, metade da fileira de trás no norte e a coluna de dentro no oeste e no leste
  saiu da faixa andável (uma peça que cruza o limite andável faz o clamp empurrar o corpo de volta e ele entala).
- **Quinas e lâmpadas**: pilar nas quinas das paredes (4 px dentro do corredor) e lâmpadas de emergência coladas na parede de frente, sem vão (um vão de ~10 px prende o corpo).
- **Regra de encostar**: peça encostada no limite andável deixa 4 px de folga (N), 7,5 px (O/L) ou cruza 3 px (S), para não criar nicho de uma célula nem forma que o corpo não resolve.
