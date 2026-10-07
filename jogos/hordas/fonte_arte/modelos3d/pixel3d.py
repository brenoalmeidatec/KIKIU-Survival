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
# Cada material usa UMA rampa (do escuro pro claro), como num pixel art desenhado à mão.
# A luz de borda sobe um degrau dentro da rampa; cada modelo/cenário escolhe as rampas que usa.
RAMPA = {
    "aco": ["0d0b14", "1d1a2b", "2e2a40", "45405c", "6b6585", "9a94b0", "c9c3d6", "ece8f2"],   # sombra -> aço frio
    "sangue": ["2a0d14", "4f1520", "7e2027", "b0342f", "d9614a"],
    "couro": ["2b1d18", "4a3324", "6e4c32", "9a6d45"],                                         # couro / madeira
    "ouro": ["5c4320", "8f6a2e", "c49a45", "eccb7a"],
    "musgo": ["1f2a24", "35473a", "566e55"],
    "osso": ["a89e86", "d6ccb2"],
    "pedra": ["141211", "1f1b19", "2c2724", "3a3430", "4a423b", "5e544a", "766a5d", "958775", "b8a892"],   # pedra quente (muitos tons: chão)
    "veneno": ["0f2a1c", "1d4a2a", "2f7a3a", "56b04a", "a6e070", "e4ffb0"],                    # brilho alquímico
    "fogo": ["3a1408", "7a2c0c", "c45a14", "f0921e", "ffd060", "fff2b0"],                      # tocha, vela
    "noite": ["0b1020", "152040", "223566", "3a5794", "6f8fc8"],                               # cidade à noite
    "pele": ["3b2219", "6b3f2a", "9c6444", "c98e62", "e8b98e"],                               # pele (Hazaki)
    "cobalto": ["0a1030", "142a6e", "2a4fc0", "4073ff", "8cd9ff", "e0f6ff"],                  # energia do Hazaki (aura, dragão)
    "folha": ["11190e", "1d2e17", "2d4721", "466a2c", "6a943d"],                            # copa de árvore, mato (floresta, #64)
}
# Rampas extras (só entram numa paleta se pedidas por nome em paleta_de; NÃO fazem parte de PALETA global,
# então cavaleiro/dragão/cenários não mudam). Usadas pelo Hazaki de regata preta e calça cargo.
RAMPA_EXTRA = {
    "hz_neutro": ["0d0d10", "1a1618", "2a2426", "3d3335", "5e504b", "7d6e65", "a89a8e", "d0c4b6"],   # preto -> cinza encardido -> faixa suja
    "hz_pele": ["3e261e", "6d4332", "b16e52", "d29a78", "e8bb9c"],                                   # pele bronzeada
    "hz_sangue": ["3a0c0d", "75191a", "a52a26"],                                                     # pano vermelho, sangue
    "areia": ["2a2015", "4a3a24", "7a6038", "a8884e", "cdb06e", "e6d3a0"],                           # areia, linho velho (deserto, #64)
    "lapis": ["0f1f3a", "1d3a6a", "2f63a0", "4f9ac8", "8fd0e0"],                                     # azul de faiança (escaravelhos)
    "gelo": ["16202e", "2a3d52", "4a6a88", "7fa6c4", "b8d8ec", "e8f6ff"],                           # gelo, neve e geada (pico, #64)
    "caos": ["1a0a1f", "3d1046", "6e1a6e", "a62a8f", "e04aa8", "ff9ad8"],                           # energia do caos (reino sombrio)
}
PALETA_HEX = [h for r in RAMPA.values() for h in r]
PALETA = np.array([[int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] for h in PALETA_HEX])
CONTORNO = PALETA[0]
RAMPAS = list(RAMPA.values())
DEGRAU_ACIMA = {PALETA_HEX.index(r[k]): PALETA_HEX.index(r[k + 1]) for r in RAMPAS for k in range(len(r) - 1)}


def _rgb(h):
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# degraus de "luz de borda" das rampas extras: (cor, cor um degrau acima)
DEGRAU_EXTRA = [(_rgb(r[k]), _rgb(r[k + 1])) for r in RAMPA_EXTRA.values() for k in range(len(r) - 1)]


def paleta_sem(*hexas):
    """Paleta sem algumas cores (cada material só deve usar a rampa dele; ex.: cavaleiro sem musgo e osso)."""
    return np.array([c for h, c in zip(PALETA_HEX, PALETA) if h not in hexas])


