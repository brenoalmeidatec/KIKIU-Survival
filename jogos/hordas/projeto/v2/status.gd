extends CanvasLayer
## Card "SUA BUILD" da v2: tudo o que a build faz, em números. Duas partes:
##  1. `Status.coletar(mundo)` (estática, sem desenhar nada, testável) devolve as SEÇÕES do card em dados simples. Os números são os REAIS do
##     jogo: cada um vem do getter do módulo que o usa (heroi.vel_andar, combate.dano_do_passo, armas.numeros, progresso.cura_por_nivel...),
##     nunca de uma fórmula copiada aqui. Cada linha tem `id`, `rotulo`, `valor` (o texto), `bonus` (o que passa da base, em outra cor) e `n`
##     (os números crus, em ordem; é o que o teste v2_status compara com o que o jogo FAZ).
##  2. O desenho, em TRÊS modos (`_modo()`), todos com a moldura dourada dos menus (v2/estilo_premium.gd). Títulos na Jersey 10, texto na
##     Spleen 8x16 em 16 px e NÚMEROS na Press Start 2P (a fonte do HUD). Tudo é desenhado num Control só (draw_*): nenhum nó por linha, nenhum nó criado ao atualizar.
## Onde aparece:
##  - "pausa": na tela "menu" da pausa, duas colunas ladeiam o menu (pausa.gd chama `na_pausa(true/false)`), por cima da pausa (camada 15).
##    Layout COMPLETO paginado (nomes por extenso, números e dicas de evolução sem corte);
##  - "hud": na partida, a tecla C liga e desliga um card COMPACTO (camada 8: abaixo do HUD). Semitransparente, não pega o mouse, atualiza a
##    4 Hz e só enquanto está visível. A coluna da esquerda fica sob a vida e o fôlego e a da direita sob o minimapa, as duas fora das faixas
##    do HUD (barra do chefe, anúncios, combo, XP): o centro, onde o herói luta, fica livre. No compacto cada golpe e cada modificador cabe
##    numa linha (ícone, nome curto, nível e número), sem dicas; atributos longos quebram e o conteúdo pagina com PgUp/PgDn ou roda sobre o card;
##  - "central": sobre a escolha de cartas e o baú o C abre um painel no centro, em três colunas e no layout completo paginado, com o fundo opaco: ele
##    ESCONDE as cartas (nada pela metade). Enquanto está aberto, clique e tecla não escolhem carta (a trava de 3 s das cartas segue correndo
##    em tempo real); o ESC abre a pausa como sempre; no controle, o Select liga o painel e B o fecha (LB/RB paginam).
##    Com o painel fechado o card do HUD sai de cena nessas telas (ele cobriria a 1ª e a 3ª carta).
## A entrada é `entrada(evento)`, chamada pelo mundo.gd (o SubViewport não recebe a entrada da janela, então este nó não tem _input).
## Criado pelo mundo.gd (uma linha no _ready), que guarda em `mundo.status`.

