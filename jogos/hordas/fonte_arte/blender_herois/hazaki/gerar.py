"""Framework de animação do Hazaki (Blender 4.5): modelo do estudo do Codex + RIG com joelho e cotovelo + materiais em 4 faixas + luz + câmera
do jogo, e uma função de pose por animação em módulos separados (anim_<nome>.py).

    blender -b -t 6 -P gerar.py                       # todas as animações (anim_*.py desta pasta)
    blender -b -t 6 -P gerar.py -- --anim=andar       # só uma
Saída: quadros/<anim>/<direcao>_<i>_{cor,normal}.png (32x44, ver LEIA-ME.md) e hazaki_rig.blend (modelo + rig na pose de repouso).

Contrato de uma animação: anim_<nome>.py define N_QUADROS (int) e posar(arm, quadro, n_quadros). `arm` é o Armature (ossos em ossos.OSSOS, já
zerado); use ossos.girar/mover/pisar. Nada mais precisa ser registrado: o gerar.py descobre o arquivo pelo nome.

Modelo e técnica de render: os de gerar_heroi_estilo.py (aprovado pelo Alisson): geometria do Codex (codex_estudo/criar_estudo.py), materiais em 4
faixas por emissão (paleta escura do jogo, sombra fria, luz quente lateral), contorno por casca invertida no tom escuro da cor, Cycles em pixel
nativo (1 amostra, filtro BOX mínimo, sem bloom), câmera ortográfica a 45 graus, 24,5 px/m, pé na linha 42 do quadro 32x44.
Mudou em relação ao estudo: pernas e braços recriados em repouso reto (com joelho e cotovelo), katana de lâmina espessa na mão apontando
para o lado/baixo, herói mais largo (~31 px), e tudo preso a ossos.
"""
import importlib
import importlib.util
import inspect
import math
import os
import random
import shutil
import sys
from pathlib import Path

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
import normais  # noqa: E402
import ossos  # noqa: E402

CODEX = AQUI.parent / "codex_estudo" / "criar_estudo.py"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SO_ANIM = next((a.split("=", 1)[1] for a in ARGS if a.startswith("--anim=")), None)
# PERFIL: outro personagem sobre o MESMO rig e as MESMAS animações (ex.: ../matheus/perfil.py, rodado por ../matheus/gerar.py). Sem --perfil, é o Hazaki.
# O perfil define NOME, PALETA, BRILHANTES e, opcionalmente, fonte(heroi_src, trocar) e ajustar(ns, heroi, OSSO_DE, apagar); ver ../matheus/perfil.py.
_PERFIL = next((a.split("=", 1)[1] for a in ARGS if a.startswith("--perfil=")), None)
perfil = None
if _PERFIL:
    _spec = importlib.util.spec_from_file_location("perfil_heroi", _PERFIL)
    perfil = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(perfil)
NOME = perfil.NOME if perfil else "hazaki"
SAIDA = (Path(_PERFIL).resolve().parent if perfil else AQUI) / "quadros"

W, H = 32, 44             # quadro do herói no jogo
PPU = 24.5                # px por metro (câmera do jogo)
ELEV = 45.0               # graus
PE_LINHA = 43             # última linha do desenho (pé = 42 + 1 px de contorno)
ESCALA = 0.55             # o modelo do Codex tem ~3 m; o do jogo, ~2,3 m
LARGURA = 0.95            # largura relativa do herói (o estudo usava 0.95); com 1.0 a lâmina e o lenço encostam nos 32 px
CONTORNO = 0.062          # espessura da casca do contorno, em metros do mundo (~1 px)
# ordem das linhas do jogo (v2/sprites.gd) e ângulo do herói em torno de Z (0 = de frente para a câmera)
DIRECOES = [("baixo", 0.0), ("esquerda", -90.0), ("direita", 90.0), ("cima", 180.0),
            ("baixo_esq", -45.0), ("baixo_dir", 45.0), ("cima_esq", -135.0), ("cima_dir", 135.0)]