def paleta_de(*rampas):
    """Só as rampas pedidas, mais o preto do contorno (ex.: paleta_de("pedra", "fogo", "osso"))."""
    hexas = {"0d0b14"} | {h for r in rampas for h in (RAMPA[r] if r in RAMPA else RAMPA_EXTRA[r])}
    base = [c for h, c in zip(PALETA_HEX, PALETA) if h in hexas]
    extra = [_rgb(h) for r in RAMPA_EXTRA.values() for h in r if h in hexas]
    return np.array(base + extra)


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


def preparar_suave(largura, altura, fator=4, amostras=48):
    """Render "pré-renderizado" (técnica de Donkey Kong Country / Diablo): Cycles com luz e sombra reais e oclusão
    nas frestas, em 'fator' vezes o tamanho. Depois reduzir() faz a média e pixelar(pontilhado=...) põe na paleta."""
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = amostras
    cena.cycles.use_denoising = True
    cena.render.resolution_x = largura * fator
    cena.render.resolution_y = altura * fator
    cena.render.resolution_percentage = 100
    cena.render.film_transparent = True
    cena.render.image_settings.file_format = "PNG"
    cena.render.image_settings.color_mode = "RGBA"
    cena.view_settings.view_transform = "Standard"
    cena.world = bpy.data.worlds.new("mundo")
    cena.world.use_nodes = True
    fundo = cena.world.node_tree.nodes.get("Background")
    fundo.inputs[0].default_value = (0.32, 0.34, 0.45, 1.0)   # céu fraco e frio: preenche as sombras sem chapar
    fundo.inputs[1].default_value = 0.35
    return cena


def reduzir(px, fator):
    """Média de cada bloco fator x fator (guarda a informação de luz e textura do render grande)."""
    h, w = px.shape[0] // fator, px.shape[1] // fator
    return px[:h * fator, :w * fator].reshape(h, fator, w, fator, 4).mean(axis=(1, 3))


def material_suave(nome, cor_base, rugosidade=0.85, relevo=0.0, variacao=0.0, escala=4.0):
    """Material pra render suave (Cycles): cor + rugosidade, a luz faz o resto.
    relevo > 0: ruído no relevo (bump) -> sob luz rasante vira micro sombra e brilho, textura de pedra.
    variacao > 0: ruído na cor (manchas mais claras e mais escuras)."""
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    n = m.node_tree.nodes
    l = m.node_tree.links
    p = n.get("Principled BSDF")
    p.inputs["Base Color"].default_value = cor_base
    p.inputs["Roughness"].default_value = rugosidade
    if relevo > 0 or variacao > 0:
        coord = n.new("ShaderNodeTexCoord")
        ruido = n.new("ShaderNodeTexNoise")
        ruido.inputs["Scale"].default_value = escala
        ruido.inputs["Detail"].default_value = 6.0
        l.new(coord.outputs["Object"], ruido.inputs["Vector"])
        if relevo > 0:
            bump = n.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = relevo
            l.new(ruido.outputs["Fac"], bump.inputs["Height"])
            l.new(bump.outputs["Normal"], p.inputs["Normal"])
        if variacao > 0:
            mix = n.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            rampa = n.new("ShaderNodeMapRange")
            rampa.inputs["To Min"].default_value = 1.0 - variacao
            rampa.inputs["To Max"].default_value = 1.0 + variacao
            l.new(ruido.outputs["Fac"], rampa.inputs["Value"])
            mix.inputs[0].default_value = 1.0
            mix.inputs[6].default_value = cor_base
            comb = n.new("ShaderNodeCombineColor")
            for k in range(3):
                l.new(rampa.outputs["Result"], comb.inputs[k])
            l.new(comb.outputs[0], mix.inputs[7])
            l.new(mix.outputs[2], p.inputs["Base Color"])
    return m


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


def luz(rasante=False, suave=False, preenche=1.2):
    """Luz principal de cima, da esquerda e de trás (igual às sombras do jogo) + preenchimento fraco do lado da câmera.
    suave=True (render pré-renderizado no Cycles): sombra real e macia; o céu do mundo faz o preenchimento."""
    def sol(nome, direcao, forca):
        d = bpy.data.lights.new(nome, "SUN")
        d.energy = forca
        d.angle = math.radians(4.0) if suave else 0.0
        d.use_shadow = suave   # no toon, sombra própria em 44 px vira chiado; no suave, é a graça
        o = bpy.data.objects.new(nome, d)
        bpy.context.collection.objects.link(o)
        o.rotation_euler = Vector(direcao).normalized().to_track_quat("-Z", "Y").to_euler()
        return o
    if suave:
        sol("principal", (1.0, -0.55, -0.75) if rasante else (1.0, -0.55, -1.4), 3.2)
        return
    sol("principal", (1.0, -0.55, -0.6) if rasante else (1.0, -0.55, -1.4), 4.0)   # viaja pra direita, pra câmera e pra baixo = vem de cima/esquerda/trás (igual às sombras do jogo)
    sol("preenche", (0.25, 1.0, -0.45), preenche)   # do lado da câmera: a frente não vira borrão (rosto pede mais)


