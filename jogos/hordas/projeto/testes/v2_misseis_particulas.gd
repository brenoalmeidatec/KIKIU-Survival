extends "res://testes/isolamento_v2.gd"
# Teste automático das PARTÍCULAS dos micro-mísseis da E do LightWolf (v2/misseis_particulas.gd, ligado em v2/adagas.gd; rodada 7, pedido do Alisson de 05/11/2026):
#  - o arquivo não sorteia (sem RNG da partida), não cria nó e não desenha linha; todas as cores são opacas (alfa 0/1);
#  - pool fixo (MAX): estressado não cresce nem passa do teto; o teto de estouros por quadro (IMPACTOS_QUADRO) vale; emitir não consome o RNG global;
#  - o desenho real (grava os draw_rect): retângulos de lados inteiros de 1 a 6 px, em posição inteira, alfa 1, só nas cores das tabelas; as faíscas saem em direções quantizadas (8);
#  - os detritos caem e param no chão (não atravessam), e tudo some sozinho no fim da vida;
#  - na E de verdade, contra monstros: nascem fagulhas no voo e estouros no acerto; perfil Baixo e "Reduzir piscadas": NENHUMA partícula nova (contador 0).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_misseis_particulas.tscn  (imprime "v2_misseis_particulas falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Part := preload("res://v2/misseis_particulas.gd")
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


func _ready() -> void:
	_arquivo()
	_pool()
	_desenho()
	_fisica()
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_na_e()
	Herois.forcado = ""
	print("v2_misseis_particulas falhas=%d" % falhas)
	get_tree().quit()


func _corpo(src: String, nome: String) -> String:
	var a := src.find("\nfunc %s(" % nome)
	if a < 0:
		return ""
	var b := src.find("\nfunc ", a + 1)
	return src.substr(a, (b if b > 0 else src.length()) - a)


func _arquivo() -> void:
	var src := FileAccess.get_file_as_string("res://v2/misseis_particulas.gd")
	ok(src.length() > 1000, "leu misseis_particulas.gd")
	for proibido in ["randf", "randi", "rand_", "RandomNumberGenerator", ".new()", "add_child", "draw_line", "draw_arc", "modulate"]:
		ok(src.find(proibido) < 0, "misseis_particulas.gd não usa `%s`" % proibido)
	var ad := FileAccess.get_file_as_string("res://v2/adagas.gd")
	for f in ["_fumaca", "_particulas_ok"]:
		var c := _corpo(ad, f)
		ok(c != "" and c.find("rand") < 0, "adagas.%s existe e não sorteia" % f)
	ok(_corpo(ad, "_explodir").find("particulas.impacto(") > 0, "o acerto chama o estouro das partículas")
	for tabela in [Part.AMBAR, Part.CINZA, Part.TERRA, [Part.BRANCO]]:
		for c in tabela:
			ok((c as Color).a == 1.0, "cor %s opaca" % c)


func _pool() -> void:
	var p := Part.new()
	p.montar()
	var semente := randi()
	seed(91)
	var esperado := randi()
	seed(91)
	for k in 300:
		p.voo(Vector2(10 + k, 50), Vector2.RIGHT, k % 7)
		p.impacto(Vector2(200 + k, 120), 28.0)
		p.atualizar(0.0)  # quadro com dt 0 (hit-stop): o teto por quadro zera mesmo assim
	ok(randi() == esperado, "voo/impacto não consumiram o RNG global")
	seed(semente)
	ok(p.vivos() <= Part.MAX, "pool no teto (%d de %d)" % [p.vivos(), Part.MAX])
	ok(p.pos.size() == Part.MAX and p.resta.size() == Part.MAX and p.tipo.size() == Part.MAX, "o pool não cresceu")
	p.limpar()
	var aceitos := 0
	for k in 8:  # 8 mísseis acertando no mesmo quadro
		aceitos += 1 if p.impacto(Vector2(100 + k * 20, 100), 28.0) else 0
	ok(aceitos == Part.IMPACTOS_QUADRO, "teto de estouros por quadro: %d (esperado %d)" % [aceitos, Part.IMPACTOS_QUADRO])
	p.atualizar(PASSO)
	ok(p.impacto(Vector2(50, 50), 28.0), "no quadro seguinte aceita de novo")
	for _k in 120:
		p.atualizar(PASSO)
	ok(p.vivos() == 0, "tudo some sozinho no fim da vida (%d vivos)" % p.vivos())


class Gravador:
	extends RefCounted
	var rects: Array = []

	func draw_rect(r: Rect2, c: Color) -> void:
		rects.append([r, c])


