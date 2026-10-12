"""Cidade da v2: peças comuns (cores, materiais, letras de neon, janelas, toldos) e os objetos de rua, carros e adereços. Os prédios ficam em
cidade_predios.py e o piso em cidade_piso.py; quem junta tudo e diz o tamanho da tela de cada objeto é mapa_cidade.py (lido por mapas_v2.py).

Cada função monta UM objeto com a origem no chão, no centro da pegada, a frente voltada para -Y. Medidas em metros (1 m = 32 px na horizontal e
22,6 px na vertical); as medidas e as luzes ficam em mapas_v2/medidas_cidade.py (Python puro, lido também pelo def_cidade.py). Tom: cidade
pós-apocalíptica à noite, concreto e tijolo sujos, ferrugem, e os brilhos de sódio (poste), neon (placas) e janela acesa; o fogo do barril é luz
e partícula no jogo, então o barril sai apagado.
"""
import math

import bpy

from mapas_v2 import B, C, barra, cilindro, cone, esfera, px3, vidro

# ------------------------------------------------------------------ cores
CONCRETO = "6d7073"
CONCRETO_ESC = "44474b"
CONCRETO_CLARO = "9a9b96"
METAL = "4d5258"
METAL_ESC = "2a2e33"
FERRUGEM = "7a4a2e"
FERRUGEM_ESC = "56321f"
PRETO = "14161a"
SODIO = "ffb347"
JANELA = "ffb257"
JANELA_FRIA = "a9e0ff"
NEON_ROSA = "ff3fa4"
NEON_AZUL = "3fb7ff"
NEON_VERDE = "4dff8c"
NEON_VERM = "ff3a36"
MADEIRA_VELHA = "52402f"
TIJOLO_A = ("7d4636", "63352a")
TIJOLO_B = ("6a4a3e", "553a30")


# ------------------------------------------------------------------ materiais (com cache por nome: a cena tem centenas de caixas)
def M(hexa, rug=0.7, relevo=0.0, var=0.0, escala=6.0):
    """Material opaco: cor, rugosidade, relevo e manchas (igual ao mapas_v2.M, mas um material por receita)."""
    nome = "cm_%s_%s_%s_%s_%s" % (hexa, rug, relevo, var, escala)
    m = bpy.data.materials.get(nome)
    if m is None:
        m = px3.material_suave(nome, px3.cor(hexa), rugosidade=rug, relevo=relevo, variacao=var, escala=escala)
    return m


def metal(hexa, rug=0.38, relevo=0.15, var=0.1, escala=10.0):
    """Metal fosco com manchas e arranhões."""
    nome = "cmt_%s_%s_%s_%s_%s" % (hexa, rug, relevo, var, escala)
    m = bpy.data.materials.get(nome)
    if m is None:
        m = px3.material_suave(nome, px3.cor(hexa), rugosidade=rug, relevo=relevo, variacao=var, escala=escala)
        m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.55
    return m


def E(hexa, forca=1.6):
    """Material que brilha sozinho (janela, neon, lâmpada). Não ilumina a cena do render (o halo e a luz no chão são do jogo): só pinta o pixel."""
    nome = "ce_%s_%s" % (hexa, forca)
    m = bpy.data.materials.get(nome)
    if m is None:
        m = px3.material_emissao(nome, px3.cor(hexa), forca)
        m.cycles.emission_sampling = "NONE"
    return m


def tijolo(c1=TIJOLO_A[0], c2=TIJOLO_A[1], argamassa="3a3532", larg=0.36, alt=0.12, sujeira=0.3, escala_sujo=2.2):
    """Parede de tijolo: o padrão de tijolos vem do nó Brick (visto de frente: x e z do objeto), com sujeira em manchas e relevo nas juntas."""
    m = bpy.data.materials.new("tijolo_%s_%s" % (c1, c2))
    m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links
    p = n.get("Principled BSDF")
    p.inputs["Roughness"].default_value = 0.92
    coord = n.new("ShaderNodeTexCoord")
    sep = n.new("ShaderNodeSeparateXYZ")
    comb = n.new("ShaderNodeCombineXYZ")
    l.new(coord.outputs["Object"], sep.inputs["Vector"])
    l.new(sep.outputs["X"], comb.inputs["X"])
    l.new(sep.outputs["Z"], comb.inputs["Y"])
    br = n.new("ShaderNodeTexBrick")
    br.inputs["Color1"].default_value = px3.cor(c1)
    br.inputs["Color2"].default_value = px3.cor(c2)
    br.inputs["Mortar"].default_value = px3.cor(argamassa)
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.03
    br.inputs["Mortar Smooth"].default_value = 0.08
    br.inputs["Brick Width"].default_value = larg
    br.inputs["Row Height"].default_value = alt
    l.new(comb.outputs["Vector"], br.inputs["Vector"])
    ruido = n.new("ShaderNodeTexNoise")
    ruido.inputs["Scale"].default_value = escala_sujo
    ruido.inputs["Detail"].default_value = 6.0
    l.new(coord.outputs["Object"], ruido.inputs["Vector"])
    rampa = n.new("ShaderNodeMapRange")
    rampa.inputs["To Min"].default_value = 1.0 - sujeira
    rampa.inputs["To Max"].default_value = 1.0 + sujeira * 0.4
    l.new(ruido.outputs["Fac"], rampa.inputs["Value"])
    comb2 = n.new("ShaderNodeCombineColor")
    for k in range(3):
        l.new(rampa.outputs["Result"], comb2.inputs[k])
    mix = n.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    l.new(br.outputs["Color"], mix.inputs[6])
    l.new(comb2.outputs[0], mix.inputs[7])
    l.new(mix.outputs[2], p.inputs["Base Color"])
    bump = n.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.7
    bump.inputs["Distance"].default_value = 0.02
    l.new(br.outputs["Fac"], bump.inputs["Height"])
    l.new(bump.outputs["Normal"], p.inputs["Normal"])
    return m


