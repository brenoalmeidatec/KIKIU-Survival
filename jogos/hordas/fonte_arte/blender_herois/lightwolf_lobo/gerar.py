"""Gera os quadros do LOBO do LightWolf (Blender 4.5) no rig do Luke: roda o ../lucas/gerar.py (rig, camera, luz, contorno, normal e as anim_*.py do Luke)
trocando so o modelo (modelo_lobo.py), a paleta e a pasta de saida.

    blender -b -t 6 -P gerar.py                     # todas as animacoes: quadros/<anim>/... + lobo_rig.blend
    blender -b -t 6 -P gerar.py -- --anim=andar     # so uma
"""
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
LUCAS = AQUI.parent / "lucas" / "gerar.py"
sys.path.insert(0, str(AQUI))

PALETA_LOBO = {
    "Pelo": "#b4d2f6", "Pelo sombra": "#6f98d6", "Orelha interna": "#a995bd", "Nariz escuro": "#1d2c4a",
    "Traje azul": "#3f7ed4", "Traje claro": "#66a4f0", "Traje escuro": "#2a4a7c", "Armadura branca": "#d4e4fa",
    "Couro escuro": "#222c46", "Arma branca": "#f2f8ff", "Arma cabo": "#5a6c94",
}
BRILHANTES_LOBO = {"Ciano brilho": "#7ff3ff", "Olho ciano": "#59e6ff"}


# ---------------------------------------------------------------- padrao do elenco (#586): o gerar.py do Luke nao tem estes parametros, entao entram por troca de texto
CABECA_LOBO = 1.36            # era 1,18: cabeca ~35-40% da altura (as orelhas foram baixadas em modelo_lobo.py para caberem)
ARMA_ESCALA = 1.5             # pistola 1,5x mais comprida
ARMA_ESPESSURA = 1.15
ARMA_ESCALA_ANIM = {"escudo": 0.65, "dano": 0.65, "rolamento": 0.7, "morte": 0.8}   # fator sobre o ARMA_ESCALA
RETRATO = {"pasta": "lightwolf", "cranio": "Cabeça de lobo"}


def trocar(src, a, b):
    assert src.count(a) == 1, "trecho nao encontrado (o gerar.py do Luke mudou?): " + a
    return src.replace(a, b)


src = LUCAS.read_text(encoding="utf-8")
src = trocar(src, 'SAIDA = AQUI / "quadros"', 'SAIDA = Path(r"%s") / "quadros"' % (AQUI,))
src = trocar(src, "import modelo  # noqa: E402", "import modelo_lobo as modelo  # noqa: E402")
src = trocar(src, "BRILHANTES = {}", "PALETA = %r\nBRILHANTES = %r" % (PALETA_LOBO, BRILHANTES_LOBO))
src = trocar(src, 'CABECA_PREF = ("Cabeça",', 'CABECA_PREF = ("Orelha", "Focinho", "Nariz do lobo", "Cabeça",')
src = trocar(src, "CABECA = 1.32", "CABECA = %r" % CABECA_LOBO)
src = trocar(src, 'str(AQUI / "lucas_rig.blend")', 'r"%s"' % (AQUI / "lobo_rig.blend"))
# ---------------------------------------------------------------- padrao do elenco (#586): trocas de texto no framework do Luke
SAIDA_E_FLAGS = """SAIDA = Path(r"%s") / "quadros"
SO_RETRATO = "--retrato" in ARGS           # so o retrato 64x64 (pula as animacoes)
SEM_RETRATO = "--sem-retrato" in ARGS      # todas as animacoes sem o retrato
ESTILO_2D = {"contorno": True, "escuro": 0.30, "teto": 0.16, "rim": True, "rim_dir": (1, -1), "rim_cor": (0.84, 0.93, 1.0), "rim_forca": 0.55, "rim_largura": 1}
ARMA_ESCALA, ARMA_ESPESSURA, RETRATO, ARMA_ESCALA_ANIM = %r, %r, %r, %r""" % (AQUI, ARMA_ESCALA, ARMA_ESPESSURA, RETRATO, ARMA_ESCALA_ANIM)
src = trocar(src, 'SAIDA = Path(r"%s") / "quadros"' % (AQUI,), SAIDA_E_FLAGS)

