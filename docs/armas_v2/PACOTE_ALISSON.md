# Pacote de sprites das armas da v2 (para o Alisson)

Este pacote tem um sprite por arma (50) e por fusão (9). Cada entrada traz o resumo visual, a paleta, o tamanho e o prompt pronto.

## Prompt-base de estilo (cole antes de cada prompt, para manter todas as armas parecidas)

> Pixel art for a 2.5D top-down survival game, 960x540 view. Clean hard pixels, no anti-aliasing, no gradients outside the palette, lit from the upper left, soft colored glow allowed as a separate light layer. Transparent background. No text, no labels, no borders. Each sprite sheet is one horizontal row of equal frames with the exact size given.

## Como exportar e onde salvar

1. Gere a imagem com o tamanho exato do sprite sheet da entrada (largura = quadro x quadros, altura = quadro).
2. Exporte em PNG com fundo transparente, sem redimensionar (se o gerador mudar o tamanho, recorte ou reduza para o tamanho exato, sem suavizar).
3. Salve como `<id>.png` (o id está no título de cada entrada) na pasta `jogos/hordas/projeto/assets/v2/armas/`. Sugestão, não obrigatório: se a pasta não existir, crie junto com o arquivo.
4. Não mexa no código: o Claude do projeto liga os sprites às armas depois que você entregar.

## Armas (50)

# Lâminas Rodopiantes (laminas)
- **Resumo visual (2 linhas):** Lâminas de luz azul-gelo giram num anel achatado em volta do herói, com um brilho e dois rastros atrás de cada uma. Cada lâmina é uma faixa reta e afilada que corta quem encosta nela.
- **Paleta:** #FFFFFF (núcleo branco), #B2E6FF (azul-gelo, cor da arma), #CCF2FF (borda azul-claro).
- **Sprite:** 26 x 11 px por quadro, 1 quadro (sheet de 26 x 11 px).
- **Prompt para gerar a imagem (em inglês, pronto para colar):** Pixel art sprite of one glowing ice-blue blade, seen from a top-down 2.5D view: a straight, slightly tapered strip with a bright white core and a pale cyan edge, matching the style of a 2.5D top-down survival game. Use only these colors: white #FFFFFF for the core, ice blue #B2E6FF for the body, pale cyan #CCF2FF for the edge. Transparent background. Sprite sheet with 1 frame in a single row, exact size 26 x 11 pixels. No text, no border, no frame, no shadow outside the sprite.

# Aura de Fogo (aura_fogo)
- **Resumo visual (2 linhas):** Um anel de chama laranja gira em volta do herói, com línguas de fogo subindo para fora. A cada pulso que acerta, a chama se acende e solta faíscas de brasa.
- **Paleta:** #FF8C33 (laranja, cor da arma), #FFE673 (amarelo quente, centro da chama), #FF591F (vermelho-brasa), #FFB21F (âmbar, faíscas).
- **Sprite:** 64 x 64 px por quadro, 4 quadros em linha (sheet de 256 x 64 px). Cada quadro muda a forma das línguas de fogo, em loop.
- **Prompt para gerar a imagem (em inglês, pronto para colar):** Pixel art sprite of a ring of fire lying flat on the ground, seen from a top-down 2.5D view: an orange ring with flame tongues rising outward, a bright yellow-hot core edge and small ember highlights, matching the style of a 2.5D top-down survival game. Use only these colors: orange #FF8C33 for the ring, hot yellow #FFE673 for the inner glow, brick red #FF591F for the flame tips, amber #FFB21F for embers. Transparent background. Sprite sheet with 4 frames in a single row, each frame exactly 64 x 64 pixels, the total sheet exactly 256 x 64 pixels, the flame shape changing a little from frame to frame. No text, no border, no frame.

# Corvos Famintos (corvos)
- **Resumo visual (2 linhas):** Corvos roxo-escuros de asa batendo voam até o inimigo mais perto e o bicam, com um brilho roxo em volta de cada um. Quando não têm alvo, giram em volta do herói.
- **Paleta:** #211436 (corpo), #382154 (asa), #F29933 (bico), #FF4033 (olho), #B273FF (brilho roxo).
- **Sprite:** 22 x 18 px por quadro, 3 quadros em linha (sheet de 66 x 18 px): quadro 1 com a asa para cima, quadro 2 com a asa no meio, quadro 3 com a asa para baixo.
- **Prompt para gerar a imagem (em inglês, pronto para colar):** Pixel art sprite of a black-purple crow seen from a top-down 2.5D view, facing right, with a wing that changes position, an orange beak and a small red eye, matching the style of a 2.5D top-down survival game. Use only these colors: body #211436, wing #382154, beak #F29933, eye #FF4033. Transparent background. Sprite sheet with 3 frames in a single row, each frame exactly 22 x 18 pixels, the total sheet exactly 66 x 18 pixels. Frame 1 has the wing up, frame 2 the wing level, frame 3 the wing down. No text, no border, no frame, no shadow.

# Raio em Cadeia (raio)
- **Resumo visual (2 linhas):** Um raio azul-claro desce do alto sobre o inimigo e salta para os vizinhos. No ponto de impacto aparece uma faísca branca que se abre e some.
- **Paleta:** #FFFFFF (núcleo branco), #B8DBFF (azul-claro, cor do raio), #80B2FF (halo azul).
- **Sprite:** 32 x 32 px por quadro, 4 quadros em linha (sheet de 128 x 32 px): faísca de impacto que se abre e some. A linha do raio continua desenhada pelo código.
- **Prompt para gerar a imagem (em inglês, pronto para colar):** Pixel art sprite of an electric impact spark seen from a top-down 2.5D view: a white star-shaped flash with pale blue rays and a soft blue halo, opening up over 4 frames and then fading, matching the style of a 2.5D top-down survival game. Use only these colors: white #FFFFFF for the core, light blue #B8DBFF for the rays, blue #80B2FF for the halo. Transparent background. Sprite sheet with 4 frames in a single row, each frame exactly 32 x 32 pixels, the total sheet exactly 128 x 32 pixels. No text, no border, no frame.

# Runa Explosiva (runa)
- **Resumo visual (2 linhas):** Uma runa verde-água, com um triângulo dentro de um anel, fica gravada no chão. Ela gira devagar e pisca quando está armada.
- **Paleta:** #99F2E6 (verde-água, cor da runa), #8CFFF2 (ciano, usado na evolução), #FFFFFF (glifo e anel).
- **Sprite:** 64 x 64 px por quadro, 1 quadro (sheet de 64 x 64 px): triângulo dentro de anel, que o código gira e achata no chão.
- **Prompt para gerar a imagem (em inglês, pronto para colar):** Pixel art sprite of a glowing magic rune lying flat on the ground, seen from a top-down 2.5D view: a thin ring with an equilateral triangle inside, drawn in white and seafoam green, matching the style of a 2.5D top-down survival game. Use only these colors: white #FFFFFF for the triangle and the ring line, seafoam #99F2E6 for the glow, cyan #8CFFF2 for the inner highlight. Transparent background. Sprite sheet with 1 frame, exact size 64 x 64 pixels. No text, no border, no frame, no shadow.

# Flechas Sombrias (flechas_sombrias)
- **Resumo visual (2 linhas):** Uma flecha roxa-escura, curta, que voa reta até o inimigo mais perto, com rastro de fumaça escura atrás. Não gira.
- **Paleta:** roxo escuro (cor da arma) #6B2E9E; lilás #B98AE0; preto arroxeado #1A1020; branco #FFFFFF
- **Sprite:** 16×16 px por quadro, 1 quadro (sheet de 16×16 px). Só o projétil em voo; o impacto não entra neste sheet.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy horde game, in a moody, consistent pixel style. The sheet contains 1 frame in one horizontal row, each frame exactly 16x16 pixels, total image 16x16 pixels, transparent background, no text, no border, no frame lines, no ground shadow. A single dark purple arrow, about 12 by 3 pixels, pointing right, with a sharp near-black tip, a thin lilac highlight along the shaft and small dark fletching at the back. One frame only, no rotation. Use only these colors: #6B2E9E, #B98AE0, #1A1020, #FFFFFF. Keep the object centered in each frame, with a one pixel empty margin.

# Adagas Voadoras (adagas_voadoras)
- **Resumo visual (2 linhas):** Uma adaga de aço cinza-claro que gira no ar, com brilho metálico no giro. Duas ou três saem juntas em leque curto.
- **Paleta:** aço cinza-claro (cor da arma) #BFC7D1; cinza-azulado #7D8A99; branco #FFFFFF; preto #1C1F24
- **Sprite:** 16×16 px por quadro, 4 quadros de giro (sheet de 64×16 px). Só o projétil em voo; o impacto não entra neste sheet. Ao girar, os quadros se repetem em loop.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy horde game, in a moody, consistent pixel style. The sheet contains 4 frames in one horizontal row, each frame exactly 16x16 pixels, total image 64x16 pixels, transparent background, no text, no border, no frame lines, no ground shadow. A steel dagger about 10 by 4 pixels, light gray blade with a bright white glint on the edge, dark grip, pointing right. Four rotation frames, each frame rotated 45 degrees from the previous one, so the sequence loops. Use only these colors: #BFC7D1, #7D8A99, #FFFFFF, #1C1F24. Keep the object centered in each frame, with a one pixel empty margin.

# Lança de Geada (lanca_geada)
- **Resumo visual (2 linhas):** Uma lança de gelo azul com ponta cristalina, que avança devagar girando. Deixa um pequeno rastro de cristais atrás.
- **Paleta:** azul-gelo (cor da arma) #8CD9FF; azul-claro #D6F4FF; branco #FFFFFF; azul escuro #2F6E9E
- **Sprite:** 24×24 px por quadro, 4 quadros de giro (sheet de 96×24 px). Só o projétil em voo; o impacto não entra neste sheet. Ao girar, os quadros se repetem em loop.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy horde game, in a moody, consistent pixel style. The sheet contains 4 frames in one horizontal row, each frame exactly 24x24 pixels, total image 96x24 pixels, transparent background, no text, no border, no frame lines, no ground shadow. A frost spear about 18 by 4 pixels with a pale ice-blue crystal tip, a white highlight along the shaft and a darker blue outline. Centered in a square frame, pointing right. Four rotation frames, each rotated 45 degrees from the previous one, so the sequence loops. Use only these colors: #8CD9FF, #D6F4FF, #FFFFFF, #2F6E9E. Keep the object centered in each frame, with a one pixel empty margin.

