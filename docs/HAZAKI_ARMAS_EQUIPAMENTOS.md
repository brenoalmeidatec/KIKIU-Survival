# Hazaki, armas exclusivas e equipamentos visuais (respostas da seção 15)

Implementação da issue #19 (`docs/DESIGN_PERSONAGENS_E_DESCOBERTAS.md`, seções 1 a 7, 11, 12, 14 e 15), em 3 PRs: #23 (base), #24 (armas) e o PR dos equipamentos.

## 1. O que foi alterado
- O personagem **Breno virou Hazaki** no jogo de horda (id `hazaki`, nome, arte, elenco, herói padrão). A Cairu não mudou.
- As armas agora são **globais** ou **exclusivas de um personagem**, com **limite de 2 exclusivas por partida** (configurável).
- **5 armas exclusivas do Hazaki**, cada uma com comportamento e visual próprios: Katana Samurai, Duas Desert Eagles, Arte Marcial, Aura e Poder Elemental do Mago.
- **Equipamentos visuais modulares:** o Hazaki é desenhado em camadas, e o que ele veste e segura aparece nele (Cabeça do Guerreiro, Armadura Samurai, Máscara Menpo, Braçadeiras de Ferro, Botas de Guerra, katana na mão ou na bainha, pistolas nas mãos, aura).
- Cartas mostram **"EXCLUSIVA n/2"** e **"EQUIPAMENTO"**; o HUD mostra os equipamentos vestidos.

## 2. Arquivos e sistemas
| Onde | O quê |
|---|---|
| `dados/armas.json` | `classe`, `characterId`, `_config.limite_exclusivas`, `peso_carta`, `familia`, `visual` |
| `dados/equipamentos.json` (novo) | equipamentos (slot, camada, bônus, o que esconde, dono) e a ordem de desenho |
| `dados/herois.json` | `hazaki` com `"camadas": true` |
| `scripts/hordas/construcao.gd` | regra única das armas (`arma_permitida`, `exclusiva`, `dono`, `n_exclusivas`); `stats()` soma equipamentos |
| `scripts/hordas/equipamento.gd` (novo) | regra dos equipamentos (`permitido`, `bonus`) e o montador de camadas (`camadas`) |
| `scripts/hordas/armas.gd` + `scripts/hordas/armas/*.gd` (novos) | registro `MODULOS` e um arquivo por comportamento novo |
| `scripts/hordas/arena.gd` | cartas de arma e equipamento, `aplicar`, `atualizar_visual` |
| `scripts/hordas/jogador.gd` | `definir_camadas`: empilha as camadas por cima do corpo |
| `fonte_arte/modelos3d/hazaki.py` (novo) | o Hazaki no Blender: corpo + uma camada por equipamento/arma |
| `testes/regras_armas.tscn`, `testes/equipamentos.tscn` (novos) | testes automáticos |

## 3. Como funciona o limite de 2 armas exclusivas
`construcao.arma_permitida(id, heroi, armas_atuais)` decide se uma arma pode ser oferecida como **nova**:
- arma **global** pode, se ele ainda não tem;
- arma **exclusiva** só pode se for **do próprio personagem** e se ele tiver **menos de `_config.limite_exclusivas`** exclusivas (2).

A mesma função serve pras cartas do jogador, pro baú e pra build dos robôs do duelo: **nunca aparece carta impossível**. As exclusivas que ele já tem continuam subindo de nível. Pra mudar o limite, basta trocar `limite_exclusivas` no `armas.json`.

## 4. Como o sistema identifica armas globais e exclusivas
Pelo campo `"classe"` de cada arma no `armas.json`: sem o campo (ou `"global"`) a arma é de qualquer um; `"character_exclusive"` com `"characterId": "hazaki"` é só dele. Evolução de arma exclusiva também deve ser marcada como exclusiva.

## 5. Como funciona o sistema modular de equipamentos
- Cada equipamento (`dados/equipamentos.json`) ocupa **um slot** (cabeça, rosto, peitoral, braços, pés...) e soma **bônus** como um passivo. Equipamentos de slots diferentes **convivem** (a armadura não tira o elmo). Slot ocupado não é oferecido de novo.
- **Visual:** no Blender, cada peça é **presa aos mesmos ossos** do corpo e renderizada na **sua própria camada**, com o corpo como **máscara invisível** (o que fica atrás do corpo sai recortado). Tudo sai com a mesma câmera, pose, escala, paleta e luz. Por isso nada atravessa, nada flutua e as cores combinam (seção 7).
- **No jogo:** `equipamento.camadas()` monta a lista do que desenhar: o cabelo, os equipamentos (um pode **esconder** outro: o elmo esconde o cabelo) e as armas com `visual`, que **disputam as mãos** pela prioridade. As pistolas ganham as duas mãos, e aí a katana vai **pra bainha**; a Arte Marcial não põe nada nas mãos. O `jogador.gd` empilha essas camadas como filhas do sprite do corpo, então elas herdam a animação, o piscar e o "caído".
- A **Aura** é desenhada **atrás** do corpo (a energia sai de trás e não esconde o equipamento).

