# Direção de arte do KIKIU (guia global)

Guia para o Alisson, o Breno, o Isac (diretor de arte do projeto, #459) e qualquer IA que chegue sem contexto e precise fazer um jogo de **outro gênero** mantendo a mesma identidade visual. Tudo que está marcado como **[proposta]** é extrapolação, nunca foi provado no KIKIU. O resto vem das notas e do repo. Quem decide mudança de regra é o Alisson (e o Breno em tudo que custa dinheiro); o guia descreve, não decreta.

Caminhos relativos partem da raiz deste repositório, exceto os que começam com `notas\`: essa pasta fica fora do git, na máquina do Alisson (`C:\Dev\KIKIU\notas`). Uma cópia deste guia também fica em `C:\Dev\KIKIU\DIRECAO_DE_ARTE.md`, para os jogos novos fora deste repo; se uma mudar, atualize a outra.

Data da compilação: 2026-11-06. Os números abaixo vêm do código e dos docs nessa data; se o código mudou, o código manda.

---

## 1. O DNA em um parágrafo

O KIKIU é um jogo **2.5D escuro**, visto de cima a uma inclinação de câmera, com **pixel art de grade única de 1 px**, **paleta enxuta e fixa**, **contorno escuro de 1 px**, **alfa binário** nos sprites, cenário mergulhado em escuridão com **poças de luz**, herói de uns **39 px de altura** num bloco de **960x540**, monstros com **olhos vermelhos acesos** para ler no escuro, e **interface em alta resolução (não pixelada)** com molduras de pedra/ferro e detalhes dourados. Vermelho é reservado a perigo para o jogador; ouro é o destaque do estilo. A identidade não está em uma ferramenta: está em um conjunto de **regras de pós-processo** (grade, paleta, contorno, alfa) que qualquer fonte de imagem tem que passar antes de entrar no jogo.

Referência visual: `docs/imagens/referencia_2_5d.webp`. Fases e estudos: `docs/visual_2_5d/` (`README.md`, `mundo.md`, `PIPELINE_OBJETOS.md`, `paleta.json`, `lacunas.md`, `hud_menus.md`). Os tamanhos medidos na referência são estimativas sobre uma imagem gerada por IA (margem de uns 10%).

---

## 2. A tese central: Blender sozinho não serve

O Alisson levantou, e está certo. O estilo do KIKIU é uma **cadeia de camadas**, cada uma resolve uma coisa e deixa outra descoberta. O Blender dá volume, pose e consistência entre ângulos, mas não faz efeito, clima, HUD nem retrato. E mesmo o que sai do Blender **não entra cru**: passa por scripts Python (montagem de folha, normal map, medição) e pelo conferidor de sprite. O CLAUDE.md do repo mantém o Blender por script como o caminho para heróis, monstros e cenários próprios; arte livre e IA complementam.

| Camada | Ferramenta | Para quê | O que ela NÃO resolve |
|---|---|---|---|
| 1. Volume e pose | **Blender** por script (`blender -b -P ...`), câmera ortográfica | Forma 3D, rig, poses, 8 direções iguais entre si, luz, normal map | Efeitos, chamas, clima, HUD, retrato pintado. Também não dá pixel art: o render é só matéria-prima |
| 2. Conversão para pixel | **Python + Pillow + numpy** (`gerar_objetos.py`, `pixel3d.py`, `mapas_v2.py`) | Heróis e monstros: o Blender já renderiza no tamanho final (pixel nativo, sem antialiasing, sombreamento em faixas, contorno de 1 px). Objetos de mapa: render 4x e média BOX. Folhas de IA: BOX, alfa binário, quantização a 40 cores sem dithering, normal map estimado. Folha, normal e medição por script | Não inventa desenho. Se o 3D está feio, o pixel sai feio |
| 3. Efeitos | **pixelfx** (MIT, de terceiros) + desenho procedural em GDScript + shaders + Blender para uns poucos efeitos próprios (o corte da katana, `blender_corte`; as folhas de `blender_efeitos` ainda não estão no jogo) | Impacto, partículas, status, portais, clima, brilho, golpes | Não dá o personagem. Folha de terceiros pode vir com boneco dentro (precisa checar) |
| 4. Luz e sombra | **Godot** (PointLight2D, normal map, shaders) | Poças de luz, relevo, tremeluz de tochas | Só funciona se o sprite trouxe normal map e a cena está escura |
| 5. UI/HUD | Molduras 9-slice e barras geradas por Python (`jogos/hordas/projeto/v2/hud/gerar_molduras.py`, `gerar_moldura_premium.py`; as de retrato, barra e habilidade são arte do Codex processada por `gerar_objetos.py hud`), fontes pixel, código GDScript | Painéis, barras, cartas, ícones, texto | Não usa o filtro de pixel do mundo: é outra camada, em alta resolução |
| 6. IA generativa | ChatGPT logado do Alisson, imagegen do Codex | **Referência** de personagem; ícones e cartas que, depois de reduzidos por script, viram asset | Letra miúda, transparência confiável, rotação limpa. Nunca é entregue sem o script de redução |

Resumo operacional: **Blender gera forma, o script gera pixel, o pixelfx/código gera efeito, o Godot gera luz, o código gera interface, a IA gera ideia.** Qualquer jogo novo precisa de um dono para cada uma dessas seis responsabilidades, mesmo que alguma seja "não tem nesse jogo".

---

## 3. Regras invioláveis

Estas valem em qualquer gênero, a não ser que o Breno e o Alisson decidam mudar de forma explícita.

**Grade de pixel.** Um pixel de um tamanho só no jogo inteiro. Posição e canto arredondados para pixel inteiro ao desenhar. Escala de folha **só inteira**: escala fracionária mistura pixels de tamanhos diferentes e borra. Se um efeito de terceiro tem escala fracionária (0,45, 0,7), regera a folha na grade final com `jogos/hordas/fonte_arte/pixelfx/gerar_folhas.py` (saída com sufixo `-eNN`, escala x100, ex. `-e70`) e registra com id próprio.

**Resolução.** A UI é desenhada num bloco de **960x540** ("UI px"), e a janela só muda o fator (passos de 0,5, nunca corta). O mundo roda num SubViewport 960x540 com filtro nearest, mostrado com "sharp bilinear" (`v2/apresentacao.gd`). **Atenção, conflito aberto:** o `project.godot` do Hordas ainda declara viewport 640x360 com `scale_mode="fractional"`, enquanto a UI, a apresentação v2 e o `docs/visual_2_5d/mundo.md` trabalham em 960x540. O item "decidir a resolução base e registrar em `project.godot`" segue sem marcar em `docs/visual_2_5d/lacunas.md`. Para um jogo novo, escolha uma base e **escala inteira** desde o dia 1. O número 480x270 de `ideias_visual_gba.md` é do jogo Cairu, não do Hordas.

**Alfa binário** (0 ou 255) nos sprites de personagem, inimigo e objeto. Efeitos têm alfa em degraus na prática (a sombra dos pés usa poucos degraus de alfa; não há regra escrita de quantos, [proposta] tratar como contrato por efeito). Halo de alfa baixo em volta de arte de IA é cortado por alfa >= 160 antes de qualquer redução (`docs/LICENCAS_ARTE.md`).

**Paleta fixa.** Sprites: no máximo **40 cores** por padrão (`ferramentas/conferir_objeto.py`, `--cores`), quantização sem dithering. Folhas de armas claras usam 48 (`COR_ARMAS_CLARO` em `gerar_objetos.py`), fundo de título usa 48 (`fonte_arte/gerar_fundo_titulo.py`). Poucos tons por material (3 a 5, `docs/combate_v2/SPEC_ARTE.md`). UI: paleta única em `jogos/hordas/projeto/v2/paleta.gd`, lida também pelo gerador Python. Cor nova entra lá **antes** do uso. Vermelho só para perigo ao jogador (efeito e arma do herói saem em ouro, âmbar, ciano ou verde-menta, `v2/DESIGN.md`); a fusão é magenta e não se confunde com o lendário; verde nunca é ameaça (marca de aliado).

**Contorno.** Escuro de 1 px em pelo menos 90% da borda (luminância < 60). O `docs/combate_v2/SPEC_ARTE.md` pede contorno escuro também em projétil. O prompt das armas evoluídas pediu "aço escuro com contorno claro" e o conferidor exige escuro em 90% da borda, então contorno claro em projétil escuro é exceção **não codificada** (dúvida aberta, não regra). Sem pixel solto sem vizinho em 4 direções. Sprite não encosta na borda da imagem.

**Rotação.** Nunca girar sprite em ângulo qualquer com filtro. Shader só troca UV em 0°, 90°, 180°, 270°. Ângulos intermediários saem pré-gerados com RotSprite (`fonte_arte/blender_corte/girar_corte.py`, variantes em 22,5°, 45°, 67,5°). IA que gira 45° e alterna duas poses: pegar o 1º quadro e girar no script.

**Legibilidade.** Herói, objetivos e portal sempre se destacam. Monstros têm olhos vermelhos acesos. Números de dano agregados por alvo (janela de 0,1 s), "PERFEITO!" pequeno com fade, nada de depuração visível.

**Texto.** Spleen 8x16 só em 16 ou 32 px (corrido); Jersey 10 só em 19, 37 ou 56 px (títulos); Press Start 2P em 8 ou 16 px (números, HUD). No máximo duas fontes na mesma tela (pedido da revisão visual, `notas\REVISAO_VISUAL_KIKIU.md`; o projeto tem três famílias, Press Start, Spleen e Jersey). Sem ligaduras. Selos com letra ficam em **código**, não em IA.

**Acessibilidade "Reduzir piscadas"** (`v2/piscadas.gd`). Teto de `MAX_TROCAS_S = 3.0` trocas de luminância por segundo em qualquer janela deslizante de 1 s, o que equivale a cerca de **1,5 Hz** num seno. (O briefing falava em 2 Hz; o código diz 1,5 Hz, vale o código.) Todo efeito que liga e desliga passa por `piscadas.gd` (`pulso`, `pisca`, `valor`, `clarao_permitido`), nunca por `Config.v(...)` solto. Com a opção ligada: flash de acerto com alfa fixo 0,5, clarões de tela recusados, glitch de clima desligado, shader com `calmo = 1`.

**Desempenho no i5-3470 do Breno** (alvo ainda **não medido**; o 5600X do Alisson é teto, não alvo). Pools de tamanho fixo criados na montagem; **nenhum nó criado no meio da partida**; pool de inimigo dimensionado pelo **pico** de vivos. Perfis Baixo/Médio/Alto; efeitos decorativos somem no Baixo (campo `decorativo`). Ajuste dinâmico desce o perfil abaixo de 40 fps (`v2/qualidade_auto.gd`). Medir pico só com a máquina parada.

**RNG.** Efeito não mexe no RNG da partida: usa `_rng` próprio (padrão de `v2/efeitos.gd`; `v2/clima.gd` usa semente fixa para ser reproduzível).

**Licenças e copyright** (`docs/LICENCAS_ARTE.md`, append-only).
- Serve: CC0, domínio público, Unlicense, CC BY 3.0/4.0 (com crédito), OGA-BY, MIT, BSD, zlib, SIL OFL (fontes, com o texto junto).
- Não serve: copyright reservado, "uso pessoal", "só estudo", extração de outros jogos, fan art de propriedade alheia, CC BY-NC, CC ND.
- Precisa de OK: copyleft (CC BY-SA, GPL, LGPL) pelo Alisson; qualquer coisa paga pelo Breno.
- Serviço com conta: só o resultado cozido vai ao Git, nunca o arquivo-fonte cru.
- Licença é por arquivo: conferir na página do arquivo no dia. Em dúvida, não usa e pergunta.
- **Nada de arte copiada.** O registro proíbe capturas ou extrações de outros jogos, filmes e marcas e fan art de propriedade alheia; inspiração é só de ideia (a frase "só de ideia" é deste guia). O que for de livre uso precisa ainda ser **compatível** com o jogo (pixel art 2.5D escura, herói de ~39 px em 960x540, paleta enxuta); se adaptar custar mais que fazer no Blender, não vale. CC BY pede crédito na tela de Créditos e no registro.
- Toda arte gerada por IA é registrada em `docs/LICENCAS_ARTE.md` como arte própria gerada (ChatGPT na conta do Alisson ou imagegen do Codex), com o prompt guardado. As notas **não** trazem análise dos termos de uso do serviço de IA sobre propriedade comercial do output: confirmar com o Alisson antes de publicar jogo comercial com esse material.
- Rostos reais (referências dos heróis com a cara dos amigos) dependem de autorização de uso de imagem.

---

## 4. Pipeline por tipo de asset

### 4.1 Personagem (herói)

1. **Referência:** ChatGPT do Alisson gera a imagem de referência (guardar em `notas\artes_chatgpt\`). Serve só para guiar o modelo 3D.
2. **Modelo no Blender** por script (`jogos/hordas/fonte_arte/modelos3d/*.py`, `pixel3d.py`, `jogos/hordas/prototipos/cara_nova/gerar_cara_nova.py`). Cor em **linear** no Blender. Câmera ortográfica; hoje o gerador usa **32°** de elevação (`pixel3d.py`, `camera(elevacao_graus=32.0)`), o herói a 45° em 24,5 px/m.
3. **Render já no tamanho do jogo.** Os heróis do Blender (`fonte_arte/blender_herois/`) saem em pixel nativo: Cycles com 1 amostra, filtro BOX mínimo, sem antialiasing nem bloom, 8 direções, cor e normal. Quadro do herói 32x44 com pé na linha 42 (o mecha usa 128x192, o Nicão 64x96: não há um quadro único no pipeline). Os monstros de `gerar_cara_nova.py` saem em 5 vistas x 4 quadros de andar, espelhadas para 8 direções. O render 4x com média BOX é do cenário (seção 4.3), não do personagem.
4. **Paleta, contorno e normal:** a paleta fechada e o contorno de 1 px no tom escuro da cor vêm do próprio render (rampas de `pixel3d.py`, casca invertida nos heróis); o normal map vem do pipeline do jogo (`gerar_cara_nova.py`); `montar_folha.py` junta os quadros na folha.
5. **Conferir:** `ferramentas/conferir_objeto.py` (alfa binário, <= 40 cores, contorno, sem pixel solto, não cortado) e o `medir.py` de cada herói (`fonte_arte/blender_herois/<herói>/medir.py`, nada tocando a borda).
6. **JSON de sprite:** o campo `colunas` guarda só parado + andar; colunas de ação novas vão no fim da folha, na ordem de `nomes_colunas` (`heroi.gd` anda com `colunas.size() - 1` quadros; ver `fonte_arte/blender_herois/hazaki/LEIA-ME.md`).
7. **Registrar** em `docs/LICENCAS_ARTE.md`.

### 4.2 Inimigo

Mesmo fluxo do herói, com 5 vistas x 4 quadros de andar espelhadas para 8 direções (`docs/LICENCAS_ARTE.md`). Olhos vermelhos acesos. Tinta de elenco por mapa (`tinta` do monstro) como cor-base. Pool dimensionado pelo pico de vivos. Barra de vida em monstro comum é pendência aberta (a regra 4 não prevê).

### 4.3 Cenário, tile e objeto de mapa

Trilha B (Blender): câmera ortográfica a 45°, 1 m = 32 px, render 4x com média, `blender -b -t 6 -P mapas_v2.py -- cidade`, **um Blender por vez**. Cores só das rampas de `pixel3d.py`. Objetos de 20 a 150 px decidem pela silhueta, paleta e contorno. Normal map real.
Trilha A (folha de IA): `prototipos/cara_nova/objetos/gerar_objetos.py` faz flood fill do fundo, recorte, filtro BOX, alfa binário, quantização a 40 cores, normal map estimado.
**Piso:** grade de 1 px, sem pontilhado, sem perspectiva desenhada à mão (o piso da floresta foi refeito por isso).

### 4.4 Efeito (impacto, status, portal, partícula)

Três famílias: folha animada (pixelfx de terceiros, Blender próprio, ou Python/GPT próprio), desenho procedural em código, shader `.gdshader`. Fluxo de trazer um efeito do pixelfx:

1. Gerar no clone externo (`notas\pixelfx`): `node tools/render.mjs <categoria>/<efeito> --sheet --no-actor --out <pasta>`. **Olhar o PNG antes de usar** (alguns status trazem o boneco padrão).
2. Copiar para `jogos/hordas/projeto/assets/v2/pixelfx/<categoria>/`, rodar `godot --headless --import`, versionar PNG e `.import`.
3. Registrar em `jogos/hordas/projeto/dados/v2_pixelfx.json` (`arquivo`, `quadro`, `colunas`, `quadros`, `fps`, `pivo`; opcionais `loop`, `escala` inteira, `cor`, `camada`, `aditivo`, `passo`, `limite`, `intervalo`, `decorativo`, `clarao`).
4. Escala não inteira: `gerar_folhas.py` e id novo.
5. Chamar `fx_folha.tocar(id, pos)` ou `prender(id, alvo)` (`v2/fx_folha.gd`).
6. Linha em `docs/LICENCAS_ARTE.md` (pixelfx: MIT, Patch e Hugo Duprez, aviso de copyright obrigatório).
7. Teste em `testes/v2_fx_folha.gd`.

Efeito gigante não entra como folha: `weather/*` e `scifi/glitch` (até 4800x4320) foram portados para código em `v2/clima.gd`. Status do KIKIU: só fogo (`burning`), lentidão (`slowed`) e atordoamento (`stunned`); veneno, congelado e sangrando **não existem como mecânica**. A chama de `burning` é desenhada por script (`fonte_arte/pixelfx_status/preparar_status.py`), porque a folha original pinta o boneco inteiro.

Golpes automáticos (projétil, meteoro, anel, nuvem): tira horizontal, célula exata, `indice_<grupo>.json` com `quadro`, `n`, `fps`, `loop`, `ancora`, `gira`; gerada por `fonte_arte/armas_anim/gerar_*.py` ou Blender. Contrato em `docs/combate_v2/SPEC_ARTE.md` e `docs/animacoes_armas_v2.md`. Regra de ouro: nada de PNG parado, quadros diferentes entre si.

| Tipo | fps usado no KIKIU |
|---|---|
| Pixelfx (quase tudo) | 30 (`burning`: 14) |
| Voo de projétil | 12 (aponta) ou 16 (giro) |
| Impacto | 15 a 20 |
| Nuvem | loop 6, entrada e saída 10 |
| Anel expandindo | 20 |
| Invocação | andar 10, atacar 14, parado 6 (voadores: andar 12) |

### 4.5 UI, ícone e HUD

Tudo no bloco de 960x540. Paleta de `v2/paleta.gd`. Painel de pedra: 9-slice `moldura_pedra.png` 20x20, margem 5 px, tingida por `modulate`. Painel premium (menus): `moldura_premium.png` 32x32, bisel dourado, gerado por `v2/estilo_premium.gd`. Cartão de carta: `StyleBoxFlat`, borda 2 px (+1 épico/lendário, +1 selecionado). HUD da partida (cantos em 1,5x, decisão do Alisson #368): retrato 90x108, barras de vida e fôlego, cards E e secundário de 86x74 desenhados (129x111 na tela), Q em círculo de 96 px na tela. Ícone de carta 32x32 (escolha, baú, slots) e 16x16 (linha do SUA BUILD). Molduras e barras geradas por `jogos/hordas/projeto/v2/hud/gerar_molduras.py`. Fonte única de estilo em `jogos/hordas/projeto/v2/DESIGN.md`.

### 4.6 Cartas e ícones de IA

Pedir **tamanho grande** (nunca 32x32 direto), fundo transparente de verdade (se não der, `#FF00FF` e o script converte), sem anti-aliasing, sem texto, sem grade. Reduzir com `reduzir_icones.py` ou `reduzir_cartas.py` (em `jogos/hordas/fonte_arte/lightwolf_icones/`). Prompt guardado em `PROMPTS.md` da pasta `fonte_arte/` (ver `jogos/hordas/fonte_arte/armas_anim/PROMPTS.md` e `docs/armas_v2/FUSOES_ARTE_ALISSON.md`). Peças da fusão pedidas ao Alisson: moldura de 9 fatias 600x200, halo 48x48, arco de vento 64x32, ícone 16x16.

---

## 5. Como validar

1. **Testes de cena Godot** em `jogos/hordas/projeto/testes/`: `v2_pixel_*.gd` (ex. `v2_pixel_filtros.gd`: sem filtro linear no mundo e na UI, sombra em degraus de 1 px, golpes sem escala), `v2_fontes_folha.gd`, `v2_fx_folha.gd`, `v2_escala_ui.gd`, `v2_piso_pixel.gd`, `v2_sombras_blur.gd`, `v2_piscadas.gd`. Rodam dentro do job `testes` da CI.
2. **Conferidor de sprite** `ferramentas/conferir_objeto.py` (sem Godot). Hoje serve para brutos avulsos, **não roda na CI** (não há chamada em `ci.yml`). A extensão para validar grade de folha, quadros repetidos e loop emendado está planejada (`docs/animacoes_armas_v2.md`, item 7, #207) e **não está implementada**.
3. **Fotos de cena:** `jogos/hordas/projeto/testes/fotos/*.gd`, com `godot --path jogos/hordas/projeto res://testes/fotos/<cena>.tscn -- --fotos=PASTA`.
4. **GIF ampliado:** `python -I ferramentas/gifs_golpes.py PASTA_DOS_QUADROS PASTA_DOS_GIFS` (4x, `Image.NEAREST`, 33 ms por quadro).
5. **Folha de contato / gravação:** a regra do Alisson (memória do projeto) é **uma gravação curta por rodada, 5 a 10 quadros-chave em folha de contato, sem regravar por agente**. O fluxo existe como regra de trabalho; os argumentos exatos do Movie Maker (`--write-movie`, etc.) **não aparecem em nenhum script do repo**, apenas o comentário em `notas\godot_fila.ps1`. Tratar como [pendente de documentar].
6. **Janela do Godot:** nunca mostrar. `notas\godot_fila.ps1` abre o Godot com `--headless` ou oculto; **janela minimizada grava preto**, oculta grava certo (medido em 05/11). Fila de 2 vagas por padrão (`KIKIU_GODOT_VAGAS`). Worktree nova sem `.godot` dá "SCRIPT ERROR" falso: rodar `--headless --import` antes.
7. **Medição de UI:** em `--headless` a Spleen mede o dobro (32 px em vez de 16). Nunca comparar `size` com `get_minimum_size()`. Medir em janela de verdade e provar que o teste falha no código antigo.
8. **Ok visual humano:** visual só vale depois de captura com janela de verdade (não versionada). O PR diz o que **não** foi visto. Mudança grande de tela sem verificação visual espera o "pode mergear" do Alisson. Isso é convenção de texto, sem template que force.
9. **Desempenho:** `--picos=MS` (`v2/picos.gd`), robô de playtest (`ferramentas/playtest_v2.py`). Perfil Baixo no i5.
10. **Isolamento de save:** `ferramentas/teste_golpes_isolados.ps1` roda em APPDATA de QA com arquivos sentinela.

---

## 6. Adaptando para outros gêneros

**Legenda:** [provado] = já aconteceu no KIKIU. [proposta] = extrapolação deste guia, precisa ser testada num protótipo antes de virar regra. Nenhum dos gêneros abaixo foi feito no KIKIU; o único provado é o survival/horda de câmera superior 2.5D.

### 6.1 O que fica igual em todos os gêneros [provado]

Cadeia de camadas da seção 2, regras da seção 3, pós-processo Python (BOX, alfa binário, paleta, contorno), pixelfx/código para efeitos, UI em alta resolução, licenças, acessibilidade, pools fixos. O Blender continua sendo a fonte de consistência entre ângulos **quando houver ângulos para ser consistente**.

### 6.2 Tabela por gênero

| Gênero | Mantém | Muda [proposta] | Armadilhas [proposta] |
|---|---|---|---|
| **Plataforma 2D** | Grade 1 px, paleta, contorno, pixelfx, UI | Câmera lateral: 2 direções (espelhar), em vez de 8. Blender vira opcional (render lateral ortográfico) ou se troca por desenho direto. Ênfase em **animação** (corrida, salto, queda) mais que em volume | Contorno de 1 px em fundo detalhado perde leitura; tile de cenário precisa emendar sem costura; a elevação de 32°/45° não existe mais |
| **RPG top-down** | Quase tudo: é o mais próximo do KIKIU | 4 direções costumam bastar; sprite de NPC com poucas poses; retrato pintado (IA como referência, fora do Blender); muita UI (diálogo, inventário) | Texto em volume (fontes Spleen/Jersey já aprovadas); mapa grande exige tile e oclusão por camadas; muito NPC = muita folha |
| **Metroidvania** | Paleta, contorno, efeitos | Lateral como plataforma, mais **sprites de chefe grandes** e cenário em camadas de parallax; paleta por bioma | Chefe grande estoura o limite de cores/orçamento; consistência de paleta entre biomas; backtracking pede legibilidade de saídas |
| **Luta** | Pós-processo, pixelfx, UI | Muitos quadros por golpe, quadros-chave iguais entre personagens, caixas de acerto separadas da arte; efeitos de impacto são o centro | Orçamento de quadros explode; "Reduzir piscadas" pega em flash de acerto; sem retoque manual o Blender sozinho dá animação "dura" |
| **Roguelike de cartas** | UI em alta resolução, paleta, fontes, molduras 9-slice, reduzir_cartas.py, cartão com raridade (borda +1) | Pouco ou nenhum sprite animado; arte de carta/ilustração em IA reduzida por script (já feito para as cartas do KIKIU); UI é o jogo | Texto miúdo sempre em código, nunca em IA; contraste de raridade pelo mesmo sistema de borda; pixelização de ilustração grande exige decisão (pixel ou não) |
| **Tower defense** | Câmera superior, cenário, efeitos, pools | Torres e inimigos em poucas direções; muitas unidades simultâneas = **pool pelo pico**; leitura de alcance e rota é crítica | Muitos efeitos ao mesmo tempo estouram o orçamento e o teto de piscadas; trilha de inimigos precisa de contraste |
| **Puzzle** | Paleta, grade, UI, licença | Quase sem animação; peças como tile; feedback por efeito curto | Cor sozinha como informação exclui daltônicos (usar forma também); sem Blender na maioria dos casos |
| **3D low-poly com filtro pixel** | Paleta, contorno, normal, luz do Godot | Mundo vira 3D real e o pixel vem de **filtro de pós-processo** na tela, não de sprites; Blender assume o jogo todo, não só a conversão | Perde-se a grade "garantida pelo sprite"; texto e HUD precisam continuar em alta resolução por cima; contorno vira shader; desempenho no i5 é incógnita |

### 6.3 Perguntas para fazer antes de começar qualquer jogo novo [proposta]

1. Quantas direções o personagem precisa? (define se Blender compensa).
2. Qual a base de resolução e a escala inteira? (decidir antes de desenhar).
3. Quem é dono de cada uma das 6 camadas da seção 2?
4. O jogo tem câmera inclinada? Qual elevação? (pendente no KIKIU: 32° hoje, 45–50° na referência).
5. Qual o orçamento de quadros e de efeitos simultâneos para o PC mais fraco (i5-3470)?
6. Quais assets são de IA (referência ou final reduzido) e quem aprova?

---

## 7. Lições aprendidas (erro que virou regra)

| O que deu errado | Regra que nasceu |
|---|---|
| Escala fracionária do pixelfx borrava, pixels de tamanhos diferentes | Escala **inteira**; folha regerada na grade final com `gerar_folhas.py` (`-e70`, `-e80`, `-e45`, `-e55`, `-e75`) |
| Folha `burning` do pixelfx pintava o boneco inteiro | Chama própria por script (`preparar_status.py`); sempre `--no-actor`; olhar o PNG antes de usar |
| Folhas de clima gigantes (4800x4320) | Clima portado para código com quantidade fixa |
| Efeitos oscilando acima de 1,5 Hz (brasas, runas, anéis, chama da aura) | Todo liga-desliga passa por `v2/piscadas.gd` |
| Quadros repetidos ou só brilho mudava, entrega devolvida | Regra de ouro das animações; conferidor de folha planejado |
| Pico de nó no i5 no meio da partida | Pool pré-criado na montagem; pool de inimigo pelo pico (lição de 29/10) |
| Chão com perspectiva desenhada e grade | Piso na grade de 1 px (refeito em 03/11) |
| IA erra letra miúda | Texto de selos em código |
| IA nem sempre entrega transparência real | Fallback `#FF00FF` e script converte |
| IA gira estrela de 4 pontas 45° e alterna duas poses | Pegar o 1º quadro e girar no script |
| Animação da Nuvem de Esporos gerada por código lia como nuvem oca e o ícone parecia fogo (D05, `notas\plano_2026-11-01.md`) | Cartão parado ficou como modelo; só a arte foi trocada (loop do ChatGPT, entrada e saída derivadas por script) |
| Fonte medida em headless dá o dobro | Medir em janela de verdade (29/10) |
| Janela minimizada grava preto | Janela oculta ou headless (05/11) |
| Fila de Godot com semáforo perdia vaga | Mutex nomeado por vaga em `godot_fila.ps1` |
| Pixelify Sans: o 5 parecia S | Fonte removida (12/10) |
| Revisão visual deu 5,25/10: cenário bom, HUD/números/prompts de protótipo | Agregar números de dano, tirar XP de depuração, "PERFEITO!" pequeno |
| Ícones de carta dos heróis ainda sem arte própria | Gerados por imagegen e publicados (#275 / #278); só 3 armas usam imagem emprestada de outra (`docs/animacoes_armas_v2.md`) |
| Arte de terceiros não combina com 2.5D escuro | Regra de compatibilidade: se adaptar custa mais que fazer no Blender, não vale |
| Pacote grátis não chegou ao pago (Modern Interiors, LimeZu, US$ 1,50) | Grátis servem como base ou amostra; nenhum foi usado como visual |
| QA dentro de `projeto/` entra no export | JSON bruto, relatório e GIF de prova vão como artefato ou anexo |
| Worktree nova sem `.godot` dá erro falso | `godot --headless --import` primeiro |

Pendências abertas (não esconder do próximo jogo): resolução-base (640x360 vs 960x540), elevação da câmera (32° vs 45–50°), barra de vida em monstro comum, medição real no i5-3470, extensão do conferidor de folha, ligação de "Ultra" e FSR (FSR é aceitável pelo Alisson, mas **não está implementado** no repo), contraste do campo "ok visual" no PR.

---

## 8. Índice de fontes

**Docs do repo** (`C:\Dev\KIKIU\KIKIU-Survival`)
- `CLAUDE.md`, `AGENTS.md` (regras de processo, "Rumo à RC", divisão de trabalho)
- `docs/LICENCAS_ARTE.md`, `docs/LICENCAS_AUDIO.md`, `docs/assets_gratis.md`
- `docs/visual_2_5d/` (`README.md`, `mundo.md`, `PIPELINE_OBJETOS.md`, `lacunas.md`, `hud_menus.md`, `paleta.json`)
- `docs/PIXELFX.md`, `docs/animacoes_armas_v2.md`, `docs/combate_v2/SPEC_ARTE.md`
- `docs/armas_v2/_GUIA_ESQUEMATICA.md`, `docs/armas_v2/FUSOES_ARTE_ALISSON.md`
- `docs/ux_salao/ARTE_PARA_ALISSON.md`, `docs/ux_salao/REFERENCIAS.md`
- `docs/ULTRA_MAX_PC.md`, `docs/PERF_2026-10-*.md`
- `docs/imagens/referencia_2_5d.webp`

**Código e dados**
- `jogos/hordas/projeto/v2/`: `paleta.gd`, `DESIGN.md`, `piscadas.gd`, `fx_folha.gd`, `fx_status.gd`, `efeitos.gd`, `anim_golpes.gd`, `clima.gd`, `apresentacao.gd`, `estilo_premium.gd`, `qualidade_auto.gd`, `picos.gd`, shaders `salao_vivo`, `silhueta`, `titulo_fundo`, `titulo_logo`
- `jogos/hordas/projeto/dados/v2_pixelfx.json`, `v2_clima.json`
- `jogos/hordas/projeto/assets/v2/` (`pixelfx/`, `armas_anim/`, `efeitos/`, `armas/`), `assets/fonte/`
- `jogos/hordas/projeto/testes/` (`v2_pixel_*.gd`, `v2_fx_folha.gd`, `v2_piscadas.gd`, `fotos/*.gd`)

**Ferramentas**
- `jogos/hordas/fonte_arte/modelos3d/` (`pixel3d.py`, `mapas_v2.py`), `jogos/hordas/prototipos/cara_nova/` (`gerar_cara_nova.py`, `objetos/gerar_objetos.py`)
- `jogos/hordas/fonte_arte/pixelfx/gerar_folhas.py`, `pixelfx_status/preparar_status.py`
- `jogos/hordas/fonte_arte/blender_corte/` (incl. `girar_corte.py`), `blender_efeitos/`, `armas_anim/` (`gerar_*.py`, `PROMPTS.md`)
- `ferramentas/conferir_objeto.py`, `gifs_golpes.py`, `comparar_golpes.py`, `teste_golpes_isolados.ps1`, `playtest_v2.py`
- `jogos/hordas/projeto/v2/hud/` (`gerar_molduras.py`, `gerar_moldura_premium.py`), `jogos/hordas/fonte_arte/lightwolf_icones/` (`reduzir_icones.py`, `reduzir_cartas.py`), `.github/workflows/ci.yml`

**Notas fora do git** (`C:\Dev\KIKIU\notas`)
- `DIRECAO_DE_ARTE_GUIA.md`, `GUIA_ARTE_BLENDER_PIXEL.md` (guias parciais que alimentaram este)
- `godot_fila.ps1`, `artes_chatgpt\LEIA-ME.md`, `plano_2026-11-01.md`, `REVISAO_VISUAL_KIKIU.md`
- `pixelfx\` (clone externo, MIT)

**Limites deste guia.** Não foram abertos por inteiro `DESIGN_PERSONAGENS_E_DESCOBERTAS.md`, as imagens de referência, `docs/PIXELFX.md`, `gerar_folhas.py` nem `ferramentas/testes_ci.sh`. Os testes citados não foram rodados. Heróis, monstros e mapas usam Blender 4.5 (4.5.14 no registro de licenças); os efeitos próprios (`blender_corte`, `blender_efeitos`) citam Blender 5.2, e as folhas de `blender_efeitos` ainda não são usadas pelo jogo. A coluna "Gênero" da seção 6 é toda [proposta]. O sufixo real das folhas regeradas é `-eNN`.
