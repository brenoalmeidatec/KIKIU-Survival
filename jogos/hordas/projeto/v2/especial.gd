extends RefCounted
## O ESPECIAL de cada herói da v2 (tecla Q ou RB do controle), no padrão Overwatch: botão direito = secundário (o escudo, v2/escudo.gd), E = habilidade
## (a ruptura, v2/ruptura.gd), Q = especial. Aperta e dispara na hora. O Q é uma ULTIMATE no estilo Overwatch: NÃO recarrega por tempo. Tem uma carga de
## 0 a 100 pontos (esp_carga) que começa a partida em 0 e enche por DANO CAUSADO (pontos de dano nos monstros, de qualquer fonte: golpe, ruptura, secundário,
## fogo), por bônus de ABATE (comum pequeno, elite grande, chefe muito grande) e um pouco por DANO RECEBIDO. Não enche durante o próprio Q (nem
## logo depois, enquanto as últimas adagas voam), nem com o jogo pausado ou nas cartas. Disparou, a carga volta a 0. Durante o especial o herói fica em
## Estado.ESPECIAL: não golpeia nem corre e é INVULNERÁVEL; a ruptura, o escudo e a esquiva em andamento são cancelados.
##
## Qual especial cada herói tem é DADO (dados/v2_especial.json > padrao e herois > chave do herói), igual ao secundário. Os três de hoje:
##  - INVESTIDA (Hazaki, "Corte Relâmpago"): mostra a linha da direção em que está virado até a borda da tela, dispara UM raio num único quadro que corta tudo na
##    faixa até a borda, atravessa um trecho e fecha com um corte em cruz em volta (ULT-B e D31: com mouse e teclado o raio vai para o cursor; no controle, para onde o herói está virado).
##  - TERREMOTO (Nick): ergue a marreta e bate: pancada enorme em volta, rachaduras e uma onda de choque que sai da batida e varre quem estava longe.
##  - CHUVA (Luke, "Tempestade de Adagas"): gira soltando rodadas de adagas em círculo, andando devagar, e fecha com uma rodada enorme.
##  - CHAMAR (LightWolf em forma de Lobo, LW-2): a carga do Q é o CHAMADO (bloco `carga` próprio no dado). Cheia, o Lobo aperta Q: um aviso de 0,8 s sobre os pés e o
##    mecha cai, ferindo em volta, e o herói volta a Mecha (v2/mecha.gd cuida da troca). Enquanto o aviso corre ele é invulnerável.
##  - AUTODESTRUIÇÃO (LightWolf em forma de mecha, LW-5): o piloto salta para trás da mira e vira Lobo NA HORA (v2/mecha.gd `autodestruir`: invulnerável, chamado em 35, Q gasto), o
##    mecha fica no lugar e acende sem piscar por 1 s (o fusível) e EXPLODE: limpa a tela pela peça comum (`limpar_tela`, com a frente de onda saindo do mecha, não do Lobo) e chama a Maré
##    do LightWolf (anel, atraso 4 s, sempre curta). Só o Lobo sobra: o mecha só volta pelo CHAMAR.
## Todo Q também LIMPA A TELA, menos o CHAMAR do Lobo (ULT-A, `limpar_tela`, dados > comum.limpa e `limpa_em` de cada bloco): comuns morrem aos poucos numa frente de onda (a fila adiada
## é do combate: `combate.limpar_tela` e `combate.drenar_limpa`), elite perde parte da vida e chefe só uma fatia.
## (A Autodestruição TEM `limpa_em`: é a única vez que o mecha limpa a tela, e o custo é o mecha inteiro.)
## O CHAMAR não tem `limpa_em` DE PROPÓSITO: o Lobo o usa a cada ~12 s, e se cada chamado limpasse a tela a quebra viraria vantagem; a queda fere só em volta
## (raio 60). A limpeza do LightWolf é a Autodestruição do Q do mecha (LW-5).
## Id desconhecido deixa a tecla Q sem efeito.
##
## O herói (v2/heroi.gd) cuida da entrada (`especial()`), do estado (Estado.ESPECIAL), da carga e dos campos que o HUD lê (esp_*); este módulo cuida do
## disparo (dano, controle, adagas), do visual (um Node2D aditivo na camada glow, redesenhado só enquanto há algo) e do som. Dono: o combate
## (`combate.especial`). Números em dados/v2_especial.json (veja o `_ajuda` de lá): nada de jogo fica fixo aqui.
##
## API: montar(c, camada), limpar(), id_de(chave), bloco_de(chave), armar(h) [põe os campos esp_* e a carga de começo], iniciar(h) -> bool,
## quadro(h, dt, v) -> deslocamento [chamado pelo herói em Estado.ESPECIAL], cancelar(h), dano(valor) [dano causado a um monstro], recebeu(valor) [dano
## que o herói levou], abate(m), carregar(h, pontos), pronta(h), negou(h), atualizar(dt) [tempo do mundo: a onda do terremoto e a graça pós-Q],
## efeitos(dt) [relógio de parede: o visual].

const Armas := preload("res://v2/armas.gd")
const Heroi := preload("res://v2/heroi.gd")  # Heroi.Fonte: o analógico de mira (STICK) e o controle (Glifos) não seguem o cursor no Q
const Glifos := preload("res://v2/glifos.gd")  # no controle não há cursor: o Q segue o corpo
const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (a mesma da ruptura, do escudo e dos avisos)
const PTS := 40  # pontos da elipse desenhada
const MAX_ANEIS := 10
const FISSURAS := 9
const PONTOS_FISSURA := 6
const RACH_DUR := 0.7  # s da rachadura do terremoto
const RAIO_PTS := 14  # pontos do zigue-zague do raio da investida (gerado uma vez por disparo)
const RAIO_DUR := 0.18  # s que o raio do Hazaki fica na tela
const TIQUE_AUTO := 0.2  # s entre os tiques do fusível da Autodestruição (o tom sobe a cada um)
const COR_NUM := Color(1.0, 0.96, 0.84)
const COR_CRIT := Color(1.0, 0.74, 0.2)
const COR_POEIRA := Color(0.58, 0.5, 0.42, 0.75)

var combate
var mundo
var comum: Dictionary = {}  # dados/v2_especial.json > comum
var padrao := "investida"
var herois: Dictionary = {}  # chave do herói -> id do especial (os testes mexem aqui)
var blocos: Dictionary = {}  # id -> bloco de números
var no: Node2D
var disparos := 0  # testes: quantos especiais saíram
var ultimo: Dictionary = {}  # o último especial (testes): id, n (monstros atingidos no total), mortes
var ondas := 0  # testes: quantas ondas de choque do terremoto saíram
var prontos := 0  # quantas vezes a carga chegou a 100 na partida (o robô de playtest e os testes)
var carga_total := {"dano": 0.0, "abate": 0.0, "recebido": 0.0, "tempo": 0.0}  # pontos de carga ganhos na partida por fonte (calibragem, robô de playtest)
var _graca := 0.0  # s depois do fim do Q em que ainda não carrega (as últimas adagas voando)
var limpa_ligada := true  # a limpeza da tela (ULT-A) liga/desliga por instância (os testes antigos de dano por área desligam)
var limpas := 0  # testes: quantas limpezas saíram
var _limpa_pend := false  # a limpeza deste Q ainda não saiu (espera `limpa_em`)
var explosoes := 0  # testes: quantas autodestruições do mecha explodiram
var _g_tipo: Dictionary = {}  # autodestruição: a folha do mecha que ficou no lugar (o fantasma que acende), com o quadro e o espelhamento do instante do aperto
var _g_regiao := Rect2()
var _g_flip := false
var _g_esc := Vector2.ONE

