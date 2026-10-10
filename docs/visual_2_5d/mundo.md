# Mundo 2.5D: câmera, luz, efeitos, monstros, cenário e desempenho

Análise da referência `docs/imagens/referencia_2_5d.webp` (1672x941), comparada com o jogo de hoje. Documento de análise: nada de código foi alterado. Os números de imagem são **estimativas visuais** sobre uma imagem gerada por IA. Sem grade de pixel exata, a precisão é de cerca de ±10% nas medidas e de ±1 px no tamanho do pixel de arte. Os recortes ampliados ficaram em `scratchpad/ref_mundo/` (fora do repositório).

Convenção: "px ref" é pixel da imagem de referência (941 px de altura). "% tela" é a altura do objeto dividida por 941.

---

## 1. Câmera e escala

### Medidas na referência

| Objeto | Altura aprox. (px ref) | % da altura da tela | Observação |
|---|---|---|---|
| Herói (Hazaki) | ~74 | ~7,9% | no meio da tela, com capa e espada |
| Monstro comum (esqueleto, zumbi) no meio da tela | 55 a 65 | 6 a 7% | |
| Monstro comum no primeiro plano (embaixo) | 75 a 85 | 8 a 9% | mesma classe, perspectiva de perto |
| Monstro grande (cão ou brutamontes escuro, ex.: x 1415 a 1497, y 657 a 745) | ~88 | ~9,4% | |
| Elite (brutamontes roxo do topo, com barra de vida) | ~120 | ~12,8% | barra de ~55 a 75 px de largura |

**Tamanho do pixel de arte:** ampliando 10x o rosto do herói, os blocos de pixel medem **2 a 3 px** da imagem. Tomando 2,5 px como valor central, a tela inteira (941 px) corresponde a cerca de **375 "linhas" de arte**. Ou seja, a densidade de pixel da referência fica perto da do jogo de hoje (640x360 em tela de 1080p usa escala 3, ou seja 3 px por pixel de arte). A diferença de fundo não está na densidade do pixel, e sim no tamanho relativo dos personagens.

### Comparação com o jogo de hoje

Hoje o herói tem quadro de 44x60 px em uma viewport de 640x360, com câmera de zoom 1 (padrão do `Camera2D` em `arena.gd`). Ou seja, ele ocupa **60/360 = 16,7%** da altura. A referência mostra o herói com **~8%**, ou seja, **metade** da altura relativa. Isso significa que a referência enxerga cerca de **o dobro de mundo na vertical** com a mesma densidade de pixel. Ou o herói passa a ser menor em pixels de arte, ou a resolução do mundo aumenta.

### Conta do que cada resolução base exige

Para o herói ficar com 7,9% da tela, a altura dele em pixels de arte precisa ser `0,079 x altura_base`:

| Base (altura) | Herói em px de arte para 8% | Quadro aprox. do herói | Monstro comum (6,5%) | Monstro grande (9,4%) | Elite (12,8%) | Escala 1080p (px por pixel de arte) | Custo de preenchimento vs 640x360 |
|---|---|---|---|---|---|---|---|
| 640x360 | ~28 | 22x30 (sprites pela metade) | ~23 | ~34 | ~46 | 3 (inteiro) | 1x (230 mil px) |
| **960x540** | **~43** | **32x44** (sprites x0,73) | **~35** | **~50** | **~69** | **2 (inteiro)** | **2,25x (518 mil px)** |
| 1280x720 | ~57 | 44x60 (arte atual, sem mudar) | ~46 | ~68 | ~92 | 1,5 (fracionário) | 4x (922 mil px) |

Leitura da tabela: 1280x720 mantém a arte atual sem retrabalho, mas a arte fica com pixel fino (1,5 px em 1080p), diferente da referência, que tem pixel grosso. 640x360 casa com a densidade de pixel da referência, mas obriga a redesenhar todos os sprites pela metade e perde detalhe. 960x540 fica no meio: pixel de 2 px em 1080p, escala inteira, e sprites um pouco menores.

### Recomendação: base **960x540**

