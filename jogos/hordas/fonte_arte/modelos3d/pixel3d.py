"""Modelos 3D -> pixel art (direção de arte da #6: dark fantasy, render 3D com cara de pixel art).

Base usada por cada modelo (ex.: cavaleiro.py). Roda dentro do Blender 4.5 LTS (portátil, grátis):
    blender -b -P cavaleiro.py

Regras pra sair pixel art, e não "3D borrado":
- renderiza JÁ no tamanho final (ex.: 44x60 por quadro), sem antialiasing;
- sombreamento em faixas (toon, 3 tons), como um pixel artist sombreia;
- UMA luz, de cima à esquerda (a mesma das sombras do jogo, scripts/hordas/visual.gd);
- paleta fixa dark fantasy + contorno escuro de 1 px.
"""
import math
import os
import tempfile

import bpy
import numpy as np
from mathutils import Vector

# ---------------------------------------------------------------- paleta dark fantasy
# ferro frio, couro, sangue, ouro velho, osso e musgo, sobre pretos arroxeados
PALETA_HEX = [
    "0d0b14", "1d1a2b", "2e2a40", "45405c", "6b6585", "9a94b0", "c9c3d6", "ece8f2",   # sombra -> aço
    "2a0d14", "4f1520", "7e2027", "b0342f", "d9614a",                                 # sangue
    "2b1d18", "4a3324", "6e4c32", "9a6d45",                                           # couro / madeira
    "5c4320", "8f6a2e", "c49a45", "eccb7a",                                           # ouro velho
    "1f2a24", "35473a", "566e55",                                                     # musgo
    "a89e86", "d6ccb2",                                                               # osso
]
PALETA = np.array([[int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] for h in PALETA_HEX])
CONTORNO = PALETA[0]

# rampas de cada material (do escuro pro claro): a luz de borda sobe um degrau DENTRO da rampa
RAMPAS = [PALETA_HEX[0:8], PALETA_HEX[8:13], PALETA_HEX[13:17], PALETA_HEX[17:21], PALETA_HEX[21:24], PALETA_HEX[24:26]]
DEGRAU_ACIMA = {PALETA_HEX.index(r[k]): PALETA_HEX.index(r[k + 1]) for r in RAMPAS for k in range(len(r) - 1)}


def paleta_sem(*hexas):
    """Paleta sem algumas cores (cada material só deve usar a rampa dele; ex.: cavaleiro sem musgo e osso)."""
    return np.array([c for h, c in zip(PALETA_HEX, PALETA) if h not in hexas])