var _id := ""  # o especial em andamento ("" = nenhum)
var _c: Dictionary = {}  # o bloco dele
var _t := 0.0  # s desde o disparo (tempo do mundo)
var _fase := 0
var _dir := Vector2.RIGHT  # a direção da mira travada no disparo
var _origem := Vector2.ZERO  # onde o herói estava ao disparar (o rastro da investida)
var _alcance := 0.0  # investida: até onde o raio alcança neste disparo (a borda da tela + margem_borda)
var _raio_t := -1.0  # investida: s desde o raio (< 0: ainda não saiu)
var _zig := PackedVector2Array()  # investida: o zigue-zague do raio, gerado uma vez por disparo
var _dash_t := 0.0
var _rastro_t := 0.0
var _tick_t := 0.0
var _giro := 0.0  # ângulo (rad) da próxima rodada de adagas
var _ja: Dictionary = {}  # instance_id -> true: quem este especial já feriu (a faixa e a onda não repetem)
var _n := 0  # monstros atingidos no especial inteiro
var _mortes := 0
var _numeros := 0  # números de dano já mostrados neste pulso
var _escala := 1.0  # a área do herói (cartas) nos raios deste especial
# a onda de choque do terremoto
var _onda_t := -1.0  # s desde que saiu (< 0: nenhuma)
var _onda_c := Vector2.ZERO
var _onda_r0 := 0.0
var _onda_r1 := 0.0
var _onda_dur := 1.0
var _onda_ant := 0.0  # o raio da frente no quadro anterior
var _onda_cfg: Dictionary = {}
var _onda_cor := Color.WHITE
var _onda_lento := 0.0
# anéis (pool em vetores planos)
var a_vivo := PackedByteArray()
var a_pos := PackedVector2Array()
var a_t := PackedFloat32Array()
var a_dur := PackedFloat32Array()
var a_r0 := PackedFloat32Array()
var a_r1 := PackedFloat32Array()
var a_w := PackedFloat32Array()
var a_alfa := PackedFloat32Array()
var a_cor := PackedColorArray()
var _ai := 0
# rachaduras do terremoto
var _rach: Array = []
var _rach_t := -1.0
var _rach_cor := Color.WHITE
var _desenhou := false


func montar(c, camada: Node) -> void:
	combate = c
	mundo = c.mundo
	var d: Dictionary = Dados.json("v2_especial")
	comum = d.comum
	padrao = str(d.get("padrao", "investida"))
	herois = d.get("herois", {})
	for k in d:
		if d[k] is Dictionary and k != "comum" and k != "herois":
			blocos[k] = d[k]
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no = Node2D.new()
	no.material = mat
	no.draw.connect(_desenhar)
	camada.add_child(no)
	a_vivo.resize(MAX_ANEIS)
	a_pos.resize(MAX_ANEIS)
	a_t.resize(MAX_ANEIS)
	a_dur.resize(MAX_ANEIS)
	a_r0.resize(MAX_ANEIS)
	a_r1.resize(MAX_ANEIS)
	a_w.resize(MAX_ANEIS)
	a_alfa.resize(MAX_ANEIS)
	a_cor.resize(MAX_ANEIS)


## Partida nova: nada em andamento, a carga do herói em 0.
func limpar() -> void:
	_id = ""
	_c = {}
	_t = 0.0
	_fase = 0
	_limpa_pend = false
	limpas = 0
	_ja.clear()
	_numeros = 0
	_onda_t = -1.0
	_rach.clear()
	_rach_t = -1.0
	_rastro_t = 0.0
	disparos = 0
	ondas = 0
	prontos = 0
	carga_total = {"dano": 0.0, "abate": 0.0, "recebido": 0.0, "tempo": 0.0}
	_graca = 0.0
	ultimo = {}
	a_vivo.fill(0)
	_desenhou = false
	if no != null:
		no.queue_redraw()
	if mundo != null and mundo.heroi != null:
		armar(mundo.heroi)


## O id do especial do herói `chave` (dados > herois, senão o padrão); "" se o id não tem bloco.
func id_de(chave: String) -> String:
	var id := str(herois.get(chave, padrao))
	return id if blocos.has(id) else ""


## O bloco de números do especial do herói `chave` (vazio se não tem).
func bloco_de(chave: String) -> Dictionary:
	var id := id_de(chave)
	return blocos[id] if id != "" else {}


## Os números de carga do herói de agora: o bloco do Q dele pode trazer `carga` próprio (o chamado do Lobo), senão vale o `comum.carga`.
func _carga_de(h) -> Dictionary:
	var b := bloco_de(str(h.chave))
	return b.carga if b.has("carga") else comum.carga


func _carga_max() -> float:
	return float(comum.carga.max)


## Põe no herói o que o HUD lê (nome, rótulo, cor) e a carga de começo (0): o especial não vem pronto. Chamado quando o herói nasce e quando a
## partida recomeça.
func armar(h) -> void:
	var b := bloco_de(str(h.chave))
	h.esp_invul = false
	h.esp_t = 0.0
	h.esp_nega_t = 0.0
	if b.is_empty():
		h.esp_nome = ""
		h.esp_rotulo = ""
		h.esp_carga = 0.0
		h.esp_carga_max = _carga_max()
		return
	h.esp_nome = str(b.nome)
	h.esp_rotulo = str(b.rotulo)
	h.esp_cor = _cor(b.cor)
	h.esp_carga_max = _carga_max()
	h.esp_carga = minf(float(b.get("inicio", comum.carga.inicio)), h.esp_carga_max)


## Escala a cópia privada do disparo, sem alterar o catálogo compartilhado.
func _escalar_danos(bloco: Dictionary, fator: float) -> void:
	for chave in bloco:
		if chave == "dano":
			bloco[chave] = float(bloco[chave]) * fator
		elif bloco[chave] is Dictionary:
			_escalar_danos(bloco[chave], fator)


