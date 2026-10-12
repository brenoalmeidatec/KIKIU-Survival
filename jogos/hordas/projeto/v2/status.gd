extends CanvasLayer
## Card "SUA BUILD" da v2: tudo o que a build faz, em números. Duas partes:
##  1. `Status.coletar(mundo)` (estática, sem desenhar nada, testável) devolve as SEÇÕES do card em dados simples. Os números são os REAIS do
##     jogo: cada um vem do getter do módulo que o usa (heroi.vel_andar, combate.dano_do_passo, armas.numeros, progresso.cura_por_nivel...),
##     nunca de uma fórmula copiada aqui. Cada linha tem `id`, `rotulo`, `valor` (o texto), `bonus` (o que passa da base, em outra cor) e `n`
##     (os números crus, em ordem; é o que o teste v2_status compara com o que o jogo FAZ).
##  2. O desenho, em TRÊS modos (`_modo()`), todos com a moldura de pedra do HUD (hud/moldura_pedra.png). Títulos na Jersey 10, texto na
##     Spleen 8x16 (`Dados.fonte_texto`) e NÚMEROS na Press Start 2P (a fonte do HUD). ATENÇÃO: o texto sai na Spleen em 11 e 12 px, FORA da grade de
##     16 px que a regra das fontes do v2/LEIA-ME.md pede (o card é denso: em 16 px as colunas não cabem). Fica legível nos prints, mas é pendência
##     (a Spleen 6x12, da mesma família, seria o tamanho certo). Tudo é desenhado num Control só (draw_*): nenhum nó por linha, nenhum nó criado ao atualizar.
## Onde aparece:
##  - "pausa": na tela "menu" da pausa, duas colunas ladeiam o menu (pausa.gd chama `na_pausa(true/false)`), por cima da pausa (camada 15).
##    Layout COMPLETO (nomes por extenso, duas linhas de números por golpe e as dicas de evolução);
##  - "hud": na partida, a tecla C liga e desliga um card COMPACTO (camada 8: abaixo do HUD). Semitransparente, não pega o mouse, atualiza a
##    4 Hz e só enquanto está visível. A coluna da esquerda fica sob a vida e o fôlego e a da direita sob o minimapa, as duas fora das faixas
##    do HUD (barra do chefe, anúncios, combo, XP): o centro, onde o herói luta, fica livre. No compacto cada golpe e cada modificador cabe
##    numa linha (ícone, nome curto, nível e número), sem dicas, e a build máxima cabe sem cortar nada (o teste prova);
##  - "central": sobre a escolha de cartas e o baú o C abre um painel no centro, em três colunas e no layout completo, com o fundo opaco: ele
##    ESCONDE as cartas (nada pela metade). Enquanto está aberto, clique e tecla não escolhem carta (a trava de 3 s das cartas segue correndo
##    em tempo real); o ESC abre a pausa como sempre. Com o painel fechado o card do HUD sai de cena nessas telas (ele cobriria a 1ª e a 3ª carta).
## A entrada é `entrada(evento)`, chamada pelo mundo.gd (o SubViewport não recebe a entrada da janela, então este nó não tem _input).
## Criado pelo mundo.gd (uma linha no _ready), que guarda em `mundo.status`.

