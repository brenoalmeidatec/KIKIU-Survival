# Hazaki: framework de animação no Blender (base das animações do herói)

Um script monta o herói do estudo aprovado (modelo do Codex, paleta escura do jogo, 4 faixas de luz, contorno no tom da cor, Cycles em pixel nativo)
com um **rig de ossos com joelho e cotovelo**, e chama uma função de pose por animação. Cada animação sai em 8 direções, **cor e normal**,
direto no quadro do jogo (32x44, câmera a 45 graus, 24,5 px/m, pé na linha 42).

```
blender -b -t 6 -P gerar.py                     # todas as animações (~6 s): quadros/<anim>/... + hazaki_rig.blend
blender -b -t 6 -P gerar.py -- --anim=andar     # só uma
python previa.py andar [pasta] [--normal]       # GIF (8 direções lado a lado) + folha de contato, com Pillow
python medir.py andar                           # largura/altura por direção e se algo encosta na borda do quadro
```

## Saída e nomes
`quadros/<anim>/<direcao>_<i>_cor.png` e `..._normal.png`, `i` = quadro (0..n-1), sempre 32x44 RGBA, alfa binário, a MESMA silhueta em cor e normal.
A normal é a do pipeline do jogo (`prototipos/cara_nova/gerar_cara_nova.py`: elevação desfeita, XY esticado, bisel de borda, contorno = normal reta 0.5,0.5,1).

**Ordem das 8 direções = a das linhas das folhas do jogo (`v2/sprites.gd`):** `baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir`
(ângulo do herói em torno de Z: 0, -90, 90, 180, -45, 45, -135, 135; 0 = de frente para a câmera). Para montar a folha do jogo: uma linha por direção
nessa ordem, colunas = quadros (o jogo usa `[parado, andar0..]`; cada animação nova ganha as suas colunas ou a sua folha).

## Animações existentes (exemplos)
| anim | quadros | arquivo |
|---|---|---|
| `parado` | 4 | `anim_parado.py`: respiração de 1 px (peito/cabeça sobem juntos) e leve balanço |
| `andar` | 6 | `anim_andar.py`: ciclo do piloto (contato, descida, passagem, contato oposto, descida, passagem), agora com joelho, cotovelo e bota plana |
| `rolamento` | 6 | `anim_rolamento.py`: rolamento de verdade (agacha, mergulha encolhido, gira mais de uma volta com a cabeça passando pelos pés, abre e sai agachado), com poeira atrás |
| `combo` | 18 | `anim_combo.py`: 3 golpes x 6 quadros (antecipação, antecipação funda, golpe com rastro, impacto com rastro, hold, volta): horizontal, diagonal descendente e estocada |
| `escudo` | 4 | `anim_escudo.py`: a katana cruza na frente do tronco (diagonal, ponta para cima), braço esquerdo em apoio; 2 quadros de entrada e 2 de guarda (o corpo cede no 3º) |
| `dano` | 4 | `anim_dano.py`: impacto (cabeça jogada), recuo máximo, reação e volta com ease |
| `morte` | 8 | `anim_morte.py`: leva o golpe, cede os joelhos, tomba DE LADO (rola em torno do eixo frente-trás), BATE (q3), rebate 1 px, assenta e fica deitado 2 quadros, encolhido; nas 8 direções termina atravessado na tela (cabeça para a esquerda ou a direita), nunca de cabeça para baixo |

Cada `anim_<nome>.py` pode declarar `S_POR_QUADRO` (segundos de cada quadro: impacto rápido, hold e repouso longos); o `montar_folha.py` copia isso para `s_quadros` no JSON.

## Como escrever uma animação nova
Crie `anim_<nome>.py` (o `gerar.py` descobre pelo nome; `--anim=<nome>` renderiza só ela):
```python
import ossos
N_QUADROS = 5
def posar(arm, quadro, n_quadros):      # arm já vem zerado (pose de repouso)
    ossos.girar(arm, "braco_d", x=-1.2)             # braço da katana para frente
    ossos.mover(arm, "torso", z=0.07)               # 1 px para cima
    ossos.pisar(arm)                                # opcional: ancora a bota mais baixa no chão (não use em salto)
```
Sem registrar nada em outro lugar. Os módulos compartilham só `ossos.py`.

**Opcionais do contrato** (o `gerar.py` detecta pela assinatura/nome):
- `posar(arm, quadro, n_quadros, ang)` (4 parâmetros): recebe também o giro do herói na direção (graus; 0 = de frente). A morte usa para escolher a queda de cada direção.
- `efeito(arm, quadro, n_quadros, ang)` -> `[(pontos_no_mundo, (r, g, b)), ...]`: polígonos 2D pintados DEPOIS do render (rastro da lâmina do combo, poeira do rolamento).
  Pinta só onde o corpo não está, sem meio-tom, e na normal usa a normal reta; cor e normal continuam com a mesma silhueta.
- Quedas, rolamento e tudo que sai do chão: `ossos.ancorar(arm, extra_z=, centrar_x=)` põe o corpo INTEIRO no chão (a caixa toda, não só as botas), na mesma linha de baixo
  do herói em pé; `ossos.encaixar_x(arm)` só desliza o corpo em x o necessário para caber nos 32 px (golpes e estocadas); `ossos.guarda_ponta(arm)` devolve a guarda e a ponta da katana.
