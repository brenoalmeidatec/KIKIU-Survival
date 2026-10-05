extends "res://minijogos/base.gd"
## Descer a escada com o João: ele está passando mal, com o braço em volta do ombro do Breno.
## Vista de lado. Aparece uma tecla em cima dos dois: aperte ela antes do tempo acabar e
## vocês descem um degrau. Tecla errada ou atrasada = o João tropeça. 3 tropeços = perde.
## Quando aparecer E (RESPIRA!), é pra respirar junto com ele.
## Na cena:  !minijogo escada desceu 2     (parâmetros: "quem": "joao", "ajuda": "breno", "degraus": 10)

const FALAS := [
	"João: Ai... meu coração... não consigo respirar...",
	"João: Devagar, Breno! Devagar!",
	"João: Se eu morrer, diz pro meu filho... que o boleto vence dia 10.",
	"João: Acho que é o coração. Ou foi o acarajé.",
	"João: Tô vendo uma luz, Breno... ah não, é a lâmpada do corredor.",
	"Breno: Respira, véi. Inspira... expira...",
]
const TROPECOS := [
	"João: AAAI! Segura, Breno, segura!",
	"João: Tu quer me matar antes do coração, é?",
	"Breno: Foi mal, foi mal!",
]
const ESCALA := 2.0
const PASSO := Vector2(44, 16)       # cada degrau (já em dobro)
const TECLAS := ["baixo", "baixo", "esquerda", "direita", "baixo", "interagir"]

var quem := "joao"
var _degraus := 10
var _degrau := 0
var _anda := 0.0                    # 0..1 da animação de descer um degrau
var _pedido := ""                   # tecla que tem que apertar agora
var _tempo := 0.0                   # tempo que falta pra apertar
var _tempo_total := 1.0
var _espera := 0.0                  # pausinha antes da próxima tecla
var _tropecos := 0
var _balanco := 0.0                 # o João pendendo depois de um tropeço
var _fala := ""
var _fala_t := 0.0
var _aviso := ""
var _aviso_t := 0.0
var _aviso_cor := AMARELO
var _tremer := 0.0
var _t := 0.0
var _tex_b: Texture2D
var _tex_j: Texture2D


func _init() -> void:
	musica = "minijogo_tenso"
	titulo = "Descer com o João"
	instrucoes = "O João tá passando mal e desce apoiado no seu ombro.\nAparece uma tecla em cima de vocês: aperte ela antes do tempo acabar pra descer um degrau.\nSe aparecer E (RESPIRA!), respire junto com ele.\nTecla errada ou atrasada, ele tropeça. 3 tropeços e deu ruim."


func _ready() -> void:
	super._ready()
	quem = Roteiro.nome(str(params.get("quem", "joao")))
	_degraus = int(params.get("degraus", 10))
	_tex_b = Dados.textura(str(params.get("ajuda", "breno")), "andando_8")
	_tex_j = Dados.textura(quem, "andando_8")


func _comecar() -> void:
	_degrau = 0
	_anda = 0.0
	_tropecos = 0
	_balanco = 0.0
	_t = 0.0
	_pedido = ""
	_espera = 0.8
	_dizer(FALAS[0])


func _dizer(s: String) -> void:
	_fala = s
	_fala_t = 3.0


func _avisar(s: String, cor := AMARELO) -> void:
	_aviso = s
	_aviso_cor = cor
	_aviso_t = 0.9


