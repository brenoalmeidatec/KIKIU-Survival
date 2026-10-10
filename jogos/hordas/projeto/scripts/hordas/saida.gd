extends Node2D
## Saída da fase (#112): com o chefe da fase morto abre-se um portal no chão, onde ele caiu. A fase só acaba quando o jogador
## quiser: ele entra no portal e segura CONFIRMAR (dados/prorrogacao.json: raio, segurar). Aí o herói é sugado pelo portal,
## vem o clarão branco e a cortina (Transicao) antes dos resultados e do mapa. Enquanto o portal está aberto a horda continua,
## mais leve (diretor.saida_leve), pra dar tempo de coletar.
## Solo: terminou de segurar e a sucção acabou, chama arena.fase_completa(). Online: cada um avisa o anfitrião ("saida") e fica
## parado no portal; o anfitrião (online.gd) manda "fase_completa" quando todos os vivos estão prontos (ou passou a espera).
## Os clientes só desenham o portal e mandam o próprio aviso; o formato da rede não mudou além do evento "saida_aberta".

var arena: Node
var aberta := false
var pos := Vector2.ZERO
var seg := 0.0               # quanto já segurou (0 a segurar)
var saindo := false          # a sucção começou
var bot_segurar := false     # teste de imagem: segura sozinho sem ser robô
var pronto := false          # online: já fui sugado e espero os outros
var _t := 0.0
var _suc := 0.0
var _flash := 0.0
var _cl := CanvasLayer.new()
var _cobre := ColorRect.new()
var _cl_dica := CanvasLayer.new()   # a dica "Segure CONFIRMAR" fica numa camada de tela, acima dos números de dano
var _dica := Control.new()


func _ready() -> void:
	z_index = 50   # o portal fica acima de inimigos, efeitos e baús (#123, #125)
	_cl.layer = 58
	_cl.process_mode = Node.PROCESS_MODE_ALWAYS
	_cobre.color = Color(1, 1, 1, 0)
	_cobre.size = Vector2(640, 360)
	_cobre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cl.add_child(_cobre)
	add_child(_cl)
	_cl_dica.layer = 8   # acima do mundo (números de dano, efeitos) e do HUD; abaixo das cartas, da loja e dos menus
	_dica.size = Vector2(640, 360)
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica.draw.connect(_desenhar_dica)
	_cl_dica.add_child(_dica)
	add_child(_cl_dica)


# ---------- funções puras (o teste usa) ----------

## Progresso de segurar: sobe com dt quando está dentro e segurando; senão desce rápido (soltou, não vale). Limitado a [0, total].
static func avancar(seg_atual: float, dentro: bool, segurando: bool, dt: float, total: float) -> float:
	if dentro and segurando:
		return minf(total, seg_atual + dt)
	return maxf(0.0, seg_atual - dt * 2.0)


static func dentro_do_portal(centro: Vector2, portal: Vector2, raio: float) -> bool:
	return centro.distance_to(portal) <= raio


static func cfg() -> Dictionary:
	return Dados.json("prorrogacao").get("saida", {})


# ---------- fluxo ----------

func abrir(p: Vector2) -> void:
	if aberta:
		return
	aberta = true
	pos = p
	seg = 0.0
	saindo = false
	pronto = false
	_t = 0.0
	queue_redraw()


## Fecha o portal e devolve o herói ao normal (nova fase, teste).
func fechar() -> void:
	aberta = false
	saindo = false
	pronto = false
	seg = 0.0
	_flash = 0.0
	_cobre.color.a = 0.0
	var j: Node2D = arena.jogador if arena else null
	if j and is_instance_valid(j):
		j.visible = true
		j.scale = Vector2.ONE
		j.rotation = 0.0
	queue_redraw()
	_dica.queue_redraw()


func _process(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt)
		_cobre.color.a = clampf(_flash / maxf(0.05, float(cfg().get("clarao", 0.35))), 0.0, 1.0)
	if not aberta:
		return
	_t += dt
	var j: Node2D = arena.jogador
	if pronto:
		j.position = pos   # parado no portal, escondido, esperando os outros
		j.invencivel = maxf(j.invencivel, 0.2)
	elif saindo:
		_succao(dt, j)
	elif not arena.caido and not arena.duelo_ativo:
		var dentro := dentro_do_portal(j.centro(), pos, float(cfg().get("raio", 34.0)))
		var segurando: bool = arena.bot or bot_segurar or Input.is_action_pressed("confirmar")
		seg = avancar(seg, dentro, segurando, dt, float(cfg().get("segurar", 1.0)))
		if seg >= float(cfg().get("segurar", 1.0)):
			saindo = true
			_suc = 0.0
			Som.tocar("plim", 0.05, 0.6)
	queue_redraw()
	_dica.queue_redraw()


