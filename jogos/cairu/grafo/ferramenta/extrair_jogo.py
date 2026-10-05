"""Extrator extra para o Graphify: GDScript (Godot) e o conteúdo dos capítulos.

O Graphify não tem parser de GDScript nem entende o formato das cenas do jogo,
então este script gera nós e arestas no mesmo formato da extração AST dele:
  - .gd: arquivo, class_name, extends, funções, sinais, preload/load,
    chamadas (mesmo arquivo = EXTRACTED; Alias.func / var tipada = EXTRACTED;
    nome único em outro arquivo = INFERRED), connect() de sinais.
  - capitulos/*.json, *.txt e mapas/*.json: capítulos, cenas, NPCs, mapas,
    portas entre mapas, pontos e gatilhos que abrem cenas, requer (viu_x),
    !minijogo, !se, !cena e personagens usados em cada cena.

Uso: python3 extrair_jogo.py <pasta_fonte> <saida.json>
"""
import json, re, sys
from pathlib import Path

RAIZ = Path(sys.argv[1]).resolve()
nodes, edges, ids = [], [], set()


def nid(*partes):
    return "_".join(re.sub(r"[^0-9a-zA-Z]+", "_", p).strip("_").lower() for p in partes)


def no(i, label, arq, linha=None, tipo="code", **extra):
    if i in ids:
        return i
    ids.add(i)
    d = {"id": i, "label": label, "file_type": tipo, "source_file": arq, "_origin": "jogo"}
    if linha:
        d["source_location"] = f"L{linha}"
    d.update(extra)
    nodes.append(d)
    return i


def aresta(a, b, rel, arq, linha=None, conf="EXTRACTED", score=1.0):
    if a == b:
        return
    e = {"source": a, "target": b, "relation": rel, "confidence": conf,
         "confidence_score": score, "source_file": arq, "weight": 1.0, "_origin": "jogo"}
    if linha:
        e["source_location"] = f"L{linha}"
    edges.append(e)


def rel(p):
    return str(p.relative_to(RAIZ)).replace("\\", "/")


def no_arquivo(caminho_rel):
    """Nó de arquivo com o mesmo id que o Graphify usa (pasta_arquivo sem extensão)."""
    p = Path(caminho_rel)
    return no(nid(str(p.with_suffix(""))), p.name, caminho_rel)


# ---------------------------------------------------------------- GDScript
RE_FUNC = re.compile(r"^(static\s+)?func\s+(\w+)\s*\(")
RE_SIG = re.compile(r"^signal\s+(\w+)")
RE_CLASS = re.compile(r"^class_name\s+(\w+)")
RE_EXT = re.compile(r'^extends\s+("res://[^"]+"|\w+)')
RE_RES = re.compile(r'"(res://[^"]+)"')
RE_ALIAS = re.compile(r"^\s*(?:const|var)\s+(\w+)\s*:?=\s*(?:pre)?load\(\"(res://[^\"]+\.gd)\"\)")
RE_VAR_TIPO = re.compile(r"\bvar\s+(\w+)\s*(?::\s*(\w+)|:?=\s*(\w+)\.new\()")
RE_CALL_OBJ = re.compile(r"\b(\w+)\.(\w+)\s*\(")
RE_CALL = re.compile(r"(?<![\.\w])(\w+)\s*\(")
RE_CONNECT = re.compile(r"\b(\w+)\.connect\(\s*(\w+)")
PALAVRAS = {"if", "elif", "while", "for", "match", "return", "func", "print", "len", "range",
            "str", "int", "float", "bool", "Vector2", "Color", "Rect2", "Array", "Dictionary",
            "await", "assert", "preload", "load", "super", "abs", "min", "max", "clamp", "lerp",
            "randf", "randi", "is_instance_valid", "push_error", "push_warning", "typeof"}

gds = sorted(RAIZ.rglob("*.gd"))
info = {}
for p in gds:
    r = rel(p)
    linhas = p.read_text(encoding="utf-8", errors="replace").splitlines()
    info[r] = {"linhas": linhas, "funcs": {}, "alias": {}, "vars": {}}
    fid = no_arquivo(r)
    info[r]["id"] = fid
    for n, l in enumerate(linhas, 1):
        if m := RE_FUNC.match(l):
            f = m.group(2)
            info[r]["funcs"][f] = no(f"{fid}_{f.lower()}", f"{f}()", r, n, _callable=True)
            aresta(fid, info[r]["funcs"][f], "contains", r, n)
        elif m := RE_SIG.match(l):
            s = no(f"{fid}_sinal_{m.group(1).lower()}", f"sinal {m.group(1)}", r, n)
            aresta(fid, s, "contains", r, n)
        elif m := RE_CLASS.match(l):
            info[r]["classe"] = m.group(1)

