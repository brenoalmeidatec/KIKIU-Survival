# Referência "KiKiu" (vídeo de 15/10/2026): animações, golpes e efeitos

Análise de **movimento e timing** do vídeo `Referencia KiKiu.MP4` que o Alisson mandou como referência. Nada do vídeo (arte, sprite, quadro) entra no jogo: serve só para entender *como* as coisas se mexem, para a gente construir o nosso do zero (regra de licenças do `CLAUDE.md`). As folhas de contato desta pasta são recortes pequenos e de baixa resolução, só para consulta interna da análise.

Escrito por Claude do Alisson (PC), 2026-10-15.

## 1. O que é o vídeo e o que dá (e não dá) para medir

É um trailer vertical de TikTok de um RPG de ação em pixel art com visão de cima e **efeitos 2D em alta**, de outro estúdio: 78,4 s, **30 fps (2352 quadros)**, **464×824**, com legenda grande e marca d'água por cima. Só ~55 s têm jogo rodando (o resto é árvore de habilidades, crafting/construção, tela de compra). A janela de jogo útil ocupa ~464×520 no meio do quadro.

**Limites honestos desta análise:**
- A resolução é baixa e o vídeo é recomprimido (TikTok), então eu medi **tempos e quantidade de quadros por fase** (contando quadros nas folhas a 30 fps e a 10 fps), mas **não** dá para contar quadros de ciclo de caminhada/corrida dos personagens: os sprites têm ~20–30 px na tela e o trailer corta quase sempre antes de mostrar um ciclo completo. Onde aparece andar/correr, descrevo só o que se vê (pose, rastro, poeira).
- Os números abaixo são **estimativas de ±1–2 quadros** (±0,05 s). Servem para calibrar sensação, não para copiar valor.
- O trailer é montado: vários trechos são cortes de 1–2 s com câmera aproximada. Parte do "peso" que se sente é edição, não jogo.
- Ignorei história, áudio e texto, como pedido. Não foi possível avaliar ritmo de som (sem conferir áudio), só imagem.

Método: amostra a 1,5 fps do vídeo inteiro (3 folhas) para mapear; depois folhas a 10 fps (4,8 s cada) dos trechos de combate (2,5 s, 18 s, 22,8 s, 27,6 s, 32,4 s, 37,2 s) e folhas a **30 fps nativos** (1,6 s cada, 48 quadros, lidas da esquerda para a direita e de cima para baixo) dos golpes e efeitos principais. As 12 folhas estão nesta pasta.

## 2. Catálogo (tempo no vídeo, quadros, fases)

Notação: "q" = quadros a 30 fps (1 q ≈ 0,033 s). "t" = tempo no vídeo. A numeração das folhas é a do nome do arquivo.

### 2.1 Golpe corpo a corpo e acerto

| # | O que é | t no vídeo | Duração | Fases (quadros) | O que dá a leitura/"gostoso" | Folha |
|---|---|---|---|---|---|---|
| A1 | **Marca vermelha de acerto**: o monstro vira silhueta vermelha chapada (sem detalhe) por cima de uma centelha branca de impacto | 18,3–19,2 s; de novo 35,2–37,2 s | entra em 1–2 q, **fica 25–60 q (0,8–2 s)** | centelha branca 2 q → silhueta vermelha plena → (opcional) anel laranja 3 q → permanece | A cor sólida e *sustentada* diz "esse é o alvo que está apanhando / marcado" a distância, mesmo com 50 inimigos na tela. Não é só um pisca: é um **estado** | 02, 08 |
| A2 | **Rajada de golpes na mesma marca**: sobre o vermelho caem cortes brancos (2–4 q cada), estrela de 4–6 pontas, feixe horizontal brilhante e lascas | 35,2–37,0 s | ~55 q (1,8 s), um acerto novo a cada **5–8 q** | slash curvo branco 3 q → estrela de impacto 2–3 q → lascas finas azuladas 6–8 q → feixe horizontal 2–3 q → estrela 2 q → "bola" branca 2 q → anel espiral | Cada acerto tem **forma própria** (arco, estrela, linhas, feixe) em vez de repetir o mesmo sprite: dá ritmo musical ao combo | 08 |
| A3 | **Crescente dourado do golpe do herói** (corte lateral) | 3,3–3,6 s | ~9 q | crescente aparece já "meio aberto" em 1 q, **gira/varre 2–3 q**, desfaz em faíscas douradas 4–5 q | Rastro fino, brilhante, em arco curto; faíscas amarelas vão ficando para trás e sobem | 01 |
| A4 | **Combo em ogros** (golpe dourado radial + garras azuis de cima) | 37,2–39,0 s | ~55 q | explosão dourada de pontas finas 3 q → anel de cortes brancos giratórios 6 q → 3 riscos azuis-claros caindo de cima 3–4 q → crescente branco horizontal 4 q → crescente sobre a cabeça do alvo (de novo) | O dourado quente "bate", o azul frio "corta de cima": **duas cores = duas camadas de dano** legíveis | 09 |
| A5 | **Golpe branco em silhueta de herói** (carregamento do ataque do ursinho) | 29,2–30,2 s | ~45 q | brilho rosado 2 q → silhueta **branca** chapada e inflando **8–10 q (0,3 s)** → vira cor normal 5 q → arco vermelho grosso (golpe) 4 q → arco menor 3 q → varrida verde no chão 5 q | A silhueta branca chapada = "carregando"; o corte vermelho é só o *pico*; a varrida verde no chão é a *volta* (a energia sobra no chão) | 05 |

