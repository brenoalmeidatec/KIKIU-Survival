extends Control
## Faixa de GOLPES do HUD da v2: um quadradinho fixo por golpe automático que o herói tem (bola de fogo, lâminas rodopiantes, corvos, raio,
## runa, aura, golem, lobo...), no canto inferior esquerdo, ao lado do selo de nível. Antes isto só aparecia na pausa ("GOLPES AUTOMÁTICOS").
## Cada quadradinho: o ícone próprio da carta (32x32, 1 para 1), uma linha de recarga embaixo do ícone (só nos golpes que têm recarga:
## corvos, raio, runa, projétil, nuvem, anel, meteoro e aliado; lâmina e aura batem sem parar), uma linha magenta do progresso da fusão
## (soma dos níveis das peças da receita, limitados ao pedido, sobre o total pedido; pisca quando falta só um nível) e os pips de nível.
## A peça já fundida ganha a moldura dourada e os pips dourados cheios.
## Animação: golpe novo entra com pop, anel, faíscas e brilho; nível novo dá um pulso dourado e o pip novo pisca; a fusão dá o mesmo em
## magenta. Tudo desenhado por código, em pixel inteiro, num só Control.
## Custo: lê o combate a 20 Hz (no máximo uns doze golpes), e só redesenha quando a chave (golpes, níveis, pixels de recarga e de fusão)
## muda ou enquanto há animação. Sem `combate` no mundo (mundo falso dos testes), a faixa fica escondida. Com o card da build aberto
## (tecla C, que ocupa a coluna da esquerda) ou na pausa, a faixa se esconde: o card já lista os golpes.
## Lê, com get() e valor padrão: hud.mundo; mundo.combate (.armas.ativas, .cartas), mundo.heroi.m_vel_ataque, mundo.status.aberto().

const Paleta := preload("res://v2/paleta.gd")
const ICONE := 32  # lado do ícone da carta (assets/v2/icones_cartas): sai 1 para 1
const CAIXA := 36  # lado da caixa do ícone: moldura de 1 px + 1 px de folga em volta
const ALTURA := 44  # caixa (36) + linha de fusão (2) + pips (3) + folgas
const ESPACO := 2
const POR_LINHA := 6  # 6 por linha: a faixa acaba em x 234, antes do selo de nível (x 262)
const LINHAS_MAX := 3  # 18 golpes; passou disso, o excedente vira um "+N"
const CAPACIDADE := POR_LINHA * LINHAS_MAX
const BASE := Vector2(6.0, 534.0)  # canto inferior esquerdo da faixa (a linha de baixo termina em y 534, como o selo de nível)
const LEITURA_S := 0.05  # lê o combate a 20 Hz
const ANIM_S := 0.5  # duração do pop/pulso
const FAISCAS := 8
const PIP_L := 5
const PIP_A := 3
const FUNDO := Color(Paleta.PAINEL, 0.88)
const TRILHO := Color(Paleta.BARRA_BORDA, 0.9)
const TIPOS_RECARGA := ["corvos", "raio", "runa", "projetil", "nuvem", "anel", "meteoro", "aliado"]

## O que está na faixa agora, em ordem de aquisição: [{id, nivel, max, evo, cor, rec (px 0..32 ou -1), fus (px 0..32 ou -1), quase}].
var itens: Array = []
## Segundos que faltam da animação de cada golpe (id -> {t, tipo}); públicos para os testes.
var anims := {}
## Quantos redesenhos a faixa pediu (os testes conferem que parada não pede nenhum).
var pedidos := 0
var _hud = null
var _chave := ""
var _vistos := {}  # id -> [nivel, evo] na leitura anterior
var _iniciado := false  # a primeira leitura só registra: golpes que já existiam não animam
var _acumulado := 0.0
var _fase_quase := 0
var _chave_desenhada := ""


func _ready() -> void:
	size = Vector2(POR_LINHA * (CAIXA + ESPACO), LINHAS_MAX * ALTURA)
	position = BASE - Vector2(0.0, size.y)
	light_mask = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	_hud = get_parent().get_parent()


func _process(delta: float) -> void:
	avancar(delta)


