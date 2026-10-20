extends RefCounted
## Golem de Barro (carta "golem_barro") e Colosso de Pedra (a fusão dele): o aliado de barro que anda de verdade e esmaga o chão.
## O pool de aliados é o de `v2/armas_novas.gd`; este arquivo só tem a lógica e o desenho do golem (funções estáticas sobre o item do pool).
##
## A arte é a folha 3D `assets/v2/armas/golem_barro_dir.png` (fonte_arte/blender_golem/gerar_golem.py): 16 colunas x 5 linhas.
## Colunas 0-7 = ciclo de andar (as pisadas são os quadros 2 e 6, o 2 também é o "parado"), 8-15 = ataque (o 12, `QUADRO_IMPACTO`, é a pancada).
## Linhas = frente, 3/4 frente, perfil, 3/4 costas, costas, escolhidas pela direção do movimento (como os monstros, com histerese);
## a folha olha para a direita e o lado esquerdo é o espelho.
##
## Estados do item (chaves do dicionário do pool): e = ANDANDO / ATACANDO / SURGINDO, et = tempo no estado, lin = linha da vista,
## pf = fase do passo (1 = um ciclo de andar completo, avança com a distância ANDADA: parado, o quadro não muda e o pé não escorrega),
## mov = andou neste quadro, imp = a pancada deste ataque já caiu, ip = onde a pancada cai, sumiu = o desmoronar já soltou os torrões,
## deb = entulho (torrões que quicam e ficam no chão, poeira), rt = s desde a última pancada (as rachaduras no chão; -1 = nenhuma).
## O dano cai quando a animação cruza o quadro do impacto (não quando o ataque começa), em área no ponto `ip` guardado no início do golpe.

const FOLHA := "res://assets/v2/armas/golem_barro_dir.png"
const QUADRO := Vector2(86, 104)  # tamanho de cada quadro da folha (o teste confere com o png e o .json)
const PE := Vector2(40, 83)  # ponto do quadro que fica no chão (it.p)
const COL_ANDAR := 8
const COL_ATAQUE := 8
const LINHAS := 5
const PASSO_LINHA := 45.0  # graus entre uma vista e a próxima
const HISTERESE := 8.0  # graus de folga para não piscar de vista na fronteira
## Pixels que o golem anda por ciclo de andar (8 quadros = 2 passos), por linha da vista (frente, 3/4 frente, perfil, 3/4 costas, costas). O gerador mede NOS PIXELS
## o pé de apoio (quadros 2 a 6) vista por vista e grava `ciclo_linha` no .json (2 x o quanto o pé anda na tela): o corpo tem de andar isso, senão o pé escorrega.
## De frente e de costas a câmera (45 graus) encurta o passo: o chão em profundidade vale ~0,71 na tela, e nas diagonais ~0,87.
const CICLO_LINHA := [36.0, 45.2, 52.0, 45.2, 36.0]
const PARADO := 2  # quadro de andar usado parado (pernas afastadas, os dois pés no chão)
const TEMPOS_ATAQUE := [0.09, 0.08, 0.08, 0.10, 0.06, 0.11, 0.10, 0.10]  # duração de cada quadro do ataque (s); soma 0,72 s, para caber no "tique" de 0,8 s da carta
const QUADRO_IMPACTO := 4  # índice (dentro do ataque) do quadro da pancada
const ALCANCE := 30.0  # distância (plano achatado) do alvo a partir da qual ele para e ataca; o punho no quadro da pancada, de perfil, alcança 23 px à frente do pé (medido na folha) e a pancada cai a 0,75 x isto = 22,5 px
const RAIO_IMPACTO := 42.0  # raio da pancada no chão
const RESPIRO_MIN := 0.08  # menor pausa entre o fim de um ataque e o começo do próximo (a cadência vem do "tique" da carta: ciclo = max(tique, ataque + isto))
const EMPURRA := 30.0  # empurrão da pancada em cada monstro: o do golpe antigo (de contato, alvo único). O que mudou de verdade é a ÁREA (raio 42 px), não o empurrão por alvo
const ATORDOA := 0.05  # atordoamento da pancada, em s: o do golpe antigo
const SURGIR_T := 0.55  # sobe do chão
const SUMIR_T := 0.6  # desmorona nos últimos segundos de vida
const ACHATA := 0.62
const COLOSSO := "colosso_de_pedra"
const ANDANDO := 0
const ATACANDO := 1
const SURGINDO := 2
const COR_BARRO := Color(0.66, 0.42, 0.27, 0.75)
const COR_TORRAO := Color(0.55, 0.33, 0.2)
const COR_PEDRA := Color(0.6, 0.57, 0.54)
const COR_POEIRA := Color(0.86, 0.76, 0.6)  # clara: tem de aparecer contra o chão de barro e de grama
const GRAV := 520.0  # gravidade dos torrões (px/s2 na altura)
const MAX_DEB := 36  # entulho por golem (torrões que caem e ficam no chão, nuvens de poeira)
const T_DEB := 11  # floats por peça: x, y (chão), z (altura), vx, vy, vz, tempo que falta, tempo total, tamanho, tipo (0 torrão, 1 pedra, 2 poeira que sobe, 3 poeira rasteira), tom
const T_RACHA := 1.8  # duração (s) das rachaduras que a pancada deixa no chão