## O herói apertou Q e pode: começa o especial com números capturados neste nível.
func iniciar(h) -> bool:
	var id := id_de(str(h.chave))
	if id == "":
		return false
	_id = id
	_c = blocos[id].duplicate(true)
	_escalar_danos(_c, combate.ritmo.multiplicador("q_dano", h.nivel))
	_t = 0.0
	_fase = 0
	_limpa_pend = limpa_ligada and _c.has("limpa_em")
	_ja.clear()
	_n = 0
	_numeros = 0
	_mortes = 0
	_dash_t = 0.0
	_rastro_t = 0.0
	_tick_t = 0.0
	_giro = randf() * TAU
	_escala = (1.0 + (float(h.m_area) - 1.0) * float(comum.area_k)) * combate.ritmo.multiplicador("q_area", h.nivel)
	# a direção é travada no aperto (ULT-B, D31): com mouse e teclado é SEMPRE o cursor ao vivo, seja qual for a última fonte de entrada (andando para um lado com o mouse
	# do outro, o Q vai para o cursor); em GOLPE e HABILIDADE o mouse não vira o corpo, então dir_olhar não serve. No controle (sem cursor: o ponteiro do sistema fica parado
	# e velho) e no analógico de mira (STICK) vale o corpo
	_dir = h.dir_olhar.normalized()
	if h.fonte != Heroi.Fonte.STICK and not Glifos.eh_controle():
		var viva: Vector2 = h.mundo.mouse_mundo() - h.centro()
		if viva.length() > 4.0:
			_dir = viva.normalized()
	if _dir.length_squared() < 0.01:
		_dir = Vector2.RIGHT
	_origem = h.pos
	_raio_t = -1.0
	h.dir_olhar = _dir
	h.esp_t = 0.0
	h.esp_dur = float(_c.dur)
	h.esp_invul = true
	h.esp_anim_passo = int(_c.anim.passo)
	h.esp_anim_ciclos = float(_c.anim.ciclos)
	h.esp_carga_max = _carga_max()
	h.esp_carga = 0.0  # gastou tudo: a próxima ultimate se enche de novo
	disparos += 1
	var cor := _cor(_c.cor)
	var c = combate
	_anel(h.pos, 10.0, 46.0, 0.25, 2.0, cor, 0.9)
	c.fx.luz_rapida(h.pos + Vector2(0, -10), cor, 1.8, 120.0, 0.35)
	c.audio.tocar("ruptura_pronta", 0.8, -2.0, 0.0)
	match id:
		"investida":
			c.audio.tocar("ruptura_tique", 1.4, -4.0, 0.0)
		"terremoto":
			c.audio.tocar("ruptura_carga", 0.7, 0.0, 0.0)
		"chuva":
			c.audio.tocar("ruptura_tique", 1.6, -4.0, 0.0)
		"autodestruicao":
			c.audio.tocar("ruptura_carga", 1.5, -2.0, 0.0)
			_iniciar_autodestruicao(h)
		"chamar":
			c.audio.tocar("ruptura_carga", 1.3, -2.0, 0.0)
			var q: Dictionary = _c.queda  # o aviso: o anel fecha sobre onde o mecha vai cair
			_anel(h.pos, float(q.raio) * 1.8, float(q.raio), float(_c.dur), 2.0, cor, 0.85)
	return true


## O herói em Estado.ESPECIAL (um quadro, tempo do mundo): devolve o deslocamento do quadro e encerra no fim da `dur`.
func quadro(h, dt: float, v: Vector2) -> Vector2:
	if _id == "":
		_encerrar(h)
		return Vector2.ZERO
	var c = combate
	if c.jogo != "jogando" or c.pausado:
		return Vector2.ZERO
	_t += dt
	h.esp_t = _t
	var desl := Vector2.ZERO
	match _id:
		"investida":
			desl = _q_investida(h, dt)
		"terremoto":
			_q_terremoto(h)
		"chuva":
			desl = _q_chuva(h, dt, v)
		"chamar":
			_q_chamar(h)
		"autodestruicao":
			desl = _q_autodestruicao(h, dt)
	if _limpa_pend and _t >= float(_c.limpa_em):
		_limpa_pend = false
		limpar_tela(h, _origem if _id == "autodestruicao" else null)
	if _t >= float(_c.dur):
		_encerrar(h)
	return desl


## A partida acabou (vitória ou derrota) com um especial no ar: desfaz o estado, a invulnerabilidade e a onda, que não andariam mais.
func fim_de_partida() -> void:
	_onda_t = -1.0
	if mundo != null and mundo.heroi != null:
		cancelar(mundo.heroi)


## Desfaz o especial em andamento sem mais efeito (a carga já foi gasta no disparo). Idempotente.
func cancelar(h) -> void:
	if _id == "":
		return
	_encerrar(h)


## Limpar a tela (ULT-A): bloco comum.limpa dos dados. No instante `limpa_em` do Q, a peça do combate marca os comuns da tela (e da margem) e a frente
## de onda os mata aos poucos; elite e chefe levam só uma parte da vida. Um anel que cresce com a frente e UM número "LIMPOU xN" no herói; nenhuma luz de
## tela cheia (o clarão passa pelo helper Piscadas, do UI-2, quando ele existir). A Autodestruição do LightWolf (LW-5) chama esta mesma peça.
## MARÉ (ULT-C): é também AQUI que o Q chama a Maré do herói (diretor.mare_chamar(h)): a tela está limpa e a Maré chega `atraso` s depois.
func limpar_tela(h, de: Variant = null) -> int:
	var c = combate
	var L: Dictionary = comum.limpa
	var centro: Vector2 = h.pos if de == null else de  # de onde a frente de onda sai: do herói, ou do mecha que explodiu (a Autodestruição, LW-5)
	var n: int = c.limpar_tela(centro, L)
	limpas += 1
	var cor: Color = h.esp_cor
	var rmax := Vector2(float(mundo.cam.LARG), float(mundo.cam.ALT)).length() * 0.5 + float(L.margem)
	_anel(centro, 16.0, rmax, rmax / maxf(float(L.vel), 1.0), 3.0, cor.lerp(Color.WHITE, 0.4), 0.55)
	if n > 0:
		c.fx.numero(h.pos + Vector2(0, -52), "LIMPOU x%d" % n, COR_CRIT, true)
	c.audio.tocar("ruptura_disparo", 0.9, -3.0, 0.0)
	c.diretor.mare_chamar(h)
	return n


## A Maré do herói `chave` (ULT-C): o bloco `mare` do Q dele com o `comum.mare` de padrão por baixo. {} se o herói não tem Q.
func mare_de(chave: String) -> Dictionary:
	var id := id_de(chave)
	if id == "":
		return {}
	var m: Dictionary = comum.mare.duplicate()
	var b: Dictionary = blocos[id]
	if b.has("mare"):
		m.merge(b.mare, true)
	return m


func _encerrar(h) -> void:
	ultimo = {"id": _id, "n": _n, "mortes": _mortes}
	_id = ""
	_limpa_pend = false
	_g_tipo = {}
	_graca = float(comum.carga.graca)
	h.esp_invul = false
	h.esp_t = 0.0
	if h.estado == h.Estado.ESPECIAL:
		h.estado = h.Estado.LIVRE
	h.pausa_t = maxf(h.pausa_t, 0.12)  # só impede o golpe um instante, não impede andar


# ------------------------------------------------------------------ o chamado (LightWolf em forma de Lobo)


