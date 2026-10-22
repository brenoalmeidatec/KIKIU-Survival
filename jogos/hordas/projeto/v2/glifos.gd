extends RefCounted
## Glifos de botão da v2: descobre o ÚLTIMO dispositivo usado (teclado e mouse, controle Xbox ou controle PlayStation) e devolve só o botão certo
## de cada ação, em pixel. Tocar num botão do controle troca na hora todos os rótulos; mexer no teclado ou no mouse troca de volta.
## Todas as telas pedem aqui o nome da tecla (nunca escrevem "Esc/B" no texto): `descritor(acao)` diz o que desenhar, `texto(acao)` devolve só
## um texto curto (para o que é desenhado por código, como o SUA BUILD) e `dica(...)` / `glifo(...)` devolvem o Control que desenha o botão
## sozinho e se refaz quando o dispositivo muda. As ações são nomes de PAPEL (confirmar, voltar, pausa, rerrolar, banir, abas...), não de tecla.
## Em teste ou foto: `--controle=xbox` / `--controle=ps` / `--controle=teclado` trava o dispositivo (a detecção para).
## No Godot o botão de baixo é o JOY_BUTTON_A nos dois controles (Xbox A = PlayStation cruz); direita = B = bola; esquerda = X = quadrado; cima = Y = triângulo.

const Paleta := preload("res://v2/paleta.gd")
const G := preload("res://v2/glifos.gd")  # as classes internas chamam o estático do arquivo por aqui

enum Disp { TECLADO, XBOX, PS }

const NOMES := ["teclado", "xbox", "ps"]
const PS_NOMES := ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony", "wireless controller"]
const ALTURA := 16.0  # altura de todo glifo; o texto da dica é a Spleen 16
const COR_TECLA := Color("#211f2b")
const COR_TECLA_BAIXO := Color("#0a0814")
const COR_TECLA_BORDA := Color("#8c87ad")
const COR_FACE := {"A": Color("#4fb86a"), "B": Color("#d8484a"), "X": Color("#4a86d9"), "Y": Color("#e0bc48")}
const COR_PS_FUNDO := Color("#2a2d3a")
const COR_PS_BORDA := Color("#8c87ad")
const COR_PS := {"x": Color("#6fa8ff"), "o": Color("#ff6b6b"), "q": Color("#ee8fd6"), "t": Color("#6fdc8c")}
const TECLA := "tecla"  # retângulo com texto (tecla do teclado ou botão largo do controle)
const FACE := "face"  # botão redondo com letra (A, B, X, Y)
const PS := "ps"  # botão redondo com símbolo (cruz, bola, quadrado, triângulo)
const MOUSE := "mouse"  # mouse em pixel art; o texto é o botão destacado: "e" (esquerdo), "d" (direito), "m" (do meio) ou "" (nenhum)
const COR_MOUSE_CORPO := Color("#2b2838")
const COR_MOUSE_BOTAO := Color("#3d3a52")
const COR_MOUSE_ATIVO := Color("#ffd166")  # o botão a apertar, em ouro; sem o tom da acao, no HUD o selo troca pela cor do slot
const ALTURA_SELO := 16.0  # o selo de tecla do HUD (E, Q, secundário): a mesma altura dos glifos, num nó com escala 1,5 (24 px de canvas)
const TAM_SELO := 12  # a letra do selo do HUD: 1,5x a de 8 que ele tinha (o Alisson achou o E, o Q e o mouse pequenos demais)