- **Por que:** pixel perto da referência (2 px em 1080p), escala inteira em 1080p, herói na proporção de ~8%, e custo de preenchimento de 2,25x sobre o atual. Não é o caminho mais barato em GPU, mas é o que mais se aproxima da imagem sem apelar para 4x.
- **Prós:** atinge a proporção de herói e de monstros da referência; a arte fica mais nítida em telas grandes; sobra área para mais mundo, que é o ponto da 2.5D.
- **Contras:** 2,25x de preenchimento de tela em uma GPU que já é o gargalo (ver seção 6); refazer quadros de heróis e monstros (folhas de 5 vistas) em cerca de 0,73x; refazer as dimensões dos azulejos de chão e dos enfeites; o HUD fica com mais área para cobrir. Na escala de 720p a conta vira 1,33, fracionária, então o pixel fica irregular nessa resolução.
- **Caminho de transição (sugestão):** a resolução e a escala dos sprites são coisas separadas. Dá para trocar a base para 960x540 e manter os sprites atuais em um primeiro momento, testando a proporção com `Camera2D.zoom`. Só se ganha a proporção de 8% de fato quando os quadros forem redesenhados. Melhor marcar isso como uma etapa no plano da V1.

### Por que o Blender e a câmera precisam mudar junto

O gerador (`fonte_arte/modelos3d/pixel3d.py`, função `camera(elevacao_graus=32.0, ...)`) usa **elevação de 32 graus** e câmera ortográfica. `monstros.py` chama essa câmera com `escala = max(W, H) / PPU`. Mudar o tamanho do quadro sem mudar essa escala só corta a figura, então para reduzir o herói dentro do mesmo quadro é preciso aumentar `ortho_scale` (ou reduzir `PPU`).

### Inclinação da câmera (3/4)

Medida pela elipse do anel do portal (cerca de 215 x 160 px ref, razão h/w de 0,75 a 0,78). Um círculo no chão visto de uma elevação `θ` vira elipse com razão `sen(θ)`, o que dá **θ de cerca de 50 graus**. O gerador usa **32 graus**. A referência é mais "de cima" do que o pipeline atual. Isso é uma diferença real e precisa de decisão: ou se muda a elevação para cerca de 45 a 50 graus para chão e sprites juntos, ou se mantém 32 graus nos sprites e se usa 50 graus só no chão (o que cria mismatch entre sombra e pé). Recomendo testar 45 graus nos dois e ver a leitura do herói.

### Camadas de profundidade

- **Primeiro plano (bordas):** copas de árvore e troncos escuros nas bordas esquerda e superior, ruínas altas e folhagem na direita, e um pouco de mato embaixo. Ocupa de 12 a 18% da tela. Precisa de ordenação por Y (`y_sort`) e de transparência quando passa perto do herói, para o herói e os objetivos não sumirem. Nesse ponto a regra da legibilidade (README, regra 4) manda.
- **Chão (meio):** azulejos de terra, pedra, musgo, poças e pontes. Lugar de quase todos os monstros e do herói. A luz se acumula aqui.
- **Fundo:** árvores ao longe, névoa e as ruínas do portal, com contraste menor e tons mais frios (perspectiva aérea). O portal fica no meio do fundo, com brilho próprio.

---

## 2. Luz

### Inventário das fontes de luz (cor = amostra saturada da referência; raio = estimativa)

| Fonte | Posição aprox. (px ref) | Cor (hex, núcleo/halo) | Alcance aprox. (px ref) | O que ilumina |
|---|---|---|---|---|
| Lanterna pendurada do topo | (492, 162) | `#fec613` / `#ff9f2e` | ~45 | árvores, chão e monstros em volta |
| Lanterna da esquerda | (110, 505) | `#f68b0d` | ~35 | canto esquerdo |
| Lanterna da direita | (1240, 322) | `#ffa02e` | ~35 | ruínas da direita |
| Lanterna do canto inferior direito | (1462, 650) | `#ffa02e` | ~30 | ponte e mato |
| Tochas do portal | (1345, 535) e (1448, 492) | `#fba537` | ~40 cada | o chão do portal |
| Braseiro da ponte | (1075, 800) | `#fa9d06` | ~40 | a ponte e a água |
| Portal (núcleo e feixe) | (1333, 430) | `#d221ff` (feixe), `#ae43f9` (anel) | ~130 no chão, feixe de ~250 px de altura | o chão roxo, as ruínas, os monstros perto |
| Arco do golpe do herói | (~820 a 915, 400 a 520) | `#3bc5f6` / `#e3fafa` (núcleo) | ~75 (um raio de herói) | o herói e o chão ao redor |
| Poça de luz do herói | sob o herói | `#6fb8e8` | ~70 | o herói e os monstros mais próximos |
| Relâmpagos (cadeias) | (600 a 700, 250 a 335), (495, 522) | `#258bff` / `#22a0fe` | ~20 a 25 por trecho | os monstros atingidos |
| Explosões de fogo | (975, 380), (1030, 410), (1020, 447), (600, 590) | `#f7c51e` / `#fde42d` | ~40 a 50 cada | chão e monstros em volta |
| Nuvens de veneno | (590, 430), (856, 255) | `#b0f305` / `#7ff46c` | ~50 e ~35 | chão e monstros em volta |
| Orbes arcanos (roxo) | (1028, 585), (1092, 718) | `#d812ff` | ~25 cada | pouco, quase só o próprio orbe |
| Raio laser verde | (1240, 622) | `#56fa29` | ~25 | pouco |
| Brilho do rio | (1200 a 1400, 760 a 880) | `#7ac0ff` | faixa de ~150 | a margem do rio |

