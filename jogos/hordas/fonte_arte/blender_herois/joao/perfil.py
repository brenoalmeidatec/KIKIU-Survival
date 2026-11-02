"""Perfil do JOHN para o gerar.py do Hazaki (mesmo rig, mesmas animações e mesma câmera): só muda o modelo e as cores.

Referência: assets/personagens/joao/rosto.png (primeiro quadro do retrato): cabelo curto e escuro com entradas, bigode e barba curta escuros,
pele morena e camisa laranja. Arma: NAGINATA (lança de lâmina curva), encurtada em relação à katana do Hazaki para caber no quadro de 32x44.
O modelo parte do mesmo estudo do Codex que o Hazaki usa; trocamos o que faz o John ser o John: cores, cabelo curto, barba, camisa laranja sem lenço
e a naginata NA MÃO DIREITA (a mão esquerda segue a pose de cada animação; o rig não tem IK de duas mãos para a haste).
Os nomes "Guarda da katana" e "Ponta da katana" são mantidos porque `ossos.guarda_ponta` os usa como referência da arma nas animações.
"""
import bpy
from mathutils import Vector

NOME = "joao"

# Paleta escura do jogo, tirada do retrato (camisa laranja, pele morena, cabelo e barba escuros). Chaves = nomes dos materiais do estudo do Codex + os criados abaixo.
PALETA = {
    "Tecido vermelho queimado": "#d0601c",   # camisa laranja queimado (cor-assinatura do John; era o casaco vermelho)
    "Vermelho iluminado": "#ee7a2a",         # gola e aba clara
    "Dobras do tecido": "#8a3a12",           # costura e aba escura
    "Calça azul carvão": "#2a2630",          # calça escura (a cor-assinatura fica na camisa)
    "Cabelo quase preto": "#16141a",
    "Couro castanho": "#4e3728",
    "Pele": "#9a6444", "Rosto iluminado": "#b97a55",
    "Aço azulado": "#7f94aa", "Fio polido": "#f0f6fc",
    "Latão antigo": "#9a7a3e", "Olho": "#0a0c14",
    "Manga escura": "#b4501a", "Camisa escura": "#8a3a12", "Bota preta": "#2a2932", "Braçadeira": "#3d302d",
    "Barba": "#3a2820",                      # barba e bigode escuros
    "Madeira da haste": "#d4a868",           # haste da naginata: madeira CLARA, para contrastar com o chão escuro e com a camisa
    "Aço da lâmina": "#b4c6da",              # lâmina da naginata (mais clara que o aço da fivela)
}
BRILHANTES = {"Reflexo frio": "#8ea9c4"}


# medidas da naginata (unidades do modelo, antes do ARMA_ESCALA): haste de cada lado da mão, raio da haste, lâmina e curvatura
HASTE_BAIXO, HASTE_CIMA, RAIO_HASTE, LAMINA, CURVA = 0.42, 0.72, 0.065, 0.52, 0.17


def fonte(src, trocar):
    """Cabelo curto: tufos mais baixos e mais curtos, testa mais alta (entradas), como no retrato."""
    src = trocar(src, "math.cos(a)*.39,math.sin(a)*.33+.05,3.23+random.uniform(-.05,.12)", "math.cos(a)*.36,math.sin(a)*.30+.05,3.12+random.uniform(-.04,.05)")
    src = trocar(src, "P(0,.05,2.94),(.35,.29,.24),hair,2", "P(0,.05,2.90),(.33,.27,.20),hair,2")
    return src


