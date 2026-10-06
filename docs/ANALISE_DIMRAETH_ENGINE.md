# K.I.K.I.U × Dimraeth: análise técnica e plano de adaptação

Preparado para o Breno, para repassar ao Alisson e ao Claude dele. Documento de análise: nenhum código foi alterado. Complementa o `docs/DIMRAETH_ADAPTACAO.md` do repo (que só cobre ambientação, rolamento, telegrafia e câmera).

## 1. Resumo

- O vídeo enviado é um **Reel de 25 s do perfil mudtek** ("Same spells, new look") que compara o visual antigo ("Then") com o novo ("Now") de **magias de gelo**. Ele mostra combate e efeitos visuais, **não mostra menus, inventário, criação de personagem nem progressão**. O nome "Dimraeth" veio do nome do arquivo; a tela não o exibe.
- Por isso, a parte de sistemas (8 raças × 6 classes, 300+ magias, equipamento com raridade, co-op de 8) vem de **páginas públicas** (loja do Steam e matéria da G2A, links no fim), e está marcada como tal.
- O que adaptar, em ordem de valor: (1) **criação de personagem com raças e classes malucas**, (2) **tela de preparo/mochila antes da corrida**, (3) **magias com elemento e efeitos em camadas** (gelo congela, poça, estilhaços), (4) legibilidade (números, barras, marcas de chão). Tudo em JSON, sem tocar a arte do Dimraeth.
- **Fora do escopo, por ordem do Breno:** construção de base (fortaleza, fazenda, pedreira, estações de criação). Não há nenhum equivalente aqui.

## 2. O que o vídeo mostra (quadro a quadro)

Vertical (384×848), gravado de uma tela de celular com a interface do Instagram por cima. Extraí 16 quadros, um a cada 1,6 s.

| Trecho | O que aparece |
|---|---|
| 0–6 s ("Then") | Visão de cima, mapa de floresta com penhasco e água. Slimes azuis de dois tamanhos andam em direção ao herói. Uma magia deixa uma **poça de gelo rachada** no chão; o slime dentro dela aparece congelado. **Chuva de estilhaços** cai de cima. Um **número de dano (54)** sobe. |
| 6–12 s ("Then") | Herói de cabelo vermelho atira **uma lâmina de gelo em linha reta** contra slimes. Um slime roxo com contorno aparece com **barra de vida** pequena acima. Estouro grande de **cristais de gelo** com número 54. |
| 12–20 s ("Now") | Mesma magia com visual novo: golpe em arco branco-esverdeado ao redor do herói, **projétil laranja pequeno** que persegue o alvo, **explosão de névoa gelada** em bola, **poça rachada** maior e mais translúcida. Aparecem **pontinhos amarelos e brancos** (coletáveis) e um **círculo marrom no chão** em volta do slime roxo (marca de área do ataque). |
| 20–25 s | Etiqueta flutuante **"Droop Gelo x1"** (como está escrito na tela) sobre onde a explosão caiu: **um item (material de gelo) cai de um inimigo**, com o nome sobre ele. Novo corte para o "Then" como fechamento. |

**O que isso confirma sobre o jogo:** é um action-RPG de cima com **ataques mirados automaticamente em parte dos casos** (projétil que persegue), **efeitos de status de elemento** (congelar), **zonas persistentes no chão**, **inimigos com barra de vida e variantes (comum, grande, elite roxa)**, **drops com nome**, **números de dano**. A mensagem principal do vídeo é de arte: **as mesmas magias, refeitas com camadas de efeito (brilho, anel, partículas, névoa)** e a tela continua legível.

**O que o vídeo NÃO permite afirmar:** vida/estamina do herói (a interface do app cobre a parte de baixo), inventário, menus, classes, raças, loja, progressão.

## 3. O que o jogo tem, segundo páginas públicas

Não confirmado pelo vídeo; vem da loja do Steam e da matéria da G2A.

