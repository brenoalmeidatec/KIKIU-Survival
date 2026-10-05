# Jogos de sobrevivência de hordas: como funcionam e como fazer o nosso

Análise de Vampire Survivors, Megabonk e Risk of Rain 2 (com toques de Brotato e 20 Minutes Till Dawn), focada em **mecânicas e design**. Nada aqui copia arte ou código de ninguém; são as regras do jogo, que é o que dá para estudar e reinventar.

---

## 1. A ideia central (o que todos têm em comum)

Todo jogo desse gênero é a mesma promessa: **você começa fraco, o mundo fica mais perigoso a cada segundo, e você precisa ficar forte mais rápido do que ele.** A diversão vem de dois momentos:

1. **O sufoco**: a tela enche de inimigos e você quase morre.
2. **A virada**: você pega o upgrade certo, a build "liga" e você vira uma máquina de destruição.

O jogo inteiro é desenhado para alternar entre esses dois sentimentos várias vezes numa partida curta (10 a 30 minutos).

### O loop principal (vale para os três)

```
andar/desviar  ->  arma atira sozinha  ->  inimigo morre  ->  solta XP/ouro
      ^                                                         |
      |                                                         v
dificuldade sobe  <-  fica mais forte  <-  escolhe upgrade  <-  sobe de nível / abre baú
```

E por cima disso existe um **loop de fora da partida** (meta-progressão): ao morrer você ganha moedas/desbloqueios que deixam a próxima tentativa diferente ou mais forte. É isso que faz a pessoa jogar "só mais uma".

---

## 2. Cada jogo em poucas palavras

| | Vampire Survivors | Megabonk | Risk of Rain 2 |
|---|---|---|---|
| Visão | 2D de cima, pixel art | 3D, terceira pessoa, low-poly | 3D, terceira pessoa |
| Controle | **só anda** (arma atira sozinha) | anda, **pula, desliza**; arma atira sozinha | anda, pula, **mira e usa 4 habilidades** |
| Duração | 30 min por fase (e a Morte aparece) | ~10 min por fase + "Enxame Final" | sem fim; você escolhe quando sair |
| Como fica forte | sobe de nível, escolhe entre 3–4 opções | sobe de nível + compra baús com ouro | **só itens** (ouro → baús); não escolhe nível |
| Limite de build | 6 armas + 6 passivos | slots de armas + "tomos" + itens | itens ilimitados, empilham |
| Assinatura | **evoluções** (arma + passivo = arma nova) | movimento + santuários de risco | **empilhar itens** e escala sem fim |
| Multijogador | coop local/online (até 4) | solo | coop online até 4 |

### Vampire Survivors: "o mais simples possível, com muita coisa na tela"
- Você **só anda**. Tudo o resto é automático. O jogo é sobre **onde estar**, não sobre mirar.
- Matar inimigos solta **gemas de XP**. Encheu a barra, o jogo pausa e oferece 3 ou 4 opções: arma nova, subir nível de uma arma, ou item passivo.
- **6 espaços de arma e 6 de passivo**. Isso força escolhas: você não pode pegar tudo.
- **Evolução**: arma no nível máximo + o passivo "parceiro" dela + abrir um baú (os baús que evoluem caem de chefes a partir dos 10 minutos) = a arma vira uma versão muito mais forte. É o momento de "virada" mais famoso do gênero.
- **Uniões**: duas armas viram uma só, liberando espaço.
- Fora da partida: ouro compra bônus permanentes (mais vida, mais dano, mais sorte) e desbloqueia personagens, fases e armas por conquistas ("mate 100 mil inimigos", "sobreviva 20 min com X").
- Aos 30 minutos chega a Morte, que mata você: é o "fim" da fase.

