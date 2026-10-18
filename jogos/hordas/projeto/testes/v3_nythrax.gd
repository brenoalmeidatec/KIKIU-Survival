extends SceneTree
## Testes do Nythrax da v3 (v3/chefes/nythrax.gd + chefe_base.gd) e das folhas de 8 direções (assets/v3/chefes/nythrax_*).
## Roda: godot --headless --path jogos/hordas/projeto -s res://testes/v3_nythrax.gd  (imprime "v3_nythrax falhas=0")

const Nythrax := preload("res://v3/chefes/nythrax.gd")
const PASSO := 0.05
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func novo_chefe():
	var n = Nythrax.new()
	n.iniciar(Nythrax.CONFIG)
	return n


func rodar(n, segundos: float) -> void:
	var t := 0.0
	while t < segundos:
		n.avancar(PASSO)
		t += PASSO


func _initialize() -> void:
	test_folhas()
	test_inicio()
	test_ilusao_sem_dano()
	test_nevoa_sem_dano()
	test_caca_abaixo_de_35()
	test_morte()
	print("v3_nythrax falhas=", falhas)
	quit(1 if falhas > 0 else 0)


func test_folhas() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v3/chefes/nythrax_sprites.json"))
	ok(dados is Dictionary, "folhas: o json lê")
	if not (dados is Dictionary):
		return
	ok(int(dados.tamanho_quadro) == 128 and dados.direcoes.size() == 8, "folhas: quadro 128 e 8 direções")
	for clipe in dados.clipes:
		var info = dados.clipes[clipe]
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/v3/chefes/nythrax_%s_8dir.png" % clipe))
		ok(img != null, "folhas: %s carrega" % clipe)
		if img == null:
			continue
		ok(img.get_width() == int(info.quadros) * 128 and img.get_height() == 8 * 128,
			"folhas: %s tem %d quadros x 8 direções" % [clipe, int(info.quadros)])


func test_inicio() -> void:
	var n = novo_chefe()
	ok(n.vida == 1600.0 and n.fase == 1 and n.estado == "andar", "inicio: vida 1600, fase 1, andando")


func test_ilusao_sem_dano() -> void:
	var n = novo_chefe()
	var danos := []
	var ilusoes := []
	n.golpe.connect(func(nome, r, dano): danos.append([nome, dano]))
	n.aviso_iniciou.connect(func(nome, r): if nome == "ilusoes_espectrais": ilusoes.append(nome))
	rodar(n, 30.0)
	ok(not ilusoes.is_empty(), "ilusao: aparece no rodízio")
	for d in danos:
		if d[0] == "ilusoes_espectrais":
			ok(d[1] == 0.0, "ilusao: não dá dano principal")


func test_nevoa_sem_dano() -> void:
	var n = novo_chefe()
	var danos := []
	n.golpe.connect(func(nome, r, dano): if nome == "nevoa_ocultante" and dano > 0.0: danos.append(dano))
	rodar(n, 30.0)
	ok(danos.is_empty(), "nevoa: não causa dano")


func test_caca_abaixo_de_35() -> void:
	var n = novo_chefe()
	n.receber_dano(1600.0 * 0.5)
	ok(n.fase == 1, "caca: fase 1 com 50% de vida")
	n.receber_dano(1600.0 * 0.2)
	ok(n.fase == 2 and n.estado == "transicao", "caca: fase de caça abaixo de 35%")
	rodar(n, 2.0)
	var nomes := []
	n.aviso_iniciou.connect(func(nome, r): nomes.append(nome))
	rodar(n, 20.0)
	ok(nomes.has("investida_dupla") and nomes.has("garras_de_caca"), "caca: ataques de caça aparecem (%s)" % str(nomes))


func test_morte() -> void:
	var n = novo_chefe()
	var mortes := []
	n.morreu.connect(func(): mortes.append(true))
	ok(n.receber_dano(9999.0) and n.morto(), "morte: o lobo morre")
	rodar(n, 5.0)
	ok(mortes.size() == 1, "morte: sinal de morte sai uma vez")
