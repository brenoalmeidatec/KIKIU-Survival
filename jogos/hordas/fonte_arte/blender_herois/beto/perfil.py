"""Perfil do BERT (KUSARIGAMA) para o gerar.py do Hazaki (mesmo rig, mesmas animações e mesma câmera): muda o modelo, as cores e a arma.

Não há referência de arte do Bert no repo (referencia_herois/ só tem Lucas, Matheus e Nicão). A aparência segue a descrição do herói em
dados/v2_herois.json ("Laçador de corrente... aguenta muito, mas golpeia devagar"): casaco verde-oliva fechado, cabelo castanho, bandoleira
de couro, mangas escuras. A ARMA é a kusarigama: a foice fica na MÃO direita da tela (no mesmo lugar da katana, para as poses de golpe
do Hazaki continuarem valendo), com a lâmina em gancho na ponta de cima e uma corrente curta de 3 elos presa à ponta de baixo. Sem física.
"""
import bpy
from mathutils import Vector

NOME = "beto"

# Paleta escura e fechada do jogo: casaco verde-oliva (o Matheus é azul, o Hazaki é vinho). Chaves = nomes dos materiais do estudo do Codex.
PALETA = {
    "Tecido vermelho queimado": "#6aa84a", "Vermelho iluminado": "#84c060", "Dobras do tecido": "#4a8434",
    "Calça azul carvão": "#55555c", "Cabelo quase preto": "#3a2a1e", "Couro castanho": "#4a3322",
    "Pele": "#8a5f43", "Rosto iluminado": "#a7765a", "Aço azulado": "#6b737a", "Fio polido": "#cfd6dc",
    "Latão antigo": "#8a6a35", "Olho": "#0a0c14", "Manga escura": "#4a7a34", "Corrente prata": "#c8d0d8", "Cabo claro": "#4a2208",
}
BRILHANTES = {"Reflexo frio": "#9fb0c0"}
KATANA = ("Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido")


def fonte(src, trocar):
    """Cabelo mais baixo e curto (a cabeça cresce com CABECA): mais tufos, menos altos, testa aparecendo."""
    src = trocar(src, "for i in range(9):\n    a=i*2.399", "for i in range(12):\n    a=i*2.399")
    src = trocar(src, "math.cos(a)*.39,math.sin(a)*.33+.05,3.23+random.uniform(-.05,.12)", "math.cos(a)*.31,math.sin(a)*.27+.05,3.11+random.uniform(-.04,.07)")
    src = trocar(src, "P(0,.05,2.94),(.35,.29,.24),hair,2", "P(0,.05,3.0),(.34,.28,.19),hair,2")
    return src


