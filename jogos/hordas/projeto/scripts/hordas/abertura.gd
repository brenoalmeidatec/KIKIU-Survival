extends CanvasLayer
## Abertura da fase: a entrada cinematográfica do herói no mundo (dados/entrada.json, com a explicação de cada chave).
## Região nova (e começo da corrida): ~3,8 s, tarjas de cinema, a câmera desce de cima, o herói cai numa coluna de luz,
## o pouso racha o chão (onda de choque, brasas, flash, tremida) e o nome da região bate na tela letra por letra.
## Andar comum: a versão curta (~2 s) com uma faixa. Durante a abertura o herói fica invulnerável e parado, e o diretor,
## os inimigos e o relógio da fase esperam (arena.gd consulta heroi_preso() e mundo_preso()). Confirmar ou Esc pula.
## Só desenho barato: retângulos, uns arcos e ~40 brasas; nada de shader. Tempo = o do jogo (pausa congela junto).

const Regioes := preload("res://scripts/hordas/regioes.gd")
const W := 640.0
const H := 360.0
const MIN_QUEDA := 0.65  # = Visual.CHEGADA_POUSO: em que ponto da queda o herói encosta no chão

var arena: Node
var _tela := Control.new()
var _modo := ""  # "" = parada, "regiao" ou "andar"
var _c: Dictionary = {}  # configuração do modo atual (entrada.json)
var _tema: Dictionary = {}
var _t := 0.0  # relógio visual (pular adianta ele)
var _t_nat := 0.0  # relógio "natural": nunca pula (o online segura o mundo por ele)
var _fim := 0.0
var _pulou := false
var _apos := 0.0  # segundos desde que pulou
var _sem_titulo := false  # pulou antes do título entrar: ele nem aparece
var _caiu := false
var _bateu := false
var _t_bat := 0.0
var _liberou := false
var _kicker := ""
var _titulo := ""
var _sub := ""
var _cor_t := Color.WHITE
var _cor_b := Color.WHITE
var _cor_f := Color.WHITE
var _neve := false
var _chefe := false
var _escondidos: Array = []  # avatares do online que esta abertura escondeu (só esses voltam a aparecer)


func _ready() -> void:
	layer = 7
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


# ---------- o que a arena pergunta ----------


## A abertura está passando (visual).
func ativa() -> bool:
	return _modo != ""


## O herói ainda não manda (sem mexer, atacar, apanhar). Pular libera na hora.
func heroi_preso() -> bool:
	return _modo != "" and not _pulou and _t < float(_c.libera)


## O mundo espera (diretor, inimigos, relógio). No online segue o relógio natural: pular só adianta o seu herói.
func mundo_preso() -> bool:
	if _modo == "":
		return false
	if arena.eh_online:
		return _t_nat < float(_c.libera)
	return heroi_preso()


func duracao() -> float:
	return float(_c.get("duracao", 0.0))


func libera() -> float:
	return float(_c.get("libera", 0.0))


static func _cfg() -> Dictionary:
	return Dados.json("entrada")


