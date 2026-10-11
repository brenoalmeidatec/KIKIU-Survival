extends Node2D
const Perf := preload("res://scripts/hordas/perf.gd")
## Finalização de chefe (#32): quando o chefe morre, o golpe final depende da arma que deu a última pancada
## (dados/finalizacoes.json): katana = corte em X que parte o chefe, pistolas = rajada que fura, arte marcial =
## soco que lança e quebra, aura = coluna cobalto que desintegra, elemental = fogo + gelo + raio, o resto = explosão.
## Sozinho: câmera lenta curta e zoom (Engine.time_scale e camera.zoom, restaurados SEMPRE: no fim, ao iniciar outra,
## e no _exit_tree da arena). Online: só o desenho, sem câmera lenta e sem zoom. Tudo usa tempo REAL (ticks).
## O corpo do chefe reaproveita os efeitos de mortes.gd (corte, furo, pedaços, desintegrar, estilhaço) com um
## registro próprio, sem teto (é um por vez). Reduzida (opção Mortes violentas): coluna de luz, corpo só some.

const Mortes := preload("res://scripts/hordas/mortes.gd")

var arena: Node
var _ativo := false
var _t := 0.0
var _ultimo := 0
var _cfg: Dictionary = {}
var _chave := ""
var _rec: Dictionary = {}       # registro do corpo do chefe (Mortes.registro)
var _t0 := 0.0                  # quando o corpo passa do "parado" pro efeito de morte
var _jog := Vector2.ZERO        # de onde veio o golpe (o jogador)
var _dir := Vector2.RIGHT       # do jogador pro chefe
var _pos := Vector2.ZERO
var _mix := 0.0
var _zoom := 1.0
var _bateu := 0
var _ts_salvo := 1.0
var _ts_preso := false
var _zoom_salvo := Vector2.ONE
var _zoom_preso := false
var iniciadas := 0              # quantas finalizações já começaram (o teste lê)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # conta o tempo real mesmo com carta/mapa abertos (aí congela e solta o tempo)
	z_index = 4


# ---------- escolha (pura, testada sem desenhar) ----------

## Chave de `finalizacoes` pra uma arma: tabela por arma, senão pela causa (família), senão global.
static func chave_de(arma: String) -> String:
	var d: Dictionary = Dados.json("finalizacoes")
	if d.get("por_arma", {}).has(arma):
		return str(d.por_arma[arma])
	var causa := Mortes.causa_de(arma)
	return str(d.get("por_causa", {}).get(causa, "global"))


func ativa() -> bool:
	return _ativo


func chave() -> String:
	return _chave


## Onde a câmera deve ficar: no foco normal ou perto do chefe que está caindo.
func camera(foco: Vector2) -> Vector2:
	return foco.lerp(_pos, _mix * 0.6) if _ativo and _mix > 0.0 else foco


# ---------- ciclo de vida ----------