- Largura real do corpo, sem o corte do quadro (px): `HAZAKI_LARGURA=1 blender -b -t 6 -P gerar.py -- --anim=<nome>` imprime `LARGURA_PX` por quadro/direção.
- `ik_katana.py` (autoria, offline): dado onde a guarda e a direção da lâmina devem ficar, resolve os ângulos do braço da katana (use o número no `anim_*.py`).

**Ossos** (`ossos.OSSOS`): `raiz, quadril, torso, cabeca, braco_e/d` (ombro-cotovelo), `antebraco_e/d` (cotovelo-punho: leva mão, proteção e katana),
`perna_e/d` (quadril-joelho), `canela_e/d` (joelho-tornozelo), `pe_e/d` (bota). `_e` = esquerda DA TELA (x negativo), `_d` = direita da tela (x positivo, onde está a katana).
Hierarquia: raiz > quadril > {torso > {cabeca, braco > antebraco}, perna > canela > pe}. O pivô de cada osso é a articulação (cabeça do osso).

**Eixos de `girar`/`mover`** (espaço do herói em repouso, de frente para a câmera; valem para qualquer osso): x = direita da tela, y = para TRÁS do herói
(a frente é -y), z = para cima. `girar(x=)` NEGATIVO = para frente nos ossos que apontam para baixo (braço, antebraço, perna, canela); no tronco e na cabeça, que apontam para cima, é o contrário (x POSITIVO inclina para frente, x NEGATIVO para trás), `girar(y=)` = inclina de lado, `girar(z=)` = gira em pé
(antihorário visto de cima). Ângulos em radianos; `mover` em unidades do modelo (1 px do jogo = 0,074; herói tem ~4,2 de altura). Joelho dobra com `girar(canela, x=+)`,
cotovelo dobra com `girar(antebraco, x=-)`. `pisar` calcula o sobe-e-desce do quadril a partir da geometria das pernas.

## O que o herói é (resumo das decisões)
- Modelo = geometria do Codex (`../codex_estudo/criar_estudo.py`, lida em tempo de execução, não copiada) com franja e boca removidas, cabeça 1,22x, mechas mais grossas,
  lenço mais curto. **Pernas, botas, braços, mãos e katana são recriados em repouso reto** para poder dobrar no joelho/cotovelo.
