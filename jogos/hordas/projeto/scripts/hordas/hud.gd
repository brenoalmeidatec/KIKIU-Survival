extends CanvasLayer
const Perf := preload("res://scripts/hordas/perf.gd")
## Tela da partida (cena res://cenas/hud.tscn, Theme res://cenas/tema_hud.tres): esquerda = retrato, nome, vida e carga;
## direita = ouro e almas; topo = relógio, região/andar, objetivo e missão; embaixo à esquerda = habilidades e consumíveis;
## embaixo à direita = lugar do minimapa (Marco 4); mensagens, banner de conjunto, vida do chefe, duelo final e o menu de pausa.
## Este script só liga os dados do jogo aos nós da cena; o tamanho do texto vem do Theme (opção "Tamanho da fonte do HUD").
## Sai da tela (issue #125): nome de inimigo comum, lista de conjuntos (fica na tela de status) e contador de abates.

const W := 640.0
const H := 360.0
const TelaOpcoes := preload("res://scripts/hordas/tela_opcoes.gd")
const Interface := preload("res://scripts/hordas/interface.gd")
const Criacao := preload("res://scripts/hordas/criacao.gd")
const Descobertas := preload("res://scripts/hordas/descobertas.gd")
const Mochila := preload("res://scripts/hordas/mochila.gd")
const Slot := preload("res://scripts/hordas/hud_slot.gd")
const FONTE_BASE := 8.0
const BANNER_SEG := 2.0
const MAX_MSGS := 4

var arena: Node
var _msgs: Array = []  # {txt, cor, t}
var _anuncio := {"txt": "", "cor": Color.WHITE, "t": 0.0}
var _pausado := false
var _hud_antes_pausa := true  # o HUD estava visível antes da pausa (a abertura da fase o esconde)
var _op_pausa := 0
var _t := 0.0
var _quadro_pausa := -1
var _opcoes: Node = null  # tela de Opções aberta pela pausa
var _mouse_ult := Vector2(-1, -1)
var _fator := 0.0
var _banner_t := 0.0
var _conj_ult := {}  # etiqueta -> degrau ligado no quadro anterior (para detectar conjunto novo)
var _heroi_ult := ""
var _build_ult: Array = []
var _prov: Array = []  # slots de consumível
var _buffs: Array = []  # slots de efeito ativo
var _lut_n := -1
var _estilos := {}  # barra -> StyleBoxFlat do preenchimento (a cor muda sem criar recurso novo)
var _msg_lbl: Array = []
var _op_lbl: Array = []

@onready var raiz: Control = %Raiz
@onready var setas: Control = %Setas


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	raiz.theme = raiz.theme.duplicate()  # a opção de fonte mexe neste Theme: não pode vazar para outra partida
	_ignorar_mouse(raiz)
	setas.arena = arena
	for i in MAX_MSGS:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.visible = false
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # mensagem longa (ou fonte grande) quebra em vez de sair da tela
		l.custom_minimum_size = Vector2(400, 0)
		%Msgs.add_child(l)
		_msg_lbl.append(l)
	for i in 3:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(220, 0)
		%Opcoes.add_child(l)
		_op_lbl.append(l)
	%PausaTitulo.text = tr("HUD_PAUSADO")
	%PausaDica.text = tr("HUD_DICA_PAUSA")
	%PausaDica.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	%Versao.add_theme_color_override("font_color", Color(0.72, 0.74, 0.86, 0.85))
	%Regiao.add_theme_color_override("font_color", Color(0.7, 0.9, 1))
	%Almas.add_theme_color_override("font_color", Color(0.75, 0.6, 1))
	%Ouro.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	%DueloTitulo.text = tr("HUD_DUELO_FINAL")
	%DueloTitulo.add_theme_color_override("font_color", Color(1, 0.5, 0.45))
	%Aviso.text = tr("HUD_DUELO_VOLTE")
	%Aviso.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	%Fps.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	%BannerTitulo.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	%Minimapa.modulate = Color(1, 1, 1, 0.35)
	_cor_barra(%Xp, Color(0.3, 0.6, 1.0))
	_cor_barra(%HeroiVida, Color(0.9, 0.2, 0.25))
	_cor_barra(%Carga, Color(0.25, 0.45, 1.0))
	_aplicar_fonte()
	_pausa_texto()


