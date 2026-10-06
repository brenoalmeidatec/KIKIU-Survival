extends Node2D
const Perf := preload("res://scripts/hordas/perf.gd")
## Mortes violentas (#32): o inimigo morre de um jeito que depende do que deu o golpe final (dados/mortes.json):
## queimado até virar cinza, congelado e estilhaçado, eletrocutado, cortado em duas metades, em pedaços, furado
## a tiro, desintegrado pela aura; sem causa conhecida, a morte simples. Tudo é DESENHO (`_draw`), sem nó por efeito
## e sem textura nova: o sprite do próprio inimigo é recortado em polígonos/pedaços.
## Teto (dados `teto`): `mortes` efeitos grandes ao mesmo tempo e `particulas` no total; passou disso o inimigo usa
## a morte simples (`simples` ao mesmo tempo) e depois some como antes. Só morre com efeito quem está perto da tela.
## Opção "Mortes violentas" = Reduzida: tudo vira o efeito suave (sem sangue e sem partes).
## A finalização de chefe (finalizacao.gd) reaproveita `desenhar` com o registro do chefe.
## A física dos pedaços é fechada em função do tempo (sem estado por pedaço): custo só na hora de desenhar.

const PARTES := ["estilhaco", "corte", "pedacos", "desintegrar"]   # efeitos que mostram pedaços do corpo
const SANGUE := ["corte", "pedacos", "furo"]                       # efeitos com sangue (e mancha no chão)
const G := 360.0

var arena: Node
var ativas: Array = []        # registros (veja `registro`) dos efeitos grandes em andamento
var simples: Array = []       # mortes simples em andamento
var manchas: Array = []       # sangue e cinza no chão: {pos, t, r, cor}
var part_usadas := 0          # soma de `part` das ativas (teto de partículas)
var ult_efeito := ""          # o último efeito escolhido (o teste lê)
var contagem := {}            # efeito -> quantas vezes foi escolhido (o teste lê)


# ---------- escolha do efeito (funções puras, testadas sem desenhar) ----------

## Causa do golpe final: o elemento da bola (Poder Elemental) vale mais que a arma; depois a tabela por arma,
## depois o tipo da arma (armas.json) e por fim "padrao".
static func causa_de(arma: String, elem := "") -> String:
	var d: Dictionary = Dados.json("mortes")
	if elem != "" and d.get("efeito_por_causa", {}).has(elem):
		return elem
	var por_arma: Dictionary = d.get("causa_por_arma", {})
	if por_arma.has(arma):
		return str(por_arma[arma])
	var tipo := str(Dados.json("armas").get(arma, {}).get("tipo", ""))
	return str(d.get("causa_por_tipo", {}).get(tipo, "padrao"))


## Qual desenho uma causa usa. Reduzida: sem sangue e sem partes (a morte simples continua simples).
static func efeito_de(causa: String, reduzida := false) -> String:
	if causa == "padrao" or not Dados.json("mortes").get("efeito_por_causa", {}).has(causa):
		return "simples"
	if reduzida:
		return "suave"
	return str(Dados.json("mortes").efeito_por_causa[causa])


static func reduzida() -> bool:
	return str(Config.v("mortes")) == "reduzida"


static func tem_partes(ef: String) -> bool:
	return ef in PARTES


static func tem_sangue(ef: String) -> bool:
	return ef in SANGUE


static func _h(sd: int, i: int) -> float:
	return fposmod(sin(float(sd) * 12.9898 + float(i) * 78.233) * 43758.5453, 1.0)


## Registro de uma morte a partir de um inimigo (V de inimigos.gd). `dur_mult` estica o efeito (finalização).
static func registro(v, causa: String, ef: String, dur_mult := 1.0) -> Dictionary:
	var dm: Dictionary = Dados.json("mortes")
	var cc: Array = dm.get("cor_causa", {}).get(causa, [0.6, 0.9, 0.5])
	var cor := Color(cc[0], cc[1], cc[2])
	var sg: Array = dm.get("sangue", [0.34, 0.03, 0.06])
	var sangue := Color(sg[0], sg[1], sg[2])
	if v.d.get("cor_morte") is Array:   # "cor da morte" do inimigo: o sangue é essa cor escurecida
		var cm: Array = v.d.cor_morte
		sangue = Color(cm[0], cm[1], cm[2]).darkened(0.6)
		if causa == "padrao":
			cor = Color(cm[0], cm[1], cm[2])
	var cfg: Dictionary = dm.get("efeitos", {}).get(ef, {})
	var sd: int = v.id * 7919 + 13
	var dir: Vector2 = v.dir_ult if v.dir_ult.length() > 1.0 else Vector2(-1.0 if _h(sd, 99) < 0.5 else 1.0, -0.15)
	return {"ef": ef, "causa": causa, "pos": v.pos, "tex": v.tex, "tam": v.tam, "sz": v.sz, "vira": v.espelho, "y0": v.tam.y * v.vista,
		"quadro": v.id % 2, "t": 0.0, "dur": float(cfg.get("dur", 0.5)) * dur_mult, "dir": dir.normalized(), "seed": sd,
		"cor": cor, "sangue": sangue, "part": int(cfg.get("part", 0)), "tipo": v.tipo}


