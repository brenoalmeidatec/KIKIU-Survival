extends RefCounted
## As GOTAS DE FOGO de quem queima (decisão do Alisson, 06/11; receita do Enter the Gungeon: o corpo tingido por v2/status_corpo.gd + partículas pequenas).
## Cada monstro queimando ganha de 2 a 4 gotas de 1 a 3 px que NASCEM de um pixel opaco do próprio corpo, sobem com uma leve curva lateral, vão do amarelo-claro ao
## vermelho escuro e somem em 0,4 a 0,8 s. Nunca saem da silhueta de lado (no máximo `sobra_lado` px além da caixa do corpo) e passam no máximo `sobra_cabeca` px da
## cabeça (fagulha). Onde nascem: uma lista de pontos pré-calculada UMA vez por tipo e quadro da folha (`pontos_do_quadro`: varre o alfa, sorteia até `pontos` pixels
## opacos, com viés `bias_baixo` para a metade de baixo), então nunca nasce na folga vazia da célula (4 a 26 px embaixo em alguns bichos).
## Pool FIXO em dados (v2_pixelfx.json, status.fogo.gotas): `pool` gotas no total, vagas de `por_monstro` gotas, das quais as últimas `vagas_elite` são só de elite e chefe; quem passa
## do limite fica só com o tingimento. UM nó com um desenho só (z_index 30, acima dos monstros), RNG próprio (o da partida não é tocado), nenhum nó nasce na partida.
## Perfil Baixo (Anim.suave desligado): nenhuma gota. "Reduzir piscadas": 1 gota por monstro, parada na cor laranja, sobe devagar e nasce com folga entre uma e outra
## (nenhum pixel troca mais de 2 vezes por segundo, medido em testes/v2_chama_particulas.gd).
## API: montar(c), atualizar(dt), limpar(), pontos_do_quadro(m) -> Dictionary, vivas() -> int, monstros() -> int, gota(i) -> Dictionary (testes).

