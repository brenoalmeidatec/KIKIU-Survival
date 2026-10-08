"""Sala da loja do K.I.K.I.U (empório de mercador sombrio): piso de tábuas, parede de pedra com vigas, tapete, balcão e objetos.

Roda (Blender 4.5 LTS):
    blender -b -P loja.py                 # tudo
    blender -b -P loja.py -- parede balcao   # só essas peças (as outras vêm do cache; ver CACHE)
Saída em ../../projeto/assets/cenarios/loja/:
    piso.png      azulejo 256x256 de tábuas (repete sem emenda)
    parede.png    a parede dos fundos inteira, 640x112 (pedra, vigas, lareira, prateleiras, tapeçaria, janela, lanternas)
    objetos.png   atlas dos objetos em 3/4 (balcão, barris, baú, caldeirão, mesa, tapete, porta...)
    cenario.json  onde cada peça fica na tela de 640x360 (o layout mora AQUI), obstáculos, luzes, emissores de partículas

Mesma técnica dos outros cenários (cenarios.py): render "pré-renderizado" no Cycles em 4x, média, paleta fixa dark fantasy.
A luz forte (velas, lareira, lanternas, luar) é só desenhada no jogo (scripts/hordas/loja.gd): mapa de luz + halos ADD que tremulam.
Não importa o cenarios.py (ele roda main() ao ser importado).
"""
import json
import math
import os
import random
import sys
import tempfile

import bpy
import numpy as np

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pixel3d as px3  # noqa: E402
from pixel3d import caixa, cilindro, cone, esfera  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "cenarios", "loja"))
CACHE = os.path.join(tempfile.gettempdir(), "loja_cache")
PX = 60.0 / 2.55        # pixels por unidade do Blender (a mesma do resto do jogo)
FATOR = 4
W, H = 640, 360
PAREDE_H = 112
PISO = 256
L = PISO / PX

# ------------------------------------------------------------------ paleta (rampas do jogo + madeira escura e pedra fria)
_MADEIRA = ["120c09", "1c120d", "2a1b14", "3a271b", "4a3022", "5d3f29", "745034", "8f6a45", "ad8556"]
_FRIO = ["1a1d2a", "2a3042", "3b4560", "55627f"]
_TECIDO = ["3a0c14", "5c1420", "7e2027", "a52a2e"]
_EXTRA = _MADEIRA + _FRIO + _TECIDO
PAL_PISO = np.vstack([px3.paleta_de("couro"), np.array([px3._rgb(h) for h in _MADEIRA])])
PAL = np.vstack([px3.paleta_de("pedra", "couro", "fogo", "veneno", "sangue", "ouro", "osso", "musgo", "noite", "aco", "cobalto", "caos", "folha"),
                 np.array([px3._rgb(h) for h in _EXTRA])])


# ------------------------------------------------------------------ materiais (Cycles)
def S(hexa, rug=0.85, relevo=0.0, var=0.0, esc=3.0):
    return px3.material_suave("s_" + hexa, px3.cor(hexa), rug, relevo, var, esc)


def E(hexa, forca=1.0):
    return px3.material_emissao("e_" + hexa, px3.cor(hexa), forca)


def madeira(hexa, grao=0.35, esc=(0.5, 7.0, 0.8), relevo=0.5, rug=0.75, desloca=(0, 0, 0)):
    """Madeira com veios: ruído esticado ao longo do eixo X (cor e relevo)."""
    m = bpy.data.materials.new("mad_" + hexa)
    m.use_nodes = True
    n = m.node_tree.nodes
    ln = m.node_tree.links
    p = n.get("Principled BSDF")
    p.inputs["Roughness"].default_value = rug
    coord = n.new("ShaderNodeTexCoord")
    mapa = n.new("ShaderNodeMapping")
    mapa.inputs["Scale"].default_value = esc
    mapa.inputs["Location"].default_value = desloca
    ruido = n.new("ShaderNodeTexNoise")
    ruido.inputs["Scale"].default_value = 2.2
    ruido.inputs["Detail"].default_value = 5.0
    ln.new(coord.outputs["Object"], mapa.inputs["Vector"])
    ln.new(mapa.outputs["Vector"], ruido.inputs["Vector"])
    bump = n.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = relevo
    ln.new(ruido.outputs["Fac"], bump.inputs["Height"])
    ln.new(bump.outputs["Normal"], p.inputs["Normal"])
    mix = n.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    rampa = n.new("ShaderNodeMapRange")
    rampa.inputs["To Min"].default_value = 1.0 - grao
    rampa.inputs["To Max"].default_value = 1.0 + grao * 0.6
    ln.new(ruido.outputs["Fac"], rampa.inputs["Value"])
    mix.inputs[0].default_value = 1.0
    mix.inputs[6].default_value = px3.cor(hexa)
    comb = n.new("ShaderNodeCombineColor")
    for k in range(3):
        ln.new(rampa.outputs["Result"], comb.inputs[k])
    ln.new(comb.outputs[0], mix.inputs[7])
    ln.new(mix.outputs[2], p.inputs["Base Color"])
    return m


def metal(hexa, rug=0.45):
    m = px3.material_suave("m_" + hexa, px3.cor(hexa), rug)
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Metallic"].default_value = 0.6
    return m


# ------------------------------------------------------------------ câmeras e luzes
def cam_topo(w, h, cx, cy):
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = max(w, h) / PX
    o = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(o)
    o.location = (cx, cy, 30.0)
    o.rotation_euler = (0, 0, 0)
    bpy.context.scene.camera = o
    return o


def cam_frente(w, h, cx, cz):
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = max(w, h) / PX
    o = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(o)
    o.location = (cx, -30.0, cz)
    o.rotation_euler = (math.pi / 2, 0, 0)
    bpy.context.scene.camera = o
    return o


def sol(nome, direcao, forca, cor=(1, 1, 1), angulo=5.0):
    from mathutils import Vector
    d = bpy.data.lights.new(nome, "SUN")
    d.energy = forca
    d.color = cor
    d.angle = math.radians(angulo)
    o = bpy.data.objects.new(nome, d)
    bpy.context.collection.objects.link(o)
    o.rotation_euler = Vector(direcao).normalized().to_track_quat("-Z", "Y").to_euler()


def luz_objeto():
    """Luz quente de frente, de cima e da esquerda; borda fria de trás. Sombra suave (o chão não existe: a sombra no chão é do jogo)."""
    sol("quente", (0.55, 0.6, -0.8), 4.6, (1.0, 0.86, 0.68))
    sol("frio", (-0.5, -0.4, -0.5), 0.9, (0.55, 0.65, 1.0))


def luz_parede():
    sol("quente", (0.5, 0.75, -0.55), 4.8, (1.0, 0.84, 0.64))


def luz_piso():
    sol("rasante", (0.9, -0.5, -0.8), 4.2, (1.0, 0.86, 0.68))


def preparar(w, h, amostras=36, ceu=0.7):
    px3.limpar_cena()
    cena = px3.preparar_suave(w, h, FATOR, amostras)
    cena.world.node_tree.nodes.get("Background").inputs[1].default_value = ceu   # preenchimento do céu (mais forte que o padrão: o jogo escurece depois)
    return cena


def renderizar(w, h, pontilhado=0.0, contorno=True, luz_borda=True, opaco=False, paleta=None):
    bruto = px3.reduzir(px3.render_rgba(), FATOR)
    img = px3.pixelar(bruto, contorno=contorno, paleta=PAL if paleta is None else paleta, luz_borda=luz_borda, pontilhado=pontilhado)
    if opaco:
        img[:, :, 3] = 1.0
    return img


# ================================================================ piso: tábuas de madeira
TONS_PISO = ["5d3f29", "6a4a30", "745034", "4e3524", "654530"]


def piso(r):
    caixa("rejunte", (L, L, 0.1), (L / 2, L / 2, -0.05), S("120c09"))
    n = 16
    c = L / n
    mats = [[madeira(t, grao=0.55, relevo=1.2, esc=(0.45, 9.0, 0.8), desloca=(r.uniform(0, 9), r.uniform(0, 9), r.uniform(0, 9))) for _ in range(2)] for t in TONS_PISO]
    for j in range(n):
        # emendas desta fileira: posições aleatórias; a tábua que cruza a borda do azulejo continua no vizinho (sem emenda visível)
        cortes = []
        x = r.uniform(0.5, 3.0)
        while x < L - 0.6:
            cortes.append(x)
            x += r.uniform(2.6, 5.0)
        if cortes and L - cortes[-1] < 1.0:
            cortes.pop()
        pontos = [0.0] + cortes + [L]
        for i in range(len(pontos) - 1):
            x0, x1 = pontos[i], pontos[i + 1]
            folga0 = 0.035 if i > 0 else 0.0
            folga1 = 0.035 if i < len(pontos) - 2 else 0.0
            tom = r.randrange(len(TONS_PISO))
            alt = 0.1 + r.random() * 0.03
            caixa("tabua", (x1 - x0 - folga0 - folga1, c - 0.05, alt), ((x0 + x1) / 2 + (folga0 - folga1) / 2, j * c + c / 2, alt / 2),
                  mats[tom][r.randrange(2)], chanfro=0.025)
            for ex in ((x0 + 0.18) if i > 0 else None, (x1 - 0.18) if i < len(pontos) - 2 else None):
                if ex is not None:
                    for dy in (-0.16, 0.16):
                        cilindro("prego", 0.028, 0.02, (ex, j * c + c / 2 + dy, alt + 0.005), S("1d1a2b"), vertices=6)


