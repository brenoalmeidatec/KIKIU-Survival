extends RefCounted
## Telas simples do combate da v2 (o HUD bonito é de outro módulo): a escolha de cartas ao subir de nível (3 cartas com cor e brilho pela
## RARIDADE, mais rerrolar e banir), a roleta do baú, a tela de resultado (VOCÊ CAIU ou VITÓRIA, com as almas ganhas), os anúncios grandes
## e um texto de DEPURAÇÃO com vida, nível, XP, combo e abates (DESLIGADO por padrão agora que o HUD existe: ligue com --depur ou F1). Tudo é desenhado numa CanvasLayer dentro
## do SubViewport 960x540; o mouse não chega nos Controls de dentro dele, então o clique é lido por aqui (mundo.ap.mouse_na_tela()) e a
## escolha também aceita 1, 2, 3, setas, Enter, R (rerrolar) e B (banir a carta marcada).
## TRAVA: a escolha abre com as cartas apagadas por 3 s de TEMPO REAL (0,8 s depois de rerrolar ou banir). Nesse tempo clique, tecla e
## botão são descartados (a contagem pulsa) e nada chega ao herói; ESC passa, é da pausa. O baú tem a sua trava (bau_espera_s). Os tempos
## vêm de dados/v2_cartas.json e a contagem corre no `atualizar` (relógio de parede), congelada com a pausa aberta (mundo.pausa.aberto).
## Os anúncios grandes e a barra do chefe são do HUD (v2/hud_anuncios.gd e hud.gd), que escutam os sinais do mundo.

const Paleta := preload("res://v2/paleta.gd")
const LARG := 960
const ALT := 540
const CARTA_L := 256.0
const CARTA_A := 288.0
const CARTA_Y := 146.0
const FOLGA := 20.0
const BTN_Y := 440.0
const MARGEM := 12.0  # margem interna do cartão, igual nos dois lados
const ICONE := 32.0  # o ícone da v1 tem 16x16: aqui sai em 2x, pixel a pixel
const TAM_TITULO := 56  # múltiplo de 3 px da grade da Jersey 10 (sem meio pixel)
const TAM_NOME := 37  # múltiplo de 2 px da grade da Jersey 10 (cabe em uma linha na maioria dos nomes)
const TAM_NOME_CURTO := 28  # nomes longos (Lâminas Rodopiantes) que não cabem em TAM_NOME
const TAM_TEXTO := 16  # grade da Spleen 8x16 (só 16 ou 32): o 5 e o S, o 0 e o O não se confundem
const TAM_CONTAGEM := 19  # a contagem da trava usa a Jersey 10 na grade de 19 px (como os botões)
const PULSO_T := 0.2  # s da pulsada da contagem quando um clique ou tecla cai na trava
const ACENDER_T := 0.35  # s do brilho quando as cartas liberam

var combate
var mundo
var camada: CanvasLayer
var depuracao := true
var sel := 0
var mostrada_t := 0.0  # s desde que a tela de resultado abriu (ignora clique logo no começo)
var resultado_aberto := false
var escolha_aberta := false
var bau_aberto := false
var bau_pronto := false  # a roleta terminou de revelar tudo
var espera_escolha := 0.0  # s REAIS até as cartas aceitarem clique ou tecla (0 = liberadas)
var espera_bau := 0.0  # s REAIS até a roleta aceitar pular ou fechar (0 = liberada)
var mouse_fn := Callable()  # testes: posição do mouse na tela (960x540); sem ela, o mouse de verdade (mundo.ap)
var _espera_total := 0.0  # a trava que está correndo (base da barra de cada carta)
var _acender := 0.0  # s que faltam do brilho de liberação
var _pulso := 0.0  # s que faltam da pulsada da contagem

var _fundo: ColorRect
var _escolha: Control
var _cartas: Array[Control] = []
var _estilos: Array[StyleBoxFlat] = []
var _titulo: Label
var _sub: Label
var _btn_r: Panel
var _btn_b: Panel
var _btn_r_txt: Label
var _btn_b_txt: Label
var _build: Label
var _res: Control
var _res_titulo: Label
var _res_linhas: Label
var _res_valores: Label
var _res_dica: Label
var _dep: Label
var _dep_t := 0.0
var _fonte: Font  # texto corrido (Spleen 8x16, sempre em 16 px)
var _fonte_t: Font  # títulos e nomes (Jersey 10)
var _fonte_px: Font  # o texto de depuração segue na Press Start 2P
var _t_ui := 0.0
var _bau: Control
var _bau_titulo: Label
var _bau_slots: Array[Panel] = []
var _bau_estilos: Array[StyleBoxFlat] = []
var _bau_cartas: Array = []
var _bau_i := 0  # qual carta está girando
var _bau_t := 0.0
var _bau_fase := 0  # 0 = girando, 1 = pausa depois de revelar, 2 = tudo revelado
var _bau_tick := 0.0
var _bau_dica: Label


