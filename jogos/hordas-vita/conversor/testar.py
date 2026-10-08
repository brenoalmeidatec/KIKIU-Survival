#!/usr/bin/env python3
"""Roda as cenas de teste do jogo (testes/*.tscn) no projeto convertido, no Godot 3, e junta os resultados.

    python testar.py <godot3.exe> <projeto_gerado> [filtro]

Cada teste imprime "NOME falhas=N". Grava testes.json no projeto. Um teste que não imprime falhas= (erro, travou)
aparece como "SEM RESULTADO" com os primeiros erros.
"""
import json
import os
import re
import subprocess
import sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from concurrent.futures import ThreadPoolExecutor

godot, proj = sys.argv[1], sys.argv[2]
filtro = sys.argv[3] if len(sys.argv) > 3 else ""
cenas = sorted(a for a in os.listdir(os.path.join(proj, "testes")) if a.endswith(".tscn") and filtro in a)


def rodar(cena):
    try:
        r = subprocess.run([godot, "--no-window", "--path", proj, "res://testes/" + cena], capture_output=True,
                           text=True, timeout=240, encoding="utf-8", errors="replace")
        out = r.stdout + "\n" + r.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or "") + "\n" + (e.stderr or "") + "\nTIMEOUT"
    m = re.findall(r"falhas=(\d+)", out)
    erros = []
    linhas = out.split("\n")
    for i, l in enumerate(linhas):
        if l.startswith("SCRIPT ERROR") or l.startswith("FALHOU"):
            onde = linhas[i + 1].strip() if i + 1 < len(linhas) and l.startswith("SCRIPT") else ""
            erros.append((l.strip() + " " + onde)[:200])
    return cena, {"falhas": int(m[-1]) if m else None, "erros": erros[:6], "timeout": "TIMEOUT" in out}


with ThreadPoolExecutor(6) as ex:
    res = dict(ex.map(rodar, cenas))
json.dump(res, open(os.path.join(proj, "testes.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
ok = [c for c, v in res.items() if v["falhas"] == 0 and not v["erros"]]
print("%d/%d testes passam (falhas=0 e sem erro de script)" % (len(ok), len(res)))
for c, v in sorted(res.items()):
    if c in ok:
        continue
    estado = "SEM RESULTADO" + (" (timeout)" if v["timeout"] else "") if v["falhas"] is None else "falhas=%d" % v["falhas"]
    print("- %-28s %s" % (c, estado))
    for e in v["erros"][:3]:
        print("      " + e)
