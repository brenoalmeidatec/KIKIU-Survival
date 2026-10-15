"""Modelo do Lucas (Blender 4.5), construído por script a partir da referência do Codex (../../referencia_herois/lucas.png: frente, lado, costas).

`construir(ns)` recebe o namespace das funções do estudo do Codex (box, ico, segment, mesh, line, mat: ../codex_estudo/criar_estudo.py, só a parte
de funções) e devolve `(objetos, OSSO_DE, PONTOS)`: todas as peças, o osso de cada peça e a posição das articulações no mundo do modelo.
Coordenadas: x = direita da tela, y = para TRÁS (a frente do herói é -y), z = para cima; o herói tem ~3,2 de altura (o gerar.py escala 0,55).

Peças (da referência): capuz roxo pontudo (casca aberta na frente, o rosto aparece), cabelo preto na testa e nas têmporas, lenço dourado (gola grossa e duas
pontas compridas nas costas, que aparecem dos dois lados do corpo), túnica roxa de manga curta com a barra em ponta, camisa escura por baixo, cinto de
couro com fivela, BANDOLEIRA diagonal com três adagas (cabo de osso, lâmina de aço para baixo; espelhada nas costas), uma adaga em cada quadril, braçadeiras de
couro, calça escura e botas altas de cano dobrado. A adaga da mão (cabo + lâmina) fica presa ao antebraço; `ossos.adaga` mostra ou esconde.
"""
import math

import bmesh
import bpy
from mathutils import Vector


