"""DANO (levou um golpe): 2 quadros. Quadro 0 = impacto (tronco e cabeça jogados para trás, os braços abrem, os joelhos cedem),
quadro 1 = recuo (o corpo volta um pouco, a cabeça ainda fica para trás).

Sinais: ver anim_escudo.py. Tronco e cabeça: x NEGATIVO é para trás. Braço, antebraço, perna e canela: x POSITIVO é para trás.
"""
import ossos

N_QUADROS = 2

IMPACTO = dict(tronco=-0.24, cabeca=-0.42, braco_e=0.55, antebraco_e=-0.35, braco_d=0.45, antebraco_d=-0.50,
               perna_e=0.15, canela_e=0.35, perna_d=-0.05, canela_d=0.25)
RECUO = dict(tronco=-0.15, cabeca=-0.30, braco_e=0.40, antebraco_e=-0.25, braco_d=0.30, antebraco_d=-0.35,
             perna_e=0.10, canela_e=0.25, perna_d=0.0, canela_d=0.20)


def posar(arm, quadro, n_quadros):
    p = IMPACTO if quadro == 0 else RECUO
    ossos.girar(arm, "torso", x=p["tronco"])
    ossos.girar(arm, "cabeca", x=p["cabeca"])
    for osso in ("braco_e", "antebraco_e", "braco_d", "antebraco_d"):
        ossos.girar(arm, osso, x=p[osso])
    for lado in ("e", "d"):
        ossos.girar(arm, "perna_" + lado, x=p["perna_" + lado])
        ossos.girar(arm, "canela_" + lado, x=p["canela_" + lado])
        ossos.girar(arm, "pe_" + lado, x=-(p["perna_" + lado] + p["canela_" + lado]))   # a bota fica plana, como no repouso
    ossos.pisar(arm)
