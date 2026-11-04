"""Perfil do JOHN para o gerar.py do Hazaki (mesmo rig, mesmas animações e mesma câmera): só muda o modelo e as cores.

Referência: assets/personagens/joao/rosto.png (primeiro quadro do retrato): cabelo curto e escuro com entradas, bigode e barba curta escuros,
pele morena e camisa azul. Arma: NAGINATA (lança de lâmina curva), encurtada em relação à katana do Hazaki para caber no quadro de 32x44.
O modelo parte do mesmo estudo do Codex que o Hazaki usa; trocamos o que faz o John ser o John: cores, cabelo curto, barba, camisa azul sem lenço
e a naginata NA MÃO DIREITA (a mão esquerda segue a pose de cada animação; o rig não tem IK de duas mãos para a haste).
Os nomes "Guarda da katana" e "Ponta da katana" são mantidos porque `ossos.guarda_ponta` os usa como referência da arma nas animações.
"""
import bpy
from mathutils import Vector

NOME = "joao"

# Paleta escura do jogo, tirada do retrato (camisa azul, pele morena, cabelo e barba escuros). Chaves = nomes dos materiais do estudo do Codex + os criados abaixo.
PALETA = {
    "Tecido vermelho queimado": "#1f3d8f",   # camisa azul (era o casaco vermelho)
    "Vermelho iluminado": "#2c55b5",         # gola e aba clara
    "Dobras do tecido": "#142a66",           # costura e aba escura
    "Calça azul carvão": "#242b3a",          # calça cinza-escura
    "Cabelo quase preto": "#16141a",
    "Couro castanho": "#4e3728",
    "Pele": "#9a6444", "Rosto iluminado": "#b97a55",
    "Aço azulado": "#66798d", "Fio polido": "#d6e0ea",
    "Latão antigo": "#9a7a3e", "Olho": "#0a0c14",
    "Manga escura": "#1c2f5c", "Camisa escura": "#15213f", "Bota preta": "#2a2932", "Braçadeira": "#3d302d",
    "Barba": "#3a2820",                      # barba e bigode escuros
    "Madeira da haste": "#6b4a2e",           # haste da naginata
}
BRILHANTES = {"Reflexo frio": "#8ea9c4"}


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
    """Tira o lenço, põe a camisa azul e a calça, a barba e o bigode, e troca a katana pela naginata encurtada (na mão direita da tela)."""
    apagar(("Lenço ao vento", "Face escura do lenço", "Gola cruzada",
            "Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido"))
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

    # NAGINATA na mão direita da tela: mesmo punho e mesmo eixo da katana do Hazaki, mas haste curta e lâmina curva em arco para fora (+x).
    punho = Vector(P(.70, -.24, 1.46))
    mao = punho + Vector((0.02, -0.04, -0.09))
    d = Vector((.45, -.08, -.89)).normalized()   # um pouco mais para fora que a katana (.26), para a haste aparecer ao lado do corpo
    cabo_a, cabo_b = mao - d * .20, mao + d * .17
    novos.append(segment("Cabo da naginata", tuple(cabo_a), tuple(cabo_b), .050, .050, _material("Madeira da haste"), 8))
    novos.append(segment("Guarda da katana", tuple(cabo_b - d * .03), tuple(cabo_b + d * .03), .10, .10, _material("Latão antigo"), 8))
    p = Vector((1.0, 0.0, 0.0))
    p = (p - p.dot(d) * d).normalized()           # direção do arco: perpendicular ao eixo, para fora do corpo
    base = cabo_b + d * .06
    L, curva = .40, .12                       # lâmina mais curta: a versão de .50 passava do quadro no combo
    pts = [base + d * (L * t) + p * (curva * t * t) for t in (0.0, .25, .5, .75, 1.0, 1.12)]
    raios = [.13, .11, .09, .07, .05]          # lâmina larga o bastante para ler em 44 px
    for i in range(len(pts) - 2):
        novos.append(segment("Lâmina da naginata %d" % i, tuple(pts[i]), tuple(pts[i + 1]), raios[i], raios[i + 1], _material("Aço azulado"), 4))
    novos.append(segment("Ponta da katana", tuple(pts[-2]), tuple(pts[-1]), raios[-1], .0, _material("Fio polido"), 4))

    heroi.extend(novos)
    for o in novos:
        if not o.name.startswith("Cabeça"):
            osso_de[o] = "antebraco_d"     # a arma e a mão vão no antebraço da katana (direito da tela), como antes
