"""Perfil do FABIAN (herói fabio, arma YUMI) para o gerar.py do Hazaki: mesmo rig, mesma câmera e mesma técnica de render; muda o modelo, as cores e a arma.

Herói: arqueiro de arco longo (YUMI). Golpe: tiro, tiro, tiro duplo (ver dados/v2_herois.json, "fabio"). Aqui a katana sai e entra um arco
ENCURTADO (cerca de 1 m, o que cabe nos 44 px do quadro), preso ao tronco, do lado esquerdo da tela, na frente do corpo: é ele que a mão esquerda
segura nas animações de repouso, e no tiro o braço esquerdo estica até a pega, enquanto o direito puxa a corda até o rosto.
Limitações: a corda é uma linha fixa (não curva no tiro), não há flecha no quadro (a flecha é o projétil do jogo), e as animações de escudo, rolamento,
dano e morte são as do Hazaki (com o arco preso ao tronco), não poses próprias.
"""
import bpy

NOME = "fabio"

# Cor-assinatura (#586): marrom-couro saturado e médio (o shader ainda escurece em 4 faixas); capuz = tom mais escuro do mesmo marrom.
PALETA = {
    "Tecido vermelho queimado": "#a8662c",   # casaco marrom-couro
    "Vermelho iluminado": "#c8843e",         # gola e aba clara
    "Dobras do tecido": "#7a4818",           # aba escura e costura
    "Calça azul carvão": "#3a2a26",          # calça marrom bem escura (separa do casaco)
    "Cabelo quase preto": "#6a3c16",         # CAPUZ: marrom mais escuro que o casaco
    "Couro castanho": "#46301c",
    "Pele": "#9a6240", "Rosto iluminado": "#b87c56",
    "Aço azulado": "#c8a060", "Fio polido": "#d6e0ea",
    "Latão antigo": "#c8a050", "Olho": "#0a0c14",
    "Manga escura": "#94581e", "Camisa escura": "#4a301c", "Bota preta": "#33241c", "Braçadeira": "#4a2e18",
    # arco: madeira clara e pega escura (materiais próprios; o ARMA_CLAREAR ainda os clareia 30%)
    "Madeira do arco": "#b8662a", "Pega do arco": "#3a2412",
    # aljava com penas (segunda marca de arqueiro): couro e três cores de pena
    "Aljava": "#7a4a22", "Pena vermelha": "#e04030", "Pena creme": "#f0e8d0", "Pena verde": "#40b070",
}
# a corda do arco (#f0e8d0, 1 px) é emissiva: não escurece nas 4 faixas e o ARMA_CLAREAR não a mexe
BRILHANTES = {"Reflexo frio": "#8ea9c4", "Corda do arco": "#f0e8d0"}

KATANA = ("Cabo da katana", "Trança do cabo", "Guarda da katana", "Lâmina da katana", "Ponta da katana", "Fio azul refletido")
# YUMI assimétrico (pega no terço de baixo, ramo de cima mais longo), do lado esquerdo da tela e à frente do tronco, afastado dele.
# ARCO_* = a pega (centro do ARMA_ESCALA). Medidas em METROS FINAIS (já com o 1,5x do padrão): _FX/_FZ as devolvem ao modelo antes da escala.
ARCO_X, ARCO_Y, ARCO_Z = -0.98, -0.30, 1.85
ARCO_CIMA, ARCO_BAIXO = 1.72, 1.30     # comprimento dos dois ramos a partir da pega (passa da cabeça em cima)
ARCO_BARRIGA = 0.30                    # quanto a madeira se afasta da corda (a corda fica entre o arco e o corpo)
ARCO_RECURVA = 0.11                    # as pontas voltam para fora
_FZ, _FX = 1.5, 1.15                   # ARMA_ESCALA (ao longo do arco) e ARMA_ESPESSURA (de lado)


