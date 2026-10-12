extends RefCounted
## Silhueta do herói da v2 (leva 4): quando um MONSTRO na frente do herói (pés mais para baixo na tela) cobre o corpo dele, a
## silhueta do herói aparece por cima de tudo, com contorno claro de 1 px e preenchimento translúcido (35%). Ela fica numa
## CanvasLayer acima do mundo (layer 3: fora do escurecimento e do brilho, abaixo da HUD), então o jogador sempre enxerga o
## herói. Entra e sai com transição (VEL por segundo) e não fica ligada enquanto nada na frente cobre o herói.
## Árvores e objetos altos NÃO usam silhueta: copas.gd abre um buraco circular neles (sem efeito duplo).
## O teste de cobertura roda a cada CADA quadros e só olha os monstros das células da grade em volta do herói. A lista de
## monstros é lida como `pos`, `escala` e `tipo` (w, h, pe), então serve também aos monstros em MultiMesh enquanto o mundo
## expuser essa lista (`mundo.monstros`).
## mundo.gd: `oclusao = Oclusao.new().montar(sv, heroi)` no _montar e `oclusao.atualizar(dt, heroi, monstros)` no avancar.

const SHADER := preload("res://v2/silhueta.gdshader")
const CAMADA := 3  # acima do brilho (2) e do escurecimento, abaixo da HUD (10)
const VEL := 6.0  # alfa por segundo: de 0 a 1 em ~0,17 s
const CELULA := 128.0  # px do mundo por célula da grade
const COBERTURA_MIN := 0.12  # fração da área do corpo do herói que o monstro precisa cobrir (o toque de canto não conta)
const CADA := 3  # quadros entre dois testes de cobertura (com o tempo acumulado)

var _capa: CanvasLayer
var _ancora: Node2D
var _sil: Sprite2D
var _alfa := 0.0  # transição atual (0 a 1)
var _alvo := 0.0  # 1 se há monstro na frente cobrindo o herói, no último teste
var _acum := 0.0
var _n := 0
var _grade := {}  # chave da célula -> Array de monstros (refeita a cada teste)
var _margem := 0.0  # maior extensão de um sprite de monstro (px): quanto a busca na grade precisa cobrir além do herói


## Monta a camada e o sprite da silhueta. Devolve o próprio objeto (uma linha no mundo: `Oclusao.new().montar(sv, heroi)`).
func montar(sv: Node, _heroi) -> RefCounted:
	_capa = CanvasLayer.new()
	_capa.layer = CAMADA
	_capa.follow_viewport_enabled = true  # coordenadas do mundo, como as luzes do brilho (luzes.gd)
	sv.add_child(_capa)
	_ancora = Node2D.new()
	_capa.add_child(_ancora)
	_sil = Sprite2D.new()
	_sil.centered = false
	_sil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = SHADER
	_sil.material = m
	_sil.visible = false
	_ancora.add_child(_sil)
	return self


## Um passo: o teste de cobertura a cada CADA quadros e a transição do alfa a cada quadro (pelo dt). dt = 0 não muda nada.
func atualizar(dt: float, heroi, monstros: Array) -> void:
	if dt <= 0.0 or heroi == null:
		return
	_acum += dt
	_n += 1
	if _n % CADA == 1 or _acum >= 0.1:
		_alvo = 1.0 if _coberto(heroi, monstros) else 0.0
		_acum = 0.0
	_alfa = move_toward(_alfa, _alvo, VEL * dt)
	_sil.visible = _alfa > 0.0
	if _sil.visible:
		_copiar(heroi)


## Alfa atual da silhueta (0 = nada, 1 = inteira). Para os testes.
func alfa() -> float:
	return _alfa


## Verdadeiro se, no último teste, um monstro na frente cobre o herói. Para os testes.
func coberto() -> bool:
	return _alvo > 0.5


## Põe o sprite da silhueta no mesmo quadro, espelho, escala e posição do sprite do herói (ele pode girar no golpe e na queda).
func _copiar(heroi) -> void:
	var s: Sprite2D = heroi.sprite
	_ancora.position = heroi.raiz.position
	_sil.texture = s.texture
	_sil.region_enabled = true
	_sil.region_rect = s.region_rect
	_sil.offset = s.offset
	_sil.flip_h = s.flip_h
	_sil.position = s.position
	_sil.rotation = s.rotation
	_sil.scale = s.scale
	_sil.modulate = Color(1.0, 1.0, 1.0, _alfa)


## Corpo de um ator no mundo (o mesmo retângulo do sprite: o pé no ponto `p`, `e` vezes o tamanho do quadro).
static func _corpo(p: Vector2, t: Dictionary, e: float) -> Rect2:
	var w := float(t.w)
	var h := float(t.h)
	var pe := float(t.pe)
	return Rect2(p + Vector2(-w, -pe) * (e * 0.5), Vector2(w, h) * e)


## Verdadeiro se um monstro com os pés MAIS PARA BAIXO que os do herói cobre pelo menos COBERTURA_MIN do corpo dele.
func _coberto(heroi, monstros: Array) -> bool:
	var corpo := _corpo(heroi.pos, heroi.tipo, 1.0)
	if corpo.get_area() <= 0.0:
		return false
	_montar_grade(monstros)
	var minimo := corpo.get_area() * COBERTURA_MIN
	var busca := Rect2(corpo.position - Vector2.ONE * _margem, corpo.size + Vector2.ONE * _margem * 2.0)
	var cx0 := floori(busca.position.x / CELULA)
	var cx1 := floori(busca.end.x / CELULA)
	var cy0 := floori(busca.position.y / CELULA)
	var cy1 := floori(busca.end.y / CELULA)
	for cx in range(cx0, cx1 + 1):
		for cy in range(cy0, cy1 + 1):
			var lista: Array = _grade.get(_chave(cx, cy), [])
			for mo in lista:
				if mo.pos.y <= heroi.pos.y:  # atrás do herói (ou na mesma linha): quem desenha por cima é o herói
					continue
				var inter := corpo.intersection(_corpo(mo.pos, mo.tipo, float(mo.escala)))
				if inter.get_area() >= minimo:
					return true
	return false


## Refaz a grade de monstros por célula (px do mundo / CELULA) e guarda a maior extensão de sprite para a busca.
func _montar_grade(monstros: Array) -> void:
	_grade.clear()
	_margem = 0.0
	for mo in monstros:
		var t: Dictionary = mo.tipo
		var e := float(mo.escala)
		_margem = maxf(_margem, maxf(maxf(float(t.w) * e, float(t.pe) * e), (float(t.h) - float(t.pe)) * e))
		var k := _chave(floori(mo.pos.x / CELULA), floori(mo.pos.y / CELULA))
		if not _grade.has(k):
			_grade[k] = []
		_grade[k].append(mo)


static func _chave(cx: int, cy: int) -> int:
	return cx * 4096 + cy