## O herói é puxado pro centro do portal, encolhendo e girando; no fim o clarão e a cortina.
func _succao(dt: float, j: Node2D) -> void:
	_suc += dt
	var dur := maxf(0.1, float(cfg().get("succao", 0.8)))
	var p := clampf(_suc / dur, 0.0, 1.0)
	j.invencivel = maxf(j.invencivel, 0.5)
	j.position += (pos - j.centro()) * minf(1.0, dt * 9.0)
	j.scale = Vector2.ONE * (1.0 - p * p)
	j.rotation = p * TAU * 2.0
	if p >= 1.0:
		_terminou_succao(j)


func _terminou_succao(j: Node2D) -> void:
	j.visible = false
	j.scale = Vector2.ONE
	j.rotation = 0.0
	_flash = float(cfg().get("clarao", 0.35))
	_cobre.color.a = 1.0
	Transicao.revelar()   # o clarão abre na cortina de losangos
	pronto = true   # parado no portal, escondido, até a fase fechar (sem isso, o progresso cheio sugaria o herói de novo)
	saindo = false
	if arena.online:
		Rede.avisar("saida", 1.0)
	else:
		arena.fase_completa()


# ---------- desenho ----------

func _draw() -> void:
	if not aberta or pronto:
		return
	var pulso := 0.5 + 0.5 * sin(_t * 3.0)
	var r := 28.0 + 2.5 * pulso
	draw_circle(pos, r * 2.4, Color(0.35, 0.15, 0.7, 0.14))
	draw_circle(pos, r * 1.9, Color(0.4, 0.2, 0.8, 0.22))
	draw_circle(pos, r * 1.35, Color(0.45, 0.25, 0.9, 0.28))
	draw_circle(pos, r, Color(0.05, 0.02, 0.12, 0.95))
	draw_arc(pos, r + 1.0, 0.0, TAU, 40, Color(0.04, 0.02, 0.06, 0.85), 5.0)   # contorno escuro: lê em qualquer chão
	draw_arc(pos, r + 1.0, 0.0, TAU, 40, Color(0.85, 0.75, 1.0, 0.6 + 0.4 * pulso), 2.0)
	for i in 4:
		var a0 := _t * (1.6 + i * 0.5) * (1.0 if i % 2 == 0 else -1.0) + i * 1.3
		var rr := r * (1.0 - i * 0.18)
		var cor := Color(0.65, 0.5, 1.0, 0.9) if i % 2 == 0 else Color(0.4, 0.9, 1.0, 0.85)
		draw_arc(pos, rr, a0, a0 + PI * 1.3, 22, cor, 2.0)
	var hold := float(cfg().get("segurar", 1.0))
	if seg > 0.0:
		draw_arc(pos, r + 6.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(seg / hold, 0.0, 1.0), 40, Color(1, 0.9, 0.4), 3.0)
	# a dica ("Segure CONFIRMAR...") não é desenhada aqui: no mundo ela ficava por baixo dos números de dano e se misturava com eles.
	# Ela vai numa camada de tela (_dica, acima dos números e dos efeitos), com caixa escura e contorno: veja _desenhar_dica.


func _texto_dica() -> String:
	var perto: bool = arena != null and arena.jogador != null and dentro_do_portal(arena.jogador.centro(), pos, 140.0)
	return "SAIR DA FASE" if not perto else "Segure CONFIRMAR para sair"


## Posição da dica na tela (640x360): em cima do portal, mas sem sair da janela.
func posicao_dica() -> Vector2:
	var cam := Vector2.ZERO
	if arena != null and arena.get("camera") != null:
		cam = arena.camera.get_screen_center_position()
	var p := pos - cam + Vector2(320, 180) + Vector2(0, -50)
	return Vector2(clampf(p.x, 80.0, 560.0), clampf(p.y, 16.0, 344.0))


func _desenhar_dica() -> void:
	if not aberta or pronto or saindo:
		return
	var txt := _texto_dica()
	var fonte: Font = Dados.fonte
	var tam := int(round(8.0 * maxf(1.0, Config.fator_fonte() * 0.75)))
	var larg := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var p := posicao_dica()
	var caixa := Rect2((p + Vector2(-larg / 2.0 - 5.0, -tam - 2.0)).floor(), Vector2(larg + 10.0, tam + 7.0))
	_dica.draw_rect(caixa, Color(0.04, 0.02, 0.09, 0.82))
	_dica.draw_rect(caixa, Color(0.7, 0.55, 1.0, 0.8), false, 1.0)
	_dica.draw_string_outline(fonte, (p + Vector2(-larg / 2.0, 0)).floor(), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 3, Color(0.03, 0.01, 0.07, 1))
	_dica.draw_string(fonte, (p + Vector2(-larg / 2.0, 0)).floor(), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1.0, 0.97, 0.85))
