"""Ajuste do inimigos.gd para o núcleo C++ (NucleoHorda): a horda do jogo de verdade no Vita.

Aplicado pelo ajustes_vita.py DEPOIS da conversão automática, sobre o texto já em GDScript 3. Cada troca avisa (no
conversao.json) se o trecho esperado não existir mais, para a main poder mudar sem quebrar em silêncio.

O que muda:
- os campos de movimento do `class V` (pos, vm, kb, sepv, hp, flash, ...) passam a morar no C++ (ponte setget): os 31
  arquivos que os leem ou escrevem não mudam;
- `criar` pede um slot ao núcleo e espelha os campos fixos; `_remover`/`limpar` avisam o núcleo;
- `atualizar` roda o laço de movimento no C++ e resolve só os EVENTOS (tiro, anel, invocação, dano ao jogador,
  teleporte) em GDScript, na ordem em que aconteceram; o antigo vira `_atualizar_gd` (online e sem módulo);
- `no_circulo`, `mais_perto`, `n_mais_perto` consultam a grade do C++.
Sem o módulo (editor do PC), `_nuc` é nulo e tudo roda no GDScript como antes.
"""
import re

# nome -> (índice no núcleo, tipo, valor inicial em GDScript)
CAMPOS_ESCALARES = [
    ("hp", 0, "float", "1.0"), ("flash", 1, "float", "0.0"), ("lento", 2, "float", "0.0"),
    ("atordoado", 3, "float", "0.0"), ("t_nasc", 4, "float", "0.0"), ("t_atira", 5, "float", "0.0"),
    ("t_anel", 6, "float", "0.0"), ("t_invoca", 7, "float", "0.0"), ("t_inv", 8, "float", "0.0"),
    ("t_estado", 9, "float", "0.0"), ("estado", 10, "int", "0"),
    # comportamento (também escrito de fora: testes, calor, elite): índices F_VEL.. do núcleo
    ("vel", 12, "float", "40.0"), ("raio", 13, "float", "8.0"), ("distancia", 14, "float", "0.0"),
    ("investida", 15, "float", "0.0"), ("atira", 16, "float", "0.0"), ("anel", 17, "float", "0.0"),
    ("chefe", 18, "bool", "false"),
]
CAMPOS_VETORES = [("pos", 0), ("vm", 1), ("kb", 2), ("sepv", 3), ("dir_inv", 4)]


def _ponte():
    linhas = ["\tvar _n = null  # NucleoHorda (C++): dono dos campos de movimento abaixo",
              "\tvar _s = -1  # slot neste núcleo"]
    for nome, i, tipo, ini in CAMPOS_ESCALARES:
        linhas.append("\tvar _c_%s = %s" % (nome, ini))
        linhas.append("\tvar %s setget _set_%s, _get_%s" % (nome, nome, nome))
    for nome, i in CAMPOS_VETORES:
        linhas.append("\tvar _c_%s = Vector2.ZERO" % nome)
        linhas.append("\tvar %s setget _set_%s, _get_%s" % (nome, nome, nome))
    for nome, i, tipo, ini in CAMPOS_ESCALARES:
        conv = {"int": "int(_n.gf(_s, %d))", "bool": "_n.gf(_s, %d) != 0.0"}.get(tipo, "_n.gf(_s, %d)") % i
        valor = "(1.0 if x else 0.0)" if tipo == "bool" else "x"
        linhas += ["\tfunc _get_%s():" % nome, "\t\treturn %s if _n != null else _c_%s" % (conv, nome),
                   "\tfunc _set_%s(x):" % nome,
                   "\t\tif _n != null:", "\t\t\t_n.sf(_s, %d, %s)" % (i, valor), "\t\telse:", "\t\t\t_c_%s = x" % nome]
    for nome, i in CAMPOS_VETORES:
        linhas += ["\tfunc _get_%s():" % nome, "\t\treturn _n.gv(_s, %d) if _n != null else _c_%s" % (i, nome),
                   "\tfunc _set_%s(x):" % nome,
                   "\t\tif _n != null:", "\t\t\t_n.sv(_s, %d, x)" % i, "\t\telse:", "\t\t\t_c_%s = x" % nome]
    return "\n".join(linhas) + "\n"


