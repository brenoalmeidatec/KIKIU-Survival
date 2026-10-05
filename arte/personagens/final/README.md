# Personagens: arte final

São 8 personagens, cada um com uma pasta: `nicao`, `lucas`, `joao`, `matheus`, `beto`, `lukako`, `fabio` e `breno`.
Todos têm o mesmo estilo e usam a farda azul da Cairu. Os scripts que geram a arte ficam em `../_fonte/final/`: `final2.py` e `rig.py` fazem corpo, andar e poses, `rostos7.py` faz o rosto de diálogo a partir da foto (com `marcos.py`, que acha olhos, boca e queixo na foto) e `acoes.py` faz as animações de corpo inteiro. As versões anteriores estão guardadas em `../final_v1/` a `../final_v4/`. A pele dos bonecos usa o mesmo tom medido na foto de cada um (`pele.json`).

## Arquivos de cada personagem

| arquivo | tamanho | conteúdo |
|---|---|---|
| `andando.png` | 176x240 | 4x4 quadros de 44x60. As linhas são baixo, esquerda, direita e cima. As colunas são parado, passo A, passo B e passagem. Usa o mesmo CICLO [1,3,2,3] a 8 fps e o mesmo offset (-22,-58) de hoje, com os pés em y=58. |
| `cena.png` | 2700x140 | 27 quadros de 100x140 numa linha, na ordem `QUADROS` do jogo (idle_c ... wave_b). O corpo inteiro fica com os pés embaixo. |
| `rosto_hd.png` | 2808x104 | **recomendado**: 27 quadros de 104x104 na ordem `QUADROS`. É a própria foto pixelada, com cabeça, pescoço e ombros na farda. Desenhe em escala 1 com `Rect2(q*104, 0, 104, 104)`: ocupa o mesmo espaço na tela que o `rosto.png` em escala 2, com o dobro de detalhe. |
| `rosto.png` | 1404x52 | **novo**: 27 quadros de 52x52 na mesma ordem `QUADROS`. Mesmo rosto do `rosto_hd.png`, reduzido para 52x52 (compatível com o jogo atual em escala 2). A boca abre baixando o queixo da foto, e os olhos fecham em `piscar` e na risada. |
| `andando_8.png` | 396x240 | **novo, opcional e mais fluido**: 9 colunas de 44x60, com parado e mais 8 quadros de andar (contato, desce, passagem e sobe, para cada perna). Mesmas linhas e mesmo offset do `andando.png`. |
| `acoes.png` | 512x896 | **novo**: animações de corpo inteiro, uma ação por linha (tabela abaixo). Quadros de 64x64, até 8 por linha. |
| `folha_completa.png` | 384x192 | Folha de referência com 12 colunas de 32x48 (parado 0-3, andando 4-11) e 4 direções. |

Na raiz da pasta, `previa_elenco.png` mostra os 8 lado a lado, `previa_animada.gif` mostra as ações e a fala em movimento, e `previa_acoes.png` mostra a folha de ações do Nicão com o nome de cada linha.

## Layout do `acoes.png`

Cada quadro tem 64x64. O pé fica no chão em y=61 e o corpo fica centrado em x=32, então o offset no Godot é `(-32, -61)`. As ações de lado olham para a **direita**, e o jogo espelha com `flip_h` para a esquerda. Nas ações `baixo` o personagem olha para a câmera, e nas ações `cima` ele fica de costas.

| linha | ação | vista | quadros | fps | repete |
|---|---|---|---|---|---|
| 0 | `abrir_porta_cima` | cima | 6 | 8 | não |
| 1 | `abrir_porta_lado` | lado | 6 | 8 | não |
| 2 | `cair` | lado | 8 | 10 | não |
| 3 | `caido` | lado | 4 | 4 | sim |
| 4 | `levantar` | lado | 6 | 8 | não |
| 5 | `soco` | lado | 6 | 12 | não |
| 6 | `empurrao` | lado | 6 | 10 | não |
| 7 | `apanhar` | lado | 6 | 10 | não |
| 8 | `correr` | lado | 8 | 12 | sim |
| 9 | `comemorar` | baixo | 6 | 8 | sim |
| 10 | `cocar_cabeca` | baixo | 4 | 6 | sim |
| 11 | `bracos_cruzados` | baixo | 4 | 4 | sim |
| 12 | `apontar` | lado | 4 | 6 | não |
| 13 | `assustado` | baixo | 4 | 10 | não |