const Meta := preload("res://v2/meta.gd")
const Pausa := preload("res://v2/pausa.gd")
const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
const LAYER_HUD := 8
const LAYER_CENTRAL := 13  # acima do HUD (10), do resultado (12) e das cartas (5); abaixo do menu de pausa (14)
const LAYER_PAUSA := 15  # acima do menu de pausa (camada 14) e do escurecimento dele
const PERIODO := 0.25  # 4 Hz
const ALFA_HUD := 0.92
const TAM := 12  # texto (Spleen 8x16 escalada: ver a ATENÇÃO do cabeçalho)
const TAM_NUM := 8  # números (Press Start 2P, a grade de 8 px do HUD)
const TAM_P := 11  # linhas de apoio
const TAM_CAB := 19  # títulos e cabeçalhos (Jersey 10; 19 é a grade da fonte)
const TAM_NOME_PEQ := 14  # nome de golpe que não cabe no 19 (só quando precisa)
const ALT_LINHA := 13.0
const ALT_CAB := 18.0
const ALT_TITULO := 22.0
const ALT_BLOCO_COMPACTO := 18.0  # ícone de 16 px e 2 de respiro: um golpe ou modificador por linha no HUD
const PAD := 8.0
const ICONE := 16.0
const TELA := Rect2(0, 0, 960, 540)
const JOGO_VIVO := ["jogando", "escolha", "bau"]  # estados do combate em que o C vale
const JOGO_CARTAS := ["escolha", "bau"]  # as telas de cartas: aí o C abre o painel central
## Colunas de cada modo: x, y, largura e altura máxima. HUD: a da esquerda sob a vida e o fôlego (y 40) e fora da barra do chefe (x até 190);
## a da direita sob o minimapa (que acaba em y 112) e fora da barra do chefe e dos anúncios (x a partir de 772). Pausa: colada nos dois lados
## do painel do menu (`Pausa.PAINEL`, x 260 a 700). Central: três colunas lado a lado, a tela toda é do painel.
const COLUNAS_HUD := [Rect2(6, 40, 184, 466), Rect2(772, 118, 182, 388)]
const COLUNAS_PAUSA := [
	Rect2(8, 14, Pausa.PAINEL.position.x - 16.0, 512),
	Rect2(Pausa.PAINEL.position.x + Pausa.PAINEL.size.x + 8.0, 14, 944.0 - Pausa.PAINEL.position.x - Pausa.PAINEL.size.x, 512)
]  # coladas nos dois lados do painel do menu (`Pausa.PAINEL`)
const COLUNAS_CENTRAL := [Rect2(14, 14, 296, 512), Rect2(332, 14, 296, 512), Rect2(650, 14, 296, 512)]
const SECOES_DUAS := [["heroi", "partida", "santuario"], ["katana", "golpes"]]
const SECOES_TRES := [["heroi", "partida", "santuario"], ["katana"], ["golpes"]]
const COR_FUNDO_OPACO := Color(0.004, 0.012, 0.043, 1.0)  # o painel #01030b: por baixo da moldura (translúcida) quando o card tem de ser lido sem ver o que está atrás
const COR_TITULO := Color(1.0, 0.86, 0.42)
const COR_ROTULO := Color(0.72, 0.7, 0.83)
const COR_VALOR := Color(1.0, 0.93, 0.66)
const COR_BONUS := Color(0.55, 0.95, 0.62)
const COR_SANTUARIO := Color(0.82, 0.68, 1.0)
const COR_DICA := Color(0.6, 0.8, 0.98)
const COR_LINHA := Color(0.55, 0.53, 0.68, 0.5)
## Estilo de um trecho de texto (veja `_bloco`): 0 = apoio, 1 = número em destaque, 2 = bônus.
const CORES_TRECHO := [COR_ROTULO, COR_VALOR, COR_BONUS]

var mundo
var secoes: Array = []  # o último `coletar` (os testes leem)
var atualizacoes := 0  # quantas vezes recoletou (os testes conferem que escondido não atualiza)
var _hud := false  # o jogador ligou o card compacto com C (durante a partida)
var _central := false  # o jogador abriu o painel central com C (sobre a escolha de cartas ou o baú)
var _pausa := false  # a pausa pediu o card ao lado do menu
var _modo_atual := ""  # o modo que está na tela agora ("" = escondido)
var _m := "hud"  # o modo em que `_medir`, `_coluna` e o desenho trabalham agora
var _meta: Dictionary = {}  # níveis do Santuário, lidos uma vez quando o card abre (o save não muda durante a partida)
var _tela: Control
var _estilo: StyleBoxTexture
var _f_num: Font  # Press Start 2P sem anti-aliasing (como o HUD)
var _re := RegEx.create_from_string("[+\\-]?[0-9]+(?:[,.][0-9]+)?%?")  # um número: sinal, dígitos, decimais e % (vão na fonte dos números)
var _timer: Timer  # o relógio de 4 Hz: só corre com o card ligado (sem _process, nada roda por quadro)
var _sem_dicas := false  # a coluna estourou a altura: as dicas de evolução saem primeiro
var _cortou := false  # mesmo sem as dicas não coube: o que sobrou fica de fora, marcado com "..."
var _sobrou: Array = [false, false, false]  # por coluna: o conteúdo passou da altura mesmo sem as dicas (os testes conferem que é tudo false)


