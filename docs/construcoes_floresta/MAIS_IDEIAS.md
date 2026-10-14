# Mais ideias de construções da floresta (rascunho)

**Status:** rascunho para o Breno revisar. Ainda não entra no pacote do Alisson. Os números seguem a mesma régua de `BALANCEAMENTO.md`: toda vantagem tem preço, há limite de usos, e uma carta vale um terço de baú.

Cada ideia traz o que faz, o custo, os usos, o valor em cartas e a sobreposição com o que já existe.

| Ideia | O que faz | Custo | Usos / recarga | Valor em cartas | Sobreposição |
|---|---|---|---|---|---|
| Sino da Capela | Ao tocar, monstros a até 200 px ficam atordoados por 1,5 s | Toca os monstros de 500 px, que nascem 4 a mais | 2 usos; 120 s | 0 | Parecido com o atordoamento do golpe, mas em área |
| Forja de Campo | Gasta 6 almas da partida e dá +10% de dano para o resto da partida | 6 almas (XP que viraria carta de nível) | 2 usos; sem recarga | 0 | Usa a mesma moeda do mercador; o mercador é a alternativa |
| Corça Ferida | Animal fugindo: quem a alcança ganha 1 carta de stat | A corça corre 90 px/s; o herói gasta até 20 s perseguindo | 1 por partida | 1 | Nova; nenhuma mecânica igual |
| Cerca de Estacas | Barreira que segura monstros por 20 s; quem encosta leva 8 de dano | 3 s para montar, 40 de vida dos monstros que a quebram | 2 usos; 90 s | 0 | Sobrepõe com a defesa de ponto; o ideal é integrar |

## Notas de balanceamento

- **Sino da Capela** é um "pare" de área. Sem o custo de monstros extras, seria um botão de vitória. Por isso o custo é o nascimento de 4 monstros.
- **Forja de Campo** usa almas, que já são o preço do mercador. Sem limite de 2 usos, o jogador troca toda a meta da partida por dano.
- **Corça Ferida** dá carta, por isso só 1 uso, e a perseguição é o custo. Se for fácil demais, o Breno pode trocar a corça por uma que foge mais rápido.
- **Cerca de Estacas** deve ser integrada à defesa de ponto (`defesa` em `v2_medio.json`) antes de existir como objeto separado.

## Perguntas para o Breno

1. Quais dessas quatro entram na próxima onda?
2. A Cerca de Estacas vira parte da defesa de ponto (recomendado) ou fica separada?
3. A Forja de Campo é aceita, ou prefere manter só o mercador como troca de almas?
