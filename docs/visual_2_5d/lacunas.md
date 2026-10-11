# Lacunas: jogo atual x referência 2.5D

Análise da fase **V0** (2026-10-10). Nenhum código do jogo foi alterado. Esta é a lista do que falta entre o jogo de hoje e `docs/imagens/referencia_2_5d.webp`, com os arquivos que cuidam de cada sistema.

## Como foram feitas as capturas

- Godot 4.4.1 (console), **janela real**, sem `--headless`. Rodado `--headless --import` uma vez antes.
- Partida com horda: `--print_tela=hazaki --bot --equip --fase=1 --estresse=250 --espera=20`. Saíram `hazaki/foto_004.png` (01:03 de partida, com horda e números de dano) e `hazaki/tela_hazaki.png`.
- Portal: `--print_tela=portal --equip --estresse=250 --fase=3`, saiu `portal/tela_portal.png`.
- Pasta das capturas: `scratchpad/ref_lacunas/` (fora do repositório).
- Comparação: `docs/imagens/comparacao_atual_vs_2_5d.png` (2560x720). À esquerda, a captura do portal ampliada 2x (vizinho mais próximo, para manter o pixel). À direita, a referência escalada para 720 px de altura. A cena do portal foi escolhida porque é a que mais se parece com a composição da referência, mas **não é a mesma cena**: a referência é imagem-conceito.
- Menus atuais: `jogos/hordas/build/menus/*/tela_*.png`, todos em 640x360.

**Medidas de base** (`jogos/hordas/projeto/project.godot`, linhas 34 a 39 e 53): viewport 640x360, janela 1280x720, `stretch/mode="viewport"` com escala fracionária, renderer `gl_compatibility`. A referência tem 1672x941, ou seja, cerca de 1,3x a janela padrão de 1280x720.

**Caminhos:** `scripts/` e `dados/` são de `jogos/hordas/projeto/`, e `fonte_arte/` é de `jogos/hordas/`. Os caminhos das tabelas seguem essa base.

**Limite do que foi observado:** as comparações de densidade, escala e brilho abaixo são julgamentos visuais a partir das imagens. Não contei sprites em tela nem medi fps no perfil Baixo.

## 1. Resolução e escala

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Resolução base | Mundo em 640x360, esticado para 1280x720 (`project.godot`). Texto do HUD é fonte pixel de 8 px (`hud.gd`, `FONTE_BASE`, multiplicado por 2 na tela). | Mundo pixelado com mais densidade, e HUD nítido em alta resolução. Decidir entre manter 640x360 e subir a base (ex.: 960x540). | G | V1 | Subir a base aumenta o custo de preenchimento de tela no Baixo (i5-3470, vídeo fraco). Texto em alta resolução pede fonte nova, e a fonte pixel de 8 px deixa de servir. |
| Escala dos sprites | `ESCALA := 2.0` repetido em `inimigos.gd`, `chao.gd`, `armas.gd` e `coleta.gd`: a arte gerada é desenhada 2x. | Personagens menores em relação à tela, com mais pixels por personagem. | M | V1 (base) e V4 (arte nova) | Mudar a escala sem refazer a arte deixa o sprite borrado ou grande demais. A arte sai de `fonte_arte/modelos3d/*.py` (Blender). |

