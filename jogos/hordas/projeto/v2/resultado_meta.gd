extends CanvasLayer

const Paleta := preload("res://v2/paleta.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
## Resultado da partida com as almas da v2 (camada 12, por cima da tela de resultado de telas.gd, que não é tocada). Quando a
## partida acaba (o herói cai, ou o sinal partida_terminou do mundo, se existir), grava a partida em v2/meta.gd e mostra as almas
## ganhas subindo e o saldo somando; as conquistas cumpridas aparecem embaixo. "CONTINUAR" (clique, Enter, Espaço, E ou A) vai
## para o salão do personagem (v2/salao.tscn). Durante a partida, as conquistas de tempo e de combo viram um aviso no alto. O mouse não
## chega nos Controls de dentro do SubViewport, então o clique não passa por botão: é qualquer clique, lido aqui.
## Criada pelo mundo.gd (uma linha no _ready, fora do modo de teste); o mundo entrega a entrada a ela antes da tela de resultado.

const Meta := preload("res://v2/meta.gd")
const VitoriaFinal := preload("res://v2/vitoria_final.gd")
const LARG := 960
const ALT := 540
const SANTUARIO := "res://v2/salao.tscn"
const TEMPO_ANIM := 1.4  # s para as almas subirem até o total
const TEMPO_ACEITA := 0.8  # s antes de aceitar continuar (evita o clique de quem estava segurando o golpe)
const TEMPO_AVISO := 2.6
const MAX_NOVAS := 6  # conquistas que cabem embaixo das almas (três linhas de duas)
const DANO_LINHAS := 5  # golpes no quadro "dano por golpe" (os maiores; o resto soma em "outros" só no total)
const DANO_X := 500.0
const DANO_LARG := 380.0
const TAM_TITULO := Paleta.TITULO_GRANDE
const TAM_TEXTO := Paleta.TEXTO_TAMANHO
const COR_OURO := Paleta.OURO
const COR_ALMA := Paleta.ALMA

var mundo
var aberto := false
var _terminou := false
var _saindo := false
var _t := 0.0
var _antes := 0
var _ganhas := 0
var _premios := 0  # almas de prêmio das conquistas novas (Meta.registrar_partida.premios)
var _save_ok := true
var _tocou := false
var _checa_t := 0.0
var _aviso_t := 0.0

var _fundo: ColorRect
var _res: Control
var _titulo: Label
var _linhas: Label
var _valores: Label
var _almas_tit: Label
var _almas_num: Label
var _saldo: Label
var _novas: Label
var _botao: Control
var _aviso: Label
var _dano_tit: Label
var _dano_nomes: Array[Label] = []
var _dano_pct: Array[Label] = []
var _dano_barras: Array[ColorRect] = []
var _dano_fundos: Array[ColorRect] = []


func montar(m) -> void:
	mundo = m
	layer = 12  # por cima do HUD (camada 10): o resultado não divide a tela com o painel da partida
	_fundo = ColorRect.new()
	_fundo.color = Paleta.alfa(Paleta.PAINEL, 0.97)  # quase opaco: o HUD e o mundo ficam só de pano de fundo
	EscalaUi.cobrir(_fundo)  # cobre o canvas inteiro, não só o bloco 960x540
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.visible = false
	add_child(_fundo)
	_res = Control.new()
	_res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res.visible = false
	add_child(_res)
	_titulo = _rotulo("", TAM_TITULO, true, Paleta.PERIGO, HORIZONTAL_ALIGNMENT_CENTER)
	_titulo.position = Vector2(0, 52)
	_titulo.size = Vector2(LARG, 72)
	_res.add_child(_titulo)
	_linhas = _rotulo("Tempo\nAbates\nMaior combo\nNível", TAM_TEXTO, false, Paleta.TEXTO_SECUNDARIO, HORIZONTAL_ALIGNMENT_LEFT)
	_linhas.position = Vector2(90, 150)
	_linhas.size = Vector2(230, 140)
	_linhas.add_theme_constant_override("line_spacing", 12)
	_res.add_child(_linhas)
	_valores = _rotulo("", TAM_TEXTO, false, Paleta.VALOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_valores.position = Vector2(220, 150)
	_valores.size = Vector2(230, 140)
	_valores.add_theme_constant_override("line_spacing", 12)
	_res.add_child(_valores)
	_montar_dano()
	_almas_tit = _rotulo("ALMAS GANHAS", Paleta.TITULO_MEDIO, true, COR_ALMA, HORIZONTAL_ALIGNMENT_CENTER)
	_almas_tit.position = Vector2(0, 302)
	_almas_tit.size = Vector2(LARG, 40)
	_res.add_child(_almas_tit)
	_almas_num = _rotulo("+0", Paleta.TITULO_GRANDE, true, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER)
	_almas_num.position = Vector2(0, 340)
	_almas_num.size = Vector2(LARG, 64)
	_res.add_child(_almas_num)
	_saldo = _rotulo("", TAM_TEXTO, false, Paleta.TEXTO, HORIZONTAL_ALIGNMENT_CENTER)
	_saldo.position = Vector2(0, 408)
	_saldo.size = Vector2(LARG, 20)
	_res.add_child(_saldo)
	_novas = _rotulo("", TAM_TEXTO, false, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER)
	_novas.position = Vector2(24, 432)
	_novas.size = Vector2(LARG - 48, 50)  # três linhas de 16 px, com 1 px entre elas e 8 px livres até CONTINUAR
	_novas.add_theme_constant_override("line_spacing", 1)
	_res.add_child(_novas)
	_botao = Control.new()
	_botao.position = Vector2(300, 490)
	_botao.size = Vector2(360, 40)
	_botao.modulate.a = 0.0
	_botao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caixa := Panel.new()
	caixa.size = _botao.size
	caixa.add_theme_stylebox_override("panel", _estilo_botao())
	_botao.add_child(caixa)
	var txt := _rotulo("CONTINUAR", TAM_TEXTO, false, Paleta.FOCO, HORIZONTAL_ALIGNMENT_CENTER)
	txt.position = Vector2(0, 10)
	txt.size = _botao.size
	_botao.add_child(txt)
	_res.add_child(_botao)
	_aviso = _rotulo("", Paleta.TITULO_MEDIO, true, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER)
	_aviso.position = Vector2(0, 96)
	_aviso.size = Vector2(LARG, 40)
	_aviso.visible = false
	add_child(_aviso)
	if mundo.has_signal("partida_terminou"):
		mundo.connect("partida_terminou", _ao_terminar)


## O quadro "dano por golpe" (à direita dos números): nome, % do total e uma barra por golpe, do maior para o menor.
func _montar_dano() -> void:
	_dano_tit = _rotulo("DANO POR GOLPE", TAM_TEXTO, false, Paleta.TEXTO_SECUNDARIO, HORIZONTAL_ALIGNMENT_LEFT)
	_dano_tit.position = Vector2(DANO_X, 128)
	_dano_tit.size = Vector2(DANO_LARG, 20)
	_res.add_child(_dano_tit)
	for i in DANO_LINHAS:
		var y := 152.0 + i * 28.0
		var nome := _rotulo("", TAM_TEXTO, false, Paleta.TEXTO, HORIZONTAL_ALIGNMENT_LEFT)
		nome.position = Vector2(DANO_X, y)
		nome.size = Vector2(DANO_LARG - 80, 20)
		nome.clip_text = true
		_res.add_child(nome)
		var pct := _rotulo("", TAM_TEXTO, false, Paleta.VALOR, HORIZONTAL_ALIGNMENT_RIGHT)
		pct.position = Vector2(DANO_X + DANO_LARG - 80, y)
		pct.size = Vector2(80, 20)
		_res.add_child(pct)
		var fundo := ColorRect.new()
		fundo.color = Paleta.alfa(Paleta.BORDA, 0.6)
		fundo.position = Vector2(DANO_X, y + 20)
		fundo.size = Vector2(DANO_LARG, 3)
		fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_res.add_child(fundo)
		var barra := ColorRect.new()
		barra.color = COR_OURO if i == 0 else Paleta.FOCO
		barra.position = fundo.position
		barra.size = Vector2(0, 3)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_res.add_child(barra)
		_dano_nomes.append(nome)
		_dano_pct.append(pct)
		_dano_fundos.append(fundo)
		_dano_barras.append(barra)


## Preenche o quadro com o ranking do combate (combate.ranking_dano). Sem dano nenhum, o quadro some.
func _mostrar_dano() -> void:
	var lista: Array = mundo.combate.ranking_dano() if mundo.combate != null else []
	_dano_tit.visible = not lista.is_empty()
	for i in DANO_LINHAS:
		var tem := i < lista.size()
		_dano_nomes[i].visible = tem
		_dano_pct[i].visible = tem
		_dano_fundos[i].visible = tem
		_dano_barras[i].visible = tem
		if not tem:
			continue
		var d: Dictionary = lista[i]
		_dano_nomes[i].text = "%s  %s" % [str(d.nome), _curto(float(d.dano))]
		_dano_pct[i].text = "%d%%" % roundi(float(d.frac) * 100.0)
		_dano_barras[i].size.x = 0.0
		_dano_barras[i].set_meta("alvo", DANO_LARG * float(lista[i].dano) / maxf(float(lista[0].dano), 1.0))  # a barra do maior enche tudo


## 1234 -> "1,2 mil"; 1234567 -> "1,2 mi" (cabe na linha do nome).
static func _curto(v: float) -> String:
	if v >= 1000000.0:
		return ("%.1f mi" % (v / 1000000.0)).replace(".", ",")
	if v >= 1000.0:
		return ("%.1f mil" % (v / 1000.0)).replace(".", ",")
	return str(roundi(v))


func _rotulo(texto: String, tam: int, titulo: bool, cor: Color, alin: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", Dados.fonte_titulo if titulo else Dados.fonte_texto)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Paleta.PRETO)
	l.add_theme_constant_override("outline_size", 4 if titulo else 2)
	l.horizontal_alignment = alin
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo_botao() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Paleta.alfa(Paleta.CARTAO, 0.97)
	s.border_color = COR_OURO
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	return s


# ------------------------------------------------------------------ quadro


func _process(dt: float) -> void:
	if mundo == null or _saindo:
		return
	if _aviso_t > 0.0:
		_aviso_t -= dt
		_aviso.modulate.a = clampf(_aviso_t / 0.5, 0.0, 1.0)
		if _aviso_t <= 0.0:
			_aviso.visible = false
	if aberto:
		_animar(dt)
		return
	# conquistas de tempo e combo acontecem no meio da partida: checa duas vezes por segundo (é uma leitura pequena)
	_checa_t -= dt
	if _checa_t <= 0.0 and not _terminou:
		_checa_t = 0.5
		var novas: Array = Meta.checar_ao_vivo(mundo.tempo_partida, mundo.maior_combo, Meta.vivo_da_partida(mundo))
		if not novas.is_empty():
			_avisar(novas)
	var tela = mundo.combate.telas if mundo.combate != null else null
	if tela != null and tela.resultado_aberto and not _terminou:
		_terminar(_resultado_do_mundo())


func _ao_terminar(r: Dictionary) -> void:
	if not _terminou:
		_terminar(r)


func _resultado_do_mundo() -> Dictionary:
	var r := {
		"tempo": mundo.tempo_partida,
		"abates": mundo.abates,
		"nivel": mundo.heroi.nivel,
		"maior_combo": mundo.maior_combo,
		"venceu": false,
		"almas": Meta.almas_da_partida(mundo),
	}
	r.merge(Meta.vivo_da_partida(mundo))  # herói e evoluções, para as conquistas
	return r


func _terminar(r: Dictionary) -> void:
	_terminou = true
	r["pesadelo"] = mundo.pesadelo()  # o Pesadelo rende mais almas (Meta.registrar_partida)
	if not r.has("mapa") and mundo.get("id_mapa") != null:
		r["mapa"] = str(mundo.id_mapa)  # vencer um mapa abre o seguinte no santuário (vence_<mapa>, dados/v2_progressao.json)
	if not r.has("almas"):
		r["almas"] = Meta.almas_da_partida(mundo)
	var res: Dictionary = Meta.registrar_partida(r)
	_save_ok = not res.is_empty()
	if not _save_ok:
		_antes = Meta.saldo()
		_ganhas = 0
		_mostrar(r, [])
		_almas_tit.text = "NÃO FOI POSSÍVEL SALVAR"
		_almas_num.text = "+0"
		_saldo.text = "Saldo não atualizado"
		return
	_premios = int(res.get("premios", 0))
	_antes = int(res.antes) + _premios  # os prêmios em almas das conquistas já entram no saldo de partida: só as almas da partida sobem
	_ganhas = int(res.ganhas)
	_mostrar(r, res.novas)


func _mostrar(r: Dictionary, novas: Array) -> void:
	aberto = true
	_t = 0.0
	Transicoes.entrar(_fundo, Vector2.ZERO)
	Transicoes.entrar(_res)
	var venceu := bool(r.get("venceu", false))
	_titulo.text = "VITÓRIA" if venceu else "VOCÊ CAIU"
	if bool(r.get("pesadelo", false)):
		_titulo.text += " · PESADELO"
	_titulo.add_theme_color_override("font_color", COR_OURO if venceu else Paleta.PERIGO)
	var seg := int(float(r.get("tempo", 0.0)))
	_valores.text = "%02d:%02d\n%d\nx%d\n%d" % [floori(seg / 60.0), seg % 60, int(r.get("abates", 0)), int(r.get("maior_combo", 0)), int(r.get("nivel", 1))]
	var linhas: Array = []
	# Até seis marcos cabem (três linhas, dois por linha, sem reduzir a fonte). Com mais (a primeira vitória pode trazer herói, abates,
	# nível...), os cinco primeiros aparecem e o sexto vira "+N conquistas": a lista inteira está no Códice.
	var nomes: Array = []
	for id in novas:
		nomes.append("Conquista: " + _nome_conquista(id))
	if nomes.size() > MAX_NOVAS:
		var resto := nomes.size() - (MAX_NOVAS - 1)
		nomes = nomes.slice(0, MAX_NOVAS - 1)
		nomes.append("+%d conquistas" % resto)
	for i in range(0, nomes.size(), 2):
		linhas.append("   ·   ".join(PackedStringArray(nomes.slice(i, i + 2))))
	_novas.text = "\n".join(PackedStringArray(linhas))
	_mostrar_dano()
	_almas_num.text = "+0"
	_saldo.text = "Saldo: %d" % _antes
	mundo.combate.audio.tocar("carta", 0.7, 0.0, 0.0)


func _animar(dt: float) -> void:
	_t += dt
	_botao.modulate.a = clampf((_t - 0.4) / 0.4, 0.0, 1.0)
	var kb := 1.0 - pow(1.0 - clampf(_t / TEMPO_ANIM, 0.0, 1.0), 3.0)
	for b in _dano_barras:  # as barras do dano crescem junto com as almas
		b.size.x = float(b.get_meta("alvo", 0.0)) * kb
	if not _save_ok:
		return
	var k := clampf(_t / TEMPO_ANIM, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)  # sobe rápido e desacelera no fim
	var mostra := roundi(_ganhas * k)
	_almas_num.text = "+%d" % mostra
	_saldo.text = "Saldo: %d" % (_antes + mostra)
	if k >= 1.0 and not _tocou:
		_tocou = true
		mundo.combate.audio.tocar("nivel", 1.0, -4.0, 0.0)


func _avisar(ids: Array) -> void:
	var nomes: Array = []
	for id in ids:
		nomes.append(_nome_conquista(id))
	_aviso.text = "CONQUISTA: " + ", ".join(PackedStringArray(nomes)).to_upper()
	_aviso.visible = true
	_aviso.modulate.a = 1.0
	_aviso_t = TEMPO_AVISO
	if mundo.combate != null:
		mundo.combate.audio.tocar("nivel", 1.0, -2.0, 0.0)


func _nome_conquista(id) -> String:
	for c in Meta.conquistas():
		if c.id == id:
			return str(c.nome)
	return str(id)


# ------------------------------------------------------------------ entrada


## Entrada enquanto a tela de resultado está aberta: consome o que é do jogo (o mundo não anda e a tela de resultado de telas.gd
## não reinicia). Devolve true se usou o evento. Esc passa: aqui o ESC não abre a pausa (pausa.gd não abre no resultado, só com o jogo rolando, na escolha e no baú).
func entrada(e: InputEvent) -> bool:
	if not aberto:
		return false
	if e is InputEventKey and e.keycode == KEY_ESCAPE:
		return false
	var aceita := false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		aceita = true
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		aceita = true
	elif e.is_action_pressed("ui_accept"):
		aceita = true
	if aceita and _t >= TEMPO_ACEITA:
		_continuar()
	return true


func _continuar() -> void:
	if _saindo:
		return
	_saindo = true
	# A entrada do mundo ainda marca o evento no viewport: a troca só pode ocorrer depois dele.
	Transicoes.ir_para(mundo, VitoriaFinal.destino(mundo.resultado, SANTUARIO))  # vencer o mapa final leva à vitória final e aos créditos
