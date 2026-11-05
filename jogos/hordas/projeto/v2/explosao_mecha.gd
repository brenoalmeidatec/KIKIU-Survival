extends RefCounted
## A explosão do mecha na Autodestruição (o Q do LightWolf em forma de mecha, v2/especial.gd `_explodir_mecha`): só o DESENHO. O dano não sai daqui: quem limpa
## a tela é a peça comum (`combate.limpar_tela`, frente de onda a comum.limpa.vel px/s em toda a câmera mais comum.limpa.margem).
## Três peças, todas na grade de 1 px (quadros desenhados em código UMA vez em `montar`, alfa 0/1, desenhados com draw_texture em posição inteira,
## sem escala nem giro; pool fixo: uma explosão por vez, a nova reaproveita a vaga):
##  - BOLA: a bola de energia que estoura e vira fumaça que esfarela (BOLA_QUADROS quadros a BOLA_FPS, em FASES de FASE_QUADROS quadros), de raio `explosao.bola` px, centrada um pouco acima
##    do chão onde o mecha ficou. Vai na camada glow (por cima dos monstros e do herói). Começa com o miolo branco na 1ª fase (5 quadros, um clarão só);
##    com "Reduzir piscadas" pula essa fase e começa no ciano. A silhueta (cresce, sobe, abre o miolo, esfarela) muda a cada quadro; as CORES do miolo só mudam a cada
##    fase e seguem uma disposição FIXA (medida pela raio final da bola, não pelo raio do quadro): cada pixel só desce de claro para escuro, nunca sobe de novo.
##    Antes a cor era medida pelo raio do quadro e as faixas varriam a bola de um quadro para o outro (a "fervura": 3,2 Hz numa janela de 16x16 px, limite 2 Hz).
##  - ONDA NO CHÃO: um anel de 1 px (pontos inteiros numa elipse achatada em ACHATA) que sai do mecha na MESMA velocidade da frente de onda da limpeza
##    (comum.limpa.vel) e vai até cobrir o retângulo da câmera mais a margem: é o desenho do alcance real do dano (a tela inteira). Os monstros morrem
##    quando ela passa (a limpeza usa distância redonda; a elipse chega um pouco depois na vertical, no máximo ~0,1 s).
##    Desenhada no mesmo nó da cratera (chão, z -60): passa por baixo dos monstros e do herói e escurece com o CanvasModulate do mapa.
##  - CRATERA: buraco escuro com borda de terra, chamuscado e rachaduras, de raio `explosao.cratera.raio` (achatada em ACHATA), no nó do mundo com z -60
##    (embaixo dos monstros e do herói, em cima dos decalques do chão). As rachaduras ficam acesas em azul por `cratera.quente` s (uma troca só), e nos
##    últimos `cratera.esfarela` s ela esfarela: os pixels somem por uma máscara FIXA (cada pixel some uma vez e não volta), CRATERA_ESFARELA degraus, de
##    fora para dentro; some de vez em `cratera.dur` s. Nada pisca (nenhum pixel acende e apaga mais de uma vez).
## Tempo do mundo (`atualizar`, chamado pelo especial): o hit-stop do estouro segura o 1º quadro da bola (o "soco" do impacto) e a pausa congela tudo.
## Perfil Baixo: as três peças ficam (são o essencial: o tamanho, o alcance e a marca); o que é extra (partículas, luz, brilho do fusível) fica em especial.gd.
## API: montar(glow, mundo_no, explosao, vel) [vel = comum.limpa.vel], preparar() [desenha os quadros uma vez por sessão], explodir(centro, rect), atualizar(dt), limpar(), viva() -> bool, cratera_viva() -> bool, quadro_bola() -> int,
## quadro_cratera() -> int (testes: -1 = nada).

const Piscadas := preload("res://v2/piscadas.gd")
const ACHATA := 0.62
const BOLA_QUADROS := 25  # até a rodada 6 eram 10 (0,53 s de relógio); agora 25 a 15 por s do mundo = 1,33 s de relógio (2,5x), o mesmo desenho em mais quadros
const BOLA_FPS := 15.0
const FASE_QUADROS := 5  # o PADRÃO INTERNO da bola (as faixas de cor do miolo e a fumaça) só troca a cada 5 quadros = 0,27 s de relógio (limite 0,25 s com "Reduzir piscadas")
const FASES_COR := 4  # as paletas diferentes: a última (tudo fumaça) segue até o fim, e a fumaça só esfarela (se trocasse de novo, cada degrau escuro fazia um dente de serra com o miolo que abre)
const BOLA_SOBE := 14.0  # px que o centro da bola fica acima do chão
const CRATERA_ESFARELA := 4  # degraus do esfarelar (quadros 2..5 da cratera)
const RACHAS := 7
const ONDA_PASSO := 2.0  # px entre dois pontos do anel no chão

