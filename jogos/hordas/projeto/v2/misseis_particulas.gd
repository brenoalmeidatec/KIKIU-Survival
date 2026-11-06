extends RefCounted
## As PARTÍCULAS dos micro-mísseis da E do LightWolf (pedido do Alisson de 05/11/2026, rodada 7: "Queria particulas nos misseis"): o rastro de puffs (v2/misseis_rastro.gd) lia como uma
## fileira de pontinhos; aqui entram as faíscas e brasas que dão "chiado" ao voo e o estouro do acerto. Só desenho: v2/adagas.gd decide ONDE e QUANDO (`_fumaca` no voo, `_explodir`
## no acerto) e este arquivo guarda tudo num pool fixo (MAX; sem nó por partícula) e desenha no corpo do adagas.
##
## Voo: a NUVEM DE LARGADA (o 1º puff de cada míssil: 3 puffs de 5 a 6 px cinza claro parados que esfarelam em 3 degraus + 3 faíscas âmbar caindo do pod) e as FAGULHAS (a cada
## FAGULHA_CADA puffs, 1 faísca âmbar de 1 px que cai uns 6 a 10 px e some em 2 degraus de cor).
## Impacto: 1 quadro BRANCO de 3 px no ponto de acerto, um ANEL de choque pequeno (elipse achatada de pontos, cresce até o raio da explosão em 3 degraus, 2 -> 1 px), FAÍSCAS radiais em
## direções quantizadas (8 direções, sem giro livre), DETRITOS de 2 px que caem e quicam uma vez no chão, e um PUFF de fumaça que sobe em 3 degraus. O chamusco no chão ficou de fora:
## o adagas desenha por cima dos monstros, e uma mancha ali taparia o pé deles.
##
## Grade de pixel: draw_rect em posição INTEIRA (a física anda em float, o desenho arredonda), lados inteiros de 1 a 6 px, alfa SEMPRE 1. Não há esmaecer: a partícula vive em DEGRAUS
## de cor (do claro para o escuro) e de tamanho e some inteira. Sem RNG da partida: a variação vem de um hash do contador de emissões (`_h`), então a sequência do jogo não muda.
## Limite: com 8 mísseis no ar o pool (MAX) dá conta; cada quadro aceita no máximo IMPACTOS_QUADRO estouros (os demais acertos do mesmo quadro ficam só com o misseis_visual)
## e, cheio, a próxima partícula toma o lugar da mais antiga (anel).
## Perfil Baixo (efe_particulas <= 0,3) e "Reduzir piscadas": nenhuma partícula nasce aqui (quem chama confere); fica o mínimo de hoje (a chama do bocal e os 8 quadros do impacto).

const MAX := 160
const IMPACTOS_QUADRO := 3  # estouros completos por quadro do mundo (8 mísseis podem acertar no mesmo quadro: o resto fica só com o misseis_visual)
const FAGULHA_CADA := 3  # uma fagulha a cada tantos puffs do rastro

enum { FAGULHA, LARGADA, FLASH, ANEL, FAISCA, DETRITO, FUMACA }

const AMBAR := [Color(1.0, 0.92, 0.55), Color(1.0, 0.78, 0.38), Color(1.0, 0.5, 0.1), Color(0.3, 0.28, 0.34)]  # claro, médio, laranja, cinza escuro (o mesmo âmbar do rastro)
const CINZA := [Color(0.9, 0.87, 0.84), Color(0.68, 0.65, 0.68), Color(0.46, 0.44, 0.5)]
const TERRA := [Color(0.42, 0.33, 0.26), Color(0.26, 0.2, 0.17)]
const BRANCO := Color(1.0, 1.0, 0.96)
const ACHATA := 0.5  # o anel é uma elipse no chão (a mesma leitura das outras ondas)
const ANEL_PONTOS := 16
const GRAV_FAGULHA := 260.0
const GRAV_FAISCA := 420.0
const GRAV_DETRITO := 620.0
const DUR := {FAGULHA: 0.2, LARGADA: 0.42, FLASH: 0.03, ANEL: 0.15, FAISCA: 0.3, DETRITO: 0.42, FUMACA: 0.45}  # segundos de MUNDO (tela = /1,25)
const DIRS8 := [
	Vector2(1, 0),
	Vector2(0.7071, -0.7071),
	Vector2(0, -1),
	Vector2(-0.7071, -0.7071),
	Vector2(-1, 0),
	Vector2(-0.7071, 0.7071),
	Vector2(0, 1),
	Vector2(0.7071, 0.7071)
]

var pos := PackedVector2Array()  # float: a física anda aqui; o desenho arredonda
var vel := PackedVector2Array()
var resta := PackedFloat32Array()  # <= 0 = livre
var vida := PackedFloat32Array()
var chao := PackedFloat32Array()  # o y do chão (detritos quicam aqui)
var tipo := PackedByteArray()
var vari := PackedByteArray()  # variação por hash (tamanho, máscara, quique)
var emitidas := 0  # partículas nascidas desde o último `limpar` (testes)
var impactos := 0  # estouros completos desde o último `limpar`
var _prox := 0
var _seq := 0  # contador das emissões: a "semente" do hash (não o RNG da partida)
var _neste_quadro := 0


