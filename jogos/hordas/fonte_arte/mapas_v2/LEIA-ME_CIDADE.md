# Vila Amaldiçoada (id interno `cidade`): objetos, piso e mapa (Blender -> pixel art)

**#429 (26/10/2026):** a cidade pós-apocalíptica virou vila medieval amaldiçoada. Os NOMES dos objetos, as medidas de pegada (colisão), a planta e as passagens são os de antes (`predio_loja` é uma casa de comércio, `carro_a` uma carroça, `lixeira_azul` o poço, `ponto_onibus` a barraca de mercado...); mudaram a arte (`vila_*.py`), as luzes (`medidas_cidade.LUZES`) e a paleta. O texto abaixo foi escrito antes e ainda descreve o fluxo; onde ele fala de asfalto, neon, prédios ou carros, leia calçamento, vitral, casas e carroças.

**Estado (2026-10-12):** etapa 1 feita (os 41 objetos e o piso: asfalto, calçada e lote, conferidos a olho no tamanho do jogo) e **etapa 2 feita**: `mapas_v2/def_cidade.py` (grade de 5 x 4 quarteirões, colisão, decalques, luzes e zonas de monstros), a linha em `Mapas.LISTA` e o JSON `dados/v2_cidade.json`, gerados por `gerar_v2_mapas.py cidade`. Os brutos do Blender (`mapas_v2/brutos/cidade/`) ficam fora do Git: rode o comando abaixo antes do gerador.

## Como gerar
```
blender -b -t 6 -P jogos/hordas/fonte_arte/modelos3d/mapas_v2.py -- cidade            # tudo: ~30 s por objeto + ~4 min o piso
blender -b -t 6 -P jogos/hordas/fonte_arte/modelos3d/mapas_v2.py -- cidade carro_a poste_rua   # só alguns ("piso" é o chão)
python jogos/hordas/fonte_arte/mapas_v2/previa_brutos.py cidade saida.png [nomes] --esc=3 --final --heroi   # o que o jogador vê, com o Hazaki de 41 px ao lado
python jogos/hordas/fonte_arte/mapas_v2/previa_brutos.py cidade saida.png nomes --luz                        # com uma luz de ponto laranja sobre o normal map
python jogos/hordas/fonte_arte/mapas_v2/previa_brutos.py cidade x.png --tabela                               # a tabela de tamanhos abaixo
```
Arquivos (todos em `jogos/hordas/fonte_arte/`):

| Arquivo | O que faz |
|---|---|
| `modelos3d/mapa_cidade.py` | Junta tudo: `OBJETOS` (nome -> tela do render + função) e `PISO`, que o `mapas_v2.py` lê. |
| `modelos3d/vila_pecas.py` | Cores, materiais com cache e os objetos de rua (lampiões, postes, placas, poço, toco, braseiro, barril, banco), as carroças, barricadas, celeiros, muros e a barraca de mercado. |
| `modelos3d/vila_casas.py` | As seis casas (comércio, taverna, duas casas altas, capela com campanário, casa queimada): pedra embaixo, enxaimel em cima, telhado de duas águas, janelas acesas. |
| `modelos3d/vila_piso.py` | O piso: campo de alturas em numpy (1024 x 1024) + cor pintada em numpy, renderizado de cima pelo Blender (calçamento de paralelepípedos, lajes, lote de terra). |
| `mapas_v2/medidas_cidade.py` | **Python puro**, lido pelo Blender e pelo `def_cidade.py`: `MEDIDAS` (pegada w x d, altura, tela), `LUZES`, `LUZ_TIPOS`, `luz_objetos()`, `luzes_extras()`, `PISO`, `lote_px(i, j)`. |
| `mapas_v2/def_cidade.py` | A etapa 2: `OBJETOS` (a pegada de `medidas_cidade`), `DECALQUES`, `GRADE` dos quarteirões (P prédio no lote, E pátio, B praça com ponto de ônibus e fogueira, R ruína, V vazio), `montar()`: ruas livres, meio-fio, bordas fora da área andável, luzes e zonas de monstros. Lido por `gerar_v2_mapas.py cidade`. |
| `mapas_v2/decalques_cidade.py` | Decalques da cidade em Pillow: `bueiro(rng)` e `bueiro(rng, aberto=True)`. |

