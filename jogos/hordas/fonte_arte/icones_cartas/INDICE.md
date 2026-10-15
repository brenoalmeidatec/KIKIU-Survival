# Índice das fontes de ícones das cartas

Inventário inicial em main 77fa330; folha 09 baseada na main 51ab6aa, após as quatro cartas do #242. Inclui todas as 90 entradas de v2_cartas.json nessas bases, inclusive cartas ocultas. Não altera regras nem faz recorte ou integração.

Total com a folha 09: **94 motivos**: 50 golpes, 25 evoluções/fusões, 7 stats, 8 modificadores, katana principal, escudo secundário, E Ruptura e selo Q reservado. São 93 motivos de conteúdo e 1 placeholder sem habilidade publicada. O Dragão Cobalto de habilidades.json pertence ao sistema legado; não é a Q atual da v2 e não entra neste lote.

Referências lidas: dados/v2_cartas.json, dados/v2_secundario.json, dados/v2_ruptura.json, dados/habilidades.json, v2/heroi.gd, v2/cartas.gd, v2/telas.gd, v2/status.gd e v2/hud_habilidades.gd. Os cartões de escolha usam o campo icone; as evoluções atualmente reutilizam no HUD o ícone da primeira peça consumida. As fontes abaixo dão identidade própria a cada ID, sem mudar essa ligação.

Especificação comum: pixel art 2.5D top-down dark fantasy no estilo do jogo; silhueta legível em tamanho pequeno; materiais e luz coerentes com a referência. Cada folha: **4 colunas × 3 linhas**, fundo branco puro, sem texto/letras/números, sem grade visível, sem moldura, motivos centralizados e separados com margem ampla, nada cruzando células. Ordem de leitura esquerda para direita, de cima para baixo. As últimas seis células da folha 08 ficam brancas. Descritores em inglês são instruções visuais, não textos a desenhar.

Não são sprites de ataque ou animação de gameplay. Fusões entram como ícones de carta; não substituem qualquer reserva de sprites de fusões do Breno. Os IDs são preservados literalmente (inclusive chuva_de_lacas).

## Folha 01 — fonte prevista: folha_01.png

| Célula | Categoria / ID | Nome e descrição | Ícone atual | Visual descriptor |
|---|---|---|---|---|
| 1 | stat / dano | **Lâmina afiada** — +valor% de dano | icone_katana | Sharpened katana edge with a tiny whetstone and cold silver glint |
| 2 | stat / vel_ataque | **Punho ligeiro** — +valor% de velocidade de ataque | icone_overclock | Clenched leather gauntlet surrounded by short rapid silver slash trails |
| 3 | stat / area | **Arco largo** — +valor% de área do corte | icone_ciclone | Single wide silver crescent slash with an unusually broad sweeping arc |
| 4 | stat / vel_mov | **Pés de vento** — +valor% de velocidade de movimento | icone_botas_guerra | Pair of dark boots lifted by curling pale green wind |
| 5 | stat / vida | **Alma robusta** — +valor de vida máxima e cura | icone_vida | Stout crimson soul flame inside a protective heart silhouette |
| 6 | stat / ima | **Ímã de almas** — +valor% de alcance para pegar almas | icone_pedra_ima | Horseshoe lodestone attracting a cluster of cyan soul wisps |
| 7 | stat / critico | **Olho de falcão** — +valor% de chance de crítico | icone_olho_falcao | Amber falcon eye with sharp dark feathers and a bright pinpoint pupil |
| 8 | golpe / laminas | **Lâminas Rodopiantes** — Duas lâminas giram em volta e cortam quem encosta. | icone_laminas | Two curved silver blades orbiting an empty center on pale blue trails |
| 9 | golpe / aura_fogo | **Aura de Fogo** — Círculo de fogo: queima e empurra quem chega perto. | icone_brasa_viva | Compact orange fire ring with outward licking flames |
| 10 | golpe / corvos | **Corvos Famintos** — Corvos caçam o inimigo mais perto e bicam sozinhos. | icone_corvos | Two hungry black ravens diving with open beaks and violet highlights |
| 11 | golpe / raio | **Raio em Cadeia** — Raio no inimigo mais perto, que pula para vizinhos. | icone_raio | Forked blue lightning jumping between separate dark stones |
| 12 | golpe / runa | **Runa Explosiva** — Runas no chão. Explodem quando um inimigo pisa. | icone_runas | Carved ground rune bursting into orange fragments |

