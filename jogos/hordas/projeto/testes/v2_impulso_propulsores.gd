extends "res://testes/isolamento_v2.gd"
# Teste automático dos PROPULSORES NAS COSTAS do mecha no impulso (rodada 6; v2/propulsor.gd, v2/impulso.gd > forca, heroi.gd, dados/v2_herois.json >
# lightwolf > impulso > propulsor). Confere: no chão não há jato visível; voando existem dois jatos (pool fixo de 2 nós, os mesmos de um voo para o outro),
# nas costas do mecha nas 8 direções (a chama cai para o lado contrário ao que ele olha), atrás do corpo olhando para baixo e na frente nas outras (ordem
# no y-sort e na árvore); posições inteiras e alfa 0 ou 1; mais fortes na decolagem que no cruzeiro e na descida; ciclo de 4 quadros que só muda a forma
# (a mesma paleta); "Reduzir piscadas" deixa o ciclo em no máximo 2 Hz reais; perfil Baixo: chama simples e parada; os jatos somem no fim do voo, ao virar
# Lobo, e a sombra no chão encolhe e clareia no ar.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_impulso_propulsores.tscn  (imprime "v2_impulso_propulsores falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const Propulsor := preload("res://v2/propulsor.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const PASSO := 1.0 / 60.0
const OLHARES := {
	"direita": Vector2(1, 0),
	"baixo_dir": Vector2(1, 1),
	"baixo": Vector2(0, 1),
	"baixo_esq": Vector2(-1, 1),
	"esquerda": Vector2(-1, 0),
	"cima_esq": Vector2(-1, -1),
	"cima": Vector2(0, -1),
	"cima_dir": Vector2(1, -1),
}

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	Colisao.limpar()
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.correr_forcado = false
	h.m_vel_mov = 0.0  # o mecha voa no lugar: só o desenho interessa
	h.fonte = Heroi.Fonte.MOUSE
	h.pos = w.limite_andavel.get_center()
	h.definir_pos(h.pos)
	w.mouse_forcado = h.centro() + Vector2(4000, 0)
	passos(3)


func apertar() -> void:
	w.heroi.correr_forcado = true
	passos(1)
	w.heroi.correr_forcado = false


