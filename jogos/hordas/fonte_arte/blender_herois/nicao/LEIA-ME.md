# Nicão: o anão guardião de marreta, no Blender (todas as animações)

Mesmo processo do Hazaki (`../hazaki/`: Cycles em pixel nativo, 1 amostra, câmera a 45 graus, 24,5 px/m, 8 direções, cor + normal, materiais em 4 faixas,
contorno no tom escuro da cor), com o modelo feito **por script a partir da referência do Codex** (`../referencia_herois/nicao.png`: frente, lado e costas) e uma
marreta que as DUAS mãos seguram por IK. A folha final já está no jogo (`prototipos/cara_nova/sprites/nicao_albedo.png`, `_normal.png`, `.json`).

```
blender -b -t 6 -P gerar.py                     # todas as animações (~31 s de parede, Blender 4.5.14 com -t 6): quadros/<anim>/... + nicao_rig.blend
blender -b -t 6 -P gerar.py -- --anim=combo     # só uma
python montar_folha.py                          # nicao_final_albedo.png / _normal.png / .json / _previa_x3.png
python gifs.py <pasta> [--atual=<pasta com a folha antiga>]   # GIF por animação (8 direções lado a lado) + comparativo
python previa.py combo [pasta] [--normal]       # folha de contato de uma animação
python medir.py rolamento                       # largura/altura por direção e se algo encosta na borda
NICAO_DEBUG=1 blender ... -- --anim=combo       # lista, por quadro, quanto a mão ficou longe do cabo (ver "IK")
```

## Modelo (`modelo.py`) e o que vem da referência
Anão de 3,0 unidades até a crista do elmo (~40 px; o Hazaki tem 44), ombros largos, pernas curtas. Da referência: **elmo de ferro com nasal e crista**, rosto escuro com
os olhos, **barba ruiva grossa**, **ombreiras azul-lavanda em duas placas**, braços de pele, braçais azuis e **luvas castanhas**, peitoral de carvão com **tabardo vermelho**,
alças de couro, **cinto com fivela de latão**, joelheiras azuis, botas de ferro e a **marreta de cabo de madeira, cabeça de pedra azul e cinta de latão** (a mais alta
que a cabeça, na mão esquerda DA TELA, que é a direita do anão, como na referência). Exageros para ler em pixel: elmo e barba grandes, ombreiras grossas, cabo de 2,7 px e cabeça da marreta de 12 px.
Cores = a paleta escura do jogo (`PALETA` em `modelo.py`, tom do meio das 4 faixas de luz).

## Rig e IK
Os mesmos ossos do Hazaki (`ossos.OSSOS`) + **`marreta`** (osso próprio, filho do tronco; origem na mão esquerda de repouso, aponta para cima).
`ossos.empunhar(arm, ponto, direcao, d0)` põe a marreta no espaço do herói (onde fica a mão de baixo e para onde aponta o cabo; `ossos.dirv(elev, azim)` dá a direção em graus)
e `ossos.segurar(arm, mao_e, mao_d)` resolve os dois braços por **IK analítico de dois ossos** (`ossos.alcancar`: cotovelo para fora e para baixo) até as posições do cabo. Assim a
marreta é posada como um objeto e o resto (tronco, quadril, pernas) é FK. Se o ponto estiver longe demais, o braço estica até o limite e `arm["falta_e"/"falta_d"]` diz quanto faltou
(`NICAO_DEBUG=1` imprime por quadro do combo): o combo foi ajustado até a falta ficar em 0,00 em todos os quadros, exceto o quadro 4 (0,03 unidade, 0,4 px, na mão esquerda).
`ossos.ancorar` só considera o corpo (a marreta pode ficar fora da caixa ou no chão); `encaixar_x` considera a marreta também.

## Quadro 64x96 (o Hazaki usa 32x44)
A marreta tem 3,2 unidades (43 px) e a cabeça dela bate no chão À FRENTE do herói, que na câmera a 45 graus cai ABAIXO da linha do pé. Por isso o quadro é **64 x 96, com o pé na
linha 74 (`pe_y` do json) e 20 px de folga embaixo**; o topo comporta a marreta erguida atrás da cabeça. Medido nos 304 quadros de cor (38 colunas x 8 direções), só têm pixel na borda do quadro: a poeira do impacto da pancada (poucos px nos quadros 9 e 10 do combo, é efeito),
a cabeça da marreta no quadro 4 de perfil esquerdo (5 px, por baixo) e 1 a 2 px no rolamento (quadro 2) e na morte (quadro 1). O sprite de antes era 64x60 com o corpo de 55 px de largura;
o novo tem o corpo de ~26 px de largura e ~40 de altura, mais detalhe e a marreta à vista.

## Animações (`nicao_final.json`, `animacoes`)
Grade de **8 linhas x 38 colunas**; as 7 primeiras são as de sempre (parado + andar0 a andar5) e as outras vão no fim, como no Hazaki (`colunas` do JSON tem só o andar de propósito).