def reboco(hexa, rug=0.9, relevo=0.5, var=0.3, escala=3.0):
    """Parede rebocada e suja (concreto ou massa), com manchas grandes."""
    return M(hexa, rug, relevo, var, escala)


def CR(r, h, x, y, z, mat, rot, v=16, nome="cilindro"):
    """Cilindro DEITADO (rot) com o CENTRO em (x, y, z): roda, lâmpada de semáforo, cano na horizontal."""
    return cilindro(nome, r, h, (x, y, z), mat, vertices=v, rot=rot)


def toro(raio_maior, raio_menor, pos, mat, rot=(0, 0, 0), seg=18, seg_menor=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=raio_maior, minor_radius=raio_menor, major_segments=seg, minor_segments=seg_menor, location=pos,
                                     rotation=rot)
    o = bpy.context.active_object
    o.data.materials.append(mat)
    return o


def octogono(raio, esp, pos, mat, v=8):
    """Disco de v lados com a face para a câmera (-Y), com um lado reto em cima (placa de pare)."""
    from mathutils import Matrix
    bpy.ops.mesh.primitive_cylinder_add(radius=raio, depth=esp, vertices=v, location=(0, 0, 0))
    o = bpy.context.active_object
    o.data.transform(Matrix.Rotation(math.pi / v, 4, "Z"))
    o.rotation_euler = (math.pi / 2, 0, 0)
    o.location = pos
    o.data.materials.append(mat)
    return o


def girar(antes, ang):
    """Gira em torno do eixo Z (pela origem) tudo que foi criado desde 'antes' (nomes que já existiam)."""
    from mathutils import Matrix
    bpy.context.view_layer.update()
    rz = Matrix.Rotation(ang, 4, "Z")
    for o in list(bpy.data.objects):
        if o.name not in antes and o.type == "MESH":
            o.matrix_world = rz @ o.matrix_world


def vira(f, ang):
    """Versão do objeto f girada em ang (para os carros no sentido de Y)."""
    def g(r):
        antes = set(bpy.data.objects.keys())
        f(r)
        girar(antes, ang)
    g.__name__ = f.__name__ + "_girado"
    return g


# letras de 3x5 pixels (cada pixel vira uma caixa emissiva): placas de neon legíveis em pixel art
FONTE = {
    "A": ".X.|X.X|XXX|X.X|X.X", "B": "XX.|X.X|XX.|X.X|XX.", "C": ".XX|X..|X..|X..|.XX", "D": "XX.|X.X|X.X|X.X|XX.",
    "E": "XXX|X..|XX.|X..|XXX", "F": "XXX|X..|XX.|X..|X..", "G": ".XX|X..|X.X|X.X|.XX", "H": "X.X|X.X|XXX|X.X|X.X",
    "I": "XXX|.X.|.X.|.X.|XXX", "J": "..X|..X|..X|X.X|.X.", "L": "X..|X..|X..|X..|XXX", "M": "X...X|XX.XX|X.X.X|X...X|X...X",
    "O": ".X.|X.X|X.X|X.X|.X.", "P": "XX.|X.X|XX.|X..|X..", "R": "XX.|X.X|XX.|X.X|X.X", "S": ".XX|X..|.X.|..X|XX.",
    "T": "XXX|.X.|.X.|.X.|.X.", "U": "X.X|X.X|X.X|X.X|XXX", "2": "XX.|..X|.X.|X..|XXX", "4": "X.X|X.X|XXX|..X|..X",
    "0": "XXX|X.X|X.X|X.X|XXX", "1": ".X.|XX.|.X.|.X.|XXX", "V": "X.X|X.X|X.X|X.X|.X.", "N": "XX.|X.X|X.X|X.X|X.X",
    " ": "...|...|...|...|...",
}


