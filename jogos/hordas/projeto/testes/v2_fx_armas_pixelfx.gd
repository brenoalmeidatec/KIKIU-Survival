extends "res://testes/isolamento_v2.gd"
# Efeitos das armas no estilo do pixelfx (assets/v2/armas_anim/indice_pixelfx.json, guia em docs/visual_2_5d/estilo_pixelfx.md). Prova que (1) toda folha
# nova existe, tem o tamanho de quadro x n e o alfa nos 6 degraus, (2) as armas seguem com as outras animações, (3) meteoro desenha em escala 1 em
# todos os níveis (a conta do `armas_novas.gd`), (4) impacto vai sumindo até o fim, (5) as folhas fx_* que o código pede existem, (6) a cor e o
# espelho chegam ao pool do tocar_fx. Falha sem "pixelfx" em Anim.GRUPOS.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_fx_armas_pixelfx.tscn  (imprime "v2_fx_armas_pixelfx falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const Novas := preload("res://v2/armas_novas.gd")
const VOO := {"bola_fogo": "voo", "adagas_voadoras": "voo", "cometa_gelado": "queda", "chuva_pedras": "queda", "juizo_final": "queda"}
const RAIOS_METEORO := {"cometa_gelado": 75.0, "chuva_pedras": 40.0, "meteoro_flamejante": 60.0, "cometa_negro": 85.0, "juizo_final": 80.0}  # no maior nível
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var novas := 0
	var ind: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v2/armas_anim/indice_pixelfx.json"))
	for nome in ind.folhas:
		var fo: Dictionary = ind.folhas[nome]
		var fa := Anim.de(str(fo.armas[0]))
		for an in fo.anims:
			if not str(fo.anims[an].arquivo).begins_with("pfx_"):
				continue
			novas += 1
			ok(fa.has(an), "%s: %s carregou" % [nome, an])
			if fa.has(an):
				_folha(str(nome) + "/" + str(an), fa[an], an == "impacto" or an == "explosao")
	ok(novas >= 80, "folhas novas lidas (%d)" % novas)
	for id in VOO:
		ok(Anim.de(id).has(VOO[id]), "%s não perdeu '%s'" % [id, VOO[id]])
	for id in RAIOS_METEORO:
		var q: Vector2 = Anim.de(id).get("impacto", {}).get("quadro", Vector2.ONE)
		ok(is_equal_approx(maxf(1.0, roundf(float(RAIOS_METEORO[id]) * 2.0 / q.x)), 1.0), "%s: raio %s desenha em escala 1" % [id, RAIOS_METEORO[id]])
	for id in ["fx_explode", "fx_cabaca", "fx_pancada", "fx_aliado"]:
		ok(Anim.de(id).has("impacto"), "folha %s existe" % id)
	var n = Novas.new()
	n.x_pos.resize(n.MAX_FX)
	n.x_t.resize(n.MAX_FX)
	n.x_dur.resize(n.MAX_FX)
	n.x_esc.resize(n.MAX_FX)
	n.x_folha.resize(n.MAX_FX)
	n.x_chao.resize(n.MAX_FX)
	n.x_flip.resize(n.MAX_FX)
	n.x_cor.resize(n.MAX_FX)
	n.tocar_fx(Anim.de("fx_aliado").get("impacto", {}), Vector2.ZERO, 1.0, false, -1.0, Color.RED)
	ok(n.x_flip[0] == -1.0 and n.x_cor[0] == Color.RED, "espelho e cor chegam ao pool")
	print("v2_fx_armas_pixelfx falhas=", falhas)
	get_tree().quit(1 if falhas else 0)


func _folha(nome: String, f: Dictionary, vai_sumir: bool) -> void:
	var tex: Texture2D = f.tex
	var q: Vector2 = f.quadro
	ok(tex.get_width() == int(q.x) * int(f.n) and tex.get_height() == int(q.y), "%s: tira = quadro x n" % nome)
	if vai_sumir:
		ok(Anim.duracao(f) <= 0.6, "%s: impacto curto (%.2f s)" % [nome, Anim.duracao(f)])
	var img := tex.get_image()
	img.decompress()
	var ultimo := 0
	var meio := 0
	var fora := 0
	var u := int(q.x) * (int(f.n) - 1)
	var m := int(q.x) * (int(f.n) / 3)
	for y in range(0, int(q.y), 2):
		for x in range(0, int(q.x), 2):
			if img.get_pixel(x + m, y).a > 0.0:
				meio += 1
			var a := img.get_pixel(x + u, y).a
			if a > 0.0:
				ultimo += 1
			if absf(a * 5.0 - roundf(a * 5.0)) > 0.02:
				fora += 1
	ok(fora == 0, "%s: alfa só nos 6 degraus" % nome)
	if vai_sumir:
		ok(ultimo < meio, "%s: vai sumindo (%d px no fim, %d no meio)" % [nome, ultimo, meio])
