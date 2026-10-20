extends RefCounted
## As adagas do Lucas (v2): projétil em POOL, sem nó por adaga. `combate.golpear` chama `lancar` no quadro do arremesso (passo de tipo
## "adagas" do combo, dados/v2_herois.json); `atualizar` as move, acha quem elas acertam e as faz sumir. Os números vivem em vetores planos
## (posição, direção, velocidade, alcance que falta...), o desenho é um Node2D com texturas prontas (a lâmina) e uma linha de brilho aditivo,
## na mesma camada `glow` das armas automáticas (v2/armas.gd).
##
## Acerto: segmento do passo da adaga contra o corpo do monstro (centro no peito, raio do monstro + raio da adaga). Vale para o monstro
## da horda em lote, a elite e o chefe (todos estão em `mundo.monstros`). Cada adaga fura `perfura` monstros a mais e nunca acerta o mesmo
## duas vezes. O dano passa por `combate.ferir` (número, flash, empurrão, atordoamento, morte na fila). Crítico usa os números do combate.
## Modificadores das cartas do Lucas (armas.mods): `chuva` (% de chance de cada acerto soltar uma adaga extra para um lado qualquer) e `mira`
## (% de alcance e velocidade). O crítico explosivo (`explode`) também vale aqui.

const MAX := 96  # cabe a Tempestade de Adagas (Q do Lucas: ~42 em voo + rodada final de 18) junto com as adagas normais
const R_CAND := 560.0  # só monstros a até isto do herói entram na conta do quadro
const R_ADAGA := 4.0  # raio de acerto da adaga (cresce com a área do herói)
const COMPR := 16.0  # a lâmina desenhada: 16x5 px, apontando para a direita

var combate
var mundo
var tex_brilho: Texture2D
var no_corpo: Node2D
var no_brilho: Node2D
var lancadas := 0  # quantas adagas saíram (testes)
var acertos := 0  # quantos acertos (testes)
var sumiram := 0  # quantas adagas acabaram, por alcance, por furar tudo ou por sair do mapa (testes)
var a_pos := PackedVector2Array()
var a_dir := PackedVector2Array()
var a_vel := PackedFloat32Array()
var a_rest := PackedFloat32Array()  # alcance que falta (px); <= 0 = livre
var a_dano := PackedFloat32Array()
var a_emp := PackedFloat32Array()
var a_atord := PackedFloat32Array()
var a_raio := PackedFloat32Array()
var a_perf := PackedInt32Array()  # monstros que ainda pode furar (-1 = acabou)
var a_extra := PackedByteArray()  # 1 = veio do modificador "chuva" (não solta outra)
var a_cor := PackedColorArray()
var a_u0: Array = []  # os últimos monstros que cada adaga acertou (não repete)
var a_u1: Array = []
var a_u2: Array = []
var _cand: Array = []
var _tex: Texture2D
var _desenha := false


func montar(c, camada: Node, tex: Texture2D) -> void:
	combate = c
	mundo = c.mundo
	tex_brilho = tex
	_tex = _img_adaga()
	a_pos.resize(MAX)
	a_dir.resize(MAX)
	a_vel.resize(MAX)
	a_rest.resize(MAX)
	a_dano.resize(MAX)
	a_emp.resize(MAX)
	a_atord.resize(MAX)
	a_raio.resize(MAX)
	a_perf.resize(MAX)
	a_extra.resize(MAX)
	a_cor.resize(MAX)
	a_u0.resize(MAX)
	a_u1.resize(MAX)
	a_u2.resize(MAX)
	no_corpo = Node2D.new()
	no_corpo.draw.connect(_desenhar_corpo)
	camada.add_child(no_corpo)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no_brilho = Node2D.new()
	no_brilho.material = mat
	no_brilho.draw.connect(_desenhar_brilho)
	camada.add_child(no_brilho)


func limpar() -> void:
	a_rest.fill(0.0)
	for i in MAX:
		a_u0[i] = null
		a_u1[i] = null
		a_u2[i] = null
	lancadas = 0
	acertos = 0
	sumiram = 0
	_desenha = false
	no_corpo.queue_redraw()
	no_brilho.queue_redraw()


## Quantas adagas estão voando.
func ativas() -> int:
	var n := 0
	for i in MAX:
		if a_rest[i] > 0.0:
			n += 1
	return n


# ------------------------------------------------------------------ lançar