def repetir_3x3():
    originais = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            for o in originais:
                cp = o.copy()
                cp.location = (o.location.x + dx * L, o.location.y + dy * L, o.location.z)
                bpy.context.collection.objects.link(cp)


def gerar_piso():
    r = random.Random("loja_piso")
    preparar(PISO, PISO)
    cam_topo(PISO, PISO, L / 2, L / 2)
    luz_piso()
    piso(r)
    repetir_3x3()
    img = renderizar(PISO, PISO, pontilhado=0.04, contorno=False, luz_borda=False, opaco=True, paleta=PAL_PISO)
    return {"img": veios(img, random.Random("veios"))}


def _mais_escuro(rgb, f):
    alvo = rgb * f
    d = ((PAL_PISO - alvo) ** 2).sum(axis=1)
    return PAL_PISO[d.argmin()]


def veios(img, r):
    """Veios da madeira desenhados por cima (traços de 1 px ao longo da tábua, um degrau mais escuros; nós de vez em quando). Repete sem emenda (índices em módulo)."""
    n = 16
    c = PISO // n
    out = img.copy()
    for j in range(n):
        for _ in range(r.randint(3, 5)):
            y = j * c + r.randint(3, c - 4)
            x0, comp = r.randrange(PISO), r.randint(14, 70)
            f = r.choice([0.8, 0.86, 0.9])
            for dx in range(comp):
                x = (x0 + dx) % PISO
                if r.random() < 0.9:
                    out[y, x, :3] = _mais_escuro(out[y, x, :3], f)
                if r.random() < 0.06:
                    y = min(max(y + r.choice([-1, 1]), j * c + 2), j * c + c - 3)
        if r.random() < 0.5:   # nó
            nx, ny = r.randrange(PISO), j * c + r.randint(5, c - 6)
            for dx, dy, f in ((0, 0, 0.7), (1, 0, 0.7), (-1, 0, 0.8), (0, 1, 0.8), (0, -1, 0.8), (2, 0, 0.88), (-2, 0, 0.88)):
                out[(ny + dy) % PISO, (nx + dx) % PISO, :3] = _mais_escuro(out[(ny + dy) % PISO, (nx + dx) % PISO, :3], f)
    return out


# ================================================================ parede dos fundos (vista de frente, 640x112)
def X(p):
    return p / PX


def Z(p):
    return (PAREDE_H - p) / PX


def cx_(nome, x0, y0, x1, y1, mat, frente=0.0, prof=0.2, chanfro=0.0, rot=(0, 0, 0)):
    """Caixa na parede a partir de um retângulo em pixels (x0,y0)-(x1,y1) (y pra baixo); 'frente' = quanto sai do plano da parede (+ = pra câmera)."""
    return caixa(nome, ((x1 - x0) / PX, prof, (y1 - y0) / PX), (X((x0 + x1) / 2), -frente + prof / 2, Z((y0 + y1) / 2)), mat, chanfro=chanfro, rot=rot)


def garrafa(x, y_base, hexa, r, forma=0):
    """Frasco de poção em pé numa prateleira: corpo que brilha (emissão), gargalo, rolha e um reflexo. x e y_base em px da parede."""
    z0 = Z(y_base)
    xw = X(x)
    ra, al = (0.15 + 0.03 * forma, 0.34 + 0.08 * (r.random())) if forma < 2 else (0.1, 0.5)
    esfera("frasco", ra, (xw, -0.45, z0 + ra), E(hexa, 1.0), escala=(1, 0.8, 1.0 if forma != 1 else 1.15))
    cilindro("gargalo", 0.055, al, (xw, -0.45, z0 + ra * 1.7 + al / 2 - 0.05), S("2a3042", 0.3), vertices=8)
    cilindro("rolha", 0.065, 0.07, (xw, -0.45, z0 + ra * 1.7 + al - 0.02), S("8f6a45"), vertices=8)
    caixa("reflexo", (0.03, 0.02, 0.1), (xw - ra * 0.45, -0.62, z0 + ra * 1.15), E("ece8f2", 1.4))


def livro(x, y_base, r, inclinado=False):
    cor = r.choice(["7e2027", "35473a", "8f6a2e", "223566", "5d3f29", "4f1520", "3d1046"])
    h = r.uniform(0.4, 0.62)
    w = r.uniform(0.09, 0.15)
    caixa("livro", (w, 0.34, h), (X(x), -0.45, Z(y_base) + h / 2), S(cor, 0.8, 0.3, 0.2), rot=(0, 0.28 if inclinado else 0, 0))
    caixa("lombo", (w + 0.005, 0.02, 0.05), (X(x), -0.63, Z(y_base) + h * 0.7), S("c49a45"))


def cranio(x, y_base, escala=1.0):
    z0 = Z(y_base)
    xw = X(x)
    osso = S("d6ccb2", 0.8, 0.4, 0.2)
    esfera("cranio", 0.19 * escala, (xw, -0.45, z0 + 0.2 * escala), osso, escala=(1, 0.95, 1.05))
    caixa("mandibula", (0.17 * escala, 0.14, 0.09 * escala), (xw, -0.5, z0 + 0.06 * escala), osso)
    for sx in (-0.07, 0.07):
        esfera("olho", 0.05 * escala, (xw + sx * escala, -0.62, z0 + 0.22 * escala), S("0d0b14"))


def pergaminho(x, y_base, r):
    z0 = Z(y_base)
    cilindro("rolo", 0.08, 0.5, (X(x), -0.45, z0 + 0.1), S("d6ccb2", 0.9), rot=(0, math.pi / 2, 0), vertices=10)
    caixa("fita", (0.04, 0.17, 0.17), (X(x), -0.45, z0 + 0.1), S("7e2027"))


def prateleira(x0, x1, y, r, itens, frente=0.62):
    """Prancha de madeira em y (px) com mísulas, e os itens em cima (lista de ('garrafa', hexa) | 'livros' | 'cranio' | 'pergaminho' | 'pote')."""
    cx_("prancha", x0, y, x1, y + 4, madeira("5d3f29", relevo=0.4), frente=frente, prof=0.6, chanfro=0.02)
    cx_("friso", x0, y + 4, x1, y + 6, madeira("3a271b", relevo=0.3), frente=frente - 0.02, prof=0.5)
    for xm in (x0 + 6, x1 - 8):
        cx_("misula", xm, y + 4, xm + 3, y + 14, madeira("3a271b"), frente=0.4, prof=0.34)
        cx_("misula_d", xm - 1, y + 12, xm + 4, y + 15, madeira("3a271b"), frente=0.4, prof=0.34)
    x = x0 + 8
    for it in itens:
        if isinstance(it, tuple) and it[0] == "garrafa":
            garrafa(x, y, it[1], r, it[2] if len(it) > 2 else 0)
            x += 11
        elif it == "livros":
            for k in range(r.randint(3, 5)):
                livro(x, y, r, inclinado=(k == 0 and r.random() < 0.4))
                x += 5
            x += 3
        elif it == "cranio":
            cranio(x + 5, y)
            x += 14
        elif it == "pergaminho":
            pergaminho(x + 6, y, r)
            x += 15
        elif it == "pote":
            z0 = Z(y)
            cilindro("pote", 0.2, 0.34, (X(x + 5), -0.45, z0 + 0.17), S("6e4c32", 0.7, 0.4, 0.2), vertices=12)
            cilindro("boca", 0.15, 0.06, (X(x + 5), -0.45, z0 + 0.36), S("2a1b14"), vertices=12)
            x += 13
        elif it == "vela":
            vela_parede(x + 3, y, r)
            x += 9
        if x > x1 - 6:
            break


