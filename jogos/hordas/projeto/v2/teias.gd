extends RefCounted
## A TEIA DA ARANHA no chão (pedido do Alisson, 06/11). Números em dados/v2_teia.json; arte em assets/v2/teias/ (fonte_arte/teia/gerar_teia.py).
##  - A aranha com a flag `teia` (v2/monstro.gd) pede `disparar`: sai uma bolota que VOA (arco, fio de 1 px ligado à boca e, nos últimos instantes, a rede abrindo no
##    ar), POUSA e ABRE no chão (elipse achatada, a mesma proporção dos avisos) e fica PARADA por `vida_s`; depois DESMANCHA (`sumir_s`). Mais velha que o teto desmancha antes.
##  - O CHÃO: um único Node2D com z_index -60 (a mesma camada do chão de efeitos.gd: acima do decalque do cenário, abaixo das sombras e dos monstros) e uma só
##    chamada de desenho por quadro. Nenhum nó nasce durante a partida: as teias são vetores de tamanho fixo (o pool é dimensionado pelo pico: 2 x max_vivas + max_voando).
##  - LENTIDÃO: o herói com os pés dentro da elipse ganha a fonte "teia" em `Heroi.lento_fontes` (o menor multiplicador vale; v2/heroi.gd). O mecha do LightWolf em VOO
##    (impulso, `voando`) não fica lento e, se o propulsor passar por cima (a elipse mais `queima.margem`), a teia QUEIMA: o fogo nasce no canto do lado dele e corre pelo anel.
##  - CORTE: `cortar_arco` (chamado por combate.golpear, ruptura e especiais) parte a teia que o golpe cobre: risco diagonal (corte) ou estilhaço radial (martelo, giro de 360 graus).
##  - A QUEIMA ganha LABAREDAS por cima da folha (v2/teia_chamas.gd, `chamas` em dados): as mini-animações das gotas de fogo nascem nos pixels quentes da frente de fogo.
##  - RNG próprio (a recarga das aranhas): o RNG da partida não é tocado. Sem partículas: tudo é folha de pixel art; no perfil Baixo o teto de teias cai e a abertura pula quadros.
## API: montar(c), atualizar(dt), limpar(), disparar(m, dir) -> bool, lancar(chao, alt0, alvo) -> bool, pode_lancar(), dentro(p) -> bool, voando(h) -> bool,
## cortar_arco(origem, dir, alc, arco, tipo) -> int, tipo_do_passo(nome) -> String, sorteio_recarga(inicial) -> float, contar(estado) -> int.

const Anim := preload("res://v2/anim_golpes.gd")
const Chamas := preload("res://v2/teia_chamas.gd")  # as labaredas (mesma folha das gotas de fogo) sobre a frente de fogo da queima
const PASTA := "res://assets/v2/teias/"
const LIVRE := 0
const VOANDO := 1
const ABRINDO := 2
const PARADA := 3
const QUEIMANDO := 4
const CORTADA := 5
const QUEBRADA := 6
const SUMINDO := 7
const FIO := Color(0.886, 0.925, 0.969)
const SOMBRA := Color(0.118, 0.149, 0.235)
const SEED_RNG := 5150

