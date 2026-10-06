extends Node
# Teste automático: foto compacta do online (#55, banda). Ida e volta sem perder o que importa.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/rede.tscn  (imprime "REDE falhas=0")
const Online := preload("res://scripts/hordas/online.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func _ready() -> void:
	var c := Vector2(1234.5, -987.25)
	var vir := PackedFloat32Array()
	var ti := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 220:
		vir.append_array([100000 + i, rng.randi_range(0, 30), c.x + rng.randf_range(-420, 420), c.y + rng.randf_range(-420, 420), rng.randf(), rng.randi_range(0, 31)])
	for i in 120:
		ti.append_array([c.x + rng.randf_range(-420, 420), c.y + rng.randf_range(-420, 420), rng.randf_range(-400, 400), rng.randf_range(-400, 400), rng.randi_range(0, 9)])
	var b := Online.compactar(c, vir, ti)
	var antes := (vir.size() + ti.size()) * 4
	ok(b.size() == 12 + 220 * 11 + 120 * 9, "tamanho da foto compacta (%d)" % b.size())
	ok(b.size() * 2 < antes, "foto compacta é menos da metade (%d contra %d bytes)" % [b.size(), antes])
	var f := Online.descompactar(b)
	ok(f.size() == 2 and f[0].size() == vir.size() and f[1].size() == ti.size(), "volta com o mesmo tamanho")
	var pior_pos := 0.0
	var pior_hp := 0.0
	var ids_ok := true
	for i in 220:
		var k := i * 6
		ids_ok = ids_ok and f[0][k] == vir[k] and f[0][k + 1] == vir[k + 1] and f[0][k + 5] == vir[k + 5]
		pior_pos = maxf(pior_pos, maxf(absf(f[0][k + 2] - vir[k + 2]), absf(f[0][k + 3] - vir[k + 3])))
		pior_hp = maxf(pior_hp, absf(f[0][k + 4] - vir[k + 4]))
	ok(ids_ok, "id, tipo e flags exatos")
	ok(pior_pos <= 0.26, "posição do vírus com erro de no máximo 1/4 px (%.3f)" % pior_pos)
	ok(pior_hp <= 1.0 / 255.0, "vida com erro de no máximo 1/255 (%.4f)" % pior_hp)
	var pior_tiro := 0.0
	for i in 120:
		var k := i * 5
		pior_tiro = maxf(pior_tiro, maxf(absf(f[1][k] - ti[k]), absf(f[1][k + 2] - ti[k + 2])))
		ok(f[1][k + 4] == ti[k + 4], "sprite do tiro %d" % i)
	ok(pior_tiro <= 0.51, "tiro com erro de no máximo meio px e meio px/s (%.3f)" % pior_tiro)
	ok(Online.descompactar(PackedByteArray([1, 2, 3])).is_empty(), "foto torta é ignorada")
	var vazia := Online.compactar(c, PackedFloat32Array(), PackedFloat32Array())
	ok(Online.descompactar(vazia).size() == 2, "foto vazia vai e volta")
	print("REDE falhas=", falhas)
	get_tree().quit()
