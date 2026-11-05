"""Perfil da LUKAKO para o gerar.py do Hazaki (mesmo rig, mesma câmera, mesmas animações): troca o modelo, as cores e a ARMA.

Lukako é MULHER (decisão do Isac, #586) e a leitura tem de aparecer a 1x, em 32x44: coque alto com kanzashi (alfinete dourado com conta vermelha que
sobe 2-3 px acima da cabeça: nenhum homem do elenco tem), mechas finas emoldurando o rosto, cílios e batom (o rosto dos homens é um ponto só),
cintura de obi vermelho bem mais estreita que os ombros e saia do haori em trapézio aberto, marfim, que destaca do amarelo do haori e da calça escura.
Arma: o TESSEN (leque de ferro), agora ABERTO em meia-lua o tempo todo (vermelho vivo, varetas e aro dourados), 1,5x, erguido ao lado do corpo no
parado/andar/dano/etc. e, no combo (3 cortes), a meia-lua grande que corta junto com o braço. O rastro de lâmina do combo some: o golpe do leque
solta vento, e o vento é efeito do jogo, não da folha.

Ganchos lidos pelo gerar.py do Hazaki (só com --perfil): fonte, ajustar, quadro (mostra/esconde peças por animação e quadro) e efeito.
"""
import math

import bpy
from mathutils import Vector

NOME = "lukako"

# Chaves = nomes dos materiais do estudo do Codex + os criados aqui (todas as chaves do Matheus, para o Codex não falhar).
PALETA = {
    "Tecido vermelho queimado": "#e0b020",   # haori amarelo-dourado (cor-assinatura, padrão #586)
    "Vermelho iluminado": "#f4cc40",         # lapela e aba clara
    "Dobras do tecido": "#b8860e",           # dourado fundo: costura e aba escura
    "Calça azul carvão": "#3c2c44",          # calça ameixa escura: o dourado do haori fica sozinho e lê a 1x
    "Cabelo quase preto": "#3a2a3e",         # preto-ameixa (preto puro some no contorno escuro)
    "Couro castanho": "#8a2a24",             # faixa da bota
    "Pele": "#94624a", "Rosto iluminado": "#bc8460",   # pele marrom, mais clara que a antiga (o rosto lê a 1x)
    "Aço azulado": "#66798d", "Fio polido": "#d6e0ea",
    "Latão antigo": "#e0b030", "Olho": "#0a0c14",
    "Manga escura": "#c89a18", "Camisa escura": "#8a6410", "Bota preta": "#24232a", "Braçadeira": "#3d302d",
    "Leque de tecido": "#e61616",            # tecido do leque: vermelho vivo, contra o dourado do haori
    "Vareta dourada": "#f8d048",             # varetas e aro do leque
    "Saia marfim": "#ecd9b0",                # saia do haori: o contraste com o amarelo e com a calça escura
    "Obi rubi": "#d02440",                   # faixa da cintura (e o laço atrás)
    "Batom": "#e0405a",
    "Conta vermelha": "#f03a30",             # conta do kanzashi
}
BRILHANTES = {"Reflexo frio": "#8ea9c4"}

LEQUE_ARO = "Leque — aro"                    # rebite dourado na mão, sempre visível
LEQUE_COMBO = "Leque aberto"                 # meia-lua grande do combo (o arco vai para onde o braço corta)
RAIO_COMBO = 0.34    # raio da meia-lua do combo (m; 1 m = 24,5 px). Arma que passa do quadro é encurtada, nunca o quadro aumentado (oclusao.gd:89).
RAIO_LIVRE = 0.26    # raio do leque aberto de pé (x ARMA_ESCALA 1,5 = ~5 px de raio, ~8 px de largura na tela)
ESP_LIVRE = 0.045    # o leque de pé é uma placa de ~1 px de espessura: plano fino demais vira ruído de pixel (e some de lado)
ESPESSURA = 0.012    # meia espessura do tecido (m), para o contorno pegar o leque
CABO_LIVRE = 0.30    # o leque de pé fica nesta altura acima da mão (num cabo dourado): sobe até o ombro e deixa de se perder contra a saia
GUIA_LIVRE = 25.0    # graus: o plano do leque de pé fica entre a frente e o lado, para ler de frente, de lado e na diagonal

_BASE = {}           # escala de cada peça (para esconder com escala zero e voltar sem perder o tamanho)
_GRUPO = {"combo": [], "livre": []}   # nomes das peças de cada leque; o quadro() liga um grupo e desliga o outro


