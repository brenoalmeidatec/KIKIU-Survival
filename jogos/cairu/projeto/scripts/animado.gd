extends Node2D
## Detalhe animado do cenário (lista "animados" no mapa). Fica no meio das pessoas e
## móveis, ordenado pela "base" (o pé do móvel em que ele está), então quem passa na
## frente cobre o monitor, e quem passa atrás fica atrás.
##
## Tipos: tela, led, relogio, bolhas, nuvens, papel, brilho, tremeluz, letreiro, globo.
## Veja a seção ANIMAÇÕES DO CENÁRIO no LEIA-ME.

var d: Dictionary = {}
var tipo := ""
var r := Rect2()
var _t := 0.0
var _rnd := RandomNumberGenerator.new()
var _linhas: Array = []     # tela de código: [largura, cor]
var _estado := 0.0          # usado por cada tipo do seu jeito


func configurar(dados: Dictionary) -> void:
	d = dados
	tipo = str(d.get("tipo", "led"))
	var base: float = float(d.get("base", float(d.get("y", 0)) + float(d.get("h", 0))))
	position = Vector2(0, base)
	r = Rect2(float(d.get("x", 0)), float(d.get("y", 0)) - base, float(d.get("w", 4)), float(d.get("h", 4)))
	_rnd.seed = hash(str(d))
	_t = _rnd.randf() * 10.0
	if tipo == "tela":
		for i in 12:
			_linhas.append(_linha_codigo())
	if tipo == "tremeluz" or tipo == "letreiro" or tipo == "brilho":
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m


func _linha_codigo() -> Array:
	var cores := ["#7ee787", "#79c0ff", "#ff7b72", "#d2a8ff", "#e6edf3", "#ffa657"]
	return [_rnd.randi_range(2, int(max(r.size.x - 4, 3))), Color(cores[_rnd.randi() % cores.size()]), _rnd.randi_range(0, 4)]


func _process(delta: float) -> void:
	if not Visual.ligado():
		if visible:
			visible = false
		return
	visible = true
	_t += delta
	queue_redraw()


func _draw() -> void:
	match tipo:
		"tela": _tela()
		"led": _led()
		"relogio": _relogio()
		"bolhas": _bolhas()
		"nuvens": _nuvens()
		"papel": _papel()
		"brilho": _brilho()
		"tremeluz": _tremeluz()
		"letreiro": _letreiro()
		"globo": _globo()


# ---------------------------------------------------------------- monitores
func _tela() -> void:
	var estilo := str(d.get("estilo", "codigo"))
	match estilo:
		"chiado":   # monitor quebrado: chuvisco e linha rolando
			for y in int(r.size.y):
				for x in range(0, int(r.size.x), 2):
					var v := _rnd.randf()
					if v > 0.55:
						draw_rect(Rect2(r.position + Vector2(x, y), Vector2(2, 1)), Color(1, 1, 1, v * 0.5))
			var ly := fmod(_t * 12.0, r.size.y)
			draw_rect(Rect2(r.position.x, r.position.y + ly, r.size.x, 1), Color(1, 1, 1, 0.35))
		"verde":    # tela de terminal velho
			draw_rect(r, Color(0.05, 0.12, 0.06))
			var n := int(_t * 3.0) % 6
			for i in n:
				draw_rect(Rect2(r.position + Vector2(2, 2 + i * 2), Vector2(_rnd.randi_range(3, int(r.size.x) - 4), 1)), Color("4bd06a"))
			if int(_t * 2.0) % 2 == 0:
				draw_rect(Rect2(r.position + Vector2(2, 2 + n * 2), Vector2(2, 1)), Color("4bd06a"))
		"brilho":   # só a tela ligada, com reflexo passando
			var x := fmod(_t * 6.0, r.size.x + 16) - 8
			draw_rect(Rect2(r.position.x + clampf(x, 0, r.size.x - 1), r.position.y, 2, r.size.y), Color(1, 1, 1, 0.25))
			draw_rect(r, Color(1, 1, 1, 0.04 + 0.03 * sin(_t * 9.0)))
		_:          # código rolando
			draw_rect(r, Color("0d1117"))
			var passo := 2
			var linhas := int(r.size.y / passo) - 1
			var rolou := int(_t * 4.0)
			while _linhas.size() < rolou + linhas + 2:
				_linhas.append(_linha_codigo())
			for i in linhas:
				var l: Array = _linhas[rolou + i]
				var w: int = mini(int(l[0]), int(r.size.x) - 3 - l[2])
				draw_rect(Rect2(r.position + Vector2(1 + l[2], 1 + i * passo), Vector2(w, 1)), l[1])
			if _linhas.size() > 400:
				_linhas = _linhas.slice(rolou)
				_t = fmod(_t, 0.25)
			if int(_t * 2.5) % 2 == 0:
				draw_rect(Rect2(r.position + Vector2(2, r.size.y - 2), Vector2(2, 1)), Color.WHITE)
	# brilho da tela no vidro
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.12))


