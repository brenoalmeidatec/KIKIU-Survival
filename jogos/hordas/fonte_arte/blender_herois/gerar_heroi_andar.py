"""Piloto: herói (Hazaki samurai, o padrão da v2) andando, 6 quadros x 8 direções, cor + normal, render grande e redução BOX.

Reaproveita o modelo/rig por script de fonte_arte/modelos3d/hazaki.py (articulações = empties, sem modelar à mão) e as
funções de paleta/normal/contorno de prototipos/cara_nova/gerar_cara_nova.py (carregado em memória, sem rodar o main dele).
O que muda em relação ao cara_nova: ciclo de andar NOVO de 6 quadros (contato, descida, passagem, contato oposto,
descida, passagem) com balanço de braços, quadril girando, subida do pé, sobe-e-desce do corpo e da cabeça; e render
em SUPERAMOSTRAGEM (4x, com antialias) reduzido com média por bloco (BOX) antes de paleta + contorno de 1 px.

Uso (Blender 4.5, em segundo plano):
    blender -b -t 6 -P gerar_heroi_andar.py [-- <pasta_de_saida>]
Saída: hazaki_samurai_blender_{albedo,normal}.png (+ _emissao se houver) e .json, no MESMO formato das folhas de
prototipos/cara_nova/sprites: quadro 32x44, uma linha por direção (baixo, esquerda, direita, cima, baixo_esq, baixo_dir,
cima_esq, cima_dir), colunas = [parado, andar0..andar5].
"""
import math
import os
import sys
import time

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, "..", ".."))
CARA_NOVA = os.path.join(HORDAS, "prototipos", "cara_nova", "gerar_cara_nova.py")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAIDA = ARGS[0] if ARGS else AQUI

SS = 4              # superamostragem: render em 4x o quadro do jogo
AMOSTRAS = 8        # amostras de antialias do EEVEE
QUADROS_ANDAR = 6
NOME = "hazaki_samurai_blender"


def carregar_cara_nova():
    """gerar_cara_nova.py sem o bloco final que roda o modo (só queremos as funções e o patch de materiais)."""
    with open(CARA_NOVA, encoding="utf-8") as f:
        src = f.read()
    corte = src.rsplit('\nif MODO == "heroi":', 1)[0]
    ns = {"__name__": "cara_nova_lib", "__file__": CARA_NOVA}
    antes = sys.argv
    sys.argv = [antes[0], "--", "heroi", "samurai"]      # MODO/ARGS do módulo (lidos no topo dele)
    exec(compile(corte, CARA_NOVA, "exec"), ns)
    sys.argv = antes
    return ns


# ------------------------------------------------------------------ pose: ciclo de andar de 6 quadros

# subida/descida do corpo por quadro dentro de meio passo: contato (médio), descida (baixo), passagem/subida (alto)
BOB = (0.0, -1.0, 1.0)
PERNA = 0.62        # rad de balanço da perna
BRACO = 0.65        # rad de balanço do braço (oposto à perna do mesmo lado)
ELEVA_PE = 0.13     # m que o pé sobe no balanço
SOBE_CORPO = 0.045  # m do sobe-e-desce do quadril
QUADRIL = 0.10      # rad de giro do quadril (ombros giram ao contrário)


def pose_andar(hz, corpo, p, q, base):
    hz["pose"](corpo, p, "parado", 0)
    fase = 2 * math.pi * q / QUADROS_ANDAR
    c, s = math.cos(fase), math.sin(fase)
    # frente = ângulo negativo em X (o boneco olha para -Y)
    p["perna_e"].rotation_euler = (-PERNA * c, 0, 0)
    p["perna_d"].rotation_euler = (PERNA * c, 0, 0)
    p["perna_e"].location = (base["pe"][0], base["pe"][1], base["pe"][2] + ELEVA_PE * max(0.0, -s))
    p["perna_d"].location = (base["pd"][0], base["pd"][1], base["pd"][2] + ELEVA_PE * max(0.0, s))
    p["braco_e"].rotation_euler = (BRACO * c, 0, 0)
    p["braco_d"].rotation_euler = (-BRACO * c, 0, 0)
    # cotovelo dobra mais no braço que vai à frente
    p["ante_e"].rotation_euler = (-0.18 - 0.35 * max(0.0, -c), 0, 0)
    p["ante_d"].rotation_euler = (-0.18 - 0.35 * max(0.0, c), 0, 0)
    b = BOB[q % 3]
    bant = BOB[(q - 1) % 3]
    corpo.location = (0, 0, SOBE_CORPO * b)
    corpo.rotation_euler = (0, 0, QUADRIL * c)
    p["torso"].rotation_euler = (-0.05, 0, -2.0 * QUADRIL * c)       # leve inclinação e ombros contra o quadril
    p["torso"].location = (0, 0, 0.95)
    p["cab"].rotation_euler = (0.0, 0, QUADRIL * c)                   # cabeça segue o quadril (anula o giro do torso)
    p["cab"].location = (0, 0, 1.5 - 0.35 * SOBE_CORPO * bant)       # cabeça atrasa um quadro no sobe-e-desce


