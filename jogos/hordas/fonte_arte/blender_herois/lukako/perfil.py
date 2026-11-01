"""Perfil do LUKAKO para o gerar.py do Hazaki (mesmo rig, mesma câmera, mesmas animações): troca o modelo, as cores e a ARMA.

Referência: plano de personagens (notas/plano_2026-11-01.md, A12): cabelo preto curto, pele marrom, rosto largo; haori azul-petróleo e navy de
mangas largas, faixa na cintura, calça clara, botas escuras. Arma: o TESSEN (leque de ferro) na mão direita da tela.

O leque é o do jogo (`heroi.gd`/`v2_herois.json`, "tessen"): FECHADO no parado, no andar e nas outras animações (a mesma haste da katana, na mão),
e ABERTO, em meia-lua (semicírculo com o lado reto na mão), em todos os quadros do combo (os 3 cortes). O rastro de lâmina do combo some:
o golpe do leque solta vento, e o vento é efeito do jogo, não da folha.

Ganchos lidos pelo gerar.py do Hazaki (só com --perfil): fonte, ajustar, quadro (mostra/esconde peças por animação e quadro) e efeito.
"""
import math

import bpy
from mathutils import Vector

NOME = "lukako"

# Paleta escura e fechada do jogo. Chaves = nomes dos materiais do estudo do Codex + os criados aqui (todas as chaves do Matheus, para o Codex não falhar).
PALETA = {
    "Tecido vermelho queimado": "#1d5a63",   # haori azul-petróleo (era o casaco vermelho)
    "Vermelho iluminado": "#2f7f86",         # lapela e aba clara
    "Dobras do tecido": "#12303f",           # navy escuro: costura e aba escura
    "Calça azul carvão": "#7d7b70",          # calça clara, em tom fechado (bege-cinza)
    "Cabelo quase preto": "#16161d",
    "Couro castanho": "#4a2e2a",             # faixa da cintura, cinto e couro
    "Pele": "#6e4632", "Rosto iluminado": "#8a5a40",
    "Aço azulado": "#66798d", "Fio polido": "#d6e0ea",
    "Latão antigo": "#9a7a3e", "Olho": "#0a0c14",
    "Manga escura": "#17464c", "Camisa escura": "#1a2a33", "Bota preta": "#24232a", "Braçadeira": "#3d302d",
    "Leque de tecido": "#5f9e98",            # tecido do leque (verde-azulado claro, lê no quadro)
}
BRILHANTES = {"Reflexo frio": "#8ea9c4"}

LEQUE_FECHADO = "Leque fechado"
LEQUE_ABERTO = "Leque aberto"
LEQUE_ARO = "Leque — aro"
RAIO_ABERTO = 0.42   # raio da meia-lua (m; 1 m = 24,5 px). Arma que passa do quadro é encurtada, nunca o quadro aumentado (oclusao.gd:89).
ESPESSURA = 0.012    # meia espessura do tecido (m), para o contorno pegar o leque

_BASE = {}           # escala de cada peça (para esconder com escala zero e voltar sem perder o tamanho)


def fonte(src, trocar):
    """Cabelo curto e preto: mais tufos e mais baixos, sem as mechas compridas do Hazaki."""
    src = trocar(src, "for i in range(9):\n    a=i*2.399", "for i in range(12):\n    a=i*2.399")
    src = trocar(src, "math.cos(a)*.39,math.sin(a)*.33+.05,3.23+random.uniform(-.05,.12)", "math.cos(a)*.31,math.sin(a)*.27+.05,3.11+random.uniform(-.04,.07)")
    src = trocar(src, "P(0,.05,2.94),(.35,.29,.24),hair,2", "P(0,.05,3.0),(.34,.28,.19),hair,2")  # testa aparecendo
    return src


