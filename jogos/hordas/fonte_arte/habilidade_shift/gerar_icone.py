"""Gera o ícone do IMPULSO do mecha do LightWolf (o slot do Shift na HUD, v2/hud_habilidades.gd).

Arte própria em pixel, desenhada aqui caractere a caractere (32x32, alfa só 0 ou 255): a mochila de propulsores do mecha vista de trás, com a seta
de subida, traços de velocidade e duas chamas. Nenhuma imagem de terceiros.
Uso (da raiz do repositório): python jogos/hordas/fonte_arte/habilidade_shift/gerar_icone.py
"""

from pathlib import Path

from PIL import Image

SAIDA = Path("jogos/hordas/projeto/assets/v2/habilidade_shift/lightwolf.png")
CORES = {
    "k": (18, 28, 44, 255),
    "b": (140, 220, 255, 255),
    "B": (70, 150, 220, 255),
    "w": (235, 250, 255, 255),
    "o": (255, 190, 70, 255),
    "r": (240, 110, 40, 255),
    "y": (255, 240, 160, 255),
    "g": (120, 140, 160, 255),
}
ARTE = [
    "................................",
    "...............kk...............",
    "..............kwwk..............",
    ".............kwbbwk.............",
    "............kwbbbbwk............",
    "...........kwbbBBbbwk...........",
    "..........kwbbBkkBbbwk..........",
    ".........kwbbBk..kBbbwk.........",
    "........kkkkkk....kkkkkk........",
    "................................",
    "......kkkkk..........kkkkk......",
    ".bbb.kwbbbbk........kwbbbbk.bbb.",
    ".....kbbbbBk........kbbbbBk.....",
    ".....kbbbbBkkkkkkkkkkbbbbBk.....",
    ".bbb.kbbbbBkwbbbbbbwkbbbbBk.bbb.",
    ".....kbbbbBkbBBBBBBbkbbbbBk.....",
    ".....kbbbbBkbBkkkkBbkbbbbBk.....",
    ".bbb.kbbbbBkbBBBBBBbkbbbbBk.bbb.",
    ".....kgggggkkkkkkkkkkgggggk.....",
    "......kgggk..........kgggk......",
    "......kyyyk..........kyyyk......",
    "......kyoyk..........kyoyk......",
    ".......yoy............yoy.......",
    ".......ooo............ooo.......",
    ".......oro............oro.......",
    "........r..............r........",
    ".......oro............oro.......",
    "........r..............r........",
    "................................",
    "................................",
    "................................",
    "................................",
]


def main() -> None:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = img.load()
    for y, linha in enumerate(ARTE):
        assert len(linha) == 32, (y, len(linha))
        for x, ch in enumerate(linha):
            if ch in CORES:
                px[x, y] = CORES[ch]
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    img.save(SAIDA)


if __name__ == "__main__":
    main()