## O mouse desenhado pixel a pixel (cada caractere é um pixel inteiro): '#' contorno, 'L' botão esquerdo, 'M' roda, 'R' botão direito, '.' corpo e espaço = transparente.
const MOUSE_GRANDE := [
	"  ########  ",
	"#LLL#MM#RRR#",
	"#LLL#MM#RRR#",
	"#LLL#MM#RRR#",
	"#LLL#MM#RRR#",
	"#LLL#MM#RRR#",
	"############",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	" ########## ",
]
## ação -> [teclado, xbox, ps]; cada um é uma lista de [tipo, texto]. Vazio = não existe nesse dispositivo.
const TABELA := {
	"confirmar": [[[TECLA, "Enter"]], [[FACE, "A"]], [[PS, "x"]]],
	"voltar": [[[TECLA, "Esc"]], [[FACE, "B"]], [[PS, "o"]]],
	"pausa": [[[TECLA, "Esc"]], [[TECLA, "Menu"]], [[TECLA, "Options"]]],
	"rerrolar": [[[TECLA, "R"]], [[FACE, "X"]], [[PS, "q"]]],
	"automatico": [[[TECLA, "Q"]], [[FACE, "Y"]], [[PS, "t"]]],
	"banir": [[[TECLA, "B"]], [[TECLA, "LB"]], [[TECLA, "L1"]]],
	"aba_anterior": [[[TECLA, "Q"]], [[TECLA, "LB"]], [[TECLA, "L1"]]],
	"aba_proxima": [[[TECLA, "E"]], [[TECLA, "RB"]], [[TECLA, "R1"]]],
	"abas": [[[TECLA, "Q"], [TECLA, "E"]], [[TECLA, "LB"], [TECLA, "RB"]], [[TECLA, "L1"], [TECLA, "R1"]]],
	"detalhes": [[[TECLA, "Tab"]], [[FACE, "Y"]], [[PS, "t"]]],
	"card": [[[TECLA, "C"]], [[TECLA, "View"]], [[TECLA, "Share"]]],
	"navegar": [[[TECLA, "Setas"]], [[TECLA, "D-pad"]], [[TECLA, "D-pad"]]],
	"andar": [[[TECLA, "Setas"]], [[TECLA, "Stick"]], [[TECLA, "Stick"]]],
	"habilidade": [[[TECLA, "E"]], [[TECLA, "LB"]], [[TECLA, "L1"]]],
	"ultimate": [[[TECLA, "Q"]], [[TECLA, "RB"]], [[TECLA, "R1"]]],
	"secundario": [[[MOUSE, "d"]], [[TECLA, "LT"]], [[TECLA, "L2"]]],
	"clique": [[[MOUSE, "e"]], [[TECLA, "RT"]], [[TECLA, "R2"]]],
	"mouse": [[[MOUSE, ""]], [], []],  # só existe no teclado: a dica "mouse também" some no controle
	"correr": [[[TECLA, "Shift"]], [[TECLA, "L3"]], [[TECLA, "L3"]]],
	"esquiva": [[[TECLA, "Espaço"]], [[FACE, "B"]], [[PS, "o"]]],
}

static var disp: int = Disp.TECLADO
static var forcado := false  # --controle=...: a detecção fica parada
static var _ouvintes: Array[Callable] = []
static var _no: Node


## Cria (uma vez) o nó que escuta toda a entrada da janela. Idempotente; as telas chamam por Entrada.garantir().
static func instalar() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--controle="):
			var v := a.get_slice("=", 1).to_lower()
			if v in NOMES:
				definir(NOMES.find(v))
				forcado = true
	var arv := Engine.get_main_loop() as SceneTree
	if arv == null or (_no != null and is_instance_valid(_no)):
		return
	_no = No.new()
	_no.name = "GlifosV2"
	_no.process_mode = Node.PROCESS_MODE_ALWAYS
	arv.root.add_child.call_deferred(_no)


## O que um evento diz sobre o dispositivo em uso. Mouse parado ou analógico de leve (deriva) não troca nada.
static func observar(e: InputEvent) -> void:
	if forcado:
		return
	if e is InputEventKey:
		if e.pressed:
			definir(Disp.TECLADO)
	elif e is InputEventMouseButton:
		if e.pressed:
			definir(Disp.TECLADO)
	elif e is InputEventMouseMotion:
		if e.relative.length() > 2.0:
			definir(Disp.TECLADO)
	elif e is InputEventJoypadButton:
		if e.pressed:
			definir(tipo_joy(e.device))
	elif e is InputEventJoypadMotion:
		if absf(e.axis_value) > 0.6:
			definir(tipo_joy(e.device))


