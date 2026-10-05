extends Node
## Alunos de fundo (figurantes): deixam a faculdade movimentada.
## Tudo vem de capitulos/figurantes.json: quais bonecos existem, quantos aparecem em cada mapa
## e o que fazem ("andar", "grupo", "parado", "sentado" nas carteiras, "pc" nos computadores),
## e as falinhas que soltam quando o Breno aperta E perto deles.
## Eles não bloqueiam ninguém, não entram nas cenas e congelam enquanto uma cena toca.
## Num capítulo, "figurantes": false desliga.

const Personagem := preload("res://scripts/personagem.gd")

var mundo: Node
var _lista: Array = []          # Personagem com meta "fig" = {tipo, sexo, ...}
var _dados: Dictionary = {}
var _mauro_t := 12.0


func _defs() -> Dictionary:
	if _dados.is_empty():
		var d = Dados.ler_json("figurantes.json")
		_dados = d if d is Dictionary else {"mapas": {}}
	return _dados


## Põe os figurantes do mapa que acabou de carregar (os antigos somem junto com a cena).
func montar(mapa_id: String, mapa_dados: Dictionary, cena: Node) -> void:
	_lista.clear()
	if not mundo.capitulo.get("figurantes", true):
		return
	var defs := _defs()
	var bonecos: Dictionary = defs.get("bonecos", {})
	var usados := {}
	var grupos: Array = defs.get("mapas", {}).get(mapa_id, [])
	for g in grupos:
		if not mundo.condicao_ok(g.get("requer", [])):
			continue
		var tipo: String = g.get("tipo", "andar")
		var lugares: Array = []
		match tipo:
			"sentado":
				for o in mapa_dados.get("objetos", []):
					if str(o.get("imagem", "")).contains(str(g.get("objeto", "carteira"))):
						var l := Vector2(o.x, float(o.y) + float(g.get("dy", -4)))
						if mundo._npcs.all(func(n): return n.position.distance_to(l) > 34.0):
							lugares.append(l)
				lugares.shuffle()
			"pc", "parado":
				for p in g.get("lugares", []):
					lugares.append(Vector2(p[0], p[1]))
				lugares.shuffle()
			"grupo":
				var c := Vector2(g.get("x", 0), g.get("y", 0))
				var n := int(g.get("n", 3))
				for i in n:
					var ang := TAU * i / n + randf_range(-0.3, 0.3)
					lugares.append(c + Vector2(cos(ang) * 15.0, sin(ang) * 8.0))
			_:
				for i in int(g.get("n", 2)):
					var p := _ponto_livre(Vector2.ZERO, 9999.0)
					if p != Vector2.INF:
						lugares.append(p)
		var n_max := int(g.get("n", lugares.size()))
		if Visual.qualidade() == "baixa":   # PC fraco: menos gente em cada grupo
			n_max = mini(n_max, 2)
		for i in mini(n_max, lugares.size()):
			var sexo: String = g.get("sexo", ["aluno", "aluna"].pick_random())
			var opcoes: Array = bonecos.get(sexo, []).filter(func(b): return not usados.has(b))
			if opcoes.is_empty():
				opcoes = bonecos.get(sexo, [])
			if opcoes.is_empty():
				continue
			var boneco: String = opcoes.pick_random()
			usados[boneco] = true
			var f := Personagem.new()
			f.position = lugares[i]
			var dir: String = g.get("dir", "cima" if tipo in ["sentado", "pc"] else ["baixo", "esquerda", "direita"].pick_random())
			f.configurar(boneco, dir)
			if tipo == "grupo":
				f.olhar_para(Vector2(g.get("x", 0), g.get("y", 0)))
			f.set_meta("fig", {"tipo": tipo, "sexo": sexo, "mapa": mapa_id, "t": randf_range(1.0, 5.0)})
			f.set_meta("dados", {"dica": "Falar"})
			f.set_meta("figurante", true)
			f.modulate = Color(0.97, 0.97, 0.97)
			cena.add_child(f)
			if tipo in ["sentado", "pc"]:
				_sentar(f, float(g.get("sobe", 0)))
			_lista.append(f)
	_mauro_t = randf_range(6.0, 12.0)


## Sentado de costas: só cabeça e tronco (o encosto da cadeira esconde o resto).
## "sobe" levanta o desenho uns pixels (carteira com encosto alto).
func _sentar(f: Node2D, sobe: float) -> void:
	f.set_process(false)
	f.sombra = false
	f.queue_redraw()
	var s: Sprite2D = f._spr
	s.hframes = 1
	s.vframes = 1
	s.frame = 0
	s.region_enabled = true
	s.region_rect = Rect2(0, 3 * 60, 44, 44)
	s.offset = Vector2(-22, -58 - sobe)


## Ponto do mapa onde dá pra ficar em pé (perto de "de", até "raio" de distância).
func _ponto_livre(de: Vector2, raio: float) -> Vector2:
	var m = mundo._mapa
	for k in 20:
		var p: Vector2
		if raio > 5000.0:
			p = Vector2(randf_range(m.limites.position.x + 10, m.limites.end.x - 10),
				randf_range(m.limites.position.y + 10, m.limites.end.y - 6))
		else:
			p = de + Vector2(randf_range(-raio, raio), randf_range(-raio * 0.6, raio * 0.6))
		if _livre(p) and (raio > 5000.0 or _caminho_livre(de, p)):
			return p
	return Vector2.INF


func _livre(p: Vector2) -> bool:
	if mundo._mapa.bloqueia(Rect2(p.x - 7, p.y - 5, 14, 5)):
		return false
	for n in mundo._npcs:
		if is_instance_valid(n) and n.position.distance_to(p) < 22.0:
			return false
	for porta in mundo._mapa.portas:
		if porta.rect.grow(14).has_point(p):
			return false
	return true