## Convenções (as mesmas do laboratório)
Escala 1 m = 32 px na horizontal e 22,63 px na vertical; câmera ortográfica a 45 graus; albedo + **normal map de verdade** + origem. A origem é o centro da pegada, no
chão, e a frente (o que a câmera vê) é o lado -Y. No jogo o **pé** do sprite é a FRENTE da pegada: `pe = origem + d * 11,315 px` para baixo, e o `gerar_v2_mapas.py`
faz isso sozinho com `{"col": "caixa", "w": w, "d": d}` (use os `w` e `d` da tabela). `passável` = enfeite que o herói atravessa (`"col": "passavel"`).
Os carros `_v` são o mesmo carro com o comprimento ao longo de Y (`carro_a_v` e `carro_c_v` de frente para a câmera, `carro_b_v` de costas); `poste_rua_e` é o poste
com o braço para a esquerda; `lixeira_azul` é `lixeira_rodas` com outra cor.

## O piso (azulejo de 16 m = 512 x 362 px, sem emenda)
Um azulejo tem **um cruzamento no canto** (as ruas têm o eixo nas bordas do azulejo, asfalto de 6,5 m) e **um quarteirão no meio**: meio-fio levantado 14 cm com
cantos arredondados, calçada de 1,25 m e **lote de concreto de 7 x 7 m** (de 4,5 a 11,5 m) onde ficam os prédios. Em px do mundo, com o azulejo (i, j) começando em
(512 i, 362 j): o lote é `medidas_cidade.lote_px(i, j)` = (512 i + 144, 362 j + 102, 224, 158). Tinta de rua gasta (faixa dupla amarela, uma faixa de pedestre e uma linha
de retenção por rua), buracos, remendos, rachaduras, mato nas juntas, musgo e terra no lote. Como o mapa é 2880 x 1620, cabem 5,6 x 4,5 azulejos (uns 25 quarteirões):
os lotes vazios viram praças, e a variedade vem dos objetos, dos decalques e das luzes. **Sugestão para o prédio:** centrado no lote, com o pé em
`lote_y + 4 + d * 22,63` (a pegada encostada no fundo do lote; a frente dá para a calçada do sul). `ganho` do piso: comece em 3,0 como o laboratório (o albedo médio
é 59, o do laboratório é 55).
Como ele é feito: `cidade_piso.campos()` monta a altura (meio-fio com chanfro, lajes com desnível e inclinação, juntas, rachaduras, buracos, remendos, pedriscos, mato) e
a cor; o Blender só renderiza a malha com o sol rasante, então as sombras e o normal map saem da geometria. A semente é fixa. As imagens de conferência
`_piso_albedo.png` e `_piso_altura.png` ficam em `brutos/cidade/`.

## Objetos (tamanho final do sprite, pegada e luz)
| objeto | sprite (px) | pegada (m) | luz |
|---|---|---|---|
| `banco` | 56 x 35 | 1.80 x 0.60 | - |
| `barricada_concreto` | 140 x 43 | 4.40 x 1.00 | - |
| `barricada_madeira` | 100 x 44 | 3.20 x 0.90 | - |
| `barril_fogo` | 22 x 36 | 0.65 x 0.65 | fogo_barril |
| `cacamba` | 88 x 55 | 2.50 x 1.30 | - |
| `carro_a` | 150 x 69 | 4.50 x 1.90 | - |
| `carro_a_v` | 63 x 115 | 1.90 x 4.50 | - |
| `carro_b` | 150 x 69 | 4.50 x 1.90 | - |
| `carro_b_v` | 63 x 114 | 1.90 x 4.50 | - |
| `carro_c` | 150 x 69 | 4.50 x 1.90 | - |
| `carro_c_v` | 63 x 114 | 1.90 x 4.50 | - |
| `carro_queimado` | 150 x 82 | 4.50 x 1.90 | - |
| `cone` | 16 x 23 | 0.42 x 0.42 | - |
| `cone_tombado` | 41 x 22 | passável | - |
| `container_a` | 196 x 115 | 6.00 x 2.40 | - |
| `container_b` | 196 x 115 | 6.00 x 2.40 | - |
| `entulho_a` | 40 x 30 | passável | - |
| `entulho_b` | 97 x 52 | 2.00 x 1.20 | - |
| `hidrante` | 18 x 23 | 0.40 x 0.40 | - |
| `lixeira_azul` | 24 x 38 | 0.68 x 0.80 | - |
| `lixeira_metal` | 21 x 36 | 0.62 x 0.62 | - |
| `lixeira_rodas` | 24 x 38 | 0.68 x 0.80 | - |
| `muro_quebrado` | 102 x 73 | 3.00 x 0.40 | - |
| `muro_tijolo` | 102 x 62 | 3.00 x 0.40 | - |
| `placa_neon` | 44 x 83 | 0.40 x 0.40 | neon_rosa |
| `placa_pare` | 24 x 57 | 0.20 x 0.20 | - |
| `placa_rua` | 36 x 65 | 0.20 x 0.20 | - |
| `pneus` | 65 x 43 | 1.30 x 1.10 | - |
| `ponto_onibus` | 132 x 89 | 3.40 x 1.30 | vitrine |
| `poste_quebrado` | 73 x 121 | 0.50 x 0.50 | - |
| `poste_rua` | 69 x 131 | 0.40 x 0.40 | sodio |
| `poste_rua_e` | 69 x 131 | 0.40 x 0.40 | sodio |
| `predio_apto_a` | 184 x 204 | 5.40 x 2.10 | janela, janela |
| `predio_apto_b` | 184 x 203 | 5.40 x 2.10 | janela, janela |
| `predio_bar` | 190 x 177 | 5.60 x 2.60 | neon_rosa, neon_rosa, neon_azul |
| `predio_loja` | 210 x 174 | 6.20 x 2.60 | vitrine, neon_verde, neon_verde |
| `predio_ruina` | 203 x 207 | 5.80 x 2.20 | - |
| `predio_torre` | 190 x 195 | 5.60 x 2.00 | neon_vermelho, baliza |
| `sacos_areia` | 88 x 36 | 2.60 x 0.80 | - |
| `semaforo` | 30 x 90 | 0.35 x 0.35 | semaforo |
| `semaforo_torto` | 29 x 88 | 0.35 x 0.35 | - |

