extends "res://testes/isolamento_v2.gd"
# Teste automático: herói e monstro NÃO entram andando nos objetos do Laboratório (v2/colisao.gd + Mundo.mover, o ponto único de movimento).
# Para cada forma (caixa ou elipse) de cada objeto do Laboratório, um corpo (herói, raio 6; monstro comum, raio 7) nasce a 60 px de cada um dos
# 4 lados e anda 2 s em direção ao centro da forma, só por mundo.mover(). Dois passes:
#  1) no mundo REAL (todas as formas juntas): o corpo termina fora da forma e livre de qualquer outra (nunca entra);
#  2) com a forma SOZINHA na colisão: o corpo para na face (folga pequena, nada de parar longe nem de atravessar) e, nas caixas, desliza ao
#     longo de cada fachada (anda de verdade ao longo dela, sem prender).
# (O Laboratório é denso: muitos casos começam presos em outra forma e são pulados.)
# Casos que a borda do mapa atrapalha (início fora da área andável) ou que já começam presos em outra forma são contados e pulados.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_laboratorio_colisao.tscn  (imprime "v2_laboratorio_colisao falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Colisao := preload("res://v2/colisao.gd")
const RAIOS := [6.0, 7.0]  # herói (dados/v2_herois.json) e monstro comum (dados/v2_combate.json)
const DIST := 60.0
const VEL := 150.0  # px/s
const DT := 1.0 / 60.0
const PASSOS := 120  # 2 s
const GAP_FACE := 1.5  # folga máxima (px, no espaço do chão) entre o corpo parado e a forma

var falhas := 0
var n_formas := 0
var n_real := 0
var n_pulados := 0
var n_face := 0
var n_deslizes := 0


