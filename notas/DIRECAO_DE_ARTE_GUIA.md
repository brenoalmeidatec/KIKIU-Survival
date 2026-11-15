# Direção de arte do K.I.K.I.U: guia para outros jogos

Levantamento feito em 2026-11-06 a partir das fontes do repo `C:\Dev\KIKIU\KIKIU-Survival` (nada foi editado no repo). Tudo que é dedução e não tem fonte citada está marcado como **[inferência]**. Números de imagem são estimativas (a referência é uma imagem-conceito gerada por IA, ±10%).

Fontes principais: `docs/VISUAL_KIKIU.md`, `docs/visual_2_5d/` (README, `mundo.md`, `hud_menus.md`, `lacunas.md`, `paleta.json`, `PIPELINE_OBJETOS.md`), `docs/ideias_visual_gba.md`, `docs/PIXELFX.md`, `docs/LICENCAS_ARTE.md`, `docs/DESIGN_PERSONAGENS_E_DESCOBERTAS.md`, `jogos/hordas/projeto/v2/DESIGN.md`, `jogos/hordas/projeto/v2/paleta.gd`, `jogos/hordas/projeto/project.godot`, `jogos/hordas/fonte_arte/modelos3d/pixel3d.py`, `C:\Dev\KIKIU\notas\REVISAO_VISUAL_KIKIU.md`.

---

## 1. Resposta curta à pergunta

Sim, é isso. "Só Blender" não é a direção de arte. O estilo é uma **cadeia de quatro camadas**:

1. **Personagens e cenário** saem de modelos 3D simples no Blender, com câmera ortográfica fixa, luz única e toon de 3 tons, e viram pixel art por script (paleta fixa, contorno de 1 px, alfa binário).
2. **Efeitos** (fogo, raio, status, recompensa) vêm de folhas de pixel art do **pixelfx** (MIT, gerado por código com Node), tocadas no Godot.
3. **Luz e profundidade falsa** no Godot: sombra achatada no chão, sombra de contato, halos aditivos, `CanvasModulate` e `PointLight2D` só no que se mexe.
4. **Interface** em alta resolução, **não** em pixel art. Os textos usam fontes limpas e o layout é desenhado num bloco fixo de 960x540. Isso foi a maior reclamação da revisão visual.

Arte de terceiros entra só se for de licença livre e registrada (seção 8).

---

## 2. Regras concretas (números)

### 2.1 Resolução e grade

| Regra | Valor atual no código | Fonte |
|---|---|---|
| Viewport do jogo (Hordas v2) | **640x360**, `stretch/mode="viewport"`, `scale_mode="fractional"`, janela 1280x720 | `jogos/hordas/projeto/project.godot` linhas 44-49 |
| Filtro de textura | `default_texture_filter=0` (nearest) | mesmo arquivo, linha 62 |
| Bloco da UI | **960x540** ("UI px"). Fator = px de janela por UI px; canvas da UI = janela / fator | `v2/DESIGN.md` seção 1; `v2/escala_ui.gd` (LARG 960, ALT 540) |
| Recomendação para o mundo | **960x540** (pixel de 2 px em 1080p, herói ~8% da altura). Decidir por medição no i5-3470 | `visual_2_5d/mundo.md` seção 1 |
| Herói | quadro **44x60**, pé na linha **Y=57**, folha **23 colunas x 8 linhas** (1012x480) | `fonte_arte/modelos3d/hazaki.py` (cabeçalho, `PE_Y`, `COLUNAS`) |
| Rosto (retrato) | **52x52** | `hazaki.py` linha 356 |
| Monstros | quadros de andar + 1 quadro branco de flash, x **5 vistas**, mesma câmera e mesmo pé | `monstros.py` linha 170 |

