extends "res://testes/isolamento_v2.gd"
## O foguinho no peito do herói (v2/foguinho.gd, dados/v2_foguinho.json; ideia do Isac, aprovada pelo Alisson em 29/10). Confere: o json (cor, tamanho,
## intensidade, perfis, _ajuda); em CADA herói da v2 o nó existe, é um Sprite2D aditivo e sem luz, não tem colisão nem filho, fica no peito, segue o
## herói quando ele anda e não muda o raio do corpo; o perfil (Baixo fixo e mais fraco, Médio e Alto pulsando, "ligado": false apaga, o Personalizado
## segue Brilhos e halos); a chama apaga com a morte e volta ao reiniciar.
## Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_foguinho.tscn  (imprime "v2_foguinho falhas=0")
## Fotos (precisa de janela): ... res://testes/v2_foguinho.tscn -- --fotos=PASTA  grava, por herói, o recorte ampliado do peito (sem o foguinho, Baixo e Alto).
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Foguinho := preload("res://v2/foguinho.gd")
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


## Um mundo novo com o herói `id`.
func novo(id: String, janela := false) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = not janela
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true


func _ready() -> void:
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
	else:
		_t_dados()
		await _t_herois()
		await _t_perfis()
		await _t_morte()
	Config.g_soltar_temporario()
	Herois.forcado = ""
	if pasta == "":
		print("v2_foguinho falhas=%d" % falhas)
	get_tree().quit()


# ------------------------------------------------------------------ dados


func _t_dados() -> void:
	var d: Dictionary = Dados.json("v2_foguinho")
	ok(not d.is_empty(), "dados/v2_foguinho.json carrega")
	ok(str(d.get("_ajuda", "")).length() > 100, "o json traz a _ajuda para o Isac")
	var cor: Array = d.get("cor", [])
	ok(cor.size() == 3, "cor tem 3 canais")
	for c in cor:
		ok(float(c) >= 0.0 and float(c) <= 1.0, "canal de cor entre 0 e 1")
	ok(cor.size() == 3 and float(cor[0]) > float(cor[2]), "cor quente (mais vermelho que azul)")
	ok(int(d.get("tamanho", 0)) >= 5 and int(d.get("tamanho", 0)) <= 25, "tamanho em px razoável")
	ok(float(d.get("intensidade", -1.0)) > 0.0 and float(d.get("intensidade", 2.0)) <= 1.0, "intensidade entre 0 e 1")
	ok(float(d.get("intensidade", 2.0)) <= 0.85, "discreto: intensidade até 0,85")
	ok(d.get("peito", []).size() == 2 and float(d.peito[1]) < 0.0, "peito acima dos pés")
	for p in ["baixo", "medio", "alto"]:
		ok(d.get("perfis", {}).has(p), "perfil %s no json" % p)
	ok(not bool(d.perfis.baixo.pulsa), "Baixo não pulsa (versão barata)")
	ok(bool(d.perfis.medio.pulsa) and bool(d.perfis.alto.pulsa), "Médio e Alto pulsam")
	var tex = Foguinho._textura(Color(1, 0.5, 0.2), 13, 0.5)
	ok(tex.get_width() == 13 and tex.get_height() == 13, "a textura tem o tamanho pedido")
	var img: Image = tex.get_image()
	ok(img.get_pixel(6, 6).a > 0.9, "o miolo da chama é opaco")
	ok(img.get_pixel(0, 0).a == 0.0, "o canto é transparente")
	ok(Foguinho._textura(Color(1, 0.5, 0.2), 13, 0.5) == tex, "a textura é guardada por cor e tamanho")


# ------------------------------------------------------------------ cada herói


func _t_herois() -> void:
	Config.g_perfil_temporario("alto")
	for h in Herois.lista():
		var id := str(h.id)
		await novo(id)
		var heroi = w.heroi
		var f = heroi.foguinho
		ok(f != null and f.no != null, "%s: o foguinho existe" % id)
		if f == null or f.no == null:
			continue
		var no: Sprite2D = f.no
		ok(no.get_parent() == heroi.raiz, "%s: é filho da raiz do herói" % id)
		ok(no.visible, "%s: aceso no perfil Alto" % id)
		ok(no.get_class() == "Sprite2D", "%s: é só um Sprite2D" % id)
		ok(no.get_child_count() == 0, "%s: sem filhos" % id)
		ok(
			no.find_children("*", "CollisionObject2D", true, false).is_empty() and no.find_children("*", "CollisionShape2D", true, false).is_empty(),
			"%s: sem colisão" % id
		)
		var mat := no.material as CanvasItemMaterial
		ok(mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "%s: aditivo" % id)
		ok(mat != null and mat.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "%s: sem luz do cenário" % id)
		var esperado := Foguinho.config_do_heroi(id)
		var peito := Vector2(float(esperado.peito[0]), float(esperado.peito[1]))
		ok(no.position == peito, "%s: no peito %s (está em %s)" % [id, peito, no.position])
		ok(peito.y < 0.0 and peito.y > -float(heroi.tipo.pe), "%s: o peito fica dentro do corpo" % id)
		ok(is_equal_approx(heroi.raio, float(Herois.heroi(id).get("raio", 6.0))), "%s: o raio do corpo não mudou" % id)
		# segue o herói
		var antes: Vector2 = no.global_position - heroi.raiz.global_position
		heroi.entrada_forcada = Vector2(1, 0)
		passos(40)
		ok(heroi.pos.x > 0.0 and heroi.raiz.global_position.distance_to(no.global_position - antes) < 0.01, "%s: anda junto com o herói" % id)
		heroi.entrada_forcada = Vector2.ZERO
		# um golpe não solta a chama (só o tronco se mexe um pouco)
		heroi.atacar()
		passos(20)
		ok((no.global_position - heroi.raiz.global_position).length() < peito.length() + 6.0, "%s: no golpe a chama fica junto do tronco" % id)
	# 3 heróis, 3 cores/tamanhos que o json pode dar: um ajuste por herói vale
	var base := Foguinho.config_do_heroi("hazaki")
	var nic := Foguinho.config_do_heroi("nicao")
	ok(base.peito != nic.peito, "o json ajusta o peito do Nick (mais baixo)")