def vela_parede(x, y_base, r, alta=1.0):
    z0 = Z(y_base)
    cilindro("cera", 0.07, 0.3 * alta, (X(x), -0.45, z0 + 0.15 * alta), S("d6ccb2", 0.9), vertices=8)
    cone("chama", 0.06, 0.0, 0.2, (X(x), -0.45, z0 + 0.3 * alta + 0.1), E("ffb347", 2.0), vertices=6)
    cone("miolo", 0.03, 0.0, 0.12, (X(x), -0.47, z0 + 0.3 * alta + 0.07), E("fff2b0", 3.0), vertices=6)


def lareira(r):
    pedra = [S(h, 0.9, 0.9, 0.3, 4.0) for h in ("5e544a", "4a423b", "766a5d", "3a3430")]
    # volta (chaminé) subindo até o teto
    cx_("chamine", 52, 0, 114, 44, S("3a3430", 0.95, 0.9, 0.3), frente=0.35, prof=0.5)
    for i in range(4):
        for j in range(3):
            cx_("bloco", 52 + j * 21 + (i % 2) * 6, 3 + i * 11, 52 + j * 21 + 19 + (i % 2) * 6, 12 + i * 11, r.choice(pedra), frente=0.5, prof=0.1, chanfro=0.03)
    # moldura de pedra
    cx_("pilar_e", 40, 40, 52, 112, S("5e544a", 0.9, 0.9, 0.3), frente=0.5, prof=0.5, chanfro=0.04)
    cx_("pilar_d", 114, 40, 126, 112, S("5e544a", 0.9, 0.9, 0.3), frente=0.5, prof=0.5, chanfro=0.04)
    cx_("verga", 38, 40, 128, 52, S("766a5d", 0.9, 0.9, 0.3), frente=0.62, prof=0.55, chanfro=0.04)
    cx_("consolo", 34, 36, 132, 41, madeira("5d3f29", relevo=0.5), frente=0.72, prof=0.62, chanfro=0.03)
    # boca: fundo preto e brasas
    cx_("boca", 52, 52, 114, 104, S("0d0b14", 1.0), frente=0.0, prof=0.3)
    cx_("fundo_quente", 56, 62, 110, 104, E("7a2c0c", 0.9), frente=-0.05, prof=0.05)
    cx_("soleira", 44, 104, 122, 112, S("766a5d", 0.9, 0.7, 0.2), frente=0.8, prof=0.7, chanfro=0.04)
    # lenha e chamas
    for k, (xa, ya, rot) in enumerate(((66, 100, 0.12), (82, 101, -0.08), (98, 100, 0.1))):
        cilindro("lenha", 0.16, 1.1, (X(xa), -0.2, Z(ya)), madeira("3a271b", relevo=0.8), rot=(0, math.pi / 2 + rot, 0), vertices=8)
    cilindro("brasa", 0.5, 0.14, (X(83), -0.15, Z(100)), E("c45a14", 1.4), rot=(math.pi / 2, 0, 0), vertices=10)
    for (xa, hh, cor) in ((70, 1.3, "f0921e"), (83, 1.8, "ffb347"), (96, 1.2, "f0921e"), (77, 0.9, "ffd060"), (90, 1.0, "ffd060")):
        cone("chama", 0.3 if hh > 1.4 else 0.22, 0.0, hh, (X(xa), -0.2, Z(100) + hh / 2 + 0.05), E(cor, 2.0), vertices=7)
    cone("miolo", 0.14, 0.0, 0.8, (X(83), -0.28, Z(100) + 0.5), E("fff2b0", 3.0), vertices=6)
    # sobre o consolo: velas e um crânio
    vela_parede(46, 36, r, 0.8)
    cranio(83, 36, 0.8)
    garrafa(118, 36, "56b04a", r, 0)


def tapecaria(r):
    x0, x1, y0, y1 = 254, 388, 10, 80
    cx_("haste", x0 - 6, y0 - 4, x1 + 6, y0, S("c49a45", 0.4), frente=0.6, prof=0.12)
    for xa in (x0 - 8, x1 + 6):
        esfera("pomo", 0.12, (X(xa), -0.55, Z(y0 - 2)), S("eccb7a", 0.35))
    pano = S("7e2027", 0.95, 0.4, 0.25, 6.0)
    cx_("pano", x0, y0, x1, y1, pano, frente=0.42, prof=0.06)
    cx_("barra_e", x0, y0, x0 + 8, y1, S("4f1520", 0.95), frente=0.45, prof=0.04)
    cx_("barra_d", x1 - 8, y0, x1, y1, S("4f1520", 0.95), frente=0.45, prof=0.04)
    for ya in (y0 + 5, y1 - 9):
        cx_("fita", x0 + 8, ya, x1 - 8, ya + 3, S("c49a45", 0.5), frente=0.46, prof=0.03)
    # emblema: sol de ouro com olho
    cxm, cym = (x0 + x1) / 2, (y0 + y1) / 2
    cilindro("sol", 0.95, 0.04, (X(cxm), -0.42 - 0.05 + 0.02, Z(cym)), S("c49a45", 0.4), rot=(math.pi / 2, 0, 0), vertices=24)
    cilindro("sol_i", 0.7, 0.04, (X(cxm), -0.47 + 0.0, Z(cym)), S("5c1420", 0.9), rot=(math.pi / 2, 0, 0), vertices=24)
    for k in range(10):
        a = k * math.tau / 10
        caixa("raio", (0.12, 0.04, 0.5), (X(cxm) + math.cos(a) * 1.15, -0.5, Z(cym) + math.sin(a) * 1.15), S("c49a45", 0.4), rot=(0, a - math.pi / 2, 0))
    esfera("olho", 0.3, (X(cxm), -0.5, Z(cym)), S("eccb7a", 0.4), escala=(1.0, 0.2, 0.6))
    esfera("pupila", 0.12, (X(cxm), -0.56, Z(cym)), S("0d0b14"), escala=(1, 0.3, 1))
    for k in range(int((x1 - x0) / 6)):   # franjas na ponta
        cone("franja", 0.05, 0.0, 0.3, (X(x0 + 3 + k * 6), -0.45, Z(y1) - 0.12), S("c49a45", 0.5), vertices=4).rotation_euler = (math.pi, 0, 0)


def janela(r):
    x0, x1, y0, y1 = 442, 492, 14, 78
    pedra = S("766a5d", 0.9, 0.8, 0.3, 4.0)
    cx_("vao", x0, y0, x1, y1, E("2f4a86", 1.0), frente=0.1, prof=0.05)        # vidro (brilho de noite)
    # luar
    cilindro("lua", 0.62, 0.03, (X(468), -0.12, Z(34)), E("ece8f2", 1.8), rot=(math.pi / 2, 0, 0), vertices=18)
    cilindro("lua_sombra", 0.5, 0.03, (X(473), -0.14, Z(32)), E("2f4a86", 1.0), rot=(math.pi / 2, 0, 0), vertices=18)
    for (xa, ya) in ((452, 24), (484, 58), (456, 62), (478, 22)):
        esfera("estrela", 0.045, (X(xa), -0.13, Z(ya)), E("ece8f2", 2.5))
    # caixilho de chumbo
    cx_("trave_v", 465, y0, 469, y1, madeira("2a1b14"), frente=0.12, prof=0.1)
    cx_("trave_h", x0, 44, x1, 48, madeira("2a1b14"), frente=0.12, prof=0.1)
    # moldura de pedra
    cx_("m_e", x0 - 6, y0 - 6, x0, y1 + 4, pedra, frente=0.3, prof=0.4, chanfro=0.04)
    cx_("m_d", x1, y0 - 6, x1 + 6, y1 + 4, pedra, frente=0.3, prof=0.4, chanfro=0.04)
    cx_("m_c", x0 - 8, y0 - 10, x1 + 8, y0 - 4, pedra, frente=0.35, prof=0.45, chanfro=0.04)
    cx_("peitoril", x0 - 8, y1, x1 + 8, y1 + 6, pedra, frente=0.55, prof=0.6, chanfro=0.05)
    # cortina rasgada
    cx_("cortina_e", x0, y0 - 4, x0 + 9, y0 + 44, S("4f1520", 0.95, 0.4, 0.2), frente=0.4, prof=0.05)
    cx_("cortina_d", x1 - 9, y0 - 4, x1, y0 + 36, S("4f1520", 0.95, 0.4, 0.2), frente=0.4, prof=0.05)
    cx_("varao", x0 - 4, y0 - 4, x1 + 4, y0 - 2, S("45405c", 0.4), frente=0.45, prof=0.06)