const Paleta := preload("res://v2/paleta.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const Meta := preload("res://v2/meta.gd")
const Glifos := preload("res://v2/glifos.gd")
const Pausa := preload("res://v2/pausa.gd")
const EstiloPremium := preload("res://v2/estilo_premium.gd")
const LAYER_HUD := 8
const LAYER_CENTRAL := 13  # acima do HUD (10), das cartas (11) e do resultado (12); abaixo do menu de pausa (14)
const LAYER_PAUSA := 15  # acima do menu de pausa (camada 14) e do escurecimento dele
const PERIODO := 0.25  # 4 Hz
const ALFA_HUD := 0.92
const BOTAO_PAINEL := JOY_BUTTON_BACK  # o Select liga e desliga o painel central, como o C (a v1 já o dava ao card: "status" em main.gd)
const TAM := Paleta.TEXTO_TAMANHO
const TAM_NUM := Paleta.NUMERO_PEQUENO
const TAM_P := Paleta.TEXTO_TAMANHO
const TAM_CAB := Paleta.TITULO_PEQUENO
const TAM_NOME_PEQ := Paleta.TITULO_PEQUENO
const ALT_LINHA := 18.0
const Herois := preload("res://v2/herois.gd")  # o herói escolhido: nome, arma (dados/v2_herois.json)
const Dificuldade := preload("res://v2/dificuldade.gd")  # defesa_regen_mult: a linha "Recarga da defesa"
const ALT_CAB := 18.0
const ALT_TITULO := 22.0
const ALT_BLOCO_COMPACTO := 18.0  # ícone de 16 px e 2 de respiro: um golpe ou modificador por linha no HUD
const PAD := 8.0
const FILETE_PAUSA := 6.0  # o filete interno da moldura premium fica no pixel 6 da borda externa do quadro (o miolo começa no 7); medido na foto
const FOLGA_PAUSA := 8.0  # vão livre entre esse filete e o texto dos quadros laterais da pausa, nos quatro lados (escala com a UI)
const INTERNA_PAUSA := FILETE_PAUSA + 1.0 + FOLGA_PAUSA  # da borda externa do quadro ao texto: 15 px na base 960x540
const TINTA_TITULO := 6.0  # a caixa de um título (Jersey 10, TAM_CAB) fica 6 px acima da tinta da maiúscula
const ICONE := 16.0
const ICONE_FUSAO := preload("res://assets/v2/fusoes/icone.png")  # junção de duas setas (16 x 16): marca a linha de peça já fundida
const TELA := Rect2(0, 0, 960, 540)
const JOGO_VIVO := ["jogando", "escolha", "bau"]  # estados do combate em que o C vale
const JOGO_CARTAS := ["escolha", "bau"]  # as telas de cartas: aí o C abre o painel central
## Colunas de cada modo: x, y, largura e altura máxima. HUD: a da esquerda acima do retrato e das barras de vida e fôlego (que começam em y 426) e fora
## da barra do chefe (x até 190); a da direita sob o minimapa (que acaba em y 112), acima do E e do secundário (y 423) e fora da barra do chefe e dos anúncios (x a partir de 772). Pausa: colada nos dois lados
## do painel do menu (`Pausa.PAINEL`, x 260 a 700), com o MESMO topo e a MESMA altura dele: os três quadros formam uma faixa alinhada. Central: três
## colunas lado a lado, a tela toda é do painel.
const COLUNAS_HUD := [Rect2(6, 6, 184, 416), Rect2(772, 118, 182, 301)]
const MARGEM_PAUSA := 8.0  # do quadro lateral à borda da tela (a mesma nos dois lados)
const VAO_PAUSA := 12.0  # do quadro lateral ao painel do menu (o mesmo nos dois lados)
const COLUNAS_PAUSA := [
	Rect2(MARGEM_PAUSA, Pausa.PAINEL.position.y, Pausa.PAINEL.position.x - VAO_PAUSA - MARGEM_PAUSA, Pausa.PAINEL.size.y),
	Rect2(Pausa.PAINEL.end.x + VAO_PAUSA, Pausa.PAINEL.position.y, TELA.size.x - MARGEM_PAUSA - Pausa.PAINEL.end.x - VAO_PAUSA, Pausa.PAINEL.size.y)
]  # nos dois lados do painel do menu (`Pausa.PAINEL`): mesmo topo, mesma altura e o mesmo espaço para o painel e para a borda da tela
const COLUNAS_CENTRAL := [Rect2(14, 14, 296, 512), Rect2(332, 14, 296, 512), Rect2(650, 14, 296, 512)]
const SECOES_DUAS := [["heroi", "partida", "santuario"], ["katana", "golpes"]]
const SECOES_TRES := [["heroi", "partida", "santuario"], ["katana"], ["golpes"]]
const COR_FUNDO_OPACO := Paleta.PAINEL
const COR_TITULO := Paleta.OURO
const COR_ROTULO := Paleta.TEXTO_SECUNDARIO
const COR_VALOR := Paleta.VALOR
const COR_BONUS := Paleta.BONUS
const COR_SANTUARIO := Paleta.ALMA
const COR_DICA := Paleta.DICA
const COR_APAGADO := Paleta.TEXTO_APAGADO
const COR_LINHA := Color(Paleta.DIVISOR, 0.5)
## Estilo de um trecho de texto (veja `_bloco`): 0 = apoio, 1 = número em destaque, 2 = bônus.
const CORES_TRECHO := [COR_ROTULO, COR_VALOR, COR_BONUS]

var mundo
var secoes: Array = []  # o último `coletar` (os testes leem)
var atualizacoes := 0  # quantas vezes recoletou (os testes conferem que escondido não atualiza)
var _hud := false  # o jogador ligou o card compacto com C (durante a partida)
var _central := false  # o jogador abriu o painel central com C (sobre a escolha de cartas ou o baú)
var _pausa := false  # a pausa pediu o card ao lado do menu
var _saindo := false  # o card da pausa está sumindo (fade junto com o menu, #377): a camada segue visível até o fim
var _modo_atual := ""  # o modo que está na tela agora ("" = escondido)
var _m := "hud"  # o modo em que `_medir`, `_coluna` e o desenho trabalham agora
var _meta: Dictionary = {}  # níveis do Santuário, lidos uma vez quando o card abre (o save não muda durante a partida)
var _tela: Control
var _estilo: StyleBoxTexture
var _f_num: Font  # Press Start 2P sem anti-aliasing (como o HUD)
var _caixas_visuais: Array = []  # por coluna da página visual: a área do texto (x, topo da tinta do título, largura, base), de `_visual`
var _re := RegEx.create_from_string("[+\\-]?[0-9]+(?:[,.][0-9]+)?%?")  # um número: sinal, dígitos, decimais e % (vão na fonte dos números)
var _re_palavras := RegEx.create_from_string("\\s+|\\S+")  # preserva palavras, espaços e estilo dos trechos
var _timer: Timer  # o relógio de 4 Hz: só corre com o card ligado (sem _process, nada roda por quadro)
var _sobrou: Array = [false, false, false]  # por coluna: um item individual ultrapassou o espaço disponível
var _golpes_mostrados := 0  # golpes desenhados na coluna agora (o "+N golpes" conta os que faltam)
var _pag_detalhes := 0
var _paginas_detalhes: Array = [1, 1, 1]
var _diagnostico: Array = []
var _golpes_visuais: Array = []

var _pag := 0  # página dos golpes na página visual (pausa e painel central): Q e R trocam; a altura da coluna decide quantos cabem
var _npag_golpes := 1  # páginas dos golpes na última medida (Q e R não passam dali)


## Cria o card ligado ao mundo. É o que o mundo.gd chama (e guarda em `mundo.status`).
static func criar(m) -> CanvasLayer:
	var s := new()
	s.mundo = m
	return s


func _redesenhar_dicas() -> void:
	if _tela != null:
		_tela.queue_redraw()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # a pausa e a escolha de cartas param o mundo; o card segue atualizando
	layer = LAYER_HUD
	add_to_group("ui_escala")
	Glifos.ao_mudar(_redesenhar_dicas)  # as dicas de tecla seguem o dispositivo em uso
	_estilo = EstiloPremium.painel()  # a moldura dourada dos menus (o texto fica a PAD = 8 px da borda, fora do bisel e dos losangos)
	_f_num = (Dados.fonte as FontFile).duplicate() as FontFile
	(_f_num as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_NONE
	(_f_num as FontFile).hinting = TextServer.HINTING_NONE
	(_f_num as FontFile).subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_tela = Control.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.light_mask = 0
	_tela.draw.connect(_pintar)
	add_child(_tela)
	_timer = Timer.new()
	_timer.wait_time = PERIODO
	_timer.one_shot = false
	_timer.timeout.connect(_tique)
	add_child(_timer)
	visible = false  # escondido, o relógio parado: nada roda


## A janela ou a opção "tamanho_ui" mudou: o painel central cobre o canvas novo.
func ui_reencaixar(_canvas: Vector2, _desloc: Vector2) -> void:
	_tela.queue_redraw()


# ------------------------------------------------------------------ ligar e desligar


## C (ou o Select do controle): liga e desliga o card compacto (ou o painel central, sobre as cartas). Devolve true se usou o evento (o mundo.gd o
## passa antes da escolha de cartas e do baú, que comem as teclas). Com o painel central aberto o card engole TODA a entrada, menos o ESC (que é
## da pausa): nenhum clique, tecla ou botão chega às cartas escondidas. No controle, com o painel aberto, B fecha e LB/RB paginam como Q e R.
func entrada(e: InputEvent) -> bool:
	if _modo_atual == "central" and not _sobre_cartas():
		_aplicar()  # as cartas fecharam por outro caminho: o painel sai antes de engolir a entrada
	if _modo_atual == "central":
		if e is InputEventKey:
			if e.keycode == KEY_ESCAPE:
				return false
			if e.keycode == KEY_TAB and e.pressed and not e.echo:
				alternar_detalhe()
			if e.keycode == KEY_C and e.pressed and not e.echo and not (e.ctrl_pressed or e.alt_pressed or e.meta_pressed):
				alternar()
			if e.keycode in [KEY_Q, KEY_R] and e.pressed and not e.echo:
				paginar(-1 if e.keycode == KEY_Q else 1)
		elif e is InputEventJoypadButton and e.pressed:
			if e.button_index == BOTAO_PAINEL:
				alternar()  # Select: liga e desliga, como o C
			elif e.button_index == JOY_BUTTON_Y:
				alternar_detalhe()  # Y é o Tab: visual / detalhes
			elif e.button_index == JOY_BUTTON_B:
				_central = false  # B fecha o painel (o "voltar" das outras telas)
				_aplicar()
			elif e.button_index == JOY_BUTTON_LEFT_SHOULDER or e.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				paginar(-1 if e.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)  # LB é o Q, RB é o R
		return true  # o resto da entrada é engolido: as cartas estão escondidas
	if _modo_atual == "hud" and e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		for r in retangulos():
			if (r as Rect2).has_point(_pos_na_tela(e.position)):
				return paginar(-1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
	if _modo_atual == "hud" and e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		return paginar(-1 if e.keycode == KEY_PAGEUP else 1)
	if e is InputEventJoypadButton:
		# o Select sobre a escolha ou o baú abre o painel central, como o C; na partida o controle não mexe no card compacto
		if not e.pressed or e.button_index != BOTAO_PAINEL or not _sobre_cartas() or not pode_alternar():
			return false
		alternar()
		return true
	if not (e is InputEventKey) or not e.pressed or e.echo or e.keycode != KEY_C:
		return false
	if e.ctrl_pressed or e.alt_pressed or e.meta_pressed:
		return false
	if not pode_alternar():
		return false
	alternar()
	return true


## Converte o evento da janela para o bloco 960x540 da UI (desfaz o fator e o deslocamento do bloco no canvas, ver apresentacao.pos_ui).
## Sem clamp: uma roda fora do jogo não deve atingir a borda do card.
func _pos_na_tela(pos: Vector2) -> Vector2:
	return mundo.ap.pos_ui(pos)


## O C (e o Select do controle) vale com a partida de pé, na escolha de cartas e no baú;
## não vale com a pausa aberta (ela mostra o card dela), com o "Pausar agora?" das cartas aberto (ele come a entrada e o painel por cima
## deixaria o tempo das cartas voltar a correr escondido) nem no fim da partida.
func pode_alternar() -> bool:
	if mundo == null or mundo.combate == null or _pausa or not (str(mundo.combate.jogo) in JOGO_VIVO) or get_tree().paused:
		return false
	var tl = mundo.combate.get("telas")
	return tl == null or not bool(tl.conf_aberta)


## O painel central da build (C / Select sobre as cartas) está na tela agora.
func central_aberto() -> bool:
	return visible and _modo_atual == "central"


## Liga ou desliga: o painel central sobre as cartas, o card compacto no resto da partida.
func alternar() -> void:
	if _sobre_cartas():
		_central = not _central
	else:
		_hud = not _hud
	_aplicar()


## O card está na tela agora (HUD ligado pelo C, painel central, ou ao lado do menu de pausa).
func aberto() -> bool:
	return visible and not _saindo


## A pausa pede o card ao lado do menu (tela "menu") ou o tira (outras telas e fechar). Uma chamada só, de pausa.gd.
func na_pausa(v: bool) -> void:
	var mudou := v != _pausa
	_pausa = v
	if mudou or _modo_atual != _modo():
		_aplicar()


## A escolha de cartas ou o baú estão abertos (o jogo está nelas).
func _sobre_cartas() -> bool:
	return mundo != null and mundo.combate != null and str(mundo.combate.jogo) in JOGO_CARTAS


## O modo que o estado de agora pede: "pausa" ao lado do menu; sobre as cartas, "central" se o jogador abriu o painel (senão nada: o card
## compacto cobriria as cartas); com o menu da pausa em Ajustes ou numa confirmação, nada (o menu cobre tudo); no resto, "hud" se ligado.
func _modo() -> String:
	if _pausa:
		return "pausa"
	if not is_inside_tree() or get_tree().paused:
		return ""
	if _sobre_cartas():
		return "central" if _central else ""
	return "hud" if _hud else ""


func _colunas() -> Array:
	match _m:
		"pausa":
			return COLUNAS_PAUSA
		"central":
			return COLUNAS_CENTRAL
	return COLUNAS_HUD


func _secoes_das_colunas() -> Array:
	return SECOES_TRES if _m == "central" else SECOES_DUAS


func _aplicar() -> void:
	if _central and not _sobre_cartas():
		_central = false  # as cartas já se foram: o painel não fica órfão
	var anterior := _modo_atual
	_modo_atual = _modo()
	if anterior != _modo_atual:
		_pag_detalhes = 0
		_paginas_detalhes = [1, 1, 1]
	if _modo_atual != "" and not visible:
		_pag = 0  # o card abre na primeira página dos golpes
	_saindo = anterior == "pausa" and _modo_atual == "" and visible
	visible = _modo_atual != "" or _saindo
	if _hud or _central or _pausa:
		if _timer.is_stopped():
			_timer.start()
	else:
		_timer.stop()
	if _saindo:  # fechar a pausa: o card some junto com o menu em vez de piscar para fora (sem animação, esconde na hora)
		Transicoes.sair(_tela, Vector2.ZERO, Transicoes.DUR_SAIR, _fim_saida, false)
		return
	if not visible:
		return
	_m = _modo_atual
	layer = LAYER_PAUSA if _m == "pausa" else (LAYER_CENTRAL if _m == "central" else LAYER_HUD)
	_meta = Meta.estado().get("niveis", {})
	_recoletar()
	if _modo_atual == "pausa" and anterior == "":
		Transicoes.entrar(_tela, Vector2.ZERO)  # abre junto com o menu: o fade do card acompanha o do menu


func _fim_saida() -> void:
	_saindo = false
	visible = _modo_atual != ""


## A cada 0,25 s com o card ligado: confere se a partida segue de pé e se o modo mudou (as cartas abriram ou fecharam) e atualiza os números.
func _tique() -> void:
	var viva: bool = mundo != null and mundo.combate != null and str(mundo.combate.jogo) in JOGO_VIVO
	if not _pausa and not viva and (_hud or _central):
		_hud = false  # a partida acabou (morte, vitória, abandono): o card sai de cena
		_central = false
		_aplicar()
		return
	if _modo() != _modo_atual or (_central and not _sobre_cartas()):
		_aplicar()
		return
	if visible:
		_recoletar()


func _recoletar() -> void:
	secoes = coletar(mundo, _meta)
	atualizacoes += 1
	# na pausa e no painel central o card fica opaco (a pessoa quer ler); no jogo rolando é semitransparente
	if not Transicoes.animando(_tela):  # no meio do fade da pausa quem manda no alfa é a transição
		_tela.modulate.a = ALFA_HUD if _modo_atual == "hud" else 1.0
	_tela.queue_redraw()


# ------------------------------------------------------------------ coletar (sem desenhar)


## As seções do card, em dados simples: [{id, titulo, cor, linhas: [...]}]. `meta_niveis` = níveis do Santuário (id -> nível); sem ele, lê o save.
## Linha comum: {tipo "linha", id, rotulo, valor, bonus, n}. Texto solto: {tipo "texto", id, texto, estilo, n}. Bloco (golpe, modificador):
## {tipo "bloco", id, rotulo, nome_curto, icone, cor, nivel_txt, nivel_curto, trechos, curto, uma, dica, n}; `trechos` é a linha de números
## ([[texto, estilo], ...]), `curto` a mesma linha abreviada (para a coluna estreita) e `uma` o número que fica na linha única do HUD compacto.
static func coletar(m, meta_niveis: Variant = null) -> Array:
	var r: Array = []
	if m == null or m.heroi == null or m.combate == null:
		return r
	r.append(_sec_heroi(m))
	r.append(_sec_katana(m))
	r.append(_sec_golpes(m))
	r.append(_sec_partida(m))
	r.append(_sec_santuario(m, meta_niveis))
	return r


## A linha com o `id` dado, ou {} (testes e quem quiser ler um número só).
static func linha(secs: Array, id: String) -> Dictionary:
	for s in secs:
		for l in s.linhas:
			if str(l.get("id", "")) == id:
				return l
	return {}


static func _sec(id: String, titulo: String, cor: Color, linhas: Array) -> Dictionary:
	return {"id": id, "titulo": titulo, "cor": cor, "linhas": linhas}


## `so_cheio` = a linha só entra nos layouts completos (pausa e painel central): o HUD já mostra tempo, abates, combo e nível, e o card compacto precisa do espaço.
static func _l(id: String, rotulo: String, valor: String, n: Array, bonus := "", so_cheio := false) -> Dictionary:
	return {"tipo": "linha", "id": id, "rotulo": rotulo, "valor": valor, "bonus": bonus, "n": n, "so_cheio": so_cheio}


## Número com vírgula decimal ("1,6"); `casas` = casas decimais.
static func _v(v: float, casas := 0) -> String:
	return (("%." + str(casas) + "f") % v).replace(".", ",") if casas > 0 else str(roundi(v))


## Percentual para mostrar: inteiro quando é inteiro, UMA casa decimal só quando precisa ("17,5", não "18").
static func _p(v: float) -> String:
	var r := roundf(v * 10.0) / 10.0
	return _v(r, 0 if is_equal_approx(r, roundf(r)) else 1)


## "+20%", "+17,5%" ou "" (sem bônus): o que passa da base, mostrado em outra cor.
static func _mais_pct(v: float) -> String:
	if absf(v) < 0.05:
		return ""
	return "+" + _p(v) + "%"


## "+5" ou "+0,5" ou "" (sem bônus), para o que não é percentual.
static func _mais(v: float, casas := 0) -> String:
	if absf(v) < 0.5 * pow(10.0, -casas):
		return ""
	return "+" + _v(v, casas)


static func _tempo(s: float) -> String:
	var seg := int(s)
	return "%d:%02d" % [seg / 60, seg % 60]


## O cadastro do herói escolhido (nome, título, arma): dados/v2_herois.json. O card não tem nada fixo de herói.
static func _cadastro(m) -> Dictionary:
	return Herois.heroi(str(m.heroi.chave))


static func _sec_heroi(m) -> Dictionary:
	var h = m.heroi
	var c = m.combate
	var cfg: Dictionary = c.cfg
	var cura: float = c.progresso.cura_por_nivel()
	var frac: float = cura / h.vida_max * 100.0
	var seguidas := int(floorf(h.folego_max / float(cfg.esquiva.gasto)))
	var rp := float(cfg.folego.regen_parado)
	var ra := float(cfg.folego.regen_andando)
	var lin: Array = []
	lin.append(_l("heroi.vida", "Vida", "%d / %d" % [roundi(h.vida), roundi(h.vida_max)], [h.vida, h.vida_max], _mais(h.vida_bonus())))
	lin.append(_l("heroi.cura", "Cura por nível", "+%d (%s%%)" % [roundi(cura), _p(frac)], [cura, frac]))
	lin.append(_l("heroi.andar", "Andar", "%d px/s" % roundi(h.vel_andar()), [h.vel_andar()], _mais_pct((h.m_vel_mov - 1.0) * 100.0)))
	lin.append(_l("heroi.correr", "Correr", "%d px/s" % roundi(h.vel_correr()), [h.vel_correr()]))
	lin.append(_l("heroi.folego", "Fôlego", "%s cargas" % _v(h.folego_max, 1), [h.folego_max], _mais(h.folego_max - float(cfg.folego.max), 1)))
	# o fôlego volta à taxa rápida só com o herói livre E parado; andando ou golpeando (o golpe tira o herói do estado livre) vale a lenta
	lin.append(_l("heroi.recupera", "Recupera parado", "%s/s" % _v(rp, 1), [rp]))
	lin.append(_l("heroi.recupera_andando", "Recupera em ação", "%s/s" % _v(ra, 1), [ra]))
	if h.def_max > 0.0:  # a barra de defesa do escudo (própria, separada do fôlego); quem não tem escudo não vê estas linhas
		var barra: Dictionary = c.escudo.cfg.barra
		var regen: float = Dificuldade.fator(m, "defesa_regen_mult")
		lin.append(_l("heroi.defesa", "Defesa do escudo", "%d (%s s erguido)" % [roundi(h.def_max), _v(h.def_max / float(barra.gasto_s))], [h.def_max]))
		lin.append(
			_l(
				"heroi.defesa_recarga",
				"Recarga da defesa",
				"%s/s parado" % _v(float(barra.regen_parado) * regen, 1) if regen > 0.0 else "só com cura",
				[float(barra.regen_parado) * regen]
			)
		)
	lin.append(_l("heroi.ima", "Ímã de almas", "%d px" % roundi(h.alcance_ima()), [h.alcance_ima()], _mais_pct((h.m_ima - 1.0) * 100.0)))
	lin.append(_l("heroi.nivel", "Nível", "%d · XP %d/%d" % [h.nivel, roundi(h.xp), roundi(h.xp_proximo)], [h.nivel, h.xp, h.xp_proximo], "", true))
	lin.append(_l("heroi.esquiva", "Esquiva", "%d seguidas" % seguidas, [seguidas, h.esq_dur]))
	lin.append(_l("heroi.imune", "Imune na esquiva", "%s s" % _v(h.esq_inv, 2), [h.esq_inv]))
	return _sec("heroi", "HERÓI: " + str(_cadastro(m).get("nome", "")).to_upper(), Paleta.SECAO_HEROI, lin)


static func _sec_katana(m) -> Dictionary:
	var h = m.heroi
	var c = m.combate
	var cfg: Dictionary = c.cfg
	var passos: Array = cfg.golpe.passos
	var danos: Array = []
	var alcances: Array = []
	var t_danos: Array = []
	var t_alc: Array = []
	for i in passos.size():
		var p: Dictionary = passos[i]
		danos.append(c.dano_do_passo(p))
		alcances.append(c.alcance_efetivo_do_passo(p))
		t_danos.append(str(roundi(c.dano_do_passo(p))))
		t_alc.append(str(roundi(c.alcance_efetivo_do_passo(p))))
	var ciclo: float = c.ciclo_do_combo()
	var chance := minf(c.chance_critico(), 1.0)  # o jogo sorteia `randf() < chance`: acima de 100% não passa
	var mult := float(cfg.golpe.critico.mult)
	var lin: Array = []
	lin.append(_l("katana.dano", "Dano", "/".join(t_danos), danos, _mais_pct((h.m_dano - 1.0) * 100.0)))
	lin.append(_l("katana.vel", "Vel. de ataque", _mais_pct((h.m_vel_ataque - 1.0) * 100.0) if h.m_vel_ataque != 1.0 else "base", [h.m_vel_ataque]))
	var combo_rotulo := "Combo estimado" if str(passos[0].get("tipo", "melee")) == "adagas" else "Combo completo"
	lin.append(_l("katana.combo", combo_rotulo, "%s s" % _v(ciclo, 2), [ciclo]))
	lin.append(_l("katana.alcance", "Alcance", "/".join(t_alc) + " px", alcances))
	lin.append(_l("katana.area", "Área do corte", _mais_pct((h.m_area - 1.0) * 100.0) if h.m_area != 1.0 else "base", [h.m_area]))
	lin.append(_l("katana.critico", "Crítico x%s" % _v(mult, 1), "%s%%" % _p(chance * 100.0), [chance, mult], _mais_pct(h.m_critico * 100.0)))
	var cs = c.cartas
	var ar = c.armas
	for md in ["onda", "fura", "explode", "folego", "abalo", "muralha", "chuva", "mira"]:  # os de cada herói só aparecem com a carta dele
		var valor := float(ar.mods[md])
		if valor <= 0.0:
			continue
		var d: Dictionary = cs.definicao(md)
		var nivel: int = cs.nivel_de(md)
		var tr: Array = []
		var curto: Array = []
		var uma: Array = []
		var n: Array = [valor]
		match md:
			"onda":
				# a onda sai em TODO corte do combo (pelo nome do passo, não pela posição), e cada corte tem o seu dano
				var pct: float = ar.pct_onda()
				var danos_onda: Array = []
				for p in c.passos_de("corte"):
					danos_onda.append(ar.dano_da_onda(c.dano_do_passo(p)))
				n = [pct] + danos_onda
				var txt := _lista_dano(danos_onda)
				tr = [[_p(pct), 1], ["% do corte (", 0], [txt, 1], [" de dano)", 0]]
				curto = [[_p(pct), 1], ["% do corte (", 0], [txt, 1], [")", 0]]
				uma = [[_p(pct) + "%", 1]]
			"fura":
				# a lança sai em TODA estocada (pelo nome do passo), com o leque de três da Ventania
				var danos_lanca: Array = []
				for p in c.passos_de("estocada"):
					danos_lanca.append(ar.dano_da_lanca(c.dano_do_passo(p)))
				var lancas: int = ar.n_lancas()
				n = [valor, lancas] + danos_lanca
				var txt_l := _lista_dano(danos_lanca)
				tr = [[_p(valor), 1], ["% da estocada (", 0], [txt_l, 1], [" de dano)", 0]]
				curto = [[_p(valor), 1], ["% da estocada (", 0], [txt_l, 1], [")", 0]]
				uma = [[_p(valor) + "%", 1]]
				if lancas > 1:
					tr.append([" x%d em leque" % lancas, 0])
					curto.append([" x%d" % lancas, 0])
					uma.append([" x%d" % lancas, 0])
			"explode":
				tr = [[_p(valor), 1], ["% do dano do crítico, em área", 0]]
				curto = [[_p(valor), 1], ["% do crítico, em área", 0]]
				uma = [[_p(valor) + "%", 1]]
			"folego":
				tr = [[_p(valor), 1], ["% de uma carga por abate", 0]]
				curto = [[_p(valor), 1], ["% de carga por abate", 0]]
				uma = [[_p(valor) + "%", 1]]
			"abalo":
				# o Nick: a pancada no chão solta uma onda de choque com esse % do dano dela
				var danos_abalo: Array = []
				for p in c.passos_de("pancada"):
					danos_abalo.append(valor / 100.0 * c.dano_do_passo(p))
				var txt_a := _lista_dano(danos_abalo)
				n = [valor] + danos_abalo
				tr = [[_p(valor), 1], ["% da pancada (", 0], [txt_a, 1], [" de dano)", 0]]
				curto = [[_p(valor), 1], ["% da pancada (", 0], [txt_a, 1], [")", 0]]
				uma = [[_p(valor) + "%", 1]]
			"muralha":
				# o Nick: empurra e atordoa mais (o empurrão do golpe e o atordoamento sobem esse %)
				tr = [["+", 0], [_p(valor), 1], ["% de empurrão e atordoamento", 0]]
				curto = [["+", 0], [_p(valor), 1], ["% empurrão", 0]]
				uma = [["+" + _p(valor) + "%", 1]]
			"chuva":
				# o Luke: cada acerto solta uma adaga extra com esse % de chance
				tr = [[_p(valor), 1], ["% de chance de cada acerto soltar uma adaga extra", 0]]
				curto = [[_p(valor), 1], ["% de adaga extra", 0]]
				uma = [[_p(valor) + "%", 1]]
			"mira":
				# o Luke: alcance e velocidade das adagas
				tr = [["+", 0], [_p(valor), 1], ["% de alcance e velocidade das adagas", 0]]
				curto = [["+", 0], [_p(valor), 1], ["% alcance das adagas", 0]]
				uma = [["+" + _p(valor) + "%", 1]]
		# a peça que já virou a Ventania não sobe mais de nível: diz "evoluída" em vez de um "nv 2/4" parado
		var evoluida: bool = not cs.ativa(str(md))
		var nivel_txt := "evoluída" if evoluida else "nv %d/%d" % [nivel, int(d.max)]
		var nivel_curto := "evo" if evoluida else "%d/%d" % [nivel, int(d.max)]
		lin.append(
			_bloco(
				"katana." + str(md),
				str(d.nome),
				str(d.get("curto", d.nome)),
				str(d.get("icone", "")),
				Paleta.DICA,
				nivel_txt,
				nivel_curto,
				tr,
				curto,
				uma,
				_dica_evolucao(cs, str(md)),
				n,
				str(md)
			)
		)
	if not ar.ventania.is_empty():
		var ev: Dictionary = ar.ventania
		var tr_v: Array = [["onda x", 0], [_v(float(ev.mult_onda), 1), 1], [", lanças em leque", 0]]
		var cor_v := Color(ev.cor[0], ev.cor[1], ev.cor[2])
		lin.append(
			_bloco(
				"katana.ventania",
				str(ev.nome),
				str(ev.get("curto", ev.nome)),
				str(cs.definicao("onda").get("icone", "")),
				cor_v,
				"evoluída",
				"evo",
				tr_v,
				tr_v,
				[["x" + _v(float(ev.mult_onda), 1), 1]],
				"",
				[float(ev.mult_onda)],
				"ventania"
			)
		)
	return _sec("katana", "%s (CLIQUE)" % str(_cadastro(m).get("arma", "KATANA")), Paleta.SECAO_KATANA, lin)


static func _sec_golpes(m) -> Dictionary:
	var c = m.combate
	var cs = c.cartas
	var ar = c.armas
	var lin: Array = []
	for id in ar.ativas:
		var a: Dictionary = ar.ativas[id]
		var nums: Dictionary = ar.numeros(a)
		var nome := ""
		var nome_curto := ""
		var icone := ""
		var nivel_txt := ""
		var nivel_curto := ""
		if bool(a.evo):
			for ev in cs.cfg.evolucoes:
				if str(ev.id) == str(id):
					nome = str(ev.nome)
					nome_curto = str(ev.get("curto", ev.nome))
					var consumidas: Array = ev.get("consome", [])
					if not consumidas.is_empty():
						icone = str(cs.definicao(str(consumidas[0])).get("icone", ""))
			nivel_txt = "evoluída"
			nivel_curto = "evo"
		else:
			var d: Dictionary = cs.definicao(str(id))
			nome = str(d.nome)
			nome_curto = str(d.get("curto", d.nome))
			icone = str(d.get("icone", ""))
			nivel_txt = "nv %d/%d" % [int(a.nivel), int(d.max)]
			nivel_curto = "%d/%d" % [int(a.nivel), int(d.max)]
		var dano := str(roundi(float(nums.dano)))
		var cada := _v(float(nums.intervalo), 2)
		var poder := _v(float(nums.dps))
		# "poder" é uma ESTIMATIVA de dano por segundo num monstro sempre ao alcance (veja armas.numeros): o til avisa
		var tr: Array = [["dano ", 0], [dano, 1], [" · a cada ", 0], [cada, 1], [" s · poder ", 0], ["~" + poder, 1], ["/s", 0]]
		var curto: Array = [[dano, 1], [" dano · ", 0], [cada, 1], [" s · ", 0], ["~" + poder, 1], ["/s", 0]]
		var uma: Array = [["~" + poder, 1], ["/s", 0]]
		var dica := "" if bool(a.evo) else _dica_evolucao(cs, str(id))
		lin.append(
			_bloco(
				"arma." + str(id),
				nome,
				nome_curto,
				icone,
				a.cor,
				nivel_txt,
				nivel_curto,
				tr,
				curto,
				uma,
				dica,
				[nums.dano, nums.intervalo, nums.dps, nums.acertos],
				str(id)
			)
		)
	if lin.is_empty():
		lin.append({"tipo": "texto", "id": "arma.nenhum", "texto": "Nenhum ainda: eles vêm das cartas.", "estilo": 0, "n": []})
	return _sec("golpes", "GOLPES AUTOMÁTICOS", Paleta.SECAO_GOLPES, lin)


## Os danos de uma lista, arredondados como o jogo os aplica e separados por "/" ("8/9"); repetidos em seguida viram um número só.
static func _lista_dano(danos: Array) -> String:
	var t: Array = []
	for d in danos:
		var r := str(maxi(1, roundi(float(d))))
		if t.is_empty() or t[t.size() - 1] != r:
			t.append(r)
	return "/".join(t)


## "Evolui: Anel de Brasas (falta Lâminas Rodopiantes nv 3)", ou, se uma peça não chega mais lá (já gasta em outra evolução),
## "Evolução perdida (Anel de Brasas: Lâminas Rodopiantes já evoluiu em outra)", ou "".
static func _dica_evolucao(cs, id: String) -> String:
	var partes: Array = []
	for e in cs.evolucoes_com(id):
		var perdida: Array = e.perdida
		var falta: Array = e.falta
		if not perdida.is_empty():
			partes.append("Evolução perdida (%s: %s)" % [e.nome, ", ".join(perdida)])
		elif not falta.is_empty():
			partes.append("Evolui: %s (falta %s)" % [e.nome, ", ".join(falta)])
	return "\n".join(partes)


static func _bloco(
	id: String,
	rotulo: String,
	nome_curto: String,
	icone: String,
	cor: Color,
	nivel_txt: String,
	nivel_curto: String,
	trechos: Array,
	curto: Array,
	uma: Array,
	dica: String,
	n: Array,
	carta: String = ""  # id da carta (golpe, evolução, modificador): o ícone próprio dela sai na linha; `icone` é o antigo, de reserva
) -> Dictionary:
	return {
		"tipo": "bloco",
		"id": id,
		"rotulo": rotulo,
		"nome_curto": nome_curto,
		"icone": icone,
		"cor": cor,
		"nivel_txt": nivel_txt,
		"nivel_curto": nivel_curto,
		"trechos": trechos,
		"curto": curto,
		"uma": uma,
		"dica": dica,
		"n": n,
		"carta": carta
	}


static func _sec_partida(m) -> Dictionary:
	var c = m.combate
	var cs = c.cartas
	var falta_onda: float = c.diretor.falta_onda_real()
	# as almas que o fim da partida credita de fato: as coletadas mais o bônus "Almas abundantes" do Santuário (a conta de Meta.registrar_partida)
	var bruto: int = m.almas_partida
	var bonus_almas := float(m.meta_bonus.get("almas", 0.0)) if m.meta_bonus is Dictionary else 0.0
	var creditadas: int = Meta.almas_creditadas(bruto, bonus_almas, m.fator_pesadelo("almas_mult"))
	var lin: Array = []
	if m.pesadelo():
		lin.append(_l("partida.modo", "Modo", "PESADELO", [1], "", true))
	lin.append(_l("partida.tempo", "Tempo", _tempo(m.tempo_partida), [m.tempo_partida], "", true))
	lin.append(_l("partida.abates", "Abates", str(m.abates), [m.abates], "", true))
	lin.append(_l("partida.combo", "Combo", "x%d · maior x%d" % [m.combo, m.maior_combo], [m.combo, m.maior_combo], "", true))
	lin.append(_l("partida.almas", "Almas a receber", str(creditadas), [bruto, creditadas], _mais(float(creditadas - bruto))))
	lin.append(_l("partida.onda", "Onda forte", str(c.diretor.ondas), [c.diretor.ondas]))
	lin.append(_l("partida.proxima", "Próxima onda", "em %d s" % ceili(falta_onda), [falta_onda]))
	return _sec("partida", "PARTIDA", Paleta.SECAO_PARTIDA, lin)


static func _sec_santuario(_m, meta_niveis: Variant) -> Dictionary:
	var niveis: Dictionary = meta_niveis if meta_niveis is Dictionary else Meta.estado().get("niveis", {})
	var lin: Array = []
	for md in Meta.melhorias_visiveis(false):  # só id, nome e valor: sem reler o save no tique do card
		var n := int(niveis.get(md.id, 0))
		if n <= 0:
			continue
		lin.append({"tipo": "texto", "id": "santuario." + str(md.id), "texto": Meta.texto_efeito(md, n), "estilo": 3, "n": [float(md.valor) * n]})
	if lin.is_empty():
		lin.append({"tipo": "texto", "id": "santuario.nenhuma", "texto": "Nenhuma melhoria comprada.", "estilo": 0, "n": []})
	return _sec("santuario", "SANTUÁRIO", COR_SANTUARIO, lin)


# ------------------------------------------------------------------ desenho


func _pintar() -> void:
	if secoes.is_empty() or _modo_atual == "":
		return
	_m = _modo_atual
	if _m != "hud" and not _detalhe:
		_pintar_visual()  # pausa e painel central abrem na página visual; o Tab troca pela tabela de detalhes
		return
	var rects: Array = _colunas()
	var opaco: bool = _m != "hud"  # na pausa e no painel central: sem ver o que está atrás
	if _m == "central":
		_tela.draw_rect(EscalaUi.cobertura(EscalaUi.canvas_atual, EscalaUi.desloc_atual), COR_FUNDO_OPACO)  # o painel central cobre a tela toda: as cartas (camada 11) e o HUD ficam escondidos
	for c in rects.size():
		var r := _medir(c)
		if opaco:
			_tela.draw_rect(r, COR_FUNDO_OPACO)
		_tela.draw_style_box(_estilo, r)
		_coluna(c, rects[c], false)


## A folga de dentro de um quadro, da borda externa ao texto: na pausa, a faixa da moldura mais a folga (INTERNA_PAUSA); fora dela, PAD como antes.
func _margem() -> float:
	return INTERNA_PAUSA if _m == "pausa" else PAD


## O modo em que as medidas valem: o da tela agora ou, com o card escondido, o compacto do HUD (os testes medem o layout sem abrir o card).
func _modo_de_medida() -> String:
	return _modo_atual if _modo_atual != "" else "hud"


## Os retângulos das colunas como são desenhadas agora (a altura é a que o conteúdo pede). Os testes conferem que não cobrem o HUD.
func retangulos() -> Array:
	_m = _modo_de_medida()
	var r: Array = []
	for c in _colunas().size():
		r.append(_medir(c))
	return r


## Por coluna: true se um item individual excedeu a altura disponível. A tabela distribui todos os itens entre páginas.
func colunas_cortadas() -> Array:
	_m = _modo_de_medida()
	var r: Array = []
	for c in _colunas().size():
		_medir(c)
		r.append(bool(_sobrou[c]))
	return r


func _medir(c: int) -> Rect2:
	var r: Rect2 = _colunas()[c]
	var alt := _coluna(c, r, true)
	_sobrou[c] = alt > r.size.y
	return Rect2(r.position, Vector2(r.size.x, _alt_quadro(r, alt)))


## A altura do quadro: a que o conteúdo pede, sem passar da coluna; na pausa é sempre a da coluna (a do painel do menu), para os três quadros
## terem o mesmo topo e o mesmo fundo.
func _alt_quadro(col: Rect2, conteudo: float) -> float:
	return col.size.y if _m == "pausa" else minf(conteudo, col.size.y)


## IDs com conteúdo que ultrapassa a largura, depois das quebras reais de texto. Vazio = tudo cabe.
func linhas_que_estouram() -> Array:
	_m = _modo_de_medida()
	var r: Array = []
	var rects: Array = _colunas()
	var grupos: Array = _secoes_das_colunas()
	for c in rects.size():
		var w: float = (rects[c] as Rect2).size.x - 2.0 * _margem()
		for id in grupos[c]:
			for l in _achar(str(id)).get("linhas", []):
				if _estoura(l, w):
					r.append(str(l.id))
	return r


func _estoura(l: Dictionary, w: float) -> bool:
	match str(l.tipo):
		"linha":  # cada parte pode ocupar várias linhas, incluindo o bônus
			return (
				_quebrar(str(l.rotulo), TAM, w).any(func(t): return _larg_misto(t, TAM) > w)
				or _quebrar(str(l.valor), TAM, w).any(func(t): return _larg_misto(t, TAM) > w)
				or _quebrar(str(l.bonus), TAM, w).any(func(t): return _larg_misto(t, TAM) > w)
			)
		"texto":
			var tam := TAM_P if int(l.estilo) == 3 else TAM
			for palavra in str(l.texto).split(" ", false):
				if _larg_misto(palavra, tam) > w:
					return true
			return false
		"bloco":
			var wt := w - ICONE - 4.0
			if _m == "hud":
				# o nome encolhe e corta com "." quando não cabe (`_desenhar_bloco_compacto`): estoura só se nível e número não cabem com um pedaço de nome
				return _larg_misto(str(l.nivel_curto), TAM_P) + 12.0 + _larg_trechos(l.uma) + 40.0 > wt
			if _larg_misto(str(l.nivel_txt), TAM_P) > wt:
				return true
			for nome in _quebrar(str(l.rotulo), TAM, wt):
				if _larg_misto(nome, TAM) > wt:
					return true
			for trechos in _linhas_do_bloco(l, wt):
				if _larg_trechos(trechos) > wt:
					return true
			return false
	return false


## Desenha (ou só mede, com `seco`) a coluna `c` dentro de `r`. Devolve a altura que o conteúdo pede, com a moldura.
func _coluna(c: int, r: Rect2, seco: bool) -> float:
	var m := _margem()
	var x := r.position.x + m
	var w := r.size.x - 2.0 * m
	var topo := r.position.y + m - (1.0 if _m == "pausa" else 0.0)  # na pausa, o título da 1ª seção (1 px acima da linha) põe o acento de "HERÓI" na folga de dentro
	var limite := r.end.y - m - ALT_LINHA
	var paginas: Array = [[]]
	var alturas: Array = [topo]
	var pagina_atual := 0
	for id in _secoes_das_colunas()[c]:
		var sec := _achar(str(id))
		if sec.is_empty():
			continue
		var cab := true
		for l in sec.linhas:
			if _m == "hud" and bool(l.get("so_cheio", false)):
				continue
			var alt := _altura(l, w)
			var titulo := ALT_CAB + 4.0 if cab else 0.0
			if float(alturas[pagina_atual]) + titulo + alt > limite and not paginas[pagina_atual].is_empty():
				paginas.append([])
				alturas.append(topo)
				pagina_atual += 1
				cab = true
				titulo = ALT_CAB + 4.0
			if cab:
				paginas[pagina_atual].append({"sec": sec, "y": alturas[pagina_atual]})
				alturas[pagina_atual] += titulo
				cab = false
			paginas[pagina_atual].append({"linha": l, "y": alturas[pagina_atual]})
			alturas[pagina_atual] += alt
	if c == 0:
		_diagnostico.clear()
	for n in paginas.size():
		for item in paginas[n]:
			if item.has("linha"):
				_diagnostico.append(
					{
						"id": str(item.linha.id),
						"coluna": c,
						"pagina": n + 1,
						"rect": Rect2(x, item.y, w, _altura(item.linha, w)),
						"dados": item.linha.duplicate(true)
					}
				)
	_paginas_detalhes[c] = paginas.size()
	var pg := mini(_pag_detalhes, paginas.size() - 1)
	_golpes_mostrados = 0
	if not seco:
		for item in paginas[pg]:
			if item.has("sec"):
				_texto_titulo(str(item.sec.titulo), Vector2(x, item.y - 1.0), item.sec.cor)
			else:
				_item(item.linha, x, item.y, w)
				if str(item.linha.tipo) == "bloco" and "golpes" in _secoes_das_colunas()[c]:
					_golpes_mostrados += 1
		var teclas := (Glifos.texto("abas") if Glifos.eh_controle() else "PgUp/PgDn") if _m == "hud" else Glifos.texto("abas")
		var fecha := ("%s fecha" % Glifos.texto("card")) if _m == "hud" else ("%s visual" % Glifos.texto("detalhes"))
		var nav := "%d/%d %s" % [pg + 1, paginas.size(), teclas] if paginas.size() > 1 else fecha
		_misto(nav, x, float(alturas[pg]), TAM, COR_DICA, COR_DICA)
	return float(alturas[pg]) - r.position.y + m + ALT_LINHA


## Todas as páginas da tabela, por coluna. Nenhum atributo é removido.
func paginas_detalhes() -> Dictionary:
	retangulos()
	_pag_detalhes = clampi(_pag_detalhes, 0, int(_paginas_detalhes.max()) - 1)
	return {"pagina": _pag_detalhes + 1, "paginas": _paginas_detalhes.max(), "colunas": _paginas_detalhes.duplicate()}


## Geometria e dados completos de cada item em todas as páginas da tabela.
func medir_layout() -> Array:
	retangulos()
	return _diagnostico.duplicate(true)


## Golpes da página visual corrente, com o mesmo intervalo usado pelo desenho.
func medir_golpes_visuais() -> Array:
	_m = _modo_de_medida()
	_visual(true)
	return _golpes_visuais.duplicate(true)


## Quantos golpes a build tem no total (as linhas de bloco da seção "golpes").
func _golpes_total() -> int:
	var n := 0
	for l in _achar("golpes").get("linhas", []):
		if str(l.tipo) == "bloco":
			n += 1
	return n


func _achar(id: String) -> Dictionary:
	for s in secoes:
		if str(s.id) == id:
			return s
	return {}


func _altura(l: Dictionary, w: float) -> float:
	match str(l.tipo):
		"linha":
			if (
				_larg_misto(str(l.rotulo), TAM) + 8.0 + _larg_misto(str(l.valor), TAM) + _larg_misto(str(l.bonus), TAM) + (5.0 if str(l.bonus) != "" else 0.0)
				> w
			):
				return ALT_LINHA * (_quebrar(str(l.rotulo), TAM, w).size() + _quebrar(str(l.valor), TAM, w).size() + _quebrar(str(l.bonus), TAM, w).size())
			return ALT_LINHA
		"bloco":
			if _m == "hud":
				return ALT_BLOCO_COMPACTO
			var wt := w - ICONE - 4.0
			var alt := ALT_LINHA * float(_quebrar(str(l.rotulo), TAM, wt).size() + 1 + _linhas_do_bloco(l, wt).size())
			if str(l.dica) != "":
				alt += _alt_dica(str(l.dica), wt)
			return alt + 3.0
		"texto":
			return ALT_LINHA * float(_quebrar(str(l.texto), TAM_P if int(l.estilo) == 3 else TAM, w).size())
	return ALT_LINHA


func _item(l: Dictionary, x: float, y: float, w: float) -> void:
	match str(l.tipo):
		"linha":
			_desenhar_linha(l, x, y, w)
		"texto":
			var santuario := int(l.estilo) == 3
			var cor := COR_SANTUARIO if santuario else COR_ROTULO
			var yy := y
			for linha_t in _quebrar(str(l.texto), TAM_P if santuario else TAM, w):
				_misto(str(linha_t), x, yy, TAM_P if santuario else TAM, cor, cor)
				yy += ALT_LINHA
		"bloco":
			if _m == "hud":
				_desenhar_bloco_compacto(l, x, y, w)
			else:
				_desenhar_bloco(l, x, y, w)


func _desenhar_linha(l: Dictionary, x: float, y: float, w: float) -> void:
	var f: Font = Dados.fonte_texto
	if _larg_misto(str(l.rotulo), TAM) + 8.0 + _larg_misto(str(l.valor), TAM) + _larg_misto(str(l.bonus), TAM) + (5.0 if str(l.bonus) != "" else 0.0) > w:
		for texto in _quebrar(str(l.rotulo), TAM, w):
			_misto(texto, x, y, TAM, COR_ROTULO, COR_ROTULO)
			y += ALT_LINHA
		for texto in _quebrar(str(l.valor), TAM, w):
			_misto(texto, x + w, y, TAM, COR_ROTULO, COR_VALOR, true)
			y += ALT_LINHA
		for texto in _quebrar(str(l.bonus), TAM, w):
			_misto(texto, x + w, y, TAM, COR_BONUS, COR_BONUS, true)
			y += ALT_LINHA
		return
	var direita := x + w
	var bonus := str(l.bonus)
	# aqui as três partes cabem juntas; o caminho acima empilha as partes quando necessário
	if (
		bonus != ""
		and f.get_string_size(str(l.rotulo), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x + 8.0 + _larg_misto(str(l.valor), TAM) + _larg_misto(bonus, TAM) + 5.0 <= w
	):
		_misto(bonus, direita, y, TAM, COR_BONUS, COR_BONUS, true)
		direita -= _larg_misto(bonus, TAM) + 5.0
	_texto(f, str(l.rotulo), Vector2(x, y), w, HORIZONTAL_ALIGNMENT_LEFT, TAM, COR_ROTULO)
	_misto(str(l.valor), direita, y, TAM, COR_ROTULO, COR_VALOR, true)


## Ícone da carta na linha do card: o próprio do id, na versão de 16 px (a linha tem 18 a 20 px); sem ele, o antigo `icone`.
func _desenhar_icone(l: Dictionary, x: float, y: float) -> void:
	var tx := Dados.icone_carta(str(l.get("carta", "")), str(l.icone), true)
	if tx != null:
		_tela.draw_texture(tx, Vector2(x, y))


## Linha de peça já fundida: o nível é "evoluída" (nível curto "evo"). Só essa linha leva o ícone da fusão.
static func _fundida(l: Dictionary) -> bool:
	return str(l.nivel_curto) == "evo"


## Um golpe ou modificador numa linha só (HUD): ícone, nome curto, nível e o número (poder estimado, ou o valor do modificador).
func _desenhar_bloco_compacto(l: Dictionary, x: float, y: float, w: float) -> void:
	var ft: Font = Dados.fonte_titulo
	_desenhar_icone(l, x, y)
	var xt := x + ICONE + 4.0
	var fim := x + w
	var cor: Color = Color(l.cor).lerp(Paleta.BRANCO, 0.35)
	var larg_uma := _larg_trechos(l.uma)
	var xx := fim - larg_uma
	var xs := xx
	for tr in l.uma:
		xs += _desenhar_trecho(tr, xs, y + 4.0)
	var nivel := str(l.nivel_curto)
	_misto(nivel, xx - 6.0, y + 3.0, TAM_P, COR_ROTULO, COR_ROTULO, true)
	# o nome vai até o nível (o espaço que sobra entre o ícone e o nível); na grade da Jersey 10 (19) quando cabe, um degrau abaixo se não
	# (a Jersey fora da grade sai borrada, então só quando precisa), e corta com "." quando nem o degrau cabe (golpe com nome longo e sem curto)
	var espaco_nome := (xx - 6.0 - _larg_misto(nivel, TAM_P) - 6.0) - xt
	if _fundida(l):  # o ícone da fusão entra antes do "evo", e o nome cede o espaço dele
		var xi := xx - 6.0 - _larg_misto(nivel, TAM_P) - 4.0 - ICONE_FUSAO.get_width()
		_tela.draw_texture(ICONE_FUSAO, Vector2(xi, y))
		espaco_nome -= ICONE_FUSAO.get_width() + 4.0
	var tam_nome := TAM_CAB if ft.get_string_size(str(l.nome_curto), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_CAB).x <= espaco_nome else TAM_NOME_PEQ
	var nome := _cabe_nome(str(l.nome_curto), espaco_nome, tam_nome)
	_tela.draw_string(ft, Vector2(xt, y - 1.0 + ft.get_ascent(TAM_CAB)), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nome, cor)


func _desenhar_bloco(l: Dictionary, x: float, y: float, w: float) -> void:
	_desenhar_icone(l, x, y)
	var xt := x + ICONE + 4.0
	var wt := w - ICONE - 4.0
	var cor: Color = Color(l.cor).lerp(Paleta.BRANCO, 0.35)
	var yy := y
	for nome in _quebrar(str(l.rotulo), TAM, wt):
		_texto(Dados.fonte_texto, nome, Vector2(xt, yy), wt, HORIZONTAL_ALIGNMENT_LEFT, TAM, cor)
		yy += ALT_LINHA
	_misto(str(l.nivel_txt), xt, yy, TAM_P, COR_ROTULO, COR_ROTULO)
	if _fundida(l):  # a peça fundida leva o ícone da fusão depois do "evoluída"
		_tela.draw_texture(ICONE_FUSAO, Vector2(xt + _larg_misto(str(l.nivel_txt), TAM_P) + 6.0, yy))
	yy += ALT_LINHA
	for linha_t in _linhas_do_bloco(l, wt):
		var xx := xt
		for tr in linha_t:
			xx += _desenhar_trecho(tr, xx, yy)
		yy += ALT_LINHA
	if str(l.dica) != "":
		for linha_d in _linhas_dica(str(l.dica), wt):  # os números da dica na fonte dos números (a fonte de texto pequena confunde dígitos)
			_misto(str(linha_d), xt, yy, TAM_P, COR_DICA, COR_DICA)
			yy += ALT_LINHA


## Desenha um trecho de uma linha de números e devolve a largura. Estilo 1 e 2 são números (Press Start 2P); estilo 0 é texto de apoio.
func _desenhar_trecho(tr: Array, x: float, y: float) -> float:
	var estilo := int(tr[1])
	var cor: Color = CORES_TRECHO[estilo]
	if estilo == 0:
		_misto(str(tr[0]), x, y, TAM_P, cor, COR_VALOR)
	else:
		var base := y + Dados.fonte_texto.get_ascent(TAM_P)
		_tela.draw_string(_f_num, Vector2(x, base), str(tr[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUM, cor)
	return _larg_trecho(tr)


func _larg_trecho(tr: Array) -> float:
	if int(tr[1]) == 0:
		return _larg_misto(str(tr[0]), TAM_P)
	return _f_num.get_string_size(str(tr[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUM).x


# ------------------------------------------------------------------ página VISUAL (pausa e painel central)
# O que a pessoa lê para decidir a build, em barras, pips e ícones: nível e XP, vida, fôlego, esquivas, os bônus e o que cada golpe faz.
# O detalhe técnico (px/s, recuperação do fôlego, imunidade em segundos, a próxima onda...) fica na página de DETALHES (a tabela de antes),
# que o Tab alterna (`alternar_detalhe`). O HUD compacto (C na partida) segue a tabela curta. Os números vêm das `secoes` (o mesmo `coletar`
# que os testes conferem) e, no que é só barra (vida, XP e fôlego de agora, os multiplicadores), do herói.

const TAM_GRANDE := Paleta.NUMERO_GRANDE
const ALT_STAT := 20.0
const ALT_GOLPE := 20.0
const COR_VIDA := Paleta.VIDA
const COR_XP := Paleta.XP
const COR_FOLEGO := Paleta.FOLEGO
const COR_VAZIO := Paleta.BARRA_VAZIA
const COR_BORDA := Paleta.BARRA_BORDA
## Ícones 8x8 desenhados aqui (2x na tela = 16 px). "#" = cor do ícone, "o" = brilho, "." = vazio. Feitos para o card, sem arte de terceiros.
const ICONES := {
	"vida": [".##.##..", "#o####..", "######..", "######..", ".####...", "..##....", "........", "........"],
	"folego": ["...##...", "..#o##..", ".#o###..", ".####...", "..###...", "...##...", "....#...", "........"],
	"esquiva": ["..##....", "..#o#...", "...##...", ".####.#.", "#.##.#..", "..#.#...", ".#...#..", "#.....#."],
	"ima": ["#.....#.", "#o...o#.", "#.....#.", "#.....#.", "##...##.", ".#####..", "..###...", "........"],
	"vel": ["...##...", "..##....", ".####o#.", "#####...", "..##....", ".##.....", "##......", "........"],
	"dano": [".......#", "......##", ".....o#.", "....##..", ".#.##...", "..##....", ".#.#....", "#......."],
	"critico": ["...#....", "..###...", "#.#o#.#.", ".#####..", "#.#o#.#.", "..###...", "...#....", "........"],
	"ritmo": ["..###...", ".#o..#..", "#...#.#.", "#..#..#.", "#.....#.", ".#...#..", "..###...", "........"],
	"area": ["#.#.#.#.", "........", "#..##..#", "..#oo#..", "#.#oo#.#", "...##...", "#......#", ".#.#.#.."],
	"tempo": ["..###...", ".#o..#..", "#..#..#.", "#..##.#.", "#.....#.", ".#...#..", "..###...", "........"],
	"abates": [".####...", "#o####..", "#.##.#..", "######..", ".#..#...", ".####...", "........", "........"],
	"almas": ["...#....", "..##....", ".#o##...", ".####...", "######..", "#o####..", ".####...", "........"],
}

var _detalhe := false  # pausa e painel central: true = a página de detalhes (a tabela), false = a visual


## Tab: troca a página visual pela de detalhes (e volta). Vale com o card na pausa ou no painel central; devolve true se trocou.
func alternar_detalhe() -> bool:
	if _modo_atual != "pausa" and _modo_atual != "central":
		return false
	_detalhe = not _detalhe
	_tela.queue_redraw()
	return true


## A página na tela (ou a que seria medida): "visual", "detalhe" ou "hud" (o compacto do C).
func pagina() -> String:
	if _modo_de_medida() == "hud":
		return "hud"
	return "detalhe" if _detalhe else "visual"


## As colunas da página visual: na pausa as duas ao lado do menu; no painel central as três.
func colunas_visuais() -> Array:
	return COLUNAS_CENTRAL if _modo_de_medida() == "central" else COLUNAS_PAUSA


## Desenha (ou só mede, com `seco`) a página visual; devolve, por coluna, a altura que o conteúdo pede.
## Dicas de tecla do cabeçalho da SUA BUILD: cada par é [ação, texto]; o glifo do botão vem antes do texto, alinhado à direita da coluna.
func _dica_teclas(pares: Array, x: float, w: float, base: float) -> void:
	var total := 10.0 * float(pares.size() - 1)
	for p in pares:
		total += Glifos.largura_acao(p[0]) + 6.0 + _f_num.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUM).x
	var cx := x + w - total
	for p in pares:
		cx += Glifos.desenhar_acao(_tela, p[0], Vector2(cx, base - 12.0)) + 6.0
		_tela.draw_string(_f_num, Vector2(cx, base), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUM, COR_ROTULO)
		cx += _f_num.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUM).x + 10.0


func _visual(seco: bool) -> Array:
	var cols: Array = colunas_visuais()
	var grupos: Array = [["heroi", "partida"], ["katana", "golpes"]] if cols.size() == 2 else [["heroi", "partida"], ["katana"], ["golpes"]]
	var alts: Array = []
	_caixas_visuais.clear()
	for c in cols.size():
		var r: Rect2 = cols[c]
		var m := _margem()
		var x := r.position.x + m
		var w := r.size.x - 2.0 * m
		var y := r.position.y + m - 2.0
		if _m == "pausa" and c > 0:
			y -= TINTA_TITULO  # sem o "SUA BUILD", a 1ª seção (KATANA, desenhada 2 px abaixo do topo) põe a tinta dela na folga de dentro
		var tinta_topo := y + (2.0 if c == 0 else 8.0)  # a tinta mais alta da coluna: a tecla do cabeçalho (y + 2) ou o título da 1ª seção (y + 8)
		if c == 0:
			if not seco:
				_texto_titulo("SUA BUILD", Vector2(x, y), COR_TITULO)
				var pares := [["detalhes", "detalhes"]]
				if _m != "pausa":
					pares.append(["card", "fecha"])
				_dica_teclas(pares, x, w, y + 6.0 + _f_num.get_ascent(TAM_NUM))
			y += ALT_TITULO
		for id in grupos[c]:
			var sec := _achar(str(id))
			if sec.is_empty():
				continue
			if not seco:
				var tit := str(sec.titulo).replace(" (CLIQUE)", "").trim_prefix("HERÓI: ")
				_texto_titulo("GOLPES" if str(id) == "golpes" else tit, Vector2(x, y + 2.0), sec.cor)  # GOLPES curto: a legenda cabe ao lado
				if str(id) == "golpes":  # a legenda das duas colunas da direita das linhas de golpe
					_texto(Dados.fonte_texto, "nível · dano/s", Vector2(x, y + 2.0), w, HORIZONTAL_ALIGNMENT_RIGHT, TAM, COR_APAGADO)
				_tela.draw_line(Vector2(x, y + ALT_CAB + 2.0), Vector2(x + w, y + ALT_CAB + 2.0), COR_LINHA, 1.0)
			y += ALT_CAB + 7.0
			match str(id):
				"heroi":
					y = _v_heroi(x, y, w, seco)
				"partida":
					y = _v_partida(x, y, w, seco)
				"katana":
					y = _v_katana(x, y, w, seco)
				"golpes":
					y = _v_golpes(sec, x, y, w, seco, r.end.y - m)
			y += 4.0
		alts.append(y - r.position.y + m - 2.0)
		_caixas_visuais.append(Rect2(x, tinta_topo, w, r.end.y - m - tinta_topo))
	return alts


## Os retângulos da página visual como são desenhados (a altura é a que o conteúdo pede, sem passar da coluna).
func retangulos_visuais() -> Array:
	_m = _modo_de_medida()
	var alts := _visual(true)
	var r: Array = []
	for c in alts.size():
		var col: Rect2 = colunas_visuais()[c]
		r.append(Rect2(col.position, Vector2(col.size.x, _alt_quadro(col, float(alts[c])))))
	return r


## Por coluna: true se a página visual pede mais altura que a coluna (os testes conferem que nunca, nem com a build cheia).
func visual_cortada() -> Array:
	_m = _modo_de_medida()
	var alts := _visual(true)
	var r: Array = []
	for c in alts.size():
		r.append(float(alts[c]) > (colunas_visuais()[c] as Rect2).size.y)
	return r


## Por coluna da página visual, a folga da área do texto até o filete interno da moldura: [esq, topo, dir, base], em px do canvas.
## A área é a de `_visual` (a coluna sem a margem, a partir da tinta do 1º título até a base da coluna menos a margem). Na pausa, FOLGA_PAUSA ou mais.
func folgas_visuais() -> Array:
	_m = _modo_de_medida()
	var cols := colunas_visuais()
	_visual(true)
	var filete := FILETE_PAUSA + 1.0
	var r: Array = []
	for c in cols.size():
		var col: Rect2 = cols[c]
		var caixa: Rect2 = _caixas_visuais[c]
		r.append(
			[
				caixa.position.x - (col.position.x + filete),
				caixa.position.y - (col.position.y + filete),
				(col.end.x - filete) - caixa.end.x,
				(col.end.y - filete) - caixa.end.y
			]
		)
	return r


## Na tabela de detalhes, por coluna, a menor folga de uma linha até o filete interno da moldura: [esq, dir].
func folgas_tabela() -> Array:
	retangulos()  # mede as colunas e enche o diagnóstico com as linhas de todas elas
	var cols := _colunas()
	var filete := FILETE_PAUSA + 1.0
	var r: Array = []
	for c in cols.size():
		var col: Rect2 = cols[c]
		var esq := INF
		var dir := INF
		for d in _diagnostico:
			if int(d.coluna) == c:
				var rect: Rect2 = d.rect
				esq = minf(esq, rect.position.x - (col.position.x + filete))
				dir = minf(dir, (col.end.x - filete) - rect.end.x)
		r.append([esq, dir])
	return r


## Golpes e modificadores da página visual cujo nome sai cortado (com "."): vazio = nenhum nome foi cortado.
func nomes_cortados() -> Array:
	_m = _modo_de_medida()
	var cols := colunas_visuais()
	var w := (cols[cols.size() - 1] as Rect2).size.x - 2.0 * _margem()
	var r: Array = []
	for id in ["katana", "golpes"]:
		for l in _achar(id).get("linhas", []):
			if str(l.tipo) == "bloco" and _cabe(str(l.nome_curto), _largura_nome(l, w)) != str(l.nome_curto):
				r.append(str(l.id))
	return r


func _pintar_visual() -> void:
	var alts := _visual(true)
	var cols := colunas_visuais()
	if _m == "central":
		_tela.draw_rect(EscalaUi.cobertura(EscalaUi.canvas_atual, EscalaUi.desloc_atual), COR_FUNDO_OPACO)
	for c in cols.size():
		var col: Rect2 = cols[c]
		var r := Rect2(col.position, Vector2(col.size.x, _alt_quadro(col, float(alts[c]))))
		_tela.draw_rect(r, COR_FUNDO_OPACO)
		_tela.draw_style_box(_estilo, r)
	_visual(false)


func _icone8(nome: String, pos: Vector2, cor: Color, escala := 2.0) -> void:
	var px: Array = ICONES.get(nome, [])
	var brilho := cor.lightened(0.55)
	for j in px.size():
		var row: String = px[j]
		for i in row.length():
			var ch := row[i]
			if ch == ".":
				continue
			_tela.draw_rect(Rect2(pos + Vector2(i, j) * escala, Vector2(escala, escala)), brilho if ch == "o" else cor)


func _num(s: String, pos: Vector2, w: float, alin: HorizontalAlignment, tam: int, cor: Color) -> void:
	_tela.draw_string(_f_num, Vector2(pos.x, pos.y + _f_num.get_ascent(tam)), s, alin, w, tam, cor)


## Barra com moldura escura: `frac` de 0 a 1 cheio na cor `cor`.
func _barra(r: Rect2, frac: float, cor: Color) -> void:
	_tela.draw_rect(r.grow(1.0), COR_BORDA)
	_tela.draw_rect(r, COR_VAZIO)
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		_tela.draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * f), r.size.y)), cor)
		_tela.draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * f), 2.0)), cor.lightened(0.3))


