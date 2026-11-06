extends RefCounted
## As GOTAS DE FOGO de quem queima (decisão do Alisson, 06/11; receita do Enter the Gungeon: o corpo tingido por v2/status_corpo.gd + partículas pequenas).
## Cada monstro queimando ganha de 10 (pequeno) a 14 (médio e grande) gotas vivas, 18 a 20 no elite e no chefe, e CADA GOTA É UMA MINI-ANIMAÇÃO: uma labareda de 3 a 5 px de largura
## e 4 a 8 de altura, de uma folha procedural de 8 quadros (fonte_arte/chama/gerar_gotas.py -> assets/v2/efeitos/chama_gotas.png): nasce gorda e clara, estica, a ponta
## tremula, a ponta se destaca em fagulha, o corpo sobe e encolhe, escurece (amarelo-claro, âmbar, laranja, vermelho, vermelho escuro) e some. O QUADRO AVANÇA PELA IDADE DA GOTA
## (não por relógio global): cada gota está numa fase diferente e o nascimento é contínuo, sem ondas. A ÂNCORA (centro da base da labareda) NASCE num pixel opaco do próprio corpo
## (lista pré-calculada UMA vez por tipo e quadro da folha, com viés `bias_baixo` para a metade de baixo: o pé pega fogo). Sobem com aceleração leve e balanço senoidal próprio;
## a posição é float e só o fim do passo arredonda para pixel inteiro. As gotas novas ficam ATRÁS das velhas (duas passadas de desenho: jovens, depois velhas).
## A gota inteira nunca sai de lado mais que `sobra_lado` px além da caixa opaca do corpo e a ponta passa no máximo `sobra_cabeca` px da cabeça (acima disso ela fica na altura
## máxima até acabar a vida, como uma coroa de fogo, sem estourar de uma vez).
## Pool FIXO em dados (v2_pixelfx.json, status.fogo.gotas): `vagas` vagas comuns de `por_vaga` gotas mais `vagas_elite` vagas só de elite e chefe de `por_vaga_elite` gotas
## (40 x 14 + 4 x 20 = 640); quem passa do limite fica só com o tingimento. UM nó com um desenho só (z_index 30, acima dos monstros; uma chamada por gota, mesma textura: o Godot
## junta num lote), RNG próprio (o da partida não é tocado), nenhum nó nasce na partida.
## Perfil Baixo (Anim.suave desligado): nenhuma gota. "Reduzir piscadas": 3 a 4 gotas por monstro CONGELADAS num quadro médio (sem trocar de quadro nem balançar), subindo
## devagar e com folga entre uma e outra (nenhum pixel troca mais de 2 vezes por segundo, medido em testes/v2_chama_particulas.gd).
## API: montar(c), atualizar(dt), limpar(), pontos_do_quadro(m) -> Dictionary, vivas() -> int, monstros() -> int, gota(i), pixels(vaga) (testes).

