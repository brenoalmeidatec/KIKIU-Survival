"""Vila Amaldiçoada da v2 (id interno "cidade"): as MEDIDAS dos objetos e as LUZES deles, em Python puro (sem Blender), numa fonte só para os dois passos.

Quem lê:
  modelos3d/mapa_cidade.py   (Blender)  o tamanho da tela de cada objeto e o ponto da luz;
  mapas_v2/def_cidade.py     (Pillow)   a pegada de colisão (w x d) de cada objeto e as luzes (luz_objetos do JSON do mapa).

Escala: 1 m = 32 px na horizontal e 22,63 px na vertical (câmera ortográfica a 45 graus). A ORIGEM de cada objeto é o centro da pegada, no
chão; a frente (o que a câmera vê) é o lado -Y. No jogo o "pé" do sprite é a FRENTE da pegada: pé = origem + d * 11,315 px para baixo
(é o que gerar_v2_mapas.py faz com {"col": "caixa", "w": w, "d": d}). As luzes dos objetos (luz_objetos) são relativas ao pé.

Cada medida: w, d, h = pegada e altura do corpo (metros); lx = meia largura que o desenho ocupa (padrão w/2); zmax = altura do ponto mais alto
(padrão h); yb e yf = quanto o desenho avança para trás (+Y) e para a frente (-Y) da origem (padrão d/2); col = pegada de colisão quando
não é w x d (None = o objeto é só enfeite, o herói passa por cima).
"""
import math

PX = 32.0
PY = PX * math.sin(math.radians(45.0))   # 22,63 px por metro de altura (ou de profundidade)


def _m(w, d, h, lx=None, zmax=None, yb=None, yf=None, col="caixa"):
    return {"w": w, "d": d, "h": h, "lx": w / 2.0 if lx is None else lx, "zmax": h if zmax is None else zmax,
            "yb": d / 2.0 if yb is None else yb, "yf": d / 2.0 if yf is None else yf, "col": col}


# nome -> medidas. Carros "_v" são o mesmo carro virado de frente ou de costas (comprimento ao longo de Y).
MEDIDAS = {
    # prédios: a fachada (lado -Y) fica no plano da frente da pegada; toldos, escadas de incêndio e entulho avançam para a frente (yf)
    "predio_loja": _m(6.2, 2.6, 4.0, lx=3.4, zmax=6.1, yb=1.45, yf=2.4),
    "predio_bar": _m(5.6, 2.6, 4.2, lx=3.1, zmax=6.1, yb=1.45, yf=2.0),
    "predio_apto_a": _m(5.4, 2.1, 5.8, lx=3.1, zmax=6.7, yb=1.15, yf=2.1),
    "predio_apto_b": _m(5.4, 2.1, 5.8, lx=3.1, zmax=6.7, yb=1.15, yf=2.1),
    "predio_torre": _m(5.6, 2.0, 6.0, lx=3.4, zmax=7.7, yb=1.1, yf=1.4),
    "predio_ruina": _m(5.8, 2.2, 5.2, lx=3.3, zmax=3.8, yb=1.2, yf=2.6),
    # ruas
    "poste_rua": _m(0.4, 0.4, 5.4, lx=1.95, zmax=5.5),
    "poste_rua_e": _m(0.4, 0.4, 5.4, lx=1.95, zmax=5.5),
    "poste_quebrado": _m(0.5, 0.5, 3.0, lx=2.0, zmax=3.1, yb=0.3, yf=2.2),
    "semaforo": _m(0.35, 0.35, 3.5, lx=0.85, zmax=3.65),
    "semaforo_torto": _m(0.35, 0.35, 3.4, lx=0.85, zmax=3.65),
    "placa_pare": _m(0.2, 0.2, 2.4, lx=0.45),
    "placa_rua": _m(0.2, 0.2, 2.7, lx=0.9),
    "placa_neon": _m(0.4, 0.4, 3.4, lx=0.75),
    "hidrante": _m(0.4, 0.4, 0.7, lx=0.3),
    "cone": _m(0.42, 0.42, 0.7, lx=0.3),
    "cone_tombado": _m(0.7, 0.6, 0.35, lx=0.8, yb=0.45, yf=0.5, col=None),
    "barril_fogo": _m(0.65, 0.65, 0.95, lx=0.36),
    "lixeira_metal": _m(0.62, 0.62, 0.95, lx=0.36),
    "lixeira_rodas": _m(0.68, 0.8, 1.1, lx=0.4, yb=0.9),
    "lixeira_azul": _m(0.68, 0.8, 1.1, lx=0.4, zmax=1.6),
    "banco": _m(1.8, 0.6, 0.95, lx=0.95),
    # cemitério (#429): lápide de pedra e cruz de madeira sobre o túmulo
    "lapide": _m(0.5, 0.3, 0.95, lx=0.4),
    "cruz_tumulo": _m(0.6, 0.8, 1.45, lx=0.55, yb=0.5, yf=0.5),
    # adereços de rua
    "sacos_areia": _m(2.6, 0.8, 0.8, lx=1.4, yf=0.7),
    "barricada_concreto": _m(4.4, 1.0, 0.9, lx=2.4, zmax=0.95, yf=0.8),
    "barricada_madeira": _m(3.2, 0.9, 1.55, lx=1.7, zmax=1.9, yf=0.6),
    "pneus": _m(1.3, 1.1, 1.0, lx=1.05, yb=0.8, yf=0.8),
    "cacamba": _m(2.5, 1.3, 1.2, lx=1.7, zmax=1.7, yf=0.8),
    "container_a": _m(6.0, 2.4, 2.6, lx=3.3, zmax=3.4, yb=1.8, yf=1.8),
    "container_b": _m(6.0, 2.4, 2.6, lx=3.3, zmax=3.4, yb=1.8, yf=1.8),
    "entulho_a": _m(1.0, 0.7, 0.5, lx=0.9, yb=0.7, yf=0.7, col=None),
    "entulho_b": _m(2.0, 1.2, 1.0, lx=1.7, zmax=1.5, yb=1.0, yf=1.1),
    "muro_tijolo": _m(3.0, 0.4, 2.0, lx=1.6, zmax=2.7, yf=0.5),
    "muro_quebrado": _m(3.0, 0.4, 2.0, lx=1.7, zmax=2.7, yf=0.9),
    "ponto_onibus": _m(3.4, 1.3, 2.4, lx=2.3, zmax=2.9, yf=1.0),
    # carros: comprimento ao longo de X; os "_v" ao longo de Y (a frente para a câmera, ou de costas)
    "carro_a": _m(4.5, 1.9, 1.5, lx=2.6, yb=1.1, yf=1.1),
    "carro_b": _m(4.5, 1.9, 1.5, lx=2.6, yb=1.1, yf=1.1),
    "carro_c": _m(4.5, 1.9, 1.6, lx=2.6, yb=1.1, yf=1.1),
    "carro_queimado": _m(4.5, 1.9, 1.5, lx=2.6, yb=1.1, yf=1.1),
    "carro_a_v": _m(1.9, 4.5, 1.5, lx=1.2, yb=2.7, yf=2.7),
    "carro_b_v": _m(1.9, 4.5, 1.5, lx=1.2, yb=2.7, yf=2.7),
    "carro_c_v": _m(1.9, 4.5, 1.6, lx=1.2, yb=2.7, yf=2.7),
}

