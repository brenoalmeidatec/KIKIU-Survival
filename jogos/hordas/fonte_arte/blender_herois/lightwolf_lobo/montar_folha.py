"""Monta a folha do LOBO (lightwolf_lobo_{albedo,normal}.png + .json + previa x4) com o montar_folha.py do Luke, so trocando a pasta e o nome.

    python montar_folha.py
"""
from pathlib import Path

AQUI = Path(__file__).resolve().parent
LUCAS = AQUI.parent / "lucas" / "montar_folha.py"
src = LUCAS.read_text(encoding="utf-8")
a = "AQUI = os.path.dirname(os.path.abspath(__file__))"
assert src.count(a) == 1
src = src.replace(a, "AQUI = r'%s'" % AQUI).replace("lucas_final", "lightwolf_lobo")
exec(compile(src, str(LUCAS), "exec"), {"__name__": "__main__", "__file__": str(LUCAS)})
