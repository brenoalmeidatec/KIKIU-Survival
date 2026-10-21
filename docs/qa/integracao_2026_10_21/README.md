# Integração local v2 — 21/10/2026

Ramo de QA: `wip/integracao-v2-2026-10-21`, iniciado em `origin/main` (`dc497dd0e21788c4a30fa56ee0ffb2ff471deba5`). Esta integração preserva os históricos por merges locais normais; não publica PR agregado nem altera `main`. O patch de texto/OAuth do workflow (#393) ficou fora da integração, sem alteração do workflow ativo.

## Integridade do produto

A árvore rastreada de `jogos/hordas/projeto`, excluindo `testes/`, foi idêntica em toda a bateria: SHA-256 `9911483f7369fad163044accf8aa74328ab4370e05852c915959c69c2e5946d7` (2.448 arquivos). Os merges posteriores às primeiras cenas verdes alteraram documentação e testes; `v2_transicoes.gd` recebeu a compatibilidade com o modal de dificuldade antes de sua prova final.

O teste `v2_status` foi repetido em saves base e migrável após a guarda do harness ser dividida em: hashes e tamanhos dos seis saves raiz; remoção da fixture da cena e ausência de resíduos em `testes_v2`; inventário raiz sem arquivos ou diretórios inesperados. Três sentinelas sintéticos dentro da fixture foram removidos em ambas as variantes. Os seis saves e o conjunto golden permaneceram inalterados. A primeira medição recursiva do harness foi preservada como erro do próprio harness: contou artefatos temporários da fixture como saves protegidos; o processo Godot terminou com `falhas=0`, e a guarda corrigida foi repetida.

## Bateria local focada

Foram concluídos 29 processos Godot 4.4.1 na matriz final, todos com saída 0, `falhas=0`, sem `SCRIPT ERROR`, fixture limpa e hashes protegidos intactos: 14 cenas em base e migrável, mais `v2_isolamento` em base. As 14 cenas pareadas foram `v2_adagas_impacto`, `v2_combate`, `v2_combate_fases`, `v2_golpes_visuais`, `v2_hud`, `v2_hud_barras`, `v2_hud_busto`, `v2_hud_golpes`, `v2_hud_layout`, `v2_pesadelo`, `v2_ritmo`, `v2_robo_borda`, `v2_status` e `v2_transicoes`.

Houve três execuções diagnósticas adicionais: duas repetições de `v2_status` base (uma identificou apenas o falso positivo do snapshot recursivo; a outra passou antes da semeadura explícita) e uma execução prévia de `v2_transicoes` base com uma asserção desatualizada para a tela de dificuldade integrada. O teste foi corrigido no commit de origem `72f7c5dc2603793d5bec0190b6d2d7dd357ed8f9` para confirmar a dificuldade pela entrada real; as variantes base e migrável passaram depois dessa correção. O erro do harness anterior à inicialização do Godot não conta como processo.

`gdformat -l 160 --check jogos/hordas/projeto/scripts jogos/hordas/projeto/testes jogos/hordas/projeto/v2` verificou 347 arquivos sem mudanças necessárias.

## Partidas longas integradas

O runner da bateria conjunta terminou com código 0. Hazaki, Nicão e Lucas venceram na Floresta, Fácil, semente 1, com Q ativo; durações de jogo de 736,4 s, 682,1 s e 716,0 s. Não houve derrota, teto, trava ou ausência de JSON. Os 169 hashes dos arquivos `v2/` e `dados/` conferem com o produto integrado. O manifesto sanitizado completo está em [robo.json](robo.json). A prova cobre uma combinação de mapa/dificuldade/semente e não é uma comparação de FPS renderizado nem uma avaliação de equilíbrio humano para todos os mapas.

## Origens e merges locais

Cada linha registra o HEAD de origem e o merge local correspondente. Todos foram merges `ort` normais; não houve conflito textual para resolver.

| Commit de origem | Merge local | Assunto da origem |
| --- | --- | --- |
| `68bf0230bde1f69652bae947017309d65fa9a0f9` | `2c593f320d9bd220bcaf372a0afd7647d36baf07` | Documenta as 24 medições de FPS do produto 4b73d15 |
| `f3119e0a5917015d26bae224fd88e59278d145f3` | `abd79acb90ad7b7bce49649cc16c33d1c03bfeb1` | Preserva guard dos GIFs junto da fixture de testes |
| `b0b7ed8869eab6accceb6fc509c90cd589fe0e59` | `9e2a53d3fbcadd901ea27aa68fde1fa2e5063195` | Alinha cliques da pausa às linhas durante os slides |
| `8f9256c1a322b14986dc3eacbff01f33b9b6bea4` | `7a56eca6840a70cca9faaa1faecd6b290d0202fd` | Ajustes da revisão da roleta e baú |
| `3327cdc459562b938081c0949b607e147da1899f` | `1821595067bbeddd6fd7131bbd2e992a61c8ef0b` | Testes e resultados da dificuldade |
| `076018d637327bafeb8f6a69b426d650dc857e28` | `b4f874442ecf68264047e8614bbf3de0aa770765` | Ícones próprios da E de Nicão e Lucas |
| `ca7b87f5cb11d6df3560493175498d4133c175eb` | `f5f9c97335cb78c78ca35f946524c7412550c727` | Espessura e layout das barras do HUD |
| `3681c15043879bb1d2b2bdcbff10653a1b28abb0` | `ed419334194dec558634e37bf41ce93998cdf431` | Vigia de imobilidade |
| `808f096c3cc58dbc8b2a8646ffd07fb486282d12` | `4d69d0a544fe15c72c4f973e658ff35cfafbc90a` | Comparação controlada do ritmo e regressão do robô |
| `e5bdd32ce171e2413374fbdb80f60480e4a60fa2` | `1bb34d881ff942091cce9e429b8914f79818eff4` | Seleção de alvos nos segmentos ativos das adagas |
| `b12b07bb57c8ec52bb8cccb5328d84b3b01ad2d5` | `9e67a905ec74bd9fd3213ee553a02e7b4935fc26` | Isolamento e limpeza das fixtures dos golpes |
| `5f132dc0b34c87d33edf70259d94327dadc458cf` | `334db44bce0e86317d5364a39875ec7c7abbb93c` | Repetição do robô após correção do alcance de Q |
| `63a4d7c42ff57014de8135771c05c7299e6ef3a3` | `33723e7ce2b6552dc1121a89ee8cc7d2a763c09c` | Testes de steering de borda com fixture isolada |
| `72149ecc3570d7915d654b6eeb0a08ef942480e9` | `efe7fb672fb6e90eedc67669551c3c488e36605a` | Fixture canônica na prova de ritmo |
| `511ce161a5846f43935cf0e72f24d9d9c3dafed9` | `8ff3b69a44ab38c21d9ff9e2d7585910c530d735` | Fixture isolada e propagação de falhas das transições |
| `72f7c5dc2603793d5bec0190b6d2d7dd357ed8f9` | `d66da75734245d838bdc86762408447ab43c56e2` | Confirma a dificuldade real no fluxo integrado |
| `8b1411c1ebb0d0465ca1217efc795414d61af4c1` | `7ce429ca4c9e5342b787c60a47d4109071fe9e36` | Documentação após a margem completa da adaga extra |

O workflow ainda não foi executado neste HEAD final: ele não tem gatilho `push`; falta integrar o append autorizado do `LOGBOOK` e então solicitar `workflow_dispatch` para o SHA final, aguardando os sete jobs terminarem verdes.
