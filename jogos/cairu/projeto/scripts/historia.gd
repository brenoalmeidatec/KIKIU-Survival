class_name Historia
## Histórias em arquivo de texto simples (capitulos/<capitulo>.txt) e o verificador.
##
## Cada cena começa com uma linha "===":
##
##   === h3_lucas | uma_vez | cinema | requer: viu_h2_nicao
##   lucas: Bora testar! #point
##   !andar lucas 300 200
##
## As linhas seguintes (até o próximo "===") são os passos, no mesmo jeito curto
## das cenas do JSON (veja roteiro.gd). Uma cena do .txt com o mesmo nome de uma
## do .json substitui a do .json. Linhas que começam com // são comentários.

const _PERS := preload("res://scripts/personagem.gd")
const GESTOS := ["idle", "talk1", "talk2", "point", "shrug", "think", "cross", "laugh", "wave", "cismado"]
const OPCOES_CENA := ["uma_vez", "cinema", "requer", "vezes", "depois", "teste"]
const COMANDOS := ["andar", "correr", "virar", "pular", "balao", "emocao", "pensar", "dizer", "tremer",
	"flash", "fade", "esperar", "marcar", "desmarcar", "sumir", "aparecer", "entrar", "sair", "mapa",
	"camera", "zoom", "barras", "tom", "minijogo", "cena", "enfileirar", "se", "anim", "animar",
	"animacao", "pose", "briga", "porta", "musica", "som", "video", "fim", "fim_capitulo", "salvar",
	"susto", "impacto", "close", "tela", "lateral", "lado", "rosto"]
## comando -> quantos argumentos no mínimo e quais deles são personagens / números
const ARGS := {
	"andar": [2, [0], [1, 2]], "correr": [2, [0], [1, 2]], "virar": [2, [0], []],
	"pular": [1, [0], []], "balao": [2, [0], []], "emocao": [2, [0], []], "pensar": [2, [0], []],
	"dizer": [2, [0], []], "sumir": [1, [0], []], "aparecer": [3, [0], [1, 2]], "entrar": [3, [0], [1, 2]],
	"sair": [1, [0], []], "mapa": [1, [], [1, 2]], "zoom": [1, [], [0]], "esperar": [0, [], [0]],
	"minijogo": [1, [], []], "cena": [1, [], []], "enfileirar": [1, [], []], "anim": [2, [], []],
	"animar": [2, [], []], "animacao": [2, [], []], "pose": [2, [0], []], "briga": [2, [0, 1], []],
	"som": [1, [], []], "video": [1, [], []], "marcar": [1, [], []], "desmarcar": [1, [], []],
	"tremer": [0, [], [0, 1]], "flash": [0, [], [0]], "fade": [0, [], [1]],
	"susto": [1, [0], []], "impacto": [0, [], [0]], "close": [1, [0], [1, 2]],
	"lateral": [1, [], [1]], "lado": [1, [], [1]], "rosto": [2, [0], [2]],
}


## Lê o texto e devolve {"cenas": {id: {...}}, "linhas": {id: [nº da linha de cada passo]},
## "erros": [{linha, msg}]}.
static func ler(texto: String) -> Dictionary:
	var cenas := {}
	var linhas := {}
	var erros := []
	var atual := ""
	var n := 0
	for bruta in texto.split("\n"):
		n += 1
		var s := bruta.strip_edges()
		if s == "" or s.begins_with("//"):
			continue
		if s.begins_with("==="):
			var partes := Array(s.trim_prefix("===").split("|"))
			atual = str(partes.pop_front()).strip_edges().trim_suffix("===").strip_edges()
			if atual == "" or atual.contains(" "):
				erros.append({"linha": n, "msg": "nome de cena inválido: \"%s\" (use letras, números e _ , sem espaço)" % atual})
				atual = "_sem_nome_%d" % n
			if cenas.has(atual):
				erros.append({"linha": n, "msg": "a cena \"%s\" aparece duas vezes neste arquivo" % atual})
			var c := {"passos": []}
			for p in partes:
				var op := str(p).strip_edges()
				if op == "":
					continue
				var dois := op.find(":")
				var chave := Roteiro.sem_acento((op if dois < 0 else op.substr(0, dois)).strip_edges().to_lower())
				var valor := "" if dois < 0 else op.substr(dois + 1).strip_edges()
				match chave:
					"uma_vez", "cinema":
						c[chave] = true
					"requer":
						c["requer"] = Array(valor.replace(",", " ").split(" ", false))
					"vezes":
						if not valor.is_valid_int():
							erros.append({"linha": n, "msg": "\"vezes\" precisa de um número (ex.: vezes: 2)"})
						c["vezes"] = int(valor)
					"depois":
						c["depois"] = valor
					"teste":   # aparece no topo do F6 com esse nome, em qualquer capítulo
						c["teste"] = valor if valor != "" else atual
					_:
						erros.append({"linha": n, "msg": "opção de cena desconhecida: \"%s\" (vale: %s)" % [chave, ", ".join(OPCOES_CENA)]})
			cenas[atual] = c
			linhas[atual] = [n]
			continue
		if atual == "":
			erros.append({"linha": n, "msg": "texto fora de cena: comece a cena com uma linha \"=== nome_da_cena\""})
			continue
		cenas[atual].passos.append(s)
		linhas[atual].append(n)
	for id in cenas:
		if cenas[id].passos.is_empty():
			erros.append({"linha": linhas[id][0], "msg": "a cena \"%s\" está vazia" % id})
	return {"cenas": cenas, "linhas": linhas, "erros": erros}


