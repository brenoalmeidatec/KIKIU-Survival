# Fusões da v2: por que não se viam e o que mudou

Branch `claude/fusoes-claras`. Escopo: só a v2 (`jogos/hordas/projeto/v2/`, `dados/v2_cartas.json`). A v1 segue pausada.

## Diagnóstico

**Não é bug de disparo.** A fusão dispara quando as duas peças chegam ao nível pedido. A regra está em `v2/cartas.gd` (`_checar_evolucoes`, `_peca_ok`), e `testes/v2_partida.gd` já cobre cada fusão e as lendárias. O que falhou foi a leitura.

Causas, por ordem de peso:

1. **O momento da fusão era pequeno e rápido.** Ela acontece no clique da carta (`progresso.escolher` → `cartas.aplicar` → `combate.evolucao_feita`). O único aviso era a faixa de anúncio do HUD: texto de 16 px, 1,2 s de tela, na fila junto com "NÍVEL N!" e "ONDA FORTE!". Não havia pausa, nem cartão grande, nem câmera lenta. O flash e os anéis duravam 0,25 a 0,7 s, no meio da ação.
2. **A receita não aparecia antes.** A carta de uma peça dizia só "Evolui: Anel de Brasas", sem dizer com quem junta nem em qual nível. O jogador tinha que lembrar a receita de cabeça.
3. **A dica da SUA BUILD some quando a coluna não cabe.** `v2/status.gd` tira as "dicas de evolução" primeiro (`_sem_dicas`) quando o conteúdo estoura a altura. Com build cheia, a receita das fusões que faltam não aparece justamente quando mais importa. (Não mexi nisso nesta entrega: fica para uma próxima.)
4. **O poder e o visual das fusões eram tímidos.** A Ventania Cortante não cria arma nova: o corte fica 1,9× mais forte e 1,6× mais largo, e a estocada vira três lanças. Nas armas evoluídas, o halo tinha alfa 0,55 contra 0,42 da arma normal: quase igual.

Não tenho o caso exato do Breno (qual fusão ele fechou). Com base no que o relato descreve ("tinha tudo e nada aconteceu"), a causa mais provável é a 1, somada à 2: a fusão aconteceu, mas passou em 1,2 s, com um texto de 16 px, sem que a receita tivesse sido lida antes.

## O que mudou

| Área | Antes | Depois |
|---|---|---|
| Carta (rodapé) | "Evolui: Anel de Brasas" | "Lâminas nv3 » FUSÃO Anel" (cabe numa linha de 16 px; sem "FUSÃO" quando não cabe, como em "Esqueleto nv3 » Exército") |
| Momento da fusão | faixa pequena de 1,2 s | cartão grande no centro ("FUSÃO!", nome em Jersey 10 de 37 px e o que faz em Spleen 16 px), 2 s |
| Tempo | nenhum | hit-stop de 0,10 s e câmera lenta de 0,6 s a 35% |
| Som | `evolucao.wav` | o mesmo (já era distinto) |
| Ventania Cortante | onda 1,9× de dano e 1,6× de largura | onda **2,4×** de dano (+26%) e **2,0×** de largura (+25%) |
| Armas evoluídas | halo 0,55 de alfa | halo maior (48 px, alfa 0,5) com miolo branco |

Nomes curtos novos em `dados/v2_cartas.json` (campo `curto`), para o rodapé da carta caber: Dragão, Caçada, Exército, Colosso, Chuva, Bola, Nevasca, Cinzas, Terra, Pedreira, Cometa, Ferro, Peste, Juramento, Eclipse, Tempestade, Almas, Juízo, Furacão, Urso.

### Números antes e depois (Ventania)

Com 2 cartas comuns de Corte ondulante (80%) e 2 de Estocada perfurante:

| Medida | Antes | Depois | Ganho |
|---|---|---|---|
| Dano da onda, em % do dano do corte | 80% × 1,9 = 152% | 80% × 2,4 = 192% | +26% |
| Largura da faixa da onda | 34 × 1,6 = 54 px | 34 × 2,0 = 68 px | +25% |
| Lanças por estocada | 3 | 3 | — |

Balanço: as outras fusões ficam como estavam. A Ventania é a única que muda o número, porque era a mais fraca em relação às outras (não criava arma nova). Confira no teste `v2_partida` ("a Ventania leva a onda a 80% x 2,4").

## Pesquisa: como os jogos do gênero mostram a fusão

Fontes: busca na web em outubro de 2026 (Vampire Survivors) e conhecimento do gênero. A busca sobre Brotato, Death Must Die, Halls of Torment e Soulstone Survivors não trouxe nada sobre o sistema de fusão deles, então o que está abaixo desses quatro é de memória e precisa de confirmação antes de virar regra.

- **Vampire Survivors (evoluções).** A receita é visível: a coleção mostra a arma base, o item passivo parceiro e a evolução. Quando a arma e o parceiro estão prontos, o jogo avisa, e a evolução só sai ao abrir um baú. Lição: mostrar a receita antes e deixar a "hora da fusão" acontecer num momento próprio. Nós fazemos a fusão no clique (sem baú): precisamos de um momento mais marcado. Fontes: [Primagames, como evoluir armas](https://primagames.com/tips/how-to-evolve-weapons-in-vampire-survivors), [Vampire Survivors Wiki, Evolution](https://vampire-survivors.fandom.com/wiki/Evolution).
- **Vampire Survivors (regra de uma por partida).** Já temos (lendárias: uma por partida). O jogador entende melhor quando o aviso diz isso.
- **Hades (duo boons).** Memória: a dica aparece no próprio item que o jogador escolhe ("com X, vira Y"). Lição: o aviso fica na carta, não num menu separado.
- **Brotato, Death Must Die, Halls of Torment, Soulstone Survivors.** Memória, sem confirmação: fusões ou evoluções com receita visível no menu de armas, e um efeito grande e curto na hora da evolução. Confirmar antes de citar como regra.

## Próximos passos (fora desta entrega)

- Dica da receita na SUA BUILD mesmo com a coluna cheia (hoje cai primeiro).
- Ventania com cor e partículas próprias (hoje só a largura e o dano mudam).
- Arte da fusão e do cartão: ver `FUSOES_ARTE_ALISSON.md`.