## Começa a abertura do andar idx. Devolve false (e não faz nada) se ela não deve tocar: arena sem a opção
## (robô, teste, captura sem --entrada), desligada em entrada.json ou em duelo. Quem chama anuncia a fase do jeito antigo.
func comecar(idx: int, marca := "") -> bool:
	_parar()
	if arena == null or not arena.com_abertura or arena.duelo_ativo or arena.acabou:
		return false
	var cfg := _cfg()
	if cfg.is_empty() or not bool(cfg.get("ligada", true)):
		return false
	var fs: Array = arena.diretor.fases()
	var f: Dictionary = fs[clampi(idx, 0, fs.size() - 1)]
	var com_regiao := f.has("regiao")
	var nova_regiao: bool = (int(f.get("andar_regiao", 0)) == 0) if com_regiao else idx == 0
	_modo = "regiao" if nova_regiao else "andar"
	_c = cfg.get(_modo, {})
	if _c.is_empty():
		_modo = ""
		return false
	var rid := str(Regioes.regiao(int(f.regiao)).get("id", "")) if com_regiao else ""
	var padrao: Dictionary = cfg.get("padrao", {})
	_tema = cfg.get("tema", {}).get(rid, padrao)
	_cor_t = _cor(_tema.get("titulo", padrao.get("titulo", [1, 1, 1])))
	_cor_b = _cor(_tema.get("brasa", padrao.get("brasa", [1, 1, 1])))
	_cor_f = _cor(_tema.get("faixa", padrao.get("faixa", [1, 1, 1])))
	_neve = bool(_tema.get("neve", false))
	_chefe = bool(f.get("chefe_regiao", false))
	var elite := marca.strip_edges() != ""
	var k := Regioes.por_regiao() if com_regiao else 0
	if _modo == "regiao":
		if com_regiao:
			_kicker = "REGIÃO %d DE %d" % [int(f.regiao) + 1, Regioes.n()]
			_titulo = str(f.get("regiao_nome", "")).to_upper()
			_sub = str(Regioes.regiao(int(f.regiao)).get("descricao", ""))
		else:
			_kicker = "FASE %d" % (idx + 1)
			_titulo = str(f.get("nome", "")).to_upper()
			_sub = ""
	else:
		_titulo = str(f.get("nome", "")).to_upper()
		if _chefe:
			_kicker = "CHEFE DA REGIÃO"
		elif com_regiao:
			_kicker = "FASE %d DE %d" % [int(f.andar_regiao) + 1, k]
		else:
			_kicker = "FASE %d" % (idx + 1)
		if elite:
			_kicker += "  -  ELITE"
		_sub = ""
	if _chefe or elite:
		_cor_t = Color(1.0, 0.55, 0.45) if not _chefe else Color(1.0, 0.45, 0.4)
		_cor_f = Color(0.9, 0.2, 0.25)
	_t = 0.0
	_t_nat = 0.0
	_fim = float(_c.duracao)
	_pulou = false
	_caiu = false
	_bateu = false
	_liberou = false
	arena.jogador.visible = false
	arena.jogador._ent_t = 0.0
	arena.jogador._nome_t = 0.0
	if arena.online:
		for av in arena.online.avatares.values():
			if av.visible:
				av.visible = false
				_escondidos.append(av)
	arena.hud.visible = false
	Som.tocar("tremor", 0.0, 0.55, -7)  # o ronco que antecede a chegada
	_tela.queue_redraw()
	return true


static func _cor(a) -> Color:
	var v: Array = a if a is Array else [1, 1, 1]
	return Color(float(v[0]), float(v[1]), float(v[2]))


## Para tudo e devolve o que a abertura escondeu (herói, HUD, avatares).
func _parar() -> void:
	if _modo == "" and _escondidos.is_empty():
		return
	_modo = ""
	if arena and is_instance_valid(arena.jogador):
		arena.jogador.visible = true
	if arena and is_instance_valid(arena.hud):
		arena.hud.visible = true
	for av in _escondidos:
		if is_instance_valid(av):
			av.visible = true
	_escondidos.clear()
	_tela.queue_redraw()


## Pula: o herói assume na hora, as tarjas saem e o resto some em um instante.
func pular() -> void:
	if _modo == "" or _pulou:
		return
	_pulou = true
	_apos = 0.0
	_sem_titulo = _t < float(_c.titulo_em)
	_garantir_heroi()
	var saida: float = float(_c.libera) - 0.3
	if _t < saida:
		_t = saida  # a câmera volta de vez ao herói (corte) e as tarjas saem
	else:
		_t = float(_c.duracao)
	_fim = _t + 0.3
	arena.hud.visible = true
	_solta()


func _input(e: InputEvent) -> void:
	if _modo == "" or _pulou or get_tree().paused or e is InputEventMouseMotion:
		return
	if e.is_echo():
		return
	if e.is_action_pressed("confirmar") or e.is_action_pressed("voltar"):
		get_viewport().set_input_as_handled()  # o Esc que pula não abre a pausa junto
		pular()