func _led() -> void:
	var ritmo := float(d.get("ritmo", 1.0))
	var aceso := fmod(_t * ritmo, 1.0) < float(d.get("ligado", 0.5))
	var cor := Color(str(d.get("cor", "#4bd06a")))
	draw_rect(r, cor if aceso else cor.darkened(0.7))
	if aceso:
		draw_rect(r.grow(1), Color(cor, 0.25))


# ---------------------------------------------------------------- relógio
func _relogio() -> void:
	var c := r.position
	var raio := float(d.get("r", 9))
	draw_circle(c, raio, Color.WHITE)
	for k in 12:
		var a := k * TAU / 12.0
		draw_rect(Rect2(c + Vector2(cos(a), sin(a)) * (raio - 2) - Vector2(0.5, 0.5), Vector2(1, 1)), Color("8b9bb4"))
	var hora := Time.get_time_dict_from_system()
	var seg := float(hora.second)
	var minu := float(hora.minute) + seg / 60.0
	var hr := fmod(float(hora.hour), 12.0) + minu / 60.0
	_ponteiro(c, hr / 12.0 * TAU, raio * 0.5, Color("181425"), 2.0)
	_ponteiro(c, minu / 60.0 * TAU, raio * 0.8, Color("181425"), 1.0)
	_ponteiro(c, seg / 60.0 * TAU, raio * 0.85, Color("e43b44"), 1.0)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color("181425"))


func _ponteiro(c: Vector2, ang: float, tam: float, cor: Color, larg: float) -> void:
	var fim := c + Vector2(sin(ang), -cos(ang)) * tam
	draw_line(c, fim, cor, larg)


# ---------------------------------------------------------------- bebedouro
func _bolhas() -> void:
	# de vez em quando sobe um "glub" de bolhas no galão
	var ciclo := fmod(_t, 4.0)
	if ciclo > 1.6:
		return
	for i in 5:
		var tt := ciclo - i * 0.18
		if tt < 0.0 or tt > 1.0:
			continue
		var y := r.end.y - tt * r.size.y
		var x := r.position.x + r.size.x * (0.3 + 0.4 * fmod(i * 0.37, 1.0)) + sin(tt * 12.0 + i) * 1.5
		var raio := 1.0 + (i % 2)
		draw_circle(Vector2(x, y), raio, Color(1, 1, 1, 0.75))
		draw_circle(Vector2(x, y), raio - 0.5, Color(0.75, 0.9, 1, 0.6))


# ---------------------------------------------------------------- janela com nuvens
func _nuvens() -> void:
	var vel := float(d.get("velocidade", 3.0))
	for i in 3:
		var w := 10.0 + i * 3.0
		var x := fmod(_t * vel * (0.6 + i * 0.25) + i * 31.0, r.size.x + w) - w
		var y := r.position.y + 2 + (i * 5) % int(max(r.size.y - 6, 1))
		var x0 := r.position.x + x
		var a := maxf(r.position.x, x0)
		var b := minf(r.end.x, x0 + w)
		if b > a:
			draw_rect(Rect2(a, y, b - a, 3), Color.WHITE)
		var a2 := maxf(r.position.x, x0 + 3)
		var b2 := minf(r.end.x, x0 + w - 3)
		if b2 > a2:
			draw_rect(Rect2(a2, y - 2, b2 - a2, 2), Color.WHITE)
	for cx in d.get("colunas", []):   # caixilhos da janela por cima das nuvens
		draw_rect(Rect2(float(cx), r.position.y, 1, r.size.y), Color(str(d.get("cor_coluna", "#8b9bb4"))))
		draw_rect(Rect2(float(cx) + 1, r.position.y, 1, r.size.y), Color.WHITE)


