extends RefCounted
## Golpes secundários novos da v2 (leva 5): cinco tipos que `v2/armas.gd` chama pelo nome do golpe (dados/v2_cartas.json > "golpes").
##   projetil: a cada recarga, tiros no inimigo mais perto (perfura N inimigos; explosao = área no impacto).
##   nuvem:    a cada recarga, uma nuvem cai perto de um inimigo, fica `duracao` s e dá dano em tiques (lentidao opcional).
##   anel:     a cada recarga, um anel de choque sai do herói e cresce até `raio`; cada inimigo é atingido uma vez (`lento_s`, opcional: segundos de lentidão).
##   meteoro:  a cada recarga, meteoros marcam o chão (aviso) e caem em área perto de inimigos.
##   aliado:   a cada recarga, espíritos perseguem o inimigo mais perto e dão dano em tiques ao tocar.
##   torre:    (leva 6) a cada recarga, `quantidade` torretas de bambu caem atrás do herói e ficam `duracao` s no lugar, atirando virotes
##             (itens "projetil") no inimigo mais perto DELAS; com `cadeia` (Pagode do Trovão) cada virote salta em arco elétrico.
##   granada:  (leva 6) a cada recarga, cabaças de pólvora voam em arco até o maior grupo, quicam uma vez, queimam o pavio e explodem em
##             área soltando estilhaços (itens "projetil"); com `fogos` (Fogos de Festival) cada estilhaço estoura de novo.
## Tudo em um pool fixo (MAX slots, dicionários reaproveitados): nenhum nó, nenhuma alocação por quadro. O desenho usa a textura
## de brilho que o `armas.gd` já tem, em modo aditivo (camada no_brilho). O `armas.gd` guarda o pai (`pai`) para usar o dano em área
## (`_dano_area`) e a explosão (`explodir`), e o combate (`ferir`) para o dano direto.

const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (igual ao armas.gd)
const MAX := 64
const RAIO_PROJ := 10.0
const RAIO_ALIADO := 7.0  # corpo do aliado no chão (colisão: v2/colisao.gd, igual ao do Ator)
## Tempos da torre (s): queda, armar (pernas se abrem e a balestra sobe) e desmontar (some em lascas depois da `duracao`).
const POUSO_T := 0.25
const ARMA_T := 0.4
const DESMONTA := 0.35
## Tempos da granada (s): o quique depois do voo, o clarão da explosão e a altura do arremesso.
const QUIQUE_T := 0.18
const EXPLOSAO_T := 0.45
const FOGOS_CORES := [Color(0.5, 0.95, 1.0), Color(1.0, 0.82, 0.3), Color(0.4, 1.0, 0.5)]  # ciano, dourado e verde dos Fogos de Festival (vermelho fica so para perigo)
const COR_BAMBU := Color(0.86, 0.76, 0.36)
const COR_BAMBU_ESCURO := Color(0.5, 0.36, 0.15)
const COR_CONTORNO := Color(0.1, 0.06, 0.03)
const COR_CABACA := Color(0.95, 0.6, 0.18)
## A geometria da torre (px acima dos pés): a plataforma, o eixo da balestra e a boca de onde sai o virote. Desenho, brilho e tiro usam estas.
const TORRE_TOPO := -30.0
const TORRE_PIVO := -38.0
const TORRE_BOCA := 15.0
## O pool de partículas deste arquivo (a camada normal, que recebe a luz): fumaça, lascas e brasas. `fx` só desenha em modo aditivo, que não
## serve para fumaça escura nem para casca de cabaça.
const MAX_PARTS := 96
const SLOTS_NUM := [
	Vector2(0, -8), Vector2(-26, -4), Vector2(26, -4), Vector2(-22, -20), Vector2(22, -20), Vector2(-30, -34), Vector2(30, -34), Vector2(0, -42)
]
const PT_FUMACA := 0
const PT_LASCA := 1
const PT_BRASA := 2
const PT_FUMACA_QUENTE := 3  # a fumaça da explosão: nasce alaranjada e esfria até o cinza
const GRAVIDADE_LASCA := 520.0
const PASTA_SPRITES := "res://assets/v2/armas/"
const PASTA_FUSOES := "res://assets/v2/fusoes/"
const Golem := preload("res://v2/golem.gd")  # o Golem de Barro e o Colosso: andar, ataque e as 8 direções
const Andante := preload("res://v2/andante.gd")  # as outras invocações que andam de verdade (Espírito do Urso...): folha de 8 direções, andar e ataque
const Anim := preload("res://v2/anim_golpes.gd")  # as folhas animadas de projétil, meteoro, anel e nuvem (docs/combate_v2/SPEC_ARTE.md)
## Fases dos golpes com folha (docs/combate_v2/ENTREGA.md): no PREPARO não há hitbox (o tiro carrega na boca, o anel junta força, a nuvem se
## forma); no ATIVO a colisão vale e cada monstro é atingido uma vez por item; o IMPACTO e a marca no chão são só efeito (pool `x_*`), tocados no
## evento real do acerto ou da queda. Os tempos encolhem com a velocidade de ataque, dentro de VEL_ANIM_MIN..VEL_ANIM_MAX; a arma pode
## trocar o preparo com o número `preparo` dos dados.
const F_PREPARO := 0
const F_ATIVO := 1
const PREPARO_PROJ := 0.1
const PREPARO_ANEL := 0.12
const QUEDA_ANEL := 0.35  # s da peça que cai antes do anel (Martelo do Trovão: a folha "<id>_queda")
const ENTRADA_NUVEM := 0.3
const VEL_ANIM_MIN := 0.5
const VEL_ANIM_MAX := 2.5
const MAX_FX := 48  # impactos e marcas tocando ao mesmo tempo; cheio, o mais velho dá lugar
const COR_CRIT := Color(1.0, 0.74, 0.2)  # o número do crítico (o mesmo de combate.gd)
const RICOCHETE_ALC := 110.0  # px: até onde o tiro com `ricochete` procura o próximo alvo
static var _tex_fumaca: Texture2D
static var _sprites: Dictionary = {}
static var _lidos := false

var pai  # v2/armas.gd
var itens: Array = []  # o pool: cada slot é um dicionário fixo; vida <= 0 é livre
var fila_aquecer: Array = []  # folhas de invocação a carregar antes de nascerem (pedir_aquecer), uma por quadro com a tela de cartas aberta
var q_pos := PackedVector2Array()  # as partículas: posição no chão, altura (z), velocidades, vida, tamanho, tipo e cor
var q_z := PackedFloat32Array()
var q_vel := PackedVector2Array()
var q_vz := PackedFloat32Array()
var q_vida := PackedFloat32Array()
var q_max := PackedFloat32Array()
var q_tam := PackedFloat32Array()
var q_tipo := PackedByteArray()
var q_cor := PackedColorArray()
var q_ativas := 0
var _qi := 0
var _rng_fumaca := RandomNumberGenerator.new()  # o sorteio só do enfeite (fumaca_impacto), fora do randf() global
var _relogio := 0.0
var _num_acum := {}  # id do monstro -> [quando abriu a janela da soma (s do relógio daqui, -1 = fechada), dano somado, monstro, direção, cor, quando mostrou o último]
var _slot_num := {}  # id do monstro -> Vector2(quando saiu o último número em leque, quantos saíram nessa rajada)
var ultimo_anel := 0  # quantos estilhaços a última explosão de cabaça criou (o teste confere)
var x_pos := PackedVector2Array()  # o pool de impactos e marcas: ponto, idade, duração (<= idade: livre), escala, folha e camada (0 = chão)
var x_t := PackedFloat32Array()
var x_dur := PackedFloat32Array()
var x_esc := PackedFloat32Array()
var x_folha: Array = []
var x_chao := PackedByteArray()
var x_ativos := 0
var _xi := 0
var impactos := 0  # quantos impactos tocaram (testes)


func montar(p) -> void:
	pai = p
	carregar_sprites()
	itens.clear()
	for i in MAX:
		itens.append(_item_vazio())
		Golem.zerar(itens[itens.size() - 1])
		Andante.zerar(itens[itens.size() - 1])
	q_pos.resize(MAX_PARTS)
	q_z.resize(MAX_PARTS)
	q_vel.resize(MAX_PARTS)
	q_vz.resize(MAX_PARTS)
	q_vida.resize(MAX_PARTS)
	q_max.resize(MAX_PARTS)
	q_tam.resize(MAX_PARTS)
	q_tipo.resize(MAX_PARTS)
	q_cor.resize(MAX_PARTS)
	Anim.carregar()
	x_pos.resize(MAX_FX)
	x_t.resize(MAX_FX)
	x_dur.resize(MAX_FX)
	x_esc.resize(MAX_FX)
	x_chao.resize(MAX_FX)
	x_folha.resize(MAX_FX)
	x_dur.fill(0.0)


## Um slot do pool. Campos da leva 6 (torre e granada): `orig`/`dest` (origem e destino do arremesso), `age` (relógio da fase), `est` (a fase:
## torre 0 cai, 1 de pé, 2 desmonta; granada 0 voa, 1 quica, 2 pavio, 3 explodiu; projétil 1 = estoura de novo), `mult` (multiplicador de dano),
## `mira`/`aux` (mira e recuo da torre, queda do quique da granada), `cand` (os alvos perto DA TORRE ou da explosão) e `lista`, a que o
## projétil usa para colidir (null = os monstros perto do herói).
func _item_vazio() -> Dictionary:
	return {
		"k": "",
		"a": null,
		"sp": {},
		"vida": 0.0,
		"p": Vector2.ZERO,
		"v": Vector2.ZERO,
		"t": 0.0,
		"r": 0.0,
		"fase": 0.0,
		"pen": 0,
		"hit": [],
		"pulso": 0.0,
		"orig": Vector2.ZERO,
		"dest": Vector2.ZERO,
		"age": 0.0,
		"est": 0,
		"mult": 1.0,
		"mira": 0.0,
		"aux": 0.0,
		"cand": [],
		"lista": null,
		"fa": {},  # as folhas animadas da arma (Anim.de), {} = desenho antigo
		"fk": F_ATIVO,  # a fase (F_PREPARO, F_ATIVO)
		"ft": 0.0  # s que faltam do preparo
	}


func limpar() -> void:
	for it in itens:
		it.vida = 0.0
		Golem.limpar_restos(it)
	q_vida.fill(0.0)
	q_ativas = 0
	x_dur.fill(0.0)
	x_ativos = 0
	_num_acum.clear()
	_slot_num.clear()


func remover(a: Dictionary) -> void:
	for it in itens:
		if is_same(it.a, a):
			it.vida = 0.0


func tem_ativos() -> bool:
	if q_ativas > 0 or x_ativos > 0:
		return true
	for it in itens:
		if float(it.vida) > 0.0 or Golem.tem_restos(it):  # o entulho do golem que acabou ainda está no chão
			return true
	return false


# ------------------------------------------------------------------ sprites (assets/v2/armas/indice.json)


## Lê o índice uma vez por processo: cada arma aponta para o seu {tex, tam, tipo} (sugeridas e aproximadas). Sprite que não carrega
## fica de fora (o golpe segue com a forma antiga). Com normal map, a textura é um CanvasTexture: a luz 2D age nela.
## A arte das fusões (assets/v2/fusoes/) lê por último: a Ventania Cortante troca a onda da arma base pela sua.
static func carregar_sprites() -> void:
	if _lidos:
		return
	_lidos = true
	for pasta in [PASTA_SPRITES, PASTA_FUSOES]:
		_ler_indice(pasta)


static func _ler_indice(pasta: String) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(pasta.path_join("indice.json")))
	if not (d is Dictionary):
		return
	for nome in d.get("sprites", {}):
		var s: Dictionary = d.sprites[nome]
		var tex := load(pasta.path_join(str(s.arquivo))) as Texture2D
		if tex == null:
			continue
		if s.get("normal") != null:
			var ct := CanvasTexture.new()
			ct.diffuse_texture = tex
			ct.normal_texture = load(pasta.path_join(str(s.normal))) as Texture2D
			tex = ct
		var entrada := {"tex": tex, "tam": Vector2(float(s.tamanho[0]), float(s.tamanho[1])), "tipo": str(s.tipo)}
		for arma in s.armas_sugeridas + s.armas_aproximadas:
			_sprites[str(arma)] = entrada


## Sprite do golpe `id` ({tex, tam, tipo}), ou {} quando a arma não tem sprite.
static func sprite_de(id: String) -> Dictionary:
	carregar_sprites()
	return _sprites.get(id, {})


# ------------------------------------------------------------------ o timer de recarga (chamado por golpe, como as outras famílias)


## Conta a recarga do golpe `a` e, quando ela zera, dispara. Sem inimigo por perto, espera um pouco e não gasta a recarga.
func golpe(a: Dictionary, h, dt: float, vel_a: float, perto: Array) -> void:
	# Brinde temporário (aliado e torre): a recarga só começa a contar quando o último da leva já sumiu; sem isso a leva nova nasceria antes
	# da velha acabar e o aliado pareceria permanente.
	if _relogio < float(a.get("ate", 0.0)):
		return
	a.t = float(a.t) - dt
	if float(a.t) > 0.0:
		return
	if perto.is_empty():
		a.t = 0.3
		return
	var st: Dictionary = a.st
	a.t = float(st.recarga) / vel_a
	match str(a.tipo):
		"projetil":
			_disparar(a, h, perto)
		"nuvem":
			_nuvem(a, h, perto)
		"anel":
			_anel(a, h)
		"meteoro":
			_meteoros(a, h, perto)
		"aliado":
			_aliados(a, h)
		"torre":
			_torres(a, h, perto)
		"granada":
			_granadas(a, h, perto)


# ------------------------------------------------------------------ o quadro (movimento e dano)


## Um passo de todos os itens do pool. `h` é o herói; `perto` são os monstros dentro de 340 px (lista que o armas.gd monta).
func quadro(h, dt: float, perto: Array) -> void:
	_relogio += dt
	for it in itens:
		if float(it.vida) <= 0.0:
			if Golem.tem_restos(it):
				Golem.restos(it, dt)
			continue
		it.vida = float(it.vida) - dt
		it.fase = float(it.fase) + dt * 6.0
		it.pulso = maxf(0.0, float(it.pulso) - dt * 4.0)
		match str(it.k):
			"projetil":
				if int(it.fk) == F_PREPARO:
					_preparar_projetil(it, h, dt)
				else:
					_mover_projetil(it, dt, perto)
			"nuvem":
				_tique_nuvem(it, dt)
			"anel":
				_mover_anel(it, h, dt, perto)
			"meteoro":
				_cair_meteoro(it, dt)
			"aliado":
				_mover_aliado(it, h, dt, perto)
			"torre":
				_mover_torre(it, h, dt)
			"granada":
				_mover_granada(it, dt)
		# O estilhaço dos Fogos de Festival estoura de novo onde acaba (no fim da vida ou ao acertar): `est` 1 marca quem ainda vai estourar.
		if str(it.k) == "projetil" and int(it.est) == 1 and float(it.vida) <= 0.0:
			_estourar_fogo(it)
	if q_ativas > 0:
		_quadro_partes(dt)
	if x_ativos > 0:
		_quadro_fx(dt)
	if not _num_acum.is_empty():
		_num_soltar()


# ------------------------------------------------------------------ partículas próprias (fumaça, lascas e brasas)


## Solta uma partícula no pool (`pos` é o ponto no chão e `z` a altura). Se estiver cheio, sobrescreve a mais velha da fila. Não cria nó.
func _parte(tipo: int, pos: Vector2, z: float, vel: Vector2, vz: float, vida: float, tam: float, cor: Color) -> void:
	var i := _qi
	_qi = (_qi + 1) % MAX_PARTS
	if q_vida[i] <= 0.0:
		q_ativas += 1
	q_tipo[i] = tipo
	q_pos[i] = pos
	q_z[i] = z
	q_vel[i] = vel
	q_vz[i] = vz
	q_vida[i] = vida
	q_max[i] = vida
	q_tam[i] = tam
	q_cor[i] = cor


func _quadro_partes(dt: float) -> void:
	var amorte := exp(-2.5 * dt)
	for i in MAX_PARTS:
		var v := q_vida[i]
		if v <= 0.0:
			continue
		v -= dt
		if v <= 0.0:
			q_vida[i] = 0.0
			q_ativas -= 1
			continue
		q_vida[i] = v
		var vel := q_vel[i]
		var z := q_z[i]
		var vz := q_vz[i]
		match int(q_tipo[i]):
			PT_LASCA:
				vz -= GRAVIDADE_LASCA * dt
				z += vz * dt
				if z <= 0.0:
					z = 0.0
					if vz < -70.0:  # um quique curto e ela assenta
						vz = -vz * 0.35
						vel *= 0.5
					else:
						vz = 0.0
						vel *= 0.15
			PT_FUMACA, PT_FUMACA_QUENTE:  # a fumaça sobe quase sem freio (só o lado para): sobe de 40 a 60 px na vida dela
				z += vz * dt
				vel *= amorte
				vz *= exp(-0.5 * dt)
			_:  # a brasa sobe devagar e vai parando
				z += vz * dt
				vel *= amorte
				vz *= amorte
		q_vel[i] = vel
		q_vz[i] = vz
		q_z[i] = z
		q_pos[i] += vel * dt


