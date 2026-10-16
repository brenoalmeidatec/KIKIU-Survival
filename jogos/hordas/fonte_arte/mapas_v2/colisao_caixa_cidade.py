"""Reescreve SÓ o campo "colisao" dos objetos retangulares da cidade em projeto/assets/v2/mapas/cidade/cenario.json (caixa w x d em vez da elipse).

Os brutos do Blender não estão no repositório, então o gerador (gerar_v2_mapas.py) não roda inteiro aqui; este script faz a mesma conta de
formas_colisao para os itens marcados com "forma": "retangulo" em def_cidade.py e deixa o resto do JSON como está.
Uso: python3 -I jogos/hordas/fonte_arte/mapas_v2/colisao_caixa_cidade.py
"""
import json
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
import def_cidade  # noqa: E402

CENARIO = AQUI.parents[1] / "projeto" / "assets" / "v2" / "mapas" / "cidade" / "cenario.json"
PY = 11.315  # px de fundo por metro (metade de 22,63)


def caixa(cfg):
    """A mesma conta de gerar_v2_mapas.formas_colisao para forma 'retangulo'."""
    folga = cfg.get("folga", 1.0)
    return [{"tipo": "caixa", "centro": [0.0, round(-cfg["d"] * PY, 1)], "meio": [round(cfg["w"] * 16.0 * folga, 1), round(cfg["d"] * PY * folga, 1)]}]


def main():
    cen = json.loads(CENARIO.read_text(encoding="utf-8"))
    n = 0
    for it in cen["itens"]:
        cfg = def_cidade.OBJETOS.get(it["nome"], {})
        if cfg.get("col") == "caixa" and cfg.get("forma") == "retangulo":
            it["colisao"] = caixa(cfg)
            n += 1
            print("%-20s %s" % (it["nome"], it["colisao"][0]))
    CENARIO.write_text(json.dumps(cen, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("%d itens reescritos" % n)


if __name__ == "__main__":
    main()