## Xbox ou PlayStation pelo nome que o sistema dá ao controle. Qualquer outro cai no layout do Xbox (é o que o Godot normaliza).
static func tipo_joy(device: int) -> int:
	return tipo_pelo_nome(Input.get_joy_name(device))


static func tipo_pelo_nome(nome: String) -> int:
	var n := nome.to_lower()
	if n.contains("xbox") or n.contains("xinput"):
		return Disp.XBOX
	for p in PS_NOMES:
		if n.contains(p):
			return Disp.PS
	return Disp.XBOX


static func definir(d: int) -> void:
	if d == disp:
		return
	disp = d
	var vivos: Array[Callable] = []
	for c in _ouvintes:
		if c.is_valid():
			vivos.append(c)
			c.call()
	_ouvintes = vivos


## Avisa quando o dispositivo troca. Callable de nó liberado é descartado sozinho.
static func ao_mudar(c: Callable) -> void:
	_ouvintes.append(c)


static func eh_controle() -> bool:
	return disp != Disp.TECLADO


## Lista de [tipo, texto] do botão da ação no dispositivo atual (vazia se a ação não existe nele).
static func descritor(acao: String) -> Array:
	var t: Array = TABELA.get(acao, [])
	return t[disp] if not t.is_empty() else []


## Só texto curto da ação (para o que é desenhado por código): "Esc", "A", "LB/RB". Cruz, bola, quadrado e triângulo viram X, O, Quad e Tri.
static func texto(acao: String) -> String:
	var partes: Array[String] = []
	for d in descritor(acao):
		var t: String = d[1]
		if d[0] == PS:
			t = {"x": "Cruz", "o": "Bola", "q": "Quad.", "t": "Tri."}[t]
		elif d[0] == MOUSE:
			t = {"e": "Mouse E", "d": "Mouse D", "m": "Mouse M", "": "Mouse"}[t]
		partes.append(t)
	return "/".join(partes)


## Largura em px do glifo de um descritor.
static func largura(d: Array) -> float:
	if d[0] == MOUSE:
		return float(String(MOUSE_GRANDE[0]).length())
	if d[0] == TECLA:
		return maxf(ALTURA, 8.0 * float(String(d[1]).length()) + 8.0)
	return ALTURA


## Largura do conjunto de glifos de uma ação (com 2 px entre eles).
static func largura_acao(acao: String) -> float:
	var w := 0.0
	var ds := descritor(acao)
	for i in ds.size():
		w += largura(ds[i]) + (2.0 if i > 0 else 0.0)
	return w


## Desenha todos os glifos de uma ação (2 px entre eles) na posição e devolve a largura usada: para o que é desenhado por código.
static func desenhar_acao(ci: CanvasItem, acao: String, pos: Vector2) -> float:
	var ds := descritor(acao)
	var x := 0.0
	for i in ds.size():
		x += desenhar(ci, ds[i], pos + Vector2(x, 0.0)) + (2.0 if i < ds.size() - 1 else 0.0)
	return x


