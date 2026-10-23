extends Control
## Faixa de GOLPES do HUD da v2: um quadradinho fixo por golpe automático que o herói tem (bola de fogo, lâminas rodopiantes, corvos, raio,
## runa, aura, golem, lobo...), no canto inferior esquerdo, acima do retrato e das barras de vida e fôlego. Antes isto só aparecia na pausa ("GOLPES AUTOMÁTICOS").
## Quadradinhos pequenos (caixa de 26 px, ícone da carta reduzido de 32 para 24) para não poluir com 10 golpes: parada, a faixa fica
## translúcida; ao ganhar golpe, subir de nível ou fundir, ela fica opaca por ~1,5 s e volta a esmaecer.
## Cada quadradinho tem só três leituras: o ícone próprio da carta, os pips de nível embaixo e UMA linha fina de recarga no pé do ícone (só
## enquanto recarrega, nos golpes que têm recarga: corvos, raio, runa, projétil, nuvem, anel, meteoro, aliado e torre; lâmina e aura batem sem
## parar). Sem barra de fusão: quando falta só UM nível para fundir uma receita, um losango magenta pisca no canto do ícone.
## A peça já fundida ganha a moldura dourada e os pips dourados cheios.
## Animação: golpe novo entra com pop curto (sem invadir o vizinho), anel, faíscas e brilho; nível novo dá um pulso que CLAREIA o ícone e o pip
## novo pisca; a fusão dá o mesmo em magenta. Tudo desenhado por código, em pixel inteiro, num só Control.
## Posição: âncora no canto inferior esquerdo do pai (a Raiz do HUD), logo ACIMA do retrato e das barras de vida e fôlego (MARGEM_BAIXO), sem coordenada
## absoluta de tela; acha o HUD subindo pela árvore.
## Custo: lê o combate a 20 Hz (no máximo uns doze golpes), e só redesenha quando a chave (golpes, níveis, pixels de recarga e a marca de
## fusão) muda ou enquanto há animação; a translucidez é o `modulate` do nó e não redesenha. Sem `combate` no mundo (mundo falso dos testes),
## a faixa fica escondida. Com o card da build aberto (tecla C, que ocupa a coluna da esquerda, ou o menu principal da pausa, que mostra o
## card ao lado) a faixa se esconde: o card já lista os golpes. Nas outras telas da pausa (Ajustes, Sair) ela fica desenhada sob o fundo
## escuro e parada. Escondida, a animação em curso espera.
## Lê, com get() e valor padrão: hud.mundo; mundo.combate (.armas.ativas, .cartas), mundo.heroi.m_vel_ataque, mundo.status.aberto().

const Paleta := preload("res://v2/paleta.gd")
const ICONE := 24  # lado do ícone desenhado (a arte da carta tem 32 e é reduzida a 0,75)
const CAIXA := 26  # lado da caixa do ícone: moldura de 1 px em volta
const ALTURA := 32  # caixa (26) + pips (3) + folgas
const ESPACO := 3
const POR_LINHA := 8  # 8 por linha: a faixa (1,5x na tela) acaba em x 354, antes do Q (x 432)
const LINHAS_MAX := 3  # 24 golpes; passou disso, o excedente vira um "+N"
const CAPACIDADE := POR_LINHA * LINHAS_MAX
const MARGEM := 6.0  # folga até a borda esquerda do pai
const ESCALA := 1.5  # decisão do Alisson: o HUD da partida é 1,5x. O nó é escalado (`scale`); o desenho e `size` ficam no espaço de 26x32 por golpe
const MARGEM_BAIXO := 118.0  # até a borda de baixo (na tela): 6 de folga, 108 do retrato e 4 de respiro (a faixa fica acima do bloco do herói)
const LEITURA_S := 0.05  # lê o combate a 20 Hz
const ANIM_S := 0.5  # duração do pop/pulso
const DESTAQUE_S := 1.5  # quanto tempo a faixa fica opaca depois de uma mudança
const ALFA_PARADA := 0.72  # opacidade da faixa quando nada muda
const FAISCAS := 6
const PIP_L := 4
const PIP_A := 3
const FUNDO := Color(Paleta.PAINEL, 0.88)
const TRILHO := Color(Paleta.BARRA_BORDA, 0.6)
const TIPOS_RECARGA := ["corvos", "raio", "runa", "projetil", "nuvem", "anel", "meteoro", "aliado", "torre"]

