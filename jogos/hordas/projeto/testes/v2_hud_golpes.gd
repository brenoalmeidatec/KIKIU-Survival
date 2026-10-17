extends Node
# Teste automático da faixa de GOLPES do HUD da v2 (v2/hud_golpes.gd, no hud.tscn): cada golpe automático que o herói ganha aparece como
# parte fixa do HUD, com nível, recarga e progresso da fusão; o nível sobe e anima; a fusão troca as peças pela evolução e nada mais some;
# parada, a faixa não pede redesenho; com mundo sem combate fica escondida; não cruza nenhum outro bloco do HUD (e se esconde com o card C).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_hud_golpes.tscn  (imprime "v2_hud_golpes falhas=0")
# Prints: godot --path jogos/hordas/projeto res://testes/v2_hud_golpes.tscn -- --fotos=PASTA  (grava PNG do HUD com golpes e sai)
const Mundo := preload("res://v2/mundo.tscn")
const Hud := preload("res://v2/hud.gd")
const Golpes := preload("res://v2/hud_golpes.gd")
const PASSO := 1.0 / 60.0
const LEITURA := 0.06

var falhas := 0


class MundoFalso:
	extends RefCounted
	var heroi = null
	var abates := 0
	var combo := 0
	var tempo_partida := 0.0
	var monstros_vivos := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	_sem_combate()
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	var hud = w.ui.get_node("Hud")  # a escala da interface (#320) pôs o HUD no SubViewport de UI
	hud.set_process(false)
	var g = hud.get_node("Raiz/Golpes")
	g.set_process(false)
	if pasta != "":
		await _fotos(w, hud, g, pasta)
	else:
		_partida(w, hud, g)
		print("v2_hud_golpes falhas=%d" % falhas)
	get_tree().quit()


func _dar(w, id: String) -> void:
	var cs = w.combate.cartas
	cs.aplicar(cs.montar_carta(cs.definicao(id), 0))


func _passar(g, s: float) -> void:
	for i in int(s / PASSO) + 1:
		g.avancar(PASSO)


func _item(g, id: String) -> Dictionary:
	for it in g.itens:
		if it.id == id:
			return it
	return {}


func _sem_combate() -> void:
	var v := SubViewport.new()
	add_child(v)
	var falso := MundoFalso.new()
	var hud = Hud.criar(falso)
	v.add_child(hud)
	hud.set_process(false)
	var g = hud.get_node("Raiz/Golpes")
	g.set_process(false)
	g.avancar(LEITURA)
	hud.avancar(PASSO)
	ok(g.itens.is_empty() and not g.visible, "mundo sem combate: a faixa de golpes fica escondida")
	ok(g.area_ocupada().size == Vector2.ZERO, "sem golpes a faixa não ocupa área")
	var vazio := Node.new()
	var hud2 = Hud.criar(vazio)
	v.add_child(hud2)
	hud2.set_process(false)
	hud2.get_node("Raiz/Golpes").avancar(LEITURA)
	hud2.avancar(PASSO)
	ok(not hud2.get_node("Raiz/Golpes").visible, "mundo sem nenhum campo: sem erro e sem faixa")
	v.queue_free()
	vazio.free()


