extends "res://testes/isolamento_v2.gd"
# Teste dos segredos escondidos dos mapas da v2 (#424): dados/v2_segredos.json, v2/segredos.gd, v2/vigia_segredos.gd, Meta.achar_segredo e o
# Códice. Usa saves TEMPORÁRIOS (meta, personagens e opções); o save real da meta não é tocado (conferência por md5).
# Confere: todo mapa da lista tem pelo menos um segredo; cada segredo está fora de colisão, na área andável, alcançável do nascimento e longe
# dele (achado explorando); o gatilho certo dispara (encostar, ficar parado `tempo` s, golpear no raio) e os errados não (passar andando,
# golpear longe, ficar parado fora do raio); dispara UMA vez por partida (sem repetir almas nem baú, mesmo saindo e voltando); grava a
# conquista no save e credita as almas só na primeira vez do personagem (uma partida nova dispara de novo o anúncio e o baú, sem almas);
# o Códice esconde o nome e a lore ("???" e a dica) até achar e depois mostra o fragmento; achar um segredo abre o Códice.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_segredos.tscn  (imprime "v2_segredos falhas=0")
# Foto (precisa de janela): ... res://testes/v2_segredos.tscn -- --fotos=PASTA  grava segredo_<mapa>.png no instante em que o segredo é achado.

const Meta := preload("res://v2/meta.gd")
const Segredos := preload("res://v2/segredos.gd")
const Conquistas := preload("res://v2/conquistas.gd")
const Mapas := preload("res://v2/mapas.gd")
const Colisao := preload("res://v2/colisao.gd")
const Passagens := preload("res://v2/passagens.gd")
const Progressao := preload("res://v2/progressao.gd")
const Icones := preload("res://v2/icones_santuario.gd")
const Personagens := preload("res://v2/personagens.gd")
const Salao := preload("res://v2/salao.tscn")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
const PASTA := "user://testes_v2/v2_segredos/"
const SAVE_TESTE := PASTA + "teste_v2_segredos_meta.cfg"
const OPCOES_TESTE := PASTA + "teste_v2_segredos_opcoes.cfg"
const SAVE_REAL := PASTA + "v2_progresso.cfg"
const GATILHOS := ["encostar", "parado", "golpe"]

var falhas := 0
var pasta_fotos := ""


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var md5_real := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos="):
			pasta_fotos = arg.substr(8)
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	Personagens.caminho_base = PASTA + "teste_v2_segredos_p"
	Personagens.caminho_indice = PASTA + "teste_v2_segredos_personagens.cfg"
	Personagens.caminho_antigo = PASTA + "teste_v2_segredos_antigo.cfg"
	_limpar()
	_dados()
	for id in Mapas.ids():
		await _mapa(id)
	_nova_partida_e_estado()
	await _codice()
	_limpar()
	var depois := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	ok(md5_real == depois, "o save real da meta nao foi tocado")
	print("v2_segredos falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _limpar() -> void:
	get_tree().paused = false
	for f in DirAccess.get_files_at(PASTA):
		if f.begins_with("teste_v2_segredos_"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PASTA + f))


