extends Node2D
## Todos os inimigos da partida num lugar só (sem um nó por inimigo, pra caber 500 na tela).
## Cada inimigo é um objeto leve (classe V). Uma grade espacial acha quem está perto rápido.
## Também cuida dos tiros dos inimigos.

const Visual := preload("res://scripts/hordas/visual.gd")
const Perf := preload("res://scripts/hordas/perf.gd")
const ESCALA := 2.0        # a arte gerada é desenhada 2x
const CELULA := 48.0
const LONGE := 720.0       # mais longe que isso do jogador = reaparece do outro lado
const NASC_T := 0.26       # animação de nascer / reaparecer (teleporte): some e volta numa nuvem escura
const ACEL_VEL := 14.0     # suavização do andar: 1/ACEL_VEL s (~70 ms) pra chegar na velocidade pedida
const SEP_MAX := 1.2       # empurrão de separação: no máximo 1,2x a velocidade do bicho, por segundo
const KB_MAX := 360.0      # teto do empurrão (px/s): o knockback desliza, não teleporta
const SEP_PERIODO := 0.04       # a separação de cada bicho é recalculada a cada ~40 ms (em quadros: 40 ms / dt) e aplicada suave TODO quadro
const SEP_PERIODO_LONGE := 0.1  # ... e a cada ~100 ms se está longe do alvo (fora da tela)
const SEP_PERTO := 380.0
const SEP_VIZ: Array[int] = [-65537, -65536, -65535, -1, 0, 1, 65535, 65536, 65537]   # 3x3 células na chave inteira (x << 16) + y
const AUSENTE_T := 0.45    # cliente online: bicho que some da foto fica mais um pouco (foto cheia / borda) antes de sair
const GIRO_OLHAR := 9.42478   # velocidade máxima de giro do olhar: 540 graus/s
const HIST_OLHAR := 0.12      # folga (rad) além da divisa do setor antes de trocar de vista
const SNAP_ONLINE := 150.0 # cliente online: foto mais longe que isso do que se vê = teleporte (anima), não deslize

class V:
	var id := 0
	var tipo := ""
	var d: Dictionary            # dados do inimigos.json
	var tex: Texture2D
	var tam := Vector2.ZERO      # tamanho de um quadro (sem escala)
	var pos := Vector2.ZERO
	var hp := 1.0
	var hpmax := 1.0
	var dano := 1.0
	var vel := 40.0
	var raio := 8.0
	var esc := 1.0
	var kb := Vector2.ZERO
	var flash := 0.0
	var lento := 0.0
	var atordoado := 0.0         # parado no lugar (rugido do dragão)
	var elite := false
	var chefe := false
	var t_atira := 0.0
	var t_anel := 0.0
	var t_invoca := 0.0
	var t_inv := 0.0
	var estado := 0              # 0 normal, 1 se preparando pra investida, 2 investindo
	var t_estado := 0.0
	var dir_inv := Vector2.ZERO
	# comportamentos (lidos uma vez do json, pra não procurar no dicionário todo quadro)
	var distancia := 0.0
	var investida := 0.0
	var atira := 0.0
	var anel := 0.0
	var invoca: Dictionary = {}
	var pesado := false
	# vida no desenho (dados/inimigos.json): tudo lido uma vez aqui
	var ppx := 2.0               # pixels da tela por pixel do sprite (2 = vírus, 1 = arte de horror)
	var ritmo := 4.0             # quadros de andar por segundo
	var balanco := 0.0           # pulinho de andar, em px da tela
	var gira := false            # arte vista de cima com a cabeça pra cima (bug): gira pra onde anda em vez de espelhar
	var ang := 0.0               # ângulo atual do desenho (só com gira)
	var pos_ant := Vector2.INF   # posição no último desenho (só com gira): vale no solo e no cliente online
	var flutua := 0.0            # px acima do chão (a sombra fica no chão)
	var aura := Color(0, 0, 0, 0)   # brilho em volta (a > 0)
	var sz := Vector2.ZERO       # tamanho na tela (tam x escala x esc), calculado uma vez
	var luz := Vector2.ZERO      # x = raio, y = intensidade: ilumina a escuridão da fase de horror
	# suavidade do movimento
	var vm := Vector2.ZERO       # velocidade de andar atual (acelera até a desejada, não troca de uma vez)
	var sepv := Vector2.ZERO     # último empurrão de separação calculado (aplicado aos poucos, todo quadro)
	var t_nasc := 0.0            # > 0: nascendo / reaparecendo (animação de teleporte)
	# vistas (a folha tem uma linha por vista): vistas = 1 é o vírus, sempre de frente pra câmera (sem espelhar nem achatar);
	# vistas = 5 é o monstro de horror: 0 frente, 1 3/4 frente, 2 perfil, 3 3/4 costas, 4 costas (esquerda = espelho)
	var vistas := 1
	var olhar := 0.0             # pra onde olha, em rad a partir da frente (pra baixo): +PI/2 = direita, PI = costas
	var setor := 0               # setor de 45° escolhido (com histerese): -3..4, negativo = lado esquerdo (espelhado)
	var vista := 0               # linha da folha em uso
	var espelho := false         # desenhado espelhado (olhando pra esquerda)
	var orientar := true         # primeira vez ou voltou de fora da tela: o olhar vai direto pro alvo, sem girar
	var pos_olho := Vector2.INF  # cliente online: posição no último desenho (o olhar vem do deslocamento desenhado)
	var dr := Rect2()            # último retângulo desenhado (os testes conferem a largura)
	var p_ini := Vector2.ZERO    # cliente online: de onde o deslize da foto parte
	var p_fim := Vector2.ZERO    # ... e pra onde vai (posição da foto do anfitrião)
	var t_foto := 0.0            # ... e há quanto tempo a foto chegou
	# causa do golpe final (mortes violentas): cada dano grava a arma e a direção; `causa_pend` é o elemento da bola (Poder Elemental)
	var arma_ult := ""
	var causa_pend := ""
	var causa_ult := ""
	var dir_ult := Vector2.ZERO
	var sombra_reg: Array = [Rect2(), Rect2(), Rect2(), Rect2()]   # sombra assada por (quadro, espelho): ver Visual.sombra_regiao
	var t_ausente := 0.0        # ... e quanto tempo faz que ficou fora das fotos (some só depois de AUSENTE_T)