# ------------------------------------------------------------------ luzes
# O jogo (v2/cenario.gd) cria UMA luz por objeto (luz_objetos do JSON: tipo, luz, orbe, fogo), com os deslocamentos RELATIVOS AO PÉ do sprite. Os objetos
# com mais de uma fonte (fachada com vitrine e neon) dão a principal em luz_objetos e as outras em "extras", que o def_cidade.py põe em "luzes"
# (luzes soltas do mapa) ao lado de cada cópia do objeto. Cada fonte: tipo, p = ponto 3D da luz em metros a partir da origem (x, y, z) e orbe = ponto 3D do
# brilho que aparece no sprite (padrão: o mesmo), fogo = escala do fogo em partículas (só o barril).
LUZES = {
    "poste_rua": [{"tipo": "lampiao", "p": (1.42, 0.0, 5.12), "orbe": (1.42, 0.0, 5.2)}],
    "poste_rua_e": [{"tipo": "lampiao", "p": (-1.42, 0.0, 5.12), "orbe": (-1.42, 0.0, 5.2)}],
    "semaforo": [{"tipo": "lanterna_rubra", "p": (-0.55, -0.16, 2.95)}],
    "placa_neon": [{"tipo": "vitral_roxo", "p": (0.0, -0.2, 2.72)}],
    "barril_fogo": [{"tipo": "fogo_barril", "p": (0.0, 0.0, 0.85), "orbe": (0.0, 0.0, 0.9), "fogo": 1.0}],
    "ponto_onibus": [{"tipo": "janela_quente", "p": (0.75, -0.55, 1.5)}],
    "predio_loja": [{"tipo": "janela_quente", "p": (-1.0, -1.6, 1.4)}, {"tipo": "lampiao", "p": (-0.5, -1.6, 3.1)}],
    "predio_bar": [{"tipo": "vitral_roxo", "p": (-0.7, -1.75, 2.8)}, {"tipo": "janela", "p": (-1.7, -1.5, 1.2)}],
    "predio_torre": [{"tipo": "lanterna_rubra", "p": (-0.1, -1.2, 3.1)}],
    "predio_apto_a": [{"tipo": "janela", "p": (0.0, -1.2, 3.1)}, {"tipo": "janela", "p": (-1.7, -1.2, 3.1)}],
    "predio_apto_b": [{"tipo": "janela", "p": (-1.7, -1.2, 3.1)}, {"tipo": "janela", "p": (1.7, -1.2, 3.1)}],
}