## Os dados: cada mapa tem segredo, ids únicos, gatilho conhecido, lore curta (cabe na faixa de anúncio), prêmio e ícone próprio.
func _dados() -> void:
	var todos := Segredos.lista()
	var ids := {}
	for s in todos:
		ok(not ids.has(str(s.id)), "id de segredo unico: " + str(s.id))
		ids[str(s.id)] = true
		ok(Mapas.ids().has(str(s.local)), "%s: o mapa %s existe" % [s.id, s.local])
		ok(GATILHOS.has(str(s.gatilho)), "%s: gatilho conhecido (%s)" % [s.id, s.gatilho])
		ok(s.pos is Array and s.pos.size() == 2 and float(s.raio) > 0.0, "%s: posicao e raio" % s.id)
		ok(str(s.gatilho) != "parado" or float(s.get("tempo", 0.0)) > 0.0, "%s: parado tem tempo" % s.id)
		ok(
			str(s.nome) != "" and str(s.dica) != "" and s.lore is Array and s.lore.size() >= 1 and s.lore.size() <= 5,
			"%s: nome, dica e 1 a 5 frases de lore" % s.id
		)
		for frase in s.lore:
			ok(str(frase).length() <= 56, "%s: a frase cabe na linha do Codice (%d): %s" % [s.id, str(frase).length(), frase])
		ok(str(s.dica).length() <= 56, "%s: a dica cabe numa linha do Codice" % s.id)
		ok(str(s.nome).length() <= 26, "%s: o nome cabe na faixa de anuncio (~28 letras, o resto e cortado)" % s.id)
		ok(int(s.get("bau", 0)) == 0 or s.get("bau_pos", []).size() == 2, "%s: baú com posicao" % s.id)
		var premio: Dictionary = s.recompensa  # almas, ou tipo "nenhuma" no fragmento só de lore (o segundo de cada mapa: sem almas e sem linha de prêmio)
		var so_lore := str(premio.get("tipo", "")) == "nenhuma"
		ok(so_lore or (str(premio.get("tipo", "")) == "almas" and int(premio.get("n", 0)) > 0), "%s: recompensa em almas ou nenhuma" % s.id)
		ok(Icones.textura(str(s.icone)) != null and Icones.textura(str(s.icone)) != Icones.textura("generico"), "%s: icone proprio" % s.id)
	for id in Mapas.ids():
		ok(Segredos.lista(id).size() >= 2, "o mapa %s tem pelo menos 2 fragmentos" % id)
		ok(Segredos.lista(id).any(func(s): return str(s.recompensa.get("tipo", "")) == "nenhuma"), "o mapa %s tem um fragmento só de lore (sem almas)" % id)
	ok(Meta.conquistas().size() >= Segredos.conquistas().size() + 22, "os segredos entram no catalogo de conquistas")
	for c in Segredos.conquistas():
		ok(not c.has("mapa"), "segredo nunca tem 'mapa' (seria vitoria de mapa): " + str(c.id))


func _novo_mundo(id: String):
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	return w


func _sem_monstros(w) -> void:
	for mo in w.monstros:  # ninguém empurra o herói nem o interrompe: o teste confere o gatilho, não a luta
		mo.pos = Vector2(-4000.0, -4000.0)


