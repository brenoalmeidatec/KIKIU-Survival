extends RefCounted
## Explosão dos micro-mísseis: oito quadros preparados uma vez, pool fixo e nenhum nó por impacto.
## Só desenha; o dano continua em adagas._explodir. Não usa o RNG do combate.

const MAX := 16
const QUADROS := 8
const DUR := 0.36
const TAM := 40
const Piscadas := preload("res://v2/piscadas.gd")
var pos := PackedVector2Array()
var tempo := PackedFloat32Array()
var escala := PackedFloat32Array()
var calmo_tempo := PackedFloat32Array()  # evita reacender a mesma região mais de uma vez por segundo
var quadros: Array[Texture2D] = []
var emitidas := 0
var _proxima := 0


func montar() -> void:
	pos.resize(MAX)
	tempo.resize(MAX)
	escala.resize(MAX)
	calmo_tempo.resize(MAX)
	for q in QUADROS:
		quadros.append(_quadro(q))
	limpar()


func limpar() -> void:
	tempo.fill(0.0)
	calmo_tempo.fill(0.0)
	_proxima = 0
	emitidas = 0


func emitir(p: Vector2, raio: float) -> void:
	var origem := p + Vector2(0, -6)
	if Piscadas.ligado():
		for i in MAX:
			if calmo_tempo[i] > 0.0 and pos[i].distance_squared_to(origem) <= 48.0 * 48.0:
				return  # não reinicia o fade da mancha anterior nem soma outro clarão no mesmo alvo
		var livre := -1
		for k in MAX:
			var i := (_proxima + k) % MAX
			if calmo_tempo[i] <= 0.0:
				livre = i
				break
		if livre < 0:
			return  # saturado: descarta só o visual; não apaga a proteção temporal de outra região
		_proxima = livre
		calmo_tempo[_proxima] = 1.0
	else:
		calmo_tempo[_proxima] = 0.0
	pos[_proxima] = origem
	tempo[_proxima] = DUR
	escala[_proxima] = clampf(raio / 30.0, 0.7, 1.15)
	_proxima = (_proxima + 1) % MAX
	emitidas += 1


func atualizar(dt: float) -> void:
	for i in MAX:
		tempo[i] = maxf(0.0, tempo[i] - dt)
		calmo_tempo[i] = maxf(0.0, calmo_tempo[i] - dt)


func ativas() -> int:
	var n := 0
	for t in tempo:
		if t > 0.0:
			n += 1
	return n


func desenhar(no: Node2D, baixo: bool) -> void:
	var calmo := Piscadas.ligado()
	for i in MAX:
		if tempo[i] <= 0.0:
			continue
		var q := quadro_em(tempo[i], baixo, calmo)
		var lado := float(TAM) * escala[i] * (0.85 if baixo else 1.0)
		var cor := Color(1, 1, 1, tempo[i] / DUR) if calmo else Color.WHITE
		no.draw_texture_rect(quadros[q], Rect2((pos[i] - Vector2.ONE * lado * 0.5).round(), Vector2.ONE * lado), false, cor)


func quadro_em(restante: float, baixo: bool, calmo: bool) -> int:
	if calmo:
		return 6  # fumaça escura fixa com fade: sem núcleo branco ou alternância de luminância
	var q := clampi(int((1.0 - restante / DUR) * QUADROS), 0, QUADROS - 1)
	return mini((q / 2) * 2, QUADROS - 1) if baixo else q


func _quadro(q: int) -> Texture2D:
	var im := Image.create(TAM, TAM, false, Image.FORMAT_RGBA8)
	var fase := float(q) / float(QUADROS - 1)
	var raio := 4.0 + 12.0 * sqrt(fase)
	for y in TAM:
		for x in TAM:
			var p := Vector2(float(x) - 19.5, float(y) - 19.5)
			# Contorno de cinco lóbulos: forma de explosão, em vez de outra bala/halo.
			var borda := raio * (0.87 + 0.13 * cos(p.angle() * 5.0 + float(q) * 0.17))
			var dist := p.length()
			if dist > borda:
				continue
			var r := dist / maxf(borda, 1.0)
			var cor := Color(0.23, 0.18, 0.22, 1.0 - fase * 0.65)
			if q < 5:
				if r < 0.4 * (1.0 - fase):
					cor = Color(1.0, 0.96, 0.72)
				elif r < 0.72:
					cor = Color(1.0, 0.7 - fase * 0.35, 0.12)
				elif r < 0.9:
					cor = Color(0.8, 0.22, 0.08)
			elif r < 0.62:
				cor = Color(0.65, 0.29, 0.12, 1.0 - fase * 0.75)
			im.set_pixel(x, y, cor)
	return ImageTexture.create_from_image(im)