def _material(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    return m


def ajustar(ns, heroi, osso_de, apagar):
    """Tira a katana, a bainha, o lenço e a gola cruzada; põe a kusarigama na mão direita, a bandoleira e as mangas escuras.

    A foice é modelada ao longo do eixo `d` da katana (as poses do combo do Hazaki continuam valendo), mas desenhada no referencial de REPOUSO
    (cabo de pé, lâmina em L saindo para fora, corrente em arco): `rest()` converte repouso -> modelo com o inverso da rotação que o ARMA_DIRECAO
    aplica, então no parado/andar/dano a foice aparece exatamente como foi desenhada."""
    for o in list(osso_de):
        if o.name.startswith(KATANA):
            del osso_de[o]
    apagar(("Lenço ao vento", "Face escura do lenço", "Gola cruzada", "Bainha", "Terminal da bainha") + KATANA)
    for o in heroi:
        if o.type == "MESH" and o.name.startswith("Braço"):
            o.data.materials[0] = _material("Manga escura")
    P, segment, ico = ns["P"], ns["segment"], ns["ico"]
    mao = Vector(P(.70, -.24, 1.46)) + Vector((0.02, -0.04, -0.09))
    d = Vector((.26, -.08, -.97)).normalized()                 # eixo do cabo no referencial do modelo (o mesmo da katana)
    alvo = Vector(_EM_PE).normalized()
    R = d.rotation_difference(alvo).to_matrix().inverted()      # repouso -> modelo
    out = (Vector((1, 0, 0)) - alvo * alvo.x).normalized()      # "para fora do corpo" (direita da tela), perpendicular ao cabo de pé
    cam = Vector((0, -1, 0))
    fr = (cam - alvo * alvo.dot(cam) - out * out.dot(cam)).normalized()   # para a câmera

    def rest(a, b, c=0.0):
        """a ao longo do cabo (para cima, no repouso), b para fora do corpo, c para a câmera; origem na mão."""
        return tuple(mao + R @ (alvo * a + out * b + fr * c))

    prata = ns["silver"]
    novos = []
    # cabo comprido (a mão fica a 2/3 do pomo): couro, com o pomo e a ponta metálica; a ponta (a=.92) é o ponto mais longe, o que fixa o eixo da arma
    novos.append(segment("Cabo da foice", rest(-.22, 0), rest(.78, 0), .075, .075, _material("Cabo claro"), 8))
    novos.append(segment("Ponta do cabo", rest(.76, 0), rest(.92, 0), .062, .0, prata, 6))
    # "Guarda da katana" e "Ponta da katana" são os nomes que ossos.guarda_ponta (rastro do combo) procura: a foice segue o contrato da katana
    novos.append(segment("Guarda da katana", rest(-.03, 0), rest(.03, 0), .10, .10, ns["gold"], 8))
    # LÂMINA EM L: sai do cabo perpendicular (para fora), engrossa na curva e a ponta do gancho volta para baixo; é isso que lê a 1x
    novos.append(segment("Lâmina da foice 0", rest(.68, 0), rest(.74, .16), .10, .09, prata, 6))
    novos.append(segment("Lâmina da foice 1", rest(.74, .16), rest(.70, .33), .09, .075, prata, 6))
    novos.append(segment("Lâmina da foice 2", rest(.70, .33), rest(.52, .39), .075, .055, prata, 6))
    novos.append(segment("Ponta da katana", rest(.52, .39), rest(.36, .31), .055, .0, prata, 5))     # malha: ossos.guarda_ponta lê vértices
    # CORRENTE: sai do pomo para FORA e cai em arco (Bezier quadrática), sem encostar no cabo; o peso fica longe da perna
    p0, c1, p2 = (-.22, 0.0), (-.26, .40), (-.42, .36)
    pts = []
    n = 7
    for k in range(n + 1):
        t = k / n
        a = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c1[0] + t * t * p2[0]
        b = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c1[1] + t * t * p2[1]
        pts.append((a, b, -.04))
    corrente = _material("Corrente prata")
    for k in range(n):
        novos.append(segment("Elo da corrente %d" % k, rest(*pts[k]), rest(*pts[k + 1]), .075 if k % 2 else .06, .075 if k % 2 else .06, corrente, 8))
    for k in range(1, n, 2):
        novos.append(ico("Elo redondo %d" % k, rest(*pts[k]), (.095, .095, .095), corrente, 1))
    novos.append(ico("Peso da corrente", rest(p2[0] - .08, p2[1] + .02, -.04), (.19, .19, .19), ns["steel"], 2))
    bandoleira = segment("Bandoleira", P(-.30, -.26, 2.25), P(.30, -.27, 1.55), .05, .05, ns["leather"], 6)
    novos.append(bandoleira)
    heroi.extend(novos)
    for o in novos:
        osso_de[o] = "torso" if o is bandoleira else "antebraco_d"  # a arma vai com a mão; a bandoleira fica no tronco


# ---------------------------------------------------------------- padrão do elenco (#586)
CABECA = 1.29
ARMA_ESCALA = 1.5
ARMA_ESPESSURA = 1.15
ARMA_CLAREAR = 0.30
_EM_PE = (0.14, -0.15, 1.0)   # foice de pé, como a katana do Brendan: a 1,5x apontando para baixo ela passaria do pé
ARMA_DIRECAO = {"parado": _EM_PE, "andar": _EM_PE, "dano": _EM_PE}
ARMA_ESCALA_ANIM = {"rolamento": 0.7, "morte": 0.8}
ESTILO_2D = True
RETRATO = {"pasta": "beto"}