def _material(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    return m


def ajustar(ns, heroi, osso_de, apagar):
    """Tira a katana e o lenço, põe o casaco marrom, o capuz caído, a aljava com penas e o arco curvo com corda."""
    apagar(KATANA + ("Lenço ao vento", "Face escura do lenço", "Bainha", "Terminal da bainha", "Mecha de cabelo", "Cabelo"))
    por_prefixo = [
        ("Braço", "Manga escura"), ("Antebraço", "Pele"), ("Proteção", "Braçadeira"),
        ("Bota ", "Bota preta"), ("Aba do casaco esquerda", "Tecido vermelho queimado"), ("Faixa da bota", "Couro castanho"), ("Fivela pequena", "Aço azulado"),
    ]
    for o in heroi:
        for pref, nome in por_prefixo:
            if o.name.startswith(pref) and o.type == "MESH":
                o.data.materials[0] = _material(nome)
    P, segment, line, ico = ns["P"], ns["segment"], ns["line"], ns["ico"]
    novos = []
    # CAPUZ (lê melhor que o cabelo espetado em 44 px): calota lisa e redonda sobre a nuca e o topo da cabeça, empurrada para trás para a testa e o rosto
    # aparecerem, mais a gola do capuz sobre os ombros. A ponta NÃO sobe (repetia o chapéu do Luke): cai para trás, como o rabo de um capuz.
    # "Capuz ..." escala com a cabeça (CABECA_PREF "Cabelo"), por isso se chama "Cabelo do capuz".
    cap = _material("Cabelo quase preto")
    novos.append(ico("Cabelo do capuz", P(0, 0.12, 2.80), (0.375, 0.33, 0.36), cap, 2))
    novos.append(segment("Cabelo do capuz rabo", P(0, 0.36, 2.92), P(0, 0.60, 2.40), 0.21, 0.13, cap, 6))   # rabo do capuz, caído nas costas
    novos.append(ico("Cabelo do capuz fundo", P(0, 0.15, 2.58), (0.34, 0.27, 0.34), cap, 2))
    novos.append(ico("Gola do capuz", P(0, 0.03, 2.36), (0.50, 0.36, 0.17), cap, 2))
    # ALJAVA nas costas, sobre o ombro direito da tela, com três penas (vermelha, creme, verde) que aparecem ao lado da cabeça
    couro = _material("Aljava")
    novos.append(segment("Aljava", P(0.22, 0.46, 1.25), P(0.74, 0.44, 2.72), 0.21, 0.23, couro, 6))
    novos.append(segment("Aljava boca", P(0.74, 0.44, 2.72), P(0.77, 0.44, 2.80), 0.25, 0.25, _material("Pega do arco"), 6))
    for nome, base, ponta in (("vermelha", (0.60, 0.44, 2.80), (0.52, 0.42, 3.36)), ("creme", (0.76, 0.44, 2.82), (0.80, 0.42, 3.50)),
                              ("verde", (0.92, 0.44, 2.80), (1.04, 0.42, 3.30))):
        novos.append(segment("Pena " + nome, P(*base), P(*ponta), 0.105, 0.055, _material("Pena " + nome), 4))
    # ARCO: madeira em curva (barriga para fora, pontas recurvadas para fora), corda de uma ponta à outra do lado do corpo, pega enrolada.
    # Coordenadas em metros finais relativas à pega; _fx/_fz devolvem ao modelo (o gerar escala o arco em torno da pega depois).
    def _modelo(zr):
        """Ponto da madeira à altura zr (m finais, relativo à pega): x = pega na barriga, corda do lado do corpo, pontas recurvadas para fora."""
        L = ARCO_CIMA if zr >= 0 else ARCO_BAIXO
        u = min(abs(zr) / L, 1.0)
        dx = ARCO_BARRIGA * u * u                                # 0 na pega (o ponto mais fora), BARRIGA nas pontas (mais perto do corpo)
        k = max(0.0, (u - 0.72) / 0.28)
        dx -= ARCO_RECURVA * k * k                               # recurva: as pontas voltam para fora (-x)
        return P(ARCO_X + dx / _FX, ARCO_Y, ARCO_Z + zr / _FZ)
    zs = [-ARCO_BAIXO * (i / 9.0) for i in range(9, 0, -1)] + [ARCO_CIMA * (i / 12.0) for i in range(0, 13)]
    pts = [_modelo(zr) for zr in zs]
    mad = _material("Madeira do arco")
    # a barriga já é "dx - BARRIGA"; reposiciona para que a PEGA fique em ARCO_X e a corda em ARCO_X + BARRIGA
    pts = [(ARCO_X + (p[0] - ARCO_X - ARCO_BARRIGA * 0), p[1], p[2]) for p in pts]
    # a madeira é UMA curva com bisel (tubo liso, sem as emendas de prismas que liam como bambu segmentado)
    novos.append(line("Madeira do arco", pts, 0.088, mad))
    g0, g1 = P(ARCO_X, ARCO_Y - 0.02, ARCO_Z - 0.22 / _FZ), P(ARCO_X, ARCO_Y - 0.02, ARCO_Z + 0.22 / _FZ)
    novos.append(segment("Pega do arco", g0, g1, 0.10, 0.10, _material("Pega do arco"), 6))
    corda = _material("Corda do arco")
    novos.append(line("Corda do arco", [pts[0], pts[-1]], 0.042, corda))
    heroi.extend(novos)
    for o in novos:
        osso_de[o] = "torso"


# ---------------------------------------------------------------- padrão do elenco (#586); ver hazaki/perfil.py e gerar.py
CABECA = 1.42
ARMA_ESCALA = 1.5
ARMA_ESPESSURA = 1.15
ARMA_CLAREAR = 0.30
ARMA_PECAS = ("Madeira do arco", "Pega do arco", "Corda do arco")        # o arco está preso ao tronco, não ao antebraço
ARMA_PIVO = (ARCO_X, ARCO_Y - 0.75, ARCO_Z)                              # centro do arco (mundo do modelo: y + H, H = -0,75)
ESTILO_2D = True
RETRATO = {"pasta": "fabio"}