## O Lobo parado sob o aviso; no fim dele o mecha cai: dano em volta, onda, tremor, e `mecha.chegar` devolve o herói à forma mecha.
func _q_chamar(h) -> void:
	if _fase != 0 or _t < float(_c.dur):
		return
	_fase = 1
	var c = combate
	var q: Dictionary = _c.queda
	var raio := float(q.raio) * _escala
	var cor := _cor(_c.cor)
	_numeros = 0
	_pulso(h, h.pos, raio, float(q.dano), float(q.empurrao), float(q.atordoa), cor, false, float(q.get("chefe_lento", 0.0)))
	c.fx.onda(h.pos, Color(cor.r, cor.g, cor.b, 0.9), raio, 0.3)
	c.fx.onda(h.pos, Color(1, 1, 1, 0.6), raio * 0.6, 0.2)
	_anel(h.pos, raio * 0.2, raio, 0.25, 4.0, cor.lerp(Color.WHITE, 0.3), 1.0)
	c.fx.estouro(h.pos + Vector2(0, -2), Color(0.75, 0.68, 0.55), 12)
	c.fx.luz_rapida(h.pos + Vector2(0, -6), cor, 2.4, 2.8 * raio, 0.35)
	c.audio.tocar("impacto", 0.45, 3.0, 0.0)
	mundo.cam.tremer(float(q.get("tremor", 3.0)), 0.3)
	if _n > 0:
		c.hit_stop(float(q.get("hit_stop", 0.05)))
	c.mecha.chegar(h)


# ------------------------------------------------------------------ a autodestruição (LightWolf em forma de mecha, LW-5)


## O aperto do Q do mecha: guarda o mecha como está (a folha, o quadro e o espelhamento: é ele que fica no lugar e acende), o piloto salta e vira Lobo (v2/mecha.gd) e o
## fusível começa. A troca de forma rearma o Q e solta o estado do herói; o fusível o prende de volta em Estado.ESPECIAL, invulnerável.
func _iniciar_autodestruicao(h) -> void:
	_g_tipo = h.tipo
	_g_regiao = h.regiao
	_g_flip = h.sprite.flip_h
	_g_esc = h.sprite.scale
	if combate.mecha == null or not combate.mecha.autodestruir(h):
		_g_tipo = {}  # herói sem formas (só em teste): o fusível e a explosão saem do mesmo jeito, sem o fantasma do mecha
	h.estado = h.Estado.ESPECIAL
	h.esp_invul = true
	h.esp_t = 0.0
	h.esp_dur = float(_c.dur)
	h.esp_anim_passo = int(_c.anim.passo)
	h.esp_anim_ciclos = float(_c.anim.ciclos)


## Um quadro da Autodestruição (tempo do mundo): o piloto salta para trás da mira nos primeiros `salto.t` s, os tiques sobem de tom e, no fim do fusível, o mecha explode.
## A limpeza da tela sai logo depois, no mesmo quadro (`limpa_em`, em `quadro`), com a frente de onda saindo de onde o mecha ficou.
func _q_autodestruicao(h, dt: float) -> Vector2:
	var dur := maxf(float(_c.dur), 0.001)
	if _fase == 0:
		_tick_t += dt
		if _tick_t >= TIQUE_AUTO:
			_tick_t -= TIQUE_AUTO
			combate.audio.tocar("ruptura_tique", 0.9 + 0.9 * clampf(_t / dur, 0.0, 1.0), -5.0, 0.0)
	var desl := Vector2.ZERO
	var salto: Dictionary = _c.salto
	var st := maxf(float(salto.t), 0.001)
	if _t - dt < st:
		desl = -_dir * (float(salto.distancia) / st) * minf(dt, st - (_t - dt))
	if _fase == 0 and _t >= dur:
		_fase = 1
		_explodir_mecha()
	return desl


## O estouro do mecha no lugar onde ele ficou: ondas, cascos azuis, luz local, um clarão (que respeita "Tremor e clarões"), tremor e uma pausa curta. Nenhum dano aqui: quem limpa a tela
## é a peça comum (`limpar_tela`) e o raio dos dados é só visual.
func _explodir_mecha() -> void:
	var c = combate
	var e: Dictionary = _c.explosao
	var cor := _cor(_c.cor)
	var raio := float(e.raio)
	var centro := _origem + Vector2(0, -16)
	explosoes += 1
	c.fx.onda(centro, Color(cor.r, cor.g, cor.b, 0.95), raio, 0.45)
	c.fx.onda(centro, Color(1, 1, 1, 0.7), raio * 0.6, 0.3)
	c.fx.estouro(centro, Color(0.55, 0.78, 1.0), 34)
	c.fx.luz_rapida(centro, cor, 3.0, raio * 2.5, 0.5)
	c.fx.clarao(Color(cor.r, cor.g, cor.b, float(e.clarao)), 0.25)
	_anel(_origem, raio * 0.2, raio, 0.4, 5.0, cor.lerp(Color.WHITE, 0.5), 1.0)
	c.audio.tocar("impacto", 0.4, 4.0, 0.0)
	c.audio.tocar("ruptura_disparo", 0.6, 0.0, 0.0)
	mundo.cam.tremer(float(e.tremor), 0.4)
	c.hit_stop(float(e.hit_stop))


# ------------------------------------------------------------------ a investida (Hazaki)


func _q_investida(h, dt: float) -> Vector2:
	var c = combate
	var cor := _cor(_c.cor)
	var desl := Vector2.ZERO
	if _raio_t >= 0.0:
		_raio_t += dt
	if _fase == 2:  # o corte final sai um quadro depois do último passo: aí h.pos já é onde o herói parou de verdade (colisão, limites)
		_fase = 3
		_final_investida(h)
	if _fase == 0 and _t >= float(_c.prep):
		_fase = 1
		_origem = h.pos
		c.audio.tocar("esquiva", 1.5, 0.0, 0.0)
		c.audio.tocar("estocada", 1.3, -2.0, 0.0)
		_anel(h.pos, 8.0, 40.0, 0.2, 3.0, Color.WHITE, 0.9)
		_raio(h)  # o raio: um quadro só, ferindo a faixa até a borda da tela; o avanço depois só atravessa
	if _fase == 1:
		var dur_av := float(_c.avanco_t)
		var passo := minf(dt, dur_av - _dash_t)
		_dash_t += dt
		var vel := float(_c.distancia) / dur_av
		desl = _dir * vel * passo
		_rastro_t -= dt
		if _rastro_t <= 0.0:
			_rastro_t = 0.03
			c.fx.flash(h, 0.25, cor, 2)
			for i in maxi(1, roundi(2.0 * c.fx.fator_part)):
				c.fx.particula(
					h.pos + Vector2(randf_range(-4, 4), randf_range(-14, -2)), -_dir * randf_range(30, 90), randf_range(0.2, 0.35), 2.0, cor, 0.0, true
				)
		if _dash_t >= dur_av:
			_fase = 2
	return desl


## O raio da investida (ULT-B): UM quadro. Fere quem está na faixa de `largura` (x escala) de onde o herói está até a borda da tela, uma vez só,
## e gera o zigue-zague que o desenho mostra por RAIO_DUR s (nenhum nó novo).
func _raio(h) -> void:
	_alcance = _alcance_tela(h)
	_faixa(h, _alcance)
	_zigue(h)
	_raio_t = 0.0


## Até onde vai o raio do herói nesta direção: até a borda da tela (a câmera mais margem_borda px).
func _alcance_tela(h) -> float:
	return alcance_ate_borda(h.pos, _dir, mundo.cam.retangulo(float(_c.margem_borda)))