## O herói e os aliados visíveis e de pé no chão (quando a queda não chegou a rolar).
func _garantir_heroi() -> void:
	var j = arena.jogador
	j.visible = true
	if j._ent_t > 0.0 or not _caiu:
		j._ent_t = 0.0
		j.spr.position.y = 0.0
	for av in _escondidos:
		if is_instance_valid(av):
			av.visible = true
	_escondidos.clear()
	for av in arena.online.avatares.values() if arena.online else []:
		av._ent_t = 0.0


func _solta() -> void:
	if _liberou:
		return
	_liberou = true
	arena.jogador.invencivel = maxf(arena.jogador.invencivel, float(_cfg().get("invulneravel_extra", 0.8)))


func _process(dt: float) -> void:
	if _modo == "":
		return
	if arena.acabou:
		_parar()
		return
	if _pulou:
		_apos += dt
	_t += dt
	_t_nat += dt
	var q: Dictionary = _c.queda
	if not _caiu and _t >= float(q.inicio) and not _pulou:
		_caiu = true
		arena.jogador.visible = true
		arena.jogador.entrar(str(arena.heroi.get("nome", arena.heroi_id)), float(q.duracao), float(q.altura))
		for av in _escondidos:
			if is_instance_valid(av):
				av.visible = true
				av.entrar()
		_escondidos.clear()
		Som.tocar("whoosh", 0.0, 0.6, -2)
	if not _bateu and _t >= _t_pouso() and not _pulou:
		_bateu = true
		_t_bat = _t
		arena.tremer(float(_c.tremor))
		Som.tocar("tremor", 0.0, 1.0, -1)
		Som.tocar("soco", 0.0, 0.6, -2)
		var pe: Vector2 = arena.jogador.position
		if arena.efeitos:
			arena.efeitos.explodir(pe + Vector2(0, -2), _cor_b, 22 if _modo == "regiao" else 10, 170.0)
			arena.efeitos.explodir(pe + Vector2(0, -2), Color(0.85, 0.8, 0.7), 12, 120.0)
	if _modo == "regiao" and not _pulou and _t >= float(_c.titulo_em) and _t - dt < float(_c.titulo_em):
		Som.tocar("soco", 0.0, 0.8, -4)
	if heroi_preso() or mundo_preso():
		arena.jogador.invencivel = maxf(arena.jogador.invencivel, 0.3)
	if not heroi_preso():
		if not _liberou:
			_garantir_heroi()
			arena.hud.visible = true
		_solta()
	if _t >= _fim and (not arena.eh_online or _t_nat >= float(_c.libera)):
		_parar()
		return
	_tela.queue_redraw()


func _t_pouso() -> float:
	return float(_c.queda.inicio) + MIN_QUEDA * float(_c.queda.duracao)


# ---------- câmera ----------


## A câmera desce de cima até o herói (só antes do fim do guindaste; pular corta pro herói).
func camera(foco: Vector2) -> Vector2:
	if _modo == "" or _pulou:
		return foco
	var g: Dictionary = _c.guindaste
	var x := clampf(_t / float(g.ate), 0.0, 1.0)
	var k := 1.0 - pow(1.0 - x, 3.0)
	return foco + Vector2(float(g.dx), float(g.dy)) * (1.0 - k)


# ---------- desenho ----------