def lampiao(x, y_topo, r):
    """Lampião pendurado de uma corrente (vem da viga)."""
    xw = X(x)
    cilindro("corrente", 0.03, (y_topo - 8) / PX, (xw, -0.4, Z((y_topo + 8) / 2)), S("2e2a40", 0.4), vertices=6)
    z0 = Z(y_topo + 18)
    cone("teto", 0.26, 0.05, 0.16, (xw, -0.4, z0 + 0.92), S("2e2a40", 0.4), vertices=8)
    cilindro("vidro", 0.2, 0.62, (xw, -0.4, z0 + 0.5), E("ffb347", 1.5), vertices=8)
    esfera("chama", 0.1, (xw, -0.4, z0 + 0.45), E("fff2b0", 3.0), escala=(1, 1, 1.5))
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        caixa("grade", (0.04, 0.04, 0.66), (xw + math.cos(ang) * 0.21, -0.4 + math.sin(ang) * 0.21, z0 + 0.5), S("2e2a40", 0.4))
    cilindro("base", 0.23, 0.06, (xw, -0.4, z0 + 0.15), S("2e2a40", 0.4), vertices=8)
    cone("ponta", 0.12, 0.0, 0.18, (xw, -0.4, z0 + 0.06), S("2e2a40", 0.4), vertices=8)


def castical_parede(x, y, r):
    """Suporte de ferro na parede com uma vela."""
    cx_("braco", x - 6, y + 2, x + 6, y + 4, S("2e2a40", 0.4), frente=0.5, prof=0.12)
    cx_("placa", x - 2, y - 6, x + 2, y + 8, S("2e2a40", 0.4), frente=0.1, prof=0.1)
    cilindro("prato", 0.14, 0.04, (X(x), -0.55, Z(y + 3)), S("c49a45", 0.4), vertices=10)
    vela_parede(x, y + 3, r, 0.9)


def ervas(x, y_topo, r):
    for k, dx in enumerate((-3, 3)):
        xw = X(x + dx)
        cilindro("cordao", 0.012, (6 + k * 3) / PX, (xw, -0.4, Z(y_topo + 3)), S("8f6a45"), vertices=4)
        for a in range(8):
            ang = a * math.tau / 8
            cone("folha", 0.06, 0.0, 0.5, (xw + math.cos(ang) * 0.1, -0.4 + math.sin(ang) * 0.06, Z(y_topo + 14 + k * 3) - 0.1), S(r.choice(["2d4721", "466a2c", "566e55", "6a943d"]), 0.9), vertices=4).rotation_euler = (math.pi + math.cos(ang) * 0.4, math.sin(ang) * 0.3, 0)
        cilindro("amarra", 0.06, 0.05, (xw, -0.4, Z(y_topo + 8 + k * 3)), S("7e2027"), vertices=6)


def parede(r):
    Wm = W / PX
    caixa("fundo", (Wm + 2, 0.6, PAREDE_H / PX + 1), (Wm / 2, 0.45, PAREDE_H / 2 / PX), S("120c09"))
    # pedras (fileiras de tamanhos variados, argamassa escura aparece nas juntas)
    pedras = [S(h, 0.95, 1.0, 0.28, 5.0) for h in ("4a423b", "544b42", "3a3430", "5e544a", "443c35", "4f4a46")]
    musgo = S("35473a", 1.0, 0.5, 0.2)
    y = 0.0
    fila = 0
    while y < PAREDE_H:
        alt = r.choice([12, 13, 14, 12])
        x = -r.uniform(0, 20)
        while x < W:
            larg = r.choice([22, 26, 30, 34, 38])
            cx_("pedra", max(x, 0) + 0.8, y + 0.8, min(x + larg, W) - 0.8, min(y + alt, PAREDE_H) - 0.8, r.choice(pedras), frente=0.0, prof=0.16 + r.random() * 0.1, chanfro=0.05)
            if r.random() < 0.07:
                cx_("musgo", max(x, 0) + 3, y + alt - 5, max(x, 0) + 3 + r.randint(8, 18), y + alt - 0.8, musgo, frente=0.1, prof=0.1)
            x += larg
        y += alt
        fila += 1
    # lambri de madeira embaixo (y 88 a 112) e rodapé
    for xa in range(0, W, 24):
        cx_("tabua_v", xa + 0.6, 90, xa + 23.4, 112, madeira("4a3022", grao=0.3, esc=(7, 0.6, 0.8), desloca=(r.uniform(0, 9), 0, 0)), frente=0.22, prof=0.18, chanfro=0.02)
    cx_("friso_lambri", 0, 86, W, 91, madeira("5d3f29", relevo=0.4), frente=0.34, prof=0.26, chanfro=0.03)
    cx_("rodape", 0, 105, W, 112, madeira("2a1b14", relevo=0.4), frente=0.4, prof=0.3, chanfro=0.03)
    # viga de cima e pilares de madeira (separam 3 vãos)
    viga = madeira("3a271b", grao=0.35, relevo=0.7)
    cx_("viga", 0, 0, W, 9, viga, frente=0.55, prof=0.55, chanfro=0.04)
    cx_("viga_baixo", 0, 9, W, 11, madeira("2a1b14"), frente=0.5, prof=0.4)
    for xp in (0, 210, 420, 628):
        cx_("pilar", xp, 0, xp + 12, 112, madeira("3a271b", grao=0.3, esc=(0.8, 0.6, 7.0), relevo=0.8), frente=0.5, prof=0.5, chanfro=0.04)
        for sgn, off in ((1, 12), (-1, -12)):
            if 4 < xp + off < W - 4:
                cx_("mao_francesa", xp + (12 if sgn > 0 else -16), 9, xp + (28 if sgn > 0 else -2), 24, madeira("2a1b14"), frente=0.45, prof=0.3, rot=(0, -0.7 * sgn, 0), chanfro=0.02)
    # peças
    lareira(r)
    prateleira(142, 206, 52, r, [("garrafa", "56b04a", 0), ("garrafa", "b0342f", 1), ("garrafa", "4073ff", 0), "pergaminho", ("garrafa", "e04aa8", 2)])
    prateleira(142, 206, 82, r, ["pote", "livros", "cranio", "pote"])
    ervas(150, 11, r)
    ervas(200, 11, r)
    tapecaria(r)
    castical_parede(238, 44, r)
    castical_parede(402, 44, r)
    janela(r)
    prateleira(506, 626, 44, r, [("garrafa", "f0921e", 0), ("garrafa", "56b04a", 1), ("garrafa", "e04aa8", 0), "cranio", ("garrafa", "4073ff", 1), "livros", ("garrafa", "b0342f", 0)])
    prateleira(506, 626, 76, r, ["livros", "pergaminho", "pote", ("garrafa", "a6e070", 0), "cranio", ("garrafa", "ffd060", 2), "livros"])
    lampiao(180, 11, r)
    lampiao(500, 11, r)
    ervas(556, 11, r)


def gerar_parede():
    r = random.Random("loja_parede")
    preparar(W, PAREDE_H, amostras=32)
    cam_frente(W, PAREDE_H, W / 2 / PX, PAREDE_H / 2 / PX)
    luz_parede()
    parede(r)
    return {"img": renderizar(W, PAREDE_H, pontilhado=0.025, contorno=False, luz_borda=False, opaco=True)}


# ================================================================ tapete (visto de cima)
def gerar_tapete():
    w, h = 200, 92
    preparar(w, h, amostras=24)
    cam_topo(w, h, 0, 0)
    luz_piso()
    A, B = w / PX, h / PX
    base = S("5c1420", 0.95, 0.5, 0.15, 7.0)
    caixa("base", (A, B, 0.04), (0, 0, 0.02), S("1c0709", 0.95))
    caixa("campo", (A - 0.5, B - 0.5, 0.06), (0, 0, 0.03), S("7e2027", 0.95, 0.6, 0.15, 7.0), chanfro=0.015)
    caixa("faixa_ouro", (A - 1.1, B - 1.1, 0.07), (0, 0, 0.035), S("c49a45", 0.7), chanfro=0.01)
    caixa("faixa_int", (A - 1.3, B - 1.3, 0.08), (0, 0, 0.04), S("4f1520", 0.95, 0.5, 0.15, 7.0))
    caixa("campo2", (A - 1.9, B - 1.9, 0.09), (0, 0, 0.045), S("7e2027", 0.95, 0.6, 0.15, 7.0))
    # losango central com padrão
    for k, (s, cor) in enumerate(((1.0, "c49a45"), (0.86, "3d1046"), (0.6, "5c1420"), (0.3, "c49a45"))):
        caixa("losango", (B * 0.78 * s, B * 0.78 * s, 0.1 + 0.01 * k), (0, 0, 0.05 + 0.01 * k), S(cor, 0.8), rot=(0, 0, math.pi / 4))
    for sgn in (-1, 1):
        for k in range(3):   # medalhões laterais
            cilindro("medalhao", 0.28 - 0.06 * k, 0.1, (sgn * (A / 2 - 2.2 - k * 0.0), 0, 0.06 + k * 0.01), S(("c49a45", "3d1046", "c49a45")[k], 0.8), vertices=12)
    # franjas nas pontas
    for sgn in (-1, 1):
        for k in range(18):
            caixa("franja", (0.35, 0.05, 0.03), (sgn * (A / 2 + 0.15), -B / 2 + 0.25 + k * (B - 0.5) / 17, 0.02), S("d6ccb2", 0.9))
    return {"img": renderizar(w, h, pontilhado=0.02, contorno=False, luz_borda=False)}