Os monstros não emitem luz própria na referência, mas os olhos são pontos vermelhos (`#ff3a2a`), com brilho aditivo de 2 a 3 px.

### Escuro ambiente

Amostras de chão sem luz direta: `#0b1f14` a `#102711` (verde quase preto). A luminância mediana do quadro inteiro é cerca de **41 de 255**, e os cantos ficam quase pretos (mediana de 4 a 13). Ou seja: a cena é escura, com vinheta forte, e a luz cria quase todo o contraste. Proposta para o `CanvasModulate` do andar noturno: cor de **`#1c2a24` a `#223029`** (verde-azulado frio, cerca de 0,2 a 0,25 de intensidade). Nos andares de horror, a luz deve ficar mais fraca, como hoje em `chao.gd` (`_aplicar_luz`).

### Como isso vira Godot

- **Luz baked do cenário:** o `cenarios.py` já assa a luz das lanternas e tochas no atlas de enfeites, com `brilha()` e halos (`cenario.json`). Serve para as lanternas e braseiros **fixos**, sem custo dinâmico. Continua sendo a melhor opção para tudo que não se mexe.
- **Luz dinâmica (`PointLight2D`):** só para o que se mexe: herói (arco e poça), portal, magias (roxo e fogo) e explosões. Poucas, em torno de 3 a 6 por quadro. Usar `blend_mode = ADD` e textura radial, o mesmo esquema que o `efeitos.gd` já faz com `_tex_luz`.
- **CanvasModulate:** já existe (`chao.gd`, `_ambiente`). Cor do andar como acima.
- **Normal map:** o protótipo da PR #148 (`alisson/prototipo-luz-2d`) gera normais a partir do próprio gerador (`prototipos/luz/gerar_normais.py`) para o Hazaki e o cão de ossos. Resultado medido na própria PR: o efeito ficou **sutil**. O sprite já tem sombra assada (luz de cima e da esquerda), então parte do volume aparece duas vezes. O próprio Alisson sugeriu, como próximo passo, uma base de albedo sem sombreamento assado antes de julgar. Recomendo seguir essa ordem.
- **Sombra projetada:** a PR não testou. Não recomendo `LightOccluder2D` na horda; custo alto.

---

## 3. Efeitos (VFX)

