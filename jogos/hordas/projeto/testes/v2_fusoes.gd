extends Node
# Teste automático da arte das fusões (assets/v2/fusoes/, gerada por `gerar_objetos.py fusoes`, PR #289 do Codex integrado):
# o cartão FUSÃO é 600 x 200 com borda de 12 px (9-slice), o halo 48 x 48, o ícone 16 x 16 e a onda da Ventania 64 x 32.
# A Ventania entra pelo registro de armas (v2/armas_novas.gd lê o índice da fusão por último, então vale por cima da arte da arma base).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_fusoes.tscn  (imprime "v2_fusoes falhas=0")
const Novas := preload("res://v2/armas_novas.gd")
const PASTA := "res://assets/v2/fusoes/"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var tamanhos := {"moldura.png": Vector2(600, 200), "halo.png": Vector2(48, 48), "icone.png": Vector2(16, 16), "ventania.png": Vector2(64, 32)}
	for arquivo in tamanhos:
		var tex := load(PASTA + arquivo) as Texture2D
		ok(tex != null, "%s carrega" % arquivo)
		if tex != null:
			ok(tex.get_size() == tamanhos[arquivo], "%s tem %s (tem %s)" % [arquivo, tamanhos[arquivo], tex.get_size()])
	var d = JSON.parse_string(FileAccess.get_file_as_string(PASTA.path_join("indice.json")))
	ok(d is Dictionary, "indice.json lê")
	if d is Dictionary:
		ok(int(d.arte.moldura.borda) == 12, "a moldura tem borda de 12 px no índice")
		var tam_v: Array = d.sprites.ventania.tamanho
		ok(float(tam_v[0]) == 64.0 and float(tam_v[1]) == 32.0, "a Ventania registra 64 x 32 no índice")
	var sp: Dictionary = Novas.sprite_de("ventania")
	ok(not sp.is_empty(), "a Ventania tem sprite no registro de armas")
	if not sp.is_empty():
		ok(sp.tam == Vector2(64, 32), "o sprite da Ventania usa o tamanho da arte da fusão (tem %s)" % str(sp.tam))
		ok(sp.tex.resource_path.begins_with(PASTA), "o sprite da Ventania vem de assets/v2/fusoes/ (vem de %s)" % sp.tex.resource_path)
	print("v2_fusoes falhas=%d" % falhas)
	get_tree().quit()
