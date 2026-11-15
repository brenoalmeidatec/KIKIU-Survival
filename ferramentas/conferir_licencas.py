#!/usr/bin/env python3
"""Confere os textos de licença que vão junto do jogo (jogos/hordas/projeto/licencas/).

Falha (código 1) se:
  - um arquivo listado no licencas/LEIA-ME.txt não existe ou está vazio;
  - um .txt da pasta não está listado no LEIA-ME.txt;
  - uma fonte de assets/fonte/ (.ttf, .otf) não tem o texto de licença dela na pasta;
  - algum preset do export_presets.cfg não inclui licencas/*.txt.
Com --pasta DIR, confere também que DIR (a pasta licencas copiada para um pacote) tem os mesmos arquivos, com o
mesmo conteúdo. Só biblioteca padrão. Uso: python3 -I ferramentas/conferir_licencas.py [--pasta DIR]
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PROJETO = RAIZ / "jogos" / "hordas" / "projeto"
LICENCAS = PROJETO / "licencas"
# fonte em assets/fonte/ -> arquivo de licença dela em licencas/
FONTES = {
    "jersey10/Jersey10-Regular.ttf": "fonte_jersey10_OFL.txt",
    "PressStart2P.ttf": "fonte_press_start_2p_OFL.txt",
    "atkinson/AtkinsonHyperlegible-Regular.ttf": "fonte_atkinson_hyperlegible_OFL.txt",
    "spleen/spleen-8x16.otf": "fonte_spleen_LICENSE.txt",
}


def listados() -> list:
    """Os nomes de arquivo do LEIA-ME.txt (a primeira palavra de cada linha que termina em .txt)."""
    nomes = []
    for linha in (LICENCAS / "LEIA-ME.txt").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^(\S+\.txt)\s", linha)
        if m:
            nomes.append(m.group(1))
    return nomes


def main() -> int:
    erros = []
    nomes = listados()
    if not nomes:
        erros.append("LEIA-ME.txt não lista nenhum arquivo")
    for n in nomes:
        f = LICENCAS / n
        if not f.is_file() or f.stat().st_size == 0:
            erros.append(f"listado no LEIA-ME.txt mas ausente ou vazio: licencas/{n}")
    for f in sorted(LICENCAS.glob("*.txt")):
        if f.name != "LEIA-ME.txt" and f.name not in nomes:
            erros.append(f"licencas/{f.name} não está no LEIA-ME.txt")
    fonte = PROJETO / "assets" / "fonte"
    for f in sorted(list(fonte.rglob("*.ttf")) + list(fonte.rglob("*.otf"))):
        rel = f.relative_to(fonte).as_posix()
        if rel not in FONTES:
            erros.append(f"fonte sem licença registrada aqui: assets/fonte/{rel} (acrescente em FONTES e em licencas/)")
        elif FONTES[rel] not in nomes:
            erros.append(f"a licença da fonte {rel} ({FONTES[rel]}) não está no LEIA-ME.txt")
    presets = (PROJETO / "export_presets.cfg").read_text(encoding="utf-8")
    filtros = re.findall(r'^include_filter="([^"]*)"', presets, re.M)
    if not filtros:
        erros.append("export_presets.cfg sem include_filter")
    for i, filtro in enumerate(filtros):
        if "licencas/*.txt" not in [x.strip() for x in filtro.split(",")]:
            erros.append(f"preset {i} do export_presets.cfg não inclui licencas/*.txt")
    if "--pasta" in sys.argv:
        destino = Path(sys.argv[sys.argv.index("--pasta") + 1])
        for f in sorted(LICENCAS.glob("*.txt")):
            g = destino / f.name
            if not g.is_file() or g.read_bytes() != f.read_bytes():
                erros.append(f"{g} ausente ou diferente de licencas/{f.name}")
    for e in erros:
        print("ERRO:", e)
    print(f"licencas: {len(nomes)} arquivos listados, {len(erros)} erros")
    return 1 if erros else 0


if __name__ == "__main__":
    sys.exit(main())