# Estrelas de Sombra (estrelas_sombra)
- **Resumo visual (2 linhas):** Uma shuriken preta de quatro pontas, que gira rápido no ar em direção ao inimigo, com um pequeno risco cinza atrás.
- **Paleta:** preto (cor da arma) #1F1A29; cinza-escuro #4A4A52; cinza-claro #BDBDC4
- **Sprite:** 12×12 px por quadro, 4 quadros de giro (sheet de 48×12 px). Só o projétil em voo; o impacto não entra neste sheet. Ao girar, os quadros se repetem em loop.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy horde game, in a moody, consistent pixel style. The sheet contains 4 frames in one horizontal row, each frame exactly 12x12 pixels, total image 48x12 pixels, transparent background, no text, no border, no frame lines, no ground shadow. A black four-pointed shuriken about 8 by 8 pixels, with dark gray edges and a light gray highlight on one point. Centered in a square frame. Four rotation frames, each rotated 22.5 degrees from the previous one, so the sequence loops after 90 degrees. Use only these colors: #1F1A29, #4A4A52, #BDBDC4. Keep the object centered in each frame, with a one pixel empty margin.

# Bola de Fogo (bola_fogo)
- **Resumo visual (2 linhas):** Uma esfera de fogo laranja com núcleo amarelo, que sai devagar. Não gira; o desenho só segue a direção do voo.
- **Paleta:** laranja (cor da arma) #FF731A; amarelo #FFD93D; vermelho #D62E1F
- **Sprite:** 16×16 px por quadro, 1 quadro (sheet de 16×16 px). Só o projétil em voo; o impacto não entra neste sheet.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy horde game, in a moody, consistent pixel style. The sheet contains 1 frame in one horizontal row, each frame exactly 16x16 pixels, total image 16x16 pixels, transparent background, no text, no border, no frame lines, no ground shadow. A small fireball about 14 pixels across, with an orange body, a yellow hot core and a red rim. Centered in the frame. One frame only, no text. Use only these colors: #FF731A, #FFD93D, #D62E1F. Keep the object centered in each frame, with a one pixel empty margin.

# Dardos Peçonhentos (dardos_peconhentos)
- **Resumo visual (2 linhas):** Um dardo curto verde-limão com ponta escura, que voa reto em direção ao inimigo, deixando um rastro verde.
- **Paleta:** verde-limão (cor da arma) #80F233; verde-escuro #2E7D1F; preto #14140F
- **Sprite:** 16×16 px por quadro, 1 quadro (sheet de 16×16 px). Só o projétil em voo; o impacto não entra neste sheet.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy horde game, in a moody, consistent pixel style. The sheet contains 1 frame in one horizontal row, each frame exactly 16x16 pixels, total image 16x16 pixels, transparent background, no text, no border, no frame lines, no ground shadow. A short lime-green dart about 8 by 2 pixels, with a dark tip at the front and a darker green tail. Centered in the frame, pointing right. One frame only. Use only these colors: #80F233, #2E7D1F, #14140F. Keep the object centered in each frame, with a one pixel empty margin.

# Raio Solar (raio_solar)
- **Resumo visual (2 linhas):** Um feixe dourado fino e reto, que sai do herói em direção ao inimigo, com um ponto branco brilhante na ponta. Não gira.
- **Paleta:** dourado (cor da arma) #FFD94C; amarelo-claro #FFF3A8; branco #FFFFFF
- **Sprite:** 48×8 px por quadro, 1 quadro (sheet de 48×8 px). Só o projétil em voo; o impacto não entra neste sheet.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy horde game, in a moody, consistent pixel style. The sheet contains 1 frame in one horizontal row, each frame exactly 48x8 pixels, total image 48x8 pixels, transparent background, no text, no border, no frame lines, no ground shadow. A thin golden beam about 40 by 3 pixels, pointing right, with a bright white point at the front end and a soft golden glow along the body. Centered in a 48 by 8 pixel frame. One frame only. Use only these colors: #FFD94C, #FFF3A8, #FFFFFF. Keep the object centered in each frame, with a one pixel empty margin.

# Bumerangue de Ferro (bumerangue_ferro)
- **Resumo visual (2 linhas):** Um disco de ferro ferrugento que gira no próprio eixo enquanto voa, com um risco de faísca laranja atrás.
- **Paleta:** ferrugem (cor da arma) #B8734C; cinza-ferro #6E747C; laranja #FF8A2B
- **Sprite:** 16×16 px por quadro, 4 quadros de giro (sheet de 64×16 px). Só o projétil em voo; o impacto não entra neste sheet. Ao girar, os quadros se repetem em loop.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy horde game, in a moody, consistent pixel style. The sheet contains 4 frames in one horizontal row, each frame exactly 16x16 pixels, total image 64x16 pixels, transparent background, no text, no border, no frame lines, no ground shadow. A rusty iron disc about 16 pixels across, with a gray metal center and a few orange spark pixels on one edge. Four rotation frames, each rotated 45 degrees from the previous one, so the sequence loops. Use only these colors: #B8734C, #6E747C, #FF8A2B. Keep the object centered in each frame, with a one pixel empty margin.

# Bolas de Chumbo (bolas_chumbo)
- **Resumo visual (2 linhas):** Uma bola de chumbo cinza-escuro, pesada, que voa devagar com um pequeno rastro de poeira. Não gira.
- **Paleta:** chumbo cinza-escuro (cor da arma) #737885; cinza-claro #B5B9C2; marrom-poeira #8A6A4B
- **Sprite:** 16×16 px por quadro, 1 quadro (sheet de 16×16 px). Só o projétil em voo; o impacto não entra neste sheet.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy horde game, in a moody, consistent pixel style. The sheet contains 1 frame in one horizontal row, each frame exactly 16x16 pixels, total image 16x16 pixels, transparent background, no text, no border, no frame lines, no ground shadow. A heavy dark lead ball about 14 pixels across, with a light gray highlight on the upper left and a few brown dust specks at the bottom. Centered in the frame. One frame only. Use only these colors: #737885, #B5B9C2, #8A6A4B. Keep the object centered in each frame, with a one pixel empty margin.

# Nuvem Venenosa (nuvem_veneno)
- **Resumo visual (2 linhas):** Uma nuvem verde-tóxica, densa e com bolhas, cai sobre um inimigo e fica parada no chão, com partículas subindo. O pulso é lento e ela some no fim.
- **Paleta:** Verde-tóxico (cor do golpe) #73F233; Verde musgo #4B6B1F; Verde-escuro (sombra) #1E3312; Bolhas claras #E8FFB0
- **Sprite:** 132 x 82 px por quadro, 6 quadros em linha, sheet de 792 x 82 px. O quadro cobre o nível 5 (diâmetro de 124 px).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a dense toxic green cloud with rounded bubbles, lime and moss green, with small particles rising slowly for a 2.5D top-down survival game. The ground footprint is an ellipse squashed to about 62% of its width, seen from a slightly angled top-down view. Use these colors: #73F233, #4B6B1F, #1E3312, #E8FFB0. Transparent background. Exactly 6 frames in one horizontal row, each frame 132x82 px, total image 792x82 px. The 6 frames form a seamless looping gentle pulse animation. Consistent with the game's existing 2.5D pixel-art style. No text, no labels, no border, no frame outline, no drop shadow outside the effect.

# Nevoeiro Gelado (nevoeiro_gelado)
- **Resumo visual (2 linhas):** Uma névoa azul-gelo espessa se espalha no chão, com cristais finos girando devagar por dentro. Respira em pulsos lentos e some no fim.
- **Paleta:** Azul-gelo (cor do golpe) #338CFF; Azul profundo #1B3F8A; Branco-frio #E6F4FF; Azul-noite (sombra) #0E2350
- **Sprite:** 128 x 80 px por quadro, 6 quadros em linha, sheet de 768 x 80 px. O quadro cobre o nível 5 (diâmetro de 120 px).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a thick icy blue fog spreading on the ground, with fine ice crystals slowly rotating inside for a 2.5D top-down survival game. The ground footprint is an ellipse squashed to about 62% of its width, seen from a slightly angled top-down view. Use these colors: #338CFF, #1B3F8A, #E6F4FF, #0E2350. Transparent background. Exactly 6 frames in one horizontal row, each frame 128x80 px, total image 768x80 px. The 6 frames form a seamless looping gentle pulse animation. Consistent with the game's existing 2.5D pixel-art style. No text, no labels, no border, no frame outline, no drop shadow outside the effect.

# Cinzas Vulcânicas (cinzas_vulcanicas)
- **Resumo visual (2 linhas):** Uma nuvem grande, cinza-escura e turva cai no chão, com brasas apagadas girando por dentro. Pulsa rápido e some no fim.
- **Paleta:** Cinza-carvão (cor do golpe) #595961; Cinza-escuro #2E2E33; Cinza claro (borda) #9A9AA3; Laranja apagado (brasas) #8A4A22
- **Sprite:** 188 x 116 px por quadro, 6 quadros em linha, sheet de 1128 x 116 px. O quadro cobre o nível 5 (diâmetro de 180 px).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a large dark grey volcanic ash cloud, murky and thick, with dim orange-tinted dead embers swirling inside for a 2.5D top-down survival game. The ground footprint is an ellipse squashed to about 62% of its width, seen from a slightly angled top-down view. Use these colors: #595961, #2E2E33, #9A9AA3, #8A4A22. Transparent background. Exactly 6 frames in one horizontal row, each frame 188x116 px, total image 1128x116 px. The 6 frames form a seamless looping gentle pulse animation. Consistent with the game's existing 2.5D pixel-art style. No text, no labels, no border, no frame outline, no drop shadow outside the effect.

# Fumaça Sonolenta (fumaca_sonolenta)
- **Resumo visual (2 linhas):** Uma fumaça roxa-clara, suave e lenta, se espalha no chão com fiapos subindo devagar. Pulsa de leve e some no fim.
- **Paleta:** Roxo-claro (cor do golpe) #BF99FF; Lilás #A37FD9; Branco-lavanda #F3EEFF; Roxo profundo (sombra) #5E3D8C
- **Sprite:** 118 x 74 px por quadro, 6 quadros em linha, sheet de 708 x 74 px. O quadro cobre o nível 5 (diâmetro de 110 px).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a soft purple-lilac smoke cloud spreading slowly on the ground, with faint wisps rising upward for a 2.5D top-down survival game. The ground footprint is an ellipse squashed to about 62% of its width, seen from a slightly angled top-down view. Use these colors: #BF99FF, #A37FD9, #F3EEFF, #5E3D8C. Transparent background. Exactly 6 frames in one horizontal row, each frame 118x74 px, total image 708x74 px. The 6 frames form a seamless looping gentle pulse animation. Consistent with the game's existing 2.5D pixel-art style. No text, no labels, no border, no frame outline, no drop shadow outside the effect.