# ---------------------------------------------------------------- papel no mural
func _papel() -> void:
	# a pontinha de baixo do papel levanta com o vento do ar-condicionado
	var s := maxf(sin(_t * float(d.get("ritmo", 2.2))), 0.0)
	var dobra := int(round(s * 3.0))
	if dobra <= 0:
		return
	var p := r.end
	var cor := Color(str(d.get("cor", "#fbfbf2")))
	draw_rect(Rect2(p.x - dobra - 1, p.y - dobra - 1, dobra + 1, dobra + 1), Color("c28569"))
	for k in dobra:
		draw_rect(Rect2(p.x - dobra - 1 + k, p.y - dobra - 2 - k + dobra, 1, k + 1), cor.darkened(0.15))


# ---------------------------------------------------------------- brilho (estrelinha)
func _brilho() -> void:
	var periodo := float(d.get("periodo", 4.0))
	var f := fmod(_t, periodo) / 0.6
	if f > 1.0:
		return
	var tam := sin(f * PI) * float(d.get("tam", 4.0))
	var c := r.position
	var cor := Color(str(d.get("cor", "#fff6c8")))
	draw_rect(Rect2(c.x - tam, c.y, tam * 2 + 1, 1), cor)
	draw_rect(Rect2(c.x, c.y - tam, 1, tam * 2 + 1), cor)
	draw_rect(Rect2(c.x - 1, c.y - 1, 3, 3), Color(cor, 0.5))


# ---------------------------------------------------------------- luz tremendo
func _tremeluz() -> void:
	var cor := Color(str(d.get("cor", "#ffffff")))
	var forca := float(d.get("forca", 0.08))
	var a := forca * (0.8 + 0.2 * sin(_t * 31.0))
	# lâmpada velha: às vezes dá umas piscadas
	var ciclo := fmod(_t, float(d.get("periodo", 7.0)))
	if ciclo < 0.5 and int(ciclo * 20.0) % 3 == 0:
		a = 0.0
	draw_rect(r, Color(cor, a))


# ---------------------------------------------------------------- letreiro com lâmpadas
func _letreiro() -> void:
	var cor := Color(str(d.get("cor", "#feae34")))
	var passo := 6.0
	var pts: Array = []
	var x := r.position.x
	while x <= r.end.x:
		pts.append(Vector2(x, r.position.y))
		x += passo
	var y := r.position.y
	while y <= r.end.y:
		pts.append(Vector2(r.end.x, y))
		y += passo
	x = r.end.x
	while x >= r.position.x:
		pts.append(Vector2(x, r.end.y))
		x -= passo
	y = r.end.y
	while y >= r.position.y:
		pts.append(Vector2(r.position.x, y))
		y -= passo
	var vez := int(_t * 6.0)
	for i in pts.size():
		if (i + vez) % 3 == 0:
			draw_rect(Rect2(pts[i] - Vector2(1, 1), Vector2(2, 2)), cor)
			draw_rect(Rect2(pts[i] - Vector2(2, 2), Vector2(4, 4)), Color(cor, 0.25))


# ---------------------------------------------------------------- globo girando
func _globo() -> void:
	var c := r.position
	var raio := float(d.get("r", 8))
	var gira := _t * 0.8
	for k in 4:
		var fase := fmod(gira + k * 0.25, 1.0)
		var x := c.x + (fase * 2.0 - 1.0) * raio
		var lado := sqrt(maxf(raio * raio - pow(x - c.x, 2), 0.0))
		if lado < 1.5:
			continue
		var h := lado * 0.6
		draw_rect(Rect2(x - 1.5, c.y - h + (k % 2) * 2 - 1, 3, h * 0.9), Color("63c74d"))
	draw_arc(c, raio, 0, TAU, 20, Color(1, 1, 1, 0.12), 1.0)
