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
    "Tecido vermelho queimado": "#4a5530", "Vermelho iluminado": "#66733f", "Dobras do tecido": "#2a3320",
    "Calça azul carvão": "#3a3a40", "Cabelo quase preto": "#3a2a1e", "Couro castanho": "#4a3322",
    "Pele": "#8a5f43", "Rosto iluminado": "#a7765a", "Aço azulado": "#6b737a", "Fio polido": "#cfd6dc",
    "Latão antigo": "#8a6a35", "Olho": "#0a0c14", "Manga escura": "#333d24",
}
BRILHANTES = {"Reflexo frio": "#9fb0c0"}
KATANA = ("Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido")


def _material(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    return m


def ajustar(ns, heroi, osso_de, apagar):
    """Tira a katana e o lenço (e a gola cruzada), põe a foice e a corrente na mão, a bandoleira e as mangas escuras."""
    for o in list(osso_de):
        if o.name.startswith(KATANA):
            del osso_de[o]
    apagar(("Lenço ao vento", "Face escura do lenço", "Gola cruzada") + KATANA)
    for o in heroi:
        if o.type == "MESH" and o.name.startswith("Braço"):
            o.data.materials[0] = _material("Manga escura")
    P, segment, line = ns["P"], ns["segment"], ns["line"]
    # mesma mão e mesma linha da katana (gerar.py): o cabo sobe acima da mão, a lâmina desce ao longo de d e a ponta curva para fora
    mao = Vector(P(.70, -.24, 1.46)) + Vector((0.02, -0.04, -0.09))
    d = Vector((.26, -.08, -.97)).normalized()
    fora = Vector((1, 0, 0))
    cabo_a = mao - d * .20
    novos = [segment("Cabo da foice", tuple(cabo_a), tuple(mao + d * .03), .052, .052, ns["leather"], 8),
             # "Guarda da katana" e "Ponta da katana" são os nomes que ossos.guarda_ponta (rastro do combo) procura: a foice segue o contrato da katana
             segment("Guarda da katana", tuple(mao - d * .03), tuple(mao + d * .03), .15, .15, ns["gold"], 8)]
    pts = [mao + d * (.06 + .14 * k) + fora * off for k, off in ((0, 0.0), (1, 0.0), (2, 0.0), (3, 0.02), (4, 0.07))]
    pts.append(pts[-1] + d * .06 + fora * .08)                 # ponta do gancho: curva para fora e para dentro
    novos.append(line("Lâmina da foice", [tuple(p) for p in pts[:-1]], .07, ns["silver"]))
    novos.append(segment("Ponta da katana", tuple(pts[-2]), tuple(pts[-1]), .07, .0, ns["silver"], 4))  # malha (ossos.guarda_ponta lê vértices)
    # corrente curta: 3 elos alternados (vertical, horizontal, vertical) presos à ponta de cima, logo acima da mão
    for i in range(3):
        a = cabo_a - d * (.02 + .10 * i)
        b = a + (fora * .07 if i % 2 else -d * .08)
        novos.append(segment("Elo da corrente %d" % i, tuple(a), tuple(b), .05, .05, ns["steel"], 8))
    bandoleira = segment("Bandoleira", P(-.30, -.26, 2.25), P(.30, -.27, 1.55), .05, .05, ns["leather"], 6)
    novos.append(bandoleira)
    heroi.extend(novos)
    for o in novos:
        osso_de[o] = "torso" if o is bandoleira else "antebraco_d"  # a arma vai com a mão; a bandoleira fica no tronco