static var _tex: Texture2D
static var _lida := false


## A folha do golem (carrega uma vez; null se faltar o arquivo, e o aliado volta ao desenho antigo).
static func tex() -> Texture2D:
	if not _lida:
		_lida = true
		_tex = load(FOLHA) as Texture2D
	return _tex


## A folha já foi lida (ou tentada)? armas_novas.pedir_aquecer pula o golem quando sim.
static func lida() -> bool:
	return _lida


static func eh_golem(id: String) -> bool:
	return id == "golem_barro" or id == COLOSSO


static func escala(id: String) -> float:
	return 1.3 if id == COLOSSO else 1.0


## Px do pé até o alto do golem (a barrinha de tempo de vida dele fica aí).
static func topo(it: Dictionary) -> float:
	return PE.y * 0.62 * escala(str(it.a.id))


## A linha (0 frente, 1 3/4 frente, 2 perfil, 3 3/4 costas, 4 costas) para ir na direção `v` (tela, y para baixo), com histerese:
## perto da fronteira entre duas vistas fica na que já estava (`atual`).
static func linha_de(v: Vector2, atual: int) -> int:
	var ang := rad_to_deg(atan2(absf(v.x), v.y))  # 0 = descendo (frente), 90 = de lado, 180 = subindo (costas)
	if atual >= 0 and atual < LINHAS and absf(ang - atual * PASSO_LINHA) <= PASSO_LINHA * 0.5 + HISTERESE:
		return atual
	return clampi(roundi(ang / PASSO_LINHA), 0, LINHAS - 1)


## Duração total do ataque (s).
static func tempo_ataque() -> float:
	var s := 0.0
	for d in TEMPOS_ATAQUE:
		s += float(d)
	return s


## Instante (s desde o começo do ataque) em que a animação cruza o quadro da pancada.
static func tempo_impacto() -> float:
	var s := 0.0
	for i in QUADRO_IMPACTO:
		s += float(TEMPOS_ATAQUE[i])
	return s


## Pausa depois do ataque: o "tique" da carta (dados/v2_cartas.json, sobe e desce com os níveis) é o ciclo inteiro; nunca menos que `RESPIRO_MIN`.
static func respiro(it: Dictionary) -> float:
	return maxf(RESPIRO_MIN, float(it.a.st.tique) - tempo_ataque())


## Quadro do ataque (0 a 7) para `t` segundos desde o começo dele.
static func quadro_ataque(t: float) -> int:
	var s := 0.0
	for i in TEMPOS_ATAQUE.size():
		s += float(TEMPOS_ATAQUE[i])
		if t < s:
			return i
	return TEMPOS_ATAQUE.size() - 1