### Megabonk: "Vampire Survivors em 3D, com movimento de verdade"
- Mesmo núcleo (arma automática, XP, subir nível e escolher), mas **o movimento importa muito**: pular, deslizar em rampas, usar o terreno para fugir.
- **Tomos**: upgrades passivos em forma de livro (velocidade de ataque, XP, sorte, área...). É o equivalente aos passivos do VS.
- **Ouro e baús**: além do nível, o mapa tem baús que custam ouro, e o preço sobe a cada baú aberto.
- **Santuários (shrines)** espalhados pelo mapa, cada um um pequeno risco/recompensa:
  - de *carga*: fique parado dentro do círculo até encher e ganhe um bônus;
  - de *ímã*: puxa todo o XP do mapa;
  - de *desafio*: chama inimigos de elite em troca de prêmio;
  - de *ganância*: aumenta a dificuldade em troca de mais recompensa.
- Ferramentas de controle de sorte: **banir** (tira uma opção do sorteio para sempre), **re-sortear** (trocar as opções), "micro-ondas" para duplicar itens.
- Fases de ~10 min com **chefe**; ao fim do tempo começa o **Enxame Final**, inimigos sem fim com pressão crescente.
- **Sorte** é um atributo: aumenta a raridade do que aparece.

### Risk of Rain 2: "o tempo é o inimigo"
- Você **mira e usa habilidades** (é um jogo de ação de verdade), mas a progressão é **só por itens**.
- Itens vêm de **baús comprados com ouro**, espalhados pelo mapa. Não há "escolher 1 de 3" ao subir de nível; o item vem aleatório (existem impressoras e caldeirões para trocar).
- **Itens empilham sem limite**: 1 cópia dá +10% de algo, 10 cópias dão +100%. Builds nascem de empilhar muito o mesmo item.
- **Sinergias** fortes por "chance de ativar" (proc): itens que disparam efeitos ao acertar, e outros que aumentam essa chance ou disparam de novo. Uma cadeia de efeitos é o momento de "virada".
- **O relógio é a dificuldade**. Quanto mais você demora, mais difícil fica. Isso cria uma tensão ótima: explorar o mapa para pegar mais baús x correr para o teleporte antes que fique impossível.
- Cada fase termina ativando um **teleporte**, que chama um chefe e você precisa sobreviver dentro de uma área até carregar.

---

## 3. Progressão e upgrades (os 3 jeitos de ficar forte)

1. **Nível (XP) com escolha** (VS, Megabonk, Brotato): inimigo solta XP → barra enche → pausa e escolha entre 3–4 cartas. Dá controle ao jogador; a aleatoriedade está em *quais* cartas aparecem.
   - Raridade das cartas (comum, rara, épica) influenciada por **Sorte**.
   - Ferramentas anti-azar: re-sortear, banir, pular.
2. **Itens por ouro/baús** (RoR2, Megabonk): ouro dos inimigos → abrir baús no mapa. O preço do baú sobe com o tempo/dificuldade. Cria a decisão "explorar ou fugir".
3. **Meta-progressão** (todos): moeda que fica depois de morrer → bônus permanentes e desbloqueios. É a "cenoura" de longo prazo.

### Tipos de upgrade que aparecem em todos
- **Atributos**: dano, velocidade de ataque, área, quantidade de projéteis, duração, velocidade de projétil, vida máxima, regeneração, armadura, velocidade de movimento, raio do ímã de XP, sorte, ganho de XP, ouro.
- **Armas novas**: cada uma com um "jeito" de cobrir a tela (reta, em volta de você, aleatória, que persegue, área no chão, ricochete).
- **Efeitos ao acertar**: chance de queimar, congelar, explodir, ricochetear, roubar vida.

---

## 4. Dificuldade e spawn de inimigos (o coração do gênero)

### O que sobe com o tempo
- **Quantidade** de inimigos vivos ao mesmo tempo.
- **Tipo** de inimigo (os fracos somem, entram os mais fortes).
- **Atributos** dos inimigos (vida, dano).
- **Eventos**: chefes, ondas especiais, enxames em círculo.