## Pips (quadradinhos): `total` casas, `cheios` cheios (a fração vira pip parcial).
func _pips(pos: Vector2, cheios: float, total: int, cor: Color, lado := 8.0) -> void:
	for i in total:
		var r := Rect2(pos + Vector2(i * (lado + 3.0), 0), Vector2(lado, lado))
		_tela.draw_rect(r.grow(1.0), COR_BORDA)
		_tela.draw_rect(r, COR_VAZIO)
		var f := clampf(cheios - i, 0.0, 1.0)
		if f > 0.0:
			_tela.draw_rect(Rect2(r.position, Vector2(roundf(lado * f), lado)), cor)


## Uma linha de atributo: ícone, rótulo e o número grande à direita. A cor do valor (`cor_valor`) apaga o que não mudou, para o que mudou saltar.
func _stat(ic: String, cor_ic: Color, rotulo: String, valor: String, x: float, y: float, w: float, cor_valor := COR_VALOR) -> void:
	_icone8(ic, Vector2(x, y + 1.0), cor_ic)
	_texto(Dados.fonte_texto, rotulo, Vector2(x + 22.0, y + 2.0), w, HORIZONTAL_ALIGNMENT_LEFT, TAM, COR_ROTULO)
	_num(valor, Vector2(x, y + 1.0), w, HORIZONTAL_ALIGNMENT_RIGHT, TAM_GRANDE if valor.length() <= 6 else TAM_NUM, cor_valor)


