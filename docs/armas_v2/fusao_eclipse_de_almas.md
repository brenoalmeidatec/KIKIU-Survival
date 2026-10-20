# Eclipse de Almas (fusão eclipse_de_almas)

> **Tempo de vida (aliado temporário, 18/10):** dura **50 s** e some (as fusões e os mais fortes duram mais: 45 a 60 s); a recarga de **30 s** só começa a contar depois que o último da leva sumiu, então nunca fica indefinidamente. Marca de amigo: anel verde no chão e barrinha verde pequena de tempo sobre a cabeça (pisca nos últimos 5 s). Onde este arquivo citar duração ou recarga menores, vale este número.

**Peças:** Lobo Espiritual (nível 5) + Espírito Raposa (nível 5) + Fantasma da Mata (nível 5) + Espírito Urso (nível 5). Fichas: lobo_espirito.md, espirito_raposa.md, fantasma_mata.md, espirito_urso.md.

**Vira:** quatro espíritos de almas, do tipo aliado. As quatro peças saem do sorteio.

**O que faz:** os espíritos prendem o inimigo na sombra; quem já está preso leva dano em dobro.

**Como liberar:** a fusão acontece na hora em que as quatro peças chegam ao nível 5 (anúncio EVOLUÇÃO), como nas outras fusões (ver `fusao_cacada_espiritual.md`). Enquanto falta alguma, a que falta mostra o rodapé "Evolui: Eclipse de Almas".

## Esquemática
- **Gatilho:** recarga de 30 s, a mesma regra dos outros aliados (só corre depois que o último espírito some). Invoca 4 espíritos de uma vez com inimigo a até 340 px do herói.
- **Alvo:** cada espírito persegue o inimigo mais perto dele, dentro de 400 px, a 230 px/s.
- **Como aplica:** tique de 0,5 s por espírito. Cada toque dá 24 de dano (o bônus de raridade multiplica) e deixa o inimigo lento por 2 s (`prende` 2.0, via `deixar_lento` em `monstro.gd`). Com o inimigo lento, o dano dobra (`mult_lento` 2.0): 48 por toque.
- **Limites:** 4 espíritos por invocação; dividem o pool de 48 golpes novos.

**Mudanças:** desde 18/10, aliado temporário. Antes: dura 7 s e recarga de 2,2 s. Agora: 50 s e 30 s, com a recarga contando só depois que a leva some.
