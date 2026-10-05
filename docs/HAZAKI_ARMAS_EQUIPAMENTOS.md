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

## 6. Como a transformação do Hazaki funciona
É a issue #20 (próximo passo). O sistema de camadas já foi feito pensando nela: ao transformar, as camadas humanas são escondidas e o dragão entra; ao voltar, `atualizar_visual()` remonta **exatamente** o que estava (vem das armas e equipamentos atuais). Também não conta como arma exclusiva (seção 13).

## 7. Como adicionar outro personagem com 5 armas exclusivas (e transformação)
1. **Personagem:** uma entrada no `herois.json`. Pra ele ter equipamentos visíveis, faça o modelo em camadas copiando `fonte_arte/modelos3d/hazaki.py` (corpo + uma camada por equipamento) e marque `"camadas": true`.
2. **Armas exclusivas:** no `armas.json`, com `"classe": "character_exclusive", "characterId": "<id>"`. Se a arma precisar de comportamento novo, crie `scripts/hordas/armas/<tipo>.gd` (copie o `katana.gd`) e registre em `MODULOS` no `armas.gd`. Se ela aparece na mão, ponha `"visual"` com a camada e as mãos.
3. **Equipamentos:** no `equipamentos.json`, com `"characterId"` dele e a `camada` gerada pelo modelo.
4. **Testes:** rode `testes/regras_armas.tscn` e `testes/equipamentos.tscn`.
5. **Transformação:** vem com a #20/#21 (estrutura genérica `DiscoverableAbility`, seção 31).

**Limitações conhecidas:** no online, os outros jogadores veem o Hazaki com cabelo, mas ainda sem os equipamentos (não vão pela rede). Rivais do duelo também aparecem sem equipamento.