func montar(c, sv: Node) -> void:
	combate = c
	mundo = c.mundo
	_fonte = Dados.fonte_texto
	_fonte_t = Dados.fonte_titulo
	_fonte_px = Dados.fonte
	camada = CanvasLayer.new()
	camada.layer = 5
	sv.add_child(camada)
	_fundo = ColorRect.new()
	_fundo.color = Paleta.alfa(Paleta.PAINEL, 0.62)
	_fundo.size = Vector2(LARG, ALT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.visible = false
	camada.add_child(_fundo)
	_montar_escolha()
	_montar_bau()
	_montar_resultado()
	_dep = _rotulo("", 8, false, Paleta.TEXTO, HORIZONTAL_ALIGNMENT_LEFT)
	_dep.add_theme_font_override("font", _fonte_px)
	_dep.position = Vector2(6, 30)
	_dep.size = Vector2(500, 40)
	camada.add_child(_dep)
	depuracao = mundo.args.has("depur")  # o HUD (hud.gd) é o painel de verdade; este texto é só para depurar (--depur ou F1)
	_dep.visible = depuracao


func _rotulo(texto: String, tam: int, titulo: bool, cor: Color, alin: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", _fonte_t if titulo else _fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 4 if titulo else 2)
	l.horizontal_alignment = alin
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo(sel_: bool, cor: Color = Paleta.BORDA, rar := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Paleta.alfa(Paleta.CARTAO_SELECIONADO, 0.97) if sel_ else Paleta.alfa(Paleta.CARTAO, 0.96)
	s.bg_color = s.bg_color.lerp(cor, 0.1 + 0.05 * rar)
	s.border_color = cor.lerp(Color.WHITE, 0.45) if sel_ else cor
	s.set_border_width_all(2 + (1 if rar >= 2 else 0) + (1 if sel_ else 0))
	s.set_corner_radius_all(0)
	if rar > 0:  # o brilho em volta: mais forte quanto mais rara
		s.shadow_color = Color(cor.r, cor.g, cor.b, 0.18 + 0.12 * rar)
		s.shadow_size = 4 + 3 * rar
	return s


func _montar_escolha() -> void:
	_escolha = Control.new()
	_escolha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escolha.visible = false
	camada.add_child(_escolha)
	_titulo = _rotulo("", TAM_TITULO, true, Paleta.OURO, HORIZONTAL_ALIGNMENT_CENTER)
	_titulo.position = Vector2(0, 66)
	_titulo.size = Vector2(LARG, 64)
	_escolha.add_child(_titulo)
	_sub = _rotulo("Escolha uma carta", TAM_TEXTO, false, Paleta.TEXTO, HORIZONTAL_ALIGNMENT_CENTER)
	_sub.position = Vector2(0, 122)
	_sub.size = Vector2(LARG, 20)
	_escolha.add_child(_sub)
	var x0 := (LARG - (3.0 * CARTA_L + 2.0 * FOLGA)) * 0.5
	for i in 3:
		var p := Panel.new()
		p.position = Vector2(x0 + i * (CARTA_L + FOLGA), CARTA_Y)
		var st := _estilo(false)
		p.add_theme_stylebox_override("panel", st)
		_estilos.append(st)
		_montar_cartao(p, "[%d]" % (i + 1))
		var barra := ColorRect.new()  # a trava: enche de 0 à largura da carta (só aparece na trava)
		barra.name = "espera"
		barra.position = Vector2(MARGEM, CARTA_A - 6.0)
		barra.size = Vector2(0.0, 3.0)
		barra.color = Paleta.OURO
		barra.visible = false
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(barra)
		_escolha.add_child(p)
		_cartas.append(p)
	# rerrolar e banir
	_btn_r = _botao(Vector2(LARG * 0.5 - 254, BTN_Y), "r")
	_btn_b = _botao(Vector2(LARG * 0.5 + 14, BTN_Y), "b")
	_btn_r_txt = _btn_r.get_node("t")
	_btn_b_txt = _btn_b.get_node("t")
	_build = _rotulo("", TAM_TEXTO, false, Paleta.TEXTO_SECUNDARIO, HORIZONTAL_ALIGNMENT_CENTER)
	_build.position = Vector2(60, 472)
	_build.size = Vector2(LARG - 120, 36)
	_build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_escolha.add_child(_build)


## Um campo de texto do cartão (ou de qualquer tela de cartas): nó com nome, posição e tamanho dados.
func _campo(
	pai: Node, nome: String, tam: int, titulo: bool, cor: Color, alin: HorizontalAlignment, x: float, y: float, w: float, h: float, quebra := false
) -> Label:
	var l := _rotulo("", tam, titulo, cor, alin)
	l.name = nome
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pai.add_child(l)
	return l


## Monta o cartão vazio (a escolha e o baú usam o mesmo). Ordem fixa, de cima para baixo: tecla e raridade; faixa da cor da raridade;
## ícone numa moldura da cor da raridade; nome; descrição; o que o golpe ganha no próximo nível; no rodapé, nível e evolução.
## Todas as linhas são centradas (a tecla e a raridade ficam nas pontas do topo), com a mesma margem dos dois lados.
func _montar_cartao(p: Panel, tecla: String) -> void:
	p.size = Vector2(CARTA_L, CARTA_A)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var larg := CARTA_L - 2.0 * MARGEM
	_campo(p, "tecla", TAM_TEXTO, false, Paleta.TEXTO_SECUNDARIO, HORIZONTAL_ALIGNMENT_LEFT, MARGEM, 8, larg, 20).text = tecla
	_campo(p, "rar", TAM_TEXTO, false, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, MARGEM, 8, larg, 20)
	var faixa := ColorRect.new()
	faixa.name = "faixa"
	faixa.position = Vector2(MARGEM, 32)
	faixa.size = Vector2(larg, 3)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(faixa)
	var moldura := Panel.new()
	moldura.name = "moldura"
	moldura.position = Vector2((CARTA_L - ICONE) * 0.5 - 6.0, 40)
	moldura.size = Vector2(ICONE + 12.0, ICONE + 12.0)
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(moldura)
	var icone := TextureRect.new()
	icone.name = "icone"
	icone.position = Vector2((CARTA_L - ICONE) * 0.5, 46)
	icone.size = Vector2(ICONE, ICONE)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icone)
	_campo(p, "nome", TAM_NOME, true, Paleta.VALOR, HORIZONTAL_ALIGNMENT_CENTER, MARGEM, 86, larg, 40)
	_campo(p, "desc", TAM_TEXTO, false, Paleta.TEXTO, HORIZONTAL_ALIGNMENT_CENTER, MARGEM, 128, larg, 54, true)
	_campo(p, "proximo", TAM_TEXTO, false, Paleta.DICA, HORIZONTAL_ALIGNMENT_CENTER, MARGEM, 184, larg, 50, true)
	var sep := ColorRect.new()
	sep.name = "sep"
	sep.position = Vector2(MARGEM, 236)
	sep.size = Vector2(larg, 1)
	sep.color = Color(1, 1, 1, 0.2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(sep)
	_campo(p, "nivel", TAM_TEXTO, false, Paleta.TEXTO, HORIZONTAL_ALIGNMENT_CENTER, MARGEM, 242, larg, 20)
	_campo(p, "evolui", TAM_TEXTO, false, Paleta.OURO, HORIZONTAL_ALIGNMENT_CENTER, MARGEM, 262, larg, 20)


## Põe os dados de uma carta (escolha, ou baú já revelado) no cartão `p`.
func _preencher(p: Panel, c: Dictionary) -> void:
	var cor: Color = c.get("cor", Paleta.RARIDADES[0])
	var nome := p.get_node("nome") as Label
	nome.text = str(c.nome)
	nome.add_theme_color_override("font_color", cor.lerp(Color.WHITE, 0.55))
	_ajustar_nome(nome)
	(p.get_node("desc") as Label).text = str(c.desc)
	(p.get_node("proximo") as Label).text = str(c.get("proximo", ""))
	(p.get_node("nivel") as Label).text = str(c.get("nivel_txt", ""))
	var evo := p.get_node("evolui") as Label
	evo.text = str(c.get("evolui", ""))
	var lendaria := bool(c.get("lendaria", false))  # a peça que fecha uma lendária ganha o magenta da fusão
	evo.add_theme_color_override("font_color", Paleta.FUSAO if lendaria else Paleta.OURO)
	var rl := p.get_node("rar") as Label
	rl.text = str(c.get("rar_nome", "")).to_upper()
	rl.add_theme_color_override("font_color", cor.lerp(Color.WHITE, 0.3))
	(p.get_node("faixa") as ColorRect).color = Paleta.alfa(Paleta.FUSAO, 0.9) if lendaria else Color(cor.r, cor.g, cor.b, 0.9)
	var nome_icone := str(c.get("icone", ""))
	(p.get_node("icone") as TextureRect).texture = Dados.tex(nome_icone) if nome_icone != "" else null
	(p.get_node("moldura") as Panel).add_theme_stylebox_override("panel", _moldura(cor))


## Nome numa linha só: o tamanho grande se cabe na largura do cartão, senão o pequeno (um nome longo não sai da carta).
func _ajustar_nome(l: Label) -> void:
	var largura := _fonte_t.get_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, -1, TAM_NOME).x
	l.add_theme_font_size_override("font_size", TAM_NOME if largura <= CARTA_L - 2.0 * MARGEM else TAM_NOME_CURTO)


## Moldura do ícone: fundo quase preto e borda da cor da raridade.
func _moldura(cor: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Paleta.alfa(Paleta.PAINEL, 0.95)
	s.border_color = cor
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	return s


func _botao(pos: Vector2, _id: String) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(240, 28)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _estilo(false, Paleta.BORDA))
	var t := _rotulo("", TAM_TEXTO, false, Paleta.TEXTO, HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "t"
	t.position = Vector2(4, 5)
	t.size = Vector2(232, 18)
	p.add_child(t)
	_escolha.add_child(p)
	return p


func _montar_bau() -> void:
	_bau = Control.new()
	_bau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bau.visible = false
	camada.add_child(_bau)
	_bau_titulo = _rotulo("BAÚ!", TAM_TITULO, true, Paleta.OURO, HORIZONTAL_ALIGNMENT_CENTER)
	_bau_titulo.position = Vector2(0, 80)
	_bau_titulo.size = Vector2(LARG, 64)
	_bau.add_child(_bau_titulo)
	for i in 3:
		var p := Panel.new()
		var st := _estilo(false)
		p.add_theme_stylebox_override("panel", st)
		_bau_estilos.append(st)
		_montar_cartao(p, "")
		_bau.add_child(p)
		_bau_slots.append(p)
	_bau_dica = _rotulo("ENTER ou clique para continuar", TAM_TEXTO, false, Paleta.OURO, HORIZONTAL_ALIGNMENT_CENTER)
	_bau_dica.position = Vector2(0, 450)
	_bau_dica.size = Vector2(LARG, 20)
	_bau.add_child(_bau_dica)


func _montar_resultado() -> void:
	_res = Control.new()
	_res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res.visible = false
	camada.add_child(_res)
	_res_titulo = _rotulo("VOCÊ CAIU", TAM_TITULO, true, Paleta.PERIGO, HORIZONTAL_ALIGNMENT_CENTER)
	_res_titulo.position = Vector2(0, 80)
	_res_titulo.size = Vector2(LARG, 72)
	_res.add_child(_res_titulo)
	_res_linhas = _rotulo("Tempo\nAbates\nMaior combo\nNível\nAlmas ganhas", TAM_TEXTO, false, Paleta.TEXTO_SECUNDARIO, HORIZONTAL_ALIGNMENT_LEFT)
	_res_linhas.position = Vector2(300, 186)
	_res_linhas.size = Vector2(240, 190)
	_res_linhas.add_theme_constant_override("line_spacing", 8)
	_res.add_child(_res_linhas)
	_res_valores = _rotulo("", TAM_TEXTO, false, Paleta.VALOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_res_valores.position = Vector2(540, 186)
	_res_valores.size = Vector2(120, 190)
	_res_valores.add_theme_constant_override("line_spacing", 8)
	_res.add_child(_res_valores)
	_res_dica = _rotulo("ENTER ou clique para jogar de novo", TAM_TEXTO, false, Paleta.OURO, HORIZONTAL_ALIGNMENT_CENTER)
	_res_dica.position = Vector2(0, 410)
	_res_dica.size = Vector2(LARG, 12)
	_res.add_child(_res_dica)


# ------------------------------------------------------------------ mostrar


## Mostra a escolha. `refresh` = é o mesmo menu com cartas novas (rerrolar ou banir): mantém a marcação.
func mostrar_escolha(cartas: Array, nivel: int, refresh := false) -> void:
	escolha_aberta = true
	if not refresh:
		sel = 0
	_fundo.visible = true
	_escolha.visible = true
	_titulo.text = "NÍVEL %d" % nivel
	var maxn := cartas.size()
	sel = clampi(sel, 0, maxi(maxn - 1, 0))
	for i in 3:
		var p := _cartas[i]
		p.visible = i < maxn
		if i >= maxn:
			continue
		var c: Dictionary = cartas[i]
		_preencher(p, c)
		var rar := int(c.get("rar", 0))
		_estilos[i].shadow_size = 0 if rar == 0 else 4 + 3 * rar
	var ec: Dictionary = combate.cartas.cfg.escolha
	_espera_total = float(ec.rerrolar_espera_s) if refresh else float(ec.espera_s)
	espera_escolha = _espera_total
	_acender = 0.0
	_marcar()
	_atualizar_botoes()
	if espera_escolha > 0.0:
		_iniciar_trava()
	_texto_build()
	combate.audio.tocar("carta", 1.0 + 0.12 * float(_rar_max(cartas)), 0.0, 0.0)


func _rar_max(cartas: Array) -> int:
	var m := 0
	for c in cartas:
		m = maxi(m, int(c.get("rar", 0)))
	return m


## A carta marcada (sel) só aparece fora da trava: na trava não há realce de seleção.
func _marcar() -> void:
	var cartas: Array = combate.progresso.cartas
	var sem_trava := espera_escolha <= 0.0
	for i in 3:
		var c: Dictionary = cartas[i] if i < cartas.size() else {}
		var cor: Color = c.get("cor", Paleta.BORDA)
		var rar := int(c.get("rar", 0))
		var marcada := sem_trava and i == sel
		var novo := _estilo(marcada, cor, rar)
		_estilos[i].bg_color = novo.bg_color
		_estilos[i].border_color = novo.border_color
		_estilos[i].shadow_color = novo.shadow_color
		_estilos[i].shadow_size = novo.shadow_size
		_estilos[i].set_border_width_all(2 + (1 if rar >= 2 else 0) + (1 if marcada else 0))
		_cartas[i].position.y = CARTA_Y - (8.0 if marcada else 0.0)


func _atualizar_botoes() -> void:
	var cs = combate.cartas
	var pr: bool = cs.pode_rerrolar() and espera_escolha <= 0.0
	var pb: bool = cs.pode_banir() and espera_escolha <= 0.0
	_btn_r_txt.text = "[R] Rerrolar (%d)" % cs.rerrolares_restantes() if cs.rerrolar_na_tela < cs.rerrolar_por_tela() else "[R] Rerrolar (já usou)"
	_btn_b_txt.text = "[B] Banir a marcada (%d)" % cs.banimentos_restantes()
	_btn_r.modulate = Color.WHITE if pr else Color(1, 1, 1, 0.4)
	_btn_b.modulate = Color.WHITE if pb else Color(1, 1, 1, 0.4)


func _texto_build() -> void:
	var partes: Array = []
	for r in combate.cartas.resumo():
		partes.append("%s %s" % [r.nome, ("nv %d" % r.nivel) if int(r.nivel) > 0 else "(evoluído)"])
	_build.text = "Sua build: " + ", ".join(partes) if not partes.is_empty() else "Sua build: só a katana (os golpes automáticos vêm pelas cartas)"


func mostrar_resultado() -> void:
	resultado_aberto = true
	mostrada_t = 0.0
	var venceu: bool = combate.venceu
	if mundo.get("meta_res") != null:
		return  # o resultado com as almas (resultado_meta.gd, por cima) mostra tudo; aqui fica só o estado (resultado_aberto)
	_fundo.visible = true
	_fundo.color = Paleta.alfa(Paleta.PAINEL, 0.7) if venceu else Paleta.alfa(Paleta.PAINEL, 0.72)
	_res_titulo.text = "VITÓRIA" if venceu else "VOCÊ CAIU"
	_res_titulo.add_theme_color_override("font_color", Paleta.OURO if venceu else Paleta.PERIGO)
	_res.visible = true
	var h = mundo.heroi
	var seg := int(mundo.tempo_partida)
	_res_valores.text = "%02d:%02d\n%d\nx%d\n%d\n%d" % [floori(seg / 60.0), seg % 60, mundo.abates, mundo.maior_combo, h.nivel, mundo.almas_partida]
	combate.audio.tocar("carta", 0.7, 0.0, 0.0)


func esconder() -> void:
	if mundo.heroi != null:
		mundo.heroi.exigir_soltar_ataque()  # o clique que fechou a escolha ou o baú não vira golpe no quadro seguinte
	escolha_aberta = false
	resultado_aberto = false
	bau_aberto = false
	espera_escolha = 0.0
	espera_bau = 0.0
	for p in _cartas:
		p.modulate = Color.WHITE
		(p.get_node("espera") as ColorRect).visible = false
	_escolha.visible = false
	_bau.visible = false
	_res.visible = false
	_fundo.visible = false
	_fundo.color = Paleta.alfa(Paleta.PAINEL, 0.62)


func ligar_depuracao(v: bool) -> void:
	depuracao = v
	_dep.visible = v


# ------------------------------------------------------------------ baú


## A roleta do baú: as cartas já foram aplicadas; aqui só aparecem, uma a uma, depois de girar.
func mostrar_bau(cartas: Array) -> void:
	bau_aberto = true
	bau_pronto = false
	espera_bau = float(combate.cartas.cfg.bau.bau_espera_s)
	_bau_cartas = cartas
	_bau_i = 0
	_bau_t = 0.0
	_bau_fase = 0
	_fundo.visible = true
	_fundo.color = Paleta.alfa(Paleta.PAINEL, 0.7)
	_bau.visible = true
	_bau_dica.visible = false
	var n := cartas.size()
	var x0 := (LARG - (n * CARTA_L + (n - 1) * FOLGA)) * 0.5
	for i in 3:
		var p := _bau_slots[i]
		p.visible = i < n
		if i >= n:
			continue
		p.position = Vector2(x0 + i * (CARTA_L + FOLGA), CARTA_Y)
		_limpar_slot(i)
	combate.audio.tocar("bau", 1.0, 0.0, 0.0)


func _limpar_slot(i: int) -> void:
	var p := _bau_slots[i]
	(p.get_node("nome") as Label).text = "?"
	for campo in ["rar", "desc", "proximo", "nivel", "evolui"]:
		(p.get_node(campo) as Label).text = ""
	(p.get_node("icone") as TextureRect).texture = null
	(p.get_node("moldura") as Panel).add_theme_stylebox_override("panel", _moldura(Paleta.BORDA))
	p.modulate = Color(1, 1, 1, 0.9)
	var novo := _estilo(false)
	_bau_estilos[i].bg_color = novo.bg_color
	_bau_estilos[i].border_color = novo.border_color
	_bau_estilos[i].shadow_size = 0


func _girar_slot(i: int) -> void:
	# um sorteio qualquer de nome e raridade, só para parecer uma roleta (não muda nada do jogo)
	var cs = combate.cartas
	var todas: Array = cs.disponiveis()
	var d: Dictionary = todas[randi() % todas.size()] if not todas.is_empty() else {"nome": "?"}
	var r: int = randi() % cs.rar.size()
	var cor := Paleta.RARIDADES[r]
	var p := _bau_slots[i]
	var nome_girando := p.get_node("nome") as Label
	nome_girando.text = str(d.nome)
	_ajustar_nome(nome_girando)
	(p.get_node("nome") as Label).add_theme_color_override("font_color", cor.lerp(Color.WHITE, 0.4))
	var novo := _estilo(false, cor, r)
	_bau_estilos[i].bg_color = novo.bg_color
	_bau_estilos[i].border_color = novo.border_color
	_bau_estilos[i].shadow_color = novo.shadow_color
	_bau_estilos[i].shadow_size = novo.shadow_size


func _revelar_slot(i: int) -> void:
	var c: Dictionary = _bau_cartas[i]
	var cor: Color = c.get("cor", Paleta.RARIDADES[0])
	var rar := int(c.get("rar", 0))
	var p := _bau_slots[i]
	_preencher(p, c)
	var novo := _estilo(true, cor, rar)
	_bau_estilos[i].bg_color = novo.bg_color
	_bau_estilos[i].border_color = novo.border_color
	_bau_estilos[i].shadow_color = novo.shadow_color
	_bau_estilos[i].shadow_size = novo.shadow_size
	p.modulate = Color(1.8, 1.8, 1.8, 1.0)  # o clarão da revelação (vai baixando em atualizar)
	combate.fx.onda(mundo.heroi.pos, Color(cor.r, cor.g, cor.b, 0.9), 40.0 + 20.0 * rar, 0.35)
	combate.audio.tocar("nivel" if rar >= 3 else "escolher", 1.0 + 0.05 * rar, 0.0, 0.0)


func _atualizar_bau(dt: float) -> void:
	if espera_bau > 0.0 and not _pausa_aberta():
		espera_bau = maxf(0.0, espera_bau - dt)
	for i in 3:
		if _bau_slots[i].visible and _bau_slots[i].modulate.r > 1.0:
			var m := _bau_slots[i].modulate
			_bau_slots[i].modulate = Color(maxf(1.0, m.r - dt * 3.0), maxf(1.0, m.g - dt * 3.0), maxf(1.0, m.b - dt * 3.0), 1.0)
	if _bau_fase == 2:
		return
	var rol: Dictionary = combate.cartas.cfg.bau.roleta
	var giro := float(rol.giro) * (1.0 if _bau_i == 0 else 0.65)
	_bau_t += dt
	if _bau_fase == 0:
		_bau_tick -= dt
		if _bau_tick <= 0.0:
			_bau_tick = 0.06 + 0.12 * (_bau_t / giro) * (_bau_t / giro)  # a roleta desacelera
			_girar_slot(_bau_i)
			combate.audio.tocar("carta", 0.8 + 0.5 * (_bau_t / giro), -8.0, 0.0)
		if _bau_t >= giro:
			_revelar_slot(_bau_i)
			_bau_fase = 1
			_bau_t = 0.0
	elif _bau_fase == 1:
		if _bau_t >= float(rol.pausa):
			_bau_i += 1
			_bau_t = 0.0
			if _bau_i >= _bau_cartas.size():
				_bau_fase = 2
				bau_pronto = true
				_bau_dica.visible = true
			else:
				_bau_fase = 0
				_bau_tick = 0.0


## Pula a roleta: revela o que falta de uma vez.
func _pular_bau() -> void:
	while _bau_fase != 2:
		if _bau_fase == 0:
			_revelar_slot(_bau_i)
		_bau_i += 1
		if _bau_i >= _bau_cartas.size():
			_bau_fase = 2
			bau_pronto = true
			_bau_dica.visible = true
		else:
			_bau_fase = 0
			_bau_t = 0.0


# ------------------------------------------------------------------ quadro e entrada


func atualizar(dt: float) -> void:
	_t_ui += dt
	if resultado_aberto:
		mostrada_t += dt
		_res_dica.visible = int(mostrada_t * 2.0) % 2 == 0 or mostrada_t < 0.6
	if escolha_aberta:
		_atualizar_escolha(dt)
	if bau_aberto:
		_atualizar_bau(dt)
	if depuracao:
		_dep_t -= dt
		if _dep_t <= 0.0:
			_dep_t = 0.1
			var h = mundo.heroi
			_dep.text = (
				"VIDA %d/%d   NV %d   XP %d/%d   FOLEGO %.1f\nCOMBO x%d   ABATES %d   VIVOS %d   %02d:%02d   [F1 esconde]"
				% [
					roundi(h.vida),
					roundi(h.vida_max),
					h.nivel,
					roundi(h.xp),
					roundi(h.xp_proximo),
					h.folego,
					mundo.combo,
					mundo.abates,
					mundo.monstros.size(),
					floori(mundo.tempo_partida / 60.0),
					int(mundo.tempo_partida) % 60
				]
			)


## O brilho das cartas raras respira (épico e lendário mais forte).
func _pulsar_cartas() -> void:
	var cartas: Array = combate.progresso.cartas
	for i in mini(3, cartas.size()):
		var rar := int(cartas[i].get("rar", 0))
		if rar > 0:
			var base := 4 + 3 * rar
			_estilos[i].shadow_size = base + roundi((2.0 + 2.0 * rar) * (0.5 + 0.5 * sin(_t_ui * (3.0 + rar) + float(i))))


## Posição do mouse na tela 960x540 (mouse_fn é o gancho dos testes; sem ele, o mouse de verdade).
func _mouse() -> Vector2:
	if mouse_fn.is_valid():
		return mouse_fn.call()
	return mundo.ap.mouse_na_tela()


## Pausa aberta (v2/pausa.gd): a trava não anda. mundo.pausa é o nó do menu (mundo.gd); sem ele, nenhuma pausa conta.
func _pausa_aberta() -> bool:
	var p = mundo.get("pausa")
	return p != null and bool(p.aberto)


## Tempo REAL da escolha: a trava das cartas (3 s; 0,8 s depois de rerrolar ou banir), o brilho ao liberar e a pulsada da contagem.
## O dt vem do relógio de parede (combate.efeitos), então câmera lenta e hit-stop não mexem nele.
func _atualizar_escolha(dt: float) -> void:
	if espera_escolha > 0.0:
		if not _pausa_aberta():
			espera_escolha = maxf(0.0, espera_escolha - dt)
			_pulso = maxf(0.0, _pulso - dt)
		if espera_escolha > 0.0:
			_quadro_trava()
		else:
			_liberar_cartas()
		return
	if _acender > 0.0:
		_acender = maxf(0.0, _acender - dt)
		var k := 0.7 * _acender / ACENDER_T
		for p in _cartas:
			p.modulate = Color(1.0 + k, 1.0 + k, 1.0 + k, 1.0)
	_pulsar_cartas()


## Começa a trava: cartas apagadas, uma barra vazia em cada carta e a contagem na legenda (fonte de título).
func _iniciar_trava() -> void:
	_sub.add_theme_font_override("font", _fonte_t)
	_sub.add_theme_font_size_override("font_size", TAM_CONTAGEM)
	for i in 3:
		var p := _cartas[i]
		p.modulate = Paleta.CARTA_APAGADA
		(p.get_node("espera") as ColorRect).visible = p.visible
	_quadro_trava()


## Cada quadro da trava: a barra enche, a contagem muda (3, 2, 1) e a pulsada da contagem decai.
func _quadro_trava() -> void:
	var feito := clampf(1.0 - espera_escolha / maxf(_espera_total, 0.001), 0.0, 1.0)
	for p in _cartas:
		(p.get_node("espera") as ColorRect).size.x = (CARTA_L - 2.0 * MARGEM) * feito
	var txt := "Escolha em %d" % ceili(espera_escolha)
	if _sub.text != txt:
		_sub.text = txt
	_sub.add_theme_color_override("font_color", Paleta.OURO.lerp(Color.WHITE, clampf(_pulso / PULSO_T, 0.0, 1.0)))


## Fim da trava: as cartas acendem, a legenda volta ao normal, a marcação aparece e um som curto avisa.
func _liberar_cartas() -> void:
	espera_escolha = 0.0
	_pulso = 0.0
	_acender = ACENDER_T
	_sub.text = "Escolha uma carta"
	_sub.add_theme_font_override("font", _fonte)
	_sub.add_theme_font_size_override("font_size", TAM_TEXTO)
	_sub.add_theme_color_override("font_color", Paleta.TEXTO)
	for p in _cartas:
		(p.get_node("espera") as ColorRect).visible = false
	_marcar()
	_atualizar_botoes()
	combate.audio.tocar("carta", 1.4, -4.0, 0.0)


## Entrada das telas. Devolve true se o evento foi usado (escolha de carta, baú, jogar de novo, F1).
func entrada(e: InputEvent) -> bool:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F1:
		ligar_depuracao(not depuracao)
		return true
	if escolha_aberta:
		return _entrada_escolha(e)
	if bau_aberto:
		return _entrada_bau(e)
	if resultado_aberto:
		return _entrada_resultado(e)
	return false


func _carta_sob_mouse() -> int:
	var m := _mouse()
	for i in 3:
		if _cartas[i].visible and Rect2(_cartas[i].position, _cartas[i].size).grow(6.0).has_point(m):
			return i
	return -1


func _botao_sob_mouse() -> String:
	var m := _mouse()
	if Rect2(_btn_r.position, _btn_r.size).has_point(m):
		return "r"
	if Rect2(_btn_b.position, _btn_b.size).has_point(m):
		return "b"
	return ""


## Na trava (espera_escolha > 0) qualquer clique, tecla ou botão de escolha é DESCARTADO e pulsa a contagem: nada escolhe, nada
## rerrola, nada bane e nada chega ao herói. Um clique que já estava apertado antes da liberação não conta: só aperto novo (press) vale.
func _entrada_escolha(e: InputEvent) -> bool:
	var n: int = combate.progresso.cartas.size()
	var travada := espera_escolha > 0.0
	if e is InputEventMouseMotion:
		if not travada:  # na trava o mouse passa sem realce de carta
			var i := _carta_sob_mouse()
			if i >= 0 and i != sel:
				sel = i
				_marcar()
				combate.audio.tocar("carta", 1.2, -6.0, 0.03)
		return true
	if e is InputEventMouseButton:
		if not e.pressed:
			return false
		if travada:
			_pulso = PULSO_T
			return true
		if e.button_index == MOUSE_BUTTON_LEFT:
			var b := _botao_sob_mouse()
			if b == "r":
				_rerrolar()
				return true
			if b == "b":
				_banir()
				return true
			var j := _carta_sob_mouse()
			if j >= 0:
				combate.progresso.escolher(j)
		return true
	if e is InputEventKey:
		if not e.pressed or e.keycode == KEY_ESCAPE:
			return false  # ESC é da pausa (pausa.gd), e soltar uma tecla não escolhe nada
		if e.echo:
			return true
		if travada:
			_pulso = PULSO_T
			return true
		match e.keycode:
			KEY_1, KEY_2, KEY_3:
				var i: int = e.keycode - KEY_1
				if i < n:
					combate.progresso.escolher(i)
			KEY_LEFT, KEY_A:
				_mover(-1, n)
			KEY_RIGHT, KEY_D:
				_mover(1, n)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				combate.progresso.escolher(sel)
			KEY_R:
				_rerrolar()
			KEY_B, KEY_X:
				_banir()
		return true
	if e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right") or e.is_action_pressed("ui_accept"):
		if travada:
			_pulso = PULSO_T
		elif e.is_action_pressed("ui_left"):
			_mover(-1, n)
		elif e.is_action_pressed("ui_right"):
			_mover(1, n)
		else:
			combate.progresso.escolher(sel)
		return true
	return false


func _rerrolar() -> void:
	if not combate.progresso.rerrolar():
		combate.audio.tocar("dano_heroi", 1.4, -10.0, 0.1)


func _banir() -> void:
	if not combate.progresso.banir(sel):
		combate.audio.tocar("dano_heroi", 1.4, -10.0, 0.1)
	else:
		combate.audio.tocar("morte", 1.2, -4.0, 0.0)


func _mover(d: int, n: int) -> void:
	if n <= 0:
		return
	sel = posmod(sel + d, n)
	_marcar()
	combate.audio.tocar("carta", 1.2, -6.0, 0.03)


func _entrada_bau(e: InputEvent) -> bool:
	if e is InputEventKey and e.keycode == KEY_ESCAPE:
		return false  # ESC é da pausa (pausa.gd), no baú como na escolha
	var vai := false
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		vai = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		vai = true
	elif e.is_action_pressed("ui_accept"):
		vai = true
	if vai:
		if espera_bau <= 0.0:  # na trava de 1,5 s o clique é descartado: não pula nem fecha
			if bau_pronto:
				combate.baus.fechar()
			else:
				_pular_bau()
		return true
	return e is InputEventKey or e is InputEventMouseButton


func _entrada_resultado(e: InputEvent) -> bool:
	if mostrada_t < 0.6:
		return false
	var vai := false
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		vai = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		vai = true
	elif e.is_action_pressed("ui_accept"):
		vai = true
	if vai:
		mundo.reiniciar()
	return vai
