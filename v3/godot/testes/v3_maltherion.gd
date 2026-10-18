extends SceneTree
## Testes do Maltherion da v3 (v3/chefes/maltherion.gd + chefe_base.gd) e das folhas de 8 direções (assets/v3/chefes/maltherion_*).
## Roda: godot --headless --path v3/godot -s res://testes/v3_maltherion.gd  (imprime "v3_maltherion falhas=0")

const Maltherion := preload("res://chefes/maltherion.gd")
const PASSO := 0.05
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func novo_chefe():
	var m = Maltherion.new()
	m.iniciar(Maltherion.CONFIG)
	return m


func rodar(m, segundos: float) -> void:
	var t := 0.0
	while t < segundos:
		m.avancar(PASSO)
		t += PASSO


func _initialize() -> void:
	test_folhas()
	test_fases()
	test_coracao_so_na_fase3()
	test_invocacao_sem_dano_e_limitada()
	test_janela_do_coracao()
	test_morte()
	print("v3_maltherion falhas=", falhas)
	quit(1 if falhas > 0 else 0)


func test_folhas() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://assets/chefes/maltherion_sprites.json"))
	ok(dados is Dictionary, "folhas: o json lê")
	if not (dados is Dictionary):
		return
	ok(int(dados.tamanho_quadro) == 192 and dados.direcoes.size() == 8, "folhas: quadro 192 e 8 direções")
	for clipe in dados.clipes:
		var info = dados.clipes[clipe]
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/chefes/maltherion_%s_8dir.png" % clipe))
		ok(img != null, "folhas: %s carrega" % clipe)
		if img == null:
			continue
		ok(img.get_width() == int(info.quadros) * 192 and img.get_height() == 8 * 192,
			"folhas: %s tem %d quadros x 8 direções" % [clipe, int(info.quadros)])


func test_fases() -> void:
	var m = novo_chefe()
	var fases := []
	m.fase_mudou.connect(func(f): fases.append(f))
	m.receber_dano(5000.0 * 0.25)
	ok(fases.is_empty() and m.fase == 1, "fases: ainda fase 1 com 75%")
	m.receber_dano(5000.0 * 0.1)
	ok(fases == [2] and m.fase == 2, "fases: fase 2 abaixo de 70%")
	rodar(m, 2.0)
	m.receber_dano(5000.0 * 0.5)
	ok(fases == [2, 3] and m.fase == 3, "fases: fase 3 abaixo de 30%")


func test_coracao_so_na_fase3() -> void:
	var m = novo_chefe()
	var nomes := []
	m.aviso_iniciou.connect(func(n, r): nomes.append(n))
	rodar(m, 60.0)
	ok(not nomes.has("coracao_da_floresta"), "coracao: não aparece na fase 1")
	m.receber_dano(5000.0 * 0.5)
	rodar(m, 2.0)
	m.receber_dano(5000.0 * 0.25)
	nomes.clear()
	rodar(m, 60.0)
	ok(nomes.has("coracao_da_floresta"), "coracao: aparece na fase 3 (%s)" % str(nomes))


func test_invocacao_sem_dano_e_limitada() -> void:
	var m = novo_chefe()
	var danos := []
	m.golpe.connect(func(n, r, dano): if n == "invocacao_de_criaturas": danos.append(dano))
	rodar(m, 80.0)
	ok(danos.is_empty() or danos.all(func(d): return d == 0.0), "invocacao: não dá dano")
	m.ataque_atual = {"invoca": 2}
	ok(m.pode_invocar(0) == 2, "invocacao: sai o que cabe (2 com nenhuma viva)")
	ok(m.pode_invocar(2) == 1, "invocacao: 3 vivas no máximo (sai 1 com 2 vivas)")
	ok(m.pode_invocar(3) == 0, "invocacao: nenhuma com o limite cheio")


func test_janela_do_coracao() -> void:
	var m = novo_chefe()
	var achou := false
	for a in m.CONFIG.ataques:
		if a.nome == "coracao_da_floresta":
			achou = true
			ok(float(a.janela) >= 2.0, "janela: o Coração deixa pelo menos 2 s de contra-ataque")
			ok(float(a.recupera) >= float(a.janela), "janela: a recuperação cobre a janela")
	ok(achou, "janela: o Coração existe nos dados")


func test_morte() -> void:
	var m = novo_chefe()
	var mortes := []
	m.morreu.connect(func(): mortes.append(true))
	ok(m.receber_dano(99999.0) and m.morto(), "morte: o Maltherion morre")
	rodar(m, 5.0)
	ok(mortes.size() == 1, "morte: sinal sai uma vez")