## 2. Câmera e profundidade

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Câmera 3/4 | `scripts/hordas/arena.gd` (linha 71 cria a `Camera2D`; linha 273 segue `jogador.centro()`). Zoom padrão, sem inclinação. Vista de cima reta. | Vista de cima inclinada, com chão em perspectiva e herói em 3/4. | G | V1 | Em 2D, a inclinação é um truque (achatar o chão e as sprites). Pode mexer com a leitura de distância e com o hit-test. O tremor (`camera.offset`, linha 413) continua. |
| Primeiro plano | Não existe. Nada cobre as bordas da tela. | Árvores, ruínas e folhagem nas bordas, na frente do mundo, sem cobrir o herói nem os objetivos. | M | V1 (folhagem simples) e V3 (ruínas) | Primeiro plano que tapa o herói piora a legibilidade, que é a regra 4 do README. Pede uma camada acima do mundo com área de exclusão no centro. |
| Ordem de profundidade | Bichos ordenados por altura dentro de um MultiMesh (`scripts/hordas/atlas_inimigos.gd`). Herói em `jogador.gd`. | Ordem por Y também com objetos altos (ruínas, árvores) cobrindo o herói quando ele passa atrás. | M | V3 | O atlas de inimigos é um único MultiMesh. Objetos do cenário precisam entrar na mesma ordem, senão ficam por cima de tudo. |