static func _suave(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _txt(p: Vector2, s: String, tam: int, cor: Color, larg := -1.0, borda := true, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var f: Font = Dados.fonte
	var a := cor.a
	if borda:
		var o := maxi(1, tam / 16)
		for d in [Vector2(-o, 0), Vector2(o, 0), Vector2(0, -o), Vector2(0, o)]:
			_tela.draw_string(f, p + d, s, alinhar, larg, tam, Color(0.04, 0.0, 0.06, a))
	_tela.draw_string(f, p + Vector2(maxi(1, tam / 10), maxi(1, tam / 8)), s, alinhar, larg, tam, Color(0, 0, 0, a * 0.7))
	_tela.draw_string(f, p, s, alinhar, larg, tam, cor)


func _desenhar() -> void:
	if _modo == "" or arena == null:
		return
	var t := _t
	var lib := float(_c.libera)
	var dur := float(_c.duracao)
	var saida := 1.0 - _suave((t - (lib - 0.3)) / 0.4)  # as tarjas saem um pouco antes de liberar
	var env := _suave(t / maxf(0.05, float(_c.barras_entra))) * saida
	# mundo escuro que clareia até o pouso, mais o fade do preto do começo
	var esc := float(_c.escuro) * (1.0 - _suave(t / _t_pouso())) * saida
	var preto := (1.0 - _suave(t / maxf(0.05, float(_c.preto)))) if float(_c.preto) > 0.0 else 0.0
	var fundo := maxf(esc, preto)
	if fundo > 0.01:
		_tela.draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.0, 0.05, fundo))
	_brasas(t, env)
	if _bateu:
		_onda(t - _t_bat)
	# título e faixa
	var tit_a := 1.0 - _suave((t - float(_c.titulo_some)) / 0.3)
	if _pulou:
		tit_a = 0.0 if _sem_titulo else tit_a * (1.0 - _suave(_apos / 0.15))
	if tit_a > 0.01 and t >= float(_c.titulo_em) - 0.05:
		if _modo == "regiao":
			_titulo_regiao(t, tit_a)
		else:
			_faixa_andar(t, tit_a)
	# flash branco do pouso
	if _bateu:
		var fa := float(_c.flash) * (1.0 - clampf((t - _t_bat) / 0.2, 0.0, 1.0))
		if fa > 0.01:
			_tela.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, fa))
	# tarjas de cinema
	var b := float(_c.barras) * env
	if b > 0.5:
		_tela.draw_rect(Rect2(0, 0, W, b), Color(0, 0, 0, 0.96))
		_tela.draw_rect(Rect2(0, H - b, W, b), Color(0, 0, 0, 0.96))
		_tela.draw_rect(Rect2(0, b, W, 1), Color(_cor_f, 0.7 * env))
		_tela.draw_rect(Rect2(0, H - b - 1, W, 1), Color(_cor_f, 0.7 * env))
		if not _pulou and env > 0.95 and t > 0.6:
			_txt(Vector2(0, H - b + 12), str(_cfg().get("pular_rotulo", "ENTER/ESC: PULAR")), 8, Color(0.75, 0.75, 0.85, 0.7), W - 12.0, false)


func _brasas(t: float, env: float) -> void:
	var n := int(_c.brasas)
	if n <= 0:
		return
	var cima := -1.0 if not _neve else 1.0
	for i in n:
		var h1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(i * 78.233) * 12345.678, 1.0)
		var h3 := fposmod(sin(i * 39.346) * 24634.634, 1.0)
		var vel := 16.0 + 46.0 * h2
		var y := fposmod(h1 * (H + 20.0) + cima * vel * t, H + 20.0) - 10.0
		var x := h3 * W + sin(t * 1.4 + i) * 7.0
		var a := env * (0.35 + 0.65 * absf(sin(t * 3.0 + i * 1.7)))
		var s := 2.0 if h2 > 0.55 else 1.0
		_tela.draw_rect(Rect2(floorf(x), floorf(y), s, s), Color(_cor_b, a))


