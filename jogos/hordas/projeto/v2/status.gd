extends CanvasLayer
## Card "SUA BUILD" da v2: tudo o que a build faz, em números. Duas partes:
##  1. `Status.coletar(mundo)` (estática, sem desenhar nada, testável) devolve as SEÇÕES do card em dados simples. Os números são os REAIS do
##     jogo: cada um vem do getter do módulo que o usa (heroi.vel_andar, combate.dano_do_passo, armas.numeros, progresso.cura_por_nivel...),
##     nunca de uma fórmula copiada aqui. Cada linha tem `id`, `rotulo`, `valor` (o texto), `bonus` (o que passa da base, em outra cor) e `n`
##     (os números crus, em ordem; é o que o teste v2_status compara com o que o jogo FAZ).
##  2. O desenho: duas colunas coladas nas bordas, com a moldura de pedra do HUD (hud/moldura_pedra.png). Títulos na Jersey 10, texto na
##     Pixelify Sans e NÚMEROS na Press Start 2P (regra do v2/LEIA-ME.md; a Pixelify Sans desenha o 5 como um S e o 7 como um T, o que não
##     serve para um painel de números). Tudo é desenhado num Control só (draw_*): nenhum nó por linha, nenhum nó criado ao atualizar.
## Onde aparece:
##  - na PAUSA (tela "menu"): as duas colunas ladeiam o menu (pausa.gd chama `na_pausa(true/false)`), por cima da pausa (camada 15);
##  - na partida: a tecla C liga e desliga um card compacto no HUD (camada 8: abaixo do HUD). Semitransparente, não pega o mouse, atualiza a
##    4 Hz e só enquanto está visível. A coluna da esquerda fica sob a vida e o fôlego e a da direita sob o minimapa, as duas fora das faixas
##    do HUD (barra do chefe, anúncios, combo, XP): o centro, onde o herói luta, fica livre. C vale também sobre a escolha de cartas e o baú.
## A entrada é `entrada(evento)`, chamada pelo mundo.gd (o SubViewport não recebe a entrada da janela, então este nó não tem _input).
## Criado pelo mundo.gd (uma linha no _ready), que guarda em `mundo.status`.

const Meta := preload("res://v2/meta.gd")
const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
const LAYER_HUD := 8
const LAYER_PAUSA := 15  # acima do menu de pausa (camada 14) e do escurecimento dele
const PERIODO := 0.25  # 4 Hz
const ALFA_HUD := 0.92
const TAM := 12  # texto (Pixelify Sans)
const TAM_NUM := 8  # números (Press Start 2P, a grade de 8 px do HUD)
const TAM_P := 11  # linhas de apoio
const TAM_CAB := 19  # títulos e cabeçalhos (Jersey 10; 19 é a grade da fonte)
const TAM_NOME_PEQ := 14  # nome de golpe que não cabe no 19 (só quando precisa)
const ALT_LINHA := 13.0
const ALT_CAB := 18.0
const ALT_TITULO := 22.0
const PAD := 8.0
const ICONE := 16.0
const JOGO_VIVO := ["jogando", "escolha", "bau"]  # estados do combate em que o C vale
## Colunas de cada modo: x, y, largura e altura máxima. HUD: a da esquerda sob a vida e o fôlego (y 40) e fora da barra do chefe (x até 190);
## a da direita sob o minimapa (que acaba em y 112) e fora da barra do chefe e dos anúncios (x a partir de 772). Pausa: colada nos dois lados
## do menu (que ocupa x 290 a 670).
const COLUNAS_HUD := [Rect2(6, 40, 184, 466), Rect2(772, 118, 182, 388)]
const COLUNAS_PAUSA := [Rect2(8, 14, 274, 512), Rect2(678, 14, 274, 512)]
const SECOES_DA_COLUNA := [["heroi", "partida", "santuario"], ["katana", "golpes"]]
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
var _hud := false  # o jogador ligou o card com C
var _pausa := false  # a pausa pediu o card ao lado do menu
var _meta: Dictionary = {}  # níveis do Santuário, lidos uma vez quando o card abre (o save não muda durante a partida)
var _tela: Control
var _estilo: StyleBoxTexture
var _f_num: Font  # Press Start 2P sem anti-aliasing (como o HUD)
var _re := RegEx.create_from_string("[+\\-]?[0-9]+(?:[,.][0-9]+)?%?")  # um número: sinal, dígitos, decimais e % (vão na fonte dos números)
var _timer: Timer  # o relógio de 4 Hz: só corre com o card visível (sem _process, nada roda por quadro)
var _sem_dicas := false  # a coluna estourou a altura: as dicas de evolução saem primeiro
var _cortou := false  # mesmo sem as dicas não coube: o que sobrou fica de fora, marcado com "..."


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