| colunas | animação | quadros | s por quadro |
|---|---|---|---|
| 0, 7 a 9 | parado (0 = quadro 0; 7 a 9 = quadros 1 a 3): respira, a mão esquerda segura a marreta plantada | 4 | 0,28 |
| 1 a 6 | andar: passo curto, balanço de lado, a marreta acompanha inclinada | 6 | 0,11 |
| 10 a 15 | rolamento / esquiva: a marreta deitada ao longo do eixo do giro, as duas mãos nela, poeira atrás | 6 | 0,06 a 0,10 |
| 16 a 27 | combo: golpe 1 "batida" = 16 a 21, golpe 2 "pancada" = 22 a 27 | 12 | 0,05 a 0,16 |
| 28 e 29 | secundário / defesa: o cabo cruza o peito, joelhos dobrados (segura no último quadro) | 2 | 0,07 e 0,12 |
| 30 e 31 | dano: cabeça jogada para trás, a marreta balança, o corpo recua | 2 | 0,07 e 0,13 |
| 32 a 37 | morte: cai DE LADO e fica deitado atravessado na tela (como o Hazaki); a marreta escapa da mão e cai deitada no chão à frente | 6 | 0,05 a 0,40 |

**Combo** (o jogo reparte a duração do golpe em partes iguais, `heroi.gd: _coluna_acao`; `acerto_em` de 0,5 e 0,55 cai no quadro 3 dos dois): quadros do golpe = 0 antecipação, 1 antecipação
funda (longa e pesada), 2 golpe, 3 IMPACTO, 4 segura, 5 volta. A **batida** vem de trás do ombro direito do anão, varre a frente na altura da cintura e acerta à esquerda dele, o corpo girando junto;
a **pancada** levanta a marreta acima e atrás da cabeça, arqueia, desce por cima e BATE no chão (poeira e pedras pintadas no quadro de impacto e no seguinte, só onde o corpo não está).

## Arquivos
`modelo.py` (o anão), `gerar.py` (materiais, contorno, rig, câmera e render; a estrutura é a do Hazaki), `ossos.py` (poses + IK da marreta), `anim_<nome>.py` (uma por animação; descobertas pelo nome),
`normais.py` (cópia do `../hazaki/normais.py`), `montar_folha.py`, `gifs.py`, `previa.py`, `medir.py`, `quadros/` (608 PNG), `nicao_rig.blend`, `nicao_final_*.png/.json`.
Candidatos a módulo compartilhado com o Hazaki, se um terceiro herói chegar: `normais.py` (idêntico), as seções 2 a 5 do `gerar.py` (materiais, contorno, rig, cena: só mudam as constantes do quadro) e `montar_folha.py`/`gifs.py` (mudam as listas de animação).

## Limites conhecidos
- O Salão (`v2/salao.gd`) desenha sempre o Hazaki (constante `SPRITE`); os prints do Nicão nele (`docs/visual_2_5d/blender_herois/nicao/`) trocam só a textura num QA (`testes/fotos/nicao_salao_fotos.gd`).
- O jogo desenha por cima o arco branco de corte e o escudo azul que já existiam (os mesmos do Hazaki): não são da folha.
- O quadro de 64x96 deixa o sprite com mais área transparente que o do Hazaki (32x44), mas o de antes já tinha 64 de largura (a sombra-blob do jogo usa `largura x 0,75`, igual a antes).
- `parado` no jogo é só a coluna 0 (o `heroi.gd` não anima o parado); as colunas 7 a 9 existem para quando ele animar.

## Revisão de arte 2 (PR #298)
- **Pancada nas costas:** o golpe 2 cai agora de LADO (módulo de 50 graus, quadros 8 a 11 do combo; `LATERAIS` em `anim_combo.py`) e o SINAL do ângulo sai da direção da câmera (`ang`), para a cabeça da marreta ficar fora da silhueta em todas as 8 direções (antes ficava atrás do corpo em cima, cima_esq e cima_dir). A pose, portanto, difere por direção só nesses quadros.
- **Brilho no jogo:** elmo `#4a4a58 -> #6a6c82`, crista `#aab0c4`, cabeça da marreta `#6c78b8`, ombreira `#5a62a2`, barba `#a83e24`; a luz de contorno (rim) ficou mais larga e forte (limiar 0,58 -> 0,45, força 0,55 -> 0,70). A cena da partida é escura por natureza (luz noturna); o ganho aparece comparando com os prints da revisão 1.
- **Andar de lado:** a marreta inclina mais para a frente (0,30 rad em vez de 0,22, e 0,10 de avanço), então a cabeça dela sai do tronco e a silhueta deixa de ser um bloco; mais que isso corta na borda do quadro nas diagonais.
- **Barba:** maior e com duas costeletas, para ler nas diagonais.
- **Escala e quadro:** o Nicão e o Hazaki usam os mesmos 24,5 px/m e o jogo desenha as folhas a 1:1 (sem escala; `sprites.gd` só alinha pela linha do pé), então a escala bate (anão de 1,65 m = 40 px, Hazaki 44 px). A célula de 64x96 continua necessária: a marreta tem 43 px e vai para o lado e para cima; 32x44 cortaria. Medido de novo: o andar, o rolamento e a morte não têm pixel na borda; no combo só sobram 1 a 5 px de poeira do impacto (quadros 9 e 10) e 5 px da cabeça da marreta no quadro 4 de perfil.
