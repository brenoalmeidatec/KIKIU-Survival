#!/usr/bin/env python3
"""Roda o jogo convertido no Godot 3 (PC) por alguns segundos, salva uma foto e agrupa os erros de execução.

    python rodar.py <godot3.exe> <projeto_gerado> [segundos=8] [args extras do jogo...]

A foto vai para user://g4_foto.png (o caminho é impresso). Os erros saem agrupados por mensagem + local.
"""
import collections
import re
import subprocess
import sys

godot, proj = sys.argv[1], sys.argv[2]
seg = float(sys.argv[3]) if len(sys.argv) > 3 else 8.0
extras = sys.argv[4:]
cmd = [godot, "--path", proj, "--g4-foto=%g" % (seg - 1.5), "--g4-sair=%g" % seg] + extras
try:
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=seg + 60, encoding="utf-8", errors="replace")
    out = r.stdout + "\n" + r.stderr
except subprocess.TimeoutExpired as e:
    out = (e.stdout or "") + "\n" + (e.stderr or "") + "\n(TIMEOUT)"
erros = collections.Counter()
exemplo = {}
linhas = out.split("\n")
for i, l in enumerate(linhas):
    if l.startswith("SCRIPT ERROR:") or l.startswith("ERROR:"):
        onde = linhas[i + 1].strip() if i + 1 < len(linhas) else ""
        chave = (l.strip()[:150], onde[:110])
        erros[chave] += 1
print("%d erros distintos (%d no total)" % (len(erros), sum(erros.values())))
for (msg, onde), n in erros.most_common(25):
    print("%5d  %s\n       %s" % (n, msg, onde))
for l in linhas:
    if "G4: foto" in l or "TIMEOUT" in l:
        print(l)