**Inconsistência que precisa de decisão:** o `project.godot` do Hordas ainda está em **640x360 com escala fracionária**, mas a UI já é desenhada no bloco 960x540 e `mundo.md` recomenda 960x540. Além disso, a regra "1 px de arte = múltiplo inteiro de px de tela" (`notas/REVISAO_VISUAL_KIKIU.md`, item "Pixel único") **não é atendida** pela escala fracionária. [inferência] A resolução ainda não está fechada no código. Não copie 640x360 nem 960x540 sem medir.

**Cuidado com `ideias_visual_gba.md`:** ele fala em "viewport 480x270, escala inteira", mas esse número é do **Cairu** (`jogos/cairu/projeto/project.godot`, 480x270, escala inteira), não do Hordas.

### 2.2 Câmera e perspectiva 2.5D

- Câmera **ortográfica**, elevação **32°** no gerador (`pixel3d.camera(elevacao_graus=32.0, ...)`).
- A referência parece mais de cima: a elipse do portal dá **~50°**. `mundo.md` recomenda testar **45° para chão e sprites juntos**. Status: **não decidido**.
- **Sem rotação livre**: cada sprite é um quadro pré-renderizado por direção. As 8 direções no jogo são espelhos de 5 vistas (`vila_aldeao.md`). [inferência, pelo `monstros.py` e o `vila_aldeao.md`: as vistas 1-3 são espelhadas para as outras]
- Escala das figuras: `PPU = 60.0 / 2.55` (`monstros.py` linha 29). Herói ~1,9 unidade do Blender = 45 px. Para mudar o tamanho relativo, mexa em `ortho_scale` ou `PPU`, senão a figura é cortada.
- Tamanho relativo medido na referência (% da altura da tela): herói ~8%, monstro comum 6-7%, grande ~9%, elite ~13% (com barra de vida).

### 2.3 Alfa, paleta, luz e sombra

- **Alfa binário**: o sprite não tem semitransparência (`pixelar`: "alfa binário, cor na paleta mais próxima e contorno escuro de 1 px"). Semitransparência só em efeito e sombra.
- **Contorno escuro de 1 px** por fora da silhueta (`pixelar(contorno=True)`), na cor da primeira faixa da rampa.
- **Paleta fixa** `PALETA` com rampas dark fantasy: aço (8 tons), sangue (5), couro (4), ouro (4), musgo (3), osso (2), pedra (9), veneno (6), fogo (6), noite (5), pele (5), cobalto (6), folha (5). Rampas extras só entram por nome em `paleta_de(...)`. Fonte: `fonte_arte/modelos3d/pixel3d.py` linhas 20-75.
- **Sombreamento toon em 3 faixas** (`faixas=(0.35, 0.62, 1.0)`, limites `(0.22, 0.55)`). A referência usa 4-5 tons em herói e armadura. Proposta da `mundo.md`: 4 tons no herói e 3 nos monstros, com brilho de 1 px.
- **Luz de borda**: `pixelar(luz_borda=True)` sobe **um degrau dentro da rampa** no lado da luz. Proposta: usar a cor da luz (azul do golpe, laranja da tocha) em vez de um degrau cinza.
- **Uma luz só, de cima à esquerda**, no jogo inteiro. Sombra projetada e luz de borda seguem essa direção (`VISUAL_KIKIU.md`, "regra de ouro"). Constantes em `v2/visual.gd`:
  - `ACHATA = 0.42` (altura da sombra em relação ao sprite),
  - `INCLINA = 0.55` (quanto a sombra deita para a direita),
  - `COR = Color(0.13, 0.1, 0.22, 0.4)`, `COR_CONTATO = Color(0.1, 0.07, 0.16, 0.38)`,
  - atlas único de **1024x1024** para todas as sombras.