const Anim := preload("res://v2/anim_golpes.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const SEED_RNG := 6677
const FATIAS := 6  # a lista de monstros é varrida inteira em ~6 quadros
const PASTA := "res://assets/v2/"

var combate
var no: Node2D = null
var cfg: Dictionary = {}
var n_slots := 44  # vagas comuns + vagas de elite
var n_comuns := 40
var vagas_elite := 4  # as últimas vagas: só elite e chefe
var ativos := 0
var _rng := RandomNumberGenerator.new()
var _tex: Texture2D = null
var _img: Image = null
var _cw := 9  # célula da folha
var _ch := 12
var _ax := 4  # âncora na célula (centro da base)
var _ay := 11
var _nq := 8  # quadros por fila
var _ntam := 4  # tamanhos (fila = tamanho * 2 + variante)
var _px_q: Array = []  # por fila * quadros + quadro: PackedInt32Array (dx, dy, cor_rgba8) em px relativos à âncora
var _ex0 := PackedInt32Array()  # por fila * quadros + quadro: caixa dos pixels relativa à âncora
var _ex1 := PackedInt32Array()
var _topo := PackedInt32Array()  # linhas acima da âncora do pixel mais alto
var _cls: Array = []  # por classe: {ate: px, gotas: [min, max], pesos: PackedFloat32Array}
var _base := PackedInt32Array()  # por vaga: índice da 1ª gota
var _cap := PackedInt32Array()  # por vaga: quantas gotas tem
var _p := {}  # os parâmetros do modo atual (normal ou calmo)
var _calmo_ant := false
var _sob_cab := 6.0
var _sob_lado := 2.0
var _jovem := 0.35
var _cache := {}  # id da textura -> {chave -> {pts, x0, y0, x1, y1}}
var _imgs := {}  # id da textura -> Image
var _cursor := 0
var _m: Array = []  # por vaga: o monstro, ou null
var _n := PackedInt32Array()  # por vaga: quantas gotas vale
var _nc := PackedInt32Array()  # por vaga: quantas vale em "Reduzir piscadas"
var _classe := PackedInt32Array()  # por vaga: a classe de tamanho do monstro
var _est := PackedInt32Array()  # por gota: 0 = livre, 1 = esperando, 2 = no ar
var _idade := PackedFloat32Array()
var _vida := PackedFloat32Array()
var _espera := PackedFloat32Array()
var _x0 := PackedFloat32Array()  # onde nasceu (a âncora), em px da tela relativo ao ponto dos pés do monstro (pr)
var _y0 := PackedFloat32Array()
var _vel := PackedFloat32Array()
var _acel := PackedFloat32Array()
var _amp := PackedFloat32Array()
var _fase := PackedFloat32Array()
var _fila := PackedInt32Array()  # linha da folha (tamanho * 2 + variante)
var _quadro := PackedInt32Array()
var _ox := PackedInt32Array()  # onde a âncora está agora (px inteiros relativos a pr, arredondados), o que o desenho usa
var _oy := PackedInt32Array()


func montar(c) -> void:
	combate = c
	_rng.seed = SEED_RNG
	cfg = Dados.json("v2_pixelfx").get("status", {}).get("fogo", {}).get("gotas", {})
	n_comuns = maxi(int(cfg.get("vagas", 40)), 1)
	vagas_elite = clampi(int(cfg.get("vagas_elite", 4)), 0, 64)
	n_slots = n_comuns + vagas_elite
	var por_c := maxi(int(cfg.get("por_vaga", 14)), 1)
	var por_e := maxi(int(cfg.get("por_vaga_elite", 20)), 1)
	_base.resize(n_slots)
	_cap.resize(n_slots)
	var total := 0
	for i in n_slots:
		_base[i] = total
		_cap[i] = por_c if i < n_comuns else por_e
		total += _cap[i]
	_sob_cab = float(cfg.get("sobra_cabeca", 6))
	_sob_lado = float(cfg.get("sobra_lado", 2))
	_jovem = float(cfg.get("jovem", 0.35))
	_carregar_folha()
	_cls.clear()
	for nome in ["pequeno", "medio", "grande", "especial"]:
		var e: Dictionary = cfg.get("classes", {}).get(nome, {})
		var pesos := PackedFloat32Array()
		pesos.resize(_ntam)
		var tams: Array = cfg.get("folha", {}).get("tamanhos", [])
		for k in tams.size():
			pesos[k] = float(e.get("tamanhos", {}).get(tams[k], 0.0))
		_cls.append({"ate": float(e.get("ate_px", 99999)), "gotas": e.get("gotas", [10, 10]), "pesos": pesos})
	_p = _parametros(false)
	_calmo_ant = false
	_m.resize(n_slots)
	_n.resize(n_slots)
	_nc.resize(n_slots)
	_classe.resize(n_slots)
	for t in [_est, _fila, _quadro, _ox, _oy]:
		t.resize(total)
	for t in [_idade, _vida, _espera, _x0, _y0, _vel, _acel, _amp, _fase]:
		t.resize(total)
	var pai = combate.mundo.get("no_mundo")
	if pai is Node:
		no = Node2D.new()
		no.z_index = 30  # acima dos monstros e dos atores; abaixo só do depurador de colisão (400)
		no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		no.draw.connect(_desenhar)
		pai.add_child(no)


## Carrega a folha e mede, por fila e quadro, os pixels (para os testes) e a caixa (para a sobra de lado e de cima).
func _carregar_folha() -> void:
	var f: Dictionary = cfg.get("folha", {})
	var cel: Array = f.get("celula", [9, 12])
	var anc: Array = f.get("ancora", [4, 11])
	_cw = int(cel[0])
	_ch = int(cel[1])
	_ax = int(anc[0])
	_ay = int(anc[1])
	_nq = maxi(int(f.get("quadros", 8)), 1)
	_ntam = maxi(f.get("tamanhos", []).size(), 1)
	var arq := PASTA + str(f.get("arquivo", "efeitos/chama_gotas.png"))
	_tex = load(arq) if ResourceLoader.exists(arq) else null
	_px_q.clear()
	_ex0.clear()
	_ex1.clear()
	_topo.clear()
	if _tex == null:
		push_error("chama_gotas: folha ausente " + arq)
		return
	_img = _tex.get_image()
	for fila in _ntam * 2:
		for q in _nq:
			var lista := PackedInt32Array()
			var x0 := 999
			var x1 := -999
			var topo := 0
			for y in _ch:
				for x in _cw:
					var c := _img.get_pixel(q * _cw + x, fila * _ch + y)
					if c.a < 0.5:
						continue
					lista.append(x - _ax)
					lista.append(y - _ay)
					lista.append(int(c.to_rgba32()))
					x0 = mini(x0, x - _ax)
					x1 = maxi(x1, x - _ax)
					topo = maxi(topo, _ay - y)
			if lista.is_empty():
				x0 = 0
				x1 = 0
			_px_q.append(lista)
			_ex0.append(x0)
			_ex1.append(x1)
			_topo.append(topo)


## Os parâmetros do modo (normal ou "Reduzir piscadas": o que está em `calmo` troca o normal).
func _parametros(calmo: bool) -> Dictionary:
	var r := {}
	var c: Dictionary = cfg.get("calmo", {})
	for k in ["vida_s", "sobe_px_s", "acel_px_s2", "balanco_px", "atraso_s"]:
		var v: Array = c[k] if (calmo and c.has(k)) else cfg.get(k, [0.0, 0.0])
		r[k] = [float(v[0]), float(v[1])]
	r["balanco_hz"] = float(cfg.get("balanco_hz", 6.0))
	r["quadro_fixo"] = int(c.get("quadro", 2)) if calmo else -1
	return r


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


## O tamanho do pool (fixo).
func n_gotas() -> int:
	return _est.size()


## Quantas gotas a vaga i guarda (o máximo de uma vaga comum ou de elite).
func cap_da_vaga(i: int) -> int:
	return _cap[i]


## A gota i para os testes: {ativa, x, y (a âncora, px relativos a pr), idade, vida, fila, quadro, x0, y0}.
func gota(i: int) -> Dictionary:
	return {"ativa": _est[i] == 2, "x": _ox[i], "y": _oy[i], "idade": _idade[i], "vida": _vida[i], "fila": _fila[i], "quadro": _quadro[i], "x0": _x0[i], "y0": _y0[i]}


## Os pixels que as gotas desenham agora, em px relativos ao ponto dos pés (pr) de cada monstro, de TODAS as vagas somadas (ou só a `so_vaga`): {Vector2i: Color}, na
## mesma ordem do desenho (jovens primeiro, velhas por cima). Os testes medem aqui.
func pixels(so_vaga := -1) -> Dictionary:
	var r := {}
	for i in n_slots:
		if _m[i] == null or (so_vaga >= 0 and i != so_vaga):
			continue
		for passo in 2:
			for j in _n_vivas(i):
				var g: int = _base[i] + j
				if _est[g] != 2 or (_idade[g] < _vida[g] * _jovem) != (passo == 0):
					continue
				var lista: PackedInt32Array = _px_q[_fila[g] * _nq + _quadro[g]]
				for k in lista.size() / 3:
					var rgba: int = lista[k * 3 + 2]
					r[Vector2i(_ox[g] + lista[k * 3], _oy[g] + lista[k * 3 + 1])] = Color8((rgba >> 24) & 255, (rgba >> 16) & 255, (rgba >> 8) & 255)
	return r


## A vaga do monstro m (ou -1).
func vaga_de(m) -> int:
	return _m.find(m)


func _n_vivas(i: int) -> int:
	return mini(_nc[i], _cap[i]) if _calmo() else mini(_n[i], _cap[i])


func _calmo() -> bool:
	return Piscadas.ligado()


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
	var calmo := _calmo()
	if calmo != _calmo_ant:
		_calmo_ant = calmo
		_p = _parametros(calmo)
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
	var base: int = _base[i]
	var quer := _n_vivas(i)
	var s := escala_de(m)
	var dados := pontos_do_quadro(m)
	var lim := _limites(m, dados, s)
	var topo_max: float = lim.y0 - _sob_cab
	var at: Array = _p.atraso_s
	var fixo: int = _p.quadro_fixo
	var hz: float = _p.balanco_hz
	var nq := _nq
	for j in _cap[i]:
		var g := base + j
		if j >= quer:
			_est[g] = 0
			continue
		if _est[g] == 0:
			_est[g] = 1
			_espera[g] = _rng.randf_range(0.0, float(_p.vida_s[1]) if fixo < 0 else float(at[1]))  # começam espalhadas: sem onda
		if _est[g] == 1:
			_espera[g] -= dt
			if _espera[g] > 0.0 or not _nascer(g, m, dados, s, i):
				continue
		var t: float = _idade[g] + dt
		_idade[g] = t
		if t >= _vida[g]:
			_est[g] = 1
			_espera[g] = _rng.randf_range(at[0], at[1])
			continue
		var q := fixo if fixo >= 0 else mini(int(t / _vida[g] * nq), nq - 1)
		var idx: int = _fila[g] * nq + q
		_quadro[g] = q
		var y: float = _y0[g] - (_vel[g] + 0.5 * _acel[g] * t) * t
		var x: float = _x0[g] + _amp[g] * sin(t * hz + _fase[g])
		y = maxf(y, topo_max + float(_topo[idx]))  # a ponta não passa da sobra da cabeça: fica na altura máxima até acabar a vida
		var lo := ceili(lim.x0 - _sob_lado - float(_ex0[idx]))
		var hi := floori(lim.x1 + _sob_lado - float(_ex1[idx]))
		var xi := roundi(x)
		_ox[g] = clampi(xi, lo, hi) if lo <= hi else (lo + hi) / 2  # a gota INTEIRA fica a no máximo `sobra_lado` px da caixa
		_oy[g] = roundi(y)  # só aqui, no fim, a posição float vira pixel inteiro


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


## Nasce a gota g do monstro m (vaga i): a âncora num pixel opaco do quadro atual. Devolve false se o quadro não tem pixel opaco.
func _nascer(g: int, m, dados: Dictionary, s: int, i: int) -> bool:
	var pts: PackedInt32Array = dados.pts
	if pts.is_empty():
		return false
	var w := int(m.tipo.w)
	var tentativas := 8 if fixo_calmo() else 1  # "Reduzir piscadas": as gotas nunca se sobrepõem (sobreposição que acaba é uma troca de cor)
	var achou := false
	for _t in tentativas:
		var k := _rng.randi() % (pts.size() / 2)
		var lx := pts[k * 2]
		var ly := pts[k * 2 + 1]
		if m.espelha:
			lx = w - 1 - lx
		var nx := float(lx - w / 2) * s + float(s - 1) * 0.5
		var ny := (float(ly) - float(m.tipo.pe)) * s + float(s - 1) * 0.5
		achou = true
		if tentativas > 1:
			for j in _cap[i]:
				var o: int = _base[i] + j
				if o != g and _est[o] == 2 and absf(_x0[o] - nx) < 8.0 and absf(_y0[o] - ny) < 14.0:
					achou = false
					break
		if achou:
			_x0[g] = nx
			_y0[g] = ny
			break
	if not achou:
		return false
	var v: Array = _p.sobe_px_s
	_vel[g] = _rng.randf_range(v[0], v[1])
	var a: Array = _p.acel_px_s2
	_acel[g] = _rng.randf_range(a[0], a[1])
	var vi: Array = _p.vida_s
	_vida[g] = _rng.randf_range(vi[0], vi[1])
	var b: Array = _p.balanco_px
	_amp[g] = _rng.randf_range(-1.0, 1.0) * _rng.randf_range(b[0], b[1])
	_fase[g] = _rng.randf() * TAU
	_fila[g] = _sortear_tamanho(i) * 2 + (_rng.randi() & 1)
	_idade[g] = 0.0
	_quadro[g] = 0
	_est[g] = 2
	_ox[g] = roundi(_x0[g])
	_oy[g] = roundi(_y0[g])
	return true


func fixo_calmo() -> bool:
	return int(_p.quadro_fixo) >= 0


## O tamanho (coluna de tamanhos da folha) por peso da classe do monstro; em "Reduzir piscadas" só os tamanhos listados em `calmo.tamanhos`.
func _sortear_tamanho(i: int) -> int:
	var pesos: PackedFloat32Array = _cls[_classe[i]].pesos
	var ok: Array = []
	if _calmo():
		var nomes: Array = cfg.get("folha", {}).get("tamanhos", [])
		for nome in cfg.get("calmo", {}).get("tamanhos", []):
			ok.append(nomes.find(nome))
	var total := 0.0
	for k in pesos.size():
		total += pesos[k] if (ok.is_empty() or ok.has(k)) else 0.0
	var x := _rng.randf() * total
	var ult := 0
	for k in pesos.size():
		if ok.is_empty() or ok.has(k):
			if pesos[k] > 0.0:
				ult = k
			x -= pesos[k]
			if x <= 0.0 and pesos[k] > 0.0:
				return k
	return ult


func _soltar(i: int) -> void:
	if _m[i] == null:
		return
	_m[i] = null
	_n[i] = 0
	for j in _cap[i]:
		_est[_base[i] + j] = 0
	ativos -= 1


## A classe de tamanho do monstro (pelo alto da caixa opaca no quadro atual, em px da tela): 0 pequeno, 1 médio, 2 grande, 3 elite e chefe.
func _classe_de(m, especial: bool) -> int:
	if especial:
		return 3
	var dados := pontos_do_quadro(m)
	var alto := float(int(dados.y1) - int(dados.y0) + 1) * escala_de(m)
	for c in 2:
		if alto <= float(_cls[c].ate):
			return c
	return 2


## Uma fatia da lista de monstros por quadro: quem queima, está na tela e não tem vaga ganha uma (elite e chefe usam as vagas reservadas primeiro).
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
		if especial:
			for i in range(n_comuns, n_slots):
				if _m[i] == null:
					v = i
					break
		if v < 0:
			for i in n_comuns:
				if _m[i] == null:
					v = i
					break
		if v < 0:
			continue
		_m[v] = m
		_classe[v] = _classe_de(m, especial)
		var gs: Array = _cls[_classe[v]].gotas
		_n[v] = mini(_rng.randi_range(int(gs[0]), int(gs[1])), _cap[v])
		var gc: Array = cfg.get("calmo", {}).get("gotas", [3, 4])
		_nc[v] = mini(_rng.randi_range(int(gc[0]), int(gc[1])), _cap[v])
		ativos += 1
		for j in _cap[v]:
			_est[_base[v] + j] = 0


# ------------------------------------------------------------------ desenho

func _desenhar() -> void:
	if no == null or _tex == null:
		return
	var sz := Vector2(_cw, _ch)
	for i in n_slots:
		var m = _m[i]
		if m == null:
			continue
		var pe: Vector2 = m.pr
		var px := floorf(pe.x) - _ax
		var py := floorf(pe.y) - _ay
		var base: int = _base[i]
		var quer := _n_vivas(i)
		for passo in 2:  # 0: as jovens (atrás), 1: as velhas (por cima)
			for j in quer:
				var g := base + j
				if _est[g] != 2 or (_idade[g] < _vida[g] * _jovem) != (passo == 0):
					continue
				no.draw_texture_rect_region(_tex, Rect2(px + _ox[g], py + _oy[g], sz.x, sz.y), Rect2(_quadro[g] * _cw, _fila[g] * _ch, sz.x, sz.y))
