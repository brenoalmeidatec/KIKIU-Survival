extends Node
# Teste dos mapas da v2 (v2/mapas.gd e os json de cada mapa em dados/v2_*.json). Usa um save TEMPORÁRIO (user://teste_v2_mapas.cfg).
# Confere: a lista de mapas e a escolha gravada (padrão, trocar, id desconhecido, dar a volta); cada mapa tem os objetos e decalques que
# o json cita nos atlas dele, as luzes e o minimapa só citam nomes que existem, o herói e as zonas de monstros nascem fora de qualquer
# colisão, o mundo roda 2 s com o herói andando nas 4 direções (dentro da área andável e sem esbarrar para sempre) e o santuário troca o
# mapa pelo botão e mostra o nome no ENTRAR.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_mapas.tscn  (imprime "v2_mapas falhas=0")
# Prints (precisa de janela): ... res://testes/v2_mapas.tscn -- --fotos=PASTA  grava santuario_mapa_<id>.png (a tela do santuário com cada mapa).
const Mapas := preload("res://v2/mapas.gd")
const Meta := preload("res://v2/meta.gd")
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Colisao := preload("res://v2/colisao.gd")
const Passagens := preload("res://v2/passagens.gd")
const Sombras := preload("res://v2/sombras.gd")
const SAVE_TESTE := "user://teste_v2_mapas.cfg"
const PASSO := 1.0 / 60.0
const PADRAO_OBJ := "res://prototipos/objetos"
const PADRAO_DEC := "res://prototipos/decalques"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	_apagar_save()
	_lista_e_escolha()
	for id in Mapas.ids():
		_dados_do_mapa(id)
	for id in Mapas.ids():
		await _mundo_do_mapa(id)
		_passagens_e_vista(id)
		_marcadores(id)
	await _santuario()
	_apagar_save()
	print("v2_mapas falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _apagar_save() -> void:
	var sufixos: Array[String] = ["", ".tmp", ".bak"]
	for sufixo in sufixos:
		var caminho := SAVE_TESTE + sufixo
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))


func _lista_e_escolha() -> void:
	ok(Mapas.ids() == ["floresta", "laboratorio", "cidade", "medio"], "os quatro mapas na ordem de seleção")
	ok(Mapas.ids().size() >= 2, "há pelo menos 2 mapas (floresta e laboratório): %s" % str(Mapas.ids()))
	ok(Mapas.ids().has("floresta") and Mapas.ids().has("laboratorio"), "floresta e laboratório estão na lista")
	ok(Mapas.escolhido() == "floresta", "sem save o mapa é a floresta (deu %s)" % Mapas.escolhido())
	Mapas.escolher("laboratorio")
	ok(Mapas.escolhido() == "laboratorio", "escolher grava e escolhido lê de volta")
	var legado := ConfigFile.new()
	legado.set_value("config", "mapa", "medio")
	legado.set_value("meta", "almas", 123)
	ok(legado.save(SAVE_TESTE) == OK, "fixture de save antigo com id medio")
	ok(Mapas.escolhido() == "medio" and Mapas.buscar("medio").nome == "RUÍNAS DA FLORESTA", "save antigo medio preserva o id e mostra o nome novo")
	Mapas.escolher("cidade")
	var preservado := ConfigFile.new()
	preservado.load(SAVE_TESTE)
	ok(preservado.get_value("meta", "almas", 0) == 123, "trocar mapa preserva os dados anteriores do save")
	ok(Mapas.escolhido() == "cidade", "cidade é gravada no save seguro")
	Mapas.escolher("nao_existe")
	ok(Mapas.escolhido() == "floresta", "id desconhecido cai na floresta")
	ok(Mapas.proximo("floresta") == Mapas.ids()[1], "o seguinte da floresta é o segundo da lista")
	ok(Mapas.proximo(Mapas.ids()[Mapas.ids().size() - 1]) == "floresta", "o último dá a volta para a floresta")
	ok(Mapas.proximo("floresta", -1) == Mapas.ids()[Mapas.ids().size() - 1], "o anterior da floresta é o último")
	for m in Mapas.LISTA:
		ok(str(m.nome) != "" and str(m.entrar).begins_with("ENTRAR"), "%s tem nome e texto de entrada" % m.id)
		ok(FileAccess.file_exists("res://dados/%s.json" % m.dados), "%s tem o json de dados" % m.id)