## Um quadro: lê o combate de tempos em tempos, avança as animações e pede redesenho só se algo mudou. Os testes chamam isto direto.
func avancar(dt: float) -> void:
	_acumulado += dt
	var mudou := false
	if _acumulado >= LEITURA_S or not _iniciado:
		_acumulado = 0.0
		mudou = _ler()
	var animando := false
	for id in anims.keys():
		anims[id].t = float(anims[id].t) - dt
		if float(anims[id].t) <= 0.0:
			anims.erase(id)
		animando = true
	_fase_quase = int(Time.get_ticks_msec() / 250) % 2
	var pisca := false
	for it in itens:
		pisca = pisca or bool(it.quase)
	var chave := _chave + ("|q%d" % _fase_quase if pisca else "")
	if mudou or animando or chave != _chave_desenhada:
		_chave_desenhada = chave
		pedidos += 1
		queue_redraw()


## O retângulo que a faixa ocupa agora, em coordenadas de 960x540 (vazio sem golpes). Os testes conferem que não cruza o resto do HUD.
func area_ocupada() -> Rect2:
	var n := mini(itens.size(), CAPACIDADE)
	if n == 0:
		return Rect2()
	var colunas := mini(n, POR_LINHA)
	var linhas := ceili(float(n) / POR_LINHA)
	return Rect2(BASE.x, BASE.y - linhas * ALTURA, colunas * (CAIXA + ESPACO) - ESPACO, linhas * ALTURA)


## Lê o combate e monta `itens`; dispara as animações do que chegou ou subiu. Devolve true se a chave visível mudou.
func _ler() -> bool:
	var mundo = _campo(_hud, "mundo")
	var combate = _campo(mundo, "combate")
	var armas = _campo(combate, "armas")
	var ativas = _campo(armas, "ativas")
	var novos: Array = []
	if ativas is Dictionary:
		var cartas = _campo(combate, "cartas")
		var vel := maxf(float(_campo(_campo(mundo, "heroi"), "m_vel_ataque", 1.0)), 0.1)
		for id in ativas:
			novos.append(_item(str(id), ativas[id], cartas, vel))
	var st = _campo(mundo, "status")
	var escondido: bool = novos.is_empty() or (st != null and st.has_method("aberto") and st.aberto())
	if visible == escondido:
		visible = not escondido
	var partes: PackedStringArray = []
	for it in novos:
		partes.append("%s,%d,%d,%d,%d" % [it.id, it.nivel, int(it.evo), it.rec, it.fus])
	var chave := ",".join(partes)
	_animar_chegadas(novos)
	itens = novos
	if chave == _chave:
		return false
	_chave = chave
	return true


func _item(id: String, a: Dictionary, cartas, vel: float) -> Dictionary:
	var evo: bool = bool(a.get("evo", false))
	var def = cartas.definicao(id) if cartas != null and cartas.has_method("definicao") else {}
	var it := {
		"id": id,
		"nivel": int(a.get("nivel", 1)),
		"max": 5 if evo or not def is Dictionary or not def.has("max") else int(def.max),
		"evo": evo,
		"cor": a.get("cor", Paleta.OURO),
		"rec": -1,
		"fus": -1,
		"quase": false
	}
	var st: Dictionary = a.get("st", {})
	if TIPOS_RECARGA.has(str(a.get("tipo", ""))) and st.has("recarga"):
		var dur := maxf(float(st.recarga) / vel, 0.05)
		it.rec = roundi((1.0 - clampf(float(a.get("t", 0.0)) / dur, 0.0, 1.0)) * ICONE)
	if not evo and cartas != null:
		var f := _fusao(id, cartas)
		if f.x >= 0.0:
			it.fus = roundi(f.x * ICONE)
			it.quase = f.y <= 1.0
	return it


