extends RefCounted
## O baú da v2 (leva 3): a elite e o mini-chefe soltam um baú dourado que brilha no chão. Encostar nele abre: o mundo pára, uma roleta curta de
## cartas de raridade maior (dados/v2_cartas.json > "bau") aparece na tela da escolha de nível e o herói PEGA 1 ou 2 delas em até 12 s (bau.limite_s), com a
## mais rara sendo escolhida sozinha ao zerar; com 3 melhorias, número fixado no mapa (forcar) ou sem melhoria para sortear, ele dá tudo DE GRAÇA com a roleta de revelação (telas.mostrar_bau).
## O baú não tem arte pronta: o desenho é um pixel art de 22x20 gerado aqui, uma vez, e o brilho dourado (aditivo, na camada glow) e a luz
## são o que o faz aparecer no escuro. Pool de 4 baús criados na abertura; nada de nó novo durante a partida.

const MAX := 4
const ACHATA := 0.62

var combate
var mundo
var cfg: Dictionary = {}
var lista: Array = []  # {raiz, corpo, brilho, luz, ativo, pos, t, bonus, forcar}
var abertos := 0  # baús abertos na partida (testes)
var soltos := 0  # baús que já caíram (testes)
var ultimas: Array = []  # as cartas do último baú aberto
var _tex: Texture2D
var _tex_sombra: Texture2D
var _prox := 0


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	cfg = c.cartas.cfg.bau
	_tex = _textura()
	_tex_sombra = _textura_sombra()
	for i in MAX:
		var raiz := Node2D.new()
		raiz.visible = false
		mundo.no_mundo.add_child(raiz)
		var sombra := Sprite2D.new()
		sombra.texture = _tex_sombra
		sombra.show_behind_parent = true
		sombra.position = Vector2(0, -1)
		raiz.add_child(sombra)
		var corpo := Sprite2D.new()
		corpo.texture = _tex
		corpo.centered = false
		corpo.offset = Vector2(-11, -19)
		corpo.scale = Vector2(1.5, 1.5)
		corpo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		corpo.visible = false
		mundo.glow.add_child(corpo)  # na camada glow, sem o escurecimento da floresta: o baú sempre aparece, e o brilho dele é a luz
		var brilho := Sprite2D.new()
		brilho.texture = c.fx.tex_brilho
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		brilho.material = mat
		brilho.visible = false
		mundo.glow.add_child(brilho)
		var luz := PointLight2D.new()
		luz.texture = c.armas.luz_fogo.texture
		luz.color = Color(1.0, 0.8, 0.35)
		luz.height = 18.0
		luz.energy = 0.9
		luz.texture_scale = 70.0 / 128.0
		luz.enabled = false
		luz.shadow_enabled = false
		mundo.sv.add_child(luz)
		lista.append({"raiz": raiz, "corpo": corpo, "brilho": brilho, "luz": luz, "ativo": false, "pos": Vector2.ZERO, "t": 0.0, "bonus": 1.0, "forcar": 0})


func _textura() -> Texture2D:
	var im := Image.create(22, 20, false, Image.FORMAT_RGBA8)
	var borda := Color(0.09, 0.05, 0.03)
	var madeira := Color(0.42, 0.25, 0.12)
	var madeira_l := Color(0.55, 0.34, 0.16)
	var metal := Color(0.82, 0.66, 0.24)
	var metal_l := Color(1.0, 0.9, 0.5)
	_ret(im, 1, 8, 20, 11, borda)
	_ret(im, 2, 9, 18, 9, madeira)
	_ret(im, 2, 9, 18, 2, madeira_l)
	_ret(im, 2, 3, 18, 6, borda)  # tampa
	_ret(im, 3, 4, 16, 5, madeira_l)
	_ret(im, 5, 2, 12, 2, borda)
	_ret(im, 6, 3, 10, 1, madeira_l)
	_ret(im, 3, 4, 3, 15, metal)  # cintas
	_ret(im, 16, 4, 3, 15, metal)
	_ret(im, 3, 4, 1, 15, metal_l)
	_ret(im, 16, 4, 1, 15, metal_l)
	_ret(im, 9, 8, 4, 5, borda)  # fechadura
	_ret(im, 10, 9, 2, 3, metal_l)
	_ret(im, 2, 15, 18, 1, borda)
	return ImageTexture.create_from_image(im)


func _ret(im: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, mini(y + h, im.get_height())):
		for xx in range(x, mini(x + w, im.get_width())):
			im.set_pixel(xx, yy, c)


func _textura_sombra() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0)])
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 48
	tx.height = 20
	return tx


func limpar() -> void:
	for b in lista:
		b.ativo = false
		b.raiz.visible = false
		b.corpo.visible = false
		b.brilho.visible = false
		b.luz.enabled = false
	abertos = 0
	soltos = 0
	ultimas = []


func ativos() -> int:
	var n := 0
	for b in lista:
		if b.ativo:
			n += 1
	return n


## Um baú cai em `p`. `bonus` multiplica a chance de raridade alta (1 = o normal do baú), `forcar_n` fixa quantas melhorias dá (0 = sorteia).
func soltar(p: Vector2, bonus := 1.0, forcar_n := 0) -> void:
	var q := p.clamp(mundo.limite_andavel.position, mundo.limite_andavel.end)
	var b: Dictionary = {}
	for x in lista:
		if not x.ativo:
			b = x
			break
	if b.is_empty():
		b = lista[_prox % MAX]
		_prox += 1
	b.ativo = true
	b.pos = q
	b.t = 0.0
	b.bonus = bonus
	b.forcar = forcar_n
	b.raiz.position = q.round()
	b.raiz.visible = true
	b.corpo.visible = true
	b.brilho.visible = true
	b.luz.enabled = true
	b.luz.position = (q + Vector2(0, -8)).round()
	soltos += 1
	combate.fx.onda(q, Color(1.0, 0.85, 0.4, 0.9), 34.0, 0.4)
	combate.fx.faiscas(q + Vector2(0, -10), Vector2(0, -1), 10, Color(1.0, 0.85, 0.4), 120.0)
	combate.audio.tocar("bau_cai", 1.0, -2.0, 0.1)