var arena: Node
var mortes: Node = null        # mortes.gd: desenha como o inimigo morreu (criado pela arena)
var online: Node = null     # online.gd (só na partida online)
var espelho := false         # cliente online: os vírus vêm do anfitrião, aqui não roda IA
var por_id := {}             # id -> V
var lista: Array = []
var tiros: Array = []          # {pos, vel, dano, tex, vida}
var _grade := {}
var _prox_id := 1
var _t := 0.0
var _quadro := 0
var _ordem: Array = []         # visíveis, do mais alto pro mais baixo (refeita todo quadro no _draw)
var _chaves := PackedFloat64Array()
var _dt := 0.016
var fantasmas: Array = []     # quem acabou de sumir (teleporte): {pos, tex, tam, sz, vira, quadro, t}
var tp_n := 0                 # quantos teleportes (reaparecimentos) já tocaram: o teste lê
# --- medição de saltos (--saltos): por inimigo, deslocamento por quadro contra a velocidade dele ---
var medir := false
var med_tempo := 0.0
var med_quadros := 0
var med_saltos := {}          # causa -> quantidade (passo > 2,5x a velocidade)
var med_grandes := {}         # causa -> quantidade (passo > 12 px num quadro)
var med_nasc_vis := 0         # nascimentos dentro da tela
var med_vistos := {}          # online (cliente): ids já vistos; recriar um id = o bicho piscou (saiu da foto e voltou)
var med_recriados := 0
var med_ex := {}              # causa -> até 3 exemplos


func criar(tipo: String, pos: Vector2, nivel := 1, elite := false) -> V:
	var dd: Dictionary = Dados.json("inimigos").get(tipo, {})
	if dd.is_empty():
		return null
	var fase: Dictionary = Dados.json("fase").get("dificuldade", {})
	var v := V.new()
	v.id = _prox_id
	_prox_id += 1
	v.tipo = tipo
	v.d = dd
	v.tex = Dados.tex(str(dd.get("sprite", "inimigo_bug")))
	v.vistas = maxi(1, int(dd.get("vistas", 1)))
	v.tam = Vector2(v.tex.get_width() / 3.0, v.tex.get_height() / float(v.vistas))
	if v.vistas > 1:
		v.sombra_reg = []
		for _i in 4 * v.vistas:
			v.sombra_reg.append(Rect2())
	v.pos = pos
	v.chefe = bool(dd.get("chefe", false))
	var mult_vida := 1.0 + float(fase.get("vida_por_nivel", 0.2)) * (nivel - 1)
	if v.chefe:
		mult_vida = 1.0 + 0.08 * (nivel - 1)
	v.hpmax = float(dd.get("vida", 10)) * mult_vida
	v.dano = float(dd.get("dano", 5)) * (1.0 + float(fase.get("dano_por_nivel", 0.08)) * (nivel - 1))
	v.vel = float(dd.get("velocidade", 40)) * randf_range(0.9, 1.1)
	v.raio = float(dd.get("raio", 8))
	if bool(dd.get("elite", false)) and not v.chefe:
		v.elite = true               # elite "de fábrica" (Abominação): vida e tamanho já vêm do json
	elif elite and not v.chefe:
		v.elite = true
		v.hpmax *= 6.0
		v.esc = 1.4
		v.raio *= 1.4
		v.dano *= 1.5
	v.hp = v.hpmax
	v.distancia = float(dd.get("distancia", 0.0))
	v.investida = float(dd.get("investida", 0.0))
	v.atira = float(dd.get("atira", 0.0))
	v.anel = float(dd.get("anel", 0.0))
	v.invoca = dd.get("invoca", {}) if dd.get("invoca") is Dictionary else {}
	v.pesado = bool(dd.get("pesado", false))
	v.ppx = float(dd.get("escala", ESCALA))
	v.sz = v.tam * v.ppx * v.esc
	v.ritmo = float(dd.get("ritmo", 4.0))
	v.balanco = float(dd.get("balanco", 0.0))
	v.gira = bool(dd.get("gira", false))
	v.flutua = float(dd.get("flutua", 0.0))
	if dd.get("aura") is Array:
		v.aura = Color(dd.aura[0], dd.aura[1], dd.aura[2], 1.0)
	if dd.get("luz") is Array:
		v.luz = Vector2(dd.luz[0], dd.luz[1])
	v.t_atira = randf_range(0.5, float(dd.get("atira", 3.0)))
	v.t_anel = float(dd.get("anel", 0.0))
	v.t_inv = float(dd.get("investida", 0.0))
	v.t_invoca = float(dd.get("invoca", {}).get("a_cada", 0.0)) if dd.get("invoca") is Dictionary else 0.0
	v.t_nasc = NASC_T
	v.p_ini = pos
	v.p_fim = pos
	lista.append(v)
	por_id[v.id] = v
	if medir and arena and arena.jogador and absf(pos.x - arena.jogador.position.x) < 330 and absf(pos.y - arena.jogador.position.y) < 190:
		med_nasc_vis += 1
	return v