## A camada normal (recebe a luz): a fumaça que incha e some, e as lascas com a sombrinha no chão.
func _desenhar_partes(ci: CanvasItem) -> void:
	for i in MAX_PARTS:
		var v := q_vida[i]
		if v <= 0.0:
			continue
		var tipo := int(q_tipo[i])
		if tipo == PT_BRASA:
			continue
		var k := v / q_max[i]
		var c := q_cor[i]
		var p := (q_pos[i] + Vector2(0, -q_z[i])).round()
		if tipo == PT_FUMACA or tipo == PT_FUMACA_QUENTE:
			var r := q_tam[i] * (1.0 + 0.9 * (1.0 - k))
			c.a *= minf(1.0, k * 2.5) * minf(1.0, (1.0 - k) * 10.0)
			if tipo == PT_FUMACA_QUENTE:
				c = c.lerp(Color(1.0, 0.5, 0.15, c.a), clampf((k - 0.6) / 0.4, 0.0, 1.0) * 0.8)
			ci.draw_circle(p, r, Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, c.a))
			ci.draw_circle(p + Vector2(-r * 0.2, -r * 0.25), r * 0.65, c)
		else:
			c.a *= minf(1.0, k * 3.0)
			if q_z[i] > 1.0:
				ci.draw_rect(Rect2(q_pos[i].round() + Vector2(-1, 0), Vector2(2, 1)), Color(0, 0, 0, 0.35 * c.a))
			var t := q_tam[i]
			ci.draw_rect(
				Rect2(p - Vector2(t, t * 0.6) * 0.5 - Vector2.ONE, Vector2(t, t * 0.6) + Vector2(2, 2)),
				Color(COR_CONTORNO.r, COR_CONTORNO.g, COR_CONTORNO.b, c.a)
			)
			ci.draw_rect(Rect2(p - Vector2(t, t * 0.6) * 0.5, Vector2(t, t * 0.6)), c)


## A camada aditiva: as brasas (um ponto quente com um halo pequeno que pisca).
func _brilho_partes(ci: CanvasItem, tex: Texture2D) -> void:
	for i in MAX_PARTS:
		var v := q_vida[i]
		if v <= 0.0 or int(q_tipo[i]) != PT_BRASA:
			continue
		var k := v / q_max[i]
		var c := q_cor[i]
		var p := (q_pos[i] + Vector2(0, -q_z[i])).round()
		var pisca := 0.7 + 0.3 * sin(v * 23.0 + float(i))
		var a := minf(1.0, k * 2.0) * pisca
		var t := q_tam[i]
		ci.draw_texture_rect(tex, Rect2(p - Vector2(t, t) * 2.0, Vector2(t, t) * 4.0), false, Color(c.r, c.g, c.b, 0.55 * a))
		ci.draw_rect(Rect2(p - Vector2(t, t) * 0.5, Vector2(t, t)), Color(1.0, 0.92, 0.6, a).lerp(Color(1.0, 0.7, 0.25, a), 1.0 - k))


# ------------------------------------------------------------------ tipos


func _disparar(a: Dictionary, h, perto: Array) -> void:
	var st: Dictionary = a.st
	var alvo = _mais_perto(h.pos, float(st.alcance), perto)
	if alvo == null:
		return
	var saida: Vector2 = h.pos + Vector2(0, -14)  # o tiro sai do alto do herói, então a mira parte dali (senão a trajetória fica deslocada)
	var direcao: Vector2 = (alvo.pos - saida).normalized()
	var n := int(st.quantidade)
	var fa := Anim.de(str(a.id))
	# com folha, o tiro nasce em PREPARO: carrega na boca (sem hitbox) e só depois voa; sem folha sai na hora, como antes
	var prep := float(st.get("preparo", PREPARO_PROJ)) / vel_anim(h) if fa.has("voo") else 0.0
	for k in n:
		var it := _novo("projetil", a, saida, 1.6 + prep)
		if it.is_empty():
			return
		var ang := (float(k) - (n - 1) * 0.5) * 0.14  # tiros em leque curto
		it.v = direcao.rotated(ang) * float(st.vel)
		it.pen = int(st.get("perfura", 0.0))
		it.aux = float(st.get("ricochete", 0.0))
		if prep > 0.0:
			it.fk = F_PREPARO
			it.ft = prep
			it.age = prep  # o preparo inteiro (o desenho da carga mede o progresso por ele)
			it.orig = saida - h.pos  # a boca acompanha o herói enquanto carrega
			it.dest = direcao.rotated(ang)


## Fator de tempo das fases e das folhas: a velocidade de ataque encolhe o preparo, dentro de VEL_ANIM_MIN..VEL_ANIM_MAX (as cartas não
## deixam o golpe sem antecipação nem o arrastam demais).
func vel_anim(h) -> float:
	return clampf(float(h.m_vel_ataque), VEL_ANIM_MIN, VEL_ANIM_MAX)


## Toca a folha `f` (impacto ou marca no chão) uma vez em `p`. Só efeito: o dano já saiu no evento que chamou isto. Pool fixo, sem nó.
func tocar_fx(f: Dictionary, p: Vector2, esc := 1.0, chao := false) -> void:
	if f.is_empty():
		return
	var i := _xi
	_xi = (_xi + 1) % MAX_FX
	x_pos[i] = p
	x_t[i] = 0.0
	x_dur[i] = Anim.duracao(f)
	x_esc[i] = esc
	x_folha[i] = f
	x_chao[i] = 1 if chao else 0
	x_ativos += 1
	impactos += 1


func _quadro_fx(dt: float) -> void:
	var n := 0
	for i in MAX_FX:
		if x_t[i] < x_dur[i]:
			x_t[i] += dt
			if x_t[i] < x_dur[i]:
				n += 1
	x_ativos = n


## Desenha os impactos (`chao` false) ou as marcas no chão (true) que estão tocando.
func _desenhar_fx(ci: CanvasItem, chao: bool) -> void:
	for i in MAX_FX:
		if x_t[i] >= x_dur[i] or (x_chao[i] == 1) != chao:
			continue
		var f: Dictionary = x_folha[i]
		var esc := x_esc[i]
		if not chao:  # o soco do impacto: incha 14% nos primeiros 0,16 s e assenta (só o desenho; a área do dano é a mesma)
			esc *= 1.0 + 0.14 * sin(PI * clampf(x_t[i] / 0.16, 0.0, 1.0))
		Anim.desenhar_suave(ci, f, Anim.quadro_em_f(f, x_t[i]), x_pos[i], 0.0, Vector2(esc, esc))


## PREPARO do tiro: fica na boca (acompanha o herói), sem colidir; quando acaba, sai voando na direção guardada.
func _preparar_projetil(it: Dictionary, h, dt: float) -> void:
	it.p = h.pos + (it.orig as Vector2)
	it.ft = float(it.ft) - dt
	if float(it.ft) <= 0.0:
		it.fk = F_ATIVO


func _mover_projetil(it: Dictionary, dt: float, perto: Array) -> void:
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	it.p = it.p + it.v * dt
	var p: Vector2 = it.p
	# O virote da torre e o estilhaço da granada só enxergam os monstros perto DELES (`lista`): o herói pode estar longe dali.
	var alvos: Array = perto if it.lista == null else it.lista
	if str(a.tipo) == "torre":  # o rastro do virote: uma faísca a cada ~2 quadros, que apaga rápido
		it.mira = float(it.mira) - dt
		if float(it.mira) <= 0.0:
			it.mira = 0.03
			var pagode_t := st.has("cadeia")
			var cor_t: Color = Color(0.55, 0.8, 1.0, 0.85) if pagode_t else Color(1.0, 0.7, 0.28, 0.85)
			pai.fx.particula(p - (it.v as Vector2).normalized() * 6.0, Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)), 0.22, 3.0, cor_t, 0.0, true)
	for m in alvos:
		if not m.vivo or m.morrendo or (it.hit as Array).has(m):
			continue
		if _eli(m.pos - p).length() > RAIO_PROJ + float(m.raio):
			continue
		(it.hit as Array).append(m)
		var dir: Vector2 = (it.v as Vector2).normalized()
		var dano := _dano(st) * float(it.mult)
		var estilhaco := str(a.tipo) == "granada"  # o número do estilhaço sai espalhado, não em cima do número da explosão
		# o crítico das cartas (Olho de falcão) vale para o tiro do herói também: dano da regra da katana e número dourado
		var crit: bool = str(a.tipo) == "projetil" and randf() < pai.combate.chance_critico()
		if crit:
			dano *= float(pai.combate.cfg.golpe.critico.mult)
		pai.combate.ferir(m, dano, dir, 40.0, 0.1, COR_CRIT if crit else _cor_num(a.cor), not estilhaco, crit)
		var fa: Dictionary = it.fa
		if fa.has("impacto"):  # o impacto toca no ponto do acerto (o evento real), não no fim da animação do voo
			tocar_fx(fa.impacto, p, 2.0 if crit else 1.0)
		if estilhaco:
			_numero_estilhaco(m, dano, dir, a, it)
		pai._acertou("projetil")
		if str(a.tipo) == "torre" and int(st.get("cadeia", 0.0)) > 0:  # o Pagode do Trovão: o virote vira arco elétrico
			_cadeia_eletrica(m, dano * 0.6, int(st.cadeia), alvos)
		var ex := float(st.get("explosao", 0.0))
		if ex > 0.0:
			pai.explodir(m.pos, dano, ex, a.cor, m)
		if st.has("puxa"):  # a tempestade: cada impacto puxa os inimigos próximos para o ponto
			_puxar(m.pos, float(st.get("puxa_raio", 90.0)), float(st.puxa))
		if float(it.aux) >= 1.0 and str(a.tipo) == "projetil":  # ricochete (número `ricochete` da arma): muda de rumo para o vizinho mais perto
			var prox = _mais_perto_sem(p, RICOCHETE_ALC, alvos, it.hit)
			if prox != null:
				it.aux = float(it.aux) - 1.0
				it.v = (prox.pos - p).normalized() * (it.v as Vector2).length()
				it.vida = maxf(float(it.vida), 0.5)
				return
		if int(it.pen) <= 0:
			it.vida = 0.0
			return
		it.pen = int(it.pen) - 1


func _nuvem(a: Dictionary, h, perto: Array) -> void:
	var st: Dictionary = a.st
	var alvo = _mais_perto(h.pos, float(st.alcance) * 1.6, perto)
	if alvo == null:
		return
	var it := _novo("nuvem", a, alvo.pos, float(st.duracao))
	if it.is_empty():
		return
	it.r = float(st.raio)
	it.t = 0.05  # o primeiro tique já vem logo
	if Anim.de(str(a.id)).has("entrada"):  # com folha: a nuvem se forma (entrada) e só então o primeiro tique cai
		var prep := float(st.get("preparo", ENTRADA_NUVEM)) / vel_anim(h)
		it.t = prep
		it.vida = float(it.vida) + prep
		it.aux = prep


func _tique_nuvem(it: Dictionary, dt: float) -> void:
	it.t = float(it.t) - dt
	if float(it.t) > 0.0:
		return
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	it.t = float(st.tique)
	var alvos := 0
	var dano_total := 0.0
	for m in pai.mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		if not pai.na_elipse(m.pos - it.p, float(it.r) + m.raio):
			continue
		var dano := _dano(st)
		if st.has("gelo_mult") and m.lento_t > 0.0:  # o furacão: quem já está lento dentro leva dano em dobro
			dano *= float(st.gelo_mult)
		var vida_antes := float(m.vida)
		var fora: Vector2 = (m.pos - it.p).normalized() if m.pos.distance_squared_to(it.p) > 0.25 else Vector2.RIGHT
		pai.combate.ferir(m, dano, fora, 30.0, 0.0, _cor_num(a.cor))
		var aplicado := maxf(0.0, vida_antes - float(m.vida))
		if float(st.get("lentidao", 0.0)) > 0.0:
			m.deixar_lento(float(st.lentidao))
		alvos += 1
		dano_total += aplicado
		if st.has("gelo_mult"):
			pai._acertou("nuvem")  # o golpe de gelo contava cada inimigo atingido
	if alvos > 0:
		if not st.has("gelo_mult"):
			pai._acertou("nuvem")  # o dano de área comum contava um evento por tique
	if dano_total > 0.0:
		# O brilho acompanha a vida realmente removida; um tique sem alvo ou sem dano não pulsa.
		it.pulso = clampf(dano_total / maxf(1.0, _dano(st) * 4.0), 0.0, 1.0)


## Puxa os monstros dentro de `raio` até `forca` px na direção de `p` (a tempestade primordial).
func _puxar(p: Vector2, raio: float, forca: float) -> void:
	for m in pai.mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var d: Vector2 = p - m.pos
		if _eli(d).length() > raio:
			continue
		pai.mundo.mover(m, d.normalized() * minf(forca, d.length()))  # passa pela colisão: a tempestade não puxa ninguém para dentro de uma barreira


## Onde sai o próximo número de um monstro: cada número da mesma rajada (0,7 s) ocupa um lugar diferente em volta dele (`SLOTS_NUM`: o meio,
## depois um de cada lado, subindo), para não empilhar. `dir` escolhe o lado do segundo.
func _pos_numero(m, dir: Vector2) -> Vector2:
	var id: int = m.get_instance_id()
	var reg: Vector2 = _slot_num.get(id, Vector2(-10.0, 0.0))
	if _relogio - reg.x > 0.7:
		reg.y = 0.0
	var k := int(reg.y)
	reg = Vector2(_relogio, reg.y + 1.0)
	_slot_num[id] = reg
	if _slot_num.size() > 64:  # só ficam os que ainda estão numa rajada
		for outro in _slot_num.keys():
			if _relogio - (_slot_num[outro] as Vector2).x > 0.7:
				_slot_num.erase(outro)
	var slot: Vector2 = SLOTS_NUM[k % SLOTS_NUM.size()]
	if k % 2 == 1 and dir.x < 0.0:  # o segundo vai para o lado de onde veio o golpe
		slot.x = -slot.x
	return m.pos + slot + Vector2(0, -float(m.alt) * 0.8 - floorf(float(k) / float(SLOTS_NUM.size())) * 8.0)


## O número do estilhaço da cabaça: pequeno, quente (ou da cor do fogo) e SOMADO por monstro: os estilhaços de uma explosão que acertam o mesmo
## monstro saem num número só (`_num_somar`), num lugar só dele (`_pos_numero`), em vez de "7 7 7" empilhados. Faz também a piscada de dano que o
## `ferir` pularia.
func _numero_estilhaco(m, dano: float, dir: Vector2, a: Dictionary, it: Dictionary) -> void:
	var cor := Color(1.0, 0.78, 0.4)
	if a.st.has("fogos"):
		cor = FOGOS_CORES[int(it.t) % 3].lerp(Color.WHITE, 0.3)
	_num_somar(m, dano, dir, cor)
	pai.fx.flash(m, 0.08)


## Dano do golpe; se o monstro já está lento e a arma tem `mult_lento`, o dano sobe (combo de lentidão).
func _dano_em(m, st: Dictionary) -> float:
	var d := _dano(st)
	if st.has("mult_lento") and m.lento_t > 0.0:
		d *= float(st.mult_lento)
	return d


func _anel(a: Dictionary, h) -> void:
	var st: Dictionary = a.st
	var prep := float(st.get("preparo", PREPARO_ANEL)) / vel_anim(h) if Anim.de(str(a.id)).has("expandir") else 0.0
	if Anim.de(str(a.id) + "_queda").has("queda"):  # o anel que vem de uma peça caindo (o Martelo do Trovão): o preparo é a queda dela
		prep = float(st.get("preparo", QUEDA_ANEL)) / vel_anim(h)
	var it := _novo("anel", a, h.pos, float(st.raio) / float(st.vel) + 0.05 + prep)
	if it.is_empty():
		return
	it.r = 0.0
	fumaca_impacto(h.pos, 30.0, a.cor, 0.5)  # o sopro da onda saindo: poeira rasteira na cor dela
	if prep <= 0.0:
		pai.fx.explosao(h.pos, float(st.raio), a.cor, 0.0, _dur_onda(st))
	if prep > 0.0:  # PREPARO: o anel junta força no herói (o primeiro quadro da folha pulsa), sem hitbox
		it.fk = F_PREPARO
		it.ft = prep
		it.aux = prep


## Duração da explosão que acompanha a onda do anel: o anel de energia do shader chega à borda em 40% dela, junto da frente real.
func _dur_onda(st: Dictionary) -> float:
	return clampf(float(st.raio) / maxf(float(st.vel), 1.0) / 0.4, 0.5, 2.0)


func _mover_anel(it: Dictionary, h, dt: float, perto: Array) -> void:
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	it.p = h.pos  # o anel sai do herói e anda com ele
	if int(it.fk) == F_PREPARO:
		it.ft = float(it.ft) - dt
		if float(it.ft) > 0.0:
			return
		it.fk = F_ATIVO
		pai.fx.explosao(it.p, float(st.raio), a.cor, 0.0, _dur_onda(st))  # a onda sai: os anéis de energia abrem junto dela até a borda
		if Anim.de(str(a.id) + "_queda").has("queda"):  # a peça bateu no chão: a onda nasce aqui, com tremor e poeira
			pai.mundo.cam.tremer(1.5, 0.1)
			_poeira(it.p, 6, Color(0.6, 0.62, 0.7), 80.0, 0.4)
			fumaca_impacto(it.p, 40.0, a.cor)
			pai.fx.explosao(it.p, 44.0, a.cor)
			pai.fx.marca_chao(it.p, 34.0, a.cor)
	it.r = float(it.r) + float(st.vel) * dt
	var c: Vector2 = it.p
	var r := float(it.r)
	for m in perto:
		if not m.vivo or m.morrendo or (it.hit as Array).has(m):
			continue
		if absf(_eli(m.pos - c).length() - r) > 14.0 + float(m.raio):
			continue
		(it.hit as Array).append(m)
		var dir: Vector2 = (m.pos - c).normalized()
		pai.combate.ferir(m, _dano(st), dir, float(st.get("empurra", 0.0)), 0.15, _cor_num(a.cor))
		var lento := float(st.get("lento_s", 0.0))  # o gelo: segundos de lentidão no monstro atingido
		if lento > 0.0:
			m.deixar_lento(lento)
		pai._acertou("anel")
	if r >= float(st.raio):
		it.vida = 0.0


func _meteoros(a: Dictionary, h, perto: Array) -> void:
	var st: Dictionary = a.st
	for k in int(st.quantidade):
		var alvo = perto[randi() % perto.size()]
		var it := _novo("meteoro", a, alvo.pos, float(st.aviso) + 0.3)
		if it.is_empty():
			return
		it.t = float(st.aviso)  # o aviso no chão antes da queda
		it.r = -1.0 if randi() % 2 == 0 else 1.0  # de que lado ele vem descendo (_queda)
		it["filho"] = false