def texto(txt, x, z, y, cel, mat):
    """Escreve txt com a base em z e o centro em x, na face que está em y (voltada para -Y); cel = lado de cada pixel da letra (m)."""
    larg = 0.0
    glifos = []
    for ch in txt:
        g = [lin for lin in FONTE[ch].split("|")]
        glifos.append(g)
        larg += len(g[0]) + 1
    larg = (larg - 1) * cel
    cx = x - larg / 2.0
    for g in glifos:
        for j, lin in enumerate(g):
            for i, c in enumerate(lin):
                if c == "X":
                    B(cel * 0.92, 0.03, cel * 0.92, cx + (i + 0.5) * cel, y - 0.015, z + (4 - j + 0.5) * cel, mat, ch=0.0)
        cx += (len(g[0]) + 1) * cel
    return larg


# ------------------------------------------------------------------ rua: postes, semáforo, placas
def _poste_base(r, cor=METAL_ESC):
    aco = metal(cor, 0.45, 0.2, 0.2)
    C(0.2, 0.18, 0, 0, 0, metal(CONCRETO_ESC, 0.7, 0.3, 0.2), v=16, ch=0.01)
    C(0.14, 0.7, 0, 0, 0.18, aco, v=16)
    B(0.14, 0.03, 0.34, 0, -0.14, 0.4, M(FERRUGEM, 0.9, 0.4, 0.3), ch=0.0)   # portinhola enferrujada
    return aco


def poste_rua(r, lado=1):
    """Poste de rua com a luminária de sódio ACESA (a luz é do jogo: poste_rua em LUZES)."""
    aco = _poste_base(r)
    cone("haste", 0.095, 0.058, 4.2, (0, 0, 0.88 + 2.1), aco, vertices=14)
    for z in (1.0, 2.6, 4.1):
        C(0.1, 0.05, 0, 0, z, metal(FERRUGEM_ESC, 0.6, 0.3, 0.3), v=14)
    # braço curvo para o lado, depois a luminária
    pts = [(0, 0, 5.04), (0.22 * lado, 0, 5.28), (0.62 * lado, 0, 5.4), (1.05 * lado, 0, 5.38), (1.35 * lado, 0, 5.28)]
    for a, b in zip(pts, pts[1:]):
        barra(a, b, 0.05, aco, v=10)
    B(0.95, 0.34, 0.1, 1.42 * lado, 0, 5.2, metal("33383d", 0.4, 0.2, 0.1), ch=0.04)
    B(0.8, 0.28, 0.05, 1.42 * lado, 0, 5.15, E(SODIO, 3.2), ch=0.0)
    B(0.18, 0.3, 0.1, 1.0 * lado, 0, 5.3, metal("33383d", 0.4, 0.2, 0.1), ch=0.02)
    # cabo e uma fita de cartaz rasgado
    barra((0.07 * lado, -0.07, 1.6), (0.07 * lado, -0.07, 2.4), 0.012, M(PRETO, 0.6), v=6)
    B(0.18, 0.015, 0.34, 0, -0.1, 1.45, M("b9b6a4", 0.95, 0.3, 0.3), ch=0.0)
    B(0.12, 0.015, 0.2, 0.01, -0.105, 1.85, M("8c4a3c", 0.95), ch=0.0)


def poste_rua_e(r):
    poste_rua(r, lado=-1)


def poste_quebrado(r):
    """Poste partido ao meio: o toco com os ferros, a parte de cima caída e pendurada pelo fio, a luminária apagada e rachada."""
    aco = _poste_base(r)
    cone("haste", 0.095, 0.075, 1.9, (0, 0, 0.88 + 0.95), aco, vertices=14)
    # fratura: ferros e lasca
    for k in range(5):
        a = k * 1.25
        barra((0.05 * math.cos(a), 0.05 * math.sin(a), 2.7), (0.1 * math.cos(a) + 0.04, 0.1 * math.sin(a), 3.05 + 0.05 * k), 0.014,
              M(FERRUGEM, 0.8, 0.3, 0.3), v=6)
    # a parte de cima, tombada para a frente e apoiada no chão
    barra((0.1, -0.1, 2.75), (0.5, -1.4, 0.35), 0.085, aco, v=12)
    barra((0.5, -1.4, 0.35), (1.05, -1.7, 0.2), 0.05, aco, v=10)
    B(0.95, 0.34, 0.1, 1.5, -1.85, 0.12, metal("33383d", 0.4, 0.2, 0.1), ch=0.04, rot=(0, 0, 0.35))
    B(0.8, 0.28, 0.03, 1.5, -1.85, 0.07, M("1e2226", 0.3), ch=0.0, rot=(0, 0, 0.35))
    for k in range(5):
        B(r.uniform(0.04, 0.12), r.uniform(0.04, 0.1), 0.02, 1.2 + r.uniform(0, 0.6), -1.75 - r.uniform(0, 0.3), 0.0, vidro("7f9aa0"), ch=0.0,
          rot=(0, 0, r.uniform(0, 3)))
    # fios soltos
    barra((0.12, -0.08, 2.7), (0.3, -0.5, 1.6), 0.012, M(PRETO, 0.6), v=6)
    barra((0.06, -0.1, 2.65), (-0.2, -0.6, 0.1), 0.012, M("5b2a22", 0.6), v=6)
    B(0.5, 0.35, 0.12, 0.05, -0.1, 0.0, M(CONCRETO, 0.9, 0.4, 0.3), ch=0.04, rot=(0, 0, 0.5))