# ================================================================ objetos em 3/4 (origem = pé, frente = -Y)
def luz(ponto, cor, raio, pisca=0.12, forca=1.0):
    return {"ponto": ponto, "cor": cor, "raio": raio, "pisca": pisca, "forca": forca}


FOGO = (1.0, 0.62, 0.22)
VENENO = (0.36, 0.9, 0.42)
OURO = (1.0, 0.8, 0.35)
SANGUE = (0.95, 0.25, 0.32)
AZUL = (0.35, 0.55, 1.0)
ROXO = (0.85, 0.35, 0.95)


def balcao(r):
    mad = madeira("5d3f29", relevo=0.6)
    escura = madeira("3a271b", relevo=0.5)
    clara = madeira("8f6a45", relevo=0.4)
    A, P, Hh = 5.9, 1.15, 1.2
    caixa("corpo", (A, P, Hh - 0.12), (0, 0, (Hh - 0.12) / 2), escura, chanfro=0.03)
    # painéis da frente com moldura
    for i in range(5):
        x = -A / 2 + 0.55 + i * ((A - 1.1) / 4)
        caixa("moldura", (0.95, 0.06, 0.8), (x, -P / 2 - 0.02, 0.58), clara, chanfro=0.02)
        caixa("painel", (0.8, 0.06, 0.66), (x, -P / 2 - 0.045, 0.58), mad, chanfro=0.015)
        esfera("tacha", 0.045, (x, -P / 2 - 0.09, 0.58), S("c49a45", 0.4))
    for sx in (-A / 2 + 0.1, A / 2 - 0.1):   # pés/colunas dos cantos
        caixa("coluna", (0.22, P + 0.1, Hh), (sx, 0, Hh / 2), clara, chanfro=0.04)
        cilindro("capitel", 0.2, 0.08, (sx, -P / 2 - 0.02, Hh + 0.02), S("c49a45", 0.4), vertices=8)
    caixa("rodape", (A + 0.1, P + 0.1, 0.1), (0, 0, 0.05), escura, chanfro=0.02)
    caixa("tampo", (A + 0.3, P + 0.35, 0.13), (0, 0, Hh + 0.01), clara, chanfro=0.035)
    caixa("filete", (A + 0.34, 0.05, 0.05), (0, -P / 2 - 0.2, Hh - 0.08), S("c49a45", 0.4))
    z = Hh + 0.075
    # balança de latão (pratos)
    lat = metal("c49a45", 0.35)
    bx = -1.9
    cilindro("base_b", 0.22, 0.06, (bx, 0.05, z + 0.03), lat, vertices=10)
    cilindro("coluna_b", 0.04, 0.78, (bx, 0.05, z + 0.4), lat, vertices=6)
    caixa("braco_b", (1.2, 0.04, 0.05), (bx, 0.05, z + 0.78), lat, rot=(0, 0.05, 0))
    for sx in (-0.58, 0.58):
        for sy in (-0.07, 0.07):
            cilindro("corda", 0.008, 0.38, (bx + sx, 0.05 + sy, z + 0.57), S("2e2a40"), vertices=4)
        cilindro("prato", 0.24, 0.035, (bx + sx, 0.05, z + 0.37), lat, vertices=14)
    cilindro("peso", 0.06, 0.07, (bx - 0.58, 0.05, z + 0.43), S("45405c"), vertices=8)
    esfera("gema", 0.08, (bx + 0.58, 0.05, z + 0.45), E("b0342f", 1.2))
    # moedas
    ouro = metal("eccb7a", 0.3)
    for (mx, my, n) in ((0.5, 0.1, 6), (0.85, -0.05, 4), (0.6, -0.15, 3)):
        for k in range(n):
            cilindro("moeda", 0.1, 0.035, (mx + r.uniform(-0.01, 0.01), my, z + 0.02 + k * 0.038), ouro, vertices=10)
    for k in range(5):
        cilindro("moeda_sol", 0.1, 0.03, (1.5 + r.uniform(-0.2, 0.2), -0.1 + r.uniform(-0.1, 0.2), z + 0.016), ouro, vertices=10, rot=(r.uniform(-.2, .2), 0, 0))
    # livro-caixa aberto com pena
    caixa("livro_a", (0.5, 0.36, 0.05), (-0.55, -0.05, z + 0.025), S("5c1420", 0.9))
    caixa("pag_e", (0.22, 0.32, 0.04), (-0.68, -0.05, z + 0.07), S("d6ccb2", 0.9), rot=(0, -0.08, 0))
    caixa("pag_d", (0.22, 0.32, 0.04), (-0.43, -0.05, z + 0.07), S("d6ccb2", 0.9), rot=(0, 0.08, 0))
    cilindro("pena", 0.012, 0.5, (-0.3, -0.18, z + 0.3), S("d6ccb2"), rot=(0.5, 0, 0.35), vertices=4)
    cilindro("tinteiro", 0.07, 0.1, (-0.2, 0.2, z + 0.05), S("1d1a2b", 0.3), vertices=8)
    # vela no castiçal
    cilindro("cast_base", 0.14, 0.05, (2.3, 0.05, z + 0.025), lat, vertices=10)
    cilindro("cast_haste", 0.03, 0.28, (2.3, 0.05, z + 0.17), lat, vertices=6)
    cilindro("cera", 0.07, 0.4, (2.3, 0.05, z + 0.5), S("d6ccb2", 0.9), vertices=8)
    cone("chama", 0.065, 0.0, 0.22, (2.3, 0.05, z + 0.8), E("ffb347", 2.0), vertices=6)
    cone("miolo", 0.03, 0.0, 0.13, (2.3, 0.03, z + 0.77), E("fff2b0", 3.0), vertices=6)
    # frasco de poção rubi
    esfera("frasco", 0.14, (1.5, 0.15, z + 0.15), E("d9614a", 1.0))
    cilindro("gargalo", 0.05, 0.2, (1.5, 0.15, z + 0.35), S("2a3042", 0.3), vertices=8)
    # placa "LOJA" gravada (texto no jogo): só a tábua
    return [luz((2.3, 0.05, z + 0.7), FOGO, 56, 0.2), luz((1.5, 0.15, z + 0.2), SANGUE, 18, 0.04, 0.5)]


def barril(r, tom="5d3f29", tampa=True):
    mad = madeira(tom, relevo=0.7, esc=(5, 0.6, 0.9))
    aro = metal("45405c")
    cilindro("meio", 0.4, 0.5, (0, 0, 0.42), mad, vertices=16, chanfro=0.02)
    cilindro("base", 0.34, 0.24, (0, 0, 0.12), mad, vertices=16)
    cilindro("topo", 0.34, 0.24, (0, 0, 0.72), mad, vertices=16)
    for z, rr in ((0.14, 0.355), (0.3, 0.415), (0.58, 0.415), (0.74, 0.355)):
        cilindro("aro", rr, 0.05, (0, 0, z), aro, vertices=16)
    if tampa:
        cilindro("tampo", 0.31, 0.03, (0, 0, 0.845), madeira("3a271b", relevo=0.5), vertices=16)
    return None


def pilha_caixotes(r):
    mad = madeira("745034", relevo=0.7)
    esc = madeira("3a271b", relevo=0.6)
    def cx(x, y, z, s, rot):
        caixa("caixote", (s, s, s * 0.9), (x, y, z + s * 0.45), mad, chanfro=0.04, rot=(0, 0, rot))
        for dz in (-0.3, 0.3):
            caixa("ripa", (s + 0.02, s + 0.02, 0.07), (x, y, z + s * 0.45 + dz * s), esc, rot=(0, 0, rot))
        caixa("diag", (0.07, s + 0.03, s * 0.8), (x, y - 0.0, z + s * 0.45), esc, rot=(0.0, 0.0, rot))
    cx(-0.5, 0.1, 0, 0.95, 0.06)
    cx(0.55, 0.0, 0, 0.8, -0.12)
    cx(-0.35, 0.05, 0.86, 0.75, -0.2)
    # saco em cima
    esfera("saco", 0.3, (0.55, 0.0, 0.95), S("a8884e", 0.95, 0.4, 0.2), escala=(1.0, 0.8, 0.75))
    cone("boca_saco", 0.12, 0.05, 0.14, (0.55, 0.0, 1.14), S("7a6038", 0.95), vertices=8)
    return None