## O que está na faixa agora, em ordem de aquisição: [{id, nivel, max, evo, cor, rec (px 0..24 ou -1), quase}].
var itens: Array = []
## Segundos que faltam da animação de cada golpe (id -> {t, tipo}); públicos para os testes.
var anims := {}
## Quantos redesenhos a faixa pediu (os testes conferem que parada não pede nenhum).
var pedidos := 0
var _hud = null
var _chave := ""
var _destaque := 0.0  # segundos que faltam da fase opaca
var _vistos := {}  # id -> [nivel, evo] na leitura anterior
var _iniciado := false  # a primeira leitura só registra: golpes que já existiam não animam
var _acumulado := 0.0
var _fase_quase := 0
var _chave_desenhada := ""


func _ready() -> void:
	# âncora no canto inferior esquerdo do pai: a posição não depende de coordenada de tela (o HUD pode estar num SubViewport de UI)
	var tam := Vector2(POR_LINHA * (CAIXA + ESPACO), LINHAS_MAX * ALTURA)
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = MARGEM
	offset_right = MARGEM + tam.x
	scale = Vector2(ESCALA, ESCALA)
	offset_top = -MARGEM_BAIXO - tam.y * ESCALA  # o nó mede tam.y e aparece com tam.y * ESCALA: a base dele fica em -MARGEM_BAIXO
	offset_bottom = offset_top + tam.y
	light_mask = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # o ícone de 32 px é reduzido a 24: com nearest sairia serrilhado
	modulate.a = ALFA_PARADA
	visible = false
	_hud = _achar_hud()


## Sobe pela árvore até o nó do HUD (o que tem o campo `mundo`): não depende de a faixa ser neta direta dele.
func _achar_hud():
	var n := get_parent()
	while n != null:
		if "mundo" in n:
			return n
		n = n.get_parent()
	return null


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
	# escondida (HUD coberto pela escolha do baú, card aberto), a animação espera: senão o pop acaba antes de alguém ver
	if is_visible_in_tree():
		for id in anims.keys():
			anims[id].t = float(anims[id].t) - dt
			if float(anims[id].t) <= 0.0:
				anims.erase(id)
			animando = true
		_destaque = maxf(_destaque - dt, 0.0)
		if animando:
			_destaque = DESTAQUE_S
		# opaca ao mudar, translúcida parada: só o modulate do nó, sem redesenho
		var alvo := 1.0 if _destaque > 0.0 else ALFA_PARADA
		modulate.a = move_toward(modulate.a, alvo, dt * (6.0 if alvo > modulate.a else 1.5))
	_fase_quase = int(Time.get_ticks_msec() / 250) % 2
	var pisca := false
	for it in itens:
		pisca = pisca or bool(it.quase)
	var chave := _chave + ("|q%d" % _fase_quase if pisca else "")
	if mudou or animando or chave != _chave_desenhada:
		_chave_desenhada = chave
		pedidos += 1
		queue_redraw()


## O retângulo que a faixa ocupa agora, nas coordenadas do pai, a Raiz do HUD (vazio sem golpes). Os testes conferem que não cruza o resto do HUD.
func area_ocupada() -> Rect2:
	var n := mini(itens.size(), CAPACIDADE)
	if n == 0:
		return Rect2()
	var colunas := mini(n, POR_LINHA)
	var linhas := ceili(float(n) / POR_LINHA)
	return Rect2(position.x, position.y + (size.y - linhas * ALTURA) * ESCALA, (colunas * (CAIXA + ESPACO) - ESPACO) * ESCALA, linhas * ALTURA * ESCALA)


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
		var relogio := float(_campo(_campo(armas, "novas"), "_relogio", 0.0))
		for id in ativas:
			novos.append(_item(str(id), ativas[id], cartas, vel, relogio))
	var st = _campo(mundo, "status")
	var escondido: bool = novos.is_empty() or (st != null and st.has_method("aberto") and st.aberto())
	if visible == escondido:
		visible = not escondido
	var partes: PackedStringArray = []
	for it in novos:
		partes.append("%s,%d,%d,%d,%d" % [it.id, it.nivel, int(it.evo), it.rec, int(it.quase)])
	var chave := ",".join(partes)
	_animar_chegadas(novos)
	itens = novos
	if chave == _chave:
		return false
	_chave = chave
	return true