| Sistema | Como é no Dimraeth |
|---|---|
| Personagem | 8 raças × 6 classes = 48 "arquétipos", cada um com **árvore de habilidades** própria. Criação por raça, classe, atributos, equipamento e magia. |
| Magias | 300+; o jogador equipa **5 por vez**, vindas da raça, da classe ou de livros fabricados. Magias universais exigem atributo mínimo. |
| Combate | "Souls-lite": stamina, esquiva, bloqueio, aparo, inimigos que telegrafam. |
| Equipamento | Raridades e melhorias; saque e recursos pelo mundo. |
| Co-op | Até 8 jogadores, entrada e saída a qualquer hora; o personagem viaja entre mundos, o progresso do mundo fica com o anfitrião. |
| Base | Fortaleza com fazendas, pedreiras, criação, cozinha e poções; **comida aumenta a vitalidade nas expedições**. *(não vai pro K.I.K.I.U)* |

## 4. Onde o K.I.K.I.U está hoje (conferido no código)

- Fluxo de telas em `main.gd`: `titulo → herois → (calor) → partida → fim`; sala online: `sala → calor_sala → partida`. A partida nasce em `_comecar(heroi, opcoes, online)`.
- Heróis fixos em `dados/herois.json` (`lista`: hazaki, nicao, lucas; outros só como rivais do duelo). Cada herói tem `arma`, `bonus`, `reviver`, `sprite`, `camadas`.
- Atributos: `Construcao.stats(heroi, passivos, equip, extra)` soma herói + passivos + equipamentos + dádivas sobre `BASE`. **É o ponto único onde raça e classe entram.**
- Limites: `MAX_ARMAS = 4`, `MAX_PASSIVOS = 5`. Equipamentos por slot (`equipamentos.json`, camadas desenhadas por `equipamento.gd`; só o Hazaki tem modelo em camadas).
- Especial por herói na tecla E (`especiais.json` + `scripts/hordas/especiais/<tipo>.gd`).
- Corrida: 5 regiões × 5 fases (`regioes.json`), mapa de nós, loja (`loja.gd`), calor (`calor.json`), semente compartilhada (`sorte.gd`).
- Online: `rede.gd` (ENet, até 6, anfitrião manda). Cada peer manda só **id do herói**; a sala recusa herói repetido (`_escolher`). Estado de partida via `online.gd`.
- Já existem: números de dano (`efeitos.gd`, teto 70), `lentidao` em `armas.gd`, poças desenhadas por código (`poca.gd`). Renderer: `gl_compatibility`.

## 5. Adaptações propostas

Legenda de esforço: **P** = só JSON e poucas linhas, **M** = módulo novo, **G** = sistema novo ou arte nova.

### 5.1 Criação de personagem: raça, classe, aparência (esforço G, valor alto)

**Ideia:** uma tela nova "Criar herói" no fluxo, ao lado dos heróis fixos. O herói criado vira um `Dictionary` no mesmo formato de `herois.json`, montado em tempo de execução, então **o resto do jogo não precisa saber a diferença**.

**Fluxo:** `herois` ganha uma carta "+ Criar herói" e as cartas dos heróis salvos. Criar: nome → raça → classe → aparência → pontos → confirmar. Salva em `user://herois_criados.json` (máx. 6).

**Montagem do herói (fórmula):**

```
heroi = {
  nome, sprite = base da raça, camadas = true,
  arma = classe.arma_inicial,
  especial = classe.especial,           # ids de especiais.json
  reviver = classe.reviver,
  bonus = soma(raca.bonus, raca.fraquezas, classe.bonus, pontos_distribuidos),
  ganchos = raca.ganchos + classe.ganchos,   # regras novas (tabela abaixo)
  aparencia = {cabelo, cor_pele, cor_cabelo, cor_roupa, acessorio}
}
```

**Arquivos de dados novos:**

- `dados/racas.json`: `{id, nome, descricao, bonus{}, fraquezas{}, ganchos[], sprite_base, paletas{}}`.
- `dados/classes.json`: `{id, nome, descricao, arma_inicial, bonus{}, especial, reviver, limite_exclusivas}`.
- `dados/aparencia.json`: opções e paletas (cabelos, cores, acessórios), no mesmo espírito do `_config.ordem` do `equipamentos.json`.
- `dados/criacao.json`: pontos para distribuir, limite por atributo, **pontos extras por "defeito voluntário"**, nome mínimo/máximo.

**Raças malucas (proposta; "bônus/fraqueza" usam só atributos que `Construcao.BASE` já conhece; "gancho" é regra nova):**

