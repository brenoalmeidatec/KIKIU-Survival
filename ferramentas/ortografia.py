#!/usr/bin/env python3
"""Confere a ortografia dos textos exibiveis de jogos/hordas/projeto/dados/*.json.

Uso:  python ferramentas/ortografia.py            (CI: usa o comando `hunspell -d pt_BR`)
      python ferramentas/ortografia.py --dic CAMINHO/pt_BR   (usa spylls, sem hunspell instalado)
      python ferramentas/ortografia.py --gerar-excecoes      (imprime as palavras desconhecidas)
Excecoes (nomes proprios, termos do jogo): ferramentas/ortografia_excecoes.txt, uma palavra por linha.
Sai com codigo 1 se sobrar palavra fora do dicionario e das excecoes.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DADOS = RAIZ / "jogos/hordas/projeto/dados"
EXC = Path(__file__).with_name("ortografia_excecoes.txt")
# chaves cujo valor e texto mostrado ao jogador
CHAVES = {"nome", "descricao", "desc", "texto", "titulo", "subtitulo", "curto", "dica", "rotulo",
          "causa", "info", "msg", "frase", "texto_entrega", "titulo_tomada",
          "pular_rotulo", "nome_dano"}
PALAVRA = re.compile(r"[^\W\d_]+(?:[-'][^\W\d_]+)*", re.UNICODE)


def textos(o, arq, caminho=""):
    if isinstance(o, dict):
        for k, v in o.items():
            if k.startswith("_"):
                continue
            if isinstance(v, str):
                if k in CHAVES:
                    yield arq, f"{caminho}/{k}", v
            else:
                yield from textos(v, arq, f"{caminho}/{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from textos(v, arq, f"{caminho}/{i}")


def limpar(t):
    return re.sub(r"\{[^}]*\}|\[/?[a-z_=#0-9 ]*\]|%[a-z0-9.]+", " ", t)  # {v}, BBCode, %d


def checador(dic):
    if dic:
        from spylls.hunspell import Dictionary
        d = Dictionary.from_files(dic)
        return lambda ps: {p for p in ps if not d.lookup(p)}

    def f(ps):
        r = subprocess.run(["hunspell", "-d", "pt_BR", "-l"], input="\n".join(sorted(ps)),
                           capture_output=True, text=True, encoding="utf-8", check=True)
        return set(r.stdout.split())
    return f


def main():
    dic = sys.argv[sys.argv.index("--dic") + 1] if "--dic" in sys.argv else None
    onde = {}
    for f in sorted(DADOS.glob("*.json")):
        for arq, cam, t in textos(json.loads(f.read_text(encoding="utf-8")), f.name):
            for p in PALAVRA.findall(limpar(t)):
                if len(p) > 1:
                    onde.setdefault(p, f"{arq}{cam}")
    exc = set()
    if EXC.exists():
        exc = {x.strip().lower() for x in EXC.read_text(encoding="utf-8").splitlines()
               if x.strip() and not x.startswith("#")}
    ruins = {p for p in checador(dic)(set(onde)) if p.lower() not in exc}
    if "--gerar-excecoes" in sys.argv:
        for p in sorted(ruins, key=str.lower):
            print(f"{p}\t{onde.get(p, "?")}")
        return 0
    for p in sorted(ruins, key=str.lower):
        print(f"ORTOGRAFIA: '{p}' em {onde.get(p, "?")}")
    print(f"{len(onde)} palavras distintas, {len(ruins)} fora do dicionario/excecoes")
    return 1 if ruins else 0


if __name__ == "__main__":
    sys.exit(main())