### 2.2 Magias, projéteis, giros e explosões

| # | O que é | t | Duração | Fases | O que dá a leitura | Folha |
|---|---|---|---|---|---|---|
| M1 | **Projétil pequeno** (setas vermelhas de 2 q, rasto curto) até o alvo | 18,6–18,8 s | ~7 q de voo | 2 setas finas saem do herói, rasto claro de 2–3 q | Projétil quase sem corpo: o que vende é o **impacto** (silhueta vermelha + centelha) | 02 |
| M2 | **Magia rosa grande**: esfera → núcleo branco → **dois anéis laranja** → "bolha" de vidro | 3,6–5,3 s | ~50 q (1,7 s) | esfera lilás carregada com casca 3 q → núcleo branco estourando 2 q → **anel duplo laranja nasce em 1–2 q e cresce até ~2× em 4–5 q** → anel vira bolha translúcida com pétalas dentro 15+ q → desmancha em partículas rosa 12 q | Anel de luz que **expande e fica**, com partículas pequenas girando dentro: parece muito maior do que é. Faíscas rosa-flor por todo o chão (cobertura de partícula) e feixe/laser vermelho de apoio | 01 |
| M3 | **Giro azul-violeta** (vórtice de arcos concêntricos em volta do alvo, mais um anel rosa na cabeça do herói) | 20,2–20,9 s | ~22 q + 8 q de saída | 4–5 arcos concêntricos azuis/lilases já girando, anel rosa-neon horizontal sobre o herói (gira/pulsa 8 q), **lens flare de 4 pontas com núcleo preto** nasce em 1 q e vive ~6 q | O núcleo preto no meio do flare dá contraste: o olho vai direto ao ponto do impacto. Arcos concêntricos são "speed lines" em volta do alvo | 03, 12 |
| M4 | **Anel de fogo no herói** + números de dano | 20,9–21,8 s | ~28 q | anel laranja de chamas (2–3 q para aparecer) com chamas subindo verticais → encolhe/some 5 q; ao redor, lascas rosa e **números 10/14/20 pequenos, laranja, que sobem pouco e somem em ~10–12 q** | Número pequeno, quase sem fonte "bonita": é **ritmo**, não informação. Barrinha vermelha acima do inimigo some/enche junto | 03 |
| M5 | **Vórtice azul sustentado** (tornado branco-azul com pontinhos orbitando) | 29,6–31,6 s (e dupla em 32–33 s) | **~60–90 q** | 2–3 anéis concêntricos de pontos de luz em volta do alvo, arcos brancos girando, partículas orbitando em órbita estável | Efeito **longo e estável**, não pisca: lê como "habilidade ativa" (como a nossa aura). Brilha mais no centro | 05, 06 |
| M6 | **Explosão de cristal**: bola branca-rosada → estouro de espinhos radiais finos azuis/brancos | 32,4–33,0 s | ~15 q | bola branca com halo 3 q → estouro radial de espinhos (como cristal quebrando) **em 1–2 q**, ~6 q de alcance, depois polvilho | A **forma do estouro** (espinhos finos, não círculo) torna a explosão legível mesmo sem som | 07 |
| M7 | **Chuva de lanças** do chefe-cervo (verde brilhante, em leque) | 22,8–23,6 s | ~25 q | cabeça de chifres brilha branco 6 q → ~10–12 lanças verdes finas aparecem em leque **escalonadas uma a uma (~1 q de diferença)** → descem pontiagudas, uma delas vermelha (a que acerta o herói) | Leque + um item de cor diferente = "essa aqui é a que acerta". Chuva diagonal contínua no fundo (traços finos) | 04 |