## Bônus de um multiplicador em porcentagem: "+35%", e "+0%" quando não há bônus (no lugar do antigo "base", que confundia).
static func _bonus_pct(mult: float) -> String:
	return "%+d%%" % roundi((mult - 1.0) * 100.0)


## A cor do valor de um bônus: verde se ganhou, vermelho se perdeu, apagado se está no zero.
static func _cor_bonus(mult: float) -> Color:
	var p := roundi((mult - 1.0) * 100.0)
	return COR_BONUS if p > 0 else (COR_VIDA if p < 0 else COR_APAGADO)


## Herói: nível com a barra de XP, vida, fôlego (cada pip é uma esquiva) e os dois bônus de corpo. Uma linha por coisa, rótulo à
## esquerda e valor à direita, sem rótulo solto do outro lado da coluna.
func _v_heroi(x: float, y: float, w: float, seco: bool) -> float:
	var h = mundo.heroi
	if not seco:
		var nv := "NV%d" % h.nivel
		_num(nv, Vector2(x, y), w, HORIZONTAL_ALIGNMENT_LEFT, TAM_GRANDE, COR_TITULO)  # nível grande e a barra de XP ao lado, com o rótulo
		var bx := x + _f_num.get_string_size(nv, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_GRANDE).x + 10.0
		_texto(Dados.fonte_texto, "XP", Vector2(bx, y + 1.0), 20.0, HORIZONTAL_ALIGNMENT_LEFT, TAM, COR_ROTULO)
		_barra(Rect2(bx + 20.0, y + 5.0, x + w - bx - 20.0, 8.0), h.xp / maxf(1.0, h.xp_proximo), COR_XP)
		_icone8("vida", Vector2(x, y + ALT_STAT + 2.0), COR_VIDA)  # vida: barra grossa com o número dentro
		_barra(Rect2(x + 22.0, y + ALT_STAT + 2.0, w - 22.0, 16.0), h.vida / maxf(1.0, h.vida_max), COR_VIDA)
		_num(
			"%d/%d" % [roundi(h.vida), roundi(h.vida_max)], Vector2(x + 22.0, y + ALT_STAT + 6.0), w - 22.0, HORIZONTAL_ALIGNMENT_CENTER, TAM_NUM, Paleta.BRANCO
		)
		var yf := y + 2.0 * ALT_STAT + 4.0  # fôlego: rótulo e os pips (cada carga cheia é uma esquiva) à direita
		_icone8("folego", Vector2(x, yf + 1.0), COR_FOLEGO)
		_texto(Dados.fonte_texto, "Fôlego", Vector2(x + 22.0, yf + 2.0), w, HORIZONTAL_ALIGNMENT_LEFT, TAM, COR_ROTULO)
		var total := ceili(h.folego_max - 0.01)
		_pips(Vector2(x + w - (total * 11.0 - 3.0), yf + 5.0), h.folego, total, COR_FOLEGO)
		_stat("vel", COR_BONUS, "Velocidade", _bonus_pct(h.m_vel_mov), x, y + 3.0 * ALT_STAT + 4.0, w, _cor_bonus(h.m_vel_mov))
		_stat("ima", COR_SANTUARIO, "Ímã de almas", _bonus_pct(h.m_ima), x, y + 4.0 * ALT_STAT + 4.0, w, _cor_bonus(h.m_ima))
	return y + 5.0 * ALT_STAT + 4.0