# Chuva Ácida (chuva_acida)
- **Resumo visual (2 linhas):** Uma área com gotas amarelo-esverdeadas caindo de cima e fumaça fina subindo onde batem. Fica pouco tempo no chão e some com fade.
- **Paleta:** Amarelo-ácido (cor do golpe) #F2E640; Verde-amarelado #B8D94A; Fumaça clara #E8EED8; Verde-oliva (sombra) #6E8A1E
- **Sprite:** 172 x 106 px por quadro, 6 quadros em linha, sheet de 1032 x 106 px. O quadro cobre o nível 5 (diâmetro de 164 px).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a patch of acid rain: yellow-green droplets falling onto the ground, with thin pale fumes rising where they hit for a 2.5D top-down survival game. The ground footprint is an ellipse squashed to about 62% of its width, seen from a slightly angled top-down view. Use these colors: #F2E640, #B8D94A, #E8EED8, #6E8A1E. Transparent background. Exactly 6 frames in one horizontal row, each frame 172x106 px, total image 1032x106 px. The 6 frames form a seamless looping gentle pulse animation. Consistent with the game's existing 2.5D pixel-art style. No text, no labels, no border, no frame outline, no drop shadow outside the effect.

# Nevasca (nevasca)
- **Resumo visual (2 linhas):** Uma nuvem branca e alta, com flocos saindo do centro para fora e ocupando o chão. Gira devagar e some no fim.
- **Paleta:** Branco (cor do golpe) #F7F7FC; Branco-gelo #DCEEF7; Cinza-azulado claro #A9BCCB; Azul-acinzentado (sombra) #6F8799
- **Sprite:** 138 x 86 px por quadro, 6 quadros em linha, sheet de 828 x 86 px. O quadro cobre o nível 5 (diâmetro de 130 px).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a tall white snowstorm cloud, with snowflakes swirling outward from its center for a 2.5D top-down survival game. The ground footprint is an ellipse squashed to about 62% of its width, seen from a slightly angled top-down view. Use these colors: #F7F7FC, #DCEEF7, #A9BCCB, #6F8799. Transparent background. Exactly 6 frames in one horizontal row, each frame 138x86 px, total image 828x86 px. The 6 frames form a seamless looping gentle pulse animation. Consistent with the game's existing 2.5D pixel-art style. No text, no labels, no border, no frame outline, no drop shadow outside the effect.

# Nuvem de Esporos (nuvem_espora)
- **Resumo visual (2 linhas):** Uma nuvem marrom-dourada de esporos, com grãos girando devagar e caindo para o chão. Fica bastante tempo e some no fim.
- **Paleta:** Marrom-dourado (cor do golpe) #B28033; Bege #E3CFA3; Âmbar #E0A22E; Marrom escuro (sombra) #5A3D17
- **Sprite:** 152 x 94 px por quadro, 6 quadros em linha, sheet de 912 x 94 px. O quadro cobre o nível 5 (diâmetro de 144 px).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a brown-gold spore cloud, with small grains slowly swirling and drifting down toward the ground for a 2.5D top-down survival game. The ground footprint is an ellipse squashed to about 62% of its width, seen from a slightly angled top-down view. Use these colors: #B28033, #E3CFA3, #E0A22E, #5A3D17. Transparent background. Exactly 6 frames in one horizontal row, each frame 152x94 px, total image 912x94 px. The 6 frames form a seamless looping gentle pulse animation. Consistent with the game's existing 2.5D pixel-art style. No text, no labels, no border, no frame outline, no drop shadow outside the effect.

# Cortina de Sangue (cortina_sangue)
- **Resumo visual (2 linhas):** Uma névoa vermelho-sangue densa, com gotas escorrendo de dentro, que aparece de uma vez no chão. Some no fim.
- **Paleta:** Vermelho-sangue (cor do golpe) #D9141F; Vermelho escuro #6B0A10; Rosa-vivo (borda) #FF5C7A
- **Sprite:** 94 x 58 px por quadro, 6 quadros em linha, sheet de 564 x 58 px. O quadro cobre o nível 5 (diâmetro de 86 px).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a dense blood-red mist patch, with drips of blood running down inside it, dark red with rose-pink edges for a 2.5D top-down survival game. The ground footprint is an ellipse squashed to about 62% of its width, seen from a slightly angled top-down view. Use these colors: #D9141F, #6B0A10, #FF5C7A. Transparent background. Exactly 6 frames in one horizontal row, each frame 94x58 px, total image 564x58 px. The 6 frames form a seamless looping gentle pulse animation. Consistent with the game's existing 2.5D pixel-art style. No text, no labels, no border, no frame outline, no drop shadow outside the effect.

# Névoa Espectral (nevoa_espectral)
- **Resumo visual (2 linhas):** Uma névoa branco-azulada, meio transparente, com rostos muito difusos por dentro, flutuando no chão. Pulsa de leve e some no fim.
- **Paleta:** Branco-azulado (cor do golpe) #CCF2F2; Azul-pálido #A8D8F0; Ciano claro #8EEBF0; Branco-névoa #F0FBFF
- **Sprite:** 108 x 66 px por quadro, 6 quadros em linha, sheet de 648 x 66 px. O quadro cobre o nível 5 (diâmetro de 100 px).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a pale blue-white ghostly mist, semi-transparent, with very faint blurred face shapes drifting inside for a 2.5D top-down survival game. The ground footprint is an ellipse squashed to about 62% of its width, seen from a slightly angled top-down view. Use these colors: #CCF2F2, #A8D8F0, #8EEBF0, #F0FBFF. Transparent background. Exactly 6 frames in one horizontal row, each frame 108x66 px, total image 648x66 px. The 6 frames form a seamless looping gentle pulse animation. Consistent with the game's existing 2.5D pixel-art style. No text, no labels, no border, no frame outline, no drop shadow outside the effect.

# Onda de Choque (onda_choque)
- **Resumo visual (2 linhas):** Um anel branco-gelo achatado nasce sob o herói e cresce para fora, andando com ele. Um filete branco acompanha a borda por dentro, e o anel some na borda da área.
- **Paleta:**
  - branco-gelo #FAFAFF (cor da arma)
  - azul-claro #8FD3FF (realce ou contorno)
  - branco #FFFFFF (realce ou contorno)
  - azul-noite #1E3550 (realce ou contorno)
