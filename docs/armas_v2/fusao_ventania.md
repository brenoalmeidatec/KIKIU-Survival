# Ventania Cortante (fusão ventania)

**Peças:** Corte ondulante (nível 2, modificador da katana) + Estocada perfurante (nível 2, modificador da katana). Fichas: não há ficha própria em armas_v2 para "onda" nem "fura" (o efeito vem de dados/v2_cartas.json, modificadores "onda" e "fura").

**Vira:** não cria arma nova. A onda do corte fica 1,9 vez mais forte e 1,6 vez mais larga, e a estocada solta três lanças em leque, no lugar de uma. As duas peças saem do sorteio, mas o efeito delas continua na katana.

**O que faz:** cada corte solta uma onda de vento mais forte e mais larga. Cada estocada solta três lanças de luz em leque, que atravessam os inimigos.

**Como liberar:** pegue 2 cartas de Corte ondulante e 2 de Estocada perfurante. Quando as duas estão no nível 2, a fusão acontece na hora (anúncio EVOLUÇÃO). Enquanto falta uma delas, a que falta aparece com o rodapé "Evolui: Ventania Cortante" e pesa mais no sorteio.

## Esquemática
- **Gatilho:** cada golpe da katana. O corte solta uma onda; a estocada solta as lanças. Não tem recarga própria: segue o ritmo que o herói já golpeia com a katana.
- **Alvo:** nenhum. A onda vai na direção do corte e a lança na direção da estocada.
- **Trajetória e alcance:**
  - Onda: sai 14 px à frente do herói, reta, a 250 px/s, por 150 px (0,6 s).
  - Lança: sai 20 px à frente do herói, reta, a 380 px/s, por 190 px (0,5 s). Com a fusão, saem 3 lanças em leque: ângulos de -0,3, 0 e +0,3 rad (cerca de ±17°).
- **Área:** a onda é uma faixa de 54 px de largura (34 px do normal x 1,6; meia largura 27 px mais o raio do inimigo). A lança é uma faixa de 12 px de largura (6 px de meia largura mais o raio do inimigo).
- **Dano por nível:**

| Nível | Dano | Como muda |
|---|---|---|
| 5 (fixo) | Onda = dano do corte x (soma do modificador / 100) x 1,9. Lança = dano da estocada x (soma do modificador / 100), uma por lança | A fusão não usa bônus de raridade. O modificador já soma o valor de cada carta, multiplicado pela raridade (comum x1,0; raro x1,5; épico x2,2; lendário x3,2). Exemplo: 2 cartas comuns de Corte ondulante somam 80%, então a onda sai com 80% x 1,9 = 152% do dano do corte. Com 2 cartas comuns de Estocada, cada lança sai com 90% do dano da estocada. |

  O multiplicador de dano do herói (m_dano) é 1,0 por padrão e entra no dano do corte e da estocada antes dos percentuais.
- **Como aplica:** uma vez por inimigo para cada onda ou lança. Cada projétil guarda o último alvo que acertou, então não acerta o mesmo inimigo duas vezes. A lança atravessa todo inimigo que estiver na faixa; a onda também.
- **Efeitos de status:** empurrão de 90 px e atordoamento de 0,15 s, tanto para onda quanto para lança. Queimadura, lentidão: nenhuma.
- **Limites na tela:** 8 ondas e lanças ao mesmo tempo, no pool compartilhado da katana (MAX_ONDAS). Cada corte gasta 1 slot e cada estocada gasta 3. Obs. do código: quando os 8 slots estão ocupados, a nova onda ou lança sobrescreve o slot 0 (`_livre_onda` devolve 0 se não há slot livre), então a mais antiga some na frente.
- **Sequência de animação (quadro a quadro, a 60 fps):**
  - Antecipação: a onda nasce 14 px à frente do herói no momento do corte. A lança nasce 20 px à frente no momento da estocada.
  - Disparo: nenhum (sai no mesmo quadro do golpe).
  - Viagem: onda de 150 px a 250 px/s = 0,6 s (36 quadros). Lança de 190 px a 380 px/s = 0,5 s (30 quadros).
  - Impacto: quando o inimigo cruza a faixa, sai uma faísca de 4 partículas (130 px/s). A onda é desenhada com 3 arcos, cada um recuado 6 px do anterior.
  - Fim: a onda some nos últimos 40 px (cerca de 10 quadros). A lança some nos últimos 40 px (cerca de 6 quadros).
  - Tamanho do sprite: onda de 64 x 32 px (arco com cauda). A lança continua com o desenho atual (linha de 30 px com 7 px de largura e brilho de 24 x 24 px).
- **Obs. (cor):** o campo "cor" da fusão (0,8; 1,0; 0,95) não é lido pelo código; a onda usa a cor fixa de `armas.gd` (0,75; 1,0; 0,95), quase igual.

**Mudanças:** Nenhuma.