## Interseção raio-retângulo: quantos px vai de `origem` (dentro do retângulo) na direção `dir` (normalizada) até a borda dele.
## Função estática e sem estado: o teste confere as 4 bordas, os cantos e a origem fora do centro.
static func alcance_ate_borda(origem: Vector2, dir: Vector2, rect: Rect2) -> float:
	var t := INF
	if absf(dir.x) > 0.000001:
		t = minf(t, maxf((rect.position.x - origem.x) / dir.x, (rect.end.x - origem.x) / dir.x))
	if absf(dir.y) > 0.000001:
		t = minf(t, maxf((rect.position.y - origem.y) / dir.y, (rect.end.y - origem.y) / dir.y))
	return maxf(0.0, t) if t < INF else 0.0


## O zigue-zague do raio: RAIO_PTS pontos do herói até `_alcance`, com desvio de lado (zero nas pontas). Gerado uma vez por disparo.
func _zigue(h) -> void:
	_zig.resize(RAIO_PTS)
	var base: Vector2 = h.pos + Vector2(0, -6)
	var lado := Vector2(-_dir.y, _dir.x)
	for i in RAIO_PTS:
		var desvio := 0.0
		if i > 0 and i < RAIO_PTS - 1:
			desvio = (9.0 if i % 2 == 0 else -9.0) * randf_range(0.5, 1.0)
		_zig[i] = base + _dir * (_alcance * float(i) / float(RAIO_PTS - 1)) + lado * desvio


## Quem está na faixa à frente do herói (screen space: `along` ao longo da mira, `perp` de lado) leva o corte, uma vez só.
## `olhar` é até onde a faixa vai (o alcance até a borda, no raio).
func _faixa(h, olhar: float) -> void:
	var c = combate
	var largura := float(_c.largura) * _escala
	var cor := _cor(_c.cor)
	var chance: float = c.chance_critico()
	var variacao := float(c.cfg.golpe.variacao)
	var feitos := 0
	for m in mundo.monstros:
		if not m.vivo or m.morrendo or _ja.has(m.get_instance_id()):
			continue
		var rel: Vector2 = m.pos - h.pos
		var along := rel.dot(_dir)
		if along < -14.0 or along > olhar:
			continue
		if absf(rel.cross(_dir)) > largura + float(m.raio):
			continue
		_ja[m.get_instance_id()] = true
		_n += 1
		feitos += 1
		var lado := Vector2(-_dir.y, _dir.x) * (1.0 if rel.cross(_dir) < 0.0 else -1.0)
		var fora := (_dir * 0.4 + lado * 0.6).normalized()
		var crit := randf() < chance
		var d: float = float(_c.dano) * float(h.m_dano) * (1.0 + randf_range(-variacao, variacao))
		if crit:
			d *= float(c.cfg.golpe.critico.mult)
		var dn := maxi(1, roundi(d))
		c.fonte_dano = "especial"
		if c.ferir(m, d, fora, float(_c.empurrao), float(_c.atordoa), COR_NUM, false):
			_mortes += 1
		var ponto: Vector2 = m.pos + Vector2(0, -8)
		if _numeros < int(comum.numeros_max) or crit:
			_numeros += 1
			c.fx.numero(m.pos + Vector2(0, -float(m.alt) * 0.85), str(dn), COR_CRIT if crit else COR_NUM, crit)
			c.fx.flash(m, 0.1)
			c.fx.folha("estrela", ponto, 15.0 if crit else 11.0, cor, 0.14)
			c.fx.faiscas(ponto, fora, 6, cor, 170.0)
		c.audio.tocar("critico" if crit else "impacto", randf_range(0.95, 1.15), -3.0, 0.05)
	if feitos > 0:
		c.processar_mortes()


func _final_investida(h) -> void:
	var c = combate
	var f: Dictionary = _c.final
	var raio := float(f.raio) * _escala
	var cor := _cor(_c.cor)
	_numeros = 0
	var p: Vector2 = h.pos
	_pulso(h, p, raio, float(f.dano), float(f.empurrao), float(f.atordoa), cor, false, 0.0)
	# o corte em cruz: quatro arcos largos saindo do herói
	for k in 4:
		var ang := _dir.angle() + PI * 0.25 + float(k) * PI * 0.5
		c.fx.corte(p + h.ORIGEM_GOLPE, ang, raio * 0.95, 110.0, 1.0 if k % 2 == 0 else -1.0, "corte", cor.lerp(Color.WHITE, 0.4), 0.2)
	_anel(p, raio * 0.2, raio, 0.25, 3.0, cor.lerp(Color.WHITE, 0.35), 1.0)
	_anel(p, raio * 0.1, raio * 0.8, 0.15, 1.5, Color.WHITE, 1.0)
	c.fx.estouro(p + Vector2(0, -6), cor, 10)
	c.fx.luz_rapida(p + Vector2(0, -8), cor.lerp(Color.WHITE, 0.3), 2.4, 2.6 * raio, 0.3)
	c.audio.tocar("ruptura_disparo", 1.3, 0.0, 0.0)
	c.audio.tocar("critico", 1.0, -1.0, 0.0)
	mundo.cam.tremer(float(f.tremor), 0.2)
	if _n > 0:
		c.hit_stop(float(f.hit_stop))


# ------------------------------------------------------------------ o terremoto (Nick)


func _q_terremoto(h) -> void:
	if _fase == 0 and _t >= float(_c.golpe):
		_fase = 1
		_bater(h)


func _bater(h) -> void:
	var c = combate
	var b: Dictionary = _c.batida
	var raio := float(b.raio) * _escala
	var cor := _cor(_c.cor)
	var p: Vector2 = h.pos
	_numeros = 0
	_pulso(h, p, raio, float(b.dano), float(b.empurrao), float(b.atordoa), cor, true, float(_c.chefe_lento))
	# a onda sai da batida e vai até onda.raio
	var o: Dictionary = _c.onda
	_onda_t = 0.0
	_onda_c = p
	_onda_r0 = raio
	_onda_r1 = maxf(float(o.raio) * _escala, raio + 20.0)
	_onda_dur = maxf(float(o.dur), 0.05)
	_onda_ant = raio
	_onda_cfg = o
	_onda_cor = cor
	_onda_lento = float(_c.chefe_lento)
	ondas += 1
	# o visual: duas ondas, poeira, estouro, rachaduras, luz, tremor e o baque grave
	c.fx.onda(p, Color(cor.r, cor.g, cor.b, 0.9), raio, 0.3)
	c.fx.onda(p, Color(1, 1, 1, 0.6), raio * 0.6, 0.2)
	_anel(p, raio * 0.2, raio, 0.25, 4.0, cor.lerp(Color.WHITE, 0.3), 1.0)
	_rachar(p, raio * 1.15, cor)
	for i in maxi(8, roundi(22.0 * c.fx.fator_part)):
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a) * ACHATA) * randf_range(90.0, 190.0)
		c.fx.particula(p + Vector2(0, -1), v, randf_range(0.35, 0.55), 2.0 if randf() < 0.6 else 3.0, COR_POEIRA, 40.0)
	c.fx.estouro(p + Vector2(0, -2), Color(0.75, 0.68, 0.55), 14)
	c.fx.luz_rapida(p + Vector2(0, -6), cor, 2.4, 2.8 * raio, 0.35)
	c.audio.tocar("impacto", 0.45, 3.0, 0.0)
	c.audio.tocar("ruptura_disparo", 0.7, 1.0, 0.0)
	mundo.cam.tremer(float(b.tremor), 0.3)
	if _n > 0:
		c.hit_stop(float(b.hit_stop))


