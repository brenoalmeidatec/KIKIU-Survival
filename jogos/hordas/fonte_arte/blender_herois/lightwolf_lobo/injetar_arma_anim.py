# Trecho injetado pelo gerar.py do lobo (antes da secao "5. cena"): tamanho da pistola POR ANIMACAO (como o ARMA_ESCALA_ANIM do hazaki/gerar.py).
# No escudo, no dano e no rolamento a pistola de 1,5x saia do quadro de 32 px; la ela volta a ~1x. A matriz de base de cada peca (prender() deixou a do
# mundo de repouso) e escalada em torno da mao do lado da peca.
BASE_ARMA = {o: o.matrix_basis.copy() for o in heroi if "Adaga na mão" in o.name}
PIVO_MAO = {l: Vector(PONTOS["punho_" + l]) + Vector((0.02, -0.04, -0.09)) for l in ("e", "d")}


def posar_arma(nome):
    fator = float(ARMA_ESCALA_ANIM.get(nome, 1.0))
    for o, b0 in BASE_ARMA.items():
        p = PIVO_MAO[o.name[-1]]
        o.matrix_basis = Matrix.Translation(p) @ Matrix.Scale(fator, 4) @ Matrix.Translation(-p) @ b0


