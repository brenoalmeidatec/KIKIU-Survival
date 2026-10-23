# O que os survivors de sucesso têm e o KIKIU ainda não

Pesquisa de 23/10/2026 (dia da v2.0-beta). Só leitura e pesquisa: **nada muda no jogo agora**.
Complementa `docs/ANALISE_10_JOGOS_HORDAS.md` (de outubro), que já cobre Brotato, 20MTD, Halls of Torment, DRG Survivor, Soulstone, Death Must Die, HoloCure, Hades, StS e Archero. Aqui o foco é outro: **comparar com o que a v2 já tem hoje na `main`** e separar o que cabe antes da RC (26/10) do que vai para a v3.

## O que a v2 já tem (conferido no código e em `dados/v2_*.json`)

| Sistema | Situação na v2 |
|---|---|
| Heróis | 3 (Hazaki, Nicão, Lucas) |
| Mapas | 4 (floresta, laboratório, cidade, médio) + F/M/D + modo Pesadelo |
| Golpes / evoluções | 52 golpes, 27 evoluções, carta já avisa "evolui" |
| Escolha de carta | 3 cartas, rerrolar (1 por tela, 3 no total), banir (2), roleta |
| Modificador do ataque principal | 8 (onda, estocada, crítico explosivo, fôlego, abalo...), equivalente às "estampas" do HoloCure |
| Baú, elites, chefes, especial/ultimate | sim |
| Meta | 9 melhorias com almas, 8 conquistas, 1 visual desbloqueável |
| Números de dano, controle (joypad), pausa | sim |
| Tela de fim | tempo, abates, maior combo, nível |

## O que falta, priorizado (impacto x esforço)

Impacto e esforço de 1 a 3. **Antes da RC** = cabe até o congelamento de domingo à noite, sem mexer em sistema; o resto é **v3**.

### Antes da RC (26/10): pequeno, mais dados e UI do que sistema

| # | O que | De onde vem | Impacto | Esforço | Por que vale |
|---|---|---|---|---|---|
| 1 | **Dano por golpe na tela de fim** (barra por arma, % do total, DPS) | VS, Brotato, HoloCure | 3 | 1 | O jogador entende a build e quer testar outra. Os contadores já existem em `armas.gd`/`status.gd`; falta mostrar. |
| 2 | **Mais conquistas que destravam coisas** (8 → ~25: "evolua X", "vença sem curar", "500 abates com Lucas") | VS (conquista destrava arma/herói), Halls of Torment (centenas de missões) | 3 | 1 | É o motor do "só mais uma". Quase tudo é `dados/v2_meta.json` + checagem que já existe em `conquistas.gd`. |
| 3 | **Dica de evolução no pause** (lista "golpe + passiva = evolução" do que já foi visto) | VS (Grimório na subida de nível) | 2 | 1 | Hoje a carta avisa, mas o jogador não planeja. |
| 4 | **Recorde por herói x mapa x dificuldade** na tela de escolha | 20MTD, VS | 2 | 1 | Dá meta pessoal sem conteúdo novo. |

> Se o congelamento apertar, só o **#1** e o **#2** já valem a RC.

### v3: o que muda o jogo de verdade

