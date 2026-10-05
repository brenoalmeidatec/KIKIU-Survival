extends Node2D
## Personagem andando no mapa (folha 44x60, 4 colunas x 4 direções).

const LINHA := {"baixo": 0, "esquerda": 1, "direita": 2, "cima": 3}
const CICLO := [1, 3, 2, 3]
const CICLO_8 := [1, 2, 3, 4, 5, 6, 7, 8]

var id := ""
var dir := "baixo"
var andando := false
var _t := 0.0
var _spr := Sprite2D.new()
var _oito := false   # folha de andar com 8 quadros (andando_8.png), se existir
var pose := ""        # animação que ficou "mantida" (caído, pose de herói...); "" = normal
var _acao := ""       # ação da folha acoes.png sendo mostrada ("" = andar normal)
var _seq := {}        # linha da folha tocando agora: {linha, quadros, fps, repete, t, fixo}
var _animando := 0
var _tex_andar: Texture2D
var _resp := randf() * TAU   # fase da respiração (cada um respira no seu tempo)
var sombra := true            # false = sem a sombrinha no pé (aluno sentado)


func configurar(personagem: String, direcao := "baixo") -> void:
	id = personagem
	dir = direcao
	var t8 := Dados.textura(personagem, "andando_8")
	_oito = t8 != null
	_tex_andar = t8 if _oito else Dados.textura(personagem, "andando")
	_spr.centered = false
	add_child(_spr)
	_folha_andar()
	_atualizar()


## Troca quem este boneco é (o jogo online usa: nas cenas, o jogador vira o protagonista).
func trocar(personagem: String) -> void:
	if personagem == id:
		return
	id = personagem
	var t8 := Dados.textura(personagem, "andando_8")
	_oito = t8 != null
	_tex_andar = t8 if _oito else Dados.textura(personagem, "andando")
	pose = ""
	_animando = 0
	_folha_andar()
	_atualizar()


func _folha_andar() -> void:
	_acao = ""
	_seq = {}
	_spr.texture = _tex_andar
	_spr.hframes = 9 if _oito else 4
	_spr.vframes = 4
	_spr.offset = Vector2(-22, -58)
	_spr.flip_h = false


## Sombrinha embaixo do pé (desenhada antes do sprite, então fica atrás dele).
## Deitado = sombra comprida; no ar = sombra menor e mais clara.
func _draw() -> void:
	if not sombra:
		return
	var deitado: float = abs(sin(_spr.rotation))
	var alto: float = clampf(-_spr.position.y / 30.0, 0.0, 0.6)
	var cx: float = sin(_spr.rotation) * 24.0
	draw_set_transform(Vector2(cx, -1), 0, Vector2((1.0 + deitado * 1.6) * (1.0 - alto * 0.5), 0.35))
	draw_circle(Vector2.ZERO, 10, Color(0.09, 0.08, 0.15, 0.32 * (1.0 - alto)))


func olhar_para(alvo: Vector2) -> void:
	var d := alvo - position
	if abs(d.x) > abs(d.y):
		dir = "direita" if d.x > 0 else "esquerda"
	else:
		dir = "baixo" if d.y > 0 else "cima"
	_atualizar()


func _process(delta: float) -> void:
	_t = _t + delta if andando else 0.0
	if not _seq.is_empty():
		_seq.t += delta
		var i := int(_seq.t * float(_seq.fps))
		i = i % int(_seq.quadros) if _seq.repete else mini(i, int(_seq.quadros) - 1)
		if _seq.fixo >= 0:
			i = _seq.fixo
		_spr.frame = int(_seq.linha) * _spr.hframes + i
	_atualizar()
	if _animando > 0 or pose != "":
		queue_redraw()
	else:
		_vivo(delta)


var _piscar_t := randf_range(2.0, 5.0)


