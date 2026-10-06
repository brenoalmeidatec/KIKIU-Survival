"""Hazaki MODULAR: corpo base + uma camada por equipamento/arma, todas no formato de folha que o jogo usa:
23 colunas x 4 linhas de quadros 44x60 (folha 1012x240). Linhas: baixo, esquerda, direita, cima.
Colunas (mesmo boneco, mesma câmera, pé sempre em PE_Y=57):
    0       parado
    1-8     andando (ciclo de 8 quadros)
    9-11    parado respirando (3 quadros)
    12-14   ataque (preparar, golpear com o braço direito, recuperar)
    15-16   defesa (braços cruzados na frente do rosto, corpo abaixado)
    17-18   levar dano (tronco e cabeça jogados para trás)
    19-22   morte (joelhos dobram, cai de lado, deitado, corpo no chão)

Visual (referência: arte/hazaki/hazaki_folha.png): cabelo preto curto em degradê, cavanhaque, pele bronzeada,
regata preta, faixas sujas nos punhos, luvas sem dedo, cinto com bolsinhos, pano vermelho no quadril,
calça cargo cinza-amarronzada com joelheiras, botas pretas e mochila tática.

Roda (Blender 4.5 LTS):
    blender -b -P hazaki.py
Saída: ../../projeto/assets/personagens/hazaki/corpo.png, andando_8.png (corpo + cabelo), rosto.png e camadas/<camada>.png

Por que encaixa (seção 7 do design: nada atravessando o corpo, nada flutuando, escala igual):
- todo equipamento é PRESO aos mesmos ossos do corpo (perna, braço, antebraço, tronco, cabeça) e anda junto;
- cada camada é renderizada com o corpo base presente como MÁSCARA invisível (holdout): o que fica
  atrás do corpo sai recortado. No jogo, as camadas são empilhadas quadro a quadro (jogador.gd).
"""
import math
import os
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pixel3d as px3  # noqa: E402
from pixel3d import caixa, cilindro, esfera  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "personagens", "hazaki"))
QW, QH = 44, 60
PE_Y = 57
COLUNAS = 23
DIRECOES = [0.0, -90.0, 90.0, 180.0]   # baixo, esquerda, direita, cima
PAL = px3.paleta_de("hz_neutro", "hz_pele", "hz_sangue", "ouro")

CAMADAS = {}          # nome -> [objetos]
_atual = ["base"]


def em(nome):
    """Daqui pra frente, o que for criado entra na camada 'nome'."""
    _atual[0] = nome
    CAMADAS.setdefault(nome, [])


def _r(o):
    CAMADAS[_atual[0]].append(o)
    return o


def cx(*a, **k):
    return _r(caixa(*a, **k))


def ci(*a, **k):
    return _r(cilindro(*a, **k))


def es(*a, **k):
    return _r(esfera(*a, **k))


def osso(nome, pos, pai):
    """Articulação invisível: gira tudo o que estiver preso nela, em torno de 'pos'."""
    bpy.ops.object.empty_add(location=pos)
    o = bpy.context.active_object
    o.name = nome
    px3.pendurar(o, pai)
    return o