func _json(caminho: String) -> Dictionary:
	var r = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return r if r is Dictionary else {}


func _dados_do_mapa(id: String) -> void:
	var d: Dictionary = Dados.json(str(Mapas.buscar(id).dados))
	ok(str(d.get("_ajuda", "")) != "", "%s: json com _ajuda" % id)
	var tam: Array = d.get("mapa", {}).get("tam", [])
	ok(tam.size() == 2 and int(tam[0]) == 2880 and int(tam[1]) == 1620, "%s: mapa 2880x1620 (o minimapa e a grade de colisão são desse tamanho)" % id)
	var pastas: Dictionary = d.get("mapa", {}).get("pastas", {})
	var cen := _json(str(pastas.get("objetos", PADRAO_OBJ)) + "/cenario.json")
	var dec := _json(str(pastas.get("decalques", PADRAO_DEC)) + "/decalques.json")
	var itens := {}
	for it in cen.get("itens", []):
		itens[str(it.nome)] = it
		ok(it.has("pe") and it.has("regiao") and it.has("colisao"), "%s: item %s com pe, regiao e colisao" % [id, it.nome])
	var decs := {}
	for it in dec.get("itens", []):
		decs[str(it.nome)] = true
	ok(itens.size() >= 10, "%s: o atlas tem objetos (%d)" % [id, itens.size()])
	var faltam := {}
	for o in d.get("objetos", []):
		if not itens.has(str(o[0])):
			faltam[str(o[0])] = true
		ok(
			float(o[1]) >= -100.0 and float(o[1]) <= 3000.0 and float(o[2]) >= -50.0 and float(o[2]) <= 1800.0,
			"%s: objeto %s dentro do mapa %s" % [id, o[0], str(o)]
		)
	ok(faltam.is_empty(), "%s: objetos do mapa que o atlas não tem: %s" % [id, str(faltam.keys())])
	faltam = {}
	for o in d.get("decalques", []):
		if not decs.has(str(o[0])):
			faltam[str(o[0])] = true
	ok(faltam.is_empty(), "%s: decalques do mapa que o atlas não tem: %s" % [id, str(faltam.keys())])
	for nome in d.get("luz_objetos", {}):
		ok(itens.has(nome), "%s: luz_objetos cita %s, que não existe" % [id, nome])
		ok(d.get("luz_tipos", {}).has(str(d.luz_objetos[nome].tipo)), "%s: o tipo de luz de %s existe" % [id, nome])
	for l in d.get("luzes", []):
		ok(d.get("luz_tipos", {}).has(str(l.tipo)), "%s: luz solta de tipo %s existe" % [id, l.tipo])
	ok(d.get("luz_tipos", {}).has("tocha") and d.luz_tipos.has("aura"), "%s: tem as luzes do herói (tocha e aura)" % id)
	var mm: Dictionary = d.get("minimapa", {})
	for nome in mm.get("objetos", {}):
		ok(itens.has(nome), "%s: minimapa cita o objeto %s, que não existe" % [id, nome])
	for nome in mm.get("decalques", {}):
		ok(decs.has(nome), "%s: minimapa cita o decalque %s, que não existe" % [id, nome])
	var nasc: Dictionary = d.get("nascimento", {})
	ok(nasc.has("heroi") and nasc.get("monstros", []).size() >= 6, "%s: nascimento com herói e zonas de monstro" % id)


