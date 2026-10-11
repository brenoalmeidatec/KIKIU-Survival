extends RefCounted
## Animação procedural dos heróis (#97): respiração parado, balanço e inclinação andando, golpe com peso, recuo ao
## apanhar e queda na morte. Não são quadros novos: é o sprite inteiro mexendo (escala, posição e inclinação por
## cisalhamento, que mantém o pixel art nítido). Todos os números estão em dados/animacao.json; os PADRAO daqui só
## entram quando o arquivo some ou perde uma chave (e o teste animacao_heroi.tscn confere que os dois batem).
##
## Uso: um `AnimacaoHeroi.new()` por boneco (herói local e cada pessoa do online). A cada quadro `atualizar(...)`,
## depois leia escala(), desloc() e inclina(). As poses de golpe, dano e morte são funções puras (estáticas).

const PADRAO := {
	"respiracao": {"hz": 0.65, "altura": 0.03, "largura": 0.35, "pixel": true, "altura_px": 56.0, "folha_animada": 0.5},
	"andar":
	{"px_por_ciclo": 66.7, "ciclos_max": 2.6, "balanco_px": 1.5, "fase": 0.0, "inclina": 0.045, "vel_ref": 100.0, "suavidade": 14.0, "suavidade_inclina": 11.0},
	"squash": {"entrada": 40.0},
	"golpe":
	{"tempo": 0.26, "antecipa": 0.24, "bate": 0.36, "avanco": 8.0, "recuo": 3.0, "passa": 0.3, "inclina": 0.2, "estica": 0.16, "agacha": 0.1, "assenta": 0.07},
	"dano": {"tempo": 0.26, "recuo_px": 3.0, "achata": 0.14, "inclina": 0.1},
	"morte": {"tempo": 0.8, "tropeco": 0.12, "queda": 0.38, "quica": 0.16, "x": -30.0, "y": -10.0, "alpha": 0.8},
}
static var _cfg := {}
static var _fonte = null

# ---- estado de um boneco ----
var t := 0.0
var fase := 0.0  # 0..1: defasagem da respiração (cada boneco respira num ritmo próprio)
var ciclo := 0.0  # 0..1: ponto do ciclo de andar (8 quadros); avança com a distância andada, não com o relógio
var mix := 0.0  # 0 parado .. 1 andando (suavizado)
var incl := 0.0  # inclinação atual (cisalhamento em rad)
var resp := Vector2.ZERO  # variação de escala da respiração
var bob := 0.0  # px que o corpo sobe no balanço do passo
var _andava := false


## Seção da tabela (dados/animacao.json) com os padrões por baixo. Guarda o resultado até a tabela ser recarregada.
static func sec(nome: String) -> Dictionary:
	var d: Dictionary = Dados.json("animacao")
	if _fonte == null or not is_same(_fonte, d):
		_cfg = {}
		for k in PADRAO:
			var s: Dictionary = PADRAO[k].duplicate()
			var o = d.get(k, {})
			if o is Dictionary:
				s.merge(o, true)
			_cfg[k] = s
		_fonte = d
	return _cfg[nome]


## Defasagem estável (0..1) a partir de um texto (herói, pessoa do online): grupo não respira em uníssono.
static func fase_de(texto: String) -> float:
	return float(absi(texto.hash()) % 1000) / 1000.0


## Suavização exponencial independente da taxa de quadros: vai de `atual` até `alvo` com constante `taxa` (1/s).
static func suave(atual: float, alvo: float, taxa: float, dt: float) -> float:
	return lerpf(atual, alvo, 1.0 - exp(-taxa * maxf(dt, 0.0)))


## Respiração parado: variação de escala (x, y) no instante t. O pé fica fixo (a origem do sprite é o pé).
## Com "pixel", a altura muda em passos de 1 px (a cabeça sobe 0, 1 ou 2 px, sem pixel "derretido").
static func respiracao(t_: float, fase_: float, c: Dictionary) -> Vector2:
	var s := sin(TAU * (float(c.hz) * t_ + fase_))
	var y := float(c.altura) * (0.5 + 0.5 * s)
	if bool(c.pixel):
		var h := maxf(float(c.altura_px), 1.0)
		y = roundf(y * h) / h
	return Vector2(-y * float(c.largura), y)


## Quadro da folha andando (coluna 1..8) para um ponto do ciclo 0..1.
static func quadro_andar(ciclo_: float) -> int:
	return 1 + int(floorf(ciclo_ * 8.0)) % 8


## Balanço do passo em px (>= 0): dois apoios por ciclo (o corpo está mais baixo nos quadros de apoio, mais alto entre eles).
static func balanco(ciclo_: float, vel_frac: float, c: Dictionary) -> float:
	var k := 0.5 - 0.5 * cos(TAU * 2.0 * (ciclo_ + float(c.fase)))
	return float(c.balanco_px) * k * clampf(vel_frac, 0.0, 1.0)


