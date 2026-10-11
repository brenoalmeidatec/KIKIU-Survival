extends Node2D
## Elementos e estados dos inimigos (#72 marco 5): fogo queima, gelo deixa lento e congela, raio salta entre vizinhos,
## veneno acumula. Tudo vem de dados/elementos.json (acúmulos, teto, duração, resistências, reações).
##
## Custo: o estado de cada inimigo vive AQUI, num dicionário só de quem tem estado (`estados`, id -> registro), e é o único
## que `passo()` percorre; o laço dos 500 inimigos em inimigos.gd só lê `v.el_vis` (um inteiro) pra pintar. Sem estado nenhum,
## `passo()` e o desenho saem na primeira linha. As partículas não têm lista: a posição de cada uma é função do tempo e do
## id do inimigo, então não há nada pra alocar nem pra limpar.
##
## Online: só o anfitrião roda os estados (dano, lentidão, congelamento). Os bits do que pesa (congelado, queimando, envenenado)
## vão na foto (online.gd) e o cliente só pinta (`aplicar_vis`).

const Perf := preload("res://scripts/hordas/perf.gd")
const BITS := {"fogo": 1, "gelo": 2, "raio": 4, "veneno": 8}
const BIT_CONG := 16

var ino: Node                      # inimigos.gd
var estados := {}                  # id -> {v, st{elemento: [acúmulos, resto, tique]}, cong, imune, cd, acc, num}
var vis := {}                      # cliente: id -> V que a foto marcou com algum estado
var contagem := {"qualquer": 0, "fogo": 0, "gelo": 0, "raio": 0, "veneno": 0, "congelados": 0, "reacoes": 0}
var reacoes_n := {}                # id da reação -> quantas vezes disparou
var chance := {}                   # elemento -> chance por golpe de qualquer arma (atributo el_<elemento>)
var arcos: Array = []              # {a, b, t}: saltos do raio, só desenho
var aneis: Array = []              # {pos, r, t, total, cor, nome}: reações, só desenho
var _marc := {}                    # id * 8 + índice -> true (cada inimigo conta uma vez por elemento, por fase)
var _por_arma := {}                # id da arma -> [elemento, acúmulos por golpe]
var _els: Dictionary
var _reacoes: Array
var _tv: Dictionary
var _pt: Dictionary
var _saltos := 0
var _nums := 0
var _dano_mult := 1.0
var _desenhadas := 0


func _ready() -> void:
	var cfg: Dictionary = Dados.json("elementos")
	_els = cfg.get("elementos", {})
	_reacoes = cfg.get("reacoes", [])
	_tv = cfg.get("teto_visual", {})
	_pt = cfg.get("por_tipo", {})
	z_index = 1


static func cor_de(el: String) -> Color:
	var c: Array = Dados.json("elementos").get("elementos", {}).get(el, {}).get("cor", [1, 1, 1])
	return Color(c[0], c[1], c[2])


## Atributos el_<elemento> do herói (chance por golpe): a arena chama quando recalcula a build.
func recalcular(stats: Dictionary) -> void:
	chance.clear()
	for el in _els:
		var p := float(stats.get("el_" + str(el), 0.0))
		if p > 0.0:
			chance[el] = p


## Tira todos os estados (fim do andar, duelo): os contadores do santuário continuam.
func limpar() -> void:
	for id in estados.keys():
		_soltar(id)
	estados.clear()
	for v in vis.values():
		v.el_vis = 0
	vis.clear()
	arcos.clear()
	aneis.clear()


## Andar novo: estados e contadores do zero.
func nova_fase() -> void:
	limpar()
	_marc.clear()
	for k in contagem:
		contagem[k] = 0


## Elemento e acúmulos por golpe de uma arma (cache). Vem de `elemento` e `elem_acumulos` no armas.json.
func _de_arma(arma: String) -> Array:
	var r = _por_arma.get(arma)
	if r == null:
		var d: Dictionary = Dados.item(arma) if arma != "" else {}
		r = [str(d.get("elemento", "")), float(d.get("elem_acumulos", 1.0))]
		_por_arma[arma] = r
	return r