def hexa(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


PALETA = {
    "Tecido vermelho queimado": "#7a2a32", "Vermelho iluminado": "#93383b", "Dobras do tecido": "#4c1c2c",
    "Calça azul carvão": "#2f384c", "Cabelo quase preto": "#222839", "Couro castanho": "#503829",
    "Pele": "#9a7360", "Rosto iluminado": "#b78c74", "Aço azulado": "#66798d", "Fio polido": "#d6e0ea",
    "Latão antigo": "#9a7a3e", "Olho": "#0a0c14",
}
BRILHANTES = {"Reflexo frio": "#8ea9c4"}
if perfil:
    PALETA, BRILHANTES = perfil.PALETA, perfil.BRILHANTES
LUZ_PRINCIPAL = Vector((-0.80, -0.35, 0.50)).normalized()
LUZ_CONTRA = Vector((0.60, 0.75, 0.30)).normalized()


def srgb_para_linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def lin(c):
    return tuple(srgb_para_linear(max(0.0, min(1.0, v))) for v in c) + (1.0,)


def clampc(c):
    return tuple(max(0.0, min(1.0, v)) for v in c)


def mais(c, t, k=1.0):
    return tuple(a * k + b for a, b in zip(c, t))


# ============================================================ 1. modelo (Codex) + pernas, braços e katana recriados em repouso
src = CODEX.read_text(encoding="utf-8")
defs = src.split("# Base de pedra")[0]
heroi_src = "# Herói original" + src.split("# Herói original", 1)[1].split("# Portal de pedra")[0]


def trocar(txt, de, para):
    assert de in txt, "trecho não encontrado: " + de
    return txt.replace(de, para)


# cabelo mais grosso e mechas mais compridas (lê melhor em 44 px), como no estudo aprovado
heroi_src = trocar(heroi_src, "segment('Mecha de cabelo',root,tip,.105,0,hair,4)", "segment('Mecha de cabelo',root,tip,.15,0,hair,4)")
heroi_src = trocar(heroi_src, "3.19+random.uniform(-.05,.13)", "3.23+random.uniform(-.05,.12)")

if perfil and hasattr(perfil, "fonte"):
    heroi_src = perfil.fonte(heroi_src, trocar)

ns = {"__name__": "codex_estudo", "__file__": str(CODEX)}
exec(compile(defs, str(CODEX), "exec"), ns)
antes = set(bpy.data.objects)
random.seed(26)
exec(compile(heroi_src, str(CODEX), "exec"), ns)
heroi = [o for o in bpy.data.objects if o not in antes]
HY = ns["H"]
P, segment, box, ico = ns["P"], ns["segment"], ns["box"], ns["ico"]


def apagar(prefixos):
    for o in [o for o in heroi if o.name.startswith(prefixos)]:
        heroi.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)


# fora: franja e boca (ruído em 44 px) e tudo que vai ser refeito em repouso reto (pernas, botas, braços, mãos, katana)
apagar(("Franja", "Boca", "Bota", "Canela", "Coxa", "Faixa da bota", "Braço", "Antebraço", "Proteção", "Mão",
        "Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Dorso da lâmina", "Fio azul refletido"))