def semaforo(r, torto=False, aceso=True):
    aco = metal(METAL_ESC, 0.45, 0.2, 0.2)
    C(0.16, 0.14, 0, 0, 0, metal(CONCRETO_ESC, 0.7, 0.3, 0.2), v=14, ch=0.01)
    inclina = 0.0 if not torto else 0.16
    if torto:
        barra((0, 0, 0.1), (0.5, 0, 3.4), 0.07, aco, v=12)
        bx, bz = 0.5, 3.4
    else:
        C(0.07, 3.4, 0, 0, 0.12, aco, v=14)
        bx, bz = 0.0, 3.5
    # braço curto e a cabeça (3 lâmpadas), voltada para a câmera
    barra((bx, 0, bz - 0.15), (bx - 0.5, -0.02, bz - 0.05), 0.04, aco, v=8)
    B(0.34, 0.26, 0.92, bx - 0.55, -0.02, bz - 0.78, metal("22262a", 0.5, 0.3, 0.2), ch=0.03, rot=(0, inclina, 0))
    for k, (z, cor) in enumerate([(bz - 0.2, NEON_VERM), (bz - 0.5, "ffb23a"), (bz - 0.8, "4dff8c")]):
        acesa = aceso and k == 0
        mat = E(cor, 2.4) if acesa else M("1d2124" if k else "3a1210", 0.3)
        CR(0.095, 0.05, bx - 0.55, -0.16, z, mat, (math.pi / 2, 0, 0), v=14)
        B(0.22, 0.12, 0.04, bx - 0.55, -0.18, z + 0.1, metal("22262a", 0.5), ch=0.01)   # viseira
    B(0.2, 0.015, 0.2, 0.0, -0.08, 2.0, M("b9b6a4", 0.95, 0.3, 0.3), ch=0.0)


def semaforo_torto(r):
    semaforo(r, torto=True, aceso=False)


def placa_pare(r):
    aco = metal(METAL, 0.5, 0.2, 0.2)
    C(0.045, 2.35, 0, 0, 0, aco, v=10)
    octogono(0.38, 0.035, (0, -0.06, 2.0), M("a8302a", 0.5, 0.3, 0.25), v=8)
    octogono(0.33, 0.01, (0, -0.085, 2.0), M("c6c2b4", 0.6, 0.2, 0.2), v=8)
    octogono(0.3, 0.01, (0, -0.092, 2.0), M("a8302a", 0.5, 0.3, 0.25), v=8)
    B(0.44, 0.012, 0.075, 0, -0.1, 1.97, M("d8d4c4", 0.6), ch=0.0)
    B(0.12, 0.015, 0.1, 0.0, -0.05, 1.45, M("7a6e56", 0.9, 0.3, 0.3), ch=0.0)


def placa_rua(r):
    aco = metal(METAL, 0.5, 0.2, 0.2)
    C(0.045, 2.7, 0, 0, 0, aco, v=10)
    B(1.0, 0.04, 0.26, 0.1, -0.06, 2.25, M("2e5a46", 0.6, 0.3, 0.25), ch=0.01, rot=(0, 0, 0.0))
    B(0.94, 0.012, 0.2, 0.1, -0.085, 2.28, M("c9ccc2", 0.6, 0.2, 0.2), ch=0.0)
    B(0.9, 0.012, 0.16, 0.1, -0.09, 2.3, M("2e5a46", 0.6, 0.3, 0.25), ch=0.0)
    B(0.6, 0.012, 0.045, 0.1, -0.1, 2.34, M("d8d4c4", 0.6), ch=0.0)
    B(0.8, 0.04, 0.26, -0.05, -0.1, 1.95, M("2c4a6e", 0.6, 0.3, 0.25), ch=0.01, rot=(0, 0.1, 0.0))
    B(0.2, 0.015, 0.2, 0.0, -0.06, 1.2, M("7a6e56", 0.9, 0.3, 0.3), ch=0.0)