## O arremesso do passo `passo`: `n` adagas em leque de `leque` graus, centrado em `dir`. O dano de cada uma já leva o dano do herói.
## Com `anel` (a Tempestade do especial) o leque é fixo: a área do herói não abre o círculo além de 360 graus.
## Com `cresce_com_nivel` (só o golpe do herói, combate.golpear) o alcance ganha o crescimento por nível do golpe (combate.bonus_nivel_golpe).
func lancar(h, origem: Vector2, dir: Vector2, passo: Dictionary, cresce_com_nivel := false) -> void:
	var n := maxi(1, int(passo.get("n", 1)))
	var abre: float = 1.0 if passo.get("anel", false) else 1.0 + (h.m_area - 1.0) * 0.5
	var leque := deg_to_rad(float(passo.get("leque", 0.0)) * abre)
	var mira := 1.0 + float(combate.armas.mods.mira) / 100.0
	var alcance_k: float = mira * (1.0 + (combate.bonus_nivel_golpe(h) if cresce_com_nivel else 0.0))  # o golpe do Lucas cresce com o nível, o especial Q não
	var cor := Color(passo.cor[0], passo.cor[1], passo.cor[2])
	for k in n:
		var ang := 0.0 if n == 1 else leque * (float(k) / float(n - 1) - 0.5)
		ang += randf_range(-0.025, 0.025)
		_nova(
			origem + dir.rotated(ang) * 10.0,
			dir.rotated(ang),
			float(passo.vel) * mira,
			float(passo.alcance) * alcance_k,
			float(passo.dano) * h.m_dano,
			float(passo.empurrao),
			float(passo.atordoa),
			cor,
			int(passo.get("perfura", 0)),
			false,
			R_ADAGA * sqrt(h.m_area)
		)
	combate.fx.faiscas(origem + dir * 12.0, dir, 3, cor, 110.0)


func _livre() -> int:
	var pior := 0
	for i in MAX:
		if a_rest[i] <= 0.0:
			return i
		if a_rest[i] < a_rest[pior]:
			pior = i
	return pior  # pool cheio: reaproveita a que está mais perto de acabar


func _nova(
	p: Vector2, dir: Vector2, vel: float, alcance: float, dano: float, emp: float, atord: float, cor: Color, perfura: int, extra: bool, raio: float
) -> int:
	var i := _livre()
	a_pos[i] = p
	a_dir[i] = dir.normalized()
	a_vel[i] = vel
	a_rest[i] = alcance
	a_dano[i] = dano
	a_emp[i] = emp
	a_atord[i] = atord
	a_raio[i] = raio
	a_perf[i] = perfura
	a_extra[i] = 1 if extra else 0
	a_cor[i] = cor
	a_u0[i] = null
	a_u1[i] = null
	a_u2[i] = null
	lancadas += 1
	return i


# ------------------------------------------------------------------ o quadro


func atualizar(dt: float) -> void:
	var h = mundo.heroi
	var ativo := false
	for i in MAX:
		if a_rest[i] > 0.0:
			ativo = true
			break
	if not ativo:
		if _desenha:
			_desenha = false
			no_corpo.queue_redraw()
			no_brilho.queue_redraw()
		return
	_cand.clear()
	var c: Vector2 = h.pos
	var r2 := R_CAND * R_CAND
	for m in mundo.monstros:
		if m.vivo and not m.morrendo and (m.pos - c).length_squared() < r2:
			_cand.append(m)
	for i in MAX:
		if a_rest[i] <= 0.0:
			continue
		_mover(i, dt)
	_desenha = true
	no_corpo.queue_redraw()
	no_brilho.queue_redraw()


func _mover(i: int, dt: float) -> void:
	var dir: Vector2 = a_dir[i]
	var p0: Vector2 = a_pos[i]
	var passo := minf(a_vel[i] * dt, a_rest[i])
	var raio_a: float = a_raio[i]
	for m in _cand:
		if not m.vivo or m.morrendo or m == a_u0[i] or m == a_u1[i] or m == a_u2[i]:
			continue
		var alvo: Vector2 = m.pos + Vector2(0, -6)  # o peito do monstro
		var t := clampf((alvo - p0).dot(dir), 0.0, passo)
		var perto := p0 + dir * t
		var lim: float = float(m.raio) + raio_a
		if (alvo - perto).length_squared() > lim * lim:
			continue
		_acertar(i, m, perto)
		a_u2[i] = a_u1[i]
		a_u1[i] = a_u0[i]
		a_u0[i] = m
		a_perf[i] -= 1
		if a_perf[i] < 0:  # furou tudo o que podia: acabou aqui
			a_pos[i] = perto
			_acabar(i)
			return
	a_pos[i] = p0 + dir * passo
	a_rest[i] -= passo
	if a_rest[i] <= 0.0 or not mundo.mapa.has_point(a_pos[i]):
		_acabar(i)