func _ignorar_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignorar_mouse(c)


## Cor do preenchimento de uma barra (um StyleBoxFlat por barra, criado uma vez).
func _cor_barra(b: ProgressBar, cor: Color) -> void:
	var sb: StyleBoxFlat = _estilos.get(b)
	if sb == null:
		sb = StyleBoxFlat.new()
		_estilos[b] = sb
		b.add_theme_stylebox_override("fill", sb)
	if sb.bg_color != cor:
		sb.bg_color = cor


func _cor_txt(l: Label, cor: Color) -> void:
	l.add_theme_color_override("font_color", cor)


## Tamanho da fonte do HUD (opção 1x, 1,5x, 2x): muda os tamanhos do Theme e todos os textos acompanham.
func _aplicar_fonte() -> void:
	_fator = Config.fator_fonte()
	var th: Theme = raiz.theme
	th.default_font_size = roundi(FONTE_BASE * _fator)
	th.set_font_size("font_size", "LabelGrande", roundi(16.0 * (1.0 + (_fator - 1.0) * 0.5)))
	var larg := roundf(116.0 * (1.0 + (_fator - 1.0) * 0.5))  # as barras crescem junto, mas menos que o texto (o texto fica mais curto)
	%HeroiVida.custom_minimum_size.x = larg
	%Carga.custom_minimum_size.x = larg
	%Build.custom_minimum_size.x = larg + 38.0
	for b in [%HeroiVida, %Carga]:
		b.custom_minimum_size.y = roundf(10.0 * _fator)


func mensagem(txt: String, cor := Color.WHITE) -> void:
	_msgs.append({"txt": txt, "cor": cor, "t": 2.5})
	if _msgs.size() > MAX_MSGS:
		_msgs.pop_front()


func anunciar(txt: String, cor := Color.WHITE) -> void:
	_anuncio = {"txt": txt, "cor": cor, "t": 2.5}


func limpar_mensagens() -> void:
	_msgs.clear()


## Faixa de 2 s no meio da tela quando um conjunto de etiquetas completa um degrau (a lista inteira fica na tela de status).
func banner_conjunto(nome: String, efeito: String, cor := Color(1, 0.9, 0.5)) -> void:
	%BannerTitulo.text = tr("HUD_BANNER_CONJUNTO") % nome
	%BannerTitulo.add_theme_color_override("font_color", cor)
	%BannerEfeito.text = efeito
	%BannerEfeito.visible = efeito != ""
	_banner_t = BANNER_SEG
	%Banner.visible = true
	%Banner.modulate.a = 1.0
	Som.ui("confirmar")


func atualizar(dt: float) -> void:
	var _pp := Perf.ini()
	atualizar_i(dt)
	Perf.fim("hud_a", _pp)


func atualizar_i(dt: float) -> void:
	_t += dt
	for m in _msgs.duplicate():
		m.t -= dt
		if m.t <= 0:
			_msgs.erase(m)
	_anuncio.t = maxf(0.0, _anuncio.t - dt)
	_banner_t = maxf(0.0, _banner_t - dt)
	_sincronizar()


# ---------- ligação dos dados do jogo com os nós ----------


func _sincronizar() -> void:
	if arena == null or arena.jogador == null:
		return
	var duelo: bool = arena.duelo_ativo
	%Xp.visible = not duelo
	%Nivel.visible = not duelo
	%Dir.visible = not duelo
	%Topo.visible = not duelo
	%Duelo.visible = duelo
	_heroi()
	if duelo:
		_duelo()
		%Chefe.visible = false
	else:
		_xp_e_relogio()
		_ouro()
		_objetivo()
		_missao()
		_chefe()
	_build()
	_habilidades()
	_provisoes()
	_conjuntos()
	_mensagens()
	%Fps.visible = bool(Config.v("mostrar_fps"))
	if %Fps.visible:
		%Fps.text = tr("HUD_FPS") % Engine.get_frames_per_second()
	setas.t = _t
	setas.queue_redraw()