Algumas observações:
- `cair` termina deitado de bruços e emenda em `caido`, que repete. Depois vem `levantar`. Nos quadros da queda, o corpo é centralizado no quadro, então o personagem pode deslizar um pouco para trás.
- `abrir_porta_cima` é para portas na parede de cima, com o personagem de costas. `abrir_porta_lado` é para portas na lateral. As duas terminam com o personagem dando um passo para dentro.
- `soco` e `empurrao` são de quem bate. `apanhar` é de quem leva o golpe: ele recua 4 px para trás.
- `correr` é um ciclo de 8 quadros, mais rápido que o andar.

## Como plugar no jogo

1. Copie `andando.png` e `cena.png` para `assets/personagens/<id>/`. Eles têm o mesmo formato dos arquivos atuais.
2. O rosto de diálogo **muda de fonte**. O corpo novo tem proporção realista, então o recorte antigo `Rect2(q*100+24, 0, 52, 52)` do `cena.png` não pega mais o rosto. Para corrigir, copie também `rosto.png` para `assets/personagens/<id>/` e, em `dialogo.gd`, use `rosto.png` com `Rect2(q*52, 0, 52, 52)`. A escala 2 continua igual, e `q` é o mesmo índice de `QUADROS`. Melhor ainda: use `rosto_hd.png` com `Rect2(q*104, 0, 104, 104)` em escala 1.
3. Para um andar mais fluido, use `andando_8.png` em vez de `andando.png`, com `hframes = 9`, `CICLO = [1,2,3,4,5,6,7,8]` a 10 fps e o quadro 0 para parado.
4. Os gestos aceitos no JSON continuam os mesmos: `idle`, `talk1`, `talk2`, `point`, `shrug`, `think`, `cross`, `wave` e `laugh`.
5. Para as ações, carregue `acoes.png` com `hframes = 8` e `vframes = 14`. Cada ação usa o quadro `linha*8 + i`, com a quantidade de quadros e o fps da tabela.

## acoes2.png (animações de detalhe)

Mesmo formato do `acoes.png`: quadros 64x64, 8 colunas, 17 linhas (512x1088). Pé em y=61, centro x=32, offset (-32,-61). Linhas "lado" olham para a direita (use `flip_h` para a esquerda). Linha = índice abaixo; quadros vazios no fim da linha ficam transparentes.

| linha | nome | vista | quadros | fps | repete |
|---|---|---|---|---|---|
| 0 | respirar | frente | 4 | 4 | sim |
| 1 | piscar | frente | 3 | 10 | não |
| 2 | olhar_lados | frente | 6 | 4 | não |
| 3 | bocejar | frente | 6 | 6 | não |
| 4 | sentar | lado | 4 | 8 | não |
| 5 | digitar | lado | 4 | 10 | sim |
| 6 | levantar_cadeira | lado | 4 | 8 | não |
| 7 | pegar_objeto | lado | 6 | 8 | não |
| 8 | beber | lado | 6 | 6 | não |
| 9 | rir_alto | frente | 4 | 10 | sim |
| 10 | chorar_de_rir | frente | 6 | 10 | sim |
| 11 | bravo | frente | 4 | 8 | sim |
| 12 | envergonhado | frente | 4 | 4 | sim |
| 13 | andar_de_costas | lado | 8 | 10 | sim |
| 14 | comemorar_lado | lado | 6 | 8 | sim |
| 15 | rir_lado | lado | 4 | 10 | sim |
| 16 | assustado_lado | lado | 4 | 10 | não |

Observações: a cadeira de escritório já vem desenhada nas linhas sentar/digitar/levantar_cadeira (não precisa de outro sprite). A caixa em pegar_objeto e o copo em beber também vêm no quadro. "andar_de_costas" anda para trás (recua) olhando para a direita: mova o personagem para a esquerda enquanto toca. Prévias: `previa_acoes2.png` e `previa_acoes2.gif`.

