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
| `morte` | 8 | `anim_morte.py`: leva o golpe, cede os joelhos, tomba, BATE (q3), rebate 1 px, assenta e fica deitado 2 quadros; nas 8 direções termina deitado com a cabeça para a câmera |

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

## Folha final (montagem 1: todas as animações)
Gerada por `python montar_folha.py` (depois do `gerar.py`): `hazaki_final_albedo.png` (cor), `hazaki_final_normal.png` (normal),
`hazaki_final.json` (formato que `v2/sprites.gd` e `v2/heroi.gd` leem, mais `animacoes`) e `hazaki_final_previa_x4.png` (prévia ampliada 4x).
Os GIFs (`python gifs.py <pasta>`) estão em `docs/visual_2_5d/blender_herois/hazaki/`. A cena de QA do Salão é `../qa/qa_hazaki_final.gd`.

Grade: **8 linhas** (a ordem de `linhas`: baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir) x **38 colunas**, quadro 32x44.
As colunas 0 a 6 são as da folha do piloto (parado + andar0 a andar5); as colunas novas vão no fim.

| colunas | animação | quadros | s por quadro (sugerido) |
|---|---|---|---|
| 0, 7 a 9 | parado (0 = quadro 0; 7 a 9 = quadros 1 a 3, colunas novas) | 4 | 0,25 |
| 1 a 6 | andar (andar0 a andar5) | 6 | 0,09 |
| 10 a 15 | rolamento | 6 | 0,07 |
| 16 a 27 | combo: golpe 1 = 16 a 19, golpe 2 = 20 a 23, golpe 3 = 24 a 27 | 12 | 0,06 |
| 28 a 29 | escudo | 2 | 0,12 |
| 30 a 31 | dano | 2 | 0,08 |
| 32 a 37 | morte (WIP) | 6 | 0,14 |

- **`colunas` do JSON tem só as 7 do andar de propósito**: `heroi.gd` anda com `colunas.size() - 1` quadros, e colunas novas ali fariam o passo
  rodar pelo combo e pela morte. As animações novas estão em `animacoes` (coluna inicial e final, quadros, tempo por quadro, aviso). O jogo ainda
  não as usa: ligar isso é trabalho no `heroi.gd`, fora desta pasta.
- `pe_y` = 42 (o pé na linha 42; a linha 43 é o contorno, ver `PE_LINHA` em `gerar.py`).
- Cortes de borda medidos com `medir.py` (encostar não é corte, mas a largura chega perto de 32 px): `andar`, `rolamento` e `escudo` encostam
  em algumas diagonais; `morte` corta a borda em vários quadros (é WIP do autor). Por isso a morte não deve entrar no jogo antes de fechar.
- Tempo medido nesta montagem: `gerar.py` com as 7 animações, 22 s (Blender 4.5.14, `-b -t 6`).