func _heroi() -> void:
	if arena.heroi_id != _heroi_ult:
		_heroi_ult = arena.heroi_id
		%Retrato.texture = Dados.tex_personagem(str(arena.heroi.get("sprite", arena.heroi_id)), "rosto")
	%HeroiNome.text = str(arena.heroi.get("nome", arena.heroi_id))
	var hpmax: float = arena.stat("vida_max")
	%HeroiVida.max_value = maxf(1.0, hpmax)
	%HeroiVida.value = clampf(arena.jogador.hp, 0.0, hpmax)
	%HeroiVidaTxt.text = "%d/%d" % [ceili(arena.jogador.hp), int(hpmax)]
	# carga: energia da transformação (dragão do Hazaki) ou os fragmentos que faltam para despertá-la
	var h = arena.habilidades
	var mostra := false
	if h != null and h.tem():
		if not h.desbloqueada and str(h.d().get("desbloqueio", {}).get("tipo", "")) == "fragmentos":
			var total: int = arena.descobertas.precisa(h.atual)
			var tem: int = arena.descobertas.tem_fragmentos(h.atual)
			%Carga.max_value = maxf(1.0, total)
			%Carga.value = tem
			%CargaTxt.text = tr("HUD_FRAGMENTOS" if _fator <= 1.0 else "HUD_FRAGMENTOS_CURTO") % [tem, total]
			_cor_txt(%CargaTxt, Color(0.8, 0.88, 1.0))
			mostra = true
		elif h.desbloqueada:
			var frac: float = clampf(h.energia / h.energia_max(), 0.0, 1.0)
			%Carga.max_value = 1.0
			%Carga.value = frac
			var txt: String = tr("HUD_ENERGIA" if _fator <= 1.0 else "HUD_ENERGIA_CURTO") % roundi(frac * 100.0)
			var cor := Color(0.8, 0.88, 1.0)
			if h.ativa:
				txt = tr("HUD_DRAGAO_ATIVO") % ceili(h.restante())
				cor = Color(0.55, 0.85, 1.0)
			elif h.pronta():
				txt = tr("HUD_DRAGAO_PRONTO")
				cor = Color(1, 0.9, 0.4) if int(_t * 4) % 2 == 0 else Color(0.55, 0.85, 1.0)
			%CargaTxt.text = txt
			_cor_txt(%CargaTxt, cor)
			mostra = true
	%Carga.visible = mostra