const BRANCO := Color(1.0, 1.0, 1.0)
const CIANO_CLARO := Color(0.78, 0.96, 1.0)
const CIANO := Color(0.4, 0.8, 1.0)
const AZUL := Color(0.18, 0.42, 0.9)
const AZUL_ESC := Color(0.08, 0.14, 0.4)
const FUMACA := Color(0.3, 0.33, 0.4)
const FUMACA_ESC := Color(0.16, 0.17, 0.22)
const TERRA := Color(0.36, 0.3, 0.25)
const BURACO := Color(0.1, 0.09, 0.1)
const FUNDO := Color(0.05, 0.05, 0.07)
const CHAMUSCA := Color(0.17, 0.14, 0.13)
const BRASA := Color(0.5, 0.88, 1.0)

static var _cache := {}  # os quadros já desenhados nesta sessão, pela chave dos tamanhos (desenhar custa ~0,5 s: uma vez só, não a cada partida)

var bola: Array = []  # [k] -> Texture2D
var cratera: Array = []  # [0] quente, [1] fria, [2..] esfarelando
var raio_bola := 84
var raio_cratera := 56
var cratera_dur := 4.0
var cratera_esfarela := 1.6
var cratera_quente := 0.6
var vel_onda := 2600.0

var no_bola: Node2D
var no_chao: Node2D
var centro := Vector2.ZERO
var t := -1.0  # s desde o estouro; < 0 = nada
var onda_max := 0.0  # raio (px, eixo x) em que a onda cobre a câmera inteira
var explosoes := 0  # testes
var _pulou_branco := false


func montar(glow: Node, mundo_no: Node, e: Dictionary, vel: float) -> void:
	raio_bola = maxi(8, int(e.get("bola", raio_bola)))
	var cr: Dictionary = e.get("cratera", {})
	raio_cratera = maxi(8, int(cr.get("raio", raio_cratera)))
	cratera_dur = maxf(0.5, float(cr.get("dur", cratera_dur)))
	cratera_esfarela = clampf(float(cr.get("esfarela", cratera_esfarela)), 0.1, cratera_dur)
	cratera_quente = clampf(float(cr.get("quente", cratera_quente)), 0.0, cratera_dur - cratera_esfarela)
	vel_onda = maxf(1.0, vel)
	if glow != null:
		no_bola = Node2D.new()
		no_bola.draw.connect(_desenhar_bola)
		glow.add_child(no_bola)
	if mundo_no != null:
		no_chao = Node2D.new()
		no_chao.z_index = -60
		no_chao.draw.connect(_desenhar_chao)
		mundo_no.add_child(no_chao)


## Desenha os quadros (ou pega do cache da sessão). O especial chama no `armar` do herói que tem a Autodestruição (o custo cai no começo da partida dele, não no
## estouro nem nos outros heróis); `explodir` chama também, por garantia.
func preparar() -> void:
	if not bola.is_empty():
		return
	var chave := "%d_%d" % [raio_bola, raio_cratera]
	if not _cache.has(chave):
		_gerar_bola()
		_gerar_cratera()
		_cache[chave] = [bola, cratera]
	bola = _cache[chave][0]
	cratera = _cache[chave][1]


## O estouro em `p` (onde o mecha ficou, no chão). `rect` = o retângulo que a limpeza cobre (câmera mais a margem): a onda vai até cobri-lo.
func explodir(p: Vector2, rect: Rect2) -> void:
	preparar()
	centro = p.round()
	t = 0.0
	_pulou_branco = Piscadas.ligado()
	onda_max = 0.0
	for k in 4:
		var canto := Vector2(rect.position.x if k % 2 == 0 else rect.end.x, rect.position.y if k < 2 else rect.end.y)
		var d := canto - centro
		onda_max = maxf(onda_max, Vector2(d.x, d.y / ACHATA).length())
	explosoes += 1
	_redesenhar()


func atualizar(dt: float) -> void:
	if t < 0.0:
		return
	t += dt
	if t >= cratera_dur and t >= _bola_dur():
		t = -1.0
	_redesenhar()


func limpar() -> void:
	t = -1.0
	_redesenhar()


func viva() -> bool:
	return t >= 0.0


func cratera_viva() -> bool:
	return quadro_cratera() >= 0