## Um quadro da onda de choque (tempo do mundo): a frente cresce de `_onda_r0` a `_onda_r1` e fere uma vez quem ela alcança.
func atualizar(dt: float) -> void:
	if _graca > 0.0:
		_graca = maxf(0.0, _graca - dt)
	if _onda_t < 0.0:
		return
	_onda_t += dt
	var k := clampf(_onda_t / _onda_dur, 0.0, 1.0)
	var r := lerpf(_onda_r0, _onda_r1, k)
	var c = combate
	var o := _onda_cfg
	var h = mundo.heroi
	var chance: float = c.chance_critico()
	var variacao := float(c.cfg.golpe.variacao)
	var feitos := 0
	for m in mundo.monstros:
		if not m.vivo or m.morrendo or _ja.has(m.get_instance_id()):
			continue
		var rel: Vector2 = m.pos - _onda_c
		var rg := Vector2(rel.x, rel.y / ACHATA)
		var dist := rg.length()
		if dist - float(m.raio) > r:
			continue
		_ja[m.get_instance_id()] = true
		_n += 1
		feitos += 1
		var fora: Vector2 = rel / maxf(rel.length(), 0.5)
		var crit := randf() < chance
		var d: float = float(o.dano) * float(h.m_dano) * (1.0 + randf_range(-variacao, variacao))
		if crit:
			d *= float(c.cfg.golpe.critico.mult)
		var dn := maxi(1, roundi(d))
		c.fonte_dano = "especial"
		if c.ferir(m, d, fora, float(o.empurrao), float(o.atordoa), COR_NUM, false):
			_mortes += 1
			if str(mundo.id_mapa) == "cidade" and str(h.chave) == "nicao":
				c.fx.fragmentar(m, fora)
		if m.chefe:
			m.deixar_lento(_onda_lento)
		if _numeros < int(comum.numeros_max) or crit:
			_numeros += 1
			c.fx.numero(m.pos + Vector2(0, -float(m.alt) * 0.85), str(dn), COR_CRIT if crit else COR_NUM, crit)
			c.fx.flash(m, 0.1)
			c.fx.faiscas(m.pos + Vector2(0, -8), fora, 5, _onda_cor, 150.0)
	if feitos > 0:
		c.audio.tocar("impacto", 0.8, -2.0, 0.05)
		c.processar_mortes()
	_onda_ant = r
	if k >= 1.0:
		_onda_t = -1.0
	no.queue_redraw()
	_desenhou = true


# ------------------------------------------------------------------ a tempestade de adagas (Luke)


func _q_chuva(h, dt: float, v: Vector2) -> Vector2:
	var c = combate
	var cor := _cor(_c.cor)
	var cada := float(_c.cada)
	_tick_t -= dt
	var guarda := 0
	while _tick_t <= 0.0 and guarda < 6 and _t < float(_c.dur):
		guarda += 1
		_tick_t += cada
		_rodada(h, int(_c.n), _c.adaga)
		_giro += deg_to_rad(float(_c.giro))
		if int(_t / cada) % 3 == 0:
			c.audio.tocar("corte2", randf_range(1.5, 1.8), -7.0, 0.04)
	h.dir_olhar = Vector2.from_angle(_giro)  # o corpo gira junto: o sprite olha para onde a rodada saiu
	if _t >= float(_c.dur) and _fase == 0:  # o último quadro: a rodada enorme
		_fase = 1
		_rodada(h, int(_c.final.n), _c.final)
		_anel(h.pos, 10.0, 90.0, 0.3, 3.0, cor.lerp(Color.WHITE, 0.3), 1.0)
		c.fx.luz_rapida(h.pos + Vector2(0, -10), cor, 2.2, 220.0, 0.3)
		c.audio.tocar("ruptura_disparo", 1.5, -2.0, 0.0)
		mundo.cam.tremer(2.5, 0.15)
	if v == Vector2.ZERO:
		return Vector2.ZERO
	return v * h.vel_andar() * float(_c.mov) * dt


## Uma rodada de `n` adagas em círculo a partir do ângulo `_giro` (as adagas do Luke, v2/adagas.gd: o dano de cada uma já leva o bônus de dano).
func _rodada(h, n: int, p: Dictionary) -> void:
	var cor := _cor(_c.cor)
	var passo := {
		"n": n,
		"leque": 360.0 * float(n - 1) / float(n),  # n adagas a 360/n graus uma da outra
		"anel": true,
		"dano": float(p.dano),
		"vel": float(p.get("vel", _c.adaga.vel)),
		"alcance": float(p.alcance) * _escala,
		"perfura": int(p.perfura),
		"empurrao": float(p.empurrao),
		"atordoa": float(p.atordoa),
		"cor": [cor.r, cor.g, cor.b],
	}
	var base: Vector2 = h.pos + h.ORIGEM_GOLPE
	combate.fonte_dano = "especial"
	combate.adagas.lancar(h, base, Vector2.from_angle(_giro), passo)


# ------------------------------------------------------------------ o pulso (a pancada em volta)


## Fere tudo dentro da elipse do chão de `raio` em volta de `centro` (elite e chefe entram; o herói nunca é ferido). `marcar` = anota em `_ja` quem
## apanhou (a onda do terremoto não repete). `lento` > 0 = segundos de lentidão no chefe, que não é atordoado nem empurrado. Devolve quantos acertou.
func _pulso(h, centro: Vector2, raio: float, dano_b: float, emp: float, atordoa: float, cor: Color, marcar: bool, lento: float) -> int:
	var c = combate
	var chance: float = c.chance_critico()
	var variacao := float(c.cfg.golpe.variacao)
	var n := 0
	for m in mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var rel: Vector2 = m.pos - centro
		if not Armas.na_elipse(rel, raio + m.raio):
			continue
		var dist := rel.length()
		var fora: Vector2 = rel / dist if dist > 0.5 else Vector2.from_angle(m.ang_cerco)
		var crit := randf() < chance
		var d: float = dano_b * float(h.m_dano) * (1.0 + randf_range(-variacao, variacao))
		if crit:
			d *= float(c.cfg.golpe.critico.mult)
		var dn := maxi(1, roundi(d))
		c.fonte_dano = "especial"
		if c.ferir(m, d, fora, emp, atordoa, COR_NUM, false):
			_mortes += 1
			if _id == "terremoto" and str(mundo.id_mapa) == "cidade" and str(h.chave) == "nicao":
				c.fx.fragmentar(m, fora)
		if lento > 0.0 and m.chefe:
			m.deixar_lento(lento)
		if marcar:
			_ja[m.get_instance_id()] = true
		n += 1
		_n += 1
		if _numeros < int(comum.numeros_max) or crit:
			_numeros += 1
			c.fx.numero(m.pos + Vector2(0, -float(m.alt) * 0.85), str(dn), COR_CRIT if crit else COR_NUM, crit)
			c.fx.flash(m, 0.1)
			c.fx.faiscas(m.pos + Vector2(0, -8), fora, 6, cor, 170.0)
	if _mortes >= 3:
		c.fx.numero(centro + Vector2(0, -44), "x%d" % _mortes, COR_CRIT, true)
	c.processar_mortes()
	return n