ANT = set(bpy.data.objects)
# JOELHO e COTOVELO: cada membro é duas peças em ossos diferentes (coxa/canela, braço/antebraço), a articulação fica entre elas
PONTOS = {}      # nome da articulação -> posição no mundo do modelo (com o deslocamento H do Codex)
OSSO_DE = {}     # objeto -> nome do osso
for lado, s in (("esquerda", -1), ("direita", 1)):
    sfx = "_e" if s < 0 else "_d"
    quadril, joelho, tornoz = P(s * .19, 0, 1.55), P(s * .20, .03, 1.02), P(s * .20, .03, .52)
    OSSO_DE[segment("Coxa " + lado, joelho, quadril, .19, .22, ns["charcoal"])] = "perna" + sfx
    OSSO_DE[segment("Canela " + lado, tornoz, joelho, .16, .185, ns["charcoal"])] = "canela" + sfx
    OSSO_DE[box("Bota " + lado, P(s * .20, -.10, .37), (.36, .60, .34), ns["leather"], .065)] = "pe" + sfx
    OSSO_DE[box("Faixa da bota " + lado, P(s * .20, .03, .61), (.35, .32, .08), ns["steel"], .015)] = "pe" + sfx
    ombro, cotov, punho = P(s * .40, 0, 2.20), P(s * (.68 if s > 0 else .72), -.05, 1.78), P(s * (.70 if s > 0 else .84), -.24, 1.46)
    PONTOS.update({"quadril" + sfx: quadril, "joelho" + sfx: joelho, "tornozelo" + sfx: tornoz,
                   "ombro" + sfx: ombro, "cotovelo" + sfx: cotov, "punho" + sfx: punho})
    OSSO_DE[segment("Braço " + lado, ombro, cotov, .21, .155, ns["red"] if s < 0 else ns["red_light"])] = "braco" + sfx
    OSSO_DE[segment("Antebraço " + lado, cotov, punho, .15, .115, ns["leather"])] = "antebraco" + sfx
    dv = (Vector(punho) - Vector(cotov)).normalized()
    meio = (Vector(punho) + Vector(cotov)) / 2 + Vector((0, -.03, 0))
    OSSO_DE[box("Proteção " + lado, tuple(meio), (.25, .25, .30), ns["steel"], .03,
                dv.to_track_quat("Z", "Y").to_euler())] = "antebraco" + sfx
    mao = Vector(punho) + Vector((0.02, -.04, -.09))
    OSSO_DE[ico("Mão " + lado, tuple(mao), (.13, .13, .14), ns["skin"] if s < 0 else ns["skin_lit"], 2)] = "antebraco" + sfx
    if s > 0:
        # KATANA na mão direita da tela, apontada para o lado e para baixo, lâmina espessa (lê de qualquer direção)
        d = Vector((.26, -.08, -.97)).normalized()
        cabo_a, cabo_b = mao - d * .20, mao + d * .17
        OSSO_DE[segment("Cabo da katana", tuple(cabo_a), tuple(cabo_b), .052, .052, ns["hair"], 8)] = "antebraco_d"
        for i in range(4):
            c = cabo_a + d * (.04 + i * .065)
            OSSO_DE[segment("Trança do cabo", tuple(c), tuple(c + d * .025), .058, .058, ns["gold"], 8)] = "antebraco_d"
        OSSO_DE[segment("Guarda da katana", tuple(cabo_b - d * .03), tuple(cabo_b + d * .03), .15, .15, ns["gold"], 8)] = "antebraco_d"
        lam_a = cabo_b + d * .06
        lam_b = lam_a + d * .80
        OSSO_DE[segment("Lâmina da katana", tuple(lam_a), tuple(lam_b), .180, .130, ns["silver"], 4)] = "antebraco_d"
        OSSO_DE[segment("Ponta da katana", tuple(lam_b), tuple(lam_b + d * .18), .130, .0, ns["silver"], 4)] = "antebraco_d"
        OSSO_DE[ns["line"]("Fio azul refletido", [tuple(lam_a + Vector((0, -.05, 0))), tuple(lam_b + Vector((0, -.05, 0)))], .028, ns["cyan"])] = "antebraco_d"
novos = [o for o in bpy.data.objects if o not in ANT]
heroi += novos
if perfil and hasattr(perfil, "ajustar"):
    perfil.ajustar(ns, heroi, OSSO_DE, apagar)

