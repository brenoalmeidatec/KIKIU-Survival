# Lucas: o segundo herói no Blender (adagas arremessadas)

Mesmo processo do Hazaki (`../hazaki/LEIA-ME.md`, aprovado no #293): um script monta o herói a partir da **referência do Codex**
(`../../referencia_herois/lucas.png`: frente, lado e costas), com **rig de ossos com joelho e cotovelo**, materiais em 4 faixas na paleta escura do jogo, contorno no tom
escuro da cor, Cycles em pixel nativo (1 amostra, quadro 32x44, câmera a 45 graus, 24,5 px/m, pé na linha 42), 8 direções, **cor e normal**, e monta a folha no formato que
`v2/sprites.gd` e `v2/heroi.gd` leem, com o json de animações.

```
blender -b -t 6 -P gerar.py                     # todas as animações (~28 s): quadros/<anim>/... + lucas_rig.blend
blender -b -t 6 -P gerar.py -- --anim=combo     # só uma
python montar_folha.py                          # lucas_final_albedo.png, lucas_final_normal.png, lucas_final.json, lucas_final_previa_x4.png
python gifs.py <pasta>                          # um GIF por animação (8 direções lado a lado) + comparativo com o sprite de antes
python previa.py combo [pasta] [--normal]       # GIF + folha de contato de uma animação
python medir.py combo                           # largura/altura por direção e se algo encosta na borda do quadro
```

## O que é reaproveitado do Hazaki e o que é novo
Cópias do Hazaki (sem mudança de lógica): `normais.py`, `previa.py`, `medir.py`, `anim_parado.py`, `anim_rolamento.py`, o corpo de `gerar.py` (materiais, contorno, rig, câmera,
render, normais) e o de `montar_folha.py`. **Novo**: `modelo.py` (o modelo do Lucas, por script, da referência; o do Hazaki vinha do estudo do Codex), as animações
`anim_combo.py` (arremessos), `anim_escudo.py` (guarda com as duas adagas), `anim_morte.py` e `anim_dano.py` (reduzidas a 6 e 2 quadros) e, em `ossos.py`, `adaga()` e
`mao_adaga()`: a **adaga da mão** (cabo + lâmina, presa ao antebraço) aparece ou some por quadro (`ossos.adaga(arm, direita, esquerda)`; `zerar` volta a "só na direita"). Foi
a única mudança de contrato; o resto das animações não precisa saber dela. Não foi extraído um módulo comum de propósito: as três pastas de herói (Hazaki, Lucas e os próximos)
mudam em ritmos diferentes e os PRs em paralelo não podem brigar por um arquivo compartilhado.

## O modelo (de `referencia_herois/lucas.png`)
Capuz roxo pontudo (casca aberta na frente, o rosto aparece; ponta para cima e para trás), cabelo preto, lenço dourado grosso na gola e com uma ponta comprida (até o joelho)
do lado esquerdo da tela e uma curta do direito, túnica roxa de manga curta com a barra em ponta, camisa escura por baixo, cinto com fivela, **bandoleira diagonal com três
adagas** (cabo de osso claro, lâmina de aço), espelhada nas costas, uma adaga em cada quadril, braçadeiras de couro, calça escura e botas altas de cano dobrado. Cabeça 1,32x
(a do Hazaki é 1,22x) e largura 1,15x para o capuz e as adagas lerem em 32x44. A **adaga da mão** (osso e lâmina clara de ~6 px) fica na mão direita no parado, andar e rolamento.

## Animações e colunas da folha (8 linhas x 38 colunas, quadro 32x44)
As colunas 0 a 6 são as do piloto (parado + andar0..andar5), as outras vão no fim, na ordem de `nomes_colunas`. `colunas` do json tem só as 7 do andar (o `heroi.gd` anda com
`colunas.size() - 1` quadros); as demais estão em `animacoes`.

| colunas | animação | quadros | s por quadro |
|---|---|---|---|
| 0, 7 a 9 | parado | 4 | 0,25 |
| 1 a 6 | andar | 6 | 0,09 |
| 10 a 15 | rolamento (agacha, mergulha, gira, abre, sai) | 6 | 0,06 a 0,09 |
| 16 a 27 | combo de arremesso: 16-19 = arremesso 1 (mão direita), 20-23 = arremesso 2 (esquerda), 24-27 = **leque** (as duas mãos) | 12 | 0,04 a 0,07 |
| 28, 29 | secundário / defesa: as duas adagas cruzam na frente do peito | 2 | 0,07 e 0,14 |
| 30, 31 | dano | 2 | 0,07 e 0,14 |
| 32 a 37 | morte (de lado, enrolada e deitada) | 6 | 0,05 a 0,30 |

Cada arremesso tem 4 quadros: **puxa** (corpo gira para trás, braço armado ao lado da cabeça, adaga na mão), **lança** (o braço dispara; a adaga some da mão e deixa um
risco de luz na direção da lâmina), **braço estendido** (o corpo à frente) e **volta** (a próxima adaga já está na mão). O `heroi.gd` escolhe o quadro pelo progresso do golpe
(`combo.golpes` = 3 e `quadros_por_golpe` = 4 no json), então o 3º passo (o leque de 5 adagas) cai nos quadros do leque.
O risco de luz do `efeito` só aparece onde o corpo não está e é cortado pela célula nas vistas de perfil (a mão fica na borda); no jogo as adagas de verdade
(`v2/adagas.gd`) saem pela frente do herói.

Morte: o corpo caído **encolhe 12%** (`ENCOLHE` em `anim_morte.py`) e o tronco se enrola para a câmera (`CURVA`), porque a cabeça e o lenço do Lucas são maiores e deitado de comprido
ele passaria dos 32 px; assim cabe em 32 px na maioria das direções. O jogo toca a queda toda e só depois dissolve (coluna 37 = o último quadro, o dissolve começa nela).

## Bordas (`medir.py`; tocar a coluna 0 ou 31 não é cortar)
- `parado` e `escudo` de frente/costas: não tocam. `andar` e `rolamento`: só nas diagonais e de perfil, por 1 px.
- `combo`: o braço estendido encosta nos 32 px em todas as direções nos quadros de lançar/estender; o leque, com os dois braços abertos, tem 34 a 37 px de largura real (as mãos
  são cortadas por 1 a 3 px). `morte`: 25 a 32 px.

## Limites conhecidos
- O Salão agora mostra a folha do herói do personagem ativo (`v2/salao.gd`), mas o retrato de `v2/personagens_tela.gd` ainda usa o Hazaki.
- Sem rosto detalhado: em 32x44 o rosto são 2 olhos e a pele; o capuz e o lenço dão a identidade.
- Os quadros de cor e normal têm a mesma silhueta (conferido em `montar_folha.py`).

## Padrão do elenco (issue #586)
`gerar_elenco.py` é o gerar.py do padrão novo: roda o `gerar.py` com trocas de texto (roxo saturado, lenço lilás, adagas das mãos 1,5x e mais claras, contorno escuro de 1 px + rim light do `../hazaki/estilo2d.py`, retrato 64x64 em `assets/personagens/lucas/retrato.png`). O `gerar.py` não foi editado de propósito: o lobo do LightWolf (`../lightwolf_lobo/gerar.py`) faz trocas de texto nele. Uso: `blender -b -t 4 -P gerar_elenco.py` (`-- --retrato` só o retrato), depois `python montar_folha.py`.
