"""Borda dura em pixel art: alfa em poucos degraus e paleta enxuta, na FONTE do PNG.

Pixel art de um tamanho de pixel so nao tem alfa gradual (fumaca, anel e brilho com 250 niveis de transparencia): cada pixel
do desenho vira uma mancha de transparencia diferente e a borda "borra" quando o jogo amplia. Aqui o alfa vai para no maximo
DEGRAUS niveis (alem do zero), como no gerar_folhas.py do pixelfx (#602), e a paleta cai para um numero fixo de cores, sem
dither de cor. Brilho e luz suave de verdade (tex_brilho, PointLight2D) ficam como estao: isto e so para pixel art.

Uso (a partir da raiz do repositorio; idempotente, rodar de novo nao muda nada):
  python jogos/hordas/fonte_arte/quantizar_alfa.py              aplica o MANIFESTO (grava no proprio PNG so se mudar)
  python jogos/hordas/fonte_arte/quantizar_alfa.py --verificar  lista o que o MANIFESTO ainda mudaria (codigo 1 se algo)
  python jogos/hordas/fonte_arte/quantizar_alfa.py a.png b.png  so esses (alfa em 6 degraus e 48 cores)

Como biblioteca: `from quantizar_alfa import quantizar_arquivo` e chame no fim do gerador de cada PNG (preparar_status.py,
importar_nuvem.py, gerar_folhas.py...). Os PNG cuja fonte e uma imagem gerada fora do repo (o cartao de arma saido do
imagegen, o render do Blender do fantasma) ficam com o MANIFESTO como unica passagem de limpeza: a fonte original continua no
historico do git e `quantizar_arquivo` e o passo final de qualquer regeracao.
"""
import fnmatch
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.normpath(os.path.join(AQUI, "..", "projeto"))

DEGRAUS = 6  # niveis de alfa alem do zero (0, 43, 85, 128, 170, 213, 255)
# Modo = alfa minimo (fracao 0..1): abaixo dele o pixel some; o resto arredonda ao degrau mais perto.
# Sprite: so some o que nao chega a meio degrau. Brilho e neblina do pixelfx: a neblina fraca (a vinheta escura de um portal, alfa de 5 a 30%)
# NAO vira o primeiro degrau, que seria um halo de contorno duro em volta do efeito; abaixo de 30% some.
MODO_SPRITE = 0.0
MODO_BRILHO = 0.30
CORES = 48  # cores da paleta (so dos pixels visiveis; o RGB do que e transparente vira 0)

# (padrao relativo a jogos/hordas/projeto, cores, modo). Brilho e neblina do pixelfx usam MODO_BRILHO; o resto, MODO_SPRITE. Padrao com "*" vale para o diretorio. Os "*_normal.png" nunca entram.
MANIFESTO = [
    ("assets/v2/armas/*.png", 48, MODO_SPRITE),
    ("assets/v2/armas_anim/nuvem_esporos_*.png", 48, MODO_SPRITE),
    ("assets/v2/icones_cartas/nuvem_espora.png", 48, MODO_SPRITE),
    ("assets/v2/icones_cartas/16/nuvem_espora.png", 48, MODO_SPRITE),
    ("assets/v2/mapas/cidade/decalques.png", 48, MODO_SPRITE),
    ("assets/v2/mapas/laboratorio/decalques.png", 48, MODO_SPRITE),
    ("assets/v2/mapas/medio/decalques.png", 48, MODO_SPRITE),
    ("v2/hud/foco_premium.png", 32, MODO_SPRITE),
    ("assets/v2/escudos/camadas.png", 32, MODO_SPRITE),
    ("assets/v2/pixelfx/status/stunned.png", 32, MODO_BRILHO),
    ("assets/v2/pixelfx/status/slowed.png", 32, MODO_BRILHO),
    ("assets/v2/pixelfx/pickups/collect-burst.png", 48, MODO_BRILHO),
    ("assets/v2/pixelfx/spawn/soul-rise.png", 64, MODO_BRILHO),
    ("assets/v2/pixelfx/spawn/spawn-portal.png", 64, MODO_BRILHO),
    # as folhas -eNN (gerar_folhas.py) ja saem com alfa em degraus (#602): aqui so a paleta
    ("assets/v2/pixelfx/spawn/spawn-portal-e*.png", 64, MODO_SPRITE),
    ("assets/v2/pixelfx/spawn/summon-rise-e*.png", 64, MODO_SPRITE),
    ("assets/v2/pixelfx/pickups/chest-open-e*.png", 64, MODO_SPRITE),
    ("assets/v2/pixelfx/pickups/loot-beam-e*.png", 48, MODO_SPRITE),
    ("assets/v2/pixelfx/ui/level-up-e*.png", 64, MODO_SPRITE),
]