## Junta o .txt do capítulo (mesmo nome do .json) nas cenas dele. Guarda os erros de leitura
## em cap["_erros_txt"] e as linhas em cap["_linhas_txt"] pro verificador.
static func juntar(cap: Dictionary) -> void:
	var arq := str(cap.get("_arquivo", ""))
	if arq == "":
		return
	var nome_txt := arq.get_basename() + ".txt"
	var texto := Dados.ler_texto(nome_txt)
	if texto == "":
		return
	var r := ler(texto)
	if not cap.get("cenas") is Dictionary:
		cap["cenas"] = {}
	for id in r.cenas:
		cap.cenas[id] = r.cenas[id]
	cap["_txt"] = nome_txt
	cap["_erros_txt"] = r.erros
	cap["_linhas_txt"] = r.linhas


# ======================================================== verificador

## Confere tudo do capítulo e devolve uma lista de textos "arquivo linha N: problema".
static func verificar(cap: Dictionary) -> Array:
	var saida := []
	var arq_json := str(cap.get("_arquivo", "?"))
	var arq_txt := str(cap.get("_txt", ""))
	for e in cap.get("_erros_txt", []):
		saida.append("%s linha %d: %s" % [arq_txt, e.linha, e.msg])
	var nomes := _nomes_validos(cap)
	var cenas: Dictionary = cap.get("cenas", {})
	var linhas_txt: Dictionary = cap.get("_linhas_txt", {})
	var ctx := {"nomes": nomes, "cenas": cenas, "animacoes": _animacoes()}
	Roteiro.apelidos = cap.get("apelidos", {})
	for id in cenas:
		var c = cenas[id]
		var passos: Array = c if c is Array else ([c] if c is String else c.get("passos", []))
		var do_txt := linhas_txt.has(id)
		for i in passos.size():
			if not passos[i] is String:
				continue
			var onde := ("%s linha %d" % [arq_txt, linhas_txt[id][i + 1]]) if do_txt and i + 1 < linhas_txt[id].size() \
				else ("%s, cena %s, passo %d" % [arq_json, id, i + 1])
			for msg in verificar_linha(str(passos[i]), ctx):
				saida.append("%s: %s" % [onde, msg])
		if c is Dictionary and c.get("depois", "") != "" and not cenas.has(c.depois):
			saida.append("%s: cena \"%s\" tem depois: %s, que não existe" % [arq_txt if do_txt else arq_json, id, c.depois])
	# cenas citadas por NPCs, pontos e gatilhos
	for n in cap.get("npcs", []):
		for cid in _cenas_de(n):
			if not cenas.has(cid):
				saida.append("%s: o NPC %s usa a cena \"%s\", que não existe" % [arq_json, n.get("personagem", "?"), cid])
	for g in cap.get("gatilhos", []):
		for cid in _cenas_de(g):
			if not cenas.has(cid):
				saida.append("%s: um gatilho em %s usa a cena \"%s\", que não existe" % [arq_json, g.get("mapa", "?"), cid])
	for k in ["inicio", "abertura"]:
		var v = cap.get(k, "")
		if v is String and v != "" and not cenas.has(v) and not FileAccess.file_exists("res://capitulos/mapas/%s.json" % v):
			saida.append("%s: \"%s\": cena \"%s\" não existe" % [arq_json, k, v])
	return saida