| Efeito | Cores (ref) | Tamanho aprox. (px ref) | O que já existe no jogo | Diferença |
|---|---|---|---|---|
| Arco do golpe do herói | `#3bc5f6`, núcleo `#e3fafa` | ~150 x 120 (raio ~75, achatado) | `efeitos.gd` `corte()`, com `CORTE_ACHATA = 0.8` e `dur = 0.16` | A forma já bate. Falta brilho aditivo mais forte e cauda mais longa. |
| Raios em cadeia | `#258bff`, miolo branco | trechos de 120 a 150, 2 a 3 ramos | `armas/raio.gd`, `elemental.gd` (linhas 119 a 120: `COR.raio` com linha de 3 px e miolo de 1 px) | A cor do jogo é pálida: `COR.raio = (0,6; 0,85; 1,0)`. A referência é mais saturada. |
| Explosão de fogo | `#f7c51e`, `#fde42d`, anel `#ff7a1a` | 60 a 70 de diâmetro | `elemental.gd` (linhas 105 a 106: círculo `(1, 0,45, 0,1)` e arco `(1, 0,85, 0,4)`), `COR.fogo = (1,0; 0,5; 0,15)` | A referência é mais amarela e mais brilhante. Aumentar o miolo e a luz. |
| Nuvem de veneno | `#b0f305`, `#7ff46c` | 60 a 80 de diâmetro, com bolhas | `elementos.gd` `tinta()` e `poça` em `armas` | A cor do jogo (`0,7; 1,0; 0,6`) é pálida. Referência mais verde-elétrico. |
| Orbes arcanos | `#d812ff`, miolo quase branco | 20 a 25, com rastro de ~2 a 3 px | `armas/runas.gd` e projéteis | Confirmar a cor roxa; a referência é mais saturada. |
| Feixe do portal | `#d221ff`, miolo branco | ~8 a 10 px de largura por ~250 px de altura | não verificado (portal está em `camada_objetivos.gd` e `arena.gd`) | Não há feixe vertical conhecido. Confirmar. |
| Rastro de tiro (laser verde, magenta) | `#56fa29`, `#c846c8` | linhas de 40 a 60 | `armas/pistolas.gd` (rastro) | Compatível. |
| Brasas e fagulhas | laranja `2 x 2` px, subindo | pontos de 2 a 3 px | `efeitos.gd` (brasas e `faiscas`, teto de 260) | Compatível. |
| Números de dano | branco (normal), amarelo-laranja (fogo), vermelho (recebido) | altura ~14 px ref (fonte ~8 px no jogo) | `efeitos.gd` `numero()` (`tam` 8 normal, 16 crítico, cor de crítico `(1; 0,9; 0,3)`) | Compatível em cor. Verificar o tamanho com o HUD novo. |

Observação importante: quase todos os efeitos já têm estrutura no jogo. O trabalho é de **cor saturada**, **brilho aditivo** e **halo** (que o `efeitos.gd` já limita a 96 luzes por quadro, `MAX_LUZES`, ajustado pelo perfil em `qualidade.json`).

---

## 4. Monstros e heróis

### Silhuetas e variedade

Na referência vê-se pelo menos **8 famílias de silhueta** nas hordas: esqueleto de armadura azul (elite), esqueleto cinza-branco, zumbi verde-lodo (um deles com manchas), carniçal de capa vermelho-marrom, cão ou lobo quadrúpede escuro, figura encapuzada com manto, brutamontes roxo-escuro (elite do topo), espectro roxo e pequenas gosmas verdes. A cor é o principal elemento de variação entre quem tem a mesma forma (vermelho, verde, azul, roxo).

Para comparar com o jogo: as folhas de `monstros.py` e `horror.py` têm paleta fixa por monstro (`C("6c8068")` para a pele apodrecida, `C("3c3552")` para o manto roxo-noite, e assim por diante). Ou seja, o pipeline tem cor por monstro, mas **a variedade de silhueta e de manto** tem que vir de peças ou de variantes de semente. Conferir a quantidade de monstros em `dados/inimigos.json` antes de dizer que falta variedade.

### Olhos acesos

Quase todos os monstros da referência têm **olhos vermelhos** (`#ff3a2a`), e alguns têm âmbar. Isso confirma a regra 4 do README. O gerador já tem `olho_r` (brasa), `olho_f` (âmbar) e `olho_v` (verde-pálido) como `material_emissao`, mas o brilho só aparece se a cor estiver na paleta passada ao `pixelar` (nota de `monstros.py`). Mudança sugerida: um pixel de halo fora do olho, com cor mais clara, para o olho "acender" no escuro.

### Barras de vida

Na referência, as barras vermelhas (~55 a 75 px de largura, 3 a 4 px de altura, com contorno escuro) aparecem em **vários** monstros, não só em elites. O README (regra 4) diz que só elite e chefe têm barra. Isso é uma dúvida (ver seção final). Se a regra for só elite, a referência é mais livre ou mostra mais elites do que o esperado.

### Contorno, rim light e sombra no chão

- **Contorno:** a referência tem contorno escuro de 1 px, como o `pixelar(contorno=True)` do jogo.
- **Luz de borda:** a referência mostra **borda clara do lado das luzes** (azul do golpe, laranja das tochas, roxo do portal). Hoje o `pixelar` tem `luz_borda=True`, que sobe um degrau de rampa no lado da luz (fixo, sem cor da luz). Proposta: borda colorida com a cor da luz mais próxima, em vez de um degrau de cinza.
- **Sombra no chão:** manchas escuras e macias embaixo de cada monstro. O jogo tem a sombra de contato (mancha no pé) e a sombra projetada (`sombra_projetada`, só em alta). Recomendo manter a de contato em todos os perfis.

### Densidade de detalhe