func _passos(w, n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Cada segredo do mapa: posição válida, gatilhos certo e errados, uma vez só, gravação, depois uma partida nova.
func _mapa(id: String) -> void:
	for s in Segredos.lista(id):
		var w = _novo_mundo(id)
		var p := Vector2(float(s.pos[0]), float(s.pos[1]))
		var raio := float(s.raio)
		var rotulo := "%s/%s" % [id, s.id]
		ok(Colisao.livre(p, Passagens.RAIO_HEROI), "%s: o ponto %s esta fora de colisao" % [rotulo, str(p)])
		ok(w.limite_andavel.has_point(p), "%s: o ponto esta na area andavel" % rotulo)
		var g: Dictionary = Passagens.grade(w.limite_andavel, Passagens.RAIO_HEROI)
		var vis: PackedByteArray = Passagens.alcancaveis(g, w.heroi.pos)
		var c := Passagens.celula_de(g, p)
		ok(vis[c.y * int(g.w) + c.x] == 1, "%s: o ponto e alcancavel do nascimento" % rotulo)
		ok(p.distance_to(w.heroi.pos) >= 300.0, "%s: longe do nascimento, so se acha explorando (%.0f px)" % [rotulo, p.distance_to(w.heroi.pos)])
		if int(s.get("bau", 0)) > 0:
			var bp := Vector2(float(s.bau_pos[0]), float(s.bau_pos[1]))
			var cb := Passagens.celula_de(g, bp)
			ok(Colisao.livre(bp, Passagens.RAIO_HEROI) and vis[cb.y * int(g.w) + cb.x] == 1, "%s: o baú em %s esta livre e alcancavel" % [rotulo, str(bp)])
			var d := p - bp  # a conta de pegar do baú (v2/bau.gd): elipse de alcance `bau.alcance`, com o chão achatado
			var alcance := float(Dados.json("v2_cartas").bau.alcance)
			ok(sqrt(d.x * d.x + (d.y / 0.62) * (d.y / 0.62)) > alcance * 1.5, "%s: o baú cai fora do alcance de pegar, o herói anda até ele" % rotulo)
		ok(w.segredos.itens.size() == Segredos.lista(id).size(), "%s: o mundo montou os segredos do mapa" % rotulo)
		_sem_monstros(w)
		var linha := _linha(str(s.id))
		ok(
			not linha.feita and linha.nome == "???" and linha.fazer == str(s.dica) and linha.lore.is_empty() and linha.progresso == "0/1 segredo",
			"%s: antes de achar o Codice so mostra '???' e a dica" % rotulo
		)
		var saldo0 := Meta.saldo()
		await _gatilhos_errados(w, s, p, raio, rotulo)
		var baus0: int = w.combate.baus.soltos  # depois dos gatilhos errados: os baús de marcador do mapa (Ruínas) já caíram ao herói chegar perto
		ok(w.segredos.achados == 0 and Meta.saldo() == saldo0, "%s: os gatilhos errados nao revelam nada" % rotulo)
		_disparar(w, s, p)
		ok(w.segredos.achados == 1, "%s: o gatilho %s revela o segredo (%d)" % [rotulo, s.gatilho, w.segredos.achados])
		ok(Meta.saldo() == saldo0 + int(s.recompensa.get("n", 0)), "%s: credita as almas na primeira vez (%d -> %d)" % [rotulo, saldo0, Meta.saldo()])
		var esperado_baus := baus0 + (1 if int(s.get("bau", 0)) > 0 else 0)
		ok(w.combate.baus.soltos == esperado_baus, "%s: baus caidos %d (esperado %d)" % [rotulo, w.combate.baus.soltos, esperado_baus])
		ok(bool(Meta.estado().conquistas.get(Segredos.id_conquista(str(s.id)), false)), "%s: a conquista do segredo fica gravada" % rotulo)
		ok(Meta.segredos_achados().has(str(s.id)), "%s: segredos_achados lista o id" % rotulo)
		if str(s.recompensa.get("tipo", "")) == "nenhuma":  # só lore: o título curto e nada de prêmio
			ok(
				w.combate.anuncios >= 2 and str(w.combate.ultimo_anuncio) == str(s.nome).to_upper(),
				"%s: anuncia o achado e só o título, sem prêmio (%s)" % [rotulo, w.combate.ultimo_anuncio]
			)
		else:
			ok(
				w.combate.anuncios >= 3 and str(w.combate.ultimo_anuncio).begins_with("NO CÓDICE"),
				"%s: anuncia o achado, o nome e o prêmio (%s)" % [rotulo, w.combate.ultimo_anuncio]
			)
		if pasta_fotos != "" and DisplayServer.get_name() != "headless":
			await _foto(w, id)
		# uma vez só: ficar, sair e voltar não repete almas, baú nem anúncio
		_passos(w, 120)
		w.heroi.definir_pos(p + Vector2(raio + 200.0, 0.0))
		_passos(w, 4)
		var anuncios: int = w.combate.anuncios  # depois de sair: avisos dos marcadores do mapa (placa, mirante) não contam, só o do segredo
		_disparar(w, s, p)
		_passos(w, 200)
		ok(w.segredos.achados == 1, "%s: dispara uma vez por partida (%d)" % [rotulo, w.segredos.achados])
		ok(Meta.saldo() == saldo0 + int(s.recompensa.get("n", 0)), "%s: as almas nao se repetem" % rotulo)
		ok(
			w.combate.baus.soltos == esperado_baus and w.combate.anuncios == anuncios,
			"%s: baú e anuncio nao se repetem (baus %d/%d, anuncios %d/%d)" % [rotulo, w.combate.baus.soltos, esperado_baus, w.combate.anuncios, anuncios]
		)
		var linha2 := _linha(str(s.id))
		ok(
			linha2.feita and linha2.nome == str(s.nome) and linha2.lore == s.lore and linha2.selo == "ACHADO",
			"%s: depois de achar o Codice mostra nome e lore" % rotulo
		)
		ok(
			linha2.progresso == "1/1 segredo" and linha2.fazer.begins_with("Segredo: "),
			"%s: progresso e subtitulo do segredo achado (%s)" % [rotulo, linha2.fazer]
		)
		remove_child(w)
		w.free()
		# partida nova no mesmo save: o segredo dispara de novo (anuncio e baú), mas sem almas nem conquista nova
		var w2 = _novo_mundo(id)
		_sem_monstros(w2)
		w2.heroi.definir_pos(p + Vector2(raio + 150.0, 0.0))
		_passos(w2, 2)
		var baus1: int = w2.combate.baus.soltos
		ok(w2.segredos.achados == 0, "%s: a partida nova comeca sem segredo achado" % rotulo)
		_disparar(w2, s, p)
		ok(w2.segredos.achados == 1, "%s: a partida nova dispara de novo" % rotulo)
		ok(Meta.saldo() == saldo0 + int(s.recompensa.get("n", 0)), "%s: partida nova nao credita almas de novo" % rotulo)
		ok(w2.combate.baus.soltos == baus1 + (1 if int(s.get("bau", 0)) > 0 else 0), "%s: partida nova solta o baú de novo" % rotulo)
		ok(str(w2.combate.ultimo_anuncio) == str(s.nome).to_upper(), "%s: partida nova so anuncia o nome (%s)" % [rotulo, w2.combate.ultimo_anuncio])
		# "Jogar de novo": montar outra vez volta a vigiar
		w2.segredos.montar(w2)
		ok(w2.segredos.achados == 0 and w2.segredos.itens.all(func(it): return not it.feito), "%s: montar de novo (Jogar de novo) rearma o segredo" % rotulo)
		remove_child(w2)
		w2.free()
		await get_tree().process_frame


func _linha(id: String) -> Dictionary:
	for l in Conquistas.linhas():
		if str(l.id) == Segredos.id_conquista(id):
			return l
	return {}


## Faz o que o gatilho pede, no ponto do segredo.
func _disparar(w, s: Dictionary, p: Vector2) -> void:
	w.heroi.definir_pos(p)
	_passos(w, 2)
	match str(s.gatilho):
		"parado":
			_passos(w, ceili(float(s.tempo) / PASSO) + 20)
		"golpe":
			var golpes: int = w.heroi.golpes
			w.heroi.atacar()
			for i in 90:
				if w.heroi.golpes > golpes:
					break
				w.avancar(PASSO)
			ok(w.heroi.golpes > golpes, "o herói golpeou de verdade (%d)" % w.heroi.golpes)
			_passos(w, 4)


## O que NÃO pode revelar: ficar longe, passar andando, golpear fora do raio e (no golpe) ficar encostado sem atacar.
func _gatilhos_errados(w, s: Dictionary, p: Vector2, raio: float, rotulo: String) -> void:
	var longe := p + Vector2(raio + 150.0, 0.0)
	w.heroi.definir_pos(longe)
	_passos(w, ceili((float(s.get("tempo", 3.0)) + 1.0) / PASSO))
	ok(w.segredos.achados == 0, "%s: ficar parado longe do segredo nao revela" % rotulo)
	match str(s.gatilho):
		"parado":
			for i in 240:  # 4 s indo e voltando dentro do raio: 20 px a cada passo, bem acima da velocidade de parado
				w.heroi.definir_pos(p + Vector2(20.0 * (i % 2), 0.0))
				w.avancar(PASSO)
			ok(w.segredos.achados == 0, "%s: passar andando por dentro do raio nao revela" % rotulo)
			w.heroi.definir_pos(p)  # parado, mas menos que o tempo: ainda não
			_passos(w, ceili((float(s.tempo) - 1.0) / PASSO))
			ok(w.segredos.achados == 0, "%s: ficar parado menos que o tempo nao revela" % rotulo)
			w.heroi.definir_pos(longe)
			_passos(w, 2)
		"golpe":
			w.heroi.definir_pos(p)
			_passos(w, 120)
			ok(w.segredos.achados == 0, "%s: encostar sem golpear nao revela" % rotulo)
			w.heroi.definir_pos(longe)
			var golpes: int = w.heroi.golpes
			w.heroi.atacar()
			for i in 90:
				if w.heroi.golpes > golpes:
					break
				w.avancar(PASSO)
			_passos(w, 4)
			ok(w.heroi.golpes > golpes and w.segredos.achados == 0, "%s: golpear fora do raio nao revela" % rotulo)
			w.heroi.definir_pos(longe + Vector2(300.0, 0.0))
			_passos(w, 2)
		"encostar":
			w.heroi.definir_pos(p + Vector2(raio + 12.0, 0.0))  # a um passo de fora do raio
			_passos(w, 4)
			ok(w.segredos.achados == 0, "%s: ficar a um passo de fora do raio nao revela" % rotulo)
	await get_tree().process_frame


## Com --fotos=PASTA grava a tela no instante em que o segredo foi achado (anúncio, onda e faíscas já na tela).
func _foto(w, id: String) -> void:
	for i in 24:
		w.avancar(PASSO)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta_fotos.path_join("segredo_%s.png" % id))