var combate
var mundo
var cfg: Dictionary = {}
var no: Node2D = null
var chamas  # v2/teia_chamas.gd
var raio := 40.0
var achata := 0.62
var vida_s := 12.0
var sumir_s := 1.0
var max_vivas := 6
var max_vivas_baixo := 3
var max_voando := 4
var lento_mult := 0.5
var queimando_lento := false
var estados_lentos: Array = []  # os Heroi.Estado (int) em que a teia segura
var aranha: Dictionary = {}
var lancadas := 0  # testes e calibragem
var queimadas := 0
var cortadas := 0
var _folhas := {}
var _rng := RandomNumberGenerator.new()
var _est := PackedInt32Array()
var _t := PackedFloat32Array()  # s no estado
var _idade := PackedFloat32Array()  # s desde o pouso (a vida da teia)
var _pos := PackedVector2Array()  # o centro da teia (o ponto do pouso)
var _ini := PackedVector2Array()  # voo: de onde a bolota saiu (no chão)
var _boca := PackedVector2Array()  # voo: onde o fio está preso (a boca da aranha)
var _alt0 := PackedFloat32Array()
var _geo := PackedInt32Array()  # qual das geometrias da folha
var _var := PackedInt32Array()  # queima: bits do canto (1 = espelha H, 2 = espelha V); corte: 0 "/" e 1 "\"
var _desenhado := false


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	_rng.seed = SEED_RNG
	cfg = Dados.json("v2_teia")
	var t: Dictionary = cfg.get("teia", {})
	raio = float(t.get("raio", 40))
	achata = float(t.get("achata", 0.62))
	vida_s = float(t.get("vida_s", 12.0))
	sumir_s = maxf(float(t.get("sumir_s", 1.0)), 0.05)
	max_vivas = maxi(int(t.get("max_vivas", 6)), 1)
	max_vivas_baixo = maxi(int(t.get("max_vivas_baixo", 3)), 1)
	max_voando = maxi(int(t.get("max_voando", 4)), 1)
	var l: Dictionary = cfg.get("lento", {})
	lento_mult = clampf(float(l.get("mult", 0.5)), 0.05, 1.0)
	queimando_lento = bool(l.get("queimando_lento", false))
	estados_lentos.clear()
	for nome in l.get("estados", []):
		var v := estado_do_heroi(str(nome))
		if v >= 0:
			estados_lentos.append(v)
	aranha = cfg.get("aranha", {})
	var n := 2 * max_vivas + max_voando
	_est.resize(n)
	_t.resize(n)
	_idade.resize(n)
	_pos.resize(n)
	_ini.resize(n)
	_boca.resize(n)
	_alt0.resize(n)
	_geo.resize(n)
	_var.resize(n)
	for k in cfg.get("folhas", {}):
		var e: Dictionary = cfg.folhas[k]
		var tex = load(PASTA + str(e.arquivo)) if ResourceLoader.exists(PASTA + str(e.arquivo)) else null
		if not (tex is Texture2D):
			push_error("teia '%s': folha não encontrada (%s)" % [k, PASTA + str(e.arquivo)])
			continue
		_folhas[str(k)] = {
			"tex": tex,
			"quadro": Vector2(float(e.quadro[0]), float(e.quadro[1])),
			"quadros": int(e.quadros),
			"linhas": int(e.get("linhas", 1)),
			"fps": maxf(float(e.fps), 1.0),
			"pivo": Vector2(float(e.pivo[0]), float(e.pivo[1])),
		}
	var pai = mundo.get("no_mundo")
	if pai is Node:
		no = Node2D.new()
		no.z_index = -60  # a camada do chão de efeitos.gd: acima do decalque do cenário (-90), abaixo das sombras (-51 e -50) e dos monstros
		no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		no.draw.connect(_desenhar)
		pai.add_child(no)
	chamas = Chamas.new()
	chamas.montar(self)


## O número do estado do herói (Heroi.Estado) pelo nome; -1 se não existe.
static func estado_do_heroi(nome: String) -> int:
	var e: Dictionary = preload("res://v2/heroi.gd").Estado
	return int(e[nome]) if e.has(nome) else -1


func limpar() -> void:
	_est.fill(LIVRE)
	_desenhado = false
	var h = mundo.heroi if mundo != null else null
	if h != null:
		h.lento_fontes.erase("teia")
	if no != null:
		no.queue_redraw()
	if chamas != null:
		chamas.limpar()


func teto_vivas() -> int:
	return max_vivas if Anim.suave else mini(max_vivas, max_vivas_baixo)


func contar(estado: int) -> int:
	var n := 0
	for e in _est:
		if e == estado:
			n += 1
	return n


func _livre() -> int:
	for i in _est.size():
		if _est[i] == LIVRE:
			return i
	return -1


func pode_lancar() -> bool:
	return contar(VOANDO) < max_voando and _livre() >= 0


## O tempo (s) até a aranha poder atirar de novo (ou o primeiro tiro, `inicial`), sorteado com o RNG próprio da teia.
func sorteio_recarga(inicial := false) -> float:
	var r: Array = aranha.get("recarga_inicial" if inicial else "recarga", [6.0, 9.0])
	return _rng.randf_range(float(r[0]), float(r[1]))


## A aranha `m` atira na direção `dir` (unitária, para o herói): sai da boca, mira à frente do herói. false se não há bolota livre.
func disparar(m, dir: Vector2) -> bool:
	var h = mundo.heroi
	var esc := float(m.escala)
	var chao: Vector2 = (m.pos + dir * float(aranha.get("boca_dist", 10)) * esc).round()
	var alt0 := float(aranha.get("boca_alt", 10)) * esc
	var alvo: Vector2 = h.pos + h.vel * float(aranha.get("mira_a_frente", 0.35)) * float(aranha.get("voo_s", 0.65))
	return lancar(chao, alt0, alvo)