## Parado de frente: respira e pisca com os quadros desenhados (acoes2.png).
## Sem esses quadros, o peito sobe e desce 1 pixel.
func _vivo(delta: float) -> void:
	var ligado := Visual.ligado()
	if _acao in ["respirar", "piscar"]:
		if andando or dir != "baixo" or not ligado:
			_folha_andar()
			_atualizar()
			return
		_piscar_t -= delta
		if _acao == "respirar" and _piscar_t <= 0.0:
			mostrar_acao("piscar", 1.0)
			_piscar_t = 0.3
		elif _acao == "piscar" and _piscar_t <= 0.0:
			mostrar_acao("respirar", 1.0)
			_piscar_t = randf_range(2.5, 6.0)
		return
	if _acao != "":
		return
	if ligado and not andando and dir == "baixo" and _t <= 0.0 and Dados.textura(id, "acoes2") != null:
		if mostrar_acao("respirar", 1.0) > 0.0:
			_seq.t = randf() * 1.0
			return
	_resp += delta * (2.2 if not andando else 0.0)
	var alvo := 1.0
	if not andando and ligado:
		alvo = 1.0 + 0.018 * maxf(sin(_resp), 0.0)
	_spr.scale.y = alvo


## Uma mania sorteada da lista do personagem (capitulos/animacoes.json, "manias").
func mania(mundo: Node = null) -> void:
	var m: Dictionary = Animacao.defs().get("manias", {})
	var lista: Array = m.get(id, m.get("padrao", []))
	if lista.is_empty() or not Visual.ligado():
		return
	await anim(str(lista.pick_random()), mundo)


func _atualizar() -> void:
	if _acao != "" or _spr.region_enabled:
		return
	if _oito:
		_spr.frame = LINHA[dir] * 9 + (CICLO_8[int(_t * 10.0) % 8] if andando else 0)
	else:
		_spr.frame = LINHA[dir] * 4 + (CICLO[int(_t * 8.0) % 4] if andando else 0)


# ---------- usados pelas cenas ----------

var _passeio := 0


## Anda em linha reta até "alvo" (atravessa móveis; é cena, não controle).
## Se mandarem andar de novo antes de chegar, o caminho antigo é abandonado.
## Anda até o ponto. Nas cenas o caminho desvia das mesas e paredes (mundo.rota);
## "reto" = true vai em linha reta (atravessa tudo).
func andar_ate(alvo: Vector2, velocidade := 60.0, reto := false) -> void:
	if pose != "":
		soltar_pose()
	_passeio += 1
	var meu := _passeio
	andando = true
	var mundo := get_parent().get_parent() if get_parent() else null
	var pontos: Array = [alvo]
	if not reto and mundo and mundo.has_method("rota"):
		pontos = mundo.rota(position, alvo)
	var correndo: bool = velocidade >= 110.0 and abs(alvo.x - position.x) > abs(alvo.y - position.y) \
		and mostrar_acao("correr", 1.0 if alvo.x > position.x else -1.0) > 0.0
	for ponto in pontos:
		var p: Vector2 = ponto
		while position.distance_to(p) > 1.0:
			if meu != _passeio or not is_inside_tree():
				return
			var d := p - position
			if abs(d.x) > abs(d.y) * 0.8:
				dir = "direita" if d.x > 0 else "esquerda"
			else:
				dir = "baixo" if d.y > 0 else "cima"
			var passo := velocidade * get_process_delta_time()
			position = position.move_toward(p, max(passo, 0.5))
			await get_tree().process_frame
		position = p
	andando = false
	if correndo and meu == _passeio:
		_folha_andar()
	_atualizar()


