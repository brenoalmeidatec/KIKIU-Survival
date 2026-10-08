#!/usr/bin/env python3
"""Carrega todos os scripts do projeto gerado no Godot 3 (com autoloads ativos) e agrupa os erros de parse.

    python verificar.py <godot3.exe> <projeto_gerado>

Usa a cena _verificar.tscn (gerada pelo gerar.py). Grava verificacao.json no projeto.
"""
import collections
import json
import os
import re
import subprocess
import sys

godot, proj = sys.argv[1], sys.argv[2]
r = subprocess.run([godot, "--no-window", "--path", proj, "res://_verificar.tscn"], capture_output=True, text=True,
                   timeout=300, encoding="utf-8", errors="replace")
out = r.stdout + "\n" + r.stderr
estado = dict(re.findall(r"G4VERIFICA (res://\S+) (OK|ERRO)", out))
erros = {}
for m in re.finditer(r"SCRIPT ERROR: (?:Parse Error: )?(.*?)\n\s+at: GDScript::reload \((res://[^:]+):(\d+)\)", out):
    if "Couldn't fully preload" in m.group(1) or "Couldn't load" in m.group(1):
        continue
    onde = "%s:%s" % (m.group(2), m.group(3))
    if onde in erros:
        continue
    try:
        txt = open(os.path.join(proj, m.group(2)[6:]), encoding="utf-8").read().split("\n")[int(m.group(3)) - 1].strip()
    except Exception:
        txt = ""
    erros[onde] = {"erro": m.group(1).strip(), "linha": txt[:150]}
json.dump({"estado": estado, "erros": erros}, open(os.path.join(proj, "verificacao.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
ok = sum(1 for v in estado.values() if v == "OK")
print("%d/%d scripts carregam no Godot 3%s" % (ok, len(estado), "" if "G4VERIFICA_FIM" in out else "  (a cena NAO terminou)"))
cont = collections.Counter(re.sub(r"'[^']*'|\"[^\"]*\"", "'_'", v["erro"]) for v in erros.values())
print("%d locais de erro de parse:" % len(erros))
for msg, n in cont.most_common(12):
    print("  %3d  %s" % (n, msg[:110]))
print()
for onde, v in sorted(erros.items())[:45]:
    print("%-40s %-50s | %s" % (onde.replace("res://scripts/hordas/", ""), v["erro"][:50], v["linha"][:85]))
if "G4VERIFICA_FIM" not in out:
    print("\n--- fim da saída ---\n" + "\n".join(out.strip().split("\n")[-15:]))