## Partida: uma linha com rótulo por número (antes eram ícones soltos sem nome).
func _v_partida(x: float, y: float, w: float, seco: bool) -> float:
	var itens: Array = []
	var t := float(linha(secoes, "partida.tempo").get("n", [0])[0])
	var ab := int(linha(secoes, "partida.abates").get("n", [0])[0])
	var al := int(linha(secoes, "partida.almas").get("n", [0, 0])[1])
	itens.append(["tempo", COR_DICA, "Tempo", _tempo(t)])
	itens.append(["abates", COR_ROTULO, "Abates", str(ab)])
	itens.append(["almas", COR_SANTUARIO, "Almas", str(al)])
	if not seco:
		for i in itens.size():
			_stat(str(itens[i][0]), itens[i][1], str(itens[i][2]), str(itens[i][3]), x, y + i * ALT_STAT, w)
	return y + itens.size() * ALT_STAT


func _v_katana(x: float, y: float, w: float, seco: bool) -> float:
	var h = mundo.heroi
	if not seco:
		var maior := 0.0
		for d in linha(secoes, "katana.dano").get("n", []):
			maior = maxf(maior, float(d))
		var cr: Array = linha(secoes, "katana.critico").get("n", [0, 1])
		_stat("dano", COR_VALOR, "Dano", str(roundi(maior)), x, y, w)
		_stat("critico", COR_TITULO, "Crítico", "%s%%" % _p(float(cr[0]) * 100.0), x, y + ALT_STAT, w)
		_stat("ritmo", COR_DICA, "Vel. ataque", _bonus_pct(h.m_vel_ataque), x, y + 2.0 * ALT_STAT, w, _cor_bonus(h.m_vel_ataque))
		_stat("area", COR_BONUS, "Área", _bonus_pct(h.m_area), x, y + 3.0 * ALT_STAT, w, _cor_bonus(h.m_area))
	y += 4.0 * ALT_STAT
	for l in _achar("katana").get("linhas", []):  # os modificadores da katana: uma linha cada, como os golpes
		if str(l.tipo) == "bloco":
			if not seco:
				_golpe(l, x, y, w)
			y += ALT_GOLPE
	return y