def fonte(src, trocar):
    """Cabelo baixo e chato no alto (o coque é a peça alta): mais tufos e mais baixos, sem as mechas compridas do Hazaki."""
    src = trocar(src, "for i in range(9):\n    a=i*2.399", "for i in range(12):\n    a=i*2.399")
    src = trocar(src, "math.cos(a)*.39,math.sin(a)*.33+.05,3.23+random.uniform(-.05,.12)", "math.cos(a)*.31,math.sin(a)*.27+.05,3.04+random.uniform(-.03,.05)")
    src = trocar(src, "P(0,.05,2.94),(.35,.29,.24),hair,2", "P(0,.05,2.97),(.34,.28,.18),hair,2")  # testa aparecendo
    return src


def _material(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    return m


def _meia_lua(centro, a, w, raio, n=14, esp=ESPESSURA):
    """Leque aberto: semicírculo de raio `raio`, com o lado reto passando pelo `centro` (a mão). `a` = direção do arco, `w` = eixo do lado reto.
    Dois lados (frente e costas) para ter espessura. Devolve (verts, faces, pontos do arco)."""
    c = Vector(centro)
    n_ = a.cross(w).normalized()                      # normal do plano do leque
    fr, tr = n_ * esp, n_ * -esp          # a frente é o lado para onde a normal (a x w) aponta: as faces grandes olham para fora
    verts = [c + fr, c + tr]                          # 0 = centro da frente, 1 = centro de trás
    arco = []
    for i in range(n + 1):
        t = -math.pi / 2 + math.pi * i / n
        arco.append(c + (a * math.cos(t) + w * math.sin(t)) * raio)
    verts += [p + fr for p in arco]                   # 2 .. 2+n  (arco da frente)
    verts += [p + tr for p in arco]                   # 2+n+1 .. 2+2n+1 (arco de trás)
    m = n + 1
    faces = []
    for i in range(n):
        f0, f1 = 2 + i, 3 + i
        b0, b1 = 2 + m + i, 3 + m + i
        faces.append((0, f0, f1))                     # leque da frente (triângulos a partir do centro)
        faces.append((1, b1, b0))                     # leque de trás (ordem invertida)
        faces.append((f0, f1, b1, b0))                # borda do arco (espessura)
    return [tuple(v) for v in verts], faces, arco


def _leque(ns, nome, centro, a, w, raio, hastes, grupo, osso_de, heroi, espessura_vareta, esp=ESPESSURA):
    """Monta um leque aberto (tecido + varetas + aro dourado), todas as peças presas ao antebraço da arma; registra os nomes no grupo."""
    mesh, segment, line = ns["mesh"], ns["segment"], ns["line"]
    verts, faces, arco = _meia_lua(centro, a, w, raio, esp=esp)
    c = Vector(centro)
    pecas = [mesh(nome, verts, faces, _material("Leque de tecido"))]
    n_ = a.cross(w).normalized()
    sai = n_ * (esp + 0.006)                   # varetas um fio à frente do tecido: aparecem sobre o vermelho
    for i in range(hastes):
        p = arco[round(i * (len(arco) - 1) / max(1, hastes - 1))]
        pecas.append(segment("%s vareta %d" % (nome, i), tuple(c + sai), tuple(p + sai), espessura_vareta, espessura_vareta * 0.75, _material("Vareta dourada"), 6))
    pecas.append(line(nome + " aro", [tuple(p + sai) for p in arco], espessura_vareta * 0.8, _material("Vareta dourada")))
    for o in pecas:
        osso_de[o] = "antebraco_d"
        _GRUPO[grupo].append(o.name)
    heroi.extend(pecas)


def _feminino(ns, heroi, osso_de, apagar):
    """Silhueta feminina legível a 1x: cintura de obi (bem mais estreita que os ombros), saia do haori em trapézio aberto e marfim, coque alto com
    kanzashi, mechas finas emoldurando o rosto e cabelo comprido caindo atrás, cílios e batom. Mesma cabeça (CABECA) e mesmo leque."""
    P, segment, box, ico, mesh, line = ns["P"], ns["segment"], ns["box"], ns["ico"], ns["mesh"], ns["line"]
    for o in heroi:
        if o.name == "Casaco vermelho" and o.type == "MESH":
            for v in o.data.vertices:
                f = max(0.0, min(1.0, (v.co.z - 1.48) / (2.30 - 1.48)))   # 0 na cintura, 1 nos ombros
                v.co.x *= 0.60 + 0.24 * f                                  # cintura de ~.37 de largura, ombros de ~.72
                v.co.y *= 0.88
            o.data.update()
    apagar(("Cinto",))                                                      # o obi substitui o cinto largo do Hazaki
    cabelo, eye = ns["hair"], ns["eye"]
    obi, marfim = _material("Obi rubi"), _material("Saia marfim")
    # saia: trapézio da cintura ao joelho (hem de ~1,0 de largura contra ~.45 na cintura): ampulheta, e a cor marfim separa o amarelo da calça
    cx0, cy0, zc = 0.23, 0.17, 1.76
    cx1, cy1, zh = 0.48, 0.38, 1.14
    base = [P(-cx1, -cy1, zh), P(cx1, -cy1, zh), P(cx1, cy1, zh), P(-cx1, cy1, zh)]
    topo = [P(-cx0, -cy0, zc), P(cx0, -cy0, zc), P(cx0, cy0, zc), P(-cx0, cy0, zc)]
    saia = mesh("Saia do haori", base + topo, [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7), (0, 3, 2, 1)], marfim)
    novos = [
        saia,
        box("Obi", P(0, -0.02, 1.70), (0.46, 0.38, 0.20), obi, 0.03),                    # faixa vermelha na cintura
        box("Laço do obi", P(0.0, 0.25, 1.70), (0.30, 0.10, 0.28), obi, 0.02),          # laço atrás
    ]
    for o in novos:
        osso_de[o] = "quadril" if o is saia else "torso"
    # cabelo: coque alto + kanzashi (cabelo e kanzashi herdam a CABECA, o prefixo "Cabelo" entra na lista da cabeça do gerar.py)
    # (prefixo "Mecha": entra na lista da cabeça do gerar.py e fica fora da MEDIDA de massa, como as pontas do cabelo)
    coque = ico("Mecha coque", P(0.0, 0.08, 3.21), (0.14, 0.14, 0.12), cabelo, 2)
    pino = segment("Mecha kanzashi", P(0.03, 0.05, 3.23), P(0.16, 0.03, 3.38), 0.030, 0.020, _material("Vareta dourada"), 6)
    conta = ico("Mecha kanzashi conta", P(0.165, 0.025, 3.39), (0.048, 0.048, 0.048), _material("Conta vermelha"), 1)
    longos = [
        segment("Cabelo longo costas", P(0, 0.14, 2.85), P(0, 0.22, 2.20), 0.21, 0.15, cabelo, 8),
        segment("Cabelo mecha esq", P(-0.32, -0.08, 2.80), P(-0.35, -0.10, 2.42), 0.040, 0.026, cabelo, 6),   # fios na frente das orelhas
        segment("Cabelo mecha dir", P(0.32, -0.08, 2.80), P(0.35, -0.10, 2.42), 0.040, 0.026, cabelo, 6),
    ]
    # cílios: um traço de 2 px subindo e abrindo para fora de cada olho (o olho do homem é um ponto)
    cilios = [
        line("Cabelo cílio esq", [P(-0.155, -0.273, 2.775), P(-0.195, -0.268, 2.835)], 0.017, eye),
        line("Cabelo cílio dir", [P(0.155, -0.271, 2.775), P(0.195, -0.266, 2.835)], 0.017, eye),
        line("Cabelo pálpebra esq", [P(-0.17, -0.276, 2.785), P(-0.055, -0.278, 2.795)], 0.013, eye),
        line("Cabelo pálpebra dir", [P(0.055, -0.276, 2.795), P(0.17, -0.274, 2.785)], 0.013, eye),
    ]
    boca = ico("Nariz boca", P(0.0, -0.255, 2.585), (0.068, 0.034, 0.030), _material("Batom"), 1)
    for o in [coque, pino, conta] + longos + cilios + [boca]:
        osso_de[o] = "cabeca"
    heroi.extend(novos + [coque, pino, conta] + longos + cilios + [boca])