func _med_reg(v: V, dt: float, passo: float, causa: String, vmax: float) -> void:
	if passo > 2.5 * vmax * dt and passo > 0.5:
		med_saltos[causa] = int(med_saltos.get(causa, 0)) + 1
		if passo > 12.0:
			med_grandes[causa] = int(med_grandes.get(causa, 0)) + 1
		var ex: Array = med_ex.get(causa, [])
		if ex.size() < 3:
			ex.append("%s passo=%.1f vmax*dt=%.2f" % [v.tipo, passo, vmax * dt])
			med_ex[causa] = ex


func med_relatorio() -> String:
	return "quadros=%d tempo=%.1fs saltos_sem_animacao(>2,5x vel)=%s  grandes(>12px)=%s  teleportes_animados=%d  nascimentos_na_tela=%d  recriados_online=%d  exemplos=%s" % [
		med_quadros, med_tempo, str(med_saltos), str(med_grandes), tp_n, med_nasc_vis, med_recriados, str(med_ex)]


func vivos() -> int:
	return lista.size()


func _remover(v: V) -> void:
	por_id.erase(v.id)
	var i := lista.find(v)
	if i >= 0:
		lista[i] = lista[lista.size() - 1]
		lista.pop_back()


func limpar() -> void:
	lista.clear()
	por_id.clear()
	tiros.clear()
	_ordem.clear()


## Dá dano. Retorna true se matou.
func ferir(v: V, valor: float, empurrao := Vector2.ZERO, arma := "") -> bool:
	if v.hp <= 0:
		return false
	var crit: bool = randf() < arena.stat("critico")
	if crit:
		valor *= arena.stat("critico_mult")
	v.hp -= valor
	v.flash = 0.09
	v.arma_ult = arma   # causa do golpe final (mortes violentas)
	v.causa_ult = v.causa_pend
	v.causa_pend = ""
	if empurrao.length_squared() > 1.0:
		v.dir_ult = empurrao
	arena.registrar_dano(arma, valor, v.pos, crit)
	if espelho:
		# cliente: o anfitrião aplica de verdade (e avisa se morreu); aqui só some até a confirmação
		online.acerto(v.id, valor, empurrao)
		if v.hp <= 0:
			_remover(v)
			_morte_visual(v)   # efeito só local: a morte em si o anfitrião já sincroniza
			return true
		return false
	var peso := 4.0 if v.pesado else 1.0
	if v.chefe:
		peso = 12.0
	v.kb = (v.kb + empurrao / peso).limit_length(KB_MAX)
	if v.hp <= 0:
		_remover(v)
		_morte_visual(v)
		arena.inimigo_morreu(v)
		return true
	return false


## Anfitrião: acerto que veio de outro computador (o dano e o crítico já foram calculados lá).
func ferir_remoto(v: V, valor: float, empurrao: Vector2) -> void:
	if v.hp <= 0:
		return
	v.hp -= valor
	v.flash = 0.09
	v.arma_ult = ""   # a arma do outro jogador não vem na rede: morte padrão
	v.causa_ult = ""
	v.kb = (v.kb + empurrao / (12.0 if v.chefe else (4.0 if v.pesado else 1.0))).limit_length(KB_MAX)
	if v.hp <= 0:
		_remover(v)
		_morte_visual(v)
		arena.inimigo_morreu(v)


## Como o inimigo morre na tela. Chefe: a finalização (finalizacao.gd) cuida; os outros: mortes.gd.
func _morte_visual(v: V) -> void:
	if v.chefe:
		if arena.finalizacao:
			arena.finalizacao.iniciar(v)
	elif mortes:
		mortes.nova(v)


func remover_id(id: int) -> void:
	var v = por_id.get(id)
	if v:
		_remover(v)