## C: liga e desliga o card compacto. Devolve true se usou o evento (o mundo.gd o passa antes da escolha de cartas e do baú, que comem as teclas).
func entrada(e: InputEvent) -> bool:
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


func alternar() -> void:
	_hud = not _hud
	_aplicar()


## O card está na tela agora (HUD ligado pelo C, ou ao lado do menu de pausa).
func aberto() -> bool:
	return visible


## A pausa pede o card ao lado do menu (tela "menu") ou o tira (outras telas e fechar). Uma chamada só, de pausa.gd.
func na_pausa(v: bool) -> void:
	var mudou := v != _pausa
	_pausa = v
	if mudou or visible != _quer_ver():
		_aplicar()


## Com a pausa aberta numa tela sem o card (Ajustes, confirmações), o card do HUD também sai: o menu cobre tudo.
func _quer_ver() -> bool:
	return _pausa or (_hud and not get_tree().paused)


func _aplicar() -> void:
	var quer := _quer_ver()
	visible = quer
	if not quer:
		_timer.stop()
		return
	layer = LAYER_PAUSA if _pausa else LAYER_HUD
	_meta = Meta.estado().get("niveis", {})
	_timer.start()
	_recoletar()


## A cada 0,25 s com o card visível: confere se a partida segue de pé e atualiza os números.
func _tique() -> void:
	if _hud and not _pausa and not (mundo != null and mundo.combate != null and str(mundo.combate.jogo) in JOGO_VIVO):
		_hud = false  # a partida acabou (morte, vitória, abandono): o card sai de cena
		_aplicar()
		return
	_recoletar()


func _recoletar() -> void:
	secoes = coletar(mundo, _meta)
	atualizacoes += 1
	# na escolha de cartas e no baú o card fica opaco (a pessoa quer ler); no jogo rolando é semitransparente
	var parado: bool = _pausa or (mundo != null and mundo.combate != null and mundo.combate.pausado)
	_tela.modulate.a = 1.0 if parado else ALFA_HUD
	_tela.queue_redraw()


# ------------------------------------------------------------------ coletar (sem desenhar)


## As seções do card, em dados simples: [{id, titulo, cor, linhas: [...]}]. `meta_niveis` = níveis do Santuário (id -> nível); sem ele, lê o save.
## Linha comum: {tipo "linha", id, rotulo, valor, bonus, n}. Texto solto: {tipo "texto", id, texto, estilo, n}. Bloco (golpe, modificador):
## {tipo "bloco", id, rotulo, icone, cor, nivel_txt, nivel_curto, trechos, curto, dica, n}; `trechos` é a linha de números ([[texto, estilo], ...])
## e `curto` a mesma linha abreviada, para quando a coluna é estreita.
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


static func _l(id: String, rotulo: String, valor: String, n: Array, bonus := "") -> Dictionary:
	return {"tipo": "linha", "id": id, "rotulo": rotulo, "valor": valor, "bonus": bonus, "n": n}


## Número com vírgula decimal ("1,6"); `casas` = casas decimais.
static func _v(v: float, casas := 0) -> String:
	return (("%." + str(casas) + "f") % v).replace(".", ",") if casas > 0 else str(roundi(v))


