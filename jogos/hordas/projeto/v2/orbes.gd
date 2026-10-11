extends RefCounted
## Fragmentos de alma (orbes de XP) da v2. Pool de vetores (nada de nó por orbe) e UMA chamada de desenho aditiva por quadro, na camada
## glow. O monstro que morre solta o orbe com um pulinho; quando o herói chega perto (raio do ímã) ele voa para o herói, cada vez mais
## rápido, e ao encostar vira XP (combate.coletar). Cheio o pool, o XP novo se soma ao orbe parado mais próximo (nada se perde).

const MAX := 240
const ENCOSTA := 7.0  # px do centro do herói em que o orbe é pego

var combate
var no: Node2D
var tex_brilho: Texture2D
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var z := PackedFloat32Array()  # altura do pulinho
var zv := PackedFloat32Array()
var valor := PackedFloat32Array()
var estado := PackedByteArray()  # 0 = livre, 1 = no chão, 2 = voando para o herói
var voo := PackedFloat32Array()  # velocidade atual do voo (px/s)
var fase := PackedFloat32Array()
var ativos := 0
var pegos := 0  # quantos já foram pegos (testes)
var t := 0.0
var ima_vel := 190.0
var ima_acel := 900.0


func montar(c, camada: Node, tex: Texture2D) -> void:
	combate = c
	tex_brilho = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no = Node2D.new()
	no.material = mat
	no.draw.connect(_desenhar)
	camada.add_child(no)
	pos.resize(MAX)
	vel.resize(MAX)
	z.resize(MAX)
	zv.resize(MAX)
	valor.resize(MAX)
	estado.resize(MAX)
	voo.resize(MAX)
	fase.resize(MAX)


func limpar() -> void:
	estado.fill(0)
	ativos = 0
	no.queue_redraw()


## Solta um orbe em `p` com um pulinho para o lado.
func soltar(p: Vector2, v: float) -> void:
	var i := -1
	for k in MAX:
		if estado[k] == 0:
			i = k
			break
	if i < 0:
		var melhor := 1e12
		for k in MAX:
			if estado[k] == 1:
				var d := pos[k].distance_squared_to(p)
				if d < melhor:
					melhor = d
					i = k
		if i >= 0:
			valor[i] += v
		return
	var a := randf() * TAU
	pos[i] = p
	vel[i] = Vector2(cos(a), sin(a) * 0.6) * randf_range(18.0, 46.0)
	z[i] = 0.0
	zv[i] = randf_range(60.0, 95.0)
	valor[i] = v
	estado[i] = 1
	voo[i] = 0.0
	fase[i] = randf() * TAU
	ativos += 1


## Atrai todos os orbes a até `raio` px de `alvo` (subida de nível: as almas vêm todas).
func atrair_todos(alvo: Vector2, raio: float) -> void:
	for i in MAX:
		if estado[i] == 1 and pos[i].distance_to(alvo) <= raio:
			estado[i] = 2
			voo[i] = ima_vel


func atualizar(dt: float, alvo: Vector2, raio_ima: float) -> void:
	if ativos <= 0:
		return
	t += dt
	var r2 := raio_ima * raio_ima
	for i in MAX:
		var e := estado[i]
		if e == 0:
			continue
		if e == 1:
			if z[i] > 0.0 or zv[i] > 0.0:  # pulinho
				zv[i] -= 330.0 * dt
				z[i] = maxf(0.0, z[i] + zv[i] * dt)
				pos[i] += vel[i] * dt
				vel[i] *= exp(-2.0 * dt)
				if z[i] <= 0.0 and zv[i] < 0.0:
					zv[i] = 0.0
			if pos[i].distance_squared_to(alvo) <= r2:
				estado[i] = 2
				voo[i] = ima_vel
		else:
			voo[i] += ima_acel * dt
			var d := alvo - pos[i]
			var dist := d.length()
			var passo := voo[i] * dt
			z[i] = maxf(0.0, z[i] - 60.0 * dt)
			if dist <= ENCOSTA or passo >= dist:
				estado[i] = 0
				ativos -= 1
				pegos += 1
				combate.coletar(valor[i], pos[i])
			else:
				pos[i] += d / dist * passo
	no.queue_redraw()


func _desenhar() -> void:
	if ativos <= 0:
		return
	for i in MAX:
		var e := estado[i]
		if e == 0:
			continue
		var bob := sin(t * 4.0 + fase[i]) * 1.5 if e == 1 else 0.0
		var p := pos[i] + Vector2(0, -5.0 - z[i] + bob)
		p = p.round()
		var forte := 1.0 if e == 2 else 0.8
		no.draw_texture_rect(tex_brilho, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false, Color(0.35, 0.85, 1.0, 0.55 * forte))
		no.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(0.85, 1.0, 1.0, 1.0))
		no.draw_rect(Rect2(p - Vector2(0, 2), Vector2(1, 5)), Color(0.6, 0.95, 1.0, 0.8))
		no.draw_rect(Rect2(p - Vector2(2, 0), Vector2(5, 1)), Color(0.6, 0.95, 1.0, 0.8))