func montar() -> void:
	pos.resize(MAX)
	vel.resize(MAX)
	resta.resize(MAX)
	vida.resize(MAX)
	chao.resize(MAX)
	tipo.resize(MAX)
	vari.resize(MAX)
	limpar()


func limpar() -> void:
	resta.fill(0.0)
	_prox = 0
	_seq = 0
	emitidas = 0
	impactos = 0
	_neste_quadro = 0


## Hash inteiro determinístico (0..1023) de dois números: o "sorteio" das partículas, sem tocar no RNG da partida.
static func _h(a: int, b: int) -> int:
	var x := (a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995
	x = (x ^ (x >> 13)) * 1274126177
	return (x ^ (x >> 16)) & 1023


func _f(b: int) -> float:  # 0..1 do hash da emissão atual
	return float(_h(_seq, b)) / 1023.0


func _nova(t: int, p: Vector2, v: Vector2, dur: float, var_: int, chao_y := 0.0) -> void:
	var i := _prox
	for k in MAX:
		var j := (_prox + k) % MAX
		if resta[j] <= 0.0:
			i = j
			break
	pos[i] = p
	vel[i] = v
	resta[i] = dur
	vida[i] = dur
	chao[i] = chao_y
	tipo[i] = t
	vari[i] = var_
	_prox = (i + 1) % MAX
	emitidas += 1


## O míssil deixou o puff número `n` (0 = o primeiro) em `p`, voando na direção `dir` (unitária, a do desenho). O 1º puff vira a nuvem de largada; a cada FAGULHA_CADA, uma fagulha.
func voo(p: Vector2, dir: Vector2, n: int) -> void:
	_seq += 1
	if n == 0:
		for k in 3:  # três puffs parados em volta do pod
			var off := Vector2(roundf((_f(k) - 0.5) * 8.0), roundf((_f(k + 7) - 0.5) * 6.0))
			_nova(LARGADA, p + off, Vector2.ZERO, DUR[LARGADA] * (0.85 + 0.3 * _f(k + 3)), _h(_seq, k) & 3)
		for k in 3:  # faíscas que caem do pod
			var v := Vector2((_f(k + 11) - 0.5) * 60.0, 10.0 + 30.0 * _f(k + 13)) - dir * 20.0
			_nova(FAGULHA, p, v, 0.15, 0)
		return
	if n % FAGULHA_CADA != 0:
		return
	var v2 := -dir * (25.0 + 20.0 * _f(1)) + Vector2((_f(2) - 0.5) * 30.0, 15.0)  # sai para trás e cai: 6 a 10 px em 0,2 s
	_nova(FAGULHA, p, v2, DUR[FAGULHA] * (0.8 + 0.4 * _f(3)), 0)


## O estouro do acerto em `p` (o pé do monstro: o chão), com o raio da explosão `raio`. Devolve false se o teto do quadro (IMPACTOS_QUADRO) já foi.
func impacto(p: Vector2, raio: float) -> bool:
	if _neste_quadro >= IMPACTOS_QUADRO:
		return false
	_neste_quadro += 1
	impactos += 1
	_seq += 1
	var o := p + Vector2(0, -6)  # o centro do estouro (o mesmo do misseis_visual)
	var chao_y := p.y + 2.0
	_nova(FLASH, o, Vector2.ZERO, DUR[FLASH], 0)
	_nova(ANEL, p, Vector2(raio, 0), DUR[ANEL], 0)
	var giro := _h(_seq, 0) & 7
	for k in 6:  # faíscas em leque por 8 direções quantizadas (sem ângulo livre): sobem mais do que descem
		var d: Vector2 = DIRS8[(giro + k * 3) & 7]
		if d.y > 0.5:
			d = DIRS8[(giro + k * 3 + 2) & 7]
		var v := d * (110.0 + 90.0 * _f(k + 20)) + Vector2(0, -40)
		_nova(FAISCA, o, v, DUR[FAISCA] * (0.5 + 0.5 * _f(k + 30)), _h(_seq, k + 40) & 1, chao_y)
	for k in 3:  # detritos do chão
		var lado := -1.0 if k == 0 else (1.0 if k == 1 else (_f(50) - 0.5) * 2.0)
		var v := Vector2(lado * (40.0 + 50.0 * _f(k + 51)), -(110.0 + 70.0 * _f(k + 54)))
		_nova(DETRITO, p + Vector2(0, -2), v, DUR[DETRITO] * (0.85 + 0.3 * _f(k + 57)), 0, chao_y)
	_nova(FUMACA, o, Vector2(0, -24.0 - 4.0 * _f(60)), DUR[FUMACA], _h(_seq, 61) & 3)
	return true


func atualizar(dt: float) -> void:
	_neste_quadro = 0
	if dt <= 0.0:
		return
	for i in MAX:
		if resta[i] <= 0.0:
			continue
		resta[i] = maxf(0.0, resta[i] - dt)
		var v := vel[i]
		var p := pos[i]
		match tipo[i]:
			FAGULHA:
				v.y += GRAV_FAGULHA * dt
				p += v * dt
			FAISCA:
				v.y += GRAV_FAISCA * dt
				p += v * dt
			DETRITO:
				v.y += GRAV_DETRITO * dt
				p += v * dt
				if p.y > chao[i] and v.y > 0.0:
					p.y = chao[i]
					if vari[i] == 0:  # um quique curto, depois fica no chão
						v = Vector2(v.x * 0.5, -v.y * 0.3)
						vari[i] = 1
					else:
						v = Vector2.ZERO
			FUMACA:
				p += v * dt
		vel[i] = v
		pos[i] = p


func vivos() -> int:
	var n := 0
	for t in resta:
		if t > 0.0:
			n += 1
	return n


## O degrau (0..n-1) da partícula `i` na vida: 0 = recém-nascida. Só avança (cor do claro para o escuro).
func degrau(i: int, n: int) -> int:
	return clampi(int((1.0 - resta[i] / maxf(vida[i], 0.0001)) * float(n)), 0, n - 1)


func desenhar(no) -> void:  # `no` é um Node2D (o corpo do adagas); sem tipo para o teste gravar os draw_rect
	for i in MAX:
		if resta[i] <= 0.0:
			continue
		var p := pos[i].round()
		match tipo[i]:
			FAGULHA:
				no.draw_rect(Rect2(p, Vector2.ONE), AMBAR[1 + degrau(i, 2)])  # médio -> laranja
			FAISCA:
				var d := degrau(i, 3)
				var c: Color = AMBAR[d + 1] if d > 0 else AMBAR[0]
				var t := 2.0 if vari[i] == 1 and d == 0 else 1.0
				if d == 0:  # rastro de 1 px na posição de um passo atrás (inteiro)
					no.draw_rect(Rect2((pos[i] - vel[i] * 0.02).round(), Vector2.ONE), AMBAR[1])
				no.draw_rect(Rect2(p, Vector2(t, t)), c)
			DETRITO:
				var d2 := degrau(i, 2)
				no.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), TERRA[d2])
			FLASH:
				no.draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), BRANCO)
				no.draw_rect(Rect2(p - Vector2(0, 1), Vector2(1, 3)), BRANCO)
			ANEL:
				_anel(no, i)
			LARGADA:
				_puff(no, p, [6, 5, 3][degrau(i, 3)], CINZA[degrau(i, 3)], degrau(i, 3), vari[i])
			FUMACA:
				var d3 := degrau(i, 3)
				_puff(no, p, [6, 5, 3][d3], CINZA[d3], d3, vari[i])