## Passagens (v2/passagens.gd), objeto na frente do herói (copas.gd) e sombra base (sombras.gd), em cada mapa.
func _passagens_e_vista(id: String) -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	w.monstros.clear()
	var pontos: Array = []
	for z in w.dados.nascimento.monstros:
		pontos.append(Vector2(float(z.centro[0]), float(z.centro[1])))
	# 1. caminho livre: do nascimento do herói a cada zona de monstros, com o corpo comum e com o corpo largo (elite/chefe), sem ilhas fechadas
	for raio in [Passagens.RAIO_HEROI, Passagens.RAIO_HORDA]:
		var rel: Dictionary = Passagens.relatorio(w.limite_andavel, w.heroi.pos, pontos, raio)
		ok(rel.pontos_fora.is_empty(), "%s: toda zona de monstros tem caminho até o herói (raio %.0f): fora = %s" % [id, raio, str(rel.pontos_fora)])
		ok(rel.bolsoes.is_empty(), "%s: sem ilhas livres fechadas (raio %.0f): %s" % [id, raio, str(rel.bolsoes)])
		ok(
			float(rel.alcancadas) >= 0.97 * float(rel.livres),
			"%s: 97%% ou mais do chão livre se alcança (raio %.0f): %d de %d" % [id, raio, rel.alcancadas, rel.livres]
		)
		if id == "laboratorio":  # o laboratório é desenhado com corredores: nada de beco fino (a floresta tem os dela, de árvores e tocos)
			ok(rel.becos <= 4, "%s: sem becos finos sem saída (raio %.0f): %d células" % [id, raio, rel.becos])
	# os quatro cantos andáveis ligam entre si (o corredor das bordas não fecha)
	var g: Dictionary = Passagens.grade(w.limite_andavel, Passagens.RAIO_HEROI)
	var a0: Rect2 = w.limite_andavel
	for canto in [
		a0.position + Vector2(60, 60), a0.position + Vector2(a0.size.x - 60, 60), a0.position + Vector2(60, a0.size.y - 60), a0.end - Vector2(60, 60)
	]:
		var vis: PackedByteArray = Passagens.alcancaveis(g, canto)
		ok(Passagens.contar(vis) >= 0.97 * float(Passagens.contar(g.livre)), "%s: do canto %s se alcança quase todo o mapa" % [id, str(canto)])
	# 2. objeto alto na frente do herói fica translúcido; baixo não; na frente dele volta
	var alt_min := float(w.dados.get("mapa", {}).get("copas_altura_min", w.copas.ALTURA_MIN))
	var alto = null
	var baixo = null
	for a in w.cenario.objetos:
		var h := float(a.sprite.texture.get_height())
		if alto == null and h >= alt_min and h <= 130.0 and a.sprite.material != null:
			alto = a
		if baixo == null and h < alt_min - 12.0 and a.sprite.material == null:
			baixo = a
	ok(alto != null, "%s: há um objeto alto para o teste do fade" % id)
	if alto != null:
		w.heroi.definir_pos(alto.pos + Vector2(0, -float(alto.alt) * 0.3))
		for i in 90:
			w.avancar(PASSO)
		ok(
			w.copas.fuerza_da_copa(alto) > 0.97,
			"%s: herói atrás de %s: o objeto fica translúcido (força %.2f)" % [id, alto.chave, w.copas.fuerza_da_copa(alto)]
		)
		w.heroi.definir_pos(alto.pos + Vector2(0, 40))
		for i in 90:
			w.avancar(PASSO)
		ok(w.copas.fuerza_da_copa(alto) < 0.03, "%s: herói na frente de %s: o objeto volta opaco" % [id, alto.chave])
	if baixo != null:
		w.heroi.definir_pos(baixo.pos + Vector2(0, -8))
		for i in 30:
			w.avancar(PASSO)
		ok(w.copas.fuerza_da_copa(baixo) == 0.0, "%s: objeto baixo (%s) não encobre o herói" % [id, baixo.chave])
	# 3. sombra base: sem nenhuma luz perto, o laboratório ainda dá sombra (sombra_ambiente); a floresta segue só com as luzes
	w.sombras.definir_modo(Sombras.MEDIA)
	w.luzes.dn = 0
	var sombreado := 0
	var n := 0
	for a in w.cenario.objetos:
		if float(a.sprite.texture.get_height()) < 50.0:
			continue
		n += 1
		w.sombras.calcular(a, 1.0)
		if a.sa[0] > 0.1:
			sombreado += 1
		if n >= 20:
			break
	if w.dados.get("mapa", {}).has("sombra_ambiente"):
		ok(sombreado == n and n > 0, "%s: sem luz por perto, os objetos altos ainda têm sombra (%d de %d)" % [id, sombreado, n])
	else:
		ok(sombreado == 0, "%s: sem sombra_ambiente e sem luz, nada de sombra (%d)" % [id, sombreado])
	remove_child(w)
	w.free()