func _xp_e_relogio() -> void:
	%Xp.value = clampf(arena.xp / arena.xp_para(arena.nivel), 0.0, 1.0)
	%Nivel.text = tr("HUD_NIVEL") % arena.nivel
	var df = arena.diretor
	var fa: Dictionary = df.fases()[df.fase_idx]
	var resta := maxf(0.0, float(fa.get("duracao", 0)) - df.t_fase)
	var nome_fase := str(fa.get("nome", "")).to_upper()
	var rotulo: String
	if fa.has("regiao"):  # regiões (#64): "FLORESTA SOMBRIA 2/5  TRILHA TORTA"
		rotulo = "%s %d/%d" % [str(fa.regiao_nome).to_upper(), int(fa.andar_regiao) + 1, int(Dados.json("regioes").get("fases_por_regiao", 5))]
	else:
		rotulo = tr("HUD_FASE_N") % [df.fase_idx + 1, df.fases().size()]
	if nome_fase != "" and _fator <= 1.0:  # com fonte maior o nome do andar não cabe do lado: fica só a região
		rotulo += "  " + nome_fase
	%Regiao.text = rotulo
	var sub := ""
	var cor_sub := Color(1, 0.75, 0.35)
	if df.saida_leve:
		%Tempo.text = tr("HUD_PORTAL_ABERTO")
		_cor_txt(%Tempo, Color(0.75, 0.65, 1))
	elif df.pror_ativa():  # prorrogação (#112): o cronômetro sobe e a cada degrau fica mais difícil e paga mais ouro
		var pt: float = df.pror_t()
		%Tempo.text = "+%02d:%02d" % [int(pt) / 60, int(pt) % 60]
		_cor_txt(%Tempo, Interface.cor("alerta"))
		sub = tr("HUD_PRORROGACAO") % [df.pror_degrau(), df.mult_ouro()]
	elif df.final_chamado:
		%Tempo.text = tr("HUD_CHEFE")
		_cor_txt(%Tempo, Interface.cor("alerta"))
		var jr: float = df.janela_resta()
		if jr > 0.0 and not df.enxame_final:
			sub = tr("HUD_DERROTE_EM") % [int(jr) / 60, int(jr) % 60]
			cor_sub = Color(1, 0.75, 0.6)
	else:
		%Tempo.text = "%02d:%02d" % [int(resta) / 60, int(resta) % 60]
		_cor_txt(%Tempo, Interface.cor("alerta") if df.enxame_final else Color.WHITE)
	%Sub.text = sub
	%Sub.visible = sub != ""
	_cor_txt(%Sub, cor_sub)


func _ouro() -> void:
	%Ouro.text = tr("HUD_OURO") % arena.ouro
	var almas = arena.get("almas")  # ainda não existe (Marco 7): aparece zerado
	%Almas.text = tr("HUD_ALMAS") % (int(almas) if almas != null else 0)


func _chefe() -> void:
	var chefes: Array = arena.chefes()
	%Chefe.visible = not chefes.is_empty()
	if chefes.is_empty():
		return
	var c = chefes[0]
	_cor_barra(%ChefeBarra, Interface.cor("vida_chefe"))
	%ChefeBarra.value = clampf(c.hp / c.hpmax, 0.0, 1.0)
	%ChefeNome.text = str(c.d.get("nome", ""))
	_cor_txt(%ChefeNome, Color(1, 0.8, 0.8))


## Objetivo do andar (#63): nome, barra de progresso e o tempo que sobra. As setas vão no hud_setas.gd.
func _objetivo() -> void:
	var ob = arena.objetivo
	%Objetivo.visible = ob != null and ob.visivel()
	if not %Objetivo.visible:
		return
	var d: Dictionary = ob.tipo_def(ob.id)
	var cor: Color = ob.cor_de(ob.id)
	var det := ("%d/%d s" if str(ob.id) == "pira" else "%d/%d") % [int(ob.prog), int(ob.alvo)]
	if ob.est == ob.CUMPRIDO:
		cor = Color(0.5, 1.0, 0.6)
		det = tr("HUD_CUMPRIDO")
	elif ob.est == ob.FALHOU:
		cor = Color(1.0, 0.45, 0.4)
		det = tr("HUD_FALHOU")
	else:
		det += "   %02d:%02d" % [int(ob.resta) / 60, int(ob.resta) % 60]
	var pulso := 0.8 + 0.2 * sin(_t * 5.0) if ob.est < ob.CUMPRIDO else 1.0
	%ObjNome.text = str(d.get("nome", ""))
	_cor_txt(%ObjNome, Color(cor, pulso))
	_cor_barra(%ObjBarra, Color(cor, 0.9))
	%ObjBarra.value = clampf(ob.prog / maxf(ob.alvo, 0.01), 0.0, 1.0)
	%ObjDet.text = det
	_cor_txt(%ObjDet, Color(0.92, 0.92, 1.0))


