class_name Roteiro
## Jeito curto de escrever cenas: cada passo pode ser só um texto.
##
##   "lucas: Bora testar! #point #talk1 @laugh"   fala (gestos com #, ouvinte com @)
##   "breno pensa: Isso não vai dar certo..."     pensamento (caixa diferente)
##   "> O João foi tomar café."                   narrador
##   "? Sentar na cadeira? | Sentar -> cena_sentar | Melhor não"
##   "!andar lucas 300 200"                       comando (lista no LEIA-ME)
##   "// comentário"                              ignorado
##
## Os nomes não ligam pra acento nem maiúscula ("Nicão" = "nicao"), e o capítulo
## pode ter "apelidos": {"n": "nicao"}. "eu" é sempre o jogador.
## Os passos no formato antigo (objetos JSON) continuam valendo e podem ser misturados.

static var apelidos := {}


static func preparar(passos: Array) -> Array:
	var saida := []
	for p in passos:
		var d = passo(p)
		if d == null:
			continue
		if d is Array:
			saida.append_array(d)
		else:
			saida.append(d)
	return saida


static func passo(p) -> Variant:
	if p is Dictionary:
		var d: Dictionary = p.duplicate()
		if d.has("quem"):
			d.quem = nome(str(d.quem))
		for k in ["entao", "senao", "passos"]:
			if d.get(k) is Array:
				d[k] = preparar(d[k])
		if d.get("opcoes") is Array:
			var ops := []
			for o in d.opcoes:
				ops.append(passo(o) if o is Dictionary else _opcao(str(o)))
			d.opcoes = ops
		return d
	if not p is String:
		return null
	var s: String = p.strip_edges()
	if s == "" or s.begins_with("//"):
		return null
	if s.begins_with(">"):
		return {"narrar": s.substr(1).strip_edges()}
	if s.begins_with("?"):
		return _escolha(s.substr(1))
	if s.begins_with("!"):
		return _comando(s.substr(1).strip_edges())
	var dois := s.find(":")
	if dois > 0:
		var cab := s.substr(0, dois).strip_edges().split(" ", false)
		var f := _fala(s.substr(dois + 1))
		if cab.size() > 0:
			f["quem"] = nome(cab[0])
			if cab.size() > 1 and cab[1].to_lower() in ["pensa", "pensando", "pensou"]:
				f["pensa"] = true
			return f
	return {"narrar": s}


## Normaliza um nome: sem acento, minúsculo, apelidos do capítulo.
static func nome(n: String) -> String:
	var s := sem_acento(n.strip_edges().to_lower())
	if s in ["", "*", "narrador", "ninguem"]:
		return "*"
	if s == "eu":
		return "jogador"
	return apelidos.get(s, s)


static func sem_acento(s: String) -> String:
	const DE := "áàâãäéèêëíìîïóòôõöúùûüçñ"
	const PARA := "aaaaaeeeeiiiiooooouuuucn"
	var r := ""
	for ch in s:
		var i := DE.find(ch)
		r += PARA[i] if i >= 0 else ch
	return r


static func _fala(resto: String) -> Dictionary:
	var palavras := Array(resto.strip_edges().split(" ", false))
	var gestos := []
	var ouvinte := ""
	var foco := ""
	# #gestos, @ouvinte e ^foco só valem no fim da frase
	while palavras.size() > 0:
		var w: String = palavras[palavras.size() - 1]
		if w.begins_with("#") and w.length() > 1:
			gestos.push_front(w.substr(1))
		elif w.begins_with("@") and w.length() > 1:
			ouvinte = w.substr(1)
		elif w.begins_with("^") and w.length() > 1:
			foco = nome(w.substr(1))
		else:
			break
		palavras.remove_at(palavras.size() - 1)
	var f := {"texto": " ".join(palavras)}
	if not gestos.is_empty():
		f["gestos"] = gestos
	if ouvinte != "":
		f["ouvinte"] = ouvinte
	if foco != "":
		f["foco"] = foco
	return f


static func _escolha(s: String) -> Dictionary:
	var partes := s.split("|")
	var d := {"escolha": partes[0].strip_edges(), "quem": "jogador", "opcoes": []}
	for i in range(1, partes.size()):
		d.opcoes.append(_opcao(partes[i]))
	return d