## Quadro de andar (0 a 7) para a fase do passo `pf` (1 = um ciclo).
static func quadro_andar(pf: float) -> int:
	return clampi(floori(fposmod(pf, 1.0) * COL_ANDAR), 0, COL_ANDAR - 1)


## Chaves novas do item do pool (o `montar` e o `_novo` do armas_novas usam: um slot reaproveitado nunca herda o estado de outro golem).
static func zerar(it: Dictionary) -> void:
	_limpar_som(it, true)
	it.g = false
	it.e = ANDANDO
	it.et = 0.0
	it.lin = 0
	it.pf = 0.0
	it.mov = false
	it.imp = false
	it.ip = Vector2.ZERO
	it.sumiu = false
	it.deb = PackedFloat32Array()
	it.rt = -1.0


## O item acaba de nascer: sobe do chão olhando para a câmera.
static func nascer(nv, it: Dictionary) -> void:
	it.g = true
	it.e = SURGINDO
	it.et = 0.0
	it.lin = 0
	it.v = Vector2(0, 1)
	it.sumiu = false
	var esc := escala(str(it.a.id))
	nv.pai.combate.audio.registrar_invocacao(it, "golem", 0.65 / sqrt(esc))
	var p: Vector2 = it.p
	_torroes(nv, it, p, 8, 40.0 * esc, esc)
	_poeira(nv, it, p, 6, 30.0 * esc, esc)
	nv.pai.fx.onda(p, Color(0.85, 0.65, 0.45, 0.6), 22.0 * esc, 0.3)


# ------------------------------------------------------------------ movimento e ataque


static func mover(nv, it: Dictionary, h, dt: float, perto: Array) -> void:
	it.et = float(it.et) + dt
	it.t = float(it.t) - dt  # a recarga do golpe (o armas_novas não conta o tempo do aliado)
	it.mov = false
	_entulho(it, dt)
	if float(it.vida) <= SUMIR_T:
		_desmoronar(nv, it, dt)
		return
	match int(it.e):
		SURGINDO:
			if randf() < dt * 24.0:
				_poeira(nv, it, it.p, 1, 22.0 * escala(str(it.a.id)), escala(str(it.a.id)), true)
			if float(it.et) >= SURGIR_T:
				it.e = ANDANDO
				it.et = 0.0
		ATACANDO:
			_atacar(nv, it)
		_:
			_andar(nv, it, h, dt, perto)


static func _andar(nv, it: Dictionary, h, dt: float, perto: Array) -> void:
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	var esc := escala(str(a.id))
	var alvo = nv._mais_perto(it.p, 400.0, perto)
	var dest: Vector2
	if alvo != null:
		dest = alvo.pos
	else:
		dest = h.pos + Vector2.from_angle(float(it.fase)) * 50.0  # sem inimigo, anda em volta do herói
	var d: Vector2 = dest - it.p
	if absf(d.x) > 2.0:
		it.r = signf(d.x)
	if alvo != null and nv._eli(d).length() <= ALCANCE * esc + float(alvo.raio):
		# em alcance: para (olhando para o alvo) e ataca quando a recarga deixa
		if d.length() > 1.0:
			it.v = (it.v as Vector2).lerp(d.normalized(), clampf(dt * 12.0, 0.0, 1.0))
			it.lin = linha_de(it.v, int(it.lin))
		if float(it.t) <= 0.0:
			_iniciar_ataque(it, d, esc)
		return
	if d.length() > 1.0:
		var dir := d.normalized()
		var passo := minf(float(st.vel) * dt, d.length())
		it.p = nv.pai.mundo.mover_ponto(it.p, dir * passo, nv.RAIO_ALIADO)
		it.v = (it.v as Vector2).lerp(dir, clampf(dt * 10.0, 0.0, 1.0))  # suavizado: o quadro não pisca na virada
		it.lin = linha_de(it.v, int(it.lin))
		var antes := float(it.pf)
		it.pf = antes + passo / (float(CICLO_LINHA[int(it.lin)]) * esc)
		it.mov = true
		if floori((float(it.pf) - 0.25) * 2.0) != floori((antes - 0.25) * 2.0):  # cruzou o quadro 2 ou o 6: um pé bateu no chão
			_pisada(nv, it, esc)