# ------------------------------------------------------------------ eventos (herói e combate chamam)


## O Q em andamento (ou logo depois dele) não enche a carga: nem o dano das adagas e da onda dele, nem os abates dele.
func ocupado() -> bool:
	return _id != "" or _onda_t >= 0.0 or _graca > 0.0


## Soma `pontos` à carga do herói (para na carga máxima). Só com o jogo rolando, fora do próprio Q e com o herói vivo. Avisa uma vez ao chegar a 100.
## `fonte`: "dano", "abate" ou "recebido" (só a contabilidade da calibragem).
func carregar(h, pontos: float, fonte := "dano", por_nivel := true) -> void:
	if h == null or pontos <= 0.0 or h.esp_nome == "" or h.esp_carga >= h.esp_carga_max:
		return
	var c = combate
	if c.jogo != "jogando" or c.pausado or ocupado() or h.estado == h.Estado.MORTO or h.estado == h.Estado.ESPECIAL:
		return
	var antes: float = h.esp_carga
	if h.forma_lobo and c.cartas != null:  # LW-6: o Cabo de Resgate acelera a carga do chamado do Lobo (toda fonte: dano, abate, recebido e tempo)
		pontos *= c.cartas.mult_cabo()
	# o herói fica mais forte a cada nível (dano e abates por segundo sobem), então o mesmo golpe vale menos carga: o Q segue a cada ~1 minuto e pouco
	if por_nivel:
		pontos /= 1.0 + float(_carga_de(h).nivel_k) * float(maxi(h.nivel - 1, 0))
	h.esp_carga = minf(h.esp_carga + pontos, h.esp_carga_max)
	carga_total[fonte] = float(carga_total[fonte]) + (h.esp_carga - antes)
	if h.esp_carga >= h.esp_carga_max:
		pronta(h)


## Dano causado a um monstro (pontos de dano, sem contar o que passou da vida dele). Chamado por combate.ferir e combate.golpear.
func dano(valor: float) -> void:
	if mundo == null or mundo.heroi == null:
		return
	carregar(mundo.heroi, valor * float(_carga_de(mundo.heroi).dano), "dano")


## O herói levou dano de verdade (não o que o escudo bloqueou). Chamado por combate.heroi_apanhou.
func recebeu(valor: float) -> void:
	if mundo == null or mundo.heroi == null:
		return
	carregar(mundo.heroi, valor * float(_carga_de(mundo.heroi).recebido), "recebido")


## Um abate dá carga de bônus: comum pequeno, elite grande, chefe muito grande. Chamado por combate.matar.
func abate(m) -> void:
	if mundo == null or mundo.heroi == null:
		return
	var a: Dictionary = _carga_de(mundo.heroi).abate
	var s := float(a.chefe) if m.chefe else (float(a.elite) if m.elite else float(a.comum))
	if m.mare:
		s *= float(mare_de(str(combate.heroi_id)).get("abate_carga", 1.0))  # monstro da Maré (ULT-C): o Q do herói da partida enche mais rápido
	carregar(mundo.heroi, s, "abate")


## A carga chegou a 100: um anel nos pés, o tique, o aviso sobre o herói e o anúncio "ULTIMATE PRONTA" no HUD, uma vez por carga.
func pronta(h) -> void:
	prontos += 1
	var cor: Color = h.esp_cor
	_anel(h.pos, 6.0, 30.0, 0.3, 2.0, cor.lerp(Color.WHITE, 0.4), 0.9)
	combate.audio.tocar("ruptura_pronta", 1.2, -2.0, 0.0)
	combate.audio.tocar("evolucao", 1.25, -5.0, 0.0)  # o sino grave da evolução, que não se confunde com o "nivel" do level up
	var texto := str(bloco_de(str(h.chave)).get("pronta_texto", "ULTIMATE PRONTA"))  # o chamado do Lobo avisa "MECHA PRONTO"
	combate.fx.numero(h.pos + Vector2(0, -52), texto, cor.lerp(Color.WHITE, 0.3), true)
	combate.anunciar(texto, cor.lerp(Color.WHITE, 0.25))


## Apertou sem a carga cheia: o som grave (o slot do HUD treme pelo esp_nega_t do herói).
func negou(_h) -> void:
	combate.audio.tocar("ruptura_cancela", 0.7, -4.0, 0.0)


# ------------------------------------------------------------------ o visual (um Node2D aditivo; elipse de chão achatada em 0,62)


func _anel(p: Vector2, r0: float, r1: float, dur: float, w: float, c: Color, alfa: float) -> void:
	var i := _ai
	_ai = (_ai + 1) % MAX_ANEIS
	a_vivo[i] = 1
	a_pos[i] = p
	a_t[i] = 0.0
	a_dur[i] = dur
	a_r0[i] = r0
	a_r1[i] = r1
	a_w[i] = w
	a_alfa[i] = alfa
	a_cor[i] = c
	no.queue_redraw()
	_desenhou = true


## Nove fissuras irregulares de seis pontos do centro até `raio`.
func _rachar(p: Vector2, raio: float, cor: Color) -> void:
	_rach.clear()
	for k in FISSURAS:
		var dir := Vector2.from_angle(TAU * (float(k) + randf_range(-0.3, 0.3)) / float(FISSURAS))
		var pts := PackedVector2Array()
		var lado := randf_range(-0.12, 0.12)
		for j in PONTOS_FISSURA:
			var f := float(j) / float(PONTOS_FISSURA - 1)
			var d := dir.rotated(lado * f * (1.0 if j % 2 == 0 else -1.0))
			pts.append(p + Vector2(d.x * raio * f, d.y * raio * f * ACHATA))
		_rach.append(pts)
	_rach_t = 0.0
	_rach_cor = cor


## Relógio de parede (continua no hit-stop): anéis e rachaduras envelhecem e o desenho só roda se há o que mostrar.
func efeitos(dt: float) -> void:
	var vivo := _id != ""
	for i in MAX_ANEIS:
		if a_vivo[i] == 1:
			a_t[i] += dt
			if a_t[i] >= a_dur[i]:
				a_vivo[i] = 0
			else:
				vivo = true
	if _rach_t >= 0.0:
		_rach_t += dt
		if _rach_t >= RACH_DUR:
			_rach_t = -1.0
			_rach.clear()
		else:
			vivo = true
	if _onda_t >= 0.0:
		vivo = true
	if vivo or _desenhou:
		no.queue_redraw()
	_desenhou = vivo