static func _cenas_de(d: Dictionary) -> Array:
	var l: Array = []
	if str(d.get("cena", "")) != "":
		l.append(str(d.cena))
	for c in d.get("cenas", []):
		l.append(str(c))
	return l


static func _nomes_validos(cap: Dictionary) -> Dictionary:
	var n := {"jogador": true, "*": true}
	for k in Dados.NOMES:
		n[k] = true
	for k in cap.get("apelidos", {}):
		n[Roteiro.sem_acento(str(k).to_lower())] = true
	for v in cap.get("apelidos", {}).values():
		n[str(v)] = true
	for npc in cap.get("npcs", []):
		n[str(npc.get("personagem", ""))] = true
	for i in range(1, 11):
		n["aluno%d" % i] = true
	n[str(cap.get("jogador", "breno"))] = true
	return n


static func _animacoes() -> Dictionary:
	var a := {}
	var d = Dados.ler_json("animacoes.json")
	if d is Dictionary:
		for k in d.get("animacoes", {}):
			a[k] = true
		var folha = d.get("folha_acoes", {})
		if folha is Dictionary:
			for k in folha.get("linhas", {}) if folha.get("linhas") is Dictionary else {}:
				a[k] = true
	return a


static func _nome_ok(bruto: String, ctx: Dictionary) -> bool:
	var s := Roteiro.nome(bruto)
	return ctx.nomes.has(s) or ctx.nomes.has(Roteiro.sem_acento(bruto.to_lower()))


## Problemas de uma linha só (lista vazia = tudo certo).
static func verificar_linha(linha: String, ctx: Dictionary) -> Array:
	var s := linha.strip_edges()
	var e := []
	if s == "" or s.begins_with("//") or s.begins_with(">"):
		return e
	if s.begins_with("?"):
		var partes := s.substr(1).split("|")
		if partes.size() < 2:
			e.append("pergunta sem opções (ex.: ? Vai? | Vou -> cena_sim | Não vou)")
		for i in range(1, partes.size()):
			var o := Roteiro._opcao(partes[i])
			if str(o.get("texto", "")) == "":
				e.append("opção %d da pergunta está sem texto" % i)
			if o.has("cena") and not ctx.cenas.has(o.cena):
				e.append("a opção \"%s\" vai pra cena \"%s\", que não existe" % [o.texto, o.cena])
		return e
	if s.begins_with("!"):
		return _verificar_comando(s.substr(1).strip_edges(), ctx)
	var dois := s.find(":")
	if dois <= 0:
		return e   # sem "quem:", o jogo lê como narrador
	var cab := s.substr(0, dois).strip_edges().split(" ", false)
	if cab.size() > 2 or (cab.size() == 2 and not cab[1].to_lower() in ["pensa", "pensando", "pensou"]):
		return e   # "Dica: ..." com espaço vira narração, não tem como errar
	if not _nome_ok(cab[0], ctx):
		e.append("personagem desconhecido: \"%s\" (se era narração, comece com >)" % cab[0])
	var f := Roteiro._fala(s.substr(dois + 1))
	for g in f.get("gestos", []):
		if not g in GESTOS:
			e.append("gesto desconhecido: #%s (vale: %s)" % [g, ", ".join(GESTOS)])
	if f.has("foco") and not _nome_ok(f.foco, ctx):
		e.append("^%s: personagem desconhecido" % f.foco)
	if str(f.get("texto", "")) == "":
		e.append("fala vazia")
	elif _parece_emoji(str(f.texto)):
		e.append("emoji na fala não aparece na tela; use um balão na linha de baixo (ex.: !balao %s 😳)" % cab[0])
	return e