static func _iniciar_ataque(it: Dictionary, d: Vector2, esc: float) -> void:
	var dir := d.normalized()
	it.e = ATACANDO
	it.et = 0.0
	it.imp = false
	it.v = dir  # a vista fica travada durante o golpe
	it.lin = linha_de(dir, int(it.lin))
	it.ip = (it.p as Vector2) + dir * (ALCANCE * esc * 0.75)


static func _atacar(nv, it: Dictionary) -> void:
	var et := float(it.et)
	if not bool(it.imp) and et >= tempo_impacto():
		it.imp = true
		_impacto(nv, it)
	if et >= tempo_ataque():
		it.e = ANDANDO
		it.et = 0.0
		it.t = respiro(it)


## A pancada: dano em área no ponto guardado no início do golpe, onda no chão, torrões, poeira, clarão e um tremor leve.
static func _impacto(nv, it: Dictionary) -> void:
	var pai = nv.pai
	var a: Dictionary = it.a
	var esc := escala(str(a.id))
	var p: Vector2 = it.ip
	var raio := RAIO_IMPACTO * esc
	pai._dano_area(p, raio, nv._dano(a.st), EMPURRA, ATORDOA, a.cor, "aliado")
	var fx = pai.fx
	fx.onda(p, Color(0.9, 0.65, 0.42, 0.9), raio, 0.3)
	fx.onda(p, Color(1.0, 0.8, 0.5, 0.6), raio * 0.55, 0.2)
	fx.folha("anel", p, raio * 1.15, Color(0.85, 0.6, 0.4, 0.8), 0.3)
	fx.luz_rapida(p + Vector2(0, -6), Color(1.0, 0.62, 0.3), 2.0, raio * 2.4, 0.25)
	it.rt = 0.0
	_torroes(nv, it, p, 16, 100.0 * esc, esc)
	_poeira(nv, it, p, 14, 95.0 * esc, esc)
	pai.combate.audio.invocacao(it, "atacar")
	if (pai.mundo.heroi.pos as Vector2).distance_to(p) < 360.0:
		pai.mundo.cam.tremer(1.6 * esc, 0.14)


static func _pisada(nv, it: Dictionary, esc: float) -> void:
	var p: Vector2 = it.p
	_poeira(nv, it, p + Vector2(randf_range(-9.0, 9.0), 2.0) * esc, 3, 34.0 * esc, esc, true)
	if randf() < 0.6:
		_torroes(nv, it, p + Vector2(randf_range(-8.0, 8.0), 0.0) * esc, 1, 45.0 * esc, esc)
	if (nv.pai.mundo.heroi.pos as Vector2).distance_to(p) < 240.0:
		nv.pai.mundo.cam.tremer(0.35 * esc, 0.06)


## Últimos instantes de vida: afunda no chão soltando torrões (uma vez a rajada, depois a poeira fina).
static func _desmoronar(nv, it: Dictionary, dt: float) -> void:
	var esc := escala(str(it.a.id))
	if not bool(it.sumiu):
		it.sumiu = true
		it.e = ANDANDO
		nv.pai.combate.audio.invocacao(it, "sumir")
		var p: Vector2 = it.p
		_torroes(nv, it, p + Vector2(0, -18.0 * esc), 12, 70.0 * esc, esc)
		_poeira(nv, it, p, 7, 40.0 * esc, esc)
		nv.pai.fx.onda(p, Color(0.8, 0.6, 0.42, 0.5), 30.0 * esc, 0.35)
	if randf() < dt * 30.0:
		_poeira(nv, it, it.p, 1, 28.0 * esc, esc, true)