## O chefe `v` (V de inimigos.gd, já fora da lista) morreu.
func iniciar(v) -> void:
	if arena.acabou or arena.duelo_ativo:
		return
	if _ativo:
		restaurar()
	var arma := str(v.arma_ult)
	if arma == "" and arena.armas and not arena.armas.ativas().is_empty():
		arma = str(arena.armas.ativas()[0].id)   # kill remoto (online) ou sem arma: a arma que o jogador usa
	var red := Mortes.reduzida()
	_chave = chave_de(arma)
	_cfg = Dados.json("finalizacoes").get("finalizacoes", {}).get(_chave, Dados.json("finalizacoes").finalizacoes.global)
	var golpe := "coluna_suave" if red else str(_cfg.golpe)
	var causa := Mortes.causa_de(arma, str(v.causa_ult))
	var ef := "suave"
	var t0 := 0.3
	match golpe:
		"x_katana":
			ef = "corte"; t0 = 0.3; causa = "corte"
		"rajada":
			ef = "furo"; t0 = 0.85; causa = "tiro"
		"soco":
			ef = "pedacos"; t0 = 0.55; causa = "explosao"
		"coluna":
			ef = "desintegrar"; t0 = 0.4; causa = "aura"
		"elemental":
			ef = "estilhaco"; t0 = 1.0; causa = "gelo"
		"global":
			ef = "pedacos"; t0 = 0.22; causa = "explosao"
		_:
			ef = "suave"; t0 = 0.35
	_t0 = t0
	var dur: float = float(_cfg.dur)
	_rec = Mortes.registro(v, causa, ef, 1.0)
	_rec.dur = maxf(0.4, dur - t0 - 0.1)
	_rec.t = 0.0
	_pos = v.pos + Vector2(0, -16)
	_jog = arena.jogador.centro() if arena.jogador else v.pos - Vector2(80, 0)
	_dir = (v.pos - _jog).normalized() if v.pos.distance_to(_jog) > 1.0 else Vector2.RIGHT
	_rec.dir = _dir
	if golpe == "x_katana":
		_rec.th = -0.62 if _dir.x >= 0.0 else 0.62   # o corte segue a primeira diagonal do X
		_rec.n_gotas = 26
	_t = 0.0
	_bateu = 0
	_mix = 0.0
	_ultimo = Time.get_ticks_usec()
	_ativo = true
	iniciadas += 1
	_cfg = _cfg.duplicate()
	_cfg.golpe = golpe
	Som.tocar("whoosh", 0.0, 0.6)
	set_process(true)


func _process(_dt: float) -> void:
	if not _ativo:
		return
	var agora := Time.get_ticks_usec()
	var dt := minf(0.1, (agora - _ultimo) / 1.0e6)
	_ultimo = agora
	var pausado := is_inside_tree() and get_tree().paused
	if not pausado:
		_t += dt
	var dur: float = float(_cfg.dur)
	var fim := smoothstep(dur - 0.5, dur, _t)
	_mix = smoothstep(0.0, 0.3, _t) * (1.0 - fim)
	_zoom = 1.0
	if not arena.eh_online:
		_zoom = 1.0 + (float(_cfg.zoom) - 1.0) * _mix
		_aplicar_zoom(_zoom)
		_tempo(pausado)
	_rec.t = maxf(0.0, _t - _t0)
	if _rec.t > 0.0 and str(_cfg.golpe) == "elemental":
		_rec.t += 0.2 * float(_rec.dur)   # já chegou congelado: pula a fase parada do estilhaço
	_eventos()
	if _t >= dur or arena.acabou:
		restaurar()
	queue_redraw()


## Câmera lenta só sozinho: segura em `lento` até `lento_ate` e volta suave; pausado, volta ao normal.
func _tempo(pausado: bool) -> void:
	if not _ts_preso:
		_ts_salvo = Engine.time_scale
		_ts_preso = true
	var f := 1.0
	if not pausado:
		var lento := float(_cfg.lento)
		var ate := float(_cfg.lento_ate)
		if _t < ate:
			f = lento
		elif _t < ate + 0.4:
			f = lerpf(lento, 1.0, smoothstep(0.0, 1.0, (_t - ate) / 0.4))
	Engine.time_scale = _ts_salvo * f


func _aplicar_zoom(z: float) -> void:
	if not _zoom_preso:
		_zoom_salvo = arena.camera.zoom
		_zoom_preso = true
	arena.camera.zoom = Vector2(z, z)


## Devolve o tempo e a câmera ao normal. Fim da finalização, nova finalização e _exit_tree da arena.
func restaurar() -> void:
	if _ts_preso:
		Engine.time_scale = _ts_salvo
		_ts_preso = false
	if _zoom_preso:
		if is_instance_valid(arena) and arena.camera:
			arena.camera.zoom = _zoom_salvo
		_zoom_preso = false
	_ativo = false
	_mix = 0.0
	queue_redraw()


func _exit_tree() -> void:
	restaurar()


