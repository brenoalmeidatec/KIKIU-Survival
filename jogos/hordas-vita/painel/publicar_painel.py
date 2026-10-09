#!/usr/bin/env python3
"""Publica o painel ao vivo numa branch do GitHub (painel-ao-vivo), a cada ~20 s quando algo mudou.
A branch tem SEMPRE 1 commit (force-push): é só uma vitrine, não polui o histórico. Quem quer acompanhar roda
`python seguir.py` (está na própria branch). Para parar: crie o arquivo `parar.txt` ao lado deste script.
Uso: python publicar_painel.py <pasta_do_repo_git> [segundos=20]"""
import os, shutil, subprocess, sys, time
AQUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(sys.argv[1])
INTERVALO = float(sys.argv[2]) if len(sys.argv) > 2 else 20.0
PUB = os.path.join(os.path.dirname(AQUI), "painel-pub")
ARQS = ["painel.html", "status.js", "status.json", "seguir.py", "LEIAME_PAINEL.md"]
BRANCH = "painel-ao-vivo"


def git(*a, cwd=PUB, check=True):
    r = subprocess.run(["git", *a], cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        raise RuntimeError("git %s: %s" % (" ".join(a), (r.stderr or r.stdout).strip()[:300]))
    return r


def preparar():
    if not os.path.isdir(os.path.join(PUB, ".git")) and not os.path.exists(os.path.join(PUB, ".git")):
        git("worktree", "add", "--detach", PUB, "HEAD", cwd=REPO)
        git("checkout", "--orphan", BRANCH)
        git("rm", "-rf", "--quiet", ".", check=False)
        git("config", "user.name", "Claude do Alisson (PC)")
        git("config", "user.email", "noreply@anthropic.com")


def assinatura():
    return tuple((os.path.getmtime(os.path.join(AQUI, a)), os.path.getsize(os.path.join(AQUI, a)))
                 for a in ARQS if os.path.exists(os.path.join(AQUI, a)))


def publicar():
    for a in ARQS:
        if os.path.exists(os.path.join(AQUI, a)):
            shutil.copy2(os.path.join(AQUI, a), os.path.join(PUB, a))
    git("add", "-A")
    if git("diff", "--cached", "--quiet", check=False).returncode == 0:
        return False
    git("commit", "-q", "-m", "painel ao vivo (%s)" % time.strftime("%H:%M:%S"), "--amend" if _tem_commit() else "--no-edit-dummy") \
        if _tem_commit() else git("commit", "-q", "-m", "painel ao vivo (%s)" % time.strftime("%H:%M:%S"))
    git("push", "-q", "--force", "origin", "HEAD:refs/heads/" + BRANCH)
    return True


def _tem_commit():
    return git("rev-parse", "--verify", "HEAD", check=False).returncode == 0


def main():
    preparar()
    ultima = None
    erros = 0
    inicio = time.time()
    print("publicando em origin/%s a cada %.0f s (parar: crie parar.txt)" % (BRANCH, INTERVALO), flush=True)
    while not os.path.exists(os.path.join(AQUI, "parar.txt")) and time.time() - inicio < 12 * 3600:
        try:
            sig = assinatura()
            if sig != ultima:
                if publicar():
                    print(time.strftime("%H:%M:%S"), "publicado", flush=True)
                ultima = sig
                erros = 0
        except Exception as e:
            erros += 1
            print(time.strftime("%H:%M:%S"), "erro:", e, flush=True)
            if erros > 20:
                break
        time.sleep(INTERVALO)
    print("encerrado", flush=True)


main()
