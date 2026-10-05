extends "res://minijogos/base.gd"
## Conserte o PC: aparece o defeito, escolha a peça certa antes do tempo acabar.
## Na cena dá pra trocar os defeitos: "casos": [{"sintoma": "...", "peca": "fonte"}, ...]
## Peças: fonte, ram, ssd, rede, cooler, video, teclado, mouse.

const PECAS := [
	{"id": "fonte", "nome": "Fonte"}, {"id": "ram", "nome": "Memória"},
	{"id": "ssd", "nome": "SSD"}, {"id": "rede", "nome": "Rede"},
	{"id": "cooler", "nome": "Cooler"}, {"id": "video", "nome": "Vídeo"},
	{"id": "teclado", "nome": "Teclado"}, {"id": "mouse", "nome": "Mouse"},
]
const CASOS := [
	{"sintoma": "Não liga. Nem com reza.", "peca": "fonte"},
	{"sintoma": "Tela azul a cada cinco minutos.", "peca": "ram"},
	{"sintoma": "SSD de 500GB lotado. Ninguém sabe de quê.", "peca": "ssd"},
	{"sintoma": "Sem internet. Só esse PC da sala.", "peca": "rede"},
	{"sintoma": "Faz barulho de avião decolando.", "peca": "cooler"},
	{"sintoma": "Imagem cheia de risquinho colorido.", "peca": "video"},
	{"sintoma": "A tecla A não funciona.", "peca": "teclado"},
	{"sintoma": "A setinha não sai do lugar.", "peca": "mouse"},
]
const ERROS := ["Trocou e... continua igual.", "O professor olhou feio.", "Fez até fumaça. Era outra coisa.",
	"Nada. O PC te ignora.", "Quase! (mentira, nem perto)"]

var _casos: Array = []
var _rodada := 0
var _sel := 0
var _vidas := 3
var _tempo := 0.0
var _tempo_max := 12.0
var _aviso := ""
var _aviso_cor := BRANCO
var _aviso_t := 0.0
var _t := 0.0


func _init() -> void:
	titulo = "Conserte o PC"
	instrucoes = "Os PCs do laboratório estão dando defeito.\nLeia o problema e escolha a peça certa (setas + E) antes do tempo acabar.\nErrou demais, perdeu."


func _comecar() -> void:
	_casos = params.get("casos", CASOS).duplicate()
	_casos.shuffle()
	_casos = _casos.slice(0, 2 + dificuldade)
	_tempo_max = [0, 12.0, 9.0, 6.5][dificuldade]
	_vidas = 3 if dificuldade < 3 else 2
	_rodada = 0
	_sel = 0
	_aviso = ""
	_proxima()


func _proxima() -> void:
	_tempo = _tempo_max


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_t += delta
	_tempo -= delta
	_aviso_t -= delta
	if _tempo <= 0.0:
		_errou("Acabou o tempo!")
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	match acao_de(event):
		"esquerda":
			_sel = (_sel + 7) % 8
			Jogo.som("cursor")
		"direita":
			_sel = (_sel + 1) % 8
			Jogo.som("cursor")
		"cima", "baixo":
			_sel = (_sel + 4) % 8
			Jogo.som("cursor")
		"interagir":
			if PECAS[_sel].id == _casos[_rodada].peca:
				Jogo.som("acerto")
				_aviso = "Consertou!"
				_aviso_cor = VERDE
				_aviso_t = 1.0
				_rodada += 1
				if _rodada >= _casos.size():
					vencer()
				else:
					_proxima()
			else:
				_errou(ERROS.pick_random())


func _errou(msg: String) -> void:
	Jogo.som("erro")
	_vidas -= 1
	_aviso = msg
	_aviso_cor = VERMELHO
	_aviso_t = 1.2
	_tempo = _tempo_max
	if _vidas <= 0:
		perder("O PC venceu. Melhor chamar o técnico... que é você.")