def linear(v):
    """sRGB (o que a gente vê e escreve em hexa) -> linear (o que os nós de cor do Blender esperam)."""
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def cor(hexa):
    return tuple(linear(int(hexa[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


# ---------------------------------------------------------------- cena

def limpar_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def preparar_render(largura, altura):
    cena = bpy.context.scene
    try:
        cena.render.engine = "BLENDER_EEVEE_NEXT"   # Blender 4.2 a 4.5
    except TypeError:
        cena.render.engine = "BLENDER_EEVEE"        # Blender 5
    cena.render.resolution_x = largura
    cena.render.resolution_y = altura
    cena.render.resolution_percentage = 100
    cena.render.film_transparent = True
    cena.render.filter_size = 0.0              # sem antialiasing: pixel cheio ou vazio
    cena.eevee.taa_render_samples = 1
    cena.render.image_settings.file_format = "PNG"
    cena.render.image_settings.color_mode = "RGBA"
    cena.view_settings.view_transform = "Standard"   # cor "crua", pra paleta bater
    cena.world = bpy.data.worlds.new("mundo")
    cena.world.color = (0.0, 0.0, 0.0)
    return cena


def camera(elevacao_graus=32.0, escala=2.4):
    """Câmera ortográfica olhando o personagem de frente, um pouco de cima (o '3/4' do jogo)."""
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = escala
    obj = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(obj)
    el = math.radians(elevacao_graus)
    obj.location = (0.0, -20.0 * math.cos(el), 20.0 * math.sin(el))
    obj.rotation_euler = (math.pi / 2 - el, 0.0, 0.0)
    bpy.context.scene.camera = obj
    return obj


def luz():
    """Luz principal de cima, da esquerda e de trás (igual às sombras do jogo) + preenchimento fraco do lado da câmera."""
    def sol(nome, direcao, forca):
        d = bpy.data.lights.new(nome, "SUN")
        d.energy = forca
        d.angle = 0.0
        d.use_shadow = False   # sombra própria em 44 px vira chiado; o volume vem das faixas do toon
        o = bpy.data.objects.new(nome, d)
        bpy.context.collection.objects.link(o)
        o.rotation_euler = Vector(direcao).normalized().to_track_quat("-Z", "Y").to_euler()
        return o
    sol("principal", (1.0, -0.55, -1.4), 4.0)   # viaja pra direita, pra câmera e pra baixo = vem de cima/esquerda/trás (igual às sombras do jogo)
    sol("preenche", (0.25, 1.0, -0.45), 1.2)   # fraca, do lado da câmera: a frente não vira borrão


def material_toon(nome, cor_base, faixas=(0.35, 0.62, 1.0)):
    """Difuso -> faixas constantes (3 tons) x cor base -> emissão. Sombreamento de pixel art."""
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    n = m.node_tree.nodes
    l = m.node_tree.links
    n.clear()
    dif = n.new("ShaderNodeBsdfDiffuse")
    s2r = n.new("ShaderNodeShaderToRGB")
    rampa = n.new("ShaderNodeValToRGB")
    rampa.color_ramp.interpolation = "CONSTANT"
    els = rampa.color_ramp.elements
    els[0].position = 0.0
    els[0].color = (linear(faixas[0]),) * 3 + (1,)
    els[1].position = 0.22
    els[1].color = (linear(faixas[1]),) * 3 + (1,)
    e3 = els.new(0.55)
    e3.color = (linear(faixas[2]),) * 3 + (1,)
    mult = n.new("ShaderNodeMix")
    mult.data_type = "RGBA"
    mult.blend_type = "MULTIPLY"
    mult.inputs[0].default_value = 1.0
    mult.inputs[7].default_value = cor_base
    emi = n.new("ShaderNodeEmission")
    out = n.new("ShaderNodeOutputMaterial")
    l.new(dif.outputs[0], s2r.inputs[0])
    l.new(s2r.outputs[0], rampa.inputs[0])
    l.new(rampa.outputs[0], mult.inputs[6])
    l.new(mult.outputs[2], emi.inputs[0])
    l.new(emi.outputs[0], out.inputs[0])
    return m


# ---------------------------------------------------------------- render e pós

def render_rgba():
    """Renderiza o quadro atual e devolve um array (altura, largura, 4), com a linha 0 em CIMA."""
    caminho = os.path.join(tempfile.gettempdir(), "pixel3d_quadro.png")
    bpy.context.scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(caminho, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    return px


def pixelar(px, contorno=True, paleta=None, luz_borda=True):
    """Alfa binário, cor na paleta mais próxima e contorno escuro de 1 px por fora da silhueta."""
    out = np.zeros_like(px)
    pal = PALETA if paleta is None else paleta
    cheio = px[:, :, 3] > 0.5
    rgb = px[:, :, :3][cheio]
    if len(rgb):
        # distância "redmean" (aproxima como o olho vê cor): respeita o matiz, não só o brilho,
        # senão vermelho escuro vira marrom
        a = rgb[:, None, :]
        b = pal[None, :, :]
        rm = (a[..., 0] + b[..., 0]) / 2.0
        dif = (a - b) ** 2
        d = (2.0 + rm) * dif[..., 0] + 4.0 * dif[..., 1] + (3.0 - rm) * dif[..., 2]
        out[:, :, :3][cheio] = pal[d.argmin(axis=1)]
        out[:, :, 3][cheio] = 1.0
    if luz_borda and len(rgb):
        # luz de borda: pixel opaco com vazio em cima ou à esquerda (o lado da luz) sobe um degrau na rampa
        # do próprio material. É o que dá volume num sprite pequeno sem trocar a cor.
        vazio = ~cheio
        lado_luz = np.zeros_like(cheio)
        lado_luz[1:, :] |= vazio[:-1, :]
        lado_luz[0, :] = True
        lado_luz[:, 1:] |= vazio[:, :-1]
        lado_luz[:, 0] = True
        alvo = cheio & lado_luz
        antes = out[:, :, :3].copy()   # compara com a cor ORIGINAL (senão sobe em cascata até o topo)
        for i, j in DEGRAU_ACIMA.items():
            mesmo = alvo & np.all(np.abs(antes - PALETA[i]) < 1e-4, axis=2)
            out[:, :, :3][mesmo] = PALETA[j]
    if contorno:
        viz = np.zeros_like(cheio)
        viz[1:, :] |= cheio[:-1, :]
        viz[:-1, :] |= cheio[1:, :]
        viz[:, 1:] |= cheio[:, :-1]
        viz[:, :-1] |= cheio[:, 1:]
        borda = viz & ~cheio
        out[:, :, :3][borda] = CONTORNO
        out[:, :, 3][borda] = 1.0
    return out


def caixa_alfa(px):
    """(x0, y0, x1, y1) dos pixels opacos, com y0 em cima."""
    ys, xs = np.nonzero(px[:, :, 3] > 0.5)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max(), ys.max()


def calibrar_pe(cam, pe_y, largura, altura):
    """Desloca a câmera pra o pé do modelo cair na linha pe_y e o corpo ficar centrado na largura."""
    cam.data.shift_x = 0.0
    cam.data.shift_y = 0.0
    cx = caixa_alfa(render_rgba())
    if cx is None:
        raise RuntimeError("o modelo não apareceu no render")
    maior = max(largura, altura)
    dx = (cx[0] + cx[2]) / 2.0 - (largura - 1) / 2.0
    dy = cx[3] - pe_y
    cam.data.shift_x = dx / maior
    cam.data.shift_y = -dy / maior          # linha da imagem cresce pra baixo; shift_y cresce pra cima


def salvar_png(px, caminho):
    h, w = px.shape[:2]
    img = bpy.data.images.new("saida", w, h, alpha=True)
    img.pixels[:] = px[::-1].ravel()
    img.filepath_raw = caminho
    img.file_format = "PNG"
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    img.save()
    bpy.data.images.remove(img)
