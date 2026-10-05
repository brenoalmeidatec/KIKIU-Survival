# Desenho do jogo: horda em grupo + duelo final

A ideia do Breno: um jogo no estilo Vampire Survivors, mais bonito e mais gostoso de jogar, com várias mecânicas incríveis. Todos os jogadores enfrentam a mesma horda e, no fim, lutam entre si para descobrir **quem foi o mais forte**.

O tema "Cairu x Vírus" é só para teste. Tudo que é tema (heróis, vírus, armas, itens, nomes) fica em `dados/*.json` e `assets/`, e pode ser trocado sem mexer no código.

---

## 1. O ciclo da partida (até 6 jogadores)

| Fase | O que acontece | Duração |
|---|---|---|
| 1. Sala | O anfitrião abre a sala, os amigos entram pelo endereço, cada um escolhe um herói diferente. | livre |
| 2. Horda | Todos na mesma arena contra a mesma horda. Cada um sobe de nível, escolhe cartas e monta a própria build. Os vírus ficam mais fortes com o tempo e com o número de jogadores. | 10 min |
| 3. Chefe final | A Tela Azul chega e a equipe precisa derrubar junto. Quem tomou mais risco aqui já está com a build mais formada. | até cair |
| 4. Duelo final | Contagem de 4 s, todos contra todos numa arena redonda que vai fechando. O último de pé é o campeão. | 45 a 70 s |
| 5. Resultado | Ranking de 1º ao 6º, build de cada um (armas e itens), dano por arma e recordes. | |

**Regras da horda em grupo (padrão proposto, pode mudar):**
- Sem fogo amigo na horda.
- XP, baús e tomadas são **pessoais**: cada jogador pega os seus, então ninguém fica sem build por azar de posição.
- Morrer na horda **não elimina**. O jogador cai, fica 15 s fantasma e volta com metade da vida e um nível a menos. Assim todo mundo chega ao duelo, e quem joga mal chega só um pouco mais fraco.
- A dificuldade já escala com o número de jogadores (o diretor multiplica o coeficiente por 1 + 0,3 por jogador extra, como no Risk of Rain 2).

## 2. Como a build vira poder no duelo

No duelo cada um luta com **as mesmas armas e itens que montou**. Para o duelo não ser decidido só por quem tem o maior número, existem três regras (todas em `dados/pvp.json`):

1. **Dano normalizado pela força relativa.** O jogo calcula a "força" de cada build (dano de catálogo de cada arma x quanto dela realmente acerta alguém que se mexe). Cada um bate com `dps_ref x (força / média)^0,7`. Resultado: o duelo dura o mesmo tempo com build de nível 8 ou de nível 45, e uma build 2x mais forte que a média rende 1,6x, não 2x. Vale a pena se esforçar, mas quem ficou atrás ainda tem chance.
2. **Vida do duelo = 500 + 0,6 x vida máxima da build.** Vida pesa pouco, então não existe a build "tanque infinito". A regeneração vale 25%.
3. **Anel que fecha.** Começa em 340 de raio, começa a fechar aos 10 s e chega em 70 aos 65 s. Fora dele, perde 4% da vida por segundo (dobra no fim). Acaba com fuga eterna e força o encontro.

Outras regras: dash (invencível por 0,28 s, recarga de 1,4 s) é a defesa principal; invencibilidade de 0,12 s após cada acerto, para golpes em sequência não zerarem ninguém; empurrão pela metade; crítico (chance dos itens, dano 1,5x) funciona igual na horda e no duelo.

**Classes de arma** (já aparecem no duelo): projétil (longe, 170), poça (médio, 120), chicote (perto, 85), órbita (perto, 65) e aura (perto, 60, a evolução 5G deixa o alvo lento). Quem tem arma curta precisa do dash para chegar; quem tem projétil precisa se mexer. Por isso nenhuma é a "melhor".

## 3. O que já está pronto no protótipo (esta entrega)

- Depois da Tela Azul o jogo inicia o duelo sozinho: limpa os vírus, posiciona todos em círculo, contagem, **LUTEM!**, anel que fecha, ranking.
- Os **rivais** (3 no modo solo) são robôs que usam as mesmas armas do jogador, com builds sorteadas do mesmo nível, e usam dash, andam de lado e fogem do anel. No online, cada rival será uma pessoa.
- HUD do duelo: vida, quantos vivos, aviso de anel, setas para quem está fora da tela, lista de lutadores.
- Tela de resultado com ranking, e recorde de melhor colocação e de vitórias por herói.
- 8 heróis (3 jogáveis, 5 só como rivais por enquanto), crítico e o item Mouse Gamer.
- **Equilíbrio testado com robôs:** mais de 100 duelos. Duração média 45 s (nível 8), 53 s (nível 20) e 66 s (nível 45). A colocação do jogador-robô fica espalhada entre 1º e 4º, sem build dominante.