def montar():
    t = lambda h: px3.material_toon("m_" + h, px3.cor(h))  # noqa: E731
    pele, pele_esc = t("b16e52"), t("7a4a38")
    pele_braco = t("c07a5a")
    preto, regata = t("2a2426"), t("26201f")
    cargo, cargo_esc, bolso = t("4a403c"), t("2a2426"), t("5e504b")
    faixa, metal = t("a89a8e"), t("7d6e65")
    pano, laca = t("75191a"), t("75191a")
    cabelo, fade = t("1a1618"), t("3d3335")
    olho = px3.material_toon("olho", px3.cor("0d0d10"), faixas=(1, 1, 1))
    ouro = t("c49a45")
    aco, aco_esc = t("7d6e65"), t("3d3335")

    bpy.ops.object.empty_add(location=(0, 0, 0))
    queda = bpy.context.active_object            # só gira na morte (cair de lado)
    bpy.ops.object.empty_add(location=(0, 0, 0))
    raiz = bpy.context.active_object             # direção para onde o boneco olha
    raiz.parent = queda
    bpy.ops.object.empty_add(location=(0, 0, 0))
    corpo = bpy.context.active_object            # pelve
    corpo.parent = raiz
    p = {"queda": queda, "raiz": raiz}
    torso = osso("torso", (0, 0, 0.95), corpo)
    cab = osso("cab", (0, 0, 1.5), torso)
    p["torso"], p["cab"] = torso, cab

    # ---------------- corpo base: calça cargo, botas pretas, regata preta, braços nus, mochila
    em("base")
    for lado, x in (("e", 0.13), ("d", -0.13)):
        perna = cx("perna_" + lado, (0.23, 0.28, 0.64), (x, 0, 0.55), cargo, corpo, pivo=(x, 0, 0.86))
        cx("pe_" + lado, (0.2, 0.33, 0.2), (x, -0.04, 0.1), preto, perna, chanfro=0.02)
        cx("joelheira_" + lado, (0.17, 0.05, 0.14), (x, -0.15, 0.5), cargo_esc, perna)
        cx("bolso_" + lado, (0.06, 0.15, 0.17), (x + (0.13 if lado == "e" else -0.13), -0.01, 0.6), bolso, perna)
        p["perna_" + lado] = perna
    cx("cinto", (0.5, 0.34, 0.1), (0, 0, 0.92), preto, corpo)
    for x in (0.16, -0.16):
        cx("bolsinho", (0.09, 0.07, 0.1), (x, -0.2, 0.92), cargo, corpo)
    cx("fivela", (0.07, 0.03, 0.07), (0, -0.185, 0.92), metal, corpo)
    cx("pano", (0.15, 0.1, 0.44), (-0.28, -0.05, 0.68), pano, corpo)
    cx("tronco_b", (0.4, 0.27, 0.3), (0, 0, 1.05), regata, torso, chanfro=0.03)
    cx("peito", (0.52, 0.31, 0.3), (0, 0, 1.28), regata, torso, chanfro=0.04)
    cx("decote", (0.2, 0.02, 0.12), (0, -0.155, 1.37), pele, torso)
    cx("dogtag", (0.045, 0.02, 0.075), (0, -0.17, 1.31), faixa, torso)
    for x in (0.15, -0.15):
        cx("alca", (0.07, 0.33, 0.34), (x, 0, 1.31), cargo_esc, torso)
    cx("mochila", (0.42, 0.2, 0.46), (0, 0.26, 1.2), cargo_esc, torso, chanfro=0.03)
    cx("mochila_topo", (0.36, 0.17, 0.12), (0, 0.27, 1.5), cargo, torso, chanfro=0.03)
    for lado, x in (("e", 0.37), ("d", -0.37)):
        braco = cx("braco_" + lado, (0.19, 0.19, 0.32), (x, 0, 1.24), pele_braco, torso, pivo=(x, 0, 1.4), chanfro=0.03)
        cx("ombro_" + lado, (0.23, 0.22, 0.17), (x + (0.01 if lado == "e" else -0.01), 0, 1.36), pele_braco, braco, chanfro=0.04)
        ante = cx("antebraco_" + lado, (0.15, 0.16, 0.22), (x, 0, 0.97), pele_braco, braco, pivo=(x, 0, 1.08), chanfro=0.02)
        cx("faixa_" + lado, (0.17, 0.17, 0.1), (x, 0, 0.8), faixa, ante)
        cx("luva_" + lado, (0.15, 0.16, 0.12), (x, 0, 0.69), preto, ante, chanfro=0.02)
        p["braco_" + lado] = braco
        p["ante_" + lado] = ante
    ci("pescoco", 0.09, 0.12, (0, 0, 1.52), pele, cab, vertices=8)
    cx("cabeca", (0.34, 0.31, 0.35), (0, 0, 1.68), pele, cab, chanfro=0.07)
    cx("mandibula", (0.31, 0.27, 0.09), (0, -0.01, 1.57), pele, cab, chanfro=0.03)
    for x in (0.077, -0.077):
        cx("olho", (0.055, 0.02, 0.04), (x, -0.158, 1.70), olho, cab)
        cx("sobrancelha", (0.1, 0.02, 0.025), (x * 1.05, -0.16, 1.765), olho, cab, rot=(0, -0.3 if x > 0 else 0.3, 0))
    cx("nariz", (0.045, 0.04, 0.055), (0, -0.17, 1.64), pele_esc, cab)
    cx("bigode", (0.15, 0.025, 0.03), (0, -0.155, 1.6), cabelo, cab)
    cx("cavanhaque", (0.065, 0.03, 0.09), (0, -0.15, 1.545), cabelo, cab)

    # ---------------- cabelo preto curto, degradê (fade) nas laterais e na nuca; o elmo esconde esta camada
    em("cabelo")
    cx("topo", (0.35, 0.33, 0.05), (0, 0.01, 1.86), cabelo, cab, chanfro=0.02)
    cx("franja", (0.33, 0.03, 0.04), (0, -0.155, 1.835), cabelo, cab)
    for x in (0.172, -0.172):
        cx("lateral", (0.02, 0.17, 0.07), (x, 0.03, 1.8), pele_esc, cab)
    cx("nuca", (0.32, 0.04, 0.1), (0, 0.155, 1.76), pele_esc, cab)
    cx("nuca_alta", (0.33, 0.04, 0.06), (0, 0.155, 1.83), fade, cab)

    # ---------------- Cabeça do Guerreiro (elmo de aço com chifres dourados e protetor de nuca)
    em("cabeca_guerreiro")
    es("domo", 0.25, (0, 0, 1.77), aco, cab, escala=(1, 1, 0.75))
    ci("aba", 0.28, 0.05, (0, 0, 1.74), aco_esc, cab, vertices=16)
    cx("nuca_placa", (0.46, 0.1, 0.2), (0, 0.18, 1.64), aco_esc, cab, rot=(-0.3, 0, 0), chanfro=0.02)
    for s_ in (1, -1):
        cx("chifre", (0.04, 0.03, 0.32), (s_ * 0.11, -0.18, 1.94), ouro, cab, rot=(0, s_ * 0.45, 0))
    cx("brasao", (0.1, 0.03, 0.08), (0, -0.2, 1.82), ouro, cab)

    # ---------------- máscara menpo (protege boca e queixo)
    em("mascara")
    cx("menpo", (0.33, 0.06, 0.14), (0, -0.185, 1.57), laca, cab, chanfro=0.02)

    # ---------------- Armadura Samurai (peitoral laqueado, ombreiras nos braços, saiote de placas)
    em("armadura_samurai")
    cx("peitoral", (0.56, 0.38, 0.46), (0, 0, 1.24), laca, torso, chanfro=0.03)
    for z in (1.1, 1.22, 1.34):
        cx("amarra", (0.57, 0.39, 0.025), (0, 0, z), ouro, torso)
    for lado, x in (("e", 0.36), ("d", -0.36)):
        cx("ombreira", (0.22, 0.28, 0.24), (x * 1.08, 0, 1.36), laca, p["braco_" + lado], chanfro=0.02)
    for x in (-0.18, 0.0, 0.18):
        cx("saiote", (0.17, 0.4, 0.26), (x, 0, 0.78), laca, corpo, chanfro=0.02)

    # ---------------- braçadeiras (protetor de antebraço)
    em("bracadeiras")
    for lado, x in (("e", 0.37), ("d", -0.37)):
        cx("bracadeira", (0.17, 0.17, 0.2), (x, 0, 0.97), aco_esc, p["ante_" + lado], chanfro=0.02)

    # ---------------- botas (cano reforçado e solado)
    em("botas")
    for lado, x in (("e", 0.13), ("d", -0.13)):
        cx("caneleira", (0.24, 0.29, 0.3), (x, 0, 0.3), aco_esc, p["perna_" + lado], chanfro=0.02)
        cx("bota", (0.22, 0.35, 0.07), (x, -0.04, 0.035), aco_esc, p["perna_" + lado])

    # ---------------- katana na mão direita (arma) e na bainha (quando as mãos estão ocupadas)
    em("katana_mao")
    ante_d = p["ante_d"]
    cx("tsuka", (0.05, 0.22, 0.05), (-0.37, -0.12, 0.69), t("1a1618"), ante_d)
    ci("tsuba", 0.07, 0.03, (-0.37, -0.24, 0.69), ouro, ante_d, rot=(math.radians(90), 0, 0), vertices=10)
    cx("lamina", (0.035, 0.72, 0.03), (-0.37, -0.6, 0.71), t("d0c4b6"), ante_d, rot=(-0.08, 0, 0))
    em("katana_bainha")
    cx("saya", (0.06, 0.08, 0.95), (0.27, 0.0, 0.9), t("1a1618"), corpo, rot=(0, -1.0, 0))
    cx("cabo", (0.05, 0.05, 0.22), (0.05, -0.02, 1.1), t("3d3335"), corpo, rot=(0, -1.0, 0))

    # ---------------- duas Desert Eagles, uma em cada mão
    em("pistolas")
    for lado, x in (("e", 0.37), ("d", -0.37)):
        ante = p["ante_" + lado]
        cx("cano", (0.08, 0.3, 0.09), (x, -0.17, 0.71), aco, ante, chanfro=0.01)
        cx("cabo_pistola", (0.07, 0.08, 0.14), (x, -0.04, 0.64), aco_esc, ante)
    return raiz, corpo, p