## "Texto -> cena +marca -marca"
static func _opcao(s: String) -> Dictionary:
	var o := {}
	var seta := s.find("->")
	var texto := s if seta < 0 else s.substr(0, seta)
	var resto := "" if seta < 0 else s.substr(seta + 2)
	var palavras := Array(texto.strip_edges().split(" ", false))
	var marcar := []
	var desmarcar := []
	while palavras.size() > 0 and (palavras[-1].begins_with("+") or palavras[-1].begins_with("-")) and palavras[-1].length() > 1:
		var w: String = palavras[-1]
		(marcar if w.begins_with("+") else desmarcar).push_front(w.substr(1))
		palavras.pop_back()
	o["texto"] = " ".join(palavras)
	for w in resto.strip_edges().split(" ", false):
		if w.begins_with("+"):
			marcar.append(w.substr(1))
		elif w.begins_with("-"):
			desmarcar.append(w.substr(1))
		else:
			o["cena"] = w
	if not marcar.is_empty():
		o["marcar"] = marcar
	if not desmarcar.is_empty():
		o["desmarcar"] = desmarcar
	return o


static func _num(a: Array, i: int, padrao: float) -> float:
	return float(a[i]) if i < a.size() and str(a[i]).is_valid_float() else padrao


static func _txt(a: Array, i: int, padrao := "") -> String:
	return str(a[i]) if i < a.size() else padrao