## Folha 02 — fonte prevista: folha_02.png

| Célula | Categoria / ID | Nome e descrição | Ícone atual | Visual descriptor |
|---|---|---|---|---|
| 1 | golpe / flechas_sombrias | **Flechas Sombrias** — Dispara flechas roxas rápidas no inimigo mais perto, em linha reta. | icone_u_arco_sussurro | Three sleek violet arrows flying straight in parallel shadow trails |
| 2 | golpe / adagas_voadoras | **Adagas Voadoras** — Atira adagas de aço em leque curto no inimigo mais perto, sem parar. | icone_u_adaga_sombria | Steel throwing daggers spread in a short forward fan |
| 3 | golpe / lanca_geada | **Lança de Geada** — Arremessa lança de gelo no inimigo mais perto a cada poucos segundos. | icone_u_lanca_cacada | Long translucent ice spear with a blue frozen tip |
| 4 | golpe / estrelas_sombra | **Estrelas de Sombra** — Atira estrelas pretas bem seguidas no inimigo mais perto, sem parar. | icone_u_kunai_corvo | Black shuriken throwing stars with faint purple motion trails |
| 5 | golpe / bola_fogo | **Bola de Fogo** — Esfera de fogo lenta que explode em área no inimigo mais perto. | icone_u_frasco_incendiario | Slow heavy orange fire sphere with a compact explosive halo |
| 6 | golpe / dardos_peconhentos | **Dardos Peçonhentos** — Atira dardos verdes de dano baixo no inimigo mais perto, bem seguidos. | icone_u_dardo_primitivo | Slim green poison darts with wet emerald tips |
| 7 | golpe / raio_solar | **Raio Solar** — Dispara um feixe dourado rápido e de longe no inimigo mais perto. | icone_u_estrela_matutina | Narrow brilliant golden beam with a sunburst origin |
| 8 | golpe / bumerangue_ferro | **Bumerangue de Ferro** — Lança um disco de ferro que atravessa até três inimigos em linha reta. | icone_u_disco_cortante | Iron throwing disc with three cutting notches and a straight trail |
| 9 | golpe / bolas_chumbo | **Bolas de Chumbo** — Bolas de chumbo pesadas e lentas que esmagam o inimigo mais perto. | icone_u_marreta_enferrujada | Heavy dull lead cannonballs with compressed impact cracks |
| 10 | golpe / nuvem_veneno | **Nuvem Venenosa** — Uma nuvem verde cai perto de você e envenena quem ficar dentro. | icone_u_pocao_corrosiva | Dense low emerald poison cloud with suspended toxic droplets |
| 11 | golpe / nevoeiro_gelado | **Nevoeiro Gelado** — Uma nuvem azul cai perto de você e congela quem entra nela. | icone_cristal_geada | Low blue freezing mist wrapping a jagged ice shard |
| 12 | golpe / cinzas_vulcanicas | **Cinzas Vulcânicas** — Nuvem grande de cinza cai perto de você e sufoca em pulsos seguidos. | icone_u_tocha_ardente | Broad charcoal ash cloud with ember flecks and concentric pulse wisps |

## Folha 03 — fonte prevista: folha_03.png

