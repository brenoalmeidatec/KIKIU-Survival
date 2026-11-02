extends RefCounted
## As adagas do Luke (v2): projétil em POOL, sem nó por adaga. `combate.golpear` chama `lancar` no quadro do arremesso (passo de tipo
## "adagas" do combo, dados/v2_herois.json); `atualizar` as move, acha quem elas acertam e as faz sumir. Os números vivem em vetores planos
## (posição, direção, velocidade, alcance que falta...), o desenho é um Node2D com texturas prontas (a lâmina) e uma linha de brilho aditivo,
## na mesma camada `glow` das armas automáticas (v2/armas.gd).
##
## Acerto: segmento do passo da adaga contra o corpo do monstro (centro no peito, raio do monstro + raio da adaga). Vale para o monstro
## da horda em lote, a elite e o chefe (todos estão em `mundo.monstros`). Cada adaga fura `perfura` monstros a mais e nunca acerta o mesmo
## duas vezes. O dano passa por `combate.ferir` (número, flash, empurrão, atordoamento, morte na fila). Crítico usa os números do combate.
## Modificadores das cartas do Luke (armas.mods): `chuva` (% de chance de cada acerto soltar uma adaga extra para um lado qualquer) e `mira`
## (% de alcance e velocidade). O crítico explosivo (`explode`) também vale aqui.
##
## Projétil genérico (#509, PER-2): o campo `proj` do passo escolhe a imagem no pool (`_proj_lista`; sem o campo, ou com nome que não existe,
## é a adaga). Entradas desenhadas em código: `adaga`, `bala` e `plasma` (a pistola e o canhão do LightWolf). Qualquer outro nome procura uma
## folha animada em `assets/v2/armas_anim/` (v2/anim_golpes.gd): a arma `<proj>_heroi`, animação `voo` (shuriken_heroi, kunai_heroi, flecha_heroi).
## Míssil (LW-4, a E do LightWolf; entrada `missil` da mesma tabela): o passo `giro` (rad/s) faz o projétil buscar UM alvo, escolhido ao sair: o monstro vivo mais perto dentro
## de um cone de `cone` graus em volta de `cone_dir` (a mira; senão a direção do tiro), até `alcance` px, com no máximo `por_alvo` mísseis no mesmo alvo enquanto houver outro no
## cone. Sem alvo, ou com o alvo morto no caminho, segue reto (a busca contínua fica para a v3). `expl_raio` > 0 faz o acerto explodir em área (`expl_dano`, pela conta de dano em área
## de v2/armas.gd, sem repetir o monstro acertado). Os campos só valem para quem os escreve no passo: adaga, bala e plasma seguem como antes.
## Ricochete: o campo `ricochete` do passo (n) vale só no golpe principal (`cresce_com_nivel`); o Q, a E e a chuva usam o projétil sem ricochetear.
## No acerto, uma varredura acha o monstro vivo mais perto (até RIC_ALCANCE px) que a lâmina ainda não acertou e a vira para ele; a direção nova
## vale no quadro seguinte, porque a lista de candidatos deste quadro foi montada com a direção antiga.

const AnimGolpes := preload("res://v2/anim_golpes.gd")
const MisseisVisual := preload("res://v2/misseis_visual.gd")

