"""Mapas novos da v2 (laboratório, cidade): objetos e piso renderizados no Blender, no mesmo enquadramento do herói.

Roda (Blender 4.5 LTS):
    blender -b -P mapas_v2.py -- laboratorio            # todos os objetos e o piso do laboratório
    blender -b -P mapas_v2.py -- laboratorio mesa_lab   # só os objetos citados (o piso se chama "piso")

Saída (não vai ao Git: é regenerável; o passo seguinte, fonte_arte/gerar_v2_mapas.py, lê daqui):
    fonte_arte/mapas_v2/brutos/<mapa>/<nome>.png     albedo na escala do jogo (alfa fracionário, o gerador binariza)
    fonte_arte/mapas_v2/brutos/<mapa>/<nome>_n.png   normal map de verdade (espaço da câmera), mesma grade
    fonte_arte/mapas_v2/brutos/<mapa>/<nome>.json    ponto da origem no PNG e tamanho

Escala e câmera: 1 unidade do Blender = 1 metro = PX px na horizontal; câmera ortográfica a 45 graus (a mesma do Hazaki, elevação 45),
então 1 m de altura vira PX * sen(45) = 22,6 px. O herói (1,75 m) fica com ~40 px. Cada objeto é desenhado com a origem no CHÃO, no
centro da pegada; a frente (a face que a câmera vê) é o lado -Y.

A luz do albedo é de propósito calma (céu forte + sol fraco): o brilho de verdade vem da luz dinâmica do jogo sobre o normal map,
então o albedo só carrega cor, oclusão nas frestas e uma sombra suave de lado. Quem emite luz (tela, tubo de líquido, lâmpada) usa
material_emissao: o halo e a luz no chão são PointLight2D do jogo (dados/v2_<mapa>.json, "luz_objetos").
"""
import json
import math
import os
import random
import sys

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.append(AQUI)
import pixel3d as px3  # noqa: E402
from pixel3d import caixa, cilindro, cone, esfera  # noqa: E402

PX = 32.0                  # pixels por metro, na horizontal
ELEV = 45.0                # elevação da câmera (graus), como o Hazaki
FATOR = 4                  # renderiza 4x maior e reduz pela média (pré-renderizado)
BRUTOS = os.path.normpath(os.path.join(AQUI, "..", "mapas_v2", "brutos"))


# ------------------------------------------------------------------ materiais e peças
def M(hexa, rug=0.7, relevo=0.0, var=0.0, escala=6.0):
    """Material opaco (render suave): cor, rugosidade, relevo e manchas opcionais."""
    return px3.material_suave("m_%s_%s_%s_%s" % (hexa, rug, relevo, var), px3.cor(hexa), rugosidade=rug, relevo=relevo,
                              variacao=var, escala=escala)


def metal(hexa, rug=0.38, relevo=0.15, var=0.1, escala=10.0):
    """Metal fosco com manchas e arranhões (relevo fino)."""
    m = M(hexa, rug, relevo, var, escala)
    m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.55
    return m


def E(hexa, forca=1.6):
    """Material que brilha sozinho (tela, líquido, lâmpada)."""
    return px3.material_emissao("e_%s_%s" % (hexa, forca), px3.cor(hexa), forca)


def vidro(hexa="3f7f86"):
    """Vidro opaco para o render (o alfa do sprite é binário): cor + brilho no topo; o interior é emissivo no código do objeto."""
    m = M(hexa, 0.08)
    m.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.9
    return m


def B(w, d, h, x, y, z, mat, ch=0.02, rot=(0, 0, 0), nome="caixa"):
    """Caixa por largura (x), profundidade (y) e altura (z): (x, y) é o centro e z a face de BAIXO."""
    return caixa(nome, (w, d, h), (x, y, z + h / 2.0), mat, chanfro=ch, rot=rot)


def C(r, h, x, y, z, mat, v=20, ch=0.0, rot=(0, 0, 0), nome="cilindro"):
    """Cilindro vertical: (x, y) é o centro e z a base."""
    return cilindro(nome, r, h, (x, y, z + h / 2.0), mat, vertices=v, chanfro=ch, rot=rot)


def barra(a, b, raio, mat, v=10):
    """Cilindro entre dois pontos (cano, cabo, perna de mesa)."""
    from mathutils import Vector
    pa, pb = Vector(a), Vector(b)
    d = pb - pa
    bpy.ops.mesh.primitive_cylinder_add(radius=raio, depth=d.length, vertices=v, location=(pa + pb) / 2)
    o = bpy.context.active_object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(mat)
    return o


# ------------------------------------------------------------------ render
def preparar_prop(largura, altura, pe_y, amostras=40):
    """Cena do objeto: câmera a 45 graus com a origem na coluna do meio e na linha pe_y, céu forte e sol fraco."""
    px3.limpar_cena()
    cena = px3.preparar_suave(largura, altura, FATOR, amostras)
    cam = px3.camera(elevacao_graus=ELEV, escala=max(largura, altura) / PX)
    cam.data.shift_y = (pe_y - altura / 2.0) / max(largura, altura)
    px3.luz(rasante=False, suave=True)
    for o in bpy.data.objects:
        if o.type == "LIGHT":
            o.data.energy = 2.4
    fundo = cena.world.node_tree.nodes.get("Background")
    fundo.inputs[0].default_value = (0.92, 0.94, 1.0, 1.0)
    fundo.inputs[1].default_value = 1.05
    return cena