func _bola_dur() -> float:
	return float(BOLA_QUADROS - _salto()) / BOLA_FPS


## Quantos quadros do começo a bola pula: a fase branca inteira com "Reduzir piscadas", nenhum fora dele.
func _salto() -> int:
	return FASE_QUADROS if _pulou_branco else 0


## O quadro da bola agora (-1 = acabou ou nada).
func quadro_bola() -> int:
	if t < 0.0 or t >= _bola_dur():
		return -1
	return mini(BOLA_QUADROS - 1, int(t * BOLA_FPS) + _salto())


## O quadro da cratera agora (0 quente, 1 fria, 2.. esfarelando; -1 = nada).
func quadro_cratera() -> int:
	if t < 0.0 or t >= cratera_dur:
		return -1
	if t < cratera_quente:
		return 0
	var inicio := cratera_dur - cratera_esfarela
	if t < inicio:
		return 1
	return 2 + mini(CRATERA_ESFARELA - 1, int((t - inicio) / cratera_esfarela * float(CRATERA_ESFARELA)))


## O raio da onda no chão agora (px, eixo x); < 0 = já cobriu a câmera.
func raio_onda() -> float:
	if t < 0.0:
		return -1.0
	var r := t * vel_onda
	return r if r <= onda_max else -1.0


func _redesenhar() -> void:
	if no_bola != null:
		no_bola.queue_redraw()
	if no_chao != null:
		no_chao.queue_redraw()


func _desenhar_bola() -> void:
	var k := quadro_bola()
	if k >= 0:
		var tex: Texture2D = bola[k]
		no_bola.draw_texture(tex, centro + Vector2(-raio_bola, -raio_bola - BOLA_SOBE))


## O chão: a cratera e, por cima dela, a onda de 1 px (as duas embaixo dos monstros e do herói).
func _desenhar_chao() -> void:
	var k := quadro_cratera()
	if k >= 0:
		var tex: Texture2D = cratera[k]
		no_chao.draw_texture(tex, centro - Vector2(tex.get_width() / 2, tex.get_height() / 2))
	var r := raio_onda()
	if r > 0.0:
		var cor := CIANO_CLARO if r < onda_max * 0.5 else CIANO
		var n := maxi(24, int(TAU * r / ONDA_PASSO))
		var ultimo := Vector2.INF
		for i in n:
			var a := TAU * float(i) / float(n)
			var q := (centro + Vector2(cos(a) * r, sin(a) * r * ACHATA)).round()
			if q != ultimo:
				no_chao.draw_rect(Rect2(q, Vector2(2, 1)), cor)
				ultimo = q


# ------------------------------------------------------------------ os quadros (desenhados uma vez)