## Um golpe acertou `v` e ele sobreviveu (inimigos.ferir). `el` forçado = a bola do Poder Elemental.
func golpe(v, arma: String, el := "") -> void:
	if el != "" and _els.has(el):
		aplicar(v, el, 1.0, arma)
	else:
		var ae := _de_arma(arma)
		if ae[0] != "":
			aplicar(v, ae[0], ae[1], arma)
	if not chance.is_empty():
		for e in chance:
			if randf() < chance[e]:
				aplicar(v, e, 1.0, arma)


var remotos := 0   # teste/log: golpes de clientes que puseram elemento pela arma deles


## Golpe de arma de outro jogador (cliente online): só o elemento da própria arma, sem a `chance` do anfitrião.
func golpe_remoto(v, arma: String) -> void:
	var ae := _de_arma(arma)
	if ae[0] != "" and aplicar(v, ae[0], ae[1], arma) > 0.0:
		remotos += 1


## Soma `n` acúmulos de `el` em `v` (com resistência, chefe/elite e teto). Devolve quanto realmente entrou.
func aplicar(v, el: String, n := 1.0, _fonte := "") -> float:
	if not _els.has(el) or v.hp <= 0.0 or n <= 0.0:
		return 0.0
	var res := float(v.resist.get(el, 0.0))
	if res >= 1.0:
		return 0.0
	var ganho := n * (1.0 - res)
	if v.chefe:
		ganho *= float(_pt.get("mult_chefe", 1.0))
	elif v.elite:
		ganho *= float(_pt.get("mult_elite", 1.0))
	if ganho <= 0.0:
		return 0.0
	var cfg: Dictionary = _els[el]
	var rec = estados.get(v.id)
	if rec == null:
		rec = {"v": v, "st": {}, "cong": 0.0, "imune": 0.0, "cd": 0.0, "acc": 0.0, "num": 0.0}
		estados[v.id] = rec
	if el == "gelo" and rec.cong > 0.0:
		return 0.0   # já congelado: o gelo não passa disso
	var st = rec.st.get(el)
	if st == null:
		st = [0.0, 0.0, 0.0]
		rec.st[el] = st
	var antes: float = st[0]
	st[0] = minf(float(cfg.get("teto", 5)), st[0] + ganho)
	st[1] = float(cfg.get("duracao", 3.0))
	_contar(v.id, el)
	_bits(rec)
	_reagir(rec, el)
	if el == "gelo" and v.hp > 0.0 and rec.imune <= 0.0 and rec.st.has("gelo") and rec.st["gelo"][0] >= float(cfg.get("congela_em", 4)) - 0.001:
		_congelar(rec, cfg)
	return st[0] - antes


func _contar(id: int, el: String) -> void:
	var k: int = id * 8 + (BITS.keys().find(el))
	if _marc.has(k):
		return
	_marc[k] = true
	contagem[el] = int(contagem.get(el, 0)) + 1
	var kq: int = id * 8 + 7
	if not _marc.has(kq):
		_marc[kq] = true
		contagem["qualquer"] += 1


func acumulos(v, el: String) -> float:
	var rec = estados.get(v.id)
	if rec == null or not rec.st.has(el):
		return 0.0
	return rec.st[el][0]


func congelado(v) -> bool:
	var rec = estados.get(v.id)
	return rec != null and rec.cong > 0.0


func _bits(rec: Dictionary) -> void:
	var b := 0
	for el in rec.st:
		if rec.st[el][0] > 0.0:
			b |= int(BITS[el])
	if rec.cong > 0.0:
		b |= BIT_CONG
	rec.v.el_vis = b


func _congelar(rec: Dictionary, cfg: Dictionary) -> void:
	var v = rec.v
	rec.cong = float(cfg.get("congela_dur", 1.6))
	rec.imune = float(cfg.get("congela_imune", 3.0))
	rec.st["gelo"][0] = 0.0
	v.atordoado = maxf(v.atordoado, rec.cong)
	contagem["congelados"] += 1
	_bits(rec)
	if ino.arena and ino.arena.efeitos:
		ino.arena.efeitos.impacto(v.pos + Vector2(0, -6), cor_de("gelo"), false)


# ---------- reações ----------

func _reagir(rec: Dictionary, el: String) -> void:
	if rec.cd > 0.0:
		return
	for r in _reacoes:
		if r.a != el and r.b != el:
			continue
		var m := float(r.get("min", 1.0))
		if _st(rec, r.a) >= m and _st(rec, r.b) >= m:
			_disparar(rec, r)
			return