- Katana na mão direita da tela, apontada para baixo e levemente para fora, **lâmina espessa e clara (pirâmide de 4 lados, ~4 px, 0,8 de comprimento, tom #d6e0ea mais claro que o contorno)** com fio frio: lê em qualquer direção, mesmo a 44 px.
  O braço da katana quase não balança no andar (senão a lâmina estoura os 32 px nas diagonais).
- Largura: 27-28 px de frente (o estudo: ~27), até 30 nas diagonais; nenhum quadro passa de 32 px (conferido renderizando num quadro de 48 px). Pixel na coluna 0 ou 31 pode
  ocorrer, mas nada é cortado. `LARGURA` em `gerar.py` ajusta; subir encosta a lâmina e o lenço na borda.
- Cabelo e rosto: os do estudo (o `gerar_heroi_estilo.py` tinha trocas de cabelo depois do `exec` que nunca rodavam; aqui não foram aplicadas, para manter o visual aprovado).

## Limites conhecidos
- `chao` (sola em repouso) e a calibragem do pé (linha 43 com contorno) são medidos a cada execução no parado de frente; a vista `cima` fica 1 px acima porque a bota projeta menos.
- Sem normal "de luz": o jogo faz a iluminação dele a partir da normal; `previa.py` só mostra a cor.
- O jogo ainda NÃO usa estes quadros.

## Folha final (montagem 2: todas as animações)
Gerada por `python montar_folha.py` (depois do `gerar.py`): `hazaki_final_albedo.png` (cor), `hazaki_final_normal.png` (normal),
`hazaki_final.json` (formato que `v2/sprites.gd` e `v2/heroi.gd` leem, mais `animacoes`) e `hazaki_final_previa_x4.png` (prévia ampliada 4x).
Os GIFs (`python gifs.py <pasta>`) estão em `docs/visual_2_5d/blender_herois/hazaki/`.

Grade: **8 linhas** (a ordem de `linhas`: baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir) x **50 colunas**, quadro 32x44.
As colunas 0 a 6 são as da folha do piloto (parado + andar0 a andar5); as colunas novas vão no fim, na ordem de `nomes_colunas` do JSON.

| colunas | animação | quadros | s por quadro (sugerido) |
|---|---|---|---|
| 0, 7 a 9 | parado (0 = quadro 0; 7 a 9 = quadros 1 a 3) | 4 | 0,25 |
| 1 a 6 | andar (andar0 a andar5) | 6 | 0,09 |
| 10 a 15 | rolamento | 6 | 0,07 (ritmo por quadro em `s_quadros`) |
| 16 a 33 | combo: golpe 1 = 16 a 21, golpe 2 = 22 a 27, golpe 3 = 28 a 33 | 18 | 0,06 (ritmo por quadro em `s_quadros`) |
| 34 a 37 | escudo | 4 | 0,10 |
| 38 a 41 | dano | 4 | 0,08 |
| 42 a 49 | morte | 8 | 0,12 (ritmo por quadro em `s_quadros`) |

- **`colunas` do JSON tem só as 7 do andar de propósito**: `heroi.gd` anda com `colunas.size() - 1` quadros, e colunas novas ali fariam o passo
  rodar pelo combo e pela morte. As animações novas estão em `animacoes` (coluna inicial e final, quadros, tempo por quadro sugerido, `s_quadros` quando o quadro tem ritmo próprio, aviso). O jogo ainda
  não as usa: ligar isso é trabalho no `heroi.gd`, fora desta pasta.
- `pe_y` = 42 (o pé na linha 42; a linha 43 é o contorno, ver `PE_LINHA` em `gerar.py`).
- **Bordas, medidas com `medir.py`** (toca = algum quadro tem pixel na coluna 0 ou 31; tocar não é cortar, o corte real se mede com `HAZAKI_LARGURA=1`):
  - `parado` e `escudo`: não tocam.
  - `andar`: baixo_esq, baixo_dir, cima_esq e cima_dir.
  - `rolamento`: esquerda, direita, baixo_dir e cima_esq.
  - `combo`: todas, menos baixo e cima (o rastro da lâmina é cortado pela célula).
  - `dano`: baixo, direita, cima, baixo_dir e cima_esq.
  - `morte`: baixo, direita, cima, baixo_esq e cima_dir (largura de 25 a 32 px).
- **Reprodutibilidade:** o `gerar.py` é determinístico. Re-renderizar nesta montagem deu os 800 PNGs pixel-idênticos aos commitados, e a folha, a prévia e os GIFs saíram byte a byte iguais. Diferença só de bytes do PNG (encode) não vai para o commit.

## QA no Salão (montagem 2)
`docs/visual_2_5d/blender_herois/hazaki/qa_salao_parado_andando_golpe3.png` tem cinco painéis ampliados 4x em volta do herói no Salão: o sprite atual do jogo (controle) e, depois, parado (coluna 0), andando (coluna 4, andar3), golpe 3 de frente (coluna 30, quadro 2 do golpe 3) e golpe 3 de perfil (mesma coluna, direção direita). Os prints inteiros (960x540) ficaram fora do repo.
A cena `../qa/qa_hazaki_final.gd` só troca a textura do herói; o jogo não muda.
- **O Salão está no `origin/main`, não nesta branch** (esta branch parte de antes do #242). Para rodar: copie `qa/qa_hazaki_final.gd` e o `.tscn` para `testes/` de uma cópia do `main` (fora do repo), faça o import (`Godot --headless --path <projeto> --import`) e rode com janela oculta (`Start-Process ... -WindowStyle Hidden`), passando `--folha=<.../hazaki/hazaki_final>` (sem `_albedo.png`) e `--saida=<png>`.
- Nesta montagem: import 39 s; cada print, uns 5 s.

## Tempo medido (montagem 2)
- `gerar.py` com as 7 animações: **32 s** de parede (Blender 4.5.14, `-b -t 6`, contando a abertura do Blender). Gravado em `tempo_render_s` do JSON (a montagem 1 registrou 22 s).
- `montar_folha.py` e `gifs.py` não foram cronometrados separadamente.

## Brendan no padrão do elenco (2026-11-01, #586)
Esta pasta é o piloto: `perfil.py` (carregado sozinho quando o `gerar.py` roda sem `--perfil`) traz as cores e os parâmetros do padrão novo
(ver `../LEIA-ME.md`, seção "Padrão do elenco"). Sem o `perfil.py`, o `gerar.py` volta ao Hazaki de antes.
- Cor: vermelho samurai `#c0202c`/`#e03a36` no casaco, mangas e lenço; calça, couro e braçadeiras pretos; dourado `#d0a040`; cabelo preto-azulado `#282c3e` (preto puro virava um capacete).
- Cabeça 1,42 (era 1,22) e mechas um fio mais baixas: `massa_pct` 38,8 (era 35,6; crânio de 14 para 16 px), topo do cabelo na linha 2 no parado/andar.
- Katana 1,5x mais comprida, 1,15x mais grossa, 30% mais clara; de pé ao lado do corpo no parado/andar/dano; menor no rolamento (0,7) e na morte (0,8).
- Contorno de 1 px + rim light (`estilo2d.py`), retrato em `projeto/assets/personagens/hazaki/retrato.png`.
- Bordas (`medir.py`, direções que tocam a coluna 0 ou 31): parado 2, andar 4, rolamento 4, combo 8, escudo 6, dano 2, morte 8. A lâmina maior encosta mais no topo do quadro: 31 quadros com pixel na linha 0 (combo 12, dano 6, morte 6, escudo 5, rolamento 2), contra 1 antes; parado e andar não encostam (topo na linha 2).
- Render completo (7 animações + retrato): 33 s com `-t 4`.