func atualizar(dt: float) -> void:
	var h = mundo.heroi
	for b in lista:
		if not b.ativo:
			continue
		b.t += dt
		var queda := clampf(b.t / 0.4, 0.0, 1.0)
		var y := -90.0 * (1.0 - queda) * (1.0 - queda)
		b.corpo.position = (b.pos + Vector2(0, y)).round()
		var pulso := 0.8 + 0.2 * sin(b.t * 5.0)
		b.brilho.position = (b.pos + Vector2(0, -10 + y)).round()
		var tam := 84.0 * pulso
		b.brilho.scale = Vector2.ONE * tam / 128.0
		b.brilho.modulate = Color(1.0, 0.8, 0.35, 0.75 * clampf(b.t / 0.4, 0.0, 1.0))
		b.luz.energy = 0.7 + 0.3 * pulso
		if queda >= 1.0 and int(b.t * 6.0) != int((b.t - dt) * 6.0):
			combate.fx.particula(
				b.pos + Vector2(randf_range(-9, 9), -8.0), Vector2(randf_range(-6, 6), -26), 0.7, 3.0, Color(1.0, 0.85, 0.4, 0.9), -10.0, randf() < 0.5
			)
		if combate.jogo == "jogando" and h.vivo() and queda >= 1.0:
			var d: Vector2 = h.pos - b.pos
			var r := float(cfg.alcance)
			if d.x * d.x + (d.y / ACHATA) * (d.y / ACHATA) < r * r:
				abrir(b)
				return


## Abre o baú `b`. O baú sorteado (elite e mini-chefe) dá 1 a 3 melhorias e deixa o jogador ESCOLHER entre 3 cartas de raridade melhor, com `bau.limite_s`
## (12 s, contra os 8 s da carta de nível) e escolha automática no fim: 1 ou 2 melhorias = pega 1 ou 2 das 3 na mesma tela da escolha de nível. Sem
## escolha de verdade, o baú entrega tudo de graça na hora e mostra a roleta de revelação (o mundo pára até o jogador confirmar): 3 melhorias (não
## sobra o que escolher), baú com número fixado no mapa (`forcar`, "cartas do baú") e a cura de reserva quando não resta melhoria para sortear.
func abrir(b: Dictionary) -> void:
	b.ativo = false
	b.raiz.visible = false
	b.corpo.visible = false
	b.brilho.visible = false
	b.luz.enabled = false
	abertos += 1
	if bool(preload("res://v2/dificuldade.gd").da_partida(mundo).get("folego_cheio", false)):
		mundo.heroi.encher_folego()
	var n: int = int(b.forcar)
	var fixo := n > 0
	if n <= 0:
		n = sortear_quantidade()
	var h = mundo.heroi
	var bonus := float(cfg.bonus_raridade) * float(b.bonus)
	var piso := int(cfg.get("piso_raridade", 0))
	var qtd := int(combate.cartas.cfg.escolha.cartas)
	if not fixo and n < qtd:
		var candidatas: Array = combate.cartas.sortear(qtd, h.nivel, bonus, [], piso)
		if candidatas.size() > n:
			_abrir_escolha(b, candidatas, n)
			return
	var cartas: Array = combate.cartas.sortear(n, h.nivel, bonus, [], piso)
	if cartas.is_empty():
		cartas = [
			{
				"id": "cura",
				"nome": "Alma renovada",
				"desc": "Cura toda a vida",
				"cat": "stat",
				"stat": "cura",
				"rar": 0,
				"rar_nome": "Comum",
				"cor": Color(0.8, 0.82, 0.86),
				"icone": "icone_vida",
				"proximo": "",
				"nivel_txt": "",
				"evolui": "",
				"valor": 0.0,
				"max": 99
			}
		]
	for c in cartas:
		combate.cartas.aplicar(c)
	ultimas = cartas
	_efeitos_de_abertura(b)
	combate.jogo = "bau"
	combate.pausado = true
	combate.telas.mostrar_bau(cartas)


## O baú com escolha: nada é aplicado ainda; a tela de escolha (progresso.abrir_escolha_bau) aplica cada carta que o jogador pega, ou a mais rara
## quando o tempo acaba. `ultimas` vai enchendo com as pegas.
func _abrir_escolha(b: Dictionary, candidatas: Array, picks: int) -> void:
	ultimas = []
	_efeitos_de_abertura(b)
	combate.progresso.abrir_escolha_bau(candidatas, picks)


func _efeitos_de_abertura(b: Dictionary) -> void:
	combate.fx.onda(b.pos, Color(1.0, 0.9, 0.5, 0.95), 60.0, 0.5)
	combate.fx.faiscas(b.pos + Vector2(0, -10), Vector2(0, -1), 14, Color(1.0, 0.9, 0.5), 180.0)
	combate.audio.tocar("bau", 1.0, 0.0, 0.1)


func sortear_quantidade() -> int:
	var pesos: Array = cfg.n_pesos
	var total := 0.0
	for p in pesos:
		total += float(p)
	var r := randf() * total
	for i in pesos.size():
		r -= float(pesos[i])
		if r < 0.0:
			return i + 1
	return 1


## O jogador confirmou a roleta: o jogo volta.
func fechar() -> void:
	if combate.jogo != "bau":
		return
	combate.telas.esconder()
	combate.pausado = false
	combate.jogo = "jogando"
