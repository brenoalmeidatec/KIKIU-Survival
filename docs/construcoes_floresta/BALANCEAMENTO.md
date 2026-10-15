# Balanceamento das construções da floresta

Este arquivo compara as 17 construções e registra o parecer de revisão. Os números de referência vêm do código e dos dados da v2 (`dados/v2_combate.json`, `dados/inimigos.json`, `dados/fase.json`, `dados/prorrogacao.json`, `dados/v2_medio.json`, `dados/v2_cartas.json`, `dados/v2_meta.json`).

## Números de referência (o que a construção compete com)

| Item | Valor | Fonte |
|---|---|---|
| Vida inicial do herói (Hazaki) | 100 | v2_combate.json > heroi.vida |
| Katana, golpes do combo | 12, 13, 26 de dano | v2_combate.json > golpe.passos |
| Cura por nível | 12% da vida máxima | v2_combate.json > heroi.cura_nivel |
| Almas por partida | XP / 10 | v2/mundo.gd (`almas_partida`) |
| XP de abate comum | 1 (cogumelo, lobo, corvo), 2 (aranha), 5 (espantalho), 12 (galhudo) | inimigos.json |
| XP de mini-chefe | 30 (3 min), 60 (6 min); chefe final 150 (10 min) | v2_cartas.json > chefes.marcas |
| Baú do mapa médio | 3 cartas (forcar 3) | v2_medio.json |
| Mercador do mapa médio | 8 almas por carta, 1 carta | v2_medio.json |
| Teto de monstros vivos | 250 (normal) | fase.json > dificuldade |
| Elite | a 45 s, depois a cada 50 s, máx. 2 vivos; vida x6, dano x1,5 | v2_cartas.json > elites |
| Duração de referência | 10 min (600 s), chefe final em 600 s | fase.json |

Estimativa de almas por partida: não medida. Os benches de `testes/bench_*.tscn` não têm registro de almas por minuto na documentação. Sugestão de medição antes de fechar a conta de almas: rodar a partida de referência e anotar as almas de cada minuto.

## Regras de balanceamento usadas

1. **Toda vantagem tem preço.** Ou tempo parado no meio da horda, ou vida, ou almas, ou risco de elite, ou debuff. Nenhuma construção cura de graça nem dá invencibilidade.
2. **Uso limitado por partida.** A maioria tem 1 a 3 usos, com recarga de 20 s a 150 s.
3. **Carta vale um terço de baú.** Uma carta de construção é contada como 1 em "valor de carta". Um baú vale 3. O total de cartas extras de construções em um mapa fica abaixo de um baú (3 de valor) no primeiro mapa, e abaixo de 6 nos seguintes. Assim o mapa não fica fácil demais.
4. **Número de construções por mapa: no máximo 8 ativas ao mesmo tempo, e no máximo 8 por mapa.** Isso protege o desempenho do PC fraco (ver nota de desempenho em cada ficha).
5. **Monstros que aparecem por causa da construção entram no teto de 250 vivos.** Nenhuma construção cria elite nem chefe.

## Tabela comparativa

Valor em cartas: quanto a construção equivale a cartas de baú (1 baú = 3). Estimativa a partir dos números das fichas, não medida.