func _elipse(p: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in PTS + 1:
		var a := TAU * float(i) / float(PTS)
		pts.append(p + Vector2(cos(a) * r, sin(a) * r * ACHATA))
	return pts


func _desenhar() -> void:
	for i in MAX_ANEIS:
		if a_vivo[i] == 0:
			continue
		var k: float = a_t[i] / a_dur[i]
		var r: float = lerpf(a_r0[i], a_r1[i], 1.0 - pow(1.0 - k, 2.0))
		var al: float = a_alfa[i] * (1.0 - k)
		var cor: Color = a_cor[i]
		var pts := _elipse(a_pos[i], r)
		no.draw_polyline(pts, Color(cor.r, cor.g, cor.b, al * 0.35), a_w[i] * 2.5)
		no.draw_polyline(pts, Color(cor.r, cor.g, cor.b, al), a_w[i])
	if _rach_t >= 0.0:
		var k := _rach_t / RACH_DUR
		var al := 1.0 - k
		var cor := _rach_cor.lerp(Color(0.8, 0.2, 0.1), k)
		for pts in _rach:
			no.draw_polyline(pts, Color(cor.r, cor.g, cor.b, al * 0.4), 5.0)
			no.draw_polyline(pts, Color(cor.r, cor.g, cor.b, al), 1.5)
	if _onda_t >= 0.0:
		var f := clampf(_onda_t / _onda_dur, 0.0, 1.0)
		var r := lerpf(_onda_r0, _onda_r1, f)
		var pts := _elipse(_onda_c, r)
		var cor := _onda_cor.lerp(Color.WHITE, 0.4)
		no.draw_polyline(pts, Color(cor.r, cor.g, cor.b, (1.0 - f) * 0.3), 14.0)
		no.draw_polyline(pts, Color(cor.r, cor.g, cor.b, (1.0 - f) * 0.9), 4.0)
	var h = mundo.heroi
	if _id == "" or h == null or h.estado != h.Estado.ESPECIAL:
		return
	match _id:
		"investida":
			_desenhar_investida(h)
		"terremoto":
			_desenhar_terremoto(h)
		"chuva":
			_desenhar_chuva(h)
		"autodestruicao":
			_desenhar_autodestruicao(h)


## A mira da investida (a faixa que vai ser cortada) enquanto o herói se prepara, e o rastro de luz atrás dele no avanço.
func _desenhar_investida(h) -> void:
	var cor := _cor(_c.cor)
	var base: Vector2 = h.pos + Vector2(0, -6)
	if _fase == 0:
		# a linha fina e translúcida até a borda da tela: a direção do raio fica à vista antes do disparo (ULT-B)
		var k := clampf(_t / maxf(float(_c.prep), 0.001), 0.0, 1.0)
		no.draw_line(base, base + _dir * _alcance_tela(h), Color(cor.r, cor.g, cor.b, 0.15 + 0.35 * k), 1.0)
	elif _fase == 1:
		var ini := _origem + Vector2(0, -6)
		no.draw_line(ini, base, Color(cor.r, cor.g, cor.b, 0.35), 18.0)
		no.draw_line(ini, base, Color(cor.r, cor.g, cor.b, 0.8), 8.0)
		no.draw_line(ini, base, Color(1, 1, 1, 0.95), 3.0)
	if _raio_t >= 0.0 and _raio_t < RAIO_DUR:
		# o raio: três passadas do mesmo zigue-zague (halo, corpo e núcleo) que somem juntas em RAIO_DUR s
		var f := 1.0 - _raio_t / RAIO_DUR
		no.draw_polyline(_zig, Color(cor.r, cor.g, cor.b, 0.35 * f), 14.0)
		no.draw_polyline(_zig, Color(cor.r, cor.g, cor.b, 0.85 * f), 6.0)
		no.draw_polyline(_zig, Color(1, 1, 1, 0.95 * f), 2.0)


## O anel que cresce nos pés até o raio da batida, mais claro conforme a marreta sobe.
func _desenhar_terremoto(h) -> void:
	if _fase != 0:
		return
	var cor := _cor(_c.cor)
	var k := clampf(_t / maxf(float(_c.golpe), 0.001), 0.0, 1.0)
	var alvo := float(_c.batida.raio) * _escala
	var pts := _elipse(h.pos, alvo)
	no.draw_polyline(pts, Color(cor.r, cor.g, cor.b, 0.15 + 0.3 * k), 2.0)
	var dentro := _elipse(h.pos, alvo * (0.25 + 0.75 * k))
	no.draw_colored_polygon(dentro, Color(cor.r, cor.g, cor.b, 0.08 + 0.12 * k))
	no.draw_polyline(dentro, Color(cor.r, cor.g, cor.b, 0.5 + 0.4 * k), 3.0)


## Cinco adagas em órbita em volta do herói, girando junto com as rodadas.
func _desenhar_chuva(h) -> void:
	var cor := _cor(_c.cor)
	var c: Vector2 = h.pos + Vector2(0, -10)
	var n := int(_c.n)
	for k in n:
		var a := _giro + TAU * float(k) / float(n)
		var d := Vector2(cos(a), sin(a))
		var p := c + Vector2(d.x * 30.0, d.y * 30.0 * ACHATA)
		no.draw_line(p, p + d * 9.0, Color(cor.r, cor.g, cor.b, 0.9), 2.0)
		no.draw_line(p + d * 4.0, p + d * 12.0, Color(1, 1, 1, 0.8), 1.0)
	no.draw_polyline(_elipse(h.pos, 30.0), Color(cor.r, cor.g, cor.b, 0.25), 1.5)


## O mecha que ficou no lugar acende durante o fusível: o quadro dele em luz aditiva, um brilho em elipses e o anel que cresce até o raio da explosão. Tudo SOBE e nunca oscila (nada de
## piscar). No perfil Baixo (partículas em "poucas" ou "nenhuma") fica só o mecha e o anel, sem o brilho.
func _desenhar_autodestruicao(_h) -> void:
	if _fase != 0:
		return
	var cor := _cor(_c.cor)
	var k := clampf(_t / maxf(float(_c.dur), 0.001), 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var corpo := _origem + Vector2(0, -14)
	if not _leve():
		for i in 3:
			var r := lerpf(18.0, 44.0, e) * (1.0 + 0.6 * float(i))
			no.draw_colored_polygon(_elipse(corpo, r), Color(cor.r, cor.g, cor.b, (0.04 + 0.09 * e) / float(i + 1)))
	if not _g_tipo.is_empty():
		var t: Dictionary = _g_tipo
		var tom := cor.lerp(Color.WHITE, 0.2 + 0.6 * e)
		var cresce := 1.0 + 0.1 * e
		no.draw_set_transform(_origem, 0.0, Vector2(_g_esc.x * cresce * (-1.0 if _g_flip else 1.0), _g_esc.y * cresce))
		no.draw_texture_rect_region(t.alb, Rect2(-float(t.w) * 0.5, -float(t.pe), float(t.w), float(t.h)), _g_regiao, Color(tom.r, tom.g, tom.b, 0.3 + 0.6 * e))
		no.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var alvo := float(_c.explosao.raio)
	no.draw_polyline(_elipse(_origem, lerpf(alvo * 0.15, alvo, e)), Color(cor.r, cor.g, cor.b, 0.15 + 0.35 * e), 1.5)


## O perfil Baixo (partículas em "poucas" ou "nenhuma"): sem o brilho em elipses.
func _leve() -> bool:
	if mundo == null or not mundo.has_method("_nivel_particulas"):
		return false
	return float(mundo._nivel_particulas().get("efe_particulas", 1.0)) < 0.5


func _cor(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))
