# Pagode do Trovão (fusão pagode_do_trovao)

> **Tempo de vida (torre temporária, 18/10):** dura **45 s** e some (nos últimos 0,35 s ela desmonta); a recarga de **30 s** só começa a contar depois que a torre sumiu, então nunca fica indefinidamente. Marca de amigo: anel verde no chão e barrinha verde pequena de tempo sobre a cabeça (some quando a torre começa a desmontar). Onde este arquivo citar duração ou recarga menores, vale este número.

**Peças:** Sentinela de Bambu (nível 3) + Raio em Cadeia (nível 3). Ficha: sentinela_bambu.md.

**Vira:** uma torre de duas camadas cujos virotes viram arcos elétricos e saltam entre os inimigos. Substitui a Sentinela e o Raio, que saem do sorteio.

**O que faz:** atira virotes no inimigo mais perto; cada virote que acerta vira um arco elétrico que salta para outros inimigos.

**Como liberar:** a fusão acontece na hora em que as duas peças estão no nível 3 (anúncio EVOLUÇÃO). Enquanto falta uma delas, a que falta mostra o rodapé "Evolui: Pagode do Trovão".

## Esquemática
- **Gatilho:** recarga de 30 s; planta 1 torre atrás do herói quando há inimigo a até 340 px (igual à Sentinela).
- **Alvo:** o inimigo mais perto da torre, dentro de 260 px de alcance. Virote a 480 px/s.
- **Como aplica:** tiro a cada 0,5 s. O virote acerta o alvo com o dano cheio (14, com o bônus de raridade) e salta até 2 vezes para o inimigo mais perto a até 72 px do anterior. Cada salto dá 60% do dano do virote (`armas_novas.gd::_cadeia_eletrica`).
- **Limites:** 1 torre por invocação; divide o pool de 48 golpes novos.

**Mudanças:** desde 18/10, torre temporária. Antes: dura 9 s e recarga de 6 s. Agora: 45 s e 30 s, com a recarga contando só depois que a torre some.