- **Sombra de contato** (mancha no pé) em todos os perfis. **Sombra projetada** só no perfil Alto (`mundo.md`, tabela).
- **Ambiente de noite**: `CanvasModulate` sugerido **#1c2a24 a #223029** (verde-azulado frio). No horror, luz mais fraca (`chao.gd`, `_aplicar_luz`).
- **Olhos dos monstros** acesos (vermelho `#ff3a2a`, âmbar, verde-pálido), como `material_emissao`. Regra 4 do README: legibilidade no escuro. **Dúvida em aberto:** a regra diz que só elite e chefe têm barra de vida, mas a referência mostra barra em vários monstros comuns.

### 2.4 Cor de elementos e dano (`visual_2_5d/paleta.json`)

| Elemento | Hex |
|---|---|
| Fogo | `#d87a2b` |
| Raio | `#336ec8` |
| Veneno | `#87d141` |
| Gelo | `#378fd2` |
| Arcano | `#8120ca` |

Números de dano: branco `#eeeeed`, vermelho `#c5251c` (recebido), laranja `#c24d29` (fogo), azul `#57afde`, verde `#87d141`. O próprio `paleta.json` avisa que são amostras históricas. A paleta de UI real é `v2/paleta.gd` (68 linhas, também lida pelo gerador de molduras). Use `v2/paleta.gd` como fonte única.

### 2.5 Cena escura e vinheta

- Luminância mediana da referência ~41/255, com cantos quase pretos (4-13). A cena é escura e a luz cria o contraste.
- O custo de preenchimento é o gargalo: `CanvasModulate`, halos aditivos (até `MAX_LUZES = 96`, `efeitos.gd`), sombras, névoa, vinheta e shader de escuridão tocam **todos os pixels da viewport**. Por isso o perfil Baixo corta.

---

## 3. Ferramentas e para que cada uma serve

| Ferramenta | Para quê | Onde |
|---|---|---|
| **Blender 4.5 LTS portátil** (sem instalar, em `C:\Dev\Tools\Blender`) | modelar em primitivas, render ortográfico no tamanho final, luz única, cenário pré-renderizado | `blender -b -P <script>` |
| **`pixel3d.py`** (base comum) | câmera, luz, toon de 3 faixas, paleta fixa, `pixelar` (alfa binário, contorno, luz de borda), `calibrar_pe`, `camera_topo`, `brilho` (halo em anéis) | `fonte_arte/modelos3d/pixel3d.py` |
| **`hazaki.py`, `cavaleiro.py`, `monstros.py`, `horror.py`, `v2_nicao.py`, `v2_lucas.py`** | um modelo por personagem. `hazaki.py` é modular (uma camada por equipamento, com holdout do corpo) | `fonte_arte/modelos3d/` |
| **`cenarios.py`** | piso pré-renderizado (Cycles, fator 4, média, pontilhado ordenado) e enfeites num atlas com ponto do pé | `blender -b -P cenarios.py [-- nome]`, ~2 min |
| **`mapas_v2.py` + `mapa_*.py` + `medidas_*.py`** | objetos de mapa em lote, câmera 45°, 1 m = 32 px, render 4x com média, `-t 6` | `fonte_arte/modelos3d/`, branches de mapa |
| **`ferramentas/conferir_objeto.py`** (Pillow + numpy, sem Blender) | checklist automático: alfa binário, até 40 cores, contorno de 1 px, sem pixel solto, sem corte, normal do mesmo tamanho | `PIPELINE_OBJETOS.md` seção 3 |
| **`gerar_objetos.py`** (Pillow, trilha A, folha do GPT) | recorte de folhas de imagem gerada, filtro BOX, quantização a 40 cores, normal estimado. **Trilha antiga**, dá mais retrabalho | `prototipos/cara_nova/objetos/` |
| **pixelfx** (Node, MIT, `patch-gg/pixelfx`) | efeitos em pixel art por código: `node tools/render.mjs <cat>/<efeito> --sheet --no-actor --out <pasta>` | clone em `C:\Dev\KIKIU\notas\pixelfx` |
| **`preparar_status.py`** | corta o boneco padrão do pixelfx, reduz à metade (média de caixa) e recorta os status | `fonte_arte/pixelfx_status/` |
| **`gerar_folhas.py`** (pixelfx) | gera folha nova com tamanho próprio e id novo | `fonte_arte/pixelfx/` |
| **`v2/fx_folha.gd`** | tocador de folhas: `tocar`, `prender`, `soltar`, `vivo`. Pool de tamanho fixo | `projeto/v2/` |
| **`v2/fx_status.gd`** | status sobre monstros (chama, relógio, estrelas) em pool fixo de 10 âncoras | `projeto/v2/` |
| **Godot 4.4.1** | `CanvasModulate`, `PointLight2D` com `blend_mode=ADD` e textura radial, normal map 2D, `Camera2D.zoom`, `texture_filter=nearest` | `project.godot` |
| **Spleen, Jersey, Press Start 2P** (fontes) | texto corrido em Spleen 16; títulos em Jersey 19/37/56; números e HUD de debug em Press Start 2P | `v2/DESIGN.md` seção 3; licenças em `docs/LICENCAS_ARTE.md` |
| **Fila do Godot** `notas/godot_fila.ps1` | roda o Godot com vagas nomeadas e `APPDATA` por worktree. Só no notebook | `C:\Dev\KIKIU\notas\godot_fila.ps1` |
| **ChatGPT / Codex (imagegen)** | referências e folhas-fonte no estilo. Não é o pipeline final | `notas/artes_chatgpt/`, `fonte_arte/` |
| **Blender MCP oficial** | **não usado**. `PIPELINE_OBJETOS.md` concluiu que `blender -b -P` faz o mesmo sem dependência nova. Só entra se houver objeto orgânico travado (critério: mais de 5 objetos, ou 1 h de script sem silhueta aceitável) | `PIPELINE_OBJETOS.md` seção 5 |