## Tremida e som nos tempos do golpe (a arena respeita a opção "Tremer a tela").
func _eventos() -> void:
	var fr := float(_cfg.tremor)
	var marcos: Array = [_t0 * 0.5 if str(_cfg.golpe) in ["rajada", "elemental"] else 0.0, _t0]
	if _bateu < 1 and _t >= float(marcos[0]):
		_bateu = 1
		arena.tremer(fr * 0.5)
		match str(_cfg.golpe):
			"x_katana", "rajada": Som.tocar("acerto", 0.0, 1.4, -4)
			"soco": Som.tocar("soco", 0.0, 0.7)
			_: Som.tocar("tremor", 0.0, 1.2, -6)
	if _bateu < 2 and _t >= _t0:
		_bateu = 2
		arena.tremer(fr)
		Som.tocar("tremor", 0.0, 0.9, -2)
		if str(_cfg.golpe) in ["soco", "global", "x_katana"]:
			Som.tocar("queda", 0.0, 0.8, -4)


# ---------- desenho ----------

func _draw() -> void:
	var _pp := Perf.ini()
	_draw_i()
	Perf.fim("fin_d", _pp)


func _draw_i() -> void:
	if not _ativo or _rec.is_empty():
		return
	var golpe := str(_cfg.golpe)
	var cor: Color = Color(_cfg.cor[0], _cfg.cor[1], _cfg.cor[2])
	var s: Vector2 = _rec.sz
	var pe: Vector2 = Mortes._pe(_rec)
	var meio := pe + Vector2(0, -s.y * 0.5)
	match golpe:
		"x_katana": _x_katana(cor, s, meio)
		"rajada": _rajada(cor, s, pe, meio)
		"soco": _soco(cor, s, pe, meio)
		"coluna", "coluna_suave": _coluna(cor, s, pe, meio)
		"elemental": _elemental(s, pe, meio)
		_: _global(cor, s, pe, meio)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _corpo_parado(cor: Color, quadro := -1, off := Vector2.ZERO) -> void:
	Mortes._corpo(self, _rec, off, 0.0, 1.0, 1.0, cor, quadro)


func _clarao(forca_base: float) -> void:
	var forca := forca_base * float(Config.g("tremor_clarao")) / 100.0   # aba Gráficos: 0 a 100% dos clarões
	if forca <= 0.0:
		return
	var c: Vector2 = arena.camera.position if arena and arena.camera else _pos
	draw_rect(Rect2(c - Vector2(700, 450), Vector2(1400, 900)), Color(1, 1, 1, clampf(forca, 0.0, 1.0)))


## Raio irregular de um ponto a outro, com brilho.
func _zigue(a: Vector2, b: Vector2, semente: int, cor: Color, larg := 1.0) -> void:
	var pts := PackedVector2Array([a])
	var n := 7
	var perp := (b - a).orthogonal().normalized()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + perp * (Mortes._h(semente, i) - 0.5) * 18.0)
	pts.append(b)
	draw_polyline(pts, Color(cor.r, cor.g, cor.b, 0.35), larg * 4.0)
	draw_polyline(pts, Color(1, 1, 1, 0.95), larg)


func _linha_golpe(a: Vector2, b: Vector2, k: float, cor: Color) -> void:
	# traço de espada que cresce de `a` até `b` (k 0..1) e some
	var p := a.lerp(b, smoothstep(0.0, 1.0, minf(1.0, k * 3.0)))
	var al := 1.0 - smoothstep(0.4, 1.0, k)
	draw_line(a, p, Color(cor.r, cor.g, cor.b, 0.35 * al), 8.0)
	draw_line(a, p, Color(1, 1, 1, al), 3.0)


func _x_katana(cor: Color, s: Vector2, meio: Vector2) -> void:
	var t := _t
	if t < _t0:
		_corpo_parado(Color(1.4, 1.4, 1.5) if int(t * 40.0) % 2 == 0 else Color(0.5, 0.5, 0.6), 2 if t < 0.1 else -1)
	else:
		Mortes.desenhar(self, _rec)
	var L := maxf(s.x, s.y) * 1.1
	var sg := 1.0 if _dir.x >= 0.0 else -1.0
	var d1 := Vector2.from_angle(-0.62 * sg)   # mesma diagonal do corte do corpo
	var d2 := Vector2(-d1.x, d1.y)               # espelhada: forma o X
	if t < 0.9:
		_linha_golpe(meio - d1 * L, meio + d1 * L, t / 0.5, cor)
	if t > 0.1 and t < 1.0:
		_linha_golpe(meio - d2 * L, meio + d2 * L, (t - 0.1) / 0.5, cor)
	if t >= _t0 and t < _t0 + 0.2:
		_clarao(0.55 * (1.0 - (t - _t0) / 0.2))
		var k := (t - _t0) / 0.2
		draw_arc(meio, s.x * (0.3 + 0.9 * k), 0.0, TAU, 28, Color(1, 1, 1, 0.6 * (1.0 - k)), 2.0)


