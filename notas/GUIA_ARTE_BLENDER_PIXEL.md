# Guia: pipeline 3D → pixel art do KIKIU (Blender) e onde ele para

Escrito em 2026-11-06 a partir das fontes do repo `C:\Dev\KIKIU\KIKIU-Survival` (worktrees `wt-*` e `qa*` ignoradas). Objetivo: permitir fazer **outros gêneros** (plataforma, puzzle, RPG, shooter) com a **mesma direção de arte**. Não edita nada do repo. Itens marcados **[inferência]** não estão escritos nas fontes.

Raiz das fontes: `C:\Dev\KIKIU\KIKIU-Survival` (abreviado aqui como `REPO`).

---

## 1. Resposta curta

Sim, Blender sozinho não serve. O Blender entra como **gerador de sprite a partir de modelo 3D** (forma, luz, rig, poses), e a arte final sai de um **pós-processo em Python/Pillow** (superamostragem, média BOX, paleta fixa, contorno de 1 px, normal map). Efeitos (golpes, chamas, explosões, status) não são Blender: vêm de **pixelfx** (MIT) ou de código. HUD e menus não são Blender. Retrato pintado em pixel é outra etapa.

Cadeia resumida:

```
modelo (script bpy) → rig com ossos → poses por animação (anim_*.py)
  → render Cycles/EEVEE em pixel nativo ou 4x → BOX → paleta fixa → contorno 1 px
  → normal map (mesmo silhueta da cor) → folha (grade linhas x colunas) + JSON
  → medir.py (nada toca a borda) → Godot lê a folha
```

---

## 2. Regras concretas (números)