---

## 4. Fluxos passo a passo

### 4.1 Personagem (herói ou monstro)

1. Modelo em primitivas (`caixa`, `cilindro`, `esfera`) num script próprio, copiando `cavaleiro.py` ou `hazaki.py`. Escala com `PPU`, pé em altura fixa.
2. Material toon com `px3.material_toon(nome, px3.cor("hexa"), ...)`. A cor **sempre** passa por `px3.cor()` (armadilha 1 da seção 5).
3. `px3.preparar_render(W, H)` (sem antialiasing, Eevee com `taa_render_samples=1`, view "Standard") e `px3.camera(elevacao_graus=32.0, escala=...)`.
4. Uma vista por direção. Para cada quadro: `px3.pixelar(px3.render_rgba(), paleta=PAL)`, onde `PAL` vem de `paleta_sem(...)` ou `paleta_de(...)`.
5. `salvar_png` em `projeto/assets/personagens/<nome>/` (`andando_8.png`, `rosto.png`, `camadas/<camada>.png`).
6. Olhar a prévia com régua e herói de 41 px (`previa_brutos.py ... --final --heroi`) e com luz (`--luz`). Rodar `conferir_objeto.py`.
7. Atualizar o JSON de elenco ou de inimigos. Atualizar `docs/LICENCAS_ARTE.md` se houver fonte de terceiro.

### 4.2 Cenário (piso e enfeites)

1. `cenarios.py` renderiza o piso em Cycles com fator 4, reduz por média e põe na paleta com pontilhado ordenado (`pixelar(pontilhado=...)`). Azulejo de **512 px** que repete (cruzamento), enfeites num atlas com ponto do pé.
2. Halos de luz assados (`brilha()`) para lanternas e braseiros fixos (`cenario.json`).
3. `dados/cenarios.json` (`por_fase`) escolhe o cenário da fase. Lista vazia volta ao chão antigo.
4. No jogo: `scripts/hordas/cenario.gd` e `chao.gd` (`ESCALA = 2.0`, `BLOCO = 256`, `CEL_DECO = 150`). Ao mudar a resolução, redimensione `BLOCO` e os pés dos enfeites em px (`cenario.json`).

