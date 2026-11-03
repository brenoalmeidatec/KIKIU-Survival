extends RefCounted
## Regra de rotação do pixel art da v2: um sprite de pixel art NUNCA gira por um ângulo livre em tempo de execução, porque os pixels da
## arte deixam de cair na grade do mundo (960x540) e viram pixels de tamanhos diferentes. O que pode:
##   - passos de 90 graus (a grade se mantém: é só trocar linha por coluna), com `quarto`;
##   - versões pré-giradas e desenhadas na hora de fazer a arte (o corte da katana, ver Efeitos.corte_direcao);
##   - formas calculadas por pixel do mundo no shader (o crescente do eco), que não têm texel para girar;
##   - sprites de arma e projétil que apontam para uma direção (adagas.gd, armas.gd, armas_novas.gd, AnimGolpes.desenhar): 16 direções,
##     três cópias pré-giradas por textura mais os quartos de volta por transformação (ver sprite_giro.gd e `direcao16` abaixo).
## Ainda NÃO coberto: o escudo.gd. Esta regra vale para o que já passou por ela.
## Luzes (PointLight2D) e polígonos de UI ficam de fora: não são pixel art.

const QUARTO := PI / 2.0


## O ângulo `rad` arredondado ao múltiplo de 90 graus mais próximo (em radianos).
static func quarto(rad: float) -> float:
	return snappedf(rad, QUARTO)


## Verdadeiro se `rad` é (com folga de float) um múltiplo de 90 graus.
static func e_quarto(rad: float) -> bool:
	return absf(rad - snappedf(rad, QUARTO)) < 0.0001


## As 16 direções do pixel art pré-girado (passos de 22,5 graus): (sub, quartos) com sub = 0 a 3 (a cópia girada 0, 22,5, 45 ou 67,5 graus) e
## quartos = 0 a 3 (voltas de 90 graus, que o desenho faz por transformação e são exatas). Ângulo desenhado = quartos x 90 + sub x 22,5.
## É o mesmo desdobramento do corte da katana (Efeitos.corte_direcao), sem o espelho.
static func direcao16(rad: float) -> Vector2i:
	var k := posmod(roundi(rad / (TAU / 16.0)), 16)
	return Vector2i(k % 4, k / 4)


## O ângulo, em radianos, que a direção `d` (de `direcao16`) representa.
static func angulo16(d: Vector2i) -> float:
	return float(d.y) * QUARTO + float(d.x) * (PI / 8.0)