## Um quadro do estado do boneco. `vel` = velocidade real em px/s; `anda` = intenção de andar (ou, no online, o
## estado recebido); `ativo` = false durante rolamento/queda/transformação (zera o efeito sem estalo, suavizando).
func atualizar(dt: float, vel: Vector2, anda: bool, ativo := true, folha_animada := false) -> void:
	t += dt
	var a := sec("andar")
	var anda_ef := anda and ativo
	if anda_ef and not _andava and mix < 0.3:
		ciclo = 0.0  # saiu do parado: começa o passo no primeiro quadro (apoio), sem pular pra um ponto qualquer
	_andava = anda_ef
	mix = suave(mix, 1.0 if anda_ef else 0.0, float(a.suavidade), dt)
	var v := vel.length()
	if anda_ef:
		# o ciclo anda com a distância percorrida (sem patinar quando o herói é lento ou rápido); o teto evita o pisca-pisca
		var vmax := float(a.px_por_ciclo) * float(a.ciclos_max)
		ciclo = fposmod(ciclo + minf(v, vmax) / maxf(float(a.px_por_ciclo), 1.0) * dt, 1.0)
	var vf := v / maxf(float(a.vel_ref), 1.0)
	bob = balanco(ciclo, vf, a) * mix
	var alvo_inc := clampf(vel.x / maxf(float(a.vel_ref), 1.0), -1.2, 1.2) * float(a.inclina) if ativo else 0.0
	incl = suave(incl, alvo_inc, float(a.suavidade_inclina), dt)
	var r := sec("respiracao")
	var m := (1.0 - mix) * (float(r.folha_animada) if folha_animada else 1.0) if ativo else 0.0
	resp = respiracao(t, fase, r) * m


func escala() -> Vector2:
	return resp


## Deslocamento do corpo em px inteiros (o balanço do passo).
func desloc() -> Vector2:
	return Vector2(0.0, -roundf(bob))


func inclina() -> float:
	return incl


## Pose do golpe do corpo em u (0..1): [deslocamento ao longo do golpe em px, estica (>0) ou achata, inclinação -1..1].
## Antecipação (recua e agacha, ease-out), golpe rápido que acelera até passar do alvo (passa), e assenta com
## amortecimento (volta com um leve achatamento do impacto). `c` = seção "golpe".
static func pose_golpe(u: float, c: Dictionary = {}) -> Vector3:
	if c.is_empty():
		c = sec("golpe")
	var a := float(c.antecipa)
	var b := float(c.bate)
	var pico := float(c.avanco) * (1.0 + float(c.passa))
	if u <= 0.0:
		return Vector3.ZERO
	if u < a:
		var k := u / a
		k = 1.0 - (1.0 - k) * (1.0 - k)
		return Vector3(-float(c.recuo) * k, -float(c.agacha) * k, -0.35 * k)
	if u < b:
		var k := (u - a) / (b - a)
		k *= k  # acelera: o golpe é rápido
		return Vector3(lerpf(-float(c.recuo), pico, k), lerpf(-float(c.agacha), float(c.estica), k), lerpf(-0.35, 1.0, k))
	var k := minf((u - b) / (1.0 - b), 1.0)
	var f := (1.0 + 6.0 * k) * exp(-6.0 * k) * (1.0 - k * k * k)
	var impacto := float(c.assenta) * sin(PI * minf(k * 2.0, 1.0))
	return Vector3(pico * f, float(c.estica) * f - impacto * (1.0 - k), f)


## Recuo ao apanhar em u (0..1): [px pra longe do golpe, achata (>0 = mais largo e mais baixo), inclinação -1..1].
## Sobe rápido (~25 % do tempo) e volta suave.
static func pose_dano(u: float, c: Dictionary = {}) -> Vector3:
	if c.is_empty():
		c = sec("dano")
	if u <= 0.0 or u >= 1.0:
		return Vector3.ZERO
	var f := u / 0.25 if u < 0.25 else pow(1.0 - (u - 0.25) / 0.75, 2.0)
	f = minf(f, 1.0)
	return Vector3(float(c.recuo_px) * f, float(c.achata) * f, f)


## Queda de morte pra folhas sem quadros de morte, em u (0..1) e `sinal` (+1 cai pra direita, -1 pra esquerda):
## {"rot": rad, "pos": Vector2, "mix": 0..1}. Tropeça pra trás, cai acelerando, quica um pouco e fica deitado na pose
## de sempre (rot ±90°, pos (x, y) da tabela). `mix` pinta o corpo de cinza e tira um pouco da opacidade.
static func pose_morte(u: float, sinal: float, c: Dictionary = {}) -> Dictionary:
	if c.is_empty():
		c = sec("morte")
	u = clampf(u, 0.0, 1.0)
	var trop := float(c.tropeco)
	var queda := float(c.queda)
	var r := 0.0  # 0 em pé .. 1 deitado
	var rot_extra := 0.0
	var sobe := 0.0
	if u < trop:
		var s := sin(PI * u / maxf(trop, 0.001))
		rot_extra = -sinal * 0.12 * s  # pra trás
		sobe = 2.0 * s
	elif u < trop + queda:
		var k := (u - trop) / queda
		r = k * k  # gravidade: acelera
	else:
		var b := clampf((u - trop - queda) / maxf(1.0 - trop - queda, 0.001), 0.0, 1.0)
		r = 1.0 - float(c.quica) * sin(PI * b) * (1.0 - b)
	var fin := Vector2(float(c.x) * sinal, float(c.y))
	return {"rot": sinal * (PI / 2.0) * r + rot_extra, "pos": fin * r + Vector2(0.0, -sobe), "mix": smoothstep(0.0, 0.6, u)}