### 4.3 Efeito (pixelfx)

1. No clone do pixelfx: `node tools/render.mjs <cat>/<efeito> --sheet --no-actor --out <pasta>`. Abra o PNG antes de usar, porque alguns efeitos de status pintam o boneco padrão.
2. Copie para `projeto/assets/v2/pixelfx/<categoria>/` e rode `--headless --import` (gera o `.import`; versione os dois).
3. Registre em `dados/v2_pixelfx.json` (obrigatórios: `arquivo`, `quadro`, `colunas`, `quadros`, `fps`, `pivo`; opcionais: `loop`, `escala` inteira, `cor`, `camada`, `aditivo`, `limite`, `intervalo`, `decorativo`, `clarao`). Corte os quadros vazios do fim.
4. Chame `combate.fx_folha.tocar(id, pos)` ou `prender(id, alvo)`, e `soltar(alca)` ao acabar.
5. Escala **inteira**. Fração mistura pixels de tamanhos diferentes, e o `fx_folha` arredonda com aviso. Outro tamanho = folha nova com id novo, não escala fracionária.
6. Registrar o PNG em `docs/LICENCAS_ARTE.md` (origem pixelfx, MIT, Copyright Patch e Hugo Duprez) e cobrir em teste (`testes/v2_fx_folha.gd`).

### 4.4 Interface e menus

1. Todo layout é desenhado no bloco 960x540 e ancorado ao bloco ou ao canvas (`DESIGN.md` seção 1). Nada de posição em px de janela.
2. Cores só de `v2/paleta.gd`. Cor nova entra lá **e** na tabela do `DESIGN.md`.
3. Molduras por `StyleBoxTexture` com 9-patch, `texture_margin_*` de 12-16 px no tamanho nativo, `region_rect` apontando para a moldura (o canto ornamentado não estica). O gerador de molduras (`hud_molduras/`) lê `paleta.gd`.
4. Texto corrido em Spleen 16; títulos em Jersey 19/37/56; números em Press Start 2P.
5. Medição de UI no headless: Spleen mede o **dobro** (32 px em vez de 16). Meça linhas vezes a altura da fonte em janela real. Nunca compare `size` com `get_minimum_size()`, porque o `size` é forçado ao mínimo e a checagem sempre passa. Prove que o teste falha no código antigo.

### 4.5 Captura e verificação visual

- Visual só vale com captura em **janela real** 960x540 (não versionada). No PR, diga o que não foi visto.
- Antes e depois no viewport real, lado a lado com a referência (`notas/REVISAO_VISUAL_KIKIU.md`, itens de processo).
- Vídeo: uma gravação curta por rodada, 5 a 10 quadros-chave em folha de contato. [fonte: memória do usuário, não doc do repo]

---

## 5. O que deu errado e virou regra