func _cair_meteoro(it: Dictionary, dt: float) -> void:
	if float(it.t) <= 0.0:
		return  # já caiu: só o estouro sobra
	it.t = float(it.t) - dt
	if float(it.t) > 0.0:
		return
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	pai.explodir(it.p, _dano(st), float(st.raio), a.cor)
	var fa: Dictionary = it.fa
	if fa.has("impacto"):  # o impacto e a marca tocam no instante da queda, o mesmo do dano
		var q: Vector2 = fa.impacto.quadro
		tocar_fx(fa.impacto, it.p, maxf(1.0, roundf(float(st.raio) * 2.0 / q.x)))
	if fa.has("marca"):
		tocar_fx(fa.marca, it.p, 1.0, true)
	if fa.has("queda"):  # o peso da queda: poeira rasteira (pool de partículas, poucas) e um tremor curto nos grandes
		_poeira(it.p, 5, Color(0.55, 0.5, 0.42), 70.0, 0.45)
		if float(st.raio) >= 40.0:
			pai.mundo.cam.tremer(1.0, 0.08)
		if Anim.suave:  # a segunda onda, mais larga e lenta, e o clarão branco no centro (só desenho: o dano já saiu acima)
			pai.fx.onda(it.p, Color(1, 1, 1, 0.55), float(st.raio) * 0.8, 0.4)
			pai.fx.luz_rapida(it.p + Vector2(0, -6), Color(1, 1, 1), 1.2, float(st.raio) * 2.0, 0.18)
	if st.has("cadeia") and not bool(it.get("filho", false)):  # o juízo: cada queda chama outro meteoro no inimigo mais perto
		var alvo = _mais_perto(it.p, 400.0, pai.mundo.monstros)
		if alvo != null:
			var f := _novo("meteoro", a, alvo.pos, float(st.aviso) + 0.3)
			if not f.is_empty():
				f.t = float(st.aviso)
				f.r = -float(it.r) if float(it.r) != 0.0 else 1.0  # o elo vem do outro lado
				f["filho"] = true  # o filho não chama outro: a corrente tem só um elo
	it.vida = 0.3  # o estouro fica um pouco


## Põe na fila as folhas que a invocação `id` (carta ou fusão) ainda não carregou. Sem isso o primeiro bicho de cada tipo lê o png (e faz a
## versão cinza das fusões) no quadro em que nasce, no meio do combate: de 2 a 8 ms aqui, num quadro só.
func pedir_aquecer(id: String) -> void:
	var pend: Array = ["golem"] if Golem.eh_golem(id) and not Golem.lida() else Andante.folhas_pendentes(id)
	for item in pend:
		if not fila_aquecer.has(item):
			fila_aquecer.append(item)


## Carrega um item da fila (telas.gd chama a cada quadro enquanto a escolha ou o baú estão abertos, com o mundo parado).
func aquecer_um() -> void:
	if fila_aquecer.is_empty():
		return
	var item: String = fila_aquecer.pop_front()
	if item == "golem":
		Golem.tex()
	else:
		Andante.aquecer(item)


func _aliados(a: Dictionary, h) -> void:
	var st: Dictionary = a.st
	a["ate"] = _relogio + float(st.duracao)
	for k in int(st.quantidade):
		var deslocado: Vector2 = h.pos + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0))
		var it := _novo("aliado", a, deslocado, float(st.duracao))
		if it.is_empty():
			return
		it.t = 0.0
		if Golem.eh_golem(str(a.id)) and Golem.tex() != null:
			Golem.nascer(self, it)
		elif Andante.eh_andante(str(a.id)) and Andante.tex(str(a.id)) != null:
			Andante.nascer(self, it)


func _mover_aliado(it: Dictionary, h, dt: float, perto: Array) -> void:
	if bool(it.g):
		Golem.mover(self, it, h, dt, perto)
		return
	if bool(it.an):
		Andante.mover(self, it, h, dt, perto)
		return
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	it.t = float(it.t) - dt
	var alvo = _mais_perto(it.p, 400.0, perto)
	var dest: Vector2
	if alvo != null:
		dest = alvo.pos
	else:
		dest = h.pos + Vector2.from_angle(float(it.fase)) * 50.0  # sem inimigo, gira em volta do herói
	var d: Vector2 = dest - it.p
	if d.length() > 1.0:
		it.p = pai.mundo.mover_ponto(it.p, d.normalized() * minf(float(st.vel) * dt, d.length()), RAIO_ALIADO)
	if d.length() > 1.0:
		it.v = (it.v as Vector2).lerp(d.normalized(), clampf(dt * 10.0, 0.0, 1.0))  # para onde corre (suavizado: o quadro não pisca na virada)
	if absf(d.x) > 2.0:
		it.r = signf(d.x)  # aliado não usa raio: guarda para que lado olha (1 = direita, -1 = esquerda)
	if alvo != null and float(it.t) <= 0.0 and _eli(alvo.pos - it.p).length() < 12.0 + float(alvo.raio):
		it.t = float(st.tique)
		var dir: Vector2 = (alvo.pos - it.p).normalized()
		var dano := _dano_em(alvo, st)
		if st.has("prende"):  # o eclipse: o toque prende o inimigo na sombra
			alvo.deixar_lento(float(st.prende))
		pai.combate.ferir(alvo, dano, dir, 30.0, 0.05, _cor_num(a.cor))
		pai._acertou("aliado")


# ------------------------------------------------------------------ torre (Sentinela de Bambu e Pagode do Trovão)


## Finca `quantidade` torretas atrás do herói (do lado oposto ao inimigo mais perto), lado a lado. As torres antigas desta arma desmontam
## na hora (no máximo `quantidade` de pé por arma). Cada torre atira por conta própria no inimigo mais perto DELA (`_atirar_torre`).
func _torres(a: Dictionary, h, perto: Array) -> void:
	var st: Dictionary = a.st
	var alvo = _mais_perto(h.pos, 340.0, perto)
	var para: Vector2 = Vector2.RIGHT if alvo == null else (alvo.pos - h.pos).normalized()
	for x in itens:
		if float(x.vida) > DESMONTA and str(x.k) == "torre" and is_same(x.a, a):
			x.vida = DESMONTA  # a velha desmonta (o `_mover_torre` solta as lascas)
	a["ate"] = _relogio + float(st.duracao) + DESMONTA
	var n := int(st.quantidade)
	var lado := para.orthogonal()
	for k in n:
		var onde: Vector2 = h.pos - para * 42.0 + lado * (float(k) - (n - 1) * 0.5) * 34.0
		var it := _novo("torre", a, onde, float(st.duracao) + DESMONTA)
		if it.is_empty():
			return
		it.r = para.angle()  # a balestra nasce apontada para onde o inimigo está
		it.dest = Vector2(para.angle(), 0.0)  # o ângulo-base da varredura ociosa
		it.age = 0.0
		it.t = 0.0


func _mover_torre(it: Dictionary, h, dt: float) -> void:
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	it.age = float(it.age) + dt
	it.aux = maxf(0.0, float(it.aux) - dt * 7.0)  # o recuo e o clarão da balestra voltam em ~0,14 s
	it.mira = maxf(0.0, float(it.mira) - dt)
	var est := int(it.est)
	if float(it.vida) - DESMONTA <= 0.0:
		if est < 2:
			it.est = 2
			_lascas_torre(it)
		return
	if est == 0:
		if float(it.age) >= POUSO_T:
			it.est = 1
			_pouso_torre(it)
		return
	if float(it.mira) <= 0.0:  # sem alvo recente: a balestra varre de um lado para o outro
		var varre := float((it.dest as Vector2).x) + sin(float(it.age) * 1.7) * 0.4
		it.r = lerp_angle(float(it.r), varre, clampf(dt * 5.0, 0.0, 1.0))
	if float(it.age) < ARMA_T:
		return
	it.t = float(it.t) - dt
	if float(it.t) > 0.0:
		return
	if _atirar_torre(it, st):
		it.t = float(st.tique) / float(h.m_vel_ataque)
	else:
		it.t = 0.15  # sem inimigo ao alcance: procura de novo em instantes (uma varredura por tentativa, não por quadro)


## Um disparo da torre: varre os monstros UMA vez (guarda os que estão perto dela em `cand`, que o virote usa para colidir), mira no mais
## perto dentro do `alcance` e solta o virote. Devolve falso quando não há ninguém ao alcance.
func _atirar_torre(it: Dictionary, st: Dictionary) -> bool:
	var alc := float(st.alcance)
	var cand: Array = it.cand
	cand.clear()
	var alvo = null
	var md := alc * alc
	var margem := (alc + 70.0) * (alc + 70.0)
	for m in pai.mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var d2 := _eli(m.pos - it.p).length_squared()
		if d2 >= margem:
			continue
		cand.append(m)
		if d2 < md:
			md = d2
			alvo = m
	if alvo == null:
		return false
	var a: Dictionary = it.a
	var eixo: Vector2 = (it.p as Vector2) + Vector2(0, TORRE_PIVO)
	var dir: Vector2 = (alvo.pos + Vector2(0, -6) - eixo).normalized()
	var boca: Vector2 = eixo + dir * TORRE_BOCA
	it.r = dir.angle()
	it.mira = 0.7
	it.aux = 1.0
	var vel := float(st.get("vel", 420.0))
	var b := _novo("projetil", a, boca, (alc + 70.0) * 1.15 / vel)
	if not b.is_empty():
		b.v = dir * vel
		b.pen = int(st.get("perfura", 0.0))
		b.lista = cand
	var pagode := st.has("cadeia")
	var cor_f: Color = pai.COR_RAIO if pagode else Color(1.0, 0.75, 0.3)
	pai.fx.faiscas(boca, dir, 5, cor_f, 230.0)
	for i in maxi(1, roundi(2.0 * pai.fx.fator_part)):  # a fumacinha do disparo
		_parte(
			PT_FUMACA,
			boca,
			0.0,
			dir * randf_range(14.0, 30.0) + Vector2(randf_range(-6.0, 6.0), 0.0),
			randf_range(8.0, 16.0),
			randf_range(0.35, 0.55),
			randf_range(2.5, 3.5),
			Color(0.82, 0.8, 0.74, 0.5)
		)
	pai.combate.audio.tocar("estocada", randf_range(1.5, 1.8), -10.0, 0.06)
	return true


## O Pagode do Trovão: depois do acerto, o virote salta `saltos` vezes para o vizinho mais perto (até 72 px) em arco elétrico.
func _cadeia_eletrica(de, dano: float, saltos: int, lista: Array) -> void:
	var pontos: Array = [de.pos + Vector2(0, -10)]
	var marcados: Array = [de]
	var atual = de
	for s in saltos:
		var melhor = null
		var md := 72.0 * 72.0
		for m in lista:
			if not m.vivo or m.morrendo or marcados.has(m):
				continue
			var d2: float = m.pos.distance_squared_to(atual.pos)
			if d2 < md:
				md = d2
				melhor = m
		if melhor == null:
			break
		marcados.append(melhor)
		pai.combate.ferir(melhor, dano, (melhor.pos - atual.pos).normalized(), 30.0, 0.1, pai.COR_RAIO)
		pontos.append(melhor.pos + Vector2(0, -10))
		pai.fx.faiscas(melhor.pos + Vector2(0, -10), (melhor.pos - atual.pos).normalized(), 3, pai.COR_RAIO, 120.0)
		pai.fx.onda(melhor.pos, Color(0.7, 0.85, 1.0, 0.9), 20.0, 0.15)
		atual = melhor
	if pontos.size() > 1:
		pai._raio_visual(pontos)
		pai._raio_visual(pontos)  # duas descargas, tortas de jeitos diferentes: o arco fica grosso e vivo
		for q in pontos:
			pai.fx.particula(q, Vector2.ZERO, 0.2, 28.0, Color(0.55, 0.8, 1.0, 0.8), 0.0, true)
		pai._acertou("raio")
		pai.fx.luz_rapida(atual.pos + Vector2(0, -10), pai.COR_RAIO, 1.6, 110.0, 0.18)
		pai.combate.audio.tocar("raio", randf_range(1.05, 1.2), -6.0, 0.08)
		pai.mundo.cam.tremer(0.8, 0.08)


## Poeira de terra/lascas: `n` pontinhos que saem rasteiros e caem (o pool de partículas dos efeitos, sem nó novo).
func _poeira(p: Vector2, n: int, cor: Color, vel := 60.0, vida := 0.4) -> void:
	n = maxi(1, roundi(n * pai.fx.fator_part))
	for i in n:
		var ang := randf() * TAU
		var v := Vector2(cos(ang), sin(ang) * 0.5) * randf_range(0.4, 1.0) * vel - Vector2(0, 8.0)
		pai.fx.particula(p + Vector2(cos(ang) * 4.0, sin(ang) * 2.0), v, randf_range(0.6, 1.0) * vida, 2.0 + float(i % 2), cor, 60.0)


## Nuvem de poeira no chão: `n` bolas que incham e somem (camada normal, tingida pela luz), saindo para os lados.
func _nuvem_poeira(p: Vector2, n: int, cor: Color, vel: float, tam: float) -> void:
	n = maxi(2, roundi(n * pai.fx.fator_part))
	for i in n:
		var ang := TAU * (float(i) + randf() * 0.6) / float(n)
		var v := Vector2(cos(ang), sin(ang) * 0.45) * randf_range(0.6, 1.0) * vel
		_parte(PT_FUMACA, p + v * 0.05, 1.0, v, randf_range(5.0, 14.0), randf_range(0.45, 0.7), tam * randf_range(0.7, 1.1), cor)


## Fumaça que sobe de uma explosão: bolas escuras que nascem espalhadas na área e incham devagar.
func _fumaca_subindo(p: Vector2, n: int, raio: float, tam: float) -> void:
	n = maxi(2, roundi(n * pai.fx.fator_part))
	for i in n:
		var q := p + Vector2(randf_range(-0.3, 0.3) * raio, randf_range(-0.12, 0.12) * raio)
		_parte(
			PT_FUMACA_QUENTE,
			q,
			randf_range(2.0, 10.0),
			Vector2(randf_range(-14.0, 14.0), 0.0),
			randf_range(34.0, 62.0),
			randf_range(0.8, 1.2),
			tam * randf_range(0.9, 1.4),
			Color(0.6, 0.55, 0.52, 0.9)
		)


## Fumaça e poeira de impacto (só efeito, nada de dano): um anel de poeira rasteira que abre para os lados e umas bolas de fumaça que sobem
## e incham, tingidas de leve pela cor do golpe. Cresce com a área (`raio`) e com `forca`; segue a opção de partículas (nenhuma = sem fumaça)
## e usa o pool fixo de partículas daqui (MAX_PARTS, a mais velha é sobrescrita), então muitos impactos juntos não pesam mais.
## O sorteio é do `_rng_fumaca` (próprio): enfeite não gasta o randf() global, de que o jogo e os testes dependem.
func fumaca_impacto(p: Vector2, raio: float, cor: Color, forca := 1.0) -> void:
	if pai.fx.fator_part <= 0.0:
		return
	var r := _rng_fumaca
	var tinta := Color(0.52, 0.5, 0.48).lerp(Color(cor.r, cor.g, cor.b), 0.3)
	var n := clampi(roundi(raio / 10.0 * forca), 3, 9)
	var tam := clampf(raio * 0.09, 3.5, 8.0) * lerpf(0.75, 1.0, clampf(forca, 0.0, 1.0))
	var n_chao := maxi(2, roundi(n * pai.fx.fator_part))
	for i in n_chao:  # a poeira rasteira (como _nuvem_poeira)
		var ang := TAU * (float(i) + r.randf() * 0.6) / float(n_chao)
		var v := Vector2(cos(ang), sin(ang) * 0.45) * r.randf_range(0.6, 1.0) * raio * 1.2
		_parte(
			PT_FUMACA,
			p + v * 0.05,
			1.0,
			v,
			r.randf_range(5.0, 14.0),
			r.randf_range(0.45, 0.7),
			tam * r.randf_range(0.7, 1.1),
			Color(tinta.r, tinta.g, tinta.b, 0.45)
		)
	for i in maxi(1, roundi(float(n) * 0.5 * pai.fx.fator_part)):  # a fumaça que sobe
		var q := p + Vector2(r.randf_range(-0.35, 0.35) * raio, r.randf_range(-0.15, 0.15) * raio)
		_parte(
			PT_FUMACA,
			q,
			r.randf_range(2.0, 8.0),
			Vector2(r.randf_range(-10.0, 10.0), 0.0),
			r.randf_range(18.0, 36.0),
			r.randf_range(0.7, 1.05),
			tam * r.randf_range(1.0, 1.4),
			Color(tinta.r, tinta.g, tinta.b, 0.5)
		)
	var claro := cor.lerp(Color(1.0, 0.9, 0.7), 0.4)
	for i in maxi(2, roundi(float(n) * pai.fx.fator_part)):  # lascas do chão que pulam e quicam, e brasas na cor do golpe que sobem
		var ang := r.randf() * TAU
		var v := Vector2(cos(ang), sin(ang) * 0.5) * r.randf_range(0.4, 1.0) * (60.0 + raio * 1.2)
		var lasca := Color(0.32, 0.27, 0.24) if i % 2 == 0 else Color(0.5, 0.44, 0.38)
		_parte(PT_LASCA, p, 3.0, v, r.randf_range(90.0, 180.0), r.randf_range(0.6, 0.9), 2.0 + float(i % 2), lasca)
		var q := p + Vector2(cos(ang), sin(ang) * ACHATA) * raio * 0.6 * sqrt(r.randf())
		_parte(PT_BRASA, q, r.randf_range(0.0, 4.0), Vector2(r.randf_range(-10.0, 10.0), 0.0), r.randf_range(12.0, 30.0), r.randf_range(0.6, 1.2), 2.0, claro)


