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
    "Pelo": "#c9d9ee", "Pelo sombra": "#8ea8cc", "Orelha interna": "#a995bd", "Nariz escuro": "#1d2c4a",
    "Traje azul": "#4a82c4", "Traje claro": "#6aa0e0", "Traje escuro": "#2a4a7c", "Armadura branca": "#c4d4e6",
    "Couro escuro": "#222c46", "Arma branca": "#d0dceb", "Arma cabo": "#222c46",
}
BRILHANTES_LOBO = {"Ciano brilho": "#7ff3ff", "Olho ciano": "#59e6ff"}


def trocar(src, a, b):
    assert src.count(a) == 1, "trecho nao encontrado (o gerar.py do Luke mudou?): " + a
    return src.replace(a, b)


src = LUCAS.read_text(encoding="utf-8")
src = trocar(src, 'SAIDA = AQUI / "quadros"', 'SAIDA = Path(r"%s") / "quadros"' % (AQUI,))
src = trocar(src, "import modelo  # noqa: E402", "import modelo_lobo as modelo  # noqa: E402")
src = trocar(src, "BRILHANTES = {}", "PALETA = %r\nBRILHANTES = %r" % (PALETA_LOBO, BRILHANTES_LOBO))
src = trocar(src, 'CABECA_PREF = ("Cabeça",', 'CABECA_PREF = ("Orelha", "Focinho", "Nariz do lobo", "Cabeça",')
src = trocar(src, "CABECA = 1.32", "CABECA = 1.18")
src = trocar(src, 'str(AQUI / "lucas_rig.blend")', 'r"%s"' % (AQUI / "lobo_rig.blend"))
exec(compile(src, str(LUCAS), "exec"), {"__name__": "__main__", "__file__": str(LUCAS)})