### Modelo 1: roteiro por tempo (Vampire Survivors)
Cada fase tem uma **tabela por minuto**: "no minuto 3, mantenha no mínimo 60 morcegos vivos e solte mais 1 a cada 0,5 s; no minuto 5, chega um chefe; no minuto 7, um círculo de plantas te cerca". É previsível, fácil de balancear e **perfeito para ser um arquivo de dados**.

### Modelo 2: "diretor com orçamento" (Risk of Rain 2)
Existe um número que só cresce, o **coeficiente de dificuldade**:

```
fatorJogadores = 1 + 0,3 × (jogadores − 1)
fatorTempo     = 0,0506 × dificuldadeEscolhida × jogadores^0,2
fatorFase      = 1,15 ^ fasesCompletas
coeficiente    = (fatorJogadores + minutos × fatorTempo) × fatorFase
```

- Um "**diretor**" ganha **créditos** por segundo proporcionais ao coeficiente e os **gasta** comprando inimigos: um fraco custa pouco, um elite custa muito. Com mais crédito, ele compra grupos maiores e inimigos mais fortes.
- **Nível do inimigo** sobe com o coeficiente (cada nível dá mais vida e dano).
- **Preço dos baús** também sobe com o coeficiente (custoBase × coef^1,25), então o tempo deixa tudo mais caro.
- Mais jogadores = coeficiente maior. É assim que o coop fica justo.

Esse modelo é mais "vivo" e ótimo para multijogador.

### Regras práticas de spawn (todos fazem)
- Inimigos nascem **fora da tela**, num anel em volta do jogador (nunca em cima dele).
- **Limite de inimigos vivos** (ex.: 300–500) por desempenho; quando o limite enche, os mais distantes são reciclados para perto.
- Inimigos simples só **andam em direção ao jogador** (sem pathfinding pesado). É isso que permite centenas na tela.
- **Elites**: inimigo comum com cor/brilho diferente, mais vida e uma habilidade.

---

## 5. Builds e sinergias (o que deixa viciante)

Sinergia = duas coisas que juntas valem mais do que separadas. Os padrões que se repetem:

1. **Receita explícita** (VS): arma A + passivo B → arma evoluída. O jogo te *ensina* o combo e você caça as peças.
2. **Multiplicadores** (todos): "+1 projétil" vale mais se cada projétil já é forte; "+área" vale mais em armas de área.
3. **Gatilhos em cadeia** (RoR2): "ao acertar, chance de X" + "aumenta a chance de tudo" + "X também ativa ao acertar" = reação em cadeia.
4. **Temas/etiquetas** (Brotato, Megabonk): itens marcados como "fogo", "elementar", "corpo a corpo"; ter vários da mesma etiqueta dá bônus.
5. **Troca de risco** (santuários do Megabonk, itens "lunares" do RoR2): ganha muito, perde algo.

Dica de design: **o jogador precisa perceber a sinergia acontecendo** (números grandes, efeitos visuais, som). Uma build forte que não "aparece" na tela não diverte.

---

## 6. O que diferencia cada jogo (para escolher o nosso caminho)

- **VS** é o mais fácil de fazer bem: 2D, só andar, tudo dirigido por tabelas. O desafio é desempenho (muitos inimigos) e balanceamento.
- **Megabonk** mostra que **movimento expressivo** muda tudo; em 2D isso pode virar um **dash/esquiva** ou pulo.
- **RoR2** mostra que **o tempo como dificuldade** + **itens empilháveis** + **coop** dão partidas imprevisíveis, mas exige combate com mira e é bem mais trabalhoso.

**Recomendação para o nosso**: base de Vampire Survivors (2D de cima, pixel art, teclado, arma automática, nível com escolha), roubando duas ideias: o **dash** do Megabonk e o **diretor com coeficiente** do RoR2 (que já resolve dificuldade no coop até 6). Isso casa direto com o que a engine já tem.

---

## 7. Como implementar cada sistema em Godot

