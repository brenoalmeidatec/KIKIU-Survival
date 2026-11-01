# Arte, som e fontes de terceiros: o que pode e como registrar

**Regra (Alisson, 2026-10-12):** nada de arte com direitos autorais. Arte de terceiros de **livre uso** pode e deve ser usada quando economiza esforço e é compatível com o nosso contexto. Isto substitui a regra antiga ("nada de arte de terceiros no Git", #132 e #116).

## O que serve ("livre uso")
Serve a licença que permite, ao mesmo tempo, **uso comercial**, **redistribuição dentro do jogo** (o jogo vai ser publicado) e **modificação** (a gente recorta, reduz, quantiza, gera normal map):
- **CC0 / domínio público / Unlicense**: sem condição.
- **CC BY (3.0 ou 4.0)**: com **crédito** (autor, título, licença, link) na tela de Créditos e neste registro.
- **OGA-BY, MIT, BSD, zlib** (para assets) e **SIL OFL** (fontes): com o texto da licença quando ela pedir.

## O que NÃO serve
- Qualquer coisa com **direitos autorais reservados**: sem licença declarada, "uso pessoal", "só para estudo", capturas ou extrações de outros jogos, filmes e marcas, fan art de propriedade alheia.
- **CC BY-NC** (não comercial) e **CC ND** (sem derivados): a gente vende ou publica o jogo e adapta tudo.
- **Copyleft** (CC BY-SA, GPL, LGPL): só com o OK do Alisson, caso a caso (pode obrigar a abrir os arquivos adaptados).
- **Pago:** só com o OK do Breno (regra do `CLAUDE.md`: nada pago sem ele).
- Licenças que deixam **usar no jogo mas não redistribuir o arquivo avulso** (como animações de serviços que exigem conta): só o **resultado cozido** (sprite já renderizado) vai ao Git, nunca o arquivo-fonte cru.

## Compatível com o nosso contexto
Além da licença, o item tem de combinar com o jogo: pixel art 2.5D a 45 graus, escuro com poças de luz coloridas (`docs/visual_2_5d/`), herói de ~39 px em 960x540, paleta enxuta. O que for diferente a gente adapta no pipeline (recorte, redução com filtro BOX, paleta, contorno de 1 px, normal map pelo gerador); se a adaptação custar mais do que fazer no Blender, não vale.

## Como usar (passo a passo)
1. Ache o arquivo e **confira a licença na página dele no dia** (a licença é por arquivo; pacotes às vezes misturam).
2. Sites que pedem login para baixar (Freesound, Mixamo): quem tem a conta baixa; o Claude não entra em contas.
3. Guarde o arquivo em `jogos/hordas/projeto/assets/` (arte e som) ou `assets/fonte/` (fonte) junto do texto da licença quando ela exigir (`LICENSE.txt` ou `OFL.txt` ao lado).
4. **Registre na tabela abaixo** (todas as colunas) e ponha o crédito na tela de Créditos se a licença pedir.
5. Música e efeitos sonoros também entram no `docs/LICENCAS_AUDIO.md`.
6. Na dúvida, não use e pergunte.

## Registro
| Arquivo(s) no jogo | Onde é usado | Autor | Fonte (link) | Licença | Crédito exigido? | Mudanças nossas | Data |
|---|---|---|---|---|---|---|---|
| `assets/fonte/jersey10/` | títulos da v2 | The Soft Type Project | Google Fonts (Jersey 10) | SIL OFL 1.1 | texto da licença (`OFL.txt`) e Créditos | nenhuma | 2026-10-11 |
| `assets/fonte/PressStart2P.ttf` | números e HUD da v1 (o HUD da v2 deixou de usar, em 2026-10-20) | CodeMan38 | Google Fonts (Press Start 2P) | SIL OFL 1.1 | Créditos | nenhuma | desde a v1 |
| `assets/fonte/atkinson/` | HUD da v2 (texto nítido e legível em tamanho pequeno) | Braille Institute of America | Google Fonts (Atkinson Hyperlegible), `ofl/atkinsonhyperlegible` | SIL OFL 1.1 | texto da licença (`OFL.txt`) e Créditos | nenhuma | 2026-10-20 |
| `assets/audio/musica/*.ogg` | música | Kevin MacLeod (incompetech.com) | incompetech.com | CC BY 4.0 | sim (Créditos e `LICENCAS_AUDIO.md`) | cortes, laço, ganho, OGG | 2026-10-12 |
| ~~`assets/fonte/pixelify_sans/`~~ | removida em 2026-10-12 (o 5 saía como S: "500" lia-se "800"); trocada pela Spleen | The Pixelify Sans Project | Google Fonts (Pixelify Sans) | SIL OFL 1.1 | - | - | 2026-10-11 |
| `assets/fonte/spleen/spleen-8x16.otf` | texto corrido e valores da v2 (`Dados.fonte_texto`), sempre em 16 px | Frederic Cambus | https://github.com/fcambus/spleen (release 2.2.0) | BSD de 2 cláusulas | sim: aviso de copyright e texto da licença (`LICENSE.txt` ao lado; linha na tela de Créditos) | nenhuma | 2026-10-12 |
| `assets/audio/v2/corte1.wav` | v2: katana, 1º corte (`dados/v2_combate.json`, `som: "corte1"`) | Kenney (kenney.nl) | RPG Audio, `Audio/knifeSlice.ogg`: https://kenney.nl/assets/rpg-audio | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/corte2.wav` | v2: katana, 2º corte | Kenney (kenney.nl) | RPG Audio, `Audio/knifeSlice2.ogg`: https://kenney.nl/assets/rpg-audio | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/estocada.wav` | v2: katana, estocada | Kenney (kenney.nl) | RPG Audio, `Audio/drawKnife2.ogg`: https://kenney.nl/assets/rpg-audio | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/impacto.wav` | v2: acerto comum num monstro | Kenney (kenney.nl) | Impact Sounds, `Audio/impactMetal_medium_002.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/critico.wav` | v2: acerto crítico | Kenney (kenney.nl) | Impact Sounds, `Audio/impactMetal_heavy_001.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/morte.wav` | v2: morte de monstro (grande = mais grave); também ao banir carta (`telas.gd`) | Kenney (kenney.nl) | Impact Sounds, `Audio/impactSoft_heavy_001.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/esquiva.wav` | v2: esquiva do herói | Kenney (kenney.nl) | RPG Audio, `Audio/cloth2.ogg`: https://kenney.nl/assets/rpg-audio | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/orbe.wav` | v2: coleta de orbe de XP (tom sobe) | Kenney (kenney.nl) | Impact Sounds, `Audio/impactGlass_light_002.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/dano_heroi.wav` | v2: herói recebe dano; também quando rerrolar ou banir não dá certo (`telas.gd`) | Kenney (kenney.nl) | Impact Sounds, `Audio/impactPunch_medium_001.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/nivel.wav` | v2: subir de nível; também carta rara na escolha (`telas.gd`) | Kenney (kenney.nl) | Impact Sounds, `Audio/impactBell_heavy_000.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/evolucao.wav` | v2: evolução de arma | Kenney (kenney.nl) | Impact Sounds, `Audio/impactBell_heavy_002.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/carta.wav` | v2: carta virada (pausa, telas de escolha e resultado) | Kenney (kenney.nl) | RPG Audio, `Audio/bookFlip2.ogg`: https://kenney.nl/assets/rpg-audio | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/escolher.wav` | v2: escolha de carta ou melhoria | Kenney (kenney.nl) | RPG Audio, `Audio/bookPlace1.ogg`: https://kenney.nl/assets/rpg-audio | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/bau.wav` | v2: baú abre | Kenney (kenney.nl) | RPG Audio, `Audio/creak2.ogg`: https://kenney.nl/assets/rpg-audio | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/bau_cai.wav` | v2: baú cai no chão | Kenney (kenney.nl) | Impact Sounds, `Audio/impactWood_heavy_001.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/ui_cursor.wav` | v2: cursor do menu fora da partida (santuário; `v2/pausa.gd`) | Kenney (kenney.nl) | Interface Sounds, `Audio/click_002.ogg`: https://kenney.nl/assets/interface-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/ui_confirmar.wav` | v2: confirmar no menu fora da partida (santuário; `v2/pausa.gd`) | Kenney (kenney.nl) | RPG Audio, `Audio/metalLatch.ogg`: https://kenney.nl/assets/rpg-audio | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/escudo_bloqueio.wav` | NÃO LIGADO: escudo bloqueia (mecânica na branch `alisson/v2-ruptura`) | Kenney (kenney.nl) | Impact Sounds, `Audio/impactPlate_medium_002.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/escudo_perfeito.wav` | NÃO LIGADO: bloqueio perfeito do escudo (branch `alisson/v2-ruptura`) | Kenney (kenney.nl) | Impact Sounds, `Audio/impactBell_heavy_004.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/ruptura_carga.wav` | NÃO LIGADO: Ruptura carregando (branch `alisson/v2-ruptura`) | Kenney (kenney.nl) | Impact Sounds, `Audio/impactPlate_heavy_004.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/audio/v2/ruptura_solta.wav` | NÃO LIGADO: Ruptura solta (branch `alisson/v2-ruptura`) | Kenney (kenney.nl) | Impact Sounds, `Audio/impactGlass_heavy_004.ogg`: https://kenney.nl/assets/impact-sounds | CC0 1.0 | não | cortado, mono 44,1 kHz, WAV, normalizado | 2026-10-12 |
| `assets/titulo/fundo.png` | fundo da tela de título da v2 (`v2/menu_principal.tscn`) | Alisson: arte própria gerada no GPT (prompt no corpo do PR #215) | arte gerada no GPT pelo Alisson, versionada em `jogos/hordas/fonte_arte/fundo_titulo_fonte.webp` (1672x941) | própria (sem licença de terceiros) | não | recorte 16:9 reduzido a 960x540 (BOX), 48 cores sem dithering e sem o título K.I.K.I.U (`fonte_arte/gerar_fundo_titulo.py`) | 2026-10-12 |
| `assets/v2/armas/*.png` (44 sprites e 25 normais; lista em `indice.json`) | sprites das armas da v2, ligados em `v2/armas_novas.gd` | Alisson (arte própria) | gerada no GPT pelo Alisson; folhas-fonte em `jogos/hordas/prototipos/cara_nova/objetos/fonte_armas_*.webp` | própria do autor (sem licença de terceiros) | não | recorte por célula, redução BOX, alfa binário (projéteis e aliados) ou brilho virou alfa (efeitos, fundo preto), quantização sem dithering, normal map (projéteis e aliados), contorno claro de 1 px (flecha, shuriken e dardo) | 2026-10-12 |
| `assets/v2/armas/` (30 sprites novos e 18 normais; IDs em `indice.json`) | cinco golpes antigos e 25 evoluções da v2 | Codex do Alisson (arte própria gerada com imagegen) | três folhas `fonte_armas_evolucoes_*.png` em `jogos/hordas/prototipos/cara_nova/objetos/`; especificação em `docs/visual_2_5d/armas_evolucoes/PROMPTS.md` | própria, sem material de terceiros | não | recorte pelo modo armas de gerar_objetos.py, BOX, quantização sem dither, remoção de fundo branco ou preto aditivo, normais de projéteis/aliados e contorno claro de 1 px em lâminas/flechas evoluídas | 2026-10-14 |
| `jogos/hordas/fonte_arte/blender_herois/codex_estudo/` (`criar_estudo.py`, `criar_pixel_art.py`, `heroi_pixel_original_codex.png`) e `estudo_estilo/hazaki_blender_estilo_*` | ESTUDO, NÃO LIGADO ao jogo: modelo 3D do herói (rosto, cabelo, lenço, katana) e técnica de pixel nativo; folha derivada no estilo do jogo | Codex do Alisson (arte própria gerada no Blender 4.5, 15/10/2026) | scripts do estudo local do Codex (`ChatGPT/KIKIU/output/blender_estudo/`), copiados sem mudança; `gerar_heroi_estilo.py` os reaproveita | própria (sem licença de terceiros) | não | paleta, luz, contorno e escala trocados para o estilo do jogo | 2026-10-15 |

(Itens novos entram no fim da tabela.)

## Arte própria do salão — Codex do Alisson,14/10/2026
- Fontes: jogos/hordas/fonte_arte/santuario_v2/fonte_fundo.png, fonte_estruturas.png, fonte_portais.png. Destino: jogos/hordas/projeto/assets/v2/santuario/.
- Criadas com imagegen embutido a pedido do Alisson, seguindo conceito aprovado pelo Breno no PR260. Não adicionam arte de terceiros.
- Recorte e redução pelo wrapper gerar.py, reutilizando o pipeline gerar_objetos.py. Prompts/contexto em docs/visual_2_5d/santuario/IMPLEMENTACAO.md. Fontes originais preservadas.
## Teste de animação imagegen — Codex do Alisson,15/10/2026
- Imagens-fonte próprias geradas com imagegen embutido para a issue266: jogos/hordas/fonte_arte/teste_animacao/heroi_andando_baixo.png, heroi_andando_baixo_v2.png e golpe_katana.png.
- Referência do herói fornecida pelo projeto; nenhum material novo de terceiros. Prompts e limites registrados ao lado das fontes. Sem recorte/GIF/integração nesta entrega; isso fica com Claude do Alisson.
## Ícones das cartas por ID — Codex do Alisson,15/10/2026
- Oito folhas-fonte próprias geradas com imagegen embutido em jogos/hordas/fonte_arte/icones_cartas/folha_01.png até folha_08.png, a pedido direto do Alisson(issue270).
- Direção: pixel art2.5D dark fantasy, materiais frios e brilho elemental; folha01 gerada sem imagem externa e demais usam a primeira como estilo. Prompts exatos e índice por categoria/ID ao lado. Nenhum novo material de terceiros.
- São86entradas de cartas mais katana/escudo/Ruptura e selo Q indisponível(90motivos). Não são animações ou sprites de ataque; recorte/integração permanecem com Claude do Alisson.

- 2026-10-15 — jogos/hordas/fonte_arte/marco4/fonte_estruturas.png: oito estruturas; arte própria gerada no Codex com imagegen, referência visual do projeto, sem material novo de terceiros. Grade e prompts ao lado; recorte e integração feitos no PR #295 (Claude do Alisson, 2026-10-15).
- 2026-10-15 — jogos/hordas/fonte_arte/hud_molduras/*.png: componentes para retrato, barras de vida/fôlego e slots E/Q; arte própria gerada no Codex com imagegen, sem material novo de terceiros. Grade3×3 e prompts ao lado; recorte/9-slice/integração pendentes.
- 2026-10-15 — jogos/hordas/projeto/v2/hud/moldura_{retrato,barra,habilidade}.png (+ molduras_codex.json): recorte, redução BOX (borda de 4 a 6 px) e quantização (32 cores, sem dither) das folhas acima, por `gerar_objetos.py hud`; derivados de arte própria, sem material novo de terceiros. Integradas no HUD da v2 (retrato do herói, barras de vida e fôlego, slots E e Q).
- 2026-10-15 — jogos/hordas/fonte_arte/fusoes/*.png: moldura, halo, onda Ventania e ícone; arte própria gerada no Codex com imagegen, sem material novo de terceiros. Prompts e dimensões ao lado; fontes RGBA sem recorte/integração.

- 2026-10-15 — integração (Claude do Alisson): derivados em jogos/hordas/projeto/assets/v2/fusoes/ (moldura 600 x 200 em 9-slice com borda de 12 px, halo 48 x 48 branco, Ventania 64 x 32 e ícone 16 x 16), feitos pelo modo `fusoes` de gerar_objetos.py: recorte, redução BOX, alfa em degraus e paleta sem dithering. Nenhum material de terceiros.

## Quatro modificadores dos heróis — Codex do Alisson, 15/10/2026
- Fonte: jogos/hordas/fonte_arte/icones_cartas/folha_09.png. Arte própria gerada no Codex com imagegen para a issue #275 e pedido direto do Alisson.
- Abalo sísmico, Peso de muralha, Chuva de adagas e Mira longa; fontes 02/03 próprias usadas apenas como referência de estilo. Nenhum novo material de terceiros.
- Fonte original 1447×1087 preservada; ajuste do fundo vazio para 1448×1086, recorte e ligação ficam com Claude do Alisson. Prompts exatos e índice por ID ao lado da imagem.
>

## Ícones do santuário — Claude do Alisson (PC), 18/10/2026
- jogos/hordas/fonte_arte/icones_santuario/gerar.py gera em código (Python, PIL) 22 ícones pixel art 24x24 em jogos/hordas/projeto/assets/v2/icones_santuario/*.png (melhorias, conquistas, modo Pesadelo, rastro de katana, estruturas, portais e um genérico). Arte própria desenhada por código, sem imagegen e sem material de terceiros; paleta de v2/paleta.gd.

## Folhas animadas dos golpes secundários — Claude do Breno (PC do trabalho), 19/10/2026
- jogos/hordas/fonte_arte/armas_anim/gerar_{projeteis,meteoros,aneis,nuvens}.py geram em código (Python, Pillow, semente fixa, sem rede) 83 tiras animadas em jogos/hordas/projeto/assets/v2/armas_anim/*.png e os índices indice_{projeteis,meteoros,aneis,nuvens}.json. Arte própria desenhada pixel a pixel por código (sem imagegen e sem material de terceiros); as imagens paradas de assets/v2/armas/ e as fontes fonte_armas_*.webp serviram só de referência de cor, forma e silhueta, sem copiar pixels. Licença: a do projeto.
- Projéteis (voo + impacto): flecha_roxa, lanca_gelo, dardo_verde, feixe_dourado, adaga_aco, shuriken_sombria, disco_ferro, laminas, bola_fogo e bola_chumbo.
- Meteoros (queda + impacto + marca): meteoro_flamejante, cometa_gelo, cometa_roxo, estrela_cadente, espinho_verde, pedra_vulcanica e os três que faltavam (pedra_cinza, fogo_do_ceu e raio_meteorico).
- Anéis (expandir): anel_onda_branca, anel_dourado, anel_gelo, anel_vermelho, terremoto_poeira, anel_eletrico, redemoinho_verde, anel_espinhos_verdes e anel_lunar.
- Nuvens (entrada + loop + saída): nuvem_veneno, nevoa_gelada, nuvem_cinzas, fumaca_sonolenta, chuva_acida, nuvem_neve, nuvem_esporos, nuvem_sangue e nevoa_espectral.
- Prévias ampliadas 4x em docs/combate_v2/previas/ e GIFs do jogo em docs/combate_v2/gifs/ (capturados por testes/fotos/golpes_gif.tscn): geração própria, não vão para o jogo. Nenhuma arte existente foi sobrescrita.- 2026-10-19, segunda leva (mesmo autor e mesma licença): gerar_{evo_projeteis,evo_met_aneis,evo_nuvens,magias}.py geram mais 55 tiras e os índices indice_{evo_projeteis,evo_met_aneis,evo_nuvens,magias}.json: as evoluções urso_solar, chuva_de_lacas, bola_incendiaria, chuva_de_ferro, tempestade_primordial, anel_de_brasas, pedreira_ardente, cometa_duplo, eclipse_negro, juizo_final, estrondo, terra_partida, juramento_sagrado, nevasca_congelante, cinzas_acidas, peste_negra e furacao_glacial; aura_fogo; corvos e revoada_de_trovoes; runa e circulo_runico; o impacto do raio; ventania, onda e fura. Arte própria por código, as imagens paradas de assets/v2/armas e assets/v2/fusoes só como referência, sem material de terceiros.- 2026-10-19, quarta leva (mesmo autor e licença): gerar_perigo.py gera perigo_chuva_{queda,impacto}.png, perigo_estouro_impacto.png, perigo_investida_impacto.png e indice_perigo.json, para os ataques do chefe e da elite. Arte própria por código, sem terceiros; gerar_martelo.py gera martelo_trovao_queda.png e indice_martelo.json.


## Fontes da #349 — Codex do Alisson, 20/10/2026

| Arquivo(s) no jogo | Onde é usado | Autor | Fonte (link) | Licença | Crédito exigido? | Mudanças nossas | Data |
|---|---|---|---|---|---|---|---|
| `jogos/hordas/fonte_arte/especial_q/*.png` | fontes dos ícones Q de Hazaki, Nicão e Lucas; integração pendente | Codex do Alisson | imagegen integrado; prompts em `jogos/hordas/fonte_arte/especial_q/PROMPTS.md` | arte própria gerada no Codex, licença do projeto | não há atribuição de terceiros | geração própria; fontes sem recorte | 2026-10-20 |
| `jogos/hordas/fonte_arte/chefes_v2/*.png` | fontes dos bustos Devorador da Carne, Devoradora da Estrutura e Devorador da Terra (arquivos-fonte ainda com os nomes antigos de trabalho); integração pendente | Codex do Alisson | imagegen integrado; prompts em `jogos/hordas/fonte_arte/chefes_v2/PROMPTS.md` | arte própria gerada no Codex, licença do projeto | não há atribuição de terceiros | geração própria; fontes sem recorte | 2026-10-20 |
| `jogos/hordas/projeto/assets/v2/especial_q/{hazaki,nicao,lucas}.png` | ícones do Q de cada herói no círculo do HUD (32x32), derivados de `jogos/hordas/fonte_arte/especial_q/*.png` (linha acima) | Claude do Alisson (recorte), arte do Codex do Alisson | `python jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py especial_q` (caixa justa, BOX para 30 px, alfa binário a 25%, contorno de 1 px, paleta de 64 cores) | arte própria gerada no Codex, licença do projeto | não há atribuição de terceiros | recortada e reduzida das fontes do Codex | 2026-10-20 |
| `jogos/hordas/projeto/assets/v2/chefes/{devorador_da_carne,devoradora_da_estrutura,devorador_da_terra}.png` | busto de 36 x 36 na barra do chefe (`v2/hud.tscn`, `Raiz/Chefe/Busto`; `v2/hud.gd`, `BUSTOS`), derivado de `jogos/hordas/fonte_arte/chefes_v2/*.png` | Claude do Alisson (recorte), arte do Codex do Alisson | `python jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py chefes` (caixa justa, BOX em 34 px, alfa binário a 25%, contorno de 1 px, paleta de 64 cores compartilhada com o Q) | arte própria gerada no Codex, licença do projeto | não há atribuição de terceiros | recorte, redução e contorno; a arte não foi redesenhada | 2026-10-20 |
| `jogos/hordas/fonte_arte/referencia_herois/*.png` (e `LEIA-ME.md`, `PROMPTS.md`) | referências de Matheus, Nicão e Lucas, a partir das quais os três modelos do Blender foram feitos; as mesmas da #286 | Codex do Alisson | imagegen, usando referências do projeto; prompts em `PROMPTS.md` | própria (sem licença de terceiros) | não | nenhuma; sem recorte ou ligação no jogo | 2026-10-15 |
| `jogos/hordas/projeto/prototipos/cara_nova/sprites/lucas_*` (folha de 38 colunas, cor e normal, mais `lucas.json`) e `jogos/hordas/fonte_arte/blender_herois/lucas/` (scripts, quadros e GIFs) | sprite do herói Lucas (todas as animações), ligado em `v2/heroi.gd` | Claude do Alisson (arte própria, modelo 3D por script no Blender 4.5) | modelado a partir da referência do Codex (`fonte_arte/referencia_herois/lucas.png`, arte própria registrada abaixo) e das funções de modelagem do `codex_estudo/criar_estudo.py`; sem material de terceiros | própria (sem licença de terceiros) | não | modelo, rig, poses e render próprios; substitui o sprite antigo de 40x46 (cópia em `lucas/sprite_antigo_*`) | 2026-10-15 |
| `prototipos/cara_nova/sprites/nicao_albedo.png`, `nicao_normal.png` e `nicao.json` (fonte em `jogos/hordas/fonte_arte/blender_herois/nicao/`) | folha do herói Nicão na v2 (`dados/v2_herois.json`, sprite `nicao`): parado, andar, combo de 2 golpes, rolamento, defesa, dano e morte, 8 direções, cor e normal | Claude do Alisson: arte própria, modelada por script no Blender 4.5 | modelo feito da referência `fonte_arte/referencia_herois/nicao.png` (Codex do Alisson, arte própria gerada com imagegen); nenhum material de terceiros | própria (sem licença de terceiros) | não | modelo, rig e animações próprios; paleta, luz, contorno e escala do jogo | 2026-10-15 |
| `jogos/hordas/projeto/prototipos/cara_nova/sprites/matheus_albedo.png`, `matheus_normal.png` e `matheus.json` (fonte em `jogos/hordas/fonte_arte/blender_herois/matheus/`) | folha do personagem Matheus (usa o herói Hazaki; campo `sprite` de `dados/v2_salao.json`), ligada pelo salão, pela partida e pelo HUD | Claude do Alisson: arte própria, modelada por script no Blender | modelo feito da referência `fonte_arte/referencia_herois/matheus.png` (Codex do Alisson, arte própria) e do estudo próprio do Codex; nenhum material novo de terceiros | própria (sem licença de terceiros) | não | modelo, rig e animações próprios; paleta, luz, contorno e escala do jogo | 2026-10-15 |
| `jogos/hordas/fonte_arte/habilidade_e/{nicao,lucas}.png` e `jogos/hordas/projeto/assets/v2/habilidade_e/{nicao,lucas}.png` | fontes e ícones de 32×32 da E (Investida de Escudo e Salto das Adagas) no HUD | Codex do Alisson | ImageGen integrado; prompts em `jogos/hordas/fonte_arte/habilidade_e/PROMPTS.md`; derivados por `gerar_objetos.py habilidade_e` | arte própria gerada no Codex, licença do projeto | não há atribuição de terceiros | geração própria, recorte, redução, alfa binário, contorno e paleta do Q | 2026-10-21 |

## Reutilização de recursos no ritmo #371 — Codex do Alisson, 21/10/2026

- O curandeiro temporário reutiliza a folha própria procedural `jogos/hordas/projeto/assets/v2/armas/guardiao_pedra_dir.png`, já usada pelo aliado Guardião de Pedra. Fonte no repositório: `jogos/hordas/fonte_arte/blender_guardiao/gerar_guardiao.py` e seu `LEIA-ME.md` (modelo de blocos/rachaduras/musgo criado por código Blender, sem asset de terceiros; integrado no #325). Licença: a do projeto. Reutilização por AtlasTexture, sem alterar a imagem: coluna 2, linha 0, região `(154, 0, 77, 93)`, pé `(35, 72)`, conforme ficha `Andante.FICHAS.guardiao_pedra`. O anel verde é desenho por código e o coração usa `assets/v2/icones_cartas/vida.png`, das folhas próprias de ícones registradas acima. O pickup ímã usa `assets/v2/icones_cartas/ima.png`, do mesmo conjunto. Não há arte nova ou crédito de terceiros adicionado.

## Torre do Alquimista e Vila Amaldiçoada (#429), Claude do Alisson (PC), 26/10/2026

- `jogos/hordas/projeto/assets/v2/mapas/laboratorio/` e `jogos/hordas/projeto/assets/v2/mapas/cidade/` (atlas de objetos com normal, piso e decalques), regerados a partir de `jogos/hordas/fonte_arte/modelos3d/mapa_laboratorio.py`, `mapa_cidade.py`, `vila_pecas.py`, `vila_casas.py` e `vila_piso.py` (Blender 4.5 por script, com piso em numpy) e de `jogos/hordas/fonte_arte/mapas_v2/def_laboratorio.py`, `def_cidade.py`, `decalques_cidade.py` (decalques em Pillow). Arte própria, sem material de terceiros. Licença: a do projeto. Substitui o laboratório e a cidade pós-apocalípticos (mesma origem, mesmos nomes de objeto).

## Ruínas da Floresta com cenário próprio (#425), Claude do Alisson (PC), 26/10/2026

- `jogos/hordas/projeto/assets/v2/mapas/medio/` (`enfeites.png`, `enfeites_normal.png`, `piso.png`, `piso_normal.png`, `decalques.png`, `cenario.json`, `decalques.json`) e as fontes `jogos/hordas/fonte_arte/modelos3d/mapa_medio.py` (objetos e piso modelados por script no Blender 4.5: colunas, muros, arco, estátua, fonte seca, sarcófago, obelisco de runas) e `jogos/hordas/fonte_arte/mapas_v2/def_medio.py` (decalques por Pillow e a composição do mapa). Arte própria, sem material de terceiros. Licença: a do projeto.
- Árvores, arbustos, raízes, tocos, troncos, pedras, braseiro, fogueira, altar e caixa de oferenda do mapa são recortes do atlas da floresta (`prototipos/objetos`, arte já registrada acima), apenas esfriados em cor por `tingir()` do `def_medio.py`. Sem arte nova nem crédito de terceiros.

## Sprite próprio do corvo da Vila Amaldiçoada (#449), Claude do Alisson (notebook), 29/10/2026

- `jogos/hordas/projeto/prototipos/cara_nova/sprites/inimigo_corvo_carniceiro.json`, `inimigo_corvo_carniceiro_albedo.png`, `inimigo_corvo_carniceiro_normal.png` e `inimigo_corvo_carniceiro_emissao.png` (5 vistas x 4 quadros de andar/voo; o jogo espelha para as 8 direções), gerados por `jogos/hordas/prototipos/cara_nova/gerar_cara_nova.py` (`blender -b -P gerar_cara_nova.py -- monstro floresta corvo_carniceiro`, Blender 4.5) a partir do modelo `corvo_carniceiro` de `jogos/hordas/fonte_arte/modelos3d/floresta.py`. Arte própria, modelada por script, sem material de terceiros. Licença: a do projeto. Substitui, só para o "Corvo Agourento" da Vila (`dados/v2_elencos.json`), a aranha recolorida que ele usava.

## Sprite próprio do golem de vidro da Torre (#449), Codex do Alisson, 29/10/2026

- `jogos/hordas/fonte_arte/modelos3d/torre_golem_vidro.py` e os quatro derivados `prototipos/cara_nova/sprites/inimigo_golem_vidro{.json,_albedo.png,_normal.png,_emissao.png}`: arte própria, modelada por script no Blender 4.5.14, com facetas opacas em gelo/cobalto, núcleo e olhos emissivos. Usa o pipeline local `gerar_cara_nova.py` (cinco vistas, quatro quadros de andar; o jogo espelha para oito direções). Sem material, textura ou imagem de terceiros. Licença: a do projeto. Reprodução: `blender -b -P jogos/hordas/prototipos/cara_nova/gerar_cara_nova.py -- monstro torre_golem_vidro golem_vidro`.

## Sprite próprio do Espectro Uivante das Ruínas (#449), Codex do Alisson, 29/10/2026

- Folhas inimigo_espectro_albedo.png, inimigo_espectro_normal.png, inimigo_espectro_emissao.png e inimigo_espectro.json em jogos/hordas/projeto/prototipos/cara_nova/sprites/: cinco vistas por quatro quadros, espelhadas para oito direções. Render próprio em Blender 4.5.14 LTS pelo pipeline gerar_cara_nova.py, usando o modelo espectro já existente em fonte_arte/modelos3d/horror.py. Arte própria por script, sem materiais de terceiros; licença do projeto. Integração restrita ao Espectro Uivante das Ruínas, preservando tinta e números de combate.

## Homúnculo da Torre (#449), Codex do Alisson, 29/10/2026

- Modelo próprio `jogos/hordas/fonte_arte/modelos3d/torre_homunculo.py`, usando as primitivas do pipeline do projeto. Folhas `inimigo_homunculo.json`, `inimigo_homunculo_albedo.png`, `inimigo_homunculo_normal.png` e `inimigo_homunculo_emissao.png` em `jogos/hordas/projeto/prototipos/cara_nova/sprites/`: cinco vistas e quatro quadros, espelhados para oito direções. Geradas no Blender 4.5.14 por `gerar_cara_nova.py -- monstro torre_homunculo homunculo`. Sem arte de terceiros; licença do projeto. Troca somente a folha do homúnculo da Torre, preservando os números e a tinta do elenco.

## Aldeão morto-vivo da Vila (#449), Codex do Alisson, 29/10/2026

- `jogos/hordas/projeto/prototipos/cara_nova/sprites/inimigo_aldeao_morto.json`, `inimigo_aldeao_morto_albedo.png`, `inimigo_aldeao_morto_normal.png` e `inimigo_aldeao_morto_emissao.png`: cinco vistas por quatro quadros, espelhados pelo jogo para oito direções. Modelo próprio `jogos/hordas/fonte_arte/modelos3d/vila_aldeao.py`, renderizado pelo pipeline `gerar_cara_nova.py -- monstro vila_aldeao aldeao_morto` no Blender 4.5. Arte modelada por script, sem material de terceiros; licença do projeto. Substitui somente o cão recolorido de `cidade/aldeao_morto`, preservando os números de combate.

## Escudos de verdade, um por personagem (#467), Claude do Alisson (PC), 31/10/2026

- `jogos/hordas/projeto/assets/v2/escudos/hazaki.png`, `nicao.png`, `lucas.png` e `matheus.png` (e os `.import`): faixas 256x32 de 8 células (frente, lado, costas, rachado e 4 pedaços da quebra). Pixel art desenhada pixel a pixel por script (Python + Pillow) em `jogos/hordas/fonte_arte/escudos/gerar_escudos.py`, que também imprime os centros dos pedaços usados em `dados/v2_secundario.json`. Hazaki: tate de madeira laqueada vermelha com mon dourado; Nicão: redondo de ferro rebitado, amassado e enferrujado; Lucas: broquel de couro com aro de bronze; Matheus: escudo em gota de laca azul com um sino dourado. Arte própria gerada por script, sem material de terceiros e sem imagem gerada por IA; licença do projeto. Substitui o campo translúcido do escudo (só visual; as regras do bloqueio não mudaram).

## Troca de nomes dos bustos dos chefes, Claude do Alisson (PC), 31/10/2026

- Os três bustos de `jogos/hordas/projeto/assets/v2/chefes/` só mudaram de nome de arquivo (a imagem é a mesma, a origem e a licença continuam as da entrada dos bustos acima): `devorador_da_carne.png` virou `devourer_of_flesh.png`, `devoradora_da_estrutura.png` virou `devourer_of_structure.png` e `devorador_da_terra.png` virou `devourer_of_land.png`, porque os chefes passaram a ter nome em inglês (#467).

## Nota: onde `morte.wav` e `dano_heroi.wav` tocam hoje (31/10/2026, Claude do Alisson (PC))

Rerrolar e banir saíram da escolha de cartas, então as duas entradas acima citam usos que não existem mais. Hoje: `morte.wav` toca na morte de monstro (`v2/combate.gd`, `matar`) e no "sumir" do golem (`v2/audio.gd`); `dano_heroi.wav` toca quando o herói apanha (`v2/combate.gd`, `heroi_apanhou`) e quando o Automático não acha carta para completar a escolha (`v2/telas.gd`, `_automatico`). O arquivo e a licença não mudaram.

## pixelfx: base do tocador de folhas, Claude do Alisson (notebook), 31/10/2026

- `jogos/hordas/projeto/assets/v2/pixelfx/pickups/collect-burst.png` (e o `.import`): folha 784x648, 42 quadros de 112x108 (o registro usa os 34 primeiros), do efeito `pickups/collect-burst` do **pixelfx** (https://github.com/patch-gg/pixelfx), licença **MIT**, Copyright (c) 2026 Patch e Hugo Duprez (uso comercial, redistribuição e modificação permitidos, com o aviso de copyright e a licença junto). Exportada sem o boneco com `node tools/render.mjs pickups/collect-burst --sheet --no-actor` no clone do pixelfx; sem retoque no PNG. No jogo é recolorida por modulate (azul-ciano da alma) em `dados/v2_pixelfx.json`. Toca ao pegar um orbe de XP (`v2/fx_folha.gd`). Como regenerar e registrar outro efeito: `docs/PIXELFX.md`.

## pixelfx: status sobre monstros e herói (chama, relógio, estrelas), Claude do Alisson (notebook), 31/10/2026

- `jogos/hordas/projeto/assets/v2/pixelfx/status/slowed.png` (e o `.import`): folha 280x216, 72 quadros de 28x27, do efeito `status/slowed` do **pixelfx** (https://github.com/patch-gg/pixelfx), licença **MIT**, Copyright (c) 2026 Patch e Hugo Duprez. Modificado: só o relógio (o boneco padrão que a folha original traz foi cortado fora) e reduzido à metade com média de caixa, por `jogos/hordas/fonte_arte/pixelfx_status/preparar_status.py`. Lentidão (`lento_t`) de monstros e a teia da Rainha Tecelã no herói (`v2/fx_status.gd`).
- `jogos/hordas/projeto/assets/v2/pixelfx/status/stunned.png` (e o `.import`): folha 416x336, 60 quadros de 52x42, do efeito `status/stunned` do **pixelfx**, licença **MIT**, Copyright (c) 2026 Patch e Hugo Duprez. Modificado: só as estrelas e pássaros de cima, recortados da folha original (sem o boneco), no tamanho original, pelo mesmo script. Atordoamento longo (`atordoa_t`) de monstros.
- `jogos/hordas/projeto/assets/v2/pixelfx/status/burning.png` (e o `.import`): folha 144x64, 12 quadros de 24x32. **Arte própria, sem origem externa**: o `status/burning` do pixelfx é o boneco inteiro em chamas e não serve sobre os nossos monstros, então a chama é desenhada por código (paleta própria) no mesmo `preparar_status.py`. Fogo (`queima_t`) de monstros.

## pixelfx: recompensa e chegadas, Claude do Alisson (notebook), 31/10/2026

Seis folhas do **pixelfx** (https://github.com/patch-gg/pixelfx), licença **MIT**, Copyright (c) 2026 Patch e Hugo Duprez (uso comercial, redistribuição e modificação permitidos, com o aviso de copyright e a licença junto). Todas exportadas sem o boneco com `node tools/render.mjs <efeito> --sheet --no-actor` no clone do pixelfx. Cada uma tem o `.import` versionado junto, e o registro de uso está em `dados/v2_pixelfx.json`.

- `jogos/hordas/projeto/assets/v2/pixelfx/pickups/chest-open.png`: efeito `pickups/chest-open`. **Recortada**: só as linhas 3 a 10 da folha original (80 quadros de 176x112, do 21º ao 100º; os 20 primeiros eram o baú parado e o fim só brilho). Toca quando a escolha do baú fecha.
- `jogos/hordas/projeto/assets/v2/pixelfx/pickups/loot-beam.png`: efeito `pickups/loot-beam`, sem retoque; recolorida em dourado por modulate. Feixe preso ao baú enquanto ele espera.
- `jogos/hordas/projeto/assets/v2/pixelfx/ui/level-up.png`: efeito `ui/level-up`, sem retoque no PNG; o registro usa só os 18 primeiros quadros (a coluna de luz), sem o texto em inglês "LEVEL UP!". Toca nos pés do herói ao subir de nível.
- `jogos/hordas/projeto/assets/v2/pixelfx/spawn/spawn-portal.png`: efeito `spawn/spawn-portal`, sem retoque; recolorida pela cor da elite ou do chefe. Toca onde a elite e o chefe chegam.
- `jogos/hordas/projeto/assets/v2/pixelfx/spawn/summon-rise.png`: efeito `spawn/summon-rise`, sem retoque; o registro usa só os 44 primeiros quadros (o círculo e as faíscas, antes do demônio que a folha desenha). Toca nos filhotes da elite Invocadora.
- `jogos/hordas/projeto/assets/v2/pixelfx/spawn/soul-rise.png`: efeito `spawn/soul-rise`, sem retoque; o registro usa só os 64 primeiros quadros. Toca quando a elite ou o chefe morre.
