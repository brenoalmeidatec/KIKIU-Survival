# Vornak 3D na Godot 4.4.1 (protótipo)

O Vornak deixa de ser folha de sprites pré-renderizada e passa a ser um modelo 3D animado em tempo real, com câmera isométrica e aparência de pixel art. Fica tudo em `v3/godot`, fora da v2.

## Arquivos

| O quê | Onde |
|---|---|
| Modelo + 13 animações | `v3/godot/assets/3d/vornak.glb` |
| Texturas de detalhe (512 px, nearest) | `v3/godot/assets/3d/texturas/` (madeira, musgo, cipo, energia, olho, dente) |
| Curva de energia por clipe | `v3/godot/assets/3d/vornak_energia.json` |
| Sons sintetizados | `v3/godot/assets/audio/vornak/*.wav` (7 arquivos) |
| Cena | `v3/godot/cena_3d/vornak_3d.tscn` |
| Visual (animação por estado, materiais, sons por quadro) | `cena_3d/vornak_3d.gd` |
| Combate (máquina de estados, áreas, indicadores, balanço) | `cena_3d/vornak_combate.gd` |
| Herói de teste (cápsula) | `cena_3d/heroi_teste.gd` |
| Câmera, grade de texels, HUD, modos de demonstração | `cena_3d/vornak_3d_cena.gd` |
| Shaders | `cena_3d/toon_vornak.gdshader`, `cena_3d/contorno.gdshader`, `cena_3d/chao_ladrilho.gdshader` |
| Teste headless | `v3/godot/testes/vornak_3d_teste.gd` |
| Scripts geradores | `docs/v3/chefes/gerar_texturas_vornak.py`, `docs/v3/chefes/sintetizar_sons_vornak.py` |
| GIFs gravados | `docs/v3/chefes/gifs/vornak_3d_andar_4x.gif`, `vornak_3d_attack01_4x.gif`, `vornak_3d_fase_4x.gif` |
| Comparação com a folha | `docs/v3/chefes/vornak_3d_vs_folha.png` |
| Antes e depois em 1x (320x180 contra 640x360) | `docs/v3/chefes/vornak_3d_antes_depois_1x.png` |

Origem no Blender (fora do repositório): `D:/dev/kikiu_chefes_tmp/vornak_3d.blend` (sem UV de detalhe), `D:/dev/kikiu_chefes_tmp/v3fim/vornak_3d_uv.blend` (com a UV por projeção de cubo, de onde saiu o glb atual), scripts `v3fim/uv_cubo.py` e `v3fim/exportar_glb_uv.py`. O glb anterior ficou em `v3fim/vornak_antes.glb`.

## Como abrir a cena

    godot --path v3/godot --resolution 1280x720 res://cena_3d/vornak_3d.tscn

Teclas: WASD ou setas andam, espaço bate, Tab troca a câmera (retrato do chefe / arena inteira), R reinicia.

Na primeira vez numa máquina nova, importe antes: `godot --headless --path v3/godot --import`.

## Como rodar o teste

    godot --headless --fixed-fps 60 --path v3/godot -s res://testes/vornak_3d_teste.gd

Imprime `vornak_3d falhas=0` (53 conferências). Confere: o glb e as 13 animações; os 7 sons carregam (22050 Hz) e cada um é disparado (contador); andar -> aviso -> impacto, raízes tiram 30 uma vez; o golpe no chão toca no impacto; tempos de aviso e recuperação dos 4 ataques da folha (erro de até 1/60 s) com o quadro de impacto do clipe no fim do aviso; resolução interna 640x360 e texel = size/360; câmera e modelo presos à grade de texels durante 2 s andando; suavização da câmera (63% do salto em 0,15 s); luta simulada com o herói parado apanhando e batendo, que precisa durar 60 a 90 s (imprime a duração, o vencedor e o dano por ataque); fase 2, rugido do Grito, morte sem área ligada.

## Gravar os GIFs

    Godot_v4.4.1-stable_win64.exe --path v3/godot --write-movie <pasta>/q.png --fixed-fps 12 --resolution 1280x720 res://cena_3d/vornak_3d.tscn -- --demo=andar

Modos: `andar`, `ataque` (Attack_01 com o indicador), `fase` (transição de fase até o fim do Grito, 5,6 s), `foto` (parado, de frente), `calibrar` (sem chão, para medir). Os outros fecham sozinhos em 4 s. `-- --medir` imprime o FPS médio ao fechar. `D:/dev/kikiu_chefes_tmp/v3fim/pos_gravacao.py` monta os GIFs (12 fps, a janela 1280x720 inteira), o print ao lado da folha, o antes/depois em 1x e as medições abaixo.

## Modelo e animações

