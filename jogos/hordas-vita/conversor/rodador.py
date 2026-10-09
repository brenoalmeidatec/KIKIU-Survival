"""Monta a linha de comando do Godot para os scripts de teste. `godot` = caminho do .exe do Windows (sem o módulo C++)
ou a palavra `x11` = motor Linux com o módulo, rodando na distro WSL `vita-build` (caminhos E:/... viram /mnt/e/...)."""
import os
import re
import sys


def _wsl(a):
    m = re.match(r"^([A-Za-z]):[\/](.*)$", a)
    return "/mnt/%s/%s" % (m.group(1).lower(), m.group(2).replace("\\", "/")) if m else a


def comando(godot, args):
    """args: lista de argumentos do Godot (sem o executável)."""
    if godot == "x11":
        args = [_wsl(a) for a in args]
        interno = "export DISPLAY=:0; exec ~/godot-vita/bin/godot.x11.opt.debug.64 " + " ".join("'%s'" % a for a in args)
        return ["wsl.exe", "-d", "vita-build", "-u", "vita", "--", "bash", "-c", interno]
    return [godot] + list(args)


def texto(b):
    return b.replace("\x00", "") if isinstance(b, str) else b
