# Heróis no Blender (piloto: Hazaki samurai andando)

Modelo e rig por script (`../modelos3d/hazaki.py`, articulações = empties) + funções de paleta/normal/contorno de `prototipos/cara_nova/gerar_cara_nova.py`.
Sem modelar à mão. Câmera ortográfica a 45°, 1 m = 24,5 px, quadro 32x44 (igual à folha atual do herói da v2).

```
blender -b -t 6 -P gerar_heroi_andar.py        # ~53 s: hazaki_samurai_blender_{albedo,normal}.png + .json + .blend
python previa_gif.py                            # GIFs em docs/visual_2_5d/blender_herois/
```

Formato = o de `v2/sprites.gd`/`v2/heroi.gd`: 8 linhas (baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir) x colunas
`[parado, andar0..andar5]` (7 colunas; `heroi.gd` já usa `colunas.size() - 1` quadros de andar). O jogo ainda NÃO usa esta folha.
Obs.: `PASSO_ANIM` em `heroi.gd` é 0,13 s/quadro (feito para 4 quadros); com 6 quadros o ciclo fica 50% mais longo, e o ideal é ~0,09 s.

Render: 4x com antialias (EEVEE, 8 amostras) -> média BOX ponderada pelo alfa -> alfa binário, paleta do Hazaki (`hz_neutro`, `hz_pele`, `hz_sangue`, `ouro`) e contorno de 1 px.
Ciclo: contato, descida, passagem, contato oposto, descida, passagem (60° de fase por quadro), com braço oposto à perna, quadril/ombros girando em contra-fase,
pé subindo no balanço, sobe-e-desce do corpo e cabeça atrasada um quadro.

## Estudo: herói do Blender no estilo do jogo (2026-10-15)
`gerar_heroi_estilo.py` junta o MODELO e a TÉCNICA de render do estudo do Codex do Alisson (`codex_estudo/criar_estudo.py` e `criar_pixel_art.py`, cópias sem mudança do que está em
`ChatGPT/KIKIU/output/blender_estudo/`, arte própria do Codex no Blender, registrada em `docs/LICENCAS_ARTE.md`) com a cara do jogo. É um estudo para aprovação: o jogo NÃO usa esta folha.
```
blender -b -t 6 -P gerar_heroi_estilo.py       # 1 s: estudo_estilo/hazaki_blender_estilo_albedo.png + .json + .blend
```
Mantido do Codex: geometria (rosto, cabelo espetado, lenço, cinto, botas, katana), materiais em 4 faixas por emissão, contorno por casca invertida, render Cycles em pixel nativo (1 amostra, filtro BOX mínimo, sem suavização, sem bloom).
Trocado para o estilo do jogo: paleta escura e fechada (traje vinho `#7a2a32` em vez de vermelho vivo, calça azul-carvão, pele `#9a7360`/`#b78c74` menos laranja, aço sem ciano neon, fio da lâmina frio e fosco);
sombra fria azulada e lado iluminado quente; luz principal = tocha lateral (esquerda, um pouco à frente) + um degrau de contraluz frio atrás/à direita; contorno no tom escuro da PRÓPRIA cor (não preto puro);
render direto no quadro do jogo (32x44, 45 graus, 24,5 px/m, pé na linha 42) em vez de 128x128. Exagerado para ler em 44 px: cabeça 1,22x, mechas mais grossas, olhos e sobrancelhas maiores, franja e boca removidas;
lenço mais curto e katana apontada para baixo e menor (a do estudo estouraria os 32 px). Herói estreitado a 95% da largura.
Formato: 8 linhas x 7 colunas como o do piloto; só há o quadro PARADO (repetido onde faltaria andar), sem normal.
Para ver no salão: `qa/qa_heroi_estilo.gd` (cena de QA que troca só a textura do herói no print; precisa do Salão da v2, que está na main e ainda não nesta branch).
Prints (960x540, janela oculta) e a comparação ficam em `estudo_estilo/`.

## Framework de animação (2026-10-15)
A base para as animações do herói (rig com joelho/cotovelo, um módulo por animação, cor + normal em 8 direções) está em `hazaki/` (ver `hazaki/LEIA-ME.md`). Exemplos prontos: parado (4 quadros) e andar (6).
O **Nicão** (anão de marreta, modelado por script a partir da referência do Codex, com IK das duas mãos no cabo e quadro 64x96) usa a mesma estrutura em `nicao/` (ver `nicao/LEIA-ME.md`): parado, andar, rolamento, combo de 2 golpes (batida e pancada no chão), defesa, dano e morte, já ligados no jogo.

## Padrão do elenco (issue #586, 2026-11-01; piloto: Brendan, pasta `hazaki/`)
Pedido do Alisson e do Isac: contorno escuro de 1 px, cabeça maior (35-40% da altura), rim light, arma 1,5x maior e mais clara, uma cor-assinatura saturada por herói, e um retrato 64x64 tirado do próprio rig.
Tudo entrou no `hazaki/gerar.py` como **parâmetros opcionais do `perfil.py`**: um perfil sem eles gera exatamente o que gerava (conferido: `joao` e `lukako` re-renderizados ficaram pixel a pixel iguais aos commitados).