| Raça | Bônus | Fraqueza | Gancho (se tiver) |
|---|---|---|---|
| Humano | +10% XP, +0,1 sorte | nenhuma forte | — |
| Anão Encouraçado | +30 vida, +regen | −15% velocidade, −10% área | — |
| Elfo Sombrio | +15% crítico, +10% velocidade | −25 vida | — |
| Orc Cabeçudo | +20% dano | −10% recarga (mais lento) | — |
| Goblin Sortudo | +0,5 sorte, ímã de coleta +40% | −30 vida, −15% dano | — |
| Capivara Zen | +0,6 regen, aura calma (inimigos ao lado perdem 8% velocidade) | −20% velocidade | aura de lentidão (reaproveita `lentidao`) |
| Cogumelo Andante | esporos tóxicos em volta (dano contínuo) | −25% velocidade, +dano recebido | dano em aura |
| Gárgula | parado por 1,5 s ganha −30% dano recebido | −10% velocidade | estado "parado" |
| Vampiro | cura 3% do dano causado | perde vida na fase de horror/luz forte | roubo de vida; liga com `escuridao.gd` |
| Gato de Sete Vidas | levanta sozinho até 3 vezes por corrida | −40 vida máxima | revive local (mesma lógica do `caido` do online) |
| Pombo Mutante | +30% velocidade, voa sobre buracos/água | −50 vida, coleta menos XP | atravessa terreno |
| Meio-Dragão | +25% área, ligado à transformação do Hazaki | −0,3 sorte, cura −20% | usa `habilidades.gd` |
| Fantasma | atravessa inimigos (sem empurrão) | +25% dano recebido | desliga colisão do herói |

*Só as quatro primeiras e a Goblin são "puro JSON" (esforço P). As demais são ganchos: cada uma pede um pequeno módulo, listados em `ganchos` e registrados como as armas já registram módulos em `armas.MODULOS`.*

**Classes (proposta):** Guerreiro (corpo a corpo, +vida), Mago (projétil/área, −vida), Atirador, Ladino (crítico + velocidade), Clérigo (`reviver` 2×, cura em aura), Invocador, Samurai (a classe do Hazaki), Berserker (dano sobe com vida baixa). Cada classe aponta uma `arma_inicial` de `armas.json` e um `especial` de `especiais.json`: **a classe reaproveita os especiais dos amigos** em vez de criar novos; os heróis fixos (Hazaki, Nicão, Lucas) continuam como estão.

**Aparência:** três níveis, do mais barato ao mais caro: (1) **troca de paleta** (shader de recolorir por máscara sobre a base da raça; esforço P/M); (2) **camadas combináveis** como no sistema de equipamentos atual (cabelo, acessório); (3) corpo novo por raça (arte nova, esforço G; segue o pipeline Blender de `fonte_arte/modelos3d`). **Recomendação:** começar pela paleta + 3 cabelos, e só criar corpos novos para 2 raças.

**Atenção às regras do Breno:** esta tela é a "criação de personagem com raças e opções malucas" pedida; nada aqui cria base.

### 5.2 Preparo antes da corrida: sair com itens (esforço M/G, valor alto)

**Ideia:** depois de escolher (ou criar) o herói, uma tela nova **"Preparo"** onde se monta a mochila e se sai para a corrida. Fluxo: `herois → preparo → calor → partida` (insere um estado `preparo` em `main.gd`, antes de `_abrir_calor`).

**Conteúdo da tela:**

- **Mochila com N espaços** (N vem da classe/raça, ex.: 4 a 8). Cada item ocupa 1 ou 2 espaços.
- **Comida de viagem** (1 a 2): efeito válido a corrida inteira. É a versão sem base do "comida dá vitalidade na expedição". Já temos ícones de comida (marmita, café, energético).
- **Consumíveis**: poção de cura, bomba, pergaminho de sorte, amuleto de reviver. Usados na partida por uma tecla (ex.: Q), com cargas limitadas.
- **Amuleto inicial** (1 passivo de `passivos.json` já no nível 1) e **equipamento vestido** (slots de `equipamentos.json`).
- **Baú pessoal** (lista simples, **não é base**: uma tela de inventário): guarda itens trazidos de corridas anteriores.