## Os golpes da página visual: cabem quantos a altura que sobra (até `limite`) deixar, sem teto fixo. Se não couberem todos, a última linha
## da coluna é "Página X/Y · Q R" e Q e R trocam de página (`paginar`). Uma página só não ganha linha nenhuma de paginação.
func _v_golpes(sec: Dictionary, x: float, y: float, w: float, seco: bool, limite: float) -> float:
	_golpes_visuais.clear()
	var blocos: Array = []
	for l in sec.linhas:
		if str(l.tipo) == "bloco":
			blocos.append(l)
	if blocos.is_empty():
		var linhas := _quebrar("Nenhum ainda: vêm das cartas.", TAM, w)  # quebrada em linhas que cabem na folga: numa só, cortaria o fim
		if not seco:
			for i in linhas.size():
				_texto(Dados.fonte_texto, linhas[i], Vector2(x, y + i * ALT_LINHA), w, HORIZONTAL_ALIGNMENT_LEFT, TAM, COR_ROTULO)
		return y + linhas.size() * ALT_LINHA
	var pg := _paginas_golpes(blocos.size(), limite - y)
	var por: int = pg[0]
	var paginas: int = pg[1]
	var com_nav: bool = pg[2]
	_npag_golpes = paginas
	_pag = clampi(_pag, 0, paginas - 1)
	var ini := _pag * por if com_nav else 0
	var fim := mini(ini + por, blocos.size())
	for k in range(ini, fim):
		_golpes_visuais.append({"id": str(blocos[k].id), "rect": Rect2(x, y, w, ALT_GOLPE)})
		if not seco:
			_golpe(blocos[k], x, y, w)
		y += ALT_GOLPE
	if com_nav:
		if not seco:
			_texto(
				Dados.fonte_texto,
				"Página %d/%d  · %s" % [_pag + 1, paginas, Glifos.texto("abas").replace("/", " ")],
				Vector2(x, limite - ALT_LINHA + 2.0),
				w,
				HORIZONTAL_ALIGNMENT_LEFT,
				TAM,
				COR_DICA
			)
		return limite - 4.0  # o pé da coluna: a linha de paginação, e o +4 que `_visual` soma depois, cabem no limite
	return y


