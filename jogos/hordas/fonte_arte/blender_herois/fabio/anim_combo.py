"""COMBO do FABIAN (arco YUMI): 3 golpes x 6 quadros = 18 quadros, o mesmo contrato do anim_combo do Hazaki (posar(arm, quadro, n)).

Golpe 1 e 2 = TIRO: mira (braço esquerdo estica até a pega), puxa a corda até o rosto, segura, solta, recua, volta.
Golpe 3 = TIRO DUPLO: mira, puxa, solta (1ª flecha), puxa de novo mais rápido, solta (2ª flecha), volta.
Ângulos em radianos, no contrato de ossos.girar (x/y/z do herói; ver hazaki/LEIA-ME.md). O corpo é posto no chão por ossos.pisar.
"""
import ossos

GOLPES = 3
QUADROS_POR_GOLPE = 6
N_QUADROS = GOLPES * QUADROS_POR_GOLPE

# braço esquerdo esticado até a pega do arco (sem flexão no cotovelo nos tiros)
MIRA_E = {"braco_e": (0.0, 0.6, 0.0), "antebraco_e": (0.0, -0.6, 0.0)}
# braço direito: ombro para fora, cotovelo para trás, mão no rosto (puxa)
PUXA_D = {"braco_d": (0.0, -1.57, 0.0), "antebraco_d": (0.0, -2.45, 0.0)}
# solta: a mão da corda vai para a frente, o braço cede um pouco
SOLTA_D = {"braco_d": (0.0, -1.2, 0.0), "antebraco_d": (0.0, -1.9, 0.0)}
# repouso do combo: o braço direito pendurado, o esquerdo voltando devagar
RECUA_E = {"braco_e": (0.0, 0.4, 0.0), "antebraco_e": (0.0, 0.0, 0.0)}


def _frames_tiro():
    """Seis quadros de um tiro simples."""
    return [
        {"braco_e": (0.0, 0.4, 0.0), "antebraco_e": (0.0, 0.0, 0.0), "braco_d": (0.0, 0.0, 0.0), "antebraco_d": (0.0, -0.2, 0.0)},  # antecipação: pega a flecha
        {**MIRA_E, "braco_d": (0.0, -0.9, 0.0), "antebraco_d": (0.0, -1.9, 0.0)},                                                   # mira, puxando
        {**MIRA_E, **PUXA_D, "torso": (-0.04, 0.0, 0.0)},                                                                          # puxa até o rosto
        {**MIRA_E, **PUXA_D, "torso": (-0.07, 0.0, 0.0)},                                                                          # segura (corpo recua 1 px)
        {**MIRA_E, **SOLTA_D},                                                                                                     # solta
        {**RECUA_E, "braco_d": (0.0, 0.0, 0.0), "antebraco_d": (0.0, -0.2, 0.0)},                                                  # volta
    ]


def _frames_duplo():
    """Seis quadros do tiro duplo: duas soltas seguidas."""
    return [
        {"braco_e": (0.0, 0.4, 0.0), "antebraco_e": (0.0, 0.0, 0.0), "braco_d": (0.0, 0.0, 0.0), "antebraco_d": (0.0, -0.2, 0.0)},
        {**MIRA_E, **PUXA_D},
        {**MIRA_E, **SOLTA_D},                                                                                                     # 1ª flecha
        {**MIRA_E, "braco_d": (0.0, -1.4, 0.0), "antebraco_d": (0.0, -2.2, 0.0), "torso": (-0.05, 0.0, 0.0)},                     # puxa de novo
        {**MIRA_E, **SOLTA_D, "torso": (-0.02, 0.0, 0.0)},                                                                         # 2ª flecha
        {**RECUA_E, "braco_d": (0.0, 0.0, 0.0), "antebraco_d": (0.0, -0.2, 0.0)},
    ]


QUADROS = _frames_tiro() + _frames_tiro() + _frames_duplo()
assert len(QUADROS) == N_QUADROS


def posar(arm, quadro, n_quadros):
    for osso, (x, y, z) in QUADROS[quadro].items():
        ossos.girar(arm, osso, x=x, y=y, z=z)
    ossos.pisar(arm)
    ossos.encaixar_x(arm)