func _desenhar(a: Control) -> void:
	if _rodada >= _casos.size():
		return
	# monitor com o defeito
	caixa(a, Rect2(6, 4, 92, 64), Color("2b2f3a"), Color("0d1030"))
	var tela := Color("1060c0") if _casos[_rodada].peca != "fonte" else Color("101018")
	if _casos[_rodada].peca == "ram":
		tela = Color("2040d0")
	caixa(a, Rect2(12, 10, 80, 48), tela)
	if _casos[_rodada].peca == "video":
		for i in 10:
			a.draw_rect(Rect2(12 + (i * 23 + int(_t * 30)) % 80, 10 + (i * 17) % 48, 6, 1), Color.from_hsv(i / 10.0, 0.8, 1))
	if _casos[_rodada].peca == "ram":
		texto(a, Vector2(52, 38), ":(", BRANCO, 16, true)
	a.draw_rect(Rect2(44, 68, 16, 6), Color("2b2f3a"))
	a.draw_rect(Rect2(30, 74, 44, 4), Color("2b2f3a"))
	texto(a, Vector2(110, 16), "PC %d de %d" % [_rodada + 1, _casos.size()], CINZA)
	var sintoma: String = _casos[_rodada].sintoma
	var linhas := _quebrar(sintoma, 38)
	for i in linhas.size():
		texto(a, Vector2(110, 34 + i * 13), linhas[i], BRANCO)
	barra(a, Rect2(110, 66, 220, 6), _tempo / _tempo_max)
	for i in _vidas:
		a.draw_rect(Rect2(400 + i * 12, 62, 8, 8), VERMELHO)
	if _aviso_t > 0.0:
		texto(a, Vector2(330, 90), _aviso, _aviso_cor, 8, true)
	# peças
	for i in 8:
		var r := Rect2(6 + (i % 4) * 108, 100 + (i / 4) * 48, 100, 42)
		var sel := i == _sel
		caixa(a, r, Color("2a2fa8") if sel else Color("20265e"), AMARELO if sel else Color("0d1030"))
		_icone(a, PECAS[i].id, r.position + Vector2(6, 8))
		texto(a, r.position + Vector2(36, 26), PECAS[i].nome, AMARELO if sel else BRANCO)


func _quebrar(s: String, n: int) -> Array:
	var linhas := []
	var atual := ""
	for w in s.split(" "):
		if (atual + " " + w).strip_edges().length() > n:
			linhas.append(atual)
			atual = w
		else:
			atual = (atual + " " + w).strip_edges()
	linhas.append(atual)
	return linhas


## Desenhinho de cada peça (26x26).
func _icone(a: Control, id: String, p: Vector2) -> void:
	match id:
		"fonte":
			a.draw_rect(Rect2(p, Vector2(26, 22)), Color("8a8f9c"))
			a.draw_circle(p + Vector2(13, 11), 8, Color("3a3d46"))
			a.draw_circle(p + Vector2(13, 11), 2, Color("8a8f9c"))
			a.draw_rect(Rect2(p + Vector2(20, 2), Vector2(4, 3)), Color("f0d040"))
		"ram":
			a.draw_rect(Rect2(p + Vector2(0, 6), Vector2(26, 10)), Color("2a8a4a"))
			for i in 4:
				a.draw_rect(Rect2(p + Vector2(2 + i * 6, 8), Vector2(4, 6)), Color("151515"))
			for i in 6:
				a.draw_rect(Rect2(p + Vector2(1 + i * 4, 16), Vector2(2, 3)), Color("e0b040"))
		"ssd":
			a.draw_rect(Rect2(p + Vector2(1, 3), Vector2(24, 18)), Color("23252e"))
			a.draw_rect(Rect2(p + Vector2(4, 7), Vector2(18, 6)), Color("c03040"))
			a.draw_rect(Rect2(p + Vector2(4, 15), Vector2(10, 2)), Color("8a8f9c"))
		"rede":
			a.draw_line(p + Vector2(2, 20), p + Vector2(14, 8), Color("3070d0"), 3)
			a.draw_rect(Rect2(p + Vector2(12, 2), Vector2(12, 10)), Color("d8dce6"))
			a.draw_rect(Rect2(p + Vector2(14, 10), Vector2(8, 3)), Color("e0b040"))
		"cooler":
			a.draw_rect(Rect2(p + Vector2(1, 0), Vector2(24, 24)), Color("3a3d46"))
			a.draw_circle(p + Vector2(13, 12), 10, Color("6a6f7c"))
			for k in 4:
				var ang := k * PI / 2 + _t * 6
				a.draw_line(p + Vector2(13, 12), p + Vector2(13, 12) + Vector2.from_angle(ang) * 9, Color("c8ccd8"), 3)
		"video":
			a.draw_rect(Rect2(p + Vector2(0, 5), Vector2(26, 14)), Color("2a2a30"))
			a.draw_circle(p + Vector2(7, 12), 5, Color("5a5f6c"))
			a.draw_circle(p + Vector2(19, 12), 5, Color("5a5f6c"))
			a.draw_rect(Rect2(p + Vector2(2, 19), Vector2(16, 3)), Color("e0b040"))
		"teclado":
			a.draw_rect(Rect2(p + Vector2(0, 8), Vector2(26, 12)), Color("d8dce6"))
			for y in 2:
				for x in 5:
					a.draw_rect(Rect2(p + Vector2(2 + x * 5, 10 + y * 5), Vector2(3, 3)), Color("8a8f9c"))
		"mouse":
			a.draw_rect(Rect2(p + Vector2(8, 4), Vector2(12, 18)), Color("d8dce6"))
			a.draw_rect(Rect2(p + Vector2(13, 4), Vector2(1, 7)), Color("8a8f9c"))
			a.draw_line(p + Vector2(14, 4), p + Vector2(14, 0), Color("3a3d46"), 1)