func _partida(w, hud, g) -> void:
	g.avancar(LEITURA)
	ok(g.itens.is_empty() and not g.visible, "começa sem golpes: faixa escondida")

	# 1. o golpe aparece ao ser ganho, com pop
	_dar(w, "bola_fogo")
	g.avancar(LEITURA)
	ok(g.itens.size() == 1 and g.visible, "a bola de fogo aparece na faixa ao ser ganha")
	var it := _item(g, "bola_fogo")
	ok(int(it.nivel) == 1 and int(it.max) == 5, "bola de fogo nv 1 de 5 (tem %s de %s)" % [it.get("nivel"), it.get("max")])
	ok(g.anims.has("bola_fogo") and g.anims.bola_fogo.tipo == "novo", "golpe novo anima (pop)")
	ok(Dados.icone_carta("bola_fogo") != null, "o ícone próprio da bola de fogo carrega")
	_passar(g, 0.6)
	ok(g.anims.is_empty(), "a animação acaba em 0,5 s")

	# 2. o nível sobe e pulsa; o que já estava continua
	_dar(w, "laminas")
	g.avancar(LEITURA)
	_passar(g, 0.6)
	_dar(w, "bola_fogo")
	g.avancar(LEITURA)
	ok(int(_item(g, "bola_fogo").nivel) == 2, "bola de fogo sobe para nv 2")
	ok(g.anims.has("bola_fogo") and g.anims.bola_fogo.tipo == "nivel", "nível novo anima (pulso)")
	ok(not g.anims.has("laminas"), "só o golpe que subiu pulsa")
	ok(g.itens.size() == 2 and g.itens[0].id == "bola_fogo" and g.itens[1].id == "laminas", "ordem de aquisição mantida")
	_passar(g, 0.6)

	# 3. recarga: pronta (cheia) e recém-disparada (vazia); lâmina não tem recarga
	var a: Dictionary = w.combate.armas.ativas.bola_fogo
	a.t = 0.0
	g.avancar(LEITURA)
	ok(int(_item(g, "bola_fogo").rec) == Golpes.ICONE, "recarga zerada: pronta, linha cheia (tem %s)" % _item(g, "bola_fogo").rec)
	a.t = float(a.st.recarga) / w.heroi.m_vel_ataque
	g.avancar(LEITURA)
	ok(int(_item(g, "bola_fogo").rec) == 0, "recarga recém-disparada: linha vazia (tem %s)" % _item(g, "bola_fogo").rec)
	a.t = float(a.st.recarga) / w.heroi.m_vel_ataque / 2.0
	g.avancar(LEITURA)
	ok(absi(int(_item(g, "bola_fogo").rec) - Golpes.ICONE / 2) <= 1, "meia recarga: metade da linha (tem %s)" % _item(g, "bola_fogo").rec)
	ok(int(_item(g, "laminas").rec) == -1, "lâmina bate sem parar: sem linha de recarga")

	# 4. marca de fusão: só quando falta UM nível para uma receita (bola_fogo nv 2 de 3 e bolas_chumbo ausente = 2 de 6 níveis: longe)
	ok(not _item(g, "bola_fogo").quase, "fusão longe (2 de 6 níveis): sem marca")
	ok(not _item(g, "bola_fogo").has("fus"), "sem barra de progresso da fusão")
	_dar(w, "bola_fogo")
	g.avancar(LEITURA)
	ok(not _item(g, "bola_fogo").quase, "fusão: 3 de 6 níveis ainda sem marca")
	_dar(w, "bolas_chumbo")
	_dar(w, "bolas_chumbo")
	g.avancar(LEITURA)
	ok(_item(g, "bolas_chumbo").quase and _item(g, "bola_fogo").quase, "falta 1 nível (5 de 6): a marca de fusão acende nas duas peças")

	# 5. a fusão troca as peças pela evolução; nada mais some
	_passar(g, 0.6)
	_dar(w, "bolas_chumbo")
	g.avancar(LEITURA)
	ok(_item(g, "bola_fogo").is_empty() and _item(g, "bolas_chumbo").is_empty(), "a fusão consome as duas peças")
	var evo := _item(g, "bola_incendiaria")
	ok(not evo.is_empty() and bool(evo.evo), "a Bola Incendiária entra na faixa como evoluída")
	ok(not _item(g, "laminas").is_empty(), "a fusão não tira outros golpes (lâminas continua)")
	ok(g.anims.has("bola_incendiaria") and g.anims.bola_incendiaria.tipo == "fusao", "a fusão anima em magenta")
	ok(Dados.icone_carta("bola_incendiaria") != null, "o ícone da evolução carrega")
	ok(not evo.quase, "evoluída não tem marca de fusão")
	_passar(g, 0.6)

	# 6. parada, a faixa não pede redesenho (só a leitura a 20 Hz roda) e fica translúcida; ao mudar, fica opaca
	_passar(g, 4.0)
	var antes: int = g.pedidos
	_passar(g, 1.0)
	ok(g.pedidos == antes, "parada não pede redesenho (pediu %d)" % (g.pedidos - antes))
	ok(g.modulate.a < 0.8 and g.modulate.a > 0.3, "parada, a faixa fica translúcida (alfa %s)" % g.modulate.a)
	_dar(w, "laminas")
	_passar(g, 0.4)
	ok(g.modulate.a > 0.95, "ao subir de nível a faixa fica opaca (alfa %s)" % g.modulate.a)
	_passar(g, 5.0)
	ok(g.modulate.a < 0.8, "e volta a esmaecer depois (alfa %s)" % g.modulate.a)

	# 7. dez golpes cabem em duas linhas e não cruzam nada do HUD
	for id in ["corvos", "raio", "runa", "aura_fogo", "golem_barro", "lobo_espirito", "espirito_urso", "nuvem_veneno"]:
		_dar(w, id)
	g.avancar(LEITURA)
	ok(g.itens.size() == 10, "dez golpes na faixa (tem %d)" % g.itens.size())
	_passar(g, 0.6)
	var area: Rect2 = g.area_ocupada()
	ok(Rect2(0, 0, 960, 540).encloses(area), "a faixa cabe na tela de 960x540: %s" % area)
	ok(area.size.y == 2 * Golpes.ALTURA and area.end.x < 262.0, "dez golpes em duas linhas, antes do selo de nível: %s" % area)
	var raiz: Control = hud.get_node("Raiz")
	for caminho in ["Retrato", "Vida", "Tempo", "Abates", "Combo", "Xp", "Selo", "Chefe", "Anuncio", "Habilidades"]:
		var r: Rect2 = raiz.get_node(caminho).get_global_rect()
		ok(not r.intersects(area), "a faixa não cruza %s (%s x %s)" % [caminho, area, r])
	ok(not Rect2(800, 0, 160, 130).intersects(area), "a faixa não cruza o minimapa")
	for it2 in g.itens:
		ok(Dados.icone_carta(it2.id) != null, "ícone de %s carrega" % it2.id)

	# 8. com o card da build aberto (coluna da esquerda), a faixa se esconde; ao fechar, volta
	w.status.visible = true
	g.avancar(LEITURA)
	ok(not g.visible, "com o card da build aberto a faixa se esconde")
	w.status.visible = false
	g.avancar(LEITURA)
	ok(g.visible, "ao fechar o card a faixa volta")
	ok(Golpes.CAPACIDADE == 24, "capacidade de 24 golpes")
	var extra: Vector2 = g.pos_excedente()
	ok(extra.x >= Golpes.POR_LINHA * (Golpes.CAIXA + Golpes.ESPACO), "o +N fica fora dos quadradinhos (x %s)" % extra.x)

	# 9. peça já consumida por outra fusão não conta: a receita impossível não vira o "melhor progresso"
	# lobo_espirito e espirito_raposa viram a Caçada Espiritual (consome o lobo); espirito_urso nv 2 só tem urso_solar (2 de 6) como receita possível
	# (a eclipse_de_almas, que daria 8 de 20 com o lobo consumido, é impossível)
	_dar(w, "lobo_espirito")
	_dar(w, "lobo_espirito")
	_dar(w, "espirito_urso")
	g.avancar(LEITURA)
	_dar(w, "espirito_raposa")
	_dar(w, "espirito_raposa")
	_dar(w, "espirito_raposa")
	g.avancar(LEITURA)
	ok(_item(g, "lobo_espirito").is_empty() and not _item(g, "cacada_espiritual").is_empty(), "a Caçada Espiritual consumiu o lobo")
	ok(int(w.combate.cartas.nivel_de("espirito_urso")) == 2, "espirito_urso segue no nível 2")
	ok(not _item(g, "espirito_urso").quase, "fusão ignora receita com peça consumida: sem marca")


func _fotos(w, hud, g, pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	for i in 30:
		w.avancar(PASSO)
	for id in ["bola_fogo", "laminas", "corvos", "raio", "runa", "aura_fogo", "golem_barro", "lobo_espirito"]:
		_dar(w, id)
		g.avancar(LEITURA)
		_passar(g, 0.55)
	_dar(w, "bola_fogo")
	_dar(w, "bola_fogo")
	_dar(w, "golem_barro")
	_dar(w, "lobo_espirito")
	_dar(w, "lobo_espirito")
	_dar(w, "espirito_raposa")
	_dar(w, "nuvem_veneno")
	g.avancar(LEITURA)
	_passar(g, 0.55)
	hud.avancar(PASSO)
	await get_tree().create_timer(0.3).timeout
	await _foto(w, pasta, "golpes_hud_parado")
	_dar(w, "corvos")
	g.avancar(LEITURA)
	_passar(g, 0.12)
	await get_tree().create_timer(0.05).timeout
	await _foto(w, pasta, "golpes_hud_pulso")


func _foto(w, pasta: String, nome: String) -> void:
	var tam = await w.ap.foto(pasta.path_join("%s.png" % nome))
	print("FOTO %s %s" % [nome, tam])