## "+20%", "+0,5" ou "" (sem bônus): o que passa da base, mostrado em outra cor.
static func _mais(v: float, casas := 0, sufixo := "") -> String:
	if absf(v) < 0.5 * pow(10.0, -casas):
		return ""
	return "+" + _v(v, casas) + sufixo


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
	lin.append(_l("heroi.cura", "Cura por nível", "+%d (%s%%)" % [roundi(cura), _v(frac)], [cura, frac]))
	lin.append(_l("heroi.andar", "Andar", "%d px/s" % roundi(h.vel_andar()), [h.vel_andar()], _mais((h.m_vel_mov - 1.0) * 100.0, 0, "%")))
	lin.append(_l("heroi.correr", "Correr", "%d px/s" % roundi(h.vel_correr()), [h.vel_correr()]))
	lin.append(_l("heroi.folego", "Fôlego", "%s cargas" % _v(h.folego_max, 1), [h.folego_max], _mais(h.folego_max - float(cfg.folego.max), 1)))
	lin.append(_l("heroi.recupera", "Recupera parado", "%s/s" % _v(rp, 1), [rp]))
	lin.append(_l("heroi.recupera_andando", "Recupera andando", "%s/s" % _v(ra, 1), [ra]))
	lin.append(_l("heroi.ima", "Ímã de almas", "%d px" % roundi(h.alcance_ima()), [h.alcance_ima()], _mais((h.m_ima - 1.0) * 100.0, 0, "%")))
	lin.append(_l("heroi.nivel", "Nível", "%d · XP %d/%d" % [h.nivel, roundi(h.xp), roundi(h.xp_proximo)], [h.nivel, h.xp, h.xp_proximo]))
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
	var duracao := 0.0
	for i in passos.size():
		var p: Dictionary = passos[i]
		danos.append(c.dano_do_passo(p))
		alcances.append(c.alcance_do_passo(p))
		t_danos.append(str(roundi(c.dano_do_passo(p))))
		t_alc.append(str(roundi(c.alcance_do_passo(p))))
		duracao += h.duracao_do_passo(i)
	var chance: float = c.chance_critico()
	var mult := float(cfg.golpe.critico.mult)
	var lin: Array = []
	lin.append(_l("katana.dano", "Dano", " / ".join(t_danos), danos, _mais((h.m_dano - 1.0) * 100.0, 0, "%")))
	lin.append(_l("katana.vel", "Vel. de ataque", _mais((h.m_vel_ataque - 1.0) * 100.0, 0, "%") if h.m_vel_ataque != 1.0 else "base", [h.m_vel_ataque]))
	lin.append(_l("katana.combo", "Combo completo", "%s s" % _v(duracao, 2), [duracao]))
	lin.append(_l("katana.alcance", "Alcance", " / ".join(t_alc) + " px", alcances))
	lin.append(_l("katana.area", "Área do corte", _mais((h.m_area - 1.0) * 100.0, 0, "%") if h.m_area != 1.0 else "base", [h.m_area]))
	lin.append(_l("katana.critico", "Crítico", "%s%% · x%s" % [_v(chance * 100.0), _v(mult, 1)], [chance, mult], _mais(h.m_critico * 100.0, 0, "%")))
	var cs = c.cartas
	var ar = c.armas
	var passo_corte: Dictionary = passos[0]
	var passo_estocada: Dictionary = passos[passos.size() - 1]
	for md in ["onda", "fura", "explode", "folego"]:
		var valor := float(ar.mods[md])
		if valor <= 0.0:
			continue
		var d: Dictionary = cs.definicao(md)
		var nivel: int = cs.nivel_de(md)
		var tr: Array = []
		var curto: Array = []
		var n: Array = [valor]
		match md:
			"onda":
				var pct: float = ar.pct_onda()
				var dano_onda: float = c.dano_do_passo(passo_corte) * pct / 100.0
				n = [pct, dano_onda]
				tr = [[_v(pct), 1], ["% do corte (", 0], [str(roundi(dano_onda)), 1], [" de dano)", 0]]
				curto = [[_v(pct), 1], ["% do corte (", 0], [str(roundi(dano_onda)), 1], [")", 0]]
			"fura":
				var dano_lanca: float = c.dano_do_passo(passo_estocada) * valor / 100.0
				var lancas := 1 if ar.ventania.is_empty() else 3
				n = [valor, dano_lanca, lancas]
				tr = [[_v(valor), 1], ["% da estocada (", 0], [str(roundi(dano_lanca)), 1], [" de dano)", 0]]
				curto = [[_v(valor), 1], ["% da estocada (", 0], [str(roundi(dano_lanca)), 1], [")", 0]]
				if lancas > 1:
					tr.append([" x3 em leque", 0])
					curto.append([" x3", 0])
			"explode":
				tr = [[_v(valor), 1], ["% do dano do crítico, em área", 0]]
				curto = [[_v(valor), 1], ["% do crítico, em área", 0]]
			"folego":
				tr = [[_v(valor), 1], ["% de uma carga por abate", 0]]
				curto = [[_v(valor), 1], ["% de carga por abate", 0]]
		var nivel_txt := "nv %d/%d" % [nivel, int(d.max)]
		lin.append(
			_bloco(
				"katana." + str(md),
				str(d.nome),
				str(d.get("icone", "")),
				Color(0.8, 0.95, 1.0),
				nivel_txt,
				"%d/%d" % [nivel, int(d.max)],
				tr,
				curto,
				_dica_evolucao(cs, str(md)),
				n
			)
		)
	if not ar.ventania.is_empty():
		var ev: Dictionary = ar.ventania
		var tr_v: Array = [["onda x", 0], [_v(float(ev.mult_onda), 1), 1], [", lanças em leque", 0]]
		var cor_v := Color(ev.cor[0], ev.cor[1], ev.cor[2])
		lin.append(
			_bloco("katana.ventania", str(ev.nome), str(cs.definicao("onda").get("icone", "")), cor_v, "evoluída", "evo", tr_v, tr_v, "", [float(ev.mult_onda)])
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
		var icone := ""
		var nivel_txt := ""
		var nivel_curto := ""
		if bool(a.evo):
			for ev in cs.cfg.evolucoes:
				if str(ev.id) == str(id):
					nome = str(ev.nome)
					var consumidas: Array = ev.get("consome", [])
					if not consumidas.is_empty():
						icone = str(cs.definicao(str(consumidas[0])).get("icone", ""))
			nivel_txt = "evoluída"
			nivel_curto = "evo"
		else:
			var d: Dictionary = cs.definicao(str(id))
			nome = str(d.nome)
			icone = str(d.get("icone", ""))
			nivel_txt = "nv %d/%d" % [int(a.nivel), int(d.max)]
			nivel_curto = "%d/%d" % [int(a.nivel), int(d.max)]
		var dano := str(roundi(float(nums.dano)))
		var cada := _v(float(nums.intervalo), 2)
		var poder := _v(float(nums.dps))
		var tr: Array = [["dano ", 0], [dano, 1], [" · a cada ", 0], [cada, 1], [" s · poder ", 0], [poder, 1], ["/s", 0]]
		var curto: Array = [[dano, 1], [" dano · ", 0], [cada, 1], [" s · ", 0], [poder, 1], ["/s", 0]]
		var dica := "" if bool(a.evo) else _dica_evolucao(cs, str(id))
		lin.append(_bloco("arma." + str(id), nome, icone, a.cor, nivel_txt, nivel_curto, tr, curto, dica, [nums.dano, nums.intervalo, nums.dps, nums.acertos]))
	if lin.is_empty():
		lin.append({"tipo": "texto", "id": "arma.nenhum", "texto": "Nenhum ainda: eles vêm das cartas.", "estilo": 0, "n": []})
	return _sec("golpes", "GOLPES AUTOMÁTICOS", Color(0.6, 0.8, 1.0), lin)


## "Evolui: Anel de Brasas (falta Lâminas Rodopiantes nv 3)" ou "".
static func _dica_evolucao(cs, id: String) -> String:
	var partes: Array = []
	for e in cs.evolucoes_com(id):
		var falta: Array = e.falta
		if falta.is_empty():
			continue
		partes.append("Evolui: %s (falta %s)" % [e.nome, ", ".join(falta)])
	return "\n".join(partes)


static func _bloco(
	id: String, rotulo: String, icone: String, cor: Color, nivel_txt: String, nivel_curto: String, trechos: Array, curto: Array, dica: String, n: Array
) -> Dictionary:
	return {
		"tipo": "bloco",
		"id": id,
		"rotulo": rotulo,
		"icone": icone,
		"cor": cor,
		"nivel_txt": nivel_txt,
		"nivel_curto": nivel_curto,
		"trechos": trechos,
		"curto": curto,
		"dica": dica,
		"n": n
	}


static func _sec_partida(m) -> Dictionary:
	var c = m.combate
	var cs = c.cartas
	var falta_onda: float = maxf(0.0, c.diretor.proxima_onda - m.tempo_partida)
	var lin: Array = []
	lin.append(_l("partida.tempo", "Tempo", _tempo(m.tempo_partida), [m.tempo_partida]))
	lin.append(_l("partida.abates", "Abates", str(m.abates), [m.abates]))
	lin.append(_l("partida.combo", "Combo", "x%d · maior x%d" % [m.combo, m.maior_combo], [m.combo, m.maior_combo]))
	lin.append(_l("partida.almas", "Almas coletadas", str(m.almas_partida), [m.almas_partida]))
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
	for md in Meta.melhorias():
		var n := int(niveis.get(md.id, 0))
		if n <= 0:
			continue
		lin.append({"tipo": "texto", "id": "santuario." + str(md.id), "texto": Meta.texto_efeito(md, n), "estilo": 3, "n": [float(md.valor) * n]})
	if lin.is_empty():
		lin.append({"tipo": "texto", "id": "santuario.nenhuma", "texto": "Nenhuma melhoria comprada.", "estilo": 0, "n": []})
	return _sec("santuario", "SANTUÁRIO", COR_SANTUARIO, lin)


# ------------------------------------------------------------------ desenho


func _pintar() -> void:
	if secoes.is_empty():
		return
	var rects: Array = COLUNAS_PAUSA if _pausa else COLUNAS_HUD
	var opaco: bool = _pausa or (mundo != null and mundo.combate != null and mundo.combate.pausado)  # na pausa, na escolha e no baú: sem ver o que está atrás
	for c in 2:
		var r := _medir(c)  # também decide se as dicas de evolução cabem (_sem_dicas)
		if opaco:
			_tela.draw_rect(r, COR_FUNDO_OPACO)
		_tela.draw_style_box(_estilo, r)
		_coluna(c, rects[c], false)


## Os retângulos das duas colunas como são desenhadas agora (a altura é a que o conteúdo pede). Os testes conferem que não cobrem o HUD.
func retangulos() -> Array:
	return [_medir(0), _medir(1)]


func _medir(c: int) -> Rect2:
	var r: Rect2 = (COLUNAS_PAUSA if _pausa else COLUNAS_HUD)[c]
	_sem_dicas = false
	var alt := _coluna(c, r, true)
	if alt > r.size.y:  # não coube: as dicas de evolução saem primeiro
		_sem_dicas = true
		alt = _coluna(c, r, true)
	return Rect2(r.position, Vector2(r.size.x, minf(alt, r.size.y)))


## Os ids das linhas cujo texto não cabe na largura da coluna (rótulo, valor e bônus juntos; nome e nível do golpe; mais de 2 linhas de números).
## Vazio = tudo cabe. Os testes conferem isto com uma build cheia, no HUD e na pausa.
func linhas_que_estouram() -> Array:
	var r: Array = []
	var rects: Array = COLUNAS_PAUSA if _pausa else COLUNAS_HUD
	for c in 2:
		var w: float = (rects[c] as Rect2).size.x - 2.0 * PAD
		for id in SECOES_DA_COLUNA[c]:
			for l in _achar(str(id)).get("linhas", []):
				if _estoura(l, w):
					r.append(str(l.id))
	return r


func _estoura(l: Dictionary, w: float) -> bool:
	var f: Font = Dados.fonte_texto
	match str(l.tipo):
		"linha":
			var wb := _larg_misto(str(l.bonus), TAM) + 5.0 if str(l.bonus) != "" else 0.0
			return f.get_string_size(str(l.rotulo), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x + 8.0 + _larg_misto(str(l.valor), TAM) + wb > w
		"texto":
			return _larg_misto(str(l.texto), TAM_P if int(l.estilo) == 3 else TAM) > w
		"bloco":
			var wt := w - ICONE - 4.0
			var nome_w := Dados.fonte_titulo.get_string_size(str(l.rotulo), HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NOME_PEQ).x
			return nome_w + _larg_misto(str(l.nivel_curto), TAM_P) + 8.0 > wt or _linhas_do_bloco(l, wt).size() > 2
	return false


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
			if not _pausa:
				_texto(Dados.fonte_texto, "C fecha", Vector2(x, y + 6.0), w, HORIZONTAL_ALIGNMENT_RIGHT, TAM_P - 1, COR_ROTULO)
		y += ALT_TITULO
	for id in SECOES_DA_COLUNA[c]:
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
		var alt := _altura(l, w)
		if y + alt > limite and not seco:
			_cortou = true  # sem espaço: o que sobrou fica de fora (a coluna avisa com "...")
			return y
		if not seco:
			_item(l, x, y, w)
		y += alt
	return y


func _altura(l: Dictionary, w: float) -> float:
	if str(l.tipo) == "bloco":
		var wt := w - ICONE - 4.0
		var alt := ICONE + 1.0 + 12.0 * float(_linhas_do_bloco(l, wt).size())
		if str(l.dica) != "" and not _sem_dicas:
			alt += _alt_dica(str(l.dica), wt)
		return alt + 3.0
	return ALT_LINHA


func _item(l: Dictionary, x: float, y: float, w: float) -> void:
	match str(l.tipo):
		"linha":
			_desenhar_linha(l, x, y, w)
		"texto":
			var santuario := int(l.estilo) == 3
			_misto(str(l.texto), x, y, TAM_P if santuario else TAM, COR_SANTUARIO if santuario else COR_ROTULO, COR_SANTUARIO if santuario else COR_ROTULO)
		"bloco":
			_desenhar_bloco(l, x, y, w)


func _desenhar_linha(l: Dictionary, x: float, y: float, w: float) -> void:
	var f: Font = Dados.fonte_texto
	var direita := x + w
	var bonus := str(l.bonus)
	if bonus != "":
		_misto(bonus, direita, y, TAM, COR_BONUS, COR_BONUS, true)
		direita -= _larg_misto(bonus, TAM) + 5.0
	_texto(f, str(l.rotulo), Vector2(x, y), w, HORIZONTAL_ALIGNMENT_LEFT, TAM, COR_ROTULO)
	_misto(str(l.valor), direita, y, TAM, COR_ROTULO, COR_VALOR, true)


func _desenhar_bloco(l: Dictionary, x: float, y: float, w: float) -> void:
	var f: Font = Dados.fonte_texto
	var ft: Font = Dados.fonte_titulo
	var ic := str(l.icone)
	if ic != "":
		var tx: Texture2D = Dados.tex(ic)
		if tx != null:
			_tela.draw_texture(tx, Vector2(x, y))
	var xt := x + ICONE + 4.0
	var wt := w - ICONE - 4.0
	var cor: Color = Color(l.cor).lerp(Color.WHITE, 0.35)
	# o nome na Jersey 10 (19) com o nível por extenso (na pausa); no HUD o nível é curto; se o nome e o nível não cabem, o nome encolhe um degrau
	var nome := str(l.rotulo)
	var nivel := str(l.nivel_txt)
	var tam_nome := TAM_CAB
	if wt < 200.0:  # coluna estreita (HUD): o nível sempre curto ("2/5"), igual em todos os golpes
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
		_tela.draw_multiline_string(f, Vector2(xt, yy + f.get_ascent(TAM_P - 1)), str(l.dica), HORIZONTAL_ALIGNMENT_LEFT, wt, TAM_P - 1, 3, COR_DICA)


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
	var f: Font = Dados.fonte_texto
	return minf(f.get_multiline_string_size(dica, HORIZONTAL_ALIGNMENT_LEFT, w, TAM_P - 1).y, 3.0 * 12.0) + 1.0


# ---- texto: a Pixelify Sans para as palavras e a Press Start 2P para os números


## Parte `s` em pedaços: [[texto, é_número], ...]. Número = sinal, dígitos, decimais e % (o "5" da Pixelify Sans parece um S).
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


## Texto simples na Pixelify Sans (sem números): `pos` é o canto de cima da linha (o desenho pede a linha de base).
func _texto(f: Font, s: String, pos: Vector2, w: float, alin: HorizontalAlignment, tam: int, cor: Color) -> void:
	_tela.draw_string(f, Vector2(pos.x, pos.y + f.get_ascent(tam)), s, alin, w, tam, cor)


func _texto_titulo(s: String, pos: Vector2, cor: Color) -> void:
	var f: Font = Dados.fonte_titulo
	_tela.draw_string(f, Vector2(pos.x, pos.y + f.get_ascent(TAM_CAB)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_CAB, cor)