def material_toon(nome, cor_base, faixas=(0.35, 0.62, 1.0), limites=(0.22, 0.55), ruido=0.0, escala_ruido=6.0):
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
    els[1].position = limites[0]
    els[1].color = (linear(faixas[1]),) * 3 + (1,)
    e3 = els.new(limites[1])
    e3.color = (linear(faixas[2]),) * 3 + (1,)
    mult = n.new("ShaderNodeMix")
    mult.data_type = "RGBA"
    mult.blend_type = "MULTIPLY"
    mult.inputs[0].default_value = 1.0
    mult.inputs[7].default_value = cor_base
    emi = n.new("ShaderNodeEmission")
    out = n.new("ShaderNodeOutputMaterial")
    l.new(dif.outputs[0], s2r.inputs[0])
    if ruido > 0:
        # ruído sutil na luz ANTES das faixas: vira aglomerado de pixels (textura de pedra), não chiado
        tex = n.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = escala_ruido
        mapa = n.new("ShaderNodeMapRange")
        mapa.inputs["To Min"].default_value = 1.0 - ruido
        mapa.inputs["To Max"].default_value = 1.0 + ruido
        mul = n.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        l.new(tex.outputs["Fac"], mapa.inputs["Value"])
        l.new(s2r.outputs[0], mul.inputs[0])
        l.new(mapa.outputs["Result"], mul.inputs[1])
        l.new(mul.outputs[0], rampa.inputs[0])
    else:
        l.new(s2r.outputs[0], rampa.inputs[0])
    l.new(rampa.outputs[0], mult.inputs[6])
    l.new(mult.outputs[2], emi.inputs[0])
    l.new(emi.outputs[0], out.inputs[0])
    return m


# ---------------------------------------------------------------- render e pós