## Brasas no chão (e subindo, se `sobe` > 0): pontos quentes que piscam e apagam devagar.
func _brasas(p: Vector2, n: int, raio: float, vida: float, sobe: float, cor: Color) -> void:
	n = maxi(1, roundi(n * pai.fx.fator_part))
	for i in n:
		var ang := randf() * TAU
		var q := p + Vector2(cos(ang), sin(ang) * ACHATA) * raio * sqrt(randf())
		_parte(
			PT_BRASA,
			q,
			randf_range(0.0, 3.0),
			Vector2(randf_range(-8.0, 8.0), randf_range(-3.0, 3.0)),
			sobe * randf_range(0.4, 1.0),
			vida * randf_range(0.6, 1.0),
			3.0 if i % 3 == 0 else 2.0,
			cor
		)


## Lascas de bambu/terra que voam para cima e para os lados e caem com sombrinha.
func _lascas(p: Vector2, z: float, n: int, vel: float, c1: Color, c2: Color) -> void:
	n = maxi(2, roundi(n * pai.fx.fator_part))
	for i in n:
		var ang := randf() * TAU
		var v := Vector2(cos(ang), sin(ang) * 0.5) * randf_range(0.35, 1.0) * vel
		_parte(PT_LASCA, p, z, v, randf_range(90.0, 190.0), randf_range(0.6, 0.9), 2.0 + float(i % 3), c1 if i % 2 == 0 else c2)


func _pouso_torre(it: Dictionary) -> void:
	var p: Vector2 = it.p
	var pagode: bool = it.a.st.has("cadeia")
	pai.fx.onda(p, Color(0.85, 0.75, 0.55, 0.7), 30.0, 0.22)
	pai.fx.onda(p, Color(1.0, 0.9, 0.6, 0.5), 18.0, 0.14)
	_nuvem_poeira(p, 7, Color(0.66, 0.54, 0.38, 0.75), 85.0, 6.5)
	_lascas(p, 3.0, 9, 80.0, Color(0.5, 0.38, 0.22), Color(0.36, 0.26, 0.15))
	_poeira(p + Vector2(0, -2), 8, Color(0.75, 0.62, 0.42), 80.0, 0.45)
	pai.fx.luz_rapida(p + Vector2(0, -6), Color(0.55, 0.78, 1.0) if pagode else Color(1.0, 0.8, 0.45), 1.1, 70.0, 0.14)
	if pagode:
		pai.fx.faiscas(p + Vector2(0, -12), Vector2.UP, 7, pai.COR_RAIO, 170.0)
	pai.mundo.cam.tremer(2.0, 0.1)
	pai.combate.audio.tocar("runa_poe", 1.2, -4.0, 0.05)


func _lascas_torre(it: Dictionary) -> void:
	var p: Vector2 = it.p
	_lascas(p, 14.0, 12, 100.0, COR_BAMBU, COR_BAMBU_ESCURO)
	_nuvem_poeira(p, 4, Color(0.62, 0.5, 0.34, 0.6), 50.0, 5.0)
	_poeira(p + Vector2(0, -12), 6, COR_BAMBU, 90.0, 0.5)
	pai.combate.audio.tocar("impacto", 1.4, -10.0, 0.06)


# ------------------------------------------------------------------ granada (Cabaça de Pólvora e Fogos de Festival)


## A direção do maior grupo: dos monstros dentro de `alc`, testa até ~8 candidatos (um a cada tantos da lista) e fica com o que tem mais
## vizinhos a 60 px; devolve o centro desses vizinhos. Sem ninguém no alcance, mira o mais perto de todos.
func _centro_do_grupo(de: Vector2, alc: float, perto: Array) -> Vector2:
	var melhor_n := 0
	var melhor_c := Vector2.ZERO
	var passo := maxi(1, perto.size() >> 3)
	var i := randi() % passo
	while i < perto.size():
		var m = perto[i]
		i += passo
		if not m.vivo or m.morrendo or _eli(m.pos - de).length() > alc:
			continue
		var soma := Vector2.ZERO
		var viz := 0
		for o in perto:
			if o.vivo and not o.morrendo and _eli(o.pos - m.pos).length() < 60.0:
				soma += o.pos
				viz += 1
		if viz > melhor_n:
			melhor_n = viz
			melhor_c = soma / float(viz)
	if melhor_n > 0:
		return melhor_c
	var perto_de_tudo = _mais_perto(de, 340.0, perto)
	return perto_de_tudo.pos if perto_de_tudo != null else de + Vector2(alc * 0.5, 0.0)


## Arremessa `quantidade` cabaças sobre o maior grupo, em leque (a segunda e as outras saem 0,14 s depois, abertas para o lado).
func _granadas(a: Dictionary, h, perto: Array) -> void:
	var st: Dictionary = a.st
	var alvo_p := _centro_do_grupo(h.pos, float(st.alcance), perto)
	var d: Vector2 = alvo_p - h.pos
	var dir: Vector2 = d.normalized() if d.length() > 1.0 else Vector2.RIGHT
	var n := int(st.quantidade)
	for k in n:
		var it := _novo("granada", a, h.pos, 99.0)
		if it.is_empty():
			return
		it.orig = h.pos
		it.dest = alvo_p + dir.orthogonal() * (float(k) - (n - 1) * 0.5) * 30.0
		it.v = dir
		it.age = -0.14 * float(k)  # idade negativa = ainda na mão
		it.est = 0
		it.r = 0.0
		it.t = 0.0
	pai.fx.faiscas(h.pos + Vector2(0, -16), dir, 2, Color(1.0, 0.6, 0.2), 140.0)
	pai.combate.audio.tocar("corte2", 1.5, -6.0, 0.05)


## Altura da cabaça no ar: parábola no voo (começa na mão, 14 px) e um quique baixo de 14 px.
func _altura_granada(it: Dictionary) -> float:
	var st: Dictionary = it.a.st
	var age := float(it.age)
	match int(it.est):
		0:
			var k := clampf(age / float(st.get("voo", 0.55)), 0.0, 1.0)
			var alta := clampf(30.0 + (it.orig as Vector2).distance_to(it.dest) * 0.25, 40.0, 80.0)
			return 4.0 * alta * k * (1.0 - k) + 14.0 * (1.0 - k)
		1:
			var k := clampf(age / QUIQUE_T, 0.0, 1.0)
			return 4.0 * 14.0 * k * (1.0 - k)
	return 0.0


## A ponta do pavio na tela: o centro da cabaça (6 px acima do ponto no chão, mais a altura do voo) e o pavio girado com ela.
func _ponta_pavio(it: Dictionary) -> Vector2:
	return (it.p as Vector2) + Vector2(0, -_altura_granada(it) - 6.0) + Vector2(3.0, -13.0).rotated(float(it.r))


func _mover_granada(it: Dictionary, dt: float) -> void:
	var st: Dictionary = it.a.st
	it.age = float(it.age) + dt
	it.aux = maxf(0.0, float(it.aux) - dt)
	var est := int(it.est)
	var age := float(it.age)
	if age < 0.0:
		it.p = it.orig
		return
	if est <= 2:
		if est < 2:
			it.r = float(it.r) + dt * (12.0 if est == 0 else 5.0)  # a cabaça gira no ar
		it.t = float(it.t) - dt
		if float(it.t) <= 0.0:  # o pavio solta uma brasa a cada 0,05 s
			it.t = 0.05
			var c: Vector2 = _ponta_pavio(it)
			pai.fx.particula(c, Vector2(randf_range(-16.0, 16.0), randf_range(-30.0, -8.0)), 0.3, 2.0, Color(1.0, 0.82, 0.3, 0.95), 80.0, true)
			pai.fx.particula(c, Vector2(randf_range(-30.0, 30.0), randf_range(-10.0, 14.0)), 0.18, 2.0, Color(1.0, 0.55, 0.15, 0.9), 160.0, true)
			it.mira = float(it.mira) - 0.05
			if float(it.mira) <= 0.0:  # um fio de fumaça cinza que a cabaça deixa no arco
				it.mira = 0.1
				_parte(
					PT_FUMACA,
					c,
					0.0,
					Vector2(randf_range(-6.0, 6.0), 0.0),
					randf_range(10.0, 20.0),
					randf_range(0.35, 0.55),
					randf_range(2.0, 3.0),
					Color(0.62, 0.6, 0.56, 0.55)
				)
	match est:
		0:
			var k := clampf(age / float(st.get("voo", 0.55)), 0.0, 1.0)
			it.p = (it.orig as Vector2).lerp(it.dest, k)
			if k >= 1.0:  # primeiro toque no chão: o quique anda 18 px para a frente
				it.est = 1
				it.age = 0.0
				it.orig = it.dest
				it.dest = (it.dest as Vector2) + (it.v as Vector2) * 18.0
				it.aux = 0.07
				_poeira(it.p, 5, Color(0.7, 0.58, 0.4), 50.0, 0.35)
				pai.combate.audio.tocar("impacto", 1.6, -14.0, 0.05)
		1:
			var k := clampf(age / QUIQUE_T, 0.0, 1.0)
			it.p = (it.orig as Vector2).lerp(it.dest, k)
			if k >= 1.0:
				it.est = 2
				it.age = 0.0
				it.p = it.dest
		2:
			if age >= float(st.get("pavio", 0.5)):
				it.est = 3
				it.age = 0.0
				it.t = 0.3
				it.vida = EXPLOSAO_T + float(st.get("brasa_s", 0.0))
				_explodir_granada(it)
		3:
			if float(st.get("brasa_s", 0.0)) > 0.0 and age > 0.25:  # o chão em brasa queima quem fica em cima
				it.mira = float(it.mira) - dt
				if float(it.mira) <= 0.0:  # e solta brasas e uma fumacinha o tempo todo
					it.mira = 0.12
					_brasas(it.p, 1, float(st.raio) * 0.8, 0.9, 22.0, Color(1.0, 0.45, 0.1))
					if randf() < 0.3:
						_parte(
							PT_FUMACA,
							(it.p as Vector2) + Vector2(randf_range(-0.5, 0.5) * float(st.raio), 0.0),
							2.0,
							Vector2.ZERO,
							randf_range(14.0, 24.0),
							0.7,
							5.0,
							Color(0.3, 0.26, 0.24, 0.5)
						)
				it.t = float(it.t) - dt
				if float(it.t) <= 0.0:
					it.t = 0.5
					var dano := float(st.get("brasa_dps", 0.0)) * 0.5 * float(pai.mundo.heroi.m_dano)
					_dano_granada(it.p, float(st.raio) * 0.8, dano, it.a.cor, 0.0, 0.0)


func _explodir_granada(it: Dictionary) -> void:
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	var p: Vector2 = it.p
	var raio := float(st.raio)
	var cor: Color = a.cor
	_dano_granada(p, raio, _dano(st), cor)
	# estilhaços em anel: itens "projetil" que colidem com a lista da explosão (quem está a até ~150 px dela)
	var cand: Array = it.cand
	cand.clear()
	for m in pai.mundo.monstros:
		if m.vivo and not m.morrendo and pai.na_elipse(m.pos - p, 150.0 + m.raio):
			cand.append(m)
	var n := int(st.get("estilhacos", 0.0))
	var vel := float(st.get("vel_estilhaco", 300.0))
	var giro := randf() * TAU
	ultimo_anel = 0
	for k in n:
		var f := _novo("projetil", a, p + Vector2(0, -4), 0.35)
		if f.is_empty():
			break
		ultimo_anel += 1
		var ang := giro + TAU * float(k) / float(n)
		f.v = Vector2(cos(ang), sin(ang) * 0.8) * vel
		f.pen = 0
		f.mult = float(st.get("frac_estilhaco", 0.4))
		f.lista = cand
		if st.has("fogos"):
			f.est = 1  # estoura de novo onde acabar
			f.t = float(randi() % 3)  # a cor do fogo
	# o clarão, a onda, o estouro, a luz, a casca que voa, a fumaça que sobe, as brasas no chão e o tremor
	pai.fx.folha("cristal", p, raio * 1.1, cor, 0.25)
	pai.fx.onda(p, Color(cor.r, cor.g, cor.b, 0.9), raio, 0.3)
	pai.fx.onda(p, Color(1.0, 0.95, 0.75, 0.6), raio * 0.55, 0.16)
	pai.fx.estouro(p + Vector2(0, -6), cor, 10)
	pai.fx.luz_rapida(p + Vector2(0, -8), cor, 2.2, raio * 3.0, 0.25)
	_lascas(p, 6.0, 9, 150.0, COR_CABACA, Color(0.45, 0.25, 0.08))
	_fumaca_subindo(p, 8, raio, 8.0)
	_brasas(p, 16, raio * 0.9, 1.8, 6.0, Color(1.0, 0.5, 0.12))
	pai.mundo.cam.tremer(3.0, 0.12)
	pai.combate.audio.tocar("runa", randf_range(0.8, 0.95), -2.0, 0.05)


## O dano de área do estouro dos Fogos: como `_dano_area`, mas o número é pequeno, SOMADO por monstro (`_num_somar`) e num lugar só dele
## (`_pos_numero`), senão uma cadeia de estouros empilha dezenas de "13" no mesmo lugar. O dano e a piscada valem sempre.
func _dano_fogo(p: Vector2, raio: float, dano: float, cor: Color) -> void:
	var n := 0
	for m in pai.mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var d: Vector2 = m.pos - p
		if not pai.na_elipse(d, raio + m.raio):
			continue
		var fora := d.normalized() if d.length() > 0.5 else Vector2.from_angle(randf() * TAU)
		pai.combate.ferir(m, dano, fora, 50.0, 0.05, cor, false)
		_num_somar(m, dano, fora, cor.lerp(Color.WHITE, 0.3))
		pai.fx.flash(m, 0.08)
		n += 1
	if n > 0:
		pai._acertou("granada")


## O dano de área da explosão da cabaça (e do chão em brasa, com `empurra` e `atordoa` zerados): como `_dano_area`, mas o número entra na soma por monstro (`_num_somar`), junto com o dos estilhaços e
## o das outras cabaças que caírem em cima, em vez de um "32" por cima do outro.
func _dano_granada(p: Vector2, raio: float, dano: float, cor: Color, empurra := 140.0, atordoa := 0.15) -> void:
	var n := 0
	var cn: Color = _cor_num(cor)
	for m in pai.mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var d: Vector2 = m.pos - p
		if not pai.na_elipse(d, raio + m.raio):
			continue
		var fora := d.normalized() if d.length() > 0.5 else Vector2.RIGHT
		pai.combate.ferir(m, dano, fora, empurra, atordoa, cn, false)
		_num_somar(m, dano, fora, cn)
		pai.fx.flash(m, 0.08)
		n += 1
	if n > 0:
		pai._acertou("granada")


## Soma `dano` no número que o monstro vai mostrar: o primeiro golpe abre uma janela de 0,2 s, o que bater nela soma, e `_num_soltar` mostra
## a soma quando a janela fecha (ou o monstro morre), mesmo que não venha outro golpe.
func _num_somar(m, dano: float, dir: Vector2, cor: Color) -> void:
	var id: int = m.get_instance_id()
	var reg: Array = _num_acum.get(id, [])
	if reg.is_empty():
		reg = [-1.0, 0.0, m, dir, cor, -10.0]
		_num_acum[id] = reg
	if float(reg[0]) < 0.0:
		reg[0] = _relogio
	reg[1] = float(reg[1]) + dano
	reg[3] = dir
	reg[4] = cor


## Mostra a soma de um monstro (se tiver) e fecha a janela.
func _num_mostrar(reg: Array) -> void:
	var m = reg[2]
	if is_instance_valid(m) and float(reg[1]) > 0.0:
		pai.fx.numero(_pos_numero(m, reg[3]), str(maxi(1, roundi(float(reg[1])))), reg[4], false, 14, true)
	reg[0] = -1.0
	reg[1] = 0.0
	reg[5] = _relogio


## Todo quadro: mostra as somas cuja janela fechou (ou cujo monstro morreu) e esquece quem já saiu da rajada.
func _num_soltar() -> void:
	var sair: Array = []
	for id in _num_acum:
		var reg: Array = _num_acum[id]
		var m = reg[2]
		var vivo: bool = is_instance_valid(m) and m.vivo and not m.morrendo
		if float(reg[1]) > 0.0 and (not vivo or _relogio - float(reg[0]) >= 0.2):
			_num_mostrar(reg)
		if float(reg[1]) <= 0.0 and (not vivo or _relogio - float(reg[5]) > 1.0):
			sair.append(id)
	for id in sair:
		_num_acum.erase(id)


## O fim do estilhaço dos Fogos de Festival: um estouro colorido pequeno (raio_fogo) com parte do dano.
func _estourar_fogo(it: Dictionary) -> void:
	it.est = 0  # estoura uma vez só
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	var p: Vector2 = it.p
	var cor: Color = FOGOS_CORES[int(it.t) % 3]
	var raio := float(st.get("raio_fogo", 22.0))
	_dano_fogo(p, raio, _dano(st) * float(st.get("frac_fogo", 0.5)), cor)
	pai._acertou("fogos")  # conta cada estouro dos fogos (com ou sem monstro dentro): é o que o teste v2_cabaca confere
	pai.fx.onda(p, Color(cor.r, cor.g, cor.b, 0.9), raio, 0.18)
	for i in maxi(2, roundi(6.0 * pai.fx.fator_part)):
		var ang := TAU * float(i) / 6.0 + randf() * 0.5
		pai.fx.particula(p + Vector2(0, -4), Vector2(cos(ang), sin(ang) * 0.8) * randf_range(40.0, 90.0), randf_range(0.25, 0.4), 2.0, cor, 90.0, true)
	pai.fx.particula(p + Vector2(0, -4), Vector2.ZERO, 0.12, 18.0, Color(cor.r, cor.g, cor.b, 0.8), 0.0, true)


# ------------------------------------------------------------------ desenho (camada aditiva no_brilho)