## Cria o card ligado ao mundo. É o que o mundo.gd chama (e guarda em `mundo.status`).
static func criar(m) -> CanvasLayer:
	var s := new()
	s.mundo = m
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # a pausa e a escolha de cartas param o mundo; o card segue atualizando
	layer = LAYER_HUD
	_estilo = StyleBoxTexture.new()
	_estilo.texture = MOLDURA
	_estilo.texture_margin_left = 5
	_estilo.texture_margin_top = 5
	_estilo.texture_margin_right = 5
	_estilo.texture_margin_bottom = 5
	_estilo.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_estilo.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
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


# ------------------------------------------------------------------ ligar e desligar


## C: liga e desliga o card compacto (ou o painel central, sobre as cartas). Devolve true se usou o evento (o mundo.gd o passa antes da
## escolha de cartas e do baú, que comem as teclas). Com o painel central aberto o card engole TODA a entrada, menos o ESC (que é da pausa):
## nenhum clique, tecla ou botão chega às cartas escondidas.
func entrada(e: InputEvent) -> bool:
	if _modo_atual == "central" and not _sobre_cartas():
		_aplicar()  # as cartas fecharam por outro caminho: o painel sai antes de engolir a entrada
	if _modo_atual == "central":
		if e is InputEventKey:
			if e.keycode == KEY_ESCAPE:
				return false
			if e.keycode == KEY_C and e.pressed and not e.echo and not (e.ctrl_pressed or e.alt_pressed or e.meta_pressed):
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


## O C vale com a partida de pé, na escolha de cartas e no baú; não vale com a pausa aberta (ela mostra o card dela) nem no fim da partida.
func pode_alternar() -> bool:
	return mundo != null and mundo.combate != null and not _pausa and str(mundo.combate.jogo) in JOGO_VIVO and not get_tree().paused


## Liga ou desliga: o painel central sobre as cartas, o card compacto no resto da partida.
func alternar() -> void:
	if _sobre_cartas():
		_central = not _central
	else:
		_hud = not _hud
	_aplicar()


## O card está na tela agora (HUD ligado pelo C, painel central, ou ao lado do menu de pausa).
func aberto() -> bool:
	return visible


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
	_modo_atual = _modo()
	visible = _modo_atual != ""
	if _hud or _central or _pausa:
		if _timer.is_stopped():
			_timer.start()
	else:
		_timer.stop()
	if not visible:
		return
	_m = _modo_atual
	layer = LAYER_PAUSA if _m == "pausa" else (LAYER_CENTRAL if _m == "central" else LAYER_HUD)
	_meta = Meta.estado().get("niveis", {})
	_recoletar()


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