## O melhor progresso de fusão das receitas ainda livres que usam `id`: x = fração (soma dos níveis das peças limitados ao pedido sobre o
## total pedido) e y = quantos níveis faltam no total. x = -1 quando nenhuma receita livre usa o golpe.
func _fusao(id: String, cartas) -> Vector2:
	var melhor := Vector2(-1.0, 99.0)
	var cfg = _campo(cartas, "cfg")
	if not cfg is Dictionary or not cartas.has_method("nivel_de"):
		return melhor
	for ev in cfg.get("evolucoes", []):
		var usa := false
		for p in ev.pecas:
			usa = usa or str(p.id) == id
		if not usa or (cartas.has_method("_evo_livre") and not cartas._evo_livre(ev)):
			continue
		var tem := 0
		var total := 0
		for p in ev.pecas:
			tem += mini(cartas.nivel_de(str(p.id)), int(p.nivel))
			total += int(p.nivel)
		var f := float(tem) / float(maxi(total, 1))
		if f > melhor.x:
			melhor = Vector2(f, float(total - tem))
	return melhor


## Compara com a leitura anterior: golpe novo = pop; nível novo = pulso; virou fusão = pulso magenta. Quem some (consumido pela fusão) sai sem aviso.
func _animar_chegadas(novos: Array) -> void:
	var agora := {}
	for it in novos:
		var id: String = it.id
		agora[id] = [it.nivel, it.evo]
		if not _iniciado:
			continue
		if not _vistos.has(id):
			anims[id] = {"t": ANIM_S, "tipo": "fusao" if it.evo else "novo"}
		elif it.nivel > _vistos[id][0]:
			anims[id] = {"t": ANIM_S, "tipo": "nivel"}
	for id in anims.keys():
		if not agora.has(id):
			anims.erase(id)
	_vistos = agora
	_iniciado = true


# ------------------------------------------------------------------ desenho


func _draw() -> void:
	var n := mini(itens.size(), CAPACIDADE)
	for i in n:
		_desenhar_slot(i, itens[i])
	if itens.size() > CAPACIDADE:
		var f := get_theme_font("font")
		draw_string(f, Vector2(0.0, 8.0), "+%d" % (itens.size() - CAPACIDADE), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Paleta.TEXTO_SECUNDARIO)


func _origem(i: int) -> Vector2:
	return Vector2((i % POR_LINHA) * (CAIXA + ESPACO), size.y - (i / POR_LINHA + 1) * ALTURA)