| # | O que | De onde vem | Impacto | Esforço | Nota |
|---|---|---|---|---|---|
| 5 | **Mais heróis** (3 → 6-8, cada um com estilo próprio) | Halls of Torment (7 na estreia), HoloCure, VS | 3 | 3 | O maior buraco. O pipeline do Blender já existe; o custo é arte + golpes. |
| 6 | **Modo infinito** depois de vencer o mapa (dificuldade sobe sem fim, placar de tempo) | VS (Endless), Kingdom Survivors, pedido recorrente nos fóruns de DRG Survivor | 3 | 2 | Reaproveita `ritmo.gd`/`diretor.gd`; precisa de teto de vivos (como o #195 da v1) e rerrolagens extras. |
| 7 | **Maldição / "calor"**: o jogador aumenta o risco e ganha mais almas | VS (Curse), Hades (Heat), Halls of Torment (Agony) | 3 | 2 | Põe a dificuldade na mão do jogador e estica a vida do jogo. |
| 8 | **Fusão de dois golpes no máximo** (colab) | HoloCure (collab e super collab) | 3 | 2 | Pico de poder previsível que o jogador caça. As 27 evoluções já são a base. |
| 9 | **Overclock em nível fixo** (nível 6, 12, 18: escolha que muda a função do golpe) | DRG Survivor | 2 | 2 | Estende os modificadores atuais para todos os golpes. |
| 10 | **Coleção / bestiário** (monstros vistos, golpes, evoluções descobertas com "???") | VS (Coleção), HoloCure | 2 | 2 | Completar a coleção é meta barata e viciante. |
| 11 | **Missões longas** (centenas, cada uma com prêmio pequeno) | Halls of Torment | 2 | 2 | Substitui grind cego por objetivos. Casa com o #2. |
| 12 | **Equipamento com raridade** que sobe da partida para a conta | Halls of Torment (poço) | 2 | 3 | Já está no plano da `ANALISE_10_JOGOS_HORDAS.md`. |
| 13 | **Objetivo no mapa e terreno que quebra** (minerar, escoltar, extrair) | DRG Survivor | 2 | 3 | Dá identidade aos 4 mapas além da cor. |
| 14 | **Retomar a partida** depois de sair | Kingdom Survivors, VS | 2 | 3 | Save no meio da partida: risco de save corrompido, só com testes. |
| 15 | **Coop local** (2 jogadores, mesmo PC) | VS (coop local), HoloCure | 3 | 3 | Grande, mas os amigos reais são o trunfo do KIKIU. |
| 16 | **Hub com mini-jogos** (pesca, cassino de almas) | HoloCure (Holo House) | 1 | 3 | Bonito, mas não é prioridade. |

## Código aberto: o que dá para aproveitar

Achei clones em Godot (TriStaRvOiD/Survival-Game, Jonixo/Godot-VampireSurvivorClone, J35P1N/godot4-vampire-survivors-clone). São **tutoriais pequenos**, mais simples que a v2: servem de referência de padrão, não de código para copiar. O primeiro é **GPL v3 (copyleft)**, e a regra do repo é não usar copyleft sem falar com o Alisson. Conclusão: **nada para importar**; a v2 já está à frente deles.

## Fontes
- [Vampire Survivors e a psicologia do jogo de azar (Univ. de Portsmouth)](https://researchportal.port.ac.uk/en/publications/vampire-survivors-how-developers-used-gambling-psychology-to-crea/)
- [The Secret Sauce of Vampire Survivors](https://jboger.substack.com/p/the-secret-sauce-of-vampire-survivors)
- [VS: atualização de QoL e modo Endless](https://mp1st.com/?p=310737)
- [Games like Vampire Survivors (Brotato, Halls of Torment)](https://summerengine.com/blog/games-like-vampire-survivors)
- [Halls of Torment no Steam](https://store.steampowered.com/app/2218750) e [discussões de missões/Agony](https://steamcommunity.com/app/2218750/discussions/0/4033602326794313190)
- [HoloCure (Wikipedia)](https://en.wikipedia.org/wiki/HoloCure_%E2%80%93_Save_the_Fans!) e [Fan Letters](https://www.siliconera.com/what-are-fan-letters-in-holocure-and-how-to-get-them/)
- [DRG Survivor: overclocks](https://www.ginx.tv/en/survivor-unlock-all-overclocks-weapons) e [GameSpot sobre mineração](https://gamespot.com/articles/deep-rock-galactics-vampire-survivors-style-game-excels-by-giving-you-something-new-to-do/1100-6521414/)
- [Pedido de modo infinito no DRG Survivor](https://steamcommunity.com/app/2321470/discussions/0/4352240067027393600)
- [TriStaRvOiD/Survival-Game (GPL v3)](https://github.com/TriStaRvOiD/Survival-Game)
