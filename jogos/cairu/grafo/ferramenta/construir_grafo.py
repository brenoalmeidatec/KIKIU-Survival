"""Gera o grafo do JOGO com o Graphify (github.com/Graphify-Labs/graphify, pacote graphifyy).

Copia só o código-fonte e os capítulos para uma pasta temporária (não toca no
jogo), roda a extração AST do Graphify (Python), o extrator próprio do jogo
(GDScript + cenas/mapas, extrair_jogo.py) e grava tudo em jogo/grafo/.

Uso: python3 construir_grafo.py   (precisa de: pip install graphifyy)
"""
import json, shutil, subprocess, sys, tempfile
from collections import Counter
from pathlib import Path

JOGO = Path("/mnt/project-files/jogo")
SAIDA = Path(sys.argv[1]) if len(sys.argv) > 1 else JOGO / "grafo"
AQUI = Path(__file__).resolve().parent

from graphify.detect import detect
from graphify.extract import collect_files, extract
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from graphify.export import to_json

tmp = Path(tempfile.mkdtemp(prefix="grafo_jogo_")) / "jogo"
for pasta in ("scripts", "minijogos", "capitulos"):
    shutil.copytree(JOGO / "projeto" / pasta, tmp / pasta,
                    ignore=shutil.ignore_patterns("*.png", "*.import", "*.uid", "*.ogg", "*.wav", "*.ttf"))
for f in ("project.godot", "main.tscn"):
    shutil.copy(JOGO / "projeto" / f, tmp / f)
for pasta in ("fonte_mapas", "fonte_audio"):
    (tmp / pasta).mkdir()
    for f in (JOGO / pasta).glob("*.py"):
        shutil.copy(f, tmp / pasta / f.name)
out = tmp / "graphify-out"
out.mkdir()

det = detect(tmp)
code = []
for f in det.get("files", {}).get("code", []):
    code.extend(collect_files(Path(f)) if Path(f).is_dir() else [Path(f)])
ast = extract(code, cache_root=tmp) if code else {"nodes": [], "edges": []}
subprocess.run([sys.executable, str(AQUI / "extrair_jogo.py"), str(tmp), str(out / "jogo.json")], check=True)
extra = json.loads((out / "jogo.json").read_text(encoding="utf-8"))

seen = {n["id"] for n in ast["nodes"]}
nodes = list(ast["nodes"]) + [n for n in extra["nodes"] if n["id"] not in seen]
ext = {"nodes": nodes, "edges": ast["edges"] + extra["edges"], "hyperedges": [],
       "input_tokens": 0, "output_tokens": 0}

G = build_from_json(ext, root=str(tmp), directed=True)
comms = cluster(G)
coh = score_all(G, comms)

# Nome de cada comunidade: as pastas/arquivos que mais aparecem nela + o nó mais ligado.
labels = {}
for cid, membros in comms.items():
    arqs = Counter(Path(G.nodes[m].get("source_file") or "").stem for m in membros if G.nodes[m].get("source_file"))
    top = max(membros, key=lambda m: G.degree(m))
    base = " + ".join(a for a, _ in arqs.most_common(2)) or "conceitos"
    labels[cid] = f"{base} ({G.nodes[top].get('label', top)})"

gods = god_nodes(G)
surp = surprising_connections(G, comms)
perg = suggest_questions(G, comms, labels)

if SAIDA.exists():
    for f in ("graph.json", "GRAPH_REPORT.md", "graph.html"):
        (SAIDA / f).unlink(missing_ok=True)
SAIDA.mkdir(exist_ok=True)
to_json(G, comms, str(out / "graph.json"), community_labels=labels)
rep = generate(G, comms, coh, labels, gods, surp, det, {"input": 0, "output": 0}, "jogo", suggested_questions=perg)
(out / "GRAPH_REPORT.md").write_text(rep, encoding="utf-8")
(out / ".graphify_labels.json").write_text(json.dumps({str(k): v for k, v in labels.items()}, ensure_ascii=False), encoding="utf-8")
subprocess.run(["graphify", "export", "html", "--graph", str(out / "graph.json"),
                "--labels", str(out / ".graphify_labels.json")], cwd=tmp, check=True,
               stdout=subprocess.DEVNULL)
for f in ("graph.json", "GRAPH_REPORT.md", "graph.html"):
    if (out / f).exists():
        shutil.copy(out / f, SAIDA / f)
shutil.rmtree(tmp.parent)
print(f"grafo: {G.number_of_nodes()} nós, {G.number_of_edges()} arestas, {len(comms)} comunidades -> {SAIDA}")