## Desenha o glifo na posição (canto de cima à esquerda) e devolve a largura usada.
static func desenhar(ci: CanvasItem, d: Array, pos: Vector2) -> float:
	var w := largura(d)
	var c := pos + Vector2(w * 0.5, ALTURA * 0.5)
	match d[0]:
		MOUSE:
			desenhar_mouse(ci, String(d[1]), pos)
		TECLA:
			var r := Rect2(pos, Vector2(w, ALTURA))
			ci.draw_rect(r, COR_TECLA_BAIXO)
			ci.draw_rect(Rect2(pos, Vector2(w, ALTURA - 2.0)), COR_TECLA_BORDA)
			ci.draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w - 2.0, ALTURA - 4.0)), COR_TECLA)
			_letra(ci, String(d[1]), c + Vector2(0, -1), Paleta.TEXTO)
		FACE:
			ci.draw_circle(c, 8.0, COR_PS_BORDA)
			ci.draw_circle(c, 7.0, COR_FACE[d[1]])
			_letra(ci, String(d[1]), c, Paleta.PAINEL)
		PS:
			ci.draw_circle(c, 8.0, COR_PS_BORDA)
			ci.draw_circle(c, 7.0, COR_PS_FUNDO)
			var cor: Color = COR_PS[d[1]]
			match d[1]:
				"x":
					ci.draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), cor, 2.0)
					ci.draw_line(c + Vector2(-3, 3), c + Vector2(3, -3), cor, 2.0)
				"o":
					ci.draw_arc(c, 3.5, 0.0, TAU, 16, cor, 2.0)
				"q":
					ci.draw_rect(Rect2(c + Vector2(-3, -3), Vector2(6, 6)), cor, false, 2.0)
				"t":
					ci.draw_polyline(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 3), c + Vector2(-4, 3), c + Vector2(0, -4)]), cor, 2.0)
	return w


## O mouse em pixel art na posição (canto de cima à esquerda), com o botão `qual` aceso ("e", "d", "m" ou "" para nenhum); devolve a largura.
## `acento` é a cor do botão aceso e `contorno` a do contorno (no HUD, a cor do slot).
static func desenhar_mouse(ci: CanvasItem, qual: String, pos: Vector2, acento: Color = COR_MOUSE_ATIVO, contorno: Color = COR_TECLA_BORDA) -> float:
	for px in pixels_mouse(qual):
		var cor: Color
		match px[1]:
			"#":
				cor = contorno
			"A":
				cor = acento
			"B":
				cor = COR_MOUSE_BOTAO
			_:
				cor = COR_MOUSE_CORPO
		ci.draw_rect(Rect2(pos + Vector2(px[0]), Vector2.ONE), cor)
	return float(String(MOUSE_GRANDE[0]).length())


## Os pixels do mouse: lista de [Vector2i, tipo], com tipo "#" (contorno), "A" (botão aceso), "B" (botão apagado) ou "." (corpo). O que desenhar_mouse pinta, e o
## que o teste confere.
static func pixels_mouse(qual: String) -> Array:
	var mapa: Array = MOUSE_GRANDE
	var aceso := {"e": "L", "d": "R", "m": "M"}.get(qual, "") as String
	var r: Array = []
	for y in mapa.size():
		var linha: String = mapa[y]
		for x in linha.length():
			var ch := linha[x]
			if ch == " ":
				continue
			var tipo := ch
			if ch in ["L", "M", "R"]:
				tipo = "A" if ch == aceso else "B"
			r.append([Vector2i(x, y), tipo])
	return r


## Largura do selo de tecla do HUD de uma ação: o mouse inteiro (12 px) ou a teclinha com a letra na TAM_SELO e 4 px de folga de cada lado.
static func largura_selo(acao: String) -> float:
	var ds := descritor(acao)
	if ds.is_empty():
		return 0.0
	if ds[0][0] == MOUSE:
		return largura(ds[0])
	return maxf(ALTURA_SELO, Dados.fonte.get_string_size(texto(acao), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_SELO).x + 8.0)


## O selo de tecla do HUD (E, Q e secundário), centrado em `centro_x` com o topo em `topo`. Aceso: o contorno na cor do slot e a letra (ou o botão do
## mouse) em BRANCO, o máximo de contraste sobre o fundo escuro; apagado, tudo em `apagado`.
static func desenhar_selo(ci: CanvasItem, acao: String, centro_x: float, topo: float, cor: Color, aceso: bool, apagado: Color) -> void:
	var w := largura_selo(acao)
	if w <= 0.0:
		return
	var pos := Vector2(roundf(centro_x - w * 0.5), topo)
	var borda := cor if aceso else apagado
	var tinta := Paleta.BRANCO if aceso else apagado
	var ds := descritor(acao)
	if ds[0][0] == MOUSE:
		desenhar_mouse(ci, String(ds[0][1]), pos, tinta, borda)
		return
	var r := Rect2(pos, Vector2(w, ALTURA_SELO))
	ci.draw_rect(r, borda)
	ci.draw_rect(r.grow(-1.0), Color(Paleta.PAINEL, 0.98))
	_letra(ci, texto(acao), r.get_center(), tinta, TAM_SELO)