## `n` pedaços de barro e pedra que voam, caem, quicam uma vez e FICAM no chão um tempo (entulho do item, desenhado na camada normal, não aditiva: parece terra).
static func _torroes(nv, it: Dictionary, p: Vector2, n: int, vel: float, esc: float) -> void:
	var fx = nv.pai.fx
	n = maxi(1, roundi(n * fx.fator_part))
	for i in n:
		var ang := randf() * TAU
		var pedra := randf() < 0.3
		var tam := randf_range(4.0, 6.5) if not pedra else randf_range(3.0, 4.0)
		_deb_add(
			it,
			p + Vector2(randf_range(-6.0, 6.0), randf_range(-5.0, 0.0)) * esc,
			randf_range(6.0, 16.0) * esc,
			Vector2(cos(ang) * vel * randf_range(0.35, 1.0), sin(ang) * vel * 0.35),
			randf_range(90.0, 190.0) * (vel / 90.0 if vel > 90.0 else 1.0),
			randf_range(1.2, 1.9),
			tam,
			1.0 if pedra else 0.0,
			randf()
		)
	# um punhado de brasa de barro quente no ar (aditivo, curto): dá luz à pancada
	for i in maxi(1, roundi(3.0 * fx.fator_part)):
		var v := Vector2(randf_range(-1.0, 1.0) * vel * 0.8, -randf_range(30.0, 90.0))
		fx.particula(p + Vector2(0, -6) * esc, v, randf_range(0.2, 0.35), 3.0, Color(1.0, 0.65, 0.3, 0.8), 200.0, true)


## `n` nuvens de poeira que se abrem e sobem devagar (no entulho do item, camada normal; é terra, não luz).
## `rasteira` = poeira dos passos e do surgir: pequena, rente ao chão e SEMPRE por baixo do golem (a grande, da pancada, sobe e passa por cima dele).
static func _poeira(nv, it: Dictionary, p: Vector2, n: int, vel: float, esc: float, rasteira := false) -> void:
	var fx = nv.pai.fx
	n = maxi(1, roundi(n * fx.fator_part))
	for i in n:
		var ang := randf() * TAU
		_deb_add(
			it,
			p + Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 1.0)) * esc,
			randf_range(0.0, 3.0) * esc,
			Vector2(cos(ang) * vel * randf_range(0.3, 1.0), sin(ang) * vel * 0.3),
			0.0 if rasteira else randf_range(4.0, 12.0),
			randf_range(0.4, 0.7) if rasteira else randf_range(0.6, 1.0),
			(randf_range(3.0, 5.0) if rasteira else randf_range(6.0, 10.0)) * esc,
			3.0 if rasteira else 2.0,
			randf()
		)


static func _deb_add(it: Dictionary, p: Vector2, z: float, v: Vector2, vz: float, vida: float, tam: float, tipo: float, tom: float) -> void:
	var d: PackedFloat32Array = it.deb
	if d.size() >= MAX_DEB * T_DEB:
		return
	d.append_array(PackedFloat32Array([p.x, p.y, z, v.x, v.y, vz, vida, vida, tam, tipo, tom]))
	it.deb = d


