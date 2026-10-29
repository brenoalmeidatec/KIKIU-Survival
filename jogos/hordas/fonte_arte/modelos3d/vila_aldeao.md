# Aldeão morto-vivo da Vila

Modelo próprio em `vila_aldeao.py`: corpo ereto, camisa de tecido rasgado,
calças e botas, braços assimétricos e mandíbula caída. Frente em -Y,
escala e materiais compartilhados com o pipeline da v2; sem arte externa.

Gerar com Blender 4.5, a partir da raiz do repositório:

```text
blender -b -P jogos/hordas/prototipos/cara_nova/gerar_cara_nova.py -- monstro vila_aldeao aldeao_morto
```

Saída: `projeto/prototipos/cara_nova/sprites/inimigo_aldeao_morto*`,
cinco vistas por quatro quadros, albedo, normal e emissão dos olhos.
O jogo espelha as vistas para oito direções. `v2_elencos.json` liga somente
`cidade/aldeao_morto`; os números de combate são os do antigo cão de ossos.
O teste `v2_aldeao_vila` confere folhas, atlas, elenco, oito direções e
esgotamento/reutilização de todos os nós pré-criados do pool.

O pool tem 64 nós. O pico medido foi 39 em duas execuções de estresse da
Vila no Difícil + Pesadelo, com robô imortal (semente 1 com Q e 7 sem Q).
O teste exige pelo menos 25% de folga sobre esse pico e prova a reutilização
dos 64 nós. É margem sobre amostras, não garantia para toda semente ou build;
reavaliar ao mudar o elenco, os invocadores ou a densidade do diretor.