**De onde vêm os itens:** a loja do mapa (`loja.gd`) e os baús das fases passam a oferecer uma categoria **"trazer pra casa"**: ao terminar a corrida (vitória ou derrota), até 3 itens marcados vão para o baú pessoal. Decisão de design em aberto: **o que se perde ao morrer?** Sugestão: morrer perde os itens da mochila gastos e mantém o baú; vencer traz tudo. Fica pro Breno decidir.

**Arquivos de dados novos:**

- `dados/itens.json`: `{id, nome, icone, tipo: comida|consumivel|amuleto|equipamento, espacos, efeito{}, raridade, preco}`. Para `amuleto`/`equipamento`, apenas referencia ids já existentes.
- `dados/mochila.json`: capacidade base, bônus por classe/raça, regras de perda ao morrer.
- Save: `user://bau.json` e `user://mochila.json` (como `calor.json` e `recordes.json` já fazem).

**Pontos de código:** `main.gd` (novo estado e tela, desenhada como `tela_calor.gd` faz), `arena.gd` (aplicar mochila no início: some em `Construcao.stats` via o parâmetro `extra`, que já existe para as dádivas), `hud.gd` (barra de consumíveis), `loja.gd` (categoria "trazer").

### 5.3 Magias com elemento e efeitos em camadas (esforço M, valor médio-alto)

- **Elementos e estados:** `armas.json` ganha `elemento` (gelo, fogo, raio, veneno) e `estado` (`congelar`, `queimar`, `chocar`, `envenenar`). Hoje só existe `lentidao`; congelar é lentidão total curta. Em `inimigos.gd`, um campo `estado{tipo, resto}` por inimigo (cuidar do custo com centenas de inimigos: usar arrays paralelos, como o jogo já faz nas posições).
- **Poça persistente:** o vídeo mostra a poça de gelo rachada como zona. `armas.json` já tem tipo `poca` e `poca.gd` gera a arte em cache por tamanho; basta uma variante de gelo (outra rampa de cores) e o efeito de estado.
- **Efeitos em camadas** (a lição do vídeo): cada golpe = flash curto + anel + partículas + névoa. Registrar "receitas" em `dados/efeitos_visuais.json` (lista de camadas com cor, tamanho, duração) e um gerador em `efeitos.gd`. **Risco de desempenho:** o jogo usa `gl_compatibility` e há `docs/PERF_2026-10-06.md`; usar `CPUParticles2D` ou desenho por código com teto, nunca `GPUParticles` sem testar.
- **Equipar 5 magias:** o Dimraeth usa 5; o K.I.K.I.U usa 4 armas + 5 passivos. Não mudar nada: já é parecido.
- **Exigência de atributo (magias universais):** possível via `requer{atributo: valor}` em `armas.json`, filtrado em `cartas.gd` e `Equipamento.permitido`. Útil para ligar classe e raça às armas.

### 5.4 Legibilidade do combate (esforço P/M)

- **Barra de vida em elites/chefes:** o vídeo mostra barra pequena sobre o inimigo roxo. Desenhar só para elites (barato).
- **Marca de área no chão:** círculo/linha antes do golpe. Já proposta no doc anterior; o vídeo confirma o estilo (anel escuro no chão).
- **Etiqueta de drop:** nome flutuante curto ao cair/pegar item (`itens.json` reaproveita `nome`). Teto de etiquetas igual ao dos números de dano (70).
- **Números de dano:** já existem; revisar cor por elemento.

### 5.5 Impacto no online