def saco(r):
    pano = S("a8884e", 0.95, 0.5, 0.2)
    esfera("saco", 0.42, (0, 0, 0.36), pano, escala=(1.0, 0.8, 0.9))
    esfera("saco2", 0.3, (0.42, 0.1, 0.24), pano, escala=(1.0, 0.8, 0.8))
    cone("boca", 0.16, 0.07, 0.2, (0, 0, 0.78), S("7a6038", 0.95), vertices=8)
    cilindro("corda", 0.13, 0.04, (0, 0, 0.7), S("5d3f29"), vertices=8)
    return None


def bau(r):
    mad = madeira("5d3f29", relevo=0.6)
    ferro = metal("2e2a40")
    ouro = metal("eccb7a", 0.3)
    caixa("corpo", (1.3, 0.8, 0.55), (0, 0, 0.275), mad, chanfro=0.04)
    for sx in (-0.5, 0.5):
        caixa("cinta", (0.1, 0.84, 0.58), (sx, 0, 0.28), ferro, chanfro=0.02)
    caixa("aro_base", (1.34, 0.84, 0.06), (0, 0, 0.04), ferro)
    # moedas dentro
    caixa("recheio", (1.12, 0.62, 0.04), (0, 0, 0.56), E("c49a45", 1.0))
    for k in range(18):
        cilindro("moeda", 0.1, 0.035, (r.uniform(-0.5, 0.5), r.uniform(-0.25, 0.25), 0.6 + r.uniform(0, 0.12)), ouro, vertices=10, rot=(r.uniform(-.6, .6), r.uniform(-.6, .6), 0))
    for (x, y, z) in ((0.2, 0.0, 0.76), (-0.3, 0.1, 0.7)):
        esfera("joia", 0.09, (x, y, z), E(("b0342f", "4073ff")[x > 0 and 1 or 0], 1.6))
    # tampa aberta pra trás
    pivo = (0, 0.4, 0.55)
    caixa("tampa", (1.3, 0.8, 0.14), (0, 0.4 + 0.4 * 0.45, 0.55 + 0.4 * 0.89), mad, chanfro=0.04, rot=(-1.1, 0, 0))
    for sx in (-0.5, 0.5):
        caixa("cinta_t", (0.1, 0.84, 0.17), (sx, 0.4 + 0.4 * 0.45, 0.55 + 0.4 * 0.89), ferro, chanfro=0.02, rot=(-1.1, 0, 0))
    caixa("fecho", (0.16, 0.05, 0.18), (0, -0.4, 0.45), ouro)
    return [luz((0, 0, 0.7), OURO, 40, 0.08, 0.9)]


def caldeirao(r):
    ferro = metal("2e2a40", 0.6)
    esfera("panela", 0.62, (0, 0, 0.66), ferro, escala=(1, 1, 0.82))
    cilindro("borda", 0.5, 0.09, (0, 0, 1.1), ferro, vertices=18)
    cilindro("caldo", 0.46, 0.03, (0, 0, 1.12), E("56b04a", 1.3), vertices=18)
    for k, (x, y) in enumerate(((-0.22, -0.12), (0.12, -0.2), (0.25, 0.1), (-0.05, 0.12))):
        esfera("bolha", 0.08 - 0.01 * (k % 2), (x, y, 1.15), E("a6e070", 1.8))
    for a in range(3):   # alças e pés
        ang = a * 2.1 + 0.4
        caixa("pe", (0.1, 0.1, 0.22), (0.46 * math.cos(ang), 0.46 * math.sin(ang), 0.14), ferro)
    cilindro("alca", 0.52, 0.04, (0, -0.02, 1.0), S("1d1a2b", 0.5), vertices=18, rot=(0.0, 0.0, 0.0))
    # lenha e fogo embaixo
    for k, (ang, sz) in enumerate(((0.3, 0.7), (1.7, 0.7), (2.9, 0.7))):
        cilindro("lenha", 0.07, sz, (0.4 * math.cos(ang), 0.4 * math.sin(ang), 0.07), madeira("3a271b"), rot=(math.pi / 2, 0, ang), vertices=6)
    for (x, y, h) in ((-0.5, -0.45, 0.5), (0.0, -0.55, 0.65), (0.5, -0.45, 0.5), (-0.25, -0.5, 0.35), (0.25, -0.5, 0.35)):
        cone("fogo", 0.15, 0.0, h, (x, y, 0.2 + h / 2), E(("f0921e", "ffb347", "f0921e", "ffd060", "ffd060")[int((x + 0.5) * 4) % 5], 2.0), vertices=6)
    cilindro("brasas", 0.65, 0.04, (0, -0.3, 0.03), E("c45a14", 1.2), vertices=12)
    return [luz((0, -0.5, 0.4), FOGO, 70, 0.22), luz((0, 0, 1.1), VENENO, 46, 0.1, 0.8)]


def mesa_alquimia(r):
    mad = madeira("5d3f29", relevo=0.6)
    esc = madeira("3a271b", relevo=0.5)
    caixa("tampo", (2.0, 1.0, 0.11), (0, 0, 0.98), mad, chanfro=0.03)
    for sx in (-0.85, 0.85):
        for sy in (-0.38, 0.38):
            caixa("perna", (0.12, 0.12, 0.95), (sx, sy, 0.47), esc, chanfro=0.015)
    caixa("travessa", (1.8, 0.07, 0.07), (0, 0.38, 0.3), esc)
    caixa("travessa2", (1.8, 0.07, 0.07), (0, -0.38, 0.3), esc)
    z = 1.035
    # retorta com líquido azul + serpentina
    esfera("balao", 0.2, (-0.7, 0.05, z + 0.2), E("4073ff", 1.1))
    cilindro("colo", 0.05, 0.3, (-0.7, 0.05, z + 0.5), S("2a3042", 0.3), vertices=8)
    # frascos brilhando
    for (x, y, hexa, rr) in ((-0.2, 0.05, "56b04a", 0.14), (0.15, -0.15, "b0342f", 0.12), (0.4, 0.12, "e04aa8", 0.15), (0.75, -0.1, "ffd060", 0.12)):
        esfera("frasco", rr, (x, y, z + rr), E(hexa, 1.1))
        cilindro("gargalo", 0.045, 0.2, (x, y, z + rr * 2 + 0.04), S("2a3042", 0.3), vertices=8)
        cilindro("rolha", 0.055, 0.06, (x, y, z + rr * 2 + 0.16), S("8f6a45"), vertices=8)
    # almofariz e grimório
    cilindro("almof", 0.14, 0.12, (0.0, -0.33, z + 0.06), S("45405c", 0.6), vertices=10)
    caixa("grimorio", (0.5, 0.36, 0.08), (0.1, 0.28, z + 0.04), S("3d1046", 0.9), rot=(0, 0, 0.2))
    caixa("grim_pg", (0.44, 0.3, 0.05), (0.1, 0.28, z + 0.09), S("d6ccb2", 0.9), rot=(0, 0, 0.2))
    # vela
    cilindro("cera", 0.06, 0.26, (-0.45, -0.3, z + 0.13), S("d6ccb2", 0.9), vertices=8)
    cone("chama", 0.055, 0.0, 0.18, (-0.45, -0.3, z + 0.35), E("ffb347", 2.0), vertices=6)
    return [luz((-0.45, -0.3, z + 0.35), FOGO, 36, 0.2, 0.8), luz((-0.7, 0.05, z + 0.2), AZUL, 28, 0.05, 0.6), luz((0.4, 0.12, z + 0.2), ROXO, 26, 0.05, 0.6)]


def suporte_armas(r):
    mad = madeira("5d3f29", relevo=0.6)
    ferro = metal("9a94b0", 0.3)
    caixa("base", (1.5, 0.45, 0.1), (0, 0, 0.05), madeira("3a271b"), chanfro=0.02)
    for sx in (-0.65, 0.65):
        caixa("poste", (0.12, 0.12, 1.25), (sx, 0, 0.7), mad, chanfro=0.02)
    caixa("barra", (1.4, 0.1, 0.1), (0, 0, 0.55), mad, chanfro=0.015)
    caixa("barra2", (1.4, 0.1, 0.1), (0, 0, 1.15), mad, chanfro=0.015)
    # espadas apoiadas
    for k, (x, ang) in enumerate(((-0.35, 0.12), (-0.05, -0.05), (0.25, 0.1))):
        caixa("lamina", (0.09, 0.03, 1.15), (x, -0.1, 0.9), ferro, rot=(0.0, ang, 0.0))
        caixa("guarda", (0.32, 0.05, 0.05), (x + math.sin(ang) * 0.45 * -1, -0.1, 0.38), metal("c49a45", 0.35))
        caixa("cabo", (0.05, 0.05, 0.22), (x + math.sin(ang) * 0.55 * -1, -0.1, 0.22), madeira("3a271b"))
        esfera("pomo", 0.05, (x + math.sin(ang) * 0.6 * -1, -0.1, 0.1), metal("c49a45", 0.35))
    # lança
    cilindro("haste", 0.025, 1.9, (0.58, -0.05, 0.95), madeira("5d3f29"), rot=(0, 0.04, 0), vertices=6)
    cone("ponta", 0.07, 0.0, 0.3, (0.62, -0.05, 1.98), ferro, vertices=4)
    # escudo
    esfera("escudo", 0.38, (-0.9, -0.12, 0.45), S("5c1420", 0.8), escala=(0.5, 0.15, 1.0))
    esfera("umbo", 0.1, (-0.9, -0.26, 0.45), metal("c49a45", 0.35))
    return None