def _pass_normal(cena):
    """Troca todos os materiais por um que emite a normal no espaço da câmera (x direita, y para cima, z para a câmera)."""
    m = bpy.data.materials.new("normal_cam")
    m.use_nodes = True
    n = m.node_tree.nodes
    l = m.node_tree.links
    n.clear()
    geo = n.new("ShaderNodeNewGeometry")
    vt = n.new("ShaderNodeVectorTransform")
    vt.vector_type = "NORMAL"
    vt.convert_from = "WORLD"
    vt.convert_to = "CAMERA"
    mul = n.new("ShaderNodeVectorMath")
    mul.operation = "MULTIPLY_ADD"
    mul.inputs[1].default_value = (0.5, 0.5, 0.5)
    mul.inputs[2].default_value = (0.5, 0.5, 0.5)
    emi = n.new("ShaderNodeEmission")
    out = n.new("ShaderNodeOutputMaterial")
    l.new(geo.outputs["Normal"], vt.inputs[0])
    l.new(vt.outputs[0], mul.inputs[0])
    l.new(mul.outputs[0], emi.inputs[0])
    l.new(emi.outputs[0], out.inputs[0])
    bpy.context.view_layer.material_override = m
    cena.cycles.samples = 8
    cena.cycles.use_denoising = False
    cena.view_settings.view_transform = "Raw"
    cena.world.node_tree.nodes.get("Background").inputs[1].default_value = 0.0
    for o in bpy.data.objects:
        if o.type == "LIGHT":
            o.hide_render = True


def _reduzir_premul(px, fator):
    """Média por bloco pesada pelo alfa (a cor não escurece na borda). Devolve (rgb, alfa)."""
    h, w = px.shape[0] // fator, px.shape[1] // fator
    blocos = px[:h * fator, :w * fator].reshape(h, fator, w, fator, 4)
    a = blocos[..., 3]
    soma = a.sum(axis=(1, 3))
    rgb = (blocos[..., :3] * a[..., None]).sum(axis=(1, 3)) / np.maximum(soma, 1e-6)[..., None]
    return rgb, a.mean(axis=(1, 3))


def _normal_final(nrm):
    """Renormaliza a média dos blocos. O nó do Blender entrega o z do espaço da câmera com o sinal trocado (visível = para a câmera,
    então z é sempre positivo): usa o módulo."""
    v = nrm * 2.0 - 1.0
    v[..., 2] = np.abs(v[..., 2])
    v /= np.maximum(np.linalg.norm(v, axis=2, keepdims=True), 1e-6)
    return v * 0.5 + 0.5


def renderizar(mapa, nome, largura, altura, pe_y, construir, amostras=40):
    """Constrói o objeto com construir(r), renderiza o albedo e a normal e grava em brutos/<mapa>/."""
    cena = preparar_prop(largura, altura, pe_y, amostras)
    construir(random.Random(mapa + nome))
    bpy.context.view_layer.update()
    px = px3.render_rgba()
    rgb, a = _reduzir_premul(px, FATOR)
    _pass_normal(cena)
    pn = px3.render_rgba()
    nrm, an = _reduzir_premul(pn, FATOR)
    nrm = _normal_final(nrm)
    pasta = os.path.join(BRUTOS, mapa)
    os.makedirs(pasta, exist_ok=True)
    px3.salvar_png(np.dstack([rgb, a]).astype(np.float32), os.path.join(pasta, nome + ".png"))
    px3.salvar_png(np.dstack([nrm, a]).astype(np.float32), os.path.join(pasta, nome + "_n.png"))
    with open(os.path.join(pasta, nome + ".json"), "w", encoding="utf-8") as f:
        json.dump({"origem": [largura / 2.0, pe_y], "tam": [largura, altura]}, f)
    print("OBJETO OK", mapa, nome, largura, altura)


def renderizar_piso(mapa, lado_m, construir, amostras=48):
    """Piso que repete sem emenda: lado_m metros de lado, visto de cima, cercado por 8 cópias dele (luz e sombra repetem).
    Grava o albedo e a normal em (lado_m * PX) px de largura; o gerador achata a altura por sen(ELEV) para casar com a câmera 3/4."""
    tam = int(round(lado_m * PX))
    px3.limpar_cena()
    cena = px3.preparar_suave(tam, tam, FATOR, amostras)
    px3.camera_topo(lado_m)
    px3.luz(rasante=True, suave=True)
    construir(random.Random(mapa + "piso"))
    # 8 cópias em volta: a luz e a sombra da borda cruzam para o vizinho
    base = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            for o in base:
                c = o.copy()
                c.data = o.data
                c.location = (o.location.x + dx * lado_m, o.location.y + dy * lado_m, o.location.z)
                bpy.context.collection.objects.link(c)
    bpy.context.view_layer.update()
    px = px3.render_rgba()
    rgb, a = _reduzir_premul(px, FATOR)
    _pass_normal(cena)
    pn = px3.render_rgba()
    nrm, _ = _reduzir_premul(pn, FATOR)
    nrm = _normal_final(nrm)
    pasta = os.path.join(BRUTOS, mapa)
    os.makedirs(pasta, exist_ok=True)
    um = np.ones_like(a)
    px3.salvar_png(np.dstack([rgb, um]).astype(np.float32), os.path.join(pasta, "piso.png"))
    px3.salvar_png(np.dstack([nrm, um]).astype(np.float32), os.path.join(pasta, "piso_n.png"))
    print("PISO OK", mapa, tam)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not args:
        raise SystemExit("uso: blender -b -P mapas_v2.py -- <laboratorio|cidade> [nomes]")
    mapa, nomes = args[0], args[1:]
    mod = __import__("mapa_" + mapa)
    for nome, (larg, alt, pe_y, f) in mod.OBJETOS.items():
        if not nomes or nome in nomes:
            renderizar(mapa, nome, larg, alt, pe_y, f)
    if not nomes or "piso" in nomes:
        lado, f = mod.PISO
        renderizar_piso(mapa, lado, f)


if __name__ == "__main__":
    main()
