"""Modelo do LOBO do LightWolf (Blender 4.5), por script, no rig do Lucas (../lucas/): mesmos ossos, mesmas pecas-ancora e a mesma interface `construir(ns)`.

Referencia: notas/artes_chatgpt/A16_lightwolf_lobo_ref.png (3 vistas). A referencia e uma loba ANTROPOMORFICA (anda em duas pernas), entao o rig humanoide serve:
cabeca de lobo (focinho, nariz escuro, orelhas pontudas, olhos ciano, juba branca), macacao azul com ombreiras brancas e gola de pelo, luvas escuras, joelheiras e
botas brancas grossas com listra ciano, cauda grande e fofa atras e uma pistola de energia branca com ponta ciano em cada mao.

A pistola ocupa o lugar da adaga do Lucas (mesmos nomes "Adaga na mao cabo/guarda/lamina/ponta d|e", que o ossos.py e o gerar.py mostram/escondem por quadro):
as animacoes de arremesso viram "tiros" (o risco de luz sai pela ponta ciano).

Coordenadas e escala como no ../lucas/modelo.py: x = direita da tela, y = para TRAS (a frente e -y), z = para cima; ~3,2 de altura (gerar.py escala 0,55).
"""
import math

import bmesh
import bpy
from mathutils import Vector

MATERIAIS = (
    "Pelo", "Pelo sombra", "Orelha interna", "Nariz escuro", "Olho ciano",
    "Traje azul", "Traje claro", "Traje escuro", "Armadura branca", "Couro escuro", "Ciano brilho",
    "Arma branca", "Arma cabo",
)