## Quantos golpes cabem por página no espaço `espaco` e quantas páginas dão para `n` golpes: [por_pagina, paginas, com_paginacao].
## Sem paginação, tudo numa página só. Com ela, a linha de baixo é reservada para "Página X/Y".
static func _paginas_golpes(n: int, espaco: float) -> Array:
	if n <= 0:
		return [0, 1, false]
	if int(floorf(espaco / ALT_GOLPE)) >= n:
		return [n, 1, false]
	var por := maxi(int(floorf((espaco - ALT_LINHA) / ALT_GOLPE)), 1)
	return [por, int(ceilf(float(n) / por)), true]


## Q (anterior) e E (próxima): troca a página dos golpes na página visual da pausa e do painel central. Devolve true se trocou.
func paginar(d: int) -> bool:
	if _modo_atual == "hud" or ((_modo_atual == "pausa" or _modo_atual == "central") and _detalhe):
		var info := paginas_detalhes()
		var nova_d := clampi(_pag_detalhes + d, 0, int(info.paginas) - 1)
		if nova_d == _pag_detalhes:
			return false
		_pag_detalhes = nova_d
		_tela.queue_redraw()
		return true
	if _modo_atual != "pausa" and _modo_atual != "central":
		return false
	var nova := clampi(_pag + d, 0, _npag_golpes - 1)
	if nova == _pag:
		return false
	_pag = nova
	_tela.queue_redraw()
	return true