| Célula | Categoria / ID | Nome e descrição | Ícone atual | Visual descriptor |
|---|---|---|---|---|
| 1 | golpe / fumaca_sonolenta | **Fumaça Sonolenta** — Névoa roxa cai perto de você e deixa os inimigos lentos e sonolentos. | icone_u_cajado_eremita | Soft violet sleep smoke with drooping ghostly eyelids |
| 2 | golpe / chuva_acida | **Chuva Ácida** — Gotas ácidas caem numa área longe de você e corroem quem estiver nela. | icone_u_estrela_matutina | Dark green cloud shedding bright acid drops onto corroded stone |
| 3 | golpe / nevasca | **Nevasca** — Uma nuvem branca e longa cai perto de você e atrasa quem fica nela. | icone_geada | Long white blizzard cloud with wind-driven snow streaks |
| 4 | golpe / nuvem_espora | **Nuvem de Esporos** — Nuvem de esporos dourados cai perto de você e fica por muito tempo. | icone_u_baluarte_espinhoso | Persistent golden spore cloud above a small fungal cap |
| 5 | golpe / cortina_sangue | **Cortina de Sangue** — Névoa vermelha de dano alto surge perto de você, em intervalos longos. | icone_u_retalhador_sangrento | Thick crimson blood mist hanging like a torn curtain |
| 6 | golpe / nevoa_espectral | **Névoa Espectral** — Névoa com espectros que ferem quem fica nela. | icone_u_lanterna_fantasma | Pale spectral mist containing two distinct anguished ghost faces |
| 7 | golpe / onda_choque | **Onda de Choque** — Um anel branco cresce a partir de você e empurra forte quem toca. | icone_u_cetro_astral | White expanding shockwave ring with strong outward impact rays |
| 8 | golpe / pulso_sagrado | **Pulso Sagrado** — Um pulso dourado sai de você a cada poucos segundos. | icone_u_egide_dourada | Golden sacred pulse ring around a bright central star |
| 9 | golpe / anel_gelado | **Anel Gelado** — Um anel de gelo sai de você, fraco mas constante. | icone_u_bastao_cristal | Thin icy blue ring made of repeating small frozen teeth |
| 10 | golpe / grito_guerra | **Grito de Guerra** — Um anel vermelho lento e largo sai de você de tempos em tempos. | icone_u_sino_ferro | Wide dark red sound ring emerging from a fierce open mouth |
| 11 | golpe / terremoto | **Terremoto** — Um anel marrom rente ao chão que racha o solo de tempos em tempos. | icone_u_machado_guerra | Brown low shock ring splitting rocky ground beneath it |
| 12 | golpe / martelo_trovao | **Martelo do Trovão** — Um anel amarelo veloz e estreito sai de você com estalo. | icone_u_martelo_forjagelo | Narrow yellow lightning ring surrounding a small thunder hammer |

## Folha 04 — fonte prevista: folha_04.png

| Célula | Categoria / ID | Nome e descrição | Ícone atual | Visual descriptor |
|---|---|---|---|---|
| 1 | golpe / rajada_vento | **Rajada de Vento** — Anéis verdes saem o tempo todo e empurram os inimigos para longe. | icone_u_disco_cortante | Successive pale green wind rings pushing outward |
| 2 | golpe / anel_espinhos | **Anel de Espinhos** — Um anel de espinhos verde-escuro fere quem está perto de você. | icone_u_clava_espinhos | Dark green circular bramble with sharp inward and outward thorns |
| 3 | golpe / anel_luar | **Anel Lunar** — Um anel prateado enorme se abre ao seu redor de tempos em tempos. | icone_u_estrela_matutina | Huge luminous silver moon ring with a crescent gleam |
| 4 | golpe / meteoro_flamejante | **Meteoro Flamejante** — Um meteoro de fogo cai perto de você a cada poucos segundos. | icone_u_frasco_incendiario | Blazing orange meteor descending diagonally with a long flame tail |
| 5 | golpe / chuva_pedras | **Chuva de Pedras** — Uma rajada de pedras cai em volta de você a cada poucos segundos. | icone_pedra_amolar | Several plain gray stones falling together with short dusty trails |
| 6 | golpe / cometa_gelado | **Cometa Gelado** — Um cometa de gelo cai num ponto próximo, com aviso no chão. | icone_cristal_geada | Pale blue ice comet aimed at a small circular ground marker |
| 7 | golpe / estrelas_cadentes | **Estrelas Cadentes** — Estrelas amarelas caem em pares perto de você, de tempos em tempos. | icone_u_estrela_matutina | Paired yellow shooting stars falling with matching golden trails |
| 8 | golpe / cometa_negro | **Cometa Negro** — Cometa sombrio, aviso longo e dano pesado, cai de tempos em tempos. | icone_u_maca_lua_sangue | Massive black comet wrapped in a dark violet corona |
| 9 | golpe / fogo_do_ceu | **Fogo do Céu** — Colunas de fogo descem do céu perto de você, de tempos em tempos. | icone_u_tocha_ardente | Vertical columns of orange heavenly fire descending from above |
| 10 | golpe / pedras_vulcanicas | **Pedras Vulcânicas** — Pedras quentes caem em volta de você, bem perto, de tempos em tempos. | icone_terremoto | Cluster of close-set hot basalt rocks with molten red cracks |
| 11 | golpe / raio_meteorico | **Raio Meteórico** — Um raio elétrico cai num ponto distante, com aviso curto no chão. | icone_centelha | Electric bolt plunging onto a small distant impact marker |
| 12 | golpe / chuva_espinhos | **Chuva de Espinhos** — Espinhos caem em volta de você em rajadas curtas e contínuas. | icone_u_espinho_alvorada | Repeated short volleys of dark sharp thorns falling point first |

