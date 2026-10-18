# Colosso de Pedra (fusão colosso_de_pedra)

> **Tempo de vida (aliado temporário, 18/10):** dura **60 s** e some (as fusões e os mais fortes duram mais: 45 a 60 s); a recarga de **35 s** só começa a contar depois que o último da leva sumiu, então nunca fica indefinidamente. Marca de amigo: anel verde no chão e barrinha verde pequena de tempo sobre a cabeça (pisca nos últimos 5 s). Onde este arquivo citar duração ou recarga menores, vale este número.

**Peças:** Golem de Barro (nível 3) + Guardião de Pedra (nível 3). Fichas: golem_barro.md, guardiao_pedra.md.

**Vira:** um colosso aliado, lento e pesado (um golpe secundário novo). Ele substitui o Golem e o Guardião, que saem do sorteio.

**O que faz:** um colosso de pedra e barro anda devagar atrás do inimigo mais perto e bate forte a cada segundo.

**Como liberar:** pegue 3 cartas de Golem de Barro e 3 de Guardião de Pedra. Quando as duas estão no nível 3, a fusão acontece na hora (anúncio EVOLUÇÃO) e as duas peças saem do sorteio. Enquanto falta uma delas, a que falta aparece com o rodapé "Evolui: Colosso de Pedra" e pesa mais no sorteio.

## Esquemática
- **Gatilho:** a cada 4,0 s, dividido pela velocidade de ataque do herói (com 1,0 são 4,0 s). Invoca 1 colosso. Só dispara com inimigo a até 340 px do herói. Sem inimigo, espera 0,3 s e não gasta a recarga.
- **Alvo:** o inimigo mais perto do colosso, dentro de 400 px, reescolhido a cada quadro. Sem inimigo por perto, ele gira em volta do herói a 50 px.
- **Trajetória e alcance:** anda reto em direção ao alvo a 120 px/s (o mais lento dos aliados). Nasce em volta do herói (até 30 px para os lados e 20 px para cima ou para baixo). Dura 8 s, o que dá até 960 px de caminho.
- **Área:** nenhuma. O contato é um raio de 12 px mais o raio do inimigo (achatado no chão).
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 5 (fixo) | 30 por batida | Base do registro. O bônus de raridade (cada carta de peça soma o bônus da sua raridade: raro +18%, épico +40%, lendário +80%; a fusão usa o maior bônus entre as peças consumidas) multiplica o dano: 30 comum, 35 raro, 42 épico, 54 lendário. |

  O multiplicador de dano do herói (m_dano) é 1,0 por padrão, e o dano final é esse número vezes m_dano.
- **Como aplica:** por tique de 1,0 s, enquanto ele encosta no alvo. O primeiro toque é imediato.
- **Efeitos de status:** empurrão de 30 px e atordoamento de 0,05 s. Queimadura: nenhuma. Lentidão: nenhuma. Poeira ou respingo no contato: não existe hoje.
- **Limites na tela:** 1 colosso por invocação, e ele dura 8 s. Com recarga de 4,0 s, o normal são até 2 colossos juntos (as duas invocações se sobrepõem por 4 s). O colosso divide o pool de 48 golpes novos com os outros golpes novos.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: nenhuma. O colosso aparece já na posição de nascimento.
  - Disparo: nenhum (sai no quadro da invocação).
  - Viagem: caminhada reta a 120 px/s (2 px por quadro). Balanço de 2 px, com período de 1,05 s (63 quadros) que lembra o passo.
  - Impacto: cada tique de 1,0 s (60 quadros). No contato, ele fica no inimigo e bate de novo quando o tique zera.
  - Fim: nos últimos 0,5 s (30 quadros) de vida, o brilho cai de 100% para 0%.
  - Tamanho do sprite: 48 x 56 px (o brilho atual tem 20 x 20 px).

**Mudanças:** Implementada sem balanço fino: os números são os do registro (dados/v2_cartas.json), sem ajuste de teste.