NOVO_ATUALIZAR = '''func atualizar(dt: float, jog):
	if not _nativo():
		_atualizar_gd(dt, jog)
		return
	var _p0 = Perf.ini()
	_t += dt
	_quadro += 1
	_dt = dt
	_fantasmas_passo(dt)
	if medir:
		med_tempo += dt
		med_quadros += 1
	var _p1 = Perf.ini()
	_nuc.inicio_quadro(dt, _quadro)  # grade do núcleo (antes de elementos.passo, como a original)
	Perf.fim("ini_grade", _p1)
	elementos.passo(dt)
	var alvo = jog.centro()
	var _p2 = Perf.ini()
	var retomar = false
	while true:
		var ev = _nuc.passo(alvo, retomar)
		retomar = true
		var teleporte = null
		var n = ev.size()
		var i = 0
		while i < n:
			if _slots.empty():  # um evento anterior limpou a fase (chefe final morrendo): nada mais a resolver
				return
			var v = _slots[int(ev[i + 1])]
			match int(ev[i]):
				0:
					Som.tocar("whoosh", 0.1, 0.7)
				1:  # atira: com a posição de ANTES do movimento, como a original
					var pa = v.pos
					v.pos = Vector2(ev[i + 2], ev[i + 3])
					_atirar(v, Vector2(ev[i + 4], ev[i + 5]))
					v.pos = pa
				2:
					var pb = v.pos
					v.pos = Vector2(ev[i + 2], ev[i + 3])
					_anel(v)
					v.pos = pb
				3:  # invoca
					var inv = v.invoca
					var p0 = Vector2(ev[i + 2], ev[i + 3])
					for k in int(inv.get("quantos", 4)):
						var ang = TAU * k / float(inv.get("quantos", 4))
						criar(str(inv.get("tipo", "bug")), p0 + G4.from_angle(ang) * (v.raio + 20), arena.diretor.nivel())
				4:
					_ferir_jogador(jog, 0, 0, v.dano, v.tipo)
				5:
					teleporte = v
			i += 6
		if teleporte != null:
			# muito longe: volta pra perto (do lado de onde o jogador está indo); o sorteio fica aqui por causa do RNG
			var mov_j = jog.direcao_mov()
			var a: float = mov_j.angle() + rand_range(-1.0, 1.0)
			if mov_j == Vector2.ZERO:
				a = randf() * TAU
			_teleportar(teleporte, alvo + G4.from_angle(a) * rand_range(380, 440))
		if not _nuc.pendente():
			break
	Perf.fim("ini_laco", _p2)
	# tiros dos inimigos (poucos: ficam em GDScript)
	for t in tiros.duplicate():
		t.pos += t.vel * dt
		t.vida -= dt
		var acertou = false
		if t.pos.distance_squared_to(alvo) < 100.0:
			_ferir_jogador(jog, 0, 0, t.dano, "tiro")
			acertou = true
		if acertou or t.vida <= 0:
			tiros.erase(t)
	update()
	Perf.fim("ini_atualizar", _p0)


func _nativo():
	return _nuc != null and not espelho and online == null


'''

WRAPPERS_BUSCA = '''func no_circulo(c, r: float):
	if not _nativo():
		return _no_circulo_gd(c, r)
	var res = []
	for s in _nuc.no_circulo(c, r):
		res.append(_slots[s])
	return res


func mais_perto(p, maximo = 99999.0):
	if not _nativo():
		return _mais_perto_gd(p, maximo)
	var s = _nuc.mais_perto(p, maximo)
	return _slots[s] if s >= 0 else null


func n_mais_perto(p, n: int, maximo = 400.0):
	if not _nativo():
		return _n_mais_perto_gd(p, n, maximo)
	var res = []
	for s in _nuc.n_mais_perto(p, n, maximo):
		res.append(_slots[s])
	return res


'''