func _st(rec: Dictionary, el: String) -> float:
	var s = rec.st.get(el)
	return 0.0 if s == null else s[0]


func _disparar(rec: Dictionary, r: Dictionary) -> void:
	var v = rec.v
	rec.cd = float(r.get("cd", 1.2))
	var gasto := 0.0
	for el in r.get("consome", []):
		gasto += _st(rec, el)
		if rec.st.has(el):
			rec.st[el][0] = 0.0
	_bits(rec)
	var dano := float(r.get("dano", 10.0)) * _mult_dano()
	if bool(r.get("por_acumulo", false)):
		dano *= maxf(1.0, gasto)
	var raio := float(r.get("raio", 56))
	var causa := str(r.get("causa", r.a))
	var c: Array = r.get("cor", [1, 1, 1])
	var cor := Color(c[0], c[1], c[2])
	direto(v, dano, causa, Vector2.ZERO, cor)   # o alvo sempre leva, mesmo se a grade ainda não o tem
	for w in ino.no_circulo(v.pos, raio):
		if w != v:
			direto(w, dano, causa, (w.pos - v.pos).normalized() * 60.0, cor)
	contagem["reacoes"] += 1
	reacoes_n[r.id] = int(reacoes_n.get(r.id, 0)) + 1
	if aneis.size() < int(_tv.get("reacoes", 8)):
		aneis.append({"pos": v.pos, "r": raio, "t": 0.45, "total": 0.45, "cor": cor, "nome": str(r.get("nome", ""))})
	if ino.arena and ino.arena.efeitos:
		ino.arena.efeitos.luz(v.pos, raio * 1.8, cor)
		ino.arena.efeitos.impacto(v.pos + Vector2(0, -6), cor, true)
		ino.arena.efeitos.explodir(v.pos, cor, 6, 90.0)
	Som.tocar("queda", 0.1, 1.3, -12)


# ---------- dano ----------

func _mult_dano() -> float:
	return ino.arena.stat("dano") if ino.arena else 1.0


## Dano de elemento sem o caminho de golpe (sem crítico, sem recuo forte, sem estrela de impacto): reações e saltos do raio.
func direto(v, valor: float, causa: String, empurrao := Vector2.ZERO, cor := Color.WHITE) -> void:
	if v.hp <= 0.0 or ino.espelho:
		return
	v.hp -= valor
	v.flash = 0.09
	v.arma_ult = ""
	v.causa_ult = causa
	v.kb = (v.kb + empurrao / (12.0 if v.chefe else (4.0 if v.pesado else 1.0))).limit_length(ino.KB_MAX)
	_creditar(causa, valor)
	if ino.arena and ino.arena.efeitos:
		ino.arena.efeitos.numero(v.pos, valor, cor, false)
	if v.hp <= 0.0:
		_matar(v)


## Dano no tempo (queimar, envenenar): quieto. Um número agrupado por segundo no máximo, só em quem está na tela.
func _tique(rec: Dictionary, valor: float, el: String) -> void:
	var v = rec.v
	if v.hp <= 0.0:
		return
	v.hp -= valor
	v.arma_ult = ""
	v.causa_ult = str(_els[el].get("causa", el))
	_creditar(el, valor)
	rec.acc += valor
	if v.hp <= 0.0:
		if ino.arena and ino.arena.efeitos and rec.acc >= 1.0:
			ino.arena.efeitos.numero(v.pos, rec.acc, cor_de(el), false)
		_matar(v)
		return
	rec.num -= _dt
	if rec.num <= 0.0 and rec.acc >= 1.0 and _nums < int(_tv.get("numeros_quadro", 3)) and ino._na_tela(v.pos):
		_nums += 1
		rec.num = float(_tv.get("numero_cada", 1.0))
		if ino.arena and ino.arena.efeitos:
			ino.arena.efeitos.numero(v.pos, rec.acc, cor_de(el), false)
		rec.acc = 0.0


func _creditar(causa: String, valor: float) -> void:
	if ino.arena and ino.arena.has_method("creditar_dano"):
		ino.arena.creditar_dano("elem_" + causa, valor)


func _matar(v) -> void:
	ino._remover(v)
	ino._morte_visual(v)
	ino.arena.inimigo_morreu(v)


# ---------- passo ----------

var _dt := 0.016