# olhos/sobrancelhas mais grossos e lenço mais curto (como no estudo)
for o in heroi:
    if o.type == "MESH" and o.name in ("Lenço ao vento", "Face escura do lenço"):
        for v in o.data.vertices:
            if v.co.x < -0.13:
                v.co.x = -0.13 + (v.co.x + 0.13) * 0.52
        o.data.update()
    elif o.name.startswith("Olho"):
        o.scale = (1.45, 1.3, 2.3)
        o.location.y -= 0.01
    elif o.name.startswith("Sobrancelha") and o.type == "CURVE":
        o.data.bevel_depth = 0.032

# cabeça maior (chibi), em torno do pescoço
CABECA = 1.22
centro = Vector((0.0, HY, 2.45))
CABECA_PREF = ("Cabeça", "Orelha", "Olho", "Sobrancelha", "Nariz", "Cabelo", "Mecha")
for o in heroi:
    if o.name.startswith(CABECA_PREF):
        o.matrix_world = Matrix.Translation(centro) @ Matrix.Scale(CABECA, 4) @ Matrix.Translation(-centro) @ o.matrix_world

# osso de cada peça restante do Codex
for o in heroi:
    if o in OSSO_DE:
        continue
    if o.name.startswith(CABECA_PREF):
        OSSO_DE[o] = "cabeca"
    elif o.name.startswith(("Bainha", "Terminal da bainha")):
        OSSO_DE[o] = "quadril"
    else:
        OSSO_DE[o] = "torso"      # casaco, abas, cinto, fivela, gola, costura, pescoço, lenço

# ============================================================ 2. materiais: 4 faixas por emissão (técnica do Codex), cores do jogo


def estilizar(material, base):
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    saida = nodes.new("ShaderNodeOutputMaterial")
    emissao = nodes.new("ShaderNodeEmission")
    links.new(emissao.outputs[0], saida.inputs["Surface"])
    geo = nodes.new("ShaderNodeNewGeometry")
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = LUZ_PRINCIPAL
    links.new(geo.outputs["Normal"], dot.inputs[0])
    remap = nodes.new("ShaderNodeMath")
    remap.operation = "MULTIPLY_ADD"
    remap.inputs[1].default_value = 0.5
    remap.inputs[2].default_value = 0.5
    links.new(dot.outputs["Value"], remap.inputs[0])
    ao = nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 32
    ao.inputs["Distance"].default_value = 0.18
    mult = nodes.new("ShaderNodeMath")
    mult.operation = "MULTIPLY"
    links.new(remap.outputs[0], mult.inputs[0])
    links.new(ao.outputs["AO"], mult.inputs[1])
    rampa = nodes.new("ShaderNodeValToRGB")
    rampa.color_ramp.interpolation = "CONSTANT"
    escura = clampc(mais(base, (0.012, 0.022, 0.058), 0.36))
    sombra = clampc(mais(base, (0.008, 0.014, 0.034), 0.64))
    luz = clampc(mais(base, (0.075, 0.042, 0.004), 1.10))
    for i, (pos, cor) in enumerate([(0.0, escura), (0.30, sombra), (0.52, base), (0.76, luz)]):
        el = rampa.color_ramp.elements[i] if i < 2 else rampa.color_ramp.elements.new(pos)
        el.position = pos
        el.color = lin(cor)
    links.new(mult.outputs[0], rampa.inputs[0])
    dot2 = nodes.new("ShaderNodeVectorMath")
    dot2.operation = "DOT_PRODUCT"
    dot2.inputs[1].default_value = LUZ_CONTRA
    links.new(geo.outputs["Normal"], dot2.inputs[0])
    borda = nodes.new("ShaderNodeMath")
    borda.operation = "GREATER_THAN"
    borda.inputs[1].default_value = 0.58
    links.new(dot2.outputs["Value"], borda.inputs[0])
    fac = nodes.new("ShaderNodeMath")
    fac.operation = "MULTIPLY"
    fac.inputs[1].default_value = 0.55
    links.new(borda.outputs[0], fac.inputs[0])
    mix = nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MIX"
    mix.inputs["Color2"].default_value = lin(clampc(mais(base, (0.09, 0.16, 0.30), 0.55)))
    links.new(fac.outputs[0], mix.inputs["Fac"])
    links.new(rampa.outputs["Color"], mix.inputs["Color1"])
    links.new(mix.outputs["Color"], emissao.inputs["Color"])
    emissao.inputs["Strength"].default_value = 1.0
    material.diffuse_color = lin(base)