func _rajada(cor: Color, s: Vector2, pe: Vector2, meio: Vector2) -> void:
	var t := _t
	var sd: int = _rec.seed
	var tiros := 12
	var shake := Vector2.ZERO
	if t < _t0:
		var passo := int(t * 30.0)
		shake = Vector2((Mortes._h(sd, passo) - 0.5) * 5.0, (Mortes._h(sd, passo + 70) - 0.5) * 2.0)
		_corpo_parado(Color(1.0, 0.85, 0.85) if passo % 3 == 0 else Color(0.9, 0.7, 0.75), -1, shake)
		for i in tiros:   # buracos que se acumulam
			if t > 0.06 + i * 0.06:
				var hp := pe + shake + Vector2((Mortes._h(sd, i + 200) - 0.5) * s.x * 0.6, -s.y * (0.15 + 0.7 * Mortes._h(sd, i + 230)))
				draw_circle(hp, 2.6, Color(0.55, 0.08, 0.1))
				draw_circle(hp, 1.6, Color(0.03, 0.0, 0.02))
	else:
		Mortes.desenhar(self, _rec)
	for i in tiros:
		var ti := 0.06 + i * 0.06
		var k := t - ti
		if k < 0.0 or k > 0.16:
			continue
		var alvo := pe + Vector2((Mortes._h(sd, i + 200) - 0.5) * s.x * 0.6, -s.y * (0.15 + 0.7 * Mortes._h(sd, i + 230)))
		var boca := _jog + Vector2(0, -6) + (alvo - _jog).normalized() * 12.0
		var a := 1.0 - k / 0.16
		draw_line(boca, alvo, Color(cor.r, cor.g, cor.b, 0.35 * a), 5.0)
		draw_line(boca, alvo, Color(1, 1, 0.8, a), 2.0)
		if k < 0.06:   # fogo na boca da arma e faísca no acerto
			draw_circle(boca, 5.0 * (1.0 - k / 0.06) + 1.0, Color(1, 0.9, 0.5, 0.9))
			for j in 4:
				var ang := Mortes._h(sd, i * 4 + j + 500) * TAU
				draw_line(alvo, alvo + Vector2.from_angle(ang) * (6.0 + 8.0 * Mortes._h(sd, i + j + 520)), Color(1, 0.85, 0.4, a), 1.0)
	if t >= _t0 and t < _t0 + 0.15:
		_clarao(0.35 * (1.0 - (t - _t0) / 0.15))