func _caminho_livre(a: Vector2, b: Vector2) -> bool:
	var passos := int(a.distance_to(b) / 6.0) + 1
	for i in passos + 1:
		if not _livre(a.lerp(b, float(i) / passos)):
			return false
	return true


## Para todo mundo (quando começa uma cena).
func parar() -> void:
	for f in _lista:
		if is_instance_valid(f):
			f.andando = false


func atualizar(delta: float) -> void:
	for f in _lista:
		if not is_instance_valid(f):
			continue
		var info: Dictionary = f.get_meta("fig")
		info.t -= delta
		match info.tipo:
			"andar":
				_andar(f, info, delta)
			"grupo":
				if info.t <= 0.0:
					info.t = randf_range(3.0, 8.0)
					if Visual.ligado():
						if randf() < 0.35:
							f.pular(3.0)
						else:
							f.balao(["...", "!", "?", "musica", "...", "!!"].pick_random(), 1.2)
			"pc":
				if Visual.ligado():
					var dig: bool = fmod(info.t, 4.0) < 2.5
					f._spr.position.x = 1.0 if dig and int(info.t * 9.0) % 2 == 0 else 0.0
	_mauro(delta)


func _andar(f: Node2D, info: Dictionary, delta: float) -> void:
	if not info.has("alvo"):
		if info.t > 0.0:
			f.andando = false
			return
		var p := _ponto_livre(f.position, 110.0)
		if p == Vector2.INF:
			info.t = 1.5
			return
		info["alvo"] = p
	var alvo: Vector2 = info.alvo
	var v := alvo - f.position
	if v.length() < 2.0:
		info.erase("alvo")
		info.t = randf_range(1.5, 6.0)
		f.andando = false
		f._atualizar()
		return
	var passo := v.normalized() * 34.0 * delta
	var prox: Vector2 = f.position + passo
	if not _livre(prox):
		info.erase("alvo")
		info.t = 0.8
		f.andando = false
		return
	f.position = prox
	f.andando = true
	if abs(v.x) > abs(v.y):
		f.dir = "direita" if v.x > 0 else "esquerda"
	else:
		f.dir = "baixo" if v.y > 0 else "cima"


## Figurante mais perto do jogador (ou null).
func alvo(pos: Vector2, alcance: float) -> Node2D:
	var melhor: Node2D = null
	var menor := alcance
	for f in _lista:
		if not is_instance_valid(f):
			continue
		var d := Vector2(f.position.x - pos.x, (f.position.y - pos.y) * 1.3).length()
		if d < menor:
			menor = d
			melhor = f
	return melhor


## E perto de um figurante: ele solta uma falinha (balão no mapa, some sozinho).
func falar(f: Node2D) -> void:
	var info: Dictionary = f.get_meta("fig")
	if info.has("alvo"):
		info.erase("alvo")
	info.t = 3.0
	f.andando = false
	if info.tipo in ["andar", "parado", "grupo"]:
		f.olhar_para(mundo._jogador.position)
	var falas: Dictionary = _defs().get("falas", {})
	var lista: Array = []
	lista.append_array(falas.get(info.sexo, []))
	lista.append_array(falas.get(info.tipo, []))
	lista.append_array(falas.get("mapa:" + str(info.mapa), []))
	if lista.is_empty():
		return
	var ultima: String = f.get_meta("ultima_fala", "")
	var texto: String = lista.pick_random()
	if texto == ultima and lista.size() > 1:
		texto = lista.pick_random()
	f.set_meta("ultima_fala", texto)
	Jogo.som("blip", -6.0, 0.15)
	dizer(f, texto, 2.8)


## Balão de fala no mapa que some sozinho (não trava o jogo).
func dizer(quem: Node2D, texto: String, tempo := 2.6) -> void:
	if not is_instance_valid(quem):
		return
	var velho = quem.get_node_or_null("FalaFig")
	if velho:
		velho.free()
	var n := Node2D.new()
	n.name = "FalaFig"
	n.z_index = 60
	var l: Label = quem._rotulo(texto, Color.WHITE, 150)
	n.add_child(l)
	quem.add_child(n)
	await get_tree().process_frame
	if not is_instance_valid(l):
		return
	l.position = Vector2(-l.size.x / 2, -70 - l.size.y)
	await get_tree().create_timer(tempo).timeout
	if is_instance_valid(n):
		n.queue_free()


## O Seu Mauro não vê uma aluna passar sem soltar uma cantada (das inocentes).
func _mauro(delta: float) -> void:
	var m = mundo.personagem("mauro")
	if m == null or not m.visible:
		return
	_mauro_t -= delta
	if _mauro_t > 0.0:
		return
	_mauro_t = randf_range(14.0, 24.0)
	var perto: Node2D = null
	for f in _lista:
		if is_instance_valid(f) and f.get_meta("fig").sexo == "aluna" and f.position.distance_to(m.position) < 110.0:
			perto = f
			break
	if perto == null:
		_mauro_t = randf_range(4.0, 8.0)
		return
	var d := _defs()
	var cantadas: Array = d.get("mauro_cantadas", [])
	var reacoes: Array = d.get("reacoes_aluna", [])
	if cantadas.is_empty():
		return
	m.olhar_para(perto.position)
	dizer(m, cantadas.pick_random(), 3.2)
	await get_tree().create_timer(1.8).timeout
	if is_instance_valid(perto) and not reacoes.is_empty():
		perto.olhar_para(m.position)
		var r: String = reacoes.pick_random()
		if r in ["raiva", "suor", "...", "?!", "!!"]:
			perto.balao(r, 1.4)
		else:
			dizer(perto, r, 2.4)
