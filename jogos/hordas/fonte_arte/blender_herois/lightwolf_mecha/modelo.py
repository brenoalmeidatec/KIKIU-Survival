"""Modelo do MECHA do LightWolf (robo blindado azul-gelo com orelhas de lobo, visor ciano, misseis nos ombros e canhoes nos antebracos), por script.

Mesma interface do ../nicao/modelo.py: `construir(ns)` devolve (pecas, OSSO_DE, PONTOS, H). As ARTICULACOES sao as do Nicao (mesmos ossos, mesmo IK, mesmas
animacoes); muda so o que veste cada osso. NAO ha arma de mao: o osso "marreta" fica sem geometria.
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
BRILHANTES = {"Neon ciano": "#7ff3ff"}


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
        quadril, joelho, tornoz = P(s * .32, 0, 1.00), P(s * .33, .02, .66), P(s * .33, .03, .38)
        # perna: coxa grossa de casco, joelho de junta preta com placa, canela com faixa de neon, pe pesado com biqueira clara
        nova("perna" + sfx, segment("Coxa " + lado, joelho, quadril, .30, .34, M["Casco azul"], 6))
        nova("perna" + sfx, box("Placa da coxa " + lado, P(s * .34, -.22, .88), (.44, .14, .46), M["Casco claro"], .05))
        nova("canela" + sfx, segment("Canela " + lado, tornoz, joelho, .25, .29, M["Casco azul"], 6))
        nova("canela" + sfx, ico("Joelho " + lado, P(s * .33, -.04, .66), (.25, .24, .25), M["Junta preta"], 1))
        nova("canela" + sfx, box("Joelheira " + lado, P(s * .33, -.22, .70), (.40, .14, .30), M["Casco claro"], .05))
        nova("canela" + sfx, box("Neon da canela " + lado, P(s * .33, -.27, .50), (.08, .05, .26), M["Neon ciano"], .01))
        nova("pe" + sfx, box("Bota " + lado, P(s * .33, -.08, .20), (.60, .86, .40), M["Casco escuro"], .07))
        nova("pe" + sfx, box("Biqueira " + lado, P(s * .33, -.40, .24), (.52, .26, .26), M["Casco claro"], .05))
        nova("pe" + sfx, box("Cano da bota " + lado, P(s * .33, .03, .43), (.56, .58, .10), M["Junta preta"], .02))
        # braco: ombro, cotovelo e punho nos mesmos pontos do Nicao (o IK das maos na haste depende deles)
        ombro = P(s * .66, 0, 1.94)
        cotov, punho = (P(-.92, -.06, 1.52), P(-1.14, -.20, 1.12)) if s < 0 else (P(.84, -.04, 1.50), P(.80, -.22, 1.02))
        pontos.update({"quadril" + sfx: quadril, "joelho" + sfx: joelho, "tornozelo" + sfx: tornoz,
                       "ombro" + sfx: ombro, "cotovelo" + sfx: cotov, "punho" + sfx: punho})
        nova("braco" + sfx, segment("Braço " + lado, ombro, cotov, .28, .25, M["Junta preta"], 6))
        nova("braco" + sfx, box("Ombreira " + lado, P(s * .84, 0, 2.00), (.68, .74, .50), M["Casco azul"], .10))
        nova("braco" + sfx, box("Capa do ombro " + lado, P(s * .90, 0, 2.28), (.52, .60, .14), M["Casco claro"], .05))
        # pod de misseis no alto do ombro: caixa escura com a boca de 4 tubos virada para a frente
        nova("braco" + sfx, box("Pod de misseis " + lado, P(s * .86, .02, 2.58), (.50, .46, .42), M["Junta preta"], .05))
        nova("braco" + sfx, box("Moldura do pod " + lado, P(s * .86, -.20, 2.58), (.46, .06, .38), M["Casco claro"], .02))
        for dx in (-.10, .10):
            for dz in (-.09, .09):
                nova("braco" + sfx, ico("Tubo de missil", P(s * .86 + dx, -.245, 2.58 + dz), (.065, .04, .065), M["Bocal"], 1))
        nova("antebraco" + sfx, segment("Antebraço " + lado, cotov, punho, .26, .22, M["Casco escuro"], 6))
        dv = (Vector(punho) - Vector(cotov)).normalized()
        meio = (Vector(punho) + Vector(cotov)) / 2
        rot = dv.to_track_quat("Z", "Y").to_euler()
        nova("antebraco" + sfx, box("Canhão do antebraço " + lado, tuple(meio), (.46, .50, .56), M["Casco azul"], .08, rot))
        nova("antebraco" + sfx, box("Hexagono do antebraço " + lado, tuple(meio + Vector((s * .22, -.02, 0))), (.05, .30, .30), M["Neon ciano"], .01, rot))
        nova("antebraco" + sfx, segment("Cano do antebraço " + lado, tuple(Vector(punho) - dv * .02), tuple(Vector(punho) + dv * .46), .17, .15, M["Bocal"], 8))
        nova("antebraco" + sfx, ico("Anel do cano " + lado, tuple(Vector(punho) + dv * .44), (.20, .20, .07), M["Neon ciano"], 1))
    pontos["marreta"] = pontos["punho_e"]

    # quadril: pelve blindada com saia de placas
    nova("quadril", box("Pelve", P(0, 0, 1.08), (1.02, .70, .32), M["Casco escuro"], .07))
    nova("quadril", box("Placa frontal da pelve", P(0, -.36, .90), (.44, .12, .56), M["Casco azul"], .05))
    nova("quadril", box("Saia traseira", P(0, .40, .88), (.70, .10, .50), M["Casco azul"], .04))
    for s in (-1, 1):
        nova("quadril", box("Saia lateral %d" % s, P(s * .46, -.04, .92), (.14, .46, .46), M["Casco claro"], .04))
    # tronco: cabine de vidro escuro no peito, nucleo neon abaixo, mochila de misseis nas costas
    nova("torso", box("Torso", P(0, 0, 1.64), (1.10, .80, .96), M["Casco azul"], .12))
    nova("torso", box("Moldura da cabine", P(0, -.39, 1.86), (.74, .06, .58), M["Casco claro"], .04))
    nova("torso", box("Vidro da cabine", P(0, -.43, 1.88), (.58, .04, .44), M["Vidro da cabine"], .02))
    nova("torso", box("Placa do lobo", P(0, -.41, 1.42), (.46, .06, .30), M["Casco claro"], .03))
    nova("torso", box("Nucleo neon", P(0, -.45, 1.42), (.18, .04, .14), M["Neon ciano"], .01))
    nova("torso", box("Cintura de junta", P(0, 0, 1.15), (.82, .62, .14), M["Junta preta"], .03))
    nova("torso", box("Mochila", P(0, .56, 1.90), (.86, .36, .94), M["Casco claro"], .08))
    for s in (-1, 1):
        nova("torso", box("Neon da mochila %d" % s, P(s * .26, .75, 1.90), (.08, .04, .62), M["Neon ciano"], .01))
        nova("torso", box("Respiro lateral %d" % s, P(s * .56, .10, 1.50), (.06, .40, .30), M["Junta preta"], .01))
    # cabeca: capacete de lobo (focinho curto, visor ciano, duas orelhas altas)
    nova("cabeca", box("Pescoço", P(0, 0, 2.22), (.38, .36, .20), M["Junta preta"], .03))
    nova("cabeca", ico("Capacete", P(0, 0, 2.64), (.50, .47, .44), M["Casco azul"], 2))
    nova("cabeca", box("Focinho", P(0, -.36, 2.44), (.44, .30, .22), M["Casco claro"], .06))
    nova("cabeca", box("Queixo", P(0, -.34, 2.28), (.34, .22, .10), M["Casco escuro"], .03))
    nova("cabeca", box("Olho visor", P(0, -.42, 2.66), (.56, .06, .13), M["Neon ciano"], .02))
    nova("cabeca", box("Testeira", P(0, -.30, 2.90), (.34, .20, .10), M["Casco claro"], .03))
    for s in (-1, 1):
        nova("cabeca", segment("Orelha %d" % s, P(s * .30, .02, 2.84), P(s * .34, 0.0, 3.40), .15, .035, M["Casco azul"], 4))
        nova("cabeca", segment("Dentro da orelha %d" % s, P(s * .30, -.10, 2.90), P(s * .33, -.09, 3.30), .07, .02, M["Casco escuro"], 4))
        nova("cabeca", box("Bochecha %d" % s, P(s * .40, -.12, 2.50), (.14, .40, .30), M["Casco claro"], .04))
    # sem arma de mao (A15): o osso "marreta" fica sem geometria; os bracos sao posados pelas animacoes do Nicao e os canhoes dos antebracos apontam a frente
    return pecas, osso_de, pontos, H