## Anda o entulho: torrão sob gravidade (quica uma vez, depois para), poeira que freia e sobe; some quando o tempo acaba. Também conta o tempo das rachaduras.
static func _entulho(it: Dictionary, dt: float) -> void:
	if float(it.rt) >= 0.0:
		it.rt = float(it.rt) + dt
		if float(it.rt) > T_RACHA:
			it.rt = -1.0
	var d: PackedFloat32Array = it.deb
	if d.is_empty():
		return
	var n := d.size() / T_DEB
	var dest := 0
	var freio := exp(-3.0 * dt)
	for k in n:
		var o := k * T_DEB
		var t := d[o + 6] - dt
		if t <= 0.0:
			continue
		d[o + 6] = t
		if d[o + 9] > 1.5:  # poeira: abre, freia e sobe devagar
			d[o] += d[o + 3] * dt
			d[o + 1] += d[o + 4] * dt
			d[o + 3] *= freio
			d[o + 4] *= freio
			d[o + 2] += d[o + 5] * dt
		elif d[o + 2] > 0.0 or d[o + 5] > 0.0:  # torrão no ar
			d[o + 5] -= GRAV * dt
			d[o + 2] += d[o + 5] * dt
			d[o] += d[o + 3] * dt
			d[o + 1] += d[o + 4] * dt
			if d[o + 2] <= 0.0:
				d[o + 2] = 0.0
				if d[o + 5] < -70.0:  # quica uma vez, menor
					d[o + 5] = -d[o + 5] * 0.3
					d[o + 3] *= 0.4
					d[o + 4] *= 0.4
				else:  # parou: fica no chão
					d[o + 5] = 0.0
					d[o + 3] = 0.0
					d[o + 4] = 0.0
		if dest != k:
			for j in T_DEB:
				d[dest * T_DEB + j] = d[o + j]
		dest += 1
	d.resize(dest * T_DEB)
	it.deb = d


## O golem acabou (vida <= 0, o slot do pool já é livre), mas o entulho e as rachaduras dele ainda estão no chão: o pool continua andando e desenhando isso até acabar.
static func tem_restos(it: Dictionary) -> bool:
	return bool(it.g) and (float(it.rt) >= 0.0 or not (it.deb as PackedFloat32Array).is_empty())


static func restos(it: Dictionary, dt: float) -> void:
	_entulho(it, dt)


## Limpa o entulho e as rachaduras (nova partida; o slot reaproveitado por outro aliado).
static func limpar_restos(it: Dictionary) -> void:
	_limpar_som(it)
	it.deb = PackedFloat32Array()
	it.rt = -1.0


## WeakRef evita o ciclo áudio -> item -> áudio. O restart é silencioso; reutilizar completa a saída ainda não observada da geração anterior.
static func _limpar_som(it: Dictionary, retirada := false) -> void:
	var ref = it.get("som_inv_audio")
	var audio = ref.get_ref() if ref is WeakRef else null
	if audio != null:
		audio.cancelar_invocacao(int(it.get("som_inv_id", 0)), retirada)
		if not retirada:
			audio.cancelar_slot_invocacao(it)
	it.som_inv_id = 0
	# Até um projétil que reutilizou o slot pode guardar uma cauda curta da invocação anterior. Só a limpeza final solta este WeakRef.
	it.som_inv_audio = ref if retirada and audio != null else null


## O que sobra no chão depois que o golem some: rachaduras, torrões e a poeira que ainda não baixou (camada normal).
static func desenhar_restos(ci: CanvasItem, it: Dictionary) -> void:
	_desenhar_rachaduras(ci, it, false)
	_desenhar_entulho(ci, it, false)
	_desenhar_entulho(ci, it, true)


# ------------------------------------------------------------------ desenho


## Coluna e linha da folha do golem agora (o teste usa para conferir o ciclo andar -> atacar).
static func quadro_de(it: Dictionary) -> Vector2i:
	var col: int
	if int(it.e) == ATACANDO:
		col = COL_ANDAR + quadro_ataque(float(it.et))
	elif bool(it.mov):
		col = quadro_andar(float(it.pf))
	else:
		col = PARADO
	return Vector2i(col, int(it.lin))