### 2.3 Chefes, monstros e telégrafos

| # | O que é | t | Duração | Fases | Leitura | Folha |
|---|---|---|---|---|---|---|
| C1 | **Chefe ogro levanta o tronco** | 39,6–41,3 s | ≥ 50 q (1,7 s) só da antecipação | **reticulo laranja** (anel + cruz) aparece sobre o herói 2 q, gira e some 6 q → tronco sobe, o ogro **fica translúcido/pálido** (fade pálido de 3–4 q) enquanto levanta → braços acima da cabeça, parado ~25 q | **Antecipação longa e parada no ponto mais alto** = o jogador sabe que dá tempo de sair. A mudança de cor do ogro (pálido) é o segundo sinal além do reticulo | 10 |
| C2 | **Chefe na penumbra** (cena escura, só brilho dos olhos e das runas) | 28,5–30,0 s | ~45 q | silhueta preta com olho violeta, quase sem animação (respira, ~1 px) | Escuridão + um ponto de luz = presença sem gastar animação | 06 |
| C3 | **Entrada do chefe com chuva** | 21,6–23,6 s | ~60 q | cena inteira escurece, chuva diagonal, chifres acendem em verde → branco e partículas verdes soltam do peito | Parada de câmera de **~1–2 s** antes do ataque: o chefe "chega" antes de agir | 04 |
| C4 | **Círculos vermelhos no chão** sob inimigos | 24–26 s | contínuo | anel/disco vermelho fino abaixo de cada inimigo "marcado" | Mesma ideia da marca (A1), mas no chão: não cobre o sprite | 04 |
| C5 | **Monstros entrando**: silhueta branca (fade branco → cor real) no canto | 18,0–18,8 s | ~12 q | silhueta branca chapada que clareia do centro e some | Spawn legível: o jogador vê *onde* o monstro vai nascer | 02 |

### 2.4 Movimento (andar, correr, esquiva)

| # | O que é | t | Medição possível | Folha |
|---|---|---|---|---|
| V1 | **Esquiva/deslize com espiral de vento**: um redemoinho branco fino (2–3 arcos) nasce **no pé do herói**, fica parado no chão enquanto o herói se afasta, fica menor/mais fino em ~6–8 q | 39,8–41,2 s (no trecho do ogro) | ~25–40 q de rastro; não dá para contar quadros de corpo do herói (muito pequeno e escuro). Uma espiral nova a cada ~8 q enquanto ele corre | 10 |
| V2 | **Herói correndo**: pose inclinada, cabelo balançando, sombra sob os pés | 18,0–19,0 s | só dá para ver que são ~4 poses por passo (movimento rápido); sem contagem confiável. O herói fica mais **achatado verticalmente** ao correr | 02 |
| V3 | **Montaria/lobos correndo** (corpo comprido, patas ciano) | 18,0–19,5 s | idem: corte rápido, sem contagem | 02 |
| V4 | **Camada de vento**: traços finos brancos cruzando a cena inteira (cena escura de 33–37 s) | 33–37 s | contínuo; ~6–10 traços na tela, vão e voltam em ~10 q | 07 |

### 2.5 Câmera, luz e transição

| # | O que é | t | Duração | Comentário | Folha |
|---|---|---|---|---|---|
| X1 | **Árvore de habilidades**: a câmera **se afasta (zoom-out)** de 3 nós gigantes até a árvore inteira | 5,3–8 s | ~80 q (2,7 s), ease-out suave | A UI "abre" em escala, e os nós viram constelação. Transição animada de verdade (única de UI no vídeo) | 11 |
| X2 | **Cena do chefe com tint**: cena inteira tingida de azul/roxo (noite), halos coloridos por efeito | quase todo o trailer | contínuo | **O efeito é o que mais ilumina a cena**: o fundo é escuro de propósito para as magias brilharem (glow aditivo) | 04, 07 |
| X3 | **Lens flare** (4 pontas) como fecho do impacto forte | 20,4 s | 6–8 q | só em 2–3 momentos do vídeo; por isso pesa | 03 |
| X4 | **Corte de cena a cada 1–2 s** | todo o trailer | – | Em gameplay real não existe; é edição. **Não** copiar o ritmo | 12 |