## Cliente: aplica a foto do anfitrião. vir = [id, tipo_idx, x, y, hp_frac, flags] por vírus;
## tiros = [x, y, vx, vy, sprite_idx]. Quem não veio na foto sumiu (morreu ou ficou longe).
func aplicar_foto(vir: PackedFloat32Array, tir: PackedFloat32Array, onl: Node) -> void:
	var vistos := {}
	for i in range(0, vir.size(), 6):
		var id := int(vir[i])
		var ti := int(vir[i + 1])
		if ti < 0 or ti >= onl.tipos.size() or not is_finite(vir[i + 2]) or not is_finite(vir[i + 3]):
			continue
		var flags := int(vir[i + 5])
		var v: V = por_id.get(id)
		if v == null:
			v = criar(onl.tipos[ti], Vector2(vir[i + 2], vir[i + 3]), 1, (flags & 1) != 0)
			if v == null:
				continue
			if medir:
				if med_vistos.has(id):
					med_recriados += 1
				med_vistos[id] = true
			por_id.erase(v.id)
			v.id = id
			por_id[id] = v
		var np := Vector2(vir[i + 2], vir[i + 3])
		if v.pos.distance_squared_to(np) > SNAP_ONLINE * SNAP_ONLINE:
			_teleportar(v, np)   # salto grande (reciclagem no anfitrião, volta de longe): anima em vez de deslizar
			v.p_ini = np
		else:
			v.p_ini = v.pos
		v.p_fim = np
		v.t_foto = 0.0
		v.t_ausente = 0.0
		v.hp = clampf(vir[i + 4], 0.01, 1.0) * v.hpmax
		v.chefe = (flags & 2) != 0
		if (flags & 4) != 0:
			v.flash = maxf(v.flash, 0.05)
		v.estado = 1 if (flags & 8) != 0 else 0
		v.lento = 0.1 if (flags & 16) != 0 else 0.0
		vistos[id] = true
	for v in lista.duplicate():
		if not vistos.has(v.id):
			v.t_ausente += onl.ENVIO
			if v.t_ausente > AUSENTE_T:
				_remover(v)
	tiros.clear()
	for i in range(0, tir.size(), 5):
		var si := int(tir[i + 4])
		var spr: String = onl.sprites_tiro[si] if si >= 0 and si < onl.sprites_tiro.size() else "proj_email"
		tiros.append({"pos": Vector2(tir[i], tir[i + 1]), "vel": Vector2(tir[i + 2], tir[i + 3]), "dano": 0.0,
			"tex": Dados.tex(spr), "vida": 1.0, "sprite": spr})


# ---------- buscas ----------

func _celula(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELULA), floori(p.y / CELULA))


func no_circulo(c: Vector2, r: float) -> Array:
	var res := []
	var a := _celula(c - Vector2(r + 40, r + 40))
	var b := _celula(c + Vector2(r + 40, r + 40))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var cel = _grade.get(((cx + 32768) << 16) + cy + 32768)
			if cel == null:
				continue
			for v: V in cel:
				var rr: float = r + v.raio
				if v.pos.distance_squared_to(c) <= rr * rr:
					res.append(v)
	return res


func mais_perto(p: Vector2, maximo := 99999.0) -> V:
	var melhor: V = null
	var md := maximo * maximo
	for v in lista:
		var dd: float = v.pos.distance_squared_to(p)
		if dd < md:
			md = dd
			melhor = v
	return melhor


## Os n mais perto (pra armas com vários tiros).
func n_mais_perto(p: Vector2, n: int, maximo := 400.0) -> Array:
	var perto := no_circulo(p, maximo)
	perto.sort_custom(func(a, b): return a.pos.distance_squared_to(p) < b.pos.distance_squared_to(p))
	return perto.slice(0, n)


func aleatorio_na_tela(centro: Vector2) -> V:
	var na_tela := no_circulo(centro, 260)
	return na_tela.pick_random() if not na_tela.is_empty() else null


# ---------- atualização ----------