# ------------------------------------------------------------------ perfis


func _alfas(f, n: int) -> Array:
	var r := []
	for i in n:
		w.avancar(PASSO)
		r.append(f.no.modulate.a)
	return r


func _t_perfis() -> void:
	await novo("hazaki")
	var f = w.heroi.foguinho
	var inten := float(f._cfg.intensidade)
	var mult_baixo := float(f._cfg.perfis.baixo.intensidade_mult)
	# Baixo: fixo, um pouco mais fraco, nenhuma conta por quadro
	Config.g_perfil_temporario("baixo")
	ok(f.no.visible and not f._pulsa, "Baixo: aceso e parado")
	var a_baixo := _alfas(f, 90)
	ok(a_baixo.min() == a_baixo.max(), "Baixo: o brilho não muda quadro a quadro")
	ok(is_equal_approx(a_baixo[0], inten * mult_baixo), "Baixo: intensidade x multiplicador (%.3f)" % a_baixo[0])
	ok(a_baixo[0] < inten, "Baixo é mais fraco que o normal")
	# Médio e Alto: pulsam
	for p in ["medio", "alto"]:
		Config.g_perfil_temporario(p)
		ok(f.no.visible and f._pulsa, "%s: aceso e pulsando" % p)
		var a := _alfas(f, 90)  # 1,5 s: mais de um pulso inteiro a 0,8 Hz
		ok(a.max() - a.min() > 0.05, "%s: o brilho pulsa (de %.2f a %.2f)" % [p, a.min(), a.max()])
		ok(a.max() <= 1.0 and a.min() > 0.0, "%s: o pulso nunca apaga nem estoura" % p)
		ok(a.max() <= inten * (1.0 + float(f._cfg.pulso_amp)) + 0.001, "%s: o pulso respeita a amplitude do json" % p)
	# "ligado": false no json apaga
	var perfis_antes: Dictionary = f._cfg.perfis.duplicate(true)
	f._cfg.perfis["baixo"] = {"ligado": false}
	Config.g_perfil_temporario("baixo")
	ok(not f.no.visible, "ligado=false apaga o foguinho no perfil")
	ok(f.no.find_children("*", "", true, false).is_empty(), "apagado não cria nada")
	f._cfg.perfis = perfis_antes
	Config.g_perfil_temporario("baixo")
	ok(f.no.visible, "voltou a acender")
	# o perfil muda no meio da partida e o foguinho acompanha (sinal graficos_mudou)
	Config.g_perfil_temporario("alto")
	ok(f._pulsa, "trocar o perfil na partida religa o pulso")
	# o nível que o Personalizado usa (Brilhos e halos)
	Config.g_soltar_temporario()


# ------------------------------------------------------------------ morte


func _t_morte() -> void:
	Config.g_perfil_temporario("alto")
	await novo("lucas")
	var h = w.heroi
	var f = h.foguinho
	passos(10)
	ok(f.no.modulate.a > 0.2, "vivo: a chama acesa")
	f.desvanecer(0.0)
	ok(f.no.modulate.a == 0.0, "desvanecer(0) apaga")
	f.desvanecer(1.0)
	ok(f.no.modulate.a > 0.0, "desvanecer(1) acende")
	h.imortal = false
	h.invenc = 0.0
	h.levar_dano(100000.0, h.pos + Vector2(30, 0))
	ok(h.estado == h.Estado.MORTO, "o herói morreu")
	for i in 600:
		w.avancar(PASSO)
		if h.morte_k() >= 1.0:
			break
	ok(f.no.modulate.a < 0.05, "morto: a chama apagou com o corpo (alfa %.3f)" % f.no.modulate.a)
	w.reiniciar()
	passos(3)
	ok(w.heroi.foguinho.no.modulate.a > 0.2, "ao reiniciar a chama volta")
	ok(w.heroi.foguinho.no.visible, "ao reiniciar a chama está visível")


# ------------------------------------------------------------------ fotos


func _recorte(pasta: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = w.ap.sv.get_texture().get_image()
	var c := img.get_size() / 2
	var r := Rect2i(c.x - 24, c.y - 24, 48, 56)
	var parte := img.get_region(r)
	parte.resize(parte.get_width() * 8, parte.get_height() * 8, Image.INTERPOLATE_NEAREST)
	var caminho := pasta.path_join(nome + ".png")
	parte.save_png(caminho)
	print("FOTO ", caminho, " (mundo ", img.get_size(), ")")


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	for h in Herois.lista():
		var id := str(h.id)
		await novo(id, true)
		w.heroi.imortal = true
		w.heroi.entrada_forcada = Vector2.ZERO
		for i in 4:
			await get_tree().process_frame
		var f = w.heroi.foguinho
		f.no.visible = false
		passos(30)
		await _recorte(pasta, "%s_sem" % id)
		f.no.visible = true
		Config.g_perfil_temporario("baixo")
		passos(30)
		await _recorte(pasta, "%s_baixo" % id)
		Config.g_perfil_temporario("alto")
		passos(30)
		await _recorte(pasta, "%s_alto" % id)
		w.heroi.entrada_forcada = Vector2(0, -1)  # de costas
		passos(20)
		await _recorte(pasta, "%s_alto_costas" % id)