- **Sprite:** 32x20 px por quadro, 6 quadros em linha (sheet de 192x20 px). Na tela, o sprite é esticado para a largura de 2 × raio do nível (de 140 a 180 px), com a altura em 62% da largura.
- **Prompt para o gerador de imagens (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D survival game, one horizontal row of 6 frames. Each frame is exactly 32x20 px, the full sheet is 192x20 px, with a transparent background, no text, no frame border and no blurred anti-aliasing. A white-ice shockwave ring: outer edge 3 px in the weapon color, with a thin 1.5 px white highlight just inside the edge, and a faint bright glint on the leading edge. The ring is drawn flattened like a floor ellipse (height about 62% of its width). Use only these colors: #FAFAFF, #8FD3FF, #FFFFFF, #1E3550. Frame 1 is a small ring just appearing, the last frame is the ring almost at full size and faded, and the frames in between show steady growth. Clean hard-edged pixels with a one-pixel darker outline, consistent with a dark fantasy pixel style. Output exactly 192x20 px.

# Pulso Sagrado (pulso_sagrado)
- **Resumo visual (2 linhas):** Um anel dourado sai do herói e cresce, com pequenas faíscas douradas subindo da borda. Some devagar ao chegar à borda da área.
- **Paleta:**
  - dourado #FFB233 (cor da arma)
  - amarelo-claro #FFE27A (realce ou contorno)
  - branco #FFFFFF (realce ou contorno)
  - marrom-escuro #6B4215 (realce ou contorno)
- **Sprite:** 32x20 px por quadro, 6 quadros em linha (sheet de 192x20 px). Na tela, o sprite é esticado para a largura de 2 × raio do nível (de 110 a 160 px), com a altura em 62% da largura.
- **Prompt para o gerador de imagens (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D survival game, one horizontal row of 6 frames. Each frame is exactly 32x20 px, the full sheet is 192x20 px, with a transparent background, no text, no frame border and no blurred anti-aliasing. A golden holy pulse ring: outer edge 3 px in gold, a thin white highlight inside, and a few tiny golden sparks rising from the edge. The ring is drawn flattened like a floor ellipse (height about 62% of its width). Use only these colors: #FFB233, #FFE27A, #FFFFFF, #6B4215. Frame 1 is a small ring just appearing, the last frame is the ring almost at full size and faded, and the frames in between show steady growth. Clean hard-edged pixels with a one-pixel darker outline, consistent with a dark fantasy pixel style. Output exactly 192x20 px.

# Anel Gelado (anel_gelado)
- **Resumo visual (2 linhas):** Um anel azul-gelo com cristais brancos na borda cresce a partir do herói e some na borda da área. A faixa é fina, mas o anel dispara sem parar.
- **Paleta:**
  - azul-gelo #73CCFF (cor da arma)
  - azul-claro #C9F2FF (realce ou contorno)
  - branco #FFFFFF (realce ou contorno)
  - azul-escuro #1F4F7A (realce ou contorno)
- **Sprite:** 32x20 px por quadro, 6 quadros em linha (sheet de 192x20 px). Na tela, o sprite é esticado para a largura de 2 × raio do nível (de 120 a 144 px), com a altura em 62% da largura.
- **Prompt para o gerador de imagens (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D survival game, one horizontal row of 6 frames. Each frame is exactly 32x20 px, the full sheet is 192x20 px, with a transparent background, no text, no frame border and no blurred anti-aliasing. A blue-ice ring: outer edge 3 px in ice blue, with small white ice crystals along the edge and a thin white highlight inside. The ring is drawn flattened like a floor ellipse (height about 62% of its width). Use only these colors: #73CCFF, #C9F2FF, #FFFFFF, #1F4F7A. Frame 1 is a small ring just appearing, the last frame is the ring almost at full size and faded, and the frames in between show steady growth. Clean hard-edged pixels with a one-pixel darker outline, consistent with a dark fantasy pixel style. Output exactly 192x20 px.

# Grito de Guerra (grito_guerra)
- **Resumo visual (2 linhas):** Um anel vermelho, grosso e lento, se espalha a partir do herói com linhas de vento vermelho por dentro. Demora mais que os outros anéis para chegar à borda da área.
- **Paleta:**
  - vermelho #E62626 (cor da arma)
  - carmim #8C0E1E (realce ou contorno)
  - vermelho-claro #FF7A7A (realce ou contorno)
  - branco #FFFFFF (realce ou contorno)
- **Sprite:** 48x30 px por quadro, 6 quadros em linha (sheet de 288x30 px). Na tela, o sprite é esticado para a largura de 2 × raio do nível (de 200 a 220 px), com a altura em 62% da largura.
- **Prompt para o gerador de imagens (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D survival game, one horizontal row of 6 frames. Each frame is exactly 48x30 px, the full sheet is 288x30 px, with a transparent background, no text, no frame border and no blurred anti-aliasing. A thick crimson war-cry ring: outer edge 6 px in red, with two or three faint red wind lines inside it and a thin white highlight. The ring is drawn flattened like a floor ellipse (height about 62% of its width). Use only these colors: #E62626, #8C0E1E, #FF7A7A, #FFFFFF. Frame 1 is a small ring just appearing, the last frame is the ring almost at full size and faded, and the frames in between show steady growth. Clean hard-edged pixels with a one-pixel darker outline, consistent with a dark fantasy pixel style. Output exactly 288x30 px.

# Terremoto (terremoto)
- **Resumo visual (2 linhas):** Uma elipse marrom achatada, rente ao chão, cresce a partir do herói com poeira e pedras que saltam na borda. Não tem altura: parece um tremor no solo.
- **Paleta:**
  - marrom-terra #8C5C33 (cor da arma)
  - cinza-pedra #7A7A74 (realce ou contorno)
  - marrom-escuro #4A2E17 (realce ou contorno)
  - poeira-clara #C9B79C (realce ou contorno)
- **Sprite:** 40x24 px por quadro, 6 quadros em linha (sheet de 240x24 px). Na tela, o sprite é esticado para a largura de 2 × raio do nível (de 150 a 180 px), com a altura em 62% da largura.
- **Prompt para o gerador de imagens (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D survival game, one horizontal row of 6 frames. Each frame is exactly 40x24 px, the full sheet is 240x24 px, with a transparent background, no text, no frame border and no blurred anti-aliasing. A flat brown earthquake ellipse lying on the ground (no height), with dust puffs and small grey pebbles jumping along the edge. The ring is drawn flattened like a floor ellipse (height about 62% of its width). Use only these colors: #8C5C33, #7A7A74, #4A2E17, #C9B79C. Frame 1 is a small ring just appearing, the last frame is the ring almost at full size and faded, and the frames in between show steady growth. Clean hard-edged pixels with a one-pixel darker outline, consistent with a dark fantasy pixel style. Output exactly 240x24 px.

# Martelo do Trovão (martelo_trovao)
- **Resumo visual (2 linhas):** Um anel amarelo estreito e muito rápido, quase um estalo, com faíscas elétricas e dois riscos brancos curtos ao lado. Some em menos de um décimo de segundo.
- **Paleta:**
  - amarelo #FFFF4C (cor da arma)
  - branco-azulado #DDF0FF (realce ou contorno)
  - branco #FFFFFF (realce ou contorno)
  - amarelo-escuro #A6A300 (realce ou contorno)
- **Sprite:** 32x20 px por quadro, 5 quadros em linha (sheet de 160x20 px). Na tela, o sprite é esticado para a largura de 2 × raio do nível (de 90 a 114 px), com a altura em 62% da largura.
- **Prompt para o gerador de imagens (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D survival game, one horizontal row of 5 frames. Each frame is exactly 32x20 px, the full sheet is 160x20 px, with a transparent background, no text, no frame border and no blurred anti-aliasing. A narrow, very bright yellow thunder ring with tiny electric sparks on the edge and two short white streaks beside it. The ring is drawn flattened like a floor ellipse (height about 62% of its width). Use only these colors: #FFFF4C, #DDF0FF, #FFFFFF, #A6A300. Frame 1 is a small ring just appearing, the last frame is the ring almost at full size and faded, and the frames in between show steady growth. Clean hard-edged pixels with a one-pixel darker outline, consistent with a dark fantasy pixel style. Output exactly 160x20 px.

# Rajada de Vento (rajada_vento)
- **Resumo visual (2 linhas):** Um anel verde-claro quase transparente passa rápido a partir do herói, com um rastro de vento atrás e folhas soltas. Some quase no mesmo instante em que aparece.
- **Paleta:**
  - verde-claro #A6FF8C (cor da arma)
  - branco #FFFFFF (realce ou contorno)
  - verde-folha #4E9A3A (realce ou contorno)
- **Sprite:** 32x20 px por quadro, 4 quadros em linha (sheet de 128x20 px). Na tela, o sprite é esticado para a largura de 2 × raio do nível (de 100 a 124 px), com a altura em 62% da largura.
- **Prompt para o gerador de imagens (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D survival game, one horizontal row of 4 frames. Each frame is exactly 32x20 px, the full sheet is 128x20 px, with a transparent background, no text, no frame border and no blurred anti-aliasing. A pale green wind ring, almost transparent, with a short trail of white wind lines behind it and tiny leaves at the edge. The ring is drawn flattened like a floor ellipse (height about 62% of its width). Use only these colors: #A6FF8C, #FFFFFF, #4E9A3A. Frame 1 is a small ring just appearing, the last frame is the ring almost at full size and faded, and the frames in between show steady growth. Clean hard-edged pixels with a one-pixel darker outline, consistent with a dark fantasy pixel style. Output exactly 128x20 px.

# Anel de Espinhos (anel_espinhos)
- **Resumo visual (2 linhas):** Um anel verde-escuro com espinhos saindo para fora cresce a partir do herói e some na borda da área. Os espinhos ficam para fora da borda, como uma cerca.
- **Paleta:**
  - verde-escuro #1A6B26 (cor da arma)
  - verde-musgo #3E8A3E (realce ou contorno)
  - marrom-musgo #5C4A22 (realce ou contorno)
  - verde-noite #0B2A10 (realce ou contorno)
- **Sprite:** 40x26 px por quadro, 6 quadros em linha (sheet de 240x26 px). Na tela, o sprite é esticado para a largura de 2 × raio do nível (de 120 a 170 px), com a altura em 62% da largura.
- **Prompt para o gerador de imagens (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D survival game, one horizontal row of 6 frames. Each frame is exactly 40x26 px, the full sheet is 240x26 px, with a transparent background, no text, no frame border and no blurred anti-aliasing. A dark green thorn ring: outer edge 3 px, with short thorns pointing outward from the edge, in dark moss and brown. The ring is drawn flattened like a floor ellipse (height about 62% of its width). Use only these colors: #1A6B26, #3E8A3E, #5C4A22, #0B2A10. Frame 1 is a small ring just appearing, the last frame is the ring almost at full size and faded, and the frames in between show steady growth. Clean hard-edged pixels with a one-pixel darker outline, consistent with a dark fantasy pixel style. Output exactly 240x26 px.

# Anel Lunar (anel_luar)
- **Resumo visual (2 linhas):** Um halo prateado, enorme e tênue, se abre ao redor do herói com brilho de lua e estrelas pequenas na borda. Some devagar, perto da borda da área.
- **Paleta:**
  - prateado #B2C7F2 (cor da arma)
  - azul-noite #1B2A4A (realce ou contorno)
  - branco #FFFFFF (realce ou contorno)
  - prata-escuro #6E7B99 (realce ou contorno)
- **Sprite:** 48x30 px por quadro, 6 quadros em linha (sheet de 288x30 px). Na tela, o sprite é esticado para a largura de 2 × raio do nível (de 220 a 220 px), com a altura em 62% da largura.
- **Prompt para o gerador de imagens (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D survival game, one horizontal row of 6 frames. Each frame is exactly 48x30 px, the full sheet is 288x30 px, with a transparent background, no text, no frame border and no blurred anti-aliasing. A huge faint silver moon-halo ring: thin outer edge, a soft pale blue outer glow, and tiny star points on the edge. The ring is drawn flattened like a floor ellipse (height about 62% of its width). Use only these colors: #B2C7F2, #1B2A4A, #FFFFFF, #6E7B99. Frame 1 is a small ring just appearing, the last frame is the ring almost at full size and faded, and the frames in between show steady growth. Clean hard-edged pixels with a one-pixel darker outline, consistent with a dark fantasy pixel style. Output exactly 288x30 px.

# Meteoro Flamejante (meteoro_flamejante)
- **Resumo visual (2 linhas):** Um meteoro de fogo com cauda laranja desce do alto da tela até um ponto no chão. No impacto, um estouro achatado laranja-avermelhado se espalha e some. O círculo de aviso no chão fica fora do sprite (o código desenha, porque o raio muda por nível).
- **Paleta:** laranja (cor da arma) #FF731A, vermelho #D92B1E, amarelo #FFD83A, branco quente #FFF4DC.
- **Sprite:** 32x32 px por quadro, 4 quadros em uma linha (sheet de 128x32 px). Quadros 1 e 2: voo. Quadros 3 e 4: impacto.
- **Prompt para gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D horde-survival game, clean and readable pixel art. One horizontal row of 4 frames, each frame exactly 32x32 px, total sheet exactly 128x32 px, transparent background, no text, no frame or border, no ground circle. Frames 1 and 2: a fiery meteor with a bright yellow-orange core and a short orange tail, coming straight down, tail length changes slightly between the two frames. Frames 3 and 4: a flattened ground explosion burst with an orange and red ring and a yellow-white core, frame 4 slightly wider and fading. Use only these colors: #FF731A, #D92B1E, #FFD83A, #FFF4DC. Keep each subject centered in its frame, crisp hard pixels, no anti-aliasing, no blur.

# Chuva de Pedras (chuva_pedras)
- **Resumo visual (2 linhas):** Pedras cinzentas caem do alto da tela em pontos perto de inimigos que estão perto do herói. Cada pedra some ao bater, deixando uma poeira curta no chão. O círculo de aviso no chão fica fora do sprite (o código desenha, porque o raio muda por nível).
- **Paleta:** marrom-pedra (cor da arma) #9E8566, cinza #7A7A80, areia #D9C48F, marrom escuro #5C4A36.
- **Sprite:** 16x16 px por quadro, 4 quadros em uma linha (sheet de 64x16 px). Quadros 1 e 2: voo. Quadros 3 e 4: impacto.
- **Prompt para gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D horde-survival game, clean and readable pixel art. One horizontal row of 4 frames, each frame exactly 16x16 px, total sheet exactly 64x16 px, transparent background, no text, no frame or border, no ground circle. Frames 1 and 2: a small grey-brown stone with a sandy highlight, tumbling slightly between the two frames. Frames 3 and 4: a small flattened dust puff in sand and brown tones, frame 4 larger and fading. Use only these colors: #9E8566, #7A7A80, #D9C48F, #5C4A36. Keep each subject centered in its frame, crisp hard pixels, no anti-aliasing, no blur.

# Cometa Gelado (cometa_gelado)
- **Resumo visual (2 linhas):** Um cometa azul-claro com cauda de cristais desce do alto da tela até um ponto no chão. Ao cair, espalha pequenos cristais brancos. O círculo de aviso no chão fica fora do sprite (o código desenha, porque o raio muda por nível).
- **Paleta:** azul gelo (cor da arma) #8CE6FF, azul claro #4FA3DB, branco #FFFFFF, azul escuro #2A5C8A.
- **Sprite:** 32x32 px por quadro, 4 quadros em uma linha (sheet de 128x32 px). Quadros 1 e 2: voo. Quadros 3 e 4: impacto.
- **Prompt para gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D horde-survival game, clean and readable pixel art. One horizontal row of 4 frames, each frame exactly 32x32 px, total sheet exactly 128x32 px, transparent background, no text, no frame or border, no ground circle. Frames 1 and 2: a light-blue comet with a tail of small crystals, coming straight down. Frames 3 and 4: a flattened burst of white ice crystals and light-blue shards, frame 4 wider and fading. Use only these colors: #8CE6FF, #4FA3DB, #FFFFFF, #2A5C8A. Keep each subject centered in its frame, crisp hard pixels, no anti-aliasing, no blur.

# Estrelas Cadentes (estrelas_cadentes)
- **Resumo visual (2 linhas):** Uma estrela amarela com rastro brilhante cai do alto da tela sobre um ponto perto do herói. No impacto, solta faíscas douradas no chão. O círculo de aviso no chão fica fora do sprite (o código desenha, porque o raio muda por nível).
- **Paleta:** amarelo (cor da arma) #FFF259, branco #FFFFFF, dourado #E0A526.
- **Sprite:** 24x24 px por quadro, 4 quadros em uma linha (sheet de 96x24 px). Quadros 1 e 2: voo. Quadros 3 e 4: impacto.
- **Prompt para gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D horde-survival game, clean and readable pixel art. One horizontal row of 4 frames, each frame exactly 24x24 px, total sheet exactly 96x24 px, transparent background, no text, no frame or border, no ground circle. Frames 1 and 2: a yellow four-point star with a bright short trail, coming straight down. Frames 3 and 4: a small flattened golden spark burst with a few white flecks, frame 4 fading. Use only these colors: #FFF259, #FFFFFF, #E0A526. Keep each subject centered in its frame, crisp hard pixels, no anti-aliasing, no blur.

# Cometa Negro (cometa_negro)
- **Resumo visual (2 linhas):** Um cometa roxo-escuro com cauda de fumaça e brilho violeta desce devagar até o chão. No impacto, uma onda de fumaça escura se espalha. O círculo de aviso no chão fica fora do sprite (o código desenha, porque o raio muda por nível).
- **Paleta:** roxo escuro (cor da arma) #591A73, violeta #8A3FC2, violeta claro #B98AE6, preto #140A1C.
- **Sprite:** 48x48 px por quadro, 4 quadros em uma linha (sheet de 192x48 px). Quadros 1 e 2: voo. Quadros 3 e 4: impacto.
- **Prompt para gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D horde-survival game, clean and readable pixel art. One horizontal row of 4 frames, each frame exactly 48x48 px, total sheet exactly 192x48 px, transparent background, no text, no frame or border, no ground circle. Frames 1 and 2: a dark purple comet with a smoky tail and a violet glow around the head, coming straight down. Frames 3 and 4: a flattened dark smoke burst with violet edges spreading outward, soft pixel clusters, frame 4 wider and fading. Use only these colors: #591A73, #8A3FC2, #B98AE6, #140A1C. Keep each subject centered in its frame, crisp hard pixels, no anti-aliasing, no blur.

# Fogo do Céu (fogo_do_ceu)
- **Resumo visual (2 linhas):** Uma coluna de fogo vermelho e amarelo desce do alto da tela e bate no chão em um ponto perto do herói. No impacto, uma chama curta sobe da base. O círculo de aviso no chão fica fora do sprite (o código desenha, porque o raio muda por nível).
- **Paleta:** vermelho (cor da arma) #F23340, amarelo #FFD83A, laranja #FF8C1A, vermelho escuro #8C1A22.
- **Sprite:** 24x80 px por quadro, 4 quadros em uma linha (sheet de 96x80 px). Quadros 1 e 2: voo. Quadros 3 e 4: impacto.
- **Prompt para gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D horde-survival game, clean and readable pixel art. One horizontal row of 4 frames, each frame exactly 24x80 px, total sheet exactly 96x80 px, transparent background, no text, no frame or border, no ground circle. Frames 1 and 2: a vertical column of red and yellow fire that fills the frame, flames flickering between the two frames, coming straight down. Frames 3 and 4: a flame burst at the base of a column, orange and yellow, flattened on the ground, frame 4 fading. Use only these colors: #F23340, #FFD83A, #FF8C1A, #8C1A22. Keep each subject centered in its frame, crisp hard pixels, no anti-aliasing, no blur.

# Pedras Vulcânicas (pedras_vulcanicas)
- **Resumo visual (2 linhas):** Uma pedra escura com brilho laranja cai do alto da tela em um ponto perto do herói. No impacto, um brilho laranja curto aparece no chão. O círculo de aviso no chão fica fora do sprite (o código desenha, porque o raio muda por nível).
- **Paleta:** marrom escuro #5A2A14, laranja #FF8C1A, vermelho escuro #7A1F14, brasa (cor da arma) #99331A.
- **Sprite:** 16x16 px por quadro, 4 quadros em uma linha (sheet de 64x16 px). Quadros 1 e 2: voo. Quadros 3 e 4: impacto.
- **Prompt para gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D horde-survival game, clean and readable pixel art. One horizontal row of 4 frames, each frame exactly 16x16 px, total sheet exactly 64x16 px, transparent background, no text, no frame or border, no ground circle. Frames 1 and 2: a dark brown volcanic rock with a glowing orange edge, coming straight down, slight rotation between the frames. Frames 3 and 4: a short flattened orange glow with a dark red ring, frame 4 fading. Use only these colors: #5A2A14, #FF8C1A, #7A1F14, #99331A. Keep each subject centered in its frame, crisp hard pixels, no anti-aliasing, no blur.

# Raio Meteórico (raio_meteorico)
- **Resumo visual (2 linhas):** Um meteoro elétrico azul-violeta com faíscas desce do céu até o chão. No impacto, um anel elétrico se espalha em volta do ponto de queda. O círculo de aviso no chão fica fora do sprite (o código desenha, porque o raio muda por nível).
- **Paleta:** azul elétrico (cor da arma) #6699FF, violeta #8A5CFF, branco #FFFFFF, azul escuro #2B3A8C.
- **Sprite:** 64x64 px por quadro, 4 quadros em uma linha (sheet de 256x64 px). Quadros 1 e 2: voo. Quadros 3 e 4: impacto.
- **Prompt para gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D horde-survival game, clean and readable pixel art. One horizontal row of 4 frames, each frame exactly 64x64 px, total sheet exactly 256x64 px, transparent background, no text, no frame or border, no ground circle. Frames 1 and 2: an electric blue-violet meteor with small white sparks and a zigzag trail, coming straight down, centered in the frame. Frames 3 and 4: a flattened electric ring of blue and white sparks spreading outward from the centre, frame 4 fainter. Use only these colors: #6699FF, #8A5CFF, #FFFFFF, #2B3A8C. Keep each subject centered in its frame, crisp hard pixels, no anti-aliasing, no blur.

# Chuva de Espinhos (chuva_espinhos)
- **Resumo visual (2 linhas):** Espinhos verdes e pontiagudos caem em rajadas curtas sobre pontos perto do herói. Cada um some ao bater, com uma poeira curta. O círculo de aviso no chão fica fora do sprite (o código desenha, porque o raio muda por nível).
- **Paleta:** verde (cor da arma) #80E64D, verde-limão #C4F03A, marrom #6B4A22, verde escuro #2E6B2A.
- **Sprite:** 16x16 px por quadro, 4 quadros em uma linha (sheet de 64x16 px). Quadros 1 e 2: voo. Quadros 3 e 4: impacto.
- **Prompt para gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D horde-survival game, clean and readable pixel art. One horizontal row of 4 frames, each frame exactly 16x16 px, total sheet exactly 64x16 px, transparent background, no text, no frame or border, no ground circle. Frames 1 and 2: a green pointed thorn, about 6 by 14 px, pointing down with a small lime highlight. Frames 3 and 4: a small flattened puff of green and brown dust dots, frame 4 fading. Use only these colors: #80E64D, #C4F03A, #6B4A22, #2E6B2A. Keep each subject centered in its frame, crisp hard pixels, no anti-aliasing, no blur.

# Lobo Espiritual (lobo_espirito)
- **Resumo visual (2 linhas):** Um lobo de espírito branco-azulado, meio transparente, que corre rente ao chão atrás do inimigo. Some em sopro de partículas ao fim da vida.
- **Paleta:** #E6F1FF branco-azulado; #B8D6FF azul da arma; #5B86B8 azul-sombra; #FFFFFF brilho.
- **Sprite:** 36x28 px por quadro, 4 quadros em linha (sheet de 144x28 px). Só a criatura: rastros, faíscas, névoa e poeira são efeitos à parte.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a translucent pale blue-white spirit wolf in a running pose, head forward, tail streaming, semi-transparent body with a faint glow, drawn in a top-down 2.5D style that matches a dark fantasy horde survival game (three-quarter overhead view, clean pixel edges, limited palette). Use only these colors: #E6F1FF, #B8D6FF, #5B86B8, #FFFFFF. Transparent background, no ground shadow, no effects, no text, no border. The sheet has 4 frames in one horizontal row, each frame exactly 36x28 pixels, total image 144x28 pixels. The 4 frames form one looping animation cycle, with the sprite centered in each frame.

# Espírito Raposa (espirito_raposa)
- **Resumo visual (2 linhas):** Uma raposa laranja de espírito, esguia e de cauda longa, que corre em direção ao inimigo. Some num estalo dourado ao fim da vida.
- **Paleta:** #FFA64D laranja da arma; #FFD966 amarelo-dourado; #FFFFFF ponta da cauda; #B3561A laranja-escuro.
- **Sprite:** 28x18 px por quadro, 4 quadros em linha (sheet de 112x18 px). Só a criatura: rastros, faíscas, névoa e poeira são efeitos à parte.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a slender orange spirit fox in a running pose, long bushy tail with a white tip, semi-transparent body, drawn in a top-down 2.5D style that matches a dark fantasy horde survival game (three-quarter overhead view, clean pixel edges, limited palette). Use only these colors: #FFA64D, #FFD966, #FFFFFF, #B3561A. Transparent background, no ground shadow, no effects, no text, no border. The sheet has 4 frames in one horizontal row, each frame exactly 28x18 pixels, total image 112x18 pixels. The 4 frames form one looping animation cycle, with the sprite centered in each frame.

# Guardião de Pedra (guardiao_pedra)
- **Resumo visual (2 linhas):** Um guardião humanoide de pedra cinza, com rachaduras e musgo, que anda pesado até o inimigo. Some no fim da vida, sem poeira no sprite.
- **Paleta:** #9EA3AD cinza pedra da arma; #6B6F78 cinza-escuro; #C9CDD4 cinza claro; #4F8A3C verde-musgo.
- **Sprite:** 44x52 px por quadro, 4 quadros em linha (sheet de 176x52 px). Só a criatura: rastros, faíscas, névoa e poeira são efeitos à parte.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a humanoid stone guardian made of grey rock, with cracks and green moss in the crevices, walking heavily, slightly hunched, drawn in a top-down 2.5D style that matches a dark fantasy horde survival game (three-quarter overhead view, clean pixel edges, limited palette). Use only these colors: #9EA3AD, #6B6F78, #C9CDD4, #4F8A3C. Transparent background, no ground shadow, no effects, no text, no border. The sheet has 4 frames in one horizontal row, each frame exactly 44x52 pixels, total image 176x52 pixels. The 4 frames form one looping animation cycle, with the sprite centered in each frame.

# Fantasma da Mata (fantasma_mata)
- **Resumo visual (2 linhas):** Um espírito verde-claro e meio transparente, de figura encapuzada, que flutua atrás do inimigo. Some no fim da vida, sem névoa no sprite.
- **Paleta:** #66FF80 verde-claro da arma; #3FA35A verde-musgo; #D9FFE0 branco translúcido; #1F5C32 contorno.
- **Sprite:** 24x34 px por quadro, 4 quadros em linha (sheet de 96x34 px). Só a criatura: rastros, faíscas, névoa e poeira são efeitos à parte.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a hooded green-tinted translucent ghost figure, floating, the cloak tapering into a wisp at the bottom, semi-transparent, drawn in a top-down 2.5D style that matches a dark fantasy horde survival game (three-quarter overhead view, clean pixel edges, limited palette). Use only these colors: #66FF80, #3FA35A, #D9FFE0, #1F5C32. Transparent background, no ground shadow, no effects, no text, no border. The sheet has 4 frames in one horizontal row, each frame exactly 24x34 pixels, total image 96x34 pixels. The 4 frames form one looping animation cycle, with the sprite centered in each frame.

# Serpente Ardente (serpente_ardente)
- **Resumo visual (2 linhas):** Uma serpente longa de fogo, com corpo ondulado e cabeça de brasa, que desliza até o inimigo. Some no fim da vida, sem rastro de chamas no sprite.
- **Paleta:** #FF730D laranja-vivo da arma; #D6330A vermelho-brasa; #FFD23F amarelo do centro; #5A1A05 contorno escuro.
- **Sprite:** 40x16 px por quadro, 4 quadros em linha (sheet de 160x16 px). Só a criatura: rastros, faíscas, névoa e poeira são efeitos à parte.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a long serpent made of fire, with a wavy body in an S-curve and an ember-red head, slithering pose, drawn in a top-down 2.5D style that matches a dark fantasy horde survival game (three-quarter overhead view, clean pixel edges, limited palette). Use only these colors: #FF730D, #D6330A, #FFD23F, #5A1A05. Transparent background, no ground shadow, no effects, no text, no border. The sheet has 4 frames in one horizontal row, each frame exactly 40x16 pixels, total image 160x16 pixels. The 4 frames form one looping animation cycle, with the sprite centered in each frame.

# Espírito Urso (espirito_urso)
- **Resumo visual (2 linhas):** Um urso marrom grande, de espírito, que avança sobre quatro patas contra o inimigo. Some no fim da vida, sem arco de terra no sprite.
- **Paleta:** #8C5926 marrom da arma; #5C3A18 marrom-escuro; #D9BF94 bege da barriga; #2B1A0B contorno.
- **Sprite:** 52x40 px por quadro, 4 quadros em linha (sheet de 208x40 px). Só a criatura: rastros, faíscas, névoa e poeira são efeitos à parte.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a large brown spirit bear, four-legged walking pose, semi-transparent, with a lighter beige belly, drawn in a top-down 2.5D style that matches a dark fantasy horde survival game (three-quarter overhead view, clean pixel edges, limited palette). Use only these colors: #8C5926, #5C3A18, #D9BF94, #2B1A0B. Transparent background, no ground shadow, no effects, no text, no border. The sheet has 4 frames in one horizontal row, each frame exactly 52x40 pixels, total image 208x40 pixels. The 4 frames form one looping animation cycle, with the sprite centered in each frame.

# Golem de Barro (golem_barro)
- **Resumo visual (2 linhas):** Um golem de barro marrom-avermelhado, com torrões que se soltam, que anda pesado até o inimigo. Some no fim da vida, sem torrões e respingo no sprite.
- **Paleta:** #BF6B52 barro avermelhado da arma; #7A3F2E barro escuro; #D9A679 terra clara; #4A2418 contorno.
- **Sprite:** 46x54 px por quadro, 4 quadros em linha (sheet de 184x54 px). Só a criatura: rastros, faíscas, névoa e poeira são efeitos à parte.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a clay golem made of reddish-brown mud, stocky body with a lumpy surface, walking heavily, drawn in a top-down 2.5D style that matches a dark fantasy horde survival game (three-quarter overhead view, clean pixel edges, limited palette). Use only these colors: #BF6B52, #7A3F2E, #D9A679, #4A2418. Transparent background, no ground shadow, no effects, no text, no border. The sheet has 4 frames in one horizontal row, each frame exactly 46x54 pixels, total image 184x54 pixels. The 4 frames form one looping animation cycle, with the sprite centered in each frame.

# Dragãozinho (dragao_filhote)
- **Resumo visual (2 linhas):** Um dragãozinho vermelho, de asas abertas e cauda curta, que voa rente ao chão até o inimigo. Some no fim da vida, sem sopro no sprite.
- **Paleta:** #E61F26 vermelho da arma; #8C0F14 vermelho-escuro; #FFB3B3 ventre claro; #3A0507 contorno.
- **Sprite:** 32x26 px por quadro, 4 quadros em linha (sheet de 128x26 px). Só a criatura: rastros, faíscas, névoa e poeira são efeitos à parte.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a small red baby dragon with wings spread and a short tail, low flying pose, drawn in a top-down 2.5D style that matches a dark fantasy horde survival game (three-quarter overhead view, clean pixel edges, limited palette). Use only these colors: #E61F26, #8C0F14, #FFB3B3, #3A0507. Transparent background, no ground shadow, no effects, no text, no border. The sheet has 4 frames in one horizontal row, each frame exactly 32x26 pixels, total image 128x26 pixels. The 4 frames form one looping animation cycle, with the sprite centered in each frame.

# Esqueleto Guerreiro (esqueleto_guerreiro)
- **Resumo visual (2 linhas):** Um esqueleto de ossos brancos-amarelados, com espada curta na mão, que corre até o inimigo. Some no fim da vida, sem nuvem de terra e sem arco de corte no sprite.
- **Paleta:** #F2EDD9 branco-osso da arma; #D8CDB0 bege; #8A8A85 cinza nos vãos dos ossos; #3B3A36 contorno e órbitas.
- **Sprite:** 30x44 px por quadro, 4 quadros em linha (sheet de 120x44 px). Só a criatura: rastros, faíscas, névoa e poeira são efeitos à parte.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet of a skeleton warrior with yellowish-white bones holding a short sword, running pose, drawn in a top-down 2.5D style that matches a dark fantasy horde survival game (three-quarter overhead view, clean pixel edges, limited palette). Use only these colors: #F2EDD9, #D8CDB0, #8A8A85, #3B3A36. Transparent background, no ground shadow, no effects, no text, no border. The sheet has 4 frames in one horizontal row, each frame exactly 30x44 pixels, total image 120x44 pixels. The 4 frames form one looping animation cycle, with the sprite centered in each frame.

## Fusões (9)

# Anel de Brasas (anel_de_brasas)
- **Resumo visual (2 linhas):** uma lâmina de brasa laranja, em forma de arco de chama, que gira em volta do herói num círculo achatado. Deixa um rastro de brilho quente atrás de si.
- **Paleta:**
  - Brasa (base): #FF8026
  - Brilho quente: #FFB988
  - Sombra de brasa: #592D0D
  - Núcleo branco: #FFFFFF
- **Sprite:** 26 x 11 px por quadro, 4 quadros em linha (sheet de 104 x 11 px). Os quadros são a mesma lâmina com a brasa piscando (o núcleo muda de intensidade).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. A single curved blade of glowing ember, shaped like a short arc of flame, with a bright white-hot core and orange edges, slightly tilted, like a spinning fire blade seen from above. Use these colors only: ember orange #FF8026, warm highlight #FFB988, dark ember shadow #592D0D, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 26 x 11 pixels, the whole sheet exactly 104 x 11 pixels, the core flickering a little from frame to frame. Transparent background, no text, no border, no frame, no ground shadow, no extra decoration. Clean pixel art with flat shading and a one-pixel dark outline, matching the style of the rest of the game.

# Revoada de Trovões (revoada_de_trovoes)
- **Resumo visual (2 linhas):** um corvo azul-elétrico com as asas batendo, que voa de um lado a outro e solta pequenas faíscas.
- **Paleta:**
  - Azul elétrico (base): #B2CCFF
  - Azul claro (brilho): #D5E3FF
  - Cinza-azulado (sombra e corpo): #3E4759
  - Branco (faísca): #FFFFFF
- **Sprite:** 22 x 18 px por quadro, 3 quadros em linha (sheet de 66 x 18 px). Quadro 1: asas para cima. Quadro 2: asas no meio. Quadro 3: asas para baixo.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. A small black crow with electric blue-white feathers, seen from above and slightly from the side, wings spread, with a few tiny sparks around it. Use these colors only: electric blue #B2CCFF, light blue highlight #D5E3FF, blue-grey shadow #3E4759, white spark #FFFFFF. Three frames in one horizontal row, each frame exactly 22 x 18 pixels, the whole sheet exactly 66 x 18 pixels: frame 1 wings raised, frame 2 wings level, frame 3 wings lowered. Transparent background, no text, no border, no frame, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the style of the rest of the game.

# Círculo Rúnico (circulo_runico)
- **Resumo visual (2 linhas):** um glifo de runa ciano que fica parado no chão e pulsa; ao explodir, abre um anel de luz que cresce.
- **Paleta:**
  - Ciano da runa (base): #8CFFF2
  - Brilho ciano: #C0FFF8
  - Sombra de runa (contorno do chão): #315955
  - Branco (centro do glifo): #FFFFFF
- **Sprite:** 64 x 64 px por quadro, 4 quadros em linha (sheet de 256 x 64 px). Os quadros são o glifo com a luz pulsando de 70% a 100%.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. A round rune circle lying flat on the ground, cyan glowing runic glyphs arranged in a ring around a small white center, seen from above. Use these colors only: rune cyan #8CFFF2, bright cyan highlight #C0FFF8, dark teal shadow #315955, white center #FFFFFF. Four frames in one horizontal row, each frame exactly 64 x 64 pixels, the whole sheet exactly 256 x 64 pixels, the glow pulsing slightly from frame to frame. Transparent background, no text, no border, no frame. Clean pixel art with flat shading and a one-pixel dark outline, matching the style of the rest of the game.

# Ventania Cortante (ventania)
- **Resumo visual (2 linhas):** um arco de vento branco-esverdeado, largo e curvo, que corre reto pelo chão com uma cauda de vento atrás.
- **Paleta:**
  - Vento (base): #CCFFF2
  - Brilho do vento: #E3FFF8
  - Sombra do vento: #475955
  - Branco (núcleo do arco): #FFFFFF
- **Sprite:** 64 x 32 px por quadro, 4 quadros em linha (sheet de 256 x 32 px). Os quadros são o arco com a cauda se desfazendo (o arco fica um pouco mais fino a cada quadro).
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. A wide curved arc of pale cyan-white wind, like a sword slash made of air, with three thin trailing lines behind it, seen from above. Use these colors only: wind cyan-white #CCFFF2, bright highlight #E3FFF8, dark green-grey shadow #475955, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 64 x 32 pixels, the whole sheet exactly 256 x 32 pixels, the trailing lines fading a little more from frame to frame. Transparent background, no text, no border, no frame, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the style of the rest of the game.

# Dragão de Brasa (dragao_de_brasa)
- **Resumo visual (2 linhas):** um espírito de brasa, uma bola de fogo com cauda curta e faíscas, que voa até o inimigo e balança no ar.
- **Paleta:**
  - Brasa (base): #FF731A
  - Brilho quente: #FFB281
  - Sombra de brasa: #592809
  - Núcleo branco: #FFFFFF
- **Sprite:** 24 x 24 px por quadro, 4 quadros em linha (sheet de 96 x 24 px). Os quadros mostram a chama tremendo e a cauda se mexendo.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. A small floating spirit made of ember and fire, a round glowing head with a short flame tail trailing behind, seen from above and slightly from the side. Use these colors only: ember orange #FF731A, warm highlight #FFB281, dark ember shadow #592809, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 24 x 24 pixels, the whole sheet exactly 96 x 24 pixels, the flame tail moving from frame to frame. Transparent background, no text, no border, no frame, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the style of the rest of the game.

# Caçada Espiritual (cacada_espiritual)
- **Resumo visual (2 linhas):** um espírito azul-gelo esguio, com a ponta da cauda alaranjada, que corre reto deixando um rastro de brilho frio.
- **Paleta:**
  - Azul gelo (base): #99D9FF
  - Brilho gelado: #C7EAFF
  - Sombra azul-escura: #364C59
  - Laranja da raposa (ponta): #FFA64D
- **Sprite:** 28 x 20 px por quadro, 4 quadros em linha (sheet de 112 x 20 px). Os quadros são a passada: as patas se alternam e a cauda balança.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. A translucent spirit hunter, a slim wolf-and-fox shape made of icy blue light, with an orange-tipped tail, running forward, seen from above and slightly from the side. Use these colors only: ice blue #99D9FF, pale ice highlight #C7EAFF, dark blue shadow #364C59, fox orange tip #FFA64D. Four frames in one horizontal row, each frame exactly 28 x 20 pixels, the whole sheet exactly 112 x 20 pixels, the legs alternating in a running cycle. Transparent background, no text, no border, no frame, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the style of the rest of the game.

# Urso Solar (urso_solar)
- **Resumo visual (2 linhas):** um feixe dourado e alongado que voa reto, com um brilho mais forte na ponta.
- **Paleta:**
  - Dourado (base): #FFD959
  - Brilho dourado: #FFEAA4
  - Sombra dourada: #594C1F
  - Núcleo branco: #FFFFFF
- **Sprite:** 24 x 12 px por quadro, 3 quadros em linha (sheet de 72 x 12 px). Os quadros são o feixe com o brilho pulsando.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. A narrow golden beam of solar light, a long glowing streak with a bright white tip and a soft golden tail, pointing to the right, seen from above. Use these colors only: gold #FFD959, pale gold highlight #FFEAA4, dark gold shadow #594C1F, white tip #FFFFFF. Three frames in one horizontal row, each frame exactly 24 x 12 pixels, the whole sheet exactly 72 x 12 pixels, the tip glowing a little stronger from frame to frame. Transparent background, no text, no border, no frame, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the style of the rest of the game.

# Exército Esquecido (exercito_esquecido)
- **Resumo visual (2 linhas):** um espírito ósseo e pálido, meio esqueleto e meio fantasma, com um toque verde; anda reto e fica translúcido perto do fim.
- **Paleta:**
  - Osso (base): #D9D9CC
  - Brilho de osso: #EAEAE3
  - Sombra entre os ossos: #4C4C47
  - Verde fantasma: #66FF80
- **Sprite:** 24 x 28 px por quadro, 4 quadros em linha (sheet de 96 x 28 px). Os quadros são a passada do espírito, com o toque verde pulsando.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. A pale humanoid spirit, half skeleton and half ghost, bone-white with a faint green glow around the ribs and hands, a small short blade in one hand, seen from above and slightly from the side. Use these colors only: bone #D9D9CC, pale bone highlight #EAEAE3, dark bone-grey shadow #4C4C47, ghost green #66FF80. Four frames in one horizontal row, each frame exactly 24 x 28 pixels, the whole sheet exactly 96 x 28 pixels, the legs alternating in a walking cycle. Transparent background, no text, no border, no frame, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the style of the rest of the game.

# Colosso de Pedra (colosso_de_pedra)
- **Resumo visual (2 linhas):** um colosso grande de pedra e barro, com torrões caindo a cada passo; anda devagar e pesado.
- **Paleta:**
  - Barro (base): #BF9966
  - Brilho de barro: #DCC7AB
  - Sombra de barro: #433624
  - Pedra cinza (rachaduras e ombros): #9EA3AD
- **Sprite:** 48 x 56 px por quadro, 4 quadros em linha (sheet de 192 x 56 px). Os quadros são a passada: a perna da frente sobe e desce e os torrões se soltam.
- **Prompt para o gerador de imagem (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. A heavy colossus built from clay and grey stone, a broad body with cracks, small chunks of clay falling from its shoulders, seen from above and slightly from the side. Use these colors only: clay #BF9966, pale clay highlight #DCC7AB, dark clay shadow #433624, grey stone #9EA3AD. Four frames in one horizontal row, each frame exactly 48 x 56 pixels, the whole sheet exactly 192 x 56 pixels, the legs alternating in a slow stomping cycle. Transparent background, no text, no border, no frame, no ground dust. Clean pixel art with flat shading and a one-pixel dark outline, matching the style of the rest of the game.



## Fusões novas (16): comuns, raras e lendárias

Estas fusões entraram no código depois da lista acima. Lendárias têm mecânica própria; o gerador de sprite só precisa do efeito visual.

# Chuva de Lâminas (chuva_de_lacas)
- **Tipo e raridade:** Projétil, Comum (fusão de 2 peças: flechas_sombrias (nível 3), adagas_voadoras (nível 3)).
- **Resumo visual (2 linhas):** Três lâminas voam de uma vez no inimigo mais perto.
- **Paleta:**
  - Cor principal: #BFE6FF
  - Brilho: #D9F0FF
  - Sombra: #4D5C66
  - Núcleo branco: #FFFFFF
- **Sprite:** 14 x 6 px por quadro, 4 quadros em linha (sheet de 56 x 6 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a small glowing arrow or shard, pointing right, themed as: Três lâminas voam de uma vez no inimigo mais perto.. Use these colors only: main #BFE6FF, highlight #D9F0FF, dark shadow #4D5C66, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 14 x 6 pixels, the whole sheet exactly 56 x 6 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Bola Incendiária (bola_incendiaria)
- **Tipo e raridade:** Projétil, Comum (fusão de 2 peças: bola_fogo (nível 3), bolas_chumbo (nível 3)).
- **Resumo visual (2 linhas):** Projéteis pesados explodem ao cair e ferem quem está perto.
- **Paleta:**
  - Cor principal: #FF8C33
  - Brilho: #FFBA85
  - Sombra: #663814
  - Núcleo branco: #FFFFFF
- **Sprite:** 14 x 6 px por quadro, 4 quadros em linha (sheet de 56 x 6 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a small glowing arrow or shard, pointing right, themed as: Projéteis pesados explodem ao cair e ferem quem está perto.. Use these colors only: main #FF8C33, highlight #FFBA85, dark shadow #663814, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 14 x 6 pixels, the whole sheet exactly 56 x 6 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Nevasca Congelante (nevasca_congelante)
- **Tipo e raridade:** Nuvem, Comum (fusão de 2 peças: nevoeiro_gelado (nível 3), nevasca (nível 3)).
- **Resumo visual (2 linhas):** Uma nevasca larga desacelera quem fica dentro dela.
- **Paleta:**
  - Cor principal: #99E6FF
  - Brilho: #C2F0FF
  - Sombra: #3D5C66
  - Núcleo branco: #FFFFFF
- **Sprite:** 48 x 48 px por quadro, 4 quadros em linha (sheet de 192 x 48 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a soft swirling cloud or mist puff seen from above, themed as: Uma nevasca larga desacelera quem fica dentro dela.. Use these colors only: main #99E6FF, highlight #C2F0FF, dark shadow #3D5C66, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 48 x 48 pixels, the whole sheet exactly 192 x 48 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Cinzas Ácidas (cinzas_acidas)
- **Tipo e raridade:** Nuvem, Comum (fusão de 2 peças: cinzas_vulcanicas (nível 3), chuva_acida (nível 3)).
- **Resumo visual (2 linhas):** Uma nuvem de cinza ácida cai perto do herói e corrói os inimigos.
- **Paleta:**
  - Cor principal: #B2CC4C
  - Brilho: #ECFF9F
  - Sombra: #47521F
  - Núcleo branco: #FFFFFF
- **Sprite:** 48 x 48 px por quadro, 4 quadros em linha (sheet de 192 x 48 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a soft swirling cloud or mist puff seen from above, themed as: Uma nuvem de cinza ácida cai perto do herói e corrói os inimigos.. Use these colors only: main #B2CC4C, highlight #ECFF9F, dark shadow #47521F, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 48 x 48 pixels, the whole sheet exactly 192 x 48 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Estrondo (estrondo)
- **Tipo e raridade:** Anel, Comum (fusão de 2 peças: onda_choque (nível 3), grito_guerra (nível 3)).
- **Resumo visual (2 linhas):** Um grito de guerra em onda empurra tudo com força.
- **Paleta:**
  - Cor principal: #FFCC80
  - Brilho: #FFE0B2
  - Sombra: #665233
  - Núcleo branco: #FFFFFF
- **Sprite:** 64 x 64 px por quadro, 4 quadros em linha (sheet de 256 x 64 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is an expanding ring of energy seen from above, themed as: Um grito de guerra em onda empurra tudo com força.. Use these colors only: main #FFCC80, highlight #FFE0B2, dark shadow #665233, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 64 x 64 pixels, the whole sheet exactly 256 x 64 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Terra Partida (terra_partida)
- **Tipo e raridade:** Anel, Comum (fusão de 2 peças: terremoto (nível 3), martelo_trovao (nível 3)).
- **Resumo visual (2 linhas):** O chão racha em anéis que levantam os inimigos.
- **Paleta:**
  - Cor principal: #D99959
  - Brilho: #FFD2A5
  - Sombra: #573D24
  - Núcleo branco: #FFFFFF
- **Sprite:** 64 x 64 px por quadro, 4 quadros em linha (sheet de 256 x 64 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is an expanding ring of energy seen from above, themed as: O chão racha em anéis que levantam os inimigos.. Use these colors only: main #D99959, highlight #FFD2A5, dark shadow #573D24, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 64 x 64 pixels, the whole sheet exactly 256 x 64 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Pedreira Ardente (pedreira_ardente)
- **Tipo e raridade:** Meteoro, Comum (fusão de 2 peças: chuva_pedras (nível 3), pedras_vulcanicas (nível 3)).
- **Resumo visual (2 linhas):** Quatro pedras em brasa caem em volta do herói.
- **Paleta:**
  - Cor principal: #FF7333
  - Brilho: #FFAB85
  - Sombra: #662E14
  - Núcleo branco: #FFFFFF
- **Sprite:** 24 x 24 px por quadro, 4 quadros em linha (sheet de 96 x 24 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a burning rock or comet head with a short fiery tail, themed as: Quatro pedras em brasa caem em volta do herói.. Use these colors only: main #FF7333, highlight #FFAB85, dark shadow #662E14, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 24 x 24 pixels, the whole sheet exactly 96 x 24 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Cometa Duplo (cometa_duplo)
- **Tipo e raridade:** Meteoro, Comum (fusão de 2 peças: cometa_gelado (nível 3), estrelas_cadentes (nível 3)).
- **Resumo visual (2 linhas):** Dois cometas caem juntos sobre inimigos próximos.
- **Paleta:**
  - Cor principal: #B2E6FF
  - Brilho: #D1F0FF
  - Sombra: #475C66
  - Núcleo branco: #FFFFFF
- **Sprite:** 24 x 24 px por quadro, 4 quadros em linha (sheet de 96 x 24 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a burning rock or comet head with a short fiery tail, themed as: Dois cometas caem juntos sobre inimigos próximos.. Use these colors only: main #B2E6FF, highlight #D1F0FF, dark shadow #475C66, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 24 x 24 pixels, the whole sheet exactly 96 x 24 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Chuva de Ferro (chuva_de_ferro)
- **Tipo e raridade:** Projétil, Rara (fusão de 3 peças: bumerangue_ferro (nível 3), rajada_vento (nível 3), meteoro_flamejante (nível 3)).
- **Resumo visual (2 linhas):** Projéteis de ferro atravessam inimigos e explodem no fim.
- **Paleta:**
  - Cor principal: #B2B2CC
  - Brilho: #ECECFF
  - Sombra: #474752
  - Núcleo branco: #FFFFFF
- **Sprite:** 14 x 6 px por quadro, 4 quadros em linha (sheet de 56 x 6 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a small glowing arrow or shard, pointing right, themed as: Projéteis de ferro atravessam inimigos e explodem no fim.. Use these colors only: main #B2B2CC, highlight #ECECFF, dark shadow #474752, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 14 x 6 pixels, the whole sheet exactly 56 x 6 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Peste Negra (peste_negra)
- **Tipo e raridade:** Nuvem, Rara (fusão de 3 peças: dardos_peconhentos (nível 3), nuvem_veneno (nível 3), fumaca_sonolenta (nível 3)).
- **Resumo visual (2 linhas):** Uma névoa de peçonha se espalha e não sai de perto do herói.
- **Paleta:**
  - Cor principal: #66CC4C
  - Brilho: #B3FF9F
  - Sombra: #29521F
  - Núcleo branco: #FFFFFF
- **Sprite:** 48 x 48 px por quadro, 4 quadros em linha (sheet de 192 x 48 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a soft swirling cloud or mist puff seen from above, themed as: Uma névoa de peçonha se espalha e não sai de perto do herói.. Use these colors only: main #66CC4C, highlight #B3FF9F, dark shadow #29521F, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 48 x 48 pixels, the whole sheet exactly 192 x 48 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Juramento Sagrado (juramento_sagrado)
- **Tipo e raridade:** Anel, Rara (fusão de 3 peças: anel_espinhos (nível 3), pulso_sagrado (nível 3), nevoa_espectral (nível 3)).
- **Resumo visual (2 linhas):** Anéis sagrados se abrem e sopram os inimigos para longe.
- **Paleta:**
  - Cor principal: #FFF2B2
  - Brilho: #FFF7D1
  - Sombra: #666147
  - Núcleo branco: #FFFFFF
- **Sprite:** 64 x 64 px por quadro, 4 quadros em linha (sheet de 256 x 64 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is an expanding ring of energy seen from above, themed as: Anéis sagrados se abrem e sopram os inimigos para longe.. Use these colors only: main #FFF2B2, highlight #FFF7D1, dark shadow #666147, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 64 x 64 pixels, the whole sheet exactly 256 x 64 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Eclipse Negro (eclipse_negro)
- **Tipo e raridade:** Meteoro, Rara (fusão de 3 peças: cometa_negro (nível 3), fogo_do_ceu (nível 3), cortina_sangue (nível 3)).
- **Resumo visual (2 linhas):** Dois cometas negros e uma cortina de sangue caem sem trégua.
- **Paleta:**
  - Cor principal: #733380
  - Brilho: #C083CC
  - Sombra: #2E1433
  - Núcleo branco: #FFFFFF
- **Sprite:** 24 x 24 px por quadro, 4 quadros em linha (sheet de 96 x 24 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a burning rock or comet head with a short fiery tail, themed as: Dois cometas negros e uma cortina de sangue caem sem trégua.. Use these colors only: main #733380, highlight #C083CC, dark shadow #2E1433, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 24 x 24 pixels, the whole sheet exactly 96 x 24 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.

# Tempestade Primordial (tempestade_primordial)
- **Tipo e raridade:** Projétil, Lendária (fusão de 4 peças: lanca_geada (nível 5), estrelas_sombra (nível 5), bumerangue_ferro (nível 5), raio_solar (nível 5)).
- **Resumo visual (2 linhas):** Lanças e pedras perfuram; cada impacto puxa os inimigos para o ponto.
- **Paleta:**
  - Cor principal: #FFFF99
  - Brilho: #FFFFC2
  - Sombra: #66663D
  - Núcleo branco: #FFFFFF
- **Sprite:** 14 x 6 px por quadro, 4 quadros em linha (sheet de 56 x 6 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a small glowing arrow or shard, pointing right, themed as: Lanças e pedras perfuram; cada impacto puxa os inimigos para o ponto.. Use these colors only: main #FFFF99, highlight #FFFFC2, dark shadow #66663D, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 14 x 6 pixels, the whole sheet exactly 56 x 6 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.
- **Animação extra (lendária):** a carta ganha borda e rodapé magenta (#FF73D9). O efeito em si é o mesmo tamanho; o brilho em volta pode ser um pouco mais forte.

# Eclipse de Almas (eclipse_de_almas)
- **Tipo e raridade:** Aliado, Lendária (fusão de 4 peças: lobo_espirito (nível 5), espirito_raposa (nível 5), fantasma_mata (nível 5), espirito_urso (nível 5)).
- **Resumo visual (2 linhas):** Espíritos prendem o inimigo; quem já está preso leva dano em dobro.
- **Paleta:**
  - Cor principal: #B280FF
  - Brilho: #D1B2FF
  - Sombra: #473366
  - Núcleo branco: #FFFFFF
- **Sprite:** 20 x 24 px por quadro, 4 quadros em linha (sheet de 80 x 24 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a small spirit creature standing upright, themed as: Espíritos prendem o inimigo; quem já está preso leva dano em dobro.. Use these colors only: main #B280FF, highlight #D1B2FF, dark shadow #473366, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 20 x 24 pixels, the whole sheet exactly 80 x 24 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.
- **Animação extra (lendária):** a carta ganha borda e rodapé magenta (#FF73D9). O efeito em si é o mesmo tamanho; o brilho em volta pode ser um pouco mais forte.

# Juízo Final (juizo_final)
- **Tipo e raridade:** Meteoro, Lendária (fusão de 4 peças: cometa_negro (nível 5), fogo_do_ceu (nível 5), meteoro_flamejante (nível 5), raio_meteorico (nível 5)).
- **Resumo visual (2 linhas):** Cada meteoro que cai chama outro sobre o inimigo mais perto.
- **Paleta:**
  - Cor principal: #FF4C1A
  - Brilho: #FF9475
  - Sombra: #661F0A
  - Núcleo branco: #FFFFFF
- **Sprite:** 24 x 24 px por quadro, 4 quadros em linha (sheet de 96 x 24 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a burning rock or comet head with a short fiery tail, themed as: Cada meteoro que cai chama outro sobre o inimigo mais perto.. Use these colors only: main #FF4C1A, highlight #FF9475, dark shadow #661F0A, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 24 x 24 pixels, the whole sheet exactly 96 x 24 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.
- **Animação extra (lendária):** a carta ganha borda e rodapé magenta (#FF73D9). O efeito em si é o mesmo tamanho; o brilho em volta pode ser um pouco mais forte.

# Furacão Glacial (furacao_glacial)
- **Tipo e raridade:** Nuvem, Lendária (fusão de 4 peças: nevasca (nível 5), nevoeiro_gelado (nível 5), anel_gelado (nível 5), lanca_geada (nível 5)).
- **Resumo visual (2 linhas):** Nuvem gelada; inimigos lentos dentro dela levam dano em dobro.
- **Paleta:**
  - Cor principal: #80F2FF
  - Brilho: #B2F7FF
  - Sombra: #336166
  - Núcleo branco: #FFFFFF
- **Sprite:** 48 x 48 px por quadro, 4 quadros em linha (sheet de 192 x 48 px).
- **Prompt para o GPT (em inglês, pronto para colar):** Pixel art sprite sheet for a top-down 2.5D dark fantasy survival game. The effect is a soft swirling cloud or mist puff seen from above, themed as: Nuvem gelada; inimigos lentos dentro dela levam dano em dobro.. Use these colors only: main #80F2FF, highlight #B2F7FF, dark shadow #336166, white core #FFFFFF. Four frames in one horizontal row, each frame exactly 48 x 48 pixels, the whole sheet exactly 192 x 48 pixels, the effect pulsing slightly from frame to frame. Transparent background, no text, no border, no ground shadow. Clean pixel art with flat shading and a one-pixel dark outline, matching the rest of the game.
- **Animação extra (lendária):** a carta ganha borda e rodapé magenta (#FF73D9). O efeito em si é o mesmo tamanho; o brilho em volta pode ser um pouco mais forte.