def placa_neon(r):
    """Totem de neon na calçada: haste e uma caixa de letreiro com o contorno aceso (rosa) e a palavra (azul)."""
    aco = metal(METAL_ESC, 0.45, 0.2, 0.2)
    C(0.18, 0.12, 0, 0, 0, metal(CONCRETO_ESC, 0.7, 0.3, 0.2), v=14, ch=0.01)
    C(0.06, 2.3, 0, 0, 0.12, aco, v=12)
    B(1.3, 0.2, 1.15, 0, 0, 2.2, metal("20242a", 0.5, 0.3, 0.2), ch=0.03)
    ros = E(NEON_ROSA, 3.0)
    B(1.2, 0.03, 0.04, 0, -0.115, 3.28, ros, ch=0.0)
    B(1.2, 0.03, 0.04, 0, -0.115, 2.27, ros, ch=0.0)
    B(0.04, 0.03, 1.05, -0.6, -0.115, 2.26, ros, ch=0.0)
    B(0.04, 0.03, 1.05, 0.6, -0.115, 2.26, ros, ch=0.0)
    texto("BAR", 0.0, 2.55, -0.115, 0.1, E(NEON_AZUL, 3.0))
    B(0.5, 0.03, 0.04, 0, -0.115, 3.06, E(NEON_AZUL, 2.4), ch=0.0)
    B(0.1, 0.1, 0.3, 0.3, 0.08, 1.9, aco, ch=0.01)
    barra((0.0, 0.1, 2.2), (0.3, 0.12, 1.5), 0.015, M(PRETO, 0.5), v=6)


def hidrante(r):
    vm = M("a52f26", 0.5, 0.35, 0.3, 14.0)
    ferr = M("6e2a22", 0.6, 0.4, 0.4, 14.0)
    C(0.15, 0.08, 0, 0, 0, M(CONCRETO_ESC, 0.8, 0.3, 0.2), v=14)
    C(0.12, 0.5, 0, 0, 0.08, vm, v=14, ch=0.01)
    C(0.15, 0.06, 0, 0, 0.5, ferr, v=14)
    esfera("cupula", 0.12, (0, 0, 0.58), vm, escala=(1, 1, 0.8))
    C(0.04, 0.06, 0, 0, 0.66, ferr, v=8)
    for s in (-1, 1):
        CR(0.065, 0.14, s * 0.16, 0, 0.33, vm, (0, math.pi / 2, 0), v=12)
        CR(0.075, 0.03, s * 0.25, 0, 0.33, ferr, (0, math.pi / 2, 0), v=12)
    CR(0.07, 0.13, 0, -0.14, 0.31, vm, (math.pi / 2, 0, 0), v=12)
    CR(0.08, 0.03, 0, -0.22, 0.31, ferr, (math.pi / 2, 0, 0), v=12)
    B(0.1, 0.03, 0.12, 0.04, -0.13, 0.12, M("c8a020", 0.7), ch=0.0)   # tinta amarela descascada


def cone_transito(r, tombado=False):
    lar = M("c9541a", 0.5, 0.2, 0.3)
    br = M("bcbab0", 0.6, 0.2, 0.3)
    if not tombado:
        B(0.42, 0.42, 0.04, 0, 0, 0, M("2a2d30", 0.7, 0.2, 0.2), ch=0.015)
        cone("cone", 0.17, 0.045, 0.66, (0, 0, 0.37), lar, vertices=14)
        C(0.108, 0.1, 0, 0, 0.3, br, v=14)
        C(0.077, 0.08, 0, 0, 0.46, br, v=14)
    else:
        # tombado: a base solta ao lado e o cone deitado, apontando para +X (virado 0,4 rad)
        B(0.42, 0.42, 0.04, 0.55, -0.25, 0, M("2a2d30", 0.7, 0.2, 0.2), ch=0.015, rot=(0, 0, 0.7))
        yaw = 0.4
        c = cone("cone", 0.17, 0.045, 0.66, (0, 0, 0.17), lar, vertices=14)
        c.rotation_euler = (0, math.pi / 2, yaw)
        for t, rr in ((-0.12, 0.108), (0.12, 0.077)):
            CR(rr, 0.1, t * math.cos(yaw), t * math.sin(yaw), 0.17, br, (0, math.pi / 2, yaw), v=14)


def cone_tombado(r):
    cone_transito(r, tombado=True)


