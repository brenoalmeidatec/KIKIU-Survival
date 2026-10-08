"""Içar lambdas do GDScript 2 (Godot 4) para métodos nomeados, antes das outras conversões.

    func(a, b): return a < b            (numa linha, dentro de uma chamada)
    obj.sinal.connect(func(x):          (corpo nas linhas seguintes, mais indentado)
        faz(x)
    )

viram `funcref(self, "_lambda_3")` (ou `G4.ligar(funcref(...), [capturadas])` quando o corpo usa variáveis locais da
função de fora; em função estática, o objeto é `load("res://este.gd")`). O método `_lambda_3(a, b, capturadas...)`
vai para o fim da classe de cima. O resto do conversor transforma `connect(funcref(...))`, `sort_custom(funcref(...))`
e `G4.filtrar(x, funcref(...))` no formato do Godot 3.
"""
import re

PALAVRAS = set("""and or not in is as if elif else for while match return pass break continue var const func static
self true false null PI TAU INF NAN extends class signal await yield super load preload""".split())


def _codigo_sem_strings(s):
    return re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', s.split("#")[0] if "#" in s and '"' not in s else s)


def _identificadores(s):
    s = re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', s)
    return set(m.group(1) for m in re.finditer(r"(?<![\.\w$%])([A-Za-z_]\w*)", s))


def _fechar(texto, i):
    pares = {"(": ")", "[": "]", "{": "}"}
    pilha = []
    j = i
    while j < len(texto):
        ch = texto[j]
        if ch in "\"'":
            k = j + 1
            while k < len(texto) and texto[k] != ch:
                k += 2 if texto[k] == "\\" else 1
            j = k + 1
            continue
        if ch in pares:
            pilha.append(pares[ch])
        elif pilha and ch == pilha[-1]:
            pilha.pop()
            if not pilha:
                return j
        j += 1
    return -1


def _fim_corpo_linha(texto, i):
    """Fim do corpo de uma lambda de uma linha que começa em texto[i]: vírgula ou fechamento no nível 0."""
    prof = 0
    j = i
    while j < len(texto):
        ch = texto[j]
        if ch in "\"'":
            k = j + 1
            while k < len(texto) and texto[k] != ch:
                k += 2 if texto[k] == "\\" else 1
            j = k + 1
            continue
        if ch == "#":
            return j
        if ch in "([{":
            prof += 1
        elif ch in ")]}":
            if prof == 0:
                return j
            prof -= 1
        elif ch == "," and prof == 0:
            return j
        j += 1
    return len(texto)


def _indent(l):
    return len(l) - len(l.lstrip("\t "))


