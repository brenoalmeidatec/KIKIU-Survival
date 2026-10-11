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
		vir.append_array(
			[100000 + i, rng.randi_range(0, 30), c.x + rng.randf_range(-420, 420), c.y + rng.randf_range(-420, 420), rng.randf(), rng.randi_range(0, 31)]
		)
	for i in 120:
		ti.append_array(
			[c.x + rng.randf_range(-420, 420), c.y + rng.randf_range(-420, 420), rng.randf_range(-400, 400), rng.randf_range(-400, 400), rng.randi_range(0, 9)]
		)
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
	# lista de salas (#13): o tópico é público, então todo anúncio que chega é conferido
	var S := preload("res://scripts/hordas/salas.gd")
	var bom := JSON.stringify(
		{
			"v": S.VERSAO,
			"id": "s123456",
			"nome": "Sala de Breno",
			"anfitriao": "Breno",
			"jogadores": 2,
			"max": 6,
			"porta": 7777,
			"endereco": "abc.gl.at.ply.gg:12345"
		}
	)
	var s: Dictionary = S.validar(bom, "")
	ok(s.get("endereco") == "abc.gl.at.ply.gg:12345" and s.get("jogadores") == 2 and s.get("nome") == "Sala de Breno", "anúncio da internet válido (%s)" % [s])
	ok(S.validar(bom, "192.168.0.7").get("endereco") == "192.168.0.7:7777", "na rede local o endereço é o IP de quem anunciou")
	var ruins := [
		"isso não é json",
		JSON.stringify({"v": S.VERSAO + 1, "id": "s123456", "jogadores": 1, "max": 6, "porta": 7777, "endereco": "a.b:1"}),
		JSON.stringify({"v": S.VERSAO, "id": "s1", "jogadores": 1, "max": 6, "porta": 7777, "endereco": "a.b:1"}),
		JSON.stringify({"v": S.VERSAO, "id": "s123456", "jogadores": 9, "max": 6, "porta": 7777, "endereco": "a.b:1"}),
		JSON.stringify({"v": S.VERSAO, "id": "s123456", "jogadores": 1, "max": 6, "porta": 80, "endereco": "a.b:1"}),
		JSON.stringify({"v": S.VERSAO, "id": "s123456", "jogadores": 1, "max": 6, "porta": 7777, "endereco": "evil.com/x?y:80"}),
		JSON.stringify({"v": S.VERSAO, "id": "s123456", "jogadores": "1", "max": 6, "porta": 7777, "endereco": "a.b:1"}),
		"x".repeat(700),
	]
	for i in ruins.size():
		ok(S.validar(ruins[i], "").is_empty(), "anúncio torto %d é ignorado" % i)
	var nome_feio: Dictionary = S.validar(
		JSON.stringify({"v": S.VERSAO, "id": "s123456", "nome": "\u0007Sala\n" + "z".repeat(50), "jogadores": 1, "max": 6, "porta": 7777, "endereco": "a.b:7"}),
		""
	)
	ok(nome_feio.get("nome", "").length() <= 20 and not "\n" in nome_feio.get("nome", ""), "nome limpo e curto (%s)" % nome_feio.get("nome"))
	ok(S.endereco_valido("1.2.3.4:7777") and not S.endereco_valido("1.2.3.4") and not S.endereco_valido("a b:1"), "formato de endereço")
	# chat (#13): enquanto digita, as teclas saem do mapa de ações (digitar "e" não é confirmar, WASD não anda)
	if not InputMap.has_action("esquerda"):
		InputMap.add_action("esquerda")
	var tecla_a := InputEventKey.new()
	tecla_a.physical_keycode = KEY_A
	InputMap.action_add_event("esquerda", tecla_a)
	var antes_n := InputMap.action_get_events("esquerda").size()
	Chat.digitando = false
	Chat._suspender_teclas()
	ok(InputMap.action_get_events("esquerda").filter(func(e): return e is InputEventKey).is_empty(), "digitando: A não é mais 'esquerda'")
	Chat._devolver_teclas()
	ok(InputMap.action_get_events("esquerda").size() == antes_n, "fechou: as teclas voltam iguais")
	ok(
		Chat.limpar_texto("oi\nlinha\u0007 ok" + "x".repeat(200)).length() == Chat.MAX_TXT and not "\n" in Chat.limpar_texto("a\nb"),
		"texto do chat limpo e cortado"
	)
	# voz (#13): mu-law em 8 bits, ida e volta (erro relativo pequeno, mais detalhe nos sons baixos)
	var V := preload("res://scripts/hordas/voz.gd")
	var pior_rel := 0.0
	for x in [-1.0, -0.5, -0.1, -0.01, 0.0, 0.003, 0.02, 0.2, 0.7, 1.0]:
		var y: float = V.expandir(V.comprimir(x))
		ok(signf(y) == signf(x) or absf(x) < 0.001, "voz: sinal mantido em %.3f" % x)
		if absf(x) >= 0.01:
			pior_rel = maxf(pior_rel, absf(y - x) / absf(x))
	ok(pior_rel < 0.05, "voz: erro relativo < 5%% (%.3f)" % pior_rel)
	ok(V.comprimir(2.0) == V.comprimir(1.0) and V.comprimir(-2.0) <= 255, "voz: saturação sem estourar o byte")
	print("REDE falhas=", falhas)
	get_tree().quit()
