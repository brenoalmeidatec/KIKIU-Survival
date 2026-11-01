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

O golpe gasta fôlego mas **não adia a recuperação** (correr, esquivar e escudo
adiam). Com golpes a cada ~0,35 s, o atraso de 0,6 s nunca vencia e a barra só
descia: segurando o ataque, zerava em ~4,7 s no Médio e ~3,3 s no Difícil
(relato do Alisson, 22/10). Agora a regeneração andando (0,5/s) desconta o gasto:
o mesmo ataque segurado dura ~22 s no Médio e ~8 s no Difícil, e parado quase
se sustenta. O robô grava `golpe_bloq_s` e `cansado_s` no JSON do playtest.

XP e almas têm bases independentes: os orbes carregam o XP-base com o bônus de
combo. `xp_coletado` guarda essa base para a moeda e o mercador; somente o XP
entregue à progressão recebe `xp_mult`. O crédito final aplica `almas_mult` uma
vez. Isso evita que os dois bônus se multipliquem sobre a mesma moeda.

Os valores atuais são `almas_mult` 1,0 / 1,5 / 2,25 e `xp_mult` 1,0 / 1,25 / 1,6
(Fácil / Médio / Difícil; decisão D21 do plano de 01/11, ECO-4). O cartão de
escolha mostra os dois bônus separados ("ALMAS +50%", "XP +25%"), lidos desses
campos. Com o Pesadelo, as almas do Difícil sobem a até 3,4x.

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

O portal monta o componente no salão e preserva o ponto existente de troca de
cena. A lista de conquistas do resultado comporta até seis nomes em três linhas,
acima de CONTINUAR, sem diminuir a fonte.