def construir(ns):
    box, ico, segment, mesh, line, mat = ns["box"], ns["ico"], ns["segment"], ns["mesh"], ns["line"], ns["mat"]
    for m in list(bpy.data.materials):       # os materiais do estudo do Codex têm os mesmos nomes (Aço azulado...): saem, os daqui entram
        bpy.data.materials.remove(m)
    antes = set(bpy.data.objects)
    osso_de, pontos = {}, {}

    # ------------------------------------------------------------------ materiais (nomes = chaves de PALETA no gerar.py)
    M = {n: mat(n, (0.3, 0.3, 0.3)) for n in (
        "Roxo do capuz", "Roxo iluminado", "Roxo das dobras", "Lenço dourado", "Lenço verso", "Camisa escura", "Calça escura",
        "Couro castanho", "Couro claro", "Pele", "Rosto iluminado", "Cabelo quase preto", "Osso do cabo", "Aço azulado", "Fio polido",
        "Latão antigo", "Olho")}

    def reg(o, osso):
        osso_de[o] = osso
        return o

    def prisma(nome, pts, esp, material, osso):
        """Faixa de tecido com espessura (a casca do contorno precisa de volume): `pts` = contorno (x, y, z) da face da frente; a de trás fica `esp` mais para trás (+y)."""
        n = len(pts)
        v = [tuple(p) for p in pts] + [(p[0], p[1] + esp, p[2]) for p in pts]
        f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        o = mesh(nome, v, f, material)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(o.data)
        bm.free()
        return reg(o, osso)

    # ------------------------------------------------------------------ pernas, botas, braços e mãos (em repouso reto, com joelho e cotovelo)
    for lado, s in (("esquerda", -1), ("direita", 1)):
        sfx = "_e" if s < 0 else "_d"
        quadril, joelho, tornoz = (s * .17, 0, 1.55), (s * .18, .02, 1.02), (s * .18, .02, .52)
        reg(segment("Coxa " + lado, joelho, quadril, .165, .205, M["Calça escura"]), "perna" + sfx)
        reg(segment("Canela " + lado, tornoz, joelho, .135, .165, M["Calça escura"]), "canela" + sfx)
        reg(box("Bota " + lado, (s * .18, -.07, .37), (.32, .54, .34), M["Couro castanho"], .06), "pe" + sfx)
        reg(box("Cano da bota " + lado, (s * .18, .02, .59), (.38, .38, .09), M["Couro claro"], .03), "pe" + sfx)
        reg(box("Cinta da bota " + lado, (s * .18, -.08, .30), (.34, .20, .06), M["Couro claro"], .02), "pe" + sfx)
        ombro, cotov, punho = (s * .37, 0, 2.18), (s * .57, -.03, 1.75), (s * .61, -.14, 1.41)
        pontos.update({"quadril" + sfx: quadril, "joelho" + sfx: joelho, "tornozelo" + sfx: tornoz,
                       "ombro" + sfx: ombro, "cotovelo" + sfx: cotov, "punho" + sfx: punho})
        meio = tuple((a + b) * .5 + (b - a) * .0 for a, b in zip(ombro, cotov))
        reg(segment("Manga " + lado, ombro, meio, .20, .175, M["Roxo do capuz"] if s < 0 else M["Roxo iluminado"]), "braco" + sfx)
        reg(segment("Camisa do braço " + lado, meio, cotov, .165, .15, M["Camisa escura"]), "braco" + sfx)
        reg(segment("Antebraço " + lado, cotov, punho, .15, .125, M["Couro castanho"]), "antebraco" + sfx)
        reg(box("Braçadeira " + lado, tuple((a + b) * .5 + o for a, b, o in zip(cotov, punho, (0, -.03, .02))), (.27, .27, .34), M["Couro claro"], .035,
                (Vector(punho) - Vector(cotov)).normalized().to_track_quat("Z", "Y").to_euler()), "antebraco" + sfx)
        mao = Vector(punho) + Vector((0.02, -.04, -.09))
        reg(ico("Mão " + lado, tuple(mao), (.13, .13, .14), M["Couro castanho"] if s < 0 else M["Pele"], 2), "antebraco" + sfx)
        # ADAGA NA MÃO (cabo e lâmina; `ossos.adaga` mostra/esconde): cabo de osso para cima, lâmina para baixo e levemente para fora/frente
        d = Vector((.10 * s, -.10, -.99)).normalized()
        cabo_a, cabo_b = mao - d * .20, mao + d * .13
        reg(segment("Adaga na mão cabo " + sfx[1], tuple(cabo_a), tuple(cabo_b), .052, .052, M["Osso do cabo"], 6), "antebraco" + sfx)
        reg(segment("Adaga na mão guarda " + sfx[1], tuple(cabo_b - d * .02), tuple(cabo_b + d * .03), .13, .13, M["Latão antigo"], 6), "antebraco" + sfx)
        lam_a = cabo_b + d * .05
        reg(segment("Adaga na mão lâmina " + sfx[1], tuple(lam_a), tuple(lam_a + d * .50), .19, .13, M["Fio polido"], 4), "antebraco" + sfx)
        reg(segment("Adaga na mão ponta " + sfx[1], tuple(lam_a + d * .50), tuple(lam_a + d * .76), .13, .0, M["Fio polido"], 4), "antebraco" + sfx)

    # ------------------------------------------------------------------ tronco: túnica roxa (barra em ponta), camisa escura, cinto, lenço, bandoleira
    corpo = [(-.28, -.19, 1.52), (.28, -.19, 1.52), (.28, .18, 1.52), (-.28, .18, 1.52),
             (-.40, -.21, 2.30), (.40, -.21, 2.30), (.40, .19, 2.30), (-.40, .19, 2.30)]
    reg(mesh("Túnica", corpo, [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7), (0, 3, 2, 1)], M["Roxo do capuz"]), "torso")
    reg(prisma("Barra da frente", [(-.30, -.20, 1.70), (.30, -.20, 1.70), (.27, -.21, 1.52), (.0, -.22, 1.30), (-.27, -.21, 1.52)], .04, M["Roxo iluminado"], "torso"), "torso")
    reg(prisma("Barra de trás", [(-.30, .19, 1.70), (.30, .19, 1.70), (.27, .20, 1.52), (.0, .21, 1.32), (-.27, .20, 1.52)], .04, M["Roxo das dobras"], "torso"), "torso")
    reg(box("Cinto", (0, -.01, 1.72), (.64, .46, .14), M["Couro castanho"], .025), "torso")
    reg(box("Fivela", (0, -.245, 1.72), (.14, .035, .11), M["Latão antigo"], .012), "torso")
    # lenço: gola grossa, ombros, e as duas pontas compridas nas costas (aparecem dos dois lados do corpo)
    reg(segment("Gola do lenço", (0, 0, 2.30), (0, 0, 2.54), .30, .25, M["Lenço dourado"], 10), "torso")
    for s in (-1, 1):
        reg(ico("Ombro do lenço", (s * .25, -.02, 2.36), (.20, .21, .11), M["Lenço dourado"], 2), "torso")
    reg(prisma("Lenço frente", [(-.24, -.25, 2.46), (.24, -.25, 2.46), (.14, -.26, 2.24), (-.14, -.26, 2.24)], .05, M["Lenço dourado"], "torso"), "torso")
    # a ponta comprida (até o joelho) cai do lado esquerdo da tela e uma curta do direito, como na referência
    reg(prisma("Ponta do lenço esquerda", [(-.50, .20, 2.38), (-.26, .22, 2.42), (-.28, .25, 1.30), (-.36, .26, 1.04), (-.44, .25, 1.20), (-.52, .24, 1.12),
                                          (-.54, .23, 1.40)], .06, M["Lenço dourado"], "torso"), "torso")
    reg(prisma("Ponta do lenço direita", [(.26, .22, 2.42), (.50, .20, 2.38), (.52, .25, 1.62), (.44, .26, 1.46), (.36, .25, 1.58)], .06, M["Lenço verso"], "torso"), "torso")

    def adaga_corpo(nome, topo, d, osso, y_face=-1.0, comp=0.30):
        """Adaga de bandoleira/cinto: cabo de osso (em `topo`), guarda e lâmina de aço para baixo (direção d)."""
        d = Vector(d).normalized()
        t = Vector(topo)
        reg(segment(nome + " cabo", tuple(t), tuple(t + d * .17), .05, .05, M["Osso do cabo"], 6), osso)
        reg(segment(nome + " lâmina", tuple(t + d * .17), tuple(t + d * (.17 + comp)), .085, .06, M["Aço azulado"], 4), osso)
        reg(segment(nome + " ponta", tuple(t + d * (.17 + comp)), tuple(t + d * (.17 + comp + .12)), .06, .0, M["Aço azulado"], 4), osso)

    for nome, y, sx in (("frente", -.235, 1), ("costas", .225, -1)):
        a, b = Vector((-.30 * sx, y, 2.28)), Vector((.31 * sx, y, 1.76))
        reg(segment("Bandoleira " + nome, tuple(a), tuple(b), .05, .05, M["Couro castanho"], 6), "torso")
        for i, t in enumerate((.22, .50, .78)):
            p = a + (b - a) * t
            adaga_corpo("Adaga %s %d" % (nome, i), tuple(p + Vector((0, y / abs(y) * .03, .0))), (.06 * sx, 0, -1), "torso", comp=.26 if i else .22)
    # adagas nos quadris (a da esquerda da tela com a lâmina para baixo, a da direita só com o cabo aparecendo)
    adaga_corpo("Adaga do quadril esquerdo", (-.38, -.03, 1.74), (-.08, 0, -1), "quadril", comp=.28)
    adaga_corpo("Adaga do quadril direito", (.38, .02, 1.74), (.08, 0, -1), "quadril", comp=.20)

    # ------------------------------------------------------------------ cabeça: rosto, cabelo, capuz (casca aberta na frente) com a ponta para cima e para trás
    reg(ico("Cabeça facetada", (0, -.02, 2.72), (.235, .25, .35), M["Rosto iluminado"], 2), "cabeca")
    reg(ico("Cabelo da testa", (0, -.14, 3.04), (.17, .07, .045), M["Cabelo quase preto"], 2), "cabeca")
    for s in (-1, 1):
        reg(box("Olho " + ("esquerdo" if s < 0 else "direito"), (s * .082, -.258, 2.725), (.068, .025, .046), M["Olho"], .007), "cabeca")
    reg(ico("Nariz", (0, -.276, 2.665), (.038, .05, .06), M["Pele"], 1), "cabeca")
    # capuz: esfera achatada sem a frente (abertura do rosto) e sem a base (o lenço cobre o pescoço)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=(0, .07, 2.80))
    capuz = bpy.context.object
    capuz.name = "Capuz"
    capuz.scale = (.405, .385, .42)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    capuz.data.materials.append(M["Roxo do capuz"])
    bm = bmesh.new()
    bm.from_mesh(capuz.data)
    apagar = []
    for f in bm.faces:
        c = f.calc_center_median()
        frente = f.normal.y < -.30 and c.z < 3.05 and abs(c.x) < .30
        if frente or c.z < 2.50:
            apagar.append(f)
    bmesh.ops.delete(bm, geom=apagar, context="FACES")
    bm.to_mesh(capuz.data)
    bm.free()
    reg(capuz, "cabeca")
    # forro: o interior do capuz, escuro, atrás do rosto (só a metade de trás da elipse), dá a sombra interna e emoldura o rosto estreito
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=(0, .06, 2.80))
    forro = bpy.context.object
    forro.name = "Forro do capuz"
    forro.scale = (.36, .34, .40)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    forro.data.materials.append(M["Roxo das dobras"])
    bm = bmesh.new()
    bm.from_mesh(forro.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < .02 or f.calc_center_median().z < 2.52], context="FACES")
    bm.to_mesh(forro.data)
    bm.free()
    reg(forro, "cabeca")
    reg(segment("Ponta do capuz", (0, .12, 3.06), (0, .44, 3.24), .14, .0, M["Roxo do capuz"], 6), "cabeca")
    reg(segment("Dobra do capuz", (0, .05, 3.00), (0, .20, 3.12), .30, .22, M["Roxo das dobras"], 6), "cabeca")

    novos = [o for o in bpy.data.objects if o not in antes]
    return novos, osso_de, pontos