def quantizar_alfa(alfa: np.ndarray, degraus: int = DEGRAUS, minimo: float = MODO_SPRITE) -> np.ndarray:
    """alfa uint8 -> uint8 em `degraus` niveis (0, 255/degraus, ... 255). Abaixo de `minimo` (0..1) o pixel some."""
    f = alfa.astype(np.float32) / 255.0
    n = np.where(f < minimo, 0.0, np.floor(f * degraus + 0.5))
    return np.rint(n * 255.0 / degraus).astype(np.uint8)


def reduzir_paleta(rgb: np.ndarray, cores: int) -> np.ndarray:
    """rgb (N,3) uint8 -> o mesmo vetor com no maximo `cores` cores (median cut, sem dither)."""
    if rgb.shape[0] == 0 or len(np.unique(rgb, axis=0)) <= cores:
        return rgb
    tira = Image.fromarray(np.ascontiguousarray(rgb.reshape(1, -1, 3)), "RGB")
    q = tira.quantize(colors=cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette(), dtype=np.uint8)[: 3 * cores].reshape(-1, 3)
    return pal[np.asarray(q).reshape(-1)]


def quantizar_array(a: np.ndarray, degraus: int = DEGRAUS, cores: int = CORES, modo: float = MODO_SPRITE) -> np.ndarray:
    """a (h,w,4) uint8 -> (h,w,4) uint8 com alfa em degraus e paleta enxuta."""
    out = a.copy()
    out[..., 3] = quantizar_alfa(a[..., 3], degraus, modo)
    vis = out[..., 3] > 0
    out[~vis] = 0
    if cores > 0 and vis.any():
        out[..., :3][vis] = reduzir_paleta(out[..., :3][vis], cores)
    return out


def quantizar_imagem(im: Image.Image, degraus: int = DEGRAUS, cores: int = CORES, modo: float = MODO_SPRITE) -> Image.Image:
    return Image.fromarray(quantizar_array(np.asarray(im.convert("RGBA")), degraus, cores, modo), "RGBA")


def quantizar_arquivo(caminho: str, degraus: int = DEGRAUS, cores: int = CORES, so_verificar: bool = False, modo: float = MODO_SPRITE) -> bool:
    """Quantiza o PNG no proprio lugar. Devolve True se mudou (ou mudaria, com so_verificar). Sem mudanca nao grava."""
    a = np.asarray(Image.open(caminho).convert("RGBA"))
    novo = quantizar_array(a, degraus, cores, modo)
    visivel = np.where((a[..., 3] > 0)[..., None], a, 0)  # o RGB do que e transparente nao conta como mudanca
    if np.array_equal(visivel, novo):
        return False
    if not so_verificar:
        Image.fromarray(novo, "RGBA").save(caminho, optimize=True)
    return True


def alvos():
    """(caminho, cores, modo) de tudo que o MANIFESTO cobre, sem repetir e sem os *_normal.png."""
    vistos = set()
    for padrao, cores, modo in MANIFESTO:
        pasta, nome = os.path.split(os.path.join(PROJETO, padrao))
        if not os.path.isdir(pasta):
            continue
        for f in sorted(os.listdir(pasta)):
            if fnmatch.fnmatch(f, nome) and not f.endswith("_normal.png"):
                p = os.path.join(pasta, f)
                if p not in vistos:
                    vistos.add(p)
                    yield p, cores, modo


def main(argv):
    so_verificar = "--verificar" in argv
    arqs = [a for a in argv if not a.startswith("--")]
    lista = [(a, CORES, MODO_SPRITE) for a in arqs] if arqs else list(alvos())
    mudou = 0
    for p, cores, modo in lista:
        if quantizar_arquivo(p, DEGRAUS, cores, so_verificar, modo):
            mudou += 1
            print(("mudaria " if so_verificar else "quantizado ") + os.path.relpath(p, PROJETO))
    print("%d de %d arquivos %s" % (mudou, len(lista), "mudariam" if so_verificar else "mudaram"))
    return 1 if (so_verificar and mudou) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
