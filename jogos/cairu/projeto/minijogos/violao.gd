extends "res://minijogos/base.gd"
## Violão: resenha no pátio com o Seu Mauro. O Seu Mauro faz a base no violão e o
## jogador toca a melodia: cada bolinha é uma nota da música, e quando ela passa na
## linha amarela a seta certa toca essa nota no violão. Errou = corda abafada.
## A música e as notas saem de fonte_audio/violao.py (minijogos/violao_musica.json).

const FAIXAS := ["esquerda", "baixo", "cima", "direita"]
const LETRA := [
	"~ Ô morena do pátio, me empresta um sorriso...",
	"~ Lá na roça tem jegue, aqui tem Wi-Fi...",
	"~ Varri a sala inteira pensando em você...",
	"~ A cana é doce, mas o salário não é...",
	"~ Meu celular tem vírus, meu coração também...",
	"~ Ê, lê, lê... ê, lê, lê, lê...",
]
const LINHA_Y := 168.0
const X0 := 150.0
const LARG := 40.0
const JANELA := 0.16      # segundos de folga pra acertar (antes ou depois)
const MUSICA_VIOLAO := "violao_mauro"

var _musica := {}          # violao_musica.json
var _fila: Array = []      # notas que o jogador tem que tocar: {t, nota, faixa, ok, foi}
var _sozinhas: Array = []  # notas que a música toca sozinha (as que ficaram fora na dificuldade)
var _tempo := 0.0
var _duracao := 30.0
var _acertos := 0
var _total := 0
var _brilho := {}          # faixa -> tempo do brilho
var _queda := 1.6          # segundos que a bolinha leva do topo até a linha
var _base := AudioStreamPlayer.new()
var _cordas: Array[AudioStreamPlayer] = []
var _prox_corda := 0
var _acerto_txt := ""
var _acerto_t := 0.0


func _init() -> void:
	musica = ""   # o violão do Seu Mauro começa junto com o jogo (silêncio na tela de instruções)
	titulo = "Resenha no violão"
	instrucoes = "O Seu Mauro puxou o violão no pátio e você faz a melodia.\nCada bolinha é uma nota: aperte a seta da faixa quando ela passar na linha amarela e o violão toca.\nAcerte bastante pra roda cantar junto."