## Folha 05 — fonte prevista: folha_05.png

| Célula | Categoria / ID | Nome e descrição | Ícone atual | Visual descriptor |
|---|---|---|---|---|
| 1 | golpe / lobo_espirito | **Lobo Espiritual** — Um lobo espiritual caça o inimigo mais perto de tempos em tempos. | icone_u_lanca_cacada | Translucent cyan wolf lunging with jaws open |
| 2 | golpe / espirito_raposa | **Espírito Raposa** — Raposas espirituais caçam o inimigo mais perto, bem rápidas. | icone_u_kunai_corvo | Swift small spectral violet fox with a flowing bright tail |
| 3 | golpe / guardiao_pedra | **Guardião de Pedra** — Um guardião de pedra avança devagar e esmaga quem se aproxima. | icone_u_escudo_vigia | Broad slow stone guardian with blocky granite fists |
| 4 | golpe / fantasma_mata | **Fantasma da Mata** — Fantasmas verdes saem do chão e assombram o inimigo mais perto. | icone_u_lanterna_fantasma | Green woodland ghosts rising out of twisted roots |
| 5 | golpe / serpente_ardente | **Serpente Ardente** — Uma serpente de fogo desliza até o inimigo mais perto e o queima. | icone_u_frasco_incendiario | Coiling orange fire serpent with a clear snake head |
| 6 | golpe / espirito_urso | **Espírito Urso** — Um urso espiritual investe contra o inimigo mais perto, com força. | icone_u_machado_guerra | Large amber spectral bear charging with raised heavy paws |
| 7 | golpe / golem_barro | **Golem de Barro** — Um golem de barro lento persegue o inimigo mais perto e o esmaga. | icone_u_marreta_enferrujada | Heavy reddish clay golem with rounded muddy fists |
| 8 | golpe / dragao_filhote | **Dragãozinho** — Um dragãozinho vermelho voa até o inimigo mais perto e cospe fogo. | icone_u_lanca_dragao | Tiny winged red dragon breathing a short orange flame |
| 9 | golpe / esqueleto_guerreiro | **Esqueleto Guerreiro** — Esqueletos brancos saem do chão e perseguem o inimigo mais perto. | icone_u_espada_treino | White animated warrior skeleton carrying a worn sword |
| 10 | modificador / onda | **Corte ondulante** — Cada corte solta uma onda de valor% do dano. | icone_vento_sopro | Katana slash releasing a pale green traveling crescent wave |
| 11 | modificador / fura | **Estocada perfurante** — Estocada solta uma lança que atravessa: valor% do dano. | icone_lanca | Straight luminous spear piercing a row of dark target fragments |
| 12 | modificador / explode | **Crítico explosivo** — O crítico explode em área, com valor% do dano. | icone_inferno | Bright critical hit spark expanding into a red-orange explosion |

## Folha 06 — fonte prevista: folha_06.png