def barril_fogo(r):
    """Barril de óleo enferrujado, APAGADO: o fogo é luz e partícula no jogo (veja LUZES: ponto da chama e do brilho)."""
    fer = metal("4a4f54", 0.5, 0.4, 0.4, 8.0)
    esc = metal("6b6f73", 0.5, 0.3, 0.3, 8.0)
    C(0.3, 0.92, 0, 0, 0, fer, v=22, ch=0.005)
    for z in (0.08, 0.44, 0.8):
        C(0.318, 0.045, 0, 0, z, esc, v=22)
    # boca aberta, interior preto e brasa apagada (carvão e pedaços de madeira queimada)
    C(0.285, 0.03, 0, 0, 0.92, M("0b0a0a", 1.0), v=22)
    for k in range(7):
        a = r.uniform(0, 6.28)
        d = r.uniform(0.0, 0.17)
        B(r.uniform(0.07, 0.16), r.uniform(0.04, 0.07), r.uniform(0.05, 0.14), d * math.cos(a), d * math.sin(a), 0.93, M("181514", 0.9, 0.3, 0.3),
          ch=0.01, rot=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), r.uniform(0, 3)))
    # furos de ar pela lateral e uma mancha de fuligem
    for k in range(4):
        B(0.07, 0.03, 0.05, -0.12 + 0.08 * k, -0.295, 0.12 + 0.06 * (k % 2), M("0d0c0c", 1.0), ch=0.0)
    B(0.3, 0.012, 0.28, 0.0, -0.3, 0.55, M("1c1a19", 0.9, 0.3, 0.2), ch=0.0)
    for k in range(5):   # ferrugem escorrida
        B(r.uniform(0.05, 0.14), 0.012, r.uniform(0.1, 0.3), r.uniform(-0.22, 0.22), -0.3, r.uniform(0.2, 0.7), M("7a4a2e", 0.8, 0.3, 0.3), ch=0.0)


def lixeira_metal(r):
    gal = metal("6e757b", 0.4, 0.25, 0.25, 12.0)
    C(0.28, 0.82, 0, 0, 0, gal, v=20, ch=0.005)
    for z in (0.1, 0.45):
        C(0.295, 0.035, 0, 0, z, metal("4a5056", 0.4, 0.2, 0.2), v=20)
    C(0.3, 0.05, 0.02, 0.02, 0.8, metal("565d63", 0.4), v=20, rot=(0.12, -0.1, 0))
    # lixo transbordando
    for k in range(7):
        B(r.uniform(0.07, 0.18), r.uniform(0.05, 0.14), r.uniform(0.05, 0.12), r.uniform(-0.18, 0.18), r.uniform(-0.15, 0.12), 0.84,
          M(r.choice(["8d8a7a", "5a6a56", "7d6a4a", "6a3a30", "9a9890"]), 0.9, 0.2, 0.3), ch=0.02, rot=(r.uniform(-0.4, 0.4), 0, r.uniform(0, 3)))
    B(0.28, 0.015, 0.2, 0.0, -0.285, 0.55, M(FERRUGEM, 0.9, 0.4, 0.3), ch=0.0)
    B(0.04, 0.012, 0.1, -0.2, -0.28, 0.35, M("d2d0c0", 0.6), ch=0.0)


def lixeira_rodas(r, cor="2f5d3c"):
    pl = M(cor, 0.6, 0.15, 0.2, 10.0)
    B(0.62, 0.72, 0.9, 0, 0, 0.1, pl, ch=0.05)
    B(0.68, 0.78, 0.07, 0, 0.0, 0.98, M("26492f", 0.6, 0.15, 0.2), ch=0.03, rot=(-0.1, 0, 0))   # tampa entreaberta
    B(0.55, 0.05, 0.05, 0, -0.38, 1.0, M("22402a", 0.6), ch=0.01)
    for s in (-1, 1):
        cilindro("roda", 0.1, 0.06, (s * 0.3, 0.3, 0.1), M("141618", 0.8), vertices=12, rot=(0, math.pi / 2, 0))
    B(0.3, 0.015, 0.2, 0, -0.365, 0.6, M("c9c6b4", 0.6), ch=0.0)
    B(0.2, 0.012, 0.12, 0, -0.372, 0.62, M("2b6b3c", 0.6), ch=0.0)
    B(0.14, 0.04, 0.22, -0.2, -0.4, 0.3, M(FERRUGEM, 0.9), ch=0.0)


def lixeira_azul(r):
    lixeira_rodas(r, cor="3c4a5e")


