"""Monta a FOLHA FINAL do Nicão (todas as animações) no formato que v2/sprites.gd e v2/heroi.gd leem (Python com Pillow).

    python montar_folha.py

Lê quadros/<anim>/<direcao>_<i>_{cor,normal}.png (saída do gerar.py) e grava nesta pasta:
  nicao_final_albedo.png e nicao_final_normal.png: grade de 8 linhas x 38 colunas, quadros 64x96 (cor e normal, mesma silhueta)
  nicao_final.json: formato do jogo (quadro, linhas, colunas, pe_y) + animação -> colunas, quadros e tempo por quadro
  nicao_final_previa_x3.png: cópia de prévia (albedo ampliado 3x, sobre fundo escuro)

Colunas (mesma regra do Hazaki): as 7 primeiras são as do andar (parado = coluna 0, andar0..andar5 = colunas 1 a 6), e o heroi.gd anda com
colunas.size() - 1 quadros; as demais vão no FIM, na ordem de COLUNAS. Por isso "colunas" do JSON tem só as 7 do andar; as outras animações
estão em "animacoes".
"""
import json
import os

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
W, H = 64, 96
PE_Y = 74          # PE_LINHA - 1 do gerar.py (H - 1 - MARGEM_BAIXO = 75 é a linha do contorno da sola)
DIRECOES = ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"]
FUNDO = (34, 34, 42)

# animação, quadros, segundos por quadro sugeridos
ANIMACOES = [
    ("parado", 4, 0.28),
    ("andar", 6, 0.11),
    ("rolamento", 6, 0.07),
    ("combo", 12, 0.09),
    ("escudo", 2, 0.10),
    ("dano", 2, 0.10),
    ("morte", 6, 0.12),
]
# tempo por quadro (s) quando o quadro tem ritmo próprio; os mesmos números do S_POR_QUADRO de cada anim_<nome>.py
TEMPOS = {
    "parado": [0.28, 0.28, 0.28, 0.28],
    "rolamento": [0.08, 0.07, 0.06, 0.06, 0.07, 0.10],
    "combo": [0.11, 0.13, 0.05, 0.06, 0.12, 0.09] + [0.12, 0.16, 0.05, 0.07, 0.16, 0.10],
    "escudo": [0.07, 0.12],
    "dano": [0.07, 0.13],
    "morte": [0.10, 0.11, 0.08, 0.05, 0.10, 0.40],
}

# (animação, quadro) de cada coluna da folha, na ordem em que a folha é escrita
COLUNAS = [("parado", 0)] + [("andar", i) for i in range(6)] + [("parado", i) for i in (1, 2, 3)]
COLUNAS += [("rolamento", i) for i in range(6)] + [("combo", i) for i in range(12)]
COLUNAS += [("escudo", i) for i in range(2)] + [("dano", i) for i in range(2)] + [("morte", i) for i in range(6)]

AVISOS = {
    "combo": "golpe 1 (batida, quadros 0 a 5) e golpe 2 (pancada, 6 a 11); o impacto e o quadro 3 de cada golpe; a marreta de 3,2 passa de 40 px e cai fora do quadro em poucos quadros de diagonal (medir.py)",
    "morte": "cai DE LADO, deitado atravessado na tela (cabeca para a esquerda ou a direita), encolhido; a marreta cai ao lado, no chao a frente dele",
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
    if albedo.getchannel("A").tobytes() != normal.getchannel("A").tobytes():
        raise SystemExit("silhueta da normal difere da cor")
    albedo.save(os.path.join(AQUI, "nicao_final_albedo.png"))
    normal.save(os.path.join(AQUI, "nicao_final_normal.png"))

    previa = Image.new("RGBA", (albedo.width * 3, albedo.height * 3), FUNDO + (255,))
    previa.alpha_composite(albedo.resize((albedo.width * 3, albedo.height * 3), Image.NEAREST))
    previa.convert("RGB").save(os.path.join(AQUI, "nicao_final_previa_x3.png"))

    info = {
        "quadro": [W, H],
        "elevacao": 45.0,
        "ppu": 24.5,
        "pe_y": PE_Y,
        "retrato": {"regiao": [10, 34, 38, 42], "escala": 2},  # recorte do quadro parado de frente (linha baixo) que o HUD mostra, sem o vazio em volta
        "linhas": DIRECOES,
        "colunas": ["parado"] + ["andar%d" % i for i in range(6)],
        "render": "Cycles, pixel nativo 64x96 (anao ~40 px), 1 amostra, sem bloom (gerar.py, 8 direcoes, cor e normal)",
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
    info["animacoes"]["combo"]["golpes"] = 2
    info["animacoes"]["combo"]["quadros_por_golpe"] = 6
    info["animacoes"]["combo"]["golpes_tipo"] = ["batida", "pancada"]
    info["animacoes"]["combo"]["quadros_do_golpe"] = ["antecipacao", "antecipacao_funda", "golpe", "impacto", "segura", "volta"]
    with open(os.path.join(AQUI, "nicao_final.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("folha %dx%d (%d colunas x %d linhas)" % (albedo.width, albedo.height, len(COLUNAS), len(DIRECOES)))


main()