classes = {v["classe"]: r for r, v in info.items() if "classe" in v}
por_nome = {}
for r, v in info.items():
    for f in v["funcs"]:
        por_nome.setdefault(f, []).append(r)

for r, v in info.items():
    fid = v["id"]
    atual = fid
    for n, l in enumerate(v["linhas"], 1):
        if m := RE_ALIAS.match(l):
            v["alias"][m.group(1)] = m.group(2)[6:]
        if m := RE_VAR_TIPO.search(l):
            t = m.group(2) or m.group(3)
            if t:
                v["vars"][m.group(1)] = t
    for n, l in enumerate(v["linhas"], 1):
        cod = l.split("#", 1)[0]
        if m := RE_FUNC.match(l):
            atual = v["funcs"][m.group(2)]
            continue
        if not l.startswith(("\t", " ")) and cod.strip() and not l.startswith(("func", "static")):
            atual = fid
        if m := RE_EXT.match(l):
            alvo = m.group(1)
            if alvo.startswith('"'):
                aresta(fid, no_arquivo(alvo.strip('"')[6:]), "inherits", r, n)
            elif alvo in classes:
                aresta(fid, info[classes[alvo]]["id"], "inherits", r, n)
            else:
                b = no(nid("godot", alvo), alvo, "", tipo="concept")
                aresta(fid, b, "inherits", r, n)
        for res in RE_RES.findall(cod):
            alvo = res[6:]
            if (RAIZ / alvo).exists() and alvo.endswith((".gd", ".json", ".txt", ".tscn")):
                aresta(atual, no_arquivo(alvo), "imports" if alvo.endswith(".gd") else "references", r, n)
        objs = set()
        for m in RE_CALL_OBJ.finditer(cod):
            obj, f = m.group(1), m.group(2)
            objs.add(m.start(2))
            alvo_arq = None
            if obj in v["alias"]:
                alvo_arq = v["alias"][obj]
            elif obj in classes:
                alvo_arq = classes[obj]
            elif obj in v["vars"]:
                t = v["vars"][obj]
                alvo_arq = v["alias"].get(t) or classes.get(t)
            if alvo_arq and alvo_arq in info:
                if f in info[alvo_arq]["funcs"]:
                    aresta(atual, info[alvo_arq]["funcs"][f], "calls", r, n)
                elif f == "new":
                    aresta(atual, info[alvo_arq]["id"], "instantiates", r, n)
            elif f in por_nome and f not in v["funcs"] and len(por_nome[f]) == 1 and not f.startswith("_"):
                aresta(atual, info[por_nome[f][0]]["funcs"][f], "calls", r, n, "INFERRED", 0.6)
        for m in RE_CALL.finditer(cod):
            f = m.group(1)
            if f in PALAVRAS or m.start(1) in objs:
                continue
            if f in v["funcs"]:
                aresta(atual, v["funcs"][f], "calls", r, n)
        for m in RE_CONNECT.finditer(cod):
            if m.group(2) in v["funcs"]:
                aresta(atual, v["funcs"][m.group(2)], "connects_signal", r, n)

# minijogos registrados (nome -> script)
for r, v in info.items():
    for n, l in enumerate(v["linhas"], 1):
        if m := re.match(r'\s*"(\w+)":\s*"res://(minijogos/\w+\.gd)"', l):
            mj = no(nid("minijogo", m.group(1)), f"minijogo {m.group(1)}", r, n, tipo="concept")
            aresta(mj, no_arquivo(m.group(2)), "implemented_by", r, n)

# ---------------------------------------------------------------- capítulos
cenas_def = {}


def cena(cid, arq, linha=None):
    i = nid("cena", cid)
    no(i, f"cena {cid}", arq, linha, tipo="concept")
    return i


def personagem(p):
    return no(nid("personagem", p), f"personagem {p}", "", tipo="concept")


def mapa(m):
    arq = f"capitulos/mapas/{m}.json"
    return no(nid("mapa", m), f"mapa {m}", arq if (RAIZ / arq).exists() else "", tipo="concept")