| Construção | Benefício | Custo | Usos / recarga | Valor em cartas | Minuto de aparição sugerido | Onde fica (mapa médio) |
|---|---|---|---|---|---|---|
| Cabana do Lenhador | 1 carta (70% comum, 30% rara) | 25% da vida atual; 3 s parado; 2 lobos por uso | 2 usos; 90 s | 1,8 (2 usos x 0,9) | 1 a 3 | Rota, depois do santuário |
| Fogueira de Acampamento | +15% dano por 25 s, raio 150 px | 4 s parado; anel de 6 monstros | 3 usos; 100 s | 0 (buff, não carta) | 2 a 6 | Perto dos pilares de fogo e água |
| Poço Antigo | 1 carta (bônus de raridade 0,5) | perde a barra de XP atual; 1 em 4 vira espectro | 1 uso | 0,8 | 3 a 8 | Perto do fragmento, lado do pilar de terra |
| Mercador Ambulante | 2 cartas por visita (era 1) | 8 almas por carta | 1 visita | 0 (integrado ao mercador) | já existe | Ponto A ou B, sorteado |
| Torre de Vigia | minimapa mostra monstros e baús por 60 s | 5 s de subida; +10% vel. dos monstros por 15 s | 2 usos; 150 s | 0 (informação) | 4 a 9 | Centro da rota |
| Totem de Madeira | +25% XP nos abates por 60 s, raio 200 px | +15% vida dos monstros que entram na área | 2 usos; 120 s | 0 (XP, cerca de 0,5 carta) | 2 a 7 | Antes do mini-chefe 1 |
| Armadilha de Troncos | 12 de dano e lentidão 50% a cada disparo | 2 s para montar; 2 armadilhas por partida | 4 disparos cada; 20 s | 0 (dano) | 2 a 7 | Corredor entre pilar de fogo e baú |
| Árvore Anciã Oca | guarda até 3 pacotes de 30 XP (9 almas no total) | -10% vel. por 10 s ao liberar | 3 pacotes; 30 s | 0 (adia XP, não cria) | 1 a 5 | Beira leste da rota |
| Toca do Urso | baú de 2 cartas | urso elite (360 de vida) + 6 monstros ao acordar | 1 uso | 2,0 | 5 a 9 | Lado oeste, perto do baú trancado |
| Ninho de Aranhas | 3 aranhas aliadas por 25 s | 2 aranhas inimigas a cada 6 s enquanto o ninho está de pé | 1 uso | 0 (aliados) | 4 a 8 | Entre baú do centro e espinhos |
| Ruínas com Runas | 1 carta épica (50%) ou rara (50%) | -15% de vida máxima por 90 s | 1 uso | 1,3 (carta de alta raridade) | 5 a 9 | Perto do altar |
| Altar Amaldiçoado | +20% dano por 60 s | -15% de vida máxima (permanente); +20% vel. dos monstros a 300 px | 1 uso (opção do santuário) | 0 (integrado ao santuário) | 3 a 8 | Santuário |
| Ponte Quebrada | atalho de ~200 px | 6 s parado; monstros também usam | 1 uso | 0 (atalho) | 3 a 8 | Integrada à alavanca |
| Represa do Riacho | -30% vel. dos monstros por 20 s, raio 200 px | 8 s parado | 2 usos; 120 s | 0 (lentidão) | 4 a 9 | No riacho |
| Acampamento de Goblins | 2 cartas e 60 XP (baú) | 12 monstros em 2 ondas; 900 de vida em tendas | 1 uso, depois do minuto 6 | 2,0 | 6 a 10 | Lado sul, fora da rota |
| Espantalho de Guarda | monstros mudam de alvo por 15 s | 2 s para plantar; exige código novo | 3 usos; 60 s | 0 (defesa) | 6 a 10 | Frente da defesa de ponto |
| Colmeia | nuvem de 12 de dano por s, raio 120 px, 6 s | 3 de vida por s dentro da nuvem (o herói) | 1 uso | 0 (dano em área) | 3 a 8 | Copa de árvore baixa |

Observação: a árvore anciã e o totem não criam recurso novo. A árvore só adia XP; o totem aumenta o XP da área à custa de vida dos monstros.

## Ordem sugerida das ondas

- **Onda 1 (primeiro mapa médio):** cabana_lenhador, fogueira_acampamento, poco_antigo, torre_vigia, totem_madeira, armadilha_troncos, arvore_ancia. Valor de cartas: 1,8 + 0,8 = 2,6, abaixo de um baú (3).
- **Onda 2:** toca_urso, ninho_aranhas, ruinas_runas, colmeia, represa_riacho. Valor de cartas: 2 + 1,3 = 3,3 (toca e ruína), somado ao que já passou da onda 1, fica abaixo de 6.
- **Onda 3 (depois de código novo):** acampamento_goblins (precisa de goblin), espantalho_guarda (precisa de alvo de desvio).
- **Integrar, não criar:** mercador_ambulante (ao mercador), altar_amaldicoado (ao santuário), ponte_quebrada (à alavanca).

## Parecer da revisão

A revisão foi feita pelo Claude do projeto, inline, e não por um subagente Sonnet. Foi feita olhando cada ficha contra a tabela acima e os números de referência.

Os três pontos que deixariam o jogo fácil demais, e o que foi corrigido nas fichas:

1. **Colmeia: 20 de dano por segundo em raio de 120 px** limpava a horda inteira em uma área. **Corrigido:** 12 por segundo, com a nota de que raio 100 px é a alternativa.
2. **Altar amaldiçoado com 2 usos:** -30% de vida máxima permanente na partida, com +20% de dano. **Corrigido:** 1 uso, e a ficha vira opção do santuário, sem objeto novo.
3. **Ruína com épica garantida:** a melhor carta do jogo, sem custo de uso. **Corrigido:** 50% de épica e 50% de rara. A maldição de -15% de vida máxima por 90 s foi mantida, porque é o preço.

Pontos que ficam em aberto, para o Breno decidir:

- **Mercador ambulante e altar:** a recomendação é integrar. Se o Breno quiser objetos separados, o custo de arte e de código sobe.
- **Espantalho de guarda e acampamento de goblins:** dependem de código novo (alvo de desvio) e de sprite novo de goblin. Ficam na onda 3.
- **Estimativa de almas:** sem medição, a conta de almas por construção é teórica. Medir antes de fechar.
- **Toca do urso:** 2 cartas e um elite. Se o primeiro mapa ficar fácil, sai do primeiro mapa (já está na onda 2).

## Performance (resumo para o PC fraco)

- Máximo de 8 construções por mapa, com no máximo 8 ativas ao mesmo tempo.
- Só anima o que está na tela (regra das fichas).
- Sem partícula contínua acima de 8 por construção; as maiores (fogueira, colmeia) usam 4 partículas por 0,5 s ou sprite de 4 quadros.
- Nada de física extra: os monstros usam a horda normal (MultiMesh), e as zonas são testes de distância.
- Nenhuma construção nova cria luz acima do orçamento de luzes do mundo (`ORCAMENTO_LUZES` em `v2/mundo.gd`, perfil "Baixo" usa "desligada").