## Onda de choque no chão em volta dos pés do herói (anéis achatados + riscos de impacto), k segundos depois do pouso.
func _onda(k: float) -> void:
	var raio := float(_c.onda)
	if k > 0.7:
		return
	var pe: Vector2 = get_viewport().get_canvas_transform() * (arena.jogador.global_position + Vector2(0, -2))
	_tela.draw_set_transform(pe, 0.0, Vector2(1.0, 0.42))
	for j in 2:
		var kk := clampf((k - j * 0.1) / 0.5, 0.0, 1.0)
		if kk <= 0.0 or kk >= 1.0:
			continue
		var e := 1.0 - pow(1.0 - kk, 2.5)
		var cor := Color(1, 1, 1, 0.85 * (1.0 - kk)) if j == 0 else Color(_cor_b, 0.8 * (1.0 - kk))
		_tela.draw_arc(Vector2.ZERO, 8.0 + raio * e, 0.0, TAU, 56, cor, 5.0 * (1.0 - kk) + 1.0)
	var kl := clampf(k / 0.3, 0.0, 1.0)
	if kl < 1.0:
		var e2 := 1.0 - pow(1.0 - kl, 2.0)
		for i in 14:
			var ang := i * TAU / 14.0 + 0.2
			var d := Vector2.from_angle(ang)
			_tela.draw_line(d * (10.0 + raio * 0.45 * e2), d * (10.0 + raio * 0.45 * e2 + 30.0 * (1.0 - kl)), Color(1, 1, 1, 0.8 * (1.0 - kl)), 2.0)
	_tela.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _titulo_regiao(t: float, a: float) -> void:
	var em := float(_c.titulo_em)
	var tam := int(_c.tamanho) if _titulo.length() * int(_c.tamanho) <= 600 else 24
	var y0 := 62.0
	var banda := _suave((t - em + 0.3) / 0.25) * a
	_tela.draw_rect(Rect2(0, y0, W, 80), Color(0.04, 0.0, 0.07, 0.62 * banda))
	var larg := W * _suave((t - em + 0.25) / 0.35)
	_tela.draw_rect(Rect2((W - larg) / 2.0, y0, larg, 2), Color(_cor_f, a))
	_tela.draw_rect(Rect2((W - larg) / 2.0, y0 + 78, larg, 2), Color(_cor_f, a))
	# subtítulo da região na faixa do meio: "REGIÃO 2 DE 5" aparece antes do pouso, em cima da faixa
	var ka := _suave((t - 0.45) / 0.3) * a
	if ka > 0.01:
		_txt(Vector2(0, y0 + 16), _kicker, 8, Color(_cor_f.lightened(0.45), ka), W, false)
	# letras batendo uma por uma
	var n := _titulo.length()
	var atraso := float(_c.letra_atraso)
	var x0 := (W - n * tam) / 2.0
	var base := y0 + 52.0
	var todas := (t - em) > n * atraso + 0.2
	if todas:
		_txt(Vector2(0, base), _titulo, tam, Color(_cor_t, a), W)
	else:
		for i in n:
			var k := clampf((t - em - i * atraso) / 0.14, 0.0, 1.0)
			if k <= 0.0 or _titulo[i] == " ":
				continue
			var dy := -pow(1.0 - k, 2.0) * 16.0
			_txt(Vector2(x0 + i * tam, base + dy), _titulo[i], tam, Color(_cor_t, k * a), -1.0, true, HORIZONTAL_ALIGNMENT_LEFT)
	# faixa de luz que varre o título no impacto
	var kv := (t - em) / 0.3
	if kv > 0.0 and kv < 1.0:
		_tela.draw_rect(Rect2(-80.0 + (W + 160.0) * kv, y0 + 14, 46, 50), Color(1, 1, 1, 0.22 * (1.0 - kv) * a))
	# descrição, digitada
	if _sub != "":
		var sa := int(maxf(0.0, (t - em - 0.3) * 100.0))
		var txt := _sub.substr(0, mini(sa, _sub.length()))
		if txt != "":
			_txt(Vector2(0, y0 + 71), txt, 8, Color(0.88, 0.88, 0.98, a), W, false)


func _faixa_andar(t: float, a: float) -> void:
	var em := float(_c.titulo_em)
	var y0 := 74.0
	var w := W * _suave((t - em) / 0.25)
	_tela.draw_rect(Rect2(0, y0, w, 40), Color(0.04, 0.0, 0.07, 0.7 * a))
	_tela.draw_rect(Rect2(0, y0, w, 2), Color(_cor_f, a))
	_tela.draw_rect(Rect2(0, y0 + 38, w, 2), Color(_cor_f, a))
	var dx := (1.0 - _suave((t - em) / 0.25)) * -90.0
	_txt(Vector2(dx, y0 + 15), _kicker, 8, Color(_cor_f.lightened(0.5), a), W, false)
	var tam := int(_c.tamanho) if _titulo.length() * int(_c.tamanho) <= 600 else 8
	_txt(Vector2(-dx, y0 + 33), _titulo, tam, Color(_cor_t, a), W)