func _soco(cor: Color, s: Vector2, _pe: Vector2, meio: Vector2) -> void:
	var t := _t
	var voo := 0.5
	var dist := 120.0
	if t < _t0:
		var k := smoothstep(0.0, voo, t)
		var off := _dir * dist * k
		var rot := 7.0 * k * (1.0 if _dir.x >= 0.0 else -1.0)
		for g in 4:   # rastro
			var kg := maxf(0.0, k - 0.07 * (g + 1))
			Mortes._corpo(self, _rec, _dir * dist * kg, 7.0 * kg * (1.0 if _dir.x >= 0.0 else -1.0), 1.0, 1.0, Color(1, 0.9, 0.8, 0.3 - 0.07 * g), 2)
		Mortes._corpo(self, _rec, off, rot, 1.0 - 0.1 * k, 1.0 - 0.1 * k, Color(1.2, 1.1, 1.1) if t < 0.12 else Color(1, 0.85, 0.85), 2 if t < 0.1 else -1)
		if t < 0.25:   # o soco: clarão e estrela no ponto de impacto
			var a := 1.0 - t / 0.25
			draw_circle(meio, s.x * 0.35 * (0.5 + t / 0.25), Color(1, 0.95, 0.8, 0.8 * a))
			draw_arc(meio, s.x * (0.2 + 1.0 * t / 0.25), 0.0, TAU, 24, Color(1, 1, 1, 0.7 * a), 2.0)
			for j in 8:
				var ang := j * TAU / 8.0 + 0.2
				draw_line(meio + Vector2.from_angle(ang) * s.x * 0.3, meio + Vector2.from_angle(ang) * s.x * (0.5 + 0.5 * t / 0.25), Color(1, 0.9, 0.5, a), 2.0)
		for p in 5:   # poeira atrás
			draw_circle(meio + _dir * dist * k * 0.5 - _dir * (p * 10.0), 3.0 + p, Color(0.5, 0.45, 0.4, 0.3 * (1.0 - k)))
	else:
		var fim := meio + _dir * dist
		var r2: Dictionary = _rec.duplicate()
		r2.pos = _rec.pos + _dir * dist
		Mortes.desenhar(self, r2)
		var k := (t - _t0)
		if k < 0.35:
			var a := 1.0 - k / 0.35
			_clarao(0.5 * a)
			draw_arc(fim, 20.0 + k * 360.0, 0.0, TAU, 32, Color(1, 1, 1, 0.75 * a), 3.0)
			draw_arc(fim, 10.0 + k * 220.0, 0.0, TAU, 32, Color(cor.r, cor.g, cor.b, 0.6 * a), 2.0)
		for p in 8:   # poeira do impacto
			var ang := p * TAU / 8.0
			draw_circle(fim + Vector2.from_angle(ang) * (8.0 + k * 70.0) * Vector2(1, 0.5), 4.0 + k * 6.0, Color(0.5, 0.45, 0.4, 0.4 * (1.0 - smoothstep(0.0, 0.8, k))))


