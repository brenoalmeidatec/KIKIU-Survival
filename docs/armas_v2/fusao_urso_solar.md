# Urso Solar (fusão urso_solar)

**Peças:** Espírito Urso (nível 3) + Raio Solar (nível 3). Fichas: espirito_urso.md, raio_solar.md.

**Vira:** feixes dourados de projétil (um golpe secundário novo). Saem 2 feixes por disparo, cada um atravessa até 4 inimigos em linha reta. Substituem o Espírito Urso e o Raio Solar, que saem do sorteio.

**O que faz:** dois feixes dourados saem na direção do inimigo mais perto e atravessam até quatro inimigos em linha reta.

**Como liberar:** pegue 3 cartas de Espírito Urso e 3 de Raio Solar. Quando as duas estão no nível 3, a fusão acontece na hora (anúncio EVOLUÇÃO) e as duas peças saem do sorteio. Enquanto falta uma delas, a que falta aparece com o rodapé "Evolui: Urso Solar" e pesa mais no sorteio.

## Esquemática
- **Gatilho:** a cada 2,2 s, dividido pela velocidade de ataque do herói (com 1,0 são 2,2 s). Dispara 2 feixes. Só dispara com inimigo a até 340 px do herói. Sem inimigo, espera 0,3 s e não gasta a recarga.
- **Alvo:** o inimigo mais perto do herói, dentro de 300 px. A direção é fixada no momento do disparo: o feixe não persegue. Os 2 feixes saem em leque curto, de -4° e +4° (±0,07 rad) em volta da direção do alvo.
- **Trajetória e alcance:** reta, a 420 px/s. Cada feixe dura 1,6 s, então o alcance real é de 672 px. O valor de alcance do código (300 px) só serve para escolher o alvo. Sai 14 px acima do herói.
- **Área:** linha (o feixe não tem área). O contato é um raio de 10 px mais o raio do inimigo.
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 5 (fixo) | 30 por acerto | Base do registro. O bônus de raridade (cada carta de peça soma o bônus da sua raridade: raro +18%, épico +40%, lendário +80%; a fusão usa o maior bônus entre as peças consumidas) multiplica o dano: 30 comum, 35 raro, 42 épico, 54 lendário. |

  O multiplicador de dano do herói (m_dano) é 1,0 por padrão, e o dano final é esse número vezes m_dano.
- **Como aplica:** uma vez por inimigo, por feixe. O feixe perfura: pode acertar até 4 inimigos diferentes (perfura 3 mais o primeiro), depois some. Um mesmo inimigo não leva o mesmo feixe duas vezes. Não há explosão (explosão 0).
- **Efeitos de status:** empurrão de 40 px e atordoamento de 0,1 s. Queimadura: nenhuma. Lentidão: nenhuma.
- **Limites na tela:** 2 feixes no ar ao mesmo tempo, já que um disparo dura 1,6 s e a recarga é de 2,2 s. Os feixes dividem o pool de 48 golpes novos.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: nenhuma. O feixe nasce no quadro do disparo, 14 px acima do herói.
  - Disparo: nenhum.
  - Viagem: 420 px/s (7 px por quadro), por 1,6 s (96 quadros), a menos que ele pare antes por ter atravessado 4 inimigos.
  - Impacto: em cada inimigo acertado sai uma faísca de 4 partículas. Como o acerto é instantâneo, não há quadros próprios.
  - Fim: o feixe some ao fim dos 96 quadros, sem fade no código.
  - Tamanho do sprite: feixe de 24 x 12 px (a linha atual tem 9 px com brilho de 14 x 14 px).

**Mudanças:** Implementada sem balanço fino: os números são os do registro (dados/v2_cartas.json), sem ajuste de teste.
