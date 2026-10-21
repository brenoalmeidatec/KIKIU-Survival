"""SECUNDÁRIO / DEFESA (guarda): 2 quadros. As duas adagas cruzam na frente do peito em X (cada mão perto do ombro oposto, as lâminas para cima e para fora), o corpo
agachado e levemente à frente. q0 = ENTRADA (os braços sobem, o corpo desce a meio caminho), q1 = GUARDA firme (hold: o corpo cede um pouco mais, as lâminas se cruzam).
O jogo toca o escudo pelos tempos do JSON (`s_quadros`): o último quadro segura enquanto o botão estiver apertado.
Os ângulos vêm da pose de abertura do leque (anim_combo.py, q0), onde as mãos já cruzam o peito.
"""
import ossos

N_QUADROS = 2
S_POR_QUADRO = [0.07, 0.14]

#        braço direito, antebraço, braço esq., antebraço, tronco (x), coxa, canela, raiz (x)
QUADROS = [
    dict(d=(-0.80, 0.0, -0.35), ad=(-1.30, 0.0, 0.0), e=(-0.80, 0.0, 0.35), ae=(-1.30, 0.0, 0.0), tronco=0.08, coxa=-0.22, canela=0.40, raiz=0.0),
    dict(d=(-1.00, 0.0, -0.50), ad=(-1.70, 0.0, 0.0), e=(-1.00, 0.0, 0.50), ae=(-1.70, 0.0, 0.0), tronco=0.18, coxa=-0.38, canela=0.68, raiz=-0.04),
]


def posar(arm, quadro, n_quadros):
    p = QUADROS[quadro]
    ossos.girar(arm, "raiz", x=p["raiz"])
    ossos.girar(arm, "torso", x=p["tronco"])
    ossos.girar(arm, "cabeca", x=-0.5 * p["tronco"])
    for osso, chave in (("braco_d", "d"), ("antebraco_d", "ad"), ("braco_e", "e"), ("antebraco_e", "ae")):
        ossos.girar(arm, osso, x=p[chave][0], y=p[chave][1], z=p[chave][2])
    for lado in ("e", "d"):
        ossos.girar(arm, "perna_" + lado, x=p["coxa"])
        ossos.girar(arm, "canela_" + lado, x=p["canela"])
        ossos.girar(arm, "pe_" + lado, x=-(p["coxa"] + p["canela"] + p["raiz"]))     # a bota fica plana, como no repouso
    ossos.adaga(arm, True, True)
    ossos.pisar(arm)