## Uma bolota sai de `chao` (o ponto do chão sob a boca, a `alt0` px de altura) e pousa em `alvo`.
func lancar(chao: Vector2, alt0: float, alvo: Vector2) -> bool:
	if not pode_lancar():
		return false
	var i := _livre()
	_est[i] = VOANDO
	_t[i] = 0.0
	_idade[i] = 0.0
	_ini[i] = chao
	_boca[i] = chao + Vector2(0.0, -alt0)
	_alt0[i] = alt0
	_pos[i] = alvo.round()
	_geo[i] = _rng.randi() % maxi(int(_folhas.get("abre", {}).get("linhas", 1)), 1)
	_var[i] = 0
	lancadas += 1
	return true


## O mecha do LightWolf está voando (o impulso) e alto o bastante para os propulsores acenderem a teia?
func voando(h) -> bool:
	return h != null and h.imp_t > 0.0 and h.alt_px >= int(cfg.get("queima", {}).get("alt_min_px", 4))


func _contem(i: int, p: Vector2, margem := 0.0) -> bool:
	var rx := raio + margem
	var ry := raio * achata + margem * achata
	var dx := (p.x - _pos[i].x) / rx
	var dy := (p.y - _pos[i].y) / ry
	return dx * dx + dy * dy <= 1.0


func _no_chao(i: int) -> bool:
	var e := _est[i]
	return e == ABRINDO or e == PARADA or e == SUMINDO


## O ponto `p` está sobre alguma teia que segura (no chão, ou em chamas se `queimando_lento`)?
func dentro(p: Vector2) -> bool:
	for i in _est.size():
		if (_no_chao(i) or (queimando_lento and _est[i] == QUEIMANDO)) and _contem(i, p):
			return true
	return false


func _folha_fim(nome: String, t: float) -> bool:
	var f: Dictionary = _folhas.get(nome, {})
	return f.is_empty() or t * float(f.fps) >= float(f.quadros)


func atualizar(dt: float) -> void:
	var algum := false
	var voo_s := float(aranha.get("voo_s", 0.65))
	for i in _est.size():
		var e := _est[i]
		if e == LIVRE:
			continue
		algum = true
		_t[i] += dt
		match e:
			VOANDO:
				if _t[i] >= voo_s:
					_pousar(i)
			ABRINDO:
				_idade[i] += dt
				if _folha_fim("abre", _t[i]):
					_est[i] = PARADA
					_t[i] = 0.0
			PARADA:
				_idade[i] += dt
				if _idade[i] >= vida_s:
					_est[i] = SUMINDO
					_t[i] = 0.0
			SUMINDO:
				if _t[i] >= sumir_s:
					_est[i] = LIVRE
			QUEIMANDO:
				if _folha_fim("queima", _t[i]):
					_est[i] = LIVRE
			CORTADA:
				if _folha_fim("corte", _t[i]):
					_est[i] = LIVRE
			QUEBRADA:
				if _folha_fim("quebra", _t[i]):
					_est[i] = LIVRE
	_heroi()
	if no != null and (algum or _desenhado):
		no.queue_redraw()
	_desenhado = algum
	chamas.atualizar(dt)  # depois do passo: vê as teias que acabaram de pegar fogo


func _pousar(i: int) -> void:
	_est[i] = ABRINDO
	_t[i] = 0.0
	_idade[i] = 0.0
	# acima do teto, a mais velha desmancha (a que acabou de pousar não conta)
	var vivas := 0
	for k in _est.size():
		if k != i and (_est[k] == ABRINDO or _est[k] == PARADA):
			vivas += 1
	while vivas >= teto_vivas():
		var velha := -1
		for k in _est.size():
			if k != i and (_est[k] == ABRINDO or _est[k] == PARADA) and (velha < 0 or _idade[k] > _idade[velha]):
				velha = k
		if velha < 0:
			break
		_est[velha] = SUMINDO
		_t[velha] = 0.0
		vivas -= 1