# estilo2d (contorno escuro de 1 px + rim light) do pipeline do Hazaki
src = trocar(src, "import ossos  # noqa: E402", "import ossos  # noqa: E402\nsys.path.insert(0, r'%s')\nimport estilo2d  # noqa: E402\nsys.path.remove(r'%s')" % ((AQUI.parent / "hazaki",) * 2))

# ler/gravar_normal para qualquer tamanho (o retrato e 64x64)
src = trocar(src, "px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1].copy()",
             "w, h = img.size\n    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()")
src = trocar(src, 'img = bpy.data.images.new("n", W, H, alpha=True)', 'img = bpy.data.images.new("n", px.shape[1], px.shape[0], alpha=True)')

# casca do contorno guarda a base e o delta (o retrato afina a casca para continuar com ~1 px)
src = trocar(src, "CASCAS = []\nfor original in list(heroi):", "CASCAS = []\nDELTA_CASCA = {}\nfor original in list(heroi):")
src = trocar(src, """    for v in copia.data.vertices:
        v.co = v.co + Ai @ ((Ai.transposed() @ v.normal).normalized() * CONTORNO)
    copia.data.update()""", """    _base = np.empty(len(copia.data.vertices) * 3, np.float32)
    copia.data.vertices.foreach_get("co", _base)
    _delta = []
    for v in copia.data.vertices:
        dv = Ai @ ((Ai.transposed() @ v.normal).normalized() * CONTORNO)
        _delta.extend(dv)
        v.co = v.co + dv
    DELTA_CASCA[copia] = (_base, np.array(_delta, np.float32))
    copia.data.update()""")

# ARMA 1,5x (injetar_arma.py) antes dos materiais
src = trocar(src, "# ============================================================ 2. materiais: 4 faixas",
             (AQUI / "injetar_arma.py").read_text(encoding="utf-8") + "# ============================================================ 2. materiais: 4 faixas")

# pistola menor em algumas animacoes (injetar_arma_anim.py): a de 1,5x saia do quadro no escudo, no dano e no rolamento
src = trocar(src, "# ============================================================ 5. cena", (AQUI / "injetar_arma_anim.py").read_text(encoding="utf-8") + "# ============================================================ 5. cena")
src = trocar(src, "arm.scale = (ESCALA * LARGURA, ESCALA, ESCALA)      # uma animação pode encolher o herói (a morte)\n",
             "arm.scale = (ESCALA * LARGURA, ESCALA, ESCALA)      # uma animação pode encolher o herói (a morte)\n            posar_arma(nome)\n")

# acabamento 2D em cada quadro de cor (contorno escuro + rim), antes do rastro
src = trocar(src, """            if polis:
                cor = ler(str(base) + "_cor.png", True)
                pintar_poligonos(cor, nor, mascara, polis)
                gravar_normal(cor, str(base) + "_cor.png")""", """            if polis or ESTILO_2D:
                cor = ler(str(base) + "_cor.png", True)
                estilo2d.aplicar(cor, mascara, ESTILO_2D)               # contorno escuro + rim: so no corpo, antes do rastro
                if polis:
                    pintar_poligonos(cor, nor, mascara, polis)
                gravar_normal(cor, str(base) + "_cor.png")""")

# retrato (injetar_retrato.py) no lugar do laco final das animacoes
src = trocar(src, "for nome in animacoes():\n    renderizar_animacao(nome)\n", (AQUI / "injetar_retrato.py").read_text(encoding="utf-8"))
src = trocar(src, "if not SO_ANIM:\n    bpy.ops.wm.save_as_mainfile", "if not (SO_ANIM or SO_RETRATO):\n    bpy.ops.wm.save_as_mainfile")

exec(compile(src, str(LUCAS), "exec"), {"__name__": "__main__", "__file__": str(LUCAS)})
