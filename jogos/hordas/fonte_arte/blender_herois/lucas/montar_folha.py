"""Monta a FOLHA FINAL do Lucas (todas as animações) no formato que v2/sprites.gd e v2/heroi.gd leem (Python com Pillow).

    python montar_folha.py

Lê quadros/<anim>/<direcao>_<i>_{cor,normal}.png (saída do gerar.py) e grava nesta pasta:
  lucas_final_albedo.png e lucas_final_normal.png: grade de 8 linhas x 50 colunas, quadros 32x44 (cor e normal, mesma silhueta)
  lucas_final.json: formato do jogo (quadro, linhas, colunas, pe_y) + animação -> colunas, quadros e tempo por quadro sugerido
  lucas_final_previa_x4.png: cópia de prévia (albedo ampliado 4x, sobre fundo escuro)

Colunas: as 7 primeiras são as da folha do piloto (parado = coluna 0, andar0..andar5 = colunas 1 a 6), e o heroi.gd anda com
colunas.size() - 1 quadros. As colunas novas vão no FIM: parado 1..3, rolamento, combo (3 golpes x 6), escudo, dano e morte.
Por isso "colunas" do JSON continua com as 7 do andar; as animações novas estão em "animacoes" (ver LEIA-ME.md).
"""
import json
import os

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
W, H = 32, 44
DIRECOES = ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"]
FUNDO = (34, 34, 42)

# animação, quadros, segundos por quadro sugeridos (o jogo decide o ritmo real; andar = 0,09 s, ver LEIA-ME de blender_herois)
ANIMACOES = [
    ("parado", 4, 0.25),
    ("andar", 6, 0.09),
    ("rolamento", 6, 0.07),
    ("combo", 12, 0.06),
    ("escudo", 2, 0.10),
    ("dano", 2, 0.10),
    ("morte", 6, 0.12),
]
# tempo por quadro (s) quando o quadro tem ritmo próprio; mesmos números do S_POR_QUADRO de cada anim_<nome>.py
TEMPOS = {
    "rolamento": [0.07, 0.07, 0.06, 0.06, 0.07, 0.09],
    "combo": [0.07, 0.04, 0.06, 0.07] * 3,
    "escudo": [0.07, 0.14],
    "dano": [0.07, 0.14],
    "morte": [0.10, 0.10, 0.08, 0.05, 0.12, 0.30],
}

# (animação, quadro) de cada coluna da folha, na ordem em que a folha é escrita
COLUNAS = [("parado", 0)] + [("andar", i) for i in range(6)] + [("parado", i) for i in (1, 2, 3)]
COLUNAS += [("rolamento", i) for i in range(6)] + [("combo", i) for i in range(12)]
COLUNAS += [("escudo", i) for i in range(2)] + [("dano", i) for i in range(2)] + [("morte", i) for i in range(6)]

AVISOS = {
    "morte": "cai DE LADO, enrolada e deitada atravessada na tela (cabeca para a esquerda ou a direita); o corpo caido e encolhido 12% e fica a 32 px ou menos, com a borda tocada em varias direcoes (anim_morte.py, medir.py)",
    "andar": "as diagonais e o perfil encostam na borda em alguns quadros (medir.py)",
    "combo": "o braco estendido (e a adaga) encosta na borda de perfil e nas diagonais; o risco da adaga solta e cortado pela celula (medir.py)",
}
AVISOS = {
    "morte": "cai DE LADO, deitada atravessada na tela (cabeca para a esquerda ou a direita), encolhida; nos quadros deitados o corpo (botas, katana) passa 3 a 5 px dos 32 e e cortado pela celula (anim_morte.py, medir.py)",
    "andar": "baixo_esq, baixo_dir, cima_esq e cima_dir encostam na borda em alguns quadros (medir.py)",
    "rolamento": "quadro 1 (mergulho): a bainha ou a katana encostam na borda de perfil e em baixo_dir/cima_esq (medir.py)",
    "combo": "o rastro da lamina e a ponta da katana encostam na borda em varios quadros de golpe, de perfil e nas diagonais; o rastro e cortado pela celula (medir.py)",
    "dano": "frente, costas e baixo_dir/cima_esq encostam 1 px na borda (os bracos abertos; medir.py)",
}