def banco(r):
    ferro = metal("2e3238", 0.45, 0.2, 0.2)
    mad = M(MADEIRA_VELHA, 0.85, 0.5, 0.3, 14.0)
    for x in (-0.78, 0.78):
        B(0.07, 0.5, 0.06, x, 0.0, 0.0, ferro, ch=0.01)
        B(0.06, 0.06, 0.45, x, -0.2, 0.0, ferro, ch=0.01)
        B(0.06, 0.06, 0.45, x, 0.2, 0.0, ferro, ch=0.01)
        B(0.07, 0.5, 0.05, x, 0.0, 0.43, ferro, ch=0.01)
        barra((x, 0.2, 0.43), (x, 0.28, 0.9), 0.03, ferro, v=8)
    for i, y in enumerate((-0.18, -0.02, 0.14)):
        if i == 1 and r.random() < 0.5:
            continue
        B(1.7, 0.13, 0.04, 0, y, 0.45, mad, ch=0.01)
    for i, z in enumerate((0.62, 0.78)):
        if r.random() < 0.7:
            B(1.7, 0.04, 0.11, 0, 0.3, z, mad, ch=0.01, rot=(-0.15, 0, 0))
    B(0.4, 0.02, 0.03, 0.4, 0.16, 0.5, M("20150e", 0.9), ch=0.0)


