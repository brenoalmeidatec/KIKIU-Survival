extends Node
## Roda as cenas: lê a lista de "passos" de uma cena e executa um por um.
## O formato de cada passo está explicado no LEIA-ME (seção CENAS).

const Minijogo := preload("res://scripts/minijogo.gd")

var mundo: Node      # mundo.gd
var _parar := false


func rodar_cena(id: String, npc := "") -> void:
	var def: Dictionary = mundo.def_cena(id)
	_parar = false
	await rodar(def.passos, npc)
	mundo.contar_vista(id)


func rodar(passos: Array, npc := "") -> void:
	var i := 0
	while i < passos.size() and not _parar:
		var p = passos[i]
		if not p is Dictionary:
			i += 1
			continue
		# falas seguidas (e uma escolha logo depois) viram um bloco de diálogo só
		if p.has("quem") or p.has("escolha"):
			var falas := []
			while i < passos.size() and passos[i] is Dictionary and passos[i].has("quem") and not passos[i].has("escolha"):
				falas.append(passos[i])
				i += 1
			var escolha: Dictionary = {}
			if i < passos.size() and passos[i] is Dictionary and passos[i].has("escolha"):
				escolha = passos[i]
				i += 1
			await _dialogo(falas, escolha, npc)
			continue
		await _passo(p, npc)
		i += 1


func _parceiro(falas: Array, escolha: Dictionary, npc: String) -> String:
	if npc != "":
		return npc
	var jogador: String = mundo.jogador_id()
	for f in falas + [escolha]:
		var q: String = f.get("quem", "*")
		if q != "*" and q != "" and q != jogador:
			return q
	return ""


func _dialogo(falas: Array, escolha: Dictionary, npc: String) -> void:
	var d: CanvasLayer = mundo.dialogo()
	var resultado := -1
	if Rede.cliente() and not escolha.is_empty():
		# online: quem escolhe é o anfitrião; aqui só mostra as falas e espera a escolha dele
		if not falas.is_empty():
			d.tocar(falas, mundo.jogador_id(), _parceiro(falas, escolha, npc), {})
			await d.terminou
		mundo.avisar_rede("Esperando %s escolher..." % Dados.nome(Rede.personagem_anfitriao()), 60.0)
		resultado = int(await Rede.proxima_decisao())
		mundo.avisar_rede("", 0.0)
	else:
		d.tocar(falas, mundo.jogador_id(), _parceiro(falas, escolha, npc), escolha)
		await d.terminou
		resultado = d.resultado
		if not escolha.is_empty():
			Rede.decidir(resultado)
	if escolha.is_empty() or resultado < 0 or resultado >= escolha.get("opcoes", []).size():
		return
	var op: Dictionary = escolha.get("opcoes", [])[resultado]
	mundo.marcar(op.get("marcar", []))
	mundo.desmarcar(op.get("desmarcar", []))
	if op.has("passos"):
		await rodar(op.passos, npc)
	if op.has("cena") and not _parar:
		await rodar(mundo.def_cena(op.cena).passos, npc)


