"""ESCUDO (guarda firme): 2 quadros. Quadro 0 = erguer (os braços sobem à frente), quadro 1 = segurar (guarda cheia, joelhos um pouco dobrados).

Sinais do rig (conferidos num teste no hazaki_rig.blend): nos ossos que apontam para baixo (braço, antebraço, perna, canela, pé),
x NEGATIVO leva para a frente, e o antebraço dobra para cima com x NEGATIVO. No tronco e na cabeça, que apontam para cima, é o contrário:
x POSITIVO inclina para a frente e x NEGATIVO inclina para trás.
A katana fica na mão direita da tela (braco_d / antebraco_d); o braço esquerdo sobe junto, com o antebraço para cima, como escudo.
"""
import ossos

N_QUADROS = 2

# tronco e cabeça (x, o tronco inclina um pouco para a frente para se agachar sobre a guarda), braço e antebraço de cada lado (x),
# perna e canela (x, iguais dos dois lados). A katana tem inclinação própria para a frente (rest), então o antebraço direito
# precisa somar ~-2.9 rad para a lâmina subir quase na vertical (de frente ela some se apontar para a câmera).
ERGUER = dict(tronco=0.0, cabeca=0.0, braco_d=-0.20, antebraco_d=-2.20, braco_e=-0.30, antebraco_e=-1.50,
              perna=-0.05, canela=0.15)
SEGURAR = dict(tronco=0.08, cabeca=0.10, braco_d=-0.50, antebraco_d=-2.40, braco_e=-0.80, antebraco_e=-1.80,
               perna=-0.10, canela=0.35)


def posar(arm, quadro, n_quadros):
    p = ERGUER if quadro == 0 else SEGURAR
    ossos.girar(arm, "torso", x=p["tronco"])
    ossos.girar(arm, "cabeca", x=p["cabeca"])
    ossos.girar(arm, "braco_d", x=p["braco_d"])
    ossos.girar(arm, "antebraco_d", x=p["antebraco_d"])
    ossos.girar(arm, "braco_e", x=p["braco_e"])
    ossos.girar(arm, "antebraco_e", x=p["antebraco_e"])
    for lado in ("e", "d"):
        ossos.girar(arm, "perna_" + lado, x=p["perna"])
        ossos.girar(arm, "canela_" + lado, x=p["canela"])
        ossos.girar(arm, "pe_" + lado, x=-(p["perna"] + p["canela"]))   # a bota fica plana, como no repouso
    ossos.pisar(arm)
