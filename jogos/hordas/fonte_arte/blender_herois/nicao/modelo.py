"""Modelo do Nicão (anão guardião de marreta), modelado por script a partir da referência do Codex (../referencia_herois/nicao.png).

`construir(ns)` recebe o namespace dos ajudantes do estudo do Codex (mat, box, ico, segment, line; ver gerar.py) e devolve
(peças, OSSO_DE, PONTOS, H): as peças criadas, o osso de cada uma, a posição de cada articulação (mundo do modelo, com o deslocamento H) e H.

Eixos do modelo: x = direita da tela, y = para trás (o herói olha para -y, para a câmera), z = para cima. Anão: 3,0 unidades até a crista do elmo
(~40 px), ombros largos, pernas curtas; a marreta (cabo de 3,2) passa da cabeça e fica na mão ESQUERDA DA TELA (x negativo), como na referência.
"""
import bpy
from mathutils import Vector

H = -0.75


def P(x, y, z):
    return (x, y + H, z)


# nome do material -> (cor base; é o tom do meio das 4 faixas), lido pelo gerar.py
PALETA = {
    "Elmo de ferro": "#a0a6b8", "Crista do elmo": "#aab0c4", "Armadura carvão": "#4a4c5c", "Ombreira azul": "#b8322a",
    "Barba ruiva": "#d0481e", "Tabardo vermelho": "#c8302a", "Couro castanho": "#6e4a28", "Luva": "#523622", "Pele": "#bc7a3a",
    "Cabo de madeira": "#8a5624", "Cabeça da marreta": "#6c78b8", "Latão antigo": "#b48c3a", "Bota de ferro": "#4c464c", "Olho": "#0a0c14",
}