static func _sec_heroi(m) -> Dictionary:
	var h = m.heroi
	var c = m.combate
	var cfg: Dictionary = c.cfg
	var cura: float = c.progresso.cura_por_nivel()
	var frac := float(cfg.heroi.cura_nivel) * 100.0
	var seguidas := int(floorf(h.folego_max / float(cfg.esquiva.gasto)))
	var rp := float(cfg.folego.regen_parado)
	var ra := float(cfg.folego.regen_andando)
	var lin: Array = []
	lin.append(_l("heroi.vida", "Vida", "%d / %d" % [roundi(h.vida), roundi(h.vida_max)], [h.vida, h.vida_max], _mais(h.vida_max - float(cfg.heroi.vida))))
	lin.append(_l("heroi.cura", "Cura por nível", "+%d (%s%%)" % [roundi(cura), _p(frac)], [cura, frac]))
	lin.append(_l("heroi.andar", "Andar", "%d px/s" % roundi(h.vel_andar()), [h.vel_andar()], _mais_pct((h.m_vel_mov - 1.0) * 100.0)))
	lin.append(_l("heroi.correr", "Correr", "%d px/s" % roundi(h.vel_correr()), [h.vel_correr()]))
	lin.append(_l("heroi.folego", "Fôlego", "%s cargas" % _v(h.folego_max, 1), [h.folego_max], _mais(h.folego_max - float(cfg.folego.max), 1)))
	# o fôlego volta à taxa rápida só com o herói livre E parado; andando ou golpeando (o golpe tira o herói do estado livre) vale a lenta
	lin.append(_l("heroi.recupera", "Recupera parado", "%s/s" % _v(rp, 1), [rp]))
	lin.append(_l("heroi.recupera_andando", "Recupera em ação", "%s/s" % _v(ra, 1), [ra]))
	lin.append(_l("heroi.ima", "Ímã de almas", "%d px" % roundi(h.alcance_ima()), [h.alcance_ima()], _mais_pct((h.m_ima - 1.0) * 100.0)))
	lin.append(_l("heroi.nivel", "Nível", "%d · XP %d/%d" % [h.nivel, roundi(h.xp), roundi(h.xp_proximo)], [h.nivel, h.xp, h.xp_proximo], "", true))
	lin.append(_l("heroi.esquiva", "Esquiva", "%d seguidas" % seguidas, [seguidas, h.esq_dur]))
	lin.append(_l("heroi.imune", "Imune na esquiva", "%s s" % _v(h.esq_inv, 2), [h.esq_inv]))
	return _sec("heroi", "HERÓI", Color(1.0, 0.6, 0.55), lin)


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
	lin.append(_l("katana.combo", "Combo completo", "%s s" % _v(ciclo, 2), [ciclo]))
	lin.append(_l("katana.alcance", "Alcance", "/".join(t_alc) + " px", alcances))
	lin.append(_l("katana.area", "Área do corte", _mais_pct((h.m_area - 1.0) * 100.0) if h.m_area != 1.0 else "base", [h.m_area]))
	lin.append(_l("katana.critico", "Crítico x%s" % _v(mult, 1), "%s%%" % _p(chance * 100.0), [chance, mult], _mais_pct(h.m_critico * 100.0)))
	var cs = c.cartas
	var ar = c.armas
	for md in ["onda", "fura", "explode", "folego"]:
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
				Color(0.8, 0.95, 1.0),
				nivel_txt,
				nivel_curto,
				tr,
				curto,
				uma,
				_dica_evolucao(cs, str(md)),
				n
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
				[float(ev.mult_onda)]
			)
		)
	return _sec("katana", "KATANA (CLIQUE)", Color(1.0, 0.78, 0.45), lin)


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
				[nums.dano, nums.intervalo, nums.dps, nums.acertos]
			)
		)
	if lin.is_empty():
		lin.append({"tipo": "texto", "id": "arma.nenhum", "texto": "Nenhum ainda: eles vêm das cartas.", "estilo": 0, "n": []})
	return _sec("golpes", "GOLPES AUTOMÁTICOS", Color(0.6, 0.8, 1.0), lin)


## Os danos de uma lista, arredondados como o jogo os aplica e separados por "/" ("8/9"); repetidos em seguida viram um número só.
static func _lista_dano(danos: Array) -> String:
	var t: Array = []
	for d in danos:
		var r := str(maxi(1, roundi(float(d))))
		if t.is_empty() or t[t.size() - 1] != r:
			t.append(r)
	return "/".join(t)


## "Evolui: Anel de Brasas (falta Lâminas Rodopiantes nv 3)", ou, se uma peça não chega mais lá (banida, ou já gasta em outra evolução),
## "Evolução perdida (Anel de Brasas: Lâminas Rodopiantes banida)", ou "".
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
	n: Array
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
		"n": n
	}


static func _sec_partida(m) -> Dictionary:
	var c = m.combate
	var cs = c.cartas
	var falta_onda: float = maxf(0.0, c.diretor.proxima_onda - m.tempo_partida)
	# as almas que o fim da partida credita de fato: as coletadas mais o bônus "Almas abundantes" do Santuário (a conta de Meta.registrar_partida)
	var bruto: int = m.almas_partida
	var bonus_almas := float(m.meta_bonus.get("almas", 0.0)) if m.meta_bonus is Dictionary else 0.0
	var creditadas: int = Meta.almas_creditadas(bruto, bonus_almas)
	var lin: Array = []
	lin.append(_l("partida.tempo", "Tempo", _tempo(m.tempo_partida), [m.tempo_partida], "", true))
	lin.append(_l("partida.abates", "Abates", str(m.abates), [m.abates], "", true))
	lin.append(_l("partida.combo", "Combo", "x%d · maior x%d" % [m.combo, m.maior_combo], [m.combo, m.maior_combo], "", true))
	lin.append(_l("partida.almas", "Almas a receber", str(creditadas), [bruto, creditadas], _mais(float(creditadas - bruto))))
	lin.append(
		_l(
			"partida.rerrolar",
			"Rerrolar / banir",
			"%d / %d" % [cs.rerrolares_restantes(), cs.banimentos_restantes()],
			[cs.rerrolares_restantes(), cs.banimentos_restantes()]
		)
	)
	lin.append(_l("partida.onda", "Onda forte", str(c.diretor.ondas), [c.diretor.ondas]))
	lin.append(_l("partida.proxima", "Próxima onda", "em %d s" % ceili(falta_onda), [falta_onda]))
	return _sec("partida", "PARTIDA", Color(0.6, 0.95, 0.85), lin)