const Anim := preload("res://v2/anim_golpes.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const SEED_RNG := 6677
const FATIAS := 6  # a lista de monstros é varrida inteira em ~6 quadros

var combate
var no: Node2D = null
var cfg: Dictionary = {}
var pool := 160
var por_slot := 4  # gotas reservadas por vaga (o máximo de `por_monstro`)
var n_slots := 40
var vagas_elite := 4  # as últimas vagas: só elite e chefe
var ativos := 0
var _rng := RandomNumberGenerator.new()
var _formas: Array = []  # por forma: Array de Vector2i (pixels preenchidos, relativos ao canto de cima à esquerda)
var _pesos: Array = []
var _cores: Array = []
var _fases: Array = []
var _cache := {}  # id da textura -> {chave -> {pts, x0, y0, x1, y1}}
var _imgs := {}  # id da textura -> Image
var _cursor := 0
var _m: Array = []  # por vaga: o monstro, ou null
var _n := PackedInt32Array()  # por vaga: quantas gotas vale
var _est := PackedInt32Array()  # por gota: 0 = livre, 1 = esperando, 2 = no ar
var _idade := PackedFloat32Array()
var _vida := PackedFloat32Array()
var _espera := PackedFloat32Array()
var _x0 := PackedFloat32Array()  # onde nasceu, em px da tela relativo ao ponto dos pés do monstro (pr)
var _y0 := PackedFloat32Array()
var _vel := PackedFloat32Array()
var _amp := PackedFloat32Array()
var _fase := PackedFloat32Array()
var _forma := PackedInt32Array()
var _ox := PackedInt32Array()  # onde a gota está agora (px inteiros relativos a pr), o que o desenho usa
var _oy := PackedInt32Array()


func montar(c) -> void:
	combate = c
	_rng.seed = SEED_RNG
	cfg = Dados.json("v2_pixelfx").get("status", {}).get("fogo", {}).get("gotas", {})
	pool = maxi(int(cfg.get("pool", 160)), 4)
	var pm: Array = cfg.get("por_monstro", [2, 4])
	por_slot = maxi(int(pm[1]), 1)
	n_slots = maxi(pool / por_slot, 1)
	vagas_elite = clampi(int(cfg.get("vagas_elite", 4)), 0, n_slots - 1)
	_formas.clear()
	_pesos.clear()
	var fs: Dictionary = cfg.get("formas", {})
	var nomes: Array = fs.keys()
	nomes.sort()
	for nome in nomes:
		var e: Dictionary = fs[nome]
		var px: Array = []
		var linhas: Array = e.get("linhas", [])
		for y in linhas.size():
			var row := str(linhas[y])
			for x in row.length():
				if row[x] == "X":
					px.append(Vector2i(x, y))
		_formas.append(px)
		_pesos.append(float(e.get("peso", 1.0)))
	_cores.clear()
	for k in cfg.get("cores", []):
		_cores.append(Color8(int(k[0]), int(k[1]), int(k[2])))
	_fases = cfg.get("fases", [0.25, 0.55, 0.8])
	_m.resize(n_slots)
	_n.resize(n_slots)
	for t in [_est, _forma, _ox, _oy]:
		t.resize(pool)
	for t in [_idade, _vida, _espera, _x0, _y0, _vel, _amp, _fase]:
		t.resize(pool)
	var pai = combate.mundo.get("no_mundo")
	if pai is Node:
		no = Node2D.new()
		no.z_index = 30  # acima dos monstros e dos atores; abaixo só do depurador de colisão (400)
		no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		no.draw.connect(_desenhar)
		pai.add_child(no)


func limpar() -> void:
	for i in n_slots:
		_m[i] = null
		_n[i] = 0
	_est.fill(0)
	ativos = 0
	if no != null:
		no.queue_redraw()


func monstros() -> int:
	return ativos


func vivas() -> int:
	var n := 0
	for e in _est:
		if e == 2:
			n += 1
	return n


## A gota i para os testes: {ativa, x, y (px relativos a pr), idade, vida, forma, monstro}.
func gota(i: int) -> Dictionary:
	return {
		"ativa": _est[i] == 2, "x": _ox[i], "y": _oy[i], "idade": _idade[i], "vida": _vida[i], "forma": _forma[i], "monstro": _m[i / por_slot], "x0": _x0[i], "y0": _y0[i]
	}


## Os pixels que as gotas desenham agora, em px relativos ao ponto dos pés (pr) de cada monstro, de TODAS as vagas somadas: {Vector2i: Color}. Os testes medem aqui.
func pixels(so_vaga := -1) -> Dictionary:
	var r := {}
	var calmo := _calmo()
	for i in n_slots:
		if _m[i] == null or (so_vaga >= 0 and i != so_vaga):
			continue
		for j in por_slot:
			var g := i * por_slot + j
			if _est[g] != 2:
				continue
			var c := _cor(_idade[g] / maxf(_vida[g], 0.001), calmo)
			for p in _formas[_forma[g]]:
				r[Vector2i(_ox[g] + p.x, _oy[g] + p.y)] = c
	return r


## A vaga do monstro m (ou -1).
func vaga_de(m) -> int:
	return _m.find(m)


func n_gotas() -> int:
	return pool


func _calmo() -> bool:
	return Piscadas.ligado()


func _par(chave: String) -> Array:
	var c: Dictionary = cfg.get("calmo", {})
	if _calmo() and c.has(chave):
		return c[chave]
	return cfg.get(chave, [0.0, 0.0])


# ------------------------------------------------------------------ onde as gotas nascem

## A escala do desenho do monstro (lote: `escala`; com nó: `esc`).
static func escala_de(m) -> int:
	return maxi(int(roundf(m.escala if m.lote else m.esc)), 1)


## Os pontos de nascimento do quadro atual do monstro (cache por textura, coluna e linha): {pts: PackedInt32Array (x, y, x, y, ...) em px do quadro, x0, y0, x1, y1:
## a caixa dos pixels opacos}. Sem pixel opaco, `pts` vem vazio.
func pontos_do_quadro(m) -> Dictionary:
	var tex: Texture2D = m.tipo.alb
	var id := tex.get_instance_id()
	var por: Dictionary = _cache.get(id, {})
	var chave: int = int(m.linha) * 4096 + int(m.coluna)
	if por.has(chave):
		return por[chave]
	if not _imgs.has(id):
		_imgs[id] = tex.get_image()
	var im: Image = _imgs[id]
	var w := int(m.tipo.w)
	var h := int(m.tipo.h)
	var r := Rect2i(int(m.coluna) * w, int(m.linha) * h, w, h).intersection(Rect2i(0, 0, im.get_width(), im.get_height()))
	var res := {"pts": PackedInt32Array(), "x0": 0, "y0": 0, "x1": 0, "y1": 0}
	if r.has_area():
		var uso := im.get_region(r).get_used_rect()
		if uso.has_area():
			res.x0 = uso.position.x
			res.y0 = uso.position.y
			res.x1 = uso.end.x - 1
			res.y1 = uso.end.y - 1
			res.pts = _sortear(im, r, uso)
	por[chave] = res
	_cache[id] = por
	return res


func _sortear(im: Image, r: Rect2i, uso: Rect2i) -> PackedInt32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_RNG + r.position.x * 31 + r.position.y
	var bias := maxf(float(cfg.get("bias_baixo", 2.0)), 1.0)
	var meio := uso.position.y + uso.size.y / 2
	var cand := PackedInt32Array()
	for y in range(uso.position.y, uso.end.y):
		for x in range(uso.position.x, uso.end.x):
			if im.get_pixel(r.position.x + x, r.position.y + y).a < 0.5:
				continue
			if y < meio and rng.randf() > 1.0 / bias:
				continue  # metade de cima: entra com 1/bias da chance
			cand.append(x)
			cand.append(y)
	var maximo := maxi(int(cfg.get("pontos", 48)), 4)
	var total := cand.size() / 2
	if total <= maximo:
		return cand
	var saida := PackedInt32Array()
	var passo := float(total) / float(maximo)
	var ini := rng.randf() * passo
	for k in maximo:
		var j := mini(int(ini + k * passo), total - 1)
		saida.append(cand[j * 2])
		saida.append(cand[j * 2 + 1])
	return saida


# ------------------------------------------------------------------ a vida das gotas

func atualizar(dt: float) -> void:
	if combate == null:
		return
	if not Anim.suave:
		if ativos > 0:
			limpar()
		return
	for i in n_slots:
		if _m[i] != null:
			_passo_vaga(i, dt)
	_varrer()
	if no != null:
		no.queue_redraw()


func _vaga_vale(m) -> bool:
	return m != null and m.vivo and not m.morrendo and m.ativo and m.queima_t > 0.0 and not m.tipo.is_empty()


func _passo_vaga(i: int, dt: float) -> void:
	var m = _m[i]
	if not _vaga_vale(m):
		_soltar(i)
		return
	var base := i * por_slot
	var calmo := _calmo()
	var quer: int = mini(_n[i], 1) if calmo else _n[i]
	var s := escala_de(m)
	var dados := pontos_do_quadro(m)
	for j in por_slot:
		var g := base + j
		if j >= quer:
			_est[g] = 0
			continue
		if _est[g] == 0:
			_est[g] = 1
			_espera[g] = _rng.randf_range(0.0, float(_par("atraso_s")[1]))
		if _est[g] == 1:
			_espera[g] -= dt
			if _espera[g] > 0.0 or not _nascer(g, m, dados, s):
				continue
		_idade[g] += dt
		if _idade[g] >= _vida[g]:
			_est[g] = 1
			_espera[g] = _rng.randf_range(float(_par("atraso_s")[0]), float(_par("atraso_s")[1]))
			continue
		var oy := _y0[g] - _vel[g] * _idade[g]
		var ox := _x0[g] + _amp[g] * sin(_idade[g] * 5.6 + _fase[g])
		var lim := _limites(m, dados, s)
		if oy < lim.y0 - float(cfg.get("sobra_cabeca", 3)):
			_idade[g] = _vida[g]  # chegou à altura máxima: some
			_est[g] = 1
			_espera[g] = _rng.randf_range(float(_par("atraso_s")[0]), float(_par("atraso_s")[1]))
			continue
		var folga := float(cfg.get("sobra_lado", 2))
		ox = clampf(ox, lim.x0 - folga, lim.x1 + folga)
		_ox[g] = int(floorf(ox))
		_oy[g] = int(floorf(oy))


## A caixa dos pixels opacos do quadro atual em px da tela relativos a pr: {x0, x1, y0, y1} (espelho e escala já aplicados).
func _limites(m, dados: Dictionary, s: int) -> Dictionary:
	var w := int(m.tipo.w)
	var pe := float(m.tipo.pe)
	var lx0 := int(dados.x0)
	var lx1 := int(dados.x1)
	if m.espelha:
		var t := w - 1 - lx1
		lx1 = w - 1 - lx0
		lx0 = t
	return {
		"x0": float(lx0 - w / 2) * s,
		"x1": float(lx1 + 1 - w / 2) * s - 1.0,
		"y0": (float(dados.y0) - pe) * s,
		"y1": (float(dados.y1 + 1) - pe) * s - 1.0,
	}


## Nasce a gota g do monstro m num pixel opaco do quadro atual. Devolve false se o quadro não tem pixel opaco.
func _nascer(g: int, m, dados: Dictionary, s: int) -> bool:
	var pts: PackedInt32Array = dados.pts
	if pts.is_empty():
		return false
	var k := _rng.randi() % (pts.size() / 2)
	var lx := pts[k * 2]
	var ly := pts[k * 2 + 1]
	var w := int(m.tipo.w)
	if m.espelha:
		lx = w - 1 - lx
	_x0[g] = float(lx - w / 2) * s + float(s - 1) * 0.5
	_y0[g] = (float(ly) - float(m.tipo.pe)) * s + float(s - 1) * 0.5
	var v: Array = _par("sobe_px_s")
	_vel[g] = _rng.randf_range(float(v[0]), float(v[1]))
	var vi: Array = _par("vida_s")
	_vida[g] = _rng.randf_range(float(vi[0]), float(vi[1]))
	_amp[g] = _rng.randf_range(-1.0, 1.0) * (float(cfg.calmo.get("curva_px", 0)) if _calmo() else float(cfg.get("curva_px", 2)))
	_fase[g] = _rng.randf() * TAU
	var fm_ok: Array = []
	if _calmo():
		for nome in cfg.calmo.get("formas", []):
			fm_ok.append(_indice_forma(str(nome)))
	_forma[g] = _sortear_forma(fm_ok)
	_idade[g] = 0.0
	_est[g] = 2
	_ox[g] = int(floorf(_x0[g]))
	_oy[g] = int(floorf(_y0[g]))
	return true


func _indice_forma(nome: String) -> int:
	var nomes: Array = cfg.get("formas", {}).keys()
	nomes.sort()
	return maxi(nomes.find(nome), 0)


func _sortear_forma(entre: Array) -> int:
	var total := 0.0
	for k in _formas.size():
		if entre.is_empty() or entre.has(k):
			total += _pesos[k]
	var x := _rng.randf() * total
	for k in _formas.size():
		if entre.is_empty() or entre.has(k):
			x -= _pesos[k]
			if x <= 0.0:
				return k
	return 0


func _soltar(i: int) -> void:
	if _m[i] == null:
		return
	_m[i] = null
	_n[i] = 0
	for j in por_slot:
		_est[i * por_slot + j] = 0
	ativos -= 1


## Uma fatia da lista de monstros por quadro: quem queima, está na tela e não tem vaga ganha uma (elite e chefe podem usar as vagas reservadas).
func _varrer() -> void:
	var ms: Array = combate.mundo.monstros
	var n := ms.size()
	if n == 0:
		return
	for _k in mini(maxi(8, ceili(float(n) / FATIAS)), n):
		_cursor += 1
		if _cursor >= n:
			_cursor = 0
		var m = ms[_cursor]
		if not _vaga_vale(m) or _m.has(m):
			continue
		var especial: bool = m.elite or m.chefe
		var v := -1
		var ate := n_slots if especial else n_slots - vagas_elite
		for i in ate:
			if _m[i] == null:
				v = i
				break
		if v < 0:
			continue
		_m[v] = m
		var pm: Array = cfg.get("por_monstro", [2, 4])
		_n[v] = _rng.randi_range(int(pm[0]), int(pm[1]))
		ativos += 1
		for j in por_slot:
			_est[v * por_slot + j] = 0


# ------------------------------------------------------------------ desenho

func _desenhar() -> void:
	if no == null:
		return
	var calmo := _calmo()
	for i in n_slots:
		var m = _m[i]
		if m == null:
			continue
		var pe: Vector2 = m.pr
		var px := floorf(pe.x)
		var py := floorf(pe.y)
		for j in por_slot:
			var g := i * por_slot + j
			if _est[g] != 2:
				continue
			var c := _cor(_idade[g] / maxf(_vida[g], 0.001), calmo)
			for p in _formas[_forma[g]]:
				no.draw_rect(Rect2(px + _ox[g] + p.x, py + _oy[g] + p.y, 1.0, 1.0), c)


func _cor(f: float, calmo: bool) -> Color:
	if calmo:
		var k = cfg.calmo.get("cor", [246, 168, 30])
		return Color8(int(k[0]), int(k[1]), int(k[2]))
	var idx := 0
	for lim in _fases:
		if f >= float(lim):
			idx += 1
	return _cores[mini(idx, _cores.size() - 1)]
