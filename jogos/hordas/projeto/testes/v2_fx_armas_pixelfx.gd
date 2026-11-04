extends "res://testes/isolamento_v2.gd"
# Impactos das armas no estilo do pixelfx (assets/v2/armas_anim/indice_pixelfx.json, guia em docs/visual_2_5d/estilo_pixelfx.md). Prova que (1) as
# cinco armas tocam a folha nova sem perder as outras animações, (2) a tira tem o tamanho de quadro x n, (3) o alfa está nos 6 degraus e o último
# quadro quase acabou, (4) meteoro desenha em escala 1 em todos os níveis (a conta do `armas_novas.gd`). Falha sem "pixelfx" em Anim.GRUPOS.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_fx_armas_pixelfx.tscn  (imprime "v2_fx_armas_pixelfx falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const ARMAS := {"bola_fogo": "voo", "adagas_voadoras": "voo", "raio": "", "cometa_gelado": "queda", "chuva_pedras": "queda"}
const RAIOS_METEORO := {"cometa_gelado": [60.0, 75.0], "chuva_pedras": [30.0, 40.0]}  # do nível 1 ao 5 (dados/v2_cartas.json)
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for id in ARMAS:
		var fa := Anim.de(id)
		ok(fa.has("impacto"), "%s tem impacto" % id)
		if not fa.has("impacto"):
			continue
		var f: Dictionary = fa.impacto
		var tex: Texture2D = f.tex
		ok(tex.resource_path.get_file().begins_with("pfx_"), "%s toca a folha nova (%s)" % [id, tex.resource_path])
		if ARMAS[id] != "":
			ok(fa.has(ARMAS[id]), "%s não perdeu a animação '%s'" % [id, ARMAS[id]])
		var q: Vector2 = f.quadro
		ok(tex.get_width() == int(q.x) * int(f.n) and tex.get_height() == int(q.y), "%s: tira = quadro x n" % id)
		ok(Anim.duracao(f) <= 0.6, "%s: impacto curto (%.2f s)" % [id, Anim.duracao(f)])
		var img := tex.get_image()
		img.decompress()
		var ultimo := 0
		var primeiro := 0
		var fora_do_degrau := 0
		for y in int(q.y):
			for x in int(q.x):
				if img.get_pixel(x, y).a > 0.0:
					primeiro += 1
				var a := img.get_pixel(x + int(q.x) * (int(f.n) - 1), y).a
				if a > 0.0:
					ultimo += 1
				if absf(a * 5.0 - roundf(a * 5.0)) > 0.02:
					fora_do_degrau += 1
		ok(primeiro > 0, "%s: o primeiro quadro desenha" % id)
		ok(ultimo < primeiro or ultimo < int(q.x * q.y) / 8, "%s: o efeito vai sumindo (%d px no fim, %d no começo)" % [id, ultimo, primeiro])
		ok(fora_do_degrau == 0, "%s: alfa só nos 6 degraus" % id)
	for id in RAIOS_METEORO:
		var q: Vector2 = Anim.de(id).get("impacto", {}).get("quadro", Vector2.ONE)
		for raio in RAIOS_METEORO[id]:
			ok(is_equal_approx(maxf(1.0, roundf(float(raio) * 2.0 / q.x)), 1.0), "%s: raio %s desenha em escala 1" % [id, raio])
	print("v2_fx_armas_pixelfx falhas=", falhas)
	get_tree().quit(1 if falhas else 0)