def passos(cid, lista, arq, base_linha=None):
    c = nid("cena", cid)
    for k, p in enumerate(lista):
        if not isinstance(p, str):
            continue
        ln = base_linha + k if base_linha else None
        t = p.split()
        if not t:
            continue
        cmd = t[0]
        if cmd == "!minijogo" and len(t) > 1:
            aresta(c, no(nid("minijogo", t[1]), f"minijogo {t[1]}", arq, ln, tipo="concept"), "plays_minigame", arq, ln)
        elif cmd == "!se":
            for alvo in re.findall(r"(?:->|\|)\s*(\w+)", p):
                aresta(c, cena(alvo, arq), "branches_to", arq, ln)
        elif cmd in ("!cena",) and len(t) > 1:
            aresta(c, cena(t[1], arq), "plays_scene", arq, ln)
        elif cmd == "!mapa" and len(t) > 1:
            aresta(c, mapa(t[1]), "moves_to_map", arq, ln)
        elif cmd in ("!aparecer", "!anim", "!virar", "!andar", "!entrar", "!sair", "!camera", "!balao", "!rosto", "!lateral") and len(t) > 1 \
                and re.fullmatch(r"[a-z]+", t[1]) and t[1] not in ("eu", "sim", "nao"):
            aresta(c, personagem(t[1]), "features", arq, ln, "INFERRED", 0.8)
        elif cmd.startswith(">") or not cmd.startswith("!"):
            pass


def requer(cid, lst, arq, ln=None):
    for r in lst or []:
        r = r.strip()
        if r.startswith("viu_"):
            aresta(nid("cena", cid), cena(r[4:], arq), "requires", arq, ln)


capdir = RAIZ / "capitulos"
for jf in sorted(capdir.glob("*.json")):
    d = json.loads(jf.read_text(encoding="utf-8"))
    arq = rel(jf)
    if not isinstance(d, dict) or "cenas" not in d:
        continue
    cap = no(nid("capitulo", jf.stem), f"capítulo {d.get('titulo', jf.stem)}", arq, tipo="concept")
    aresta(cap, no_arquivo(arq), "defined_in", arq)
    if d.get("mapa_inicial"):
        aresta(cap, mapa(d["mapa_inicial"]), "starts_in", arq)
    if d.get("abertura"):
        aresta(cap, cena(d["abertura"], arq), "opens_with", arq)
    for cid, v in d["cenas"].items():
        c = cena(cid, arq)
        aresta(cap, c, "contains", arq)
        if isinstance(v, dict):
            requer(cid, v.get("requer"), arq)
            passos(cid, v.get("passos", []), arq)
    for npc in d.get("npcs", []):
        p = personagem(npc["personagem"])
        if npc.get("mapa"):
            aresta(p, mapa(npc["mapa"]), "located_in", arq)
        for cid in npc.get("cenas", []) + ([npc["cena"]] if npc.get("cena") else []):
            aresta(p, cena(cid, arq), "talk_opens", arq)
    for g in d.get("gatilhos", []):
        for cid in g.get("cenas", []) + ([g["cena"]] if g.get("cena") else []):
            alvo = mapa(g["mapa"]) if g.get("mapa") else cap
            aresta(alvo, cena(cid, arq), "trigger_opens", arq)

for tf in sorted(capdir.glob("*.txt")):
    arq = rel(tf)
    if tf.name.startswith("MODELO"):
        continue
    cap = nid("capitulo", tf.stem)
    if cap not in ids:
        no(cap, f"capítulo {tf.stem}", arq, tipo="concept")
    aresta(cap, no_arquivo(arq), "defined_in", arq)
    atual, bloco, ini = None, [], 0
    linhas = tf.read_text(encoding="utf-8").splitlines() + ["=== __fim__"]
    for n, l in enumerate(linhas, 1):
        if l.startswith("==="):
            if atual:
                passos(atual, bloco, arq, ini)
            partes = [x.strip() for x in l[3:].split("|")]
            atual, bloco, ini = partes[0], [], n + 1
            if atual == "__fim__":
                break
            aresta(cap, cena(atual, arq, n), "contains", arq, n)
            for x in partes[1:]:
                if x.startswith("requer:"):
                    requer(atual, x[7:].split(), arq, n)
        elif atual:
            bloco.append(l.strip())

for mf in sorted((capdir / "mapas").glob("*.json")):
    d = json.loads(mf.read_text(encoding="utf-8"))
    arq = rel(mf)
    m = mapa(mf.stem)
    aresta(m, no_arquivo(arq), "defined_in", arq)
    for porta in d.get("portas", []):
        if porta.get("para"):
            aresta(m, mapa(porta["para"]), "door_to", arq)
    for ponto in d.get("pontos", []):
        for cid in ponto.get("cenas", []) + ([ponto["cena"]] if ponto.get("cena") else []):
            aresta(m, cena(cid, arq), "point_opens", arq)

# arquivos .json/.txt que o Graphify não indexou precisam de nó próprio
for e in edges:
    for k in ("source", "target"):
        assert e[k] in ids, e

Path(sys.argv[2]).write_text(json.dumps({"nodes": nodes, "edges": edges, "hyperedges": [],
                                         "input_tokens": 0, "output_tokens": 0}, ensure_ascii=False, indent=1),
                             encoding="utf-8")
print(f"extrator do jogo: {len(nodes)} nós, {len(edges)} arestas")