const MAX := 96  # cabe a Tempestade de Adagas (Q do Luke: ~42 em voo + rodada final de 18) junto com as adagas normais
const ALCANCE_EXTRA := 120.0  # a Chuva pode nascer e andar ainda neste quadro
const R_ADAGA := 4.0  # raio de acerto da adaga (cresce com a área do herói)
const COMPR := 16.0  # a lâmina desenhada: 16x5 px, apontando para a direita
const RIC_ALCANCE := 110.0  # até onde o ricochete procura o próximo alvo (px, do ponto do acerto ao peito do alvo)
const PROJ_PADRAO := "adaga"
const VISUAL_DIST := 60.0  # deslocamento da boca projetada converge para a trajetória lógica
const VISUAL_DUR := 0.2

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
var a_proj := PackedInt32Array()  # qual imagem (índice em _proj_lista)
var a_ric := PackedInt32Array()  # ricochetes que ainda faltam
var a_giro := PackedFloat32Array()  # rad/s com que busca o alvo (0 = reto)
var a_expl := PackedFloat32Array()  # raio da explosão no acerto (px; 0 = não explode)
var a_expl_d := PackedFloat32Array()  # dano da explosão em cada monstro dentro do raio
var a_alvo: Array = []  # o monstro que o míssil busca (null = reto)
var a_extra := PackedByteArray()  # 1 = veio do modificador "chuva" (não solta outra)
var a_grupo := PackedInt64Array()  # arremesso principal; tamanho fixo MAX, sem histórico crescente
var a_pausa := PackedByteArray()  # 1 até o primeiro acerto de qualquer lâmina desse grupo
var _grupo := 0
var _pausa_recarga := 0.0
var a_cor := PackedColorArray()
var a_visual_offset := PackedVector2Array()
var a_visual_dist := PackedFloat32Array()
var a_visual_t := PackedFloat32Array()
var a_visual_compr := PackedFloat32Array()  # janela de convergência: só encurta ao prever uma colisão próxima
var a_visual_ultima := PackedVector2Array()
var a_visual_oculto := PackedByteArray()
var a_visual_seguir := PackedByteArray()  # só a boca projetada arma a proteção contra voo visual reverso
var a_fonte: Array = []  # de onde a adaga veio (combate.fonte_dano no arremesso: principal, especial ou habilidade), para o dano por golpe da tela de fim
var a_u0: Array = []  # os últimos monstros que cada adaga acertou (não repete)
var a_u1: Array = []
var a_u2: Array = []
var _cand: Array = []
var _cand_visual: Array = []  # previsão visual separada: nunca acrescenta alvos ao narrowphase físico
var _proj_lista: Array = []  # [{nome, tex (código) ou anim (folha), compr, alt}], o índice 0 é sempre a adaga
var _proj_nomes := {}  # nome -> índice em _proj_lista
var _relogio := 0.0  # tempo para o quadro das folhas animadas (todas as lâminas na mesma fase)
var _desenha := false
var misseis_visual := MisseisVisual.new()