def ajustar(ns, heroi, osso_de, apagar):
    """Tira o lenço, a katana, a bainha e a proteção de aço; põe o haori, a saia, a calça escura, o penteado e os DOIS leques abertos (o de pé e o do combo)."""
    apagar(("Lenço ao vento", "Face escura do lenço", "Gola cruzada", "Gola do lenço", "Proteção",
            "Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido", "Dorso da lâmina",
            "Bainha", "Terminal da bainha"))
    por_prefixo = [
        ("Braço", "Manga escura"), ("Antebraço", "Manga escura"),
        ("Bota ", "Bota preta"), ("Aba do casaco esquerda", "Tecido vermelho queimado"), ("Faixa da bota", "Couro castanho"), ("Fivela pequena", "Latão antigo"),
    ]
    for o in heroi:
        for pref, nome in por_prefixo:
            if o.name.startswith(pref) and o.type == "MESH":
                o.data.materials[0] = _material(nome)
    P, ico = ns["P"], ns["ico"]
    _feminino(ns, heroi, osso_de, apagar)
    punho = Vector(P(.70, -.24, 1.46))                       # mesmo ponto da katana (mão direita da tela)
    mao = punho + Vector((0.02, -.04, -.09))
    # leque de pé: UM plano vertical (meia-lua, lado reto embaixo, arco para cima) girado GUIA_LIVRE graus para a frente: de frente e nas diagonais lê cheio; de lado vira placa fina
    g = math.radians(GUIA_LIVRE)
    cima = Vector((0.0, 0.0, 1.0))
    base = mao + Vector((-0.05, -0.04, CABO_LIVRE))           # o leque fica um pouco para fora e para a frente da mão, num cabo dourado
    lado = Vector((math.cos(g), -math.sin(g), 0.0))
    _leque(ns, LEQUE_COMBO + " (livre)", tuple(base), cima, lado, RAIO_LIVRE, 0, "livre", osso_de, heroi, 0.034, ESP_LIVRE)
    cabo = ns["segment"]("Leque cabo", tuple(mao + Vector((0, 0, -0.03))), tuple(base - Vector((0, 0, 0.02))), 0.040, 0.032, _material("Vareta dourada"), 6)
    osso_de[cabo] = "antebraco_d"
    _GRUPO["livre"].append(cabo.name)
    heroi.append(cabo)
    # leque do combo: meia-lua grande com o arco na direção do cabo da katana (as poses do combo foram calculadas para essa arma)
    d = Vector((.26, -.08, -.97)).normalized()
    w = d.cross(Vector((0, 1, 0))).normalized()              # lado reto no plano da tela (lê de frente)
    _leque(ns, LEQUE_COMBO, tuple(mao + d * .02), d, w, RAIO_COMBO, 3, "combo", osso_de, heroi, 0.044)
    aro = ico(LEQUE_ARO, tuple(mao), (.06, .06, .06), _material("Vareta dourada"), 1)   # rebite na mão
    osso_de[aro] = "antebraco_d"
    heroi.append(aro)


