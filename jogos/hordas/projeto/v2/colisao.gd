extends RefCounted
## Colisão do mundo da v2 (2.5D): formas fixas (árvores, pedras, torii, muros) numa grade estática de células de 64 px.
## Cada forma é uma elipse no chão, em px do jogo e relativa ao pé do objeto: é o campo "colisao" de
## prototipos/objetos/cenario.json, {"tipo": "elipse", "centro": [dx, dy], "raio": [rx, ry]}, com ry = 0,5 * rx
## (a base vista a 45 graus). Lista vazia = objeto atravessável.
## Um corpo é um círculo de raio r. Contra uma elipse, o espaço é escalado em y por rx/ry: a elipse vira um
## círculo de raio rx, o corpo continua círculo, e a conta é círculo contra círculo. A correção volta ao espaço
## normal (y * ry/rx). O empurrão sai só no sentido normal, então o corpo desliza ao longo de uma forma lisa e não
## prende nela. Sobra uma folga de FOLGA px, para o corpo não ficar tangente à forma (erro de ponto flutuante
## contaria como dentro). Limite conhecido: entre duas formas encostadas há uma quina côncava, e um resolver que
## recebe só a posição pode parar lá (os empurrões se cancelam). Por isso o muro e o tronco são uma elipse larga,
## e as formas de cenário devem ficar separadas.
## A grade é plana e fixa: GRADE_W x GRADE_H células de 64 px, começando em -OFFSET_CELULAS células. Forma fora
## dela fica na célula da borda (a consulta também prende na borda, então o resultado não muda).
## Uso: adicionar_objeto(pe, formas) para cada objeto fixo; por quadro e corpo, resolver(pos, raio).
## limpar() zera tudo ao trocar de fase. Sem class_name: carregue com preload, como o resto do projeto.

const TAM_CELULA := 64.0
const GRADE_W := 32
const GRADE_H := 24
const OFFSET_CELULAS := 4
const PASSADAS := 4
const FOLGA := 0.01

static var _cen := PackedVector2Array()  # centro de cada forma, no mundo
static var _rx := PackedFloat32Array()  # raio em x
static var _k := PackedFloat32Array()  # rx / ry: o fator que escala o y
static var _grade: Array = []  # GRADE_W * GRADE_H células, cada uma um PackedInt32Array de índices de forma
static var _rx_max := 0.0


static func limpar() -> void:
	_cen = PackedVector2Array()
	_rx = PackedFloat32Array()
	_k = PackedFloat32Array()
	_grade = []
	for _i in GRADE_W * GRADE_H:
		_grade.append(PackedInt32Array())
	_rx_max = 0.0


## Registra um objeto fixo. pos_pe é o pé dele no mundo; formas é a lista "colisao" do cenário.
static func adicionar_objeto(pos_pe: Vector2, formas: Array) -> void:
	if _grade.is_empty():
		limpar()
	for f in formas:
		if not (f is Dictionary) or f.get("tipo", "") != "elipse":
			continue
		var c: Array = f["centro"]
		var r: Array = f["raio"]
		var centro := pos_pe + Vector2(float(c[0]), float(c[1]))
		var rx := float(r[0])
		var ry := maxf(float(r[1]), 0.01)
		var i := _cen.size()
		_cen.append(centro)
		_rx.append(rx)
		_k.append(rx / ry)
		_rx_max = maxf(_rx_max, rx)
		var ax := _coluna(centro.x - rx)
		var bx := _coluna(centro.x + rx)
		var ay := _linha(centro.y - ry)
		var by := _linha(centro.y + ry)
		for gx in range(ax, bx + 1):
			for gy in range(ay, by + 1):
				var lista: PackedInt32Array = _grade[gx * GRADE_H + gy]
				lista.append(i)
				_grade[gx * GRADE_H + gy] = lista


## Empurra o círculo (pos, raio) para fora de todas as formas que ele toca. Devolve a posição corrigida.
## A grade é consultada a cada passada, no ponto atual: a caixa cobre qualquer forma que possa tocar o círculo.
static func resolver(pos: Vector2, raio: float) -> Vector2:
	var p := pos
	if _grade.is_empty():
		return p
	var cen := _cen
	var rxs := _rx
	var ks := _k
	var grade := _grade
	var folga := raio + _rx_max
	for _passada in PASSADAS:
		var tocou := false
		var ax := _coluna(p.x - folga)
		var bx := _coluna(p.x + folga)
		var ay := _linha(p.y - folga)
		var by := _linha(p.y + folga)
		for gx in range(ax, bx + 1):
			for gy in range(ay, by + 1):
				for i in grade[gx * GRADE_H + gy]:
					var q := p - cen[i]
					# caixa rápida: |qs| >= |q.x| e |qs| >= |q.y| * k, então longe em x ou em y não toca
					if absf(q.x) >= rxs[i] + raio or absf(q.y) >= (rxs[i] + raio) / ks[i]:
						continue
					var qs := Vector2(q.x, q.y * ks[i])  # espaço escalado: a forma virou círculo de raio rx
					var d := qs.length()
					var falta := rxs[i] + raio + FOLGA - d
					if falta <= 0.0:
						continue
					tocou = true
					var n: Vector2 = qs / d if d > 0.0001 else Vector2.UP
					var empurrao: Vector2 = n * falta
					p += Vector2(empurrao.x, empurrao.y / ks[i])  # de volta ao espaço normal
		if not tocou:
			break
	return p


## True se o círculo (pos, raio) não toca nenhuma forma.
static func livre(pos: Vector2, raio: float) -> bool:
	if _grade.is_empty():
		return true
	var cen := _cen
	var rxs := _rx
	var ks := _k
	var grade := _grade
	var folga := raio + _rx_max
	for gx in range(_coluna(pos.x - folga), _coluna(pos.x + folga) + 1):
		for gy in range(_linha(pos.y - folga), _linha(pos.y + folga) + 1):
			for i in grade[gx * GRADE_H + gy]:
				var q := pos - cen[i]
				if absf(q.x) >= rxs[i] + raio or absf(q.y) >= (rxs[i] + raio) / ks[i]:
					continue
				if Vector2(q.x, q.y * ks[i]).length() < rxs[i] + raio:
					return false
	return true


static func _coluna(x: float) -> int:
	return clampi(floori(x / TAM_CELULA) + OFFSET_CELULAS, 0, GRADE_W - 1)


static func _linha(y: float) -> int:
	return clampi(floori(y / TAM_CELULA) + OFFSET_CELULAS, 0, GRADE_H - 1)