def emissivo(material, cor, forca=1.0):
    nodes = material.node_tree.nodes
    nodes.clear()
    saida = nodes.new("ShaderNodeOutputMaterial")
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = lin(cor)
    em.inputs["Strength"].default_value = forca
    material.node_tree.links.new(em.outputs[0], saida.inputs["Surface"])


usados = {m.name for o in heroi if hasattr(o.data, "materials") for m in o.data.materials if m}
for m in list(bpy.data.materials):
    if m.name not in usados or not m.use_nodes:
        continue
    if m.name in BRILHANTES:
        emissivo(m, hexa(BRILHANTES[m.name]))
    elif m.name == "Olho":
        emissivo(m, hexa(PALETA["Olho"]))
    elif m.name in PALETA:
        estilizar(m, hexa(PALETA[m.name]))
    else:
        raise RuntimeError("material sem cor na paleta: " + m.name)

# material da passada de NORMAL (espaço de câmera; Z invertido, medido no Blender 4.5: igual ao do pipeline do jogo)
mat_normal = bpy.data.materials.new("passe_normal")
mat_normal.use_nodes = True
_nt = mat_normal.node_tree
_nt.nodes.clear()
_geo, _tr = _nt.nodes.new("ShaderNodeNewGeometry"), _nt.nodes.new("ShaderNodeVectorTransform")
_tr.vector_type, _tr.convert_from, _tr.convert_to = "NORMAL", "WORLD", "CAMERA"
_mad = _nt.nodes.new("ShaderNodeVectorMath")
_mad.operation = "MULTIPLY_ADD"
_mad.inputs[1].default_value = (0.5, 0.5, -0.5)
_mad.inputs[2].default_value = (0.5, 0.5, 0.5)
_emi, _out = _nt.nodes.new("ShaderNodeEmission"), _nt.nodes.new("ShaderNodeOutputMaterial")
_nt.links.new(_geo.outputs["Normal"], _tr.inputs["Vector"])
_nt.links.new(_tr.outputs["Vector"], _mad.inputs[0])
_nt.links.new(_mad.outputs["Vector"], _emi.inputs["Color"])
_nt.links.new(_emi.outputs["Emission"], _out.inputs["Surface"])

# ============================================================ 3. contorno: casca invertida no tom ESCURO DA PRÓPRIA COR
cascas = {}


def material_contorno(m):
    if m.name in cascas:
        return cascas[m.name]
    base = hexa(PALETA.get(m.name, "#4a5a70"))
    escuro = clampc(mais(base, (0.010, 0.014, 0.034), 0.20))
    novo = bpy.data.materials.new("Contorno " + m.name)
    novo.use_nodes = True
    n = novo.node_tree.nodes
    n.clear()
    sai, mx, geo = n.new("ShaderNodeOutputMaterial"), n.new("ShaderNodeMixShader"), n.new("ShaderNodeNewGeometry")
    transp, em = n.new("ShaderNodeBsdfTransparent"), n.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = lin(escuro)
    lk = novo.node_tree.links
    lk.new(geo.outputs["Backfacing"], mx.inputs[0])
    lk.new(transp.outputs[0], mx.inputs[1])
    lk.new(em.outputs[0], mx.inputs[2])
    lk.new(mx.outputs[0], sai.inputs["Surface"])
    cascas[m.name] = novo
    return novo