- As peças viraram uma malha só, `Vornak_Corpo`, com modificador Armature apontando para `Vornak_Rig` (ver a rodada anterior). O glb tem 1 skin (59 juntas), 1 malha, 12 materiais, 0 câmeras, 0 luzes e as 13 animações: Idle, Walk, Run, Attack_01, Attack_02, Attack_03, Attack_04_Segunda_Forma, Hit, Stagger, Ability, Phase_Transition, Death, Grito. Idle, Walk e Run tocam em loop.
- **UV nova (19/10):** a malha antiga não tinha UV na maior parte (madeira, casca, rosto, boca, dentes e marca com UV zerada). Gerei UV por projeção de cubo na pose de descanso, na escala do mundo (1 unidade de UV = 7 m; com a escala 1,4 da madeira e do musgo, 1 texel da textura fica perto de 1 pixel da tela). A UV vai junto com a pele, então a textura não escorrega na animação. Só a UV mudou; ossos, pesos e animações são os mesmos. Limite: costura onde a face troca de eixo (a casca muda de direção numa linha).

## Câmera e resolução interna

- `SubViewportContainer` com `stretch = true`, `stretch_shrink = 2` e filtro NEAREST; a `SubViewport` desenha em **640x360** numa janela 1280x720 e é ampliada 2x por nearest (escala inteira, sem borrão). `handle_input_locally = false`. 960x540 não foi usado: em 1280x720 seria uma ampliação de 1,33x, que não é inteira e deixa pixels de largura desigual.
- `Camera3D` ortográfica, rotação isométrica (-35,264° em X, 45° em Y), seguindo o chefe. Modo retrato: `size = 5.0`; modo arena (Tab, e no GIF do ataque): `size = 9.0`.
- **Suavização:** a câmera vai até o alvo com `lerp` de fator `1 - e^(-dt/0,15)` (constante de tempo de 0,15 s). Medido no teste: 63% de um salto de 1 m em 0,15 s.
- **Grade de texels:** na Godot, `Camera3D.size` ortográfica é a altura visível inteira (não a metade), então o texel é `size / 360` (0,0139 m no retrato; equivale à fórmula `2*meia_altura/altura`). A posição da câmera é arredondada para múltiplos do texel no plano da câmera (eixos direita e cima; a profundidade não muda a imagem na ortográfica). O modelo do chefe (`Vornak/Modelo`) e o corpo do herói também são presos à mesma grade, só no desenho; a lógica e as áreas de dano seguem livres.
- **Medido (andar, 12 fps):** entre quadros seguidos, o chão é um deslocamento inteiro exato: 0,04% dos pixels do chão mudam além do deslocamento (máximo 0,27%), contra 5,8% no GIF de andar anterior (320x180, sem grade). O teste confere erro de grade de no máximo 0,0002 texel na câmera e 0 no modelo durante 2 s andando.

## Shader e paleta

