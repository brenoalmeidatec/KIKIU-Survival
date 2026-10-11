extends Node2D
## Corpo do dragão do Hazaki (#20): uma CORRENTE de peças pré-renderizadas no Blender (fonte_arte/modelos3d/dragao.py)
## que segue o rastro da cabeça, serpenteia de lado e ondula no ar, com sombra no chão.
## Fica como filho do jogador; o rastro é guardado em coordenadas do mundo e desenhado relativo a ele.
## Cada folha tem 16 colunas (direções: 0 = direita, 4 = baixo, 8 = esquerda, 12 = cima).

const PASTA := "res://assets/personagens/hazaki/dragao/"
const DIRS := 16
## carregadas junto com o script (no começo da partida), pra transformação não dar engasgo no meio da horda
const TEX := {
	"cabeca": preload(PASTA + "cabeca.png"),
	"corpo": preload(PASTA + "corpo.png"),
	"corpo_sem": preload(PASTA + "corpo_sem.png"),
	"pernas_frente": preload(PASTA + "pernas_frente.png"),
	"pernas_frente_sem": preload(PASTA + "pernas_frente_sem.png"),
	"pernas_tras": preload(PASTA + "pernas_tras.png"),
	"pernas_tras_sem": preload(PASTA + "pernas_tras_sem.png"),
	"cauda": preload(PASTA + "cauda.png"),
	"cauda_sem": preload(PASTA + "cauda_sem.png"),
}
## [folha, linha da folha] do pescoço à cauda (corpo.png: linhas 0..3 = gomo afinando)
const CORRENTE := [
	["pernas_frente", 0],
	["corpo", 0],
	["corpo", 0],
	["corpo", 1],
	["pernas_tras", 0],
	["corpo", 1],
	["corpo", 2],
	["corpo", 2],
	["corpo", 3],
	["corpo", 3],
	["cauda", 0]
]
const LADO := {"cabeca": 64, "corpo": 48, "pernas_frente": 48, "pernas_tras": 48, "cauda": 48}
const ESPACO := 10.0  # distância entre peças de tamanho 1 ao longo do rastro (encolhe junto com o gomo)
const TAM := [1.4, 1.0, 1.0, 1.0, 0.85, 0.85, 0.85, 0.7, 0.7, 0.55, 0.55, 0.5]  # tamanho de cada peça (cabeça + corrente)
const ALTURA := 20.0  # quanto voa acima do chão
const SOMBRA_TAM := [11.0, 11.0, 11.0, 10.0, 10.0, 10.0, 9.0, 8.0, 8.0, 7.0, 6.0, 5.0]  # raio da sombra (cabeça + corrente)

var boca_aberta := false
var surgir := 1.0  # 0..1: quanto da corrente já apareceu (animação da transformação)
var brilho := 0.0  # 0..1: clarão de energia por cima (transformação, rugido)
var olhar := Vector2.ZERO  # pra onde a CABEÇA olha (a baforada mira); ZERO = pra onde está indo
var _rastro: Array = []  # posições da cabeça no mundo (a mais nova primeiro)
var _dir := Vector2.RIGHT
var _t := 0.0
var _dist: Array = []  # distância de cada peça até a cabeça, ao longo do rastro


func _ready() -> void:
	_dist = [0.0]
	for i in range(1, TAM.size()):
		_dist.append(_dist[-1] + ESPACO * (TAM[i - 1] + TAM[i]) / 2.0)


## Começa enrolado no ponto (o corpo sai "de dentro" do Hazaki na transformação).
func iniciar(pos: Vector2, direcao := Vector2.RIGHT) -> void:
	_dir = direcao if direcao != Vector2.ZERO else Vector2.RIGHT
	_rastro = [pos, pos - _dir * ESPACO * (CORRENTE.size() + 2)]


## pos = posição da cabeça no chão (a do jogador); direcao = pra onde está indo (ou olhando).
func atualizar(pos: Vector2, direcao: Vector2, dt: float) -> void:
	_t += dt
	if direcao.length() > 0.1:
		_dir = _dir.slerp(direcao.normalized(), minf(1.0, dt * 10.0))
	if _rastro.is_empty():
		iniciar(pos, _dir)
	if pos.distance_to(_rastro[0]) > 1.0:
		_rastro.push_front(pos)
	else:
		_rastro[0] = pos
	# guarda só o rastro que a corrente usa
	var total := 0.0
	var limite: float = _dist[-1] + ESPACO * 3.0
	for i in range(1, _rastro.size()):
		total += _rastro[i].distance_to(_rastro[i - 1])
		if total > limite:
			_rastro.resize(i + 1)
			break
	queue_redraw()