| Célula | Categoria / ID | Nome e descrição | Ícone atual | Visual descriptor |
|---|---|---|---|---|
| 1 | modificador / folego | **Fôlego de caçador** — Cada abate devolve valor% de uma carga de fôlego. | icone_energetico | Crimson soul from a fallen foe flowing into a hunter lung emblem |
| 2 | evolução / anel_de_brasas | **Anel de Brasas** — Junte Aura de Fogo e Lâminas Rodopiantes, as duas no nível 3. Seis lâminas em brasa giram dentro de um anel de fogo. | sem campo; HUD herda icone_brasa_viva (aura_fogo) | Six ember blades orbiting inside a strong orange fire ring |
| 3 | evolução / revoada_de_trovoes | **Revoada de Trovões** — Junte Corvos Famintos e Raio em Cadeia, os dois no nível 3. Sete corvos elétricos: cada bicada solta um raio no inimigo ao lado. | sem campo; HUD herda icone_corvos (corvos) | Flock of black electric ravens linked by branching blue lightning |
| 4 | evolução / circulo_runico | **Círculo Rúnico** — Junte Runa Explosiva no nível 3 e Crítico explosivo no nível 2. Muitas runas com estouros enormes, e quem sobra fica lento. | sem campo; HUD herda icone_runas (runa) | Many carved runes within an enormous explosive violet ritual circle |
| 5 | evolução / ventania | **Ventania Cortante** — Junte Corte ondulante e Estocada perfurante, os dois no nível 2. A onda fica enorme e a estocada solta três lanças em leque. | sem campo; HUD herda icone_vento_sopro (onda) | Huge sweeping wind crescent paired with three luminous spears in a fan |
| 6 | evolução / dragao_de_brasa | **Dragão de Brasa** — Três espíritos de brasa perseguem o inimigo mais perto e ferem ao tocar. | sem campo; HUD herda icone_u_lanca_dragao (dragao_filhote) | Three small dragon-shaped ember spirits pursuing together |
| 7 | evolução / cacada_espiritual | **Caçada Espiritual** — Lobo e raposa espirituais caçam juntos o inimigo mais perto. | sem campo; HUD herda icone_u_lanca_cacada (lobo_espirito) | Spectral wolf and fast fox running side by side |
| 8 | evolução / urso_solar | **Urso Solar** — Feixes dourados atravessam até quatro inimigos em linha reta. | sem campo; HUD herda icone_u_machado_guerra (espirito_urso) | Golden piercing solar beams crossing a strong bear-shaped sun emblem |
| 9 | evolução / exercito_esquecido | **Exército Esquecido** — Esqueletos e fantasmas saem juntos e perseguem o inimigo mais perto. | sem campo; HUD herda icone_u_espada_treino (esqueleto_guerreiro) | Sword-bearing skeletons marching with green woodland ghosts |
| 10 | evolução / colosso_de_pedra | **Colosso de Pedra** — Um colosso de pedra e barro, lento e pesado, bate forte a cada segundo. | sem campo; HUD herda icone_u_marreta_enferrujada (golem_barro) | Towering hybrid of angular stone and reddish clay with massive fists |
| 11 | evolução / chuva_de_lacas | **Chuva de Lâminas** — Três lâminas voam de uma vez no inimigo mais perto. | sem campo; HUD herda icone_u_arco_sussurro (flechas_sombrias) | Three sharp steel blades flying together through violet arrow-like trails |
| 12 | evolução / bola_incendiaria | **Bola Incendiária** — Projéteis pesados explodem ao cair e ferem quem está perto. | sem campo; HUD herda icone_u_frasco_incendiario (bola_fogo) | Heavy lead-cored burning projectiles bursting into clustered impact fragments |

## Folha 07 — fonte prevista: folha_07.png

