"""Perfil do FABIAN (herói fabio, arma YUMI) para o gerar.py do Hazaki: mesmo rig, mesma câmera e mesma técnica de render; muda o modelo, as cores e a arma.

Herói: arqueiro de arco longo (YUMI). Golpe: tiro, tiro, tiro duplo (ver dados/v2_herois.json, "fabio"). Aqui a katana sai e entra um arco
ENCURTADO (cerca de 1 m, o que cabe nos 44 px do quadro), preso ao tronco, do lado esquerdo da tela, na frente do corpo: é ele que a mão esquerda
segura nas animações de repouso, e no tiro o braço esquerdo estica até a pega, enquanto o direito puxa a corda até o rosto.
Limitações: a corda é uma linha fixa (não curva no tiro), não há flecha no quadro (a flecha é o projétil do jogo), e as animações de escudo, rolamento,
dano e morte são as do Hazaki (com o arco preso ao tronco), não poses próprias.
"""
import bpy

NOME = "fabio"

# Paleta escura do jogo: traje verde-musgo fechado (no lugar do vermelho do Hazaki), calça de ameixa escura, couro e cabelo escuros.
PALETA = {
    "Tecido vermelho queimado": "#3b5a3c",   # casaco verde-musgo
    "Vermelho iluminado": "#587d54",         # gola e aba clara
    "Dobras do tecido": "#25402a",           # aba escura e costura
    "Calça azul carvão": "#33283d",          # calça de ameixa escura
    "Cabelo quase preto": "#1b1d28",
    "Couro castanho": "#5c4030",
    "Pele": "#8e5a3e", "Rosto iluminado": "#a56e4d",
    "Aço azulado": "#66798d", "Fio polido": "#d6e0ea",
    "Latão antigo": "#9a7a3e", "Olho": "#0a0c14",
    "Manga escura": "#2a3a2c", "Camisa escura": "#1f2a24", "Bota preta": "#2a2932", "Braçadeira": "#3d302d",
}
BRILHANTES = {"Reflexo frio": "#8ea9c4"}

KATANA = ("Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido")
# arco: eixo vertical no tronco, do lado esquerdo da tela e à frente; z = 0,95 a 2,45 (~0,9 m, encurtado de um yumi de 2 m)
ARCO_X, ARCO_Y, ARCO_Z, ARCO_MEIA = -0.86, -0.30, 1.70, 0.75


def _material(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    return m


def ajustar(ns, heroi, osso_de, apagar):
    """Tira a katana e o lenço, põe o casaco verde, a calça de ameixa e o arco preso ao tronco."""
    apagar(KATANA + ("Lenço ao vento", "Face escura do lenço"))
    por_prefixo = [
        ("Braço", "Manga escura"), ("Antebraço", "Pele"), ("Proteção", "Braçadeira"),
        ("Bota ", "Bota preta"), ("Aba do casaco esquerda", "Tecido vermelho queimado"), ("Faixa da bota", "Couro castanho"), ("Fivela pequena", "Aço azulado"),
    ]
    for o in heroi:
        for pref, nome in por_prefixo:
            if o.name.startswith(pref) and o.type == "MESH":
                o.data.materials[0] = _material(nome)
    P, segment, line = ns["P"], ns["segment"], ns["line"]
    novos = []
    # madeira do arco: 8 trechos formando um arco (a pega fica no meio, as pontas voltam para o corpo)
    n = 8
    pts = []
    for i in range(n + 1):
        t = -1.0 + 2.0 * i / n
        pts.append(P(ARCO_X + 0.10 * t * t, ARCO_Y, ARCO_Z + ARCO_MEIA * t))
    for a, b in zip(pts[:-1], pts[1:]):
        novos.append(segment("Madeira do arco", a, b, 0.045, 0.045, ns["hair"], 6))
    # pega enrolada no meio e corda de uma ponta à outra (linha fina, clara)
    meio = pts[n // 2]
    novos.append(segment("Pega do arco", (meio[0], meio[1] - 0.02, meio[2] - 0.20), (meio[0], meio[1] - 0.02, meio[2] + 0.20), 0.07, 0.07, ns["leather"], 6))
    novos.append(line("Corda do arco", [pts[0], pts[-1]], 0.02, ns["silver"]))
    heroi.extend(novos)
    for o in novos:
        osso_de[o] = "torso"