## O herói e a teia, todo quadro: dentro dela (e no chão) fica lento; o mecha em voo não fica e, passando por cima, queima a teia.
func _heroi() -> void:
	var h = mundo.heroi
	if h == null:
		return
	var voa := voando(h)
	var margem := float(cfg.get("queima", {}).get("margem", 4))
	var em := false
	if h.vivo():
		for i in _est.size():
			if not _no_chao(i):
				continue
			if voa:
				if _contem(i, h.pos, margem):
					_queimar(i, h.pos)
			elif _contem(i, h.pos):
				em = true
	if em:
		h.lento_fontes["teia"] = lento_mult
		h.lento_estados = estados_lentos
	elif h.lento_fontes.has("teia"):
		h.lento_fontes.erase("teia")


func _queimar(i: int, de: Vector2) -> void:
	_est[i] = QUEIMANDO
	_t[i] = 0.0
	var bits := 0
	if de.x - _pos[i].x >= 0.0:
		bits |= 1  # a folha nasce com o fogo no canto de cima à esquerda: o herói à direita espelha em H, embaixo em V
	if de.y - _pos[i].y >= 0.0:
		bits |= 2
	_var[i] = bits
	queimadas += 1
	if combate != null and combate.audio != null:
		combate.audio.tocar("fogo", 1.3, -9.0, 0.25)


## O desenho do corte que o passo `nome` do golpe faz ("corte", "quebra") ou "" se ele não corta teia (dados/v2_teia.json > corta > passos).
func tipo_do_passo(nome: String) -> String:
	var v = cfg.get("corta", {}).get("passos", {}).get(nome, "")
	return str(v) if v is String else ""


## O desenho do corte da ruptura do Hazaki e o dos especiais (Q: "terremoto", "investida"); "" = não corta.
func tipo_ruptura() -> String:
	var v = cfg.get("corta", {}).get("ruptura", "")
	return str(v) if v is String else ""


func tipo_especial(id: String) -> String:
	var v = cfg.get("corta", {}).get("especiais", {}).get(id, "")
	return str(v) if v is String else ""


## Parte toda teia no chão que o golpe cobre: o arco de `arco` graus e alcance `alc` a partir de `origem` (os pés do herói) para `dir`. Amostra 17 pontos da teia
## (centro, 8 no perímetro e 8 a meio raio): um dentro do arco basta. `tipo`: "corte" (risco na diagonal do golpe) ou "quebra" (estilhaço radial). Devolve quantas partiu.
func cortar_arco(origem: Vector2, dir: Vector2, alc: float, arco: float, tipo: String) -> int:
	if tipo == "":
		return 0
	var cos_meio := cos(deg_to_rad(arco * 0.5))
	var n := 0
	for i in _est.size():
		if not _no_chao(i):
			continue
		if not _toca_arco(i, origem, dir, alc, arco, cos_meio):
			continue
		_partir(i, tipo, dir)
		n += 1
	return n


## A ruptura e o terremoto: parte toda teia cuja borda toca a elipse do chão de `raio` em volta de `centro` (a mesma proporção dos avisos). `tipo` como em `cortar_arco`.
func cortar_elipse(centro: Vector2, raio_golpe: float, tipo: String) -> int:
	if tipo == "":
		return 0
	var n := 0
	for i in _est.size():
		if not _no_chao(i):
			continue
		var r := raio_golpe + raio
		var dx := (_pos[i].x - centro.x) / r
		var dy := (_pos[i].y - centro.y) / (r * achata)
		if dx * dx + dy * dy <= 1.0:
			_partir(i, tipo, Vector2(dx, dy))
			n += 1
	return n


## A investida do Hazaki (o raio do Q): parte toda teia a até `largura` px de lado da reta de `origem` por `alcance` px na direção `dir`.
func cortar_faixa(origem: Vector2, dir: Vector2, alcance: float, largura: float, tipo: String) -> int:
	if tipo == "":
		return 0
	var n := 0
	for i in _est.size():
		if not _no_chao(i):
			continue
		var rel := _pos[i] - origem
		var along := rel.dot(dir)
		if along < -raio or along > alcance + raio:
			continue
		if absf(rel.dot(dir.orthogonal())) <= largura + raio * 0.6:
			_partir(i, tipo, dir)
			n += 1
	return n