| Célula | Categoria / ID | Nome e descrição | Ícone atual | Visual descriptor |
|---|---|---|---|---|
| 1 | evolução / nevasca_congelante | **Nevasca Congelante** — Uma nevasca larga desacelera quem fica dentro dela. | sem campo; HUD herda icone_cristal_geada (nevoeiro_gelado) | Very broad white-blue blizzard cloud enclosing thick frozen crystals |
| 2 | evolução / cinzas_acidas | **Cinzas Ácidas** — Uma nuvem de cinza ácida cai perto do herói e corrói os inimigos. | sem campo; HUD herda icone_u_tocha_ardente (cinzas_vulcanicas) | Charcoal ash cloud shedding corrosive vivid green droplets |
| 3 | evolução / estrondo | **Estrondo** — Um grito de guerra em onda empurra tudo com força. | sem campo; HUD herda icone_u_cetro_astral (onda_choque) | Roaring red mouth projecting a huge white-red outward blast ring |
| 4 | evolução / terra_partida | **Terra Partida** — O chão racha em anéis que levantam os inimigos. | sem campo; HUD herda icone_u_machado_guerra (terremoto) | Concentric cracked earth rings thrusting angular rock slabs upward |
| 5 | evolução / pedreira_ardente | **Pedreira Ardente** — Quatro pedras em brasa caem em volta do herói. | sem campo; HUD herda icone_pedra_amolar (chuva_pedras) | Four glowing ember boulders descending around an empty center |
| 6 | evolução / cometa_duplo | **Cometa Duplo** — Dois cometas caem juntos sobre inimigos próximos. | sem campo; HUD herda icone_cristal_geada (cometa_gelado) | Twin comets descending together, one icy blue and one golden |
| 7 | evolução / chuva_de_ferro | **Chuva de Ferro** — Projéteis de ferro atravessam inimigos e explodem no fim. | sem campo; HUD herda icone_u_disco_cortante (bumerangue_ferro) | Iron penetrating missiles with green wind trails ending in fiery bursts |
| 8 | evolução / peste_negra | **Peste Negra** — Uma névoa de peçonha se espalha e não sai de perto do herói. | sem campo; HUD herda icone_u_dardo_primitivo (dardos_peconhentos) | Persistent black-green venom mist mixed with poison dart tips and violet sleep wisps |
| 9 | evolução / juramento_sagrado | **Juramento Sagrado** — Anéis sagrados se abrem e sopram os inimigos para longe. | sem campo; HUD herda icone_u_clava_espinhos (anel_espinhos) | Golden sacred rings intertwined with green thorns and pale spectral wisps |
| 10 | evolução / eclipse_negro | **Eclipse Negro** — Dois cometas negros e uma cortina de sangue caem sem trégua. | sem campo; HUD herda icone_u_maca_lua_sangue (cometa_negro) | Twin black comets descending through a hanging crimson blood curtain |
| 11 | evolução / tempestade_primordial | **Tempestade Primordial** — Lanças e pedras perfuram; cada impacto puxa os inimigos para o ponto. | sem campo; HUD herda icone_u_lanca_cacada (lanca_geada) | Whirling ice spears and sharp stones converging inward on a bright gravity point |
| 12 | evolução / eclipse_de_almas | **Eclipse de Almas** — Espíritos prendem o inimigo; quem já está preso leva dano em dobro. | sem campo; HUD herda icone_u_lanca_cacada (lobo_espirito) | Spectral wolves, foxes and woodland ghosts binding a dark target with soul strands |

## Folha 08 — fonte prevista: folha_08.png

| Célula | Categoria / ID | Nome e descrição | Ícone atual | Visual descriptor |
|---|---|---|---|---|
| 1 | evolução / juizo_final | **Juízo Final** — Cada meteoro que cai chama outro sobre o inimigo mais perto. | sem campo; HUD herda icone_u_maca_lua_sangue (cometa_negro) | Chain of blazing meteors, each impact spawning the next descending meteor |
| 2 | evolução / furacao_glacial | **Furacão Glacial** — Nuvem gelada; inimigos lentos dentro dela levam dano em dobro. | sem campo; HUD herda icone_geada (nevasca) | Spiraling dense white-blue frozen cloud enclosing an enemy-shaped ice silhouette |
| 3 | principal / katana | **Katana** — Combo de cortes e estocada na direção da mira. | sem campo de carta; desenho de combate | Single dark-handled katana angled diagonally with a restrained silver slash and straight thrust glint |
| 4 | secundário / escudo | **Escudo** — Bloqueia de frente; bloqueio perfeito repele e atordoa. | sem campo; desenho em código | Sturdy frontal dark steel shield with a bright parry spark on its rim |
| 5 | habilidade / ruptura | **Ruptura (E)** — Carrega e racha o chão ao redor, causando dano e repelindo. | desenho em código de duas placas e fenda | Two separated rocky ground plates with a branching central orange fissure and outward force |
| 6 | reserva / ultimate_q | **Ultimate (Q), reservada** — Sem mecânica publicada; somente selo indisponível. | desenho em código: círculo apagado e traço | Muted gray circular seal crossed by a short horizontal bar, no letters and no implied power |
## Folha 09 — fonte: folha_09.png (issue #275)