| Regra | Valor | Fonte |
|---|---|---|
| Direção de arte geral | 2.5D top-down 3/4, pixel art dark fantasy, sem texto nem grade na arte | `REPO/docs/visual_2_5d/README.md` (regra 1 e 2); `REPO/AGENTS.md` linha 55 |
| Câmera Blender (herói) | Ortográfica, **45°** de elevação, **24,5 px por metro** | `REPO/jogos/hordas/fonte_arte/blender_herois/hazaki/gerar.py` (ELEV=45, PPU=24.5) |
| Câmera Blender (mundo/monstros, pipeline antigo) | **32°** de elevação (`pixel3d.camera`), `escala = max(W,H)/PPU` | `REPO/docs/visual_2_5d/mundo.md` seção "Por que o Blender e a câmera precisam mudar junto" |
| Elevação alvo (referência) | **45 a 50°** para chão e sprites juntos. Decisão ainda aberta no doc | `REPO/docs/visual_2_5d/mundo.md` seção "O que muda no gerador do Blender" |
| Quadro do herói | **32 x 44 px**, pé na linha **42** (linha 43 = contorno) | `hazaki/gerar.py` (W, H, PE_LINHA); `blender_herois/LEIA-ME.md` |
| Quadro do Nicão (anão) | 64 x 96 | `blender_herois/LEIA-ME.md` ("quadro 64x96") |
| Quadro do mecha LightWolf | 128 x 192, 38 colunas x 8 direções, `pe_y=120` | `blender_herois/lightwolf_mecha/LEIA-ME.md` |
| Escala de sprite no jogo | `ESCALA := 2.0` repetido em 4 scripts; arte desenhada 2x. Alvo: 1x (pixel = tamanho do herói) | `REPO/docs/visual_2_5d/lacunas.md` linha 25; `REPO/LOGBOOK.md` (Escala 1 nos inimigos novos) |
| Mapa: 1 m = 32 px (cenário/props) | 1 m = 32 px, câmera a 45° | `REPO/LOGBOOK.md` linha ~1283 (objetos da Cidade) |
| Ordem das 8 direções (linhas da folha) | `baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir` (ângulo em Z: 0, -90, 90, 180, -45, 45, -135, 135) | `hazaki/LEIA-ME.md`; `hazaki/gerar.py` (DIRECOES) |
| Paleta | Rampas fixas por material (aço, sangue, couro, ouro, musgo, osso; `hz_*` para o herói). Cor em **linear** no Blender | `REPO/docs/VISUAL_KIKIU.md` (pixel3d.py, armadilha 1); `REPO/docs/visual_2_5d/paleta.json` |
| Cores de luz do herói | Sombra fria azulada; lado iluminado quente; luz principal = tocha lateral esquerda; contraluz frio atrás/direita | `blender_herois/LEIA-ME.md` (estudo estilo) |
| Contorno | 1 px, na cor **escura da própria cor** (não preto puro); Hazaki usa casca invertida. Mecha: contorno externo de 1 px por quadro `(12,18,30,255)` | `hazaki/gerar.py` (CONTORNO = 0.062 m ≈ 1 px); `lightwolf_mecha/montar_folha.py` linha 24 |
| Superamostragem | 4x com antialias (EEVEE 8 amostras) → média BOX ponderada pelo alfa → alfa binário. Ou Cycles 1 amostra, filtro BOX mínimo, sem bloom | `blender_herois/LEIA-ME.md`; `hazaki/LEIA-ME.md` |
| Alfa | Binário (0 ou 255) | `hazaki/LEIA-ME.md` ("alfa binário") |
| Normal map | Mesma silhueta da cor; contorno vira normal reta (0.5, 0.5, 1) ou (128,128,255); bisel de borda; elevação desfeita | `hazaki/LEIA-ME.md`; `lightwolf_mecha/LEIA-ME.md` |
| Normal só para herói e elite | Não para toda a horda | `REPO/docs/visual_2_5d/mundo.md` item 7 |
| Quantização de efeito | 7 degraus de intensidade (alfa) e 4 de calor (RGB) | `REPO/jogos/hordas/fonte_arte/blender_corte/corte_hazaki.py` função `quantiza` (linhas 376 a 388) |
| Piso pré-renderizado | Cycles 4x, reduzido por média, paleta + pontilhado ordenado; pontilhado **zerado** nos pisos (decisão posterior) | `REPO/docs/VISUAL_KIKIU.md`; `REPO/LOGBOOK.md` linha ~1065 |
| Luz do cenário | `CanvasModulate` + halos ADD (no jogo), não Blender | `REPO/docs/VISUAL_KIKIU.md` (Cenários) |
| Desempenho | Perfil Baixo roda em i5-3470 com vídeo fraco; Médio e Alto levam luz com relevo | `REPO/docs/visual_2_5d/README.md` regra 3 |
| Legibilidade | Herói, objetivos e portal sempre se destacam; monstros com olhos vermelhos acesos | `REPO/docs/visual_2_5d/README.md` regra 4 |
| Licença de arte | Nada com direito autoral. Terceiro só com licença de uso comercial/modificação e registro em `docs/LICENCAS_ARTE.md`. Pack pago só com OK do dono do projeto | `REPO/docs/visual_2_5d/README.md` regra 2; `REPO/docs/LICENCAS_ARTE.md` |

---

## 3. Ferramentas e para que cada uma serve