func _nova_tecla() -> void:
	var k: String = TECLAS[randi() % TECLAS.size()]
	if _degrau == 0:
		k = "baixo"
	_pedido = k
	_tempo_total = [1.7, 1.35, 1.05][dificuldade - 1] + (0.3 if k == "interagir" else 0.0)
	_tempo = _tempo_total
	if k == "interagir":
		_dizer("João: *hic* ... *snif* ... não consigo...")
		Jogo.som("tremor", -10.0)


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_t += delta
	_fala_t -= delta
	_aviso_t -= delta
	_tremer = max(_tremer - delta, 0.0)
	_balanco = move_toward(_balanco, 0.0, delta * 0.8)
	if _anda > 0.0:
		_anda = min(_anda + delta / 0.4, 1.0)
		if _anda >= 1.0:
			_anda = 0.0
			_degrau += 1
			if _degrau >= _degraus:
				vencer()
				return
			if _degrau % 3 == 0:
				_dizer(FALAS[1 + (_degrau / 3 - 1) % 4])
			_espera = 0.25
	elif _pedido == "":
		_espera -= delta
		if _espera <= 0.0:
			_nova_tecla()
	else:
		_tempo -= delta
		if _tempo <= 0.0:
			_errou("Demorou!")
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	var a := acao_de(event)
	if a == "" or a == "voltar":
		return
	if _pedido == "" or _anda > 0.0:
		Jogo.som("cursor", -12.0)
		return
	if a == _pedido:
		var k := _pedido
		_pedido = ""
		_anda = 0.001
		if k == "interagir":
			_avisar("Respirou junto!", VERDE)
			_dizer(FALAS[5])
			Jogo.som("acerto", -4.0)
		else:
			_avisar(["Boa!", "Isso!", "Devagar e sempre!"][randi() % 3], VERDE)
			Jogo.som("passo", -2.0, 0.1)
	else:
		_errou("Tecla errada!")


func _errou(motivo: String) -> void:
	_pedido = ""
	_tropecos += 1
	_tremer = 0.45
	_balanco = 1.0
	_espera = 1.0
	Jogo.som("queda", -2.0)
	_avisar(motivo, VERMELHO)
	if _tropecos >= 3:
		perder("Os dois sentaram no degrau e ficaram lá. Um aluno passou e perguntou se era fila pra cantina.")
		return
	_dizer(TROPECOS[(_tropecos - 1) % TROPECOS.size()])


## Onde fica o pé de quem está no degrau i (em pixels da área, antes da câmera).
func _pos_degrau(i: float) -> Vector2:
	return Vector2(i * PASSO.x, i * PASSO.y)