| Problema | Consequência | Regra adotada | Fonte |
|---|---|---|---|
| Cor hex passada direto ao Blender | tudo lavado (vermelho vira marrom) | `px3.cor()` converte para cor linear | `PIPELINE_OBJETOS.md`, armadilha 1 |
| Peça pendurada sem manter o lugar | posição soma duas vezes, peça flutua | `pendurar()` | idem, armadilha 2 |
| Sombra própria ligada em 44 px | chiado na luz | sombra própria desligada nas luzes | idem, armadilha 3 |
| Sinal do `shift_y` | peça para o lado errado | linha da imagem cresce para baixo; `shift_y` vai para cima | idem, armadilha 4 |
| Sombra com textura inclinada na hora | degraus irregulares | sombra calculada pixel a pixel por quadro, num atlas | `VISUAL_KIKIU.md` |
| Sombra "fantasma" de 1 px | sombra suja | cuidado com o pixel extra (referência Catlike Coding) | `VISUAL_KIKIU.md` |
| Normal map em toda a horda | 1 luz sem sprites extras: 1.423-1.554 fps; com 300 sprites normais: 678 fps | normal map só no herói e nas elites | `mundo.md` seção 6, PR #148 |
| Normal map sobre sprite já sombreado | efeito sutil, volume aparece duas vezes | testar albedo sem sombra assada antes de julgar | `mundo.md` seção 2 |
| Halos sem limite | custo de preenchimento | `MAX_LUZES=96`, cai para 24 em perfil baixo | `mundo.md` seção 6 |
| Revisão visual nota 5,25/10 | HUD, golpes, números, herói e prompts pareciam protótipo; o cenário era bom | HUD e efeitos com o mesmo rigor de pixel do cenário; um PR por item; prints antes e depois | `notas/REVISAO_VISUAL_KIKIU.md` |
| Golpe como mancha branca chapada | ilegível | arco de lâmina em 3-4 quadros, alfa 60-70%, núcleo claro, cor por elemento, hit-flash só no inimigo | idem, item 2 |
| Pool de inimigo subdimensionado | cria nó no meio da partida e engasga no i5 | dimensionar pelo pico de vivos (vila: pico 39, pool 64, folga mínima 25%) | `vila_aldeao.md` |
| Notebook com GPU fraca | ~15 fps na RTX 3060 com horda cheia; hipótese de preenchimento, não CPU | cortar fill rate antes de CPU | `mundo.md` seção 6, LOGBOOK |
| Chão xadrez liso nos mapas de sala | mapa parecia "tosco" | paredes com face visível, rodapé, objetos com volume, sombra de contato | `ideias_visual_gba.md`, diagnóstico |
| Shader de escuridão caro (`escuro_halo`, até 8 leituras da tela) | suspeita de custo | medir antes de cortar | `mundo.md` item 2 |
| Pixel misto (escala fracionária) em efeito | pixels de tamanhos diferentes | escala inteira; folha nova para outro tamanho | `PIXELFX.md` |

---

## 6. Legibilidade e identidade (regras de conteúdo)

- **Legibilidade antes de beleza.** Herói, objetivos e portal sempre se destacam (`v2/DESIGN.md` e regra 4 do README 2.5D).
- **Monstros com olhos acesos** para ler no escuro.
- **Identidade dos heróis**: cada um tem paleta própria por rampa (Hazaki: pele, aço, cobalto). Nicão, Lucas, Matheus e João têm folhas do Blender sobre o rig do Hazaki. Ver `docs/DESIGN_PERSONAGENS_E_DESCOBERTAS.md` e `docs/visual_2_5d/blender_herois/`.
- **Identidade dos mapas**: cada fase escolhe um cenário (`dados/cenarios.json`), e cada cenário tem a luz dele (lâmpada de sódio na cidade, verde e vela no laboratório, tocha na masmorra).
- **Variedade de silhueta de monstro** tem de vir de peças ou sementes, não só de cor (`mundo.md`, seção 4).
- **Limite desta leitura:** `DESIGN_PERSONAGENS_E_DESCOBERTAS.md` tem 1200 linhas. Só os trechos de arte foram lidos.

---

## 7. Guia de reuso para outro jogo

1. **Escolha a base** (resolução do bloco de UI e do mundo). Decida por medição, não por número de tabela. Hoje há conflito entre o `project.godot` (640x360) e a decisão 960x540 pendente.
2. **Copie o núcleo do pipeline, não o conteúdo**: `pixel3d.py` (câmera, toon, paleta, `pixelar`, `brilho`, `camera_topo`, recorte). Troque `RAMPA` pelas rampas do seu jogo.
3. **Mantenha as 4 regras que definem o estilo**: uma luz só, de cima e à esquerda; alfa binário com contorno escuro de 1 px; sombreamento em 3 a 4 faixas; render no tamanho final, sem antialiasing.
4. **Sombras e luz no engine**, não no albedo. Sombra projetada e de contato como em `visual.gd`.
5. **Efeitos por folha pixelfx** (MIT) ou arte própria, sempre em escala inteira.
6. **UI separada do mundo**: bloco de layout fixo, paleta em um arquivo só, fonte limpa para texto, pixel só onde é identidade.
7. **Registro de licença** para tudo que não é próprio (`docs/LICENCAS_ARTE.md`), mesmo que seja CC0.
8. **Verificação**: captura em janela real, antes e depois, e medição de fps no perfil mais fraco.