def render_rgba():
    """Renderiza o quadro atual e devolve um array (altura, largura, 4), com a linha 0 em CIMA."""
    caminho = os.path.join(tempfile.gettempdir(), "pixel3d_quadro_%d.png" % os.getpid())
    bpy.context.scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(caminho, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    return px


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def pixelar(px, contorno=True, paleta=None, luz_borda=True, pontilhado=0.0):
    """Alfa binário, cor na paleta mais próxima e contorno escuro de 1 px por fora da silhueta.
    pontilhado > 0: pontilhado ordenado (Bayer 4x4) antes de escolher a cor, que vira textura de pixel art."""
    out = np.zeros_like(px)
    pal = PALETA if paleta is None else paleta
    cheio = px[:, :, 3] > 0.5
    rgb = px[:, :, :3][cheio]
    if len(rgb) and pontilhado > 0:
        ys, xs = np.nonzero(cheio)
        rgb = rgb + ((BAYER[ys % 4, xs % 4] - 0.5) * pontilhado)[:, None]
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
        for de, para in DEGRAU_EXTRA:
            mesmo = alvo & np.all(np.abs(antes - de) < 1e-4, axis=2)
            out[:, :, :3][mesmo] = para
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


# ---------------------------------------------------------------- cenários (piso, enfeites, luzes)

def material_emissao(nome, cor_base, forca=1.0):
    """Material que brilha sozinho (chama, frasco, janela acesa): não passa pelas faixas do toon."""
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    n = m.node_tree.nodes
    n.clear()
    emi = n.new("ShaderNodeEmission")
    emi.inputs[0].default_value = cor_base
    emi.inputs[1].default_value = forca
    out = n.new("ShaderNodeOutputMaterial")
    m.node_tree.links.new(emi.outputs[0], out.inputs[0])
    return m


def camera_topo(lado_mundo):
    """Câmera ortográfica olhando reto pra baixo, cobrindo um quadrado de 'lado_mundo' (pra piso que repete)."""
    cam = bpy.data.cameras.new("cam_topo")
    cam.type = "ORTHO"
    cam.ortho_scale = lado_mundo
    obj = bpy.data.objects.new("cam_topo", cam)
    bpy.context.collection.objects.link(obj)
    obj.location = (lado_mundo / 2.0, lado_mundo / 2.0, 30.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.scene.camera = obj
    return obj


def pe_na_tela(cam, ponto=(0.0, 0.0, 0.0)):
    """Em que pixel (x, y com y pra baixo) um ponto do mundo cai no render atual."""
    from bpy_extras.object_utils import world_to_camera_view
    cena = bpy.context.scene
    v = world_to_camera_view(cena, cam, Vector(ponto))
    return v.x * cena.render.resolution_x, (1.0 - v.y) * cena.render.resolution_y


def recortar(px, pe):
    """Corta o vazio em volta (deixa 1 px pro contorno). Devolve (imagem, pé relativo ao canto do recorte)."""
    cx = caixa_alfa(px)
    if cx is None:
        return None, None
    x0, y0 = max(0, cx[0] - 1), max(0, cx[1] - 1)
    x1, y1 = min(px.shape[1] - 1, cx[2] + 1), min(px.shape[0] - 1, cx[3] + 1)
    return px[y0:y1 + 1, x0:x1 + 1], (pe[0] - x0, pe[1] - y0)


def empacotar(imagens, largura=512):
    """Atlas em prateleiras. imagens = [array RGBA]. Devolve (atlas, [(x, y, w, h)])."""
    x = y = alt = 0
    pos = []
    for im in imagens:
        h, w = im.shape[:2]
        if x + w > largura:
            x, y, alt = 0, y + alt + 1, 0
        pos.append((x, y, w, h))
        x += w + 1
        alt = max(alt, h)
    altura = y + alt
    atlas = np.zeros((altura, largura, 4), dtype=np.float32)
    for im, (x, y, w, h) in zip(imagens, pos):
        atlas[y:y + h, x:x + w] = im
    return atlas, pos


def brilho(raio, rampa, degraus=4):
    """Halo de luz em pixel art: anéis de cor/força constante (sem degradê liso) e pontilhado na borda de cada anel.
    No jogo é somado à cena (blend ADD), então é barato pra qualquer PC."""
    lado = raio * 2 + 1
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
    cores = [PALETA[PALETA_HEX.index(h)] for h in RAMPA[rampa]][-degraus:]
    out = np.zeros((lado, lado, 4), dtype=np.float32)
    for y in range(lado):
        for x in range(lado):
            d = math.hypot(x - raio, (y - raio) * 1.6) / raio          # achatado: luz no chão em perspectiva
            if d >= 1.0:
                continue
            nivel = (1.0 - d) * degraus                               # 0 (borda) .. degraus (centro)
            k = int(nivel)
            if nivel - k > bayer[y % 4, x % 4]:                        # pontilhado entre um anel e o próximo
                k += 1
            if k <= 0:
                continue
            k = min(k, degraus)
            out[y, x, :3] = cores[k - 1]
            out[y, x, 3] = 0.10 + 0.22 * (k / degraus)
    return out


# ---------------------------------------------------------------- primitivas (personagens e cenários)

def pendurar(filho, pai):
    """Prende o filho no pai SEM mudar a posição no mundo (senão a posição soma duas vezes)."""
    bpy.context.view_layer.update()
    filho.parent = pai
    filho.matrix_parent_inverse = pai.matrix_world.inverted()


def _finalizar(o, nome, mat, pai, chanfro):
    o.name = nome
    if chanfro > 0:
        b = o.modifiers.new("chanfro", "BEVEL")
        b.width = chanfro
        b.segments = 1
        b.limit_method = "ANGLE"
    o.data.materials.append(mat)
    if pai is not None:
        pendurar(o, pai)
    return o


def caixa(nome, tam, pos, mat, pai=None, pivo=None, rot=(0, 0, 0), chanfro=0.0):
    """Caixa de tamanho 'tam'. Com 'pivo', a origem fica no pivô (pra girar membro no ombro/quadril).
    'chanfro' arredonda as quinas, que pegam luz: é o que faz pedra e madeira parecerem volume."""
    from mathutils import Matrix
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.scale = tam
    bpy.ops.object.transform_apply(scale=True)
    if pivo is not None:
        o.data.transform(Matrix.Translation(Vector(pos) - Vector(pivo)))
        o.location = pivo
    else:
        o.location = pos
    o.rotation_euler = rot
    return _finalizar(o, nome, mat, pai, chanfro)


def esfera(nome, raio, pos, mat, pai=None, escala=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=raio, segments=12, ring_count=8, location=pos)
    o = bpy.context.active_object
    o.scale = escala
    return _finalizar(o, nome, mat, pai, 0.0)


def cilindro(nome, raio, altura, pos, mat, pai=None, rot=(0, 0, 0), vertices=12, chanfro=0.0):
    bpy.ops.mesh.primitive_cylinder_add(radius=raio, depth=altura, vertices=vertices, location=pos, rotation=rot)
    o = bpy.context.active_object
    return _finalizar(o, nome, mat, pai, chanfro)


def cone(nome, r1, r2, altura, pos, mat, pai=None, vertices=12):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=altura, vertices=vertices, location=pos)
    o = bpy.context.active_object
    return _finalizar(o, nome, mat, pai, 0.0)