func _mundo_do_mapa(id: String) -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	if id == "cidade":
		_rua_da_cidade(w)
		await _foto_mundo(id, "rua")
	ok(w.id_mapa == id and str(w.dados.get("_ajuda", "")) != "", "%s: o mundo carregou o json certo" % id)
	ok(w.cenario.objetos.size() >= 150, "%s: objetos no mundo: %d" % [id, w.cenario.objetos.size()])
	ok(w.cenario.n_decalques >= 100, "%s: decalques no mundo: %d" % [id, w.cenario.n_decalques])
	ok(w.luzes.lista.size() >= 8, "%s: luzes no mundo: %d" % [id, w.luzes.lista.size()])
	# nascimento limpo: o herói e as zonas de monstros não podem começar dentro de uma forma sólida
	var p: Vector2 = w.heroi.pos
	ok(Colisao.resolver(p, 6.0).distance_to(p) < 0.5, "%s: o herói nasce fora de qualquer colisão (%s)" % [id, str(p)])
	for z in w.dados.nascimento.monstros:
		var c := Vector2(float(z.centro[0]), float(z.centro[1]))
		if id != "floresta":  # na floresta uma zona cai sobre lápides (os monstros nascem em volta, no raio): não é assunto aqui
			ok(Colisao.resolver(c, 10.0).distance_to(c) < 0.5, "%s: a zona de monstros em %s nasce livre" % [id, str(c)])
		ok(w.limite_andavel.has_point(c), "%s: a zona em %s está na área andável" % [id, str(c)])
	# 2 s andando em cada direção: fica na área andável e anda de verdade (nada o prende no nascimento)
	for dir in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
		w.heroi.entrada_forcada = dir
		var antes: Vector2 = w.heroi.pos
		for i in 60:
			w.avancar(PASSO)
		ok(w.limite_andavel.has_point(w.heroi.pos), "%s: o herói fica na área andável indo para %s" % [id, str(dir)])
		ok(w.heroi.pos.distance_to(antes) > 20.0, "%s: o herói anda para %s (%.0f px)" % [id, str(dir), w.heroi.pos.distance_to(antes)])
	for i in 120:
		w.avancar(PASSO)
	ok(w.cenario.n_blocos_visiveis() > 0, "%s: blocos do cenário visíveis" % id)
	remove_child(w)
	w.free()
	await get_tree().process_frame