## O catálogo e o estado: segredo achado abre o Códice (1 conquista), save sem a seção continua válido.
func _nova_partida_e_estado() -> void:
	var cf := ConfigFile.new()
	cf.set_value("moeda", "almas", 7)
	cf.save(SAVE_TESTE)  # save de antes dos segredos: nenhum achado, nada quebra
	ok(Meta.segredos_achados().is_empty(), "save antigo: nenhum segredo achado")
	ok(Meta.estado().conquistas.size() == Meta.conquistas().size(), "save antigo: o estado cobre o catalogo inteiro")
	ok(Progressao.aviso("estrutura", "codice") != "", "sem conquistas o Codice segue trancado")
	var s: Dictionary = Segredos.lista()[0]
	ok(not Meta.achar_segredo("nao_existe"), "id desconhecido nao marca nada")
	ok(Meta.achar_segredo(str(s.id)) and Meta.saldo() == 7 + int(s.recompensa.get("n", 0)), "achar grava e credita")
	ok(not Meta.achar_segredo(str(s.id)) and Meta.saldo() == 7 + int(s.recompensa.get("n", 0)), "achar de novo nao repete")
	ok(Progressao.aviso("estrutura", "codice") == "", "achar um segredo abre o Codice")
	ok(not Meta.mapas_vencidos().has(str(s.local)), "achar um segredo nao conta como vencer o mapa")


