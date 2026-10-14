"""Heróis novos da v2 (Nicão e Lucas) no formato de folha do Hazaki: 8 direções x [parado, andar 0, 2, 4, 6], com albedo e normal.

Não roda sozinho: o `gerar_cara_nova.py` (modo `heroi_v2`) chama `gerar(g, nome)` passando o próprio módulo (`g`), para reaproveitar o
patch dos materiais (albedo chapado + normal), o render dos 3 passes, o pós-processo e a gravação, SEM mexer nos modos que já existiam.
Cada herói é um módulo em jogos/hordas/fonte_arte/modelos3d (v2_nicao.py, v2_lucas.py) com o contrato:
    NOME, QUADRO (largura, altura), PE (linha do pé no quadro), PAL (paleta), DIRECOES,
    montar() -> (raiz, corpo, ossos)   e   pose(corpo, ossos, acao, q)  com acao "parado" ou "andar" (q = 0..7)

Uso (Blender 4.5), a partir de jogos/hordas/prototipos/cara_nova:
    blender -b -P gerar_cara_nova.py -- heroi_v2 nicao
    blender -b -P gerar_cara_nova.py -- heroi_v2 lucas
Saída: projeto/prototipos/cara_nova/sprites/<nome>_albedo.png, <nome>_normal.png e <nome>.json (quadro, linhas, colunas, pe_y).
"""
import importlib


def gerar(g, nome):
    px3 = g.px3
    m = importlib.import_module("v2_" + nome)
    w, h = m.QUADRO
    px3.limpar_cena()
    g.VARIANTES.clear()
    px3.preparar_render(w, h)
    cam = px3.camera(elevacao_graus=g.ELEVACAO, escala=max(w, h) / g.PPU)
    raiz, corpo, p = m.montar()
    g.engrossar_olhos()
    g.trocar_passe("albedo")
    m.pose(corpo, p, "parado", 0)
    # só a altura do pé é calibrada: o corpo está no x = 0 do modelo e fica no meio do quadro (a arma de um lado não o desloca)
    cam.data.shift_x = 0.0
    cam.data.shift_y = 0.0
    cx = px3.caixa_alfa(px3.render_rgba())
    cam.data.shift_y = -(cx[3] - m.PE) / max(w, h)
    cx = px3.caixa_alfa(px3.render_rgba())
    print("HEROI_V2", nome, "caixa (x0,y0,x1,y1):", cx, "altura:", cx[3] - cx[1] + 1, "largura:", cx[2] - cx[0] + 1)
    acoes = [("parado", 0)] + [("andar", q) for q in g.ANDAR_HEROI]
    quadros = {}
    for linha, ang in enumerate(m.DIRECOES):
        raiz.rotation_euler = (0, 0, g.math.radians(ang))
        for col, (acao, q) in enumerate(acoes):
            m.pose(corpo, p, acao, q)
            quadros[(linha, col)] = g.render_tres(m.PAL, False)
    folhas = g.montar_folha(nome, quadros, len(m.DIRECOES), len(acoes), w, h)
    g.gravar(nome, folhas, w, h,
             {"linhas": ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"],
              "colunas": ["parado"] + ["andar%d" % q for q in g.ANDAR_HEROI], "pe_y": m.PE})