func desenhar(ci: CanvasItem, tex: Texture2D) -> void:
	for it in itens:
		if float(it.vida) <= 0.0:
			continue
		var a: Dictionary = it.a
		var st: Dictionary = a.st
		var cor: Color = a.cor
		var p: Vector2 = (it.p as Vector2).round()
		match str(it.k):
			"projetil":
				var dir: Vector2 = (it.v as Vector2).normalized()
				if (it.fa as Dictionary).has("voo"):
					_brilho_projetil_anim(ci, it, tex, cor, p)
				else:
					_desenhar_projetil(ci, it, tex, cor, p, dir)
			"nuvem":
				var fa_n: Dictionary = it.fa
				if fa_n.has("loop"):
					_desenhar_nuvem_anim(ci, it, st, p)
				else:
					var sp: Dictionary = it.sp
					if not sp.is_empty():
						var fade := opacidade_nuvem(float(it.vida), float(st.duracao))
						_area(ci, sp, p, float(it.r), Color(1, 1, 1, 0.035 * fade))
				_desenhar_pulso_nuvem(ci, it, st, p)
			"anel":
				var r := float(it.r)
				var fade_a := clampf(1.0 - r / float(st.raio), 0.0, 1.0)
				var sp: Dictionary = it.sp
				if (it.fa as Dictionary).has("expandir"):
					_desenhar_anel_anim(ci, it, st, p)
					if int(it.fk) == F_PREPARO:
						continue
					fade_a *= 0.5  # a folha mostra a onda; o arco fino fica só como a borda real da hitbox
				elif not sp.is_empty():
					_area(ci, sp, p, r, Color(1, 1, 1, 0.12 * fade_a))
				ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
				ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(cor.r, cor.g, cor.b, 0.85 * fade_a), 3.0)
				ci.draw_arc(Vector2.ZERO, maxf(r - 4.0, 0.5), 0.0, TAU, 48, Color(1, 1, 1, 0.45 * fade_a), 1.5)
				if Anim.suave:  # o eco: uma onda fraca que vem atrás da frente, e o estouro de luz no herói quando a onda sai
					var fr_a := r / maxf(float(st.raio), 1.0)
					if r > 12.0:
						ci.draw_arc(Vector2.ZERO, r * 0.78, 0.0, TAU, 40, Color(cor.r, cor.g, cor.b, 0.3 * fade_a), 2.0)
					if fr_a < 0.3:
						var rb := 10.0 + float(st.raio) * 0.5 * fr_a / 0.3
						ci.draw_texture_rect(tex, Rect2(-Vector2(rb, rb), Vector2(rb, rb) * 2.0), false, Color(cor.r, cor.g, cor.b, 0.4 * (1.0 - fr_a / 0.3)))
				if not (it.fa as Dictionary).has("expandir"):  # com folha o motivo (raios, cristais, rachaduras) já está nos quadros
					_desenhar_motivo_anel(ci, str(a.get("id", "")), r, float(it.fase), fade_a, cor)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"meteoro":
				var raio := float(st.raio)
				if float(it.t) > 0.0:
					var k := 1.0 - float(it.t) / float(st.aviso)
					var pisca := 0.5 + 0.5 * sin(float(it.fase) * 2.0)
					ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
					ci.draw_arc(Vector2.ZERO, raio * (1.0 - 0.4 * k), 0.0, TAU, 32, Color(cor.r, cor.g, cor.b, 0.5 + 0.4 * pisca), 2.0)
					ci.draw_circle(Vector2.ZERO, raio * 0.35 * k, Color(cor.r, cor.g, cor.b, 0.25 * k))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					if (it.fa as Dictionary).has("queda"):  # a folha e o rastro estão na camada normal: aqui a cintilada e o calor da cabeça
						_brilho_queda(ci, it, tex, cor)
					else:
						_desenhar_meteoro(ci, it, tex, cor, (p + Vector2(0, -80.0 * (1.0 - k))).round(), k)
				elif (it.fa as Dictionary).has("impacto"):
					pass  # o impacto e a marca tocam no pool de efeitos (tocar_fx)
				else:
					var sumindo := clampf(float(it.vida) / 0.3, 0.0, 1.0)
					ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
					ci.draw_circle(Vector2.ZERO, raio * (1.2 - 0.4 * sumindo), Color(cor.r, cor.g, cor.b, 0.35 * sumindo))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"aliado":
				if bool(it.g):
					Golem.desenhar_brilho(ci, it, p, tex)
					continue
				if bool(it.an):
					Andante.desenhar_brilho(ci, it, p, tex)
					continue
				var sobe := (p + Vector2(0, -10.0 + sin(float(it.fase)) * 2.0)).round()
				var alfa := clampf(float(it.vida) / 0.5, 0.0, 1.0)
				ci.draw_texture_rect(tex, Rect2(sobe - Vector2(10, 10), Vector2(20, 20)), false, Color(cor.r, cor.g, cor.b, 0.6 * alfa))
				ci.draw_circle(sobe + Vector2(0, 2), 4.5, Color(cor.r, cor.g, cor.b, 0.35 * alfa))
				ci.draw_circle(sobe + Vector2(0, -2), 2.5, Color(1, 1, 1, 0.95 * alfa))
				if str(a.id) == "fantasma_mata":
					ci.draw_circle(sobe + Vector2(-2, -2), 0.8, Color(0.18, 0.2, 0.35, alfa))
					ci.draw_circle(sobe + Vector2(2, -2), 0.8, Color(0.18, 0.2, 0.35, alfa))
			"torre":
				_brilho_torre(ci, it, tex, p)
			"granada":
				_brilho_granada(ci, it, tex, p)
	_brilho_partes(ci, tex)


func desenhar_corpo(ci: CanvasItem, tex: Texture2D) -> void:
	for it in itens:
		if float(it.vida) <= 0.0 or str(it.k) != "nuvem":
			continue
		_desenhar_nuvem(ci, it, it.a.st, it.a.cor, tex, (it.p as Vector2).round())
	if x_ativos > 0:
		_desenhar_fx(ci, false)  # os impactos (camada sem luz: o clarão não escurece no mapa escuro)


## Camada normal (`no_corpo`, a das sombras e dos corvos, que recebe a luz 2D): o sprite de projétil (virado para o voo), de meteoro
## que cai (com a ponta para baixo) e de aliado (de pé, flutuando).
func desenhar_sprites(ci: CanvasItem) -> void:
	if x_ativos > 0:
		_desenhar_fx(ci, true)  # as marcas no chão vêm antes de tudo: ficam por baixo dos projéteis e dos aliados
	for it in itens:
		if float(it.vida) <= 0.0:
			if Golem.tem_restos(it):
				Golem.desenhar_restos(ci, it)
			continue
		var p: Vector2 = (it.p as Vector2).round()
		if bool(it.g):
			Golem.desenhar(ci, it, p)
			_marca_amigo(ci, it, p, Golem.topo(it), 24.0 * Golem.escala(str(it.a.id)))
			continue
		if bool(it.an):
			Andante.desenhar(ci, it, p)
			_marca_amigo(ci, it, p, Andante.topo(it), Andante.raio_marca(it))
			continue
		if str(it.k) == "torre":
			_desenhar_torre(ci, it, p)
			if float(it.vida) > DESMONTA:  # desmontando já não é mais "tempo restante"
				_marca_amigo(ci, it, p, -TORRE_TOPO + 12.0, 14.0, float(it.vida) - DESMONTA)
			continue
		if str(it.k) == "granada":
			_desenhar_granada(ci, it)
			continue
		var fa: Dictionary = it.fa
		if str(it.k) == "projetil" and fa.has("voo"):
			if int(it.fk) == F_ATIVO:  # no preparo o tiro ainda é só a carga na boca (camada de brilho)
				var voo: Dictionary = fa.voo
				var giro := 0.0 if bool(voo.gira) else (it.v as Vector2).angle()
				var qv := Anim.quadro_em_f(voo, _relogio)
				var al_v := clampf(float(it.vida) / 0.12, 0.0, 1.0)  # some no fim do alcance
				if Anim.suave:  # o rastro de movimento: duas cópias fracas e menores, um pouco para trás no voo
					for c in range(2, 0, -1):
						var atras := ((it.p as Vector2) - (it.v as Vector2) * 0.018 * float(c)).round()
						Anim.desenhar(ci, voo, int(qv), atras, giro, Vector2.ONE * (1.0 - 0.1 * float(c)), Color(1, 1, 1, al_v * (0.34 - 0.12 * float(c))))
				Anim.desenhar_suave(ci, voo, qv, p, giro, Vector2.ONE, Color(1, 1, 1, al_v))
			continue
		if str(it.k) == "meteoro" and fa.has("queda"):
			if float(it.t) > 0.0:
				_desenhar_queda(ci, it, p)
			continue
		if str(it.k) == "anel" and int(it.fk) == F_PREPARO:  # a peça que cai no herói antes da onda (o martelo girando)
			var cai: Dictionary = Anim.de(str(it.a.id) + "_queda").get("queda", {})
			if not cai.is_empty():
				var u := 1.0 - clampf(float(it.ft) / maxf(float(it.aux), 0.001), 0.0, 1.0)
				var e := u * u  # acelera até o chão
				ci.draw_set_transform(p, 0.0, Vector2(1.0, ACHATA))
				ci.draw_circle(Vector2.ZERO, 3.0 + 8.0 * e, Color(0, 0, 0, 0.15 + 0.3 * e))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var q := Anim.quadro_em(cai, _relogio)
				for c in range(2, 0, -1):
					var ec := maxf(e - 0.12 * float(c), 0.0)
					Anim.desenhar(
						ci,
						cai,
						(q + int(cai.n) - c) % int(cai.n),
						p + Vector2(8, -116) * (1.0 - ec) + Vector2(0, -10),
						0.0,
						Vector2.ONE,
						Color(1, 1, 1, 0.5 - 0.18 * float(c))
					)
				Anim.desenhar(ci, cai, q, p + Vector2(8, -116) * (1.0 - e) + Vector2(0, -10))
			continue
		var sp: Dictionary = it.sp
		if sp.is_empty():
			continue
		match str(it.k):
			"projetil":
				_sprite(ci, sp, p, (it.v as Vector2).angle())
			"meteoro":
				if float(it.t) > 0.0:
					_sprite(ci, sp, _queda(it), PI * 0.5)
			"aliado":
				var sobe := (p + Vector2(0, -10.0 + sin(float(it.fase)) * 2.0)).round()
				_sprite(ci, sp, sobe, 0.0, Color(1, 1, 1, clampf(float(it.vida) / 0.5, 0.0, 1.0)))
				_marca_amigo(ci, it, p, 30.0, 12.0)
	_desenhar_partes(ci)