static func _sec_santuario(_m, meta_niveis: Variant) -> Dictionary:
	var niveis: Dictionary = meta_niveis if meta_niveis is Dictionary else Meta.estado().get("niveis", {})
	var lin: Array = []
	for md in Meta.melhorias_visiveis():
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
	var rects: Array = _colunas()
	var opaco: bool = _m != "hud"  # na pausa e no painel central: sem ver o que está atrás
	if _m == "central":
		_tela.draw_rect(TELA, COR_FUNDO_OPACO)  # o painel central cobre a tela toda: as cartas (camada 5) e o HUD ficam escondidos
	for c in rects.size():
		var r := _medir(c)  # também decide se as dicas de evolução cabem (_sem_dicas)
		if opaco:
			_tela.draw_rect(r, COR_FUNDO_OPACO)
		_tela.draw_style_box(_estilo, r)
		_coluna(c, rects[c], false)


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


## Por coluna: true se o conteúdo NÃO coube na altura da coluna, mesmo sem as dicas de evolução (o que sobra é cortado com "..."). Os testes
## conferem que nunca acontece, nem com a build máxima, nem com o Santuário todo comprado.
func colunas_cortadas() -> Array:
	_m = _modo_de_medida()
	var r: Array = []
	for c in _colunas().size():
		_medir(c)
		r.append(bool(_sobrou[c]))
	return r


func _medir(c: int) -> Rect2:
	var r: Rect2 = _colunas()[c]
	_sem_dicas = false
	var alt := _coluna(c, r, true)
	if alt > r.size.y and _m != "hud":  # não coube: as dicas de evolução saem primeiro (o HUD compacto não tem dicas)
		_sem_dicas = true
		alt = _coluna(c, r, true)
	_sobrou[c] = alt > r.size.y
	return Rect2(r.position, Vector2(r.size.x, minf(alt, r.size.y)))


## Os ids das linhas cujo texto não cabe na largura da coluna (rótulo, valor e bônus juntos; nome, nível e número do golpe; mais de 2 linhas
## de números; palavra solta mais larga que a coluna; mais de 2 linhas de texto). Vazio = tudo cabe. Os testes conferem isto em todos os modos.
func linhas_que_estouram() -> Array:
	_m = _modo_de_medida()
	var r: Array = []
	var rects: Array = _colunas()
	var grupos: Array = _secoes_das_colunas()
	for c in rects.size():
		var w: float = (rects[c] as Rect2).size.x - 2.0 * PAD
		for id in grupos[c]:
			for l in _achar(str(id)).get("linhas", []):
				if _estoura(l, w):
					r.append(str(l.id))
	return r