## Marcadores do mapa (dados "marcadores", só o médio tem): cada ponto livre e alcançável a partir do santuário, os quatro tipos, a rota
## (linha reta somada, ~1 min 30 a 100 px/s) e, no mundo, baús e mini-chefe nascem uma vez ao chegar perto e o atalho e o portão não nascem nada.
func _marcadores(id: String) -> void:
	var d: Dictionary = Dados.json(str(Mapas.buscar(id).dados))
	var marcas: Array = d.get("marcadores", [])
	if marcas.is_empty():
		return
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	var g: Dictionary = Passagens.grade(w.limite_andavel, Passagens.RAIO_HEROI)
	var vis: PackedByteArray = Passagens.alcancaveis(g, w.heroi.pos)
	var tipos := {}
	var rota: Vector2 = w.heroi.pos
	var total := 0.0
	var chefes_ok := true
	for m in marcas:
		var p := Vector2(float(m.pos[0]), float(m.pos[1]))
		var tipo := str(m.tipo)
		tipos[tipo] = int(tipos.get(tipo, 0)) + 1
		ok(Colisao.livre(p, Passagens.RAIO_HEROI), "%s: marcador %s em %s está livre" % [id, tipo, str(p)])
		var c := Passagens.celula_de(g, p)
		ok(vis[c.y * int(g.w) + c.x] == 1, "%s: marcador %s em %s é alcançável do santuário" % [id, tipo, str(p)])
		total += rota.distance_to(p)
		rota = p
		if tipo == "chefe":
			var marca := str(m.get("marca", ""))
			chefes_ok = chefes_ok and Dados.json("v2_cartas").chefes.marcas.any(func(mk): return str(mk.id) == marca)
	ok(chefes_ok, "%s: a marca de chefe do marcador existe em v2_cartas.json" % id)
	ok(tipos.get("bau", 0) >= 3 and tipos.get("bau", 0) <= 4, "%s: 3 ou 4 baús com relíquia (%d)" % [id, tipos.get("bau", 0)])
	ok(tipos.get("chefe", 0) == 1 and tipos.get("atalho", 0) == 1 and tipos.get("portao", 0) == 1, "%s: 1 mini-chefe, 1 atalho e 1 portão" % id)
	ok(marcas.size() <= 30, "%s: marcadores na rota (%d)" % [id, marcas.size()])
	ok(total >= 6000.0 and total <= 9000.0, "%s: rota de ~1 min 30 (%.0f px em linha reta, a 100 px/s)" % [id, total])
	# no mundo: o baú cai quando o herói chega perto, uma vez; o mini-chefe nasce no ponto e não nasce de novo enquanto vive
	var caidos := 0
	for m in marcas:
		var p := Vector2(float(m.pos[0]), float(m.pos[1]))
		if m.tipo == "bau":
			var antes: int = w.combate.baus.soltos
			w.heroi.definir_pos(p)
			w.avancar(PASSO)
			w.avancar(PASSO)
			ok(w.combate.baus.soltos == antes + 1, "%s: o baú em %s cai uma vez ao chegar perto" % [id, str(p)])
			caidos += 1
	ok(w.combate.baus.soltos == caidos, "%s: %d baús caíram, um por marcador" % [id, caidos])
	_mecanicas_a(w, marcas)
	_mecanicas_b(w, marcas)
	_mecanicas_c(w, marcas)
	_mecanicas_d(w, marcas)
	remove_child(w)
	w.free()


## Lote A: a chave da ruína abre o baú trancado (sem ela, nada cai) e 4 fragmentos montam a relíquia, que faz cair um baú.
func _mecanicas_a(w, marcas: Array) -> void:
	var trancado := _primeiro(marcas, "bau_trancado")
	var chave := _primeiro(marcas, "chave")
	var frags: Array = marcas.filter(func(m): return m.tipo == "fragmento")
	ok(not trancado.is_empty() and not chave.is_empty(), "lote A: há baú trancado e chave no mapa médio")
	ok(frags.size() == 4, "lote A: são 4 fragmentos (%d)" % frags.size())
	if trancado.is_empty() or chave.is_empty():
		return
	var antes: int = w.combate.baus.soltos
	_ir(w, trancado.pos)
	ok(w.combate.baus.soltos == antes and not w._tem_chave, "lote A: sem a chave o baú trancado não cai")
	_ir(w, chave.pos)
	ok(w._tem_chave, "lote A: a chave da ruína é achada")
	_ir(w, trancado.pos)
	ok(w.combate.baus.soltos == antes + 1, "lote A: com a chave o baú trancado cai")
	for f in frags:
		_ir(w, f.pos)
	ok(w._fragmentos == 4, "lote A: os 4 fragmentos contam (%d)" % w._fragmentos)
	ok(w.combate.baus.soltos == antes + 2, "lote A: a relíquia montada faz cair um baú")


func _primeiro(marcas: Array, tipo: String) -> Dictionary:
	for m in marcas:
		if m.tipo == tipo:
			return m
	return {}


func _ir(w, p) -> void:
	var v: Vector2 = p if p is Vector2 else Vector2(float(p[0]), float(p[1]))
	w.heroi.definir_pos(v)
	w.avancar(PASSO)
	w.avancar(PASSO)