Limite honesto do teste: robôs não jogam como gente. Os números de equilíbrio precisam de uma rodada com amigos. Dá para ajustar tudo em `pvp.json` sem reconstruir o jogo.

## 4. Online até 6 (reaproveitando a rede da engine)

A engine da Cairu já tem sala com ENet (o anfitrião é o servidor), lista de jogadores, escolha de personagem único, limite de 6, `online.json` e o túnel gratuito playit.gg. O que serve igual e o que é novo:

| Parte | Reaproveita | Novo |
|---|---|---|
| Sala, endereço, lista, escolha de herói | `rede.gd` quase inteiro | tela de sala no menu do jogo de hordas |
| Posição dos jogadores | `_pos` (unreliable) | enviar posição, direção, dash e vida da arena |
| Vírus | | o **anfitrião** simula todos (diretor, spawn, IA) e envia uma foto 15 vezes por segundo só dos vírus perto de cada jogador (id, tipo, posição, % de vida). Os outros jogadores só desenham. |
| Armas | `armas.gd` já recebe "dono" e "campo" | cada cliente roda as próprias armas (resposta imediata) e avisa "acertei o vírus X". Os disparos dos outros chegam como eventos leves (arma, origem, direção) para todo mundo ver. |
| XP e itens | | quando o anfitrião avisa "vírus X morreu", cada cliente cria as próprias gemas. Nada de tráfego por gema. |
| Duelo | `duelo.gd` (anel, ranking, regras) | quem ataca detecta o acerto e manda ao alvo; **quem apanha decide** o dano (aplica o multiplicador, vida e invencibilidade) e avisa que caiu. O anfitrião manda contagem, anel e resultado. |

Ordem sugerida: (1) sala + escolha de herói, (2) andar juntos na arena, (3) horda online, (4) XP e itens pessoais, (5) duelo online, (6) fantasma, reconexão e polimento.
Risco principal: CPU do anfitrião com 6 jogadores e 500 vírus. Hoje o laço de vírus leva 3 a 5 ms no meu teste, então cabe, mas precisa ser medido com 6 jogadores reais.

## 5. Mecânicas candidatas (para o jogo ficar "gostoso")

Já tem: dash, crítico, evoluções por baú, tomadas (santuários), chefes, elites, ímã de XP, diretor de dificuldade, duelo final.

Candidatas, da mais barata para a mais cara:
1. **Esquiva perfeita:** desviar de um golpe por pouco dá câmera lenta curta e recarrega o dash.
2. **Combo de abates:** abates seguidos aumentam o XP; tomar dano zera. Dá ritmo e risco.
3. **Habilidade ativa por herói** (tecla Q, carregada por abates): cada herói com a sua, e serve no duelo também.
4. **Eventos de mapa:** apagão (tela escura), surto (onda extra), chuva de itens.
5. **Baús amaldiçoados:** aceitar mais dificuldade em troca de item raro (estilo Risk of Rain 2).
6. **Etiquetas e sinergias:** itens "de energia", "de rede", "de café"; três da mesma etiqueta dão bônus.
7. **Itens de duelo:** efeitos como roubo de vida e congelar, e uma pausa de 10 s antes do duelo para trocar 1 item.
8. **Meta-progressão:** loja entre partidas, desbloqueio de heróis e armas.
9. **Fases com mapas diferentes** (obstáculos, paredes, armadilhas) e duelo em arena com obstáculos.

**"Mais bonito":** a arte atual é provisória, desenhada por código. Para ficar bonito de verdade: sprites animados de 32x32 ou maiores para vírus e armas no mesmo pipeline dos retratos (Gemini + corte), paleta única, brilho nos acertos, partículas melhores, tremor e "hit stop" nos chefes, e trilha que muda no duelo.

## 6. Perguntas que ficam para o Breno (padrões já assumidos)

1. **Morte na horda:** voltar após 15 s com metade da vida e um nível a menos (padrão) ou ficar fantasma até o duelo?
2. **Duelo:** uma luta só (padrão) ou melhor de 3?
3. **Entre horda e duelo:** nada (padrão) ou 10 s para trocar um item?
4. **Placar da noite:** acumular vitórias entre partidas dos mesmos amigos?
5. **Tema real:** quando sair do teste da Cairu, que mundo e que visual?
6. **Próximo passo:** online com amigos primeiro (padrão), mecânicas e visual, ou arte final?