# ---------- criação ----------

func _perto(p: Vector2) -> bool:
	if not (arena and arena.jogador):
		return false
	var t: Dictionary = Dados.json("mortes").get("tela", {})
	var c: Vector2 = arena.jogador.position
	return absf(p.x - c.x) < float(t.get("x", 360)) and absf(p.y - c.y) < float(t.get("y", 210))


## Chamado quando o inimigo morre (já saiu da lista). Retorna o efeito escolhido ("" = nada: longe da tela ou sem vaga).
func nova(v, forcar := false) -> String:
	if not forcar and not _perto(v.pos):
		return ""
	var causa := causa_de(str(v.arma_ult), str(v.causa_ult))
	var ef := efeito_de(causa, reduzida())
	var dm: Dictionary = Dados.json("mortes")
	var teto: Dictionary = dm.get("teto", {})
	var part := int(dm.get("efeitos", {}).get(ef, {}).get("part", 0))
	if ef != "simples" and (ativas.size() >= int(teto.get("mortes", 24)) or part_usadas + part > int(teto.get("particulas", 600))):
		ef = "simples"   # sem vaga: morte simples
	if ef == "simples":
		if simples.size() >= int(teto.get("simples", 48)):
			return ""
		simples.append(registro(v, causa, "simples"))
	else:
		var r := registro(v, causa, ef)
		ativas.append(r)
		part_usadas += r.part
		_mancha(r)
	ult_efeito = ef
	contagem[ef] = int(contagem.get(ef, 0)) + 1
	return ef


## Sangue (ou cinza) no chão: some devagar.
func _mancha(r: Dictionary) -> void:
	var ef: String = r.ef
	if not (ef in SANGUE or ef == "cinzas"):
		return
	var s: Vector2 = r.sz
	var maximo := int(Dados.json("mortes").get("teto", {}).get("manchas", 40))
	if manchas.size() >= maximo:
		manchas.pop_front()
	var cor: Color = Color(0.06, 0.05, 0.05) if ef == "cinzas" else (r.sangue as Color)
	manchas.append({"pos": r.pos + Vector2(0, s.y * 0.4), "t": -0.15 if ef != "cinzas" else 0.6, "r": s.x * (0.5 if r.causa == "explosao" else 0.34), "cor": cor})


func limpar() -> void:
	ativas.clear()
	simples.clear()
	manchas.clear()
	part_usadas = 0
	queue_redraw()


func particulas() -> int:
	return part_usadas


func atualizar(dt: float) -> void:
	var _pp := Perf.ini()
	atualizar_i(dt)
	Perf.fim("mor_a", _pp)


func atualizar_i(dt: float) -> void:
	if ativas.is_empty() and simples.is_empty() and manchas.is_empty():
		return
	var i := ativas.size() - 1
	while i >= 0:
		ativas[i].t += dt
		if ativas[i].t >= ativas[i].dur:
			part_usadas -= int(ativas[i].part)
			ativas.remove_at(i)
		i -= 1
	i = simples.size() - 1
	while i >= 0:
		simples[i].t += dt
		if simples[i].t >= simples[i].dur:
			simples.remove_at(i)
		i -= 1
	i = manchas.size() - 1
	while i >= 0:
		manchas[i].t += dt
		if manchas[i].t > 4.0:
			manchas.remove_at(i)
		i -= 1
	queue_redraw()


# ---------- desenho ----------

func _draw() -> void:
	var _pp := Perf.ini()
	_draw_i()
	Perf.fim("mor_d", _pp)