def nome_coluna(anim, quadro):
    return "%s%d" % (anim, quadro)


def carregar(anim, quadro, direcao, tipo):
    caminho = os.path.join(AQUI, "quadros", anim, "%s_%d_%s.png" % (direcao, quadro, tipo))
    return Image.open(caminho).convert("RGBA")


def montar(tipo):
    folha = Image.new("RGBA", (len(COLUNAS) * W, len(DIRECOES) * H), (0, 0, 0, 0))
    for c, (anim, q) in enumerate(COLUNAS):
        for r, d in enumerate(DIRECOES):
            im = carregar(anim, q, d, tipo)
            if im.size != (W, H):
                raise SystemExit("quadro com tamanho errado: %s %s %d %s" % (anim, d, q, im.size))
            folha.paste(im, (c * W, r * H))
    return folha


def colunas_de(anim):
    return [c for c, (a, _) in enumerate(COLUNAS) if a == anim]


def main():
    albedo = montar("cor")
    normal = montar("normal")
    # a silhueta da cor e da normal tem de ser a mesma, coluna a coluna
    if albedo.getchannel("A").tobytes() != normal.getchannel("A").tobytes():
        raise SystemExit("silhueta da normal difere da cor")
    albedo.save(os.path.join(AQUI, "lucas_final_albedo.png"))
    normal.save(os.path.join(AQUI, "lucas_final_normal.png"))

    previa = Image.new("RGBA", (albedo.width * 4, albedo.height * 4), FUNDO + (255,))
    previa.alpha_composite(albedo.resize((albedo.width * 4, albedo.height * 4), Image.NEAREST))
    previa.convert("RGB").save(os.path.join(AQUI, "lucas_final_previa_x4.png"))

    info = {
        "quadro": [W, H],
        "elevacao": 45.0,
        "ppu": 24.5,
        "pe_y": 42,
        "linhas": DIRECOES,
        "colunas": ["parado"] + ["andar%d" % i for i in range(6)],
        "render": "Cycles, pixel nativo 32x44, 1 amostra, sem bloom (gerar.py, 8 direções, cor e normal)",
        "tempo_render_s": 28,
        "grade": {"linhas": len(DIRECOES), "colunas": len(COLUNAS), "quadro": [W, H]},
        "nomes_colunas": [nome_coluna(a, q) for a, q in COLUNAS],
        "animacoes": {},
        "nota": "heroi.gd anda com colunas.size() - 1 quadros: por isso 'colunas' tem so o andar. As outras animacoes estao em 'animacoes'.",
    }
    for anim, n, s in ANIMACOES:
        if len(colunas_de(anim)) != n:
            raise SystemExit("contagem de colunas de %s diferente de %d" % (anim, n))
        entrada = {"colunas": colunas_de(anim), "quadros": n, "s_por_quadro": s, "fps": round(1.0 / s, 1)}
        if anim in TEMPOS:
            entrada["s_quadros"] = TEMPOS[anim]
        if anim in AVISOS:
            entrada["aviso"] = AVISOS[anim]
        info["animacoes"][anim] = entrada
    info["animacoes"]["combo"]["golpes"] = 3
    info["animacoes"]["combo"]["quadros_por_golpe"] = 4
    info["animacoes"]["combo"]["golpes_tipo"] = ["arremesso_direita", "arremesso_esquerda", "leque"]
    info["animacoes"]["combo"]["quadros_do_golpe"] = ["puxa", "lanca", "braco_estendido", "volta"]
    with open(os.path.join(AQUI, "lucas_final.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("folha %dx%d (%d colunas x %d linhas)" % (albedo.width, albedo.height, len(COLUNAS), len(DIRECOES)))


main()