## Lote B: duas alavancas abrem o atalho; três pilares na ordem da placa liberam o mini-chefe (fora de ordem, os pilares se apagam);
## o mini-chefe nasce uma vez ao chegar perto, depois dos pilares.
func _mecanicas_b(w, marcas: Array) -> void:
	var al: Array = marcas.filter(func(m): return m.tipo == "alavanca")
	var pil: Array = marcas.filter(func(m): return m.tipo == "pilar")
	pil.sort_custom(func(a, b): return a.ordem < b.ordem)
	var chefe := _primeiro(marcas, "chefe")
	ok(al.size() == 2 and pil.size() == 3 and not chefe.is_empty(), "lote B: 2 alavancas, 3 pilares e o mini-chefe no mapa médio")
	if al.size() != 2 or pil.size() != 3 or chefe.is_empty():
		return
	_ir(w, al[0].pos)
	ok(w._alavancas == 1 and not w._atalho_aberto, "lote B: uma alavanca não abre o atalho")
	_ir(w, al[1].pos)
	ok(w._atalho_aberto, "lote B: as duas alavancas abrem o atalho")
	_ir(w, chefe.pos)
	ok(w.combate.chefes.atual == null, "lote B: o mini-chefe não nasce antes dos pilares")
	_ir(w, pil[1].pos)
	ok(w._pilares_prox == 0 and not w._pilares_ok, "lote B: pilar fora de ordem apaga os pilares")
	_ir(w, pil[0].pos)
	_ir(w, pil[1].pos)
	_ir(w, pil[2].pos)
	ok(w._pilares_ok, "lote B: os três pilares na ordem acendem")
	_ir(w, chefe.pos)
	var nasceu = w.combate.chefes.atual
	ok(nasceu != null and str(w.combate.chefes.marca.id) == str(chefe.marca), "lote B: o mini-chefe nasce depois dos pilares")
	w.avancar(PASSO)
	ok(w.combate.chefes.atual == nasceu, "lote B: o mini-chefe não nasce de novo enquanto vive")


## Lote C: a defesa de ponto cai a relíquia depois do tempo dentro do raio (e solta monstros em volta); cada placa diz o seu texto ao entrar.
func _mecanicas_c(w, marcas: Array) -> void:
	var defesa := _primeiro(marcas, "defesa")
	var placas: Array = marcas.filter(func(m): return m.tipo == "placa")
	ok(not defesa.is_empty() and placas.size() == 3, "lote C: 1 defesa e 3 placas no mapa médio (%d)" % placas.size())
	var textos: Array = []  # todo anúncio da partida (o mercador, perto de uma placa, pode anunciar depois dela)
	w.anuncio.connect(func(t, _c): textos.append(t))
	for pl in placas:
		_ir(w, pl.pos)
		ok(textos.has(str(pl.texto)), "lote C: a placa em %s diz o seu texto" % str(pl.pos))
	if defesa.is_empty():
		return
	var antes: int = w.combate.baus.soltos
	var monstros_antes: int = w.monstros.size()
	_ir(w, defesa.pos)
	for i in int(ceil(float(defesa.tempo) / PASSO)) + 60:
		w.avancar(PASSO)
	ok(w.combate.baus.soltos == antes + 1, "lote C: a defesa cumprida faz cair a relíquia")
	ok(w.monstros.size() > monstros_antes, "lote C: a defesa solta monstros em volta")


## Lote D: o mercador troca almas da partida por uma carta (sem almas, não troca; a troca tira o custo do total); os espinhos machucam
## fora do caminho de pedra e não sobre ele.
func _mecanicas_d(w, marcas: Array) -> void:
	var merc := _primeiro(marcas, "mercador")
	var esp := _primeiro(marcas, "espinhos")
	ok(not merc.is_empty() and not esp.is_empty(), "lote D: há mercador e espinhos no mapa médio")
	if merc.is_empty() or esp.is_empty():
		return
	var antes: int = w.combate.baus.soltos
	w.xp_coletado = 50.0  # 5 almas: menos que o custo
	_ir(w, merc.pos)
	ok(w.combate.baus.soltos == antes and w._almas_gastas == 0, "lote D: sem almas o mercador não troca")
	w.xp_coletado = 300.0  # 30 almas (o XP de tanto sobe de nível: a escolha pausa o mundo, então a tela fecha aqui)
	w.combate.telas.esconder()
	w.combate.pausado = false
	_ir(w, Vector2(240, 1320))
	_ir(w, merc.pos)
	ok(w._almas_gastas == int(merc.custo) and w.combate.baus.soltos == antes + 1, "lote D: com almas o mercador troca e uma carta cai")
	ok(w.almas_partida == 30 - int(merc.custo), "lote D: as almas gastas saem do total (%d)" % w.almas_partida)
	w.monstros.clear()
	w.heroi.imortal = false
	var vida0: float = w.heroi.vida
	w.heroi.definir_pos(Vector2(float(esp.pos[0]), 705.0))  # na zona, fora do caminho de pedra
	for i in 90:
		w.avancar(PASSO)
	ok(w.heroi.vida < vida0, "lote D: fora do caminho de pedra os espinhos machucam")
	w.heroi.vida = vida0
	w.heroi.definir_pos(Vector2(float(esp.pos[0]), 760.0))  # no caminho de pedra
	for i in 90:
		w.avancar(PASSO)
	ok(w.heroi.vida == vida0, "lote D: no caminho de pedra os espinhos não machucam")
	w.heroi.imortal = true