| parâmetro do perfil | padrão (= antes) | o que faz |
|---|---|---|
| `CABECA` | 1.22 | escala da cabeça em volta do pescoço. O `gerar.py` imprime `MEDIDA ... massa_pct` (crânio + volume do cabelo, sem as pontas das mechas) e `cabeca_pct` (com as mechas); meta: `massa_pct` 35-40 e o topo do cabelo na linha 2 ou mais no parado/andar |
| `ESCALA`, `LARGURA` | 0.55, 0.95 | tamanho e largura do herói no quadro (normalmente não mexa) |
| `ARMA_ESCALA` | 1.0 | comprimento da arma em volta da empunhadura (1.5 = padrão novo) |
| `ARMA_ESPESSURA` | = `ARMA_ESCALA` | espessura da arma (perpendicular ao comprimento); 1.15 evita a lâmina virar um remo |
| `ARMA_CLAREAR` | 0.0 | a arma ganha cópias dos materiais ("<material> (arma)"), clareadas para o branco por esta fração (0.3 no Brendan) |
| `ARMA_PECAS` | None | prefixos dos nomes das peças da arma; None = tudo no `ARMA_OSSO` menos braço, antebraço, proteção e mão (o gerar imprime `ARMA: n peças (...)`: confira a lista) |
| `ARMA_OSSO`, `ARMA_PIVO` | `antebraco_d`, mão direita | osso da arma e empunhadura (mundo do modelo do Codex) |
| `ARMA_DIRECAO` | {} | `{anim ou "*": (x, y, z)}`: para onde a arma aponta em repouso naquela animação (eixos do herói: x = direita da tela, y = para trás, z = cima). Uma arma 1,5x apontada para baixo passa do pé: no Brendan ela fica de pé no parado, andar e dano; no combo/escudo/rolamento/morte fica como modelada, porque as poses foram calculadas para ela |
| `ARMA_ESCALA_ANIM` | {} | `{anim: fator}` sobre o `ARMA_ESCALA`, só naquela animação (Brendan: rolamento 0,7 e morte 0,8, senão a lâmina sai do quadro) |
| `ESTILO_2D` | None | `True` = `ESTILO_ELENCO` do `gerar.py` (contorno: anel de 1 px da silhueta escurecido a 30% da cor, luminância até 0,16; rim: 1 px por dentro do contorno nas bordas viradas para cima/direita, frio `(0.84, 0.93, 1.0)` a 55%). Dict = o padrão com chaves trocadas. Feito em `hazaki/estilo2d.py` (só numpy), depois do render da cor; a silhueta (alfa) e a normal não mudam |
| `RETRATO` | None | dict sobre `RETRATO_PADRAO`; o único campo que um herói deve mudar é `"pasta"` (pasta em `projeto/assets/personagens/`). Câmera, enquadramento e luz são os mesmos para todos |

**Retrato 64x64** (`retrato()` no fim do `gerar.py`): busto em 3/4 voltado para a direita (o herói girado 45 graus, como a linha `baixo_dir`), quadro 0 do parado, sem a arma, câmera ortográfica a 18 graus de elevação, escala tirada do crânio
(`Cabeça facetada` com 33 px de altura), topo do cabelo a 4 px da borda, cabeça centrada, ombros cortados embaixo (sem contorno no corte), casca do contorno afinada para ~1 px na escala do retrato, mesmo acabamento 2D, fundo transparente, alfa binário.
Grava em `projeto/assets/personagens/<pasta>/retrato.png`. **Os `rosto.png` antigos não são tocados** (o jogo v1 lê aquelas tiras).

```
blender -b -t 4 -P <pasta>/gerar.py                    # todas as animações + retrato (o retrato sai sozinho quando o perfil tem ESTILO_2D)
blender -b -t 4 -P <pasta>/gerar.py -- --retrato       # só o retrato (~6 s)
blender -b -t 4 -P <pasta>/gerar.py -- --sem-retrato   # só as animações
python hazaki/montar_folha.py <pasta> <nome>           # folha <nome>_final_{albedo,normal}.png + json + prévia x4
```
O `-t` da linha de comando agora vale (antes o `gerar.py` fixava 6 threads); use `-t 4`, porque há outros agentes renderizando.
Heróis com gerador próprio (`nicao/`, `lucas/` e `lightwolf_lobo/`, que roda o do `lucas/` com trocas no código) não leem estes parâmetros: para eles, `import estilo2d` (com `sys.path` apontando para `hazaki/`) e
`estilo2d.aplicar(cor, mascara, ESTILO_ELENCO)` no lugar onde o `hazaki/gerar.py` o chama, `CABECA` direto no código, e a função `retrato()` copiada (ela usa `ARMA`, `CASCAS`, `DELTA_CASCA`, `OSSO_DE`, `OCULTAS` e `carregar_anim`).
