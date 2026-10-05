extends "res://minijogos/base.gd"
## Vírus: o celular do Seu Mauro tá cheio de janelinha que ele mesmo abriu sem querer.
## O cursor anda de quadradinho em quadradinho (setas); E fecha a janela embaixo dele.
## Janela de vírus aberta enche a memória; memória cheia = celular travou.
## Não feche o que é do Seu Mauro (zap da mãe, foto da neta, previsão do tempo).

const VIRUS := ["SOLTEIRAS NA ROCA", "GATINHAS A 2 KM ;)", "MORANGO TE ESPERA", "BAIXE MAIS RAM",
	"VC GANHOU 1 BOI!", "100 FIGURINHA FOFA", "GATINHO UWU ^_^", "KITTY TURBO 3000", "ACHE O AMOR AGORA",
	"VIDEO PROIBIDAO?", "CLIQUE AQUI, MATUTO", "PREMIO: 1 TRATOR"]
const DELE := ["ZAP: MAINHA", "FOTO DA NETA", "VAI CHOVER AMANHA", "LEMBRETE: REMEDIO"]
const COLS := 2
const LINS := 4
const CEL := Rect2(135, 8, 170, 182)   # tela do celular

var _janelas := {}     # Vector2i -> {texto, dele, vida}
var _cursor := Vector2i(1, 1)
var _memoria := 0.0
var _tempo := 0.0
var _duracao := 20.0
var _prox := 0.0
var _erros := 0
var _tremor := 0.0


func _init() -> void:
	musica = "minijogo_retro"
	titulo = "Tira o vírus!"
	instrucoes = "O celular do Seu Mauro tá cheio de janelinha estranha.\nSetas andam com o cursor, E fecha a janela.\nNão feche as coisas dele (zap da mainha, foto da neta...). Se a memória encher, travou."


func _comecar() -> void:
	_janelas.clear()
	_cursor = Vector2i(0, 1)
	_memoria = 0.0
	_tempo = 0.0
	_duracao = 15.0 + dificuldade * 5.0
	_prox = 0.4
	_erros = 0


func _celula(c: Vector2i) -> Rect2:
	var w := (CEL.size.x - 8) / COLS
	var h := (CEL.size.y - 26) / LINS
	return Rect2(CEL.position + Vector2(4 + c.x * w, 18 + c.y * h), Vector2(w - 3, h - 3))


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_tempo += delta
	_tremor = max(_tremor - delta, 0.0)
	if _tempo >= _duracao:
		vencer()
		return
	_prox -= delta
	if _prox <= 0.0:
		_prox = randf_range(0.6, 1.2) / (0.6 + dificuldade * 0.3)
		var livres: Array = []
		for x in COLS:
			for y in LINS:
				if not _janelas.has(Vector2i(x, y)):
					livres.append(Vector2i(x, y))
		if not livres.is_empty():
			var dele := randf() < 0.22
			_janelas[livres.pick_random()] = {"texto": (DELE if dele else VIRUS).pick_random(), "dele": dele, "vida": 3.5}
	for k in _janelas.keys():
		var j: Dictionary = _janelas[k]
		if j.dele:
			j.vida -= delta
			if j.vida <= 0.0:
				_janelas.erase(k)
		else:
			_memoria += delta * (0.045 + dificuldade * 0.015)
	if _memoria >= 1.0:
		perder("Memória cheia. O celular travou numa foto de gatinho de óculos escuro. O Seu Mauro achou lindo.")
		return
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	match acao_de(event):
		"cima": _cursor.y = posmod(_cursor.y - 1, LINS)
		"baixo": _cursor.y = posmod(_cursor.y + 1, LINS)
		"esquerda": _cursor.x = posmod(_cursor.x - 1, COLS)
		"direita": _cursor.x = posmod(_cursor.x + 1, COLS)
		"interagir":
			if not _janelas.has(_cursor):
				return
			var dele: bool = _janelas[_cursor].dele
			_janelas.erase(_cursor)
			if dele:
				_erros += 1
				_tremor = 0.35
				Jogo.som("erro")
				if _erros >= 3:
					perder("Fechou o zap da mainha três vezes. O Seu Mauro ficou sem saber se chove na roça.")
				return
			_memoria = max(_memoria - 0.06, 0.0)
			Jogo.som("acerto")
			return
		_:
			return
	Jogo.som("cursor")
	area.queue_redraw()


func _desenhar(a: Control) -> void:
	var tx := randf_range(-3, 3) if _tremor > 0.0 else 0.0
	var cel := CEL
	cel.position.x += tx
	# celular
	caixa(a, cel.grow(6), Color("2b2f3a"), Color("0d1030"))
	caixa(a, cel, Color("dfe6ff"))
	a.draw_rect(Rect2(cel.position, Vector2(cel.size.x, 12)), Color("2a2fa8"))
	texto(a, cel.position + Vector2(4, 10), "CELULAR DO MAURO", BRANCO, 8)
	# memória e tempo
	texto(a, Vector2(16, 30), "MEMORIA", CINZA)
	barra(a, Rect2(16, 36, 110, 8), 1.0 - _memoria, VERDE)
	texto(a, Vector2(16, 64), "TEMPO", CINZA)
	barra(a, Rect2(16, 70, 110, 8), 1.0 - _tempo / _duracao, AMARELO)
	texto(a, Vector2(16, 100), "ERROS", CINZA)
	for i in 3:
		a.draw_rect(Rect2(16 + i * 12, 106, 8, 8), VERMELHO if i < _erros else Color("3a3f6a"))
	texto(a, Vector2(318, 40), "Setas: cursor", CINZA)
	texto(a, Vector2(318, 54), Controles.tecla("interagir") + ": fechar", CINZA)
	for k in _janelas:
		var j: Dictionary = _janelas[k]
		var r := _celula(k)
		r.position.x += tx
		var dele: bool = j.dele
		caixa(a, r, Color("e9fbe9") if dele else Color("ffd8f0"), Color("0d1030"))
		a.draw_rect(Rect2(r.position, Vector2(r.size.x, 7)), Color("3a9a4a") if dele else Color("e0505a"))
		if not dele:
			texto(a, r.position + Vector2(r.size.x - 7, 7), "x", BRANCO, 8)
		var palavras: PackedStringArray = str(j.texto).split(" ")
		var linha := ""
		var y := r.position.y + 18
		for p in palavras:
			if (linha + " " + p).strip_edges().length() > 10 and linha != "":
				texto(a, Vector2(r.position.x + r.size.x / 2, y), linha, AZUL, 8, true)
				y += 10
				linha = p
			else:
				linha = (linha + " " + p).strip_edges()
		texto(a, Vector2(r.position.x + r.size.x / 2, y), linha, AZUL, 8, true)
	var rc := _celula(_cursor).grow(2)
	rc.position.x += tx
	a.draw_rect(rc, AMARELO, false, 2.0)