func _partir(i: int, tipo: String, dir: Vector2) -> void:
	if tipo == "quebra":
		_est[i] = QUEBRADA
	else:
		_est[i] = CORTADA
		_var[i] = 1 if dir.x * dir.y > 0.0 else 0
	_t[i] = 0.0
	cortadas += 1
	if combate != null and combate.audio != null:
		combate.audio.tocar("corte2", 1.5, -8.0, 0.1)


func _toca_arco(i: int, origem: Vector2, dir: Vector2, alc: float, arco: float, cos_meio: float) -> bool:
	var c := _pos[i]
	for k in 17:
		var p := c
		if k > 0:
			var a := float((k - 1) % 8) * TAU / 8.0
			var f := 0.95 if k <= 8 else 0.5
			p = c + Vector2(cos(a) * raio * f, sin(a) * raio * achata * f)
		var rel := p - origem
		var dist := rel.length()
		if dist > alc:
			continue
		if arco >= 359.0 or dist < 1.0 or rel.dot(dir) >= cos_meio * dist:
			return true
	return false


# ------------------------------------------------------------------ desenho


func _quadro(nome: String, linha: int, col: int, centro: Vector2) -> void:
	var f: Dictionary = _folhas.get(nome, {})
	if f.is_empty():
		return
	var q: Vector2 = f.quadro
	col = clampi(col, 0, int(f.quadros) - 1)
	linha = clampi(linha, 0, int(f.linhas) - 1)
	no.draw_texture_rect_region(f.tex, Rect2((centro - f.pivo).round(), q), Rect2(Vector2(float(col) * q.x, float(linha) * q.y), q))


func _col(nome: String, t: float) -> int:
	var f: Dictionary = _folhas.get(nome, {})
	return mini(int(t * float(f.fps)), int(f.quadros) - 1) if not f.is_empty() else 0


func _desenhar() -> void:
	for i in _est.size():
		var e := _est[i]
		if e == LIVRE:
			continue
		var c := _pos[i]
		match e:
			VOANDO:
				_desenhar_voo(i)
			ABRINDO:
				var col := _col("abre", _t[i])
				if not Anim.suave:
					col = (col / 2) * 2
				_quadro("abre", _geo[i], col, c)
			PARADA:
				_quadro("abre", _geo[i], 99, c)
			SUMINDO:
				var f: Dictionary = _folhas.get("some", {})
				if not f.is_empty():
					_quadro("some", _geo[i], mini(int(_t[i] / sumir_s * float(f.quadros)), int(f.quadros) - 1), c)
			QUEIMANDO:
				_quadro("queima", _geo[i] * 4 + _var[i], _col("queima", _t[i]), c)
			CORTADA:
				_quadro("corte", _geo[i] * 2 + _var[i], _col("corte", _t[i]), c)
			QUEBRADA:
				_quadro("quebra", _geo[i], _col("quebra", _t[i]), c)


## A bolota no ar: sombra no chão, o fio de 1 px preso à boca nos primeiros `fio_s`, um rastro curto atrás e, nos últimos `abre_ar_s`, a rede abrindo.
func _desenhar_voo(i: int) -> void:
	var voo_s := maxf(float(aranha.get("voo_s", 0.65)), 0.05)
	var u := clampf(_t[i] / voo_s, 0.0, 1.0)
	var chao: Vector2 = _ini[i].lerp(_pos[i], u)
	var z: float = _alt0[i] * (1.0 - u) + float(aranha.get("arco_px", 28)) * 4.0 * u * (1.0 - u)
	var bola := (chao + Vector2(0.0, -z)).round()
	var rc := chao.round()
	no.draw_line(rc + Vector2(-2, 0), rc + Vector2(2, 0), SOMBRA, 1.0)
	if _t[i] < float(aranha.get("fio_s", 0.15)):
		no.draw_line(_boca[i].round(), bola, FIO, 1.0)
	var rumo: Vector2 = (_pos[i] - _ini[i]).normalized()
	for k in 3:
		var a := bola - rumo * float(5 + k * 4) + Vector2(0.0, float(k - 1) * 2.0)
		no.draw_line(a.round(), (a - rumo * 3.0).round(), FIO, 1.0)
	var ar := float(aranha.get("abre_ar_s", 0.2))
	if _t[i] >= voo_s - ar:
		_quadro("abre_ar", 0, _col("abre_ar", _t[i] - (voo_s - ar)), bola)
	else:
		_quadro("bolota", 0, int(_t[i] * float(_folhas.get("bolota", {}).get("fps", 16.0))) % 4, bola)