| Ferramenta | Função | Onde |
|---|---|---|
| **Blender 4.5 LTS portátil** (zip, sem instalar) | Modelar por script (`bpy`), rig, render. Heróis e pipeline novo são 4.5; o corte de efeito foi feito em "5.2" segundo o LEIA-ME | `REPO/docs/VISUAL_KIKIU.md` linha 40; `REPO/jogos/hordas/fonte_arte/blender_corte/LEIA-ME.md`; `hazaki/LEIA-ME.md` (4.5.14) |
| **Python + bpy** | Todo o modelo é código, não arte à mão. Sem `.blend` como fonte de verdade (o `.blend` sai junto para inspeção) | 53 arquivos com `import bpy` em `REPO/jogos/hordas/fonte_arte/` (ex.: `blender_herois/hazaki/gerar.py`, `modelos3d/pixel3d.py`) |
| **NumPy** | Máscara de contorno, bisel e suavização da normal | `lightwolf_mecha/normais.py`; `hazaki/gerar.py` (importa numpy) |
| **Pillow (PIL)** | Redução BOX, paleta, NEAREST na prévia, contorno de 1 px por quadro, montagem da folha, GIF | `blender_herois/previa_gif.py`; `lightwolf_mecha/montar_folha.py` |
| **Cycles** | Render com luz e sombra reais (piso pré-renderizado, efeito de corte) | `cenarios.py`, `corte_hazaki.py` |
| **EEVEE** | Render rápido para o herói no fluxo com superamostragem | `blender_herois/gerar_heroi_andar.py` (cena.render.filter_size = 1.0) |
| **pixelfx** (MIT, `patch-gg/pixelfx`) | Efeitos em pixel art por código (explosões, coleta, status). Exporta PNG+JSON de folha | `REPO/docs/PIXELFX.md`; clone em `C:\Dev\KIKIU\notas\pixelfx` (ver PIXELFX.md) |
| **Node** (`tools/render.mjs` do pixelfx) | Gera a folha de um efeito | `REPO/docs/PIXELFX.md` seção "Regenerar uma folha" |
| **Godot 4.4.1 headless** | Import dos PNG, cenas de QA com janela oculta, prints | `REPO/docs/visual_2_5d/README.md`; `hazaki/LEIA-ME.md` (Salão) |
| **Pillow GIF** | Prévia 8 direções lado a lado e antes x depois | `hazaki/gifs.py`, `hazaki/previa.py`, `blender_herois/previa_gif.py` |
| **Codex / ChatGPT** | Referência visual (A15, estudo do Hazaki). Não é pipeline: a arte gerada por IA é só referência de visual (a folha de IA tinha 4 direções iguais) | `REPO/LOGBOOK.md` linha 213; `REPO/docs/LICENCAS_ARTE.md` |
| **Medidor próprio** `medir.py` | Mede largura, altura e se algo toca a borda do quadro, por direção | `hazaki/medir.py`; `lightwolf_mecha/medir.py` |

---

## 4. Fluxo passo a passo (receita para um personagem novo)

Base de referência: `blender_herois/hazaki/` (framework) e `blender_herois/lightwolf_mecha/` (mesma estrutura).