## 3. Padrões de fundo (o que se repete)

1. **Escala de tempo em três camadas.** O impacto é *instantâneo* (1–3 q), a forma principal vive **6–12 q (0,2–0,4 s)** e a "cauda" (partículas, anel, marca vermelha, vórtice) fica **0,5–2 s** depois. O golpe parece rápido porque o que dói é curtinho; o jogador lê o resultado pela cauda.
2. **Cada efeito tem forma diferente** (arco, estrela, espinhos, anel, feixe, redemoinho). Nenhum é "círculo que cresce" repetido. Isso é o que mais separa um combo "gostoso" de um combo "barulhento".
3. **Cor = papel.** Branco = carga/impacto, vermelho = alvo/dano recebido, laranja = fogo/anel, azul-violeta = controle/vento, verde = veneno/lança, dourado = golpe físico "sagrado". Duas cores por efeito, no máximo.
4. **Fundo escuro + glow aditivo** (tint azul/roxo, brilho por cima). Dá contraste com os sprites minúsculos.
5. **Silhueta chapada** (branca ou vermelha) em vez de "pisca": a forma do monstro fica como uma máscara colorida, legível em 20 px.
6. **Antecipação longa só no chefe**; inimigos comuns e golpes do herói quase não têm.
7. **Números de dano pequenos**, laranja/branco, sem animação elaborada: ruído controlado.

## 4. Comparação com o que o K.I.K.I.U v2 já tem

Li `v2/efeitos.gd`, `v2/combate.gd`, `v2/heroi.gd`, `v2/chefe.gd`, `dados/v2_combate.json` e `v2/DESIGN.md` (por trechos). Em resumo, **a v2 já tem quase tudo em versão enxuta**; o que o vídeo mostra é *mais camadas e mais variedade*, não mecânica nova.

| Elemento | v2 hoje | Vídeo |
|---|---|---|
| Rastro do golpe | `efeitos.corte()`: sprite com shader, 16 quadros (`corte_hazaki.png`), crescente que varre + estocada; cores por passo | crescente + faíscas + 2–3 formas diferentes por acerto |
| Flash de dano | `efeitos.flash()` silhueta branca ~**0,09 s** (modo 0 dano, 1 morte, 2 rastro da esquiva) | silhueta branca (carga) **e vermelha sustentada** (marca) de 0,3–2 s |
| Hit-stop | `combate.hit_stop()`: **0,045 s** (corte), **0,07 s** (estocada), crítico próprio | não dá para medir (vídeo editado) |
| Tremor | `camera_mundo.tremer()`: 0 px no corte, 2 px na estocada | não se vê tremor claro no vídeo (a câmera quase não treme) |
| Números de dano | `efeitos.numero()` fonte pixel, normal 16 / crítico 24, em pool | pequenos, laranja, ~10 q; mesmo papel |
| Partículas/faíscas | `faiscas()`, `estouro()`, `particula()`, `onda()` em pool (360 partículas) | cobertura de pétalas/centelhas bem maior em magias |
| Esquiva | rolamento 0,42 s, i-frames 0,3 s, rastro (flash modo 2) | **redemoinho de vento** parado no chão |
| Telégrafo de chefe | `avisos.circulo()` ~1 s antes do dano; chefe `aviso` → `investida` | reticulo no alvo + chefe pálido + parada alta (≥1,7 s) |
| Luz | `luz_rapida()`, PointLight2D que acende o chão | glow aditivo grande e tint por cena |
| Armas secundárias | órbita, aura, corvos, raio, runa (`armas.gd`) | anéis expansivos, vórtices longos, explosões de cristal |

## 5. O que dá pra aproveitar no K.I.K.I.U v2

Esforço: **P** ≈ até 1 sessão curta, só ajustar número ou ligar algo que já existe; **M** ≈ meio dia, código novo pequeno em pool; **G** ≈ 1–2 dias, sistema ou arte nova. Quem faz segue a divisão fixa do `CLAUDE.md`: código e efeitos em código = **Claude do Alisson**; imagem-fonte nova = **Codex**; ajuste de número depois de jogar = **Claude do Breno**.

