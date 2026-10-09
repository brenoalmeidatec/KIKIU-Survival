#!/usr/bin/env python3
"""Quadro de status em tempo real dos agentes (lido pelo painel.html).
Uso: python status.py set <id> "<nome>" <modelo> <estado> "<o que está fazendo, em frase simples>" [progresso 0-100]
  estado: pensando | trabalhando | esperando | pronto | erro
     python status.py log "<mensagem>"      (linha no diário geral)
     python status.py hip <id> "<suspeita>" <probabilidade 0-100> <estado: aberta|testando|descartada|confirmada>
     python status.py fato "<rótulo>" "<valor>"        (fatos do caso, ex.: Exceção = Data abort)
     python status.py etapa <id> "<nome>" <estado: pendente|ativa|feita>
     (set aceita também  pai=<id>  depois do estado/texto: quem criou este agente, ex.: pai=claude)
     python status.py no <id> "<nome>" <tipo: arquivo|suspeita|ferramenta|resultado|dispositivo|conceito> "<detalhe>"   (cartão de assunto)
     python status.py liga <de> <para> "<o que passa por essa linha>" [tipo: tarefa|leitura|pergunta|resposta|escrita|resultado]   (linha de comunicação; some sozinha em ~2 min)
     python status.py reset
Grava status.json e status.js (window.PAINEL=...), que o painel recarrega a cada segundo (funciona abrindo o HTML direto)."""
import json, os, sys, time
AQUI = os.path.dirname(os.path.abspath(__file__))
J = os.path.join(AQUI, "status.json")


def ler():
    try:
        return json.load(open(J, encoding="utf-8"))
    except Exception:
        return {"titulo": "Caça ao crash do KIKIU no Vita", "agentes": {}, "diario": []}


def gravar(d):
    d["atualizado"] = time.time()
    txt = json.dumps(d, ensure_ascii=False)
    tmp = J + ".tmp"
    open(tmp, "w", encoding="utf-8").write(txt)
    os.replace(tmp, J)
    tmpj = os.path.join(AQUI, "status.js.tmp")
    open(tmpj, "w", encoding="utf-8").write("window.PAINEL=" + txt + ";")
    os.replace(tmpj, os.path.join(AQUI, "status.js"))


def main():
    a = sys.argv[1:]
    d = ler()
    if not a:
        print(__doc__); return
    if a[0] == "reset":
        d = {"titulo": d.get("titulo", ""), "agentes": {}, "diario": []}
    elif a[0] == "resetar_tudo":
        d = {"titulo": d.get("titulo", ""), "agentes": {}, "diario": [], "hipoteses": {}, "fatos": {}, "etapas": {}, "nos": {}, "ligacoes": []}
    elif a[0] == "set":
        ident, nome, modelo, estado, texto = a[1:6]
        prog = None
        ag = d["agentes"].get(ident, {"inicio": time.time()})
        for extra in a[6:]:
            if extra.startswith("pai="):
                ag["pai"] = extra[4:]
            elif extra.isdigit():
                prog = int(extra)
        ag.update({"nome": nome, "modelo": modelo, "estado": estado, "texto": texto, "t": time.time()})
        if prog is not None:
            ag["progresso"] = prog
        if estado in ("pronto", "erro"):
            ag["fim"] = time.time()
        d["agentes"][ident] = ag
        d["diario"].append({"t": time.time(), "quem": nome, "texto": texto, "estado": estado})
        d["diario"] = d["diario"][-60:]
    elif a[0] == "no":
        d.setdefault("nos", {})[a[1]] = {"nome": a[2], "tipo": a[3], "detalhe": a[4] if len(a) > 4 else "", "t": time.time()}
    elif a[0] == "liga":
        tipo = a[4] if len(a) > 4 else "tarefa"
        d.setdefault("ligacoes", []).append({"de": a[1], "para": a[2], "rotulo": a[3], "tipo": tipo, "t": time.time()})
        d["ligacoes"] = d["ligacoes"][-80:]
        d["diario"].append({"t": time.time(), "quem": a[1], "texto": "→ %s: %s" % (a[2], a[3]), "estado": "info"})
        d["diario"] = d["diario"][-60:]
    elif a[0] == "hip":
        d.setdefault("hipoteses", {})[a[1]] = {"texto": a[2], "prob": int(a[3]), "estado": a[4], "t": time.time()}
        d["diario"].append({"t": time.time(), "quem": "suspeitas", "texto": "%s: %s (%s%%)" % (a[4], a[2], a[3]), "estado": "info"})
        d["diario"] = d["diario"][-60:]
    elif a[0] == "fato":
        d.setdefault("fatos", {})[a[1]] = a[2]
    elif a[0] == "etapa":
        d.setdefault("etapas", {})[a[1]] = {"nome": a[2], "estado": a[3], "t": time.time(), "ordem": len(d.get("etapas", {})) if a[1] not in d.get("etapas", {}) else d["etapas"][a[1]]["ordem"]}
    elif a[0] == "log":
        d["diario"].append({"t": time.time(), "quem": "geral", "texto": a[1], "estado": "info"})
        d["diario"] = d["diario"][-60:]
    gravar(d)


main()
