"""DANO (levou um golpe): 2 quadros, uma vez só (q0 = impacto, q1 = recuo máximo; o jogo emenda no parado). A pose tem de ler sozinha em 32x44 (o flash branco/vermelho fica por conta do shader do jogo).
q0 = IMPACTO: a cabeça é jogada para trás e o tronco se curva, os braços abrem, o corpo todo recua e os joelhos cedem.
q1 = RECUO máximo: o tronco curvado, o peso nos calcanhares, um pé escorregando para trás.
q2 = reage: o tronco volta a meio caminho, a cabeça acompanha atrasada.
q3 = quase de pé (volta ao repouso com ease, o jogo emenda no parado).

Sinais (ver anim_escudo.py): raiz x NEGATIVO = o corpo todo inclina para trás (pivô nos pés); tronco e cabeça: x NEGATIVO = para trás; braço, antebraço,
perna e canela: x NEGATIVO = para a frente (POSITIVO = para trás). A cabeça fica a ~0,5 rad do tronco no máximo (mais que isso a junta do pescoço abre).
O recuo é para TRÁS do herói (o golpe vem de frente); `ossos.pisar` põe as botas no chão e `ossos.encaixar_x` desliza o corpo só se passar dos 32 px (o recuo aparece pela inclinação do corpo; não há folga para deslocar o herói).
"""
import ossos

N_QUADROS = 2
S_POR_QUADRO = [0.07, 0.14]

# raiz (inclinação do corpo todo), recuo (unidades do modelo, para trás), tronco, cabeça, braços (x, y), antebraços, coxas e canelas (e = esq, d = dir)
QUADROS = [   # (só os dois primeiros quadros, os do Hazaki)
    dict(raiz=-0.05, recuo=0.05, tronco=-0.28, cabeca=-0.42,
         braco_e=(0.55, 0.18), antebraco_e=-0.45, braco_d=(0.12, -0.08), antebraco_d=-0.10,
         perna_e=0.15, canela_e=0.55, perna_d=-0.15, canela_d=0.40),
    dict(raiz=-0.08, recuo=0.10, tronco=-0.34, cabeca=-0.28,
         braco_e=(0.40, 0.15), antebraco_e=-0.30, braco_d=(0.10, -0.06), antebraco_d=-0.08,
         perna_e=0.35, canela_e=0.75, perna_d=-0.25, canela_d=0.55),
    dict(raiz=-0.05, recuo=0.06, tronco=-0.20, cabeca=-0.30,
         braco_e=(0.30, 0.12), antebraco_e=-0.30, braco_d=(0.08, -0.05), antebraco_d=-0.06,
         perna_e=0.20, canela_e=0.45, perna_d=-0.10, canela_d=0.35),
    dict(raiz=-0.04, recuo=0.06, tronco=-0.10, cabeca=-0.12,
         braco_e=(0.12, 0.10), antebraco_e=-0.20, braco_d=(0.12, -0.05), antebraco_d=-0.15,
         perna_e=0.08, canela_e=0.20, perna_d=-0.04, canela_d=0.15),
]


def posar(arm, quadro, n_quadros):
    p = QUADROS[quadro]
    ossos.girar(arm, "raiz", x=p["raiz"])
    ossos.girar(arm, "torso", x=p["tronco"])
    ossos.girar(arm, "cabeca", x=p["cabeca"])
    for lado in ("e", "d"):
        bx, by = p["braco_" + lado]
        ossos.girar(arm, "braco_" + lado, x=bx, y=by)
        ossos.girar(arm, "antebraco_" + lado, x=p["antebraco_" + lado])
        perna, canela = p["perna_" + lado], p["canela_" + lado]
        ossos.girar(arm, "perna_" + lado, x=perna)
        ossos.girar(arm, "canela_" + lado, x=canela)
        ossos.girar(arm, "pe_" + lado, x=-(perna + canela + p["raiz"]))     # a bota fica plana no chão
    ossos.pisar(arm)               # as botas no chão (o ancorar olharia a bainha, que desce quando o quadril recua)
    ossos.encaixar_x(arm)