func _estoura(l: Dictionary, w: float) -> bool:
	var f: Font = Dados.fonte_texto
	match str(l.tipo):
		"linha":  # o bônus (o verde à direita) é opcional: sem espaço ele sai (veja `_desenhar_linha`); o rótulo e o valor têm de caber
			return f.get_string_size(str(l.rotulo), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x + 8.0 + _larg_misto(str(l.valor), TAM) > w
		"texto":
			var tam := TAM_P if int(l.estilo) == 3 else TAM
			if _quebrar(str(l.texto), tam, w).size() > 2:
				return true
			for palavra in str(l.texto).split(" ", false):
				if _larg_misto(palavra, tam) > w:
					return true
			return false
		"bloco":
			var wt := w - ICONE - 4.0
			if _m == "hud":
				return _larg_bloco_compacto(l) > wt
			var nome_w := Dados.fonte_titulo.get_string_size(str(l.rotulo), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NOME_PEQ).x
			return nome_w + _larg_misto(str(l.nivel_curto), TAM_P) + 8.0 > wt or _linhas_do_bloco(l, wt).size() > 2
	return false


## A largura de um bloco na linha única do HUD com o nome curto no tamanho `tam`: nome, nível e número, com os respiros.
func _larg_bloco_compacto(l: Dictionary, tam := TAM_NOME_PEQ) -> float:
	var nome_w := Dados.fonte_titulo.get_string_size(str(l.nome_curto), HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	return nome_w + 6.0 + _larg_misto(str(l.nivel_curto), TAM_P) + 6.0 + _larg_trechos(l.uma)


## Desenha (ou só mede, com `seco`) a coluna `c` dentro de `r`. Devolve a altura que o conteúdo pede, com a moldura.
func _coluna(c: int, r: Rect2, seco: bool) -> float:
	var x := r.position.x + PAD
	var w := r.size.x - 2.0 * PAD
	var y := r.position.y + PAD - 2.0
	var limite := r.end.y - PAD
	_cortou = false
	if c == 0:
		if not seco:
			_texto_titulo("SUA BUILD", Vector2(x, y), COR_TITULO)
			if _m != "pausa":  # o C não faz nada com o menu aberto
				_tela.draw_string(_f_num, Vector2(x, y + 6.0 + _f_num.get_ascent(TAM_NUM)), "[C] fecha", HORIZONTAL_ALIGNMENT_RIGHT, w, TAM_NUM, COR_ROTULO)
		y += ALT_TITULO
	for id in _secoes_das_colunas()[c]:
		var sec := _achar(str(id))
		if sec.is_empty() or _cortou:
			continue
		y = _secao(sec, x, y + 3.0, w, seco, limite)
	if _cortou and not seco:
		_texto(Dados.fonte_texto, "...", Vector2(x, limite - ALT_LINHA + 2.0), w, HORIZONTAL_ALIGNMENT_CENTER, TAM, COR_ROTULO)
	return y - r.position.y + PAD - 2.0


func _achar(id: String) -> Dictionary:
	for s in secoes:
		if str(s.id) == id:
			return s
	return {}


func _secao(sec: Dictionary, x: float, y: float, w: float, seco: bool, limite: float) -> float:
	if y + ALT_CAB + ALT_LINHA > limite and not seco:
		_cortou = true
		return y
	if not seco:
		_texto_titulo(str(sec.titulo), Vector2(x, y - 1.0), sec.cor)
		_tela.draw_line(Vector2(x, y + ALT_CAB - 1.0), Vector2(x + w, y + ALT_CAB - 1.0), COR_LINHA, 1.0)
	y += ALT_CAB + 2.0
	for l in sec.linhas:
		if _m == "hud" and bool(l.get("so_cheio", false)):
			continue
		var alt := _altura(l, w)
		if y + alt > limite and not seco:
			_cortou = true  # sem espaço: o que sobrou fica de fora (a coluna avisa com "...")
			return y
		if not seco:
			_item(l, x, y, w)
		y += alt
	return y


func _altura(l: Dictionary, w: float) -> float:
	match str(l.tipo):
		"bloco":
			if _m == "hud":
				return ALT_BLOCO_COMPACTO
			var wt := w - ICONE - 4.0
			var alt := ICONE + 1.0 + 12.0 * float(_linhas_do_bloco(l, wt).size())
			if str(l.dica) != "" and not _sem_dicas:
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
	var direita := x + w
	var bonus := str(l.bonus)
	# o bônus só entra se couber ao lado do rótulo e do valor (numa build extrema o valor já enche a coluna: fica o que importa)
	if (
		bonus != ""
		and f.get_string_size(str(l.rotulo), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x + 8.0 + _larg_misto(str(l.valor), TAM) + _larg_misto(bonus, TAM) + 5.0 <= w
	):
		_misto(bonus, direita, y, TAM, COR_BONUS, COR_BONUS, true)
		direita -= _larg_misto(bonus, TAM) + 5.0
	_texto(f, str(l.rotulo), Vector2(x, y), w, HORIZONTAL_ALIGNMENT_LEFT, TAM, COR_ROTULO)
	_misto(str(l.valor), direita, y, TAM, COR_ROTULO, COR_VALOR, true)


func _desenhar_icone(l: Dictionary, x: float, y: float) -> void:
	var ic := str(l.icone)
	if ic != "":
		var tx: Texture2D = Dados.tex(ic)
		if tx != null:
			_tela.draw_texture(tx, Vector2(x, y))


## Um golpe ou modificador numa linha só (HUD): ícone, nome curto, nível e o número (poder estimado, ou o valor do modificador).
func _desenhar_bloco_compacto(l: Dictionary, x: float, y: float, w: float) -> void:
	var ft: Font = Dados.fonte_titulo
	_desenhar_icone(l, x, y)
	var xt := x + ICONE + 4.0
	var fim := x + w
	var cor: Color = Color(l.cor).lerp(Color.WHITE, 0.35)
	var larg_uma := _larg_trechos(l.uma)
	var xx := fim - larg_uma
	var xs := xx
	for tr in l.uma:
		xs += _desenhar_trecho(tr, xs, y + 4.0)
	var nivel := str(l.nivel_curto)
	_misto(nivel, xx - 6.0, y + 3.0, TAM_P, COR_ROTULO, COR_ROTULO, true)
	# o nome na grade da Jersey 10 (19) quando cabe; se não, um degrau abaixo (a Jersey fora da grade sai borrada, então só quando precisa)
	var tam_nome := TAM_CAB if _larg_bloco_compacto(l, TAM_CAB) <= w - ICONE - 4.0 else TAM_NOME_PEQ
	_tela.draw_string(ft, Vector2(xt, y - 1.0 + ft.get_ascent(TAM_CAB)), str(l.nome_curto), HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nome, cor)


func _desenhar_bloco(l: Dictionary, x: float, y: float, w: float) -> void:
	var ft: Font = Dados.fonte_titulo
	_desenhar_icone(l, x, y)
	var xt := x + ICONE + 4.0
	var wt := w - ICONE - 4.0
	var cor: Color = Color(l.cor).lerp(Color.WHITE, 0.35)
	# o nome na Jersey 10 (19) com o nível por extenso (na pausa); no HUD o nível é curto; se o nome e o nível não cabem, o nome encolhe um degrau
	var nome := str(l.rotulo)
	var nivel := str(l.nivel_txt)
	var tam_nome := TAM_CAB
	if wt < 200.0:  # coluna estreita: o nível sempre curto ("2/5"), igual em todos os golpes
		nivel = str(l.nivel_curto)
	if ft.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nome).x + _larg_misto(nivel, TAM_P) + 8.0 > wt:
		nivel = str(l.nivel_curto)
	if ft.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nome).x + _larg_misto(nivel, TAM_P) + 8.0 > wt:
		tam_nome = TAM_NOME_PEQ
	_tela.draw_string(ft, Vector2(xt, y - 1.0 + ft.get_ascent(TAM_CAB)), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nome, cor)
	_misto(nivel, xt + wt, y + 1.0, TAM_P, COR_ROTULO, COR_ROTULO, true)
	var yy := y + ICONE + 1.0
	for linha_t in _linhas_do_bloco(l, wt):
		var xx := xt
		for tr in linha_t:
			xx += _desenhar_trecho(tr, xx, yy)
		yy += 12.0
	if str(l.dica) != "" and not _sem_dicas:
		for linha_d in _linhas_dica(str(l.dica), wt):  # os números da dica na fonte dos números (a fonte de texto pequena confunde dígitos)
			_misto(str(linha_d), xt, yy, TAM_P, COR_DICA, COR_DICA)
			yy += 12.0


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


func _larg_trechos(trechos: Array) -> float:
	var larg := 0.0
	for tr in trechos:
		larg += _larg_trecho(tr)
	return larg


## As linhas de números de um bloco: a versão completa se cabe numa linha só, senão a abreviada (quebrada, se preciso).
func _linhas_do_bloco(l: Dictionary, w: float) -> Array:
	var cheia := _linhas_trechos(l.trechos, w)
	if cheia.size() == 1:
		return cheia
	return _linhas_trechos(l.curto, w)


## Quebra os trechos de uma linha de números em linhas que cabem em `w`: [[ [texto, estilo], ... ], ...].
func _linhas_trechos(trechos: Array, w: float) -> Array:
	var linhas: Array = [[]]
	var x := 0.0
	for tr in trechos:
		var t: Array = tr
		var lt := _larg_trecho(t)
		if x + lt > w and x > 0.0:
			linhas.append([])
			x = 0.0
			t = [str(t[0]).strip_edges(true, false), t[1]]  # a linha nova não começa com espaço
			lt = _larg_trecho(t)
		linhas[linhas.size() - 1].append(t)
		x += lt
	return linhas


func _alt_dica(dica: String, w: float) -> float:
	return 12.0 * float(_linhas_dica(dica, w).size()) + 1.0


## As linhas da dica (um parágrafo por evolução), quebradas em `w`, no máximo 3.
func _linhas_dica(dica: String, w: float) -> Array:
	var r: Array = []
	for paragrafo in dica.split("\n", false):
		r.append_array(_quebrar(str(paragrafo), TAM_P, w))
	return r.slice(0, 3)


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