## Como se reconhece um aliado temporário: um anel verde no chão (inimigo e perigo são vermelhos, então verde nunca é ameaça) e uma barrinha
## verde sobre a cabeça que esvazia com o tempo que ainda lhe resta. `topo` = px do pé até o alto do corpo, `raio` = raio do anel,
## `resta` = segundos que faltam (padrão: `it.vida`). Pequena de propósito: 18 px de largura, 3 de altura.
func _marca_amigo(ci: CanvasItem, it: Dictionary, p: Vector2, topo: float, raio: float, resta: float = -1.0) -> void:
	var st: Dictionary = it.a.st
	var total := float(st.duracao)
	var falta := float(it.vida) if resta < 0.0 else resta
	var frac := clampf(falta / maxf(total, 0.1), 0.0, 1.0)
	var pisca := 1.0 if (falta > 5.0 or fmod(_relogio, 0.4) < 0.25) else 0.35  # nos últimos 5 s a marca pisca: vai sumir
	ci.draw_set_transform(p, 0.0, Vector2(1.0, 0.62))
	ci.draw_arc(Vector2.ZERO, raio, 0.0, TAU, 20, Color(0.1, 0.35, 0.15, 0.45 * pisca), 2.5)
	ci.draw_arc(Vector2.ZERO, raio, 0.0, TAU, 20, Color(0.45, 1.0, 0.5, 0.7 * pisca), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var o := (p + Vector2(-9.0, -topo - 6.0)).round()
	ci.draw_rect(Rect2(o + Vector2(-1, -1), Vector2(20, 5)), Color(0.04, 0.1, 0.05, 0.85 * pisca))
	ci.draw_rect(Rect2(o, Vector2(18, 3)), Color(0.12, 0.25, 0.14, 0.9 * pisca))
	ci.draw_rect(Rect2(o, Vector2(maxf(1.0, roundf(18.0 * frac)), 3)), Color(0.4, 1.0, 0.45, pisca))


## O sprite centrado em `c`, girado `ang` (o projétil aponta para a direção do voo).
func _sprite(ci: CanvasItem, sp: Dictionary, c: Vector2, ang: float, cor: Color = Color.WHITE) -> void:
	var tam: Vector2 = sp.tam
	ci.draw_set_transform(c, ang, Vector2.ONE)
	ci.draw_texture_rect(sp.tex, Rect2(-(tam * 0.5).floor(), tam), false, cor)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Área com sprite (nuvem e anel): ocupa o diâmetro 2r do golpe; a altura segue a proporção do sprite.
func _area(ci: CanvasItem, sp: Dictionary, c: Vector2, r: float, cor: Color) -> void:
	var tam: Vector2 = sp.tam
	var alt := r * 2.0 * tam.y / tam.x
	ci.draw_texture_rect(sp.tex, Rect2((c - Vector2(r, alt * 0.5)).round(), Vector2(r * 2.0, alt).round()), false, cor)


## A queda do meteoro (docs/combate_v2): no começo do aviso ele só cintila no alto (antecipação, `_queda_e` < 0); depois desce numa
## diagonal inclinada (o lado é sorteado: `it.r` = 1 ou -1), acelerando (devagar no alto, rápido perto do chão), e chega ao chão no instante
## exato do dano (`_cair_meteoro`, aviso zerado).
const QUEDA_ALTO := Vector2(-40.0, -100.0)  # de onde vem, a partir do ponto de queda (o x espelha com o lado)
const QUEDA_CINTILA := 0.25  # fração do aviso em que ele só cintila no alto
const QUEDA_RASTRO := 2  # cópias que ficam para trás e somem
const QUEDA_RASTRO_SUAVE := 5  # com os golpes suaves ligados (Anim.suave)


## O progresso acelerado da descida: 0 no alto, 1 no chão; -1 enquanto ainda cintila.
func _queda_e(it: Dictionary) -> float:
	var k := 1.0 - float(it.t) / maxf(float(it.a.st.aviso), 0.01)
	if k < QUEDA_CINTILA:
		return -1.0
	var u := clampf((k - QUEDA_CINTILA) / (1.0 - QUEDA_CINTILA), 0.0, 1.0)
	return u * u


## De onde o meteoro vem (o ponto no alto, relativo ao ponto de queda).
func _queda_de(it: Dictionary) -> Vector2:
	return QUEDA_ALTO * Vector2(-1.0 if float(it.r) < 0.0 else 1.0, 1.0)


## A posição na descida para o progresso `e` (0 no alto, 1 no chão).
func _queda_em(it: Dictionary, e: float) -> Vector2:
	return ((it.p as Vector2) + _queda_de(it) * (1.0 - clampf(e, 0.0, 1.0))).round()


## Posição do meteoro que cai agora.
func _queda(it: Dictionary) -> Vector2:
	return _queda_em(it, maxf(_queda_e(it), 0.0))


## O meteoro com folha caindo (camada normal): a sombra no chão cresce e escurece enquanto ele chega; na descida, o quadro da folha virado
## para onde ele vai e um rastro de cópias mais fracas e menores, cada vez mais para trás.
func _desenhar_queda(ci: CanvasItem, it: Dictionary, p: Vector2) -> void:
	var e := _queda_e(it)
	var se := maxf(e, 0.0)
	ci.draw_set_transform(p, 0.0, Vector2(1.0, ACHATA))
	ci.draw_circle(Vector2.ZERO, 3.0 + 9.0 * se, Color(0, 0, 0, 0.12 + 0.3 * se))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if e < 0.0:
		return
	var f: Dictionary = it.fa.queda
	var ang := (-_queda_de(it)).angle()
	var qf := Anim.quadro_em_f(f, _relogio + float(it.fase))
	var q := int(qf)
	var n_r := QUEDA_RASTRO_SUAVE if Anim.suave else QUEDA_RASTRO
	var passo := 0.07 * float(QUEDA_RASTRO) / float(n_r)  # mais cópias, mais juntas: o rastro fica corrido em vez de pontilhado
	for c in range(n_r, 0, -1):
		var ec := e - passo * float(c) * (0.35 + e)
		if ec <= 0.0:
			continue
		var t := float(c) / float(n_r)
		var s := 1.0 - 0.24 * t
		Anim.desenhar(ci, f, (q + int(f.n) - c) % int(f.n), _queda_em(it, ec), ang, Vector2(s, s), Color(1, 1, 1, 0.55 - 0.42 * t))
	var estica := 1.0 + 0.18 * e if Anim.suave else 1.0  # estica um pouco no sentido da queda conforme acelera
	Anim.desenhar_suave(ci, f, qf, _queda_em(it, e), ang, Vector2(estica, 1.0 / sqrt(estica)))


## O brilho da queda (camada aditiva): no alto, a cintilada que avisa de onde ele vem; descendo, o calor em volta da cabeça.
func _brilho_queda(ci: CanvasItem, it: Dictionary, tex: Texture2D, cor: Color) -> void:
	var e := _queda_e(it)
	if e < 0.0:
		var k := 1.0 - float(it.t) / maxf(float(it.a.st.aviso), 0.01)
		var c := _queda_em(it, 0.0)
		var cresce := clampf(k / QUEDA_CINTILA, 0.0, 1.0)
		var pisca := 0.6 + 0.4 * sin(_relogio * 30.0 + float(it.fase))
		var br := roundf(2.0 + 5.0 * cresce * pisca)
		ci.draw_line(c - Vector2(br, 0), c + Vector2(br, 0), Color(1, 1, 1, 0.8 * cresce), 1.0)
		ci.draw_line(c - Vector2(0, br), c + Vector2(0, br), Color(1, 1, 1, 0.8 * cresce), 1.0)
		ci.draw_texture_rect(tex, Rect2(c - Vector2(8, 8), Vector2(16, 16)), false, Color(cor.r, cor.g, cor.b, 0.5 * cresce))
		return
	var b := _queda_em(it, e)
	ci.draw_texture_rect(tex, Rect2(b - Vector2(11, 11), Vector2(22, 22)), false, Color(cor.r, cor.g, cor.b, 0.3 + 0.2 * e))


# ------------------------------------------------------------------ desenho da torre e da granada (em código, sem folha de sprite)


## Uma linha com contorno escuro: `cont` true desenha só o contorno (mais grosso), false o miolo. O desenho passa duas vezes pelas peças
## (primeiro todos os contornos, depois todos os miolos) para o contorno nunca comer a peça do lado.
func _lc(ci: CanvasItem, a: Vector2, b: Vector2, larg: float, cor: Color, cont: bool, alfa: float) -> void:
	if cont:
		ci.draw_line(a.round(), b.round(), Color(COR_CONTORNO.r, COR_CONTORNO.g, COR_CONTORNO.b, 0.9 * alfa), larg + 2.0)
	else:
		ci.draw_line(a.round(), b.round(), cor, larg)


## A torre na camada normal (recebe a luz 2D): sombra, tripé de bambu (4 px de perna, com contorno, nós e amarras), plataforma com aljava,
## balestra grande que gira, bandeirola vermelha e lanterna. Cai do alto (0 a 0,25 s), arma (até 0,4 s), pisca no último segundo e
## desmonta (as pernas caem para os lados e ela some). O Pagode do Trovão põe pilares, telhado azul e um orbe por cima.
func _desenhar_torre(ci: CanvasItem, it: Dictionary, p: Vector2) -> void:
	var st: Dictionary = it.a.st
	var pagode := st.has("cadeia")
	var age := float(it.age)
	var util := float(it.vida) - DESMONTA
	var alfa := 1.0
	var queda := 0.0
	var abre := clampf((age - POUSO_T) / (ARMA_T - POUSO_T), 0.0, 1.0)
	var afunda := 0.0
	if age < POUSO_T:
		var k := age / POUSO_T
		queda = 70.0 * (1.0 - k * k)  # acelera até o chão
	if util <= 0.0:
		var d := clampf(1.0 - float(it.vida) / DESMONTA, 0.0, 1.0)
		abre = 1.0 + d * 0.9
		afunda = d * 10.0
		alfa = 1.0 - d
	elif util < 1.0:
		alfa = 0.4 + 0.6 * (0.5 + 0.5 * sin(age * 26.0))
	ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
	var raio_s := maxf(5.0, 17.0 - queda * 0.1)
	ci.draw_circle(Vector2.ZERO, raio_s + 2.0, Color(0, 0, 0, 0.18 * alfa))
	ci.draw_circle(Vector2.ZERO, raio_s, Color(0, 0, 0, 0.32 * alfa))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var b := (p + Vector2(0, -queda + afunda)).round()
	var topo := b + Vector2(0, TORRE_TOPO)
	var claro := Color(COR_BAMBU.r, COR_BAMBU.g, COR_BAMBU.b, alfa)
	var escuro := Color(COR_BAMBU_ESCURO.r, COR_BAMBU_ESCURO.g, COR_BAMBU_ESCURO.b, alfa)
	var corda := Color(0.62, 0.45, 0.25, alfa)
	var contorno := Color(COR_CONTORNO.r, COR_CONTORNO.g, COR_CONTORNO.b, 0.9 * alfa)
	var topo_e := topo + Vector2(-8, 0)
	var topo_d := topo + Vector2(8, 0)
	var pe_e := b + Vector2(-9.0 - 6.0 * abre, 0.0)
	var pe_d := b + Vector2(9.0 + 6.0 * abre, 0.0)
	var pe_t := b + Vector2(3, -5)
	for passo in 2:
		var cont := passo == 0
		_lc(ci, topo, pe_t, 3.0, escuro, cont, alfa)  # a perna de trás
		_lc(ci, topo_e, pe_e, 4.0, claro, cont, alfa)
		_lc(ci, topo_d, pe_d, 4.0, claro, cont, alfa)
		_lc(ci, topo_e.lerp(pe_e, 0.55), topo_d.lerp(pe_d, 0.55), 2.0, escuro, cont, alfa)  # o travessão
		_lc(ci, topo + Vector2(0, -3), topo + Vector2(0, TORRE_PIVO - TORRE_TOPO), 3.0, escuro, cont, alfa)  # o cavalete da balestra
	for f in [0.3, 0.66]:  # os nós do bambu e o brilho no lado da luz
		for lado in 2:
			var q: Vector2 = topo_e.lerp(pe_e, f) if lado == 0 else topo_d.lerp(pe_d, f)
			ci.draw_line((q + Vector2(-3, 0)).round(), (q + Vector2(3, 0)).round(), escuro, 1.0)
	ci.draw_line((topo_e + Vector2(-1, 1)).round(), (pe_e + Vector2(-1, -1)).round(), Color(1.0, 0.95, 0.6, 0.6 * alfa), 1.0)
	ci.draw_line((topo_d + Vector2(-1, 1)).round(), (pe_d + Vector2(-1, -1)).round(), Color(1.0, 0.95, 0.6, 0.6 * alfa), 1.0)
	ci.draw_rect(Rect2(topo + Vector2(-9, -1), Vector2(18, 3)), corda)  # a amarra de corda no topo
	# a plataforma, a aljava (com virotes de reserva) e a lanterna pendurada
	var plano := Rect2(topo + Vector2(-13, -4), Vector2(26, 7))
	ci.draw_rect(plano.grow(1.0), contorno)
	ci.draw_rect(plano, escuro)
	ci.draw_rect(Rect2(plano.position, Vector2(26, 2)), claro)
	var aljava := Rect2(topo + Vector2(-13, -10), Vector2(6, 6))
	ci.draw_rect(aljava.grow(1.0), contorno)
	ci.draw_rect(aljava, Color(0.4, 0.26, 0.12, alfa))
	for k in 3:
		var x := -12.0 + 2.0 * float(k)
		ci.draw_line((topo + Vector2(x, -10)).round(), (topo + Vector2(x, -15 - k % 2)).round(), Color(0.95, 0.9, 0.7, alfa), 1.0)
		ci.draw_rect(Rect2(topo + Vector2(x - 1, -16 - k % 2), Vector2(2, 2)), Color(0.45, 0.95, 0.55, alfa))
	# a balestra: sobe com um estalo depois de armada, recua ao atirar
	var pivo := topo + Vector2(0, TORRE_PIVO - TORRE_TOPO + (1.0 - abre) * 6.0)
	var pop := 1.0
	if age >= ARMA_T:
		pop = 1.0 + 0.2 * maxf(0.0, 1.0 - (age - ARMA_T) * 10.0)
	var ang := float(it.r)
	var aux := float(it.aux)
	pivo -= Vector2.from_angle(ang) * aux * 4.0
	var corda_arco := Color(0.98, 0.94, 0.82, 0.9 * alfa)
	var recuo := 1.0 + aux * 2.5  # a corda estica para trás ao armar e solta no tiro
	ci.draw_set_transform(pivo.round(), ang, Vector2(pop, pop))
	for passo in 2:
		var cont := passo == 0
		_lc(ci, Vector2(-9, 0), Vector2(12, 0), 3.0, escuro, cont, alfa)  # a coronha e o trilho
		_lc(ci, Vector2(6, -11), Vector2(8, -4), 3.0, claro, cont, alfa)  # o arco (a prod) em curva, de cima a baixo
		_lc(ci, Vector2(8, -4), Vector2(8, 4), 3.0, claro, cont, alfa)
		_lc(ci, Vector2(8, 4), Vector2(6, 11), 3.0, claro, cont, alfa)
	ci.draw_line(Vector2(6, -11), Vector2(1.0 - recuo, 0), corda_arco, 1.0)
	ci.draw_line(Vector2(1.0 - recuo, 0), Vector2(6, 11), corda_arco, 1.0)
	ci.draw_line(Vector2(-7, 0), Vector2(11, 0), Color(0.7, 0.5, 0.25, alfa), 1.0)  # o fio de luz no trilho
	if aux < 0.4:  # o virote armado, com a ponta de ferro
		ci.draw_line(Vector2(1.0 - recuo, 0), Vector2(13, 0), Color(0.98, 0.94, 0.78, alfa), 2.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(12, -2.5), Vector2(12, 2.5)]), Color(0.9, 0.9, 0.95, alfa))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if pagode:  # a segunda camada do pagode: dois pilares, telhado azul de beiral levantado e o orbe
		var base_t := topo + Vector2(0, -4)
		var beiral := topo + Vector2(0, -19)
		var tel := PackedVector2Array(
			[beiral + Vector2(-18, 3), beiral + Vector2(-14, 0), beiral + Vector2(14, 0), beiral + Vector2(18, 3), beiral + Vector2(0, -13)]
		)
		for passo in 2:
			var cont := passo == 0
			_lc(ci, base_t + Vector2(-12, 0), beiral + Vector2(-12, 0), 3.0, escuro, cont, alfa)
			_lc(ci, base_t + Vector2(12, 0), beiral + Vector2(12, 0), 3.0, escuro, cont, alfa)
		ci.draw_colored_polygon(tel, contorno)
		var tel_i := PackedVector2Array(
			[beiral + Vector2(-15, 1), beiral + Vector2(-12, 0), beiral + Vector2(12, 0), beiral + Vector2(15, 1), beiral + Vector2(0, -11)]
		)
		ci.draw_colored_polygon(tel_i, Color(0.2, 0.34, 0.62, alfa))
		ci.draw_line((beiral + Vector2(-15, 1)).round(), (beiral + Vector2(0, -11)).round(), Color(0.55, 0.8, 1.0, alfa), 1.0)
		ci.draw_line((beiral + Vector2(-13, 0)).round(), (beiral + Vector2(13, 0)).round(), Color(0.7, 0.88, 1.0, alfa), 1.0)
		ci.draw_circle(beiral + Vector2(0, -16), 3.5, Color(0.4, 0.7, 1.0, alfa))
		ci.draw_circle(beiral + Vector2(0, -16), 1.6, Color(1, 1, 1, alfa))
	else:  # a bandeirola vermelha numa haste e a lanterna de papel pendurada na plataforma
		var haste := topo + Vector2(11, -3)
		var ponta := haste + Vector2(0, -21)
		var onda := sin(age * 6.0) * 2.0
		for passo in 2:
			_lc(ci, haste, ponta, 2.0, escuro, passo == 0, alfa)
		var flag := PackedVector2Array([ponta, ponta + Vector2(-13 + onda * 0.5, 2.0 + onda), ponta + Vector2(0, 7)])
		ci.draw_colored_polygon(flag, contorno)
		var flag_i := PackedVector2Array([ponta + Vector2(-1, 1), ponta + Vector2(-11 + onda * 0.5, 2.0 + onda), ponta + Vector2(-1, 5)])
		ci.draw_colored_polygon(flag_i, Color(0.45, 0.95, 0.55, alfa))
		var lan := topo + Vector2(14, 9)
		ci.draw_line((topo + Vector2(14, 3)).round(), lan.round(), contorno, 1.0)
		ci.draw_circle(lan + Vector2(0, 3), 4.6, contorno)
		ci.draw_circle(lan + Vector2(0, 3), 3.5, Color(1.0, 0.5, 0.2, alfa))
		ci.draw_circle(lan + Vector2(0, 3), 1.7, Color(1.0, 0.92, 0.55, alfa))


## O brilho da torre (camada aditiva): a luz da lanterna (ou do orbe do pagode) que pulsa e ergue o bambu da escuridão, o clarão da boca ao
## atirar (estrela de 4 pontas) e, no pagode, fios elétricos que passeiam entre o orbe e as pontas do beiral.
func _brilho_torre(ci: CanvasItem, it: Dictionary, tex: Texture2D, p: Vector2) -> void:
	if int(it.est) == 0:
		return
	var st: Dictionary = it.a.st
	var pagode := st.has("cadeia")
	var age := float(it.age)
	var util := float(it.vida) - DESMONTA
	var fade := 1.0
	if util <= 0.0:
		fade = clampf(float(it.vida) / DESMONTA, 0.0, 1.0)
	elif util < 1.0:
		fade = 0.4 + 0.6 * (0.5 + 0.5 * sin(age * 26.0))
	var topo := p + Vector2(0, TORRE_TOPO)
	var pulso := 0.5 + 0.5 * sin(age * 5.0)
	var tom := Color(0.5, 0.75, 1.0) if pagode else Color(1.0, 0.62, 0.28)
	ci.draw_texture_rect(tex, Rect2(topo + Vector2(-30, -26), Vector2(60, 60)), false, Color(tom.r, tom.g, tom.b, (0.1 + 0.05 * pulso) * fade))
	if pagode:
		var o := (topo + Vector2(0, -35)).round()
		ci.draw_texture_rect(tex, Rect2(o - Vector2(18, 18), Vector2(36, 36)), false, Color(0.5, 0.75, 1.0, (0.4 + 0.25 * pulso) * fade))
		var a0 := age * 11.0
		for k in 2:  # dois fios elétricos curtos do orbe até as pontas do beiral
			var ponta := (topo + Vector2(-17.0 + 34.0 * float(k), -16)).round()
			var meio := o.lerp(ponta, 0.5) + Vector2(sin(a0 + float(k) * 3.0) * 4.0, cos(a0 * 1.3 + float(k)) * 3.0)
			if sin(a0 * 1.7 + float(k) * 2.0) > -0.2:
				ci.draw_polyline(PackedVector2Array([o, meio.round(), ponta]), Color(0.65, 0.85, 1.0, 0.75 * fade), 1.0)
	else:
		var l := (topo + Vector2(14, 12)).round()
		ci.draw_texture_rect(tex, Rect2(l - Vector2(12, 12), Vector2(24, 24)), false, Color(1.0, 0.6, 0.25, (0.4 + 0.2 * pulso) * fade))
	var aux := float(it.aux)
	if aux > 0.0:
		var dir := Vector2.from_angle(float(it.r))
		var boca := (p + Vector2(0, TORRE_PIVO) + dir * (TORRE_BOCA - aux * 4.0)).round()
		var cor_b := Color(0.6, 0.85, 1.0) if pagode else Color(1.0, 0.82, 0.4)
		var t := 16.0 + 22.0 * aux
		ci.draw_texture_rect(tex, Rect2(boca - Vector2(t, t) * 0.5, Vector2(t, t)), false, Color(cor_b.r, cor_b.g, cor_b.b, 0.9 * aux * fade))
		var lado := dir.orthogonal()
		ci.draw_line(boca - dir * 3.0, (boca + dir * (6.0 + 16.0 * aux)).round(), Color(1, 0.97, 0.85, aux * fade), 2.0)
		ci.draw_line((boca - lado * 8.0 * aux).round(), (boca + lado * 8.0 * aux).round(), Color(1, 0.95, 0.8, 0.8 * aux * fade), 1.0)


## O corpo da cabaça (camada normal): a sombra no chão (mais escura, e o arco dela marcado em pontinhos), a cabaça girando com contorno e luz
## (achata no quique) e o branco que pisca no fim do pavio, cada vez mais rápido.
func _desenhar_granada(ci: CanvasItem, it: Dictionary) -> void:
	var est := int(it.est)
	if est >= 3 or float(it.age) < 0.0:
		return
	var st: Dictionary = it.a.st
	var p: Vector2 = (it.p as Vector2).round()
	var z := _altura_granada(it)
	var alta := clampf(z / 60.0, 0.0, 1.0)
	ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
	if est == 0:  # o arco projetado no chão: pontinhos de sombra que ficam para trás e apagam
		var k := clampf(float(it.age) / float(st.get("voo", 0.55)), 0.0, 1.0)
		for j in range(1, 6):
			var kj := k - 0.075 * float(j)
			if kj < 0.0:
				break
			var q: Vector2 = (it.orig as Vector2).lerp(it.dest, kj) - p
			ci.draw_circle(Vector2(q.x, q.y / ACHATA), 3.6 - 0.3 * float(j), Color(0, 0, 0, 0.65 * (1.0 - float(j) / 6.0)))
	ci.draw_circle(Vector2.ZERO, 11.0 - 2.0 * alta, Color(0, 0, 0, 0.3))
	ci.draw_circle(Vector2.ZERO, 8.0 - 1.5 * alta, Color(0, 0, 0, 0.75))
	var c := (p + Vector2(0, -z - 6.0)).round()
	var achata := Vector2(1.5, 0.85) if float(it.aux) > 0.0 else Vector2(1.2, 1.2)
	ci.draw_set_transform(c, float(it.r), achata)
	var contorno := Color(COR_CONTORNO.r, COR_CONTORNO.g, COR_CONTORNO.b, 0.95)
	ci.draw_line(Vector2(0, -7.5), Vector2(3, -11), contorno, 3.0)  # o pavio (contorno)
	ci.draw_circle(Vector2(0, 2.0), 6.6, contorno)
	ci.draw_circle(Vector2(0, -4.2), 4.8, contorno)
	ci.draw_circle(Vector2(0, 2.0), 5.6, COR_CABACA)
	ci.draw_circle(Vector2(0, -4.2), 3.8, COR_CABACA.darkened(0.08))
	ci.draw_circle(Vector2(1.8, 3.4), 3.0, COR_CABACA.darkened(0.35))  # o lado sem luz
	ci.draw_circle(Vector2(-1.9, 0.8), 1.9, COR_CABACA.lightened(0.5))  # o brilho
	ci.draw_line(Vector2(-4.2, -1.0), Vector2(4.2, -1.0), Color(0.3, 0.16, 0.06), 1.5)  # a corda do gargalo
	ci.draw_rect(Rect2(Vector2(-0.8, -1.8), Vector2(1.6, 1.6)), Color(1.0, 0.86, 0.42))  # o nó dourado
	ci.draw_line(Vector2(0, -7.5), Vector2(3, -11), Color(0.92, 0.85, 0.62), 1.2)  # o pavio
	if est == 2:
		var f := clampf(float(it.age) / float(st.get("pavio", 0.5)), 0.0, 1.0)
		if fposmod(float(it.age) * (6.0 + 18.0 * f), 1.0) < 0.5:
			ci.draw_circle(Vector2(0, 0), 6.2, Color(1, 1, 1, 0.7))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## O brilho da cabaça (camada aditiva): a faísca do pavio, a mira onde ela vai cair, o círculo de aviso que cresce até o raio, o clarão da