1. **Modelo** por script: copie `hazaki/gerar.py` com um perfil (`perfil.py` define NOME, PALETA, BRILHANTES). Ver `blender_herois/lukako/LEIA-ME.md` (mesmo rig, só muda perfil e arma).
2. **Rig**: `ossos.py` com `OSSOS` = `raiz, quadril, torso, cabeca, braco_e/d, antebraco_e/d, perna_e/d, canela_e/d, pe_e/d`. Hierarquia: raiz > quadril > {torso > {cabeca, braco > antebraco}, perna > canela > pe}. `_e` = esquerda da tela, `_d` = direita da tela. Joelho e cotovelo são ossos (não empties) desde o framework do Hazaki.
3. **Câmera e luz**: 45°, ortográfica, 24,5 px/m, pé na linha 42. Luz: tocha lateral + contraluz frio.
4. **Poses**: um arquivo `anim_<nome>.py` por animação, com `N_QUADROS` e `posar(arm, quadro, n_quadros[, ang])`. `gerar.py` descobre pelo nome. Opcionais: `efeito(...)` (pinta polígonos depois do render), `ossos.ancorar`, `ossos.encaixar_x`, `ossos.guarda_ponta`, `ossos.pisar`.
5. **Render**: `blender -b -t 6 -P gerar.py` (todas) ou `-- --anim=andar`. Saída `quadros/<anim>/<dir>_<i>_{cor,normal}.png`.
6. **Previa**: `python previa.py andar` (GIF das 8 direções + folha de contato).
7. **Medir**: `python medir.py andar` ou `--todos`. Falha se algum quadro estiver vazio ou tocar a borda. **Regra:** rodar depois de cada render completo.
8. **Montar folha**: `python montar_folha.py` → `<personagem>_final_albedo.png`, `_normal.png`, `.json` (com `linhas`, `colunas`, `animacoes` com `s_quadros`). Grade: linhas = 8 direções, colunas = quadros de todas as animações (50 no Hazaki).
9. **Registrar no jogo**: copiar para `projeto/prototipos/.../sprites/` (ou `assets/v2/`) e abrir o Godot uma vez para gerar `.import`.
10. **Ler em jogo**: `heroi.gd` lê `animacoes` do JSON. Colunas de ação (combo, rolamento, escudo, dano, morte) ficam fora de `colunas` de propósito, senão o passo de andar roda o combo (LOGBOOK 2026-10-15, #277).
11. **Prévia e QA**: print com janela oculta, 4x, em cena de QA (`qa/qa_*.gd`). Registro no PR.

Para **efeito** (golpe de katana, corte): `blender_corte/corte_hazaki.py` gera 16 quadros 128x128, quantiza (7 alfa, 4 calor), grava RGB = calor e A = intensidade. O jogo tinge com a cor do golpe (`dados/v2_combate.json`, `passos[].cor`) e espelha para `lado = -1`. Refazer: `blender -b -P corte_hazaki.py` e `blender -b -P previa.py -- ...` (ver `blender_corte/LEIA-ME.md`).

Para **monstro/cenário** (pipeline antigo, `modelos3d/`): `blender -b -P <script>.py [-- nome]`, saída em `assets/`. Ex.: `cenarios.py` (~2 min os três), `horror.py`, `dragao.py`, `loja.py`, `mapas_v2/def_cidade.py`.

---

## 5. O que deu errado e virou regra

Fonte principal: `REPO/docs/VISUAL_KIKIU.md` (armadilhas) e `REPO/LOGBOOK.md`.

| Problema | Regra que ficou |
|---|---|
| Cor lavada (vermelho virava marrom) | Cor em **linear** no Blender: usar `px3.cor("hexa")`, não o hexa direto |
| Peça flutuando | Pendurar com `pendurar()` mantendo o lugar; posição somada duas vezes |
| Chiado em 44 px | Sombra própria desligada nas luzes |
| Sinal de `shift_y` | Linha de imagem cresce para baixo; `shift_y` cresce para cima |
| Folha de IA com 4 direções iguais | IA só serve de referência; a folha vem do Blender (ex.: bichos olhando para o mesmo lado: `horror.py` passou a espelhar cada quadro) |
| Pontilhado nos pisos atrapalhava | `pixelar(pontilhado=...)` zerado nos pisos e paredes da loja |
| Sprite grande demais/borrado após trocar escala | Escala só muda com a arte refeita (`lacunas.md`) |
| Lâmina/lenço estouram 32 px nas diagonais | Katana menor e apontada para baixo; `LARGURA` em `gerar.py` ajusta; `medir.py` barra borda |
| Rolamento e morte: corpo cai para fora do quadro | `ossos.ancorar` põe o corpo inteiro no chão; morte termina de lado, nunca de cabeça para baixo |
| Combo com rastro cortado pela célula | Medido e aceito: rastro cortado no quadro. `medir.py` mostra |
| Passo de andar rodando o combo | Colunas de ação em `animacoes` do JSON, não em `colunas` |
| Dois `gerar.py` com números diferentes (32 px e 128 px) | Cada personagem tem seu quadro. Padronizar antes de um jogo novo |
| Efeito parecia magia (corte "simples") | Variante guardada, não usada; corte com katana + linha de anime |
| Estouro de tempo no Blender | `-t 6` (threads); sem paralelo de várias instâncias quando a máquina está carregada (LOGBOOK, PERF 2026-10-10) |
| Blender 4.5 vs 5.2 nos docs | **[inferência]** os LEIA-ME citam versões diferentes; conferir antes de reproduzir |

---

## 6. Onde o Blender NÃO basta

| Necessidade | Quem resolve | Fonte |
|---|---|---|
| Efeitos (explosão, coleta, faísca, rastro) | **pixelfx** (folhas PNG+JSON, MIT, registro em `dados/v2_pixelfx.json`) ou código (`fx_folha.gd`) | `REPO/docs/PIXELFX.md` |
| Status visuais (chama, relógio, estrelas) | Folha pixelfx recortada e reduzida por `preparar_status.py` (média BOX, metade) | `REPO/jogos/hordas/fonte_arte/pixelfx_status/preparar_status.py`; `REPO/docs/PIXELFX.md` |
| Clima (chuva, neve, glitch) | Código no jogo (`v2/clima.gd`, quantidade fixa, espaço de tela) | `REPO/docs/PIXELFX.md` |
| Rastro de katana | Blender (efeito emissivo, quantizado) | `blender_corte/` |
| HUD e menus (alta resolução, texto nítido) | Não é pixel do Blender: layout medido na referência | `REPO/docs/visual_2_5d/hud_menus.md` |
| Retratos | Pintados em pixel (V4) | `REPO/docs/visual_2_5d/README.md` fase V4 |
| Fundo, moldura de árvores, ruínas, rio | Cenário com profundidade (V3), fase em aberto | `REPO/docs/visual_2_5d/mundo.md` seção 5 |
| Pixel por pixel (ajuste à mão) | Permitido a arte livre, mas a regra é o pipeline. Passe de pixel: `REPO/docs/visual_2_5d/passe_pixel/` | `REPO/docs/visual_2_5d/README.md` regra 2 |
| Ícones (cartas) | Outro PR, Codex/ChatGPT como referência | `REPO/LOGBOOK.md` linha ~1850 |
| Chefes e elites | Normal map e barra de vida (Marco 1) | `REPO/docs/visual_2_5d/README.md` regra 4 |

---

## 7. Animação de personagens: estado atual

- **Hazaki (herói padrão):** 7 animações, 50 colunas, 8 direções, cor e normal. Ligado no jogo (`heroi.gd`, #277). Ver `blender_herois/hazaki/LEIA-ME.md`.
- **LightWolf mecha:** parado, andar, combo de 2 tiros (clarão no quadro de disparo), escudo, dano, rolamento, morte. Folha 128x192. Ver `blender_herois/lightwolf_mecha/LEIA-ME.md`.
- **LightWolf lobo:** mesmo rig e animações do Lucas, só modelo e paleta. Ver `blender_herois/lightwolf_lobo/LEIA-ME.md`.
- **Nicão:** anão de marreta, quadro 64x96, IK nas duas mãos, parado, andar, rolamento, combo, defesa, dano, morte. Ver `blender_herois/nicao/LEIA-ME.md`.
- **Monstros (lobo, raposa, serpente, urso, esqueleto, fantasma, golem, guardião, dragão):** `blender_<nome>/gerar_<nome>.py`. Cada um com seu gerador.

**Strafe:** o termo "strafe" / colunas `strafe` e `strafe_tiro` **não aparece** em nenhum arquivo do repo principal (busca em `.md`, `.py`, `.json`, `.gd` fora das worktrees). **[inferência]** o conceito existe só em worktree de outra branch (`wt-strafe`), ou em outro nome. Não há coluna de strafe documentada na direção de arte atual.

**Direções:** 8 (Hazaki, mecha, lobo, Nicão). Não há 4 direções no pipeline novo. O pipeline antigo (`cavaleiro.py`) usa 4 linhas (baixo, esquerda, direita, cima).

**Recorte e montagem:** folha = grade. Não há recorte por imagem de IA. Cada quadro é renderizado já no tamanho final.

**Pós-processo:** redução BOX de 4x para 1x, paleta fixa, contorno 1 px por quadro (Pillow), normal map (NumPy), sem NEAREST no render final (NEAREST só nas prévias: `previa_gif.py`, `previa.py`). Redução de cor: paleta de rampas fixas (`pixel3d.py`), não quantização automática.

**Ponto de atenção:** `C:\Dev\KIKIU\montar_folha.py` (pasta-mãe, fora do repo) está **vazio** (0 linhas). **[inferência]** resto de tentativa; não usar.

---

## 8. Mapa de fontes (caminhos)

| O que | Caminho |
|---|---|
| Direção de arte (fonte de verdade) | `REPO/docs/visual_2_5d/README.md`, `mundo.md`, `lacunas.md`, `hud_menus.md`, `paleta.json` |
| Guia geral de visual e armadilhas Blender | `REPO/docs/VISUAL_KIKIU.md` |
| Pixelfx | `REPO/docs/PIXELFX.md`; `REPO/docs/LICENCAS_ARTE.md` (linhas 162 a 168) |
| Licenças de arte | `REPO/docs/LICENCAS_ARTE.md` |
| Framework do herói | `REPO/jogos/hordas/fonte_arte/blender_herois/hazaki/` (gerar.py, ossos.py, normais.py, medir.py, montar_folha.py, previa.py, gifs.py, ik_katana.py, anim_*.py) |
| Mecha LightWolf | `REPO/jogos/hordas/fonte_arte/blender_herois/lightwolf_mecha/` |
| Lobo LightWolf | `REPO/jogos/hordas/fonte_arte/blender_herois/lightwolf_lobo/` |
| Nicão | `REPO/jogos/hordas/fonte_arte/blender_herois/nicao/` |
| Estudo de estilo do Hazaki | `REPO/jogos/hordas/fonte_arte/blender_herois/gerar_heroi_estilo.py`, `estudo_estilo/` |
| Codex (estudo de modelo) | `REPO/jogos/hordas/fonte_arte/blender_herois/codex_estudo/` |
| Corte de efeito | `REPO/jogos/hordas/fonte_arte/blender_corte/` (`corte_hazaki.py`, `previa.py`, `gif_jogo.py`, LEIA-ME) |
| Modelos antigos (monstros, cenários, props) | `REPO/jogos/hordas/fonte_arte/modelos3d/` (`pixel3d.py`, `monstros.py`, `cenarios.py`, `horror.py`, `dragao.py`, `loja.py`, `mapas_v2/`) |
| Pixelfx status | `REPO/jogos/hordas/fonte_arte/pixelfx_status/preparar_status.py` |
| Cenário de referência (mecha) | `notas/artes_chatgpt/A15_lightwolf_mecha_ref.png` (fora do git) |
| Histórico de decisões | `REPO/LOGBOOK.md` (buscar "Blender", "pipeline", "armadilha") |

---

## 9. Checklist para um jogo de outro gênero

1. Escolher o quadro (px por personagem) e a escala de jogo (1x, sem `ESCALA := 2.0`). Decidir 4 ou 8 direções.
2. Escolher elevação de câmera (45° é o valor testado) e manter a mesma para chão e sprites.
3. Montar a paleta por rampas (3 a 4 faixas por material) e as cores de luz (fria na sombra, quente na tocha).
4. Modelar por script (`bpy`), cor em linear, sombra própria desligada nas luzes pequenas.
5. Rig com joelho e cotovelo; uma animação por arquivo `anim_*.py`.
6. Render 4x → BOX → alfa binário → paleta → contorno 1 px na cor escura da própria cor.
7. Normal map só para herói e elite.
8. Medir (nada toca a borda) e prévia (GIF 8 direções + folha de contato).
9. Efeitos por pixelfx (MIT, registrar em `LICENCAS_ARTE.md`) ou código; nada de arte de terceiro sem licença.
10. HUD e menus em alta resolução, fora do Blender.
11. Registrar no LOGBOOK o que mudou e o que ficou pendente.