bpy.context.view_layer.update()
S = Matrix.Diagonal((ESCALA * LARGURA, ESCALA, ESCALA))
CASCAS = []
for original in list(heroi):
    if original.type != "MESH" or len(original.data.polygons) < 6 or original.name.startswith(("Olho", "Sobrancelha")):
        continue
    mats = [m for m in original.data.materials if m]
    if not mats:
        continue
    copia = original.copy()
    copia.data = original.data.copy()
    copia.name = "Contorno — " + original.name
    bpy.context.collection.objects.link(copia)
    A = S @ original.matrix_world.to_3x3()
    Ai = A.inverted()
    for v in copia.data.vertices:
        v.co = v.co + Ai @ ((Ai.transposed() @ v.normal).normalized() * CONTORNO)
    copia.data.update()
    copia.data.materials.clear()
    copia.data.materials.append(material_contorno(mats[0]))
    copia.visible_shadow = False
    OSSO_DE[copia] = OSSO_DE[original]
    CASCAS.append(copia)
heroi += CASCAS

# ============================================================ 4. RIG: armature com joelho e cotovelo; peças presas por osso
arm_data = bpy.data.armatures.new("Hazaki")
arm = bpy.data.objects.new("Hazaki rig", arm_data)
bpy.context.collection.objects.link(arm)
arm.location = (0.0, HY, 0.0)      # o pivô do herói é o próprio armature: escala e giro por direção ficam nele
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")


def L(nome):
    """Posição da articulação em coordenadas do armature (mundo do modelo menos o deslocamento H do Codex)."""
    p = PONTOS[nome]
    return Vector((p[0], p[1] - HY, p[2]))


def osso(nome, cabeca, cauda, pai=None):
    eb = arm_data.edit_bones.new(nome)
    eb.head, eb.tail = cabeca, cauda
    eixo_x = Vector((1.0, 0.0, 0.0))
    dirv = (cauda - cabeca).normalized()
    eb.align_roll(eixo_x.cross(dirv))      # eixo X local = X do mundo em todos os ossos (ver ossos.py)
    if pai:
        eb.parent = arm_data.edit_bones[pai]
    return eb


osso("raiz", Vector((0, 0, 0)), Vector((0, 0.3, 0)))
osso("quadril", Vector((0, 0, 1.50)), Vector((0, 0, 1.70)), "raiz")
osso("torso", Vector((0, 0, 1.70)), Vector((0, 0, 2.40)), "quadril")
osso("cabeca", Vector((0, 0, 2.45)), Vector((0, 0, 3.20)), "torso")
for sfx in ("_e", "_d"):
    osso("braco" + sfx, L("ombro" + sfx), L("cotovelo" + sfx), "torso")
    osso("antebraco" + sfx, L("cotovelo" + sfx), L("punho" + sfx), "braco" + sfx)
    osso("perna" + sfx, L("quadril" + sfx), L("joelho" + sfx), "quadril")
    osso("canela" + sfx, L("joelho" + sfx), L("tornozelo" + sfx), "perna" + sfx)
    osso("pe" + sfx, L("tornozelo" + sfx), L("tornozelo" + sfx) + Vector((0, -0.20, -0.25)), "canela" + sfx)
bpy.ops.object.mode_set(mode="OBJECT")
assert set(b.name for b in arm_data.bones) == set(ossos.OSSOS), "ossos fora de ossos.OSSOS"
arm.show_in_front = True
bpy.context.view_layer.update()


def prender(o, nome_osso):
    """Prende o objeto ao osso mantendo a posição do mundo (a matriz do pai de osso é medida, não presumida)."""
    o.parent = arm
    o.parent_type = "BONE"
    o.parent_bone = nome_osso
    o.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    pai = o.matrix_world @ o.matrix_basis.inverted()
    o.matrix_parent_inverse = pai.inverted()


for o in heroi:
    prender(o, OSSO_DE[o])
bpy.context.view_layer.update()
arm.scale = (ESCALA * LARGURA, ESCALA, ESCALA)
arm["chao"] = 0.0
arm["chao"] = ossos._min_z_botas(arm)      # altura da sola das botas em repouso = chão

