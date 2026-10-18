# Sentinela de Bambu (sentinela_bambu)
**Tipo:** torre. **Ícone:** icone_u_espada_treino. **Desenho:** código (`"desenho": "codigo"`, sem arte própria).
**O que faz:** Planta uma torreta de bambu que atira no inimigo mais perto. Fica de pé um tempo e some.
**Na prática:** Cada invocação planta 1 torre atrás do herói, apontada para o inimigo, e ela atira um virote de 7 de dano a cada 0,55 s no inimigo mais perto dela (alcance de 220 px, virote a 420 px/s). Invoca quando a recarga de 20 s zera e há inimigo a até 340 px do herói (o bônus de velocidade de ataque deixa a recarga menor).

> **Tempo de vida (torre temporária, 18/10):** dura **30 s** e some (nos últimos 0,35 s ela desmonta); a recarga de **20 s** só começa a contar depois que a torre sumiu, então nunca fica indefinidamente nem se acumula. Marca de amigo: anel verde no chão e barrinha verde pequena de tempo sobre a cabeça (pisca nos últimos 5 s; some quando a torre começa a desmontar). **Onde este arquivo citar duração ou recarga diferentes, vale o número desta caixa.**

**Níveis:**

| Nível | O que muda | Acumulado |
|---|---|---|
| 1 | (base) | 7 de dano · tiro a cada 0,55 s · 1 torre · 30 s · alcance 220 px |
| 2 | +3 de dano | 10 de dano |
| 3 | atira mais rápido (tiro a cada 0,45 s) e dura +6 s | 36 s |
| 4 | +1 sentinela (2 por invocação) | 2 torres |
| 5 | +4 de dano, alcance +40 px e perfura 1 (o virote atravessa um inimigo antes de parar) | 14 de dano · alcance 260 px |

**Fusão:** Sentinela de Bambu nível 3 + Raio em Cadeia nível 3 vira o Pagode do Trovão (`fusao_pagode_do_trovao.md`).

## Esquemática
- **Gatilho:** a recarga zera e há monstro a até 340 px do herói (`armas_novas.gd::_torres`). A torre nasce 42 px atrás do herói, no sentido do inimigo; com 2 torres, ficam lado a lado (34 px entre si).
- **Alvo:** o inimigo mais perto da torre, dentro do alcance; a balestra gira para ele.
- **Dano:** 7 por virote no nível 1, sem área. O bônus de raridade da carta multiplica o dano, como nas outras armas.
- **Recarga:** `a.ate` guarda o fim da leva (duração + 0,35 s de desmonte) e a recarga só corre depois disso.
- **Limites:** 1 torre por invocação, 2 a partir do nível 4. Divide o pool de 48 golpes novos com os outros.

**Mudanças:** desde 18/10, torre temporária. Antes: dura 6 s e recarga de 7 s (base). Agora: 30 s e 20 s, com a recarga contando só depois que a torre some.