func atualizar(dt: float, jog: Node2D) -> void:
	var _p0 := Perf.ini()
	_t += dt
	_quadro += 1
	_dt = dt
	_fantasmas_passo(dt)
	if medir:
		med_tempo += dt
		med_quadros += 1
	# grade
	var _p1 := Perf.ini()
	_grade.clear()
	for v: V in lista:
		var k: int = ((floori(v.pos.x / CELULA) + 32768) << 16) + floori(v.pos.y / CELULA) + 32768   # chave inteira: bem mais barata que Vector2i
		var cel = _grade.get(k)
		if cel == null:
			_grade[k] = [v]
		else:
			cel.append(v)
	Perf.fim("ini_grade", _p1)
	if espelho:
		_atualizar_espelho(dt)
		return
	# quem os vírus perseguem: o jogador local ou, no online, o jogador em pé mais perto
	var alvos: Array = online.alvos() if online else [[jog.centro(), 0]]
	if alvos.is_empty():
		alvos = [[jog.centro(), -1]]   # todo mundo caído: vão pro corpo do anfitrião sem ferir
	var alvo: Vector2 = alvos[0][0]
	var dono: int = alvos[0][1]
	var local: int = Rede.eu() if online else 0
	var k_vm := minf(1.0, dt * ACEL_VEL)   # suavização do andar (constante de tempo ~0,1 s); a investida arranca de uma vez
	var k_sep := dt * 12.0
	var k_kb := exp(-9.0 * dt)   # o knockback some em ~0,1 s (calculado uma vez por quadro, não por bicho)
	var cad_perto := clampi(roundi(SEP_PERIODO / maxf(dt, 0.0001)), 1, 12)   # quadros entre dois cálculos de separação
	var cad_longe := clampi(roundi(SEP_PERIODO_LONGE / maxf(dt, 0.0001)), 1, 24)

	var _p2 := Perf.ini()
	for v: V in lista.duplicate():
		if v.hp <= 0:
			continue
		if v.flash > 0.0:
			v.flash = maxf(0.0, v.flash - dt)
		if v.lento > 0.0:
			v.lento = maxf(0.0, v.lento - dt)
		if v.atordoado > 0.0:
			v.atordoado = maxf(0.0, v.atordoado - dt)
		if v.t_nasc > 0.0:
			v.t_nasc = maxf(0.0, v.t_nasc - dt)
		if alvos.size() > 1:
			var md := INF
			for a in alvos:
				var d2: float = v.pos.distance_squared_to(a[0])
				if d2 < md:
					md = d2
					alvo = a[0]
					dono = a[1]
		var para: Vector2 = alvo - v.pos
		var dist: float = para.length()
		var dir: Vector2 = para / dist if dist > 0.01 else Vector2.ZERO
		var vel: float = 0.0 if v.atordoado > 0 else v.vel * (0.45 if v.lento > 0 else 1.0)
		var mov: Vector2 = dir * vel

		# quem atira mantém distância
		if v.distancia > 0:
			var dd := v.distancia
			if dist < dd * 0.8:
				mov = -dir * vel * 0.6
			elif dist < dd:
				mov = Vector2.ZERO
		# investida: para, treme e corre reto
		if v.investida > 0:
			match v.estado:
				0:
					v.t_inv -= dt
					if v.t_inv <= 0 and dist < 360:
						v.estado = 1
						v.t_estado = 0.7
						v.dir_inv = dir
				1:
					mov = Vector2.ZERO
					v.t_estado -= dt
					if v.t_estado <= 0:
						v.estado = 2
						v.t_estado = 0.6
						Som.tocar("whoosh", 0.1, 0.7)
				2:
					mov = v.dir_inv * vel * 5.0
					v.t_estado -= dt
					if v.t_estado <= 0:
						v.estado = 0
						v.t_inv = v.investida
		if v.atira > 0:
			v.t_atira -= dt
			if v.t_atira <= 0 and dist < 330:
				v.t_atira = v.atira
				_atirar(v, dir)
		if v.anel > 0:
			v.t_anel -= dt
			if v.t_anel <= 0 and dist < 400:
				v.t_anel = v.anel
				_anel(v)
		if not v.invoca.is_empty():
			v.t_invoca -= dt
			if v.t_invoca <= 0:
				var inv: Dictionary = v.invoca
				v.t_invoca = float(inv.get("a_cada", 5.0))
				for i in int(inv.get("quantos", 4)):
					var a := TAU * i / float(inv.get("quantos", 4))
					criar(str(inv.get("tipo", "bug")), v.pos + Vector2.from_angle(a) * (v.raio + 20), arena.diretor.nivel())

		# separação dos vizinhos (não empilham): cada inimigo recalcula a cada SEP_PERIODO s (SEP_PERIODO_LONGE
		# se está longe do alvo, onde ninguém vê) e o resultado (`sepv`) é aplicado aos poucos TODO quadro, então não dá tranco
		if (v.id + _quadro) % (cad_perto if dist < SEP_PERTO else cad_longe) == 0:
			var sep := Vector2.ZERO
			var px := v.pos.x
			var py := v.pos.y
			var kc: int = ((floori(px / CELULA) + 32768) << 16) + floori(py / CELULA) + 32768
			var checados := 0
			for ko in SEP_VIZ:
				var cel = _grade.get(kc + ko)
				if cel == null or checados > 20:
					continue
				for o: V in cel:
					checados += 1
					if checados > 20:
						break
					if o == v:
						continue
					var dx: float = px - o.pos.x
					var dy: float = py - o.pos.y
					var rr: float = v.raio + o.raio
					var d2 := dx * dx + dy * dy
					if d2 < rr * rr and d2 > 0.0001:
						var dl := sqrt(d2)
						var f := (rr - dl) / dl
						sep.x += dx * f
						sep.y += dy * f
			v.sepv = sep * (0.1 if v.chefe else 1.0)
		# anda: a velocidade acelera até a desejada (sem trocar de uma vez), a separação entra aos poucos todo quadro
		# (antes entrava inteira a cada 2 quadros: o bicho dava tranco) e o empurrão tem teto
		v.vm += (mov - v.vm) * (1.0 if v.estado == 2 else k_vm)
		var push := Vector2.ZERO
		if v.sepv.x != 0.0 or v.sepv.y != 0.0:
			push = v.sepv * k_sep
			var lim_s: float = maxf(v.vel * SEP_MAX, 24.0) * dt
			if push.length_squared() > lim_s * lim_s:
				push = push.normalized() * lim_s
		var p_ant: Vector2 = v.pos
		v.pos += (v.vm + v.kb) * dt + push
		v.kb *= k_kb
		if medir:
			var comp := {"movimento": (v.vm * dt).length(), "knockback": (v.kb * dt).length(), "separacao": push.length()}
			var causa := "movimento"
			var mx := 0.0
			for k in comp:
				if comp[k] > mx:
					mx = comp[k]
					causa = k
			_med_reg(v, dt, p_ant.distance_to(v.pos), causa, v.vel * (5.0 if v.estado == 2 else 1.0))

		# encostou no jogador
		if dist < v.raio + 8:
			_ferir_jogador(jog, dono, local, v.dano, v.tipo)
		# muito longe: volta pra perto (do lado de onde o jogador está indo)
		if dist > LONGE and not v.chefe:
			var mov_j: Vector2 = jog.direcao_mov() if dono == local else Vector2.ZERO
			var a: float = mov_j.angle() + randf_range(-1.0, 1.0)
			if mov_j == Vector2.ZERO:
				a = randf() * TAU
			var destino: Vector2 = alvo + Vector2.from_angle(a) * randf_range(380, 440)
			_teleportar(v, destino)

	Perf.fim("ini_laco", _p2)
	# tiros dos inimigos
	for t in tiros.duplicate():
		t.pos += t.vel * dt
		t.vida -= dt
		var acertou := false
		for a in alvos:
			if t.pos.distance_squared_to(a[0]) < 100.0:
				_ferir_jogador(jog, a[1], local, t.dano, "tiro")
				acertou = true
				break
		if acertou or t.vida <= 0:
			tiros.erase(t)
	queue_redraw()
	Perf.fim("ini_atualizar", _p0)