func montar(c, camada: Node, tex: Texture2D) -> void:
	combate = c
	mundo = c.mundo
	tex_brilho = tex
	_proj_lista.clear()
	_proj_nomes.clear()
	_registrar("adaga", _img_adaga(), COMPR, 5.0)
	_registrar("bala", _img_bala(), 7.0, 3.0)
	_registrar("plasma", _img_plasma(), 11.0, 7.0)
	_registrar("missil", _img_missil(), 24.0, 9.0)
	misseis_visual.montar()
	a_pos.resize(MAX)
	a_dir.resize(MAX)
	a_vel.resize(MAX)
	a_rest.resize(MAX)
	a_dano.resize(MAX)
	a_emp.resize(MAX)
	a_atord.resize(MAX)
	a_raio.resize(MAX)
	a_perf.resize(MAX)
	a_proj.resize(MAX)
	a_ric.resize(MAX)
	a_giro.resize(MAX)
	a_expl.resize(MAX)
	a_expl_d.resize(MAX)
	a_alvo.resize(MAX)
	a_extra.resize(MAX)
	a_grupo.resize(MAX)
	a_pausa.resize(MAX)
	a_cor.resize(MAX)
	a_visual_offset.resize(MAX)
	a_visual_dist.resize(MAX)
	a_visual_t.resize(MAX)
	a_visual_compr.resize(MAX)
	a_visual_compr.fill(VISUAL_DIST)
	a_visual_ultima.resize(MAX)
	a_visual_oculto.resize(MAX)
	a_visual_seguir.resize(MAX)
	a_fonte.resize(MAX)
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
	misseis_visual.limpar()
	a_rest.fill(0.0)
	a_grupo.fill(0)
	a_pausa.fill(0)
	a_ric.fill(0)
	a_proj.fill(0)
	a_giro.fill(0.0)
	a_expl.fill(0.0)
	a_visual_offset.fill(Vector2.ZERO)
	a_visual_dist.fill(0.0)
	a_visual_t.fill(0.0)
	a_visual_compr.fill(VISUAL_DIST)
	a_visual_ultima.fill(Vector2.ZERO)
	a_visual_oculto.fill(0)
	a_visual_seguir.fill(0)
	_grupo = 0
	_pausa_recarga = 0.0
	for i in MAX:
		a_u0[i] = null
		a_u1[i] = null
		a_u2[i] = null
		a_alvo[i] = null
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
## Com `cresce_com_nivel` (só o golpe do herói, combate.golpear) o alcance ganha o crescimento por nível do golpe (combate.bonus_nivel_golpe)
## e o passo pode ricochetear (`ricochete`).
func lancar(h, origem: Vector2, dir: Vector2, passo: Dictionary, cresce_com_nivel := false) -> void:
	var n := maxi(1, int(passo.get("n", 1)))
	var abre: float = 1.0 if passo.get("anel", false) else 1.0 + (h.m_area - 1.0) * 0.5
	var leque := deg_to_rad(float(passo.get("leque", 0.0)) * abre)
	var mira := 1.0 + float(combate.armas.mods.mira) / 100.0
	var alcance_k: float = mira * (1.0 + (combate.bonus_nivel_golpe(h) if cresce_com_nivel else 0.0))  # o golpe do Luke cresce com o nível, o especial Q não
	var cor := Color(passo.cor[0], passo.cor[1], passo.cor[2])
	var proj := _indice_proj(str(passo.get("proj", PROJ_PADRAO)))
	var ric := maxi(0, int(passo.get("ricochete", 0))) if cresce_com_nivel else 0
	_grupo += 1
	for k in n:
		var ang := 0.0 if n == 1 else leque * (float(k) / float(n - 1) - 0.5)
		ang += randf_range(-0.025, 0.025)
		var i := _nova(
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
		a_proj[i] = proj
		_boca_visual(i, h, origem, dir, passo)
		a_ric[i] = ric
		if float(passo.get("giro", 0.0)) > 0.0:
			_mirar(i, h, passo, dir)
		a_expl[i] = float(passo.get("expl_raio", 0.0))
		a_expl_d[i] = float(passo.get("expl_dano", 0.0)) * h.m_dano
		if cresce_com_nivel:  # só combate.golpear; Q e chuva nunca recebem grupo elegível
			a_grupo[i] = _grupo
			a_pausa[i] = 1
	combate.fx.faiscas(origem + dir * 12.0, dir, 3, cor, 110.0, not _visual_mecha(proj))


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
	a_proj[i] = 0
	a_ric[i] = 0
	a_giro[i] = 0.0
	a_expl[i] = 0.0
	a_expl_d[i] = 0.0
	a_alvo[i] = null
	a_grupo[i] = 0
	a_pausa[i] = 0
	a_cor[i] = cor
	a_visual_offset[i] = Vector2.ZERO
	a_visual_dist[i] = 0.0
	a_visual_t[i] = 0.0
	a_visual_compr[i] = VISUAL_DIST
	a_visual_ultima[i] = Vector2.ZERO
	a_visual_oculto[i] = 0
	a_visual_seguir[i] = 0
	a_fonte[i] = combate.fonte_dano
	a_u0[i] = null
	a_u1[i] = null
	a_u2[i] = null
	lancadas += 1
	return i


# ------------------------------------------------------------------ o quadro


func atualizar(dt: float) -> void:
	misseis_visual.atualizar(dt)
	_pausa_recarga = maxf(0.0, _pausa_recarga - dt)
	_relogio += dt
	var ativo := misseis_visual.ativas() > 0
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
	_guiar(dt)
	_selecionar_candidatos(dt)
	for i in MAX:
		if a_rest[i] <= 0.0:
			continue
		var antes: Vector2 = a_pos[i]
		_encurtar_visual(i)
		_mover(i, dt)
		a_visual_dist[i] += antes.distance_to(a_pos[i])
		a_visual_t[i] = maxf(0.0, a_visual_t[i] - dt)
		_atualizar_visual(i)
	_desenha = true
	no_corpo.queue_redraw()
	no_brilho.queue_redraw()


## Os mísseis giram até `a_giro` rad/s para o alvo, ANTES de a lista de candidatos do quadro ser montada (que usa a direção de agora). Alvo morto ou sumido: segue reto.
func _guiar(dt: float) -> void:
	for i in MAX:
		if a_rest[i] <= 0.0 or a_giro[i] <= 0.0:
			continue
		var alvo = a_alvo[i]
		if alvo == null:
			continue
		if not is_instance_valid(alvo) or not alvo.vivo or alvo.morrendo:
			a_alvo[i] = null
			continue
		var atual: float = (a_dir[i] as Vector2).angle()
		var quer: float = (alvo.pos + Vector2(0, -6) - (a_pos[i] as Vector2)).angle()
		var giro := clampf(angle_difference(atual, quer), -a_giro[i] * dt, a_giro[i] * dt)
		a_dir[i] = Vector2.from_angle(atual + giro)


## Escolhe o alvo do míssil `i` ao sair (veja o cabeçalho): o mais perto no cone, de preferência um que ainda não tem `por_alvo` mísseis atrás dele.
func _mirar(i: int, h, passo: Dictionary, dir: Vector2) -> void:
	a_giro[i] = float(passo.giro)
	var centro: Vector2 = passo.get("cone_dir", dir)
	var meio := deg_to_rad(float(passo.get("cone", 50.0))) * 0.5
	var alcance := float(passo.alcance)
	var teto := maxi(1, int(passo.get("por_alvo", 99)))
	var origem: Vector2 = a_pos[i]
	var melhor = null
	var melhor_d2 := INF
	var reserva = null
	var reserva_d2 := INF
	for m in mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var rel: Vector2 = m.pos + Vector2(0, -6) - origem
		var d2 := rel.length_squared()
		if d2 > alcance * alcance or d2 < 4.0 or absf(centro.angle_to(rel)) > meio:
			continue
		if d2 < reserva_d2:
			reserva = m
			reserva_d2 = d2
		if d2 < melhor_d2 and _mirando(m) < teto:
			melhor = m
			melhor_d2 = d2
	a_alvo[i] = melhor if melhor != null else reserva


## Quantos mísseis em voo buscam `m`.
func _mirando(m) -> int:
	var n := 0
	for j in MAX:
		if a_rest[j] > 0.0 and a_alvo[j] == m:
			n += 1
	return n


## Busca O(MAX + monstros), independente da distância atual do herói. A união cobre os
## segmentos deste quadro e o raio de cada lâmina; o corpo do monstro usa o mesmo peito do narrowphase.
func _selecionar_candidatos(dt: float) -> void:
	_cand.clear()
	_cand_visual.clear()
	var uniao := Rect2()
	var uniao_visual := Rect2()
	var primeiro := true
	var primeiro_visual := true
	var pode_extra := false
	var maior_raio_primario := 0.0
	for i in MAX:
		if a_rest[i] <= 0.0:
			continue
		var fim := a_pos[i] + a_dir[i] * minf(a_vel[i] * dt, a_rest[i])
		var segmento := Rect2(a_pos[i], Vector2.ZERO).expand(fim).grow(a_raio[i])
		uniao = segmento if primeiro else uniao.merge(segmento)
		primeiro = false
		if _visual_em_convergencia(i):
			var prever := minf(a_rest[i], maxf(a_visual_compr[i] - a_visual_dist[i], 0.0))
			var fim_visual := a_pos[i] + a_dir[i] * prever
			var segmento_visual := Rect2(a_pos[i], Vector2.ZERO).expand(fim_visual).grow(a_raio[i])
			uniao_visual = segmento_visual if primeiro_visual else uniao_visual.merge(segmento_visual)
			primeiro_visual = false
		if a_extra[i] == 0:
			pode_extra = true
			maior_raio_primario = maxf(maior_raio_primario, a_raio[i])
	if primeiro:
		return
	if pode_extra and float(combate.armas.mods.chuva) > 0.0:
		# Uma extra nasce no centro de quem sofreu o acerto, até um raio de corpo além
		# da união. Ela anda no máximo 120 px e nasce 2 px acima do peito; não gera outras.
		var maior_raio := 0.0
		for m in mundo.monstros:
			if m.vivo and not m.morrendo:
				maior_raio = maxf(maior_raio, float(m.raio))
		# O primeiro raio cobriu o contato primario; o corpo da extra precisa de outro raio.
		uniao = uniao.grow(maior_raio + 2.0 + ALCANCE_EXTRA + maior_raio_primario)
	for m in mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var peito: Vector2 = m.pos + Vector2(0, -6)
		var raio := Vector2.ONE * float(m.raio)
		if uniao.intersects(Rect2(peito - raio, raio * 2.0), true):
			_cand.append(m)
		if not primeiro_visual and uniao_visual.intersects(Rect2(peito - raio, raio * 2.0), true):
			_cand_visual.append(m)


func _visual_em_convergencia(i: int) -> bool:
	return a_visual_t[i] > 0.0 and a_visual_dist[i] < a_visual_compr[i] and a_visual_offset[i] != Vector2.ZERO and _visual_mecha(a_proj[i])


## Antecipação apenas visual: usa a lista ampla própria, na mesma ordem do mundo, sem tocar nos candidatos físicos.
## Entrada do raio no círculo do narrowphase, não no centro: a imagem já converge antes do primeiro contato.
func _encurtar_visual(i: int) -> void:
	if not _visual_em_convergencia(i):
		return
	var p: Vector2 = a_pos[i]
	var dir: Vector2 = a_dir[i]
	var prever := minf(a_rest[i], maxf(a_visual_compr[i] - a_visual_dist[i], 0.0))
	for m in _cand_visual:
		if not m.vivo or m.morrendo or m == a_u0[i] or m == a_u1[i] or m == a_u2[i]:
			continue
		var rel: Vector2 = m.pos + Vector2(0, -6) - p
		var frente := rel.dot(dir)
		var perpendicular2 := maxf(rel.length_squared() - frente * frente, 0.0)
		var raio: float = float(m.raio) + a_raio[i]
		if perpendicular2 > raio * raio:
			continue
		var meia := sqrt(maxf(raio * raio - perpendicular2, 0.0))
		if frente + meia < 0.0:
			continue  # círculo inteiramente atrás do projétil
		var entrada := maxf(frente - meia, 0.0)
		if entrada <= prever:
			a_visual_compr[i] = minf(a_visual_compr[i], a_visual_dist[i] + entrada)


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
		if a_ric[i] > 0 and _ricochetear(i, m, perto, t):
			return
		a_perf[i] -= 1
		if a_perf[i] < 0:  # furou tudo o que podia: acabou aqui
			a_pos[i] = perto
			_acabar(i)
			return
	a_pos[i] = p0 + dir * passo
	a_rest[i] -= passo
	if a_rest[i] <= 0.0 or not mundo.mapa.has_point(a_pos[i]):
		_acabar(i)


## Ricochete do acerto de `m` em `perto` (a lâmina andou `t` px neste quadro): vira a lâmina para o vivo mais perto que ela ainda não acertou.
## Devolve false (e a lâmina segue o caminho de sempre, furando ou acabando) quando não há ninguém a RIC_ALCANCE px. Uma varredura só, sem alocar.
func _ricochetear(i: int, m, perto: Vector2, t: float) -> bool:
	var melhor = null
	var melhor_d2 := RIC_ALCANCE * RIC_ALCANCE
	for o in mundo.monstros:
		if o == m or not o.vivo or o.morrendo or o == a_u1[i] or o == a_u2[i]:
			continue
		var d2: float = (o.pos + Vector2(0, -6) - perto).length_squared()
		if d2 < melhor_d2:
			melhor_d2 = d2
			melhor = o
	if melhor == null:
		return false
	var alvo: Vector2 = melhor.pos + Vector2(0, -6)
	a_ric[i] -= 1
	a_dir[i] = (alvo - perto).normalized()
	if a_visual_seguir[i] != 0:
		a_visual_ultima[i] = perto  # a nova direção efetiva permite uma trajetória visual nova
		a_visual_oculto[i] = 0
	a_pos[i] = perto
	a_rest[i] = maxf(a_rest[i] - t, sqrt(melhor_d2) + 8.0)  # o alcance que sobrou nunca deixa a lâmina curta para chegar ao novo alvo
	combate.fx.faiscas(perto, a_dir[i], 2, a_cor[i], 90.0)
	return true


func _acabar(i: int) -> void:
	a_rest[i] = 0.0
	sumiram += 1
	combate.fx.faiscas(a_pos[i], a_dir[i], 2, a_cor[i], 70.0, not _visual_mecha(a_proj[i]))


func _acertar(i: int, m, p: Vector2) -> void:
	# Salvaguarda para alvo que entra no segmento neste mesmo quadro; perfuração/ricochete não reabrem o offset.
	a_visual_offset[i] = Vector2.ZERO
	a_visual_t[i] = 0.0
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
	combate.fonte_dano = str(a_fonte[i])
	combate.ferir(m, d, dir, a_emp[i] * (1.25 if crit else 1.0), a_atord[i] * (1.3 if crit else 1.0), cor.lerp(Color.WHITE, 0.45), true, crit)
	_pausar_grupo(i)
	if a_expl[i] > 0.0:
		_explodir(i, m)
	combate.fx.faiscas(m.pos + Vector2(0, -8), dir, 6 if crit else 3, cor, 150.0 if crit else 110.0, not _visual_mecha(a_proj[i]))
	combate.audio.tocar("critico" if crit else "impacto", randf_range(1.25, 1.5), -7.0, 0.05)
	if crit and float(combate.armas.mods.explode) > 0.0:
		var raio_e: float = float(combate.cartas.definicao("explode").raio) * (1.0 + (h.m_area - 1.0) * 0.6)
		combate.armas.explodir(m.pos, d * float(combate.armas.mods.explode) / 100.0, raio_e, Color(1.0, 0.74, 0.2), m)
	if not a_extra[i] and randf() * 100.0 < float(combate.armas.mods.chuva):  # "Chuva de adagas": uma extra para um lado qualquer
		var a := randf() * TAU
		var j := _nova(m.pos + Vector2(0, -8), Vector2.from_angle(a), a_vel[i], ALCANCE_EXTRA, a_dano[i] * 0.6, a_emp[i], a_atord[i], cor, 0, true, a_raio[i])
		a_proj[j] = a_proj[i]
		a_u0[j] = m  # a extra não volta no monstro que a soltou


## A explosão pequena do míssil `i` em volta do monstro acertado: dano em área pelo mesmo caminho das armas (elipse do chão), sem repetir o monstro `m` que ele já feriu.
## A animação usa pool próprio sem novos nós/partículas por impacto; o dano mantém o mesmo caminho.
func _explodir(i: int, m) -> void:
	var cor: Color = a_cor[i]
	var raio := float(a_expl[i])
	combate.fonte_dano = str(a_fonte[i])
	combate.armas._dano_area(m.pos, raio, a_expl_d[i], a_emp[i], a_atord[i], cor, "missil", 0.0, m)
	misseis_visual.emitir(m.pos, raio)
	combate.fx.estouro(m.pos + Vector2(0, -6), Color(1.0, 0.85, 0.5), 3, false)  # preserva o consumo de RNG do visual anterior
	combate.audio.tocar("impacto", randf_range(1.5, 1.8), -8.0, 0.05)


## Um pedido por arremesso principal, não por lâmina/perfuração. Mesmo bloqueado pelo cooldown,
## o primeiro acerto consome o grupo: não pode pedir uma pausa atrasada ao atravessar a horda.
func _pausar_grupo(i: int) -> void:
	if a_pausa[i] == 0:
		return
	var grupo := a_grupo[i]
	for j in MAX:
		if a_grupo[j] == grupo:
			a_pausa[j] = 0
	if _pausa_recarga > 0.0:
		return
	var cfg: Dictionary = combate.cfg.golpe.get("impacto_adagas", {})
	var dur := float(cfg.get("hit_stop", 0.0))
	if dur <= 0.0:
		return
	_pausa_recarga = float(cfg.get("recarga", 0.0))
	combate.hit_stop(dur)


# ------------------------------------------------------------------ desenho


func _desenhar_corpo() -> void:
	if misseis_visual.ativas() > 0:
		misseis_visual.desenhar(no_corpo, float(mundo._nivel_particulas().get("efe_particulas", 1.0)) <= 0.3)
	for i in MAX:
		if a_rest[i] <= 0.0 or a_visual_oculto[i] != 0:
			continue
		var p: Vector2 = a_pos[i]
		var fade := clampf(a_rest[i] / 24.0, 0.0, 1.0)
		no_corpo.draw_texture_rect(tex_brilho, Rect2(p + Vector2(-4, 6), Vector2(8, 3)), false, Color(0, 0, 0, 0.35 * fade))
		var e: Dictionary = _proj_lista[a_proj[i]]
		p = _pos_visual(i)  # a sombra acima permanece na trajetória lógica do chão
		if e.has("anim"):
			var f: Dictionary = e.anim
			AnimGolpes.desenhar(no_corpo, f, AnimGolpes.quadro_em(f, _relogio), p, (a_dir[i] as Vector2).angle(), Vector2.ONE, Color(1, 1, 1, fade))
			continue
		no_corpo.draw_set_transform(p.round(), (a_dir[i] as Vector2).angle(), Vector2.ONE)
		no_corpo.draw_texture(e.tex, Vector2(-float(e.compr) * 0.5, -float(e.alt) * 0.5), Color(1, 1, 1, fade))
	no_corpo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_brilho() -> void:
	for i in MAX:
		if a_rest[i] <= 0.0 or a_visual_oculto[i] != 0:
			continue
		var p: Vector2 = _pos_visual(i)
		var dir: Vector2 = a_dir[i]
		var cor: Color = a_cor[i]
		var fade := clampf(a_rest[i] / 24.0, 0.0, 1.0)
		if _visual_mecha(a_proj[i]):
			if str(_proj_lista[a_proj[i]].nome) == "missil":
				no_brilho.draw_line((p - dir * 19.0).round(), (p - dir * 10.0).round(), Color(1.0, 0.55, 0.14, 0.65 * fade), 2.0)
			else:
				no_brilho.draw_line((p - dir * 7.0).round(), p.round(), Color(cor.r, cor.g, cor.b, 0.65 * fade), 1.0)
			continue
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


## A bala do canhão do LightWolf: 7x3 px, ponta clara e corpo âmbar.
func _img_bala() -> Texture2D:
	var im := Image.create(7, 3, false, Image.FORMAT_RGBA8)
	var corpo := Color(1.0, 0.72, 0.25)
	var ponta := Color(1.0, 0.96, 0.8)
	var cauda := Color(0.8, 0.4, 0.15)
	for x in 7:
		for y in 3:
			im.set_pixel(x, y, corpo)
	for y in 3:
		im.set_pixel(0, y, cauda)
		im.set_pixel(6, y, ponta if y == 1 else corpo)
	im.set_pixel(0, 0, Color(0, 0, 0, 0))
	im.set_pixel(0, 2, Color(0, 0, 0, 0))
	im.set_pixel(5, 1, ponta)
	return ImageTexture.create_from_image(im)


## Micro-míssil 24x9: ogiva, corpo claro contornado, faixa ciano, aletas e motor quente separados.
func _img_missil() -> Texture2D:
	var im := Image.create(24, 9, false, Image.FORMAT_RGBA8)
	for x in range(5, 24):
		var meia := 2 if x < 19 else (1 if x < 22 else 0)
		for y in range(4 - meia, 5 + meia):
			var cor := Color(0.18, 0.28, 0.38)
			if abs(y - 4) < meia or meia == 0:
				cor = Color(0.92, 0.96, 1.0) if y <= 4 else Color(0.5, 0.67, 0.79)
			if x >= 17:
				cor = Color(0.3, 0.75, 0.9) if y == 4 else Color(0.15, 0.4, 0.58)
			im.set_pixel(x, y, cor)
	for x in range(6, 11):
		var fora := 3 if x < 9 else 2
		im.set_pixel(x, 4 - fora, Color(0.23, 0.4, 0.56))
		im.set_pixel(x, 4 + fora, Color(0.23, 0.4, 0.56))
	for x in range(0, 5):
		for y in range(3 if x < 2 else 2, 6 if x < 2 else 7):
			im.set_pixel(x, y, Color(1.0, 0.85, 0.4) if y == 4 else Color(0.95, 0.35, 0.08))
	return ImageTexture.create_from_image(im)


func _visual_mecha(proj: int) -> bool:
	var nome := str(_proj_lista[proj].nome)
	return nome == "missil" or (nome == "bala" and combate.heroi_id == "lightwolf")


## Coordenadas projetadas na folha, relativas aos pés do herói. Só desenho: nada altera a_pos/a_dir/alcance/colisão.
func _boca_visual(i: int, h, origem: Vector2, dir: Vector2, passo: Dictionary) -> void:
	if not _visual_mecha(a_proj[i]):
		return
	var nome := str(_proj_lista[a_proj[i]].nome)
	var chave := "pods" if nome == "missil" else "canhoes"
	var tabela: Array = h.tipo.info.get("bocas_projeteis", {}).get(chave, [])
	var mira: Vector2 = passo.get("cone_dir", dir)
	var linha: int = h.linha_de(mira)
	if tabela.size() != 8 or (tabela[linha] as Array).size() != 2:
		return
	var lado := 0 if float(passo.get("lateral", -1.0)) < 0.0 else 1
	if nome == "missil":
		var perp := Vector2(-mira.y, mira.x)
		lado = 0 if (origem - (h.pos + h.ORIGEM_GOLPE)).dot(perp) < 0.0 else 1
	var xy: Array = tabela[linha][lado]
	if xy.size() != 2:
		return
	a_visual_offset[i] = h.pos + Vector2(float(xy[0]), float(xy[1])) - a_pos[i]
	a_visual_t[i] = VISUAL_DUR
	a_visual_ultima[i] = h.pos + Vector2(float(xy[0]), float(xy[1]))
	a_visual_seguir[i] = 1


func _pos_visual(i: int) -> Vector2:
	if a_visual_compr[i] <= 0.0:
		return a_pos[i]
	var k := clampf(minf(1.0 - a_visual_dist[i] / a_visual_compr[i], a_visual_t[i] / VISUAL_DUR), 0.0, 1.0)
	if a_visual_compr[i] >= VISUAL_DIST:
		k = k * k * (3.0 - 2.0 * k)
	return a_pos[i] + a_visual_offset[i] * k


## Boca já além do contato ou alvo tardio: não desenha uma volta para trás. A física segue e o desenho volta ao alcançar a última posição.
func _atualizar_visual(i: int) -> void:
	if a_visual_seguir[i] == 0 or a_rest[i] <= 0.0:
		return
	var p := _pos_visual(i)
	if (p - a_visual_ultima[i]).dot(a_dir[i]) < -0.01:
		a_visual_oculto[i] = 1
	else:
		a_visual_oculto[i] = 0
		a_visual_ultima[i] = p


## O tiro de plasma da pistola do LightWolf: bola de 11x7 px, núcleo branco, anel ciano e uma cauda mais fraca para trás (esquerda).
func _img_plasma() -> Texture2D:
	var im := Image.create(11, 7, false, Image.FORMAT_RGBA8)
	var anel := Color(0.25, 0.8, 1.0)
	var miolo := Color(0.7, 0.95, 1.0)
	var nucleo := Color(1.0, 1.0, 1.0)
	var cauda := Color(0.15, 0.5, 0.85, 0.7)
	for x in 11:
		for y in 7:
			var dx := (float(x) - 6.5) / 4.5
			var dy := (float(y) - 3.0) / 3.0
			var r := dx * dx + dy * dy
			if r <= 0.12:
				im.set_pixel(x, y, nucleo)
			elif r <= 0.5:
				im.set_pixel(x, y, miolo)
			elif r <= 1.0:
				im.set_pixel(x, y, anel)
	for x in range(0, 3):
		im.set_pixel(x, 3, cauda)
	return ImageTexture.create_from_image(im)


# ------------------------------------------------------------------ a tabela de projéteis


func _registrar(nome: String, tex: Texture2D, compr: float, alt: float) -> int:
	_proj_lista.append({"nome": nome, "tex": tex, "compr": compr, "alt": alt})
	_proj_nomes[nome] = _proj_lista.size() - 1
	return _proj_lista.size() - 1


## O índice da imagem `nome`: as desenhadas em código, ou (na primeira vez) a folha animada `<nome>_heroi`/`voo`. Sem nenhuma das duas é a adaga.
func _indice_proj(nome: String) -> int:
	if _proj_nomes.has(nome):
		return _proj_nomes[nome]
	var folhas := AnimGolpes.de(nome + "_heroi")
	if folhas.has("voo"):
		_proj_lista.append({"nome": nome, "anim": folhas.voo})
		_proj_nomes[nome] = _proj_lista.size() - 1
	else:
		_proj_nomes[nome] = 0  # lembra que não existe, para não procurar a folha de novo a cada arremesso
	return _proj_nomes[nome]