func _passo(p: Dictionary, npc: String) -> void:
	if p.has("narrar"):
		var d: CanvasLayer = mundo.dialogo()
		d.tocar([{"quem": "*", "texto": p.narrar}], mundo.jogador_id(), "", {}, true)
		await d.terminou
	elif p.has("andar"):
		var pers: Node2D = mundo.personagem(p.andar)
		if pers:
			var alvo := Vector2(p.get("x", pers.position.x), p.get("y", pers.position.y))
			if alvo.y < 0.0 or (mundo.no_palco_lateral() and alvo.y == 0.0):
				alvo.y = pers.position.y   # "!andar joao 200" (sem y) anda só pro lado
			var vel: float = p.get("velocidade", 60.0)
			if p.get("esperar", true):
				await pers.andar_ate(alvo, vel)
				mundo.guardar_posicao(pers)
				await mundo.get_tree().create_timer(0.2).timeout   # respiro antes do próximo passo
			else:
				_andar_sem_esperar(pers, alvo, vel)
	elif p.has("virar"):
		var pers: Node2D = mundo.personagem(p.virar)
		if pers:
			if p.has("para"):
				var outro: Node2D = mundo.personagem(p.para)
				if outro:
					pers.olhar_para(outro.position)
			else:
				pers.dir = p.get("dir", "baixo")
			mundo.guardar_posicao(pers)
	elif p.has("pular"):
		var pers: Node2D = mundo.personagem(p.pular)
		if pers:
			for k in int(p.get("vezes", 1)):
				await pers.pular()
	elif p.has("balao"):
		var pers: Node2D = mundo.personagem(p.balao)
		if pers:
			await pers.balao(str(p.get("icone", "!")), p.get("tempo", 1.0))
	elif p.has("tremer"):
		await mundo.tremer(float(p.tremer), p.get("forca", 4.0))
	elif p.has("flash"):
		await mundo.flash(float(p.flash), Color(p.get("cor", "white")))
	elif p.has("fade"):
		await mundo.fade(str(p.fade), p.get("tempo", 0.5))
	elif p.has("susto"):
		var pers: Node2D = mundo.personagem(p.susto)
		if pers:
			Jogo.som("whoosh")
			mundo.tremer(0.2, 2.0)
			pers.balao(str(p.get("icone", "!!")), 0.9)
			await pers.pular()
			await get_tree().create_timer(0.35).timeout
	elif p.has("impacto"):
		Jogo.som("soco")
		mundo.flash(0.15, Color.WHITE)
		await mundo.tremer(0.35, float(p.impacto))
	elif p.has("close"):
		var pers: Node2D = mundo.personagem(p.close)
		if pers:
			Jogo.som("whoosh")
			mundo.camera_seguir(pers, float(p.get("tempo", 0.25)))
			await mundo.zoom(float(p.get("zoom", 1.8)), float(p.get("tempo", 0.25)))
	elif p.has("tela"):
		await mundo.tela_normal()
	elif p.has("lateral"):
		await mundo.lateral(str(p.lateral), float(p.get("x", -1.0)))
	elif p.has("rosto"):
		var quem := str(p.rosto)
		if quem == "jogador":
			quem = mundo.jogador_id()
		if p.get("esperar", true):
			await mundo.rosto(quem, str(p.get("expr", "normal")), float(p.get("tempo", 2.0)), str(p.get("lado", "direita")))
		else:
			mundo.rosto(quem, str(p.get("expr", "normal")), float(p.get("tempo", 2.0)), str(p.get("lado", "direita")))
	elif p.has("esperar") and not p.esperar is bool:   # "esperar": false é o "&" de outros passos
		await get_tree().create_timer(float(p.esperar)).timeout
	elif p.has("marcar"):
		mundo.marcar(p.marcar)
	elif p.has("desmarcar"):
		mundo.desmarcar(p.desmarcar)
	elif p.has("aparecer"):
		mundo.aparecer(p.aparecer, p)
	elif p.has("sumir"):
		mundo.sumir(p.sumir)
	elif p.has("mapa"):
		await mundo.ir_para_mapa(p.mapa, p)
	elif p.has("minijogo"):
		var ganhou := false
		if Rede.cliente():
			# online: o anfitrião joga; os outros esperam o resultado dele
			mundo.avisar_rede("%s está jogando um minijogo..." % Dados.nome(Rede.personagem_anfitriao()), 600.0)
			ganhou = bool(await Rede.proxima_decisao())
			mundo.avisar_rede("Resultado: " + ("conseguiu!" if ganhou else "deu ruim..."), 2.0)
		else:
			var m := Minijogo.criar(str(p.minijogo), p)
			mundo.add_child(m)
			ganhou = await m.terminou
			Rede.decidir(ganhou)
		var chave: String = p.get("guardar", "ganhou_" + str(p.minijogo))
		if ganhou:
			mundo.marcar(chave)
		else:
			mundo.desmarcar(chave)
	elif p.has("se"):
		var ramo: Array = p.get("entao", []) if mundo.condicao_ok(p.se) else p.get("senao", [])
		await rodar(ramo, npc)
	elif p.has("cena"):
		await rodar(mundo.def_cena(p.cena).passos, npc)
		mundo.contar_vista(str(p.cena))
	elif p.has("enfileirar"):
		mundo.enfileirar(str(p.enfileirar))
	elif p.has("pensar") or p.has("dizer"):
		var quem: String = p.get("pensar", p.get("dizer", ""))
		var pers: Node2D = mundo.personagem(quem)
		if pers:
			var pensa := p.has("pensar")
			var t: String = p.get("texto", "")
			Jogo.registrar_fala(pers.id, ("(%s)" % t) if pensa else t)
			await pers.falar_no_mapa(t, pensa)
	elif p.has("entrar"):
		var alvo := Vector2(p.get("x", 0), p.get("y", 0))
		if p.get("esperar", true):
			await mundo.entrar(p.entrar, alvo, str(p.get("de", "porta")), p.get("velocidade", 60.0))
		else:
			mundo.entrar(p.entrar, alvo, str(p.get("de", "porta")), p.get("velocidade", 60.0))
	elif p.has("sair"):
		if p.get("esperar", true):
			await mundo.sair_de_cena(p.sair, str(p.get("por", "porta")), p.get("velocidade", 60.0))
		else:
			mundo.sair_de_cena(p.sair, str(p.get("por", "porta")), p.get("velocidade", 60.0))
	elif p.has("camera"):
		var c = p.camera
		if c is Array:
			await mundo.camera_ir(Vector2(c[0], c[1]), p.get("tempo", 1.0))
		else:
			await mundo.camera_seguir(mundo.personagem(str(c)), p.get("tempo", 0.6))
	elif p.has("zoom"):
		await mundo.zoom(float(p.zoom), p.get("tempo", 0.6))
	elif p.has("barras"):
		mundo.barras(bool(p.barras))
	elif p.has("tom"):
		await mundo.tom(str(p.tom), p.get("tempo", 1.0))
	elif p.has("anim"):
		if p.get("esperar", true):
			await mundo.animar(str(p.anim), str(p.get("nome", "normal")), str(p.get("alvo", "")))
		else:
			mundo.animar(str(p.anim), str(p.get("nome", "normal")), str(p.get("alvo", "")))
	elif p.has("briga"):
		var b: Array = p.briga
		if b.size() >= 2:
			await mundo.briga(str(b[0]), str(b[1]), float(p.get("tempo", 2.0)), str(p.get("perdedor", "")))
	elif p.has("porta"):
		await mundo.porta(str(p.porta), str(p.get("para", "")))
	elif p.has("musica"):
		mundo.trocar_musica(str(p.musica))
	elif p.has("som"):
		Jogo.som(str(p.som))
	elif p.has("video"):
		await mundo.tocar_video(str(p.video), bool(p.get("pular", true)))
	elif p.has("salvar"):
		if mundo.has_method("salvar"):
			mundo.salvar()
	elif p.has("fim_capitulo"):
		if mundo.has_method("terminar_capitulo"):
			await mundo.terminar_capitulo()
		_parar = true
	elif p.has("fim"):
		_parar = true


func _andar_sem_esperar(pers: Node2D, alvo: Vector2, vel: float) -> void:
	await pers.andar_ate(alvo, vel)
	mundo.guardar_posicao(pers)
