# Trecho injetado pelo gerar.py do lobo no framework do Luke (antes da secao "2. materiais"), por troca de texto. Roda dentro do exec do ../lucas/gerar.py.
# ARMA (padrao do elenco #586): a pistola de cada mao cresce ARMA_ESCALA no comprimento e ARMA_ESPESSURA na largura, em torno da propria mao,
# direto na malha (antes das cascas do contorno, que sao copias desta malha).
bpy.context.view_layer.update()
ARMA = [o for o in heroi if o.name.startswith("Adaga na mão")]
for _lado in ("e", "d"):
    _pecas = [o for o in ARMA if o.name.endswith(" " + _lado) and o.type == "MESH"]
    _piv = Vector(PONTOS["punho_" + _lado]) + Vector((0.02, -0.04, -0.09))
    _longe = max(((o.matrix_world @ v.co) for o in _pecas for v in o.data.vertices), key=lambda q: (q - _piv).length)
    _d = (_longe - _piv).normalized()
    _dd = Matrix([[_d[i] * _d[j] for j in range(3)] for i in range(3)])
    _M3 = Matrix.Identity(3) * ARMA_ESPESSURA + _dd * (ARMA_ESCALA - ARMA_ESPESSURA)
    _X = Matrix.Translation(_piv) @ _M3.to_4x4() @ Matrix.Translation(-_piv)
    for o in _pecas:
        o.data.transform(o.matrix_world.inverted() @ _X @ o.matrix_world)
        o.data.update()
print("ARMA: %d peças (pistolas), escala %.2f, espessura %.2f" % (len(ARMA), ARMA_ESCALA, ARMA_ESPESSURA))