| # | Ideia (inspirada em) | Onde entra no código | Esforço | Quem | Risco / observação |
|---|---|---|---|---|---|
| 1 | **Marca vermelha sustentada no monstro atingido pelo golpe forte** (A1). Silhueta vermelha chapada por 0,4–0,8 s em estocada e crítico; vermelho some se o monstro morre | `efeitos.flash(a, dur, cor, modo, forca)` já aceita cor e duração; criar `modo 3` que segue o ator e fica mais tempo. Chamar de `combate.golpear` no crítico/estocada | **P** | Claude do Alisson | Em horda de 300 vivos, limitar a 1–2 marcas ao mesmo tempo (`MAX_FLASH := 24` já protege). Não aplicar em todo acerto, senão vira ruído |
| 2 | **Flash branco de carga + varrida de retorno** nos inimigos elite/chefe (A5). Elites brilham em branco 0,3 s antes do ataque | `elites.gd`, `chefe.gd` (estado `aviso`), `efeitos.flash` modo 0 com `dur` maior | **P** | Claude do Alisson | Já há `avisos.circulo`; isto acrescenta um segundo sinal (cor do corpo). Testar com `v2_avisos` se existir |
| 3 | **Anel duplo que nasce em 1–2 q e expande até 2×, depois fica como "bolha" por 0,4 s** (M2) para a aura/orbita e explosões | `efeitos.onda()` (hoje 1 círculo); adicionar 2º anel defasado de 0,05 s e parâmetro de "permanência". Reaproveitar nas explosões (`armas.explodir`, `_explodir_runa`) | **M** | Claude do Alisson | Mesmo orçamento aditivo (já é uma chamada só). Atenção ao FPS no i5-3470: medir com `ajustes_graficos`/`fps.txt` |
| 4 | **Explosão de espinhos radiais** (M6) para o crítico explosivo e a runa | novo tipo em `efeitos.gd` (ou textura gerada uma vez, como a aura em `armas.gd`: "texturas prontas + shader") | **M** | Claude do Alisson (forma em código/shader); Codex só se quiser sprite-fonte | Forma procedural dá para gerar sem imagem nova |
| 5 | **Lens flare de 4 pontas com núcleo escuro** (M3/X3) só em evolução de arma, fusão e chefe morrendo | `hud_anuncios.gd`/`efeitos.gd`; já existe hit-stop de fusão (`FUSAO_PARADA_S`) | **P** | Claude do Alisson | Raro de propósito: o valor está em usar **pouco** |
| 6 | **Vórtice sustentado** com 2–3 anéis de pontos orbitando (M5) para a aura (`armas._aura`) em níveis altos | `armas.gd` textura da aura + shader; anéis de partículas por `particula()` | **M** | Claude do Alisson | Já há "círculo de fogo"; o vórtice seria evolução visual. Cuidado: 360 partículas no pool |
| 7 | **Redemoinho de vento parado no pé na esquiva** (V1) | `combate.rastro_esquiva(h)` hoje solta o flash "fantasma"; somar uma espiral fina no chão, 1 a cada ~8 q (≈0,27 s) | **P–M** | Claude do Alisson | A espiral é desenhável por `linhas` ou textura gerada; sem arte de terceiros |
| 8 | **Telégrafo do chefe em duas camadas**: reticulo no herói + chefe pálido + parada alta ≥ 1,2–1,7 s (C1) | `chefe.gd` estado `aviso` (`aviso` em `dados/v2_cartas.json > chefes`), `avisos.gd` (círculo já existe) | **M** | Claude do Alisson; números `aviso` por dados: Claude do Breno depois de jogar | O aviso atual é ~1 s; testar 1,2–1,5 s no i5 do Breno para ver se fica justo. Não mexe no dano |
| 9 | **Entrada do chefe**: tela escurece 1–2 s, chuva diagonal fina e partículas verdes soltando do corpo (C3) | `atmosfera.gd`/`luzes.gd` (já há chuva do chefe), câmera lenta já existe (`combate.camera_lenta`) | **M** | Claude do Alisson | A chuva de círculos do chefe já existe; falta a "parada de câmera" curta. Ver `hud_anuncios` |
| 10 | **Leque de projéteis escalonados com um item de cor diferente** (M7) para ataque de chefe (chuva de lanças) | `chefe.gd` novo ataque ou variação do "chuva"; `avisos` | **G** | Claude do Alisson (código); Codex só se quiser sprite de lança | Novo ataque = mexe em equilíbrio; só com decisão do Alisson |
| 11 | **Número de dano mais discreto**: normal 8 px (ou 16 com opacidade) e crítico maior, vida curta ~0,35 s (M4) | `efeitos.numero()` / `_desenhar_numeros`, `MAX_NUM := 64` | **P** | Claude do Alisson (ou Breno se for só números em dados) | Só o mais perto do herói; em horda os números viram ruído. Opcional no `ajustes_graficos` |
| 12 | **Spawn legível**: silhueta branca que clareia onde o monstro vai nascer (C5) | `diretor.gd` + `efeitos.flash` modo 1 ou sombra do chão | **P–M** | Claude do Alisson | Útil para elites/chefes; em horda comum, caro e confuso |
| 13 | **Círculo vermelho no chão** sob quem está marcado (C4) em vez de cobrir o sprite | `avisos.gd` ou camada de sombra de `efeitos.gd` | **P** | Claude do Alisson | Alternativa mais leve para a ideia 1 quando houver muitos alvos |
| 14 | **Zoom-out suave na árvore/escolha de habilidade** (X1) | `hud.gd`/`cartas.gd`, `camera_lenta` já ligada ao nível | **M** | Claude do Alisson | Só se o menu de cartas ganhar uma visão em árvore (fora do escopo hoje). Antes de mexer em menu/UI, ler `v2/DESIGN.md` |
| 15 | **Camada de vento** (traços finos que cruzam a tela, V4) nos mapas escuros/chefe | `atmosfera.gd` | **P** | Claude do Alisson | Barato (poucas linhas, uma chamada); só combina com Floresta de noite |

