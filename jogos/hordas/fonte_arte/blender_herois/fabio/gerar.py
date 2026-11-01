"""Gera os quadros do FABIAN (Blender 4.5): o mesmo rig e a mesma câmera do Hazaki (../hazaki/gerar.py), com o modelo, as cores e o ARCO
(YUMI) do perfil.py desta pasta. Só o combo é próprio (anim_combo.py: os tiros); as outras animações são as do Hazaki, com o arco na mão.

    blender -b -t 6 -P gerar.py                       # todas as animações: quadros/<anim>/... e fabio_rig.blend
    blender -b -t 6 -P gerar.py -- --anim=combo       # só uma
"""
import runpy
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
if "--" not in sys.argv:
    sys.argv.append("--")
sys.argv.append("--perfil=" + str(AQUI / "perfil.py"))
runpy.run_path(str(AQUI.parent / "hazaki" / "gerar.py"), run_name="__main__")