def livros_vela(r):
    for k in range(4):
        caixa("livro", (0.5 - 0.04 * k, 0.36, 0.11), (0.0 + r.uniform(-0.04, 0.04), 0, 0.055 + k * 0.115), S(r.choice(["7e2027", "35473a", "8f6a2e", "223566", "4f1520"]), 0.8, 0.3, 0.2), rot=(0, 0, r.uniform(-0.25, 0.25)))
    cilindro("cera", 0.07, 0.3, (0.0, 0, 0.6), S("d6ccb2", 0.9), vertices=8)
    cone("chama", 0.065, 0.0, 0.22, (0, 0, 0.84), E("ffb347", 2.0), vertices=6)
    cone("miolo", 0.03, 0.0, 0.13, (0, -0.02, 0.8), E("fff2b0", 3.0), vertices=6)
    esfera("cranio", 0.16, (0.42, -0.1, 0.17), S("d6ccb2", 0.8, 0.4, 0.2), escala=(1, 0.95, 1.0))
    for sx in (-0.06, 0.06):
        esfera("olho", 0.04, (0.42 + sx, -0.24, 0.19), S("0d0b14"))
    return [luz((0, 0, 0.82), FOGO, 40, 0.22, 0.9)]


def vela_chao(r):
    cilindro("pires", 0.17, 0.03, (0, 0, 0.015), metal("c49a45", 0.4), vertices=10)
    cilindro("cera", 0.07, 0.26, (0, 0, 0.16), S("d6ccb2", 0.9), vertices=8)
    for dx in (0.17, -0.19):
        cilindro("cera2", 0.05, 0.14, (dx, -0.05, 0.1), S("d6ccb2", 0.9), vertices=8)
        cone("chama2", 0.04, 0.0, 0.14, (dx, -0.05, 0.24), E("ffb347", 2.0), vertices=6)
    cone("chama", 0.06, 0.0, 0.2, (0, 0, 0.38), E("ffb347", 2.0), vertices=6)
    cone("miolo", 0.03, 0.0, 0.12, (0, -0.02, 0.35), E("fff2b0", 3.0), vertices=6)
    return [luz((0, 0, 0.38), FOGO, 44, 0.25, 0.9)]


def armadura(r):
    """Armadura de placas num suporte de madeira, com pluma vermelha e a espada na mão."""
    aco = metal("9a94b0", 0.35)
    escuro = metal("45405c", 0.5)
    mad = madeira("3a271b", relevo=0.5)
    caixa("base", (0.9, 0.7, 0.1), (0, 0, 0.05), mad, chanfro=0.02)
    caixa("poste", (0.1, 0.1, 0.5), (0, 0.1, 0.35), mad)
    for sx in (-0.17, 0.17):   # pernas
        caixa("perna", (0.2, 0.22, 0.75), (sx, 0, 0.5), aco, chanfro=0.03)
        caixa("bota", (0.24, 0.34, 0.16), (sx, -0.05, 0.16), escuro, chanfro=0.03)
        esfera("joelho", 0.12, (sx, -0.1, 0.62), aco)
    caixa("saia", (0.62, 0.34, 0.2), (0, 0, 0.92), escuro, chanfro=0.04)
    caixa("torso", (0.62, 0.38, 0.7), (0, 0, 1.3), aco, chanfro=0.07)
    caixa("peitoral", (0.34, 0.06, 0.4), (0, -0.2, 1.36), metal("c9c3d6", 0.3), chanfro=0.02)
    for sx in (-1, 1):   # ombros e braços
        esfera("ombro", 0.2, (sx * 0.42, 0, 1.6), aco, escala=(1, 1, 0.8))
        caixa("braco", (0.16, 0.18, 0.62), (sx * 0.47, 0, 1.22), aco, chanfro=0.03)
        caixa("luva", (0.18, 0.2, 0.18), (sx * 0.47, -0.02, 0.86), escuro, chanfro=0.03)
    esfera("elmo", 0.26, (0, 0, 1.92), aco, escala=(1, 1, 1.05))
    caixa("viseira", (0.34, 0.06, 0.07), (0, -0.24, 1.94), S("0d0b14"))
    caixa("crista", (0.05, 0.4, 0.1), (0, 0, 2.2), escuro)
    for k in range(4):   # pluma
        cone("pluma", 0.07, 0.0, 0.34, (0, 0.05 + k * 0.06, 2.3 - k * 0.04), S("a52a2e", 0.9), vertices=5)
    caixa("lamina", (0.07, 0.03, 1.3), (0.5, -0.12, 1.15), metal("c9c3d6", 0.25))
    caixa("guarda", (0.3, 0.05, 0.05), (0.5, -0.12, 0.52), metal("c49a45", 0.35))
    return None


def porta(r):
    """Vão de pedra na parede de baixo, visto de dentro: moldura, escuridão azulada e degrau. Placa de madeira acima (o texto vai no jogo)."""
    pedra = [S(h, 0.9, 0.9, 0.3, 4.0) for h in ("5e544a", "4a423b", "766a5d")]
    A = 3.3
    caixa("noite", (A - 0.5, 0.3, 1.9), (0, 0.3, 1.0), E("101a33", 1.0))
    caixa("noite_b", (A - 0.5, 0.2, 1.5), (0, 0.15, 0.85), E("2a3a66", 0.8))
    for sx in (-1, 1):
        caixa("pilar", (0.55, 0.6, 2.2), (sx * (A / 2 - 0.1), 0, 1.1), r.choice(pedra), chanfro=0.05)
        caixa("base_p", (0.7, 0.75, 0.2), (sx * (A / 2 - 0.1), 0, 0.1), pedra[2], chanfro=0.05)
    caixa("verga", (A + 0.6, 0.65, 0.5), (0, 0, 2.3), pedra[2], chanfro=0.06)
    for i in range(4):
        caixa("aduela", (0.32, 0.67, 0.3), (-0.9 + i * 0.6, -0.01, 2.05), r.choice(pedra), chanfro=0.04)
    caixa("degrau", (A - 0.2, 0.7, 0.12), (0, -0.3, 0.06), pedra[0], chanfro=0.04)
    # placa de madeira na verga (o texto SAIR é desenhado no jogo)
    caixa("placa", (1.7, 0.1, 0.42), (0, -0.36, 2.3), madeira("4a3022", relevo=0.6), chanfro=0.03)
    for sx in (-0.75, 0.75):
        esfera("prego", 0.04, (sx, -0.44, 2.3), metal("c49a45", 0.35))
    return None


# nome: (função, canvas largura, canvas altura)
PECAS = {
    "balcao": (balcao, 224, 128),
    "barril": (barril, 64, 64),
    "barril_b": (lambda r: barril(r, "3a271b", False), 64, 64),
    "caixotes": (pilha_caixotes, 96, 96),
    "saco": (saco, 64, 64),
    "bau": (bau, 96, 96),
    "caldeirao": (caldeirao, 96, 96),
    "mesa": (mesa_alquimia, 128, 112),
    "armas": (suporte_armas, 96, 112),
    "livros_vela": (livros_vela, 64, 64),
    "vela_chao": (vela_chao, 48, 48),
    "armadura": (armadura, 96, 128),
    "porta": (porta, 128, 128),
}


def gerar_peca(nome):
    f, w, h = PECAS[nome]
    preparar(w, h, amostras=40)
    cam = px3.camera(elevacao_graus=32.0, escala=max(w, h) / PX)
    luz_objeto()
    luzes = f(random.Random("loja_" + nome)) or []
    bpy.context.view_layer.update()
    pe = tuple(v / FATOR for v in px3.pe_na_tela(cam))   # o render é FATOR vezes maior que a imagem final
    img = renderizar(w, h)
    img, pe_rel = px3.recortar(img, pe)
    ls = []
    for l in luzes:
        fx, fy = (v / FATOR for v in px3.pe_na_tela(cam, l["ponto"]))
        ls.append({"fonte": [round(fx - pe[0]), round(fy - pe[1])], "cor": list(l["cor"]), "raio": l["raio"], "pisca": l["pisca"], "forca": l["forca"]})
    return {"img": img, "pe": [round(pe_rel[0]), round(pe_rel[1])], "luzes": ls}


