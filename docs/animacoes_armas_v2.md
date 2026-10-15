# Animações das armas da v2: escolha por arma

Decisão do Breno (2026-10-15): o pedido **não vai mais para o Codex nem para o Alisson**; as animações serão feitas no Blender, seguindo esta tabela (a issue #267 foi cancelada). Onde o texto diz 'entregue', 'folha' ou 'pipeline', leia como o que o trabalho no Blender tem que produzir. Os nomes e tamanhos seguem o padrão de `assets/v2/armas/indice.json`.

## O problema
Hoje cada arma da v2 é **uma imagem parada** (`jogos/hordas/projeto/assets/v2/armas/*.png`, índice em `indice.json`) que só desliza: o espírito raposa, o lobo, o urso e o golem andam sem mexer as pernas e sem virar; o meteoro cai como uma pedra de figurinha; as nuvens e os anéis são uma foto esticada. O Breno quer **animação de verdade**.

## Regra de ouro: nada de PNG parado
- Todo pedido abaixo é uma **folha de sprites com quadros diferentes entre si** (não vale repetir o mesmo desenho, nem só mudar brilho). Entrega parada ou com quadros iguais **volta para refazer**.
- Invocação: tem que **andar** (pernas/asas mexem), **atacar** (golpe visível) e **ficar parada** (respira).
- Projétil: **loop de voo** com rastro, **impacto** com quadros próprios. Projétil redondo ou afiado que gira: o giro está nos quadros.
- Área: **entrada, loop vivo e saída**.
- O estilo, a paleta, a luz e a escala são os das folhas atuais (`fonte_armas_*.webp` em `jogos/hordas/prototipos/cara_nova/objetos/`). Contorno escuro de 1 px nos sprites de aliado e projétil.
- Pixel art, sem suavização, **sem texto, sem moldura, sem grade desenhada**.

## Convenções de arquivo (siga à risca)
- Pasta: `jogos/hordas/fonte_arte/armas_anim/`. Um PNG por sprite: `<nome_do_sprite>_anim.png` (o nome é o da coluna "Sprite" da tabela, o mesmo de `indice.json`).
- A folha é uma grade: **uma linha por animação, na ordem listada no pacote**, quadros da esquerda para a direita, células do tamanho exato "Quadro novo". Células sem uso ficam **transparentes**.
- Sprites de **aliado e projétil**: fundo transparente. Sprites de **área** (nuvem, anel, aura): como já é hoje, **fundo preto puro**; o pipeline vira transparência e o brilho vira alfa (mistura aditiva). Não pinte fundo colorido.
- Arte-fonte pode ser em **escala maior em múltiplo inteiro** (2×, 4× ou 8×) do tamanho do quadro, com a grade alinhada. O pipeline (`gerar_objetos.py`, do Claude do Alisson) reduz para o tamanho do jogo e gera o normal map; **não entregue normal**.
- Âncora: aliado = **pé no centro da borda inferior** (2 px acima da borda); projétil e meteoro = **a cabeça do projétil no centro-direita** (3/4 da largura) e o rastro para a esquerda; impacto e área = centro do quadro.
- Registre cada entrega em `docs/LICENCAS_ARTE.md` como você já faz (fonte, "geração própria", sem terceiros).
- **O PC do Breno é fraco:** por isso poucos quadros, quadros pequenos e poucas direções. Não aumente os quadros nem o número de direções além do pedido.

## Pacotes de animação

Direção: o jogo é 2.5D visto de cima inclinado. O código só **espelha** esquerda/direita, então desenhe **direita, baixo (de frente) e cima (de costas)**; a esquerda é o espelho da direita (por isso a criatura não pode ter detalhe que quebre no espelho: sem texto, sem arma só no lado esquerdo).

### ALI: invocações (espíritos, bichos, mortos-vivos)
Folha de **9 linhas × 6 colunas**, nesta ordem:

| Linha | Direção | Animação | Quadros | FPS |
|---|---|---|---|---|
| 1 | direita | andar | 6 | 10 |
| 2 | direita | atacar | 4 | 14 |
| 3 | direita | parado | 4 | 6 |
| 4 | baixo (frente) | andar | 6 | 10 |
| 5 | baixo | atacar | 4 | 14 |
| 6 | baixo | parado | 4 | 6 |
| 7 | cima (costas) | andar | 6 | 10 |
| 8 | cima | atacar | 4 | 14 |
| 9 | cima | parado | 4 | 6 |

- Seres que voam (corvos, fantasma, dragão): "andar" é **bater asas / flutuar** (12 FPS), "parado" é pairar. Serpente: "andar" é ondular o corpo.
- "Atacar" por criatura: raposa e lobo = bote com pulo; urso, golem, guardião, colosso = pancada pesada com antecipação; esqueleto = golpe de espada; fantasma = arranhão/investida; serpente e dragão = bote e baforada curta; corvos = mergulho com bicada.
- Quadro de ataque 3 (de 4) é o **momento do contato** (o código solta o dano nele).
- A criatura **não** se desloca pela folha: o código move o sprite. Desenhe o ciclo "no lugar".
- Entrada e saída (aparecer e sumir) ficam por conta do código (fade); não precisam de quadros.
- Criaturas de 44 px ou mais (urso, guardião, golem, colosso): **numa 2ª fase** (depois de tudo entregue) peço 2 diagonais a mais. Não faça agora.
- **Fusões (prioridade 4):** reaproveite a criatura-base com **variação de paleta e efeito** (ex.: corvos elétricos = corvos + faíscas; esqueletos e fantasmas frios; dragão de brasa = dragão em brasa; caçada espiritual = lobo e raposa com aura dupla; eclipse de almas = as quatro com aura escura). Só `colosso_de_pedra` é criatura nova (golem + guardião fundidos, lento e pesado).

### PRJ-A: projétil que aponta (flecha, lança, dardo, feixe)
Folha de 2 linhas: **voo** (4 quadros, 12 FPS, loop; rastro fino no tamanho do quadro, ponta para a **direita**) e **impacto** (3 quadros, 20 FPS, uma vez, 20×20, faísca/estalo da cor da arma). O código gira o sprite para o ângulo do voo, então desenhe sempre apontando para a direita.

### PRJ-G: projétil que gira sozinho (adaga, shuriken, disco, lâminas, ferro)
2 linhas: **giro** (8 quadros, 16 FPS, loop, uma volta completa, quadrado) e **impacto** (3 quadros, 20×20). O código **não** gira esses, o giro é dos quadros. (Lâminas e Anel de Brasas são as peças que orbitam o herói: o mesmo giro; a órbita é do código.)

### PRJ-B: bola explosiva (bola de fogo, chumbo, incendiária)
2 linhas: **voo** (4 quadros, 12 FPS, loop, bola com chama ou poeira atrás, aponta para a direita) e **explosão** (6 quadros, 15 FPS, uma vez, 56×56, abre e some).

### MET: meteoro e cometa que caem
3 linhas: **queda** (4 quadros, 12 FPS, loop, aponta para a direita, com **rastro longo**; o código gira para baixo), **impacto** (8 quadros, 15 FPS, uma vez, 72×72 nos grandes e 48×48 nos pequenos; clarão, onda e fagulhas), **marca** (4 quadros, 8 FPS, 48×32 achatado: chão queimado/rachado/gelado que esfria e some, última coluna quase transparente).

### ARE-N: nuvens, névoas, chuva e neve de área
3 linhas: **loop** (6 quadros, ou 4 se a área tem mais de 130 px de largura; 6 FPS; **o último quadro emenda no primeiro**), **entrada** (3 quadros, 10 FPS, a nuvem se forma/expande) e **saída** (3 quadros, 10 FPS, dissolve). Fundo preto puro. Movimento: turbilhão, bolhas, flocos ou gotas **dentro** da nuvem, não só o contorno respirando.

### ARE-A: anéis de choque, ondas e terremoto
1 linha: **expandir** (6 quadros, 20 FPS, uma vez): o anel nasce pequeno no centro e chega ao tamanho do quadro, afinando e esmaecendo. Fundo preto puro. Terremoto: rachaduras que correm para fora com poeira.

### ARE-F: aura, raio, runa, redemoinho
- `aura_fogo`: loop 6 quadros, 10 FPS (chamas dançando; emenda).
- `redemoinho_verde` e `ventania`: loop 6 quadros, 12 FPS (giro com folhas/lâminas de vento).
- `runa`: 3 linhas: armar 4q (6 FPS), loop pulsante 4q (6 FPS), explosão 6q (15 FPS, uma vez).
- `circulo_runico`: loop 6q (6 FPS) e explosão 6q (15 FPS).
- `raio`: 3 variações do arco elétrico × 3 quadros (20 FPS), cada uma com 100×39.

## Ordem de prioridade
1. **Primeiro as invocações e o meteoro** (o Breno citou): raposa, lobo, urso, golem, esqueleto, dragão, corvos, fantasma e o meteoro flamejante. Fazer **na ordem: raposa, meteoro flamejante, lobo, urso, golem...**.
2. Guardião, serpente, os projéteis (PRJ-A, G, B), os outros meteoros e **os 3 que faltam** (`pedra_cinza`, `fogo_do_ceu`, `raio_meteorico`).
3. As áreas base (nuvens, anéis, aura, runa, raio, redemoinho).
4. As evoluções/fusões.

## O que falta de sprite estático
Só 3 armas usam imagem emprestada (o meteoro da `chuva_pedras` usa a bola de chumbo; `fogo_do_ceu` usa a bola de fogo; `raio_meteorico` usa o estilhaço azul). Elas aparecem **em negrito** na tabela abaixo (linhas "FALTA"). Não precisam de PNG parado antes: o 1º quadro da queda já serve de estático. `anel_fogo` (arma aproximada da aura de fogo) é **dispensável**; use `aura_fogo`.

## Tabela completa (76 folhas)
Pacotes: ALI invocação, PRJ-A projétil que aponta, PRJ-G projétil que gira, PRJ-B bola explosiva, MET meteoro, ARE-N nuvem, ARE-A anel, ARE-F aura/runa/raio/redemoinho. "Quadro novo" é o tamanho de **uma célula** em px do jogo; a folha tem tamanho `colunas × quadro` por `linhas × quadro`. Nos ALI o quadro é o tamanho de hoje + 8 px (folga para pulo e golpe); a folha ALI mede `6 × largura` por `9 × altura`. "Hoje" em todas é a imagem parada.

Como o jogo move cada tipo hoje: aliado fica parado, de pé, flutuando 10 px com balanço de 2 px, e anda em linha reta até o inimigo mais perto (a 200 px/s a raposa; sem virar nem animar). Projétil voa reto com a imagem girada para o ângulo do voo. Meteoro cai do alto com a ponta para baixo e um círculo de aviso no chão. Nuvem, anel e aura são uma imagem aditiva esticada ao raio da área.
#### Prioridade 1

| Pacote | Sprite (hoje em `assets/v2/armas/`) | Arma | Tamanho hoje | Quadro novo (px do jogo) | Animação |
|---|---|---|---|---|---|
| ALI | `corvos.png` | corvos | 33x27 | 42x36 | 252x324 |
| ALI | `dragao_vermelho.png` | dragao_filhote | 32x26 | 40x34 | 240x306 |
| ALI | `esqueleto_guerreiro.png` | esqueleto_guerreiro | 30x44 | 38x52 | 228x468 |
| ALI | `fantasma_encapuzado.png` | fantasma_mata | 24x34 | 32x42 | 192x378 |
| ALI | `golem_de_barro.png` | golem_barro | 46x54 | 54x62 | 324x558 |
| ALI | `lobo_fantasma.png` | lobo_espirito | 36x28 | 44x36 | 264x324 |
| ALI | `raposa_de_fogo.png` | espirito_raposa | 28x18 | 36x26 | 216x234 |
| ALI | `urso_espiritual.png` | espirito_urso | 52x40 | 60x48 | 360x432 |
| MET | `meteoro_flamejante.png` | meteoro_flamejante | 28x28 | 46x30 (queda); 72x72 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |

#### Prioridade 2

| Pacote | Sprite (hoje em `assets/v2/armas/`) | Arma | Tamanho hoje | Quadro novo (px do jogo) | Animação |
|---|---|---|---|---|---|
| ALI | `guardiao_de_pedra.png` | guardiao_pedra | 44x52 | 52x60 | 312x540 |
| ALI | `serpente_de_brasa.png` | serpente_ardente | 40x22 | 48x30 | 288x270 |
| MET | `cometa_gelo.png` | cometa_gelado | 22x22 | 36x24 (queda); 48x48 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | `cometa_roxo.png` | cometa_negro | 40x40 | 64x42 (queda); 72x72 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | `espinho_verde.png` | chuva_espinhos | 6x14 | 10x16 (queda); 48x48 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | `estilhaco_azul.png` | (raio_meteorico aprox.) | 30x30 | 48x32 (queda); 48x48 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | `estrela_cadente.png` | estrelas_cadentes | 24x16 | 40x18 (queda); 48x48 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | **fogo_do_ceu (FALTA)** | fogo_do_ceu (hoje usa bola_fogo) | —: 24x24 | 38x26 (queda); 72x72 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | **pedra_cinza (FALTA)** | chuva_pedras (hoje usa bola_chumbo) | —: 14x14 | 24x16 (queda); 48x48 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | `pedra_vulcanica.png` | pedras_vulcanicas | 10x10 | 16x12 (queda); 48x48 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | **raio_meteorico (FALTA)** | raio_meteorico (hoje usa estilhaco_azul) | —: 30x30 | 48x32 (queda); 48x48 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| PRJ-A | `dardo_verde.png` | dardos_peconhentos | 10x5 | 16x8 (voo); 20x20 (impacto) | voo 4q + impacto 3q |
| PRJ-A | `feixe_dourado.png` | raio_solar | 40x3 | 64x6 (voo); 20x20 (impacto) | voo 4q + impacto 3q |
| PRJ-A | `flecha_roxa.png` | flechas_sombrias | 14x5 | 24x8 (voo); 20x20 (impacto) | voo 4q + impacto 3q |
| PRJ-A | `lanca_gelo.png` | lanca_geada | 18x4 | 30x6 (voo); 20x20 (impacto) | voo 4q + impacto 3q |
| PRJ-B | `bola_chumbo.png` | bolas_chumbo | 14x14 | 24x16 (voo); 56x56 (impacto) | voo 4q + impacto 6q |
| PRJ-B | `bola_fogo.png` | bola_fogo | 16x16 | 26x18 (voo); 56x56 (impacto) | voo 4q + impacto 6q |
| PRJ-G | `adaga_aco.png` | adagas_voadoras | 10x4 | 14x14 (giro); 20x20 (impacto) | giro 8q + impacto 3q |
| PRJ-G | `disco_ferro.png` | bumerangue_ferro | 16x16 | 20x20 (giro); 20x20 (impacto) | giro 8q + impacto 3q |
| PRJ-G | `laminas.png` | laminas | 20x12 | 24x24 (giro); 20x20 (impacto) | giro 8q + impacto 3q |
| PRJ-G | `shuriken_sombria.png` | estrelas_sombra | 10x10 | 14x14 (giro); 20x20 (impacto) | giro 8q + impacto 3q |

#### Prioridade 3

| Pacote | Sprite (hoje em `assets/v2/armas/`) | Arma | Tamanho hoje | Quadro novo (px do jogo) | Animação |
|---|---|---|---|---|---|
| ARE-A | `anel_dourado.png` | pulso_sagrado | 128x89 | 128x89 | expandir 6q (uma vez) |
| ARE-A | `anel_eletrico.png` | martelo_trovao | 128x63 | 128x63 | expandir 6q (uma vez) |
| ARE-A | `anel_espinhos_verdes.png` | anel_espinhos | 128x86 | 128x86 | expandir 6q (uma vez) |
| ARE-A | `anel_gelo.png` | anel_gelado | 128x60 | 128x60 | expandir 6q (uma vez) |
| ARE-A | `anel_lunar.png` | anel_luar | 128x89 | 128x89 | expandir 6q (uma vez) |
| ARE-A | `anel_onda_branca.png` | onda_choque | 128x84 | 128x84 | expandir 6q (uma vez) |
| ARE-A | `anel_vermelho.png` | grito_guerra | 128x70 | 128x70 | expandir 6q (uma vez) |
| ARE-A | `terremoto_poeira.png` | terremoto | 150x69 | 150x69 | expandir 6q (uma vez) |
| ARE-F | `aura_fogo.png` | aura_fogo | 128x82 | 128x82 | loop 6q |
| ARE-F | `raio.png` | raio | 100x39 | 100x39 | 3 variações de arco × 3q |
| ARE-F | `redemoinho_verde.png` | rajada_vento | 128x73 | 128x73 | loop 6q |
| ARE-F | `runa.png` | runa | 72x46 | 72x46 | armar 4q + loop 4q + explosão 6q |
| ARE-N | `chuva_acida.png` | chuva_acida | 120x80 | 120x80 | loop 6q + entrada 3q + saída 3q |
| ARE-N | `fumaca_sonolenta.png` | fumaca_sonolenta | 110x57 | 110x57 | loop 6q + entrada 3q + saída 3q |
| ARE-N | `nevoa_espectral.png` | nevoa_espectral | 100x65 | 100x65 | loop 6q + entrada 3q + saída 3q |
| ARE-N | `nevoa_gelada.png` | nevoeiro_gelado | 120x74 | 120x74 | loop 6q + entrada 3q + saída 3q |
| ARE-N | `nuvem_cinzas.png` | cinzas_vulcanicas | 160x104 | 160x104 | loop 4q + entrada 3q + saída 3q |
| ARE-N | `nuvem_esporos.png` | nuvem_espora | 120x77 | 120x77 | loop 6q + entrada 3q + saída 3q |
| ARE-N | `nuvem_neve.png` | nevasca | 140x91 | 140x91 | loop 4q + entrada 3q + saída 3q |
| ARE-N | `nuvem_sangue.png` | cortina_sangue | 70x50 | 70x50 | loop 6q + entrada 3q + saída 3q |
| ARE-N | `nuvem_veneno.png` | nuvem_veneno | 100x64 | 100x64 | loop 6q + entrada 3q + saída 3q |

#### Prioridade 4

| Pacote | Sprite (hoje em `assets/v2/armas/`) | Arma | Tamanho hoje | Quadro novo (px do jogo) | Animação |
|---|---|---|---|---|---|
| ALI | `cacada_espiritual.png` | cacada_espiritual | 44x32 | 52x40 | 312x360 |
| ALI | `colosso_de_pedra.png` | colosso_de_pedra | 48x54 | 56x62 | 336x558 |
| ALI | `dragao_de_brasa.png` | dragao_de_brasa | 40x36 | 48x44 | 288x396 |
| ALI | `eclipse_de_almas.png` | eclipse_de_almas | 48x38 | 56x46 | 336x414 |
| ALI | `exercito_esquecido.png` | exercito_esquecido | 34x44 | 42x52 | 252x468 |
| ALI | `revoada_de_trovoes.png` | revoada_de_trovoes | 36x30 | 44x38 | 264x342 |
| ARE-A | `estrondo.png` | estrondo | 140x95 | 140x95 | expandir 6q (uma vez) |
| ARE-A | `juramento_sagrado.png` | juramento_sagrado | 140x94 | 140x94 | expandir 6q (uma vez) |
| ARE-A | `terra_partida.png` | terra_partida | 150x106 | 150x106 | expandir 6q (uma vez) |
| ARE-F | `circulo_runico.png` | circulo_runico | 100x72 | 100x72 | loop 6q + explosão 6q |
| ARE-F | `ventania.png` | ventania | 120x79 | 120x79 | loop 6q |
| ARE-N | `cinzas_acidas.png` | cinzas_acidas | 150x130 | 150x130 | loop 4q + entrada 3q + saída 3q |
| ARE-N | `furacao_glacial.png` | furacao_glacial | 160x130 | 160x130 | loop 4q + entrada 3q + saída 3q |
| ARE-N | `nevasca_congelante.png` | nevasca_congelante | 145x114 | 145x114 | loop 4q + entrada 3q + saída 3q |
| ARE-N | `peste_negra.png` | peste_negra | 130x121 | 130x121 | loop 6q + entrada 3q + saída 3q |
| MET | `cometa_duplo.png` | cometa_duplo | 32x18 | 52x20 (queda); 72x72 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | `eclipse_negro.png` | eclipse_negro | 36x28 | 58x30 (queda); 72x72 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | `juizo_final.png` | juizo_final | 40x30 | 64x32 (queda); 72x72 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| MET | `pedreira_ardente.png` | pedreira_ardente | 22x22 | 36x24 (queda); 48x48 (impacto); 48x32 (marca) | queda 4q + impacto 8q + marca 4q |
| PRJ-A | `chuva_de_lacas.png` | chuva_de_lacas | 24x9 | 40x12 (voo); 20x20 (impacto) | voo 4q + impacto 3q |
| PRJ-A | `tempestade_primordial.png` | tempestade_primordial | 44x16 | 72x18 (voo); 20x20 (impacto) | voo 4q + impacto 3q |
| PRJ-A | `urso_solar.png` | urso_solar | 26x16 | 42x18 (voo); 20x20 (impacto) | voo 4q + impacto 3q |
| PRJ-B | `bola_incendiaria.png` | bola_incendiaria | 24x18 | 40x20 (voo); 56x56 (impacto) | voo 4q + impacto 6q |
| PRJ-G | `anel_de_brasas.png` | anel_de_brasas | 22x14 | 26x26 (giro); 20x20 (impacto) | giro 8q + impacto 3q |
| PRJ-G | `chuva_de_ferro.png` | chuva_de_ferro | 24x18 | 28x28 (giro); 20x20 (impacto) | giro 8q + impacto 3q |

---

## O que o código precisa para usar as animações
O que o código precisa para usar as folhas quando chegarem:
1. **Dados novos no índice** (`assets/v2/armas/indice.json`, gerado por `gerar_objetos.py armas`): para cada sprite, `quadro`, `animacoes` (linha, nº de quadros, FPS, `loop` sim/não) e, nos projéteis, `gira_sozinho` (PRJ-G: o código **não** gira a imagem). Um `*_anim.json` por folha também serve.
2. **Aliados** (`armas_novas.gd`, `desenhar_sprites`, ramo `"aliado"`): escolher a **direção** pelo vetor de movimento (esquerda = espelhar a direita com escala x = -1; ver o ângulo: |x| maior = direita/esquerda; y positivo maior = baixo; y negativo = cima); trocar de **andar para atacar** no toque (`_acertou("aliado")` já existe) e voltar; **parado** quando está perto do herói sem alvo. O quadro de contato do ataque é o 3. Manter o balanço de 2 px só nos parados.
3. **Projéteis**: PRJ-A/B usam o ângulo do voo como hoje; PRJ-G não giram. Ao acertar ou chegar ao fim, tocar a linha de **impacto/explosão** uma vez, no ponto de impacto, sem prender o slot do pool de 48 (o impacto é um efeito à parte, de vida curta). O rastro vem dentro do quadro (âncora na cabeça a 3/4 da largura).
4. **Meteoros**: a queda gira PI/2 como hoje (a folha aponta para a direita); no pouso tocar o **impacto** e deixar a **marca** com fade.
5. **Áreas**: tocar **entrada** uma vez, **loop** enquanto a nuvem dura, **saída** nos últimos 0,5 s (hoje já existe o fade de 0,5 s); anéis: **expandir** acompanha o raio do golpe (hoje é a imagem escalada). Mistura aditiva como hoje.
6. **Desempenho** (PC fraco): um relógio global de quadros (não um por golpe), atlas por folha, nada de criar textura por quadro, e cortar o desenho do que está fora da tela.
7. **Conferidor de sprites** (#207, `ferramentas/conferir_objeto.py`): estender para validar a grade (tamanho da célula, linhas e colunas esperadas, quadros diferentes entre si, último quadro do loop emendando no primeiro) e reprovar folha com quadros repetidos.
8. As **fusões de aliado** (colosso à parte) podem apontar para a folha-base com tinta no shader enquanto a variante de paleta não chega.

Pedido do Breno ("as armas têm que ter animação de verdade, não PNG deslizando"). 