## Teleporte de propósito (reciclagem de quem ficou longe, salto grande no online): o bicho some numa nuvem escura onde
## estava e reaparece em outra, no sentido contrário, em NASC_T s. Só vira desenho se estiver perto da tela; fora dela
## fica só o contador. Custo zero pra quem anda normal.
func _teleportar(v: V, destino: Vector2) -> void:
	tp_n += 1   # (o relatório do --saltos conta esses à parte: são saltos de propósito, com animação)
	if _na_tela(v.pos) and fantasmas.size() < 24:
		fantasmas.append({"pos": v.pos, "tex": v.tex, "tam": v.tam, "sz": v.sz, "vira": v.espelho,
			"y0": v.tam.y * v.vista, "quadro": int(_t * v.ritmo + v.id) % 2, "t": 0.0, "id": v.id})
	v.pos = destino
	v.vm = Vector2.ZERO
	v.kb = Vector2.ZERO
	v.t_nasc = NASC_T


func _na_tela(p: Vector2) -> bool:
	if not (arena and arena.jogador):
		return false
	var c: Vector2 = arena.jogador.position
	return absf(p.x - c.x) < 340.0 and absf(p.y - c.y) < 200.0


func _fantasmas_passo(dt: float) -> void:
	var i := fantasmas.size() - 1
	while i >= 0:
		fantasmas[i].t += dt
		if fantasmas[i].t >= NASC_T:
			fantasmas.remove_at(i)
		i -= 1


## Nuvem escura de fumaça (4 bolhas): u = 0 (começo) a 1 (fim); nasce densa e se esvai subindo.
func _nuvem(p: Vector2, larg: float, u: float, semente: int) -> void:
	var a := 0.6 * (1.0 - u)
	if a <= 0.01:
		return
	var raio := larg * (0.3 + 0.4 * u)
	for j in 4:
		var ang := float(semente * 7 + j) * 1.7 + u * 1.5
		draw_circle(p + Vector2.from_angle(ang) * raio * 0.5 + Vector2(0, -u * 8.0), raio * (0.55 + 0.1 * j), Color(0.09, 0.06, 0.14, a))


## Dano de vírus: no jogador daqui, ou (anfitrião online) manda pro computador de quem foi acertado.
func _ferir_jogador(jog: Node2D, quem: int, local: int, dano: float, fonte: String) -> void:
	if quem == local and quem >= 0:
		jog.sofrer(dano, fonte)
	elif quem > 0 and online:
		online.dano_remoto(quem, dano, fonte)


## Cliente online: os vírus só deslizam até a posição da última foto e os tiros seguem reto.
func _atualizar_espelho(dt: float) -> void:
	var dur: float = online.ENVIO if online else 1.0 / 15.0
	_dt = dt
	_fantasmas_passo(dt)
	for v: V in lista:
		v.flash = maxf(0.0, v.flash - dt)
		if v.t_nasc > 0.0:
			v.t_nasc = maxf(0.0, v.t_nasc - dt)
		# anda em linha reta da posição de antes até a da foto (uma foto de atraso); se a próxima atrasar, segue na mesma
		# direção por até meia foto e para: nunca dá o puxão de "pular pra última posição"
		v.t_foto += dt
		var k: float = v.t_foto / dur
		var p_ant: Vector2 = v.pos
		if k <= 1.0:
			v.pos = v.p_ini.lerp(v.p_fim, k)
		else:
			v.pos = v.p_fim + (v.p_fim - v.p_ini) * (minf(k, 1.5) - 1.0)
		if medir:
			_med_reg(v, dt, p_ant.distance_to(v.pos), "espelho", v.vel)
	for t in tiros:
		t.pos += t.vel * dt
	queue_redraw()


func _atirar(v: V, dir: Vector2) -> void:
	var tiro: Dictionary = v.d.get("tiro", {})
	_novo_tiro(v.pos, dir * float(tiro.get("velocidade", 100)), float(tiro.get("dano", 6)), str(tiro.get("sprite", "proj_email")))


func _anel(v: V) -> void:
	var tiro: Dictionary = v.d.get("tiro", {})
	var n := int(tiro.get("quantos", 10))
	var giro := randf() * TAU
	for i in n:
		var dir := Vector2.from_angle(giro + TAU * i / n)
		_novo_tiro(v.pos, dir * float(tiro.get("velocidade", 90)), float(tiro.get("dano", 8)), str(tiro.get("sprite", "proj_email")))
	Som.tocar("tremor", 0.3, 1.3, -6)


func _novo_tiro(pos: Vector2, vel: Vector2, dano: float, sprite: String) -> void:
	if tiros.size() > 300:
		return
	tiros.append({"pos": pos, "vel": vel, "dano": dano, "tex": Dados.tex(sprite), "vida": 5.0, "sprite": sprite})


# ---------- desenho ----------

