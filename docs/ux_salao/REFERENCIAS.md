# Referências: salão do personagem, escolha de personagem e menu

Pedido do Breno (13/10): tela inicial e escolha de personagem mais atuais, como os grandes jogos com essas mecânicas. Este
resumo diz o que vale copiar e o que foi aplicado no PR. Duas fontes de origem: a pesquisa desta sessão (links abaixo, a
cobertura foi rasa: quase não há análise de UI publicada) e conhecimento geral dos jogos, marcado como **não verificado**.

## O que vale copiar

| Jogo | O que ele faz | O que aplicamos |
|---|---|---|
| **Hades** (Casa de Hades, Espelho da Noite) | As melhorias permanentes ficam num único objeto do cenário (o espelho). Cada uma tem nível atual e custo na mesma moeda. | Estruturas no salão, uma por categoria. O custo fica sempre na mesma moeda (almas), no mesmo lugar do painel. [Fonte: pcinvasion](https://www.pcinvasion.com/?p=221713), [Fonte: games.gg](https://games.gg/hi/hades/) |
| **Rogue Legacy 2** (porto e mansão) | O progresso é um lugar físico que cresce. A escolha de classe e o vendedor ficam no mesmo hub. | O salão é o mesmo lugar de sempre, com portais e estruturas; a escolha de personagem é uma tela à parte e curta. [Fonte: waytoomany](https://waytoomany.games/2022/05/23/review-rogue-legacy-2/) |
| **Enter the Gungeon** (o Breach) | As entradas são portas marcadas com figuras acima, e a hora de entrar aparece no próprio cenário. | Cada portal leva a cor e o nome do mapa; o portal fechado mostra um cadeado e a condição escrita. [Fonte: wiki](https://enterthegungeon.wiki.gg/wiki/The_Breach) |
| **Dead Cells** | A interface funcional fica separada da identidade gráfica (o logo sujo fica fora dos menus), e o menu foi redesenhado para toque. | Texto de menu limpo, em fonte legível (Jersey 10 nos títulos, Spleen 16 ou 32 no corpo), e a arte fica no fundo. [Fonte: ComputerBase](https://www.computerbase.de/2019-05/dead-cells-android-ios/) |
| **Vampire Survivors, Brotato, Halls of Torment, Soulstone Survivors, Death Must Die** | Escolha de personagem: retrato grande, atributos e arma inicial do lado, confirmação com um toque. | Personagem: retrato grande, almas, melhorias compradas e arma inicial no painel da direita. Escolher é um toque. *(conhecimento geral, não verificado nesta sessão)* |
| **Children of Morta** | O hub é a casa da família: personagens andando e portas que levam às missões. | O salão é uma sala com personagem andando, como a casa deles. *(conhecimento geral, não verificado)* |

## Regras de tela que saem daí

- **Fundo vivo, mas barato:** o chão e a parede são desenhados uma vez; por quadro só se mexem o personagem e as chamas (poucas, sem luz dinâmica).
- **Menu enxuto:** uma ação por linha; o painel de uma estrutura mostra nome, nível, efeito atual → próximo, custo e saldo. O resto fica em DETALHES.
- **Retrato grande do herói** com atributos e arma inicial na escolha de personagem.
- **Comparação clara:** o efeito atual e o próximo nível aparecem um ao lado do outro, sempre com o custo.
- **Confirmação rápida:** Enter na melhoria a seleciona; COMPRAR a compra (uma tecla a mais, sem janela de confirmação).
- **Teclado e controle completos:** tudo é botão do Godot com foco; Enter ou A usa; ESC volta sempre (do painel à sala, da sala à escolha, da escolha ao título).

## Fontes

- [pcinvasion: Hades, House of Hades](https://www.pcinvasion.com/?p=221713)
- [games.gg: Hades](https://games.gg/hi/hades/)
- [waytoomany: Rogue Legacy 2 review](https://waytoomany.games/2022/05/23/review-rogue-legacy-2/)
- [gamecritics: Rogue Legacy 2 preview](https://gamecritics.com/daniel-weissenberger/rogue-legacy-2-preview/)
- [ComputerBase: Dead Cells, portagem mobile e UI](https://www.computerbase.de/2019-05/dead-cells-android-ios/)
- [Enter the Gungeon wiki: The Breach](https://enterthegungeon.wiki.gg/wiki/The_Breach)

Não foi possível confirmar nesta sessão a interface atual de Vampire Survivors, Brotato, Halls of Torment, Soulstone Survivors,
Death Must Die e Children of Morta. Vale checar as telas deles antes de mexer em detalhes finos.