def _material(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    return m


def _meia_lua(centro, a, w, raio, n=12):
    """Leque aberto: semicírculo de raio `raio`, com o lado reto passando pelo `centro` (a mão). `a` = direção do arco, `w` = eixo do lado reto.
    Dois lados (frente e costas) para ter espessura; o plano é o da tela (normal em y), então lê de frente."""
    c = Vector(centro)
    fr, tr = Vector((0, -ESPESSURA, 0)), Vector((0, ESPESSURA, 0))
    verts = [c + fr, c + tr]                         # 0 = centro da frente, 1 = centro de trás
    arco = []
    for i in range(n + 1):
        t = -math.pi / 2 + math.pi * i / n
        arco.append(c + (a * math.cos(t) + w * math.sin(t)) * raio)
    verts += [p + fr for p in arco]                  # 2 .. 2+n  (arco da frente)
    verts += [p + tr for p in arco]                  # 2+n+1 .. 2+2n+1 (arco de trás)
    m = n + 1
    faces = []
    for i in range(n):
        f0, f1 = 2 + i, 3 + i
        b0, b1 = 2 + m + i, 3 + m + i
        faces.append((0, f0, f1))                    # leque da frente (triângulos a partir do centro)
        faces.append((1, b1, b0))                    # leque de trás (ordem invertida)
        faces.append((f0, f1, b1, b0))               # borda do arco (espessura)
    return verts, faces


def ajustar(ns, heroi, osso_de, apagar):
    """Tira o lenço, a katana e a proteção de aço; põe o haori, a calça clara e o LEQUE (fechado, na mão; aberto em meia-lua, escondido até o combo)."""
    apagar(("Lenço ao vento", "Face escura do lenço", "Gola cruzada", "Gola do lenço", "Proteção",
            "Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido", "Dorso da lâmina"))
    por_prefixo = [
        ("Braço", "Manga escura"), ("Antebraço", "Manga escura"),
        ("Bota ", "Bota preta"), ("Aba do casaco esquerda", "Tecido vermelho queimado"), ("Faixa da bota", "Couro castanho"), ("Fivela pequena", "Latão antigo"),
    ]
    for o in heroi:
        for pref, nome in por_prefixo:
            if o.name.startswith(pref) and o.type == "MESH":
                o.data.materials[0] = _material(nome)
    P, segment, ico, mesh = ns["P"], ns["segment"], ns["ico"], ns["mesh"]
    punho = Vector(P(.70, -.24, 1.46))                       # mesmo ponto da katana (mão direita da tela)
    mao = punho + Vector((0.02, -.04, -.09))
    d = Vector((.26, -.08, -.97)).normalized()               # direção do cabo: para baixo e para fora, como a katana
    fechado = [
        segment(LEQUE_FECHADO, tuple(mao - d * .05), tuple(mao + d * .30), .05, .028, _material("Leque de tecido"), 8),
        ico(LEQUE_ARO, tuple(mao), (.055, .055, .055), _material("Aço azulado"), 1),
    ]
    a = d
    w = a.cross(Vector((0, 1, 0))).normalized()              # lado reto no plano da tela (lê de frente)
    verts, faces = _meia_lua(mao + d * .02, a, w, RAIO_ABERTO)
    aberto = mesh(LEQUE_ABERTO, verts, faces, _material("Leque de tecido"))
    novos = fechado + [aberto]
    heroi.extend(novos)
    for o in novos:
        osso_de[o] = "antebraco_d"                           # o leque vai preso à mão, como a katana


def _mostrar(nome, visivel):
    """Esconde com escala zero (a casca de contorno também: o gerar.py só mexe nela por cor/normal). Volta com a escala original."""
    for nome_obj in (nome, "Contorno — " + nome):
        o = bpy.data.objects.get(nome_obj)
        if o is None:
            continue
        base = _BASE.setdefault(nome_obj, tuple(o.scale))
        o.scale = base if visivel else (0.0, 0.0, 0.0)


def quadro(nome, q, n):
    """Chamado antes de cada quadro (depois do posar): o leque ABERTO só no combo; o fechado nas outras animações."""
    golpe = nome == "combo"
    _mostrar(LEQUE_ABERTO, golpe)
    _mostrar(LEQUE_FECHADO, not golpe)


def efeito(nome, do_modulo):
    """Sem rastro de lâmina no combo: o leque não corta, o golpe solta vento (efeito do jogo)."""
    return None