## Um número fixo em [0, 1) para o par (x, y) e a semente: a máscara do esfarelar e as bordas não mudam de quadro para quadro.
static func _h(x: int, y: int, s: int) -> float:
	var v := (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	v = (v ^ (v >> 13)) * 1274126177
	return float((v ^ (v >> 16)) & 0xFFFF) / 65536.0


## O raio da borda irregular no ângulo `a` (16 setores com valores fixos, interpolados): 1 +- `amp`.
static func _borda(a: float, amp: float, s: int) -> float:
	var f := (a + PI) / TAU * 16.0
	var i := int(floorf(f)) % 16
	var u := f - floorf(f)
	return 1.0 + amp * (lerpf(_h(i, 0, s), _h((i + 1) % 16, 0, s), u) * 2.0 - 1.0)


## Ruído de valor (grade de `passo` px, interpolado): as manchas de turbulência dentro da bola. Fixo para (x, y, s).
static func _ruido(x: float, y: float, s: int) -> float:
	var ix := int(floorf(x))
	var iy := int(floorf(y))
	var fx := x - floorf(x)
	var fy := y - floorf(y)
	var a := lerpf(_h(ix, iy, s), _h(ix + 1, iy, s), fx)
	var b := lerpf(_h(ix, iy + 1, s), _h(ix + 1, iy + 1, s), fx)
	return lerpf(a, b, fy)


## Os quadros da bola: começa pequena e branca com raios (o estalo; o hit-stop segura este quadro), abre com ease-out em manchas de ciano e azul (turbulência
## de ruído fixo, borda irregular de duas escalas), o miolo abre em anel e a fumaça cinza-azulada sobe e esfarela (máscara fixa por pixel: cada pixel some uma vez).
func _gerar_bola() -> void:
	bola.clear()
	var lado := raio_bola * 2 + 1
	var rb := float(raio_bola)
	# tabelas fixas (o que não muda de quadro para quadro), para desenhar em ~1/4 do tempo: a borda por ângulo, o ruído da turbulência,
	# o das manchas escuras e a máscara do esfarelar
	var n_borda := 512
	var tab_borda := PackedFloat32Array()
	tab_borda.resize(n_borda)
	for i in n_borda:
		var ang := float(i) / float(n_borda) * TAU - PI
		tab_borda[i] = _borda(ang, 0.16, 7) * _borda(ang * 2.0, 0.08, 8)
	var tab_v := PackedFloat32Array()
	tab_v.resize(lado * lado)
	for y in lado:
		for x in lado:
			tab_v[y * lado + x] = (_ruido(float(x) / 6.0, float(y) / 6.0, 41) - 0.5) * 0.45
	var tab_esc := PackedByteArray()
	var tab_hp := PackedFloat32Array()
	tab_esc.resize(lado * lado)
	tab_hp.resize(lado * lado)
	for y in lado:
		for x in lado:
			tab_esc[y * lado + x] = 1 if _ruido(float(x) / 4.0, float(y) / 4.0, 5) < 0.3 else 0
			tab_hp[y * lado + x] = _h(x, y, 3) * 0.75
	for k in BOLA_QUADROS:
		# A SILHUETA (muda a cada quadro): o raio que cresce, a fumaça que sobe, o miolo que abre, o esfarelar e os raios do estalo
		var tt := (float(k) + 0.5) / float(BOLA_QUADROS)
		var im := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
		var cresce := 1.0 - pow(1.0 - clampf(tt / 0.45, 0.0, 1.0), 3.0)
		var rr := rb * (0.3 + 0.7 * cresce) * 0.92
		var sobe := roundi(rb * 0.25 * clampf((tt - 0.4) / 0.6, 0.0, 1.0))  # a fumaça sobe um pouco (px inteiros)
		var oco := clampf((tt - 0.35) * 1.1, 0.0, 0.6)  # o miolo abre (o estouro vira anel e fumaça)
		var some := clampf((tt - 0.5) / 0.5, 0.0, 1.0) * 1.05  # a fração de pixels que já esfarelou
		var raios := 1.0 - clampf(tt / 0.25, 0.0, 1.0)  # os raios do estalo, só nos 5 primeiros quadros
		var alcance := rr * 1.26 * (1.0 + 0.9 * raios) + 1.0  # nenhum pixel passa disto (a borda irregular e os raios): o resto nem é calculado
		# O PADRÃO INTERNO (muda só a cada FASE_QUADROS quadros, pelo tempo do meio da fase): as faixas de cor e a fumaça
		var tp := (float(mini(k / FASE_QUADROS, FASES_COR - 1)) + 0.5) * float(FASE_QUADROS) / float(BOLA_QUADROS)
		var miolo := 0.5 - tp * 1.4  # o branco só na 1ª fase
		var claro := 0.72 - tp * 0.8
		var medio := 0.9 - tp * 0.45
		var fumo := 1.25 - clampf((tp - 0.3) / 0.35, 0.0, 1.0) * 1.4  # a fumaça entra de fora para dentro (v acima disto vira fumaça)
		var oco_cor := clampf((tp - 0.35) * 1.1, 0.0, 0.6)
		for y in lado:
			for x in lado:
				var dx := float(x) - rb
				var dy := float(y) - rb + float(sobe)
				var dist := sqrt(dx * dx + dy * dy)
				if dist > alcance:
					continue
				var a := atan2(dy, dx)
				var borda: float = tab_borda[clampi(int((a + PI) / TAU * float(n_borda)), 0, n_borda - 1)]
				var d := dist / maxf(rr * borda, 1.0)
				if d > 1.0:
					if raios > 0.0 and d < 1.0 + 0.9 * raios:
						var setor := floorf((a + PI) / TAU * 12.0)
						var meio := (setor + 0.5) / 12.0 * TAU - PI
						var larg := 0.09 * (1.0 - (d - 1.0) / (0.9 * raios)) * (0.6 + 0.8 * _h(int(setor), 4, 19))
						if absf(a - meio) < larg:
							im.set_pixel(x, y, BRANCO if k == 0 else CIANO_CLARO)
					continue
				if d < oco * borda:
					continue
				if tab_hp[y * lado + x] + (1.0 - d) * 0.25 < some:
					continue
				# a cor mede pelo raio FINAL, a partir do centro PARADO do quadro (disposição fixa na tela: o pixel só desce de claro para escuro, e o miolo não
				# desliza com a fumaça que sobe; só a silhueta sobe). Se o miolo subisse junto, a borda de cor atravessava uma janela de 16x16 px a cada quadro
				# e, com a troca de fase, dava dente de serra (2,7 Hz medido no vídeo).
				var dy0 := float(y) - rb
				var ang0 := atan2(dy0, dx)
				var borda0: float = tab_borda[clampi(int((ang0 + PI) / TAU * float(n_borda)), 0, n_borda - 1)]
				var dc := minf(sqrt(dx * dx + dy0 * dy0) / maxf(rb * 0.92 * borda0, 1.0), 1.0)
				var v: float = dc + tab_v[y * lado + x]
				var fumaca := v > fumo
				var cor: Color
				if v < miolo:
					cor = BRANCO
				elif v < claro:
					cor = CIANO_CLARO
				elif v < medio:
					cor = CIANO if not fumaca else FUMACA
				elif dc < 0.93:
					cor = AZUL if not fumaca else FUMACA_ESC
				else:
					cor = AZUL if not fumaca else AZUL_ESC
				if fumaca and dc > oco_cor + 0.08 and tab_esc[y * lado + x] == 1:
					cor = FUMACA_ESC
				im.set_pixel(x, y, cor)
		bola.append(ImageTexture.create_from_image(im))


func _gerar_cratera() -> void:
	cratera.clear()
	var rx := float(raio_cratera)
	var ry := rx * ACHATA
	var ext := 1.35  # as rachaduras e o chamuscado passam da borda
	var w := int(ceil(rx * ext)) * 2 + 1
	var hh := int(ceil(ry * ext)) * 2 + 1
	var cx := w / 2
	var cy := hh / 2
	# as rachaduras: pixels de linhas tortas do centro até ext * raio (fixas)
	var racha := {}
	for r in RACHAS:
		var ang := TAU * (float(r) + _h(r, 1, 9) * 0.6 - 0.3) / float(RACHAS)
		var comp := rx * lerpf(0.95, ext, _h(r, 2, 9))
		var q := Vector2.ZERO
		var passos := int(comp)
		for s in passos:
			if s % 6 == 5:
				ang += (_h(r, s, 13) - 0.5) * 0.7
			q += Vector2(cos(ang), sin(ang) * ACHATA)
			racha[Vector2i(roundi(q.x) + cx, roundi(q.y) + cy)] = float(s) / float(passos)
	var base := Image.create(w, hh, false, Image.FORMAT_RGBA8)
	var quente := Image.create(w, hh, false, Image.FORMAT_RGBA8)
	var dmap := {}
	for y in hh:
		for x in w:
			var dx := float(x - cx) / rx
			var dy := float(y - cy) / ry
			var a := atan2(dy, dx)
			var d := sqrt(dx * dx + dy * dy) / _borda(a, 0.1, 17)
			var cor := Color(0, 0, 0, 0)
			if d < 0.45:
				cor = FUNDO
			elif d < 0.82:
				cor = BURACO
			elif d < 1.0:
				cor = TERRA if _h(x, y, 21) < 0.85 else BURACO
			elif d < 1.25 and _h(x, y, 23) < lerpf(0.7, 0.0, (d - 1.0) / 0.25):
				cor = CHAMUSCA
			var rk := Vector2i(x, y)
			var em_racha := racha.has(rk)
			if em_racha and d >= 0.45:
				cor = FUNDO
			if cor.a == 0.0:
				continue
			base.set_pixel(x, y, cor)
			quente.set_pixel(x, y, BRASA if em_racha and d < 1.0 else cor)
			dmap[rk] = d
	cratera.append(ImageTexture.create_from_image(quente))
	cratera.append(ImageTexture.create_from_image(base))
	for k in CRATERA_ESFARELA:
		var limiar := 0.12 + 0.43 * float(k) / float(CRATERA_ESFARELA - 1)  # 0,12 .. 0,55: o último degrau ainda é o fundo inteiro (meio raio)
		var im := base.duplicate() as Image
		for rk in dmap:
			# de fora para dentro: a borda e o chamuscado esfarelam primeiro, o fundo por último. A distância pesa mais que o ruído para o miolo
			# continuar legível até o último degrau (com o ruído pesando 0,6 o último degrau virava pontos soltos e a cratera "sumia" ~0,7 s antes de acabar)
			var v := _h(rk.x, rk.y, 31) * 0.25 + (1.0 - clampf(float(dmap[rk]) / 1.25, 0.0, 1.0)) * 0.75
			if v < limiar:
				im.set_pixel(rk.x, rk.y, Color(0, 0, 0, 0))
		cratera.append(ImageTexture.create_from_image(im))