# ------------------------------------------------------------------ carros
def _carro(r, cor, ferrugem=0.5, taxi=False, queimado=False, bateu=True):
    """Sedã abandonado, comprimento ao longo de X (4,4 m x 1,8 m), a frente do carro para +X."""
    if queimado:
        tinta = M("3a342f", 0.7, 0.5, 0.5, 10.0)
        tinta2 = M("4a3a2c", 0.75, 0.5, 0.5, 8.0)
    else:
        tinta = M(cor, 0.4, 0.08, 0.2, 9.0)
        tinta2 = M(cor, 0.5, 0.12, 0.3, 6.0)
    ferr = M(FERRUGEM, 0.8, 0.5, 0.4, 12.0)
    vid = vidro("26394a") if not queimado else M("0c0b0a", 1.0)
    preto = M("0e0f11", 0.8)
    L, W = 4.4, 1.78
    # corpo: capô, porta-malas e cabine com o teto
    B(L, W, 0.46, 0, 0, 0.3, tinta, ch=0.1)
    if queimado:   # capô aberto e torto, o motor preto por baixo
        B(1.0, W - 0.5, 0.2, 1.5, 0, 0.74, M("0e0d0c", 0.9, 0.4, 0.4), ch=0.02)
        B(1.15, W - 0.1, 0.07, 1.25, 0.1, 1.15, tinta2, ch=0.04, rot=(0.15, -0.9, 0.0))
    else:
        B(1.15, W - 0.06, 0.12, 1.48, 0, 0.74, tinta2, ch=0.06, rot=(0, -0.05, 0))
    B(0.95, W - 0.06, 0.12, -1.6, 0, 0.74, tinta2, ch=0.06, rot=(0, 0.04, 0))
    B(2.05, W - 0.22, 0.52, -0.12, 0, 0.78, tinta, ch=0.1)
    B(1.7, W - 0.34, 0.07, -0.12, 0, 1.3, tinta2, ch=0.04)   # teto
    # vidros: faixa lateral, para-brisa e vidro de trás inclinados
    B(1.85, 0.03, 0.4, -0.12, -(W - 0.22) / 2 - 0.012, 0.86, vid, ch=0.0)
    B(1.0, 0.012, 0.03, -0.55, -(W - 0.22) / 2 - 0.03, 1.15, M("5d7384", 0.2), ch=0.0, rot=(0, 0.35, 0))      # reflexo do céu no vidro
    B(0.9, 0.012, 0.03, 0.3, -(W - 0.22) / 2 - 0.03, 1.05, M("5d7384", 0.2), ch=0.0, rot=(0, 0.35, 0))
    B(L - 0.5, 0.012, 0.14, 0, -W / 2 - 0.007, 0.28, M("3a2f26", 0.95, 0.4, 0.4), ch=0.0)               # lama na soleira
    B(0.04, W - 0.4, 0.46, 0.95, 0, 0.82, vid, ch=0.0, rot=(0, 0.62, 0))
    B(0.04, W - 0.4, 0.42, -1.2, 0, 0.84, vid, ch=0.0, rot=(0, -0.62, 0))
    for x in (-0.95, -0.12, 0.62):   # colunas
        B(0.07, 0.04, 0.4, x, -(W - 0.22) / 2 - 0.02, 0.86, tinta, ch=0.0)
    # rodas e caixas de roda
    for x in (-1.36, 1.38):
        B(0.82, 0.03, 0.52, x, -W / 2 - 0.005, 0.02, preto, ch=0.0)
        B(0.82, 0.03, 0.52, x, W / 2 + 0.005, 0.02, preto, ch=0.0)
    for k, (x, y) in enumerate([(-1.36, -0.8), (1.38, -0.8), (-1.36, 0.8), (1.38, 0.8)]):
        raio = 0.31 if not (k == 1 and bateu and not queimado) else 0.26
        if queimado:
            CR(raio * 0.7, 0.1, x, y * 1.05, raio * 0.7, metal("2a2622", 0.6, 0.3, 0.3), (math.pi / 2, 0, 0), v=14)
            continue
        CR(raio, 0.22, x, y, raio, M("121416", 0.85, 0.2, 0.2), (math.pi / 2, 0, 0), v=18)
        CR(raio * 0.58, 0.02, x, y + (-0.115 if y < 0 else 0.115), raio, metal("5c6268", 0.35, 0.2, 0.3), (math.pi / 2, 0, 0), v=12)
    # pára-choques, faróis, lanternas, grade e placa
    B(0.16, W + 0.04, 0.22, L / 2 + 0.02, 0, 0.26, M("3a3d40", 0.5, 0.2, 0.2), ch=0.04)
    B(0.16, W + 0.04, 0.22, -L / 2 - 0.02, 0, 0.26, M("3a3d40", 0.5, 0.2, 0.2), ch=0.04)
    for s in (-1, 1):
        B(0.05, 0.34, 0.15, L / 2 + 0.01, s * 0.6, 0.55, M("2a2d31" if queimado else "9a9a8c", 0.15), ch=0.0)
        B(0.05, 0.28, 0.12, -L / 2 - 0.01, s * 0.62, 0.58, M("3a1210" if queimado else "7a1e1a", 0.3), ch=0.0)
    B(0.04, 0.7, 0.14, L / 2 + 0.01, 0, 0.52, M("14161a", 0.7), ch=0.0)
    B(0.03, 0.4, 0.12, L / 2 + 0.03, 0, 0.3, M("c8c4a8", 0.7), ch=0.0)
    # portas, maçanetas, retrovisor
    for x in (-0.62, 0.5):
        B(0.014, 0.014, 0.5, x, -W / 2 - 0.008, 0.36, M("0c0d0f", 0.9), ch=0.0)
        B(0.14, 0.02, 0.03, x + 0.2, -W / 2 - 0.014, 0.68, M("8a8e92", 0.4), ch=0.0)
    B(0.12, 0.1, 0.08, 0.72, -W / 2 - 0.04, 0.98, tinta, ch=0.02)
    # ferrugem, amassado e poeira
    nf = int(8 + 14 * ferrugem)
    for k in range(nf):
        x = r.uniform(-2.0, 2.0)
        z = r.uniform(0.22, 0.7)
        B(r.uniform(0.08, 0.34), 0.012, r.uniform(0.05, 0.2), x, -W / 2 - 0.011, z, ferr if r.random() < 0.7 else M("23160f", 0.9), ch=0.0)
    for k in range(5):  # ferrugem no capô e teto
        B(r.uniform(0.1, 0.35), r.uniform(0.1, 0.4), 0.012, r.choice([1.5, -1.6, -0.1]) + r.uniform(-0.3, 0.3), r.uniform(-0.5, 0.5),
          r.choice([0.8, 1.33]), ferr, ch=0.0)
    if bateu and not queimado:
        B(0.5, 0.06, 0.3, 2.05, -0.5, 0.38, tinta2, ch=0.04, rot=(0, 0, 0.35))    # quina amassada
    if taxi:
        B(0.5, 0.2, 0.14, -0.1, 0, 1.37, M("d8cf9a", 0.6), ch=0.03)
        B(0.5, 0.01, 0.03, -0.1, -0.1, 1.45, M("14161a", 0.6), ch=0.0)
        for k in range(8):   # faixa quadriculada
            B(0.1, 0.014, 0.1, -1.5 + 0.2 * k + (0.1 if k % 2 else 0), -W / 2 - 0.016, 0.5, M("141618", 0.7), ch=0.0)
    if queimado:
        for k in range(10):
            B(r.uniform(0.1, 0.4), 0.014, r.uniform(0.05, 0.25), r.uniform(-1.9, 1.9), -W / 2 - 0.012, r.uniform(0.25, 0.9), M("0a0a0a", 0.9), ch=0.0)
    # vidro trincado: lascas claras no para-brisa e na lateral
    if not queimado:
        for k in range(4):
            B(r.uniform(0.18, 0.5), 0.012, 0.012, r.uniform(-0.8, 0.5), -(W - 0.22) / 2 - 0.03, r.uniform(0.95, 1.14), M("5a6a74", 0.2), ch=0.0,
              rot=(0, r.uniform(-0.8, 0.8), 0))


def carro_a(r):
    _carro(r, "7a2f28", 0.55)


def carro_b(r):
    _carro(r, "38546e", 0.4)


def carro_c(r):
    _carro(r, "a98d2d", 0.35, taxi=True)


def carro_queimado(r):
    _carro(r, "3a342f", 0.9, queimado=True, bateu=False)