## A cidade tem ruas livres: o herói sai do cruzamento central e anda 300 px pelo leste sem travar (carros e postes ficam no meio-fio).
func _rua_da_cidade(w) -> void:
	var ini: Vector2 = w.heroi.pos
	w.heroi.entrada_forcada = Vector2(1, 0)
	for i in 600:  # até 10 s; para ao chegar
		w.avancar(PASSO)
		if w.heroi.pos.x >= ini.x + 300.0:
			break
	w.heroi.entrada_forcada = Vector2.ZERO
	ok(
		w.heroi.pos.x >= ini.x + 300.0 and absf(w.heroi.pos.y - ini.y) < 80.0,
		"cidade: o herói anda 300 px pela rua do leste sem travar (%s -> %s)" % [str(ini), str(w.heroi.pos)]
	)


## Com --fotos=PASTA grava a tela da partida (só com janela, como as do santuário).
func _foto_mundo(id: String, nome: String) -> void:
	var pasta := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos="):
			pasta = arg.substr(8)
	if pasta == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("mundo_%s_%s.png" % [id, nome]))


func _santuario() -> void:
	Mapas.escolher("floresta")
	var a = Altar.instantiate()
	add_child(a)
	await get_tree().process_frame
	ok(a._mapa.get_rect().end.x <= a._entrar.position.x, "santuário: floresta não sobrepõe ENTRAR")
	ok(a._mapa.text.contains("FLORESTA") and a._entrar.text == "ENTRAR NA FLORESTA", "santuário: começa na floresta (%s / %s)" % [a._mapa.text, a._entrar.text])
	a._mapa.pressed.emit()
	ok(Mapas.escolhido() == "laboratorio", "santuário: o botão passa para o laboratório e grava")
	ok(
		a._mapa.text.contains("LABORATÓRIO") and a._entrar.text == "ENTRAR NO LABORATÓRIO",
		"santuário: o texto acompanha (%s / %s)" % [a._mapa.text, a._entrar.text]
	)
	await get_tree().process_frame
	ok(a._mapa.get_rect().end.x <= a._entrar.position.x, "santuário: laboratório não sobrepõe ENTRAR")
	await _foto(a, "laboratorio")
	for id in ["cidade", "medio", "floresta"]:
		a._mapa.pressed.emit()
		var m: Dictionary = Mapas.buscar(id)
		ok(Mapas.escolhido() == id and a._mapa.text.contains(m.nome) and a._entrar.text == m.entrar, "santuário: seleção e rótulo de %s" % id)
		await get_tree().process_frame
		ok(
			a._mapa.get_rect().end.x <= a._entrar.position.x,
			"santuário: seletor %s não sobrepõe ENTRAR (fim %.1f / início %.1f)" % [id, a._mapa.get_rect().end.x, a._entrar.position.x]
		)
		await _foto(a, id)
	ok(Mapas.escolhido() == "floresta", "santuário: dá a volta à lista")
	remove_child(a)
	a.free()


## Com --fotos=PASTA grava o viewport (só com janela; no headless a imagem vem vazia e não grava).
func _foto(a, id: String) -> void:
	var pasta := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos="):
			pasta = arg.substr(8)
	if pasta == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("santuario_mapa_%s.png" % id))
