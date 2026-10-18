extends SceneTree
## Testes do Vornak da v3 (v3/chefes/vornak.gd + chefe_base.gd) e das folhas de 8 direções (assets/v3/chefes/).
## Roda: godot --headless --path jogos/hordas/projeto -s res://testes/v3_vornak.gd  (imprime "v3_vornak falhas=0")
## Não liga nada à v2 nem à arena: só a lógica do chefe e os arquivos das folhas.

const Vornak := preload("res://v3/chefes/vornak.gd")
const PASSO := 0.05
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func novo_chefe():
	var v = Vornak.new()
	v.iniciar(Vornak.CONFIG)
	return v


func rodar(v, segundos: float) -> void:
	var t := 0.0
	while t < segundos:
		v.avancar(PASSO)
		t += PASSO


func _initialize() -> void:
	test_folhas()
	test_inicio()
	test_aviso_e_impacto()
	test_recarga()
	test_fase2()
	test_cura_limitada()
	test_morte()
	print("v3_vornak falhas=", falhas)
	quit(1 if falhas > 0 else 0)


func test_folhas() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v3/chefes/vornak_sprites.json"))
	ok(dados is Dictionary, "folhas: o json lê")
	if not (dados is Dictionary):
		return
	ok(int(dados.tamanho_quadro) == 128, "folhas: quadro de 128 px")
	ok(dados.direcoes.size() == 8, "folhas: 8 direções")
	for clipe in dados.clipes:
		var info = dados.clipes[clipe]
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/v3/chefes/vornak_%s_8dir.png" % clipe))
		ok(img != null, "folhas: %s carrega" % clipe)
		if img == null:
			continue
		ok(img.get_width() == int(info.quadros) * 128 and img.get_height() == 8 * 128,
			"folhas: %s tem %d quadros x 8 direções (tem %dx%d)" % [clipe, int(info.quadros), img.get_width(), img.get_height()])


func test_inicio() -> void:
	var v = novo_chefe()
	ok(v.vida == 1100.0 and v.vida_max == 1100.0, "inicio: vida 1100")
	ok(v.fase == 1 and v.estado == "andar", "inicio: fase 1, andando")
	ok(not v.morto(), "inicio: vivo")


func test_aviso_e_impacto() -> void:
	var v = novo_chefe()
	var avisos := []
	var golpes := []
	v.aviso_iniciou.connect(func(n, r): avisos.append([n, r]))
	v.golpe.connect(func(n, r, d): golpes.append([n, d]))
	rodar(v, 0.1)
	ok(avisos.size() == 1 and avisos[0][0] == "raizes_corrompidas", "aviso: primeiro ataque é raizes_corrompidas")
	ok(v.estado == "aviso" and v.clip_atual() == "attack_01", "aviso: estado aviso com a animação attack_01")
	rodar(v, 0.7)
	ok(golpes.is_empty(), "aviso: nenhum dano durante o aviso")
	rodar(v, 0.25)
	ok(golpes.size() == 1 and golpes[0][0] == "raizes_corrompidas" and golpes[0][1] == 10.0, "impacto: sai uma vez com o dano 10")
	rodar(v, 2.0)
	ok(golpes.size() == 1, "impacto: não repete o dano sem novo aviso")


func test_recarga() -> void:
	var v = novo_chefe()
	var nomes := []
	v.aviso_iniciou.connect(func(n, r): nomes.append(n))
	rodar(v, 0.9 + 0.2 + 0.6 + 2.5 + 0.2)
	ok(nomes.size() >= 2, "recarga: depois do primeiro ataque volta a atacar")
	ok(nomes.size() == 2 and nomes[1] == "golpe_de_raizes", "recarga: rodízio segue para golpe_de_raizes (tem %s)" % str(nomes))


func test_fase2() -> void:
	var v = novo_chefe()
	var fases := []
	v.fase_mudou.connect(func(f): fases.append(f))
	v.receber_dano(1100.0 * 0.5)
	ok(fases.is_empty() and v.fase == 1, "fase2: ainda fase 1 com 50% de vida")
	v.receber_dano(1100.0 * 0.2)
	ok(v.fase == 2 and fases == [2], "fase2: abre abaixo de 40%")
	ok(v.estado == "transicao", "fase2: entra na transição antes de atacar")
	rodar(v, 1.7)
	ok(v.estado == "andar" or v.estado == "aviso", "fase2: volta a atacar depois da transição")
	var nomes := []
	v.aviso_iniciou.connect(func(n, r): nomes.append(n))
	rodar(v, 20.0)
	ok(nomes.has("raizes_longas") and nomes.has("tempestade_de_raizes"), "fase2: ataques novos aparecem (%s)" % str(nomes))


func test_cura_limitada() -> void:
	var v = novo_chefe()
	v.receber_dano(300.0)
	ok(v.vida == 800.0, "cura: dano tirado")
	v.curar(60.0)
	ok(v.vida == 860.0, "cura: cura o valor pedido")
	v.curar(9999.0)
	ok(v.vida == v.vida_max, "cura: nunca passa da vida máxima")


func test_morte() -> void:
	var v = novo_chefe()
	var mortes := []
	var golpes := []
	v.morreu.connect(func(): mortes.append(true))
	v.golpe.connect(func(n, r, d): golpes.append(n))
	rodar(v, 0.1)
	var matou: bool = v.receber_dano(9999.0)
	ok(matou and v.morto() and v.vida == 0.0, "morte: vida zera e o chefe morre")
	ok(mortes.size() == 1, "morte: sinal de morte sai uma vez")
	rodar(v, 10.0)
	ok(golpes.is_empty(), "morte: nenhum golpe depois de morto")
	ok(v.receber_dano(50.0) == true and mortes.size() == 1, "morte: dano depois de morto não emite de novo")
