extends Node
## Foto de viewport dos motivos novos de nuvem para revisão visual local.
const Mundo := preload("res://v2/mundo.tscn")
const IDS := [
	"nevoa_espectral",
	"nuvem_veneno",
	"nevoeiro_gelado",
	"cinzas_vulcanicas",
	"fumaca_sonolenta",
	"cortina_sangue",
]
const NOMES := ["ESPECTRAL", "VENENO", "GEADA", "CINZAS", "SONO", "SANGUE"]
const CORES := [
	Color(0.8, 0.95, 0.95),
	Color(0.45, 0.95, 0.2),
	Color(0.2, 0.55, 1.0),
	Color(0.35, 0.35, 0.38),
	Color(0.75, 0.6, 1.0),
	Color(0.85, 0.08, 0.12),
]

var w


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	# Usa a viewport interna do jogo, sem HUD e sem atores cobrindo os efeitos.
	w.cam.zoom = Vector2(2.0, 2.0)
	for filho in w.sv.get_children():
		if filho is CanvasLayer and filho != w.glow:
			filho.visible = false
	var novas = w.combate.armas.novas
	var legenda := CanvasLayer.new()
	legenda.layer = 20
	w.sv.add_child(legenda)
	for i in IDS.size():
		var coluna := i % 3
		var linha := i / 3
		var deslocamento := Vector2(float(coluna - 1) * 105.0, float(linha) * 95.0 - 38.0)
		var p: Vector2 = w.heroi.pos + deslocamento
		var st := {"dano": 8.0, "tique": 0.5, "duracao": 4.0, "lentidao": 0.0}
		var arma := {"id": IDS[i], "st": st, "cor": CORES[i]}
		var it: Dictionary = novas._novo("nuvem", arma, p, 4.0)
		it.r = 36.0
		it.fase = float(i) * 1.07
		it.pulso = 0.68
		var texto := Label.new()
		texto.text = NOMES[i]
		texto.position = Vector2(242.0 + float(coluna) * 210.0, 242.0 + float(linha) * 190.0)
		texto.add_theme_font_size_override("font_size", 11)
		texto.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
		texto.add_theme_color_override("font_shadow_color", Color(0.04, 0.04, 0.06, 1.0))
		texto.add_theme_constant_override("shadow_offset_x", 1)
		texto.add_theme_constant_override("shadow_offset_y", 1)
		legenda.add_child(texto)
	for m in w.monstros:
		m.raiz.visible = false
	w.heroi.raiz.visible = false
	for _i in 18:
		w.avancar(1.0 / 60.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var destino := "C:/Dev/Breno/analise-kikiu/logs-ataques/identidade_nuvens.png"
	for argumento in OS.get_cmdline_user_args():
		if str(argumento).begins_with("--fotos="):
			destino = str(argumento).trim_prefix("--fotos=")
	DirAccess.make_dir_recursive_absolute(destino.get_base_dir())
	await RenderingServer.frame_post_draw
	var imagem: Image = w.sv.get_texture().get_image()
	var erro: Error = imagem.save_png(destino)
	print("V2_ATAQUES_VISUAIS foto=%s erro=%d" % [destino, erro])
	get_tree().quit(0 if erro == OK else 1)