# Sugestão de luz_tipos (mesmo formato do v2_laboratorio.json): e = energia, r = raio em px, h = altura da luz para o normal map.
LUZ_TIPOS = {
    "lampiao": {"cor": [1.0, 0.68, 0.3], "e": 1.8, "r": 300, "h": 90, "tremor": 0.08, "orbe": 0.4},
    "fogo_barril": {"cor": [1.0, 0.56, 0.22], "e": 1.9, "r": 250, "h": 30, "tremor": 0.12, "orbe": 0.5},
    "vitral_roxo": {"cor": [0.66, 0.42, 1.0], "e": 1.3, "r": 190, "h": 50, "tremor": 0.07, "orbe": 0.3},
    "lanterna_rubra": {"cor": [1.0, 0.2, 0.14], "e": 0.9, "r": 150, "h": 60, "tremor": 0.12, "orbe": 0.25},
    "janela_quente": {"cor": [1.0, 0.76, 0.42], "e": 1.0, "r": 150, "h": 30, "tremor": 0.04, "orbe": 0.15},
    "janela": {"cor": [1.0, 0.68, 0.34], "e": 0.8, "r": 110, "h": 30, "tremor": 0.03, "orbe": 0.1},
}


def _rel_pe(nome, p):
    """Ponto 3D -> deslocamento em px a partir do PÉ do sprite (frente da pegada), que é como o JSON do mapa guarda as luzes."""
    dx, dy = px(p)
    return [dx, round(dy - MEDIDAS[nome]["d"] * PY / 2.0, 1)]


def luz_objetos():
    """O trecho luz_objetos do JSON do mapa: a luz PRINCIPAL (a primeira) de cada objeto, relativa ao pé."""
    out = {}
    for nome, fontes in LUZES.items():
        f = fontes[0]
        d = {"tipo": f["tipo"], "luz": _rel_pe(nome, f["p"]), "orbe": _rel_pe(nome, f.get("orbe", f["p"]))}
        if f.get("fogo"):
            d["fogo"] = f["fogo"]
        out[nome] = d
    return out


def luzes_extras():
    """nome -> lista de {tipo, luz, orbe} (relativos ao pé) das fontes além da principal: o def_cidade.py soma à posição de cada cópia do objeto."""
    out = {}
    for nome, fontes in LUZES.items():
        if len(fontes) > 1:
            out[nome] = [{"tipo": f["tipo"], "luz": _rel_pe(nome, f["p"]), "orbe": _rel_pe(nome, f.get("orbe", f["p"]))} for f in fontes[1:]]
    return out


# ------------------------------------------------------------------ piso (geometria do azulejo de 16 m; veja modelos3d/cidade_piso.py)
PISO = {
    "lado_m": 16.0,
    "tam_px": (512, 362),                 # o azulejo no jogo: 16 m x 32 px e 16 m x 22,63 px
    "calcada_m": (3.25, 12.75),           # meio-fio: a calçada e o lote ocupam este quadrado (cantos arredondados de 0,8 m)
    "lote_m": (4.5, 11.5),                # o lote de concreto de 7 m onde ficam os prédios
    "rua_m": 6.5,                         # largura do asfalto; o eixo das ruas fica nas bordas do azulejo
}


def lote_px(i, j):
    """Retângulo (x, y, w, h) em px do mundo do lote do azulejo (i, j) (coluna e linha), com o azulejo começando em (0, 0) do mapa. A imagem tem o norte em cima."""
    w, h = PISO["tam_px"]
    x0 = PISO["lote_m"][0] * PX
    x1 = PISO["lote_m"][1] * PX
    # a imagem tem y = 16 m na linha 0: o lote em y de 4,5 a 11,5 m vira a faixa central da imagem (de cima para baixo)
    y0 = (PISO["lado_m"] - PISO["lote_m"][1]) * PY
    y1 = (PISO["lado_m"] - PISO["lote_m"][0]) * PY
    return (i * w + x0, j * h + y0, x1 - x0, y1 - y0)


def px(p):
    """Ponto 3D (x, y, z) em metros -> deslocamento em pixels da ORIGEM do objeto (x para a direita, y para baixo)."""
    return (round(p[0] * PX, 1), round(-(p[1] + p[2]) * PY, 1))


def tela(nome):
    """Tela do render (largura, altura, linha da origem) em pixels: margem de 8 px em volta do que o objeto ocupa."""
    m = MEDIDAS[nome]
    larg = int(math.ceil(2.0 * m["lx"] * PX)) + 16
    larg += larg % 2
    alt = int(math.ceil((m["zmax"] + m["yb"] + m["yf"]) * PY)) + 16
    pe_y = (m["zmax"] + m["yb"]) * PY + 8
    return larg, alt, pe_y