func pular(altura := 10.0) -> void:
	var tw := create_tween()
	tw.tween_property(_spr, "position:y", -altura, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(_spr, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN)
	await tw.finished


# ---------- animações (motor em animacao.gd, lista em capitulos/animacoes.json) ----------

## Volta ao normal na hora (em pé, sem pose).
func soltar_pose() -> void:
	pose = ""
	_animando = 0
	_spr.position = Vector2.ZERO
	_spr.rotation = 0.0
	_spr.scale = Vector2.ONE
	_spr.modulate = Color.WHITE
	_folha_andar()
	_atualizar()
	queue_redraw()


## Toca uma animação de capitulos/animacoes.json e espera ela acabar.
## "normal" (ou "levantar" quando não há pose) volta ao jeito de sempre.
func anim(nome: String, mundo: Node = null, alvo: Node2D = null) -> void:
	if alvo and alvo != self:
		olhar_para(alvo.position)
	var d := Animacao.resolver(self, nome)
	if d.is_empty():
		return
	await animar(d.passos, d.manter, nome, mundo, alvo)


## Mostra uma ação da folha acoes.png ("cair" toca a linha toda; "cair:3" só o quadro 3).
## As de lado são desenhadas viradas pra direita. Devolve quanto tempo a linha dura (0 = não tem).
func mostrar_acao(nome: String, lado: float) -> float:
	var l := Animacao.linha(nome)
	var tex := Dados.textura(id, str(l.get("folha", "acoes")))
	if l.is_empty() or tex == null:
		return 0.0
	var f := Animacao.folha()
	var tam: Array = f.get("tamanho", [64, 64])
	var anc: Array = f.get("ancora", [-32, -61])
	_acao = nome
	_spr.texture = tex
	_spr.hframes = int(f.get("colunas", 8))
	_spr.vframes = int(tex.get_height() / float(tam[1]))
	_spr.offset = Vector2(anc[0], anc[1])
	_spr.flip_h = lado < 0 and l.get("vista", "lado") == "lado"
	var fixo := int(nome.get_slice(":", 1)) if nome.contains(":") else -1
	_seq = {"linha": int(l.linha), "quadros": int(l.quadros), "fps": float(l.get("fps", 8)),
		"repete": bool(l.get("repete", false)), "t": 0.0, "fixo": fixo}
	_spr.frame = int(l.linha) * _spr.hframes + max(fixo, 0)
	return 0.0 if fixo >= 0 else float(l.quadros) / float(l.get("fps", 8))


## Toca uma animação passo a passo. "lado" espelha tudo (1 = virado pra direita).
## Cada passo muda o corpo em "t" segundos: x, y, rot (graus), sx, sy (esticar),
## mover [dx, dy] (anda de verdade), quadro, e dispara som, tremer, particulas,
## balao, flash, acerta (anima o alvo). Veja o LEIA-ME.
func animar(passos: Array, manter: bool, nome: String, mundo: Node, alvo: Node2D) -> void:
	_passeio += 1          # cancela um andar_ate em andamento
	andando = false
	if _acao in ["correr", "respirar", "piscar"]:
		_folha_andar()
	_animando += 1
	var meu := _animando
	var lado := -1.0 if dir == "esquerda" else 1.0
	if alvo:
		lado = -1.0 if alvo.position.x < position.x else 1.0
	for k in passos:
		if not is_inside_tree() or meu != _animando:
			return
		if not k is Dictionary:
			continue
		if k.get("de_costas", false):
			lado = -lado
		var dura := _eventos(k, lado, mundo, alvo)
		var t := float(k.get("t", dura))
		var tw := create_tween().set_parallel(true)
		var trans := Tween.TRANS_SINE
		var ease := Tween.EASE_IN_OUT
		match str(k.get("ease", "")):
			"in": ease = Tween.EASE_IN
			"out": ease = Tween.EASE_OUT
			"linear": trans = Tween.TRANS_LINEAR
			"back":
				trans = Tween.TRANS_BACK
				ease = Tween.EASE_OUT
			"quica", "bounce":
				trans = Tween.TRANS_BOUNCE
				ease = Tween.EASE_OUT
			"elastico":
				trans = Tween.TRANS_ELASTIC
				ease = Tween.EASE_OUT
		var pos := _spr.position
		if k.has("x"):
			pos.x = float(k.x) * lado
		if k.has("y"):
			pos.y = float(k.y)
		var tt: float = max(t, 0.001)
		tw.tween_property(_spr, "position", pos, tt).set_trans(trans).set_ease(ease)
		if k.has("rot"):
			tw.tween_property(_spr, "rotation", deg_to_rad(float(k.rot)) * lado, tt).set_trans(trans).set_ease(ease)
		if k.has("sx") or k.has("sy"):
			var sc := Vector2(float(k.get("sx", _spr.scale.x)), float(k.get("sy", _spr.scale.y)))
			tw.tween_property(_spr, "scale", sc, tt).set_trans(trans).set_ease(ease)
		if k.has("mover"):
			var m: Array = k.mover
			tw.tween_property(self, "position", position + Vector2(float(m[0]) * lado, float(m[1]) if m.size() > 1 else 0.0), tt).set_trans(trans).set_ease(ease)
		await tw.finished
	if meu != _animando:
		return
	if manter:
		pose = nome
	else:
		pose = ""
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_spr, "position", Vector2.ZERO, 0.12)
		tw.tween_property(_spr, "rotation", 0.0, 0.12)
		tw.tween_property(_spr, "scale", Vector2.ONE, 0.12)
		await tw.finished
		if _acao != "":
			_folha_andar()
	_animando = 0
	_atualizar()
	queue_redraw()