# (ação, quadro) de cada coluna da folha
ACOES = (
    [("parado", 0)] + [("andar", i) for i in range(8)]
    + [("respira", i) for i in range(3)] + [("ataque", i) for i in range(3)]
    + [("defesa", i) for i in range(2)] + [("dano", i) for i in range(2)] + [("morte", i) for i in range(4)]
)


def pose(corpo, p, acao, q):
    """Posiciona o boneco. acao: parado | andar (q = 0..7) | respira (0..2) | ataque (0..2) | defesa (0..1)
    | dano (0..1) | morte (0..3). O pé fica no mesmo lugar (só a morte sai do lugar, caindo)."""
    def z(b, x=0.0, y=0.0, w=0.0):
        p[b].rotation_euler = (x, y, w)

    for b in ("perna_e", "perna_d", "braco_e", "braco_d", "torso", "cab", "queda"):
        z(b)
    p["torso"].location = (0, 0, 0.95)
    p["cab"].location = (0, 0, 1.5)
    p["queda"].location = (0, 0, 0)
    corpo.location = (0, 0, 0)
    p["queda"].scale = (1, 1, 1)
    z("ante_e", -0.18)            # cotovelo levemente dobrado em repouso
    z("ante_d", -0.18)
    if acao == "andar":
        fase = 2 * math.pi * q / 8.0
        s = math.sin(fase)
        z("perna_e", 0.55 * s)
        z("perna_d", -0.55 * s)
        z("braco_e", -0.35 * s)
        z("braco_d", 0.35 * s)
        corpo.location = (0, 0, 0.04 * abs(math.cos(fase)))
    elif acao == "respira":
        sob = (0.0, 0.04, 0.02)[q]
        p["torso"].location = (0, 0, 0.95 + sob)
        p["cab"].location = (0, 0, 1.5 + sob * 0.5)
        z("braco_e", 0.0, 0.0, -0.03 * q)
        z("braco_d", 0.0, 0.0, 0.03 * q)
    elif acao == "ataque":
        if q == 0:      # preparar: braço direito para trás, tronco gira
            z("torso", 0.0, 0.0, 0.35)
            z("braco_d", 0.9)
            z("ante_d", -0.5)
            z("braco_e", -0.5)
            z("ante_e", -1.0)
        elif q == 1:    # golpear: braço direito para a frente, tronco joga o peso
            z("torso", -0.22, 0.0, -0.35)
            z("braco_d", -1.45)
            z("ante_d", -0.1)
            z("braco_e", 0.4)
            z("ante_e", -0.5)
            z("cab", 0.1)
            z("perna_e", -0.12)
            z("perna_d", 0.2)
        else:           # recuperar
            z("torso", -0.08, 0.0, -0.12)
            z("braco_d", -0.7)
            z("ante_d", -0.4)
            z("braco_e", -0.4)
            z("ante_e", -0.8)
    elif acao == "defesa":
        p["torso"].location = (0, 0, 0.95 - 0.07 - 0.03 * q)
        p["cab"].location = (0, 0, 1.5 - 0.03)
        z("torso", -0.25 - 0.05 * q)
        z("cab", 0.15)
        z("braco_e", -1.45, 0.0, -1.0)
        z("ante_e", -1.7)
        z("braco_d", -1.45, 0.0, 1.0)
        z("ante_d", -1.7)
        z("perna_e", 0.0, 0.0, 0.15)
        z("perna_d", 0.0, 0.0, -0.15)
    elif acao == "dano":
        k = 1.0 if q == 0 else 1.5
        z("torso", 0.22 * k)
        z("cab", 0.25 * k)
        z("braco_e", 0.5 * k, 0.0, -0.25 * k)
        z("braco_d", 0.5 * k, 0.0, 0.25 * k)
        z("ante_e", -0.4)
        z("ante_d", -0.4)
        z("perna_e", -0.1 * k)
        z("perna_d", 0.1 * k)
    elif acao == "morte":
        k = (0.0, 0.45, 0.85, 1.0)[q]       # quanto já caiu
        roll = (0.0, 0.75, 1.2, 1.57)[q]
        joelho = (0.45, 0.6, 0.3, 0.2)[q]
        z("perna_e", -joelho)
        z("perna_d", joelho * 0.6)
        corpo.location = (0, 0, -0.1 if q < 3 else -0.03)
        z("torso", -0.05 * (q + 1))
        z("cab", 0.2)
        z("braco_e", 0.3, 0.0, -0.3 * k)
        z("braco_d", -0.2, 0.0, 0.3 * k)
        lado = p.get("linha", 0) in (1, 2)
        if lado:    # de perfil: cai deitando na horizontal da tela (diagonal), um pouco menor para caber
            z("queda", 0.0, roll, 0.9 * roll / 1.57)
            e = 0.9 if q else 1.0
            p["queda"].scale = (e, e, e)
            p["queda"].location = (-(0.0, 0.6, 0.6, 0.55)[q] * math.sin(roll), 0.0, 0.2 * math.sin(roll))
        else:       # de frente/costas: cai para trás/para a frente (afastando da câmera), fica compacto
            z("queda", -roll, 0.0, 0.3 * roll / 1.57)
            p["queda"].location = (0.3 * math.sin(roll), 0.0, 0.2 * math.sin(roll))