CORPO = [o for o in heroi if o not in CASCAS]
MAT_COR = {o: list(o.data.materials) for o in CORPO}

# ============================================================ 5. cena: Cycles pixel nativo, câmera do jogo
cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.device = "CPU"
cena.cycles.samples = 1
cena.cycles.use_denoising = False
cena.cycles.pixel_filter_type = "BOX"
cena.cycles.filter_width = 0.01
cena.cycles.max_bounces = 3
cena.cycles.transparent_max_bounces = 16
cena.render.film_transparent = True
cena.render.resolution_x, cena.render.resolution_y, cena.render.resolution_percentage = W, H, 100
cena.render.image_settings.file_format = "PNG"
cena.render.image_settings.color_mode = "RGBA"
cena.render.image_settings.color_depth = "8"
cena.render.dither_intensity = 0
cena.view_settings.look = "None"
cena.view_settings.exposure = 0
cena.view_settings.gamma = 1
cena.render.threads_mode = "FIXED"
cena.render.threads = 6

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = max(W, H) / PPU
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.collection.objects.link(cam)
el = math.radians(ELEV)
cam.location = (0.0, -20.0 * math.cos(el), 20.0 * math.sin(el))
cam.rotation_euler = (math.pi / 2 - el, 0.0, 0.0)
cena.camera = cam

TMP = Path(os.environ.get("TEMP", "/tmp")) / (NOME + "_gerar_%d" % os.getpid())
TMP.mkdir(parents=True, exist_ok=True)


def renderizar(caminho, normal=False):
    """Renderiza um quadro. Cor: sRGB 'Standard'. Normal: 'Raw' (o número escrito é o número do material) e sem as cascas do contorno."""
    cena.view_settings.view_transform = "Raw" if normal else "Standard"
    for c in CASCAS:
        c.hide_render = normal
    for o in CORPO:
        o.data.materials[0] = mat_normal if normal else MAT_COR[o][0]
    cena.render.filepath = str(caminho)
    bpy.ops.render.render(write_still=True)


def ler(caminho, cru):
    img = bpy.data.images.load(str(caminho), check_existing=False)
    if cru:
        img.colorspace_settings.name = "Non-Color"
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1].copy()
    bpy.data.images.remove(img)
    return px


