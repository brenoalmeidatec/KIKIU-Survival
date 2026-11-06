"""Inventário do que a v2 usa e o Godot 3 do Vita (godot-vita 3.5-rc5, GLES2) não tem ou faz diferente.

Só lê arquivos (não roda Godot, não muda nada). Rode da raiz do repositório:
    python jogos/hordas-vita-v2/inventario.py            # tabela no terminal
    python jogos/hordas-vita-v2/inventario.py --md       # a mesma tabela em Markdown (para colar no LEIAME ou numa issue)

Cada linha é um padrão de risco, quantos arquivos e quantas ocorrências da v2 (jogos/hordas/projeto/v2) usam, e o que fazer
(a coluna "caminho" resume a seção correspondente do LEIAME.md). Rodar de novo depois de cada marco da v2 mostra se o port
ficou mais caro ou mais barato.
"""

import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
V2 = RAIZ / "jogos" / "hordas" / "projeto" / "v2"

# (nome, regex, caminho): a regex roda linha a linha nos .gd e .gdshader da v2, fora de comentário
PADROES = [
    ("await", r"\bawait\b", "vira yield; poucos na v2, à mão"),
    ("lambda func(", r"func\(", "conversor/lambdas.py da v1: vira método + funcref"),
    ("@export/@onready", r"@(export|onready)\b", "conversor: export/onready do GDScript 1"),
    ("Packed*Array", r"\bPacked(Float32|Float64|Int32|Int64|Byte|Vector2|Color|String)Array\b", "Pool*Array; Float64 vira Array (bug de precisão já visto na v1)"),
    ("Light2D / PointLight2D", r"\b(Point|Directional)?Light2D\b", "GLES2 desenha luz em várias passadas: luz BUFFER do piloto"),
    ("CanvasTexture (normal map)", r"\bCanvasTexture\b", "não existe no 3.x: normal_map no Sprite, ou só albedo no Vita"),
    ("shader", r"shader_type|ShaderMaterial|\.gdshader", "reescrever em GLES2 (sem array uniform, sem hint_screen_texture)"),
    ("SubViewport", r"\bSubViewport\b", "Viewport no 3.x; cada um custa fill-rate"),
    ("MultiMesh", r"\bMultiMesh", "existe no 3.x; conferir cor por instância"),
    ("y_sort_enabled", r"y_sort_enabled", "YSort é nó no 3.x, não propriedade"),
    ("create_tween", r"create_tween\(", "Tween é nó no 3.x (ponte G4 da v1)"),
    ("rede (@rpc/ENet)", r"@rpc|ENetMultiplayerPeer", "fora do Vita (sem online)"),
    ("FileAccess/DirAccess", r"\b(FileAccess|DirAccess)\.", "File/Directory no 3.x (ponte G4)"),
    ("Time.get_ticks", r"Time\.get_ticks", "OS.get_ticks_* no 3.x"),
]


def contar():
    arquivos = sorted(list(V2.glob("*.gd")) + list(V2.glob("*.gdshader")))
    total = 0
    por_arquivo = {}
    texto = {}
    for a in arquivos:
        t = a.read_text(encoding="utf-8", errors="replace").splitlines()
        texto[a] = [l for l in t if not l.lstrip().startswith("#")]
        total += len(t)
        por_arquivo[a.name] = len(t)
    linhas = []
    for nome, rx, caminho in PADROES:
        r = re.compile(rx)
        n_arq = n_oc = 0
        for t in texto.values():
            k = sum(len(r.findall(l)) for l in t)
            if k:
                n_arq += 1
                n_oc += k
        linhas.append((nome, n_arq, n_oc, caminho))
    maiores = sorted(por_arquivo.items(), key=lambda x: -x[1])[:8]
    return len(arquivos), total, linhas, maiores


def main():
    n, total, linhas, maiores = contar()
    if "--md" in sys.argv:
        print(f"v2: **{n} arquivos**, **{total} linhas** (.gd e .gdshader em `jogos/hordas/projeto/v2`)\n")
        print("| padrão | arquivos | ocorrências | caminho |")
        print("|---|---|---|---|")
        for nome, a, o, c in linhas:
            print(f"| {nome} | {a} | {o} | {c} |")
        print("\nMaiores scripts: " + ", ".join(f"`{k}` ({v})" for k, v in maiores))
        return
    print(f"v2: {n} arquivos, {total} linhas")
    for nome, a, o, c in linhas:
        print(f"{nome:28s} {a:4d} arq {o:6d} oc   {c}")
    print("maiores:", ", ".join(f"{k} ({v})" for k, v in maiores))


if __name__ == "__main__":
    main()
