"""Perfil do MATHEUS para o gerar.py do Hazaki (mesmo rig, mesmas animações e mesma câmera): só muda o modelo e as cores.

Referência: ../../referencia_herois/matheus.png (colete azul de gola alta sobre camisa escura, mangas arregaçadas com braçadeiras de couro, pele
morena, cabelo curto e crespo, cinto e tira de couro cruzada no peito, calça azul-marinho, botas pretas, katana de cabo azul).
O modelo parte do mesmo estudo do Codex que o Hazaki usa (pernas, braços e katana recriados em repouso reto, presos aos mesmos ossos);
aqui trocamos o que faz o Matheus ser o Matheus: cores, colete sem lenço e com gola alta, camisa escura aparecendo, tira de couro, braçadeiras,
antebraço de pele, botas pretas e cabelo curto. A katana continua NA MÃO (as animações de golpe e escudo dependem dela); a bainha fica no quadril.
"""
import bpy

NOME = "matheus"

# Paleta escura do jogo (mesmos tons de brilho do Hazaki, cores do Matheus). Chaves = nomes dos materiais do estudo do Codex + os criados abaixo.
PALETA = {
    "Tecido vermelho queimado": "#2f56c4",   # colete azul-royal (era o casaco vermelho)
    "Vermelho iluminado": "#4470d8",         # gola alta e aba clara
    "Dobras do tecido": "#1c3382",           # aba escura e costura
    "Calça azul carvão": "#242b4c",
    "Cabelo quase preto": "#1b1d28",
    "Couro castanho": "#5c4030",
    "Pele": "#8e5a3e", "Rosto iluminado": "#a56e4d",
    "Aço azulado": "#66798d", "Fio polido": "#d6e0ea",
    "Latão antigo": "#9a7a3e", "Olho": "#0a0c14",
    "Manga escura": "#2a3050", "Camisa escura": "#1f2339", "Bota preta": "#2a2932", "Braçadeira": "#3d302d",
}
BRILHANTES = {"Reflexo frio": "#8ea9c4"}


def fonte(src, trocar):
    """Cabelo curto e crespo: mais tufos, mais baixos e mais juntos (o Hazaki tem mechas compridas)."""
    src = trocar(src, "for i in range(9):\n    a=i*2.399", "for i in range(12):\n    a=i*2.399")
    src = trocar(src, "math.cos(a)*.39,math.sin(a)*.33+.05,3.23+random.uniform(-.05,.12)", "math.cos(a)*.31,math.sin(a)*.27+.05,3.11+random.uniform(-.04,.07)")
    src = trocar(src, "P(0,.05,2.94),(.35,.29,.24),hair,2", "P(0,.05,3.0),(.34,.28,.19),hair,2")  # testa aparecendo, como na referência
    return src


def _material(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    return m


def ajustar(ns, heroi, osso_de, apagar):
    """Troca materiais por peça, tira o lenço e a gola cruzada e põe a camisa escura, a tira de couro e a fivela."""
    apagar(("Lenço ao vento", "Face escura do lenço", "Gola cruzada"))
    por_prefixo = [
        ("Braço", "Manga escura"), ("Antebraço", "Pele"), ("Proteção", "Braçadeira"),
        ("Bota ", "Bota preta"), ("Aba do casaco esquerda", "Tecido vermelho queimado"), ("Faixa da bota", "Couro castanho"), ("Fivela pequena", "Aço azulado"),
    ]
    for o in heroi:
        for pref, nome in por_prefixo:
            if o.name.startswith(pref) and o.type == "MESH":
                o.data.materials[0] = _material(nome)
    P, box, segment = ns["P"], ns["box"], ns["segment"]
    novos = [
        # camisa escura entre as duas abas do colete, do peito à gola
        box("Camisa escura", P(0.0, -0.262, 2.0), (0.24, 0.05, 0.56), _material("Camisa escura"), 0.012),
        # tira de couro cruzada do ombro (lado esquerdo da tela) ao quadril direito, com a fivela no peito
        segment("Tira do peito", P(-0.27, -0.255, 2.27), P(0.31, -0.27, 1.70), 0.055, 0.055, ns["leather"], 6),
        box("Fivela da tira", P(-0.17, -0.285, 2.13), (0.12, 0.035, 0.11), ns["steel"], 0.012),
    ]
    heroi.extend(novos)
    for o in novos:
        osso_de[o] = "torso"