## Todo quadro, no anfitrião, depois da grade. Sem estado nenhum: volta na primeira linha.
func passo(dt: float) -> void:
	if estados.is_empty() and arcos.is_empty() and aneis.is_empty():
		return
	var _p := Perf.ini()
	_dt = dt
	_saltos = 0
	_nums = 0
	_dano_mult = _mult_dano()
	for i in range(arcos.size() - 1, -1, -1):
		arcos[i].t -= dt
		if arcos[i].t <= 0.0:
			arcos.remove_at(i)
	for i in range(aneis.size() - 1, -1, -1):
		aneis[i].t -= dt
		if aneis[i].t <= 0.0:
			aneis.remove_at(i)
	var fim: Array = []
	for id in estados.keys():
		if not estados.has(id):   # uma reação anterior deste mesmo laço já tirou este estado (SCRIPT ERROR visto em partidas longas do robô)
			continue
		var rec: Dictionary = estados[id]
		var v = rec.v
		if v.hp <= 0.0 or ino.por_id.get(id) != v:
			fim.append(id)
			continue
		if rec.cd > 0.0:
			rec.cd -= dt
		if rec.imune > 0.0:
			rec.imune -= dt
		var mudou := false
		if rec.cong > 0.0:
			rec.cong -= dt
			if rec.cong <= 0.0:
				rec.cong = 0.0
				mudou = true
		var vivo: bool = rec.cong > 0.0 or rec.imune > 0.0 or rec.cd > 0.0   # imunidade e espera de reação também precisam do registro
		for el in rec.st:
			var st: Array = rec.st[el]
			if st[0] <= 0.0:
				continue
			st[1] -= dt
			if st[1] <= 0.0:
				st[0] = 0.0
				mudou = true
				continue
			vivo = true
			var cfg: Dictionary = _els[el]
			match el:
				"fogo", "veneno":
					st[2] += dt
					var tq := float(cfg.get("tique", 0.5))
					if st[2] >= tq:
						st[2] -= tq
						_tique(rec, st[0] * float(cfg.get("dps", 2.0)) * tq * _dano_mult, el)
						if v.hp <= 0.0:
							break
				"gelo":
					v.lento = maxf(v.lento, 0.12)
				"raio":
					st[2] += dt
					if st[2] >= float(cfg.get("tique", 0.8)) and _saltos < int(_tv.get("saltos_quadro", 8)):
						st[2] = 0.0
						_saltos += 1
						_saltar(v, st[0], cfg)
		if v.hp <= 0.0:
			fim.append(id)
			continue
		if mudou:
			_bits(rec)
		if not vivo:
			fim.append(id)
	for id in fim:
		_soltar(id)
		estados.erase(id)
	queue_redraw()
	Perf.fim("elem_p", _p)


func _soltar(id: int) -> void:
	var rec = estados.get(id)
	if rec != null:
		rec.v.el_vis = 0


func _saltar(v, acumulos_n: float, cfg: Dictionary) -> void:
	var s: Dictionary = cfg.get("salto", {})
	var alvos := int(s.get("alvos", 2))
	var ordem: Array = []
	for w in ino.no_circulo(v.pos, float(s.get("raio", 70))):
		if w != v and w.hp > 0.0:
			ordem.append([w.pos.distance_squared_to(v.pos), w])
	if ordem.is_empty():
		return
	ordem.sort_custom(func(a, b): return a[0] < b[0])
	var dano := float(s.get("dano", 4.0)) * acumulos_n * _dano_mult
	for i in mini(alvos, ordem.size()):
		var w = ordem[i][1]
		if arcos.size() < int(_tv.get("arcos", 20)):
			arcos.append({"a": v.pos, "b": w.pos, "t": 0.18})
		direto(w, dano, "raio", Vector2.ZERO, cor_de("raio"))


# ---------- cliente ----------

## Cliente online: a foto do anfitrião traz bits 32 (congelado), 64 (queimando), 128 (envenenado) e 16 (lento).
## Devolve o el_vis. Conta o primeiro estado de cada inimigo pro santuário selado, igual ao anfitrião.
func aplicar_vis(v, flags: int) -> void:
	var b := 0
	if (flags & 16) != 0:
		b |= BITS["gelo"]
	if (flags & 32) != 0:
		b |= BIT_CONG
	if (flags & 64) != 0:
		b |= BITS["fogo"]
	if (flags & 128) != 0:
		b |= BITS["veneno"]
	if b == 0:
		if v.el_vis != 0:
			vis.erase(v.id)
			v.el_vis = 0
		return
	if v.el_vis == 0:
		vis[v.id] = v
		var kq: int = v.id * 8 + 7
		if not _marc.has(kq):
			_marc[kq] = true
			contagem["qualquer"] += 1
	v.el_vis = b


