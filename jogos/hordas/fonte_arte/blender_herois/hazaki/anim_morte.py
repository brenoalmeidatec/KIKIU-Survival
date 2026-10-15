"""MORTE (WIP, ainda não fecha no quadro 32x44): 6 quadros. q0 leva o golpe (tronco e cabeça para trás), q1 cambaleia (passo para trás,
o corpo torce), q2 cai sobre os joelhos, q3 fica de joelhos com o tronco desabando para a frente, q4 senta e recosta para trás,
q5 sentado no chão, cabeça caída.

Sinais: ver anim_escudo.py. Tronco e cabeça: x NEGATIVO é para trás. Braço, antebraço, perna e canela: x NEGATIVO é para a frente.
Quedas não usam ossos.pisar (ele só olha as botas, ver o aviso em ossos.py): aqui o chão é o ponto mais baixo de TODO o corpo.
Por que não deitado de comprido: o herói tem ~3,3 unidades de comprimento (~44 px); deitado, a vista de lado e as diagonais passam
dos 32 px de largura. Por isso a morte termina sentada e recostada, com a cabeça alta. Os quadros 2 a 5 ainda cortam a borda em
algumas direções (ver LOGBOOK e a pendência no relatório); o jogo não usa estes quadros ainda.
"""
import bpy

import ossos

N_QUADROS = 6

# cada quadro: tronco, cabeça (x; _z = torção), braços e antebraços (x), pernas e canelas (x). pe_total = ângulo final da bota
QUADROS = [
    dict(tronco=-0.28, cabeca=-0.45,
         braco_e=0.50, antebraco_e=-0.40, braco_d=0.60, antebraco_d=-0.60,
         perna_e=0.10, canela_e=0.40, perna_d=-0.10, canela_d=0.30),
    dict(tronco=-0.38, tronco_z=0.25, cabeca=-0.40, cabeca_z=-0.15,
         braco_e=-0.70, antebraco_e=-0.80, braco_d=0.90, antebraco_d=-0.30,
         perna_e=-0.20, canela_e=0.25, perna_d=0.35, canela_d=0.60),
    dict(tronco=-0.35, cabeca=-0.45,
         braco_e=0.30, antebraco_e=-0.20, braco_d=0.30, antebraco_d=-0.40,
         perna_e=-0.35, canela_e=0.95, perna_d=-0.40, canela_d=0.95),
    dict(tronco=0.10, cabeca=0.25,
         braco_e=-0.25, antebraco_e=-0.50, braco_d=-0.20, antebraco_d=-0.60,
         perna_e=-0.35, canela_e=0.95, perna_d=-0.40, canela_d=0.95),
    dict(tronco=-0.60, cabeca=-0.30,
         braco_e=-0.60, antebraco_e=-1.20, braco_d=-0.60, antebraco_d=-1.20,
         perna_e=-2.30, canela_e=2.80, perna_d=-2.30, canela_d=2.80, pe_total=3.82),
    dict(tronco=-0.75, cabeca=-0.45,
         braco_e=0.20, antebraco_e=-0.20, braco_d=0.20, antebraco_d=-0.20,
         perna_e=-2.30, canela_e=2.80, perna_d=-2.30, canela_d=2.80, pe_total=3.82),
]


def _z_min(arm):
    """Menor z, no espaço do herói (sem a escala do herói), de todos os vértices das peças presas ao esqueleto."""
    bpy.context.view_layer.update()
    inv = arm.matrix_world.inverted()
    menor = 1e9
    for o in arm.children:
        if o.type != "MESH":
            continue
        m = inv @ o.matrix_world
        for v in o.data.vertices:
            menor = min(menor, (m @ v.co).z)
    return menor


def posar(arm, quadro, n_quadros):
    z_repouso = _z_min(arm)                 # o gerar.py zera a pose antes de chamar
    p = QUADROS[quadro]
    ossos.girar(arm, "raiz", x=p.get("raiz", 0.0), z=p.get("raiz_z", 0.0))
    ossos.girar(arm, "torso", x=p.get("tronco", 0.0), z=p.get("tronco_z", 0.0))
    ossos.girar(arm, "cabeca", x=p.get("cabeca", 0.0), z=p.get("cabeca_z", 0.0))
    for osso in ("braco_e", "antebraco_e", "braco_d", "antebraco_d"):
        ossos.girar(arm, osso, x=p.get(osso, 0.0))
    for lado in ("e", "d"):
        perna = p.get("perna_" + lado, 0.0)
        canela = p.get("canela_" + lado, 0.0)
        ossos.girar(arm, "perna_" + lado, x=perna)
        ossos.girar(arm, "canela_" + lado, x=canela)
        total_pe = p.get("pe_total", 0.0)   # 0 = bota plana no mundo; 3.82 = bota para cima (sem a ponta no chão)
        ossos.girar(arm, "pe_" + lado, x=total_pe - (p.get("raiz", 0.0) + perna + canela))
    bpy.context.view_layer.update()
    ossos.mover(arm, "raiz", z=z_repouso - _z_min(arm))