def _mostrar(nome, visivel):
    """Esconde com escala zero (a casca de contorno também: o gerar.py só mexe nela por cor/normal). Volta com a escala original."""
    for nome_obj in (nome, "Contorno — " + nome):
        o = bpy.data.objects.get(nome_obj)
        if o is None:
            continue
        base = _BASE.setdefault(nome_obj, tuple(o.scale))
        o.scale = base if visivel else (0.0, 0.0, 0.0)


def quadro(nome, q, n):
    """Chamado antes de cada quadro (depois do posar): o leque grande só no combo; o leque de pé em todas as outras animações (e no retrato)."""
    golpe = nome == "combo"
    for peca in _GRUPO["combo"]:
        _mostrar(peca, golpe)
    for peca in _GRUPO["livre"]:
        _mostrar(peca, not golpe)


def efeito(nome, do_modulo):
    """Sem rastro de lâmina no combo: o leque não corta, o golpe solta vento (efeito do jogo)."""
    return None


# ---------------------------------------------------------------- padrão do elenco (#586)
CABECA = 1.34
ARMA_ESCALA = 1.5
ARMA_ESPESSURA = 1.5          # uniforme: o leque é plano e o tecido precisa crescer nos dois eixos (sem ARMA_DIRECAO: o leque já nasce na posição certa)
ARMA_CLAREAR = 0.12          # menos que os 0,30 do padrão: o vermelho do leque virava salmão
ESTILO_2D = True
# retrato: anim_retrato.py (desta pasta) = parado com o braço do leque erguido junto ao rosto; "arma": True deixa o leque na mão
RETRATO = {"pasta": "lukako", "anim": "retrato", "arma": True}

LARGURA = 0.91                # um fio mais estreita que os 0,95 do padrão: o leque ao lado do corpo não encosta na borda do quadro de 32 px
