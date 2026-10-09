#!/usr/bin/env python3
"""Acompanhe o painel ao vivo do Claude (branch painel-ao-vivo do repositório). Precisa só de Python 3 e git
(com acesso ao repositório). Uso:  python seguir.py            (abre o painel e atualiza a cada ~15 s; Ctrl+C sai)
Cria uma pasta ./kikiu-painel com a vitrine; não mexe no seu clone do jogo."""
import os, subprocess, sys, time, webbrowser
URL = "https://github.com/brenoalmeidatec/KIKIU-Survival.git"
PASTA = os.path.join(os.getcwd(), "kikiu-painel")
BRANCH = "painel-ao-vivo"


def git(*a, cwd=None):
    return subprocess.run(["git", *a], cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")


if not os.path.isdir(os.path.join(PASTA, ".git")):
    print("baixando o painel (1ª vez)...")
    r = git("clone", "--quiet", "--depth", "1", "--branch", BRANCH, "--single-branch", URL, PASTA)
    if r.returncode != 0:
        sys.exit("não consegui baixar: " + (r.stderr or r.stdout)[:300] + "\n(o Claude já publicou? você tem acesso ao repositório?)")
arq = os.path.join(PASTA, "painel.html")
webbrowser.open("file:///" + arq.replace("\\", "/"))
print("painel aberto. Atualizando a cada 15 s (Ctrl+C para sair).")
while True:
    try:
        git("fetch", "--quiet", "--depth", "1", "origin", BRANCH, cwd=PASTA)
        git("reset", "--quiet", "--hard", "FETCH_HEAD", cwd=PASTA)
    except KeyboardInterrupt:
        break
    except Exception as e:
        print("erro:", e)
    try:
        time.sleep(15)
    except KeyboardInterrupt:
        break
