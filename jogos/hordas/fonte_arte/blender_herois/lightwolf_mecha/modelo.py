"""Modelo do MECHA do LightWolf (robo blindado azul-gelo com orelhas de lobo, visor ciano, misseis nos ombros e canhoes nos antebracos), por script.

Mesma interface do ../nicao/modelo.py: `construir(ns)` devolve (pecas, OSSO_DE, PONTOS, H). Os ossos sao os mesmos do Nicao (mesma lista, mesmos nomes), mas as
ARTICULACOES do braco sao do mecha: o antebraco e o canhao e aponta para a frente e para baixo (45 graus) em repouso; o osso "marreta" fica sem geometria.
Referencia: notas/artes_chatgpt/A15_lightwolf_mecha_ref.png (frente, lado, costas). Sem pele e sem direito autoral: desenho proprio.
Eixos: x = direita da tela, y = para tras (o heroi olha para -y), z = para cima.
"""
import bpy
from mathutils import Vector

H = -0.75


def P(x, y, z):
    return (x, y + H, z)


# nome -> cor base (tom do meio das 4 faixas; o jogo e escuro, entao o casco e um azul de aco, nao o azul-gelo da referencia)
PALETA = {
    "Casco azul": "#6b9bd2", "Casco claro": "#c8dff6", "Casco escuro": "#436aa4", "Junta preta": "#232a3e", "Vidro da cabine": "#2b4366",
    "Bocal": "#161b2a", "Haste de aço": "#46526c",
}
BRILHANTES = {"Neon ciano": "#7ff3ff", "Clarao do tiro": "#f2ffff"}