## Camada normal (`no_corpo`, a que recebe a luz): sombra no chão e o quadro certo da folha, espelhado para olhar para onde vai.
## Surgindo e desmoronando mostram só uma fatia que sobe (ou afunda) pelo chão.
static func desenhar(ci: CanvasItem, it: Dictionary, p: Vector2) -> void:
	var t := tex()
	if t == null:
		return
	var id := str(it.a.id)
	var esc := escala(id)
	var lado := -1.0 if float(it.r) < 0.0 else 1.0
	var k := 1.0
	if int(it.e) == SURGINDO:
		k = clampf(float(it.et) / SURGIR_T, 0.0, 1.0)
	elif float(it.vida) < SUMIR_T:
		k = clampf(float(it.vida) / SUMIR_T, 0.0, 1.0)
	ci.draw_set_transform(p, 0.0, Vector2(esc, esc * ACHATA))
	ci.draw_circle(Vector2.ZERO, 22.0 * (0.4 + 0.6 * k), Color(0.0, 0.0, 0.0, 0.3 * k))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_desenhar_rachaduras(ci, it, false)
	_desenhar_entulho(ci, it, false)
	var q := quadro_de(it)
	var hv := QUADRO.y
	var topo := -PE.y
	if k < 1.0:
		var ease := 1.0 - (1.0 - k) * (1.0 - k)
		var fundo := (QUADRO.y - PE.y) * pow(ease, 3.0)  # quanto da fatia passa da linha do chão (só no fim, para o pé aparecer inteiro)
		hv = ease * PE.y + fundo
		topo = fundo - hv
	ci.draw_set_transform(p, 0.0, Vector2(lado * esc, esc))
	var origem := Vector2(q.x * QUADRO.x, q.y * QUADRO.y)
	var cor := Color(0.8, 0.82, 0.95) if id == COLOSSO else Color.WHITE
	ci.draw_texture_rect_region(t, Rect2(Vector2(-PE.x, topo), Vector2(QUADRO.x, hv)), Rect2(origem, Vector2(QUADRO.x, hv)), cor)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_desenhar_entulho(ci, it, true)