## O anel do acerto: ANEL_PONTOS pontos numa elipse achatada no chão, raio em 3 degraus (1/3, 2/3, 1 do raio da explosão), 2 px e depois 1 px. Pontos em 16 ângulos fixos.
func _anel(no, i: int) -> void:
	var d := degrau(i, 3)
	var r := vel[i].x * float(d + 1) / 3.0
	var t := 2.0 if d == 0 else 1.0
	var c: Color = AMBAR[0] if d < 2 else AMBAR[1]
	for k in ANEL_PONTOS:
		var a := float(k) * TAU / float(ANEL_PONTOS)
		var q := (pos[i] + Vector2(cos(a) * r, sin(a) * r * ACHATA)).round()
		no.draw_rect(Rect2(q, Vector2(t, t)), c)


## Um puff de fumaça de `lado` px (6, 5 ou 3): disco de pixels (linhas horizontais), que no degrau 1 ganha buracos fixos (máscara pela variação) antes de encolher. Sem alfa.
func _puff(no, p: Vector2, lado: int, c: Color, d: int, v: int) -> void:
	var meio := lado / 2
	for y in lado:
		var dy := float(y) - float(lado - 1) * 0.5
		var w := lado if absf(dy) < float(lado) * 0.3 else lado - 2
		if w <= 0:
			continue
		var x0 := -meio + (lado - w) / 2
		if d == 1 and y % 2 == (v & 1):  # esfarelando: a linha perde um pixel no meio (máscara fixa por puff)
			var furo := (v >> 1) % maxi(w - 1, 1) + 1
			no.draw_rect(Rect2(p + Vector2(x0, y - meio), Vector2(furo, 1)), c)
			if w - furo - 1 > 0:
				no.draw_rect(Rect2(p + Vector2(x0 + furo + 1, y - meio), Vector2(w - furo - 1, 1)), c)
			continue
		no.draw_rect(Rect2(p + Vector2(x0, y - meio), Vector2(w, 1)), c)