# ------------------------------------------------------------------ render grande + BOX

def reduzir_box(px, f):
    """Média por bloco f x f, com a cor ponderada pelo alfa (borda sem 'franja' escura)."""
    h, w = px.shape[0] // f, px.shape[1] // f
    a = px[:h * f, :w * f, 3]
    rgb = px[:h * f, :w * f, :3] * a[:, :, None]
    soma_a = a.reshape(h, f, w, f).sum(axis=(1, 3))
    soma_c = rgb.reshape(h, f, w, f, 3).sum(axis=(1, 3))
    out = np.zeros((h, w, 4), np.float32)
    out[:, :, :3] = soma_c / np.maximum(soma_a, 1e-6)[:, :, None]
    out[:, :, 3] = soma_a / float(f * f)
    return out


def render_passes(ns, pal):
    d = {}
    for pas in ns["PASSES"]:
        ns["trocar_passe"](pas)
        px = reduzir_box(ns["ler_render"](), SS)
        if pas == "albedo":
            d[pas] = ns["pos_albedo"](px, pal, False)
        elif pas == "normal":
            d[pas] = ns["pos_normal"](px, False)
        else:
            d[pas] = ns["pos_emissao"](px, False)
    return d


def main():
    t0 = time.perf_counter()
    ns = carregar_cara_nova()
    px3, bpy = ns["px3"], ns["bpy"]
    hz = ns["exec_hazaki"]()
    W, H = ns["QUADRO_HEROI"]
    px3.limpar_cena()
    ns["VARIANTES"].clear()
    px3.preparar_render(W * SS, H * SS)
    cena = bpy.context.scene
    cena.render.filter_size = 1.0               # antialias ligado: o BOX precisa de cobertura parcial nas bordas
    cena.eevee.taa_render_samples = AMOSTRAS
    cam = px3.camera(elevacao_graus=ns["ELEVACAO"], escala=max(W, H) / ns["PPU"])
    raiz, corpo, p = hz["montar"]()
    visiveis = ("base", "cabelo", "botas", "bracadeiras", "katana_bainha", "armadura_samurai")
    for nome, objs in hz["CAMADAS"].items():
        for o in objs:
            o.hide_render = nome not in visiveis
            o.is_holdout = False
    ns["engrossar_olhos"]()
    ns["trocar_passe"]("albedo")
    base = {"pe": tuple(p["perna_e"].location), "pd": tuple(p["perna_d"].location)}
    hz["pose"](corpo, p, "parado", 0)
    px3.calibrar_pe(cam, ns["PE_HEROI"] * SS + SS - 1, W * SS, H * SS)
    pal = hz["PAL"]
    print("setup %.1fs" % (time.perf_counter() - t0))

    t1 = time.perf_counter()
    quadros = {}
    n_render = 0
    for linha, ang in enumerate(hz["DIRECOES"]):
        raiz.rotation_euler = (0, 0, math.radians(ang))
        p["linha"] = linha
        hz["pose"](corpo, p, "parado", 0)
        quadros[(linha, 0)] = render_passes(ns, pal)
        for q in range(QUADROS_ANDAR):
            pose_andar(hz, corpo, p, q, base)
            quadros[(linha, 1 + q)] = render_passes(ns, pal)
        n_render += (1 + QUADROS_ANDAR) * len(ns["PASSES"])
    dt = time.perf_counter() - t1
    cols = 1 + QUADROS_ANDAR
    folhas = ns["montar_folha"](NOME, quadros, len(hz["DIRECOES"]), cols, W, H)
    ns["SAIDA"] = SAIDA
    ns["gravar"](NOME, folhas, W, H,
                 {"linhas": ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"],
                  "colunas": ["parado"] + ["andar%d" % k for k in range(QUADROS_ANDAR)],
                  "superamostragem": SS, "tempo_render_s": round(dt, 1)})
    pose_andar(hz, corpo, p, 0, base)
    raiz.rotation_euler = (0, 0, 0)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SAIDA, "hazaki_samurai_andar.blend"), compress=True)
    print("TEMPO: %d renders (%d quadros x 3 passes, %dx%d) em %.1fs = %.2fs/render; total %.1fs"
          % (n_render, n_render // 3, W * SS, H * SS, dt, dt / n_render, time.perf_counter() - t0))


main()