| Sistema | Como fazer em Godot 4 | Cuidados |
|---|---|---|
| Jogador | `CharacterBody2D`, movimento em 8 direções, dash com tempo de recarga e invencibilidade curta | Hitbox menor que o sprite (dá sensação justa) |
| Armas automáticas | Cada arma é um `Node` com `Timer`; ao disparar cria projéteis/áreas. Atributos vêm de um **Resource** ou JSON (`dano`, `cadencia`, `quantidade`, `area`, `duracao`, `velocidade`) | Arma lê os atributos do jogador na hora de atirar, assim upgrades valem na hora |
| Projéteis | `Area2D` simples, ou para muitos: **sem nós**, só um array de posições desenhado com `MultiMeshInstance2D` e colisão por distância | Reaproveitar (pool) em vez de criar/destruir |
| Inimigos | Poucos tipos de comportamento: "vai até o jogador", "atira de longe", "investida". Para centenas: lógica em um único script gerenciador com arrays, desenho com `MultiMesh`; separação simples para não empilharem | Evitar `NavigationAgent` por inimigo; usar grade espacial para colisão |
| Spawn / diretor | Um `diretor_hordas.gd` com coeficiente + créditos, lendo de JSON a lista de inimigos (custo, peso, minuto a partir do qual aparece) e eventos por tempo (chefe, enxame) | Nascer num anel fora da câmera; limite de vivos |
| XP e coleta | Gemas como objetos baratos; ímã puxa quando perto; juntar gemas próximas numa maior quando houver muitas | Gemas também em pool/MultiMesh |
| Subir nível | Pausa (`get_tree().paused`), painel com 3–4 cartas sorteadas com peso e raridade; re-sortear/banir | Painel com `process_mode = ALWAYS` |
| Itens/passivos | Tudo em `itens.json`: id, nome, ícone, raridade, nível máximo, efeitos (`{"atributo":"area","soma":0.1}`) | Sistema de atributos com "base + soma × multiplicador" |
| Evoluções | `evolucoes.json`: `{"arma":"x","precisa":"y","vira":"z"}`; checar ao abrir baú | |
| Dano e efeitos | Números de dano flutuantes, piscar branco, empurrão, tremer câmera, partículas | Limitar números na tela |
| Chefe/baú | Inimigo grande com padrão próprio; solta baú que dá 1–5 upgrades | |
| Meta-progressão | Moeda salva no save; loja de bônus permanentes; desbloqueios por conquistas | |
| Desempenho | Meta: 500 inimigos a 60 fps. Medir cedo | GDScript aguenta se a lógica for em arrays; se faltar, mover o laço quente para C# ou GDExtension depois |

---

## 8. O que dá para reaproveitar da nossa engine

Base: `/mnt/project-files/jogo/ENGINE.txt` (não mexi em nenhum arquivo do jogo da Cairu).

**Reaproveita quase direto**
- `jogo.gd`: opções, **save em slots**, música, efeitos sonoros (serve para salvar a meta-progressão).
- `controles*.gd`, `opcoes.gd`, `pausa.gd`, `menu.gd`, `main.gd`: teclado, remapear teclas, pausar, menu.
- `rede.gd`: sala online até 6 com ENet, anfitrião é o servidor, entrar por endereço, `online.json`. A estrutura de sala/lista de jogadores serve igual.
- `personagem.gd` + `animacao.gd` + `fonte_poses/`: boneco em pixel art com 4 direções e poses; serve para os heróis (e o elenco da Cairu pode virar personagens jogáveis de um modo extra, se o Breno quiser).
- `mapa.gd` + mapas em JSON (fundo, máscara, colisões, objetos): serve para arenas.
- `diretor.gd` / `roteiro.gd` / `dialogo.gd`: cutscenes de abertura, diálogo antes do chefe, história entre fases.
- `minijogos/base.gd` e `esquiva`: a ideia de "desviar de coisas" já existe em pequeno.
- Fluxo de build/zip e o modo de teste F5/F6.

