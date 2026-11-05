# Bola da explosão do mecha (Q do LightWolf, rodada 7)

Arte própria, procedural (sem Blender, sem imagem de terceiros): `gerar_bola.py` desenha os 36 quadros da bola em numpy, quantizados na paleta do mecha (7 cores, alfa 0/1), e grava `jogos/hordas/projeto/assets/v2/efeitos/lw_q_bola.png` (grade 6x6 de 203x237 px).

```
python jogos/hordas/fonte_arte/explosao_lw_q/gerar_bola.py [--folha_contato saida.png]   # ~5 s; a folha de contato sai x3 NEAREST
```

O script lê `dados/v2_especial.json > autodestruicao.explosao` (raio `bola` e o bloco `folha`: quadros, colunas, célula, centro, duração e pesos). O jogo usa os mesmos `pesos` para o tempo de cada quadro (v2/explosao_mecha.gd), então mudar pesos ou quadros pede gerar de novo. Fases: estalo branco com 12 raios (1 quadro, segurado pelo hit-stop), chicotes (3), cúpula em duas camadas defasadas com arcos elétricos que mudam a cada 2 quadros e anel de choque no ar que ondula e quebra em arcos (10), pico com o miolo que abre em anel e puffs de fumaça (10), dissipação em fumaça que esfarela por máscara fixa, com cauda lenta (12).