## 3. Chão e cenário

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Chão | `scripts/hordas/chao.gd`: azulejo `Dados.tex("chao")` em `TextureRect` de mosaico, escala 2. Por fase, `_aplicar_cenario` troca o piso pelo do cenário (`c.piso`), definido em `scripts/hordas/cenario.gd` e `dados/cenarios.json`. | Chão com volume e variação: raízes, pedras, poças, terra com relevo na vista 3/4. | M | V1 (chão 3/4) e V3 | O mosaico com 3/4 pede textura que repete sem emenda aparente. Arte sai de `fonte_arte/modelos3d/floresta.py` e `cenarios.py`. |
| Enfeites e poças | `scripts/hordas/ambiente.gd` e `scripts/hordas/poca.gd` (poças geradas por código, em cache). | Enfeites maiores, com sombra e poças que refletem a luz. | P | V3 | Baixo. A infra já existe. |
| Água e pontes | Não encontrei ponte nem água animada no código de cenário, e a captura do portal não mostra nenhuma. Confirmar em `fonte_arte/modelos3d/floresta.py` antes de dizer que não existe. | Ponte de madeira sobre o riacho e água com brilho animado. | M | V3 | Água animada custa fill rate. Deve ser só Médio e Alto (chave nova em `dados/qualidade.json`). |
| Altura no mapa | Chão plano. Não há degraus nem pilares com altura. | Ruínas, pilares e pontes em altura. | G | V3 | Altura mexe em colisão, ordem e movimento. Pode esperar o Marco 4 (#128). |

## 4. Luz

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Luz dinâmica | Sem `Light2D`, de propósito: `scripts/hordas/arena.gd` (linha 451) diz "Halos aditivos baratos no efeitos.gd, sem Light2D". Tom de ambiente por `CanvasModulate` em `chao.gd` (`_aplicar_luz`). Escuridão da fase de horror em `scripts/hordas/escuridao.gd` (shader). | Lanternas, tochas, portal e magias acendem o chão e os bichos em volta. | G | V2 | Luz real com muitos bichos é cara, e o renderer `gl_compatibility` tem limite. A decisão atual foi de desempenho, então precisa de medição no Baixo antes de ligar. |
| Relevo nos sprites (normal map) | Não existe. A #145 está pendente. | Sprites com relevo que reage à luz no Médio e no Alto. | G | V2 | A arte precisa de um segundo mapa gerado no pipeline do Blender. Dobra o trabalho de arte por sprite e o tamanho dos assets. |
| Luz do cenário (tochas, lanternas) | Já existe luz pré-assada com halo e poça: `_desenhar_luzes` em `chao.gd` e `_tex_luz` em `efeitos.gd`. | Luz colorida que acende o chão em volta de cada tocha. | P | V2 | Baixo. Reaproveita o que já existe. |

## 5. Heróis

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Sprite do herói | Um sprite por herói, animado por código (`scripts/hordas/animacao_heroi.gd`, números em `dados/animacao.json`). Arte em `fonte_arte/modelos3d/hazaki.py` e outros `.py` de cada bioma. Paleta em `scripts/hordas/paleta.gd`. | Herói menor na tela, com mais detalhe por pixel e contorno que se lê no escuro. | G | V4 | Refazer a arte de todos os heróis (ver `dados/herois.json`). A animação procedural pode não combinar com um sprite mais detalhado e precisa ser revisada. |
| Retrato no HUD | `scripts/hordas/hud.gd` (`_heroi`) mostra o retrato. | Retrato pintado em pixel de alta densidade, com moldura. | P | V4 | Baixo. |

## 6. Monstros

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Bichos em grande número | Atlas e MultiMesh em `scripts/hordas/atlas_inimigos.gd`. Arte em `fonte_arte/modelos3d/monstros.py`. Teto de vivos por perfil: `limite_vivos` (500 no Alta, em `dados/qualidade.json`). | Mais bichos na tela, em horda densa. | G | V4 | O atlas tem teto de 4096 px de altura (comentário do próprio arquivo). Mais tipos ou sprites maiores pedem um segundo atlas. Custo com 500 vivos no Baixo é desconhecido. |
| Olhos acesos e leitura no escuro | Há tratamento de olhos em `scripts/hordas/inimigos.gd`. Não confirmei se os olhos são vermelhos e acesos como na referência. | Olhos vermelhos acesos em todo monstro, para se ler na escuridão. | P | V4 | Baixo. Confirmar com um print ampliado. |
| Sombra projetada | Chave `sombra_projetada` no perfil de qualidade (`dados/qualidade.json`). | Sombra inclinada que dá volume ao bicho, além da mancha de contato. | P | V1 ou V4 | Custa fill rate. Já tem chave de perfil, então é só ligar por qualidade. |
| Elite e chefe | Barra de vida de chefe em `scripts/hordas/hud.gd` (`_chefe`). Brilho de elite em `inimigos.gd`. | Barra de vida em elite e chefe, com brilho. | P | V4 | Baixo. |

## 7. Efeitos

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Golpes e arco de luz | Cortes com arco em `scripts/hordas/efeitos.gd` (`_pintar_corte`) e halos de impacto. | Arco de luz forte, que acende o chão por onde a lâmina passa. | M | V5 | Mais brilho e mais partículas custam. Respeitar `efe_particulas` e `efe_luzes` por perfil. |
| Efeitos por elemento | Fogo, gelo, raio e veneno em `scripts/hordas/elementos.gd`, com dados em `dados/elementos.json`. Partículas por `elem_part`. | Raio azul, fogo laranja, veneno verde e arcano roxo, maiores e mais saturados. | G | V5 | Partículas maiores e mais coloridas somam custo. Teste no Baixo é obrigatório. |
| Portal | Portal de saída em `scripts/hordas/saida.gd`: anel e poça, com o aviso "Segure CONFIRMAR para sair". Não tem círculo de runas nem coluna de luz. | Portal arcano roxo com runas e coluna de luz vertical, que se lê de longe. | M | V3 e V5 | Arte nova do portal. O aviso de saída precisa continuar legível. |

## 8. Números de dano

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Números de dano | `numero()` em `scripts/hordas/efeitos.gd`. Cor vem de quem chama: branco por padrão (`arena.gd`, linha 442), cor de elemento em `elementos.gd` e `duelo.gd`. Tamanho que pulsa em `tamanho_numero`. Fonte pixel de 8 px. Pode ser desligado pela opção "Números de dano". | Números coloridos por elemento, com contorno escuro e crítico maior, nas mesmas cores dos efeitos. | M | V5 | Muitos números (teto `MAX_NUMEROS`) viram ruído. Precisa de limite e de agrupamento em horda. A fonte nova precisa de teste de leitura no 1x. |

## 9. HUD (cada elemento)

Os arquivos do HUD são `scripts/hordas/hud.gd`, `hud_slot.gd`, `hud_setas.gd`, a cena `cenas/hud.tscn` e o tema `cenas/tema_hud.tres`.

| Elemento | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Painel do herói (topo esquerdo) | Retrato, nome, barra de vida e "Fragmentos" em texto pixel pequeno (`_heroi`). Nível embaixo. | Painel escuro translúcido com borda fina, retrato maior, barra de vida vermelha, barra azul de fragmentos com ícone e badge de nível. | M | V1 | O texto precisa caber nas três opções de tamanho (`texto_hud`: 1x, 1,5x e 2x). |
| Armas e passivos (abaixo do painel) | Faixa de ícones pequenos sem moldura (`_build`, `hud_slot.gd`). | Quatro ícones com moldura dourada e número de nível. | M | V1 | Pouco risco; é só layout. |
| Objetivo (esquerda) | Nome, barra e tempo no topo central (`_objetivo`, `camada_objetivos.gd`). Missão do chefe usa a mesma região (`_missao`). | Painel "Objetivo" à esquerda, com a descrição e o contador (2/3). | M | V1 | Objetivo e missão do chefe disputam o mesmo espaço. Decidir a ordem. |
| Relógio e região (topo central) | Relógio pequeno e nome da região (`_xp_e_relogio`). | Relógio grande no centro e nomes das duas regiões numa faixa, como na referência. | P | V1 | Baixo. |
| Barra de XP | Faixa fina no topo da tela (visível na captura da floresta). | Barra dourada na base do centro, com chevrons nas pontas. | P | V1 | Baixo. Só mudar de lugar. |
| Ouro e almas (topo direito) | Texto pequeno (`_ouro`). | Painel com ícones de moeda e chama. | P | V1 | Baixo. |
| Minimapa (topo direito) | Ainda não existe. `hud.gd` reserva o lugar embaixo à direita. A referência mostra um radar circular com setas. | Radar circular com pontos de inimigo e seta do herói. | G | Marco 4 (#128), com o lugar já na V1 | Depende do Marco 4. Desenhar pontos de horda a cada quadro custa. |
| Habilidades (embaixo esquerdo) | Ícones pequenos com tecla, e consumíveis (`_habilidades`, `_provisoes`). | Cinco slots grandes com tecla, moldura e o slot 1 destacado. | M | V1 | Pouco risco; é layout. |
| Mensagens e banners | Texto pixel no centro (`mensagem`, `anunciar`). O "PORTAL ABERTO" da captura é texto rosa simples. | Toast com ícone e moldura, como "PORTAL ABERTO" na referência. | M | V1 | Baixo. |
| Chat de voz ("Segure V para falar") | Não existe. | Balão no canto inferior esquerdo. | G | Marco 9 (#133) | Depende do online. Fora da V1 a V6. |
| Ping, FPS e online (canto inferior direito) | Não existe no HUD. | Painel com FPS, ping e status online. | P | Marco 9 (#133) | Depende do online. |
| Fase e objetivo de andar (canto inferior direito) | Não existe no mesmo lugar. A fase aparece no topo. | Número da fase com ícone no canto inferior direito. | P | V1 | Baixo. |

## 10. Menus

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Menus (título, heróis, preparo, mapa, opções, status, calor, criação, pausa) | Título em `scripts/hordas/main.gd`. Telas em `tela_herois.gd`, `tela_preparo.gd`, `tela_mapa.gd`, `tela_opcoes.gd`, `tela_status.gd`, `tela_calor.gd` e `tela_criacao.gd`. Pausa em `hud.gd`. Prints de referência em `jogos/hordas/build/menus/*/tela_*.png`. | Painel escuro, moldura fina e ornamentada, texto nítido, paleta da referência. | G | V6 | Cada tela tem layout próprio em GDScript, então a consistência depende de um tema central (`cenas/tema_hud.tres`). Tradução em `assets/traducao/` precisa caber nos textos maiores. |

## 11. Desempenho

| Item | Como está hoje | Como deve ficar (referência) | Tam. | Fase | Riscos |
|---|---|---|---|---|---|
| Perfis de qualidade | `dados/qualidade.json` com perfis alta, media e baixa. `scripts/hordas/config.gd` lê as chaves por `Config.q()` e sugere o perfil na 1ª execução (`qualidade_sugerida`). `qualidade_auto` baixa o perfil se travar. Medidor em `scripts/hordas/perf.gd`. | Baixo continua rodando no i5-3470. Médio e Alto levam luz com relevo, efeitos completos e primeiro plano. | G | Transversal, mais forte em V2 | Cada fase nova precisa de medição no Baixo na máquina de teste. Não tenho fps de base medido (ver dúvidas). |
| Custo da luz e do relevo | Não existe. | Luz dinâmica e normal map só em Médio e Alto. | G | V2 | Light2D e normal map somam custo por sprite. Medir com 250 a 500 bichos. |
| Custo da câmera 3/4 e do primeiro plano | Não existe. | Câmera 3/4 e folhagem nas bordas em todos os perfis, com versão mais simples no Baixo. | M | V1 | Primeiro plano em todos os quadros tem custo de desenho. Precisa de chave por perfil. |
| Custo dos números e dos efeitos | Limitado por `efe_particulas`, `efe_luzes`, `mortes_part` e outros. | Mais efeitos e números coloridos, dentro dos tetos por perfil. | M | V5 | Sem teto, a horda cheia de efeitos derruba o Baixo. |

## Lista de issues sugeridas

Cada fase abaixo vira uma issue. O critério de pronto usa um X proposto para cada fase, que precisa de confirmação do Breno.

### V1: Base do 2.5D (resolução, câmera 3/4, primeiro plano e HUD novo)
**Objetivo:** mundo com câmera 3/4, folhagem nas bordas e HUD no layout da referência.
- [ ] Decidir a resolução base (640x360 ou 960x540) e registrar em `project.godot` e no README da pasta.
- [ ] Protótipo de câmera 3/4 atrás de uma chave de qualidade, com teste de hit-test.
- [ ] Camada de primeiro plano (folhagem nas bordas) com área de exclusão no centro e no herói.
- [ ] Reposicionar painel do herói, objetivo, habilidades, barra de XP e relógio em `hud.gd` e `cenas/hud.tscn`.
- [ ] Fonte de HUD nítida, com `texto_hud` funcionando nos três tamanhos.
- [ ] Print antes e depois na mesma cena (`--print_tela=portal`).

**Critério de pronto:** print lado a lado parecido com a referência na mesma cena, e fps no perfil Baixo não piora mais que 10%.

### V2: Luz dinâmica e relevo nos sprites
**Objetivo:** lanternas, tochas, portal e magias acendem chão e bichos; sprites com relevo no Médio e no Alto.
- [ ] Prova de conceito de luz do herói com `PointLight2D` no GL Compatibility, medida no Baixo.
- [ ] Nova chave em `dados/qualidade.json` para luz dinâmica, desligada no Baixo.
- [ ] Luz de tocha e lanterna do cenário, partindo de `_desenhar_luzes` e `_tex_luz`.
- [ ] Normal map nos sprites do herói (2ª rodada da #145), gerado no pipeline do Blender.
- [ ] Luz de elemento (fogo, raio) acendendo o chão em volta.
- [ ] Nova opção na aba de Gráficos (#150).

**Critério de pronto:** print lado a lado parecido com a referência na mesma cena, e fps no perfil Baixo não piora mais que 15% (no Baixo a luz fica desligada, então a piora esperada é zero).

### V3: Cenário com profundidade
**Objetivo:** ruínas, pontes, água, lanternas e altura no mapa.
- [ ] Ruínas e pilares como obstáculo, com ordem por Y em relação ao herói e aos bichos.
- [ ] Ponte de madeira sobre o riacho, em `fonte_arte/modelos3d/floresta.py`.
- [ ] Água com brilho animado, só no Médio e no Alto.
- [ ] Portal arcano com coluna de luz (efeito completo na V5).
- [ ] Dados novos em `dados/cenarios.json`, com `_ajuda`.
- [ ] Print antes e depois da mesma fase.

**Critério de pronto:** print lado a lado parecido com a referência na mesma cena, e fps no perfil Baixo não piora mais que 10%.

### V4: Heróis e monstros na densidade nova, com retratos em pixel
**Objetivo:** personagens na escala nova, com olhos acesos e retratos pintados.
- [ ] Mudar `ESCALA` em `inimigos.gd`, `chao.gd` e `armas.gd` com um herói de teste.
- [ ] Re-render do Hazaki no Blender (`fonte_arte/modelos3d/hazaki.py`) na densidade nova.
- [ ] Monstros com olhos vermelhos acesos, conferidos em print ampliado.
- [ ] Sombra projetada ligada por perfil (`sombra_projetada`).
- [ ] Conferir o teto de 4096 px do atlas com a altura nova (`atlas_inimigos.gd`).
- [ ] Retrato pintado em pixel para o painel do HUD.
- [ ] Revisar `dados/animacao.json` e `dados/animacao_monstros.json` com os sprites novos.

**Critério de pronto:** print lado a lado parecido com a referência na mesma cena, e fps no perfil Baixo não piora mais que 10%.

### V5: Efeitos por elemento, números coloridos e arco de luz
**Objetivo:** efeitos saturados por elemento, números de dano coloridos e golpes com arco de luz.
- [ ] Paleta por elemento em `dados/elementos.json` (raio azul, fogo laranja, veneno verde, arcano roxo).
- [ ] Números de dano coloridos por elemento, com contorno e crítico maior, em `efeitos.gd`.
- [ ] Limite de números visíveis e agrupamento em horda (`MAX_NUMEROS`).
- [ ] Arco de luz mais forte no golpe (`_pintar_corte`), respeitando `efe_particulas` e `efe_luzes`.
- [ ] Teste de legibilidade dos números no 1x.
- [ ] Portal com runas (aproveitar a V3).

**Critério de pronto:** print lado a lado parecido com a referência na mesma cena, e fps no perfil Baixo não piora mais que 10%.

### V6: Menus no mesmo visual
**Objetivo:** todas as telas com o mesmo visual da referência.
- [ ] Tema central em `cenas/tema_hud.tres`, com painel escuro, moldura e a paleta de `paleta.json`.
- [ ] Título em `scripts/hordas/main.gd` no visual novo.
- [ ] Telas de heróis e preparo (`tela_herois.gd`, `tela_preparo.gd`).
- [ ] Telas de mapa e status (`tela_mapa.gd`, `tela_status.gd`).
- [ ] Opções e pausa (`tela_opcoes.gd` e a pausa em `hud.gd`).
- [ ] Prints de cada menu em `build/menus/`, com texto em 1x e 2x.

**Critério de pronto:** print lado a lado parecido com a referência por tela, e fps no perfil Baixo não piora mais que 5%.

## Dúvidas

1. A pasta `docs/visual_2_5d/` só tem o `README.md`. Os arquivos que ele cita (`mundo.md`, `hud_menus.md` e `paleta.json`) não existem. Não criei nenhum deles.
2. Não há fps de base medido no perfil Baixo. A máquina de teste do Breno (i5-3470) é a referência. Precisa medir antes da V1 para os percentuais de "não piora mais que X%" fazerem sentido.
3. Os percentuais de X são propostas minhas. Confirmar com o Breno.
4. Não contei quantos heróis e monstros existem em `dados/herois.json` e `dados/inimigos.json`. Isso muda o tamanho do V4.
5. Câmera 3/4: o Breno quer um truque de 2D (achatar e desenhar em perspectiva) ou pseudo-3D de verdade? O custo e o risco são muito diferentes.
6. Resolução base: manter 640x360 com mais densidade ou subir para 960x540?
7. Fonte do HUD: qual fonte de alta resolução usar, com licença compatível com "nada de pack pago".