Quatro modificadores dos heróis Nicão e Lucas, nas células 1–4 da primeira linha. As células 5–12 não contêm ícones. Ordem: esquerda → direita.

**Dimensão real da fonte gerada:** 1447×1087 px. A grade lógica continua com células de 362×362. Antes de usar o recorte rígido do pipeline, o Claude deve acrescentar uma coluna branca à direita e remover uma linha branca do rodapé, chegando a 1448×1086 **sem redimensionar os desenhos**. A variação é só no fundo vazio; todos os motivos cabem na primeira linha e nas respectivas colunas. A fonte original foi preservada.

| Célula | Categoria / ID | Nome e descrição real da carta | Herói | Desenho e associação |
|---|---|---|---|---|
| 1 (linha 1, coluna 1; x=0, y=0) | modificador / abalo | **Abalo sísmico** — A pancada no chão solta uma onda de choque com {v}% do dano. | Nicão | Martelo pesado atingindo pedra, com onda dourada se abrindo a partir do impacto. |
| 2 (linha 1, coluna 2; x=362, y=0) | modificador / muralha | **Peso de muralha** — Os golpes empurram e atordoam {v}% mais. | Nicão | Manopla de ferro empurrando uma silhueta, com estrelas de atordoamento. Não representa defesa ou escudo. |
| 3 (linha 1, coluna 3; x=724, y=0) | modificador / chuva | **Chuva de adagas** — Cada adaga que acerta tem {v}% de chance de soltar outra. | Lucas | Duas adagas ligadas por um rastro violeta e uma faísca de impacto sobre fragmentos. Simboliza o encadeamento; a ilustração não é um diagrama literal da trajetória. |
| 4 (linha 1, coluna 4; x=1086, y=0) | modificador / mira | **Mira longa** — As adagas voam {v}% mais longe e mais rápido. | Lucas | Uma adaga com rastro longo e anéis de vento ciano, representando alcance e velocidade. Não acrescenta perfuração. |

Os nomes de destino sugeridos são abalo.png, muralha.png, chuva.png e mira.png, nas variantes de 32 e 16 px já usadas no #274. O Claude faz normalização do fundo, recorte e ligação no pipeline; esta entrega não altera os ícones provisórios em uso.

## Conferência das fontes e orientação de integração

As folhas são fontes ilustrativas, não diagramas de regras. Todos os motivos previstos têm sua célula; a folha 08 mantém seis células finais brancas e Q continua como selo cinza reservado. A folha 06 foi revisada com imagegen: Anel de Brasas tem seis lâminas e Colosso de Pedra usa granito frio com barro, sem lava. Revoada de Trovões usa uma amostra ilustrativa do bando. Eclipse de Almas prioriza o vínculo dos espíritos com a vítima, sem retratar separadamente todas as espécies consumidas.

O integrador deve associar cada célula pela **categoria + ID desta tabela**, nunca pelo campo `icone` legado compartilhado. Evoluções precisam de associação própria por ID; não reaproveitar automaticamente o ícone da primeira peça consumida. Números, descrições e regras continuam sendo os dados do jogo; não derivá-los das imagens. O recorte, a legibilidade no tamanho final e o vínculo no jogo ficam com o Claude do Alisson e ainda precisam ser conferidos na integração.