- **Toon de 5 tons** (`toon_vornak.gdshader`): cada pixel cai num dos 5 tons da rampa do material (sombra funda, sombra, meio, luz, brilho). O tom vem de 5 faixas de N·L, da sombra projetada (no máximo o 2º tom), da textura de detalhe e da luz de borda. Sem especular, sem PBR, sem luz ambiente e **sem emissão contínua**: nas partes de energia (fendas, olhos, boca, marca) a curva `intensidade` de cada clipe escolhe o tom (fase 2: 60% mais forte). O glow do ambiente foi desligado, porque borrava a energia.
- **Texturas de detalhe** (`gerar_texturas_vornak.py`, 512x512, cinza em 5 níveis, `filter_nearest_mipmap`): cada nível desloca o tom em -2, -1, 0, +1 ou +2. Madeira: placas de casca com fissuras onduladas, veios, rachas e nós com anel; musgo: tufos em blocos com topo claro e base escura; cipó e rosto: fibras torcidas; energia: veios brilhantes com halo; olho: brilho radial em degraus; dente: listras com ponta clara.
- **Luz de borda:** onde a superfície fica de lado para a câmera (1 - N·V > 0,62) e não está de costas para a luz, o tom sobe 1. Destaca a silhueta sem sair da paleta.
- **Contorno de 1 px na resolução interna** (`contorno.gdshader`, casco invertido, `next_pass` de cada material, #1a1410): a largura é em pixels da `SubViewport` (`2 / VIEWPORT_SIZE`), então continua 1 px interno em 640x360 (2 px na tela). Só silhueta e bordas de peças sobrepostas.
- **Paleta** (folha conceitual + tons de transição; sombras puxando para o frio, luzes para o quente):

| Material | Tons (sombra funda -> brilho) |
|---|---|
| Madeira (casca, tronco, galhos) | #24191a #3f2c1c #5c3f28 #7a5534 #9c7650 |
| Musgo (musgo, folhas) | #1f3320 #34541f #4f7a2a #6f9a3c #9cc25a |
| Cipó e rosto | #1a2a1f #2b4420 #3f6128 #577f33 #6f9a3c |
| Dentes | #3f2c1c #6e5641 #8b6b4e #b39a7a #d8c9a8 |
| Energia (fendas, boca, marca) | #4f7a2a #8fd13a #b8ff4a #dcff8a #f4ffd8 |
| Olhos | #2e3d10 #7aa82a #b8ff4a #e8ff9c #ffffff |

São 26 tons diferentes no total + o contorno.

## Antes e depois (19/10)

| Medida | Antes | Depois |
|---|---|---|
| Resolução interna | 320x180 (ampliada 4x) | 640x360 (ampliada 2x) |
| Altura do Vornak (pose de frente, `--demo=calibrar`) | 136 px internos (544 na tela) | 274 px internos (548 na tela) |
| Cores no Vornak nessa pose (contadas no quadro, sem o chão) | 36 (2 tons por material + mistura do glow e da emissão) | 24 (rampa de 5 tons, sem glow) |
| Rampa | 2 tons | 5 tons + textura + luz de borda |
| FPS na janela 1280x720, sem vsync (`--demo=andar --medir`, 2 rodadas) | 2256 e 2295 | 2762 e 2752 |
| Tempo do `--write-movie` da foto (49 quadros, inclui gravar PNG) | 2,45 s | 2,54 s |
| Pixels do chão que tremem ao andar | 5,8% | 0,04% |

O FPS subiu em vez de cair porque o glow (várias passadas de desfoque) saiu; a resolução 4x maior e as texturas não pesaram nesta máquina. FPS no headless não serve (o renderizador é falso), por isso a medida é na janela. Não foi medido em máquina fraca.

## Combate (protótipo)

- Estados: andar, aviso, impacto, recupera, stagger, transicao, morto e vitoria (herói caiu). Aviso e recuperação com os tempos da folha, clipe reescalado para o impacto cair no fim do aviso (detalhes e o que foi cortado em `VORNAK_COMBATE.md`).
- Áreas de dano (`Area3D`, ligadas só no impacto): raízes = círculo de 3 m; golpe = setor de 90° com alcance 2,2 m; absorção = 4 pontos (cura o chefe se acertar, teto de 180 na luta); fase 2: raízes longas (círculo de 3,6 m) e tempestade (4 pontos em volta do herói).
- Indicadores no chão: `MeshInstance3D` pequenos (círculo com 2 anéis, setor, 4 pontos) que pulsam e só aparecem no aviso.
- Fase 2 abaixo de 40%: Phase_Transition seguido do Grito, sem levar dano; depois recargas 15% menores (nunca abaixo de 2,5 s) e os ataques da fase 2 têm preferência.
- **Balanço (PROVISÓRIO até a v3 ter herói próprio)**, tudo no bloco do topo de `vornak_combate.gd`: vida 1400; dano raízes 30, golpe 20, absorção 0, raízes longas 35, tempestade 25; velocidade 1,5 (correr 1,8) e herói 1,5; recargas de 2,5 a 4 s; herói de teste com 900 de vida e golpe de 10 a cada 0,5 s. Luta parada medida: 76,5 s. Tabela e motivo em `VORNAK_COMBATE.md`.
- Áudio: 7 sons sintetizados, tocados por quadro do clipe (ver `vornak_sons.md`).

## O que ainda não está pronto

- Ligação com a v2, com o herói de verdade e com a arena.
- Balanço só com o herói de teste parado; sem medição com jogador de verdade. Stagger não acontece com o golpe atual do herói.
- Attack_01: 1,97 s do fim do clipe (recolher das raízes) é cortado para a recuperação caber em 0,6 s; Attack_02 e Attack_03 tocam mais lentos no aviso. O certo é refazer esses clipes no Blender.
- Janela de interrupção da absorção (0,6 s) não existe ainda.
- Sons: só os 7 sintetizados; faltam respiração, rangidos, folhas e o acerto no herói. Não houve audição no teste (headless sem áudio); os disparos foram contados.
- UV por projeção de cubo tem costura onde a face troca de eixo; uma UV feita à mão daria a casca contínua.
- Partículas de energia do Blender (`VN_Energia.*`) e a luz verde do peito ficaram de fora do glb.
- Contorno só externo; sem linhas internas.
- Herói é uma cápsula sem animação; o golpe dele é por distância (2 m), não por área.
- O ataque da folha "Absorção" puxa energia de árvores da arena; aqui são 4 pontos fixos em volta do chefe.
- Não testado em máquina fraca nem no celular.