func _coluna(cor: Color, s: Vector2, pe: Vector2, _meio: Vector2) -> void:
	var t := _t
	if t < _t0:
		_corpo_parado(Color(0.75, 0.9, 1.2).lerp(Color.WHITE, 0.3) if int(t * 24.0) % 2 == 0 else Color(0.5, 0.7, 1.0))
	else:
		Mortes.desenhar(self, _rec)
	var dur := float(_cfg.dur)
	var k := smoothstep(0.1, 0.3, t) * (1.0 - smoothstep(dur - 0.8, dur - 0.2, t))
	if k > 0.0:
		var w := s.x * (0.45 + 0.1 * sin(t * 30.0)) * k
		var topo := pe.y - 520.0
		draw_polygon(PackedVector2Array([Vector2(pe.x - w * 1.4, pe.y), Vector2(pe.x + w * 1.4, pe.y), Vector2(pe.x + w * 1.4, topo), Vector2(pe.x - w * 1.4, topo)]),
			PackedColorArray([Color(cor.r, cor.g, cor.b, 0.35 * k), Color(cor.r, cor.g, cor.b, 0.35 * k), Color(cor.r, cor.g, cor.b, 0.0), Color(cor.r, cor.g, cor.b, 0.0)]))
		draw_polygon(PackedVector2Array([Vector2(pe.x - w * 0.5, pe.y), Vector2(pe.x + w * 0.5, pe.y), Vector2(pe.x + w * 0.5, topo), Vector2(pe.x - w * 0.5, topo)]),
			PackedColorArray([Color(0.85, 0.95, 1.0, 0.9 * k), Color(0.85, 0.95, 1.0, 0.9 * k), Color(0.7, 0.9, 1.0, 0.0), Color(0.7, 0.9, 1.0, 0.0)]))
		draw_set_transform(pe, 0.0, Vector2(1.0, 0.35))
		for i in 3:
			var rk := fposmod(t * 0.9 + i * 0.33, 1.0)
			draw_arc(Vector2.ZERO, s.x * (0.3 + 1.1 * rk), 0.0, TAU, 32, Color(cor.r, cor.g, cor.b, 0.8 * (1.0 - rk) * k), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if t > 0.1 and t < 0.35:
		_clarao(0.4 * (1.0 - (t - 0.1) / 0.25))


func _elemental(s: Vector2, pe: Vector2, meio: Vector2) -> void:
	var t := _t
	var sd: int = _rec.seed
	if t < _t0:
		var fogo := 1.0 - smoothstep(0.45, 0.65, t)
		var gelo := smoothstep(0.5, 0.8, t)
		var cor := Color.WHITE.lerp(Color(1.0, 0.45, 0.2), fogo * 0.8).lerp(Color(0.6, 0.85, 1.0), gelo)
		_corpo_parado(cor)
		if fogo > 0.05:   # chamas em volta
			for k in 7:
				var fx := pe.x + (Mortes._h(sd, k) - 0.5) * s.x * 0.9
				var alt := s.y * (0.5 + 0.5 * Mortes._h(sd, k + 10)) * (1.0 + 0.2 * sin(t * 28.0 + k * 2.0))
				var w := 4.0 + 4.0 * Mortes._h(sd, k + 20)
				var sw := sin(t * 12.0 + k) * 4.0
				draw_polygon(PackedVector2Array([Vector2(fx - w, pe.y), Vector2(fx + w, pe.y), Vector2(fx + sw, pe.y - alt)]),
					PackedColorArray([Color(1.0, 0.22, 0.05, 0.9 * fogo), Color(1.0, 0.22, 0.05, 0.9 * fogo), Color(1.0, 0.9, 0.3, 0.0)]))
		if gelo > 0.05:   # cristais de gelo crescendo
			for k in 6:
				var ang := -PI * 0.5 + (k - 2.5) * 0.45
				var base := meio + Vector2(cos(ang) * s.x * 0.45, sin(ang) * s.y * 0.5)
				var ponta := base + Vector2.from_angle(ang) * (10.0 + 14.0 * Mortes._h(sd, k + 40)) * gelo
				var perp := Vector2.from_angle(ang + PI * 0.5) * 3.0
				draw_polygon(PackedVector2Array([base - perp, base + perp, ponta]), PackedColorArray([Color(0.8, 0.95, 1.0, 0.9 * gelo), Color(0.8, 0.95, 1.0, 0.9 * gelo), Color(1, 1, 1, 0.9 * gelo)]))
	else:
		Mortes.desenhar(self, _rec)
	if t > _t0 - 0.2 and t < _t0 + 0.35:   # raios do céu
		var passo := int(t * 25.0)
		for k in 3:
			var topo := Vector2(pe.x + (k - 1) * 40.0 + (Mortes._h(sd, passo + k) - 0.5) * 30.0, pe.y - 400.0)
			_zigue(topo, meio + Vector2((k - 1) * 10.0, 0), passo * 3 + k, Color(0.5, 0.7, 1.0), 2.0)
	if t >= _t0 and t < _t0 + 0.2:
		_clarao(0.6 * (1.0 - (t - _t0) / 0.2))


func _global(cor: Color, s: Vector2, pe: Vector2, meio: Vector2) -> void:
	var t := _t
	if t < _t0:
		_corpo_parado(Color(1.5, 1.4, 1.3) if int(t * 40.0) % 2 == 0 else Color(0.8, 0.5, 0.5), 2)
		draw_circle(meio, s.x * 0.3 * (t / _t0), Color(1, 0.9, 0.6, 0.6 * (t / _t0)))
		return
	Mortes.desenhar(self, _rec)
	var k := t - _t0
	if k < 0.5:
		var a := 1.0 - k / 0.5
		draw_circle(meio, s.x * (0.4 + 1.0 * k / 0.5), Color(1.0, 0.65, 0.2, 0.55 * a))
		draw_circle(meio, s.x * (0.25 + 0.6 * k / 0.5), Color(1.0, 0.95, 0.7, 0.7 * a))
		draw_arc(meio, 15.0 + k * 400.0, 0.0, TAU, 36, Color(cor.r, cor.g, cor.b, 0.8 * a), 3.0)
		draw_arc(meio, 8.0 + k * 250.0, 0.0, TAU, 36, Color(1, 1, 1, 0.6 * a), 2.0)
	if k < 0.2:
		_clarao(0.65 * (1.0 - k / 0.2))