func _eventos(k: Dictionary, lado: float, mundo: Node, alvo: Node2D) -> float:
	var dura := 0.0
	if k.has("quadro"):
		var q := str(k.quadro)
		if q == "" or q == "andar":
			_folha_andar()
		elif q.begins_with("andar:"):
			_folha_andar()
			_spr.frame = LINHA[dir] * _spr.hframes + int(q.substr(6))
			_acao = "andar"
		else:
			dura = mostrar_acao(q, lado)
	if k.has("virar"):
		dir = str(k.virar)
		_atualizar()
	if k.has("som"):
		Jogo.som(str(k.som), 0.0, 0.08)
	if k.has("balao"):
		balao(str(k.balao), float(k.get("tempo_balao", 1.0)))
	if k.has("flash"):
		_spr.modulate = Color(str(k.flash)) * 2.2
		create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.2)
	if k.has("sumir"):
		create_tween().tween_property(self, "modulate:a", 0.0 if k.sumir else 1.0, max(float(k.get("t", 0.2)), 0.05))
	if mundo:
		if k.has("tremer") and mundo.has_method("tremer"):
			var tr: Array = k.tremer if k.tremer is Array else [k.tremer, 3.0]
			mundo.tremer(float(tr[0]), float(tr[1]) if tr.size() > 1 else 3.0)
		if k.has("particulas") and Visual.ligado():
			Animacao.estouro(str(k.particulas), get_parent(), position + Vector2(10 * lado, -4))
		if k.has("acerta") and alvo and is_instance_valid(alvo):
			Animacao.tocar(alvo, str(k.acerta) if k.acerta is String else "apanhar", mundo, self)
	return dura


## Altura do balão: logo acima da cabeça (o desenho tem 60 px, a cabeça começa uns 43 px acima do pé).
const TOPO_BALAO := -56.0