## Pra onde o monstro olha: gira com velocidade limitada (GIRO_OLHAR) até o alvo e escolhe a vista da folha por setores de
## 45° (com histerese pra não piscar na divisa). Solo: o alvo é o herói. Cliente online: o deslocamento desenhado (como o
## `gira` do besouro), porque a IA roda no anfitrião. Vírus (vistas = 1) não entram: ficam sempre de frente, sem espelho.
func _orientar(v: V, jx: float, jy: float) -> void:
	if v.vistas <= 1:
		return
	var alvo := v.olhar
	var tem := false
	if espelho:
		if v.pos_olho != Vector2.INF:
			var d: Vector2 = v.pos - v.pos_olho
			var l2 := d.length_squared()
			if l2 > 0.04 and l2 < 400.0:   # parado mantém; teleporte não gira
				alvo = atan2(d.x, d.y)
				tem = true
		v.pos_olho = v.pos
	else:
		var dx := jx - v.pos.x
		var dy := jy - v.pos.y
		if dx * dx + dy * dy > 4.0:
			alvo = atan2(dx, dy)
			tem = true
	if v.orientar:
		v.orientar = false
		if tem:
			v.olhar = alvo
			v.setor = roundi(alvo / (PI * 0.25))
			if v.setor == -4:
				v.setor = 4
	elif tem:
		var passo := GIRO_OLHAR * _dt
		v.olhar = wrapf(v.olhar + clampf(angle_difference(v.olhar, alvo), -passo, passo), -PI, PI)
	if absf(angle_difference(v.setor * (PI * 0.25), v.olhar)) > PI * 0.125 + HIST_OLHAR:
		var k := roundi(v.olhar / (PI * 0.25))
		v.setor = 4 if k == -4 else k
	v.vista = absi(v.setor) if v.vistas > 1 else 0
	v.espelho = v.setor < 0


