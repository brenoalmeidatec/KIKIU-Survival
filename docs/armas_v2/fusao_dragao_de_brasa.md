# Dragão de Brasa (fusão dragao_de_brasa)

> **Tempo de vida (aliado temporário, 18/10):** dura **45 s** e some (as fusões e os mais fortes duram mais: 45 a 60 s); a recarga de **30 s** só começa a contar depois que o último da leva sumiu, então nunca fica indefinidamente. Marca de amigo: anel verde no chão e barrinha verde pequena de tempo sobre a cabeça (pisca nos últimos 5 s). Onde este arquivo citar duração ou recarga menores, vale este número.

**Peças:** Dragãozinho (nível 3) + Serpente Ardente (nível 3). Fichas: dragao_filhote.md, serpente_ardente.md.

**Vira:** três espíritos de brasa, do tipo aliado (um golpe secundário novo). Eles substituem o Dragãozinho e a Serpente, que saem do sorteio.

**O que faz:** três espíritos de brasa voam atrás do inimigo mais perto e ferem ao tocar, de tempos em tempos.

**Como liberar:** pegue 3 cartas de Dragãozinho e 3 de Serpente Ardente. Quando as duas estão no nível 3, a fusão acontece na hora (anúncio EVOLUÇÃO) e as duas peças saem do sorteio. Enquanto falta uma delas, a que falta aparece com o rodapé "Evolui: Dragão de Brasa" e pesa mais no sorteio.

## Esquemática
- **Gatilho:** a cada 2,6 s, dividido pela velocidade de ataque do herói (com 1,0 são 2,6 s). Invoca 3 espíritos de uma vez. Só dispara com inimigo a até 340 px do herói. Sem inimigo, espera 0,3 s e não gasta a recarga.
- **Alvo:** cada espírito persegue o inimigo mais perto dele, dentro de 400 px, e reescolhe a cada quadro. Vários espíritos podem ir para o mesmo inimigo. Sem inimigo por perto, o espírito gira em volta do herói a 50 px.
- **Trajetória e alcance:** voa reto em direção ao alvo a 200 px/s. Nasce em volta do herói (até 30 px para os lados e 20 px para cima ou para baixo). Dura 6 s, sem limite de distância. Não há zigue-zague nem rastro no código.
- **Área:** nenhuma. O contato é um raio de 12 px mais o raio do inimigo (achatado no chão).
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 5 (fixo) | 14 por toque | Base do registro. O bônus de raridade (cada carta de peça soma o bônus da sua raridade: raro +18%, épico +40%, lendário +80%; a fusão usa o maior bônus entre as peças consumidas) multiplica o dano: 14 comum, 17 raro, 20 épico, 25 lendário. |

  O multiplicador de dano do herói (m_dano) é 1,0 por padrão, e o dano final é esse número vezes m_dano.
- **Como aplica:** por tique de 0,45 s por espírito, enquanto ele encosta no alvo. O primeiro toque é imediato. Cada espírito tem o seu próprio tique.
- **Efeitos de status:** empurrão de 30 px e atordoamento de 0,05 s. Queimadura: não existe hoje (o nome é tema; o código não aplica fogo). Lentidão: nenhuma.
- **Limites na tela:** 3 espíritos por invocação, e cada um dura 6 s. Com recarga de 2,6 s, o normal são 3 invocações juntas, ou seja, até 9 espíritos. Eles dividem o pool de 48 golpes novos com os outros golpes novos.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: nenhuma. O espírito aparece já na posição de nascimento.
  - Disparo: nenhum (sai no quadro da invocação).
  - Viagem: voo reto até o alvo, a 200 px/s (cerca de 1 s para 200 px). Balanço de 2 px para cima e para baixo, com período de 1,05 s (63 quadros).
  - Impacto: cada tique de 0,45 s (27 quadros). No contato, o espírito fica no inimigo e bate de novo quando o tique zera.
  - Fim: nos últimos 0,5 s (30 quadros) de vida, o brilho cai de 100% para 0%.
  - Tamanho do sprite: 24 x 24 px (o brilho atual tem 20 x 20 px).

**Mudanças:** Implementada sem balanço fino: os números são os do registro (dados/v2_cartas.json), sem ajuste de teste.