def gravar_normal(px, caminho):
    img = bpy.data.images.new("n", W, H, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels[:] = px[::-1].ravel()
    img.filepath_raw = str(caminho)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


# calibra: o fundo do desenho (com contorno) cai na linha PE_LINHA, no repouso de frente; vale para todas as animações
ossos.zerar(arm)
ossos.pisar(arm)
arm.rotation_euler = (0, 0, 0)
renderizar(TMP / "calibra.png")
px = ler(TMP / "calibra.png", False)
ys, xs = np.nonzero(px[:, :, 3] > 0.5)
dy = ys.max() - PE_LINHA
cam_data.shift_y = -dy / max(W, H)
ossos.calibrar(arm, ELEV)
LOC0 = Vector(arm["loc0"])
print("calibragem: caixa y %d..%d x %d..%d (largura %d px); desloca %d px" % (ys.min(), ys.max(), xs.min(), xs.max(), xs.max() - xs.min() + 1, dy))


def animacoes():
    achadas = sorted(p.stem[len("anim_"):] for p in AQUI.glob("anim_*.py"))
    if SO_ANIM:
        if SO_ANIM not in achadas:
            raise SystemExit("animação '%s' não existe; há: %s" % (SO_ANIM, ", ".join(achadas)))
        return [SO_ANIM]
    return achadas


def projetar(co):
    """Ponto do mundo -> (x, y) em pixels do quadro (y para baixo), pela câmera do jogo."""
    v = world_to_camera_view(cena, cam, co)
    return v.x * W, (1.0 - v.y) * H


def pintar_poligonos(cor, normal, mascara, poligonos):
    """Efeitos 2D de golpe (rastro da lâmina): poligonos = [(pontos_no_mundo, (r, g, b) 0-255), ...]. Pinta só onde o corpo NÃO está (o rastro
    fica atrás do herói), sem meio-tom (alfa 1), e na normal usa a normal reta (contorno). Altera cor e normal no lugar."""
    ys, xs = np.mgrid[0:H, 0:W]
    cx, cy = xs + 0.5, ys + 0.5
    for pts, rgb in poligonos:
        p = [projetar(Vector(q)) for q in pts]
        dentro = np.zeros((H, W), bool)
        for i in range(1, len(p) - 1):
            (ax, ay), (bx, by), (qx, qy) = p[0], p[i], p[i + 1]
            d = (by - qy) * (ax - qx) + (qx - bx) * (ay - qy)
            if abs(d) < 1e-9:
                continue
            l1 = ((by - qy) * (cx - qx) + (qx - bx) * (cy - qy)) / d
            l2 = ((qy - ay) * (cx - qx) + (ax - qx) * (cy - qy)) / d
            dentro |= (l1 >= 0) & (l2 >= 0) & (1 - l1 - l2 >= 0)
        dentro &= ~mascara
        cor[dentro] = (rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, 1.0)
        normal[dentro] = (0.5, 0.5, 1.0, 1.0)


def renderizar_animacao(nome):
    mod = importlib.import_module("anim_" + nome)
    n = mod.N_QUADROS
    pasta = SAIDA / nome
    pasta.mkdir(parents=True, exist_ok=True)
    usa_ang = len(inspect.signature(mod.posar).parameters) >= 4          # posar(arm, quadro, n, ang): ang = giro do herói na direção
    efeito = getattr(mod, "efeito", None)                                # efeito(arm, quadro, n, ang) -> polígonos 2D do golpe (ver pintar_poligonos)
    if perfil and hasattr(perfil, "efeito"):
        efeito = perfil.efeito(nome, efeito)                             # o perfil pode trocar ou tirar o efeito da animação (ex.: sem rastro de lâmina no leque)
    for q in range(n):
        for dname, ang in DIRECOES:
            ossos.zerar(arm)
            arm.location = LOC0
            arm.rotation_euler = (0, 0, math.radians(ang))
            if usa_ang:
                mod.posar(arm, q, n, ang)
            else:
                mod.posar(arm, q, n)
            if perfil and hasattr(perfil, "quadro"):
                perfil.quadro(nome, q, n)                                # o perfil mostra/esconde peças por animação e quadro (ex.: leque aberto no golpe)
            bpy.context.view_layer.update()
            base = pasta / ("%s_%d" % (dname, q))
            renderizar(str(base) + "_cor.png")
            cor = ler(str(base) + "_cor.png", False)
            mascara = cor[:, :, 3] > 0.5
            tmp = TMP / "n.png"
            renderizar(tmp, normal=True)
            nor = normais.pos_normal(ler(tmp, True), mascara)
            polis = efeito(arm, q, n, ang) if efeito else []
            if polis:
                cor = ler(str(base) + "_cor.png", True)
                pintar_poligonos(cor, nor, mascara, polis)
                gravar_normal(cor, str(base) + "_cor.png")
            gravar_normal(nor, str(base) + "_normal.png")
    arm.location = LOC0
    arm.rotation_euler = (0, 0, 0)
    print("ANIM_OK %s: %d quadros x %d direções" % (nome, n, len(DIRECOES)))


for nome in animacoes():
    renderizar_animacao(nome)

ossos.zerar(arm)
for c in CASCAS:
    c.hide_render = False
for o in CORPO:
    o.data.materials[0] = MAT_COR[o][0]
arm.rotation_euler = (0, 0, 0)
if not SO_ANIM:
    bpy.ops.wm.save_as_mainfile(filepath=str(SAIDA.parent / (NOME + "_rig.blend")), compress=True)
shutil.rmtree(TMP, ignore_errors=True)
print("HAZAKI_OK")
