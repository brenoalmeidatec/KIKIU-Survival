# Dificuldade da partida

As regras ficam em `dados/v2_dificuldade.json`. Os IDs são `facil`, `medio` e
`dificil`; um save sem escolha e um ID desconhecido usam Fácil. A preferência fica
no save do personagem. `Meta.aplicar` copia as regras para
`mundo.meta_bonus.dificuldade`; o resultado usa essa cópia, mesmo se a preferência
do save mudar durante a partida. `-- --dificuldade=<id>` permite testar uma regra
sem alterar a preferência persistida.

| Campo | Onde faz efeito |
|---|---|
| `xp_mult` | XP recebido ao coletar o orbe, para subir níveis |
| `almas_mult` | Crédito final, composto com Almas abundantes e Pesadelo |
| `vel_mult` | Velocidade de perseguição de monstros e chefes |
| `densidade_mult` | Taxa, teto e tamanho de ondas do diretor |
| `onda_tempo_mult`, `elite_tempo_mult` | Intervalos das ondas e elites |
| `chefe_tempo_mult` | Duração dos níveis do mapa antes dos chefes |
| `golpe_custo`, `golpe_calor` | Fôlego por golpe e espera após zerá-lo |

XP e almas têm bases independentes: os orbes carregam o XP-base com o bônus de
combo. `xp_coletado` guarda essa base para a moeda e o mercador; somente o XP
entregue à progressão recebe `xp_mult`. O crédito final aplica `almas_mult` uma
vez. Isso evita que os dois bônus se multipliquem sobre a mesma moeda.

Pesadelo é um modificador independente, com as regras existentes. As três
conquistas de dificuldade usam o prefixo `vence_dificuldade_`; `vence_medio`
continua identificando a vitória nas Ruínas. Resultados antigos sem dificuldade
preservam conquistas de mapa, sem inventar uma vitória em Fácil.

O diretor concentra a leitura em `dificuldade(chave)`, `intervalo_onda()` e
`intervalo_elite()`. Aplicar regras depois de restaurar os atributos de um monstro
do pool evita acumular velocidade a cada renascimento. Chefes reaplicam a regra
de velocidade depois de receber os atributos próprios da marca.

`EscolhaDificuldade` é um Control modal de 960×540, centralizado na UI do salão.
`abrir(nome_mapa)` lê a preferência; cancelar não grava; confirmar só emite
`confirmou(id)` depois de salvar com sucesso. O salão deve bloquear caminhada e
outras interações enquanto o modal estiver visível. Os testes do componente e das
regras ficam em `testes/v2_escolha_dificuldade` e `testes/v2_dificuldade`.

Na preparação do PR #390, a ligação ao portal e o ajuste da lista de cinco/seis
conquistas no resultado aguardam a liberação dos trechos compartilhados na #348.
