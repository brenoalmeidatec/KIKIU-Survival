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
    "Tecido vermelho queimado": "#3f72ee",   # colete azul-royal VIVO (era o casaco vermelho): a identidade dele e o que o separa do piso escuro
    "Vermelho iluminado": "#6a97ff",         # gola alta e aba clara
    "Dobras do tecido": "#2a4cb4",           # aba escura e costura
    "Calça azul carvão": "#2e3a6c",
    "Cabelo quase preto": "#262a3c",
    "Couro castanho": "#80593d",
    "Pele": "#a4683f", "Rosto iluminado": "#c58157",
    "Aço azulado": "#8196ad", "Fio polido": "#e6eef6",
    "Latão antigo": "#c29a48", "Olho": "#07080f",
    "Manga escura": "#2c3562", "Camisa escura": "#232846", "Bota preta": "#3c3b4a", "Braçadeira": "#5a453d",
    "Bainha laca": "#1e2448", "Cabelo frente": "#4a5070",
}
LAMINA = 1.10    # comprimento do fio (unidades do modelo): o do Hazaki é 0,80. A ponta passa 1 ou 2 px da linha do pé (cabe na célula de 44) e o gerar.py ignora a lâmina na calibragem
BRILHANTES = {"Reflexo frio": "#8ea9c4"}


def fonte(src, trocar):
    """Cabelo curto e crespo: mais tufos, mais baixos e mais juntos (o Hazaki tem mechas compridas)."""
    src = trocar(src, "for i in range(9):\n    a=i*2.399", "for i in range(12):\n    a=i*2.399")
    src = trocar(src, "math.cos(a)*.39,math.sin(a)*.33+.05,3.23+random.uniform(-.05,.12)", "math.cos(a)*.31,math.sin(a)*.27+.05,3.11+random.uniform(-.04,.07)")
    src = trocar(src, "P(0,.05,2.94),(.35,.29,.24),hair,2", "P(0,.05,3.0),(.34,.28,.19),hair,2")  # testa aparecendo, como na referência
    return src


def contorno(nome, base, escuro, mais, clampc):
    """Rim claro: peças escuras (calça, mangas, botas, cabelo, bainha) ganham contorno azul-acinzentado em vez de quase preto, e a silhueta
    se separa do piso escuro. Colete, pele, couro e metal mantêm o contorno escuro da própria cor (o desenho interno não perde definição)."""
    if sum(base) / 3.0 < 0.34:
        return clampc(mais(base, (0.14, 0.20, 0.36), 1.0))
    return escuro


def _material(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    return m


def ajustar(ns, heroi, osso_de, apagar):
    """Troca materiais por peça, tira o lenço e a gola cruzada e põe a camisa escura, a tira de couro e a fivela."""
    apagar(("Lenço ao vento", "Face escura do lenço", "Gola cruzada", "Bainha", "Terminal da bainha"))
    por_prefixo = [
        ("Braço", "Manga escura"), ("Antebraço", "Pele"), ("Proteção", "Braçadeira"),
        ("Bota ", "Bota preta"), ("Aba do casaco esquerda", "Tecido vermelho queimado"), ("Faixa da bota", "Couro castanho"), ("Fivela pequena", "Aço azulado"),
    ]
    for o in heroi:
        for pref, nome in por_prefixo:
            if o.name.startswith(pref) and o.type == "MESH":
                o.data.materials[0] = _material(nome)
    P, box, segment, ico = ns["P"], ns["box"], ns["segment"], ns["ico"]
    novos = [
        # camisa escura entre as duas abas do colete, do peito à gola
        box("Camisa escura", P(0.0, -0.262, 2.0), (0.24, 0.05, 0.56), _material("Camisa escura"), 0.012),
        # tira de couro cruzada do ombro (lado esquerdo da tela) ao quadril direito, com a fivela no peito
        segment("Tira do peito", P(-0.27, -0.255, 2.27), P(0.31, -0.27, 1.70), 0.055, 0.055, ns["leather"], 6),
        box("Fivela da tira", P(-0.17, -0.285, 2.13), (0.12, 0.035, 0.11), ns["steel"], 0.012),
    ]
    # gola alta do colete nas COSTAS (a referência de costas mostra a gola subindo atrás do pescoço) e a tira de couro de trás
    colete, colete_claro = ns["red"], ns["red_light"]
    novos += [
        box("Gola traseira", P(0.0, 0.17, 2.50), (0.50, 0.12, 0.38), colete_claro, 0.03),
        box("Gola lateral esquerda", P(-0.22, 0.05, 2.49), (0.10, 0.34, 0.32), colete, 0.03),
        box("Gola lateral direita", P(0.22, 0.05, 2.49), (0.10, 0.34, 0.32), colete, 0.03),
        segment("Tira das costas", P(0.30, 0.27, 2.28), P(-0.30, 0.285, 1.70), 0.055, 0.055, ns["leather"], 6),
        box("Fivela das costas", P(0.20, 0.30, 2.12), (0.11, 0.03, 0.10), ns["steel"], 0.012),
    ]
    # BAINHA da katana na cintura, na diagonal (como na referência), longa e com ferragens claras; a lâmina fica na mão
    laca = _material("Bainha laca")
    saya = [
        segment("Bainha laca", P(-0.28, -0.10, 1.74), P(-0.80, 0.26, 0.50), 0.088, 0.070, laca, 6),
        segment("Boca da bainha", P(-0.27, -0.10, 1.75), P(-0.33, -0.06, 1.62), 0.105, 0.098, ns["gold"], 6),
        segment("Anel da bainha", P(-0.52, 0.07, 1.20), P(-0.56, 0.10, 1.12), 0.095, 0.095, ns["steel"], 6),
        segment("Terminal da bainha", P(-0.77, 0.24, 0.58), P(-0.82, 0.28, 0.46), 0.082, 0.082, ns["gold"], 6),
    ]
    novos += saya
    heroi.extend(novos)
    for o in novos:
        osso_de[o] = "torso"
    for o in saya:
        osso_de[o] = "quadril"
    # cabeça (o gerar.py amplia tudo com estes prefixos): queixo e maçãs dão volume ao rosto; a frente do cabelo é mais clara
    cabelo_claro = _material("Cabelo frente")
    cabeca = [
        ico("Cabeça — queixo", P(0.0, -0.11, 2.52), (0.25, 0.20, 0.15), ns["skin"], 2),
        ico("Cabeça — maçã esquerda", P(-0.15, -0.20, 2.66), (0.09, 0.07, 0.07), ns["skin_lit"], 1),
        ico("Cabeça — maçã direita", P(0.15, -0.20, 2.66), (0.09, 0.07, 0.07), ns["skin_lit"], 1),
    ]
    heroi.extend(cabeca)
    for o in cabeca:
        osso_de[o] = "cabeca"
    bpy.context.view_layer.update()      # matrix_world do último objeto criado ainda está desatualizada (o gerar.py amplia a cabeça por ela)
    for o in heroi:
        if o.name.startswith("Mecha de cabelo") and o.type == "MESH" and (o.matrix_world @ o.data.vertices[0].co).y < 0.0:
            o.data.materials[0] = cabelo_claro