## Missão do chefe (#112): nome, barra e texto curto ("Fragmentos 2/4", "Leve ao altar"). Abaixo do objetivo.
func _missao() -> void:
	var ms = arena.missao
	%Missao.visible = ms != null and ms.visivel()
	if not %Missao.visible:
		return
	var cor: Color = ms.cor_de(ms.id)
	if ms.est == ms.CUMPRIDO:
		cor = Color(0.5, 1.0, 0.6)
	elif ms.est == ms.FALHOU:
		cor = Color(1.0, 0.45, 0.4)
	var tx: Array = ms.texto()
	var pulso := 0.8 + 0.2 * sin(_t * 5.0) if ms.est == ms.ANDAMENTO else 1.0
	%MisNome.text = str(tx[0])
	_cor_txt(%MisNome, Color(cor, pulso))
	_cor_barra(%MisBarra, Color(cor, 0.9))
	%MisBarra.value = float(tx[2])
	%MisDet.text = str(tx[1])
	_cor_txt(%MisDet, Color(0.92, 0.92, 1.0))


func _duelo() -> void:
	var d: Node2D = arena.duelo
	var hpmax: float = arena.stat("vida_max")
	_cor_barra(%DueloVida, Interface.cor("vida_duelo"))
	%DueloVida.value = clampf(arena.jogador.hp / hpmax, 0.0, 1.0)
	%DueloVidaTxt.text = "%d / %d" % [ceili(arena.jogador.hp), int(hpmax)]
	%Vivos.text = tr("HUD_DUELO_VIVOS") % d.vivos().size()
	var f: float = d.fracao_anel()
	var anel := ""
	if d.estado == "luta":
		anel = (
			tr("HUD_DUELO_ANEL_FECHANDO")
			if f > 0.0 and f < 1.0
			else (
				tr("HUD_DUELO_ANEL_FINAL")
				if f >= 1.0
				else tr("HUD_DUELO_ANEL_COMECA") % maxi(1, ceili(float(d.cfg.get("arena", {}).get("inicio_encolher", 12)) - d.t_luta))
			)
		)
	%Anel.text = anel
	_cor_txt(%Anel, Color(1, 0.7, 0.6, 0.8))
	%Aviso.visible = d.estado == "luta" and arena.jogador.centro().distance_to(d.centro) > d.raio and d.lut_jogador.vivo and int(_t * 6) % 2 == 0
	# lista de lutadores (canto direito): uma linha por lutador, refeita só se o número mudar
	var lut: Array = d.lutadores
	if lut.size() != _lut_n:
		_lut_n = lut.size()
		for c in %Lutadores.get_children():
			c.queue_free()
		for l in lut:
			var linha := HBoxContainer.new()
			linha.add_theme_constant_override("separation", 4)
			var nome := Label.new()
			nome.custom_minimum_size = Vector2(66, 0)
			linha.add_child(nome)
			var barra := ProgressBar.new()
			barra.show_percentage = false
			barra.max_value = 1.0
			barra.custom_minimum_size = Vector2(40, 5)
			barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			linha.add_child(barra)
			linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
			%Lutadores.add_child(linha)
	for i in lut.size():
		if i >= %Lutadores.get_child_count():
			break
		var l = lut[i]
		var cor: Color = l.cor if l.vivo else Color(0.45, 0.45, 0.5)
		var linha := %Lutadores.get_child(i)
		var nome: Label = linha.get_child(0)
		var barra: ProgressBar = linha.get_child(1)
		nome.text = str(l.nome).left(8)
		_cor_txt(nome, cor)
		_cor_barra(barra, cor)
		barra.value = d._hp_frac(l) if l.vivo else 0.0


# ---------- build, habilidades e consumíveis ----------


func _novo_slot(lado: float) -> Control:
	var s: Control = Slot.new()
	s.custom_minimum_size = Vector2(lado, lado)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Armas, passivos, equipamentos e dádivas: um quadradinho por item, numa faixa só que quebra de linha. Só refaz quando algo muda.
