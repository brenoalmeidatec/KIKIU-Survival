extends RefCounted
## Regra de rotação do pixel art da v2: um sprite de pixel art NUNCA gira por um ângulo livre em tempo de execução, porque os pixels da
## arte deixam de cair na grade do mundo (960x540) e viram pixels de tamanhos diferentes. O que pode:
##   - passos de 90 graus (a grade se mantém: é só trocar linha por coluna), com `quarto`;
##   - versões pré-giradas e desenhadas na hora de fazer a arte (o corte da katana, ver Efeitos.corte_direcao);
##   - formas calculadas por pixel do mundo no shader (o crescente do eco), que não têm texel para girar.
## Ainda NÃO coberto (pendente, fica para outro PR porque exige folhas pré-giradas por sprite): projéteis do Luke (adagas.gd: folha animada,
## míssil e adaga procedural), lâminas e trechos de armas.gd e armas_novas.gd, e o escudo.gd. Esta regra vale para o que já passou por ela.
## Luzes (PointLight2D) e polígonos de UI ficam de fora: não são pixel art.

const QUARTO := PI / 2.0


## O ângulo `rad` arredondado ao múltiplo de 90 graus mais próximo (em radianos).
static func quarto(rad: float) -> float:
	return snappedf(rad, QUARTO)


## Verdadeiro se `rad` é (com folga de float) um múltiplo de 90 graus.
static func e_quarto(rad: float) -> bool:
	return absf(rad - snappedf(rad, QUARTO)) < 0.0001