def construir(ns):
    box, ico, segment, mesh, mat = ns["box"], ns["ico"], ns["segment"], ns["mesh"], ns["mat"]
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    antes = set(bpy.data.objects)
    osso_de, pontos = {}, {}
    M = {n: mat(n, (0.3, 0.3, 0.3)) for n in MATERIAIS}

    def reg(o, osso):
        osso_de[o] = osso
        return o

    # ------------------------------------------------------------------ pernas, botas, bracos, maos (repouso reto, com joelho e cotovelo)
    for lado, s in (("esquerda", -1), ("direita", 1)):
        sfx = "_e" if s < 0 else "_d"
        quadril, joelho, tornoz = (s * .17, 0, 1.55), (s * .18, .02, 1.02), (s * .18, .02, .52)
        reg(segment("Coxa " + lado, joelho, quadril, .165, .205, M["Traje azul"]), "perna" + sfx)
        reg(segment("Canela " + lado, tornoz, joelho, .135, .165, M["Traje azul"]), "canela" + sfx)
        reg(ico("Joelheira " + lado, (s * .18, -.10, 1.02), (.13, .09, .15), M["Armadura branca"], 2), "canela" + sfx)
        reg(box("Bota " + lado, (s * .18, -.07, .37), (.34, .58, .36), M["Armadura branca"], .07), "pe" + sfx)
        reg(box("Cano da bota " + lado, (s * .18, .02, .62), (.38, .38, .16), M["Armadura branca"], .05), "pe" + sfx)
        reg(box("Listra da bota " + lado, (s * .18, -.10, .20), (.36, .50, .07), M["Ciano brilho"], .02), "pe" + sfx)
        ombro, cotov, punho = (s * .37, 0, 2.18), (s * .57, -.03, 1.75), (s * .61, -.14, 1.41)
        pontos.update({"quadril" + sfx: quadril, "joelho" + sfx: joelho, "tornozelo" + sfx: tornoz,
                       "ombro" + sfx: ombro, "cotovelo" + sfx: cotov, "punho" + sfx: punho})
        meio = tuple((a + b) * .5 for a, b in zip(ombro, cotov))
        reg(segment("Manga " + lado, ombro, meio, .20, .175, M["Traje claro"]), "braco" + sfx)
        reg(box("Ombreira " + lado, (s * .43, -.01, 2.30), (.30, .36, .17), M["Armadura branca"], .05), "braco" + sfx)
        reg(segment("Camisa do braco " + lado, meio, cotov, .17, .15, M["Traje azul"]), "braco" + sfx)
        reg(segment("Antebraco " + lado, cotov, punho, .15, .125, M["Pelo"]), "antebraco" + sfx)
        reg(box("Braçadeira " + lado, tuple((a + b) * .5 + o for a, b, o in zip(cotov, punho, (0, -.03, .10))), (.27, .27, .16), M["Couro escuro"], .03,
                (Vector(punho) - Vector(cotov)).normalized().to_track_quat("Z", "Y").to_euler()), "antebraco" + sfx)
        mao = Vector(punho) + Vector((0.02, -.04, -.09))
        reg(ico("Mão " + lado, tuple(mao), (.135, .135, .145), M["Couro escuro"], 2), "antebraco" + sfx)
        # PISTOLA NA MAO (nomes = os da adaga do Lucas): cabo escuro, corpo branco grosso, cano branco, ponta ciano; longa e vertical, apontada para baixo
        d = Vector((.10 * s, -.10, -.99)).normalized()
        cabo_a, cabo_b = mao - d * .20, mao + d * .13
        reg(segment("Adaga na mão cabo " + sfx[1], tuple(cabo_a), tuple(cabo_b), .060, .060, M["Arma cabo"], 6), "antebraco" + sfx)
        reg(segment("Adaga na mão guarda " + sfx[1], tuple(cabo_b - d * .03), tuple(cabo_b + d * .26), .17, .17, M["Arma branca"], 6), "antebraco" + sfx)
        lam_a = cabo_b + d * .26
        reg(segment("Adaga na mão lâmina " + sfx[1], tuple(lam_a), tuple(lam_a + d * .28), .12, .10, M["Arma branca"], 6), "antebraco" + sfx)
        reg(segment("Adaga na mão ponta " + sfx[1], tuple(lam_a + d * .28), tuple(lam_a + d * .46), .10, .07, M["Ciano brilho"], 6), "antebraco" + sfx)

    # ------------------------------------------------------------------ tronco: macacao azul, jaqueta curta, cinto, gola de pelo, triangulo ciano no peito
    corpo = [(-.28, -.19, 1.52), (.28, -.19, 1.52), (.28, .18, 1.52), (-.28, .18, 1.52),
             (-.40, -.21, 2.30), (.40, -.21, 2.30), (.40, .19, 2.30), (-.40, .19, 2.30)]
    reg(mesh("Macacão", corpo, [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7), (0, 3, 2, 1)], M["Traje azul"]), "torso")
    reg(box("Jaqueta da frente", (0, -.215, 2.02), (.78, .06, .46), M["Traje claro"], .02), "torso")
    reg(box("Jaqueta de trás", (0, .205, 2.02), (.78, .06, .46), M["Traje claro"], .02), "torso")
    reg(box("Listra do peito", (-.14, -.25, 1.85), (.06, .04, .60), M["Armadura branca"], .01), "torso")
    reg(box("Listra do peito d", (.14, -.25, 1.85), (.06, .04, .60), M["Armadura branca"], .01), "torso")
    reg(box("Quadril do traje", (0, 0, 1.46), (.64, .44, .26), M["Traje azul"], .04), "quadril")
    reg(box("Cinto", (0, -.01, 1.66), (.66, .46, .13), M["Couro escuro"], .025), "torso")
    reg(box("Fivela", (0, -.245, 1.66), (.14, .035, .10), M["Armadura branca"], .012), "torso")
    reg(box("Triângulo ciano", (0, -.262, 2.18), (.12, .03, .10), M["Ciano brilho"], .01), "torso")
    reg(segment("Gola de pelo", (0, 0, 2.28), (0, 0, 2.54), .31, .27, M["Pelo"], 10), "torso")
    for s in (-1, 1):
        reg(ico("Gola lateral", (s * .22, -.02, 2.40), (.17, .20, .12), M["Pelo"], 2), "torso")

    # ------------------------------------------------------------------ cauda grande e fofa, atras (cai do quadril e vira para a direita da tela)
    reg(segment("Cauda 1", (.04, .20, 1.62), (.08, .50, 1.30), .17, .27, M["Pelo"], 8), "quadril")
    reg(segment("Cauda 2", (.08, .50, 1.30), (.17, .62, .82), .27, .25, M["Pelo"], 8), "quadril")
    reg(segment("Cauda 3", (.17, .62, .82), (.30, .52, .42), .25, .0, M["Pelo"], 8), "quadril")
    reg(ico("Cauda tufo", (.02, .46, 1.30), (.17, .15, .25), M["Pelo sombra"], 2), "quadril")

    # ------------------------------------------------------------------ cabeca de lobo: rosto de pelo, focinho, nariz, olhos ciano, orelhas e juba
    reg(ico("Cabeça de lobo", (0, -.02, 2.72), (.30, .27, .34), M["Pelo"], 2), "cabeca")
    reg(ico("Focinho", (0, -.30, 2.62), (.115, .19, .105), M["Pelo"], 2), "cabeca")
    reg(ico("Nariz do lobo", (0, -.47, 2.655), (.058, .05, .045), M["Nariz escuro"], 1), "cabeca")
    reg(ico("Cabelo de trás", (0, .20, 2.86), (.30, .17, .24), M["Pelo"], 2), "cabeca")
    reg(ico("Cabelo da nuca", (0, .24, 2.58), (.28, .15, .20), M["Pelo sombra"], 2), "cabeca")
    # (as pecas de segmento por ultimo: o gerar.py do Luke mexe no ultimo objeto criado ao montar o armature)
    for s in (-1, 1):
        reg(ico("Cabelo lateral " + ("esquerdo" if s < 0 else "direito"), (s * .30, .02, 2.80), (.13, .20, .22), M["Pelo"], 2), "cabeca")
    for s in (-1, 1):
        n = "esquerdo" if s < 0 else "direito"
        reg(box("Olho " + n, (s * .115, -.262, 2.745), (.075, .025, .052), M["Olho ciano"], .007), "cabeca")
        reg(segment("Orelha " + n, (s * .21, .02, 2.92), (s * .31, .05, 3.20), .20, .0, M["Pelo"], 5), "cabeca")
        reg(segment("Orelha interna " + n, (s * .21, -.04, 2.96), (s * .30, .01, 3.10), .12, .0, M["Orelha interna"], 5), "cabeca")

    novos = [o for o in bpy.data.objects if o not in antes]
    return novos, osso_de, pontos