## explosão (disco, anel e raios) e as brasas do nível 5.
func _brilho_granada(ci: CanvasItem, it: Dictionary, tex: Texture2D, p: Vector2) -> void:
	var age := float(it.age)
	if age < 0.0:
		return
	var est := int(it.est)
	var st: Dictionary = it.a.st
	var cor: Color = it.a.cor
	var raio := float(st.raio)
	if est == 0:  # a mira no chão: disco e anel no ponto de queda, com um anel que fecha sobre ele e quatro riscas; esquenta enquanto a cabaça desce
		var k := clampf(age / float(st.get("voo", 0.55)), 0.0, 1.0)
		var alvo: Vector2 = (it.dest as Vector2).round()
		var pulso := 0.8 + 0.2 * sin(float(it.fase) * 2.0)
		ci.draw_set_transform(alvo, 0.0, Vector2(1, ACHATA))
		ci.draw_circle(Vector2.ZERO, raio * 0.6, Color(1.0, 0.4, 0.1, (0.1 + 0.12 * k) * pulso))
		ci.draw_arc(Vector2.ZERO, raio * 0.6, 0.0, TAU, 32, Color(1.0, 0.55, 0.18, (0.4 + 0.45 * k) * pulso), 2.0)
		ci.draw_arc(Vector2.ZERO, raio * (1.0 - 0.4 * k), 0.0, TAU, 32, Color(1.0, 0.8, 0.4, 0.5 * (1.0 - k) + 0.1), 1.0)
		for n in 4:
			var d := Vector2.from_angle(TAU * float(n) / 4.0 + 0.785)
			ci.draw_line(d * raio * 0.5, d * raio * 0.72, Color(1.0, 0.75, 0.35, 0.55 + 0.35 * k), 2.0)
		ci.draw_circle(Vector2.ZERO, 2.5 + 2.0 * k, Color(1.0, 0.7, 0.3, 0.35 + 0.3 * k))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if est <= 1:  # a luz da cabaça no chão, sob ela: a sombra preta quase some no chão escuro, mas a mancha quente em volta mostra onde ela passa
		var alta := clampf(_altura_granada(it) / 60.0, 0.0, 1.0)
		var tam := 30.0 - 8.0 * alta
		ci.draw_texture_rect(tex, Rect2(p + Vector2(-tam, -tam * ACHATA), Vector2(tam, tam * ACHATA) * 2.0), false, Color(1.0, 0.5, 0.15, 0.42 - 0.18 * alta))
	if est <= 2:
		var ponta := _ponta_pavio(it).round()
		ci.draw_texture_rect(tex, Rect2(ponta - Vector2(7, 7), Vector2(14, 14)), false, Color(1.0, 0.8, 0.3, 0.7 + 0.3 * sin(float(it.fase) * 3.0)))
		ci.draw_circle(ponta, 1.6, Color(1, 1, 0.9, 0.95))
		var c := p + Vector2(0, -_altura_granada(it) - 6.0)
		ci.draw_texture_rect(tex, Rect2(c - Vector2(11, 11), Vector2(22, 22)), false, Color(1.0, 0.55, 0.15, 0.16))  # o calor em volta da cabaça
	if est == 2:
		var f := clampf(age / float(st.get("pavio", 0.5)), 0.0, 1.0)
		ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
		ci.draw_arc(Vector2.ZERO, raio, 0.0, TAU, 40, Color(1.0, 0.5, 0.15, 0.25 + 0.35 * f), 1.5)
		ci.draw_circle(Vector2.ZERO, raio * f, Color(1.0, 0.45, 0.1, 0.08 + 0.1 * f))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if est == 3:
		var k := clampf(age / EXPLOSAO_T, 0.0, 1.0)
		var fade := 1.0 - k
		var rr := raio * (0.35 + 0.75 * (1.0 - pow(1.0 - k, 3.0)))
		ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
		ci.draw_circle(Vector2.ZERO, rr, Color(1.0, 0.55, 0.15, 0.45 * fade * fade * fade))
		ci.draw_circle(Vector2.ZERO, rr * 0.55, Color(1.0, 0.9, 0.55, 0.65 * fade * fade))
		ci.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(1.0, 0.85, 0.5, 0.9 * fade), 2.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var alto := rr * 1.5  # a bola de fogo que sobe do chão
		ci.draw_texture_rect(tex, Rect2(p + Vector2(-rr * 0.8, -alto * 0.9), Vector2(rr * 1.6, alto)), false, Color(1.0, 0.6, 0.2, 0.5 * fade))
		if age < 0.2:  # os raios do estouro: 8 riscos que saem do centro nos primeiros quadros
			var f2 := 1.0 - age / 0.2
			var centro := p + Vector2(0, -6)
			for n in 8:
				var d := Vector2.from_angle(TAU * float(n) / 8.0 + float(it.fase)) * Vector2(1.0, 0.8)
				ci.draw_line((centro + d * raio * 0.25).round(), (centro + d * raio * (0.55 + 0.6 * (1.0 - f2))).round(), Color(1.0, 0.9, 0.55, 0.8 * f2), 2.0)
		if age < 0.05:
			ci.draw_circle(p + Vector2(0, -6), raio * 0.8, Color(1, 1, 1, 0.35))
	if est == 3 and float(st.get("brasa_s", 0.0)) > 0.0:
		_brasas_chao(ci, it, p, cor)


## O chão em brasa do nível 5: um brilho vermelho no chão e brasas subindo (a mesma `_desenhar_brasa` das cinzas vulcânicas).
func _brasas_chao(ci: CanvasItem, it: Dictionary, p: Vector2, cor: Color) -> void:
	var age := float(it.age)
	var fade := clampf(float(it.vida) / 0.4, 0.0, 1.0) * clampf((age - 0.1) / 0.3, 0.0, 1.0)
	if fade <= 0.0:
		return
	var raio := float(it.a.st.raio) * 0.8
	ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
	ci.draw_circle(Vector2.ZERO, raio, Color(1.0, 0.7, 0.25, 0.12 * fade))
	ci.draw_arc(Vector2.ZERO, raio, 0.0, TAU, 32, Color(1.0, 0.45, 0.1, 0.3 * fade), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for n in 3:
		_desenhar_brasa(ci, p + Vector2((float(n) - 1.0) * raio * 0.5, sin(float(n) * 2.0) * raio * 0.2), float(it.fase) + float(n), fade, cor)


# ------------------------------------------------------------------ auxiliares


## O brilho (camada aditiva) do tiro com folha. PREPARO: a carga na boca, um anel da cor da arma que fecha enquanto o miolo acende (o jogador
## vê de onde o tiro vai sair antes de ele sair). ATIVO: só um halo fraco; o corpo e o rastro estão nos quadros da folha.
func _brilho_projetil_anim(ci: CanvasItem, it: Dictionary, tex: Texture2D, cor: Color, p: Vector2) -> void:
	if int(it.fk) == F_PREPARO:
		var k := 1.0 - clampf(float(it.ft) / maxf(float(it.age), 0.001), 0.0, 1.0)
		var boca := (p + (it.dest as Vector2) * 6.0).round()
		ci.draw_arc(boca, roundf(9.0 - 6.0 * k), 0.0, TAU, 12, Color(cor.r, cor.g, cor.b, 0.35 + 0.5 * k), 1.0)
		ci.draw_circle(boca, 1.0 + 2.0 * k, Color(1, 1, 1, 0.4 + 0.5 * k))
		ci.draw_texture_rect(tex, Rect2(boca - Vector2(7, 7), Vector2(14, 14)), false, Color(cor.r, cor.g, cor.b, 0.5 * k))
		return
	ci.draw_texture_rect(tex, Rect2(p - Vector2(6, 6), Vector2(12, 12)), false, Color(cor.r, cor.g, cor.b, 0.3))


## A frente de cada quadro de `expandir` em fração da borda da célula (docs/combate_v2/SPEC_ARTE.md; as folhas dos anéis seguem esta
## linha do tempo): o quadro mostrado é o último cuja frente o raio real do golpe já alcançou, então a onda desenhada anda junto da hitbox.
const FRENTE_ANEL := [0.16, 0.47, 0.69, 0.84, 0.94, 1.0]


## O anel com folha (camada aditiva), esticado até o raio final do golpe. PREPARO: o 1º quadro pulsa crescendo no herói (junta força).
func _desenhar_anel_anim(ci: CanvasItem, it: Dictionary, st: Dictionary, p: Vector2) -> void:
	var f: Dictionary = it.fa.expandir
	var q: Vector2 = f.quadro
	var raio := float(st.raio)
	var esc := raio * 2.0 / q.x
	if int(it.fk) == F_PREPARO:
		var k := 1.0 - clampf(float(it.ft) / maxf(float(it.aux), 0.001), 0.0, 1.0)
		var ke := 1.0 - (1.0 - k) * (1.0 - k)  # ease-out: junta força rápido e assenta
		Anim.desenhar(ci, f, 0, p, 0.0, Vector2.ONE * esc * (0.6 + 0.4 * ke), Color(1, 1, 1, 0.5 + 0.5 * ke))
		return
	var fr := float(it.r) / maxf(raio, 1.0)
	var i := 0
	while i + 1 < FRENTE_ANEL.size() and fr >= float(FRENTE_ANEL[i + 1]):
		i += 1
	var u := 0.0  # quanto a frente já andou até a do próximo quadro (o meio-quadro de desenhar_suave)
	if i + 1 < FRENTE_ANEL.size():
		u = clampf((fr - float(FRENTE_ANEL[i])) / (float(FRENTE_ANEL[i + 1]) - float(FRENTE_ANEL[i])), 0.0, 1.0)
	var some := 1.0 - smoothstep(0.82, 1.0, fr)  # apaga nos últimos 18% em vez de sumir de uma vez
	Anim.desenhar_suave(ci, f, minf(float(i) + u, float(f.n) - 1.0), p, 0.0, Vector2(esc, esc), Color(1, 1, 1, some), true)


## A nuvem com folha (camada aditiva), esticada até o raio real: entrada (se forma, sem dano), loop (os tiques) e saída (dissolve).
func _desenhar_nuvem_anim(ci: CanvasItem, it: Dictionary, st: Dictionary, p: Vector2) -> void:
	var fa: Dictionary = it.fa
	var q: Vector2 = fa.loop.quadro
	var esc := float(it.r) * 2.0 / q.x
	var prep := float(it.aux)
	var passou := float(st.duracao) + prep - float(it.vida)
	var cor := Color(1, 1, 1, 0.45)  # rala: a nuvem não pode esconder os monstros dentro dela
	if passou < prep and fa.has("entrada"):
		Anim.desenhar_suave(ci, fa.entrada, Anim.quadro_frac_f(fa.entrada, passou / maxf(prep, 0.001)), p, 0.0, Vector2(esc, esc), cor, true)
		return
	if fa.has("saida"):
		var sai := Anim.duracao(fa.saida)
		if float(it.vida) < sai:
			Anim.desenhar_suave(ci, fa.saida, Anim.quadro_frac_f(fa.saida, 1.0 - float(it.vida) / sai), p, 0.0, Vector2(esc, esc), cor, true)
			return
	Anim.desenhar_suave(ci, fa.loop, Anim.quadro_em_f(fa.loop, passou - prep), p, 0.0, Vector2(esc, esc), cor, true)


func _desenhar_projetil(ci: CanvasItem, it: Dictionary, tex: Texture2D, cor: Color, p: Vector2, dir: Vector2) -> void:
	var id := str(it.a.get("id", ""))
	match id:
		"bola_fogo":
			ci.draw_line((p - dir * 13.0).round(), p, Color(1.0, 0.7, 0.25, 0.55), 5.0)
			ci.draw_circle(p, 7.0, Color(1.0, 0.7, 0.25, 0.45))
			ci.draw_circle(p, 3.4, Color(1.0, 0.88, 0.35, 0.95))
			ci.draw_texture_rect(tex, Rect2(p - Vector2(7, 7), Vector2(14, 14)), false, Color(1.0, 0.52, 0.12, 0.42))
		"dardos_peconhentos":
			var cauda := (p - dir * 8.0).round()
			ci.draw_line(cauda, p, Color(0.25, 0.75, 0.14, 0.82), 3.0)
			ci.draw_circle(cauda, 2.0, Color(0.7, 1.0, 0.25, 0.72))
			ci.draw_line((p - dir * 4.0).round(), p + dir * 3.0, Color(0.88, 1.0, 0.6, 0.95), 1.5)
		"lanca_geada":
			ci.draw_line((p - dir * 12.0).round(), p + dir * 5.0, Color(0.48, 0.85, 1.0, 0.88), 3.0)
			var lado := dir.orthogonal() * 3.0
			ci.draw_line((p - lado).round(), (p + lado).round(), Color(0.9, 1.0, 1.0, 0.9), 1.5)
			ci.draw_circle(p, 3.0, Color(0.9, 1.0, 1.0, 0.78))
		"sentinela_bambu":  # virote: haste clara com ponta quente e um rastro âmbar
			ci.draw_line((p - dir * 15.0).round(), (p - dir * 6.0).round(), Color(1.0, 0.65, 0.2, 0.4), 3.0)
			ci.draw_line((p - dir * 11.0).round(), (p + dir * 2.0).round(), Color(0.95, 0.82, 0.55, 0.85), 1.5)
			ci.draw_line((p - dir * 1.0).round(), (p + dir * 4.0).round(), Color(1.0, 0.95, 0.75, 0.95), 2.0)
		"pagode_do_trovao":  # virote elétrico: núcleo branco, halo azul e uma cauda torta
			var lado_t := dir.orthogonal() * sin(float(it.fase) * 9.0) * 2.0
			ci.draw_line((p - dir * 16.0 + lado_t).round(), (p - dir * 7.0 - lado_t).round(), Color(0.45, 0.7, 1.0, 0.55), 3.0)
			ci.draw_line((p - dir * 7.0 - lado_t).round(), p, Color(0.8, 0.93, 1.0, 0.85), 1.5)
			ci.draw_circle(p, 3.0, Color(0.55, 0.8, 1.0, 0.5))
			ci.draw_circle(p, 1.4, Color(1, 1, 1, 0.95))
		"cabaca_polvora", "fogos_de_festival":  # estilhaço da granada: cauda quente que encolhe, e colorida nos fogos
			var quente := Color(1.0, 0.55, 0.15)
			if id == "fogos_de_festival":
				quente = FOGOS_CORES[int(it.t) % 3]
			var fim := clampf(float(it.vida) / 0.35, 0.0, 1.0)
			ci.draw_line((p - dir * (4.0 + 9.0 * fim)).round(), p, Color(quente.r, quente.g, quente.b, 0.6 * fim + 0.25), 3.0)
			ci.draw_line((p - dir * 4.0).round(), p, Color(1, 0.95, 0.8, 0.9), 1.5)
			ci.draw_circle(p, 1.6, Color(1, 1, 0.9, 0.9))
		"estrelas_sombra", "flechas_sombrias":
			var giro := float(it.fase) * (7.0 if id == "estrelas_sombra" else 1.5)
			for ponta in 4:
				var raio := Vector2.from_angle(giro + TAU * float(ponta) / 4.0) * (7.0 if ponta % 2 == 0 else 3.0)
				ci.draw_line((p - dir * 5.0).round(), (p + raio).round(), Color(0.76, 0.58, 1.0, 0.8), 1.5)
			ci.draw_circle(p, 2.0, Color(0.14, 0.1, 0.22, 0.95))
		_:
			ci.draw_line((p - dir * 9.0).round(), p, Color(cor.r, cor.g, cor.b, 0.45), 4.0)
			ci.draw_line((p - dir * 6.0).round(), p, Color(1, 1, 1, 0.9), 1.5)
			ci.draw_texture_rect(tex, Rect2(p - Vector2(7, 7), Vector2(14, 14)), false, Color(cor.r, cor.g, cor.b, 0.5))


func _desenhar_motivo_anel(ci: CanvasItem, id: String, r: float, fase: float, alfa: float, cor: Color) -> void:
	match id:
		"martelo_trovao":
			for n in 4:
				var ang := fase * 0.25 + TAU * float(n) / 4.0
				var fora := Vector2.from_angle(ang) * r
				var dentro := Vector2.from_angle(ang + 0.12) * (r - 9.0)
				ci.draw_line(fora, dentro, Color(0.95, 1.0, 1.0, 0.9 * alfa), 2.0)
		"anel_gelado":
			for n in 4:
				var ang := fase * 0.18 + TAU * float(n) / 4.0
				var ponta := Vector2.from_angle(ang) * r
				var base := Vector2.from_angle(ang) * (r - 7.0)
				var lado := Vector2.from_angle(ang + PI * 0.5) * 3.0
				ci.draw_line(base - lado, ponta, Color(0.92, 1.0, 1.0, 0.88 * alfa), 1.5)
				ci.draw_line(base + lado, ponta, Color(0.92, 1.0, 1.0, 0.88 * alfa), 1.5)
		"terremoto":
			for n in 3:
				var ang := float(n) * 2.1 + 0.2
				var base := Vector2.from_angle(ang) * (r - 13.0)
				var ponta := Vector2.from_angle(ang + 0.16) * (r + 2.0)
				ci.draw_line(base, ponta, Color(0.82, 0.75, 0.62, 0.7 * alfa), 1.5)


func _desenhar_meteoro(ci: CanvasItem, it: Dictionary, tex: Texture2D, cor: Color, p: Vector2, k: float) -> void:
	var id := str(it.a.get("id", ""))
	var fade := clampf(float(it.vida) / 0.3, 0.0, 1.0)
	match id:
		"meteoro_flamejante", "fogo_do_ceu", "pedras_vulcanicas":
			ci.draw_line(p + Vector2(-4, -14), p + Vector2(3, 9), Color(1.0, 0.7, 0.25, 0.72 * (0.4 + k)), 4.0)
			ci.draw_line(p + Vector2(3, -11), p + Vector2(-1, 7), Color(1.0, 0.77, 0.2, 0.86 * (0.4 + k)), 1.5)
		"cometa_gelado":
			ci.draw_line(p + Vector2(-9, -13), p + Vector2(3, 8), Color(0.44, 0.77, 1.0, 0.68 * (0.4 + k)), 4.0)
			ci.draw_line(p + Vector2(-2, -7), p + Vector2(2, 8), Color(1.0, 1.0, 1.0, 0.9 * fade), 1.5)
		_:
			ci.draw_line(p + Vector2(-7, -9), p + Vector2(5, 7), Color(cor.r, cor.g, cor.b, 0.6 * (0.4 + k)), 3.0)
	ci.draw_texture_rect(tex, Rect2(p - Vector2(9, 9), Vector2(18, 18)), false, Color(cor.r, cor.g, cor.b, 0.48 * fade))
	ci.draw_circle(p, 3.5, Color(1, 1, 1, 0.88 * fade))


func _novo(k: String, a: Dictionary, p: Vector2, vida: float) -> Dictionary:
	var it := {}
	for x in itens:  # um slot livre e limpo; se não houver, o que ainda guarda o entulho de um golem (que some na hora)
		if float(x.vida) <= 0.0:
			if not Golem.tem_restos(x):
				it = x
				break
			if it.is_empty():
				it = x
	if it.is_empty():
		return it
	it.k = k
	it.a = a
	it.sp = sprite_de(str(a.id))
	it.fa = Anim.de(str(a.id))
	it.fk = F_ATIVO
	it.ft = 0.0
	it.p = p
	it.v = Vector2.ZERO
	it.vida = vida
	it.t = 0.0
	it.r = 0.0
	it.fase = randf() * TAU
	it.pen = 0
	(it.hit as Array).clear()
	it.pulso = 0.0
	it.orig = Vector2.ZERO
	it.dest = Vector2.ZERO
	it.age = 0.0
	it.est = 0
	it.mult = 1.0
	it.mira = 0.0
	it.aux = 0.0
	(it.cand as Array).clear()
	it.lista = null
	Golem.zerar(it)
	Andante.zerar(it)
	return it


## Fumaça translúcida em camadas usa uma textura irregular criada uma vez; sem partículas nem nós por golpe.
func _desenhar_nuvem(ci: CanvasItem, it: Dictionary, st: Dictionary, cor: Color, tex: Texture2D, p: Vector2) -> void:
	var vida := float(it.vida)
	var duracao := float(st.duracao)
	var fade := opacidade_nuvem(vida, duracao)
	var fase := float(it.fase)
	var r := float(it.r)
	var id := str(it.a.get("id", ""))
	# O sprite opcional de arma entra como base discreta; os volumes e motivos continuam ativos com ou sem ele.
	var sprite = it.get("sp")
	if sprite != null and not sprite.is_empty():
		var tam: Vector2 = sprite.tam
		var altura := r * 2.0 * tam.y / tam.x
		ci.draw_texture_rect(
			sprite.tex, Rect2((p - Vector2(r, altura * 0.5)).round(), Vector2(r * 2.0, altura).round()), false, Color(cor.r, cor.g, cor.b, 0.18 * fade)
		)
	var respirar := 0.96 + 0.04 * sin(fase * 0.8)
	# Só um brilho oval suave marca o alcance; o corpo principal fica suspenso como fumaça.
	ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
	ci.draw_texture_rect(tex, Rect2(-r * respirar, -r * 0.72, r * 2.0 * respirar, r * 1.44), false, Color(cor.r, cor.g, cor.b, 0.10 * fade))
	ci.draw_arc(Vector2.ZERO, r * respirar, 0.1, TAU - 0.1, 40, Color(cor.r, cor.g, cor.b, 0.09 * fade), 1.1)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match motivo_nuvem(id):
		"espectros":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.72, 0.9, 1.0), 6, 32.0, 1.16, 0.62)
			_desenhar_espiritos(ci, p, fase, fade, true, cor)
		"sono":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.72, 0.54, 1.0), 6, 30.0, 1.20, 0.62)
			_desenhar_sonolenta(ci, p, fase, fade)
		"sangue":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.55, 0.95, 0.62), 5, 38.0, 0.92, 0.58, 0.96)
			_desenhar_sangue(ci, p, fase, fade, cor)
		"bolhas":
			if id == "nuvem_espora":
				_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.7, 0.5, 0.24), 5, 22.0, 0.92, 0.50)
				_desenhar_esporos(ci, p, fase, fade)
			elif id == "chuva_acida":
				_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.72, 0.75, 0.2), 5, 27.0, 1.08, 0.56)
				_desenhar_chuva_acida(ci, p, fase, fade)
			else:
				_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.72, 0.91, 0.42), 9, 46.0, 1.65, 0.9, 0.68)
				_desenhar_bolhas(ci, p, fase, fade, cor)
		"cristais":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.53, 0.82, 1.0), 6, 28.0, 1.12, 0.62)
			_desenhar_cristais(ci, p, fase, fade, cor)
			if id == "nevasca":
				_desenhar_neve(ci, p, fase, fade)
		"brasas":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.37, 0.4, 0.44), 7, 32.0, 1.35, 0.72)
			_desenhar_brasa(ci, p, fase, fade, cor)
		_:
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, cor, 5, 24.0, 0.76, 0.28)