def construir(ns):
    mat, box, ico, segment = ns["mat"], ns["box"], ns["ico"], ns["segment"]
    M = {n: bpy.data.materials.get(n) or mat(n, (0.2, 0.2, 0.2)) for n in PALETA}
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
        nova("perna" + sfx, segment("Coxa " + lado, joelho, quadril, .24, .27, M["Armadura carvão"]))
        nova("canela" + sfx, segment("Canela " + lado, tornoz, joelho, .20, .23, M["Armadura carvão"]))
        nova("canela" + sfx, box("Joelheira " + lado, P(s * .33, -.19, .68), (.42, .17, .34), M["Ombreira azul"], .06))
        nova("pe" + sfx, box("Bota " + lado, P(s * .33, -.08, .20), (.54, .80, .40), M["Bota de ferro"], .07))
        nova("pe" + sfx, box("Faixa da bota " + lado, P(s * .33, .03, .43), (.52, .54, .08), M["Couro castanho"], .02))
        # ombro, cotovelo e punho: braços longos o bastante para segurar a marreta com as duas mãos na frente do corpo
        ombro = P(s * .66, 0, 1.94)
        cotov, punho = (P(-.92, -.06, 1.52), P(-1.14, -.20, 1.12)) if s < 0 else (P(.84, -.04, 1.50), P(.80, -.22, 1.02))
        pontos.update({"quadril" + sfx: quadril, "joelho" + sfx: joelho, "tornozelo" + sfx: tornoz,
                       "ombro" + sfx: ombro, "cotovelo" + sfx: cotov, "punho" + sfx: punho})
        nova("braco" + sfx, segment("Braço " + lado, ombro, cotov, .27, .23, M["Pele"]))
        nova("braco" + sfx, box("Ombreira " + lado, P(s * .80, 0, 2.00), (.60, .66, .44), M["Ombreira azul"], .09))
        nova("braco" + sfx, box("Ombreira alta " + lado, P(s * .82, 0, 2.24), (.46, .54, .20), M["Ombreira azul"], .06))
        nova("antebraco" + sfx, segment("Antebraço " + lado, cotov, punho, .22, .19, M["Couro castanho"]))
        dv = (Vector(punho) - Vector(cotov)).normalized()
        meio = (Vector(punho) + Vector(cotov)) / 2
        nova("antebraco" + sfx, box("Braçal " + lado, tuple(meio), (.36, .38, .34), M["Ombreira azul"], .05,
                                    dv.to_track_quat("Z", "Y").to_euler()))
        nova("antebraco" + sfx, ico("Luva " + lado, tuple(Vector(punho) + dv * .08), (.20, .20, .21), M["Luva"], 2))
    pontos["marreta"] = pontos["punho_e"]

    # quadril: saiote vermelho na frente e atrás, placas laterais
    nova("quadril", box("Pelve", P(0, 0, 1.08), (.98, .64, .30), M["Armadura carvão"], .06))
    nova("quadril", box("Saiote frente", P(0, -.38, .84), (.30, .06, .64), M["Tabardo vermelho"], .01))
    nova("quadril", box("Saiote costas", P(0, .38, .84), (.62, .06, .50), M["Tabardo vermelho"], .01))
    for s in (-1, 1):
        nova("quadril", box("Placa da coxa %d" % s, P(s * .36, -.34, .90), (.34, .07, .44), M["Armadura carvão"], .03))
    # tronco
    nova("torso", box("Torso", P(0, 0, 1.58), (1.04, .74, .95), M["Armadura carvão"], .1))
    nova("torso", box("Peitoral vermelho", P(0, -.38, 1.50), (.30, .05, .74), M["Tabardo vermelho"], .01))
    nova("torso", box("Placa das costas", P(0, .39, 1.66), (.78, .05, .66), M["Armadura carvão"], .03))
    for s in (-1, 1):
        nova("torso", box("Alça %d" % s, P(s * .34, -.38, 1.80), (.12, .05, .62), M["Couro castanho"], .01))
    nova("torso", box("Cinto", P(0, 0, 1.10), (1.08, .80, .17), M["Couro castanho"], .03))
    nova("torso", box("Fivela", P(0, -.41, 1.10), (.24, .05, .15), M["Latão antigo"], .02))
    # cabeça: elmo, rosto escuro, barba ruiva
    nova("cabeca", ico("Elmo", P(0, 0, 2.52), (.50, .47, .44), M["Elmo de ferro"], 2))
    nova("cabeca", box("Aba do elmo", P(0, -.01, 2.26), (.98, .92, .12), M["Elmo de ferro"], .03))
    nova("cabeca", box("Nasal", P(0, -.44, 2.40), (.10, .07, .42), M["Crista do elmo"], .01))
    nova("cabeca", box("Crista do elmo", P(0, 0, 2.95), (.13, .66, .12), M["Crista do elmo"], .02))
    nova("cabeca", box("Rosto", P(0, -.30, 2.34), (.60, .18, .22), M["Pele"], .02))
    nova("cabeca", ico("Barba", P(0, -.33, 1.98), (.44, .28, .40), M["Barba ruiva"], 2))
    for s in (-1, 1):       # costeletas: a barba continua lida nas diagonais
        nova("cabeca", ico("Barba lado %d" % s, P(s * .33, -.22, 2.06), (.17, .30, .34), M["Barba ruiva"], 2))
    for s in (-1, 1):
        nova("cabeca", ico("Olho %d" % s, P(s * .15, -.405, 2.36), (.065, .03, .055), M["Olho"], 1))
    # marreta: cabo de madeira do chão até acima da cabeça, cabeça de pedra azul com cinta de latão
    gx, gy = pontos["punho_e"][0], pontos["punho_e"][1] - H
    nova("marreta", segment("Cabo da marreta", P(gx, gy, .02), P(gx, gy, 3.18), .095, .095, M["Cabo de madeira"], 8))
    nova("marreta", box("Topo do cabo", P(gx, gy, .05), (.15, .15, .10), M["Elmo de ferro"], .02))
    nova("marreta", box("Cabeça da marreta", P(gx, gy, 3.12), (.92, .66, .68), M["Cabeça da marreta"], .09))
    nova("marreta", box("Cinta da marreta", P(gx, gy, 3.12), (.18, .72, .74), M["Latão antigo"], .02))
    return pecas, osso_de, pontos, H