static func _verificar_comando(s: String, ctx: Dictionary) -> Array:
	var e := []
	var a := Array(s.split(" ", false))
	if a.is_empty():
		return ["\"!\" sozinho, sem comando"]
	var cmd := Roteiro.sem_acento(str(a.pop_front()).to_lower())
	if not a.is_empty() and a[-1] == "&":
		a.pop_back()
	if not cmd in COMANDOS:
		var parecido := ""
		for c in COMANDOS:
			if c.similarity(cmd) >= 0.5:
				parecido = c
				break
		return ["comando desconhecido: !%s%s" % [cmd, (" (era !%s?)" % parecido) if parecido != "" else ""]]
	if ARGS.has(cmd):
		var regra: Array = ARGS[cmd]
		if a.size() < regra[0]:
			e.append("!%s precisa de %d coisa(s) depois dele, só tem %d" % [cmd, regra[0], a.size()])
		for i in regra[1]:
			if i < a.size() and not _nome_ok(str(a[i]), ctx):
				e.append("!%s: personagem desconhecido \"%s\"" % [cmd, a[i]])
		for i in regra[2]:
			if i < a.size() and not str(a[i]).is_valid_float():
				e.append("!%s: \"%s\" devia ser um número" % [cmd, a[i]])
	match cmd:
		"cena", "enfileirar":
			if a.size() > 0 and not ctx.cenas.has(a[0]):
				e.append("!%s %s: essa cena não existe" % [cmd, a[0]])
		"se":
			var resto := " ".join(a)
			var seta := resto.find("->")
			if seta < 0:
				e.append("!se precisa de \"->\" (ex.: !se marca -> cena_sim | cena_nao)")
			else:
				for r in resto.substr(seta + 2).split("|"):
					var c := r.strip_edges()
					if c != "" and not ctx.cenas.has(c):
						e.append("!se: a cena \"%s\" não existe" % c)
		"mapa":
			if a.size() > 0 and not FileAccess.file_exists("res://capitulos/mapas/%s.json" % a[0]) \
					and Dados.mapa(a[0]) == null:
				e.append("!mapa: o mapa \"%s\" não existe" % a[0])
		"minijogo":
			if a.size() > 0 and not _minijogos().has(a[0]):
				e.append("!minijogo: \"%s\" não existe (vale: %s)" % [a[0], ", ".join(_minijogos())])
		"anim", "animar", "animacao", "pose":
			if a.size() > 0 and cmd != "pose":
				for q in str(a[0]).split(",", false):
					if not _nome_ok(q, ctx):
						e.append("!%s: personagem desconhecido \"%s\"" % [cmd, q])
			if a.size() > 1:
				var an := str(a[1]).split(":")[0]
				if not ctx.animacoes.is_empty() and not ctx.animacoes.has(an):
					e.append("!%s: animação desconhecida \"%s\" (lista no LEIA-ME)" % [cmd, an])
		"balao", "emocao", "susto":
			if a.size() > 1 and _parece_emoji(str(a[1])) and _PERS.chave_icone(str(a[1])) == "":
				e.append("!%s: o emoji \"%s\" não tem desenho (vale: %s)" % [cmd, a[1], _icones()])
		"fade":
			if a.size() > 0 and not str(a[0]) in ["preto", "sair", "escurecer", "branco", "branca", "clarear", "volta", "voltar", "entrar", "clarear"]:
				e.append("!fade: use preto, branco ou volta (não \"%s\")" % a[0])
		"lateral", "lado":
			if a.size() > 0 and not str(a[0]) in ["fim", "sair"] and Dados.imagem_mapa("lado_%s.png" % a[0]) == null:
				e.append("!%s: não achei o fundo capitulos/mapas/lado_%s.png" % [cmd, a[0]])
		"rosto":
			const EXPR := ["normal", "fala", "rindo", "chorando", "dor", "susto", "pensando", "cismado"]
			if a.size() > 1 and not str(a[1]) in EXPR:
				e.append("!rosto: expressão \"%s\" não existe (vale: %s)" % [a[1], ", ".join(EXPR)])
			if a.size() > 3 and not str(a[3]) in ["esquerda", "direita"]:
				e.append("!rosto: o lado é esquerda ou direita (não \"%s\")" % a[3])
		"tela":
			if a.size() > 0 and a[0] != "normal":
				e.append("!tela: por enquanto só existe \"!tela normal\"")
		"virar":
			if a.size() > 1 and not str(a[1]) in ["baixo", "cima", "esquerda", "direita"] and not _nome_ok(str(a[1]), ctx):
				e.append("!virar: \"%s\" não é direção (baixo/cima/esquerda/direita) nem personagem" % a[1])
		"musica":
			if a.size() > 0 and a[0] != "mapa" and not ResourceLoader.exists("res://assets/audio/musica/%s.ogg" % a[0]):
				e.append("!musica: não achei a música \"%s\"" % a[0])
		"som":
			if a.size() > 0 and not ResourceLoader.exists("res://assets/audio/efeitos/%s.wav" % a[0]):
				e.append("!som: não achei o efeito \"%s\"" % a[0])
	return e


## Tem algum caractere de emoji/símbolo (fora das letras com acento do português)?
static func _parece_emoji(t: String) -> bool:
	for i in t.length():
		var c := t.unicode_at(i)
		if c >= 0x2190 and c != 0xFE0F:
			return true
	return false


