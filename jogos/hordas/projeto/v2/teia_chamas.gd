extends RefCounted
## As LABAREDAS da queima da teia (pedido do Alisson, 06/11: "usa os sprites da chama na queima da teia"). A folha teia_queima.png (fogo nasce num canto, corre pelo anel, fios viram brasa e cinza) lia como
## "brasa laranja pequena"; por cima dela nascem as MESMAS mini-animações das gotas de fogo dos monstros (assets/v2/efeitos/chama_gotas.png, v2/chama_gotas.gd, mesma paleta e mesmos 4 tamanhos):
## cada labareda é uma folha de 8 quadros (nasce gorda e clara, estica, tremula, a ponta vira fagulha, escurece e some) e o quadro avança pela IDADE dela, não por relógio global.
## ONDE NASCEM: nos pixels QUENTES (laranja e amarelo, `quente` em dados) da folha teia_queima no quadro e na variante (linha) que a teia está tocando AGORA, ou seja, ao longo da FRENTE DE FOGO: a lista de
## pixels quentes por linha e quadro é medida uma vez por linha (na 1ª vez que uma teia daquela linha queima, ~10 ms) e guardada. A âncora (centro da base da labareda) cai num pixel quente; sobe `sobe_px`
## px (6 a 14) com leve aceleração e balanço próprio e some. Enquanto a frente corre há `vivas` labaredas vivas por teia (20 a 40 em dados; o alvo cresce e cai com a quantidade de pixels quentes do quadro:
## poucas na ignição, o máximo no meio da corrida, poucas quando a frente morre). Quando a frente começa a passar, FAGULHAS nascem nas brasas da folha (os pixels vermelho escuro, dos quadros 4 e 5): são
## as mesmas labaredas começando no quadro 4 da folha (já pequenas), tamanho p ou m, e sobem mais alto. As labaredas são independentes da teia: terminam a própria vida mesmo que a folha da teia já tenha acabado.
## ONDE DESENHA: UM nó com z_index -49 (acima do chão da teia, -60, e das sombras, -51 e -50; ABAIXO dos monstros e do herói, z 0): o fogo está NO CHÃO, e o mecha que voa sobre a teia (é ele que a acende) fica
## por cima das labaredas em vez de ser coberto por elas (o nó das gotas dos monstros fica em 30 porque o fogo ali está no corpo; aqui cobrir o herói esconderia justo quem acendeu). Um desenho só por quadro,
## uma chamada por labareda, mesma textura (o Godot junta num lote). Pool FIXO (`pool` em dados), RNG próprio (o da partida não é tocado), nenhum nó nasce na partida.
## Perfil Baixo (Anim.suave desligado): nenhuma labareda (só a folha). "Reduzir piscadas": poucas labaredas (`calmo.vivas`), CONGELADAS num quadro médio (sem trocar de quadro nem balançar), que nascem uma
## a uma com folga, sobem 2 a 3 px devagar e nunca se sobrepõem: nenhum pixel troca mais de 2 vezes por segundo (medido em testes/v2_teia_queima.gd). A própria folha teia_queima.png toca a 10 quadros por
## segundo como antes (a luminância dela já é medida por v2_teia_folhas).
## API: montar(teias), atualizar(dt), limpar(), vivas() -> int, vivas_da_teia(i) -> int, n_pool() -> int, gota(g) -> Dictionary, pixels() -> Dictionary, quentes(linha, quadro) -> PackedInt32Array,
## brasas(linha, quadro) -> PackedInt32Array, retangulo(g) -> Rect2.

