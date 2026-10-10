extends CanvasLayer
## Tela de inventário e status (#125): segurando Tab (teclado) ou Back (controle) mostra armas (nível e tamanho do
## crescimento), passivos, equipamentos, conjuntos e todos os atributos. Cada atributo tem o valor base em cinza e a variação
## dos itens em verde (melhorou) ou vermelho (piorou). No solo o jogo pausa enquanto a tela está aberta; no online não pausa.
## Também avisa por 2 s quando um conjunto de etiquetas liga um degrau novo (o aviso que saía da lista do HUD).
## Os dados vêm de arena.stat(), Construcao, Crescimento e Conjuntos; as contas puras são estáticas (testes/status.gd chama direto).
## Quem cria é a arena (um nó filho, `arena.tela_status`). Sem a ação "status" no InputMap a tela só abre por abrir().

const Interface := preload("res://scripts/hordas/interface.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const Cresc := preload("res://scripts/hordas/crescimento.gd")
const Conjuntos := preload("res://scripts/hordas/conjuntos.gd")
const TEMA := preload("res://cenas/tema_hud.tres")
const W := 640.0
const H := 360.0
const CINZA := Color(0.62, 0.62, 0.68)
## ordem das linhas de atributo na tela
const ATRIBUTOS := ["vida_max", "regen", "dano", "recarga", "area", "duracao", "quantidade", "velocidade_proj", "velocidade", "ima", "critico", "critico_mult", "sorte", "xp"]
const ROTULO_EXTRA := {"critico_mult": "Dano crít.", "velocidade_proj": "Vel. tiro", "velocidade": "Vel. andar", "vida_max": "Vida", "duracao": "Duração"}

var arena: Node
var aberta := false
var fixa := false              # teste/print: não fecha sozinha
var _pausei := false
var _tela := Control.new()


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	_tela.visible = false


func _exit_tree() -> void:
	if _pausei and is_inside_tree():
		get_tree().paused = false


# ---------- contas puras (o teste chama direto) ----------

## Valor como o jogador lê: porcentagem para os atributos multiplicativos, número cru para os outros.
static func fmt_valor(k: String, v: float) -> String:
	if k in Interface.PERCENTUAL:
		return "%d%%" % roundi(v * 100.0)
	if k == "critico_mult":
		return "x%.2f" % v
	if k == "regen":
		return "%.1f/s" % v
	return "%d" % roundi(v) if absf(v - roundf(v)) < 0.005 else "%.1f" % v


static func fmt_delta(k: String, d: float) -> String:
	if k in Interface.PERCENTUAL:
		return "%+d%%" % roundi(d * 100.0)
	if k == "critico_mult":
		return "%+.2f" % d
	if k == "regen":
		return "%+.1f/s" % d
	return "%+d" % roundi(d) if absf(d - roundf(d)) < 0.05 else "%+.1f" % d


## Uma linha por atributo: {k, rot, base, delta, txt_base, txt_delta, sentido}. `sentido` = +1 melhorou (verde),
## -1 piorou (vermelho), 0 igual. Recarga é o contrário do resto: menos recarga é melhor, então cair é verde.
static func linhas_atributos(base: Dictionary, atual: Dictionary) -> Array:
	var r: Array = []
	for k in ATRIBUTOS:
		var b := float(base.get(k, Construcao.BASE.get(k, 0.0)))
		var a := float(atual.get(k, b))
		var d := a - b
		var sentido := 0
		if absf(d) >= 0.0005:
			sentido = 1 if d > 0.0 else -1
			if k in Interface.MENOR_MELHOR:
				sentido = -sentido
		r.append({"k": k, "rot": str(ROTULO_EXTRA.get(k, Interface.ROTULOS.get(k, k.capitalize()))), "base": b, "delta": d, "txt_base": fmt_valor(k, b),
			"txt_delta": fmt_delta(k, d) if sentido != 0 else "", "sentido": sentido})
	return r


## Os atributos da build agora: {k: valor atual} (arena.stat) e {k: base do herói sem item nenhum}.
static func atuais(arena) -> Dictionary:
	var d := {}
	for k in ATRIBUTOS:
		d[k] = arena.stat(k)
	return d


static func bases(arena) -> Dictionary:
	return Construcao.stats(arena.heroi, {}, {}, {})


## Armas da build: {id, nome, nivel, nivel_max, tamanho (multiplicador de área do crescimento), dano (idem), evoluida, icone}.
static func armas_info(arena) -> Array:
	var r: Array = []
	for a in arena.armas.lista:
		var d := Dados.item(str(a.id))
		r.append({"id": str(a.id), "nome": str(d.get("nome", a.id)), "nivel": int(a.nivel), "nivel_max": Cresc.nivel_max(str(a.id)),
			"tamanho": Cresc.mult(str(a.id), int(a.nivel), "area"), "dano": Cresc.mult(str(a.id), int(a.nivel), "dano"),
			"evoluida": Cresc.evoluida(str(a.id)), "icone": str(d.get("icone", a.id))})
	return r


static func passivos_info(arena) -> Array:
	var r: Array = []
	var pas: Dictionary = Dados.json("passivos")
	for id in arena.passivos:
		var d: Dictionary = pas.get(id, {})
		r.append({"id": str(id), "nome": str(d.get("nome", id)), "nivel": int(arena.passivos[id]), "nivel_max": int(d.get("max", 5)), "icone": str(d.get("icone", id))})
	return r


static func equipamentos_info(arena) -> Array:
	var r: Array = []
	for slot in arena.equipamentos:
		var id := str(arena.equipamentos[slot])
		var d := Dados.item(id)
		r.append({"slot": str(slot), "id": id, "nome": str(d.get("nome", id)), "icone": str(d.get("icone", id))})
	return r


# ---------- abrir e fechar ----------

func pode_abrir() -> bool:
	if arena == null or get_tree().paused or bool(arena.get("acabou")):
		return false
	return arena.get("jogador") != null


func abrir() -> void:
	if aberta:
		return
	aberta = true
	_tela.visible = true
	_pausei = false
	if not bool(arena.get("eh_online")):   # solo pausa; online o mundo segue
		get_tree().paused = true
		_pausei = true
	_tela.queue_redraw()


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	fixa = false
	_tela.visible = false
	if _pausei:
		get_tree().paused = false
	_pausei = false


func _process(_dt: float) -> void:
	if arena == null:
		return
	var quer: bool = InputMap.has_action("status") and Input.is_action_pressed("status")
	if not aberta and quer and pode_abrir():
		abrir()
	elif aberta and not quer and not fixa:
		fechar()
	elif aberta and bool(arena.get("acabou")):
		fechar()
	if aberta:
		_tela.queue_redraw()


# ---------- desenho ----------

func _txt(p: Vector2, s: String, tam: int, cor: Color, al := HORIZONTAL_ALIGNMENT_LEFT, larg := -1.0) -> void:
	var f: Font = Dados.fonte
	_tela.draw_string(f, p + Vector2(1, 1), s, al, larg, tam, Color(0, 0, 0, 0.85))
	_tela.draw_string(f, p, s, al, larg, tam, cor)


## Texto encostado à direita em `x_dir` (a conta do alinhamento é feita aqui: o draw_string só alinha dentro de uma largura).
func _dir(x_dir: float, y: float, s: String, tam: int, cor: Color) -> void:
	var w: float = Dados.fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_txt(Vector2(x_dir - w, y), s, tam, cor)


func _titulo(p: Vector2, s: String, tam: int, cor: Color, al := HORIZONTAL_ALIGNMENT_LEFT, larg := -1.0) -> void:
	var f: Font = Dados.fonte_titulo if Dados.fonte_titulo != null else Dados.fonte
	_tela.draw_string(f, p + Vector2(1, 1), s, al, larg, tam, Color(0, 0, 0, 0.9))
	_tela.draw_string(f, p, s, al, larg, tam, cor)


func _icone(p: Vector2, nome: String) -> void:
	var t := Dados.icone(nome)
	if t:
		_tela.draw_texture_rect(t, Rect2(p, Vector2(16, 16)), false)


func _cabeca(x: float, y: float, s: String, larg: float) -> void:
	_titulo(Vector2(x, y), s, 12, Interface.cor("destaque"))
	_tela.draw_rect(Rect2(x, y + 3, larg, 1), Color(Interface.cor("destaque"), 0.45))


func _desenhar() -> void:
	if arena == null:
		return
	if aberta:
		_painel()


func _painel() -> void:
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.01, 0.05, 0.96))
	TEMA.get_stylebox("panel", "PanelContainer").draw(_tela.get_canvas_item(), Rect2(8, 8, W - 16, H - 16))   # painel do tema do HUD (cenas/tema_hud.tres)
	var nome := str(arena.heroi.get("nome", ""))
	_titulo(Vector2(20, 34), "Status", 24, Color(1, 0.92, 0.7))
	_txt(Vector2(150, 32), "%s  Nv %d" % [nome, int(arena.nivel)], 8, CINZA)
	_dir(W - 20, 32, "Solte para fechar", 8, CINZA)
	# coluna 1: armas e passivos
	var x := 20.0
	var y := 62.0
	_cabeca(x, y, "Armas", 190)
	y += 12.0
	for a in armas_info(arena):
		_icone(Vector2(x, y), a.icone)
		var cor: Color = Interface.cor("evolucao") if a.evoluida else Interface.cor("arma")
		_txt(Vector2(x + 20, y + 8), str(a.nome).left(14), 8, cor)
		_dir(x + 190, y + 8, "EVO" if a.evoluida else "Nv%d" % a.nivel, 8, Color.WHITE)
		_txt(Vector2(x + 20, y + 18), "Tam x%.2f  Dano x%.2f" % [a.tamanho, a.dano], 8, CINZA)
		y += 24.0
	y += 4.0
	_cabeca(x, y, "Passivos", 190)
	y += 12.0
	for p in passivos_info(arena):
		_icone(Vector2(x, y - 2), p.icone)
		_txt(Vector2(x + 20, y + 9), str(p.nome).left(15), 8, Interface.cor("passivo"))
		_dir(x + 190, y + 9, "%d/%d" % [p.nivel, p.nivel_max], 8, Color.WHITE)
		y += 16.0
	# coluna 2: equipamentos e conjuntos
	x = 222.0
	y = 62.0
	_cabeca(x, y, "Equipamentos", 186)
	y += 12.0
	var eq := equipamentos_info(arena)
	if eq.is_empty():
		_txt(Vector2(x, y + 9), "Nada vestido", 8, CINZA)
		y += 16.0
	for e in eq:
		_icone(Vector2(x, y - 2), e.icone)
		_txt(Vector2(x + 20, y + 9), str(e.nome).left(22), 8, Interface.cor("equipamento"))
		y += 16.0
	y += 6.0
	_cabeca(x, y, "Conjuntos", 186)
	y += 12.0
	var lin: Array = arena.conj_resumo
	if lin.is_empty():
		_txt(Vector2(x, y + 9), "Nenhum ainda", 8, CINZA)
	for i in mini(lin.size(), 6):
		var l: Dictionary = lin[i]
		var lig: bool = int(l.ativo) > 0
		var cor: Color = l.cor if lig else Color(l.cor, 0.5).lerp(CINZA, 0.5)
		_tela.draw_rect(Rect2(x, y + 2, 5, 5), cor)
		_txt(Vector2(x + 9, y + 9), "%s %s" % [str(l.nome).left(15), Conjuntos.progresso_txt(l)], 8, cor)
		y += 11.0
		if lig:   # o texto do degrau ligado quebra em até 2 linhas
			var f: Font = Dados.fonte
			var tx := str(l.texto)
			_tela.draw_multiline_string(f, Vector2(x + 9, y + 9), tx, HORIZONTAL_ALIGNMENT_LEFT, 176.0, 8, 2, Color(0.85, 0.9, 1.0))
			y += f.get_multiline_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, 176.0, 8, 2).y + 1.0
		y += 3.0
	# coluna 3: atributos
	x = 424.0
	y = 62.0
	_cabeca(x, y, "Atributos", 196)
	y += 12.0
	var cb: Color = Interface.cor("bom")
	var cr: Color = Interface.cor("ruim")
	for l in linhas_atributos(bases(arena), atuais(arena)):
		_txt(Vector2(x, y + 9), str(l.rot), 8, Color(0.9, 0.9, 0.95))
		_dir(x + 132, y + 9, str(l.txt_base), 8, CINZA)
		if l.sentido != 0:
			_dir(x + 196, y + 9, str(l.txt_delta), 8, cb if l.sentido > 0 else cr)
		y += 16.0
	_txt(Vector2(x, y + 12), "cinza: base  cor: itens", 8, CINZA)
