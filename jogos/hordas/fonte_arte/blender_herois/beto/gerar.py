"""Gera os quadros do BERT (KUSARIGAMA, Blender 4.5): o framework do Hazaki (../hazaki/gerar.py: rig, câmera, luz, contorno, normal e as
animações anim_*.py), com o modelo, as cores e a foice do perfil.py desta pasta.

    blender -b -t 6 -P gerar.py                       # todas as animações: quadros/<anim>/... e beto_rig.blend
    blender -b -t 6 -P gerar.py -- --anim=andar       # só uma
"""
import runpy
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
if "--" not in sys.argv:
    sys.argv.append("--")
sys.argv.append("--perfil=" + str(AQUI / "perfil.py"))
runpy.run_path(str(AQUI.parent / "hazaki" / "gerar.py"), run_name="__main__")