## 6. Como a transformação do Hazaki funciona (#20)
**Dragão Cobalto:** um dragão oriental com identidade própria (nada copiado). Tem escamas de cobalto, a mesma energia da aura, ventre e chifres de ouro velho, juba de chamas vermelhas e bigodes de energia ciano.
- **Modelo:** `fonte_arte/modelos3d/dragao.py` gera cada peça (cabeça, gomos, patas, cauda) em 16 direções, com e sem contorno.
- **No jogo:** `scripts/hordas/dragao.gd` monta uma **corrente** que segue o rastro da cabeça, serpenteia e ondula no ar, com sombra no chão. Ela é desenhada em duas passadas, pra o corpo virar um tubo só.

**Ciclo** (`scripts/hordas/habilidades.gd` + `dados/habilidades.json`, seções 25 e 26):
1. A transformação fica **bloqueada** até a condição de desbloqueio. Hoje é o nível 8; na #21 vira "juntou os fragmentos dos santuários".
2. Desbloqueada, a **Energia Dracônica** enche com abates (elite e chefe enchem mais) e com o tempo. A barra fica no HUD, embaixo dos "Abates".
3. Cheia, **Q** (ou X no controle) transforma.
4. Transformado, a energia esvazia em 15–30 s (18 × o atributo duração). Ao acabar, ele volta sozinho e começa uma recarga.
5. A energia pedida **cresce a cada uso** (100, 160, 220...), pra transformar continuar sendo um momento e não o normal.

**Enquanto é dragão:**
- As armas humanas **param intactas** (`armas.forma_lista`) e só atacam as quatro habilidades do dragão. Elas ficam no `armas.json` com `classe: "transformacao"`, que nunca vira carta nem conta no limite de exclusivas (seção 13):
  - **Baforada:** cone de fogo que mira o vírus mais perto, com queimadura e explosão nos níveis altos.
  - **Garras:** atacam nas patas da corrente.
  - **Energia Dracônica:** orbes que perseguem e explodem.
  - **Rugido:** onda que empurra e **atordoa** os fracos (`inimigos.gd` ganhou `atordoado`); chefe e elite só ficam lentos.
- O nível das habilidades sobe com o nível do jogador.
- O dash vira **investida**, que vai mais longe e machuca no caminho.
- +20% de velocidade, +25% de dano e 40% menos dano recebido.
- Cartas escolhidas durante a forma evoluem a build **humana**.

**Ao voltar:** o corpo humano reaparece com o equipamento exatamente igual, porque as camadas são filhas do sprite e só ficam escondidas. As armas e os níveis também voltam iguais; isso é verificado em `testes/transformacao.tscn`.

**Onde não transforma:** no duelo final (é entre humanos; se estiver transformado, volta na hora) e no online (ainda não vai pela rede).

## 7. Como adicionar outro personagem com 5 armas exclusivas (e transformação)
1. **Personagem:** uma entrada no `herois.json`. Pra ele ter equipamentos visíveis, faça o modelo em camadas copiando `fonte_arte/modelos3d/hazaki.py` (corpo + uma camada por equipamento) e marque `"camadas": true`.
2. **Armas exclusivas:** no `armas.json`, com `"classe": "character_exclusive", "characterId": "<id>"`. Se a arma precisar de comportamento novo, crie `scripts/hordas/armas/<tipo>.gd` (copie o `katana.gd`) e registre em `MODULOS` no `armas.gd`. Se ela aparece na mão, ponha `"visual"` com a camada e as mãos.
3. **Equipamentos:** no `equipamentos.json`, com `"characterId"` dele e a `camada` gerada pelo modelo.
4. **Testes:** rode `testes/regras_armas.tscn`, `testes/equipamentos.tscn` e `testes/transformacao.tscn`.
5. **Transformação:** uma entrada no `dados/habilidades.json` com `"tipo": "transformacao"` e o `characterId` dele (a estrutura genérica `DiscoverableAbility`, seção 31). Faça as armas da forma no `armas.json` com `"classe": "transformacao"` (os módulos podem reaproveitar os do dragão ou ser novos). O corpo da forma é o `visual`: hoje só existe `dragao` (`dragao.gd`). Uma forma nova (demoníaca, colossal...) pode ser um script parecido, e o ponto onde ele é criado é `transformar()` em `habilidades.gd`.

**Limitações conhecidas:** no online, os outros jogadores veem o Hazaki com cabelo, mas ainda sem os equipamentos (não vão pela rede). Rivais do duelo também aparecem sem equipamento.