func _ready() -> void:
	super._ready()
	_base.bus = "Musica"
	add_child(_base)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		add_child(p)
		_cordas.append(p)
	var f := FileAccess.open("res://minijogos/violao_musica.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_musica = d


func _comecar() -> void:
	_tempo = -0.05
	_acertos = 0
	_brilho.clear()
	_acerto_txt = ""
	_queda = [2.0, 1.6, 1.3][dificuldade - 1]
	_duracao = float(_musica.get("duracao", 30.0))
	_fila.clear()
	_sozinhas.clear()
	# fácil: só as notas mais espaçadas; médio: tira as mais coladas; difícil: todas
	var folga: float = [0.65, 0.4, 0.0][dificuldade - 1]
	var ultima := -10.0
	for n in _musica.get("notas", []):
		var nt := {"t": float(n.t), "nota": int(n.nota), "faixa": int(n.faixa), "ok": false, "foi": false}
		if nt.t - ultima >= folga - 0.001:
			_fila.append(nt)
			ultima = nt.t
		else:
			_sozinhas.append(nt)
	_total = _fila.size()
	var s: AudioStream = Jogo._som("musica", MUSICA_VIOLAO)
	if s is AudioStreamOggVorbis:
		s.loop = false
	_base.stream = s
	_base.play()


## Tempo da música (pelo áudio, pra bolinha e som ficarem juntos).
func _agora() -> float:
	if _base.playing:
		return _base.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return _tempo


func tocar_nota(nota: int, vol := 0.0) -> void:
	var s: AudioStream = Jogo._som("efeitos", "violao_%d" % nota)
	if s == null:
		return
	var p := _cordas[_prox_corda]
	_prox_corda = (_prox_corda + 1) % _cordas.size()
	p.stream = s
	p.volume_db = vol
	p.play()


func _process(delta: float) -> void:
	if estado != "jogando":
		if _base.playing and estado == "resultado":
			_base.stop()
		return
	_tempo += delta
	var t := _agora()
	if _base.playing:
		_tempo = t
	for k in _brilho.keys():
		_brilho[k] -= delta
		if _brilho[k] <= 0.0:
			_brilho.erase(k)
	_acerto_t -= delta
	# a música toca sozinha as notas que não viraram bolinha
	for nt in _sozinhas:
		if not nt.foi and t >= nt.t:
			nt.foi = true
			tocar_nota(nt.nota, -7.0)
	# bolinha que passou da linha sem ninguém tocar: corda abafada
	for nt in _fila:
		if not nt.ok and not nt.foi and t > nt.t + JANELA:
			nt.foi = true
			Jogo.som("violao_abafado", -6.0, 0.1)
	if t >= _duracao:
		_base.stop()
		var frac: float = float(_acertos) / max(_total, 1)
		if frac >= 0.45 + dificuldade * 0.05:
			vencer()
		else:
			perder("Desafinou, mas a roda riu tanto que o Seu Mauro disse que foi de propósito.")
		return
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	var a := acao_de(event)
	var f := FAIXAS.find(a)
	if f < 0:
		return
	_brilho[f] = 0.12
	var t := _agora()
	var melhor = null
	for nt in _fila:
		if nt.faixa == f and not nt.ok and not nt.foi and abs(nt.t - t) <= JANELA:
			if melhor == null or abs(nt.t - t) < abs(melhor.t - t):
				melhor = nt
	if melhor:
		melhor.ok = true
		_acertos += 1
		tocar_nota(melhor.nota)
		_acerto_txt = "Perfeito!" if abs(melhor.t - t) < 0.06 else "Boa!"
		_acerto_t = 0.4
	else:
		# apertou fora da hora: ainda sai uma nota do acorde (mais baixinho)
		tocar_nota(_nota_do_acorde(t, f), -10.0)


## Nota do acorde que está tocando agora, uma por faixa (grave na esquerda).
func _nota_do_acorde(t: float, f: int) -> int:
	var acordes: Array = _musica.get("acordes", ["G"])
	var c := clampi(int(t / float(_musica.get("compasso", 2.5))), 0, acordes.size() - 1)
	var notas: Array = _musica.get("notas_acorde", {}).get(acordes[c], [67, 71, 74, 79])
	return int(notas[mini(f, notas.size() - 1)])


func _desenhar(a: Control) -> void:
	var t := _agora()
	var compasso: float = float(_musica.get("compasso", 2.5))
	var intro: int = int(_musica.get("intro", 1))
	var verso_i := int(max(t / compasso - intro, 0.0) / 2.0)
	var verso: String = "~ (o Seu Mauro afinando...)" if t < compasso * intro else LETRA[verso_i % LETRA.size()]
	texto(a, Vector2(220, 14), verso, AMARELO, 8, true)
	for i in 4:
		var x := X0 + i * LARG
		caixa(a, Rect2(x, 22, LARG - 4, 170), Color("15183a"))
		if _brilho.has(i):
			a.draw_rect(Rect2(x, LINHA_Y - 10, LARG - 4, 20), Color(1, 0.85, 0.3, 0.35))
		tecla_desenho(a, Vector2(x + (LARG - 4) / 2, LINHA_Y + 18), FAIXAS[i], 16.0)
	a.draw_rect(Rect2(X0, LINHA_Y - 1, LARG * 4 - 4, 2), AMARELO)
	var vel := (LINHA_Y + 10.0) / _queda
	for nt in _fila:
		if nt.ok or (nt.foi and t > nt.t + 0.3):
			continue
		var y: float = LINHA_Y - (nt.t - t) * vel
		if y < -10.0 or y > LINHA_Y + 30.0:
			continue
		var x: float = X0 + nt.faixa * LARG + (LARG - 4) / 2
		var cor: Color = [Color("e0505a"), Color("6fd08c"), Color("5fa8ff"), Color("ffd34e")][nt.faixa]
		if nt.foi:
			cor = Color("4a4f70")
		a.draw_circle(Vector2(x, y), 7.0, Color("0d1030"))
		a.draw_circle(Vector2(x, y), 6.0, cor)
	if _acerto_t > 0.0:
		texto(a, Vector2(X0 + LARG * 2 - 2, LINHA_Y - 30), _acerto_txt, VERDE, 8, true)
	texto(a, Vector2(20, 60), "ACERTOS", CINZA)
	texto(a, Vector2(20, 76), "%d / %d" % [_acertos, _total], BRANCO)
	texto(a, Vector2(20, 110), "MUSICA", CINZA)
	barra(a, Rect2(20, 116, 100, 8), 1.0 - clampf(t / _duracao, 0.0, 1.0), VERDE)
	texto(a, Vector2(330, 60), "Setas no", CINZA)
	texto(a, Vector2(330, 74), "tempo certo", CINZA)