A referência tem **mais tons por material** do que o jogo: a armadura e a capa têm 4 a 5 tons, e o jogo usa 3 (`faixas=(0.35, 0.62, 1.0)`). Para heróis, 4 tons; para monstros, 3 tons com um brilho pontual de 1 px, que dá sensação de metal e de pele molhada.

### O que muda no gerador do Blender

1. **Elevação da câmera:** de 32 para cerca de 45 a 50 graus (`pixel3d.camera`), aplicada a todas as folhas e aos cenários ao mesmo tempo, para o pé e a sombra baterem com o chão.
2. **Escala:** reduzir o herói e os monstros para a proporção da seção 1 (`ortho_scale` ou `PPU`), mantendo o pé na mesma linha.
3. **Luz de borda colorida** no `pixelar`, com a cor da luz do cenário, em vez do degrau fixo.
4. **Halo do olho:** um pixel mais claro ao redor de `olho_r` e `olho_f`.
5. **Tons:** 4 faixas para heróis e 3 para monstros, com brilho de 1 px.
6. **Variantes:** peças e mantos sorteados pela semente (capa, capuz, armadura, ombreira), para aumentar a variedade sem nova folha inteira.
7. **Normal map:** só para herói e elites (ver seção 2). Não para toda a horda.

---

## 5. Cenário

### Elementos da referência

- **Árvores nas bordas (moldura):** copas escuras no canto superior esquerdo e na direita, com troncos e musgo. Plano da frente, com transparência perto do herói.
- **Ruínas e pilares:** pilares de pedra com musgo e hera (direita, em frente ao portal), arcos altos no topo direito, bloco de pedra com lanterna.
- **Ponte de madeira:** diagonal, no canto inferior direito, com braseiro na ponta.
- **Rio:** canto inferior direito, com brilho azul-claro na margem (`#7ac0ff`) e pedras.
- **Chão de pedra e terra:** lajes escuras com fendas, terra batida e musgo, sem azulejo aparente.
- **Folhagem:** arbustos e mato escuro embaixo e nas bordas, com flores de luz pontuais (amarelo e verde).
- **Portal:** círculo de runas roxo no chão, com feixe vertical e tochas em volta.

### Como entra no pipeline

- **`cenarios.py`** já tem: `piso_floresta` e `piso_floresta_var` (terra, capim, musgo, pedrinhas, poça com brilho), `coluna_quebrada`, `arvore_viva`, `arvore_morta`, `arvore_pantano`, `barril_fogo`, `braseiro_baixo`, `pilha_pedras`, `vela_chao`, `cranio_vela`. Ou seja, boa parte dos enfeites já existe.
- **Não encontrei** no `cenarios.py` nem em `floresta.py`: ponte de madeira, rio com margem brilhante e feixe do portal. Esses três precisam de gerador novo (ou de função nova no `cenarios.py`).
- **`cenario.gd`** coloca enfeites por célula, com `densidade` (0,3 por padrão, em `dados/cenarios.json`) e `fixos` (postes e similares). Serve para ruínas e braseiros.
- **`chao.gd`** monta o chão com `ESCALA = 2.0`, `BLOCO = 256` (azulejo de 256 px na tela) e `CEL_DECO = 150`. Com a base 960x540 e os sprites a 0,73x, o azulejo precisa ser redimensionado (algo como `BLOCO` de 192 ou 320, conforme a conta de escala). Não é só trocar a constante, porque o `cenario.json` guarda o pé dos enfeites em px.
- **Luz do cenário:** os halos ficam em `_luzes` (blend ADD, `chao.gd`), com a poça embaixo da lâmpada. Já é a infraestrutura certa para lanternas e braseiros fixos.
- **Rio e ponte:** a ponte e o rio mudam a planta do mapa (são obstáculos ou caminho). Isso passa por `dados/cenarios.json`, não só por arte. Vale dividir a tarefa.

---

## 6. Desempenho

### O que é caro (em ordem, com a evidência que temos)