func _build() -> void:
	var itens: Array = []
	for a in arena.armas.lista:
		var d := Dados.item(a.id)
		var evo: bool = d.get("evolucao", false)
		itens.append(
			{
				"tex": Dados.icone(str(d.get("icone", a.id))),
				"borda": Color(1, 0.8, 0.3, 0.9) if evo else Color(0.2, 0.2, 0.28, 0.9),
				"sup": str(a.nivel) if not evo and a.nivel > 0 else "",
				"cor_sup": Color(1, 1, 0.6)
			}
		)
	for id in arena.passivos:
		itens.append(
			{
				"tex": Dados.icone(str(Dados.item(id).get("icone", id))),
				"borda": Color(0.2, 0.2, 0.28, 0.9),
				"sup": str(arena.passivos[id]),
				"cor_sup": Color(1, 1, 0.6)
			}
		)
	for slot in arena.equipamentos:  # equipamentos vestidos (sem número de nível)
		var eid: String = arena.equipamentos[slot]
		itens.append({"tex": Dados.icone(str(Dados.item(eid).get("icone", eid))), "borda": Color(0.2, 0.2, 0.28, 0.9)})
	var dad: Dictionary = Dados.json("dadivas")
	var defs: Dictionary = dad.get("lista", {}).merged(dad.get("duplas", {}))
	var cfg_d: Dictionary = dad.get("_config", {})
	for dd in arena.descobertas.dadivas:  # dádivas dos santuários: moldura na cor da raridade (dupla: cor própria)
		var cor: Array = (
			cfg_d.get("dupla", {}).get("cor", [1, 1, 1]) if dd.raridade == "dupla" else cfg_d.get("raridades", {}).get(dd.raridade, {}).get("cor", [1, 1, 1])
		)
		itens.append(
			{
				"tex": Dados.icone(str(defs.get(dd.id, {}).get("icone", ""))),
				"borda": Color(Interface.cor_raridade(str(dd.raridade), Color(cor[0], cor[1], cor[2])), 0.9)
			}
		)
	if itens == _build_ult:
		return
	_build_ult = itens
	for c in %Build.get_children():
		c.queue_free()
	for it in itens:
		var s := _novo_slot(18.0)
		%Build.add_child(s)
		s.definir(it)


## Slot 1 = especial do herói (retrato, relógio de recarga, tecla); slot 2 fica vazio até o Marco 6.
func _habilidades() -> void:
	var e = arena.especial
	if e == null or not e.tem():
		%Hab1.definir({"vazio": true})
		%HabNome.visible = false
	else:
		var pronto: bool = e.pronto()
		var borda := Color(0.35, 0.38, 0.5)
		if pronto:
			borda = Color(1, 0.85, 0.35).lerp(Color(1, 1, 0.8), 0.5 + 0.5 * sin(_t * 6.0))
		var pad := not Input.get_connected_joypads().is_empty()
		var tecla := "Y" if pad else "E"
		%Hab1.definir(
			{
				"tex": Dados.tex_personagem(str(arena.heroi.get("sprite", arena.heroi_id)), "rosto"),
				"borda": borda,
				"tom": Color.WHITE if pronto else Color(0.55, 0.55, 0.6),
				"inf": tecla,
				"recarga": 0.0 if pronto else e.recarga / e.recarga_total(),
				"sup": "" if pronto else str(ceili(e.recarga))
			}
		)
		%HabNome.visible = true
		%HabNome.text = tecla + ": " + str(e.d.get("nome", ""))
		_cor_txt(%HabNome, Color(1, 0.9, 0.5) if pronto else Color(0.65, 0.68, 0.78))
	%Hab2.definir({"vazio": true})