def _trocar(texto, velho, novo, avisos, nome, vezes=1):
    if texto.count(velho) < 1:
        avisos.append("ajuste inimigos: trecho não encontrado (%s): %s" % (nome, velho.strip()[:70]))
        return texto
    return texto.replace(velho, novo, vezes)


def inimigos(texto, avisos):
    # --- class V: campos de movimento viram ponte para o núcleo
    ini = texto.find("class V:\n")
    fim = ini
    if ini >= 0:
        linhas = texto[ini:].split("\n")
        n = 1
        while n < len(linhas) and (linhas[n].startswith("\t") or not linhas[n].strip()):
            n += 1
        corpo = linhas[1:n]
        nomes = [c[0] for c in CAMPOS_ESCALARES] + [c[0] for c in CAMPOS_VETORES]
        for nome in nomes:
            padrao = re.compile(r"^\tvar %s = .*$" % nome)
            achou = [k for k, l in enumerate(corpo) if padrao.match(l)]
            if not achou:
                avisos.append("ajuste inimigos: campo %s não está no class V" % nome)
                continue
            corpo[achou[0]] = "\t# %s: ponte para o núcleo C++ (ver abaixo)" % nome
        novo_v = "\n".join(["class V:"] + corpo).rstrip("\n") + "\n" + _ponte()
        texto = texto[:ini] + novo_v + "\n".join(linhas[n:])
    else:
        avisos.append("ajuste inimigos: class V não encontrada")

    # --- variáveis do node
    texto = _trocar(texto, "var lista = []\n",
                    "var lista = []\nvar _nuc = ClassDB.instance(\"NucleoHorda\") if ClassDB.class_exists(\"NucleoHorda\") and not Array(OS.get_cmdline_args()).has(\"--sem-nucleo\") and not G4.modo(4) else null\n"
                    "var _slots = []  # slot do núcleo -> V\n", avisos, "var lista")

    # --- criar
    texto = _trocar(texto, "\tvar v = V.new()\n",
                    "\tvar v = V.new()\n\tif _nuc != null:\n\t\tv._n = _nuc\n\t\tv._s = _nuc.novo()\n", avisos, "V.new")
    antes_lista = "\tlista.append(v)\n\tpor_id[v.id] = v\n"
    texto = _trocar(texto, antes_lista,
                    "\tif _nuc != null:\n\t\t_nuc.fixar(v._s, [v.id, v.raio, v.vel, (1 if v.chefe else 0) | (2 if v.d.has(\"fixo\") else 0) "
                    "| (4 if not v.invoca.empty() else 0), v.distancia, v.investida, v.atira, v.anel, "
                    "float(v.invoca.get(\"a_cada\", 5.0))])\n\t\t_nuc.anexar(v._s)\n\t\t_slots.append(v)\n" + antes_lista,
                    avisos, "lista.append")

    # --- _remover e limpar
    texto = _trocar(texto, "func _remover(v):\n",
                    "func _remover(v):\n\tif _nuc != null and v._s >= 0:\n\t\t_nuc.remover(v._s)\n", avisos, "_remover")
    texto = _trocar(texto, "func limpar():\n\telementos.limpar()\n",
                    "func limpar():\n\telementos.limpar()\n\tif _nuc != null:\n\t\tfor v in lista:  # V antigo não pode apontar para um slot reaproveitado depois\n\t\t\tv._n = null\n\t\t\tv._s = -1\n\t\t_nuc.limpar()\n\t\t_slots.clear()\n", avisos, "limpar")

    # --- buscas
    for nome in ("no_circulo", "mais_perto", "n_mais_perto"):
        texto = _trocar(texto, "func %s(" % nome, "func _%s_gd(" % nome, avisos, "func " + nome)
    texto = _trocar(texto, "func _no_circulo_gd(", WRAPPERS_BUSCA + "func _no_circulo_gd(", avisos, "wrappers busca")
    # n_mais_perto_gd chama no_circulo (que já é o nativo quando dá): ok

    # --- atualizar
    texto = _trocar(texto, "func atualizar(dt: float, jog):\n", NOVO_ATUALIZAR + "func _atualizar_gd(dt: float, jog):\n",
                    avisos, "func atualizar")
    return texto
