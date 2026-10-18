extends Node

const Combate := preload("res://v2/combate.gd")
const CEL := 26.0
const PASSO_SEP := 3
const GRADE_N := 1024
const REP := 100
const AMOSTRAS := 20

var base_cab := PackedInt32Array()
var base_prox := PackedInt32Array()
var base_pos := PackedVector2Array()
var base_rad := PackedFloat32Array()
var base_grandes: Array[int] = []


func _ready() -> void:
	for n in [100, 500]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 82142 + n
		var atores: Array = []
		for i in n:
			atores.append(
				{
					"pos": Vector2(rng.randf_range(-300.0, 300.0), rng.randf_range(-300.0, 300.0)),
					"raio": 7.0,
					"atordoa_t": 0.0,
					"sep": Vector2.ZERO,
				}
			)
		var combate = Combate.new()
		combate.mundo = {"monstros": atores}
		_base_preparar(n)
		for i in 5:
			combate._q = i
			combate._separar()
			_base_separar(atores, i)
		var novo_us: Array[int] = []
		var base_us: Array[int] = []
		for s in AMOSTRAS:
			var inicio := Time.get_ticks_usec()
			if s % 2 == 0:
				for i in REP:
					combate._q = i + s
					combate._separar()
				novo_us.append(Time.get_ticks_usec() - inicio)
				inicio = Time.get_ticks_usec()
				for i in REP:
					_base_separar(atores, i + s)
				base_us.append(Time.get_ticks_usec() - inicio)
			else:
				for i in REP:
					_base_separar(atores, i + s)
				base_us.append(Time.get_ticks_usec() - inicio)
				inicio = Time.get_ticks_usec()
				for i in REP:
					combate._q = i + s
					combate._separar()
				novo_us.append(Time.get_ticks_usec() - inicio)
		novo_us.sort()
		base_us.sort()
		var med_novo: float = (novo_us[AMOSTRAS / 2 - 1] + novo_us[AMOSTRAS / 2]) * 0.5
		var med_base: float = (base_us[AMOSTRAS / 2 - 1] + base_us[AMOSTRAS / 2]) * 0.5
		print("grade_bench n=%d mediana_us_%dchamadas base=%.1f novo=%.1f delta_pct=%.1f" % [n, REP, med_base, med_novo, (med_novo / med_base - 1.0) * 100.0])
		get_tree().quit()


func _base_preparar(n: int) -> void:
	base_cab.resize(GRADE_N)
	base_pos.resize(n)
	base_rad.resize(n)
	base_prox.resize(n)


func _base_separar(ms: Array, q: int) -> void:
	var n := ms.size()
	base_cab.fill(-1)
	base_grandes.clear()
	for i in n:
		var m = ms[i]
		var p: Vector2 = m.pos
		var r: float = m.raio
		base_pos[i] = p
		base_rad[i] = r
		if r > 11.0:
			base_grandes.append(i)
			continue
		var h := ((int(p.x / CEL) * 73856093) ^ (int(p.y / CEL) * 19349663)) & (GRADE_N - 1)
		base_prox[i] = base_cab[h]
		base_cab[h] = i
	var i0 := q % PASSO_SEP
	while i0 < n:
		var k := i0
		i0 += PASSO_SEP
		if ms[k].atordoa_t > 0.0:
			ms[k].sep = Vector2.ZERO
			continue
		var p: Vector2 = base_pos[k]
		var r: float = base_rad[k]
		var empurra := Vector2.ZERO
		var cx := int(p.x / CEL)
		var cy := int(p.y / CEL)
		var alcance := 1 if r <= 11.0 else 3
		for dx in range(-alcance, alcance + 1):
			for dy in range(-alcance, alcance + 1):
				var j: int = base_cab[(((cx + dx) * 73856093) ^ ((cy + dy) * 19349663)) & (GRADE_N - 1)]
				while j >= 0:
					if j != k:
						var d: Vector2 = p - base_pos[j]
						var lim: float = (r + base_rad[j]) * 1.15
						var d2 := d.length_squared()
						if d2 < lim * lim:
							if d2 < 0.01:
								d = Vector2(0.3, 0.4)
								d2 = d.length_squared()
							var dist := sqrt(d2)
							empurra += d / dist * (lim - dist)
					j = base_prox[j]
		for j in base_grandes:
			if j == k:
				continue
			var d: Vector2 = p - base_pos[j]
			var lim: float = (r + base_rad[j]) * 1.15
			var d2 := d.length_squared()
			if d2 < lim * lim:
				if d2 < 0.01:
					d = Vector2(0.3, 0.4)
					d2 = d.length_squared()
				var dist := sqrt(d2)
				empurra += d / dist * (lim - dist)
		ms[k].sep = (empurra * 14.0).limit_length(46.0)