---

## 8. Licenças e fontes de arte

- Regra (2026-10-12, decisão do Alisson): nada de arte com direitos autorais. Livre uso (CC0, domínio público, Unlicense, CC BY com crédito, MIT, BSD, zlib, SIL OFL) pode entrar.
- **Não serve**: sem licença, "uso pessoal", CC BY-NC, CC ND, copyleft (CC BY-SA, GPL, LGPL: só com OK caso a caso), pago (só com OK do Breno).
- Registro obrigatório em `docs/LICENCAS_ARTE.md` (fonte, autor, licença, mudanças). Crédito na tela de Créditos quando a licença pedir.
- Candidatos citados: Modern Interiors (LimeZu, pago, US$ 1,50, **não comprado**), Kenney roguelike indoor (CC0), paletas Lospec Endesga 32/64 e Resurrect 64 (livres), Better Terrain (Unlicense), Pixelorama (grátis), Aseprite (US$ 19,99).
- Arte de terceiro já no jogo: pixelfx (MIT). Fontes: ver `docs/LICENCAS_ARTE.md`.

---

## 9. Pendências em aberto (confirmadas nas fontes)

- Resolução final: 960x540 ou 640x360 (`mundo.md` decide por medição no i5-3470).
- Elevação da câmera: 32° ou 45-50° (`mundo.md` seção 1).
- Normal map: só herói e elites, ou testar albedo novo antes de julgar (`mundo.md` seção 2).
- Barra de vida em monstro comum (a regra 4 diz só elite e chefe; a referência mostra em vários).
- Escala fracionária x pixel inteiro no `project.godot`.
- Feixe do portal (`#d221ff`): "não verificado" (`mundo.md` seção 2).

---

## 10. Índice de arquivos úteis

- Direção: `docs/VISUAL_KIKIU.md`, `docs/visual_2_5d/README.md`, `docs/visual_2_5d/mundo.md`, `docs/visual_2_5d/hud_menus.md`, `docs/visual_2_5d/lacunas.md`, `docs/visual_2_5d/paleta.json`, `docs/visual_2_5d/PIPELINE_OBJETOS.md`, `docs/ideias_visual_gba.md`
- Referência: `docs/imagens/referencia_2_5d.webp` (1672x941), `docs/imagens/comparacao_atual_vs_2_5d.png`
- Pipeline: `jogos/hordas/fonte_arte/modelos3d/pixel3d.py`, `hazaki.py`, `monstros.py`, `cenarios.py`, `mapas_v2.py`, `cavaleiro.py`, `vila_aldeao.md`
- Engine: `jogos/hordas/projeto/v2/visual.gd`, `v2/paleta.gd`, `v2/fx_folha.gd`, `v2/fx_status.gd`, `v2/escala_ui.gd`, `v2/DESIGN.md`, `scripts/hordas/cenario.gd`, `chao.gd`, `efeitos.gd`, `project.godot`
- Dados: `jogos/hordas/projeto/dados/v2_pixelfx.json`, `cenarios.json`, `v2_elencos.json`
- Licenças: `docs/LICENCAS_ARTE.md`, `docs/PIXELFX.md`
- Notas (fora do git): `C:\Dev\KIKIU\notas\REVISAO_VISUAL_KIKIU.md`, `RETOMADA_KIKIU.md`, `godot_fila.ps1`, `pixelfx\`
