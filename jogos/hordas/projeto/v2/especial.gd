extends RefCounted
## O ESPECIAL de cada herói da v2 (tecla Q ou RB do controle), no padrão Overwatch: botão direito = secundário (o escudo, v2/escudo.gd), E = habilidade
## (a ruptura, v2/ruptura.gd), Q = especial. Aperta e dispara na hora. O Q é uma ULTIMATE no estilo Overwatch: NÃO recarrega por tempo. Tem uma carga de
## 0 a 100 pontos (esp_carga) que começa a partida em 0 e enche por DANO CAUSADO (pontos de dano nos monstros, de qualquer fonte: golpe, ruptura, secundário,
## fogo), por bônus de ABATE (comum pequeno, elite grande, chefe muito grande) e um pouco por DANO RECEBIDO. Não enche durante o próprio Q (nem
## logo depois, enquanto as últimas adagas voam), nem com o jogo pausado ou nas cartas. Disparou, a carga volta a 0. Durante o especial o herói fica em
## Estado.ESPECIAL: não golpeia nem corre e é INVULNERÁVEL; a ruptura, o escudo e a esquiva em andamento são cancelados.
##
## Qual especial cada herói tem é DADO (dados/v2_especial.json > padrao e herois > chave do herói), igual ao secundário. Os três de hoje:
##  - INVESTIDA (Hazaki, "Corte Relâmpago"): mira um instante, some num clarão na direção da mira cortando tudo na faixa e fecha com um corte em cruz em volta.
##  - TERREMOTO (Nick): ergue a marreta e bate: pancada enorme em volta, rachaduras e uma onda de choque que sai da batida e varre quem estava longe.
##  - CHUVA (Luke, "Tempestade de Adagas"): gira soltando rodadas de adagas em círculo, andando devagar, e fecha com uma rodada enorme.
## Todo Q também LIMPA A TELA (ULT-A, `limpar_tela`, dados > comum.limpa e `limpa_em` de cada bloco): comuns morrem aos poucos numa frente de onda (a fila adiada
## é do combate: `combate.limpar_tela` e `combate.drenar_limpa`), elite perde parte da vida e chefe só uma fatia.
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
const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (a mesma da ruptura, do escudo e dos avisos)
const PTS := 40  # pontos da elipse desenhada
const MAX_ANEIS := 10
const FISSURAS := 9
const PONTOS_FISSURA := 6
const RACH_DUR := 0.7  # s da rachadura do terremoto
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
var carga_total := {"dano": 0.0, "abate": 0.0, "recebido": 0.0}  # pontos de carga ganhos na partida por fonte (calibragem, robô de playtest)
var _graca := 0.0  # s depois do fim do Q em que ainda não carrega (as últimas adagas voando)
var limpa_ligada := true  # a limpeza da tela (ULT-A) liga/desliga por instância (os testes antigos de dano por área desligam)
var limpas := 0  # testes: quantas limpezas saíram
var _limpa_pend := false  # a limpeza deste Q ainda não saiu (espera `limpa_em`)

var _id := ""  # o especial em andamento ("" = nenhum)
var _c: Dictionary = {}  # o bloco dele
var _t := 0.0  # s desde o disparo (tempo do mundo)
var _fase := 0
var _dir := Vector2.RIGHT  # a direção da mira travada no disparo
var _origem := Vector2.ZERO  # onde o herói estava ao disparar (o rastro da investida)
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
	carga_total = {"dano": 0.0, "abate": 0.0, "recebido": 0.0}
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
	var d: Vector2 = h.mira_mundo - h.centro()
	_dir = d.normalized() if d.length() > 4.0 else h.dir_olhar
	if _dir.length_squared() < 0.01:
		_dir = Vector2.RIGHT
	_origem = h.pos
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
	if _limpa_pend and _t >= float(_c.limpa_em):
		_limpa_pend = false
		limpar_tela(h)
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
func limpar_tela(h) -> int:
	var c = combate
	var L: Dictionary = comum.limpa
	var n: int = c.limpar_tela(h.pos, L)
	limpas += 1
	var cor: Color = h.esp_cor
	var rmax := Vector2(float(mundo.cam.LARG), float(mundo.cam.ALT)).length() * 0.5 + float(L.margem)
	_anel(h.pos, 16.0, rmax, rmax / maxf(float(L.vel), 1.0), 3.0, cor.lerp(Color.WHITE, 0.4), 0.55)
	if n > 0:
		c.fx.numero(h.pos + Vector2(0, -52), "LIMPOU x%d" % n, COR_CRIT, true)
	c.audio.tocar("ruptura_disparo", 0.9, -3.0, 0.0)
	return n


func _encerrar(h) -> void:
	ultimo = {"id": _id, "n": _n, "mortes": _mortes}
	_id = ""
	_limpa_pend = false
	_graca = float(comum.carga.graca)
	h.esp_invul = false
	h.esp_t = 0.0
	if h.estado == h.Estado.ESPECIAL:
		h.estado = h.Estado.LIVRE
	h.pausa_t = maxf(h.pausa_t, 0.12)  # só impede o golpe um instante, não impede andar


# ------------------------------------------------------------------ a investida (Hazaki)


