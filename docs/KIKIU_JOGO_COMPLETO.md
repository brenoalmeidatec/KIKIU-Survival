# K.I.K.I.U: o jogo por inteiro

Documento de referência do projeto, em português, para ler no celular. Foi escrito a partir do código, dos dados (`jogos/hordas/projeto/dados/`), dos docs do repositório e das issues do GitHub, na data de 19/10/2026 (main em `9169ac1`, PR #343 já mesclado). Onde algo não existe no projeto, está escrito **não encontrado**. Os números são os que estão nos arquivos de dados; quando um valor depende de outro (bônus de herói, cartas, modo Pesadelo), isso está dito.

> Este arquivo descreve o estado atual. Ele não propõe mudanças: o que está pausado, planejado ou em andamento aparece marcado como tal.

## Índice

1. [Visão geral e proposta](#1-visão-geral-e-proposta)
2. [História e personagens do grupo](#2-história-e-personagens-do-grupo)
3. [Como se joga e controles](#3-como-se-joga-e-controles)
4. [Heróis e atributos](#4-heróis-e-atributos)
5. [Armas, golpes e fusões](#5-armas-golpes-e-fusões)
6. [Cartas e melhorias](#6-cartas-e-melhorias)
7. [Inimigos, elites e chefes](#7-inimigos-elites-e-chefes)
8. [Mapas e regiões](#8-mapas-e-regiões)
9. [Baús, itens e relíquias](#9-baús-itens-e-relíquias)
10. [Meta-progressão: almas, santuário e conquistas](#10-meta-progressão-almas-santuário-e-conquistas)
11. [HUD e menus](#11-hud-e-menus)
12. [Arte e animação](#12-arte-e-animação)
13. [Áudio](#13-áudio)
14. [Arquitetura técnica](#14-arquitetura-técnica)
15. [Testes, CI, export e como jogar](#15-testes-ci-export-e-como-jogar)
16. [Quem faz o quê](#16-quem-faz-o-quê)
17. [Marcos e o que falta para fechar a v2](#17-marcos-e-o-que-falta-para-fechar-a-v2)
18. [Roteiro da v3](#18-roteiro-da-v3)
19. [Glossário](#19-glossário)

---

## 1. Visão geral e proposta

**K.I.K.I.U** (*Knights In Kaos, Infinite Upgrades*) é um jogo de hordas em **pixel art com clima de fantasia sombria**, feito em **Godot 4.4.1**. Você atravessa um mundo tomado pelo caos enquanto ondas de monstros fecham o cerco.

- **Golpe principal:** a katana (ou o herói que você escolher) ataca no clique do mouse, na direção do cursor. No controle, é o gatilho.
- **Armas das cartas:** dezenas de armas automáticas que atacam sozinhas, de lâminas e flechas a raios, corvos e runas.
- **Escolhas a cada nível:** você escolhe cartas que dão armas, melhorias de atributo e modificadores. O objetivo é montar uma combinação que aguente a horda.
- **Com os amigos:** a proposta é jogar em grupo. O README do projeto fala em até seis pessoas no online. O online existia na v1 e está em fase de testes; o retorno dele na v2 é o Marco 9 ([#133](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/133)), ainda aberto. Ver `docs/ONLINE_V2_PLANO.md`.
- **Duelo final:** na v1, quando o último chefe cai, começa um duelo entre os jogadores numa arena que vai fechando (`dados/pvp.json`, `dados/prorrogacao.json`). Na v2, o duelo entre amigos é o Marco 9 ([#133](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/133)), ainda aberto.
- **Plataforma:** o README diz Windows; o CI também exporta Linux e Web (ver [seção 15](#15-testes-ci-export-e-como-jogar)).

### Proposta de valor, em uma frase

Um roguelike de ação com controle de verdade: você se mexe, mira, esquiva, escolhe o que aprimorar e sente o poder crescer, jogando com os amigos.

### Situação de hoje

- **v2 é a versão em desenvolvimento.** Ela roda sobre o protótipo 2.5D (`jogos/hordas/prototipos/cara_nova/`, congelado como referência). O jogo abre na v2: a cena principal é o título (`v2/menu_principal.tscn`).
- **v1 está pausada** e vai ser aposentada. Ela abre com `-- --v1`. Só entra correção de bug grave (crash, save corrompido, build quebrado). Quando um sistema da v1 serve na v2, ele é portado, sem melhorar a v1 (`CLAUDE.md`).

---

## 2. História e personagens do grupo

**História de fundo.** O texto de origem está em `docs/HISTORIA_GRUPO_AMIGOS.md`. Os personagens são inspirados em amigos reais da turma da Faculdade Cairu, em Salvador. A regra de conteúdo combinada, registrada no próprio documento, é: humor pesado ou sexual só como insinuação, nada explícito; sem piadas sobre deficiência, cor da pele ou classe; os personagens falam com gírias da Bahia.

**Quem é quem (resumo, sem as piadas):**

| Personagem | Ideia central | Papel no jogo |
|---|---|---|
| Hazaki | Samurai, lutador e feiticeiro; começa simples e vira lenda | Herói padrão da v2 e da v1 |
| Nicão | Guardião manso, de marreta; tranquilo e de boa | Herói da v2 e da v1 |
| Lucas | Adagueiro à distância, caótico, veloz e com sorte | Herói da v2 e da v1 |
| Matheus, João, Beto, Lukako, Fábio | Rivais do duelo final na v1 | Estão em `dados/pvp.json` |

Notas de estado:
- Os personagens **Matheus, Lucas e Nicão** como *novos* personagens (PRs #286, #296, #297, #298) estão **de lado**, por decisão do Breno de 15/10. O foco é o jogo.
- Os rivais de duelo (João, Beto, Lukako, Fábio, Matheus) são da v1. Na v2 o duelo **não encontrado**.
- A história de cada um (falas e piadas internas) é de responsabilidade do Breno; números e textos vêm dele.

---

## 3. Como se joga e controles

### Ciclo de uma partida (v2)

1. **Título** (`v2/menu_principal.tscn`) leva ao **santuário** (`v2/altar.tscn`).
2. No santuário você escolhe o **personagem**, o **mapa** e as **melhorias** compradas com almas, e pode entrar no **modo Pesadelo**.
3. A partida começa no mapa escolhido. O herói caminha, luta e o nível sobe a cada `duracao_nivel` (20 s em todos os mapas, ver [seção 8](#8-mapas-e-regiões)).
4. Ao subir de nível aparece a **escolha de cartas**. Ao abrir um **baú**, aparece a **roleta** de cartas.
5. O chefe de nível trava o avanço até morrer. Mini-chefes soltam baú. O chefe do último nível termina o mapa.
6. Ao morrer ou vencer, aparece a tela de resultado, e as **almas** da partida entram no saldo permanente.

### Controles (teclado e mouse)

| Ação | Teclado e mouse | Controle (o que está confirmado) |
|---|---|---|
| Andar | WASD | Analógico esquerdo |
| Mirar | Mouse | Analógico direito |
| Golpe principal (katana) | Clique esquerdo (segurar repete o combo) | Gatilho (ver `v2/LEIA-ME.md`) |
| Escudo | Botão direito | LT |
| Ruptura (carregar e soltar) | E (segurar e soltar) | LB |
| Especial do herói (um por herói: Hazaki, investida; Nicão, terremoto; Lucas, chuva de adagas) | Q (ultimate: carga de 0 a 100 por dano causado, abates e dano recebido; não recarrega por tempo) | RB |
| Esquiva | Espaço | Não confirmado |
| Correr | Shift (gasta o mesmo fôlego) | Não confirmado |
| Trocar sombra | 1, 2, 3 | Não confirmado |
| Pausa | Esc | Start |
| Card da build | C | Select |
| Fechar painel | — | B |
| Trocar página de cartas | — | LB / RB (com o painel aberto) |

Teclas de depuração (F1, F3, F4) e as opções de linha de comando (`--fotos`, `--medir`, `--perfil`, `--mapa`, `--build`, entre outras) estão no `v2/LEIA-ME.md`.

### Regras de combate

- **Invencibilidade depois de apanhar:** o herói fica invencível por um tempo curto (`v2_combate.json > heroi.invencivel`, 0,9 s no padrão), e pisca enquanto isso.
- **Empurrão ao apanhar:** `recuo_dano` (110 px/s no padrão).
- **Ímã de almas:** o orbe de alma começa a voar para o herói a 56 px (`ima_raio`).
- **Cura por nível:** ao subir de nível, o herói recupera 12% da vida (`cura_nivel`).
- **Ruptura:** segurar E carrega e, ao soltar, racha o chão em 360 graus em volta do herói, com dano, atordoamento e empurrão. Soltar logo depois da carga cheia dá o bônus "perfeito". Valores em `dados/v2_ruptura.json`.

---

## 4. Heróis e atributos

### Heróis jogáveis da v2

Lista em `dados/v2_herois.json`. O primeiro é o padrão (Hazaki).

| Herói | Título | Vida | Velocidade | Bônus de dano | Área | Sorte | Outras notas |
|---|---|---:|---:|---:|---:|---:|---|
| Hazaki | O Samurai | 100 | 100 | ×1,0 | ×1,0 | +0% | Combo de dois cortes e uma estocada que empurra. Equilibrado. |
| Nicão | O Guardião | 180 | 78 | ×1,0 | ×1,2 | +0% | Marreta; batida larga e pancada no chão em área. Recuo ao apanhar: 70. |
| Lucas | O Caótico | 70 | 118 | ×1,0 | ×1,0 | +15% | Adagas em leque na direção da mira; segure para repetir. Recuo ao apanhar: 130. |

Notas:
- **Vida, velocidade e sorte** são os números do herói como vêm no arquivo (`cfg.heroi`); os bônus são multiplicadores. "Sorte" é a chance de uma carta comum subir para rara, somada à do santuário.
- **Mover durante o golpe** (`mov_golpe`): Hazaki 55%, Nicão 30%, Lucas 80% da velocidade de andar.
- **Escudo (botão direito):** `dados/v2_secundario.json` atribui o escudo aos três heróis.
- **Ruptura (E ou LB):** vale para qualquer herói; cada um pode ter números próprios em `dados/v2_ruptura.json`.

### Combo da katana (Hazaki, base antes dos bônus)

| Passo | Tipo | Dano | Alcance (px) |
|---|---|---:|---:|
| 1 | Corte | 12 | 46 |
| 2 | Corte | 13 | 48 |
| 3 | Estocada | 26 | 74 |

O herói tem também `vida` inicial de 100 e `pisca_hz` 14 (velocidade do pisca ao levar dano). Os valores do combo de cada herói estão em `dados/v2_combate.json` e `cfg` de cada herói.

### Atributos de partida (cartas de atributo)

Sete atributos sobem com cartas (`dados/v2_cartas.json > stats`):

| Carta | Atributo | Valor por nível | Nível máximo |
|---|---|---:|---:|
| Lâmina afiada | Dano | +15% | 8 |
| Punho ligeiro | Velocidade de ataque | +12% | 6 |
| Arco largo | Área | +12% | 6 |
| Pés de vento | Velocidade de andar | +8% | 6 |
| Alma robusta | Vida máxima | +20 | 8 |
| Ímã de almas | Alcance de almas | +35% | 5 |
| Olho de falcão | Crítico | +5% | 8 |

### Heróis da v1 (pausada)

Em `dados/herois.json` a v1 tem Hazaki, Nicão e Lucas como heróis da escolha, e os rivais do duelo (João, Matheus, Beto, Lukako, Fábio). A v1 não recebe mais atualização de conteúdo.

---

## 5. Armas, golpes e fusões

Na v2 há dois tipos de ataque:

- **Golpe principal:** a katana (combo) no clique, ou o herói do personagem escolhido.
- **Armas das cartas:** atacam sozinhas. Cada uma começa no nível 1 e sobe até o nível 5 com cartas. Os números de dano e recarga na tabela são do **nível 1**.

Os dados ficam em `dados/v2_armas/lote_1.json` a `lote_5.json` (45 armas, e os efeitos gerais em `dados/v2_cartas.json > golpes`, que soma 52 entradas: as 45 dos lotes e 7 que estão só no arquivo principal: Lâminas Rodopiantes, Aura de Fogo, Corvos Famintos, Raio em Cadeia, Runa Explosiva, Sentinela de Bambu e Cabaça de Pólvora).

### Tipos de arma

| Tipo | Como funciona |
|---|---|
| Projétil | Voa até o inimigo mais perto, em linha reta, ou em leque, ou gira. |
| Nuvem | Cai perto ou longe e fica no chão, machucando ou aplicando efeito. |
| Anel | Um anel cresce a partir do herói e empurra ou fere quem toca. |
| Meteoro | Cai num ponto com aviso no chão (meteoros, pedras, cometas, espinhos, raios). |
| Aliado | Invocação que caça ou luta sozinha (lobo, raposa, urso, golem, dragão, esqueletos). |
| Órbita, aura, corvos, raio, runa | Lâminas e Anel de Brasas giram em volta do herói; a aura queima quem chega perto; corvos caçam; raio pula de alvo em alvo; runa explode quando inimigo pisa. |

### Tabela das armas da v2 (lotes, nível 1)

Dano, recarga e quantidade são os do nível 1. Cada arma sobe até o nível 5. O texto "O que faz" vem do campo `desc`.

| Arma | Tipo | Dano (nível 1) | Recarga (nível 1) | Quantidade (nível 1) | Níveis | O que faz |
|---|---|---:|---:|---:|---:|---|
| Flechas Sombrias | projétil | 8 | 1.8 s | 1 | 5 | Dispara flechas roxas rápidas no inimigo mais perto, em linha reta |
| Adagas Voadoras | projétil | 7 | 1.2 s | 2 | 5 | Atira adagas de aço em leque curto no inimigo mais perto, sem parar |
| Lança de Geada | projétil | 14 | 3.0 s | 1 | 5 | Arremessa lança de gelo no inimigo mais perto a cada poucos segundos |
| Estrelas de Sombra | projétil | 4 | 0.9 s | 1 | 5 | Atira estrelas pretas bem seguidas no inimigo mais perto, sem parar |
| Bola de Fogo | projétil | 18 | 2.6 s | 1 | 5 | Esfera de fogo lenta que explode em área no inimigo mais perto |
| Dardos Peçonhentos | projétil | 5 | 0.9 s | 1 | 5 | Atira dardos verdes de dano baixo no inimigo mais perto, bem seguidos |
| Raio Solar | projétil | 12 | 1.4 s | 1 | 5 | Dispara um feixe dourado rápido e de longe no inimigo mais perto |
| Bumerangue de Ferro | projétil | 13 | 2.2 s | 1 | 5 | Lança um disco de ferro que atravessa até três inimigos em linha reta |
| Bolas de Chumbo | projétil | 22 | 4.5 s | 1 | 5 | Bolas de chumbo pesadas e lentas que esmagam o inimigo mais perto |
| Nuvem Venenosa | nuvem | 5 | 3.0 s | - | 5 | Uma nuvem verde cai perto de você e envenena quem ficar dentro |
| Nevoeiro Gelado | nuvem | 4 | 2.5 s | - | 5 | Uma nuvem azul cai perto de você e congela quem entra nela |
| Cinzas Vulcânicas | nuvem | 4 | 3.5 s | - | 5 | Nuvem grande de cinza cai perto de você e sufoca em pulsos seguidos |
| Fumaça Sonolenta | nuvem | 4 | 3.0 s | - | 5 | Névoa roxa cai perto de você e deixa os inimigos lentos e sonolentos |
| Chuva Ácida | nuvem | 8 | 1.8 s | - | 5 | Gotas ácidas caem numa área longe de você e corroem quem estiver nela |
| Nevasca | nuvem | 4 | 4.0 s | - | 5 | Uma nuvem branca e longa cai perto de você e atrasa quem fica nela |
| Nuvem de Esporos | nuvem | 10 | 4.5 s | - | 5 | Nuvem de esporos dourados cai perto de você e fica por muito tempo |
| Cortina de Sangue | nuvem | 18 | 4.5 s | - | 5 | Névoa verde-menta de dano alto surge perto de você, em intervalos longos |
| Névoa Espectral | nuvem | 8 | 2.8 s | - | 5 | Nuvem fantasmagórica surge ao seu lado e assombra quem chega perto |
| Onda de Choque | anel | 12 | 2.4 s | - | 5 | Um anel branco cresce a partir de você e empurra forte quem toca |
| Pulso Sagrado | anel | 6 | 1.2 s | - | 5 | Um pulso dourado sai de você a cada poucos segundos |
| Anel Gelado | anel | 5 | 1.6 s | - | 5 | Um anel de gelo sai de você, fraco mas constante |
| Grito de Guerra | anel | 14 | 4.0 s | - | 5 | Um anel ciano lento e largo sai de você de tempos em tempos |
| Terremoto | anel | 22 | 4.5 s | - | 5 | Um anel marrom rente ao chão que racha o solo de tempos em tempos |
| Martelo do Trovão | anel | 18 | 2.2 s | - | 5 | Um anel amarelo veloz e estreito sai de você com estalo |
| Rajada de Vento | anel | 5 | 0.6 s | - | 5 | Anéis verdes saem o tempo todo e empurram os inimigos para longe |
| Anel de Espinhos | anel | 12 | 2.0 s | - | 5 | Um anel de espinhos verde-escuro fere quem está perto de você |
| Anel Lunar | anel | 13 | 4.2 s | - | 5 | Um anel prateado enorme se abre ao seu redor de tempos em tempos |
| Meteoro Flamejante | meteoro | 22 | 3.0 s | 1 | 5 | Um meteoro de fogo cai perto de você a cada poucos segundos |
| Chuva de Pedras | meteoro | 7 | 2.0 s | 3 | 5 | Uma rajada de pedras cai em volta de você a cada poucos segundos |
| Cometa Gelado | meteoro | 14 | 3.5 s | 1 | 5 | Um cometa de gelo cai num ponto próximo, com aviso no chão |
| Estrelas Cadentes | meteoro | 12 | 2.2 s | 2 | 5 | Estrelas amarelas caem em pares perto de você, de tempos em tempos |
| Cometa Negro | meteoro | 25 | 4.5 s | 1 | 5 | Cometa sombrio, aviso longo e dano pesado, cai de tempos em tempos |
| Fogo do Céu | meteoro | 16 | 2.8 s | 2 | 5 | Colunas de fogo descem do céu perto de você, de tempos em tempos |
| Pedras Vulcânicas | meteoro | 5 | 1.6 s | 4 | 5 | Pedras quentes caem em volta de você, bem perto, de tempos em tempos |
| Raio Meteórico | meteoro | 13 | 2.5 s | 1 | 5 | Um raio elétrico cai num ponto distante, com aviso curto no chão |
| Chuva de Espinhos | meteoro | 5 | 0.8 s | 5 | 5 | Espinhos caem em volta de você em rajadas curtas e contínuas |
| Lobo Espiritual | aliado | 12 | 3.5 s | 1 | 5 | Um lobo espiritual caça o inimigo mais perto de tempos em tempos |
| Espírito Raposa | aliado | 5 | 2.5 s | 2 | 5 | Raposas espirituais caçam o inimigo mais perto, bem rápidas |
| Guardião de Pedra | aliado | 18 | 4.5 s | 1 | 5 | Um guardião de pedra avança devagar e esmaga quem se aproxima |
| Fantasma da Mata | aliado | 6 | 3.0 s | 2 | 5 | Fantasmas verdes saem do chão e assombram o inimigo mais perto |
| Serpente Ardente | aliado | 9 | 3.0 s | 1 | 5 | Uma serpente de fogo desliza até o inimigo mais perto e o queima |
| Espírito Urso | aliado | 20 | 4.5 s | 1 | 5 | Um urso espiritual investe contra o inimigo mais perto, com força |
| Golem de Barro | aliado | 11 | 4.0 s | 1 | 5 | Um golem de barro lento persegue o inimigo mais perto e o esmaga |
| Dragãozinho | aliado | 10 | 3.5 s | 1 | 5 | Um dragãozinho verde voa até o inimigo mais perto e cospe fogo |
| Esqueleto Guerreiro | aliado | 9 | 3.0 s | 2 | 5 | Esqueletos brancos saem do chão e perseguem o inimigo mais perto |

### Tabela das fusões (evoluções) da v2

Fusão é uma **arma nova** feita de duas ou mais armas no nível indicado. Lista em `dados/v2_cartas.json > evolucoes` (27 entradas). A fusão aparece como carta quando as peças estão no nível pedido.

| Fusão | Peças (nível mínimo de cada uma) | O que faz |
|---|---|---|
| Anel de Brasas | Aura de Fogo nv3 + Lâminas Rodopiantes nv3 | Junte Aura de Fogo e Lâminas Rodopiantes, as duas no nível 3. Seis lâminas em brasa giram dentro de um anel de fogo. |
| Revoada de Trovões | Corvos Famintos nv3 + Raio em Cadeia nv3 | Junte Corvos Famintos e Raio em Cadeia, os dois no nível 3. Sete corvos elétricos: cada bicada solta um raio no inimigo ao lado. |
| Círculo Rúnico | Runa Explosiva nv3 + explode nv2 | Junte Runa Explosiva no nível 3 e Crítico explosivo no nível 2. Muitas runas com estouros enormes, e quem sobra fica lento. |
| Ventania Cortante | onda nv2 + fura nv2 | Junte Corte ondulante e Estocada perfurante, os dois no nível 2. A onda fica enorme e a estocada solta três lanças em leque. |
| Dragão de Brasa | Dragãozinho nv3 + Serpente Ardente nv3 | Três espíritos de brasa perseguem o inimigo mais perto e ferem ao tocar. Dura 45 s e some. |
| Caçada Espiritual | Lobo Espiritual nv3 + Espírito Raposa nv3 | Lobo e raposa espirituais caçam juntos o inimigo mais perto. Dura 45 s e some. |
| Urso Solar | Espírito Urso nv3 + Raio Solar nv3 | Feixes dourados atravessam até quatro inimigos em linha reta. |
| Exército Esquecido | Esqueleto Guerreiro nv3 + Fantasma da Mata nv3 | Esqueletos e fantasmas saem juntos e perseguem o inimigo mais perto. Dura 50 s e some. |
| Colosso de Pedra | Golem de Barro nv3 + Guardião de Pedra nv3 | Um colosso de pedra e barro, lento e pesado, bate forte a cada segundo. Dura 60 s e some. |
| Chuva de Lâminas | Flechas Sombrias nv3 + Adagas Voadoras nv3 | Três lâminas voam de uma vez no inimigo mais perto. |
| Bola Incendiária | Bola de Fogo nv3 + Bolas de Chumbo nv3 | Projéteis pesados explodem ao cair e ferem quem está perto. |
| Nevasca Congelante | Nevoeiro Gelado nv3 + Nevasca nv3 | Uma nevasca larga desacelera quem fica dentro dela. |
| Cinzas Ácidas | Cinzas Vulcânicas nv3 + Chuva Ácida nv3 | Uma nuvem de cinza ácida cai perto do herói e corrói os inimigos. |
| Estrondo | Onda de Choque nv3 + Grito de Guerra nv3 | Um grito de guerra em onda empurra tudo com força. |
| Terra Partida | Terremoto nv3 + Martelo do Trovão nv3 | O chão racha em anéis que levantam os inimigos. |
| Pedreira Ardente | Chuva de Pedras nv3 + Pedras Vulcânicas nv3 | Quatro pedras em brasa caem em volta do herói. |
| Cometa Duplo | Cometa Gelado nv3 + Estrelas Cadentes nv3 | Dois cometas caem juntos sobre inimigos próximos. |
| Chuva de Ferro | Bumerangue de Ferro nv3 + Rajada de Vento nv3 + Meteoro Flamejante nv3 | Projéteis de ferro atravessam inimigos e explodem no fim. |
| Peste Negra | Dardos Peçonhentos nv3 + Nuvem Venenosa nv3 + Fumaça Sonolenta nv3 | Uma névoa de peçonha se espalha e não sai de perto do herói. |
| Juramento Sagrado | Anel de Espinhos nv3 + Pulso Sagrado nv3 + Névoa Espectral nv3 | Anéis sagrados se abrem e sopram os inimigos para longe. |
| Eclipse Negro | Cometa Negro nv3 + Fogo do Céu nv3 + Cortina de Sangue nv3 | Dois cometas negros e uma cortina de sangue caem sem trégua. |
| Tempestade Primordial | Lança de Geada nv5 + Estrelas de Sombra nv5 + Bumerangue de Ferro nv5 + Raio Solar nv5 | Lanças e pedras perfuram; cada impacto puxa os inimigos para o ponto. |
| Eclipse de Almas | Lobo Espiritual nv5 + Espírito Raposa nv5 + Fantasma da Mata nv5 + Espírito Urso nv5 | Espíritos prendem o inimigo; quem já está preso leva dano em dobro. Dura 50 s e some. |
| Juízo Final | Cometa Negro nv5 + Fogo do Céu nv5 + Meteoro Flamejante nv5 + Raio Meteórico nv5 | Cada meteoro que cai chama outro sobre o inimigo mais perto. |
| Furacão Glacial | Nevasca nv5 + Nevoeiro Gelado nv5 + Anel Gelado nv5 + Lança de Geada nv5 | Nuvem gelada; inimigos lentos dentro dela levam dano em dobro. |
| Pagode do Trovão | Sentinela de Bambu nv3 + Raio em Cadeia nv3 | Junte Sentinela de Bambu e Raio em Cadeia, os dois no nível 3. Uma torre de duas camadas cujos virotes viram arcos elétricos e saltam entre os inimigos. Dura 45 s e some. |
| Fogos de Festival | Cabaça de Pólvora nv3 + Bola de Fogo nv3 | Junte Cabaça de Pólvora e Bola de Fogo, as duas no nível 3. Cada estilhaço estoura de novo numa chuva de fogos coloridos. |

A arte das fusões fica em `assets/v2/fusoes/` (ver [seção 12](#12-arte-e-animação)).

### Modificadores do golpe da katana

Oito modificadores (`dados/v2_cartas.json > modificadores`), cada um com um valor de `{v}`%:

- **Corte ondulante:** cada corte solta uma onda do dano (Hazaki).
- **Estocada perfurante:** a estocada solta uma lança que atravessa.
- **Crítico explosivo:** o crítico explode em área.
- **Fôlego de caçador:** cada abate devolve uma carga de fôlego.
- **Abalo sísmico:** a pancada no chão solta uma onda de choque.
- **Peso de muralha:** os golpes empurram e atordoam mais.
- **Chuva de adagas:** cada adaga que acerta pode soltar outra (Lucas).
- **Mira longa:** as adagas voam mais longe e mais rápido (Lucas).

### Elementos

A v1 tinha um sistema de elementos com reações entre fogo, gelo, raio e veneno (`dados/elementos.json`). Na v2 as cores e os efeitos dos golpes seguem a mesma ideia (fogo laranja, gelo azul, veneno verde, raio elétrico, arcano roxo), mas **as reações entre elementos na v2 não encontrado** nesta pesquisa.

### Escudo

O escudo é o secundário (botão direito) dos três heróis. Segurar ergue um escudo na frente do herói, na direção da mira (`v2/escudo.gd`).

---

## 6. Cartas e melhorias

A cada nível (e nos baús) o jogo oferece **cartas**. Os dados ficam em `dados/v2_cartas.json`.

### Raridades

| Raridade | Multiplicador do número da carta | Bônus de dano no golpe secundário por carta |
|---|---:|---:|
| Comum | ×1,0 | +0% |
| Raro | ×1,5 | +18% |
| Épico | (em `dados/v2_cartas.json`) | (em `dados/v2_cartas.json`) |
| Lendário | (em `dados/v2_cartas.json`) | (em `dados/v2_cartas.json`) |

A chance de raridade alta sobe com o nível: o peso de cada raridade anda em linha reta entre o nível 1 e o `nivel_fim` (`peso_ini` e `peso_fim` no arquivo).

### Tipos de carta

- **Atributos** (sete, ver [seção 4](#atributos-de-partida-cartas-de-atributo)).
- **Armas e golpes** (ver [seção 5](#5-armas-golpes-e-fusões)): cartas que dão uma arma nova ou sobem uma arma que você já tem.
- **Fusões:** só aparecem quando as peças estão no nível pedido.
- **Modificadores** do golpe da katana.
- **Ruptura:** cinco melhorias próprias (dano, recarga, atordoamento, contragolpe, eco).

### Escolha

- Quantas cartas aparecem por tela e quantas vezes você pode **rerrolar** (trocar as cartas) estão em `escolha` no mesmo arquivo.
- Há **banir** (tirar uma carta da mesa) e **garantir golpe** (uma carta de golpe aparece até um nível-alvo).
- Os campos `auto_*` servem para a escolha automática do robô de playtest (issue [#301](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/301), fechada).

---

## 7. Inimigos, elites e chefes

### Monstros comuns (v1)

A v1 tem **51 tipos de inimigo** em `dados/inimigos.json`, cada um com o campo `conjunto` que diz em qual região ele aparece. Exemplos: Bug, Popup, Spam, Trojan, Cão de Ossos, Cavaleiro Oco, Espectro, Aranha Tecelã, Espantalho, Sapo Podre, Jacaré de Lodo, Escorpião Gigante, Naja, Diabrete de Gelo, Urso de Gelo, Gigante da Tempestade, Soberano do Caos.

### Monstros da v2 e elites

A v2 usa os inimigos e as **elites** de `dados/v2_cartas.json > elites`:

- **Elite:** uma versão mais forte que aparece de tempos em tempos. A primeira aparece aos 45 s e depois a cada 50 s, com no máximo 2 vivas ao mesmo tempo (valores em segundos do arquivo).
- **Multiplicadores da elite:** vida ×6, dano ×1,5, experiência ×3, 4 orbes extras, tamanho ×1,5.
- **Tipos de elite:** Cão de Ossos e Aranha Tecelã (desde o início), Lobo Sombrio (60 s), Espantalho (100 s), Cavaleiro Oco (160 s).
- **Modificadores de elite:** por exemplo "Veloz" (velocidade ×1,7).

### Mini-chefes e chefes (v2)

Definidos em `dados/v2_cartas.json > chefes > marcas`:

| Marca | Nome | Vida base | Dano base | Ataques |
|---|---|---:|---:|---|
| mini1 | Cavaleiro Rubro | 1100 | 20 | estouro, chuva |
| mini2 | Rainha Tecelã | 3000 | 26 | estouro, investida, chuva |
| chefe | Rei Espantalho | 9000 | 34 | estouro, chuva, investida, chuva |

- **Estouro:** um aviso no chão e uma explosão em área.
- **Chuva:** cinco pancadas em sequência que espalham pelo chão.
- **Investida:** um avanço em linha reta com aviso.
- **Fase 2 do chefe:** `chefes.fase2` vale 0,5 no arquivo (o detalhe de como a fase 2 funciona está no `v2/chefe.gd`).

Em cada mapa, os chefes aparecem nos níveis indicados (ver [seção 8](#8-mapas-e-regiões)), e a vida deles é multiplicada pelo fator do mapa (de 1,3 a 2,8).

---

## 8. Mapas e regiões

### Mapas da v2 (como estão hoje)

A lista de mapas está em `v2/mapas.gd`. Cada um tem um arquivo de dados em `dados/v2_<id>.json` e um arquivo de níveis em `dados/v2_niveis.json`.

| Mapa | Níveis | Duração de cada nível | Chefes (nível: marca) | Tamanho do mundo | Como abre |
|---|---:|---:|---|---|---|
| Floresta | 30 | 20 s | 10: mini1 · 20: mini2 · 30: chefe | 2880×1620 (3×3 telas) | Aberta |
| Laboratório | 40 | 20 s | 10, 20: mini1 e mini2 (vida ×1,3) · 30: mini1 (×1,5) · 40: chefe (×1,6) | 2880×1620 | Vencer a Floresta |
| Cidade | 50 | 20 s | 10 e 20 (×1,5) · 30 e 40 (×2,2 e ×2,4) · 50: chefe (×2,6) | 2880×1620 | Vencer o Laboratório |
| Ruínas da Floresta | 60 | 20 s | 10 e 20 (×2,0) · 30 a 50 (×2,2 a ×2,6) · 60: chefe (×2,8) | ~1 min 30 de caminhada, mapa médio | Vencer a Cidade |

- A duração da partida é o número de níveis vezes 20 s, mais o tempo que você leva para vencer cada chefe (o nível fica travado até ele morrer). Floresta: 10 min de níveis; Ruínas: 20 min.
- **Pesadelo:** o modo multiplica o tempo dos chefes por 0,8 (aparecem 20% mais cedo).
- Os mapas têm **estruturas e marcadores**: baús, baú trancado (precisa de chave), ruínas que dão a chave, altares, passagens, portões e torres (no mapa médio).
- O **minimapa** está em `v2/minimapa.gd`. A arte das estruturas do Marco 4 (mapa fechado com relevo) está em `assets/v2/marco4/`.

Mapas e regiões são responsabilidade do Alisson (ver [seção 16](#16-quem-faz-o-quê)); este documento só descreve o que existe.

### Regiões da v1 (pausada)

A v1 atravessa **cinco regiões** com seis andares cada (`dados/regioes.json`):

| # | Região | Ideia |
|---|---|---|
| 1 | Floresta Sombria | Árvores retorcidas e coisas que andam entre elas. |
| 2 | Pântano Pútrido | Lama, névoa verde e afogados. |
| 3 | Deserto de Ossos | Sol que não se põe, caravanas mortas. |
| 4 | Pico Congelado | Vento que corta, gelo que não derrete. |
| 5 | Reino Sombrio | Onde o caos começou. |

Cada região tem um chefe no último andar. A dificuldade sobe de região em região (`calor`).

---

## 9. Baús, itens e relíquias

### Baús (v2)

- Os baús ficam nos marcadores do mapa. Alguns caem ao chegar; outros são trancados e pedem a chave das ruínas.
- Ao abrir, aparece uma **roleta** de cartas (`dados/v2_cartas.json > bau`): o giro dura 1,5 s e a pausa 0,45 s.
- Mini-chefes soltam baú. O chefe final não solta (`chefes.marcas[].bau`).

### Itens da mochila (v1)

A v1 tem mochila e itens em `dados/itens.json`: comida (vale pelos primeiros andares), consumíveis (teclas 1, 2 e 3; somem ao usar) e amuletos (um no pescoço, efeito passivo). Tipos de efeito: cura, buff, escudo, explosão, lentidão, ímã, fênix (levanta uma vez). Na v2 não encontrei uso da mochila.

### Relíquias

**Não encontrado** como sistema na v2. Há uma menção no código da v2 (`v2/mundo.gd`), mas nenhum dado de relíquia em `dados/v2_*.json`. O tema está previsto no Marco 5 (issue [#129](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/129)), ainda aberto.

---

## 10. Meta-progressão: almas, santuário e conquistas

### Almas

- **Almas** são a moeda permanente. Cada partida soma as almas que trouxe (`Meta.almas_partida`), e o saldo fica no save da meta-progressão (`user://v2_progresso.cfg`, separado do save da v1).
- No santuário você gasta almas em **melhorias**.

### Melhorias (`dados/v2_meta.json`)

| Melhoria | Efeito | Nível máximo | Custo do 1º nível |
|---|---|---:|---:|
| Vigor da mata | Vida inicial | 5 | 40 |
| Gume de herança | Dano inicial | 5 | 40 |
| Passos de caçador | Velocidade de andar | 5 | 50 |
| Fôlego de corredor | Fôlego máximo | 4 | 40 |
| Ímã de almas | Alcance de almas | 4 | 35 |
| Olho para o raro | Chance de carta rara | 4 | 60 |
| Segunda chance | Rolagem extra nas cartas | 2 | 90 |
| Almas abundantes | Almas por partida | 5 | 50 |
| Treino de guerreiro | Velocidade de ataque | 4 | 70 |

Cada nível seguinte custa o anterior vezes um fator (`cresce`).

### Conquistas (sete)

| Conquista (id) | Nome |
|---|---|
| sobreviva_5min | Sobreviva 5 minutos |
| derrota_chefe | Derrote o chefe |
| combo_50 | Combo de cinquenta |
| vence_floresta | Vença a Floresta |
| vence_laboratorio | Vença o Laboratório |
| vence_cidade | Vença a Cidade |
| vence_medio | Vença as Ruínas |

As condições exatas de cada uma estão em `dados/v2_meta.json > conquistas` (o nome é o que aparece para o jogador). Vencer um mapa é a conquista `vence_<mapa>`, cumprida ao derrotar o chefe final dele.

### Modo Pesadelo

Ligado no santuário antes da partida (`dados/v2_meta.json > modos`):

- Monstros com **vida ×1,5** e **dano ×1,25**.
- Hordas **30% mais densas**.
- Chefes aparecem **20% mais cedo**.
- Almas **×1,5**.

### Santuário

O santuário (`v2/altar.tscn`, `v2/salao.gd`) tem estruturas:

| Estrutura | Abre com |
|---|---|
| Estátuas | Desde o começo |
| Altar | Vencer a Floresta |
| Códice | Primeira conquista (qualquer) |

Os mapas se abrem em cadeia: Floresta → Laboratório → Cidade → Ruínas (`dados/v2_progressao.json`).

Personagens: o santuário oferece quem pode ser criado (`dados/v2_salao.json`). Um personagem novo tem herói, arma inicial, retrato e estruturas próprios.

---

## 11. HUD e menus

- **Barra de vida e fôlego**, **barra de experiência** e **nível** (`hud.gd`, `hud_nivel.gd`).
- **Golpes e cartas ativas** no canto (`hud_golpes.gd`, `hud_habilidades.gd`).
- **Minimapa** (`minimapa.gd`).
- **Anúncios** de chefe, mini-chefe e vitória (`hud_anuncios.gd`, `dados/v2_cartas.json > anuncios`).
- **Card da build (C ou Select):** mostra as cartas e melhorias da partida. Compacto no HUD; painel central sobre a escolha e os baús (`status.gd`).
- **Escolha de cartas** (`cartas.gd`) e **roleta do baú** (`bau.gd`).
- **Menu de pausa** (Esc ou Start, `pausa.gd`) e **opções/ajustes** (`ajustes_graficos.gd`, perfis de gráficos baixo, médio e alto, e a opção de verificar versão).
- **Título, personagens e santuário** (`menu_principal.gd`, `personagens_tela.gd`, `salao.gd`).
- **Resultado** da partida (`resultado_meta.gd`).
- **Créditos** (`creditos.gd`).
- **Aviso de versão nova** (`atualizador.gd`, ver [seção 15](#15-testes-ci-export-e-como-jogar)).

Antes de mexer em menu ou UI da v2, o documento de referência é `jogos/hordas/projeto/v2/DESIGN.md`. A direção visual do HUD e dos menus está em `docs/visual_2_5d/hud_menus.md`.

**Legibilidade:** o texto do jogo precisa ser legível. Fontes pixeladas pequenas não se leem; o HUD usa texto nítido sobre painéis escuros translúcidos.

---

## 12. Arte e animação

### Direção visual

O jogo é **2.5D**: roda 2D por dentro (Godot), mas parece ter volume. Vem da câmera inclinada (vista de cima com primeiro plano), da luz dinâmica (lanternas, tochas, portal, magias), da pixel art mais densa, dos efeitos fortes por elemento e do HUD de alta resolução. Documentação: `docs/visual_2_5d/README.md`.

Fases da direção visual (épico [#152](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/152), aberto): V0 preparação; V1 base de resolução, câmera e HUD; V2 luz com relevo; V3 cenário com profundidade; V4 heróis e monstros na densidade nova; V5 efeitos por elemento; V6 menus no mesmo visual.

### Sprites e direções

- **Personagens e monstros** são sprites com **8 direções**, gerados a partir de modelos 3D do Blender (`fonte_arte/modelos3d/`). O código espelha esquerda e direita.
- **Armas e invocações** saem de folhas de quadros em `assets/v2/armas_anim/`: 138 tiras PNG e 8 índices (um por tipo de arma).
- **Efeitos e fusões** ficam em `assets/v2/efeitos/` e `assets/v2/fusoes/`.

### Animação de combate (PR #343, já na main)

O combate das armas secundárias ganhou fases: **preparo, execução, impacto e recuperação**. Antes, cada golpe era uma imagem parada. Agora o projétil nasce com fase própria, o impacto tem quadros e marcas, e a hitbox acompanha a fase. Detalhes e os GIFs (4×, sem suavizar) em `docs/combate_v2/ENTREGA.md`.

### Regras de arte nova

- **Arte nova vai em arquivos novos**, sem sobrescrever a arte existente.
- **Nada de arte com direitos autorais.** Arte de terceiros só entra se a licença permitir uso comercial, redistribuição no jogo e modificação. Registro obrigatório em `docs/LICENCAS_ARTE.md` (fonte, autor, licença, mudanças) e crédito na tela de Créditos quando a licença pedir.
- **Em dúvida, não usa.** Pack pago só com o OK do Breno.
- **Pipeline de animação** (decisão do Breno, 15/10): as animações são feitas no Blender, seguindo `docs/animacoes_armas_v2.md`. A tabela diz quadros, FPS e direções por tipo.
- **Sprite animado a partir de referência** (aprovado em 16/10): a imagem de referência é a base, os quadros são reordenados pela fase real do movimento, alinhados pelo chão e reduzidos para a escala do jogo.

### Estilo dos chefes da v3

Os chefes da v3 não seguem o pipeline de sprites: são **modelos 3D reais animados em tempo real na Godot**, com câmera isométrica ortográfica e aparência pixelizada (shader toon, contorno de 1 px). Ver [seção 18](#18-roteiro-da-v3).

---

## 13. Áudio

- **Trilha por momento** (`dados/v2_musica.json`): santuário (faixa `menu`), partida (`minijogo_tenso`), chefe (`chefe`) e resultado (`fim`). Os mini-chefes aos 3 e 6 minutos e o chefe dos 10 minutos usam a faixa de chefe; ao cair um mini-chefe, a partida volta à sua faixa.
- **Arquivos** ficam em `assets/audio/musica/` (formato `.ogg`).
- **Volume** pelo controle **Música** nos Ajustes (bus `Musica`, `som.gd`).
- **Origem e licença** de cada arquivo: `docs/LICENCAS_AUDIO.md` (e `docs/LICENCAS_ARTE.md` para arte).
- Efeitos sonoros ficam no `v2/audio.gd`. A lista completa de efeitos sonoros **não encontrado** nesta pesquisa.

---

## 14. Arquitetura técnica

### Motor e versão

- **Godot 4.4.1** (mesma versão no CI e no PC do trabalho).
- Projeto em `jogos/hordas/projeto/` (`project.godot`).

### Estrutura de pastas

| Pasta | O que tem |
|---|---|
| `jogos/hordas/projeto/v2/` | O jogo novo: 75 scripts (`.gd`), cenas (`.tscn`), `DESIGN.md` e `LEIA-ME.md` |
| `jogos/hordas/projeto/scripts/` | Código da v1 e utilitários comuns (94 scripts), a v1 pausada |
| `jogos/hordas/projeto/dados/` | Números e textos em JSON, quase todos com campo `_ajuda` explicando |
| `jogos/hordas/projeto/assets/` | Arte, áudio e fontes |
| `jogos/hordas/projeto/testes/` | Cenas e scripts de teste (129 `.gd`, 128 `.tscn`) |
| `jogos/hordas/projeto/prototipos/` | `cara_nova`, o protótipo 2.5D congelado (referência) |
| `jogos/hordas/projeto/addons/` | Plugins da Godot |
| `jogos/hordas/fonte_arte/` | Fonte da arte: Blender, geradores em Python, prompts e LEIA-ME |
| `ferramentas/` | Scripts de CI e de apoio (testes, ortografia, GIFs, playtest) |
| `docs/` | Documentação de design, arte, licenças e entregas |
| `.github/workflows/` | CI (`ci.yml`) e export (`release.yml`) |

### Cenas principais

| Cena | Para quê |
|---|---|
| `v2/menu_principal.tscn` | Título (cena principal) |
| `v2/altar.tscn` | Santuário |
| `v2/mundo.tscn` | A partida. Abre direto com `res://v2/mundo.tscn` |
| `main.tscn` | v1, com `-- --v1` |

### Scripts principais da v2

| Script | O que faz |
|---|---|
| `mundo.gd` | Monta a partida e roda a ordem do quadro (`avancar(dt)`) |
| `combate.gd` | Laço de combate: dano, i-frames, empurrão, golpe da katana |
| `heroi.gd` | O herói: movimento, golpes, esquiva, fôlego |
| `armas.gd` / `armas_novas.gd` | Armas das cartas e os golpes secundários (fases de preparo e impacto) |
| `anim_golpes.gd` | Toca os quadros das folhas de animação |
| `cartas.gd` | Escolha de cartas e rerrolagem |
| `bau.gd` | Baús e a roleta |
| `diretor.gd` | Quem nasce e quando (ondas, elites, chefes) |
| `chefe.gd`, `elites.gd` | Chefes e elites |
| `monstro.gd` | Comportamento dos monstros |
| `cenario.gd` | Lê `dados/v2_<mapa>.json` e monta o mapa |
| `mapas.gd`, `progressao.gd` | Lista de mapas e travas dos portais |
| `meta.gd` | Almas, melhorias, conquistas e save |
| `salao.gd`, `altar.gd` | Santuário |
| `status.gd` | Card da build (cartas e melhorias da partida) |
| `hud.gd`, `hud_golpes.gd`, `hud_habilidades.gd`, `minimapa.gd` | HUD |
| `ruptura.gd`, `escudo.gd` | Ruptura (E) e escudo (botão direito) |
| `qualidade_auto.gd`, `ajustes_graficos.gd` | Perfis de gráficos e ajuste automático |
| `atualizador.gd` | Aviso de versão nova |

### Dados

Os números do jogo estão em `dados/` (JSON). Os da v2 têm o prefixo `v2_`:

| Arquivo | Assunto |
|---|---|
| `v2_herois.json` | Heróis jogáveis |
| `v2_secundario.json` | Tiro secundário (escudo) por herói |
| `v2_combate.json` | Golpe da katana, herói, laço de combate |
| `v2_ruptura.json` | Ruptura (E): dano, carga, recarga, cartas |
| `v2_cartas.json` | Cartas, raridades, golpes, modificadores, fusões, elites, chefes, baús |
| `v2_armas/lote_1..5.json` | As 45 armas novas |
| `v2_meta.json` | Almas, melhorias, conquistas, modo Pesadelo |
| `v2_progressao.json` | Quais mapas e estruturas abrem, e como |
| `v2_niveis.json` | Níveis, duração e chefes de cada mapa |
| `v2_floresta.json`, `v2_laboratorio.json`, `v2_cidade.json`, `v2_medio.json` | Mapas (objetos, luz, colisão, marcadores) |
| `v2_salao.json` | Personagens do santuário e estruturas |
| `v2_musica.json` | Trilha por momento |

Os dados da v1 (`armas.json`, `inimigos.json`, `regioes.json`, `itens.json` etc.) continuam no repositório, sem uso na v2 salvo quando portados.

### Saves

- **v2:** `user://v2_progresso.cfg` (almas, melhorias, conquistas, mapa escolhido, personagem, opções).
- **v1:** save separado, não mexido pela v2.
- Teste de guarda do save: `ferramentas/teste_guarda_save.py`.

### Desempenho

O PC do Breno é fraco (i5-3470, vídeo fraco). Por isso:
- Perfil de gráficos **Baixo** é a meta mínima.
- Medições de FPS ficam nos arquivos `v2/fps_*.txt`.
- `qualidade_auto.gd` faz o ajuste automático de qualidade (detalhes no próprio script).
- Hordas, partículas e luzes têm limites por fase (Marco 3, #127, aberto).

---

## 15. Testes, CI, export e como jogar

### Testes locais

Rodar uma cena de teste:

```bash
godot --headless --path jogos/hordas/projeto res://testes/<nome>.tscn
```

Uma cena passa só com código de saída 0, a linha `falhas=0` e sem `SCRIPT ERROR`. O limite é de 120 s por cena (300 s para `regras_armas`).

Rodar a suíte inteira (como o CI):

```bash
bash ferramentas/testes_ci.sh <caminho-do-godot> 4
```

### CI (`.github/workflows/ci.yml`)

Roda em todo pull request, e também quando o export chama o CI (ver abaixo):

| Job | O que faz |
|---|---|
| `testes` | Importa o projeto e roda todas as cenas de `testes/` em **3 shards** (4 em paralelo cada), com Godot 4.4.1 no Ubuntu. |
| `ortografia` | Verifica o português com hunspell `pt_BR` (`ferramentas/ortografia.py`). |
| `python_testes` | Teste do save (`teste_guarda_save.py`). |
| `gdlint` | Estilo do GDScript. Só aviso: não bloqueia. |
| `gdformat` | Formatação do GDScript (`gdformat -l 160 --check`). Bloqueia se estiver fora do padrão. |

### Export (`.github/workflows/release.yml`)

Roda em push na main, **ignorando** mudanças só em `docs/`, `**/*.md` e `LOGBOOK.md`:

1. Passa pelo CI inteiro.
2. Exporta **Linux** e **Web** (Ubuntu).
3. Exporta **Windows** (runner Windows, porque o `.exe` precisa do rcedit para ícone e versão).
4. Publica uma Release com a tag `build-AAAA-MM-DD-<sha>`.

A publicação automática chegou a ser bloqueada pela cota de artefatos do Actions (issue [#249](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/249), fechada).

### Atualizador e Releases públicas

- O repositório público de versões é **KIKIU-Releases** (criado em 18/10). O atualizador (PR #341) consulta primeiro a Release mais recente dele e, se não houver, cai para o KIKIU-Survival (`v2/atualizador.gd`).
- O atualizador **só avisa** que há versão nova. Não baixa nem troca nada.
- Pendência: o Breno precisa criar o segredo **RELEASES_TOKEN** para o workflow publicar no KIKIU-Releases. Ainda não criado.

### Como atualizar e jogar (PC de casa)

Segundo as notas de coordenação do projeto, no PC de casa existe o atalho **"Atualizar e Jogar KIKIU v2.bat"** na Área de Trabalho. Ele atualiza o jogo pelo git em `D:\dev\kikiu` e abre a versão nova; não é preciso gerar zip. (`ferramentas/jogar_kikiu.ps1` existe no repositório; não confirmei se é ele que o atalho usa.)

---

## 16. Quem faz o quê

Divisão de trabalho (`CLAUDE.md`, decisões do Alisson e do Breno):

| Quem | Fica com |
|---|---|
| **Claude do Alisson** (PC e notebook) | Todo o código do jogo: sistemas e arquitetura, heróis e habilidades, save, desempenho, online, CI e testes, e a parte visual em código (efeitos, animações, luz, shaders, UI). Integração entre PRs e mesclagem. **Mapas, regiões, estruturas e exploração.** |
| **Codex do Alisson** | Geração de imagem (folhas de sprite, arte de título e cenário, ícones). Com a etiqueta `para-o-codex`, também integração de branches, testes e PRs. |
| **Claude do Breno** | Ajuste de números em `dados/*.json`, textos e descrições, conteúdo dos amigos (falas e nomes), testes de release no PC de trabalho, relatórios em issue. Decisões do Breno em uma linha. Ações de admin do GitHub. |
| **Breno** | Decide o que é do jogo, joga, aprova. A única parada obrigatória é a aprovação final de cada entrega. Faz as ações de admin do GitHub que só a conta dele faz (como criar o segredo RELEASES_TOKEN). |
| **Animações das armas** | Breno com o Claude dele, no Blender (decisão de 15/10). Arte nova em arquivos novos. |
| **Mapas** | Alisson (decisão de 15/10). O Claude do Breno não mexe em mapas. |

Regras para ninguém pisar no outro: quem reserva primeiro fica com a tarefa (PR em rascunho ou comentário na issue), cada um fica na sua área de arquivos, quem integra conflito é o Claude do Alisson, e cada um mescla só os próprios PRs com CI verde.

---

## 17. Marcos e o que falta para fechar a v2

### Marcos do plano (épico [#134](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/134), "Roguelike de ação com controle")

| Marco | Issue | Assunto | Estado |
|---|---|---|---|
| 0 | [#124](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/124) | Fundação: CI, export automático, lint, ortografia | **Fechado** |
| 1 | [#125](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/125) | Legibilidade e HUD limpo | Aberto |
| 2 | [#126](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/126) | Esquiva com i-frames e mira direcional | Aberto |
| 3 | [#127](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/127) | Performance: MultiMesh, limite por fase, atlas | Aberto |
| 4 | [#128](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/128) | Mapa fechado com relevo, estruturas e minimapa | **Fechado** (mas o mapa segue com o Alisson) |
| 5 | [#129](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/129) | Baús fixos, relíquias e exploração como poder | Aberto |
| 6 | [#130](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/130) | Habilidades ativas por classe e fusões com efeito ativo | Aberto |
| 7 | [#131](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/131) | Meta-progressão: almas, árvore de 12 nós, desbloqueios, códice | Aberto (a v2 já tem almas, melhorias e códice) |
| 8 | [#132](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/132) | Identidade visual e página pública (itch.io, build web, trailer) | Aberto |
| 9 | [#133](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/133) | Online de volta e duelo entre amigos | Aberto |

### Outras frentes abertas

- **Épico 2.5D** ([#152](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/152)): fases V1 a V6.
- **Equilíbrio** ([#137](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/137)): calibrar jogando, precisa de gente jogando.
- **Fechamento da v2** ([#342](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/342)): meta de fechar até 23/10.
- **Colisão** ([#336](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/336)): colisão com barreiras só perto da tela.
- **Arte do Marco 4** ([#244](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/244)) e **mapas gerados por semente** ([#243](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/243)): com o Alisson.
- **Reexibir cartas escondidas** ([#213](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/213)).
- **Gráficos estilo AAA** ([#150](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/150)): perfis e seções de CPU e GPU.
- **Atualizador** ([#106](https://github.com/brenoalmeidatec/KIKIU-Survival/issues/106)): falta o segredo RELEASES_TOKEN.

### O que falta para fechar a v2

Pelo estado das issues em 19/10:

1. Conferir o que falta nas animações das armas (o PR #343 já entrou; a tabela de `docs/animacoes_armas_v2.md` define o restante).
2. Calibrar o equilíbrio jogando (#137).
3. Resolver o que sobrou dos mapas com o Alisson (#243, #244).
4. Levar o visual 2.5D ao HUD e aos menus (fases V1 e V6 do épico #152).
5. Liberar o segredo do atualizador (RELEASES_TOKEN) para a Release de versões.
6. Testar a build no PC de trabalho e no PC de casa, e fechar o que aparecer no playtest.

O que está **fora** da v2 e vai para a v3 não entra nessa lista.

---

## 18. Roteiro da v3

A v3 é planejada e fica **separada** da v2 (branch `chefes/floresta`, pastas `docs/v3` e `v3/godot`), sem ligar ao jogo atual.

- **Chefes da Floresta:** Vornak, Nythrax e Maltherion. Ficam prontos e funcionando, mas separados. A folha conceitual do Vornak está em `docs/v3/chefes/referencias/vornak_folha_conceitual.png` na branch `chefes/floresta`.
- **Visual dos chefes:** modelos 3D reais animados em tempo real na Godot, câmera isométrica ortográfica, aparência pixelizada (resolução interna 640×360 ou mais, paleta de 24 a 40 cores, 4 a 5 tons por material, texturas de 512 px). Exportação do Blender em glTF 2.0, com rig e ações.
- **Não** é sprite 2D nem quadro pré-renderizado.
- **Entrada no jogo:** nenhuma por enquanto. A v2 continua como está.

---

## 19. Glossário

| Termo | Significado |
|---|---|
| Arma | Ataque que atira ou age sozinho, vindo de uma carta |
| Golpe principal | Katana (ou herói) no clique do mouse |
| Secundário | Escudo, no botão direito |
| Ruptura | Carga da tecla E que racha o chão em volta do herói |
| Fusão | Arma nova feita de duas ou mais armas no nível pedido |
| Elite | Monstro mais forte que aparece de tempos em tempos |
| Mini-chefe | Chefe de meio de mapa; solta baú |
| Chefe | Chefe do último nível; vencer termina o mapa |
| Alma | Moeda permanente, gasta no santuário |
| Santuário | Tela entre partidas (`altar.tscn`) |
| Pesadelo | Modo de dificuldade alta, com mais almas |
| Baú | Caixa do mapa que abre uma roleta de cartas |
| Build | Conjunto de armas, cartas e melhorias de uma partida |
| v1 / v2 / v3 | v1 pausada; v2 em desenvolvimento; v3 planejada com chefes em 3D |
| Marco | Etapa do plano de desenvolvimento, uma issue cada |
| `para-o-codex` | Etiqueta de issue que dá trabalho pesado de código ao Codex do Alisson |
| `para-o-breno` | Etiqueta de issue com tarefas leves para o Breno |