1. **Preenchimento de tela inteira por quadro:** `CanvasModulate`, halos aditivos, sombras, névoa, vinheta e o shader de escuridão. Cada um toca todos os pixels da viewport. Custo proporcional à resolução base. É o motivo principal da escolha de 960x540 ser cara.
2. **Escuridão do horror (`escuridao.gd`):** o parâmetro `escuro_halo` faz até 8 leituras da textura da tela inteira por pixel (`qualidade.json`). Pela leitura do código, é o candidato mais caro por pixel, mas não foi medido. Recomendo medir antes de cortar.
3. **Halos aditivos (`efeitos.gd`):** até `MAX_LUZES = 96` por quadro, cada um um `draw_texture_rect`. Em baixa, cai para 24 ou menos (`efe_luzes`).
4. **Luz dinâmica com normal map:** medido na PR #148 (no PC do Alisson, janela 1280x720): **1 luz sem sprites extras, 1.423 a 1.554 fps; 1 luz com 300 sprites com normal, 678 fps**. Ou seja, quase metade. Com 3 luzes e 300 sprites, 432 fps. Por isso, normal map só para herói e elite, e a horda sem normal.
5. **CPU da horda:** a horda inteira usa MultiMesh (`inimigos.gd`, `_mm_som` e `_mm_spr`). Medido no LOGBOOK, com 500 vivos, cerca de 8 ms de CPU (headless). Não é o gargalo principal, mas tem teto: `limite_vivos` (500 / 350 / 250, `qualidade.json`).
6. **Partículas e projéteis:** já têm teto (`mortes_part`, `elem_part`, `efe_particulas`). Baixo risco.

Observação do LOGBOOK: o Breno relatou cerca de 15 fps numa RTX 3060 com a horda cheia, enquanto o headless mediu cerca de 8 ms de CPU por quadro. A hipótese registrada lá é **GPU ou preenchimento** (halos aditivos, sombras), e não CPU. Isso reforça o item 1 e 2 acima como os principais alvos.

### Escalonamento por perfil

Os perfis atuais em `dados/qualidade.json` se chamam `alta`, `media` e `baixa`. O README fala em Baixo, Médio e Alto. Assumi que é o mesmo conjunto (ver dúvidas). Proposta:

| Recurso | Baixo (i5-3470 e vídeo fraco) | Médio | Alto |
|---|---|---|---|
| Resolução base | 960x540 se o teste passar; senão 640x360 com a arte da referência ajustada | 960x540 | 960x540 ou 1280x720 (decidir com medição) |
| Vinheta | desligada | ligada | ligada |
| Halos aditivos (`efe_luzes`) | baixo (valor a conferir em `qualidade.json`, perto de 24) | 0,5 (~48) | 1,0 (96) |
| Luz dinâmica (`PointLight2D`) | só herói e portal (2) | 3 a 4 | 6 |
| Normal map | não | só herói | herói e elites |
| Sombra de contato | sim | sim | sim |
| Sombra projetada (`sombra_projetada`) | não | não | sim |
| Escuridão (`escuro_halo`) | 0 a 1 | 2 | 4 a 8 |
| Limite de vivos (`limite_vivos`) | 250 | 350 | 500 |
| Névoa e partículas de ambiente | poucas | médias | cheias |
| Brilho de elite e barra | mantém | mantém | mantém |

Importante: esta tabela é **proposta de partida**, não medição. A única medição real de custo é a da PR #148 (no PC do Alisson, não no i5-3470). O teste de aceitação precisa ser no i5-3470 do Breno, com o F3 (`Mostrar FPS`), que já existe no jogo.

---

## Dúvidas para o Alisson e o Breno

1. **Resolução final:** 960x540 é a recomendação. Confirmar com um teste no i5-3470 antes de mudar a arte. Se o Breno não puder testar, a sugestão é manter 640x360 e aceitar sprites menores, ou ficar com 1280x720 e a arte atual.
2. **Elevação da câmera:** a referência parece usar cerca de 50 graus e o gerador usa 32. Querem 45 graus como meio-termo, ou manter 32 e mudar só o chão?
3. **Barras de vida:** a referência mostra barra em vários monstros, mas o README diz só para elite e chefe. Qual vale?
4. **Nome dos perfis:** `qualidade.json` usa `alta`, `media`, `baixa`. O README e o pedido usam Baixo, Médio e Alto. É o mesmo conjunto?
5. **Ponte, rio e feixe do portal:** não achei geradores para eles em `cenarios.py` nem em `floresta.py`. Já existem em outro lugar, ou são novos?
6. **Ordem do normal map:** seguir a sugestão da PR #148 (albedo sem sombra assada antes de julgar) antes de ligar a luz em mais sprites?
7. **Tamanho dos sprites:** aceitamos herói de 32x44 (ou 22x30 na base 640x360) no lugar de 44x60? Isso muda todos os quadros e os dados de animação.