- **Regra geral:** o anfitrião manda. Cada peer envia **ids** (raça, classe, aparência, mochila), nunca atributos. O anfitrião **recalcula** com os mesmos JSON.
- `rede.gd` hoje guarda `jogadores[peer] = {heroi, nome, pronto}` e recusa herói repetido. Herói criado deve **ser permitido em duplicata** (só os fixos continuam únicos): trocar `heroi` por `{tipo: fixo|criado, id, raca, classe, aparencia, mochila}` e ajustar `_escolher`/`ocupados`.
- **Validar no anfitrião:** raça e classe existem, pontos ≤ orçamento de `criacao.json`, mochila cabe nos espaços, consumíveis ≤ limite. Recusar o que não bater (mesmo padrão de `_escolher`).
- **Mensagens novas** em `EVENTOS`/RPC: nenhuma na horda além de `usar_consumivel`. Efeitos de ganchos locais (aura, revive de gato) devem ser decididos **no anfitrião** quando afetam inimigos ou outros jogadores.
- **Sincronia:** a semente (`sorte.gd`) continua igual para todos; sorteios novos (drops, raridade) devem usar `Sorte.criar(nome, índice)`. Efeitos visuais em camadas são **só locais**, não vão pela rede.
- **Largura de banda:** `estado_rede()` já envia 15 Hz; aparência e raça vão **uma vez**, na entrada da sala, não por quadro.
- **Salvar:** `user://` é local; amigos podem editar o baú. Aceitável para jogo entre amigos; se um dia houver ranking público, vira problema.

## 6. Riscos

| Risco | Gravidade | Como reduzir |
|---|---|---|
| Arte de 8 raças × aparência explode o trabalho | alta | Paleta + camadas; corpo novo só para 2 raças |
| Raças com ganchos quebram equilíbrio (Gato de Sete Vidas, Fantasma) | alta | Ganchos fora do primeiro marco; usar o `--calibrar` e o bot que já existem |
| Estados de elemento custam desempenho com 500 inimigos | média | Arrays paralelos, teto de efeitos, medir com `perf.gd` |
| Online: herói duplicado, mochila forjada | média | Anfitrião recalcula tudo e valida pelos JSON |
| Perda de itens ao morrer frustra | média | Decisão do Breno; começar sem perda |
| Criação demorada afasta quem quer jogar rápido | baixa | Botão "Aleatório" e "Usar último herói" |
| Copiar o Dimraeth | — | Não copiar arte, nomes de magia, texto nem números. Só os conceitos (raça × classe, mochila, elementos), refeitos com a nossa identidade (cavaleiros no caos) |
| Fortaleza/base entrar sem querer | — | Fora do escopo; nenhum item acima cria ou melhora construção |

## 7. Ordem sugerida de implementação

1. **Marco 1: Raça e classe em JSON** (P/M): `racas.json`, `classes.json`, montagem do `heroi` em `Construcao`, tela mínima de escolha (sem aparência), 5 raças só de números. Testável pelo bot.
2. **Marco 2: Criação completa** (M/G): nome, pontos, defeito voluntário, aparência por paleta, salvar herói; validação no online (`rede.gd`).
3. **Marco 3: Preparo e mochila** (M): estado `preparo`, `itens.json`, comida de viagem, consumíveis com tecla, amuleto inicial.
4. **Marco 4: Baú pessoal e "trazer pra casa"** (M): save, categoria na loja, regra de perda.
5. **Marco 5: Elementos, poça de gelo e efeitos em camadas** (M): estados, receitas visuais, teto de desempenho.
6. **Marco 6: Raças com gancho** (M cada): Capivara, Gárgula, Vampiro, Gato de Sete Vidas, uma por vez.
7. **Marco 7: Legibilidade** (P/M): barra de elite, etiqueta de drop, marca de área.

Cada marco deve registrar no `LOGBOOK.md` e atualizar o zip, como já é regra do repo.

## 8. Perguntas para o Breno decidir

1. O que se perde ao morrer: itens da mochila, do baú, ou nada?
2. Quantas raças no primeiro lançamento: 5 (só números) ou todas as 13 da lista?
3. Heróis fixos (Hazaki, Nicão, Lucas) continuam como opção separada? *(sugestão: sim)*
4. Raça tem arte própria já no início ou começa tudo com o mesmo corpo recolorido? *(sugestão: recolorido)*

## Fontes

- Vídeo enviado pelo Breno (Reel de mudtek, 25 s).
- [Steam: Dimraeth](https://store.steampowered.com/app/2402680/Dimraeth/)
- [G2A: Dimraeth, RPG pixel de 8 jogadores](https://www.g2a.com/news/game-spotlights/dimraeth-is-an-8-player-pixel-rpg-where-souls-lite-combat-feeds-a-growing-fantasy-stronghold/)
- `docs/DIMRAETH_ADAPTACAO.md` e o código de `jogos/hordas/projeto` no repo KIKIU-Survival (branch main, commit b70fa08).