## O Códice mostra '???' e a dica dos segredos que faltam, e o nome com o fragmento de lore dos achados.
func _codice() -> void:
	Personagens.ativar(Personagens.criar("Teste"))
	var achado: Dictionary = Segredos.lista("cidade")[0]
	var escondido: Dictionary = Segredos.lista("floresta")[0]
	var achado2: Dictionary = Segredos.lista("cidade")[1]  # o segundo fragmento da cidade: só lore, sem almas
	ok(Meta.achar_segredo(str(achado.id)), "o personagem de teste acha o segredo da cidade")
	var saldo := Meta.saldo()
	ok(Meta.achar_segredo(str(achado2.id)) and Meta.saldo() == saldo, "o segundo fragmento da cidade grava e nao credita almas")
	var s = Salao.instantiate()
	add_child(s)
	await get_tree().process_frame
	s.abrir_estrutura("codice")
	await get_tree().process_frame
	ok(s._p_codice and s._p_lista.get_child_count() == Meta.conquistas().size(), "o Codice tem uma linha por conquista, segredos incluidos")
	var textos := []
	var alturas := {}
	var premios_do_achado2 := 0  # linhas "Prêmio:" na linha do fragmento só de lore (tem que ser 0)
	for i in s._p_itens.size():
		var b: Button = s._p_lista.get_child(i)
		alturas[str(s._p_itens[i].id)] = b.custom_minimum_size.y
		for f in b.get_children():
			if f is Label:
				textos.append(str(f.text))
				if str(s._p_itens[i].id) == Segredos.id_conquista(str(achado2.id)) and str(f.text).begins_with("Prêmio:"):
					premios_do_achado2 += 1
	for esperado in [
		str(achado.nome), "ACHADO", "1/1 segredo", "Prêmio: +%d almas" % int(achado.recompensa.n), "???", str(escondido.dica), "0/1 segredo", str(achado2.nome)
	]:
		ok(textos.has(esperado), "o Codice mostra '%s'" % esperado)
	for fragmento in [achado, achado2]:  # as frases dos dois fragmentos, uma por linha
		for frase in fragmento.lore:
			ok(textos.has(str(frase)), "o Codice mostra a frase do fragmento %s: %s" % [fragmento.id, frase])
	for oculto in Segredos.lista("floresta"):  # os dois fragmentos da floresta seguem escondidos
		ok(not textos.has(str(oculto.nome)) and not textos.has(str(oculto.lore[0])), "o Codice nao entrega o fragmento que falta (%s)" % oculto.id)
	ok(premios_do_achado2 == 0, "o fragmento so de lore nao mostra linha de premio")
	ok(float(alturas[Segredos.id_conquista(str(achado.id))]) > float(alturas[Segredos.id_conquista(str(escondido.id))]), "a linha com lore e mais alta")
	if pasta_fotos != "" and DisplayServer.get_name() != "headless":
		s._p_rolagem.scroll_vertical = 1000000  # os segredos são os últimos da lista
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta_fotos.path_join("codice_segredos.png"))
	s._fechar_painel()
	s.queue_free()
	await get_tree().process_frame