func _desenho() -> void:
	var p := Part.new()
	p.montar()
	var paleta := {}
	for tabela in [Part.AMBAR, Part.CINZA, Part.TERRA, [Part.BRANCO]]:
		for c in tabela:
			paleta[c] = true
	p.voo(Vector2(40.3, 60.7), Vector2.RIGHT, 0)
	p.voo(Vector2(60.3, 60.7), Vector2.RIGHT, 3)
	p.impacto(Vector2(120.4, 100.6), 30.0)
	var dirs_ok := true
	for i in Part.MAX:
		if p.resta[i] > 0.0 and p.tipo[i] == Part.FAISCA:  # a direção da faísca é uma das 8 (mais o empurrão fixo para cima)
			var d: Vector2 = (p.vel[i] - Vector2(0, -40)).normalized()
			var achou := false
			for q in Part.DIRS8:
				achou = achou or d.distance_to(q) < 0.001
			dirs_ok = dirs_ok and achou
	ok(dirs_ok, "faíscas em direções quantizadas (8)")
	var quadros := 0
	var ruins := 0
	var fora := 0
	var total := 0
	while p.vivos() > 0 and quadros < 100:
		var g := Gravador.new()
		p.desenhar(g)
		for par in g.rects:
			var rc: Rect2 = par[0]
			total += 1
			var inteiro := (
				rc.position == rc.position.round()
				and rc.size == rc.size.round()
				and rc.size.x >= 1.0
				and rc.size.y >= 1.0
				and rc.size.x <= 6.0
				and rc.size.y <= 6.0
			)
			if not inteiro:
				ruins += 1
			if not paleta.has(par[1]):
				fora += 1
		p.atualizar(PASSO)
		quadros += 1
	ok(total > 200, "desenhou bastante (%d retângulos em %d quadros)" % [total, quadros])
	ok(ruins == 0, "todo retângulo inteiro, de 1 a 6 px (%d fora)" % ruins)
	ok(fora == 0, "toda cor das tabelas, opaca (%d fora)" % fora)
	ok(quadros < 60, "o estouro acaba em menos de 1 s de mundo (%d quadros)" % quadros)


func _fisica() -> void:
	var p := Part.new()
	p.montar()
	p.impacto(Vector2(100, 200), 28.0)
	var abaixo := 0
	for _k in 40:
		p.atualizar(PASSO)
		for i in Part.MAX:
			if p.resta[i] > 0.0 and p.tipo[i] == Part.DETRITO and p.pos[i].y > p.chao[i] + 0.001:
				abaixo += 1
	ok(abaixo == 0, "detritos nunca passam do chão (%d)" % abaixo)


func _zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(120, 0)
	passos(3)
	h.hab_recarga = 0.0
	h.hab_nega_t = 0.0
	for k in 5:
		var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(140 + k * 14, -30 + k * 15))
		m.atordoa_t = 60.0
		m.vida = 5000.0
		m.vida_max = 5000.0
		m.emp = Vector2.ZERO
		m.recarga = 99.0


## Na E de verdade: fagulhas no voo e estouros nos acertos (perfil normal); nada novo no perfil Baixo e com Reduzir piscadas.
func _na_e() -> void:
	var ad = w.combate.adagas
	var antes_cfg: bool = Config.reduzir_piscadas
	for caso in ["normal", "poucas", "nenhuma", "calmo"]:
		if caso == "poucas" or caso == "nenhuma":
			w.args["particulas"] = caso
		else:
			w.args.erase("particulas")
		Config.reduzir_piscadas = caso == "calmo"
		_zerar()
		ok(w.heroi.habilidade(), "%s: a E dispara" % caso)
		var pico := 0
		for _q in 150:
			passos(1)
			pico = maxi(pico, ad.particulas.vivos())
			ok(ad.particulas.pos.size() == Part.MAX, "pool fixo durante a E")
		if caso == "normal":
			ok(ad.particulas.emitidas > 20, "normal: nasceram partículas (%d)" % ad.particulas.emitidas)
			ok(ad.particulas.impactos > 0, "normal: houve estouro de acerto (%d)" % ad.particulas.impactos)
			ok(pico > 5 and pico <= Part.MAX, "normal: pico de vivas %d (teto %d)" % [pico, Part.MAX])
			print("partículas na E: emitidas=%d, estouros=%d, pico vivas=%d" % [ad.particulas.emitidas, ad.particulas.impactos, pico])
		else:
			ok(ad.particulas.emitidas == 0 and pico == 0, "%s: nenhuma partícula nova (nasceram %d)" % [caso, ad.particulas.emitidas])
	Config.reduzir_piscadas = antes_cfg
	w.args.erase("particulas")