static func _icones() -> String:
	return "😳 💀 😭 😱 😂 ⚡ 🔥 ❤ 💡 💤 ⭐ 💧 😡 🎵 ❗ ❓ ou: " + ", ".join(_PERS.ICONES.keys())


static func _minijogos() -> Array:
	return preload("res://scripts/minijogo.gd").MINIJOGOS.keys()


## Verifica todos os capítulos do indice.json e devolve todas as linhas de problema.
static func verificar_tudo() -> Array:
	var tudo := []
	for cap in Dados.capitulos():
		tudo.append_array(verificar(cap))
	return tudo


## Escreve ERROS_HISTORIA.txt ao lado do JOGO.exe (ou na pasta do usuário no editor).
static func gravar_relatorio(erros: Array) -> String:
	var base := OS.get_executable_path().get_base_dir() if not OS.has_feature("editor") else OS.get_user_data_dir()
	var caminho := base.path_join("ERROS_HISTORIA.txt")
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		caminho = OS.get_user_data_dir().path_join("ERROS_HISTORIA.txt")
		f = FileAccess.open(caminho, FileAccess.WRITE)
	if f:
		if erros.is_empty():
			f.store_string("Tudo certo! Nenhum erro nas histórias.\n")
		else:
			f.store_string("%d problema(s) nas histórias:\n\n%s\n" % [erros.size(), "\n".join(erros)])
	return caminho


## Todas as falas de um personagem em todos os capítulos, com o nome do arquivo de voz
## que o jogo procura (audio/vozes/<arquivo>.ogg). [{arquivo, cena, texto}]
static func falas_de(quem: String) -> Array:
	var lista := []
	var vistos := {}
	for cap in Dados.capitulos():
		var jogador := Roteiro.nome(str(cap.get("jogador", "breno")))
		var cenas: Dictionary = cap.get("cenas", {})
		for id in cenas:
			var c = cenas[id]
			var passos: Array = c if c is Array else (c.get("passos", []) if c is Dictionary else [])
			_juntar_falas(Roteiro.preparar(passos), str(id), quem, jogador, lista, vistos)
	return lista


static func _juntar_falas(passos: Array, cena: String, quem: String, jogador: String, lista: Array, vistos: Dictionary) -> void:
	for p in passos:
		if not p is Dictionary:
			continue
		var q := ""
		var t := ""
		if p.has("texto") and p.has("quem"):
			q = str(p.quem)
			t = str(p.texto)
		elif p.has("escolha"):
			q = str(p.get("quem", "jogador"))
			t = str(p.escolha)
		elif p.has("dizer") or p.has("pensar"):
			q = str(p.get("dizer", p.get("pensar", "")))
			t = str(p.get("texto", ""))
		if q == "jogador":
			q = jogador
		if q == quem and t.strip_edges() != "":
			var arq := str(p.get("voz", "")) if p.has("voz") else Jogo.chave_voz(q, t)
			if not vistos.has(arq):
				vistos[arq] = true
				lista.append({"arquivo": arq, "cena": cena, "texto": t})
		for k in ["entao", "senao", "passos"]:
			if p.get(k) is Array:
				_juntar_falas(p[k], cena, quem, jogador, lista, vistos)
		if p.get("opcoes") is Array:
			for o in p.opcoes:
				if o is Dictionary and o.get("passos") is Array:
					_juntar_falas(o.passos, cena, quem, jogador, lista, vistos)


## Escreve VOZES_<QUEM>.txt ao lado do JOGO.exe: uma linha por fala, "arquivo | cena | texto".
static func gravar_lista_vozes(quem: String) -> String:
	var falas := falas_de(quem)
	var base := OS.get_executable_path().get_base_dir() if not OS.has_feature("editor") else OS.get_user_data_dir()
	var caminho := base.path_join("VOZES_%s.txt" % quem.to_upper())
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		caminho = OS.get_user_data_dir().path_join("VOZES_%s.txt" % quem.to_upper())
		f = FileAccess.open(caminho, FileAccess.WRITE)
	if f:
		f.store_line("// Falas de %s. Cada áudio vai em audio/vozes/<arquivo>.ogg (ou .wav) ao lado do JOGO.exe." % quem)
		f.store_line("// arquivo | cena | texto   (%d falas)" % falas.size())
		for x in falas:
			f.store_line("%s | %s | %s" % [x.arquivo, x.cena, x.texto])
	return caminho