## As rachaduras que a pancada abre no chão (linhas quebradas saindo do ponto do impacto, achatadas como o chão); `brasa` = só a luz laranja de dentro, nos primeiros 0,5 s (camada aditiva).
static func _desenhar_rachaduras(ci: CanvasItem, it: Dictionary, brasa: bool) -> void:
	var rt := float(it.rt)
	if rt < 0.0:
		return
	var esc := escala(str(it.a.id))
	var raio := RAIO_IMPACTO * esc
	var cresce := clampf(rt / 0.1, 0.0, 1.0)
	var fade := clampf((T_RACHA - rt) / 0.6, 0.0, 1.0)
	var ip: Vector2 = (it.ip as Vector2).round()
	var semente := fposmod(ip.x * 0.37 + ip.y * 0.71, TAU)
	ci.draw_set_transform(ip, 0.0, Vector2(1.0, ACHATA))
	for r in 7:
		var ang := semente + r * TAU / 7.0
		var comp := raio * (0.55 + 0.4 * absf(sin(semente * 3.0 + r * 2.3))) * cresce
		var dir := Vector2.from_angle(ang)
		var lado := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array(
			[dir * comp * 0.15, dir * comp * 0.45 + lado * sin(r * 5.1 + semente) * 3.5, dir * comp * 0.75 - lado * sin(r * 3.7 + semente) * 3.0, dir * comp]
		)
		if brasa:
			var kb := clampf(1.0 - rt / 0.5, 0.0, 1.0)
			if kb > 0.0:
				ci.draw_polyline(pts, Color(1.0, 0.5, 0.2, 0.5 * kb), 2.0)
		else:
			ci.draw_polyline(pts, Color(0.14, 0.08, 0.05, 0.75 * fade), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## O entulho: `no_ar` = os que ainda estão no ar e as nuvens de poeira (por cima do golem); senão os torrões no chão (por baixo). Pixel quadrado, sombra no chão.
static func _desenhar_entulho(ci: CanvasItem, it: Dictionary, no_ar: bool) -> void:
	var d: PackedFloat32Array = it.deb
	var n := d.size() / T_DEB
	for k in n:
		var o := k * T_DEB
		var tipo := int(d[o + 9])
		var alto := tipo == 2 or (tipo < 2 and d[o + 2] > 0.5)
		if alto != no_ar:
			continue
		var restante := d[o + 6]
		var total := d[o + 7]
		var x := d[o]
		var y := d[o + 1]
		var z := d[o + 2]
		var tam := d[o + 8]
		var tom := d[o + 10]
		if tipo >= 2:  # poeira: um bafo redondo e macio que cresce e some
			var kk := restante / total
			var c := COR_POEIRA.lerp(Color(0.62, 0.5, 0.38), tom * 0.4)
			var centro := Vector2(roundf(x), roundf(y - z))
			var raio := tam * (0.7 + 0.9 * (1.0 - kk))
			c.a = 0.62 * kk
			ci.draw_circle(centro, raio, c)
			c.a = 0.5 * kk  # miolo mais claro: dá volume ao bafo
			ci.draw_circle(centro + Vector2(-raio * 0.2, -raio * 0.25), raio * 0.55, c.lightened(0.3))
			continue
		var cor := COR_PEDRA.lerp(Color(0.4, 0.38, 0.36), tom * 0.5) if tipo == 1 else COR_TORRAO.lerp(Color(0.85, 0.62, 0.42), tom * 0.6)
		var a := clampf(restante / 0.35, 0.0, 1.0)
		cor.a = a
		var px := roundf(x)
		var py := roundf(y)
		if z > 0.5:
			ci.draw_rect(Rect2(Vector2(px, py), Vector2(tam, 1.0)), Color(0.0, 0.0, 0.0, 0.3 * a))
		var c0 := Vector2(px, roundf(y - z) - tam + 1.0)
		ci.draw_rect(Rect2(c0, Vector2(tam, tam)), cor)
		ci.draw_rect(Rect2(c0, Vector2(tam, 1.0)), Color(minf(cor.r + 0.2, 1.0), minf(cor.g + 0.18, 1.0), minf(cor.b + 0.15, 1.0), a))
		ci.draw_rect(Rect2(c0 + Vector2(0, tam - 1.0), Vector2(tam, 1.0)), Color(cor.r * 0.55, cor.g * 0.55, cor.b * 0.55, a))


## Camada aditiva (`no_brilho`): o brasa do peito, o aviso no chão de onde a pancada vai cair e o clarão depois dela.
static func desenhar_brilho(ci: CanvasItem, it: Dictionary, p: Vector2, glow: Texture2D) -> void:
	var esc := escala(str(it.a.id))
	if float(it.vida) < SUMIR_T or int(it.e) == SURGINDO:
		return
	_desenhar_rachaduras(ci, it, true)
	if int(it.lin) < 3:  # de costas o peito não aparece
		var pulso := 0.5 + 0.5 * sin(float(it.fase) * 0.7)
		var c := p + Vector2(0, -30.0 * esc)
		ci.draw_texture_rect(glow, Rect2(c - Vector2(15, 12) * esc, Vector2(30, 24) * esc), false, Color(1.0, 0.55, 0.2, 0.08 + 0.07 * pulso))
	if int(it.e) != ATACANDO:
		return
	var et := float(it.et)
	var ti := tempo_impacto()
	var ip: Vector2 = (it.ip as Vector2).round()
	var raio := RAIO_IMPACTO * esc
	ci.draw_set_transform(ip, 0.0, Vector2(1, ACHATA))
	if et < ti:  # a pancada vai cair aqui: o aro fecha e acende
		var k := clampf(et / ti, 0.0, 1.0)
		ci.draw_arc(Vector2.ZERO, raio * (1.25 - 0.25 * k), 0.0, TAU, 40, Color(1.0, 0.55, 0.25, 0.12 + 0.45 * k), 1.0 + 1.5 * k)
		ci.draw_circle(Vector2.ZERO, raio * 0.8, Color(1.0, 0.5, 0.2, 0.06 * k))
	elif et < ti + 0.14:  # clarão do impacto
		var f := 1.0 - (et - ti) / 0.14
		ci.draw_circle(Vector2.ZERO, raio * (1.0 - 0.3 * f), Color(1.0, 0.75, 0.4, 0.35 * f))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
