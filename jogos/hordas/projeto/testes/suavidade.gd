extends Node
# Teste (pedido do Alisson): monstros suaves (nada teleporta sem animação) e a aura do Hazaki envolvendo o herói.
#  - nenhum inimigo anda mais que o limite por quadro sem estar na animação de teleporte;
#  - a reciclagem (inimigo longe volta pra perto) toca a animação; teleporte visível cria fantasma;
#  - cliente online: desliza entre as fotos sem pulo, grande salto vira teleporte animado, foto cheia não pisca;
#  - aura: metade das chamas atrás e metade na frente do herói, as duas com alfa < 1 (a da frente mais transparente).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/suavidade.tscn  (imprime "SUAVE falhas=0")
const Aura := preload("res://scripts/hordas/armas/aura_energia.gd")
const Inimigos := preload("res://scripts/hordas/inimigos.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## Finge ser o nó de desenho: guarda cada cone (polígono) com a cor, pra conferir a divisão atrás/frente.
class Gravador:
	var polis: Array = []
	func draw_colored_polygon(pts: PackedVector2Array, cor: Color) -> void:
		polis.append([pts, cor])


class FakeArma:
	var _t := 1.3
	var dono: Node2D = null


## O "online" do cliente de mentira (só o que inimigos.gd lê).
class Onl:
	extends Node
	const ENVIO := 1.0 / 15.0
	var tipos := ["bug"]
	var sprites_tiro := []


func _ready() -> void:
	# ---------- aura: atrás e na frente, transparente ----------
	var w := FakeArma.new()
	w.dono = Node2D.new()
	w.dono.position = Vector2(100, 200)
	for nv in [1, 3, 5]:
		var a := {"nivel": nv}
		var atras := Gravador.new()
		var frente := Gravador.new()
		Aura._chamas(w, atras, a, false)
		Aura._chamas(w, frente, a, true)
		ok(atras.polis.size() > 0 and frente.polis.size() > 0, "nível %d: tem chamas atrás (%d) e na frente (%d)" % [nv, atras.polis.size(), frente.polis.size()])
		var n_total: int = 6 + int(nv) * 2
		var por_cone: int = 2 + (1 if nv >= 4 else 0)
		ok((atras.polis.size() + frente.polis.size()) / por_cone == n_total, "nível %d: as duas metades somam o anel todo (%d)" % [nv, n_total])
		var max_a := 0.0
		var max_f := 0.0
		for p in atras.polis:
			max_a = maxf(max_a, p[1].a)
		for p in frente.polis:
			max_f = maxf(max_f, p[1].a)
		ok(max_a < 1.0 and max_f < 1.0, "nível %d: alfa < 1 atrás (%.2f) e na frente (%.2f)" % [nv, max_a, max_f])
		ok(max_f < max_a, "nível %d: a frente é mais transparente (%.2f < %.2f)" % [nv, max_f, max_a])
		var por_cima := 0
		var por_baixo := 0
		for p in atras.polis:
			if p[0][0].y <= w.dono.position.y - 2.0 + 0.001:
				por_cima += 1
		for p in frente.polis:
			if p[0][0].y >= w.dono.position.y - 2.0 - 0.001:
				por_baixo += 1
		ok(por_cima == atras.polis.size() and por_baixo == frente.polis.size(), "nível %d: atrás = lado de cima do anel, frente = lado de baixo" % nv)
		var largura := 0.0
		for p in atras.polis + frente.polis:
			largura = maxf(largura, absf(p[0][0].x - w.dono.position.x))
		ok(largura >= 20.0, "nível %d: o anel é mais largo que o herói (meia largura %.1f)" % [nv, largura])
	ok(Aura.ALFA_TRAS < 1.0 and Aura.ALFA_FRENTE < Aura.ALFA_TRAS, "constantes de alfa")

	# ---------- inimigos na partida ----------
	var m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(0.3).timeout
	m._comecar("hazaki")
	var ar = m._arena
	var j = ar.jogador
	await get_tree().create_timer(1.0).timeout
	ar.set_process(false)                       # os quadros são do teste
	j.bot = true
	var I = ar.inimigos
	I.limpar()
	var tipos := ["bug", "trojan", "spam", "popup"]
	for i in 160:
		I.criar(tipos[i % tipos.size()], j.position + Vector2.from_angle(randf() * TAU) * randf_range(60, 420))
	var dt := 1.0 / 60.0
	var prev := {}
	var violacoes := 0
	var medidos := 0
	var exemplo := ""
	for q in 600:
		if q == 300:
			j.position += Vector2(2600, 0)         # herói some longe: todo mundo passa de LONGE e é reciclado
		if q == 301:
			var animando := 0
			for v in I.lista:
				if v.t_nasc > 0.0:
					animando += 1
			ok(I.tp_n > 0 and animando > 20, "reciclagem toca a animação (teleportes %d, animando %d)" % [I.tp_n, animando])
		ar._process(dt)
		for v in I.lista:
			var antes = prev.get(v.id)
			if antes != null and antes[1] <= 0.0 and v.t_nasc <= 0.0 and v.hp > 0.0:
				var lim: float = (2.5 * v.vel * (5.0 if v.estado == 2 or antes[2] == 2 else 1.0) + antes[3]) * dt + 0.5
				var passo: float = v.pos.distance_to(antes[0])
				medidos += 1
				if passo > lim:
					violacoes += 1
					if exemplo == "":
						exemplo = "%s passo=%.2f limite=%.2f quadro=%d" % [v.tipo, passo, lim, q]
			prev[v.id] = [v.pos, v.t_nasc, v.estado, v.kb.length()]
	ok(violacoes == 0, "nenhum inimigo anda mais que o limite sem animação (%d de %d passos; %s)" % [violacoes, medidos, exemplo])
	ok(medidos > 10000, "mediu passos suficientes (%d)" % medidos)

	# teleporte visível cria o fantasma (some na nuvem) e o reaparecimento
	I.limpar()
	I.fantasmas.clear()
	var v1 = I.criar("bug", j.position + Vector2(40, 0))
	v1.t_nasc = 0.0
	var tp0: int = I.tp_n
	I._teleportar(v1, j.position + Vector2(-300, 20))
	ok(I.tp_n == tp0 + 1 and I.fantasmas.size() == 1 and v1.t_nasc > 0.0, "teleporte na tela: fantasma + reaparecimento")
	for i in 30:
		I._fantasmas_passo(0.01)
	ok(I.fantasmas.is_empty(), "o fantasma some sozinho em ~0,26 s")
	I.limpar()
	I.fantasmas.clear()
	var v2 = I.criar("bug", j.position + Vector2(2000, 0))
	I._teleportar(v2, j.position + Vector2(380, 0))
	ok(I.fantasmas.is_empty(), "teleporte fora da tela não gasta desenho")

	# ---------- cliente online: foto a 15 Hz, deslize e salto ----------
	var C = Inimigos.new()
	var onl := Onl.new()
	C.online = onl
	C.arena = ar
	C.espelho = true
	add_child(C)
	var fdt := 1.0 / 144.0
	var vel := 40.0
	var t := 0.0
	var prox_foto := 0.0
	var ultimo := Vector2.ZERO
	var maxpasso := 0.0
	var salto_t := -1.0
	var desvio := 0.0
	var tp_antes := 0
	var recriou := 0
	var visto := false
	for q in 1000:
		if t >= prox_foto:
			prox_foto += onl.ENVIO
			if t > 3.0 and salto_t < 0.0:
				salto_t = t
				desvio = 400.0               # reciclagem no anfitrião: 400 px adiante de uma foto pra outra
				tp_antes = C.tp_n
			var x := 3000.0 + vel * t + desvio
			var foto := PackedFloat32Array([7, 0, x, 500.0, 1.0, 0])
			if t > 5.0 and t < 5.2:          # foto sem o bicho (foto cheia): não pode piscar
				foto = PackedFloat32Array()
			var existia: bool = C.por_id.has(7)
			C.aplicar_foto(foto, PackedFloat32Array(), onl)
			if visto and not existia and C.por_id.has(7):
				recriou += 1
			visto = visto or C.por_id.has(7)
		C._atualizar_espelho(fdt)
		C._fantasmas_passo(fdt)
		t += fdt
		if C.por_id.has(7):
			var p: Vector2 = C.por_id[7].pos
			var em_salto: bool = salto_t >= 0.0 and t - salto_t < 0.15   # logo depois do salto, o desvio é o teleporte
			if q > 0 and not em_salto:
				maxpasso = maxf(maxpasso, p.distance_to(ultimo))
			ultimo = p
	ok(maxpasso <= 2.5 * vel * fdt + 0.3, "cliente: desliza sem pulo entre as fotos (maior passo %.2f, limite %.2f)" % [maxpasso, 2.5 * vel * fdt + 0.3])
	ok(C.tp_n == tp_antes + 1 and tp_antes == 0, "cliente: salto de 400 px vira teleporte animado (%d)" % C.tp_n)
	ok(recriou == 0 and visto, "cliente: bicho que some de uma foto não pisca (recriado %d vezes)" % recriou)
	for q in 40:                              # sumiu de vez: sai depois do prazo
		C.aplicar_foto(PackedFloat32Array(), PackedFloat32Array(), onl)
	ok(not C.por_id.has(7), "cliente: quem some das fotos por muito tempo sai")

	print("SUAVE falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