## rosto_gemini.png (retratos de diálogo novos, feitos a partir do Gemini)

Substituem os rostos feitos da foto. 12 quadros de 144x192 (3:4) lado a lado: 1728x192. Quadro q = `Rect2(q*144, 0, 144, 192)`. Olhos a ~42% da altura, mesmo enquadramento em todos os quadros de cada personagem.

| q | quadro | uso sugerido |
|---|---|---|
| 0 | frente, boca fechada | parado / entre sílabas |
| 1 | boca entreaberta | fala |
| 2 | boca aberta | fala (sílaba forte) |
| 3 | boca em "o" | fala / surpresa |
| 4 | sorrindo | fala alegre |
| 5 | cabeça inclinada (esq.) | fala com gesto |
| 6 | cabeça inclinada (dir.) | fala com gesto |
| 7 | três quartos (esq.) | virar para quem está à esquerda |
| 8 | três quartos (dir.) | virar para quem está à direita |
| 9 | piscando | piscar (3 a 5 s) |
| 10 | rindo | risada |
| 11 | olhando para cima | pensando |

Fala sugerida: alternar 0→1→2→1→3→1 (8 a 10 fps), com um ângulo (5, 6, 7 ou 8) segurado por algumas sílabas de vez em quando para a cabeça mexer; piscar com 9 por 1 quadro.

Notas: o Lucas não veio com inclinações nem com o três quartos para a direita no Gemini; q5/q6 são o quadro 1 girado e q8 é o q7 espelhado. Matheus e João vieram com 16 quadros: foram usados só os 12 desta tabela. Títulos, números e logos foram apagados; a camisa do Beto foi trocada pela camiseta azul lisa. Sem sobrenomes em nenhum arquivo.

`rosto_hd.png` (27 quadros, 104x104) e `rosto.png` (52x52) agora são gerados destes mesmos quadros, então o jogo atual já mostra os rostos novos sem mudar código. Os rostos antigos de foto ficaram em `personagens/final_v5_rostos_foto/`. Prévias: `previa_rostos_gemini.png` e `previa_rostos_gemini.gif`. Fonte: `_fonte/final/gemini.py`.

## NPCs: alunos/ e mauro/

`final/alunos/aluno1..aluno10/` e `final/mauro/` têm os mesmos arquivos e formatos dos personagens: `andando.png`, `andando_8.png`, `cena.png`, `acoes.png`, `acoes2.png` (sentar/digitar já com cadeira) e `folha_completa.png`. Alunos: 10 variações (meninos e meninas, cabelos curto, raspado, black, longo, rabo de cavalo, coque e boné, vários tons de pele), roupa comum, sem a farda azul e sem rosto de pessoa real. Não têm retrato de diálogo.

Seu Mauro (`mauro/`): baixinho (4 px mais baixo que os outros, pé no mesmo lugar, mesmo offset), careca com cabelo curto grisalho dos lados, bigode grisalho, pele morena (pela foto que o Breno mandou) e uniforme verde de limpeza. Extra `mauro/extras.png`, mesmo formato do acoes.png (64x64, 8 colunas, pé em y=61, offset (-32,-61), lado olhando para a direita):

| linha | nome | vista | quadros | fps | repete |
|---|---|---|---|---|---|
| 0 | varrendo | lado | 6 | 8 | sim |
| 1 | celular (olhando o celular, sorrindo, envergonhado, rindo) | frente | 6 | 4 | sim |
| 2 | parado_vassoura | lado | 4 | 3 | sim |
| 3 | tocando_violao (sentado num banquinho, banquinho e violão já no quadro, notinhas musicais) | lado | 6 | 6 | sim |
| 4 | chupando_cana (em pé, cana na boca, mastigando) | lado | 6 | 5 | sim |

Prévia: `final/previa_npcs.png` e `final/previa_mauro_violao_cana.png`. Fonte: `_fonte/final/npc.py`. Seu Mauro não tem rosto de diálogo (decisão do Breno).
