"""Perfil do MATHEUS para o gerar.py do Hazaki (mesmo rig, mesmas animações e mesma câmera): só muda o modelo e as cores.

Referência: ../../referencia_herois/matheus.png (colete azul de gola alta sobre camisa escura, mangas arregaçadas com braçadeiras de couro, pele
morena, cabelo curto e crespo, cinto e tira de couro cruzada no peito, calça azul-marinho, botas pretas, katana de cabo azul).
O modelo parte do mesmo estudo do Codex que o Hazaki usa (pernas, braços e katana recriados em repouso reto, presos aos mesmos ossos);
aqui trocamos o que faz o Matheus ser o Matheus: cores, colete sem lenço e com gola alta, camisa escura aparecendo, tira de couro, braçadeiras,
antebraço de pele, botas pretas e cabelo curto. A katana e a bainha saem (ele luta com shuriken; ver ajustar()).
"""
import math

import bpy
from mathutils import Matrix

NOME = "matheus"

# Paleta escura do jogo (mesmos tons de brilho do Hazaki, cores do Matheus). Chaves = nomes dos materiais do estudo do Codex + os criados abaixo.
PALETA = {
    "Tecido vermelho queimado": "#2450d8",   # colete azul-royal saturado (cor-assinatura, padrão #586)
    "Vermelho iluminado": "#3a6cf0",         # gola alta e aba clara
    "Dobras do tecido": "#1a38a8",           # aba escura e costura: azul mais fundo (o branco fica só na faixa)
    "Calça azul carvão": "#242b4c",
    "Cabelo quase preto": "#1b1d28",
    "Couro castanho": "#5c4030",
    "Pele": "#8e5a3e", "Rosto iluminado": "#a56e4d",
    "Aço azulado": "#66798d", "Fio polido": "#d6e0ea",
    "Latão antigo": "#9a7a3e", "Olho": "#0a0c14",
    "Manga escura": "#1c3aa0", "Camisa escura": "#1b2c78", "Bota preta": "#2a2932", "Braçadeira": "#e8eef6", "Faixa branca": "#e8eef6",
    "Shuriken aço": "#e8eef6", "Shuriken miolo": "#e0b020",
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
        segment("Tira do peito", P(-0.27, -0.255, 2.27), P(0.31, -0.27, 1.70), 0.095, 0.095, _material("Faixa branca"), 6),  # FAIXA BRANCA em diagonal: quebra o azul e separa do John
    ]
    heroi.extend(novos)
    for o in novos:
        osso_de[o] = "torso"
    # KATANA FORA (revisão de arte, PER-4): o Matthew joga com shuriken; a katana branca na mão o deixava igual ao Brendan. Some em todas as animações
    # A bainha do quadril sai também (2ª revisão de arte: de perfil ela lia como a do Hazaki).
    for o in [o for o in heroi if o.name.startswith(("Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido"))]:
        osso_de.pop(o, None)
    apagar(("Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido",
            "Bainha", "Terminal da bainha"))
    # SHURIKEN GRANDE (~8 px) em aço claro com miolo dourado: uma na mão esquerda (presa ao antebraço; o quadro() abaixo ergue o braço à frente do peito)
    # e uma segunda na bandoleira branca do peito (presa ao torso).
    def estrela(sufixo, c, comp, larg, material_aco, osso, tilt_graus):
        tilt = Matrix.Rotation(math.radians(tilt_graus), 3, "X")
        def rot(a):
            return (tilt @ Matrix.Rotation(math.radians(a), 3, "Y")).to_euler("XYZ")
        pecas = [
            box("Shuriken braço A" + sufixo, P(*c), (comp, 0.07, larg), material_aco, 0.012, rot(45)),
            box("Shuriken braço B" + sufixo, P(*c), (comp, 0.07, larg), material_aco, 0.012, rot(-45)),
            box("Shuriken miolo" + sufixo, P(c[0], c[1] - 0.02, c[2]), (comp * 0.36, 0.09, comp * 0.36), _material("Shuriken miolo"), 0.012, rot(45)),
        ]
        heroi.extend(pecas)
        for o in pecas:
            osso_de[o] = osso
    estrela("", (-0.86, -0.42, 1.60), 0.82, 0.18, _material("Shuriken aço"), "antebraco_e", 15)
    estrela(" da bandoleira", (-0.12, -0.30, 2.14), 0.62, 0.15, _material("Shuriken aço"), "torso", -45)
    # COMBO de arremesso (no lugar do combo de katana, só neste perfil): o gerar.py importa "anim_combo" pelo nome, então
    # registramos o módulo desta pasta antes de renderizar. O anim_combo.py do Hazaki não muda.
    import importlib.util
    import sys
    from pathlib import Path
    _spec = importlib.util.spec_from_file_location("anim_combo", Path(__file__).resolve().parent / "anim_combo_arremesso.py")
    _mod = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_mod)
    sys.modules["anim_combo"] = _mod


_CONTA = {"parado": 0}


def quadro(nome, q, n):
    """Chamado depois do posar de cada quadro: no parado e no andar a mão esquerda segura a shuriken erguida à frente do peito (guarda de arremesso)."""
    import sys
    import ossos
    # o gerar.py chama quadro("parado") 4 quadros x 8 direções = 32 vezes e, por último, uma vez para o retrato (33ª; ou a única com --retrato)
    if nome == "parado":
        _CONTA["parado"] += 1
    retrato = nome == "parado" and ("--retrato" in sys.argv or _CONTA["parado"] == 33)
    if retrato:
        # retrato (64x64): a shuriken sobe à altura do ombro, ao lado do rosto, para caber no recorte de busto
        ossos.girar(arm_(), "braco_e", x=-1.15, y=-0.25, z=0.0)
        ossos.girar(arm_(), "antebraco_e", x=-1.05, y=0.0, z=0.0)
    elif nome == "parado":
        ossos.girar(arm_(), "braco_e", x=-0.75 - 0.02 * math.sin(q), y=-0.10, z=0.0)
        ossos.girar(arm_(), "antebraco_e", x=-0.95, y=0.0, z=0.0)
    elif nome == "andar":
        ossos.girar(arm_(), "braco_e", x=-0.75 + 0.06 * math.sin(2 * math.pi * q / n), y=-0.10, z=0.0)
        ossos.girar(arm_(), "antebraco_e", x=-0.95, y=0.0, z=0.0)


def arm_():
    import bpy
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


# ---------------------------------------------------------------- padrão do elenco (#586)
CABECA = 1.30
ARMA_PECAS = ("Shuriken",)      # a arma do Matthew é só a shuriken (a katana foi tirada); o tamanho 1,5x já está na geometria (estrela ~8 px)
ARMA_ESCALA = 1.0
ARMA_CLAREAR = 0.0              # o aço já é #e8eef6 (claro)
ESTILO_2D = True
RETRATO = {"pasta": "matheus", "arma": True}
