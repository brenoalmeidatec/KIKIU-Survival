"""Hazaki MODULAR: corpo base + uma camada por equipamento/arma, todas no formato de folha que o jogo usa
(9x4 quadros de 44x60; linhas baixo, esquerda, direita, cima; coluna 0 parado, 1-8 andando).

Roda (Blender 4.5 LTS):
    blender -b -P hazaki.py
Saída: ../../projeto/assets/personagens/hazaki/andando_8.png (corpo base), rosto.png e camadas/<camada>.png

Por que encaixa (seção 7 do design: nada atravessando o corpo, nada flutuando, escala igual):
- todo equipamento é PRESO aos mesmos ossos do corpo (perna, braço, tronco) e anda junto;
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
DIRECOES = [0.0, -90.0, 90.0, 180.0]   # baixo, esquerda, direita, cima
PAL = px3.paleta_de("aco", "sangue", "couro", "ouro", "noite", "pele")

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


def montar():
    t = lambda h: px3.material_toon("m_" + h, px3.cor(h))  # noqa: E731
    pele, pele_esc = t("c98e62"), t("9c6444")
    kimono, gola = t("c9c3d6"), t("223566")
    hakama, obi = t("223566"), t("7e2027")
    cabelo = t("1d1a2b")
    olho = px3.material_toon("olho", px3.cor("0d0b14"), faixas=(1, 1, 1))
    laca, laca_esc, ouro = t("7e2027"), t("2e2a40"), t("c49a45")
    aco, aco_esc = t("7a7590"), t("45405c")
    couro = t("4a3324")

    bpy.ops.object.empty_add(location=(0, 0, 0))
    raiz = bpy.context.active_object
    bpy.ops.object.empty_add(location=(0, 0, 0))
    corpo = bpy.context.active_object
    corpo.parent = raiz
    p = {}

    # ---------------- corpo base: kimono claro, hakama índigo, faixa vermelha (o Hazaki "normal")
    em("base")
    for lado, x in (("e", 0.13), ("d", -0.13)):
        perna = cx("perna_" + lado, (0.2, 0.24, 0.62), (x, 0, 0.55), hakama, corpo, pivo=(x, 0, 0.86))
        cx("pe_" + lado, (0.16, 0.26, 0.1), (x, -0.04, 0.06), couro, perna)
        p["perna_" + lado] = perna
    cx("tronco", (0.48, 0.32, 0.58), (0, 0, 1.17), kimono, corpo, chanfro=0.03)
    cx("gola_e", (0.07, 0.04, 0.42), (0.07, -0.17, 1.25), gola, corpo, rot=(0, 0.35, 0))
    cx("gola_d", (0.07, 0.04, 0.42), (-0.07, -0.17, 1.25), gola, corpo, rot=(0, -0.35, 0))
    cx("obi", (0.52, 0.36, 0.1), (0, 0, 0.92), obi, corpo)
    for lado, x in (("e", 0.32), ("d", -0.32)):
        braco = cx("braco_" + lado, (0.15, 0.15, 0.3), (x, 0, 1.27), kimono, corpo, pivo=(x, 0, 1.4))
        cx("antebraco_" + lado, (0.12, 0.12, 0.22), (x, 0, 1.02), pele, braco)
        cx("mao_" + lado, (0.13, 0.13, 0.1), (x, 0, 0.86), pele, braco)
        p["braco_" + lado] = braco
    ci("pescoco", 0.09, 0.1, (0, 0, 1.49), pele, corpo, vertices=8)
    cx("cabeca", (0.4, 0.36, 0.4), (0, 0, 1.7), pele, corpo, chanfro=0.07)
    for x in (0.09, -0.09):
        cx("olho", (0.06, 0.02, 0.07), (x, -0.185, 1.71), olho, corpo)
    cx("sobrancelha", (0.3, 0.02, 0.03), (0, -0.185, 1.79), olho, corpo)
    cx("nariz", (0.05, 0.03, 0.06), (0, -0.19, 1.65), pele_esc, corpo)

    # ---------------- cabelo (preso em coque de samurai); o elmo esconde esta camada
    em("cabelo")
    cx("topo", (0.44, 0.4, 0.12), (0, 0.01, 1.9), cabelo, corpo, chanfro=0.04)
    cx("nuca", (0.42, 0.12, 0.3), (0, 0.15, 1.75), cabelo, corpo)
    cx("franja", (0.42, 0.06, 0.05), (0, -0.17, 1.89), cabelo, corpo)
    ci("coque", 0.06, 0.18, (0, 0.08, 2.0), cabelo, corpo, rot=(math.radians(-60), 0, 0), vertices=8)

    # ---------------- Cabeça do Guerreiro (elmo de aço com chifres dourados e protetor de nuca)
    em("cabeca_guerreiro")
    es("domo", 0.27, (0, 0, 1.8), aco, corpo, escala=(1, 1, 0.75))
    ci("aba", 0.3, 0.05, (0, 0, 1.77), aco_esc, corpo, vertices=16)
    cx("nuca_placa", (0.5, 0.1, 0.22), (0, 0.2, 1.66), aco_esc, corpo, rot=(-0.3, 0, 0), chanfro=0.02)
    for s in (1, -1):
        cx("chifre", (0.04, 0.03, 0.32), (s * 0.12, -0.2, 1.98), ouro, corpo, rot=(0, s * 0.45, 0))
    cx("brasao", (0.1, 0.03, 0.08), (0, -0.22, 1.85), ouro, corpo)

    # ---------------- máscara menpo (protege boca e queixo)
    em("mascara")
    cx("menpo", (0.36, 0.06, 0.16), (0, -0.2, 1.6), laca, corpo, chanfro=0.02)
    cx("bigode", (0.2, 0.02, 0.03), (0, -0.235, 1.64), ouro, corpo)

    # ---------------- Armadura Samurai (peitoral laqueado, ombreiras nos braços, saiote de placas)
    em("armadura_samurai")
    cx("peitoral", (0.54, 0.38, 0.46), (0, 0, 1.22), laca_esc, corpo, chanfro=0.03)
    for z in (1.08, 1.2, 1.32):
        cx("amarra", (0.55, 0.39, 0.025), (0, 0, z), ouro, corpo)
    for lado, x in (("e", 0.36), ("d", -0.36)):
        cx("ombreira", (0.2, 0.26, 0.26), (x * 1.08, 0, 1.3), laca, p["braco_" + lado], chanfro=0.02)
    for x in (-0.18, 0.0, 0.18):
        cx("saiote", (0.17, 0.4, 0.26), (x, 0, 0.78), laca, corpo, chanfro=0.02)

    # ---------------- braçadeiras (protetor de antebraço)
    em("bracadeiras")
    for lado, x in (("e", 0.32), ("d", -0.32)):
        cx("bracadeira", (0.15, 0.15, 0.2), (x, 0, 1.03), aco_esc, p["braco_" + lado], chanfro=0.02)

    # ---------------- botas (caneleiras de ferro)
    em("botas")
    for lado, x in (("e", 0.13), ("d", -0.13)):
        cx("caneleira", (0.22, 0.27, 0.32), (x, 0, 0.27), aco_esc, p["perna_" + lado], chanfro=0.02)
        cx("bota", (0.2, 0.3, 0.12), (x, -0.04, 0.07), couro, p["perna_" + lado])

    # ---------------- katana na mão direita (arma) e na bainha (quando as mãos estão ocupadas)
    em("katana_mao")
    braco_d = p["braco_d"]
    cx("tsuka", (0.05, 0.22, 0.05), (-0.32, -0.12, 0.86), t("1d1a2b"), braco_d)
    ci("tsuba", 0.07, 0.03, (-0.32, -0.24, 0.86), ouro, braco_d, rot=(math.radians(90), 0, 0), vertices=10)
    cx("lamina", (0.035, 0.72, 0.03), (-0.32, -0.6, 0.88), t("c9c3d6"), braco_d, rot=(-0.08, 0, 0))
    em("katana_bainha")
    cx("saya", (0.06, 0.08, 0.95), (0.27, 0.0, 0.9), t("1d1a2b"), corpo, rot=(0, -1.0, 0))
    cx("cabo", (0.05, 0.05, 0.22), (0.05, -0.02, 1.1), t("2e2a40"), corpo, rot=(0, -1.0, 0))

    # ---------------- duas Desert Eagles, uma em cada mão
    em("pistolas")
    for lado, x in (("e", 0.32), ("d", -0.32)):
        braco = p["braco_" + lado]
        cx("cano", (0.08, 0.3, 0.09), (x, -0.17, 0.87), aco, braco, chanfro=0.01)
        cx("cabo_pistola", (0.07, 0.08, 0.14), (x, -0.04, 0.8), aco_esc, braco)
    return raiz, corpo, p


def pose(corpo, p, fase, andando):
    s = math.sin(fase) if andando else 0.0
    p["perna_e"].rotation_euler = (0.55 * s, 0, 0)
    p["perna_d"].rotation_euler = (-0.55 * s, 0, 0)
    p["braco_e"].rotation_euler = (-0.35 * s, 0, 0)
    p["braco_d"].rotation_euler = (0.35 * s, 0, 0)
    corpo.location = (0, 0, 0.04 * abs(math.cos(fase)) if andando else 0.0)


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
    pose(corpo, p, 0.0, False)
    mostrar("base")
    px3.calibrar_pe(cam, PE_Y, QW, QH)
    folhas = {n: np.zeros((QH * 4, QW * 9, 4), dtype=np.float32) for n in CAMADAS}
    for linha, ang in enumerate(DIRECOES):
        raiz.rotation_euler = (0, 0, math.radians(ang))
        for col in range(9):
            pose(corpo, p, 2 * math.pi * (col - 1) / 8.0, col > 0)
            for nome in CAMADAS:
                mostrar(nome)
                q = px3.pixelar(px3.render_rgba(), paleta=PAL)
                folhas[nome][linha * QH:(linha + 1) * QH, col * QW:(col + 1) * QW] = q
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
    pose(corpo, p, 0.0, False)
    for nome, objs in CAMADAS.items():
        for o in objs:
            o.hide_render = nome not in ("base", "cabelo")
            o.is_holdout = False
    px3.preparar_render(52, 52)
    cam.data.ortho_scale = 1.05
    cam.data.shift_x = 0.0
    cam.data.shift_y = 0.0
    el = math.radians(20.0)
    cam.location = (0.0, -20.0 * math.cos(el), 1.62 + 20.0 * math.sin(el))
    cam.rotation_euler = (math.pi / 2 - el, 0.0, 0.0)
    px3.salvar_png(px3.pixelar(px3.render_rgba(), paleta=PAL), os.path.join(SAIDA, "rosto.png"))
    print("HAZAKI OK camadas:", ", ".join(CAMADAS))


main()
