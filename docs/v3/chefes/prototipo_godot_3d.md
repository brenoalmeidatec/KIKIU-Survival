# Vornak 3D na Godot 4.4.1 (protótipo)

O Vornak deixa de ser folha de sprites pré-renderizada e passa a ser um modelo 3D animado em tempo real, com câmera isométrica e aparência de pixel art. Fica tudo em `v3/godot`, fora da v2.

## Arquivos

| O quê | Onde |
|---|---|
| Modelo + 13 animações | `v3/godot/assets/3d/vornak.glb` |
| Curva de energia por clipe | `v3/godot/assets/3d/vornak_energia.json` |
| Cena | `v3/godot/cena_3d/vornak_3d.tscn` |
| Visual (animação por estado, materiais) | `cena_3d/vornak_3d.gd` |
| Combate (máquina de estados, áreas, indicadores) | `cena_3d/vornak_combate.gd` |
| Herói de teste (cápsula) | `cena_3d/heroi_teste.gd` |
| Câmera, HUD, modos de demonstração | `cena_3d/vornak_3d_cena.gd` |
| Shaders | `cena_3d/toon_vornak.gdshader`, `cena_3d/contorno.gdshader`, `cena_3d/chao_ladrilho.gdshader` |
| Teste headless | `v3/godot/testes/vornak_3d_teste.gd` |
| GIFs gravados | `docs/v3/chefes/gifs/vornak_3d_andar_4x.gif`, `vornak_3d_attack01_4x.gif`, `vornak_3d_fase_4x.gif` |
| Comparação com a folha | `docs/v3/chefes/vornak_3d_vs_folha.png` |

Origem no Blender (fora do repositório): `D:/dev/kikiu_chefes_tmp/vornak_3d.blend` (resultado), `vornak_antes_3d.blend` (cópia de antes), scripts `vornak_3d_skin.py` e `exportar_vornak_glb_3d.py`.

## Como abrir a cena

    godot --path v3/godot --resolution 1280x720 res://cena_3d/vornak_3d.tscn

Teclas: WASD ou setas andam, espaço bate, Tab troca a câmera (retrato do chefe / arena inteira), R reinicia.

Na primeira vez numa máquina nova, importe antes: `godot --headless --path v3/godot --import`.

## Como rodar o teste

    godot --headless --fixed-fps 60 --path v3/godot -s res://testes/vornak_3d_teste.gd

Imprime `vornak_3d falhas=0`. Confere: o glb carrega, o AnimationPlayer tem as 13 animações, o estado vai de andar para aviso e para impacto em 3 s, a vida do herói cai 20 no impacto (uma vez), a vida do chefe cai no golpe do herói, abaixo de 40% entra na transição e depois na fase 2, e a morte para o combate (nenhuma área ligada, nenhum estado novo).

## Gravar os GIFs

    Godot_v4.4.1-stable_win64.exe --path v3/godot --write-movie <pasta>/q.png --fixed-fps 24 --resolution 1280x720 res://cena_3d/vornak_3d.tscn -- --demo=andar

Modos: `andar`, `ataque` (Attack_01 com o indicador), `fase` (transição de fase), `foto` (parado, de frente). Cada um fecha sozinho em 4 s. `D:/dev/kikiu_chefes_tmp/gif_3d.py` monta os GIFs a 12 fps.

## Modelo e animações

- As peças (tronco, peito, braços, mãos, pernas, cabeça, galhada, cipós, espinhos, folhas, raízes, musgo, dentes, rosto, fendas) viraram uma malha só, `Vornak_Corpo`, com modificador Armature apontando para `Vornak_Rig`. As peças que antes estavam presas a um osso ficaram com peso 1 nesse osso (o mais próximo, sem mudar o movimento). O tronco tem peso suave entre quadril e peito, então o peito agora dobra junto com os braços. Folhas, espinhos, marca no chão e o tremor da galhada (que tinham animação de objeto) ganharam ossos `fx_*`, com o movimento assado quadro a quadro em cada clipe.
- Conferência: comparando as peças antigas com a malha deformada nos quadros idle 1, attack_01 16 e walk 7, o maior desvio ficou no tronco (0,34 no attack_01, de propósito, pela dobra no peito); fora o tronco, o maior foi a galhada (0,04 no attack_01). Nada solto nas renderizações de conferência.
- O glb tem 1 skin (59 juntas), 1 malha, 12 materiais, 0 câmeras, 0 luzes e somente as 13 animações: Idle, Walk, Run, Attack_01, Attack_02, Attack_03, Attack_04_Segunda_Forma, Hit, Stagger, Ability, Phase_Transition, Death, Grito. Idle, Walk e Run tocam em loop.

