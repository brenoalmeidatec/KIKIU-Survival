extends "res://minijogos/base.gd"
## Reflexo: aparece uma tecla; aperte ela antes do tempo acabar. Errar ou demorar gasta uma vida.
## Na cena: "frases": ["Desvia do professor!", ...] troca os textos que aparecem em cima.

const TECLAS := ["cima", "baixo", "esquerda", "direita", "E"]
const FRASES := ["Rápido!", "Agora!", "Vai, vai!", "Essa!", "Olha o professor!", "Segura o café!",
	"Desvia!", "Não deixa cair!", "Corre!"]

var _total := 10
var _feitas := 0
var _vidas := 3
var _atual := ""
var _frase := ""
var _tempo := 0.0
var _tempo_max := 1.4
var _pausa := 0.0
var _flash := 0.0
var _flash_cor := VERDE


func _init() -> void:
	titulo = "Reflexo!"
	instrucoes = "Vai aparecer uma tecla no meio da tela.\nAperte ela (setas ou E) antes da barra acabar.\nErrou ou demorou, perde uma vida."


func _comecar() -> void:
	_total = 6 + dificuldade * 2
	_tempo_max = [0, 1.6, 1.15, 0.8][dificuldade]
	_vidas = 3 if dificuldade < 3 else 2
	_feitas = 0
	_atual = ""
	_pausa = 0.8


func _nova() -> void:
	var antes := _atual
	while _atual == antes:
		_atual = TECLAS.pick_random()
	_frase = params.get("frases", FRASES).pick_random()
	_tempo = _tempo_max
	Jogo.som("cursor")


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_flash = max(_flash - delta, 0.0)
	if _atual == "":
		_pausa -= delta
		if _pausa <= 0.0:
			_nova()
	else:
		_tempo -= delta
		if _tempo <= 0.0:
			_falhou()
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	if _atual == "":
		return
	var a := acao_de(event)
	if a == "":
		return
	var certo := (_atual == "E" and a == "interagir") or a == _atual
	if certo:
		Jogo.som("acerto")
		_feitas += 1
		_flash = 0.25
		_flash_cor = VERDE
		_atual = ""
		_pausa = randf_range(0.25, 0.7)
		if _feitas >= _total:
			vencer()
	else:
		_falhou()


func _falhou() -> void:
	Jogo.som("erro")
	_vidas -= 1
	_flash = 0.35
	_flash_cor = VERMELHO
	_atual = ""
	_pausa = 0.7
	if _vidas <= 0:
		perder("Lento demais. O café caiu todinho.")


func _desenhar(a: Control) -> void:
	if _flash > 0.0:
		a.draw_rect(Rect2(0, 0, 440, 196), Color(_flash_cor, _flash * 0.8))
	texto(a, Vector2(10, 16), "%d / %d" % [_feitas, _total], CINZA)
	for i in _vidas:
		a.draw_rect(Rect2(420 - i * 12, 8, 8, 8), VERMELHO)
	if _atual == "":
		return
	texto(a, Vector2(220, 46), _frase, AMARELO, 16, true)
	var tam := 52.0
	var c := Vector2(220, 112)
	tecla_desenho(a, c, _atual, tam, BRANCO, Color("2a2fa8"))
	barra(a, Rect2(140, 156, 160, 8), _tempo / _tempo_max)
