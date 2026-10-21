# Heróis do Blender integrados (Hazaki, Matheus, Lucas, Nicão), 21/10/2026

Fotos reais (janela do jogo, 1280x720, perfil padrão) tiradas com `jogos/hordas/projeto/testes/fotos/herois_fotos.gd`:

- `hud_retrato_4_herois.png`: o retrato do HUD na partida. Em cima Hazaki e Matheus, embaixo Lucas e Nicão: todos centrados na moldura de 90x108, escala inteira (2x), sem passar da borda.
- `salao_4_herois_parado_e_andando.png`: o Santuário, de cada herói parado (esquerda) e andando (direita), com a folha do personagem (Matheus) ou a do herói (Hazaki, Lucas, Nicão).
- `escolha_personagem_4_herois.png`: a escolha de personagem sem `rosto.png`: o quadro parado da folha do personagem, não mais sempre o do Hazaki.

Como refazer: `godot --path jogos/hordas/projeto --position -3000,0 res://testes/fotos/herois_fotos.tscn -- --fotos=PASTA`.