## Consumíveis da mochila (#72): um quadro por item com ícone, tecla e quantos restam; a poção ativa mostra uma barrinha de
## tempo; a comida e o amuleto aparecem pequenos em cima. No controle, L3 usa o escolhido e R3 troca.
func _provisoes() -> void:
	var p = arena.provisoes
	if p == null:
		return
	var pad := not Input.get_connected_joypads().is_empty()
	if _prov.size() != p.slots.size():
		for s in _prov:
			s.queue_free()
		_prov.clear()
		for i in p.slots.size():
			var s := _novo_slot(24.0)
			%Provisoes.add_child(s)
			_prov.append(s)
	for i in _prov.size():
		var id := str(p.slots[i])
		var n := int(p.restantes.get(id, 0))
		var escolhido: bool = pad and i == p.sel
		_prov[i].definir(
			{
				"item": id,
				"apagado": n <= 0,
				"borda": Color(1, 0.85, 0.35) if escolhido else (Color(0.4, 0.45, 0.6) if n > 0 else Color(0.2, 0.2, 0.26)),
				"sup": "x%d" % n,
				"cor_sup": Color(1, 1, 1) if n > 0 else Color(0.5, 0.5, 0.55),
				"inf": "L3" if escolhido else str(i + 1),
				"cor_inf": Color(0.8, 0.82, 0.9) if n > 0 else Color(0.4, 0.4, 0.45)
			}
		)
	var ef: Array = []
	for b in p.buffs:
		var d: Dictionary = Mochila.item(str(b.id))
		ef.append({"item": str(b.id), "barra": clampf(b.t / b.tmax, 0.0, 1.0), "cor_barra": Color(float(d.cor[0]), float(d.cor[1]), float(d.cor[2]))})
	for id in p.comidas_ativas():
		ef.append({"item": str(id)})
	if p.amuleto != "":
		ef.append({"item": str(p.amuleto), "apagado": p.fenix_gasta})
	while _buffs.size() < ef.size():
		var s := _novo_slot(16.0)
		%Buffs.add_child(s)
		_buffs.append(s)
	for i in _buffs.size():
		_buffs[i].visible = i < ef.size()
		if i < ef.size():
			_buffs[i].definir(ef[i])


# ---------- conjuntos (só o banner), mensagens e anúncio ----------


func _conjuntos() -> void:
	var atual := {}
	for l in arena.conj_resumo:
		atual[l.etq] = int(l.ativo)
	if _t > 0.5:  # nos primeiros instantes a build inicial acende conjuntos sem o jogador ter feito nada
		for l in arena.conj_resumo:
			if int(l.ativo) > int(_conj_ult.get(l.etq, 0)):
				banner_conjunto(str(l.nome), str(l.texto), l.cor)
				break
	_conj_ult = atual
	%Banner.visible = _banner_t > 0.0
	%Banner.modulate.a = clampf(_banner_t * 2.0, 0.0, 1.0)


func _mensagens() -> void:
	for i in MAX_MSGS:
		var l: Label = _msg_lbl[i]
		l.visible = i < _msgs.size()
		if l.visible:
			var m: Dictionary = _msgs[i]
			l.text = m.txt
			l.add_theme_color_override("font_color", Color(m.cor, clampf(m.t * 2, 0, 1)))
	%Anuncio.visible = _anuncio.t > 0.0
	if %Anuncio.visible:
		%Anuncio.text = _anuncio.txt
		_cor_txt(%Anuncio, Color(_anuncio.cor, clampf(_anuncio.t, 0, 1)))


# ---------- pausa ----------


func pausar() -> void:
	_pausado = true
	_op_pausa = 0
	_quadro_pausa = Engine.get_process_frames()
	_mouse_ult = raiz.get_local_mouse_position()
	get_tree().paused = not arena.eh_online  # no online o jogo dos outros não para
	%Versao.text = Dados.texto_versao()
	%Pausa.visible = true
	_hud_antes_pausa = visible
	visible = true  # a abertura da fase esconde o HUD (e com ele o menu da pausa): a pausa tem que aparecer
	_mostra_abertura(false)
	_pausa_texto()
	Som.ui("abrir")


## A abertura da fase é uma layer (7) acima da pausa (5): sem isto, o título da entrada aparece por cima do véu.
## Enquanto a pausa estiver aberta a abertura fica escondida; ao retomar ela volta de onde parou.
func _mostra_abertura(v: bool) -> void:
	if arena and arena.abertura:
		arena.abertura.visible = v


