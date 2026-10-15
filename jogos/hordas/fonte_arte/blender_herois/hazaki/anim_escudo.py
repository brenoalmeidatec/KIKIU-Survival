"""ESCUDO / DEFESA (guarda firme): 4 quadros. q0 e q1 = ENTRADA (a katana sobe da lateral e cruza na frente do tronco, a lâmina em diagonal para cima e
para a esquerda da tela, o braço esquerdo sobe em apoio), q2 = SEGURA o golpe (o corpo cede um pouco, joelhos mais dobrados), q3 = hold (a guarda firme).
A lâmina cruza o peito, então cobre o corpo de frente e fica visível de perfil (aponta para a frente e para cima); nas costas fica atrás do corpo (o gerar.py
não desenha rastro aqui).

Os ângulos do braço da katana e do braço esquerdo foram RESOLVIDOS por `ik_katana.py` (posição da guarda e direção da lâmina no espaço do herói; as animações
não dependem dele). Posições-alvo (unidades do modelo; x direita da tela, y para trás, z para cima):
  q0: guarda (0.45, -0.40, 1.70), lâmina (0.1, -0.15, 0.9)   mão esquerda (-0.30, -0.40, 1.60)
  q1..q3: guarda (0.30, -0.50, 1.85), lâmina (-0.5, -0.15, 0.85)   mão esquerda (-0.18, -0.55, 1.85)  (WDIR=2.5: prioriza a direção da lâmina)

Sinais: braço, antebraço, perna e canela: x NEGATIVO = para a frente; tronco e cabeça: x POSITIVO = para a frente (ver LEIA-ME.md).
"""
import ossos

N_QUADROS = 4
S_POR_QUADRO = [0.07, 0.08, 0.10, 0.14]

# braço e antebraço da katana (x, y, z), braço e antebraço esquerdo (x, y, z), tronco (x), cabeça (x), coxa, canela (x, as duas pernas), raiz (x)
QUADROS = [
    dict(bd=(-0.134, 0.559, -1.142), ad=(-2.716, -0.108, -1.517), be=(0.134, -0.325, 0.284), ae=(-0.927, -0.153, 0.405),
         tronco=0.05, cabeca=0.0, coxa=-0.12, canela=0.25, raiz=0.0),
    dict(bd=(0.031, 0.413, -1.057), ad=(-2.561, 0.349, -1.480), be=(-0.239, -0.357, 0.479), ae=(-1.042, 0.028, 0.489),
         tronco=0.10, cabeca=0.05, coxa=-0.22, canela=0.40, raiz=0.0),
    dict(bd=(0.031, 0.413, -1.057), ad=(-2.561, 0.349, -1.480), be=(-0.239, -0.357, 0.479), ae=(-1.042, 0.028, 0.489),
         tronco=-0.12, cabeca=-0.10, coxa=-0.38, canela=0.70, raiz=-0.06),
    dict(bd=(0.031, 0.413, -1.057), ad=(-2.561, 0.349, -1.480), be=(-0.239, -0.357, 0.479), ae=(-1.042, 0.028, 0.489),
         tronco=0.12, cabeca=0.08, coxa=-0.30, canela=0.55, raiz=0.0),
]


def posar(arm, quadro, n_quadros):
    p = QUADROS[quadro]
    ossos.girar(arm, "raiz", x=p["raiz"])
    ossos.girar(arm, "torso", x=p["tronco"])
    ossos.girar(arm, "cabeca", x=p["cabeca"])
    ossos.girar(arm, "braco_d", x=p["bd"][0], y=p["bd"][1], z=p["bd"][2])
    ossos.girar(arm, "antebraco_d", x=p["ad"][0], y=p["ad"][1], z=p["ad"][2])
    ossos.girar(arm, "braco_e", x=p["be"][0], y=p["be"][1], z=p["be"][2])
    ossos.girar(arm, "antebraco_e", x=p["ae"][0], y=p["ae"][1], z=p["ae"][2])
    for lado in ("e", "d"):
        ossos.girar(arm, "perna_" + lado, x=p["coxa"])
        ossos.girar(arm, "canela_" + lado, x=p["canela"])
        ossos.girar(arm, "pe_" + lado, x=-(p["coxa"] + p["canela"] + p["raiz"]))     # a bota fica plana, como no repouso
    ossos.pisar(arm)