def _material(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    return m


def ajustar(ns, heroi, osso_de, apagar):
    """Tira o lenço, põe a camisa laranja e a calça, a barba e o bigode, e troca a katana pela naginata encurtada (na mão direita da tela)."""
    apagar(("Lenço ao vento", "Face escura do lenço", "Gola cruzada",
            "Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido",
            "Bainha", "Terminal da bainha"))   # o John não carrega a bainha da katana do Hazaki
    por_prefixo = [
        ("Braço", "Manga escura"), ("Antebraço", "Manga escura"), ("Proteção", "Couro castanho"),
        ("Bota ", "Bota preta"), ("Aba do casaco esquerda", "Tecido vermelho queimado"), ("Faixa da bota", "Couro castanho"), ("Fivela pequena", "Aço azulado"),
    ]
    for o in heroi:
        for pref, nome in por_prefixo:
            if o.name.startswith(pref) and o.type == "MESH":
                o.data.materials[0] = _material(nome)
    P, box, segment, ico = ns["P"], ns["box"], ns["segment"], ns["ico"]
    novos = []

    # barba e bigode (nomes "Cabeça ..." entram na escala da cabeça e no osso da cabeça, como o resto do rosto)
    novos.append(box("Cabeça barba", P(0, -.262, 2.43), (.27, .07, .20), _material("Barba"), .03))
    novos.append(box("Cabeça bigode", P(0, -.292, 2.585), (.14, .04, .045), _material("Barba"), .015))

    # NAGINATA na mão direita da tela. Haste LONGA nos dois lados da mão (a ARMA_DIRECAO a põe inclinada para fora no parado/andar/dano:
    # a lâmina curva no alto, perto da altura da cabeça; a ponta de baixo, na canela). Modelada como a katana: ponta para baixo e para fora.
    punho = Vector(P(.70, -.24, 1.46))
    mao = punho + Vector((0.02, -0.04, -0.09))
    d = Vector((.45, -.08, -.89)).normalized()
    p = Vector((1.0, 0.0, 0.0))
    p = (p - p.dot(d) * d).normalized()           # direção do arco da lâmina: perpendicular ao eixo, para fora do corpo
    cabo_a = mao - d * HASTE_BAIXO
    cabo_b = mao + d * HASTE_CIMA
    novos.append(segment("Cabo da naginata", tuple(cabo_a), tuple(cabo_b), RAIO_HASTE, RAIO_HASTE, _material("Madeira da haste"), 6))
    novos.append(segment("Contra-peso da naginata", tuple(cabo_a - d * .06), tuple(cabo_a + d * .04), RAIO_HASTE * 1.5, RAIO_HASTE * 1.5, _material("Latão antigo"), 6))
    novos.append(segment("Guarda da katana", tuple(cabo_b - d * .03), tuple(cabo_b + d * .04), .115, .115, _material("Latão antigo"), 8))
    novos.append(segment("Borla da naginata", tuple(cabo_b - d * .16), tuple(cabo_b - d * .05), .075, .075, _material("Vermelho iluminado"), 6))
    base = cabo_b + d * .05
    pts = [base + d * (LAMINA * t) + p * (CURVA * t * t) for t in (0.0, .25, .5, .75, 1.0, 1.12)]
    raios = [.14, .19, .17, .12, .065]            # lâmina larga no meio (barriga), para ler como lâmina em 44 px
    for i in range(len(pts) - 2):
        novos.append(segment("Lâmina da naginata %d" % i, tuple(pts[i]), tuple(pts[i + 1]), raios[i], raios[i + 1], _material("Aço da lâmina"), 4))
    novos.append(segment("Ponta da katana", tuple(pts[-2]), tuple(pts[-1]), raios[-1], .0, _material("Fio polido"), 4))

    heroi.extend(novos)
    for o in novos:
        if not o.name.startswith("Cabeça"):
            osso_de[o] = "antebraco_d"     # a arma e a mão vão no antebraço da katana (direito da tela), como antes


# ---------------------------------------------------------------- padrão do elenco (#586); ver hazaki/perfil.py e hazaki/gerar.py
CABECA = 1.42
ARMA_ESCALA = 1.5
ARMA_ESPESSURA = 1.15
ARMA_CLAREAR = 0.30
_EM_PE = (0.08, 0.34, 1.0)   # ~20 graus fora da vertical: um pouco para fora (+x) e para trás (+y), para a haste não sair do quadro de 32 px nas 8 direções
ARMA_DIRECAO = {"parado": _EM_PE, "andar": _EM_PE, "dano": _EM_PE}
ARMA_ESCALA_ANIM = {"rolamento": 0.6, "morte": 0.7, "combo": 0.85, "escudo": 0.7}
ESTILO_2D = True
RETRATO = {"pasta": "joao"}
