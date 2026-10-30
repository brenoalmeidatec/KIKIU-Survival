# Homúnculo da Torre

Modelo próprio em `jogos/hordas/fonte_arte/modelos3d/torre_homunculo.py`: cabeça grande, abdome costurado, braços assimétricos e frasco nas costas. Geração pelo pipeline existente:

```text
blender -b -P jogos/hordas/prototipos/cara_nova/gerar_cara_nova.py -- monstro torre_homunculo homunculo
```

São cinco vistas e quatro quadros por vista, com espelho para oito direções. Albedo, normal e emissão usam o mesmo quadro de 34×42 e pé na linha 40. Vidro do frasco é sugerido por cor, sem alterar o modo de mistura da horda.

Somente `laboratorio/homunculo` usa a folha. Vida, dano, XP, velocidade, raio, peso e orbes continuam os da aranha substituída; pesos, tinta e multiplicadores do elenco também permanecem iguais. O sorteio padrão não inclui o homúnculo.

O pool pré-cria 192 instâncias. O teste exige um piso conservador calculado pelos dados: 164 do teto máximo do diretor +2 elites e 12 filhos de duas invocadoras =178, com 14 vagas de reserva. Esse piso não é um limite global: filhos de elites mortas podem persistir. A prova dirigida esgota as 192 instâncias e recicla sem criar nós. Um estresse na Torre, Difícil, semente 1, com Q, imortalidade e Pesadelo ativado pelo helper no primeiro quadro, mediu pico de 41 homúnculos vivos em 59.925 amostras até 880,8 segundos de jogo. É uma amostra, não garantia para toda trajetória nem avaliação de equilíbrio. Pré-criação ainda segue o mecanismo global existente; FPS e custo de abertura no i5-3470 não foram medidos.

`v2_homunculo_torre` verifica registro exclusivo, números, quadros, atlas, oito direções e reciclagem. `-- --fotos=PASTA_EXTERNA` captura uma cena controlada em janela real; não representa partida completa.