func _desenhar_pulso_nuvem(ci: CanvasItem, it: Dictionary, st: Dictionary, p: Vector2) -> void:
	var pulso := clampf(float(it.pulso), 0.0, 1.0)
	if pulso <= 0.0:
		return
	var fade := opacidade_nuvem(float(it.vida), float(st.duracao))
	var r := float(it.r)
	var raio_pulso := r * (0.55 + (1.0 - pulso) * 0.28)
	ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
	ci.draw_arc(Vector2.ZERO, raio_pulso, 0.0, TAU, 32, Color(1.0, 0.98, 0.9, 0.62 * pulso * fade), 1.5 + pulso)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func motivo_nuvem(id: String) -> String:
	match id:
		"nevoa_espectral":
			return "espectros"
		"fumaca_sonolenta":
			return "sono"
		"cortina_sangue":
			return "sangue"
		"nuvem_veneno", "chuva_acida", "nuvem_espora":
			return "bolhas"
		"nevoeiro_gelado", "nevasca":
			return "cristais"
		"cinzas_vulcanicas":
			return "brasas"
	return "fumaca"


static func opacidade_nuvem(vida: float, duracao: float) -> float:
	var entrada := clampf((duracao - vida) / 0.32, 0.0, 1.0)
	var saida := clampf(vida / 0.65, 0.0, 1.0)
	return entrada * saida


func _desenhar_espiritos(ci: CanvasItem, p: Vector2, fase: float, fade: float, espectral: bool, cor: Color) -> void:
	# Três espectros desencontrados deixam o centro legível e criam altura sobre o chão.
	for n in 3:
		var ang := fase * 0.55 + TAU * float(n) / 3.0
		var centro := (p + Vector2(cos(ang) * 15.0, -17.0 - sin(fase * 1.3 + n * 1.8) * 4.0 + sin(ang) * 5.0)).round()
		var escala := 0.72 if n != 1 else 1.0
		var a := (0.48 if espectral else 0.29) * fade
		ci.draw_circle(centro + Vector2(0, 5), 7.0 * escala, Color(cor.r * 0.55, cor.g * 0.72, cor.b, a * 0.4))
		ci.draw_circle(centro + Vector2(0, -1), 6.0 * escala, Color(cor.r, cor.g, cor.b, a))
		ci.draw_arc(centro + Vector2(0, -1), 6.0 * escala, PI, TAU, 12, Color(1, 1, 1, a * 0.7), 1.0)
		ci.draw_circle(centro + Vector2(-2, -1), 0.9 * escala, Color(0.22, 0.35, 0.48, a))
		ci.draw_circle(centro + Vector2(2, -1), 0.9 * escala, Color(0.22, 0.35, 0.48, a))
		ci.draw_line(centro + Vector2(-2, 3), centro + Vector2(2, 3), Color(1, 1, 1, a * 0.55), 1.0)
		ci.draw_line(centro + Vector2(-3, 7), centro + Vector2(-5, 10), Color(cor.r, cor.g, cor.b, a * 0.55), 1.0)
		ci.draw_line(centro + Vector2(3, 7), centro + Vector2(5, 10), Color(cor.r, cor.g, cor.b, a * 0.55), 1.0)


func _desenhar_bolhas(ci: CanvasItem, p: Vector2, fase: float, fade: float, cor: Color) -> void:
	for n in 4:
		var q := (p + Vector2(sin(fase * 0.7 + n * 2.1) * (15.0 + n * 2.0), -8.0 - fposmod(fase * 4.0 + n * 7.0, 35.0))).round()
		var raio := 1.8 + float(n % 2) * 0.8
		ci.draw_circle(q, raio + 1.0, Color(cor.r, cor.g, cor.b, 0.2 * fade))
		ci.draw_arc(q, raio, 0.0, TAU, 8, Color(0.9, 1.0, 0.72, 0.68 * fade), 1.0)


func _desenhar_volume_nuvem(
	ci: CanvasItem,
	tex: Texture2D,
	p: Vector2,
	r: float,
	fase: float,
	fade: float,
	cor: Color,
	quantidade: int,
	altura: float,
	largura: float,
	alfa: float,
	aspecto: float = 0.64
) -> void:
	for n in quantidade:
		var u := float(n) / float(maxi(1, quantidade - 1))
		var oscilacao := sin(fase * (0.52 + float(n % 3) * 0.08) + float(n) * 1.9)
		var x := (u - 0.5) * r * 1.16 + oscilacao * r * 0.09
		var faixa := float(n % 3)
		var y := -6.0 - faixa * (altura / 3.0) - oscilacao * 3.5
		var escala := 0.78 + faixa * 0.1 + 0.05 * sin(fase * 0.7 + float(n))
		var w := r * largura * escala * (0.86 + 0.14 * sin(float(n) * 2.37))
		var h := maxf(12.0, w * aspecto * (0.86 + 0.16 * cos(float(n) * 1.73)))
		var centro := (p + Vector2(x, y)).round()
		var camada := Color(cor.r, cor.g, cor.b, alfa * fade * (0.86 + 0.14 * sin(fase + float(n))))
		var area := Rect2(centro - Vector2(w, h) * 0.5, Vector2(w, h))
		# Sombra fria nas dobras dá volume e separa o vapor do piso iluminado.
		ci.draw_texture_rect(
			_textura_fumaca(), Rect2(area.position + Vector2(2.0, 4.0), area.size), false, Color(cor.r * 0.20, cor.g * 0.28, cor.b * 0.20, alfa * fade * 0.52)
		)
		ci.draw_texture_rect(_textura_fumaca(), area, false, camada)


static func _textura_fumaca() -> Texture2D:
	if _tex_fumaca != null:
		return _tex_fumaca
	var imagem := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 64:
			var nx := (float(x) + 0.5) / 32.0 - 1.0
			var ny := (float(y) + 0.5) / 20.0 - 1.0
			var dist := sqrt(nx * nx * 0.72 + ny * ny * 1.55)
			var borda := 0.72 + 0.12 * sin(float(x) * 0.31 + float(y) * 0.17) + 0.08 * sin(float(x) * 0.13 - float(y) * 0.39)
			var alfa := (1.0 - smoothstep(0.28, borda, dist)) * (0.72 + 0.28 * sin(float(x) * 0.21 + float(y) * 0.27))
			imagem.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alfa, 0.0, 1.0)))
	_tex_fumaca = ImageTexture.create_from_image(imagem)
	return _tex_fumaca


func _desenhar_sonolenta(ci: CanvasItem, p: Vector2, fase: float, fade: float) -> void:
	for n in 2:
		var x := roundf(cos(fase * 0.35 + float(n) * PI) * 15.0 + float(n) * 4.0)
		var y := roundf(-15.0 - fposmod(fase * 2.2 + float(n) * 12.0, 23.0))
		var origem := p + Vector2(x, y)
		var al := 0.62 * fade
		ci.draw_line(origem, origem + Vector2(4, 0), Color(0.93, 0.84, 1.0, al), 1.4)
		ci.draw_line(origem + Vector2(4, 0), origem + Vector2(1, 3), Color(0.93, 0.84, 1.0, al), 1.4)
		ci.draw_line(origem + Vector2(1, 3), origem + Vector2(5, 3), Color(0.93, 0.84, 1.0, al), 1.4)


func _desenhar_esporos(ci: CanvasItem, p: Vector2, fase: float, fade: float) -> void:
	for n in 6:
		var ang := fase * 0.2 + TAU * float(n) / 6.0
		var q := (p + Vector2(cos(ang) * (10.0 + float(n % 3) * 7.0), -8.0 + sin(ang * 1.5) * 12.0)).round()
		ci.draw_circle(q, 1.5, Color(0.95, 0.78, 0.35, 0.62 * fade))
		ci.draw_line(q, q + Vector2(0.0, 3.0), Color(0.92, 0.66, 0.24, 0.42 * fade), 1.0)


func _desenhar_chuva_acida(ci: CanvasItem, p: Vector2, fase: float, fade: float) -> void:
	for n in 5:
		var x := sin(float(n) * 3.1 + fase * 0.18) * 29.0
		var y := -34.0 + fposmod(fase * 18.0 + float(n) * 13.0, 34.0)
		var q := (p + Vector2(x, y)).round()
		ci.draw_line(q + Vector2(-1, -4), q + Vector2(1, 3), Color(0.85, 0.95, 0.3, 0.75 * fade), 2.0)
		ci.draw_circle(q + Vector2(1, 3), 1.6, Color(0.94, 1.0, 0.42, 0.6 * fade))


func _desenhar_neve(ci: CanvasItem, p: Vector2, fase: float, fade: float) -> void:
	for n in 5:
		var x := cos(fase * 0.12 + float(n) * 1.8) * (9.0 + float(n) * 4.0)
		var y := -25.0 + fposmod(fase * 3.4 + float(n) * 9.0, 27.0)
		var q := (p + Vector2(x, y)).round()
		ci.draw_line(q + Vector2(-2, 0), q + Vector2(2, 0), Color(1, 1, 1, 0.65 * fade), 1.0)
		ci.draw_line(q + Vector2(0, -2), q + Vector2(0, 2), Color(1, 1, 1, 0.65 * fade), 1.0)


func _desenhar_cristais(ci: CanvasItem, p: Vector2, fase: float, fade: float, cor: Color) -> void:
	for n in 4:
		var ang := fase * 0.25 + TAU * float(n) / 4.0
		var q := (p + Vector2(cos(ang) * 23.0, -8.0 + sin(ang) * 11.0)).round()
		var eixo := Vector2.from_angle(ang + PI * 0.25) * 3.5
		var transversal := eixo.rotated(PI * 0.5) * 0.7
		ci.draw_line(q - eixo, q + eixo, Color(cor.r, cor.g, cor.b, 0.82 * fade), 1.5)
		ci.draw_line(q - transversal, q + transversal, Color(1.0, 1.0, 1.0, 0.7 * fade), 1.0)


func _desenhar_brasa(ci: CanvasItem, p: Vector2, fase: float, fade: float, cor: Color) -> void:
	for n in 5:
		var q := (p + Vector2(cos(fase * 0.4 + n * 1.7) * (8.0 + n * 3.0), -3.0 - fposmod(fase * 5.0 + n * 4.0, 19.0))).round()
		var quente := Color(1.0, 0.4 + 0.07 * float(n), 0.12, fade * (0.55 + 0.25 * sin(fase + n)))
		ci.draw_circle(q, 1.6, quente)
		ci.draw_line(q, q + Vector2(1, -3), Color(1.0, 0.65, 0.25, quente.a * 0.45), 1.0)


func _desenhar_sangue(ci: CanvasItem, p: Vector2, fase: float, fade: float, cor: Color) -> void:
	for n in 4:
		var ang := fase * 0.32 + TAU * float(n) / 4.0
		var q := (p + Vector2(cos(ang) * (7.0 + n * 3.0), -8.0 - sin(fase + n) * 4.0)).round()
		var gota := Vector2(1.2, 3.4)
		ci.draw_line(q - gota, q + gota, Color(cor.r, cor.g * 0.5, cor.b * 0.5, 0.65 * fade), 2.0)
		ci.draw_circle(q - gota, 1.3, Color(cor.r, cor.g * 0.45, cor.b * 0.45, 0.62 * fade))


## Dano do golpe com o multiplicador de dano do herói (o mesmo que os corvos usam).
func _dano(st: Dictionary) -> float:
	return float(st.dano) * float(pai.mundo.heroi.m_dano)


func _cor_num(c: Color) -> Color:
	return c.lerp(Color.WHITE, 0.45)


## Vetor no plano achatado (y dividido por ACHATA), para medir distância como o resto da v2 faz.
static func _eli(d: Vector2) -> Vector2:
	return Vector2(d.x, d.y / ACHATA)


## O monstro mais perto de `p` dentro de `alc` px (no plano achatado), ignorando os que estão morrendo.
func _mais_perto(p: Vector2, alc: float, perto: Array):
	var melhor = null
	var md := alc * alc
	for m in perto:
		if not m.vivo or m.morrendo:
			continue
		var d2 := _eli(m.pos - p).length_squared()
		if d2 < md:
			md = d2
			melhor = m
	return melhor


## Como `_mais_perto`, mas pulando quem já está em `fora` (os que o tiro já acertou: o ricochete não volta no mesmo).
func _mais_perto_sem(p: Vector2, alc: float, perto: Array, fora: Array):
	var melhor = null
	var md := alc * alc
	for m in perto:
		if not m.vivo or m.morrendo or fora.has(m):
			continue
		var d2 := _eli(m.pos - p).length_squared()
		if d2 < md:
			md = d2
			melhor = m
	return melhor