static func _comando(s: String) -> Variant:
	var a := Array(s.split(" ", false))
	if a.is_empty():
		return null
	var cmd: String = sem_acento(a.pop_front().to_lower())
	var nao_espera: bool = not a.is_empty() and a[-1] == "&"
	if nao_espera:
		a.pop_back()
	var resto := " ".join(a)
	match cmd:
		"andar", "correr":
			var d := {"andar": nome(_txt(a, 0)), "x": _num(a, 1, 0), "y": _num(a, 2, -1),
				"velocidade": _num(a, 3, 130.0 if cmd == "correr" else 60.0)}
			if nao_espera:
				d["esperar"] = false
			return d
		"virar":
			var alvo := _txt(a, 1, "baixo")
			if alvo in ["baixo", "cima", "esquerda", "direita"]:
				return {"virar": nome(_txt(a, 0)), "dir": alvo}
			return {"virar": nome(_txt(a, 0)), "para": nome(alvo)}
		"pular":
			return {"pular": nome(_txt(a, 0)), "vezes": int(_num(a, 1, 1))}
		"balao", "emocao":
			return {"balao": nome(_txt(a, 0)), "icone": _txt(a, 1, "!"), "tempo": _num(a, 2, 1.0)}
		"pensar":
			return {"pensar": nome(_txt(a, 0)), "texto": " ".join(a.slice(1))}
		"dizer":
			return {"dizer": nome(_txt(a, 0)), "texto": " ".join(a.slice(1))}
		"tremer":
			return {"tremer": _num(a, 0, 0.5), "forca": _num(a, 1, 4.0)}
		"flash":
			return {"flash": _num(a, 0, 0.3), "cor": _txt(a, 1, "white")}
		"fade":
			return {"fade": _txt(a, 0, "preto"), "tempo": _num(a, 1, 0.5)}
		"susto":
			return {"susto": nome(_txt(a, 0, "eu")), "icone": _txt(a, 1, "!!")}
		"impacto":
			return {"impacto": _num(a, 0, 5.0)}
		"close":
			return {"close": nome(_txt(a, 0, "eu")), "zoom": _num(a, 1, 1.8), "tempo": _num(a, 2, 0.25)}
		"tela":
			return {"tela": _txt(a, 0, "normal")}
		"lateral", "lado":
			return {"lateral": _txt(a, 0, "fim"), "x": _num(a, 1, -1.0)}
		"rosto":
			var d := {"rosto": nome(_txt(a, 0, "eu")), "expr": _txt(a, 1, "normal"), "tempo": _num(a, 2, 2.0),
				"lado": _txt(a, 3, "direita")}
			if nao_espera:
				d["esperar"] = false
			return d
		"esperar":
			return {"esperar": _num(a, 0, 1.0)}
		"marcar":
			return {"marcar": a}
		"desmarcar":
			return {"desmarcar": a}
		"sumir":
			return {"sumir": nome(_txt(a, 0))}
		"aparecer":
			var d := {"aparecer": nome(_txt(a, 0)), "x": _num(a, 1, 0), "y": _num(a, 2, 0), "dir": _txt(a, 3, "baixo")}
			if a.size() > 4:
				d["no_mapa"] = a[4]
			return d
		"entrar":
			var d := {"entrar": nome(_txt(a, 0)), "x": _num(a, 1, 0), "y": _num(a, 2, 0)}
			if a.size() > 3:
				d["de"] = a[3]
			if nao_espera:
				d["esperar"] = false
			return d
		"sair":
			var d := {"sair": nome(_txt(a, 0))}
			if a.size() > 1:
				d["por"] = a[1]
			if nao_espera:
				d["esperar"] = false
			return d
		"mapa":
			return {"mapa": _txt(a, 0), "x": _num(a, 1, 240), "y": _num(a, 2, 200), "dir": _txt(a, 3, "baixo")}
		"camera":
			var alvo := _txt(a, 0, "jogador")
			if alvo.is_valid_float():
				return {"camera": [float(alvo), _num(a, 1, 0)], "tempo": _num(a, 2, 1.0)}
			return {"camera": nome(alvo), "tempo": _num(a, 1, 0.6)}
		"zoom":
			return {"zoom": _num(a, 0, 1.0), "tempo": _num(a, 1, 0.6)}
		"barras":
			return {"barras": _txt(a, 0, "sim") in ["sim", "on", "liga", "1"]}
		"tom":
			return {"tom": _txt(a, 0, "normal"), "tempo": _num(a, 1, 1.0)}
		"minijogo":
			var d := {"minijogo": _txt(a, 0)}
			if a.size() > 1:
				d["guardar"] = a[1]
			if a.size() > 2:
				d["dificuldade"] = int(_num(a, 2, 1))
			return d
		"cena":
			return {"cena": _txt(a, 0)}
		"enfileirar":
			return {"enfileirar": _txt(a, 0)}
		"se":
			# !se marca -> cena_sim | cena_nao
			var seta := resto.find("->")
			if seta < 0:
				return null
			var cond := resto.substr(0, seta).strip_edges().split(" ", false)
			var ramos := resto.substr(seta + 2).split("|")
			var d := {"se": Array(cond), "entao": [{"cena": ramos[0].strip_edges()}]}
			if ramos.size() > 1 and ramos[1].strip_edges() != "":
				d["senao"] = [{"cena": ramos[1].strip_edges()}]
			return d
		"anim", "animar", "animacao":
			# !anim lucas cair   |   !anim nicao soco lucas   |   !anim lucas,nicao comemorar &
			var quem := ",".join(Array(_txt(a, 0).split(",", false)).map(func(q): return nome(q)))
			var d := {"anim": quem, "nome": _txt(a, 1, "normal")}
			if a.size() > 2:
				d["alvo"] = nome(a[2])
			if nao_espera:
				d["esperar"] = false
			return d
		"pose":
			return {"anim": nome(_txt(a, 0)), "nome": _txt(a, 1, "normal")}
		"briga":
			# !briga lucas nicao [segundos] [perdedor]
			var d := {"briga": [nome(_txt(a, 0)), nome(_txt(a, 1))], "tempo": _num(a, 2, 2.0)}
			var perd := _txt(a, 3) if a.size() > 3 else (_txt(a, 2) if a.size() > 2 and not str(a[2]).is_valid_float() else "")
			if perd != "":
				d["perdedor"] = nome(perd)
			return d
		"porta":
			# !porta abrir laboratorio   |   !porta fechar
			return {"porta": _txt(a, 0, "abrir"), "para": _txt(a, 1, "")}
		"musica":
			return {"musica": _txt(a, 0, "")}   # "!musica mapa" volta pra do lugar
		"som":
			return {"som": _txt(a, 0)}
		"video":
			# !video teste   |   !video cutscenes/videos/prontos/teste_5s.ogv   (E ou Esc pula)
			var d := {"video": _txt(a, 0)}
			if a.size() > 1 and str(a[1]) in ["nao_pula", "sem_pular"]:
				d["pular"] = false
			return d
		"fim":
			return {"fim": true}
		"fim_capitulo":
			return {"fim_capitulo": true}
		"salvar":
			return {"salvar": true}
	push_warning("Comando desconhecido na cena: !" + s)
	return {"narrar": "(comando desconhecido: !%s)" % s}