def mostrar(camada):
    """Só a camada pedida aparece; o corpo base entra como máscara invisível (holdout) nas outras camadas."""
    for nome, objs in CAMADAS.items():
        for o in objs:
            o.hide_render = not (nome == camada or nome == "base")
            o.is_holdout = nome == "base" and camada != "base"


def main():
    import numpy as np
    px3.limpar_cena()
    px3.preparar_render(QW, QH)
    cam = px3.camera(elevacao_graus=32.0, escala=2.55)
    px3.luz(preenche=2.6)   # rosto de frente precisa ler (a luz principal vem de trás)
    raiz, corpo, p = montar()
    pose(corpo, p, "parado", 0)
    mostrar("base")
    px3.calibrar_pe(cam, PE_Y, QW, QH)
    folhas = {n: np.zeros((QH * 4, QW * COLUNAS, 4), dtype=np.float32) for n in CAMADAS}
    for linha, ang in enumerate(DIRECOES):
        raiz.rotation_euler = (0, 0, math.radians(ang))
        p["linha"] = linha
        for col, (acao, q) in enumerate(ACOES):
            pose(corpo, p, acao, q)
            for nome in CAMADAS:
                mostrar(nome)
                img = px3.pixelar(px3.render_rgba(), paleta=PAL)
                folhas[nome][linha * QH:(linha + 1) * QH, col * QW:(col + 1) * QW] = img
    # corpo.png = só o corpo (o jogador em camadas empilha o resto por cima);
    # andando_8.png = corpo + cabelo já juntos, pra quem NÃO usa camadas (rival do duelo, outros jogadores no online)
    px3.salvar_png(folhas["base"], os.path.join(SAIDA, "corpo.png"))
    junto = folhas["base"].copy()
    cab = folhas["cabelo"]
    tem = cab[:, :, 3] > 0.5
    junto[tem] = cab[tem]
    px3.salvar_png(junto, os.path.join(SAIDA, "andando_8.png"))
    for nome, f in folhas.items():
        if nome != "base":
            px3.salvar_png(f, os.path.join(SAIDA, "camadas", nome + ".png"))
    # rosto 52x52 (escolha de herói): de frente, com cabelo
    raiz.rotation_euler = (0, 0, 0)
    pose(corpo, p, "parado", 0)
    for nome, objs in CAMADAS.items():
        for o in objs:
            o.hide_render = nome not in ("base", "cabelo")
            o.is_holdout = False
    px3.preparar_render(52, 52)
    cam.data.ortho_scale = 1.05
    cam.data.shift_x = 0.0
    cam.data.shift_y = 0.0
    el = math.radians(20.0)
    cam.location = (0.0, -20.0 * math.cos(el), 1.64 + 20.0 * math.sin(el))
    cam.rotation_euler = (math.pi / 2 - el, 0.0, 0.0)
    px3.salvar_png(px3.pixelar(px3.render_rgba(), paleta=PAL), os.path.join(SAIDA, "rosto.png"))
    print("HAZAKI OK camadas:", ", ".join(CAMADAS))


main()