static func _letra(ci: CanvasItem, txt: String, centro: Vector2, cor: Color, tam: int = 8) -> void:
	var f: Font = Dados.fonte
	var l := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var base := centro.y + (f.get_ascent(tam) - f.get_descent(tam)) * 0.5
	ci.draw_string(f, Vector2(roundf(centro.x - l * 0.5), roundf(base)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, cor)


## Dica de rodapé: uma faixa de pares glifo + texto, desenhada na caixa do controle, que se refaz quando o dispositivo troca.
## `gerador` devolve a lista [[acao, "texto"], ...] (acao "" = só texto, texto "" = só glifo); chamado a cada troca de dispositivo.
static func dica(gerador: Callable, alin: int = HORIZONTAL_ALIGNMENT_CENTER, cor: Color = Paleta.TEXTO_APAGADO) -> Control:
	var d := Dica.new()
	d.gerador = gerador
	d.alin = alin
	d.cor = cor
	return d


## Um glifo só (sem texto) de uma ação, para pôr dentro de um botão ou ao lado de um rótulo.
static func glifo(acao: String, alin: int = HORIZONTAL_ALIGNMENT_LEFT) -> Control:
	return dica(func() -> Array: return [[acao, ""]], alin)


class No:
	extends Node

	func _input(e: InputEvent) -> void:
		G.observar(e)


class Dica:
	extends Control
	var gerador: Callable
	var alin := HORIZONTAL_ALIGNMENT_CENTER
	var cor := Color.WHITE
	var tam := 16
	var folga := 20.0  # entre um par e o seguinte
	var _itens: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		G.ao_mudar(atualizar)

	func _ready() -> void:
		atualizar()

	func atualizar() -> void:
		_itens = gerador.call() if gerador.is_valid() else []
		queue_redraw()
		update_minimum_size()

	func _get_minimum_size() -> Vector2:
		return Vector2(_largura_total(), G.ALTURA)

	func _largura_total() -> float:
		var w := 0.0
		var n := 0
		for it in _itens:
			var wi := _largura_item(it)
			if wi > 0.0:
				w += wi + (folga if n > 0 else 0.0)
				n += 1
		return w

	func _largura_item(it: Array) -> float:
		var g := G.largura_acao(it[0]) if str(it[0]) != "" else 0.0
		var tx := Dados.fonte_texto.get_string_size(str(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x if str(it[1]) != "" else 0.0
		if str(it[0]) != "" and g == 0.0:
			return 0.0  # a ação não existe neste dispositivo: o par inteiro some (ex.: "Mouse também" no controle)
		return g + (6.0 if g > 0.0 and tx > 0.0 else 0.0) + tx

	func _draw() -> void:
		var x := 0.0
		var total := _largura_total()
		if alin == HORIZONTAL_ALIGNMENT_CENTER:
			x = roundf((size.x - total) * 0.5)
		elif alin == HORIZONTAL_ALIGNMENT_RIGHT:
			x = size.x - total
		var y0 := roundf((size.y - G.ALTURA) * 0.5)
		var f: Font = Dados.fonte_texto
		var base := y0 + roundf((G.ALTURA + f.get_ascent(tam) - f.get_descent(tam)) * 0.5)
		for it in _itens:
			if _largura_item(it) <= 0.0:
				continue
			if str(it[0]) != "":
				var ds := G.descritor(it[0])
				for i in ds.size():
					x += G.desenhar(self, ds[i], Vector2(x, y0)) + (2.0 if i < ds.size() - 1 else 0.0)
				if str(it[1]) != "":
					x += 6.0
			if str(it[1]) != "":
				draw_string(f, Vector2(x, base), str(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, cor)
				x += f.get_string_size(str(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			x += folga