func _q_investida(h, dt: float) -> Vector2:
	var c = combate
	var cor := _cor(_c.cor)
	var desl := Vector2.ZERO
	if _fase == 2:  # o corte final sai um quadro depois do último passo: aí h.pos já é onde o herói parou de verdade (colisão, limites)
		_fase = 3
		_final_investida(h)
	if _fase == 0 and _t >= float(_c.prep):
		_fase = 1
		_origem = h.pos
		c.audio.tocar("esquiva", 1.5, 0.0, 0.0)
		c.audio.tocar("estocada", 1.3, -2.0, 0.0)
		_anel(h.pos, 8.0, 40.0, 0.2, 3.0, Color.WHITE, 0.9)
	if _fase == 1:
		var dur_av := float(_c.avanco_t)
		var passo := minf(dt, dur_av - _dash_t)
		_dash_t += dt
		var vel := float(_c.distancia) / dur_av
		desl = _dir * vel * passo
		_faixa(h, maxf(30.0, vel * passo * 1.5))
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


## Quem está na faixa à frente do herói (screen space: `along` ao longo da mira, `perp` de lado) leva o corte, uma vez só.
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
	combate.diretor.mare_chamar()  # na Vila, com o Nicão, a pancada chama a Maré (o aviso é o da própria Maré)
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
func carregar(h, pontos: float, fonte := "dano") -> void:
	if h == null or pontos <= 0.0 or h.esp_nome == "" or h.esp_carga >= h.esp_carga_max:
		return
	var c = combate
	if c.jogo != "jogando" or c.pausado or ocupado() or h.estado == h.Estado.MORTO or h.estado == h.Estado.ESPECIAL:
		return
	var antes: float = h.esp_carga
	# o herói fica mais forte a cada nível (dano e abates por segundo sobem), então o mesmo golpe vale menos carga: o Q segue a cada ~1 minuto e pouco
	pontos /= 1.0 + float(comum.carga.nivel_k) * float(maxi(h.nivel - 1, 0))
	h.esp_carga = minf(h.esp_carga + pontos, h.esp_carga_max)
	carga_total[fonte] = float(carga_total[fonte]) + (h.esp_carga - antes)
	if h.esp_carga >= h.esp_carga_max:
		pronta(h)


## Dano causado a um monstro (pontos de dano, sem contar o que passou da vida dele). Chamado por combate.ferir e combate.golpear.
func dano(valor: float) -> void:
	if mundo == null or mundo.heroi == null:
		return
	carregar(mundo.heroi, valor * float(comum.carga.dano), "dano")


## O herói levou dano de verdade (não o que o escudo bloqueou). Chamado por combate.heroi_apanhou.
func recebeu(valor: float) -> void:
	if mundo == null or mundo.heroi == null:
		return
	carregar(mundo.heroi, valor * float(comum.carga.recebido), "recebido")


## Um abate dá carga de bônus: comum pequeno, elite grande, chefe muito grande. Chamado por combate.matar.
func abate(m) -> void:
	if mundo == null or mundo.heroi == null:
		return
	var a: Dictionary = comum.carga.abate
	var s := float(a.chefe) if m.chefe else (float(a.elite) if m.elite else float(a.comum))
	if m.mare:
		s *= float(combate.cfg.diretor.mare.abate_carga)  # monstro da Maré de Sangue: o Q enche mais rápido
	carregar(mundo.heroi, s, "abate")


## A carga chegou a 100: um anel nos pés, o tique, o aviso sobre o herói e o anúncio "ULTIMATE PRONTA" no HUD, uma vez por carga.
func pronta(h) -> void:
	prontos += 1
	var cor: Color = h.esp_cor
	_anel(h.pos, 6.0, 30.0, 0.3, 2.0, cor.lerp(Color.WHITE, 0.4), 0.9)
	combate.audio.tocar("ruptura_pronta", 1.2, -2.0, 0.0)
	combate.audio.tocar("evolucao", 1.25, -5.0, 0.0)  # o sino grave da evolução, que não se confunde com o "nivel" do level up
	combate.fx.numero(h.pos + Vector2(0, -52), "ULTIMATE PRONTA", cor.lerp(Color.WHITE, 0.3), true)
	combate.anunciar("ULTIMATE PRONTA", cor.lerp(Color.WHITE, 0.25))


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


## A mira da investida (a faixa que vai ser cortada) enquanto o herói se prepara, e o rastro de luz atrás dele no avanço.
func _desenhar_investida(h) -> void:
	var cor := _cor(_c.cor)
	var lado := Vector2(-_dir.y, _dir.x)
	var larg := float(_c.largura) * _escala
	var base: Vector2 = h.pos + Vector2(0, -6)
	if _fase == 0:
		var k := clampf(_t / maxf(float(_c.prep), 0.001), 0.0, 1.0)
		var ponta := base + _dir * float(_c.distancia)
		var faixa := PackedVector2Array([base + lado * larg, ponta + lado * larg, ponta - lado * larg, base - lado * larg])
		no.draw_colored_polygon(faixa, Color(cor.r, cor.g, cor.b, 0.1 + 0.15 * k))
		no.draw_line(base, ponta, Color(cor.r, cor.g, cor.b, 0.35 + 0.5 * k), 1.5)
		no.draw_polyline(PackedVector2Array([base + lado * larg, ponta + lado * larg]), Color(cor.r, cor.g, cor.b, 0.3 * k), 1.0)
		no.draw_polyline(PackedVector2Array([base - lado * larg, ponta - lado * larg]), Color(cor.r, cor.g, cor.b, 0.3 * k), 1.0)
	elif _fase == 1:
		var ini := _origem + Vector2(0, -6)
		no.draw_line(ini, base, Color(cor.r, cor.g, cor.b, 0.35), 18.0)
		no.draw_line(ini, base, Color(cor.r, cor.g, cor.b, 0.8), 8.0)
		no.draw_line(ini, base, Color(1, 1, 1, 0.95), 3.0)


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


func _cor(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))