## Câmera e resolução interna

- `SubViewportContainer` com `stretch = true`, `stretch_shrink = 4` e filtro NEAREST; a `SubViewport` desenha em **320x180** numa janela 1280x720 e é ampliada 4x por nearest. É isso que dá o pixel. `handle_input_locally = false`.
- `Camera3D` ortográfica, rotação isométrica (-35,264° em X, 45° em Y), seguindo o chefe. Modo retrato: `size = 5.0`, medido para o chefe ocupar 75% da altura (540 de 720 px). Modo arena (Tab, e no GIF do ataque): `size = 9.0`, para o círculo de 3 m caber inteiro.
- Uma `DirectionalLight3D` (luz e sombra, sem luz de preenchimento) e `WorldEnvironment` com ambiente cinza-esverdeado (só age nas coisas que não usam o toon), tonemap linear e glow leve para a energia.

## Shader

- **Toon de 2 tons** (`toon_vornak.gdshader`): a função `light()` corta seco entre `cor_sombra` e `cor_luz` (paleta da folha: madeira #6b4a2e / #3f2c1c, musgo #6f9a3c / #4f7a2a, energia e olhos #b8ff4a). Sem especular, sem PBR e sem luz ambiente, então a cor na tela é a da paleta. A emissão das fendas, olhos, boca e marca usa o uniform `intensidade` (0 a 4), que o `vornak_3d.gd` lê a cada quadro da curva de cada clipe (a mesma que acendia a energia no Blender); na fase 2 ela sobe 60%.
- **Contorno de 1 px por casco invertido** (`contorno.gdshader`, `next_pass` de cada material): a malha é empurrada para fora ao longo da normal em pixels de tela e só as faces de trás são desenhadas na cor #1a1410. Escolhi esse e não o pós-processo porque é leve (uma passada a mais na malha de 45 mil vértices), funciona com a malha skinada (na Godot 4 o skinning já foi aplicado quando o `vertex()` roda), dá 1 px fixo em qualquer zoom e não precisa de passada de profundidade/normal na SubViewport. Limite: não desenha linhas internas (só silhueta e bordas de peças sobrepostas).

## Combate (protótipo)

- Estados: andar, aviso, impacto, recupera, stagger, transicao, morto. O aviso dura até o quadro de impacto do clipe (os tempos da rodada anterior não mudaram): Attack_01 quadro 22, Attack_02 quadro 8, Attack_03 quadro 9, Attack_04 quadro 14. O impacto segura 2 quadros; a recuperação vai até o fim do clipe.
- Áreas de dano (`Area3D`, ligadas só no impacto): raízes = círculo de 3 m; golpe = setor de 90° com alcance 2,2 m; absorção = 4 pontos (cura o chefe se acertar, teto de 180 na luta); fase 2: raízes longas (círculo de 3,6 m) e tempestade (4 pontos em volta do herói).
- Indicadores no chão: `MeshInstance3D` pequenos (círculo com 2 anéis, setor, 4 pontos) que pulsam e só aparecem no aviso.
- Fase 2 abaixo de 40%: Phase_Transition seguido do Grito, sem levar dano; depois recargas 30% menores.
- Balanço, tudo no bloco do topo de `vornak_combate.gd`: vida 1200 (folha), **dano por golpe do chefe 20 (PROVISÓRIO; a folha sugere 20 a 40; a vida de 100 do herói ainda não foi decidida)**, golpe do herói 30 (provisório), stagger com 150 de dano em 3 s, velocidade 1,4 m/s andando (folha: 1,2 a 1,8).

## O que ainda não está pronto

- Áudio: só a lista de ganchos em `vornak_sons.md`.
- Ligação com a v2, com o herói de verdade e com a arena.
- Balanço (dano 20 provisório, golpe do herói, stagger, recargas) sem medição de jogo.
- Recuperação dos ataques segue o fim do clipe (o Attack_01 fica 3,2 s parado, mais que os 0,6 s da folha); falta decidir se corta o clipe.
- Partículas de energia do Blender (`VN_Energia.*`) e a luz verde do peito ficaram de fora do glb; a energia aparece só pela emissão.
- Câmera sem ajuste à grade de pixels: andando, as bordas tremem um pouco.
- Contorno só externo; sem linhas internas.
- Herói é uma cápsula sem animação; o golpe dele é por distância (2 m), não por área.
- O ataque da folha "Absorção" puxa energia de árvores da arena; aqui são 4 pontos fixos em volta do chefe.
- Não testado em máquina fraca nem no celular.