def gerar_tapete_peca():
    d = gerar_tapete()
    h, w = d["img"].shape[:2]
    return {"img": d["img"], "pe": [w // 2, h // 2 + 0], "luzes": []}


# ================================================================ layout (tela de 640x360; pé de cada peça em px)
# camada: "chao" = desenhada antes de tudo (tapete, porta); "obj" = ordenada pelo pé junto com o herói e o vendedor.
# obst = [largura, profundidade] do que o herói não pode pisar (retângulo atrás do pé); sombra = [raio x, raio y]
LAYOUT = [
    {"peca": "tapete", "x": 320, "y": 218, "camada": "chao"},
    {"peca": "porta", "x": 320, "y": 358, "camada": "chao"},
    {"peca": "balcao", "x": 320, "y": 143, "camada": "obj", "sombra": [78, 7]},
    {"peca": "barril", "x": 46, "y": 148, "camada": "obj", "obst": [22, 9], "sombra": [14, 4]},
    {"peca": "barril_b", "x": 68, "y": 142, "camada": "obj", "obst": [22, 9], "sombra": [14, 4]},
    {"peca": "caixotes", "x": 52, "y": 190, "camada": "obj", "obst": [40, 10], "sombra": [24, 5]},
    {"peca": "mesa", "x": 98, "y": 246, "camada": "obj", "obst": [50, 12], "sombra": [34, 6]},
    {"peca": "saco", "x": 46, "y": 244, "camada": "obj", "obst": [22, 8], "sombra": [14, 4]},
    {"peca": "armas", "x": 178, "y": 142, "camada": "obj", "obst": [38, 8], "sombra": [24, 4]},
    {"peca": "bau", "x": 574, "y": 152, "camada": "obj", "obst": [34, 10], "sombra": [24, 5]},
    {"peca": "caldeirao", "x": 560, "y": 224, "camada": "obj", "obst": [32, 10], "sombra": [22, 5]},
    {"peca": "barril", "x": 532, "y": 146, "camada": "obj", "obst": [22, 9], "sombra": [14, 4]},
    {"peca": "saco", "x": 596, "y": 206, "camada": "obj", "obst": [22, 8], "sombra": [14, 4]},
    {"peca": "livros_vela", "x": 590, "y": 262, "camada": "obj", "obst": [18, 8], "sombra": [12, 4]},
    {"peca": "barril", "x": 48, "y": 318, "camada": "obj", "obst": [22, 9], "sombra": [14, 4]},
    {"peca": "barril_b", "x": 70, "y": 326, "camada": "obj", "obst": [22, 9], "sombra": [14, 4]},
    {"peca": "saco", "x": 96, "y": 328, "camada": "obj", "obst": [22, 8], "sombra": [14, 4]},
    {"peca": "armadura", "x": 596, "y": 320, "camada": "obj", "obst": [24, 8], "sombra": [20, 5]},
    {"peca": "caixotes", "x": 552, "y": 328, "camada": "obj", "obst": [40, 10], "sombra": [24, 5]},
    {"peca": "vela_chao", "x": 190, "y": 270, "camada": "obj", "sombra": [8, 3]},
    {"peca": "vela_chao", "x": 440, "y": 168, "camada": "obj", "sombra": [8, 3]},
]

# luzes que não vêm de uma peça (x, y na tela; y = onde a luz toca o chão ou a parede; "par" = parede)
LUZES_FIXAS = [
    {"x": 83, "y": 96, "cor": list(FOGO), "raio": 110, "pisca": 0.22, "forca": 1.15, "par": True},
    {"x": 180, "y": 34, "cor": list(FOGO), "raio": 70, "pisca": 0.15, "forca": 0.9, "par": True},
    {"x": 500, "y": 34, "cor": list(FOGO), "raio": 70, "pisca": 0.15, "forca": 0.9, "par": True},
    {"x": 238, "y": 46, "cor": list(FOGO), "raio": 44, "pisca": 0.25, "forca": 0.8, "par": True},
    {"x": 402, "y": 46, "cor": list(FOGO), "raio": 44, "pisca": 0.25, "forca": 0.8, "par": True},
    {"x": 467, "y": 46, "cor": [0.42, 0.58, 1.0], "raio": 80, "pisca": 0.0, "forca": 0.8, "par": True},
    {"x": 176, "y": 56, "cor": list(VENENO), "raio": 22, "pisca": 0.05, "forca": 0.5, "par": True},
    {"x": 560, "y": 50, "cor": list(ROXO), "raio": 22, "pisca": 0.05, "forca": 0.5, "par": True},
    # só no mapa de luz (sem halo): claridade geral no meio da sala pra enxergar o herói, e a poça do luar no chão
    {"x": 320, "y": 215, "cor": [1.0, 0.72, 0.44], "raio": 270, "pisca": 0.0, "forca": 0.5, "par": False, "halo": False},
    {"x": 320, "y": 345, "cor": [0.4, 0.55, 1.0], "raio": 85, "pisca": 0.0, "forca": 0.38, "par": False, "halo": False},   # luar que entra pela porta
    {"x": 515, "y": 172, "cor": [0.42, 0.58, 1.0], "raio": 80, "pisca": 0.0, "forca": 0.5, "par": False, "halo": False},
]
EMISSORES = [
    {"tipo": "brasa", "x": 83, "y": 98, "n": 7},
    {"tipo": "brasa", "x": 560, "y": 214, "n": 5},
    {"tipo": "fumaca", "x": 560, "y": 186, "n": 4},
    {"tipo": "poeira", "n": 18},
]
LUAR = {"janela": [442, 14, 492, 78], "chao": [[420, 112], [520, 112], [560, 190], [440, 190]]}


def montar_json(pecas):
    return {"_gerado_por": "fonte_arte/modelos3d/loja.py (não edite à mão)", "piso": "piso.png", "parede": "parede.png", "objetos": "objetos.png",
            "ambiente": [0.42, 0.35, 0.5], "pecas": pecas, "layout": LAYOUT, "luzes_fixas": LUZES_FIXAS, "emissores": EMISSORES, "luar": LUAR}


# ================================================================ cache e saída
def _salvar_cache(nome, d):
    os.makedirs(CACHE, exist_ok=True)
    np.save(os.path.join(CACHE, nome + ".npy"), d["img"])
    meta = {k: v for k, v in d.items() if k != "img"}
    with open(os.path.join(CACHE, nome + ".json"), "w", encoding="utf-8") as fp:
        json.dump(meta, fp)


def _ler_cache(nome):
    d = {"img": np.load(os.path.join(CACHE, nome + ".npy"))}
    with open(os.path.join(CACHE, nome + ".json"), encoding="utf-8") as fp:
        d.update(json.load(fp))
    return d


def main():
    so = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
    todos = ["piso", "parede", "tapete"] + list(PECAS)
    dados = {}
    for nome in todos:
        if so and nome not in so and os.path.exists(os.path.join(CACHE, nome + ".npy")):
            dados[nome] = _ler_cache(nome)
            continue
        if nome == "piso":
            d = gerar_piso()
        elif nome == "parede":
            d = gerar_parede()
        elif nome == "tapete":
            d = gerar_tapete_peca()
        else:
            d = gerar_peca(nome)
        _salvar_cache(nome, d)
        dados[nome] = d
        print("PECA OK", nome, d["img"].shape)
    os.makedirs(SAIDA, exist_ok=True)
    px3.salvar_png(dados["piso"]["img"], os.path.join(SAIDA, "piso.png"))
    px3.salvar_png(dados["parede"]["img"], os.path.join(SAIDA, "parede.png"))
    nomes = ["tapete"] + list(PECAS)
    atlas, pos = px3.empacotar([dados[n]["img"] for n in nomes], largura=512)
    px3.salvar_png(atlas, os.path.join(SAIDA, "objetos.png"))
    pecas = {}
    for n, p in zip(nomes, pos):
        pecas[n] = {"regiao": list(p), "pe": dados[n]["pe"], "luzes": dados[n].get("luzes", [])}
    with open(os.path.join(SAIDA, "cenario.json"), "w", encoding="utf-8") as fp:
        json.dump(montar_json(pecas), fp, ensure_ascii=False, indent=1)
    print("LOJA OK atlas", atlas.shape)


main()