def icar(texto, caminho_res, avisos):
    linhas = texto.replace("\r\n", "\n").split("\n")
    icadas = []           # (estatica, texto do método)
    cont = [0]
    # contexto: função de fora (nome, estática, params+locais) por linha
    i = 0
    func_atual = None     # dict(estatica, locais:set, indent)
    saida = []
    classes = []          # [indent, índice do cabeçalho em `saida`] das classes internas abertas
    por_classe = {}       # índice do cabeçalho -> [métodos içados para essa classe interna]
    while i < len(linhas):
        l = linhas[i]
        st = l.strip()
        if st and not st.startswith("#"):
            while classes and _indent(l) <= classes[-1][0]:
                classes.pop()
        mc = re.match(r"^(\s*)class\s+\w+.*:\s*(#.*)?$", l)
        if mc:
            classes.append([_indent(l), len(saida)])
        mf = re.match(r"^(\s*)(static\s+)?func\s+(\w+)\s*\((.*?)\)", l)
        if mf and (func_atual is None or _indent(l) <= func_atual["indent"]):
            params = set()
            for p in mf.group(4).split(","):
                p = p.strip()
                if p:
                    params.add(re.match(r"(\w+)", p).group(1))
            func_atual = {"estatica": bool(mf.group(2)), "locais": {p: _indent(l) + 1 for p in params},
                          "indent": _indent(l), "classe": _indent(l) > 0}
        elif func_atual and st and _indent(l) <= func_atual["indent"] and not st.startswith("#"):
            func_atual = None
        if func_atual and st and not st.startswith("#") and not mf:
            ind = _indent(l)
            # sai de escopo: variável declarada num bloco mais fundo do que esta linha
            for nm in [k for k, v in func_atual["locais"].items() if v > ind]:
                del func_atual["locais"][nm]
            for mv in re.finditer(r"\bvar\s+(\w+)", l):
                func_atual["locais"].setdefault(mv.group(1), ind)
            mfor = re.match(r"^\s*for\s+(\w+)\s+in\b", l)
            if mfor:
                func_atual["locais"][mfor.group(1)] = ind + 1
        # procura lambdas nesta linha (fora de strings e comentários)
        pos = 0
        while True:
            limpo = re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', lambda m: "_" * len(m.group(0)), l)
            hash_ = limpo.find("#")
            m = re.compile(r"(?<![\w])func\s*\(").search(limpo, pos)
            if not m or (hash_ >= 0 and m.start() > hash_):
                break
            if re.match(r"^\s*(static\s+)?func\s+\w", l):
                break
            a = m.end() - 1
            b = _fechar(l, a)
            if b < 0:
                break
            params_l = [p.strip() for p in l[a + 1:b].split(",") if p.strip()]
            nomes_params = [re.match(r"(\w+)", p).group(1) for p in params_l]
            dois = l.find(":", b)
            if dois < 0:
                break
            resto = l[dois + 1:]
            corpo = []
            fim_lin = None
            if resto.strip() == "" or resto.strip().startswith("#"):
                # corpo nas linhas seguintes
                ind0 = _indent(l)
                k = i + 1
                while k < len(linhas) and (not linhas[k].strip() or _indent(linhas[k]) > ind0) \
                        and not linhas[k].strip().startswith(")"):
                    corpo.append(linhas[k])
                    k += 1
                while corpo and not corpo[-1].strip():
                    corpo.pop()
                ind_corpo = min((_indent(c) for c in corpo if c.strip()), default=ind0 + 1)
                corpo = [c[ind_corpo:] if c.strip() else "" for c in corpo]
                cauda = ""
                # a última linha do corpo pode fechar a chamada de fora: "return a < b)" -> corpo "return a < b", cauda ")"
                if corpo:
                    tudo = "\n".join(corpo)
                    prof = 0
                    corte = -1
                    j = 0
                    while j < len(tudo):
                        ch = tudo[j]
                        if ch in "\"'":
                            q = j + 1
                            while q < len(tudo) and tudo[q] != ch:
                                q += 2 if tudo[q] == "\\" else 1
                            j = q + 1
                            continue
                        if ch == "#":
                            while j < len(tudo) and tudo[j] != "\n":
                                j += 1
                            continue
                        if ch in "([{":
                            prof += 1
                        elif ch in ")]}":
                            prof -= 1
                            if prof < 0:
                                corte = j
                                break
                        j += 1
                    if corte >= 0:
                        cauda = tudo[corte:].strip()
                        corpo = tudo[:corte].rstrip().split("\n")
                if not cauda and k < len(linhas) and linhas[k].strip().startswith(")"):
                    cauda = linhas[k].strip()
                    k += 1
                consumidas = k - (i + 1)
                antes = l[:m.start()]
                fim_lin = (antes, cauda, consumidas)
            else:
                e = _fim_corpo_linha(l, dois + 1)
                corpo = [l[dois + 1:e].strip()]
                antes, depois = l[:m.start()], l[e:]
            # variáveis capturadas: locais da função de fora usados no corpo, que não são parâmetros da lambda
            usados = set()
            declarados = set()
            for c in corpo:
                usados |= _identificadores(c)
                declarados |= set(re.findall(r"\bvar\s+(\w+)", c))
                declarados |= set(re.findall(r"\bfor\s+(\w+)\s+in\b", c))
            locais = set(func_atual["locais"]) if func_atual else set()
            # a variável que recebe a própria lambda ("var f = func(...)") ainda não existe dentro dela
            declarados |= set(re.findall(r"\bvar\s+(\w+)", l[:m.start()]))
            capt = sorted((usados & locais) - set(nomes_params) - declarados - PALAVRAS)
            cont[0] += 1
            nome = "_lambda_%d" % cont[0]
            estatica = bool(func_atual and func_atual["estatica"])
            obj = 'load("%s")' % caminho_res if estatica else "self"
            ref = 'funcref(%s, "%s")' % (obj, nome)
            if capt:
                ref = "G4.ligar(%s, [%s])" % (ref, ", ".join(capt))
            cab = "%sfunc %s(%s):" % ("static " if estatica else "", nome, ", ".join(params_l + capt))
            if len(corpo) == 1 and fim_lin is None:
                c = corpo[0]
                if not re.match(r"^(return|pass|if|for|while|match|var|break|continue)\b", c) \
                        and not re.match(r"^[\w\.\[\]]+\s*[-+*/]?=[^=]", c):
                    c = "return " + c
                metodo = cab + "\n\t" + c
            else:
                metodo = cab + "\n" + "\n".join(("\t" + c) if c else "" for c in corpo)
            if classes and func_atual and func_atual["indent"] > classes[-1][0]:
                por_classe.setdefault(classes[-1][1], [classes[-1][0] + 1, []])[1].append(metodo)
            else:
                icadas.append(metodo)
            if fim_lin is None:
                l = antes + ref + depois
                pos = len(antes) + len(ref)
            else:
                antes, cauda, consumidas = fim_lin
                l = antes + ref + cauda
                i += consumidas
                pos = len(antes) + len(ref)
        saida.append(l)
        i += 1
    # métodos de classes internas: no fim do bloco de cada uma (de baixo para cima, para os índices não mudarem)
    for cab in sorted(por_classe, reverse=True):
        ind, mets = por_classe[cab]
        ind_cls = ind - 1
        k = cab + 1
        while k < len(saida):
            t = saida[k]
            if t.strip() and not t.strip().startswith("#") and _indent(t) <= ind_cls:
                break
            k += 1
        bloco = []
        for mtd in mets:
            bloco += ["", ""] + ["\t" * ind + x if x else "" for x in mtd.split("\n")]
        bloco.append("")
        saida[k:k] = bloco
    if icadas:
        saida.append("")
        saida.append("")
        saida.append("# ---- lambdas do Godot 4 içadas pelo conversor ----")
        for mtd in icadas:
            saida.append("")
            saida.append("")
            saida.append(mtd)
    return "\n".join(saida)