class Corpo:
	extends RefCounted
	var pos := Vector2.ZERO
	var raio := 6.0

	func definir_pos(p: Vector2) -> void:
		pos = p


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		if falhas <= 40:
			print("FALHOU: ", msg)


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = "laboratorio"
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	var formas: Array = []  # {c: centro no mundo, m: meio (caixa) ou raio (elipse), caixa, obj}
	for a in w.cenario.objetos:
		if not w.cenario._itens.has(a.chave):
			continue
		for f in w.cenario._itens[a.chave].colisao:
			var caixa: bool = str(f.get("tipo", "")) == "caixa"
			var c: Array = f["centro"]
			var m: Array = f["meio"] if caixa else f["raio"]
			formas.append({"c": a.pos + Vector2(float(c[0]), float(c[1])), "m": Vector2(float(m[0]), float(m[1])), "caixa": caixa, "obj": a.chave})
	n_formas = formas.size()
	ok(n_formas >= 25, "o Laboratório tem formas de colisão (%d)" % n_formas)
	for f in formas:  # passe 1: mundo real
		_passe_real(w, f)
	for f in formas:  # passe 2: forma sozinha
		Colisao.limpar()
		Colisao.adicionar_objeto(Vector2.ZERO, [_json(f)])
		_passe_isolado(w, f)
	remove_child(w)
	w.free()
	ok(n_real > n_formas * 2, "o passe real rodou nos casos esperados (%d)" % n_real)
	ok(n_face > n_formas * 2, "o passe da face rodou nos casos esperados (%d)" % n_face)
	ok(n_deslizes >= 20, "houve deslizes em fachada (%d)" % n_deslizes)
	print(
		"formas=%d real=%d face=%d deslizes=%d pulados=%d em %.1f s" % [n_formas, n_real, n_face, n_deslizes, n_pulados, (Time.get_ticks_msec() - t0) / 1000.0]
	)
	print("v2_laboratorio_colisao falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _json(f: Dictionary) -> Dictionary:
	if f.caixa:
		return {"tipo": "caixa", "centro": [f.c.x, f.c.y], "meio": [f.m.x, f.m.y]}
	return {"tipo": "elipse", "centro": [f.c.x, f.c.y], "raio": [f.m.x, f.m.y]}


## Folga entre o corpo (elipse r x r/2) e a forma, no espaço do chão com o y escalado (corpo = círculo de raio r): negativa = dentro.
func _folga(f: Dictionary, p: Vector2, raio: float) -> float:
	var q: Vector2 = p - f.c
	if f.caixa:
		var qs := Vector2(q.x, q.y * 2.0)
		var meio := Vector2(f.m.x, f.m.y * 2.0)
		var d := qs - Vector2(clampf(qs.x, -meio.x, meio.x), clampf(qs.y, -meio.y, meio.y))
		if d.length() > 0.0001:
			return d.length() - raio
		return -minf(meio.x - absf(qs.x), meio.y - absf(qs.y)) - raio
	var k: float = f.m.x / f.m.y
	return Vector2(q.x, q.y * k).length() - f.m.x - raio


## Os 4 pontos de partida (relativos ao centro): DIST px além de cada face.
func _lados(f: Dictionary) -> Array:
	return [Vector2(-(f.m.x + DIST), 0), Vector2(f.m.x + DIST, 0), Vector2(0, -(f.m.y + DIST)), Vector2(0, f.m.y + DIST)]


func _andar(w, corpo: Corpo, alvo: Vector2) -> void:
	var parado := 0
	for _i in PASSOS:
		var d := alvo - corpo.pos
		if d.length() < 0.5:
			break
		var delta: Vector2 = w.mover(corpo, d.normalized() * minf(VEL * DT, d.length()))
		parado = parado + 1 if delta.length() < 0.001 else 0
		if parado >= 5:
			break


func _passe_real(w, f: Dictionary) -> void:
	for raio in RAIOS:
		for off in _lados(f):
			var corpo := Corpo.new()
			corpo.raio = raio
			corpo.pos = f.c + off
			if not w.limite_andavel.has_point(corpo.pos) or not Colisao.livre(corpo.pos, raio):
				n_pulados += 1
				continue
			n_real += 1
			_andar(w, corpo, f.c)
			var gap := _folga(f, corpo.pos, raio)
			ok(gap >= -0.05, "%s %s lado %s raio %.0f: o corpo entrou na forma (folga %.2f em %s)" % [f.obj, f.c, off, raio, gap, corpo.pos])
			ok(
				Colisao.livre(corpo.pos, raio) or not w.limite_andavel.has_point(corpo.pos),
				"%s %s lado %s: terminou dentro de outra forma (%s)" % [f.obj, f.c, off, corpo.pos]
			)


func _passe_isolado(w, f: Dictionary) -> void:
	for raio in RAIOS:
		for off in _lados(f):
			var corpo := Corpo.new()
			corpo.raio = raio
			corpo.pos = f.c + off
			var contato: Vector2 = f.c + off - off.normalized() * DIST
			if not w.limite_andavel.has_point(corpo.pos) or not w.limite_andavel.has_point(contato):
				n_pulados += 1
				continue
			n_face += 1
			_andar(w, corpo, f.c)
			var gap := _folga(f, corpo.pos, raio)
			ok(
				gap >= -0.05 and gap <= GAP_FACE,
				"%s %s lado %s raio %.0f: parou na face (folga %.2f, esperado 0..%.1f)" % [f.obj, f.c, off, raio, gap, GAP_FACE]
			)
		if f.caixa:
			_desliza(w, f, raio)


## Anda ao longo de cada fachada da caixa empurrando para dentro dela: tem que avançar pela fachada (sem prender) e nunca entrar.
func _desliza(w, f: Dictionary, raio: float) -> void:
	var meio: Vector2 = f.m
	# {início relativo ao centro, direção ao longo da fachada, direção para dentro da caixa, comprimento da fachada}
	var casos := [
		[Vector2(-meio.x, meio.y + 6.0), Vector2(1, 0), Vector2(0, -1), meio.x * 2.0],
		[Vector2(meio.x, -meio.y - 6.0), Vector2(-1, 0), Vector2(0, 1), meio.x * 2.0],
		[Vector2(-meio.x - 6.0, -meio.y), Vector2(0, 1), Vector2(1, 0), meio.y * 2.0],
		[Vector2(meio.x + 6.0, meio.y), Vector2(0, -1), Vector2(-1, 0), meio.y * 2.0],
	]
	for cs in casos:
		var ao_longo: Vector2 = cs[1]
		var para_dentro: Vector2 = cs[2]
		var comp: float = cs[3]
		var corpo := Corpo.new()
		corpo.raio = raio
		corpo.pos = f.c + cs[0]
		var passos := mini(PASSOS, int(comp / (VEL * DT * 0.8)))
		var fim: Vector2 = corpo.pos + ao_longo * comp
		if passos < 10 or not w.limite_andavel.has_point(corpo.pos) or not w.limite_andavel.has_point(fim):
			n_pulados += 1
			continue
		var inicio := corpo.pos
		var dentro := false
		for _i in passos:
			w.mover(corpo, (ao_longo * 0.8 + para_dentro * 0.6) * VEL * DT)
			if _folga(f, corpo.pos, raio) < -0.05:
				dentro = true
		var andou := (corpo.pos - inicio).dot(ao_longo)
		var esperado := passos * VEL * DT * 0.8
		n_deslizes += 1
		ok(not dentro, "%s %s fachada %s raio %.0f: o corpo entrou ao deslizar" % [f.obj, f.c, ao_longo, raio])
		ok(andou >= esperado * 0.7, "%s %s fachada %s raio %.0f: prendeu (andou %.1f de %.1f px ao longo)" % [f.obj, f.c, ao_longo, raio, andou, esperado])