## Ícones de emoção desenhados em pixel (9x9). Qualquer outro texto vira balão de texto.
const ICONES := {
	"!": ["...##....", "...##....", "...##....", "...##....", "...##....", ".........", "...##....", "...##....", "........."],
	"?": ["..####...", ".##..##..", ".....##..", "....##...", "...##....", "...##....", ".........", "...##....", "...##...."],
	"!!": [".##..##..", ".##..##..", ".##..##..", ".##..##..", ".##..##..", ".........", ".##..##..", ".##..##..", "........."],
	"?!": ["####..##.", "...##.##.", "..##..##.", ".##...##.", ".##...##.", ".........", ".##...##.", ".##...##.", "........."],
	"...": [".........", ".........", ".........", ".........", ".........", ".........", "##.##.##.", "##.##.##.", "........."],
	"coracao": [".##...##.", "####.####", "#########", "#########", ".#######.", "..#####..", "...###...", "....#....", "........."],
	"raiva": ["##.....##", ".##...##.", "..#...#..", ".........", ".........", "..#...#..", ".##...##.", "##.....##", "........."],
	"suor": ["....#....", "...###...", "..#####..", "..#####..", ".#######.", ".#######.", "..#####..", "...###...", "........."],
	"nota": ["...#####.", "...#...#.", "...#...#.", "...#...#.", "...#...#.", ".###.###.", "####.####", ".##...##.", "........."],
	"ideia": ["..#####..", ".#######.", "#########", "#########", ".#######.", "..#####..", "...###...", "...###...", "....#...."],
	"zzz": ["#####....", "...#.....", "..#......", ".#..###..", "#####.#..", "....#....", "....###..", ".........", "........."],
	"estrela": ["....#....", "...###...", "#########", ".#######.", "..#####..", ".###.###.", ".##...##.", "#.......#", "........."],
	"musica": ["...#####.", "...#...#.", "...#...#.", "...#...#.", "...#...#.", ".###.###.", "####.####", ".##...##.", "........."],
	"gota": ["....#....", "...###...", "..#####..", "..#####..", ".#######.", ".#######.", "..#####..", "...###...", "........."],
	# rostinhos e outros com mais de uma cor: # = cor do ícone, o = segunda cor, k = escuro
	"vergonha": ["..#####..", ".#######.", "##k###k##", "#########", "oo#####oo", "oo#kkk#oo", "#########", ".#######.", "..#####.."],
	"caveira": ["..kkkkk..", ".k#####k.", "k#######k", "k#kk#kk#k", "k#kk#kk#k", "k###k###k", ".k#####k.", "..k#k#k..", "..kkkkk.."],
	"choro": ["..#####..", ".#######.", "#kk###kk#", "#o#####o#", "#o#kkk#o#", "#o#k#k#o#", ".o#####o.", ".o.###.o.", ".o.....o."],
	"susto": ["..#####..", ".#######.", "#k#k#k#k#", "#########", "###kkk###", "###k#k###", "###kkk###", ".#######.", "..#####.."],
	"risada": ["..#####..", ".#######.", "#k#k#k#k#", "##k###k##", "#########", "#kkkkkkk#", "##kooook#", ".##kkkk#.", "..#####.."],
	"raio": ["....####.", "...####..", "..####...", ".#######.", "....###..", "...###...", "..##.....", ".#.......", "........."],
	"fogo": ["....#....", "...##....", "..###.#..", "..####...", ".##o###..", ".#ooo##..", "##ooo###.", ".#ooo##..", "..###...."],
	"raiva2": [".........", ".kk...kk.", "..kk.kk..", ".........", ".........", "..kk.kk..", ".kk...kk.", ".........", "........."],
}

## Emojis e apelidos que viram um ícone (o 😳 do texto vira "vergonha", e assim por diante).
const APELIDO_ICONE := {"😳": "vergonha", "🫣": "vergonha", "😊": "vergonha", "corado": "vergonha", "vergonhoso": "vergonha",
	"💀": "caveira", "☠": "caveira", "morri": "caveira", "morto": "caveira",
	"😭": "choro", "😢": "choro", "chorando": "choro", "chorar": "choro",
	"😱": "susto", "😨": "susto", "😮": "susto", "medo": "susto", "assustado": "susto",
	"😂": "risada", "🤣": "risada", "😆": "risada", "rindo": "risada", "kkk": "risada",
	"⚡": "raio", "🔥": "fogo", "❤": "coracao", "♥": "coracao", "💕": "coracao", "😍": "coracao",
	"💡": "ideia", "💤": "zzz", "😴": "zzz", "⭐": "estrela", "🌟": "estrela", "✨": "estrela",
	"💧": "suor", "💦": "suor", "😅": "suor", "😓": "suor", "😡": "raiva", "😠": "raiva", "💢": "raiva",
	"🎵": "musica", "🎶": "musica", "❗": "!", "❓": "?", "‼": "!!", "⁉": "?!", "🤔": "?", "😐": "..."}

## Nome do ícone pra um texto de balão ("" se não for ícone, aí vira balão de texto).
static func chave_icone(icone: String) -> String:
	var t := icone.strip_edges().replace("\uFE0F", "").replace(":", "")
	var chave := Roteiro.sem_acento(t.to_lower())
	if ICONES.has(chave):
		return chave
	return APELIDO_ICONE.get(chave, APELIDO_ICONE.get(t, ""))