**Precisa adaptar**
- `mundo.gd` é feito para andar e conversar; para hordas é melhor uma cena nova `arena.gd` que use os mesmos mapas, câmera e jogador, mas sem portas/NPCs de conversa.
- `rede.gd` hoje sincroniza **posição dos jogadores**. Para hordas, o **anfitrião precisa simular inimigos, projéteis e XP** e mandar um resumo compacto para os outros (posições em lote, poucas vezes por segundo, com interpolação). Isso é o maior trabalho do multiplayer.
- Mapas atuais são salas pequenas (640×400); arena pede mapa grande ou que se repete (azulejos infinitos).

**Totalmente novo**
- Arena + câmera que segue em mapa grande.
- Armas automáticas e projéteis em pool.
- Inimigos em massa (gerenciador com MultiMesh).
- Diretor de hordas (coeficiente, créditos, eventos por tempo).
- XP, ímã, subir nível com cartas, raridade, sorte.
- Sistema de atributos (base/soma/multiplicador) e itens/evoluções em JSON.
- HUD de partida (vida, XP, tempo, nível, ícones das armas).
- Meta-progressão (loja, desbloqueios).
- Juice: números de dano, piscar, partículas, tremor.

Seguindo a regra do projeto, tudo isso nasceria como **módulo da engine** (`hordas/` com scripts genéricos) e o conteúdo (inimigos, armas, itens, fases) em JSON, para servir a qualquer jogo.

---

## 9. Escopo mínimo do primeiro protótipo

Objetivo: em uma tela, descobrir **se é divertido**. Nada de arte final.

1. **Uma arena** grande com chão simples e a câmera seguindo.
2. **Um herói**: anda em 8 direções + **dash**. Vida e morte.
3. **3 armas automáticas** com jeitos diferentes: projétil reto no inimigo mais próximo, área girando em volta, poça de dano no chão.
4. **4 tipos de inimigo**: lento comum, rápido fraco, tanque, um que atira. Mais **1 chefe** aos 5 minutos.
5. **Diretor simples**: coeficiente sobe com o tempo; créditos compram inimigos; anel de spawn fora da tela; limite de vivos.
6. **XP + ímã + subir nível** com 3 cartas.
7. **8 passivos** (dano, cadência, área, quantidade, velocidade, vida, ímã, sorte) e **1 evolução** para testar o "momento de virada".
8. **Partida de 10 minutos**; vencer = sobreviver; HUD com tempo, vida, XP.
9. **Tela de fim** com inimigos mortos e tempo.
10. Tudo de inimigos/armas/itens em **JSON**.
11. **Teste de desempenho**: 500 inimigos na tela a 60 fps antes de seguir.

**Fica para depois** (em ordem sugerida): baús e ouro → mais armas/evoluções → meta-progressão e desbloqueios → santuários de risco/recompensa → **coop online** reaproveitando `rede.gd` → personagens com habilidades próprias → várias fases.

Por que o coop fica para depois: ele obriga o anfitrião a simular tudo e mandar para os outros, e é mais fácil fazer isso quando as regras do jogo já estão estáveis.

---

## Fontes
- Risk of Rain 2 Wiki, Dificuldade (fórmulas do coeficiente, nível dos inimigos, preço dos baús, créditos do diretor): https://riskofrain2.wiki.gg/wiki/Difficulty
- Vampire Survivors Wiki, Evolução: https://vampire-survivors.fandom.com/wiki/Evolution
- KeenGamer, guia de iniciante do Megabonk (tomos, santuários, baús, Enxame Final): https://www.keengamer.com/articles/guides/megabonk-beginners-guide-how-to-play-build-survive-your-first-run/
- PC Gamer, análise do Megabonk: https://pcgamer.com/games/roguelike/megabonk-review
- Gurugamer, armas e tomos do Megabonk: https://gurugamer.com/pc-console/megabonk-complete-weapon-and-tome-upgrades-guide-25658
- Rogueranker, passivos do Vampire Survivors: https://rogueranker.com/vampire-survivors-passive-items/

Alguns detalhes (limite de 6+6 slots do VS, coop do VS, 300–500 inimigos como limite comum) vêm de conhecimento geral do gênero e não foram conferidos nas páginas acima.