## Opção "Pausar ao sair da janela": trocou de janela (alt-tab) no meio da partida, pausa sozinho.
func _notification(what: int) -> void:
	# headless não tem janela: não há foco real a respeitar (o CI e os testes rodam assim)
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or not Config.v("pausar_fora") or arena == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	if not arena.bot and not arena.eh_online and not _pausado and not arena.cartas.aberto() and arena.jogador and arena.jogador.hp > 0:
		pausar()


func _pausa_rotulos() -> Array:
	var desistir := tr("HUD_DESISTIR_CRIADO") if Criacao.eh_criado(arena.heroi_id) else tr("HUD_DESISTIR")  # herói criado: desistir conta como morrer
	return [tr("HUD_CONTINUAR"), tr("HUD_OPCOES"), desistir]


func _pausa_texto() -> void:
	if arena == null:
		return
	var rot := _pausa_rotulos()
	for i in _op_lbl.size():
		var sel := i == _op_pausa
		_op_lbl[i].text = ("> " if sel else "") + str(rot[i])
		_cor_txt(_op_lbl[i], Color(1, 0.9, 0.4) if sel else Color(0.8, 0.8, 0.8))


func _pausa_rects() -> Array:
	var r := []
	for l in _op_lbl:
		r.append(l.get_global_rect())
	return r


func _retomar() -> void:
	_pausado = false
	%Pausa.visible = false
	visible = _hud_antes_pausa
	_mostra_abertura(true)
	get_tree().paused = false
	Som.ui("voltar")


func _pausa_confirmar() -> void:
	match _op_pausa:
		0:
			_retomar()
		1:
			Som.ui("confirmar")
			_opcoes = TelaOpcoes.new()
			add_child(_opcoes)
			_opcoes.fechou.connect(
				func():
					_opcoes = null
					_quadro_pausa = Engine.get_process_frames()
			)  # o Esc que fechou as Opções não fecha a pausa junto
		2:
			_pausado = false
			%Pausa.visible = false
			get_tree().paused = false
			arena.desistir()


func _process(_dt: float) -> void:
	var _pp := Perf.ini()
	_process_i(_dt)
	Perf.fim("hud_p", _pp)


func _process_i(_dt: float) -> void:
	if not is_equal_approx(_fator, Config.fator_fonte()):  # a opção mudou (inclusive com o jogo pausado)
		_aplicar_fonte()
	if not _pausado or _opcoes or Engine.get_process_frames() == _quadro_pausa:
		return
	var n := _op_lbl.size()
	var mp := raiz.get_local_mouse_position()
	if mp != _mouse_ult:  # passar o mouse por cima escolhe (só se ele se mexeu)
		_mouse_ult = mp
		var q := Interface.quem(_pausa_rects(), mp)
		if q >= 0 and q != _op_pausa:
			_op_pausa = q
			Som.ui("cursor")
			_pausa_texto()
	if Input.is_action_just_pressed("cima"):
		_op_pausa = (_op_pausa - 1 + n) % n
		Som.ui("cursor")
		_pausa_texto()
	elif Input.is_action_just_pressed("baixo"):
		_op_pausa = (_op_pausa + 1) % n
		Som.ui("cursor")
		_pausa_texto()
	elif Input.is_action_just_pressed("voltar"):
		_retomar()
	elif Input.is_action_just_pressed("confirmar"):
		_pausa_confirmar()


## Esc/Start abre a pausa. Só chega aqui o Esc que ninguém consumiu: o que fecha o chat, a loja, o mapa ou o resultado não abre a pausa junto.
func _unhandled_input(e: InputEvent) -> void:
	if arena and e.is_action_pressed("voltar") and not e.is_echo() and not _pausado and not arena.acabou and not arena.cartas.aberto():
		get_viewport().set_input_as_handled()
		pausar()


func _input(e: InputEvent) -> void:
	if not _pausado or _opcoes or Engine.get_process_frames() == _quadro_pausa or not Interface.clique(e):
		return
	var q := Interface.quem(_pausa_rects(), raiz.get_local_mouse_position())
	if q >= 0:
		_op_pausa = q
		get_viewport().set_input_as_handled()
		_pausa_confirmar()