func _draw() -> void:
	var _d0 := Perf.ini()
	var jx: float = arena.jogador.position.x if arena and arena.jogador else 0.0
	var jy: float = arena.jogador.position.y if arena and arena.jogador else 0.0
	# só entra no desenho quem está na tela (com folga pro tamanho do sprite e da sombra): com 500 bichos, a maioria fica fora.
	# `_ordem` = os visíveis, do mais alto pro mais baixo (quem está embaixo fica na frente). Ordena uma lista de números
	# (y e posição na lista juntos numa chave só) com o sort nativo, todo quadro: bem mais barato que sort_custom.
	var vis: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var x0 := vis.position.x
	var x1 := vis.end.x
	var y0 := vis.position.y
	var y1 := vis.end.y
	_chaves.clear()
	var n := lista.size()
	for i in n:
		var v: V = lista[i]
		var m: float = maxf(v.sz.x, v.sz.y) + 28.0
		var p: Vector2 = v.pos
		if v.hp <= 0 or p.x < x0 - m or p.x > x1 + m or p.y < y0 - m or p.y > y1 + m:
			if v.gira:
				v.pos_ant = p   # fora da tela não gira (e não conta o passo como teleporte quando voltar)
			v.orientar = true   # ninguém vê: ao reaparecer já olha pro alvo (não gira de longe)
			v.pos_olho = Vector2.INF
			continue
		_chaves.append(float((int(p.y * 2.0) + 4194304) << 16) + float(i))
	_chaves.sort()
	_ordem.clear()
	for k in _chaves:
		_ordem.append(lista[int(k) & 65535])
	Perf.fim("ini_d_ordem", _d0)
	var _d1 := Perf.ini()
	# 1ª passada: sombras (todas antes dos sprites, pra nenhuma sombra cair por cima de outro vírus)
	for v: V in _ordem:
		_orientar(v, jx, jy)   # (antes das sombras: elas dependem da vista e do espelho)
		if v.t_nasc > NASC_T * 0.4:
			continue
		var s: Vector2 = v.sz
		var pe: Vector2 = v.pos + Vector2(0, s.y * 0.4)
		var quadro := int(_t * v.ritmo + v.id) % 2
		var esp: bool = v.espelho
		var ic := (v.vista * 2 + quadro) * 2 + (1 if esp else 0)
		var reg: Rect2 = v.sombra_reg[ic]
		var esc_s := s.x / v.tam.x
		if reg.size.x <= 0.0:
			var src := Rect2(v.tam.x * quadro, v.tam.y * v.vista, v.tam.x, v.tam.y)
			reg = Visual.sombra_regiao(v.tex, src, esp)
			v.sombra_reg[ic] = reg
		Visual.contato(self, pe, s.x * 0.75)
		if reg.size.x > 0.0:
			# mesma conta de Visual.sombra: a base do sprite fica em pe.y + (-s.y + s.y) e a esquerda em pe.x - s.x/2 (ou pe.x + s.x/2 - s.x se espelhado = igual)
			Visual.carimbar(self, reg, esc_s, pe.x - s.x * 0.5, pe.y + 0.0)
		else:
			var src2 := Rect2(v.tam.x * quadro, v.tam.y * v.vista, v.tam.x, v.tam.y)
			var rs := Rect2(s.x / 2, -s.y, -s.x, s.y) if esp else Rect2(-s.x / 2, -s.y, s.x, s.y)
			Visual.sombra(self, v.tex, rs, src2, pe)
	Perf.fim("ini_d_sombra", _d1)
	var _d2 := Perf.ini()
	for v: V in _ordem:
		var s: Vector2 = v.sz
		var vira: bool = v.espelho
		var quadro := 2 if v.flash > 0 else (int(_t * v.ritmo + v.id) % 2)
		var cor := Color.WHITE
		if v.aura.a > 0.0:
			draw_circle(v.pos, s.x * 0.5, Color(v.aura.r, v.aura.g, v.aura.b, 0.16 + 0.08 * sin(_t * 5.0 + v.id)))
		elif v.elite:
			draw_circle(v.pos, s.x * 0.55, Color(1.0, 0.85, 0.3, 0.25 + 0.15 * sin(_t * 8.0)))
		elif v.atordoado > 0:
			cor = Color(1.0, 0.95, 0.6)   # atordoado: amarelado, piscando de leve
		elif v.lento > 0:
			cor = Color(0.6, 0.85, 1.0)
		# Rect2 de largura negativa vira o sprite, mas o Godot desenha a partir da posição pra DIREITA (não normaliza):
		# por isso a posição é a borda esquerda nos dois casos (antes o bicho à direita do herói saía deslocado 1 largura).
		var r: Rect2
		if v.estado == 0 and v.flash <= 0.0 and v.balanco <= 0.0 and v.flutua <= 0.0 and v.t_nasc <= 0.0:
			r = Rect2(v.pos.x - s.x * 0.5, v.pos.y - s.y * 0.6, -s.x if vira else s.x, s.y)   # caminho rápido (vírus)
		else:
			var fase_a: float = (_t * v.ritmo + v.id) * PI     # o pulinho acompanha a troca de quadro
			var sx := 1.0
			var sy := 1.0
			var jit := 0.0
			var lift := 0.0
			if v.estado == 1:
				# telegrafa a investida: agacha, treme e avermelha; nos últimos 35% pisca branco
				var u := clampf(1.0 - v.t_estado / 0.7, 0.0, 1.0)
				sx = 1.0 + 0.18 * u
				sy = 1.0 - 0.24 * u
				jit = sin(_t * 90.0 + v.id) * 1.5 * u
				cor = Color(1.0, 1.0 - 0.55 * u, 1.0 - 0.6 * u)
				if u > 0.65 and int(_t * 20.0) % 2 == 0:
					quadro = 2
			elif v.estado == 2:
				sx = 1.22      # em disparada: esticado no sentido da corrida
				sy = 0.86
			else:
				var sn := sin(fase_a)
				if v.balanco > 0.0:
					lift = absf(sn) * v.balanco
				var respira := 1.0 - 2.0 * sn * sn      # = cos(2 x fase), sem outra chamada trigonométrica
				sx = 1.0 + 0.045 * respira
				sy = 1.0 - 0.045 * respira
			if v.flutua > 0.0:
				lift += v.flutua * (1.0 + 0.25 * sin(_t * 3.0 + v.id))
			if v.flash > 0.0:
				var k := v.flash / 0.09      # squash ao levar dano: achata e alarga, voltando em ~0,1 s
				sx *= 1.0 + 0.3 * k
				sy *= 1.0 - 0.24 * k
			if v.t_nasc > 0.0:
				# nasce / reaparece (teleporte): sai de uma nuvem escura, crescendo e ficando opaco
				var u := 1.0 - v.t_nasc / NASC_T
				sx *= 0.45 + 0.55 * u
				sy *= 0.3 + 0.7 * u
				cor.a = u
				_nuvem(v.pos + Vector2(0, s.y * 0.35), s.x, u, v.id)
			var w := roundf(s.x * sx)   # a largura nunca vai a ~0: virar é trocar de vista, não achatar
			var h := roundf(s.y * sy)
			r = Rect2(roundf(v.pos.x + jit) - roundf(w * 0.5), roundf(v.pos.y + s.y * 0.4 - lift) - h, -w if vira else w, h)
		v.dr = r
		var fonte := Rect2(v.tam.x * quadro, v.tam.y * v.vista, v.tam.x, v.tam.y)
		if v.gira:
			# visto de cima: a cabeça aponta pra onde ele anda (antes vinha de ré quando descia na direção do herói)
			var passo: Vector2 = v.pos - v.pos_ant if v.pos_ant != Vector2.INF else Vector2.ZERO
			v.pos_ant = v.pos
			if passo.length_squared() > 0.04 and passo.length_squared() < 400.0:   # parado mantém; teleporte não gira
				v.ang = lerp_angle(v.ang, passo.angle() + PI * 0.5, minf(1.0, _dt * 10.0))
			var gw := absf(r.size.x)
			draw_set_transform(r.position + Vector2(gw, r.size.y) * 0.5, v.ang)
			draw_texture_rect_region(v.tex, Rect2(-gw * 0.5, -r.size.y * 0.5, gw, r.size.y), fonte, cor)
			draw_set_transform(Vector2.ZERO, 0.0)
		else:
			draw_texture_rect_region(v.tex, r, fonte, cor)
	Perf.fim("ini_d_sprite", _d2)
	for f in fantasmas:   # quem acabou de teleportar: encolhe e some numa nuvem escura onde estava
		var u: float = f.t / NASC_T
		var fs: Vector2 = f.sz * (1.0 - 0.6 * u)
		var fp: Vector2 = f.pos
		var fe := fp + Vector2(0, f.sz.y * 0.4)
		_nuvem(fe + Vector2(0, -f.sz.y * 0.05), f.sz.x, u, f.id)
		draw_texture_rect_region(f.tex, Rect2(fp.x - fs.x * 0.5, fe.y - fs.y, -fs.x if f.vira else fs.x, fs.y),
			Rect2(f.tam.x * f.quadro, f.y0, f.tam.x, f.tam.y), Color(1, 1, 1, 1.0 - u))
	for t in tiros:
		var tx: Texture2D = t.tex
		var sz := tx.get_size() * ESCALA
		draw_set_transform(t.pos, t.vel.angle(), Vector2.ONE)
		draw_texture_rect(tx, Rect2(-sz / 2, sz), false)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