### Sugestão de ordem

1. Itens 1 e 2 (marca vermelha + flash de carga em elite/chefe): resolvem o que o jogador mais sente ("quem é o alvo?" e "vai bater?"), custam pouco.
2. Itens 7 e 11 (esquiva com redemoinho, números discretos): pequenos e visíveis.
3. Itens 3 e 4 (anel duplo, espinhos radiais): dão cara nova às explosões das cartas.
4. Item 8 (telégrafo em duas camadas do chefe): precisa jogar com o Breno para calibrar.
5. O resto só se sobrar tempo; 10 (novo ataque do chefe) e 14 (árvore) pedem decisão do Alisson.

### O que **não** aproveitar
- O **ritmo de cortes** do trailer: no jogo, o jogador nunca vê 1,5 s de cena.
- **Volume de partículas** das magias grandes: o alvo é um i5-3470; o pool de 360 partículas e as chamadas aditivas únicas (`efeitos.gd`) existem por isso. Qualquer efeito novo respeita o orçamento ou entra como opção em `ajustes_graficos`.
- **Arte do vídeo** (qualquer sprite, quadro ou forma literal): proibido pela regra de licenças. A forma de cada efeito acima é descrita só em termos de movimento e tempo, e deve ser desenhada em código/shader ou por arte própria.

## 6. Tabela de tempos de referência (resumo para quem for implementar)

| Fase | Faixa vista no vídeo | v2 hoje | Sugestão de teste |
|---|---|---|---|
| Impacto (centelha/estrela) | 1–3 q (0,03–0,10 s) | flash 0,09 s | manter |
| Forma principal do golpe | 6–12 q (0,2–0,4 s) | corte 0,26 s, estocada 0,36 s | manter |
| Cauda (partículas, anel, marca) | 15–60 q (0,5–2 s) | partículas curtas | alongar para 0,4–0,8 s em críticos |
| Marca vermelha no alvo | 25–60 q (0,8–2 s) | 0,09 s | 0,4–0,8 s só em estocada/crítico |
| Carga branca antes do golpe do inimigo | 8–10 q (0,3 s) | aviso ~1 s (círculo) | somar flash branco 0,3 s |
| Antecipação do chefe | ≥ 50 q (≥ 1,7 s) | ~1 s | testar 1,2–1,5 s |
| Número de dano | 10–12 q (0,35 s) | ver `efeitos.numero` | testar vida de 0,35 s |
| Redemoinho de esquiva | 6–8 q cada, 1 por ~8 q | rastro-fantasma | somar |

*Folhas de contato:* `folha_01_magia_rosa_3s.jpg` … `folha_12_visao_geral_18s.jpg` (todas < 500 KB; JPG em vez de PNG para caber no limite). Abra na ordem do nome. Folhas "10 fps" têm 8×6 quadros por 4,8 s; as de "30 fps" têm 8×6 (ou 6×4) quadros por 1,6 s (ou 0,8 s).