A primeira fonte de luz de cada linha é a principal (`luz_objetos`); as outras vão em `luzes_extras()`. Prévia de todos no tamanho do jogo, com o herói de 41 px ao lado: `docs/visual_2_5d/mapa_cidade/objetos.png`; o piso sob três luzes (simulação em Python com o normal map): `piso_com_luz.png` (2 x 2 azulejos).

## Luzes
O jogo cria **uma luz por objeto** (`luz_objetos` do JSON, com os deslocamentos relativos ao pé). `medidas_cidade.luz_objetos()` já devolve esse trecho (a fonte principal de
cada objeto) e `luzes_extras()` devolve as outras fontes dos objetos com mais de uma (fachada com vitrine e neon), para o `def_cidade.py` pôr em `luzes` (as luzes soltas
do mapa) ao lado de cada cópia do objeto. O ponto da luz é onde a fonte aparece no sprite (conferido contra os pixels: poste 45,0/-119,0 medido e 45,4/-120,4 previsto).
`LUZ_TIPOS` sugere os tipos (cor, energia, raio, altura, tremor, brilho): `sodio` (poste, quente, raio grande), `fogo_barril` (com `"fogo": 1.0` o jogo põe as partículas de
fogo), `neon_rosa`, `neon_azul`, `neon_verde`, `neon_vermelho`, `vitrine` (branco frio: farmácia e ponto de ônibus), `janela` (amarelo fraco), `semaforo` e `baliza`
(vermelho fraco; a baliza pisca). O `poste_quebrado` fica sem luz (de propósito). Carros, caçamba, containers e prédio em ruína não emitem luz.

## Dicas de layout (aplicadas no def_cidade.py)
- Os prédios têm de 174 a 207 px de altura de sprite (o maior, 207 px; árvore da floresta tem 150 a 200): o buraco raio-x do `copas.gd` abre para o herói atrás deles (sprite de
  60 px ou mais), então não precisa de nada a mais; a oclusão por monstro continua valendo.
- Mapa aberto: o monstro persegue em linha reta, então ponha prédios e muros em trechos curtos com abertura; um prédio por lote deixa uma rua de 6,5 m + 2 calçadas entre eles.
- Carros e barricadas fecham a rua em pontos, não em linha longa. `barricada_concreto`, `sacos_areia` e `barricada_madeira` servem de "portão" com abertura.
- Decalques sugeridos para o `def_cidade.py`: `bueiro` e `bueiro_aberto` (já prontos em `decalques_cidade.py`), poças de óleo e de chuva, manchas de sangue e de fuligem, papéis e
  lixo (`kit_decalques.py` tem `poca`, `mancha`, `papeis`, `rachadura`). A faixa de rua e o meio-fio já estão no piso.
- Estilo: tudo escuro e sujo, com o brilho vindo das luzes dinâmicas; o albedo dos objetos é de propósito calmo (a luz do jogo faz o resto sobre o normal map).