func _desenhar(a: Control) -> void:
	var sac := Vector2(randf_range(-2, 2), randf_range(-2, 2)) if _tremer > 0.0 else Vector2.ZERO
	var f := float(_degrau) + _anda
	# a câmera acompanha os dois: o pé fica sempre no mesmo lugar da tela
	var cam := Vector2(170, 150) - _pos_degrau(f) + sac
	a.draw_rect(Rect2(0, 0, 440, 196), Color("3a4466"))
	var px := fposmod(cam.x * 0.5, 64.0)
	for k in range(-1, 9):
		a.draw_rect(Rect2(px + k * 64, 0, 2, 196), Color("262b44"))
	# degraus (desce pra direita), com o patamar no fim e a placa do pátio
	for i in range(-4, _degraus + 6):
		var p := _pos_degrau(i) + cam
		if p.x - PASSO.x > 460:
			break
		var largura := PASSO.x + 1 if i < _degraus else 400.0
		var y := p.y if i <= _degraus else _pos_degrau(_degraus).y + cam.y
		a.draw_rect(Rect2(p.x - PASSO.x * 0.5, y, largura, 260), Color("8b9bb4"))
		a.draw_rect(Rect2(p.x - PASSO.x * 0.5, y, largura, 3), Color("c0cbdc"))
		a.draw_rect(Rect2(p.x - PASSO.x * 0.5, y + 3, 2, PASSO.y), Color("5a6988"))
	var fim := _pos_degrau(_degraus) + cam
	a.draw_rect(Rect2(fim.x + 40, fim.y - 70, 60, 18), Color("265c42"))
	texto(a, Vector2(fim.x + 70, fim.y - 57), "PÁTIO >", BRANCO, 8, true)
	# corrimão
	for i in range(-4, _degraus + 1, 2):
		var p := _pos_degrau(i) + cam + Vector2(-PASSO.x * 0.5, 0)
		a.draw_line(p, p + Vector2(0, -58), Color("c28569"), 2.0)
	var c0 := _pos_degrau(-4) + cam + Vector2(-PASSO.x * 0.5, -58)
	var c1 := _pos_degrau(_degraus) + cam + Vector2(-PASSO.x * 0.5, -58)
	a.draw_line(c0, c1, Color("feae34"), 3.0)
	# os dois: o João atrás, curvado, com o braço por cima do ombro do Breno
	var pe := _pos_degrau(f) + cam
	var quadro := (1 + int(_anda * 8.0) % 8) if _anda > 0.0 else 0
	var dor := sin(_t * 3.0) * 0.03 + 0.15 + _balanco * sin(_t * 18.0) * 0.12
	var pe_j := pe + Vector2(-20, -2)
	var pe_b := pe + Vector2(10, 0)
	_boneco(a, _tex_j, pe_j, quadro, dor, Color(0.88, 0.88, 0.92))
	_boneco(a, _tex_b, pe_b, quadro, 0.0, Color.WHITE)
	# braço do João: do ombro dele até o ombro da frente do Breno
	var ombro_j := pe_j + Vector2(3, -27 * ESCALA).rotated(dor)
	var ombro_b := pe_b + Vector2(3, -26 * ESCALA)
	var meio := (ombro_j + ombro_b) / 2.0 + Vector2(0, -3)
	a.draw_line(ombro_j, meio, Color("1f4fa8"), 6.0)
	a.draw_line(meio, ombro_b, Color("1f4fa8"), 6.0)
	a.draw_line(meio + Vector2(0, 3), ombro_b + Vector2(-3, 3), Color("163a80"), 2.0)
	a.draw_rect(Rect2(ombro_b + Vector2(-1, -3), Vector2(7, 7)), Color("8d5524"))
	a.draw_rect(Rect2(ombro_b + Vector2(4, -1), Vector2(2, 6)), Color("6e3f1a"))
	# tecla pedida, em cima dos dois, com o tempo correndo em volta
	if _pedido != "":
		var centro := pe + Vector2(-4, -128)
		var frac := clampf(_tempo / _tempo_total, 0.0, 1.0)
		var pulso := 1.0 + sin(_t * 12.0) * 0.06
		a.draw_arc(centro, 24, -PI / 2, -PI / 2 + TAU * frac, 32, AMARELO if frac > 0.35 else VERMELHO, 4.0)
		var qual := _pedido if _pedido != "interagir" else Controles.tecla("interagir")
		tecla_desenho(a, centro, qual, 30.0 * pulso, BRANCO, Color("a22633") if _pedido == "interagir" else Color("2a2fa8"))
		if _pedido == "interagir":
			texto(a, centro + Vector2(44, 4), "RESPIRA!", AMARELO, 8)
	# placar
	texto(a, Vector2(8, 16), "DEGRAU %d / %d" % [_degrau, _degraus], BRANCO)
	texto(a, Vector2(8, 30), "TROPEÇOS " + ["", "X", "X X", "X X X"][mini(_tropecos, 3)], VERMELHO)
	if _aviso_t > 0.0:
		texto(a, Vector2(330, 40), _aviso, _aviso_cor, 8, true)
	if _fala_t > 0.0:
		a.draw_rect(Rect2(6, 170, 428, 22), Color(0.05, 0.06, 0.15, 0.85))
		texto(a, Vector2(12, 185), _fala, BRANCO, 8)


## Boneco de lado (folha de andar, linha "direita"), em dobro, girado pelo pé.
func _boneco(a: Control, tex: Texture2D, pe: Vector2, quadro: int, giro: float, cor: Color) -> void:
	if tex == null:
		return
	var colunas := 9 if tex.get_width() >= 396 else 4
	var w := tex.get_width() / colunas
	var h := tex.get_height() / 4
	var reg := Rect2((quadro % colunas) * w, 2 * h, w, h)
	a.draw_set_transform(pe, giro, Vector2(ESCALA, ESCALA))
	a.draw_texture_rect_region(tex, Rect2(-w / 2.0, -h + 1, w, h), reg, cor)
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