def construir(ns):
    mat, box, ico, segment = ns["mat"], ns["box"], ns["ico"], ns["segment"]
    M = {n: bpy.data.materials.get(n) or mat(n, (0.2, 0.2, 0.2)) for n in list(PALETA) + list(BRILHANTES)}
    pecas = []
    osso_de = {}
    pontos = {}

    def nova(osso, obj):
        pecas.append(obj)
        osso_de[obj] = osso
        return obj

    for lado, s in (("esquerda", -1), ("direita", 1)):
        sfx = "_e" if s < 0 else "_d"
        quadril, joelho, tornoz = P(s * .30, 0, 1.00), P(s * .32, .02, .66), P(s * .32, .03, .38)
        # perna grossa em varias pecas: coxa, placas, joelho de junta com capa, canela com aletas e modulo, bota pesada
        nova("perna" + sfx, segment("Coxa " + lado, joelho, quadril, .30, .34, M["Casco azul"], 6))
        nova("perna" + sfx, box("Placa da coxa " + lado, P(s * .30, -.24, .88), (.40, .14, .46), M["Casco claro"], .05))
        nova("perna" + sfx, box("Placa lateral da coxa " + lado, P(s * .56, .0, .86), (.12, .40, .42), M["Casco escuro"], .04))
        nova("perna" + sfx, box("Neon da coxa " + lado, P(s * .30, -.32, .74), (.16, .04, .05), M["Neon ciano"], .01))
        nova("canela" + sfx, segment("Canela " + lado, tornoz, joelho, .25, .29, M["Casco azul"], 6))
        nova("canela" + sfx, ico("Joelho " + lado, P(s * .32, -.04, .66), (.25, .24, .25), M["Junta preta"], 1))
        nova("canela" + sfx, box("Joelheira " + lado, P(s * .32, -.24, .70), (.36, .14, .28), M["Casco claro"], .05))
        nova("canela" + sfx, box("Neon da canela " + lado, P(s * .32, -.30, .50), (.07, .05, .24), M["Neon ciano"], .01))
        nova("canela" + sfx, box("Aleta da canela " + lado, P(s * .55, .0, .50), (.10, .40, .34), M["Casco claro"], .04))
        nova("canela" + sfx, box("Modulo da panturrilha " + lado, P(s * .32, .26, .54), (.34, .16, .34), M["Casco escuro"], .04))
        nova("pe" + sfx, box("Bota " + lado, P(s * .32, -.08, .20), (.58, .86, .40), M["Casco escuro"], .07))
        nova("pe" + sfx, box("Biqueira " + lado, P(s * .32, -.40, .24), (.50, .26, .26), M["Casco claro"], .05))
        nova("pe" + sfx, box("Cano da bota " + lado, P(s * .32, .03, .43), (.52, .54, .10), M["Junta preta"], .02))
        nova("pe" + sfx, box("Neon da bota " + lado, P(s * .32, -.54, .30), (.20, .04, .05), M["Neon ciano"], .01))
        # braco esguio: ombro, cotovelo e punho; o antebraco e o canhao e aponta para a frente e para baixo em repouso
        ombro = P(s * .60, 0, 1.94)
        cotov, punho = P(s * .78, -.02, 1.46), P(s * .80, -.36, 1.12)
        pontos.update({"quadril" + sfx: quadril, "joelho" + sfx: joelho, "tornozelo" + sfx: tornoz,
                       "ombro" + sfx: ombro, "cotovelo" + sfx: cotov, "punho" + sfx: punho})
        nova("braco" + sfx, segment("Braço " + lado, ombro, cotov, .20, .17, M["Junta preta"], 6))
        nova("braco" + sfx, box("Ombreira " + lado, P(s * .74, 0, 2.00), (.52, .60, .44), M["Casco azul"], .10))
        nova("braco" + sfx, box("Capa do ombro " + lado, P(s * .78, 0, 2.26), (.44, .54, .12), M["Casco claro"], .05))
        nova("braco" + sfx, box("Armadura do braço " + lado, P(s * .80, -.02, 1.72), (.34, .36, .40), M["Casco azul"], .08))
        nova("braco" + sfx, ico("Cotovelo " + lado, cotov, (.19, .19, .19), M["Junta preta"], 1))
        # pod de misseis 2x2 no alto do ombro, boca virada para a frente
        nova("braco" + sfx, box("Pod de misseis " + lado, P(s * .76, .02, 2.54), (.46, .44, .40), M["Junta preta"], .05))
        nova("braco" + sfx, box("Moldura do pod " + lado, P(s * .76, -.20, 2.54), (.44, .06, .38), M["Casco claro"], .02))
        for dx in (-.10, .10):
            for dz in (-.09, .09):
                nova("braco" + sfx, ico("Tubo de missil", P(s * .76 + dx, -.245, 2.54 + dz), (.07, .04, .07), M["Bocal"], 1))
        dv = (Vector(punho) - Vector(cotov)).normalized()
        meio = (Vector(punho) + Vector(cotov)) / 2
        rot = dv.to_track_quat("Z", "Y").to_euler()
        # canhao embutido: carcaca do antebraco, hexagono ciano em colmeia na lateral, cano escuro com boca ciano para a FRENTE
        nova("antebraco" + sfx, box("Carcaça do canhão " + lado, tuple(meio - dv * .02), (.42, .38, .60), M["Casco azul"], .08, rot))
        nova("antebraco" + sfx, box("Placa do canhão " + lado, tuple(meio + dv * .06 + Vector((0, 0, .20))), (.34, .30, .16), M["Casco claro"], .04, rot))
        m = meio + Vector((s * .21, 0, 0))
        nova("antebraco" + sfx, segment("Aro do hexagono " + lado, tuple(m - Vector((s * .02, 0, 0))), tuple(m + Vector((s * .03, 0, 0))), .21, .21, M["Junta preta"], 6))
        nova("antebraco" + sfx, segment("Hexagono do antebraço " + lado, tuple(m + Vector((s * .015, 0, 0))), tuple(m + Vector((s * .05, 0, 0))), .155, .155, M["Neon ciano"], 6))
        base_cano, ponta = Vector(punho) + dv * .05, Vector(punho) + dv * .58
        nova("antebraco" + sfx, segment("Cano do canhão " + lado, tuple(base_cano), tuple(ponta), .16, .14, M["Bocal"], 8))
        nova("antebraco" + sfx, segment("Anel do cano " + lado, tuple(base_cano + dv * .22), tuple(base_cano + dv * .29), .185, .185, M["Casco claro"], 8))
        nova("antebraco" + sfx, segment("Boca ciano " + lado, tuple(ponta - dv * .02), tuple(ponta + dv * .05), .17, .17, M["Neon ciano"], 8))
        nova("antebraco" + sfx, segment("Boca escura " + lado, tuple(ponta + dv * .04), tuple(ponta + dv * .07), .09, .09, M["Bocal"], 8))
        # clarao do tiro: so aparece no quadro do disparo (ossos.zerar esconde; anim_combo liga). O nome "Olho..." evita a casca de contorno do gerar.py
        nova("antebraco" + sfx, segment("Olho clarao do tiro " + lado, tuple(ponta + dv * .06), tuple(ponta + dv * .66), .26, .03, M["Clarao do tiro"], 8))
        nova("antebraco" + sfx, ico("Olho clarao da boca " + lado, tuple(ponta + dv * .10), (.27, .27, .27), M["Clarao do tiro"], 1))
    pontos["marreta"] = pontos["punho_e"]

    # quadril: pelve blindada com saia de placas
    nova("quadril", box("Pelve", P(0, 0, 1.08), (.86, .62, .30), M["Casco escuro"], .07))
    nova("quadril", box("Placa frontal da pelve", P(0, -.34, .90), (.40, .12, .56), M["Casco azul"], .05))
    nova("quadril", box("Saia traseira", P(0, .38, .88), (.60, .10, .50), M["Casco azul"], .04))
    for s in (-1, 1):
        nova("quadril", box("Saia lateral %d" % s, P(s * .40, -.04, .94), (.12, .46, .42), M["Casco claro"], .04))
    # tronco esguio: cabine de vidro escuro no peito, emblema do lobo e nucleo hexagonal ciano abaixo, mochila nas costas
    nova("torso", box("Torso", P(0, 0, 1.64), (.84, .66, .92), M["Casco azul"], .12))
    nova("torso", box("Peitoral alto", P(0, -.04, 2.02), (.98, .70, .30), M["Casco azul"], .10))
    nova("torso", box("Moldura da cabine", P(0, -.33, 1.90), (.64, .06, .54), M["Casco claro"], .04))
    nova("torso", box("Vidro da cabine", P(0, -.37, 1.92), (.50, .04, .40), M["Vidro da cabine"], .02))
    nova("torso", box("Piloto", P(0, -.34, 1.90), (.16, .04, .22), M["Junta preta"], .02))
    nova("torso", box("Placa do lobo", P(0, -.35, 1.54), (.44, .06, .26), M["Casco claro"], .03))
    nova("torso", box("Focinho do emblema", P(0, -.39, 1.54), (.14, .04, .12), M["Casco escuro"], .02))
    nova("torso", segment("Nucleo hexagonal", P(0, -.34, 1.30), P(0, -.42, 1.30), .12, .12, M["Neon ciano"], 6))
    nova("torso", box("Cintura de junta", P(0, 0, 1.16), (.60, .50, .16), M["Junta preta"], .03))
    nova("torso", box("Mochila", P(0, .50, 1.90), (.70, .34, .84), M["Casco claro"], .08))
    for s in (-1, 1):
        nova("torso", box("Neon da mochila %d" % s, P(s * .22, .68, 1.90), (.07, .04, .56), M["Neon ciano"], .01))
        nova("torso", box("Respiro lateral %d" % s, P(s * .43, .10, 1.50), (.06, .36, .28), M["Junta preta"], .01))
    # cabeca: capacete de lobo (focinho curto, visor ciano, duas orelhas altas)
    nova("cabeca", box("Pescoço", P(0, 0, 2.24), (.34, .32, .20), M["Junta preta"], .03))
    nova("cabeca", ico("Capacete", P(0, 0, 2.62), (.46, .44, .42), M["Casco azul"], 2))
    nova("cabeca", box("Focinho", P(0, -.34, 2.44), (.40, .28, .20), M["Casco claro"], .06))
    nova("cabeca", box("Queixo", P(0, -.32, 2.29), (.30, .20, .10), M["Casco escuro"], .03))
    nova("cabeca", box("Faixa do visor", P(0, -.36, 2.66), (.54, .08, .17), M["Junta preta"], .02))
    nova("cabeca", box("Olho visor", P(0, -.41, 2.66), (.46, .04, .08), M["Neon ciano"], .02))
    nova("cabeca", box("Testeira", P(0, -.28, 2.90), (.30, .20, .10), M["Casco claro"], .03))
    for s in (-1, 1):
        nova("cabeca", segment("Orelha %d" % s, P(s * .28, .02, 2.82), P(s * .30, 0.0, 3.46), .14, .03, M["Casco azul"], 4))
        nova("cabeca", segment("Dentro da orelha %d" % s, P(s * .28, -.10, 2.88), P(s * .30, -.09, 3.30), .065, .02, M["Casco escuro"], 4))
        nova("cabeca", box("Bochecha %d" % s, P(s * .38, -.12, 2.50), (.12, .38, .28), M["Casco claro"], .04))
    return pecas, osso_de, pontos, H