func _item(id: String, a: Dictionary, cartas, vel: float, relogio := 0.0) -> Dictionary:
	var evo: bool = bool(a.get("evo", false))
	var def = cartas.definicao(id) if cartas != null and cartas.has_method("definicao") else {}
	var it := {
		"id": id,
		"nivel": int(a.get("nivel", 1)),
		"max": 5 if evo or not def is Dictionary or not def.has("max") else int(def.max),
		"evo": evo,
		"cor": a.get("cor", Paleta.OURO),
		"rec": -1,
		"quase": false
	}
	var st: Dictionary = a.get("st", {})
	# Aliado e torre só recarregam depois que a leva some; durante a vida dela a barrinha sobre o corpo já mostra o tempo restante.
	var leva_viva := relogio < float(a.get("ate", 0.0))
	if not leva_viva and TIPOS_RECARGA.has(str(a.get("tipo", ""))) and st.has("recarga"):
		var dur := maxf(float(st.recarga) / vel, 0.05)
		it.rec = roundi((1.0 - clampf(float(a.get("t", 0.0)) / dur, 0.0, 1.0)) * ICONE)
	if not evo and cartas != null:
		var f := _fusao(id, cartas)
		it.quase = f.x >= 0.0 and f.y <= 1.0
	return it


## O melhor progresso de fusão das receitas ainda possíveis que usam `id`: x = fração (soma dos níveis das peças limitados ao pedido sobre o
## total pedido) e y = quantos níveis faltam no total. x = -1 quando nenhuma receita possível usa o golpe. Receita com peça já consumida por
## outra fusão (`usada`, que o jogo não conta mais como ativa) é impossível e não entra.
func _fusao(id: String, cartas) -> Vector2:
	var melhor := Vector2(-1.0, 99.0)
	var cfg = _campo(cartas, "cfg")
	if not cfg is Dictionary or not cartas.has_method("nivel_de"):
		return melhor
	for ev in cfg.get("evolucoes", []):
		var usa := false
		var possivel := true
		for p in ev.pecas:
			usa = usa or str(p.id) == id
			if cartas.has_method("ativa") and cartas.nivel_de(str(p.id)) > 0 and not cartas.ativa(str(p.id)):
				possivel = false
		if not usa or not possivel or (cartas.has_method("_evo_livre") and not cartas._evo_livre(ev)):
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
			_destaque = DESTAQUE_S
		elif it.nivel > _vistos[id][0]:
			anims[id] = {"t": ANIM_S, "tipo": "nivel"}
			_destaque = DESTAQUE_S
	for id in anims.keys():
		if not agora.has(id):
			anims.erase(id)
	_vistos = agora
	_iniciado = true


# ------------------------------------------------------------------ desenho


func _draw() -> void:
	var n := mini(itens.size(), CAPACIDADE)
	# quem anima é desenhado por último, por cima dos vizinhos (o pop nunca fica por baixo da caixa do lado)
	for i in n:
		if not anims.has(itens[i].id):
			_desenhar_slot(i, itens[i])
	for i in n:
		if anims.has(itens[i].id):
			_desenhar_slot(i, itens[i])
	if itens.size() > CAPACIDADE:
		var f := get_theme_font("font")
		draw_string(f, pos_excedente(), "+%d" % (itens.size() - CAPACIDADE), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Paleta.TEXTO_SECUNDARIO)


## Onde o "+N" fica: à direita da linha de baixo, na folga antes do Q (x 432), sem cobrir nenhum quadradinho.
func pos_excedente() -> Vector2:
	return Vector2(POR_LINHA * (CAIXA + ESPACO) + 2.0, size.y - ALTURA + 12.0)


func _origem(i: int) -> Vector2:
	return Vector2((i % POR_LINHA) * (CAIXA + ESPACO), size.y - (i / POR_LINHA + 1) * ALTURA)