func _acabar(i: int) -> void:
	a_rest[i] = 0.0
	sumiram += 1
	combate.fx.faiscas(a_pos[i], a_dir[i], 2, a_cor[i], 70.0)


func _acertar(i: int, m, p: Vector2) -> void:
	var h = mundo.heroi
	var cfg: Dictionary = combate.cfg.golpe
	acertos += 1
	var crit: bool = randf() < float(cfg.critico.chance) + h.m_critico
	var d: float = a_dano[i] * (1.0 + randf_range(-float(cfg.variacao), float(cfg.variacao)))
	if crit:
		d *= float(cfg.critico.mult)
		combate.criticos += 1
	var dir: Vector2 = a_dir[i]
	var cor: Color = a_cor[i]
	combate.ferir(m, d, dir, a_emp[i] * (1.25 if crit else 1.0), a_atord[i] * (1.3 if crit else 1.0), cor.lerp(Color.WHITE, 0.45), true, crit)
	combate.fx.faiscas(m.pos + Vector2(0, -8), dir, 6 if crit else 3, cor, 150.0 if crit else 110.0)
	combate.audio.tocar("critico" if crit else "impacto", randf_range(1.25, 1.5), -7.0, 0.05)
	if crit and float(combate.armas.mods.explode) > 0.0:
		var raio_e: float = float(combate.cartas.definicao("explode").raio) * (1.0 + (h.m_area - 1.0) * 0.6)
		combate.armas.explodir(m.pos, d * float(combate.armas.mods.explode) / 100.0, raio_e, Color(1.0, 0.74, 0.2), m)
	if not a_extra[i] and randf() * 100.0 < float(combate.armas.mods.chuva):  # "Chuva de adagas": uma extra para um lado qualquer
		var a := randf() * TAU
		var j := _nova(m.pos + Vector2(0, -8), Vector2.from_angle(a), a_vel[i], 120.0, a_dano[i] * 0.6, a_emp[i], a_atord[i], cor, 0, true, a_raio[i])
		a_u0[j] = m  # a extra não volta no monstro que a soltou


# ------------------------------------------------------------------ desenho


func _desenhar_corpo() -> void:
	for i in MAX:
		if a_rest[i] <= 0.0:
			continue
		var p: Vector2 = a_pos[i]
		var fade := clampf(a_rest[i] / 24.0, 0.0, 1.0)
		no_corpo.draw_texture_rect(tex_brilho, Rect2(p + Vector2(-4, 6), Vector2(8, 3)), false, Color(0, 0, 0, 0.35 * fade))
		no_corpo.draw_set_transform(p.round(), (a_dir[i] as Vector2).angle(), Vector2.ONE)
		no_corpo.draw_texture(_tex, Vector2(-COMPR * 0.5, -2.5), Color(1, 1, 1, fade))
	no_corpo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_brilho() -> void:
	for i in MAX:
		if a_rest[i] <= 0.0:
			continue
		var p: Vector2 = a_pos[i]
		var dir: Vector2 = a_dir[i]
		var cor: Color = a_cor[i]
		var fade := clampf(a_rest[i] / 24.0, 0.0, 1.0)
		no_brilho.draw_line((p - dir * 16.0).round(), p.round(), Color(cor.r, cor.g, cor.b, 0.4 * fade), 3.0)
		no_brilho.draw_line((p - dir * 9.0).round(), (p + dir * 4.0).round(), Color(1, 1, 1, 0.8 * fade), 1.0)
		no_brilho.draw_texture_rect(tex_brilho, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false, Color(cor.r, cor.g, cor.b, 0.3 * fade))


## A lâmina: 16x5 px apontando para a direita (cabo de couro, guarda de ouro, lâmina clara com fio mais escuro).
func _img_adaga() -> Texture2D:
	var im := Image.create(int(COMPR), 5, false, Image.FORMAT_RGBA8)
	var cabo := Color(0.3, 0.2, 0.14)
	var guarda := Color(0.77, 0.6, 0.27)
	var lamina := Color(0.86, 0.9, 0.98)
	var fio := Color(0.52, 0.58, 0.74)
	for x in 4:
		for y in range(1, 4):
			im.set_pixel(x, y, cabo)
	for y in 5:
		im.set_pixel(4, y, guarda)
	for x in range(5, 16):
		var meia := 2 if x < 11 else (1 if x < 14 else 0)
		for y in range(2 - meia, 3 + meia):
			im.set_pixel(x, y, lamina if y == 2 else fio)
	return ImageTexture.create_from_image(im)