const COR_ICONE := {"coracao": "e0405a", "raiva": "d03030", "suor": "4aa0e0", "gota": "4aa0e0", "ideia": "f0b020",
	"estrela": "f0b020", "nota": "6040c0", "musica": "6040c0", "zzz": "5060a0", "vergonha": "f6c86a",
	"caveira": "f3efe2", "choro": "f6c86a", "susto": "f6c86a", "risada": "f6c86a", "raio": "f0b020",
	"fogo": "e8502a", "raiva2": "d03030"}
const COR2_ICONE := {"vergonha": "f0708a", "choro": "4aa0e0", "risada": "e0405a", "fogo": "feae34"}


class Icone extends Node2D:
	var grade: Array = []
	var cor := Color("1a2050")
	var cor2 := Color("e0405a")

	func _draw() -> void:
		draw_rect(Rect2(-8, -8, 17, 15), Color("1a2050"))
		draw_rect(Rect2(-7, -7, 15, 13), Color.WHITE)
		draw_rect(Rect2(-2, 6, 4, 2), Color("1a2050"))
		draw_rect(Rect2(-1, 6, 2, 1), Color.WHITE)
		for y in grade.size():
			var linha: String = grade[y]
			for x in linha.length():
				var c: String = linha[x]
				if c != ".":
					draw_rect(Rect2(x - 4, y - 5, 1, 1), cor if c == "#" else cor2 if c == "o" else Color("1a2050"))


## Balãozinho em cima da cabeça: um ícone de emoção (veja ICONES) ou um texto curto.
func balao(icone: String, tempo := 1.0) -> void:
	var chave := chave_icone(icone)
	var n: Node2D
	if chave != "":
		var ic := Icone.new()
		ic.grade = ICONES[chave]
		ic.cor = Color(COR_ICONE.get(chave, "1a2050"))
		ic.cor2 = Color(COR2_ICONE.get(chave, "e0405a"))
		ic.position = Vector2(0, TOPO_BALAO + 4)
		n = ic
	else:
		n = Node2D.new()
		var l := _rotulo(icone, Color.WHITE)
		n.add_child(l)
		n.position = Vector2(0, TOPO_BALAO + 4)
		await get_tree().process_frame
		l.position = Vector2(-l.size.x / 2, -l.size.y)
	n.z_index = 60
	add_child(n)
	n.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", TOPO_BALAO, 0.1)
	tw.tween_interval(max(tempo - 0.22, 0.1))
	await tw.finished
	n.queue_free()


## Balão de fala ou de pensamento em cima do personagem, no próprio mapa
## (sem abrir a tela de diálogo). Espera o jogador apertar E.
func falar_no_mapa(texto: String, pensando := false) -> void:
	var n := Node2D.new()
	n.z_index = 60
	var l := _rotulo(texto, Color("eef0ff") if pensando else Color.WHITE, 150)
	n.add_child(l)
	add_child(n)
	await get_tree().process_frame
	l.position = Vector2(-l.size.x / 2, TOPO_BALAO + 2 - l.size.y)
	if pensando:
		for b in [[Vector2(-2, TOPO_BALAO + 4), 2.5], [Vector2(-5, TOPO_BALAO + 10), 1.5]]:
			var c := Polygon2D.new()
			var pts := PackedVector2Array()
			for k in 8:
				pts.append(b[0] + Vector2.from_angle(k * TAU / 8) * b[1])
			c.polygon = pts
			c.color = Color("eef0ff")
			n.add_child(c)
	Jogo.tocar_voz(id, texto)
	var t := 0.0
	while is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 0.2 and (Input.is_action_just_pressed("interagir") or (Input.is_action_pressed("acelerar") and t > 0.5)):
			break
	Jogo.parar_voz()
	n.queue_free()


func _rotulo(texto: String, fundo_cor: Color, largura := 0) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", Color("1a2050"))
	if largura > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = min(largura, texto.length() * 8 + 8)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = fundo_cor
	fundo.border_color = Color("1a2050")
	fundo.set_border_width_all(1)
	fundo.set_content_margin_all(3)
	fundo.set_corner_radius_all(3 if largura > 0 else 0)
	l.add_theme_stylebox_override("normal", fundo)
	return l