const Anim := preload("res://v2/anim_golpes.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const SEED_RNG := 7421
const PASTA := "res://assets/v2/"
const QUEIMANDO := 4  # Teias.QUEIMANDO

var teias
var cfg: Dictionary = {}
var no: Node2D = null
var n := 256
var ativas := 0
var _rng := RandomNumberGenerator.new()
var _tex: Texture2D = null
var _img: Image = null
var _cw := 9
var _ch := 12
var _ax := 4
var _ay := 11
var _nq := 8
var _tam: Array = []  # nomes dos tamanhos da folha ("p", "m", "g", "xg"): fila = tamanho * 2 + variante
var _qdata := PackedByteArray()  # a folha teia_queima em RGBA8, para medir os pixels quentes
var _qw := 96
var _qh := 64
var _qlargura := 0
var _qnq := 8
var _quente: Array = []  # por linha * quadros + quadro: PackedInt32Array (x, y, ...) em px do quadro da teia, ou null (ainda não medida)
var _brasa: Array = []
var _linha_ok := PackedByteArray()
var _p := {}  # os parâmetros do modo atual (normal ou calmo)
var _calmo_ant := false
# por labareda
var _est := PackedByteArray()  # 0 livre, 1 no ar
var _idade := PackedFloat32Array()
var _vida := PackedFloat32Array()
var _x0 := PackedFloat32Array()  # a âncora de nascimento (px do mundo)
var _y0 := PackedFloat32Array()
var _sobe := PackedFloat32Array()  # quantos px sobe em toda a vida
var _amp := PackedFloat32Array()
var _fase := PackedFloat32Array()
var _fila := PackedInt32Array()
var _q0 := PackedInt32Array()  # o quadro da folha em que a labareda começa (0; fagulha: 4)
var _qfix := PackedInt32Array()  # quadro fixo ("Reduzir piscadas") ou -1
var _quadro := PackedInt32Array()
var _ox := PackedInt32Array()  # onde a âncora está agora (px inteiros do mundo)
var _oy := PackedInt32Array()
var _src := PackedInt32Array()  # a teia de onde nasceu
var _fag := PackedByteArray()  # 1 = fagulha
var _nlinha := PackedInt32Array()  # onde nasceu na folha: a linha, o quadro da teia e o pixel (para os testes)
var _nquadro := PackedInt32Array()
var _npx := PackedInt32Array()
var _npy := PackedInt32Array()
var _cursor := 0
# por teia
var _queimava := PackedByteArray()
var _alvo := PackedInt32Array()  # labaredas vivas que a teia quer na frente de fogo
var _fag_n := PackedInt32Array()  # fagulhas que ela ainda pode soltar
var _nv := PackedInt32Array()  # vivas (sem as fagulhas)
var _nf := PackedInt32Array()  # fagulhas vivas
var _prox := PackedFloat32Array()  # "Reduzir piscadas": quando nasce a próxima


func montar(t) -> void:
	teias = t
	cfg = t.cfg.get("chamas", {})
	n = clampi(int(cfg.get("pool", 256)), 8, 2048)
	_rng.seed = SEED_RNG
	var folha: Dictionary = Dados.json("v2_pixelfx").get("status", {}).get("fogo", {}).get("gotas", {}).get("folha", {})
	var cel: Array = folha.get("celula", [9, 12])
	var anc: Array = folha.get("ancora", [4, 11])
	_cw = int(cel[0])
	_ch = int(cel[1])
	_ax = int(anc[0])
	_ay = int(anc[1])
	_nq = maxi(int(folha.get("quadros", 8)), 1)
	_tam = folha.get("tamanhos", ["p", "m", "g", "xg"])
	var arq := PASTA + str(folha.get("arquivo", "efeitos/chama_gotas.png"))
	_tex = load(arq) if ResourceLoader.exists(arq) else null
	if _tex == null:
		push_error("teia_chamas: folha ausente " + arq)
	else:
		_img = _tex.get_image()
	var fq: Dictionary = t._folhas.get("queima", {})
	if not fq.is_empty():
		_qw = int(fq.quadro.x)
		_qh = int(fq.quadro.y)
		_qnq = int(fq.quadros)
		var im: Image = (fq.tex as Texture2D).get_image()
		if im.get_format() != Image.FORMAT_RGBA8:
			im.convert(Image.FORMAT_RGBA8)
		_qdata = im.get_data()
		_qlargura = im.get_width()
	var linhas := maxi(int(fq.get("linhas", 8)), 1)
	_quente.resize(linhas * _qnq)
	_brasa.resize(linhas * _qnq)
	_linha_ok.resize(linhas)
	for a in [_est, _fag]:
		a.resize(n)
	for a in [_idade, _vida, _x0, _y0, _sobe, _amp, _fase]:
		a.resize(n)
	for a in [_fila, _q0, _qfix, _quadro, _ox, _oy, _src, _nlinha, _nquadro, _npx, _npy]:
		a.resize(n)
	var nt: int = t._est.size()
	_queimava.resize(nt)
	for a in [_alvo, _fag_n, _nv, _nf]:
		a.resize(nt)
	_prox.resize(nt)
	_p = _parametros(false)
	_calmo_ant = false
	var pai = t.mundo.get("no_mundo")
	if pai is Node:
		no = Node2D.new()
		no.z_index = -49  # acima do chão da teia (-60) e das sombras (-51, -50), abaixo dos monstros e do herói (0): ver o cabeçalho
		no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		no.draw.connect(_desenhar)
		pai.add_child(no)


## Os parâmetros do modo (normal ou "Reduzir piscadas": o que está em `calmo` troca o normal).
func _parametros(calmo: bool) -> Dictionary:
	var r := {}
	var c: Dictionary = cfg.get("calmo", {})
	for k in ["vivas", "vida_s", "sobe_px", "balanco_px", "atraso_s"]:
		var v: Array = c[k] if (calmo and c.has(k)) else cfg.get(k, [0.0, 0.0])
		r[k] = [float(v[0]), float(v[1])]
	r["balanco_hz"] = float(cfg.get("balanco_hz", 6.0))
	r["quadro_fixo"] = int(c.get("quadro", 2)) if calmo else -1
	r["tamanhos"] = c.get("tamanhos", {}) if calmo else cfg.get("tamanhos", {})
	return r


func limpar() -> void:
	_est.fill(0)
	_queimava.fill(0)
	_alvo.fill(0)
	_fag_n.fill(0)
	_nv.fill(0)
	_nf.fill(0)
	ativas = 0
	if no != null:
		no.queue_redraw()


func vivas() -> int:
	return ativas


func vivas_da_teia(i: int) -> int:
	return _nv[i] + _nf[i]


func n_pool() -> int:
	return n


## A labareda g para os testes: {ativa, x, y (a âncora, px do mundo), idade, vida, fila, quadro, fagulha, src, linha, q_teia, px, py}. `linha`, `q_teia`, `px` e `py` dizem onde ela nasceu na folha da teia.
func gota(g: int) -> Dictionary:
	return {
		"ativa": _est[g] == 1,
		"x": _ox[g],
		"y": _oy[g],
		"idade": _idade[g],
		"vida": _vida[g],
		"fila": _fila[g],
		"quadro": _quadro[g],
		"fagulha": _fag[g] == 1,
		"src": _src[g],
		"linha": _nlinha[g],
		"q_teia": _nquadro[g],
		"px": _npx[g],
		"py": _npy[g],
		"x0": _x0[g],
		"y0": _y0[g]
	}


## O retângulo de desenho da labareda g (px do mundo).
func retangulo(g: int) -> Rect2:
	return Rect2(_ox[g] - _ax, _oy[g] - _ay, _cw, _ch)


## Os pixels que as labaredas desenham agora (px do mundo): {Vector2i: Color}. Os testes medem aqui.
func pixels() -> Dictionary:
	var r := {}
	if _img == null:
		return r
	for g in n:
		if _est[g] != 1:
			continue
		for y in _ch:
			for x in _cw:
				var c := _img.get_pixel(_quadro[g] * _cw + x, _fila[g] * _ch + y)
				if c.a >= 0.5:
					r[Vector2i(_ox[g] + x - _ax, _oy[g] + y - _ay)] = Color(c.r, c.g, c.b)
	return r


# ------------------------------------------------------------------ pixels quentes e brasas da folha da teia


## Os pixels quentes (laranja e amarelo: a frente de fogo) do quadro `q` da linha `linha` de teia_queima.png, em px do quadro: (x, y, x, y, ...).
func quentes(linha: int, q: int) -> PackedInt32Array:
	_medir(linha)
	return _quente[linha * _qnq + clampi(q, 0, _qnq - 1)]


## As brasas (vermelho escuro) do quadro `q`.
func brasas(linha: int, q: int) -> PackedInt32Array:
	_medir(linha)
	return _brasa[linha * _qnq + clampi(q, 0, _qnq - 1)]


func _medir(linha: int) -> void:
	if _linha_ok[linha] != 0 or _qdata.is_empty():
		return
	_linha_ok[linha] = 1
	var qt: Array = cfg.get("quente", [200, 85, 40])
	var bt: Array = cfg.get("brasa", [70, 170, 50, 45])
	var rmin := int(qt[0])
	var gmin := int(qt[1])
	var rbmin := int(qt[2])
	for q in _qnq:
		var qs := PackedInt32Array()
		var bs := PackedInt32Array()
		for y in _qh:
			var o := ((linha * _qh + y) * _qlargura + q * _qw) * 4
			for x in _qw:
				if _qdata[o + 3] != 0:
					var r := _qdata[o]
					var g := _qdata[o + 1]
					var b := _qdata[o + 2]
					if r >= rmin and g >= gmin and r - b >= rbmin:
						qs.append(x)
						qs.append(y)
					elif r >= int(bt[0]) and r <= int(bt[1]) and g <= int(bt[2]) and b <= int(bt[3]):
						bs.append(x)
						bs.append(y)
				o += 4
		_quente[linha * _qnq + q] = qs
		_brasa[linha * _qnq + q] = bs


# ------------------------------------------------------------------ a vida das labaredas


func atualizar(dt: float) -> void:
	if teias == null:
		return
	if not Anim.suave:
		if ativas > 0:
			limpar()
		return
	var calmo := Piscadas.ligado()
	if calmo != _calmo_ant:
		_calmo_ant = calmo
		_p = _parametros(calmo)
	var nt: int = teias._est.size()
	for i in nt:
		if teias._est[i] == QUEIMANDO:
			if _queimava[i] == 0:
				_acender(i)
			_semear(i, dt)
		else:
			_queimava[i] = 0
	_envelhecer(dt)
	if no != null:
		no.queue_redraw()


func _acender(i: int) -> void:
	_queimava[i] = 1
	var v: Array = _p.vivas
	_alvo[i] = _rng.randi_range(int(v[0]), int(v[1]))
	var f: Array = cfg.get("fagulhas", {}).get("n", [10, 14])
	_fag_n[i] = 0 if _calmo_ant else _rng.randi_range(int(f[0]), int(f[1]))
	_prox[i] = 0.0
	var nv := 0
	var nf := 0
	for g in n:  # o slot da teia pode estar de volta antes de as labaredas da queima anterior acabarem: recontar
		if _est[g] == 1 and _src[g] == i:
			if _fag[g] == 1:
				nf += 1
			else:
				nv += 1
	_nv[i] = nv
	_nf[i] = nf


## Uma teia queimando, neste quadro: a frente (muitos pixels quentes) mantém `alvo` x envelope labaredas vivas; a partir do quadro `fagulhas.quadro_ini`, fagulhas nas brasas do quadro.
func _semear(i: int, dt: float) -> void:
	var t: float = teias._t[i]
	var f: Dictionary = teias._folhas.queima
	var q := mini(int(t * float(f.fps)), _qnq - 1)
	var linha: int = int(teias._geo[i]) * 4 + int(teias._var[i])
	var pq := quentes(linha, q)
	var n_quentes := pq.size() / 2
	var fixo: int = _p.quadro_fixo
	if n_quentes >= int(cfg.get("frente_min", 40)):
		var env := clampf(float(n_quentes) / maxf(float(cfg.get("frente_ref", 500)), 1.0), 0.0, 1.0)
		var quer := ceili(float(_alvo[i]) * env)
		if fixo >= 0:  # "Reduzir piscadas": uma a uma, com folga entre elas
			_prox[i] -= dt
			if _nv[i] < quer and _prox[i] <= 0.0 and _nascer(i, pq, false, q, linha):
				var at: Array = _p.atraso_s
				_prox[i] = _rng.randf_range(at[0], at[1])
		else:
			var rapido := int(cfg.get("por_quadro", 4))
			while _nv[i] < quer and rapido > 0:
				if not _nascer(i, pq, false, q, linha):
					break
				rapido -= 1
	if fixo >= 0 or _fag_n[i] <= 0:
		return
	var fg: Dictionary = cfg.get("fagulhas", {})
	var q_ini := int(fg.get("quadro_ini", 4))
	if q < q_ini or t > float(fg.get("ate_s", 0.6)):
		return
	var pb := brasas(linha, q)  # só as brasas DESTE quadro: a fagulha nasce sobre um pixel que a folha está mostrando
	if pb.is_empty():
		return
	var janela := maxf(float(fg.get("ate_s", 0.6)) - float(q_ini) / float(f.fps), 0.05)
	if _rng.randf() < float(_fag_n[i]) / janela * dt * 2.0 and _nascer(i, pb, true, q, linha):
		_fag_n[i] -= 1


## Nasce uma labareda da teia i com a âncora num dos pixels de `pts` (px do quadro da teia): false se o pool está cheio ou nenhum ponto serve.
func _nascer(i: int, pts: PackedInt32Array, fag: bool, q: int, linha: int) -> bool:
	if pts.is_empty():
		return false
	var g := -1
	for k in n:
		_cursor += 1
		if _cursor >= n:
			_cursor = 0
		if _est[_cursor] == 0:
			g = _cursor
			break
	if g < 0:
		return false
	var fq: Dictionary = teias._folhas.queima
	var base: Vector2 = (teias._pos[i] - fq.pivo).round()
	var tentativas := 8 if _p.quadro_fixo >= 0 else 1  # "Reduzir piscadas": as labaredas nunca se sobrepõem (sobreposição que acaba é uma troca de cor)
	var px := 0
	var py := 0
	var nx := 0.0
	var ny := 0.0
	var achou := false
	for _t in tentativas:
		var k := _rng.randi() % (pts.size() / 2)
		px = pts[k * 2]
		py = pts[k * 2 + 1]
		nx = base.x + float(px)
		ny = base.y + float(py)
		achou = true
		if tentativas > 1:
			for o in n:
				if _est[o] == 1 and absf(_x0[o] - nx) < float(_cw + 1) and absf(_y0[o] - ny) < float(_ch + 4):
					achou = false
					break
		if achou:
			break
	if not achou:
		return false
	var v: Array = _p.vida_s
	var s: Array = _p.sobe_px
	var b: Array = _p.balanco_px
	_x0[g] = nx
	_y0[g] = ny
	_vida[g] = _rng.randf_range(v[0], v[1])
	_sobe[g] = _rng.randf_range(s[0], s[1])
	_amp[g] = _rng.randf_range(-1.0, 1.0) * _rng.randf_range(b[0], b[1])
	_fase[g] = _rng.randf() * TAU
	_fila[g] = _sortear_tamanho(fag) * 2 + (_rng.randi() & 1)
	_q0[g] = int(cfg.get("fagulhas", {}).get("quadro_ini", 4)) if fag else 0
	_qfix[g] = int(_p.quadro_fixo)
	_idade[g] = 0.0
	_quadro[g] = maxi(_q0[g], 0) if _qfix[g] < 0 else _qfix[g]
	_ox[g] = roundi(nx)
	_oy[g] = roundi(ny)
	_src[g] = i
	_fag[g] = 1 if fag else 0
	_nlinha[g] = linha
	_nquadro[g] = q
	_npx[g] = px
	_npy[g] = py
	_est[g] = 1
	ativas += 1
	if fag:
		_nf[i] += 1
	else:
		_nv[i] += 1
	return true


## O tamanho (fila par da folha) por peso: `tamanhos` (normal ou calmo) para as labaredas, `fagulhas.tamanhos` para as fagulhas.
func _sortear_tamanho(fag: bool) -> int:
	var pesos: Dictionary = cfg.get("fagulhas", {}).get("tamanhos", {"p": 3, "m": 1}) if fag else _p.tamanhos
	var total := 0.0
	for k in _tam.size():
		total += float(pesos.get(_tam[k], 0.0))
	if total <= 0.0:
		return 0
	var x := _rng.randf() * total
	var ult := 0
	for k in _tam.size():
		var w := float(pesos.get(_tam[k], 0.0))
		if w > 0.0:
			ult = k
			x -= w
			if x <= 0.0:
				return k
	return ult


func _envelhecer(dt: float) -> void:
	var hz: float = _p.balanco_hz
	for g in n:
		if _est[g] != 1:
			continue
		var t := _idade[g] + dt
		_idade[g] = t
		if t >= _vida[g]:
			_est[g] = 0
			ativas -= 1
			var i := _src[g]
			if _fag[g] == 1:
				_nf[i] = maxi(_nf[i] - 1, 0)
			else:
				_nv[i] = maxi(_nv[i] - 1, 0)
			continue
		var u := t / _vida[g]
		var q := _qfix[g] if _qfix[g] >= 0 else _q0[g] + mini(int(u * float(_nq - _q0[g])), _nq - 1 - _q0[g])
		_quadro[g] = q
		var y := _y0[g] - _sobe[g] * u * (0.6 + 0.4 * u)  # sobe e acelera de leve; só aqui, no fim, vira px inteiro
		var x := _x0[g] + _amp[g] * sin(t * hz + _fase[g])
		_ox[g] = roundi(x)
		_oy[g] = roundi(y)


# ------------------------------------------------------------------ desenho


func _desenhar() -> void:
	if no == null or _tex == null or ativas <= 0:
		return
	var sz := Vector2(_cw, _ch)
	for g in n:
		if _est[g] != 1:
			continue
		no.draw_texture_rect_region(_tex, Rect2(_ox[g] - _ax, _oy[g] - _ay, sz.x, sz.y), Rect2(_quadro[g] * _cw, _fila[g] * _ch, sz.x, sz.y))