## Os números da paginação dos golpes na página visual: {pagina, paginas} (a página 1 de 1 quando não há paginação). Os testes leem.
func paginas_golpes() -> Dictionary:
	return {"pagina": _pag + 1, "paginas": _npag_golpes}


## Largura dos pips de um golpe ou modificador na página visual: um quadrado de 5 px a cada 8 (o último sem o espaço); evoluído, o ícone de 16 px.
func _largura_pips(l: Dictionary) -> float:
	var nc := str(l.nivel_curto)
	if nc == "evo":
		return 16.0
	var p := nc.split("/")
	var total := int(p[1]) if p.size() > 1 else int(p[0])
	return maxf(0.0, total * 8.0 - 3.0)


## O número da linha: o dano por segundo, sem o til (a legenda "dano/s" do título da seção já diz que é estimativa).
static func _numero_visual(l: Dictionary) -> Array:
	var r: Array = []
	for tr in l.uma:
		r.append([str(tr[0]).trim_prefix("~"), tr[1]])
	return r


## O que sobra para o nome da linha: depois do ícone (22 px), os pips do tamanho deles (`_largura_pips`), 3 px de vão e o número
## à direita, com 4 px entre os pips e o número.
func _largura_nome(l: Dictionary, w: float) -> float:
	return w - 22.0 - _largura_pips(l) - 7.0 - _larg_trechos(_numero_visual(l))


## Um golpe (ou modificador) numa linha: ícone na cor dele, nome curto, nível em pips (estrela dourada se evoluído) e o dano por segundo.
func _golpe(l: Dictionary, x: float, y: float, w: float) -> void:
	var cor: Color = l.cor
	var num := _numero_visual(l)
	var num_w := _larg_trechos(num)
	_tela.draw_rect(Rect2(x - 1.0, y - 1.0, 18.0, 18.0), cor.darkened(0.55))
	_desenhar_icone(l, x, y)
	var nome_w := _largura_nome(l, w)
	_texto(
		Dados.fonte_texto, _cabe(str(l.nome_curto), nome_w), Vector2(x + 22.0, y + 2.0), nome_w, HORIZONTAL_ALIGNMENT_LEFT, TAM, cor.lerp(Paleta.BRANCO, 0.35)
	)
	var pipx := x + w - num_w - 4.0 - _largura_pips(l)
	var nc := str(l.nivel_curto)
	if nc == "evo":
		_icone8("critico", Vector2(pipx, y + 1.0), COR_TITULO)
	else:
		var p := nc.split("/")
		var niv := int(p[0])
		_pips(Vector2(pipx, y + 5.0), niv, int(p[1]) if p.size() > 1 else niv, cor, 5.0)
	_desenhar_trechos_em(num, x + w - num_w, y + 2.0)


func _desenhar_trechos_em(trechos: Array, x: float, y: float) -> void:
	for tr in trechos:
		x += _desenhar_trecho(tr, x, y)


## Corta o nome com "." se não couber em `w`.
func _cabe(s: String, w: float) -> String:
	var f: Font = Dados.fonte_texto
	if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x <= w:
		return s
	while s.length() > 1 and f.get_string_size(s + ".", HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x > w:
		s = s.substr(0, s.length() - 1)
	return s + "."


## Um nome da Jersey 10 que cabe em `w` px no tamanho `tam`: se não cabe, corta e termina em "." (como `_cabe`, na fonte de texto).
func _cabe_nome(s: String, w: float, tam: int) -> String:
	var f: Font = Dados.fonte_titulo
	if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= w:
		return s
	while s.length() > 1 and f.get_string_size(s + ".", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > w:
		s = s.substr(0, s.length() - 1)
	return s + "."


func _larg_trechos(trechos: Array) -> float:
	var larg := 0.0
	for tr in trechos:
		larg += _larg_trecho(tr)
	return larg


## As linhas completas de números de um bloco, quebradas conforme a largura disponível.
func _linhas_do_bloco(l: Dictionary, w: float) -> Array:
	return _linhas_trechos(l.trechos, w)


## Quebra os trechos de uma linha de números em linhas que cabem em `w`: [[ [texto, estilo], ... ], ...].
func _linhas_trechos(trechos: Array, w: float) -> Array:
	var linhas: Array = [[]]
	var x := 0.0
	for tr in trechos:
		var estilo: int = int(tr[1])
		for palavra in _re_palavras.search_all(str(tr[0])):
			var texto: String = palavra.get_string()
			var largura := _larg_trecho([texto, estilo])
			if x + largura > w and x > 0.0:
				linhas.append([])
				x = 0.0
			if largura <= w:
				linhas[linhas.size() - 1].append([texto, estilo])
				x += largura
				continue
			# Só uma palavra maior que a coluna pode ser dividida entre caracteres.
			var parte := ""
			for ch in texto:
				if parte != "" and _larg_trecho([parte + ch, estilo]) > w:
					linhas[linhas.size() - 1].append([parte, estilo])
					linhas.append([])
					parte = ""
				parte += ch
			if parte != "":
				linhas[linhas.size() - 1].append([parte, estilo])
				x = _larg_trecho([parte, estilo])
	return linhas


func _alt_dica(dica: String, w: float) -> float:
	return ALT_LINHA * float(_linhas_dica(dica, w).size()) + 1.0


## As linhas completas da dica (um parágrafo por evolução), quebradas em `w`.
func _linhas_dica(dica: String, w: float) -> Array:
	var r: Array = []
	for paragrafo in dica.split("\n", false):
		r.append_array(_quebrar(str(paragrafo), TAM_P, w))
	return r


## Quebra um texto em linhas que cabem em `w` (pelas palavras, medindo com a fonte mista). Uma palavra mais larga que `w` fica sozinha numa linha.
func _quebrar(s: String, tam: int, w: float) -> Array:
	var linhas: Array = []
	var atual := ""
	for palavra in s.split(" ", false):
		var teste: String = palavra if atual == "" else atual + " " + palavra
		if atual != "" and _larg_misto(teste, tam) > w:
			linhas.append(atual)
			atual = palavra
		else:
			atual = teste
	if atual != "":
		linhas.append(atual)
	return linhas


# ---- texto: a Spleen para as palavras e a Press Start 2P para os números


## Parte `s` em pedaços: [[texto, é_número], ...]. Número = sinal, dígitos, decimais e % (os números do card vão na fonte do HUD).
func _partes(s: String) -> Array:
	var r: Array = []
	var i := 0
	for m in _re.search_all(s):
		if m.get_start() > i:
			r.append([s.substr(i, m.get_start() - i), false])
		r.append([m.get_string(), true])
		i = m.get_end()
	if i < s.length():
		r.append([s.substr(i), false])
	return r


func _larg_misto(s: String, tam: int) -> float:
	var larg := 0.0
	for p in _partes(s):
		if p[1]:
			larg += _f_num.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUM).x
		else:
			larg += Dados.fonte_texto.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	return larg


## Desenha `s` com o canto de cima da linha em (x, y); com `a_direita`, `x` é onde o texto TERMINA. As palavras em `cor_txt`, os números em `cor_num`.
func _misto(s: String, x: float, y: float, tam: int, cor_txt: Color, cor_num: Color, a_direita := false) -> void:
	var xx := x - _larg_misto(s, tam) if a_direita else x
	var base := y + Dados.fonte_texto.get_ascent(tam)
	for p in _partes(s):
		if p[1]:
			_tela.draw_string(_f_num, Vector2(xx, base), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUM, cor_num)
			xx += _f_num.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUM).x
		else:
			_tela.draw_string(Dados.fonte_texto, Vector2(xx, base), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor_txt)
			xx += Dados.fonte_texto.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


## Texto simples na Spleen (sem números): `pos` é o canto de cima da linha (o desenho pede a linha de base).
func _texto(f: Font, s: String, pos: Vector2, w: float, alin: HorizontalAlignment, tam: int, cor: Color) -> void:
	_tela.draw_string(f, Vector2(pos.x, pos.y + f.get_ascent(tam)), s, alin, w, tam, cor)


func _texto_titulo(s: String, pos: Vector2, cor: Color) -> void:
	var f: Font = Dados.fonte_titulo
	_tela.draw_string(f, Vector2(pos.x, pos.y + f.get_ascent(TAM_CAB)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_CAB, cor)
