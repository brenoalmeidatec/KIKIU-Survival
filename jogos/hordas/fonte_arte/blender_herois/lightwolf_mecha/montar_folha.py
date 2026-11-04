"""Monta a FOLHA FINAL do mecha do LightWolf no formato que v2/sprites.gd e v2/heroi.gd leem (Python com Pillow).

    python montar_folha.py

Lê quadros/<anim>/<direcao>_<i>_{cor,normal}.png (saída do gerar.py) e grava nesta pasta:
  lightwolf_mecha_final_albedo.png e lightwolf_mecha_final_normal.png: grade de 8 linhas x 38 colunas, quadros 128x192 (cor e normal, mesma silhueta)
  lightwolf_mecha_final.json: formato do jogo (quadro, linhas, colunas, pe_y) + animação -> colunas, quadros e tempo por quadro
  lightwolf_mecha_final_previa_x3.png: cópia de prévia (albedo ampliado 3x, sobre fundo escuro)

Colunas (mesma regra do Hazaki): as 7 primeiras são as do andar (parado = coluna 0, andar0..andar5 = colunas 1 a 6), e o heroi.gd anda com
colunas.size() - 1 quadros; as demais vão no FIM, na ordem de COLUNAS. Por isso "colunas" do JSON tem só as 7 do andar; as outras animações
estão em "animacoes".
"""
import json
import os

from PIL import Image, ImageChops, ImageFilter

AQUI = os.path.dirname(os.path.abspath(__file__))
W, H = 128, 192
PE_Y = 120         # PE_LINHA - 1 do gerar.py (H - 1 - MARGEM_BAIXO = 121)
DIRECOES = ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"]
FUNDO = (34, 34, 42)
CONTORNO = (12, 18, 30, 255)
NORMAL_NEUTRA = (128, 128, 255, 255)

# Centros dos bocais projetados pela câmera do gerar.py; relativos aos pés (64,120).
# Canhões em combo0; pods em parado0. Ordem DIRECOES, esquerda/direita do rig.
BOCAS_PROJETEIS = {
    'canhoes': [[[-20.9, -8.5], [20.9, -8.5]], [[-38.32, -50.37], [-38.32, -20.81]], [[38.32, -20.81], [38.32, -50.37]], [[20.9, -62.69], [-20.9, -62.69]], [[-41.87, -26.89], [-12.31, -5.99]], [[12.31, -5.99], [41.87, -26.89]], [[-12.31, -65.2], [-41.87, -44.3]], [[41.87, -44.3], [12.31, -65.2]]],
    'pods': [[[-19.18, -48.98], [19.18, -48.98]], [[-4.13, -65.47], [-4.13, -38.34]], [[4.13, -38.34], [4.13, -65.47]], [[19.18, -54.82], [-19.18, -54.82]], [[-16.48, -59.43], [10.64, -40.25]], [[-10.64, -40.25], [16.48, -59.43]], [[10.64, -63.56], [-16.48, -44.38]], [[16.48, -44.38], [-10.64, -63.56]]],
}

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
    "combo": "tiro esquerdo (quadros 0 a 5) e direito (6 a 11); clarão no quadro 1 de cada tiro, alinhado a acerto_em=0.2; medir.py confere as quatro bordas com o contorno",
    "morte": "cai de lado, deitado atravessado na tela (cabeca para a esquerda ou a direita), encolhido",
}


def nome_coluna(anim, quadro):
    return "%s%d" % (anim, quadro)


def carregar(anim, quadro, direcao, tipo):
    caminho = os.path.join(AQUI, "quadros", anim, "%s_%d_%s.png" % (direcao, quadro, tipo))
    return Image.open(caminho).convert("RGBA")


def mascara_contorno(alfa):
    """Um pixel externo em cada quadro, incluindo diagonais; nunca dilata entre células."""
    opaco = alfa.point(lambda a: 255 if a else 0)
    return ImageChops.subtract(opaco.filter(ImageFilter.MaxFilter(3)), opaco)


def contornar(im, tipo, alfa_cor=None):
    """Preserva pixels originais e acrescenta o mesmo contorno opaco a cor e normal."""
    alfa = im.getchannel("A")
    if alfa_cor is not None and alfa.tobytes() != alfa_cor.tobytes():
        raise ValueError("silhueta da normal difere da cor")
    mascara = mascara_contorno(alfa_cor if alfa_cor is not None else alfa)
    saida = im.copy()
    saida.paste(CONTORNO if tipo == "cor" else NORMAL_NEUTRA, (0, 0, im.width, im.height), mascara)
    return saida


def montar(tipo):
    folha = Image.new("RGBA", (len(COLUNAS) * W, len(DIRECOES) * H), (0, 0, 0, 0))
    for c, (anim, q) in enumerate(COLUNAS):
        for r, d in enumerate(DIRECOES):
            im = carregar(anim, q, d, tipo)
            if im.size != (W, H):
                raise SystemExit("quadro com tamanho errado: %s %s %d %s" % (anim, d, q, im.size))
            alfa_cor = carregar(anim, q, d, "cor").getchannel("A") if tipo == "normal" else None
            try:
                im = contornar(im, tipo, alfa_cor)
            except ValueError as erro:
                raise SystemExit("%s %s %d: %s" % (anim, d, q, erro)) from erro
            folha.paste(im, (c * W, r * H))
    return folha


def colunas_de(anim):
    return [c for c, (a, _) in enumerate(COLUNAS) if a == anim]


def main():
    albedo = montar("cor")
    normal = montar("normal")
    if albedo.getchannel("A").tobytes() != normal.getchannel("A").tobytes():
        raise SystemExit("silhueta da normal difere da cor")
    albedo.save(os.path.join(AQUI, "lightwolf_mecha_final_albedo.png"))
    normal.save(os.path.join(AQUI, "lightwolf_mecha_final_normal.png"))

    previa = Image.new("RGBA", (albedo.width * 3, albedo.height * 3), FUNDO + (255,))
    previa.alpha_composite(albedo.resize((albedo.width * 3, albedo.height * 3), Image.NEAREST))
    previa.convert("RGB").save(os.path.join(AQUI, "lightwolf_mecha_final_previa_x3.png"))

    info = {
        "quadro": [W, H],
        "elevacao": 45.0,
        "ppu": 24.5,
        "pe_y": PE_Y,
        "corpo_fixo_ao_atirar": True,
        "bocas_projeteis": BOCAS_PROJETEIS,
        "segurar_mira_s": 0.12,
        "poses_habilidades": {"misseis": "parado"},
        "retrato": {"regiao": [27, 42, 74, 84]},  # provisório: conferir o mecha renderizado de frente no HUD
        "linhas": DIRECOES,
        "colunas": ["parado"] + ["andar%d" % i for i in range(6)],
        "render": "Cycles, pixel nativo 128x192 (mecha em escala ampliada), 1 amostra, sem bloom (gerar.py, 8 direcoes, cor e normal)",
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
    info["animacoes"]["combo"]["sem_clarao"] = {"1": 2, "7": 8}
    info["animacoes"]["combo"]["quadros_por_golpe"] = 6
    info["animacoes"]["combo"]["golpes_tipo"] = ["batida", "pancada"]
    info["animacoes"]["combo"]["quadros_do_golpe"] = ["antecipacao", "antecipacao_funda", "golpe", "impacto", "segura", "volta"]
    with open(os.path.join(AQUI, "lightwolf_mecha_final.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("folha %dx%d (%d colunas x %d linhas)" % (albedo.width, albedo.height, len(COLUNAS), len(DIRECOES)))


if __name__ == "__main__":
    main()