func _desenhar_slot(i: int, it: Dictionary) -> void:
	var o := _origem(i)
	var an: Dictionary = anims.get(it.id, {})
	var u := 1.0 - float(an.t) / ANIM_S if not an.is_empty() else 1.0
	var tipo: String = an.get("tipo", "")
	var cor: Color = it.cor
	var cor_an: Color = Paleta.FUSAO if tipo == "fusao" else Paleta.OURO
	# o pop é curto para não invadir o vizinho (folga de 3 px entre caixas): golpe novo parte de 0,6 e passa a 1,10; nível e fusão dão um pulso
	var escala := 1.0
	match tipo:
		"novo":
			escala = lerpf(0.6, 1.1, u / 0.4) if u < 0.4 else lerpf(1.1, 1.0, (u - 0.4) / 0.6)
		"nivel", "fusao":
			escala = 1.0 + (0.1 if tipo == "fusao" else 0.07) * sin(u * PI)
	var brilho := (1.0 - u) * (1.0 - u) if tipo != "" else 0.0
	var centro := o + Vector2(CAIXA, CAIXA) * 0.5
	draw_set_transform(centro, 0.0, Vector2(escala, escala))
	var c0 := -Vector2(CAIXA, CAIXA) * 0.5  # canto da caixa no espaço escalado
	var caixa := Rect2(c0, Vector2(CAIXA, CAIXA))
	draw_rect(caixa, FUNDO)
	var borda: Color = Paleta.OURO if it.evo else Color(cor.lerp(Color.WHITE, 0.2), 0.95)
	if tipo != "":
		borda = borda.lerp(cor_an.lerp(Color.WHITE, 0.4), brilho)
	_moldura(caixa, borda)
	var pos_icone := c0 + Vector2(1.0, 1.0)
	var area_icone := Rect2(pos_icone, Vector2(ICONE, ICONE))
	var tex: Texture2D = Dados.icone_carta(it.id)
	if tex != null:
		# no pulso o ícone CLAREIA (multiplicador acima de 1, o 2D satura em branco), nunca escurece
		var f := 1.0 + 0.9 * brilho
		draw_texture_rect(tex, area_icone, false, Color(f, f, f, 1.0))
	else:
		draw_rect(area_icone, Color(cor, 0.5))
	if it.rec >= 0 and it.rec < ICONE:  # recarga: UMA linha fina no pé do ícone, só enquanto recarrega
		var y := pos_icone.y + ICONE - 2.0
		draw_rect(Rect2(pos_icone.x, y, ICONE, 2.0), TRILHO)
		if it.rec > 0:
			draw_rect(Rect2(pos_icone.x, y, it.rec, 2.0), cor.lerp(Color.WHITE, 0.35))
	if tipo != "":
		draw_rect(area_icone, Color(cor_an.lerp(Color.WHITE, 0.7), 0.4 * brilho))
	if it.quase:  # falta um nível para fundir: losango magenta que pisca no canto de cima do ícone
		var pc := pos_icone + Vector2(ICONE - 4.0, 3.0)
		var cor_f: Color = Paleta.FUSAO.lerp(Color.WHITE, 0.7 if _fase_quase == 1 else 0.0)
		draw_rect(Rect2(pc + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), cor_f)
		draw_rect(Rect2(pc + Vector2(-2.0, 1.0), Vector2(5.0, 1.0)), cor_f)
		draw_rect(Rect2(pc + Vector2(-1.0, 2.0), Vector2(3.0, 1.0)), cor_f)
		draw_rect(Rect2(pc + Vector2(0.0, -1.0), Vector2(1.0, 5.0)), cor_f)
	# os pips de nível ficam logo abaixo da caixa
	var y_pip := c0.y + CAIXA + 2.0
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
	var meio := CAIXA * 0.5 + u * (4.0 if grande else 2.0)  # o anel cresce pouco: fica na folga entre as caixas
	_moldura(Rect2(centro - Vector2(meio, meio), Vector2(meio, meio) * 2.0), Color(cor, alfa * 0.8))
	var semente := float(id.hash() % 360) / 360.0 * TAU
	for k in quantas:
		var ang := semente + TAU * float(k) / float(quantas)
		var dist := CAIXA * 0.5 + 2.0 + u * (10.0 if grande else 7.0)
		var p := centro + Vector2(cos(ang), sin(ang)) * dist
		var lado := 2.0
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