## Ponto e direção do rastro a uma distância 'd' da cabeça (andando pelo caminho, não em linha reta).
func _no_rastro(d: float) -> Array:
	var resto := d
	for i in range(1, _rastro.size()):
		var a: Vector2 = _rastro[i - 1]
		var b: Vector2 = _rastro[i]
		var seg := a.distance_to(b)
		if seg >= resto and seg > 0.001:
			return [a.lerp(b, resto / seg), (a - b) / seg]
		resto -= seg
	var ult: Vector2 = _rastro[-1]
	var dir_fim: Vector2 = (_rastro[-2] - ult).normalized() if _rastro.size() > 1 and _rastro[-2] != ult else _dir
	return [ult - dir_fim * resto, dir_fim]


func _indice(v: Vector2) -> int:
	return posmod(roundi(v.angle() / TAU * DIRS), DIRS)


## Pontos (no mundo) de cada peça: cabeça primeiro. Usado no desenho e pelas habilidades (garras, investida).
func pecas() -> Array:
	var res := []
	if _rastro.is_empty():
		return res
	var n := CORRENTE.size() + 1
	var visiveis := ceili(n * surgir)
	for i in visiveis:
		var r := _no_rastro(_dist[i] * lerpf(0.35, 1.0, surgir))
		var p: Vector2 = r[0]
		var d: Vector2 = r[1] if i > 0 else _cabeca()
		# serpenteia de lado (mais na cauda) e ondula no ar
		var lado := d.orthogonal() * sin(_t * 4.0 - i * 0.8) * (1.0 + i * 0.35)
		var alt := ALTURA + 3.0 * sin(_t * 5.0 - i * 0.7)
		res.append({"chao": p + lado, "dir": d, "alt": alt, "i": i})
	return res


func boca() -> Vector2:
	var p := pecas()
	if p.is_empty():
		return global_position
	return p[0].chao + _cabeca() * 18.0 - Vector2(0, p[0].alt)


func _draw() -> void:
	var lista := pecas()
	var origem := global_position
	# sombras no chão primeiro (todas embaixo de tudo)
	for pc in lista:
		draw_set_transform(pc.chao - origem, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, SOMBRA_TAM[mini(pc.i, SOMBRA_TAM.size() - 1)], Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# peças de trás pra frente na tela (quem está mais embaixo cobre quem está em cima)
	lista.sort_custom(func(a, b): return a.chao.y < b.chao.y or (is_equal_approx(a.chao.y, b.chao.y) and a.i > b.i))
	var cor := Color(1.0 + brilho * 0.6, 1.0 + brilho * 1.0, 1.0 + brilho * 1.4)  # acima de 1 clareia: clarão cobalto
	# duas passadas: 1) tudo COM contorno (vira a silhueta de fora); 2) o corpo SEM contorno por cima, que apaga
	# a costura entre os gomos e o corpo vira um tubo só. A cabeça vai com contorno nas duas, pra se destacar.
	for passada in 2:
		for pc in lista:
			var i: int = pc.i
			var folha := "cabeca"
			var linha := 1 if boca_aberta else 0
			if i > 0:
				folha = CORRENTE[i - 1][0]
				linha = CORRENTE[i - 1][1]
				if folha.begins_with("pernas"):
					linha = int(_t * 8.0 + i) % 4
			var lado: float = LADO[folha]
			var src := Rect2(_indice(pc.dir) * lado, linha * lado, lado, lado)
			var p: Vector2 = (pc.chao - origem - Vector2(0, pc.alt) - Vector2(lado, lado) / 2.0).floor()
			var tex: Texture2D = TEX[folha + "_sem"] if passada == 1 and i > 0 else TEX[folha]
			draw_texture_rect_region(tex, Rect2(p, Vector2(lado, lado)), src, cor)


func _cabeca() -> Vector2:
	return olhar if olhar != Vector2.ZERO else _dir
