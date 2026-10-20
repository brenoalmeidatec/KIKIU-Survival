extends Node
# Teste automático: transparência dos objetos de caixa (prédio, carro, container, muro, abrigo) da Cidade, em v2/copas.gd.
#   - herói ATRÁS do objeto, com o corpo sob o desenho: a força sobe a 1 (o sprite inteiro desce ao alfa de ALFA_CAIXA);
#   - herói na frente, ou atrás mas fora do retângulo do desenho: volta a 0;
#   - objeto de elipse alto (poste, placa) segue com o buraco circular (shader com `centro`), sem alfa do sprite inteiro;
#   - cenario.tem_caixa diz sim para prédio/carro/container e não para poste/hidrante.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_transparencia.tscn  (imprime "v2_transparencia falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Copas := preload("res://v2/copas.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func primeiro(nome: String):
	for a in w.cenario.objetos:
		if a.chave == nome:
			return a
	return null


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = "cidade"
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	w.monstros.clear()
	for nome in ["predio_loja", "carro_a", "container_a", "muro_tijolo", "ponto_onibus"]:
		ok(w.cenario.tem_caixa(nome), "%s tem forma caixa" % nome)
	for nome in ["poste_rua", "hidrante", "barril_fogo"]:
		ok(not w.cenario.tem_caixa(nome), "%s não tem forma caixa" % nome)
	for nome in ["predio_loja", "carro_a", "container_a"]:
		var a = primeiro(nome)
		ok(a != null, "há um %s na Cidade" % nome)
		if a == null:
			continue
		var m: ShaderMaterial = a.sprite.material
		ok(m != null and m.get_shader_parameter("alfa_min") == Copas.ALFA_CAIXA, "%s: material de caixa (alfa %.2f)" % [nome, Copas.ALFA_CAIXA])
		w.heroi.definir_pos(a.pos + Vector2(0, -float(a.alt) * 0.45))
		passos(90)
		ok(w.copas.fuerza_da_copa(a) > 0.97, "%s: herói atrás e sob o desenho: translúcido (força %.2f)" % [nome, w.copas.fuerza_da_copa(a)])
		w.heroi.definir_pos(a.pos + Vector2(0, 40))
		passos(90)
		ok(w.copas.fuerza_da_copa(a) < 0.03, "%s: herói na frente: volta opaco (força %.2f)" % [nome, w.copas.fuerza_da_copa(a)])
		w.heroi.definir_pos(a.pos + Vector2(float(a.sprite.texture.get_width()) * 0.5 + 80.0, -float(a.alt) * 0.45))
		passos(90)
		ok(w.copas.fuerza_da_copa(a) < 0.03, "%s: herói atrás mas ao lado do desenho: fica opaco (força %.2f)" % [nome, w.copas.fuerza_da_copa(a)])
	var poste = primeiro("poste_rua")
	if poste != null and poste.sprite.material != null:
		ok(poste.sprite.material.get_shader_parameter("alfa_min") == null or poste.sprite.material.shader.code.contains("centro"), "poste: buraco circular")
	print("v2_transparencia falhas=%d" % falhas)
	get_tree().quit()