func _draw_i() -> void:
	for m in manchas:
		if m.t < 0.0:
			continue
		var k := clampf(m.t / 0.4, 0.0, 1.0)
		var a := 0.62 * (1.0 - smoothstep(2.4, 4.0, m.t))
		draw_set_transform(m.pos, 0.0, Vector2(1.0, 0.36))
		draw_circle(Vector2.ZERO, float(m.r) * (0.4 + 0.6 * k), Color(m.cor.r, m.cor.g, m.cor.b, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for r in ativas:
		desenhar(self, r)
	for r in simples:
		desenhar(self, r)


static func desenhar(c, r: Dictionary) -> void:
	match str(r.ef):
		"cinzas": _cinzas(c, r)
		"estilhaco": _estilhaco(c, r)
		"choque": _choque(c, r)
		"corte": _corte(c, r)
		"pedacos": _pedacos(c, r)
		"furo": _furo(c, r)
		"desintegrar": _desintegrar(c, r)
		"suave": _suave(c, r)
		_: _simples(c, r)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _pe(r: Dictionary) -> Vector2:
	var s: Vector2 = r.sz
	return (r.pos as Vector2) + Vector2(0, s.y * 0.4)


## O corpo inteiro (um quadro do sprite), com deslocamento, giro em volta do pé e esticada.
static func _corpo(c, r: Dictionary, off: Vector2, rot: float, sx: float, sy: float, cor: Color, quadro := -1) -> void:
	var s: Vector2 = r.sz
	var q: int = int(r.quadro) if quadro < 0 else quadro
	c.draw_set_transform(_pe(r) + off, rot, Vector2(-sx if r.vira else sx, sy))
	c.draw_texture_rect_region(r.tex, Rect2(-s.x * 0.5, -s.y, s.x, s.y), Rect2(r.tam.x * q, r.y0, r.tam.x, r.tam.y), cor)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## UV (0..1 da textura inteira) de um ponto local do sprite (pé em 0,0; sprite de -s/2 a +s/2 em x e -s.y a 0 em y).
static func _uv(r: Dictionary, p: Vector2) -> Vector2:
	var s: Vector2 = r.sz
	var fx := clampf((p.x + s.x * 0.5) / s.x, 0.0, 1.0)
	if r.vira:
		fx = 1.0 - fx
	return Vector2(float(r.tam.x) * (float(r.quadro) + fx) / float(r.tex.get_width()), (float(r.y0) + clampf((p.y + s.y) / s.y, 0.0, 1.0) * float(r.tam.y)) / float(r.tex.get_height()))


static func _poligono(c, r: Dictionary, pts_local: PackedVector2Array, centro_local: Vector2, pos_centro: Vector2, rot: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	for p in pts_local:
		pts.append(pos_centro + (p - centro_local).rotated(rot))
		cores.append(cor)
		uvs.append(_uv(r, p))
	c.draw_polygon(pts, cores, uvs, r.tex)


## Posição de algo atirado de `o` com velocidade `v` depois de `tt` s: cai com gravidade, pousa em `chao` e para.
static func _balistico(o: Vector2, v: Vector2, tt: float, chao: float) -> Vector2:
	if o.y >= chao:
		return Vector2(o.x + v.x * tt * 0.08, o.y)
	var tl := (-v.y + sqrt(v.y * v.y + 2.0 * G * (chao - o.y))) / G
	var ta := minf(tt, tl)
	var tx := tt if tt <= tl else tl + (tt - tl) * 0.08
	return Vector2(o.x + v.x * tx, o.y + v.y * ta + 0.5 * G * ta * ta)


static func _gotas(c, r: Dictionary, origem: Vector2, n: int, vmax: float, tt: float, a: float, base: int) -> void:
	var sd: int = r.seed
	var chao: float = _pe(r).y + 1.0
	for i in n:
		var ang := _h(sd, base + i) * TAU
		var vel := Vector2.from_angle(ang) * lerpf(vmax * 0.25, vmax, _h(sd, base + 40 + i)) + (r.dir as Vector2) * vmax * 0.35 + Vector2(0, -vmax * 0.3)
		var p := _balistico(origem, vel, tt, chao)
		var tam := 2.0 if _h(sd, base + 80 + i) > 0.35 else 1.0
		c.draw_rect(Rect2(p.floor(), Vector2(tam, tam)), Color(r.sangue.r, r.sangue.g, r.sangue.b, a))


# ----- queimar até virar cinza: escurece, encolhe, chamas e brasas subindo -----
static func _cinzas(c, r: Dictionary) -> void:
	var u: float = r.t / r.dur
	var s: Vector2 = r.sz
	var pe := _pe(r)
	var sd: int = r.seed
	var enc := smoothstep(0.2, 0.85, u)
	var cor := Color.WHITE.lerp(Color(1.0, 0.5, 0.18), clampf(u / 0.1, 0.0, 1.0)).lerp(Color(0.13, 0.1, 0.1), clampf((u - 0.1) / 0.4, 0.0, 1.0))
	cor = cor.lerp(Color(0.32, 0.31, 0.31), smoothstep(0.55, 0.9, u))
	cor.a = 1.0 - smoothstep(0.78, 1.0, u)
	var sx := 1.0 - 0.35 * enc
	var sy := (1.0 - 0.82 * enc) * (1.0 + 0.03 * sin(r.t * 45.0))
	c.draw_set_transform(pe, 0.0, Vector2(1.0, 0.35))
	c.draw_circle(Vector2.ZERO, s.x * 0.32 * smoothstep(0.3, 0.9, u), Color(0.1, 0.09, 0.09, 0.75 * cor.a))
	_corpo(c, r, Vector2.ZERO, 0.0, sx, sy, cor)
	var fa := 1.0 - smoothstep(0.35, 0.8, u)
	if fa > 0.0:
		for k in 4:
			var fx := pe.x + (_h(sd, k) - 0.5) * s.x * 0.7 * sx
			var alt := s.y * sy * (0.5 + 0.5 * _h(sd, k + 10)) * (1.0 + 0.15 * sin(r.t * 30.0 + k * 2.0)) + 4.0
			var w := 3.0 + 3.0 * _h(sd, k + 20)
			var sway := sin(r.t * 12.0 + k) * 3.0
			var pts := PackedVector2Array([Vector2(fx - w, pe.y), Vector2(fx + w, pe.y), Vector2(fx + sway, pe.y - alt)])
			c.draw_polygon(pts, PackedColorArray([Color(1.0, 0.22, 0.05, 0.9 * fa), Color(1.0, 0.22, 0.05, 0.9 * fa), Color(1.0, 0.85, 0.3, 0.0)]))
			var pi := PackedVector2Array([Vector2(fx - w * 0.5, pe.y), Vector2(fx + w * 0.5, pe.y), Vector2(fx + sway * 0.7, pe.y - alt * 0.6)])
			c.draw_polygon(pi, PackedColorArray([Color(1.0, 0.75, 0.2, 0.85 * fa), Color(1.0, 0.75, 0.2, 0.85 * fa), Color(1.0, 1.0, 0.7, 0.0)]))
	for i in 14:   # brasas subindo
		var atraso := _h(sd, i + 30) * 0.45
		var w := (u - atraso) / 0.5
		if w <= 0.0 or w >= 1.0:
			continue
		var p := Vector2(pe.x + (_h(sd, i + 50) - 0.5) * s.x * 0.7 + sin(w * 6.0 + _h(sd, i + 70) * 6.0) * 5.0,
			pe.y - s.y * 0.45 * (1.0 - enc * 0.6) - w * (22.0 + _h(sd, i + 90) * 38.0))
		var ec := Color(1.0, 0.7, 0.2).lerp(Color(0.8, 0.2, 0.1), w).lerp(Color(0.3, 0.3, 0.3), smoothstep(0.7, 1.0, w))
		c.draw_rect(Rect2(p.floor(), Vector2(2, 2) if _h(sd, i + 110) > 0.4 else Vector2(1, 1)), Color(ec.r, ec.g, ec.b, 1.0 - w))


# ----- congelar e estilhaçar -----
static func _estilhaco(c, r: Dictionary) -> void:
	var u: float = r.t / r.dur
	var s: Vector2 = r.sz
	var pe := _pe(r)
	var sd: int = r.seed
	var tf := 0.2
	if u < tf:
		var br := 0.88 + 0.12 * sin(r.t * 60.0)
		_corpo(c, r, Vector2.ZERO, 0.0, 1.0, 1.0, Color(0.55 * br, 0.85 * br, 1.0))
		for k in 4:
			var a0 := Vector2((_h(sd, k) - 0.5) * s.x * 0.6, -s.y * (0.2 + 0.6 * _h(sd, k + 5)))
			var a1 := a0 + Vector2((_h(sd, k + 9) - 0.5) * s.x * 0.5, (_h(sd, k + 13) - 0.5) * s.y * 0.4)
			c.draw_line(pe + a0, pe + a1, Color(1, 1, 1, 0.9), 1.0)
		return
	var tt: float = (u - tf) * r.dur
	var al := 1.0 - smoothstep(0.62, 1.0, u)
	var cw := s.x / 3.0
	var ch := s.y / 2.0
	var centro := Vector2(0, -s.y * 0.5)
	var idx := 0
	for i in 3:
		for j in 2:
			var x0 := -s.x * 0.5 + i * cw
			var y0 := -s.y + j * ch
			var p00 := Vector2(x0, y0)
			var p10 := Vector2(x0 + cw, y0)
			var p11 := Vector2(x0 + cw, y0 + ch)
			var p01 := Vector2(x0, y0 + ch)
			var tris: Array = [[p00, p10, p11], [p00, p11, p01]] if _h(sd, idx) < 0.5 else [[p00, p10, p01], [p10, p11, p01]]
			for tri in tris:
				var c0: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
				var rad: Vector2 = c0 - centro
				if rad.length() < 1.0:
					rad = Vector2(0, -1)
				var vel: Vector2 = rad.normalized() * (45.0 + 75.0 * _h(sd, idx + 20)) + Vector2(0, -50.0 * _h(sd, idx + 40))
				var pos := _balistico(pe + c0, vel, tt, pe.y - 2.0)
				var cl := Color(0.72, 0.93, 1.0, al)
				_poligono(c, r, PackedVector2Array(tri), c0, pos, (_h(sd, idx + 60) - 0.5) * 16.0 * minf(tt, 0.6), cl)
				idx += 1
	for i in 8:   # brilhos de gelo
		var ang := _h(sd, i + 100) * TAU
		var p := _balistico(pe + centro, Vector2.from_angle(ang) * (40.0 + 70.0 * _h(sd, i + 120)), tt, pe.y)
		c.draw_rect(Rect2(p.floor(), Vector2(2, 2) if i % 2 == 0 else Vector2(1, 1)), Color(0.85, 0.97, 1.0, al))


# ----- eletrocutar: pisca, zigue-zague, cai chamuscado -----
static func _choque(c, r: Dictionary) -> void:
	var u: float = r.t / r.dur
	var s: Vector2 = r.sz
	var pe := _pe(r)
	var sd: int = r.seed
	var step := int(r.t * 26.0)
	var queda := smoothstep(0.55, 0.85, u)
	var j := Vector2((_h(sd, step) - 0.5) * 4.0, (_h(sd, step + 50) - 0.5) * 2.0) * (1.0 - queda)
	var q := int(r.quadro)
	var cor := Color(0.3, 0.36, 0.65)
	if step % 2 == 0 and queda < 0.3:
		q = 2
		cor = Color.WHITE
	cor = cor.lerp(Color(0.18, 0.18, 0.22), queda)
	cor.a = 1.0 - smoothstep(0.82, 1.0, u)
	var sinal := -1.0 if _h(sd, 1) < 0.5 else 1.0
	_corpo(c, r, j, sinal * 1.5 * queda, 1.0, 1.0 - 0.15 * queda, cor, q)
	if u < 0.7:
		var ini := pe + Vector2(0, -s.y * 0.5)
		for k in 3:
			if _h(sd, step * 3 + k) < 0.2:
				continue
			var dir := Vector2.from_angle(_h(sd, step * 7 + k) * TAU)
			var perp := dir.rotated(PI * 0.5)
			var larg := 18.0 + 16.0 * _h(sd, step * 5 + k + 200)
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(ini + dir * larg * i / 5.0 + perp * (_h(sd, step * 11 + k * 6 + i) - 0.5) * 9.0 * (1.0 if i > 0 else 0.0))
			c.draw_polyline(pts, Color(0.4, 0.6, 1.0, 0.35), 3.0)
			c.draw_polyline(pts, Color(0.85, 0.95, 1.0, 0.95), 1.0)
		for k in 2:   # faíscas no chão
			var p := pe + Vector2((_h(sd, step + k + 300) - 0.5) * s.x, -_h(sd, step + k + 320) * 4.0)
			c.draw_rect(Rect2(p.floor(), Vector2(2, 1)), Color(1.0, 0.95, 0.6))
	for k in 3:   # fumaça depois de cair
		var w := clampf((u - 0.5 - k * 0.07) / 0.4, 0.0, 1.0)
		if w > 0.0 and w < 1.0:
			c.draw_circle(pe + Vector2(sin(w * 5.0 + k) * 4.0, -s.y * 0.35 - w * 22.0), 3.0 + w * 3.0, Color(0.2, 0.2, 0.22, 0.4 * (1.0 - w)))


## Recorta um polígono convexo pelo semiplano n·(p - c) * lado >= 0.
static func _recortar(pts: PackedVector2Array, cen: Vector2, nrm: Vector2, lado: float) -> PackedVector2Array:
	var res := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var da := nrm.dot(a - cen) * lado
		var db := nrm.dot(b - cen) * lado
		if da >= 0.0:
			res.append(a)
		if (da >= 0.0) != (db >= 0.0):
			res.append(a.lerp(b, da / (da - db)))
	return res


# ----- cortar em duas metades que se separam -----
static func _corte(c, r: Dictionary) -> void:
	var u: float = r.t / r.dur
	var s: Vector2 = r.sz
	var pe := _pe(r)
	var sd: int = r.seed
	var th: float = float(r.th) if r.has("th") else (-0.65 if _h(sd, 0) < 0.5 else 0.65) + (_h(sd, 1) - 0.5) * 0.35
	var tang := Vector2.from_angle(th)
	var nrm := Vector2(-tang.y, tang.x)
	var cen := Vector2(0, -s.y * 0.5)
	var sep := smoothstep(0.08, 0.5, u)
	var tt := maxf(0.0, r.t - 0.22)
	var al := 1.0 - smoothstep(0.78, 1.0, u)
	var rect := PackedVector2Array([Vector2(-s.x * 0.5, -s.y), Vector2(s.x * 0.5, -s.y), Vector2(s.x * 0.5, 0), Vector2(-s.x * 0.5, 0)])
	for lado: float in [1.0, -1.0]:
		var poly := _recortar(rect, cen, nrm, lado)
		if poly.size() < 3:
			continue
		var cc := Vector2.ZERO
		for p in poly:
			cc += p
		cc /= poly.size()
		var off: Vector2 = (nrm - tang * 0.9) * lado * sep * s.y * 0.17
		if lado < 0.0:
			off.y += minf(0.5 * 220.0 * tt * tt, s.y * 0.28)   # a de cima desaba
		var rot := lado * 0.55 * smoothstep(0.15, 0.8, u) * (1.0 if th < 0.0 else -1.0)
		var cl := Color(0.86, 0.76, 0.78, al).lerp(Color(0.7, 0.6, 0.62, al), sep)
		var sentido: Vector2 = pe + off + cc
		_poligono(c, r, poly, cc, sentido, rot, cl)
		# o corte aberto (carne escura) na quina de cada metade
		var borda := PackedVector2Array()
		for p in poly:
			if absf(nrm.dot(p - cen)) < 0.01:
				borda.append(sentido + (p - cc).rotated(rot))
		if borda.size() >= 2:
			c.draw_line(borda[0], borda[1], Color(r.sangue.r, r.sangue.g, r.sangue.b, al), 2.0)
	if u < 0.35:   # o clarão do golpe
		var L := maxf(s.x, s.y) * 0.9 * smoothstep(0.0, 0.1, u)
		var a := 1.0 - smoothstep(0.05, 0.35, u)
		c.draw_line(pe + cen - tang * L, pe + cen + tang * L, Color(1, 1, 1, a), 2.0 if u < 0.15 else 1.0)
	var tg := maxf(0.0, r.t - 0.06)
	if tg > 0.0:
		var ori := pe + cen
		for i in int(r.get("n_gotas", 10)):   # sangue esguichando do corte
			var vel := nrm * (_h(sd, i + 5) - 0.5) * 90.0 + tang * (_h(sd, i + 25) - 0.5) * 150.0 + Vector2(0, -45.0)
			var p := _balistico(ori, vel, tg, pe.y + 1.0)
			var tam := 2.0 if _h(sd, i + 45) > 0.4 else 1.0
			c.draw_rect(Rect2(p.floor(), Vector2(tam, tam)), Color(r.sangue.r, r.sangue.g, r.sangue.b, al))


# ----- explodir / quebrar em pedaços e sangue escuro -----
static func _pedacos(c, r: Dictionary) -> void:
	var u: float = r.t / r.dur
	var s: Vector2 = r.sz
	var pe := _pe(r)
	var sd: int = r.seed
	var forca := 1.45 if r.causa == "explosao" else 1.0
	var centro := Vector2(0, -s.y * 0.5)
	var al := 1.0 - smoothstep(0.7, 1.0, u)
	var cw := s.x / 3.0
	var ch := s.y / 3.0
	var idx := 0
	for i in 3:
		for j in 3:
			var c0 := Vector2(-s.x * 0.5 + (i + 0.5) * cw, -s.y + (j + 0.5) * ch)
			var rad := c0 - centro
			if rad.length() < 1.0:
				rad = Vector2(0, -1)
			var vel := rad.normalized() * (45.0 + 60.0 * _h(sd, idx)) * forca + (r.dir as Vector2) * 70.0 * forca + Vector2(0, -(50.0 + 70.0 * _h(sd, idx + 20)) * forca)
			var tt: float = r.t
			var pos := _balistico(pe + c0, vel, tt, pe.y - ch * 0.4)
			var rot := (_h(sd, idx + 40) - 0.5) * 18.0 * minf(tt, 0.45)
			var col := (2 - i) if r.vira else i
			c.draw_set_transform(pos, rot, Vector2(-1.0 if r.vira else 1.0, 1.0))
			c.draw_texture_rect_region(r.tex, Rect2(-cw * 0.5, -ch * 0.5, cw, ch),
				Rect2(r.tam.x * (int(r.quadro)) + r.tam.x * col / 3.0, r.y0 + r.tam.y * j / 3.0, r.tam.x / 3.0, r.tam.y / 3.0), Color(0.82, 0.72, 0.72, al))
			idx += 1
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_gotas(c, r, pe + centro, 14, 130.0 * forca, r.t, al, 200)
	if u < 0.3:   # clarão e onda de choque
		var k := u / 0.3
		c.draw_circle(pe + centro, s.x * 0.45 * (1.0 - k) + 2.0, Color(1, 1, 1, 0.55 * (1.0 - k) * (1.0 if u < 0.1 else 0.5)))
		c.draw_arc(pe + centro, s.x * (0.25 + 0.7 * k) * forca, 0.0, TAU, 24, Color(1, 1, 1, 0.5 * (1.0 - k)), 1.0)


# ----- tiro: o corpo é jogado pra trás, buracos e jato de sangue -----
static func _furo(c, r: Dictionary) -> void:
	var u: float = r.t / r.dur
	var s: Vector2 = r.sz
	var pe := _pe(r)
	var sd: int = r.seed
	var dir: Vector2 = r.dir
	var sinal := 1.0 if dir.x >= 0.0 else -1.0
	var k := smoothstep(0.0, 0.3, u)
	var queda := smoothstep(0.05, 0.55, u)
	var al := 1.0 - smoothstep(0.75, 1.0, u)
	var q := int(r.quadro)
	var cor := Color(1, 1, 1, al).lerp(Color(0.58, 0.46, 0.5, al), smoothstep(0.0, 0.5, u))
	if r.t < 0.06:
		q = 2
	c.draw_set_transform(pe + Vector2(sinal * 10.0 * k, 0), sinal * 1.4 * queda, Vector2(-1.0 if r.vira else 1.0, 1.0))
	c.draw_texture_rect_region(r.tex, Rect2(-s.x * 0.5, -s.y, s.x, s.y), Rect2(r.tam.x * q, r.y0, r.tam.x, r.tam.y), cor)
	if r.t > 0.02:
		for i in 3:   # buracos: escuros com borda vermelha
			var hp := Vector2((_h(sd, i) - 0.5) * s.x * 0.5, -s.y * (0.25 + 0.5 * _h(sd, i + 5)))
			c.draw_circle(hp, 2.2, Color(0.5, 0.06, 0.08, al))
			c.draw_circle(hp, 1.4, Color(0.04, 0.0, 0.02, al))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if u < 0.12:   # faíscas de saída
		for i in 3:
			var o := pe + Vector2(0, -s.y * (0.3 + 0.2 * i)) + dir * 4.0
			c.draw_line(o, o + dir * (6.0 + 6.0 * _h(sd, i + 9)) + Vector2(0, (_h(sd, i + 13) - 0.5) * 6.0), Color(1.0, 0.9, 0.5, 1.0 - u / 0.12), 1.0)
	_gotas(c, r, pe + Vector2(0, -s.y * 0.55) + dir * 6.0, 8, 120.0, maxf(0.0, r.t - 0.03), al, 300)


# ----- aura: desintegra em faixas de luz cobalto -----
static func _desintegrar(c, r: Dictionary) -> void:
	var u: float = r.t / r.dur
	var s: Vector2 = r.sz
	var pe := _pe(r)
	var sd: int = r.seed
	var cob := Color(0.3, 0.62, 1.0)
	var N := 8
	var sh := s.y / N
	c.draw_set_transform(pe, 0.0, Vector2(-1.0 if r.vira else 1.0, 1.0))
	for i in N:
		var w := clampf((u - (0.1 + i * 0.07)) / 0.38, 0.0, 1.0)
		var wk := 1.0 - 0.45 * w
		var dx := (_h(sd, i) - 0.5) * 16.0 * w
		var cor := Color.WHITE.lerp(Color(0.45, 0.85, 1.0), clampf(u * 3.0 + w, 0.0, 1.0) * 0.8)
		cor.a = 1.0 - w
		if cor.a <= 0.0:
			continue
		c.draw_texture_rect_region(r.tex, Rect2(-s.x * 0.5 * wk + dx, -s.y + i * sh - w * 20.0, s.x * wk, sh),
			Rect2(r.tam.x * int(r.quadro), r.y0 + r.tam.y * i / N, r.tam.x, r.tam.y / N), cor)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var ga := sin(clampf(u, 0.0, 1.0) * PI) * 0.3
	var cw := s.x * 0.3
	c.draw_polygon(PackedVector2Array([Vector2(pe.x - cw, pe.y), Vector2(pe.x + cw, pe.y), Vector2(pe.x + cw * 0.5, pe.y - s.y * 1.7), Vector2(pe.x - cw * 0.5, pe.y - s.y * 1.7)]),
		PackedColorArray([Color(cob.r, cob.g, cob.b, ga), Color(cob.r, cob.g, cob.b, ga), Color(cob.r, cob.g, cob.b, 0.0), Color(cob.r, cob.g, cob.b, 0.0)]))
	c.draw_set_transform(pe, 0.0, Vector2(1.0, 0.35))
	c.draw_arc(Vector2.ZERO, s.x * (0.35 + 0.35 * u), 0.0, TAU, 24, Color(cob.r, cob.g, cob.b, 0.7 * (1.0 - u)), 1.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 12:   # faíscas cobalto subindo
		var w := fposmod(u * 1.1 + _h(sd, i + 30), 1.0)
		var p := Vector2(pe.x + (_h(sd, i + 50) - 0.5) * s.x * 0.8, pe.y - _h(sd, i + 70) * s.y - w * 38.0)
		var cl := cob.lerp(Color.WHITE, 0.5 if i % 3 == 0 else 0.0)
		c.draw_rect(Rect2(p.floor(), Vector2(2, 2) if i % 2 == 0 else Vector2(1, 1)), Color(cl.r, cl.g, cl.b, sin(w * PI) * (1.0 - smoothstep(0.7, 1.0, u))))


# ----- versão sem sangue e sem partes (opção Reduzida): some tingido da cor da causa -----
static func _suave(c, r: Dictionary) -> void:
	var u: float = r.t / r.dur
	var s: Vector2 = r.sz
	var pe := _pe(r)
	var sd: int = r.seed
	var cc: Color = r.cor
	var cor := Color.WHITE.lerp(cc, clampf(u * 2.5, 0.0, 0.75))
	cor.a = 1.0 - smoothstep(0.3, 1.0, u)
	_corpo(c, r, Vector2(0, -6.0 * u), 0.0, 1.0 - 0.15 * u, 1.0 - 0.15 * u, cor)
	for i in 6:
		var w := clampf(u * 1.3 - _h(sd, i) * 0.3, 0.0, 1.0)
		var p := Vector2(pe.x + (_h(sd, i + 9) - 0.5) * s.x * 0.7, pe.y - s.y * 0.5 - w * 22.0)
		c.draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(cc.r, cc.g, cc.b, 1.0 - w))


# ----- morte simples: clarão e some -----
static func _simples(c, r: Dictionary) -> void:
	var u: float = r.t / r.dur
	var cor := Color(1, 1, 1, 1.0 - u)
	_corpo(c, r, Vector2.ZERO, 0.0, 1.0 + 0.2 * u, 1.0 - 0.5 * u, cor, 2)
