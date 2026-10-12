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
## recebe só a posição pode parar lá (os empurrões se cancelam). Por isso o muro é uma elipse larga, e as formas de
## cenário devem ficar separadas.
## Árvores, tocos e tronco caído têm PEGADA: um ou mais círculos (elipses 2:1) que cobrem a base visual inteira, raízes
## incluídas (gerar_objetos.py, _pegada_de_base). Quem garante que o corpo não entra na base é essa cobertura; o teste
## testes/v2_arvores.tscn mede isso nas 8 direções.
## A grade é plana e fixa: GRADE_W x GRADE_H células de 64 px, começando em -OFFSET_CELULAS células. Forma fora
## dela fica na célula da borda (a consulta também prende na borda, então o resultado não muda).
## Uso: adicionar_objeto(pe, formas) para cada objeto fixo; por quadro e corpo, resolver(pos, raio).
## limpar() zera tudo ao trocar de fase. Sem class_name: carregue com preload, como o resto do projeto.

const TAM_CELULA := 64.0
const GRADE_W := 64  # 64 x 40 células de 64 px cobrem o mapa da v2 (2880 x 1620) e sobra: antes era 32 x 24 e o leste e o sul caíam na célula da borda
const GRADE_H := 40
const OFFSET_CELULAS := 4
const PASSADAS := 4
const FOLGA := 0.01
const RAIO_BUSCA := 32.0  # corpo de até este raio usa a tabela de células "perto de alguma forma" (a maioria do mapa aberto passa sem conta)

static var _cen := PackedVector2Array()  # centro de cada forma, no mundo
static var _rx := PackedFloat32Array()  # raio em x
static var _k := PackedFloat32Array()  # rx / ry: o fator que escala o y
static var _grade: Array = []  # GRADE_W * GRADE_H células, cada uma um PackedInt32Array de índices de forma
static var _rx_max := 0.0
static var _perto := PackedByteArray()  # por célula: 1 se alguma forma está a menos de RAIO_BUSCA dela (refeita quando entra forma nova)
static var _sujo := true


static func limpar() -> void:
	_cen = PackedVector2Array()
	_rx = PackedFloat32Array()
	_k = PackedFloat32Array()
	_grade = []
	for _i in GRADE_W * GRADE_H:
		_grade.append(PackedInt32Array())
	_rx_max = 0.0
	_sujo = true


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
		_sujo = true
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
	if _sujo:
		_refazer_perto()
	if raio <= RAIO_BUSCA and _perto[_coluna(p.x) * GRADE_H + _linha(p.y)] == 0:
		return p  # nenhuma forma por perto: nada a resolver
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


## Marca as células que têm alguma forma a menos de RAIO_BUSCA (o círculo de um corpo de até esse raio só toca forma assim).
static func _refazer_perto() -> void:
	_perto = PackedByteArray()
	_perto.resize(GRADE_W * GRADE_H)
	for i in _cen.size():
		var rx := _rx[i]
		var ry := rx / _k[i]
		var ax := _coluna(_cen[i].x - rx - RAIO_BUSCA)
		var bx := _coluna(_cen[i].x + rx + RAIO_BUSCA)
		var ay := _linha(_cen[i].y - ry - RAIO_BUSCA)
		var by := _linha(_cen[i].y + ry + RAIO_BUSCA)
		for gx in range(ax, bx + 1):
			for gy in range(ay, by + 1):
				_perto[gx * GRADE_H + gy] = 1
	_sujo = false


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


## Depuração (tecla F4): as formas registradas que tocam o retângulo `r` (coordenadas do mundo), como {c, rx, ry}.
static func formas_no_retangulo(r: Rect2) -> Array:
	var saida: Array = []
	for i in _cen.size():
		var rx := _rx[i]
		var ry := rx / _k[i]
		var caixa := Rect2(_cen[i] - Vector2(rx, ry), Vector2(rx, ry) * 2.0)
		if caixa.intersects(r):
			saida.append({"c": _cen[i], "rx": rx, "ry": ry})
	return saida


static func _coluna(x: float) -> int:
	return clampi(floori(x / TAM_CELULA) + OFFSET_CELULAS, 0, GRADE_W - 1)


static func _linha(y: float) -> int:
	return clampi(floori(y / TAM_CELULA) + OFFSET_CELULAS, 0, GRADE_H - 1)