func _desenhar_slot(i: int, it: Dictionary) -> void:
	var o := _origem(i)
	var an: Dictionary = anims.get(it.id, {})
	var u := 1.0 - float(an.t) / ANIM_S if not an.is_empty() else 1.0
	var tipo: String = an.get("tipo", "")
	var cor: Color = it.cor
	var cor_an: Color = Paleta.FUSAO if tipo == "fusao" else Paleta.OURO
	# o pop: o quadradinho cresce em torno do centro da caixa (golpe novo parte de 0,4 e passa de 1,0; nível e fusão dão um pulso)
	var escala := 1.0
	match tipo:
		"novo":
			escala = lerpf(0.4, 1.3, u / 0.4) if u < 0.4 else lerpf(1.3, 1.0, (u - 0.4) / 0.6)
		"nivel", "fusao":
			escala = 1.0 + (0.3 if tipo == "fusao" else 0.2) * sin(u * PI)
	var centro := o + Vector2(CAIXA, CAIXA) * 0.5
	draw_set_transform(centro, 0.0, Vector2(escala, escala))
	var c0 := -Vector2(CAIXA, CAIXA) * 0.5  # canto da caixa no espaço escalado
	var caixa := Rect2(c0, Vector2(CAIXA, CAIXA))
	draw_rect(caixa, FUNDO)
	var borda: Color = Paleta.OURO if it.evo else Color(cor.lerp(Color.WHITE, 0.2), 0.95)
	if tipo != "":
		borda = borda.lerp(cor_an, 1.0 - u)
	_moldura(caixa, borda)
	var pos_icone := c0 + Vector2(2.0, 2.0)
	var tex: Texture2D = Dados.icone_carta(it.id)
	if tex != null:
		draw_texture(tex, pos_icone)
	else:
		draw_rect(Rect2(pos_icone, Vector2(ICONE, ICONE)), Color(cor, 0.5))
	if it.rec >= 0:  # recarga: trilho escuro embaixo do ícone e a linha cresce até ficar pronta (cheia = pronta, mais clara)
		var y := pos_icone.y + ICONE - 2.0
		draw_rect(Rect2(pos_icone.x, y, ICONE, 2.0), TRILHO)
		if it.rec > 0:
			draw_rect(Rect2(pos_icone.x, y, it.rec, 2.0), cor.lerp(Color.WHITE, 0.55 if it.rec >= ICONE else 0.1))
	if tipo != "":
		var brilho := (1.0 - u) * (1.0 - u)
		draw_rect(Rect2(pos_icone, Vector2(ICONE, ICONE)), Color(cor_an.lerp(Color.WHITE, 0.5), 0.5 * brilho))
	# a linha de fusão (magenta) e os pips de nível ficam fora da caixa, logo abaixo
	var y_fus := c0.y + CAIXA + 1.0
	if it.fus >= 0:
		draw_rect(Rect2(pos_icone.x, y_fus, ICONE, 2.0), TRILHO)
		var cor_fus: Color = Paleta.FUSAO
		if it.quase and _fase_quase == 1:
			cor_fus = cor_fus.lerp(Color.WHITE, 0.6)
		if it.fus > 0:
			draw_rect(Rect2(pos_icone.x, y_fus, it.fus, 2.0), cor_fus)
	var y_pip := c0.y + CAIXA + 4.0
	var x_pip := c0.x + floorf((CAIXA - (it.max * (PIP_L + 1) - 1)) * 0.5)
	for k in int(it.max):
		var cheio: bool = k < int(it.nivel) or bool(it.evo)
		var cor_pip: Color = Paleta.OURO if it.evo else cor.lerp(Color.WHITE, 0.2)
		var r := Rect2(x_pip + k * (PIP_L + 1), y_pip, PIP_L, PIP_A)
		if not cheio:
			draw_rect(r, Color(Paleta.BARRA_VAZIA, 0.95))
			continue
		if tipo == "nivel" and k == int(it.nivel) - 1 and u < 0.6:  # o pip que acabou de acender cresce e fica branco
			r = r.grow(1.0)
			cor_pip = Color.WHITE
		draw_rect(r, cor_pip)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tipo == "novo" or tipo == "fusao":
		_anel_e_faiscas(centro, u, cor_an, str(it.id), tipo == "fusao")
	elif tipo == "nivel":
		_anel_e_faiscas(centro, u, cor_an, str(it.id), false, 4)


## O anel que sai da caixa e as faíscas que voam para fora e esmaecem (posições determinísticas pelo id: sem sorteio por quadro).
func _anel_e_faiscas(centro: Vector2, u: float, cor: Color, id: String, grande: bool, quantas := FAISCAS) -> void:
	var alfa := 1.0 - u
	var meio := CAIXA * 0.5 + u * (14.0 if grande else 9.0)
	_moldura(Rect2(centro - Vector2(meio, meio), Vector2(meio, meio) * 2.0), Color(cor, alfa * 0.8))
	var semente := float(id.hash() % 360) / 360.0 * TAU
	for k in quantas:
		var ang := semente + TAU * float(k) / float(quantas)
		var dist := CAIXA * 0.5 + 3.0 + u * (22.0 if grande else 15.0)
		var p := centro + Vector2(cos(ang), sin(ang)) * dist
		var lado := 3.0 if u < 0.5 else 2.0
		draw_rect(Rect2(p.round() - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), Color(cor.lerp(Color.WHITE, 0.4), alfa))


## Moldura de 1 px feita de quatro retângulos (pixel inteiro, sem a linha centrada do draw_rect vazado).
func _moldura(r: Rect2, cor: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), cor)
	draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - 1.0), Vector2(r.size.x, 1.0)), cor)
	draw_rect(Rect2(r.position + Vector2(0.0, 1.0), Vector2(1.0, r.size.y - 2.0)), cor)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 1.0, 1.0), Vector2(1.0, r.size.y - 2.0)), cor)


## Lê um campo de um objeto ou dicionário, ou o padrão se faltar (mundo falso, mundo nulo).
static func _campo(o, nome: String, padrao = null):
	if o == null:
		return padrao
	if o is Dictionary:
		return o.get(nome, padrao)
	if o is Object:
		var v = o.get(nome)
		return padrao if v == null else v
	return padrao