## As medidas de uma textura: linhas opacas (o comprimento da chama), pixels opacos, se todo alfa é 0 ou 1, as cores e a luminância somada.
func medir(tex: Texture2D) -> Dictionary:
	var img: Image = tex.get_image()
	var linhas := 0
	var opacos := 0
	var alfa01 := true
	var cores := {}
	var lum := 0.0
	for y in img.get_height():
		var tem := false
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0 and p.a < 1.0:
				alfa01 = false
			if p.a > 0.0:
				tem = true
				opacos += 1
				cores[p.to_html()] = true
				lum += p.get_luminance()
		if tem:
			linhas += 1
	return {"linhas": linhas, "opacos": opacos, "alfa01": alfa01, "cores": cores, "lum": lum}


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var h = w.heroi
	var imp = w.combate.get("impulso")
	var c: Dictionary = w.combate.cfg.get("impulso", {})
	var n: Dictionary = Propulsor.numeros(c.get("propulsor", {}))
	ok(imp != null and not c.is_empty() and c.has("propulsor"), "o cfg do impulso tem o bloco propulsor")
	if falhas > 0:
		print("v2_impulso_propulsores falhas=%d" % falhas)
		get_tree().quit()
		return
	Config.temporario(Piscadas.OPCAO, false)
	Config.g_perfil_temporario("medio")

	# 1. no chão: nada
	zerar()
	ok(h.propulsor == null or not h.propulsor.visivel(), "no chão não há jato")

	# 2. geometria pura das 8 direções: a boca fica nas costas e a chama cai para trás
	for nome in OLHARES:
		var f: Vector2 = Propulsor.DIRS[nome]
		var g: Dictionary = Propulsor.geometria(nome, n)
		var media: Vector2 = (g.monta[0] + g.monta[1]) * 0.5
		var alt := float(n.atras_altura) if f.y > 0.3 else float(n.altura)
		var no_chao := Vector2(media.x, (media.y + alt) / Propulsor.ACHATA)  # desfaz a projeção: o ponto no chão
		ok(no_chao.dot(f) < -1.0, "%s: a mochila fica nas costas (%.1f)" % [nome, no_chao.dot(f)])
		ok(f.x == 0.0 or g.inclina * f.x < 0.0, "%s: a chama cai para o lado contrário ao olhar (%.2f)" % [nome, g.inclina])
		ok(g.monta[0] != g.monta[1], "%s: dois jatos, em lugares diferentes" % nome)
		ok(bool(g.atras) == (f.y > 0.3), "%s: atrás do corpo só olhando para baixo" % nome)

	# 3. voando, nas 8 direções: jatos visíveis, na ordem certa, em px inteiros
	apertar()
	passos(30)  # já no cruzeiro, lá em cima
	ok(h.imp_t > 0.0 and h.propulsor != null and h.propulsor.visivel(), "voando os jatos aparecem")
	var nos_ids := []
	if h.propulsor != null:
		ok(h.propulsor.nos.size() == 2, "pool fixo: 2 jatos")
		for s in h.propulsor.nos:
			nos_ids.append(s.get_instance_id())
	var linhas: Array = h.tipo.info.get("linhas", [])
	for nome in OLHARES:
		w.mouse_forcado = h.centro() + OLHARES[nome] * 4000.0
		passos(4)
		var p = h.propulsor
		ok(linhas.size() > h.linha and str(linhas[h.linha]) == nome, "%s: o mecha olha para lá (linha %d)" % [nome, h.linha])
		ok(p.nome_dir == nome and p.visivel() and p.nos[1].visible, "%s: os dois jatos acesos (%s)" % [nome, p.nome_dir])
		var i_corpo: int = h.sprite.get_index()
		var f: Vector2 = Propulsor.DIRS[nome]
		for s in p.nos:
			ok(
				(s.get_index() < i_corpo) if f.y > 0.3 else (s.get_index() > i_corpo),
				"%s: ordem na árvore (jato %d, corpo %d)" % [nome, s.get_index(), i_corpo]
			)
			if h.raiz.y_sort_enabled:
				ok((s.position.y < h.sprite.position.y) if f.y > 0.3 else (s.position.y > h.sprite.position.y), "%s: ordem no y-sort" % nome)
			ok(s.position == s.position.round() and s.offset == s.offset.round(), "%s: posição e offset em px inteiros" % nome)
			# onde a chama é desenhada: o canto de cima fica nas costas do corpo (dentro de 40 px dos pés, abaixo do topo do mecha)
			var topo: Vector2 = s.position + s.offset + Vector2(float(Propulsor.METADE), 0.0)
			ok(absf(topo.x) < 40.0 and topo.y > -75.0 - float(h.alt_px) and topo.y < 10.0, "%s: a chama sai do corpo (%s)" % [nome, topo])
	w.mouse_forcado = h.centro() + Vector2(4000, 0)
	passos(4)
	var m := medir(h.propulsor.nos[0].texture)
	ok(m.alfa01, "alfa só 0 ou 1")
	for i in 2:
		ok(h.propulsor.nos[i].get_instance_id() == nos_ids[i], "os mesmos nós de antes (sem nó novo)")

	# 4. a força: decolagem > cruzeiro > descida (comprimento da chama)
	zerar()
	var comp := {}
	apertar()
	passos(3)
	comp[2] = medir(h.propulsor.nos[0].texture).linhas
	ok(h.propulsor.forca == 2, "no começo do voo a força é a da decolagem")
	passos(60)
	comp[1] = medir(h.propulsor.nos[0].texture).linhas
	ok(h.propulsor.forca == 1, "no cruzeiro a força é a normal")
	while h.imp_t > 0.2:
		passos(1)
	passos(2)
	comp[0] = medir(h.propulsor.nos[0].texture).linhas
	ok(h.propulsor.forca == 0, "na descida a força é a menor")
	ok(comp[2] > comp[1] + 3 and comp[1] > comp[0] + 3, "a chama é mais longa na decolagem que no cruzeiro e que na descida (%s)" % [comp])

	# 5. o ciclo: 4 quadros, só a forma muda, mesma paleta
	zerar()
	apertar()
	passos(45)  # cruzeiro
	var vistos := {}
	var trocas := 0
	var ant: int = h.propulsor.quadro
	var formas := {}
	var cores_ref := {}
	var lums := []
	for i in 60:
		passos(1)
		var q: int = h.propulsor.quadro
		vistos[q] = true
		if q != ant:
			trocas += 1
		ant = q
		if not formas.has(q):
			var mq := medir(h.propulsor.nos[0].texture)
			formas[q] = mq.opacos
			lums.append(mq.lum)
			for k in mq.cores:
				cores_ref[k] = true
	ok(vistos.size() == 4, "o ciclo tem 4 quadros (%d vistos)" % vistos.size())
	var distintas := {}
	for q in formas:
		distintas[formas[q]] = true
	ok(distintas.size() >= 3, "os quadros mudam a forma (%s)" % [formas])
	ok(cores_ref.size() <= 4, "a mesma paleta em todos os quadros (%d cores)" % cores_ref.size())
	var lmax: float = lums.max()
	var lmin: float = lums.min()
	ok(lmin > 0.0 and lmax / lmin < 1.4, "o brilho total quase não muda entre quadros (%.2f)" % (lmax / maxf(lmin, 0.001)))
	var normal := trocas
	# com "Reduzir piscadas": 0,5 s reais por ciclo no mínimo (2 Hz); a forma segue mudando, nunca a cor
	var ciclo_real := float(n.quadro_lento_s) * float(Propulsor.QUADROS) / 1.25
	ok(ciclo_real >= 0.5 - 0.001, "Reduzir piscadas: o ciclo dura >= 0,5 s reais (%.3f)" % ciclo_real)
	Config.temporario(Piscadas.OPCAO, true)
	trocas = 0
	ant = h.propulsor.quadro
	for i in 60:
		if h.imp_t <= 0.0:
			break
		passos(1)
		var q: int = h.propulsor.quadro
		if q != ant:
			trocas += 1
		ant = q
	# 60 quadros = 1 s de jogo = 0,8 s reais: no máximo 2 ciclos x 4 quadros por s real = 6,4 trocas de quadro (7 com o arredondamento)
	ok(trocas <= 7 and trocas * 2 <= normal + 1, "Reduzir piscadas: o ciclo anda mais devagar (%d trocas em 60 quadros, contra %d)" % [trocas, normal])
	Config.temporario(Piscadas.OPCAO, false)

	# 6. perfil Baixo: chama simples e parada
	zerar()
	Config.g_perfil_temporario("baixo")
	apertar()
	var qs := {}
	for i in 60:
		passos(1)
		qs[h.propulsor.quadro] = true
	ok(h.propulsor.visivel() and qs.size() == 1, "perfil Baixo: chama simples, 1 quadro (%s)" % [qs.keys()])
	Config.g_perfil_temporario("medio")

	# 7. a sombra no chão: menor e mais clara no ar (blob), normal no chão
	zerar()
	ok(h.ar == 0.0, "no chão a sombra é a de sempre")
	apertar()
	passos(30)
	ok(h.ar > 0.8, "no alto a sombra encolhe (ar %.2f)" % h.ar)
	var k_ar: float = h.blob.scale.x
	var a_ar: float = h.blob.modulate.a
	while h.imp_t > 0.0:
		passos(1)
	passos(4)
	ok(h.ar == 0.0 and h.blob.scale.x > k_ar * 1.2 and h.blob.modulate.a > a_ar, "pousado a sombra volta (%.2f -> %.2f)" % [k_ar, h.blob.scale.x])

	# 8. somem no fim do voo e ao virar Lobo
	ok(not h.propulsor.visivel(), "no fim do voo os jatos somem")
	zerar()
	apertar()
	passos(20)
	ok(h.propulsor.visivel(), "voando de novo, os jatos voltam")
	w.combate.mecha.virar_lobo(h, 20.0)
	passos(2)
	ok(not h.propulsor.visivel(), "ao virar Lobo os jatos somem")

	print("v2_impulso_propulsores falhas=%d" % falhas)
	get_tree().quit()