## O que a foto leva dos estados (bits 32, 64 e 128 do flags de online.gd).
static func flags_de(el_vis: int) -> int:
	return (32 if (el_vis & BIT_CONG) != 0 else 0) | (64 if (el_vis & 1) != 0 else 0) | (128 if (el_vis & 8) != 0 else 0)


## Tinta do inimigo conforme o estado (prioridade: congelado, fogo, veneno, raio, gelo), ou Color.WHITE se não tem.
static func tinta(bits: int, t: float, id: int) -> Color:
	if (bits & BIT_CONG) != 0:
		return Color(0.62, 0.88, 1.0, 0.88)
	if (bits & 1) != 0:
		return Color(1.0, 0.72, 0.5) if int(t * 9.0 + id) % 2 == 0 else Color(1.0, 0.85, 0.65)
	if (bits & 8) != 0:
		return Color(0.7, 1.0, 0.6)
	if (bits & 4) != 0:
		return Color(0.85, 0.92, 1.0) if int(t * 14.0 + id) % 3 != 0 else Color(1, 1, 1)
	if (bits & 2) != 0:
		return Color(0.6, 0.85, 1.0)
	return Color.WHITE


# ---------- desenho ----------

static func _h(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	var fonte: Dictionary = vis if ino.espelho else estados
	if fonte.is_empty() and arcos.is_empty() and aneis.is_empty():
		return
	var _p := Perf.ini()
	_desenhadas = 0
	var tt := float(Time.get_ticks_msec()) * 0.001
	var teto := roundi(float(_tv.get("particulas", 150)) * Config.fator_particulas("elem_part"))   # perfil de qualidade
	for id in fonte:
		var rec = fonte[id]
		var v = rec if ino.espelho else rec.v
		if v.el_vis == 0 or not ino._na_tela(v.pos):
			continue
		_desenhar_v(v, ino.espelho, rec, tt, teto)
	for a in arcos:   # saltos do raio: duas pernas tortas, brilho largo e fio branco
		var m: Vector2 = (a.a + a.b) * 0.5 + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		var c := cor_de("raio")
		draw_polyline(PackedVector2Array([a.a, m, a.b]), Color(c, 0.3 * a.t / 0.18), 3.0)
		draw_polyline(PackedVector2Array([a.a, m, a.b]), Color(1, 1, 1, 0.9 * a.t / 0.18), 1.0)
	for r in aneis:
		var u: float = 1.0 - r.t / r.total
		var rr: float = r.r * (0.4 + 0.6 * u)
		draw_set_transform(r.pos, 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, rr, Color(r.cor, 0.22 * (1.0 - u)))
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 32, Color(r.cor, 0.85 * (1.0 - u)), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if Dados.fonte and r.nome != "":
			draw_string(Dados.fonte, r.pos + Vector2(-40, -r.r * 0.7 - 12.0 * u), r.nome, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 8, Color(1, 1, 1, 1.0 - u))
	Perf.fim("elem_d", _p)


func _desenhar_v(v, cliente: bool, rec, tt: float, teto: int) -> void:
	var s: Vector2 = v.sz
	var c: Vector2 = v.pos + Vector2(0, -s.y * 0.1)
	var b: int = v.el_vis
	if (b & BIT_CONG) != 0:   # gelo que segue a forma: o próprio sprite já sai tingido (tinta); aqui só brilhos e cristais nos pés
		var fy: float = v.pos.y + s.y * 0.38
		for k in 3:   # brilhos brancos que piscam sobre o corpo
			if int(tt * 6.0 + k * 2 + v.id) % 3 == 0:
				continue
			var gp: Vector2 = c + Vector2((_h(v.id, k + 20) - 0.5) * s.x * 0.6, (_h(v.id, k + 30) - 0.5) * s.y * 0.5)
			draw_rect(Rect2(roundf(gp.x) - 1, roundf(gp.y), 3, 1), Color(1, 1, 1, 0.95))
			draw_rect(Rect2(roundf(gp.x), roundf(gp.y) - 1, 1, 3), Color(1, 1, 1, 0.95))
		for k in 4:   # estilhaços curtos espetados no chão
			var sx: float = v.pos.x + (_h(v.id, k + 40) - 0.5) * s.x * 0.8
			var alt: float = 3.0 + _h(v.id, k + 50) * 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(roundf(sx) - 2, fy), Vector2(roundf(sx) + 2, fy), Vector2(roundf(sx) + (k - 1.5), fy - alt)]), Color(0.8, 0.95, 1.0, 0.9))
	if _desenhadas >= teto:
		_pips(v, cliente, rec)
		return
	if (b & 1) != 0:   # brasas subindo
		for k in 3:
			var ph := fposmod(tt * 1.1 + k * 0.34 + _h(v.id, k), 1.0)
			var x := c.x + (_h(v.id, k + 9) - 0.5) * s.x * 0.7
			var y := c.y + s.y * 0.2 - ph * s.y * 0.9
			draw_rect(Rect2(roundf(x), roundf(y), 2, 2), Color(1.0, 0.85 - 0.5 * ph, 0.2, 1.0 - ph))
		_desenhadas += 3
	if (b & 8) != 0:   # bolhas verdes, mais lentas
		for k in 2:
			var ph := fposmod(tt * 0.6 + k * 0.5 + _h(v.id, k + 3), 1.0)
			var x := c.x + (_h(v.id, k + 5) - 0.5) * s.x * 0.8
			var y := c.y + s.y * 0.3 - ph * s.y * 0.8
			draw_rect(Rect2(roundf(x), roundf(y), 2, 2), Color(0.5, 0.95, 0.3, 1.0 - ph))
			draw_rect(Rect2(roundf(x), roundf(y), 1, 1), Color(0.85, 1.0, 0.6, 1.0 - ph))
		_desenhadas += 4
	if (b & 2) != 0 and (b & BIT_CONG) == 0:   # cristais piscando em volta
		for k in 2:
			if int(tt * 5.0 + k * 2 + v.id) % 3 != 0:
				continue
			var p := c + Vector2((_h(v.id, k + 1) - 0.5) * s.x * 0.9, (_h(v.id, k + 2) - 0.5) * s.y * 0.8)
			draw_rect(Rect2(roundf(p.x) - 1, roundf(p.y), 3, 1), Color(0.85, 0.97, 1.0))
			draw_rect(Rect2(roundf(p.x), roundf(p.y) - 1, 1, 3), Color(0.85, 0.97, 1.0))
		_desenhadas += 2
	if (b & 4) != 0 and int(tt * 14.0 + v.id) % 3 == 0:   # faíscas curtas
		var p0 := c + Vector2((_h(v.id, int(tt * 14.0)) - 0.5) * s.x, -s.y * 0.35)
		draw_polyline(PackedVector2Array([p0, p0 + Vector2(3, 4), p0 + Vector2(-1, 6), p0 + Vector2(2, 10)]), Color(0.9, 0.95, 1.0), 1.0)
		_desenhadas += 2
	_pips(v, cliente, rec)


## Marcas do acúmulo, só em elite e chefe (os outros morrem rápido demais pra valer a pena): uma por acúmulo, por elemento.
func _pips(v, cliente: bool, rec) -> void:
	if not (v.elite or v.chefe):
		return
	var lista: Array = []
	if cliente:
		for el in BITS:
			if (v.el_vis & int(BITS[el])) != 0:
				lista.append([el, 1])
	else:
		for el in rec.st:
			var n := ceili(rec.st[el][0])
			if n > 0:
				lista.append([el, n])
	if lista.is_empty():
		return
	var total := 0
	for e in lista:
		total += int(e[1])
	total = mini(total, 14)
	var x0 := roundf(v.pos.x - total * 2.5)
	var y0 := roundf(v.pos.y - v.sz.y * 0.6 - 9.0)
	var i := 0
	for e in lista:
		var cor := cor_de(e[0])
		for _k in int(e[1]):
			if i >= total:
				return
			draw_rect(Rect2(x0 + i * 5.0 - 1, y0 - 1, 5, 5), Color(0.05, 0.04, 0.08, 0.85))
			draw_rect(Rect2(x0 + i * 5.0, y0, 3, 3), cor)
			i += 1
