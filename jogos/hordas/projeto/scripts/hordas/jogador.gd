extends Node2D
const Perf := preload("res://scripts/hordas/perf.gd")
## O herói: anda em 8 direções, dá dash (invencível por um instante) e leva dano.
## Usa a mesma folha de andar dos personagens da Cairu (andando_8.png: 9 colunas x 4 direções, 44x60).

const Visual := preload("res://scripts/hordas/visual.gd")
const Direcao := preload("res://scripts/hordas/direcao.gd")
const Paleta := preload("res://scripts/hordas/paleta.gd")
const LINHA := Direcao.LINHA   # tabela de linhas da folha (8 direções; folhas de 4 usam só as 4 primeiras)
const LARG_QUADRO := 44            # largura de um quadro na folha; hframes = largura da textura / isto
const COLS_ANIM := 23              # folhas com 23+ colunas têm os estados extras abaixo (Hazaki); com menos, só parado/andar
## Tabela de ações da folha de 23 colunas: coluna inicial, nº de quadros, quadros por segundo, se repete.
const ANIM := {
	"parado": {"col": 9, "n": 3, "fps": 4.0, "repete": true},
	"ataque": {"col": 12, "n": 3, "fps": 12.0, "repete": false},    # 3 quadros em 0,25 s
	"defesa": {"col": 15, "n": 2, "fps": 10.0, "repete": false},    # durante o dash
	"dano": {"col": 17, "n": 2, "fps": 10.0, "repete": false},
	"morte": {"col": 19, "n": 4, "fps": 8.0, "repete": false},      # fica no último quadro
}
const ATAQUE_TEMPO := 0.25
const ATAQUE_INTERVALO := 0.6
## Golpe do corpo (todos os heróis, com ou sem quadros de ataque): recua, avança na direção do golpe e volta.
## Não são quadros novos: é o sprite inteiro se mexendo (posição, escala e inclinação), igual pra qualquer folha.
const GOLPE_TEMPO := 0.2
const GOLPE_INTERVALO := 0.28      # heróis sem quadros de ataque: no máximo um golpe do corpo a cada isto
const GOLPE_AVANCO := 8.0          # px que o corpo avança
const GOLPE_RECUO := 2.0           # px que recua na antecipação
const GOLPE_INCLINA := 0.2         # rad de inclinação pra frente no auge
const DANO_TEMPO := 0.2
const VEL_BASE := 100.0
const DASH_VEL := 3.4
const DASH_TEMPO := 0.18
## ---- Sensação de movimento e de impacto (#32 item 4): tudo se ajusta aqui ----
const ACEL_TEMPO := 0.06           # s do parado até a velocidade máxima (arranque curto, sem escorregar)
const FREIO_TEMPO := 0.07          # s da velocidade máxima até parar (precisa ficar abaixo de 0,1)
const SQUASH_INICIO := Vector2(-0.06, 0.08)   # ao começar a andar: estica um pouco
const SQUASH_PARADA := Vector2(0.07, -0.07)   # ao parar: achata um pouco
const SQUASH_POUSO := Vector2(0.20, -0.22)    # pouso da entrada na fase
const SQUASH_VOLTA := 16.0         # velocidade com que a forma volta ao normal
const PASSO_DIST := 26.0           # px andados entre um passo e outro (poeira e som)
const PASSO_SOM := true            # som baixinho de passo
const PASSO_SOM_DB := -24.0
const POEIRA_MAX := 14             # teto de partículas de poeira vivas (desenhadas no _draw)
const POEIRA_VIDA := 0.38
const DANO_FLASH := 0.09           # s de flash branco ao levar dano (opção "Flash de dano")
const DANO_EMPURRAO := 110.0       # empurrãozinho quando o golpe não diz pra onde (decai com exp(-9 t): ~12 px)
const HITSTOP_CRIT := 0.04         # s reais de congelada ao acertar crítico (só solo)
const HITSTOP_CRIT_ESPERA := 1.2   # s mínimos entre dois hitstops de crítico
const HITSTOP_GOLPE := 0.025       # s reais ao acertar um golpe corpo a corpo (arena.golpe_pesado limita a frequência)
const HITSTOP_CHEFE := 0.14        # s reais ao derrubar um chefe (só solo)
const HITSTOP_ESCALA := 0.04       # velocidade do jogo durante o hitstop (1 = sem efeito)
const SHADER_FLASH := "shader_type canvas_item;\nuniform float flash = 1.0;\nvoid fragment() { COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash * COLOR.a); }\n"
static var _mat_flash: ShaderMaterial

var arena: Node
var spr := Sprite2D.new()
var tom := Color.WHITE        # cor base do corpo (herói criado, #72: a raça tinge; os fixos ficam brancos)
var paleta := {}               # aparência por paleta do herói criado (#72, marco 2): {pele, cabelo, roupa} em índices; vazio = cores originais
var hp := 100.0
var invencivel := 0.0
var dash_t := 0.0
var folego := 2.0               # cargas de rolamento (#68): gasta 1 por rolamento e volta com o tempo (dados/movimento.json)
var _rolando := 0.0             # quanto falta do rolamento em curso (o corpo gira; 0 = não está rolando)
var _rola_lado := 1.0           # pra que lado o corpo gira
var _recupera := 0.0            # depois de rolar: um instante andando devagar (o compromisso da esquiva)
var _vel_dash := DASH_VEL       # vezes a velocidade de andar no dash em curso (rolamento, investida do dragão, onda do Lucas)
const CENTRO_CORPO := Vector2(0, -29)   # o meio do corpo em relação ao pé (a origem do sprite): o giro é em volta dele
var lado := 1.0                 # 1 = olhando pra direita, -1 = esquerda (o chicote usa)
var _mov := Vector2.ZERO
var _dir_dash := Vector2.RIGHT
var _t := 0.0
var _dir := "baixo"
var _olhar := Direcao.new()     # ângulo de olhar que gira suave (8 direções)
var _rastro: Array = []          # imagens fantasmas do dash
var _vermelho := 0.0
var bot := false                 # modo demonstração (anda sozinho)
var _bot_ang := 0.0
var kb := Vector2.ZERO
var _ia := {}
var _pref := 120.0
var camadas := {}                # nome -> Sprite2D (personagem em camadas; veja definir_camadas)
var _sprite := ""
var forma: Node2D = null         # corpo da forma transformada (dragão, habilidades.gd); null = humano
var _est := "parado"             # estado de animação atual (só muda o quadro em folhas de 23+ colunas)
var _est_t := 0.0                # tempo dentro do estado
var _atk_t := 0.0
var _atk_cool := 0.0
var _golpe_t := 0.0
var _golpe_dir := Vector2.RIGHT
var _golpe_vira := false        # o golpe trouxe direção: o herói se vira pra ela
var _dano_t := 0.0
var humano := 1.0                # 0..1: quanto do corpo humano aparece (some na transformação, volta no fim)
var _ent_t := 0.0                # chegada no começo da fase: tempo que falta da queda (0 = acabou)
var _nome_t := 0.0               # tempo que falta do nome em cima da cabeça
var _ent_nome := ""
var _ent_poeira := false
var _vel := Vector2.ZERO          # velocidade real (acelera e freia; _mov continua sendo a intenção, o que as armas e o online leem)
var _sq := Vector2.ZERO           # squash/stretch atual (soma a ONE na escala do sprite)
var _andava := false
var _passo_dist := 0.0
var _poeira: Array = []           # {pos (mundo), t, r}
var _flash_t := 0.0


func configurar(sprite: String) -> void:
	_sprite = sprite
	spr.texture = Dados.tex_personagem(sprite, "andando_8")
	spr.hframes = _colunas()
	spr.vframes = Direcao.linhas_da_altura(spr.texture.get_height() if spr.texture else 0)
	spr.centered = false
	spr.offset = Vector2(-22, -58)
	add_child(spr)


## Personagem em camadas: desenha por cima do corpo as camadas pedidas (equipamentos e armas na mão),
## na ordem da lista. Cada camada é filha do sprite do corpo: herda rotação, piscar e cor; só o quadro
## da animação é copiado (em _animar). Arquivos em assets/personagens/<sprite>/camadas/.
func definir_camadas(nomes: Array) -> void:
	# em camadas, o corpo é o corpo.png (sem cabelo); o andando_8.png completo fica pra quem não usa camadas
	var corpo := Paleta.textura(_sprite, "corpo", paleta)
	if corpo and spr.texture != corpo:
		spr.texture = corpo
		spr.hframes = _colunas()
		spr.vframes = Direcao.linhas_da_altura(corpo.get_height())
	for n in camadas.keys():
		if not n in nomes:
			camadas[n].queue_free()
			camadas.erase(n)
	for n in nomes:
		if not camadas.has(n):
			var tex := Paleta.textura(_sprite, "camadas/" + str(n), paleta) if n == "cabelo" else Dados.tex_personagem(_sprite, "camadas/" + str(n))
			if tex == null:
				continue
			var c := Sprite2D.new()
			c.texture = tex
			c.hframes = _colunas(tex)
			c.vframes = spr.vframes
			c.centered = false
			c.use_parent_material = true   # o flash de dano (shader no corpo) vale pras camadas também
			c.offset = spr.offset
			c.frame = spr.frame
			spr.add_child(c)
			camadas[n] = c
	for i in nomes.size():
		if camadas.has(nomes[i]):
			spr.move_child(camadas[nomes[i]], -1)   # a ordem da lista é a ordem de desenho


## Colunas da folha (largura da textura / largura do quadro). Com 9 colunas tudo é como antes.
func _colunas(tex: Texture2D = null) -> int:
	if tex == null:
		tex = spr.texture
	return maxi(1, int(tex.get_width()) / LARG_QUADRO) if tex else 9


func _tem_anim() -> bool:
	return spr.hframes >= COLS_ANIM


## Função pura: quadro da folha para um estado, direção e tempo (andando usa o tempo global; os outros, o tempo no estado).
## Folha sem os estados extras (hframes < 23): parado = coluna 0 e qualquer ação cai em parado.
static func quadro_de(estado: String, dir: String, t: float, hframes: int) -> int:
	var base: int = LINHA[dir] * hframes
	if estado == "andando":
		return base + 1 + int(t * 12.0) % 8
	if hframes < COLS_ANIM or not ANIM.has(estado):
		return base
	var a: Dictionary = ANIM[estado]
	var i := int(maxf(t, 0.0) * float(a.fps))
	i = i % int(a.n) if a.repete else mini(i, int(a.n) - 1)
	return base + int(a.col) + i


## Chamado pelas armas corpo a corpo (armas.gd golpe_corpo) a cada golpe; toca o ataque se já passou o intervalo.
## `dir` = para onde o golpe vai (o herói se vira e avança pra lá).
func atacou(dir := Vector2.ZERO) -> void:
	if forma != null or _atk_cool > 0.0 or hp <= 0.0:
		return
	_golpe_vira = dir.length_squared() > 0.0001
	_golpe_dir = dir.normalized() if _golpe_vira else Vector2(lado, 0)
	_golpe_t = GOLPE_TEMPO
	if _tem_anim():
		_atk_t = ATAQUE_TEMPO
		_atk_cool = ATAQUE_INTERVALO
	else:
		_atk_cool = GOLPE_INTERVALO


## Pose do golpe do corpo em u (0..1): [deslocamento ao longo da direção em px, estica (>0) ou achata, inclinação 0..1].
## Antecipação (recua e encolhe) até 0,2, avanço esticado até 0,4, e volta suave até 1.
static func pose_golpe(u: float) -> Vector3:
	if u < 0.2:
		var k := u / 0.2
		return Vector3(-GOLPE_RECUO * k, -0.08 * k, -0.3 * k)
	if u < 0.4:
		var k := (u - 0.2) / 0.2
		return Vector3(lerpf(-GOLPE_RECUO, GOLPE_AVANCO, k), lerpf(-0.08, 0.14, k), lerpf(-0.3, 1.0, k))
	var k := 1.0 - pow(1.0 - (u - 0.4) / 0.6, 2.0)
	return Vector3(lerpf(GOLPE_AVANCO, 0.0, k), lerpf(0.14, 0.0, k), lerpf(1.0, 0.0, k))


## Começo da fase: o herói cai do alto (~0,6 s) com poeira e um flash, e o nome fica em cima por um instante.
func entrar(nome: String) -> void:
	_ent_t = Visual.CHEGADA_TEMPO
	_nome_t = 2.0
	_ent_nome = nome
	_ent_poeira = false
	Som.tocar("whoosh", 0.0, 1.3, -8)


func _chegando() -> void:
	var p := 1.0 - _ent_t / Visual.CHEGADA_TEMPO
	if _ent_t > 0.0:   # só durante a queda: depois dela isto roda até o nome sumir e zerava o giro do rolamento (#68)
		spr.position.y = -Visual.chegada_altura(p)
	elif _rolando <= 0.0 and spr.position.y != 0.0:
		spr.position.y = 0.0   # pousou: o corpo fica no chão
	if not _ent_poeira and p >= Visual.CHEGADA_POUSO:
		_ent_poeira = true
		Som.tocar("queda", 0.0, 1.2, -8)
		_sq = SQUASH_POUSO
		if arena and arena.efeitos:
			arena.efeitos.explodir(position + Vector2(0, -2), Color(0.82, 0.78, 0.68), 10, 95.0)
	queue_redraw()


func _process(dt: float) -> void:
	if _ent_t > 0.0 or _nome_t > 0.0:
		_ent_t = maxf(0.0, _ent_t - dt)
		_nome_t -= dt
		_chegando()
	# morto: a arena para de chamar atualizar(); a animação de morte anda aqui
	if hp <= 0.0 and _tem_anim() and forma == null:
		_est_t = _est_t + dt if _est == "morte" else 0.0
		_est = "morte"
		spr.frame = quadro_de("morte", _dir, _est_t, spr.hframes)
		for c in camadas.values():
			c.frame = spr.frame


func centro() -> Vector2:
	return position + Vector2(0, -22)


func direcao_mov() -> Vector2:
	return _mov


func vida_max() -> float:
	return arena.stat("vida_max")


func atualizar(dt: float) -> void:
	var _pp := Perf.ini()
	atualizar_i(dt)
	Perf.fim("jog_a", _pp)


func atualizar_i(dt: float) -> void:
	_t += dt
	_dt = dt
	invencivel = maxf(0.0, invencivel - dt)
	folego = minf(_folego_cfg("cargas", 2.0), folego + dt / maxf(0.1, _folego_cfg("recarga", 1.6)))
	_recupera = maxf(0.0, _recupera - dt)
	_vermelho = maxf(0.0, _vermelho - dt)
	_atk_t = maxf(0.0, _atk_t - dt)
	_atk_cool = maxf(0.0, _atk_cool - dt)
	_golpe_t = maxf(0.0, _golpe_t - dt)
	_dano_t = maxf(0.0, _dano_t - dt)
	var entrada := _entrada()
	_mov = entrada
	if entrada.x != 0:
		lado = signf(entrada.x)
	var vmax: float = VEL_BASE * arena.stat("velocidade")
	if _recupera > 0.0:
		vmax *= float(Dados.json("movimento").get("rolamento", {}).get("lento", 0.45))
	if dash_t > 0:
		dash_t -= dt
		position += _dir_dash * vmax * _vel_dash * dt
		_vel = entrada * vmax   # ao sair do dash já anda na velocidade pedida, sem solavanco
		if _rolando > 0.0:
			_rolando = maxf(0.0, dash_t)
			if _rolando <= 0.0:   # acabou de rolar: um instante mais lento antes de poder correr de novo
				_recupera = float(Dados.json("movimento").get("rolamento", {}).get("recuperacao", 0.14))
		elif int(_t * 60) % 2 == 0:
			_rastro.append({"pos": position, "frame": spr.frame, "t": 0.25})
	else:
		_vel_dash = DASH_VEL   # a onda do Lucas (especial) liga o dash_t de fora e usa a velocidade padrão
		_vel = passo_vel(_vel, entrada * vmax, vmax, dt)
		position += _vel * dt
		if _quer_dash():
			rolar(entrada if entrada != Vector2.ZERO else Vector2(lado, 0))
	position += kb * dt
	kb *= exp(-9.0 * dt)
	_efeitos_movimento(entrada, dt)
	# regeneração
	hp = minf(vida_max(), hp + arena.stat("regen") * dt)
	_animar(entrada)
	for r in _rastro.duplicate():
		r.t -= dt
		if r.t <= 0:
			_rastro.erase(r)
	queue_redraw()


## Função pura: um passo da velocidade em direção ao alvo (acelera em ACEL_TEMPO, freia em FREIO_TEMPO, sem escorregar).
static func passo_vel(vel: Vector2, alvo: Vector2, vmax: float, dt: float) -> Vector2:
	var tempo := ACEL_TEMPO if alvo != Vector2.ZERO else FREIO_TEMPO
	return vel.move_toward(alvo, maxf(vmax, 1.0) / tempo * dt)


## Só visual: squash/stretch, passos (poeira e som baixinho) e o flash de dano.
func _efeitos_movimento(entrada: Vector2, dt: float) -> void:
	_flash_t = maxf(0.0, _flash_t - dt)
	var anda := entrada != Vector2.ZERO
	if anda and not _andava:
		_sq = SQUASH_INICIO
		_poeira_em(1, 10.0)
	elif not anda and _andava and _vel.length() > 20.0:
		_sq = SQUASH_PARADA
	_andava = anda
	_sq = _sq.lerp(Vector2.ZERO, 1.0 - exp(-SQUASH_VOLTA * dt))
	if _sq.length_squared() < 0.00001:
		_sq = Vector2.ZERO
	spr.scale = Vector2.ONE + _sq
	if dash_t <= 0.0 and forma == null and _ent_t <= 0.0 and _vel.length_squared() > 400.0:
		_passo_dist += _vel.length() * dt
		if _passo_dist >= PASSO_DIST:
			_passo_dist -= PASSO_DIST
			_poeira_em(1, 6.0)
			if PASSO_SOM:
				Som.tocar("blip", 0.12, randf_range(0.5, 0.62), PASSO_SOM_DB)
	for i in range(_poeira.size() - 1, -1, -1):
		_poeira[i].t -= dt
		if _poeira[i].t <= 0.0:
			_poeira.remove_at(i)
	var flash := _flash_t > 0.0
	if flash != (spr.material != null):
		spr.material = _material_flash() if flash else null


static func _material_flash() -> ShaderMaterial:
	if _mat_flash == null:
		var sh := Shader.new()
		sh.code = SHADER_FLASH
		_mat_flash = ShaderMaterial.new()
		_mat_flash.shader = sh
	return _mat_flash


## n nuvenzinhas de poeira nos pés, espalhadas em `abre` px (teto POEIRA_MAX, sem poeira durante a queda da entrada).
func _poeira_em(n: int, abre: float) -> void:
	if _ent_t > 0.0 or forma != null:
		return
	for i in n:
		if _poeira.size() >= POEIRA_MAX:
			_poeira.pop_front()
		_poeira.append({"pos": position + Vector2(randf_range(-abre, abre) * 0.5, -1.0 + randf_range(-1.0, 1.0)), "t": POEIRA_VIDA, "r": randf_range(1.6, 2.6)})


## Empurrão pequeno pra longe do vírus mais perto, quando o golpe não diz de onde veio.
func _empurrao_padrao() -> Vector2:
	var c := centro()
	var melhor := INF
	var dir := Vector2.ZERO
	for v in arena.inimigos.no_circulo(c, 40.0):
		var d: float = v.pos.distance_squared_to(c)
		if d < melhor:
			melhor = d
			dir = c - v.pos
	return dir.normalized() * DANO_EMPURRAO if dir != Vector2.ZERO else Vector2.ZERO


var _dash_ia := false
var _dt := 0.016


## Online: com cartas ou pausa abertas o jogo não para, mas as setas são do menu.
func _no_menu() -> bool:
	return arena.eh_online and (arena.cartas.aberto() or arena.hud._pausado)


var entrada_forcada := Vector2.ZERO   # só para prints/testes (--andar=x,y): anda nessa direção como se fosse o teclado


func _entrada() -> Vector2:
	if _no_menu():
		return Vector2.ZERO
	if entrada_forcada != Vector2.ZERO:
		return entrada_forcada.normalized()
	if bot and arena.duelo_ativo:
		return _bot_duelo()
	if bot:
		return _bot_dir()
	return Input.get_vector("esquerda", "direita", "cima", "baixo")


## Rolamento de esquiva (#68): gasta 1 de fôlego, rola na direção dada (invencível o tempo todo) e o corpo dá uma volta.
## Transformado em dragão, vira a investida dele (vai mais longe, sem rolar). Devolve false se não tem fôlego.
func rolar(dir: Vector2) -> bool:
	if folego < 1.0 or dash_t > 0:
		return false
	folego -= 1.0
	_dir_dash = dir.normalized() if dir != Vector2.ZERO else Vector2(lado, 0)
	if forma:
		dash_t = DASH_TEMPO + 0.12
		_vel_dash = DASH_VEL
	else:
		var r: Dictionary = Dados.json("movimento").get("rolamento", {})
		dash_t = float(r.get("tempo", 0.3))
		_vel_dash = float(r.get("velocidade", 2.7))
		_rolando = dash_t
		_rola_lado = signf(_dir_dash.x) if absf(_dir_dash.x) > 0.01 else lado
	invencivel = maxf(invencivel, dash_t + (0.1 if forma else 0.0))
	Som.tocar("whoosh", 0.1, 1.2)
	_poeira_em(3, 18.0)
	if arena and arena.get("armas") != null and not forma:   # #63: "Aura Pulsante" solta um pulso ao rolar
		arena.armas.ao_rolar()
	return true


func _folego_cfg(chave: String, padrao: float) -> float:
	return float(Dados.json("movimento").get("folego", {}).get(chave, padrao))


func _quer_dash() -> bool:
	if _no_menu():
		return false
	if bot and arena.duelo_ativo:
		return _dash_ia
	if bot:
		return arena.inimigos.no_circulo(centro(), 40).size() > 4
	return Input.is_action_just_pressed("dash")


## Robô no duelo: usa o mesmo cérebro dos rivais.
func _bot_duelo() -> Vector2:
	var d: Node2D = arena.duelo
	if d.estado != "luta":
		return Vector2.ZERO
	_pref = d.IA.alcance_preferido(arena.armas.lista)
	var eu := {"pos": centro(), "hp_frac": hp / maxf(1.0, vida_max()), "pref": _pref, "dash_pronto": folego >= 1.0}
	var dec: Dictionary = d.IA.decidir(eu, d.alvos_de(d.lut_jogador), d.centro, d.raio, _ia, 0.9, _dt)
	_dash_ia = dec.dash
	return dec.dir


## Demonstração: foge dos vírus por perto, vai pegar XP e as tomadas, e anda em círculo quando está calmo.
func _bot_dir() -> Vector2:
	_bot_ang += 0.4 * _dt
	var c := centro()
	var fuga := Vector2.ZERO
	for v in arena.inimigos.no_circulo(c, 110):
		var dif: Vector2 = c - v.pos
		fuga += dif.normalized() * (110.0 - dif.length()) / 110.0 * (3.0 if v.chefe else 1.0)
	for t in arena.inimigos.tiros:
		if t.pos.distance_to(c) < 60:
			fuga += (c - t.pos).normalized()
	var quer := Vector2.from_angle(_bot_ang) * 0.4
	var melhor = null
	var md := 200.0 * 200.0
	for it in arena.coleta.itens:
		var d: float = it.pos.distance_squared_to(c)
		if d < md:
			md = d
			melhor = it
	if melhor:
		quer = (melhor.pos - c).normalized()
	else:
		var s = arena.chao.mais_perto_livre(position)
		if s and s.pos.distance_to(position) < 700:
			quer = (s.pos - position).normalized()
	# chefe da fase em campo: o robô vai atrás dele (com a build na mão) em vez de só fugir
	var ch: Array = arena.chefes()
	if not ch.is_empty() and not melhor and ch[0].pos.distance_to(c) > 70.0:
		quer = (ch[0].pos - c).normalized()
	# online: amigo caído por perto, o robô vai levantar
	if arena.online:
		for a in arena.online.avatares.values():
			if a.visible and a.caido and a.position.distance_to(position) < 400.0:
				quer = (a.position - position).normalized() if a.position.distance_to(position) > 20.0 else Vector2.ZERO
				fuga *= 0.3
				break
	var d := quer + fuga * 2.0
	return d.normalized() if d.length() > 0.1 else Vector2.ZERO


func _animar(entrada: Vector2) -> void:
	_olhar.atualizar(_golpe_dir if _golpe_t > 0.0 and _golpe_vira and forma == null else entrada, _dt, spr.vframes)   # golpeando: vira pro golpe
	_dir = _olhar.dir
	var novo := "andando" if entrada != Vector2.ZERO else "parado"
	if _tem_anim() and forma == null:
		if hp <= 0.0:
			novo = "morte"
		elif _dano_t > 0.0:
			novo = "dano"
		elif dash_t > 0.0:
			novo = "defesa"
		elif _atk_t > 0.0:
			novo = "ataque"
	if novo != _est:
		_est = novo
		_est_t = 0.0
	else:
		_est_t += _dt
	spr.frame = quadro_de(_est, _dir, _t if _est == "andando" else _est_t, spr.hframes)
	for c in camadas.values():
		c.frame = spr.frame
	# pisca quando está invencível depois de apanhar
	var piscar := invencivel > 0 and dash_t <= 0 and int(_t * 20) % 2 == 0
	spr.modulate = Color(1, 0.4, 0.4) if _vermelho > 0 else tom
	if humano < 1.0:
		# transformando: o corpo (e o equipamento, que é filho dele) clareia em luz cobalto e some
		var g := 1.0 - humano
		spr.modulate = Color(1.0 + g * 1.2, 1.0 + g * 1.6, 1.0 + g * 2.2, humano)
	if _ent_t > 0.0:   # chegando: aparece e brilha branco no pouso
		var p := 1.0 - _ent_t / Visual.CHEGADA_TEMPO
		var g := Visual.chegada_flash(p) * 2.0
		spr.modulate = Color(spr.modulate.r + g, spr.modulate.g + g, spr.modulate.b + g, spr.modulate.a * clampf(p * 6.0, 0.0, 1.0))
	if piscar:   # pisca em meia transparência: sumir de vez fazia o herói desaparecer no meio da horda (#68)
		spr.modulate.a *= 0.35
	spr.visible = humano > 0.01
	# rolamento (#68): o corpo (com o equipamento, que é filho dele) dá uma volta inteira em torno do meio do corpo
	if _rolando > 0.0:
		var total := maxf(0.05, float(Dados.json("movimento").get("rolamento", {}).get("tempo", 0.3)))
		var ang := (1.0 - _rolando / total) * TAU * _rola_lado
		spr.rotation = ang
		spr.position = CENTRO_CORPO - CENTRO_CORPO.rotated(ang)   # a origem do sprite é o pé: compensa pra girar no meio
	elif _golpe_t > 0.0 and _ent_t <= 0.0 and forma == null:
		var pose := pose_golpe(1.0 - _golpe_t / GOLPE_TEMPO)
		var d := _golpe_dir
		spr.position = (Vector2(d.x, d.y * 0.6) * pose.x).round()   # câmera em 3/4: avançar pra cima/baixo anda menos na tela
		spr.rotation = d.x * GOLPE_INCLINA * pose.z
		var horiz := absf(d.x) >= absf(d.y)
		spr.scale *= Vector2(1.0 + pose.y, 1.0 - pose.y * 0.6) if horiz else Vector2(1.0 - pose.y * 0.6, 1.0 + pose.y)
	elif spr.rotation != 0.0 or (spr.position != Vector2.ZERO and _ent_t <= 0.0):
		spr.rotation = 0.0
		spr.position = Vector2.ZERO


## Dano de vírus (fonte = tipo) ou de outro lutador no duelo. Retorna true se caiu.
func sofrer(dano: float, fonte := "", iframes := 0.5, empurrao := Vector2.ZERO) -> bool:
	if invencivel > 0 or hp <= 0:
		return false
	if arena.habilidades:
		dano *= arena.habilidades.mult_dano()   # transformado, aguenta mais
	hp -= dano
	arena.dano_recebido[fonte] = float(arena.dano_recebido.get(fonte, 0.0)) + dano
	invencivel = iframes
	_vermelho = 0.15
	if _dano_t <= 0.0:
		_dano_t = DANO_TEMPO
	if empurrao == Vector2.ZERO and arena.inimigos != null:
		empurrao = _empurrao_padrao()
	kb += empurrao
	if Config.v("flash_dano"):
		_flash_t = DANO_FLASH   # flash branco curto só no jogador (opção de acessibilidade)
	Som.tocar("erro", 0.15, 1.0, -4)
	arena.tremer(3.0)
	if hp <= 0:
		hp = 0
		arena.morrer(fonte)
		return true
	return false


## Interface igual à dos rivais: o duelo chama isso quando uma arma de outro lutador acerta.
func receber(dano: float, quem: String, empurrao := Vector2.ZERO) -> bool:
	return sofrer(dano, "rival:" + quem, arena.duelo.iframes, empurrao)


## Dano do anel (sem invencibilidade).
func dano_direto(dano: float, fonte: String) -> bool:
	if hp <= 0:
		return false
	hp -= dano
	_vermelho = 0.05
	if hp <= 0:
		hp = 0
		arena.morrer(fonte)
		return true
	return false


func curar(valor: float) -> void:
	valor *= maxf(0.0, 1.0 + arena.ef("cura")) if arena and arena.has_method("ef") and not arena.duelo_ativo else 1.0   # calor: "Feridas Abertas" (no duelo não)
	hp = minf(vida_max(), hp + valor)


func _draw() -> void:
	var _pp := Perf.ini()
	_draw_i()
	Perf.fim("jog_d", _pp)


func _draw_i() -> void:
	if _ent_t > 0.0 or _nome_t > 0.0:
		Visual.chegada(self, 1.0 - _ent_t / Visual.CHEGADA_TEMPO, _ent_nome, clampf(_nome_t / 0.6, 0.0, 1.0), Color(0.6, 0.85, 1.0))
	if not (arena.caido and arena.online) and humano > 0.5:
		Visual.sombra_boneco(self, spr)   # o dragão desenha a própria sombra
	for p in _poeira:   # poeira dos passos: bolinha que cresce e some
		var k: float = 1.0 - p.t / POEIRA_VIDA
		draw_circle(p.pos - position + Vector2(0, -k * 4.0), p.r * (1.0 + k), Color(0.78, 0.74, 0.66, 0.38 * (1.0 - k)))
	for r in (_rastro if forma == null else []):
		var tex := spr.texture
		var w := tex.get_width() / float(spr.hframes)
		var h := tex.get_height() / float(spr.vframes)
		var f: int = r.frame
		draw_texture_rect_region(tex, Rect2(r.pos - position + spr.offset, Vector2(w, h)),
			Rect2((f % spr.hframes) * w, (f / spr.hframes) * h, w, h), Color(0.5, 0.8, 1.0, r.t * 2.0))
	# barra de vida e recarga do dash embaixo do pé
	if arena.caido and arena.online:
		# caído: anel mostrando quanto falta pra levantar
		draw_arc(Vector2(0, -10), 18, 0, TAU, 32, Color(0, 0, 0, 0.4), 3)
		draw_arc(Vector2(0, -10), 18, -PI / 2, -PI / 2 + TAU * arena.online.reviver_prog, 32, Color(0.5, 1, 0.6), 3)
		return
	var frac := hp / maxf(1.0, vida_max())
	draw_rect(Rect2(-14, 5, 28, 4), Color(0.1, 0.05, 0.1))
	draw_rect(Rect2(-13, 6, 26 * frac, 2), Color(0.9, 0.2, 0.25))
	var cargas := int(_folego_cfg("cargas", 2.0))
	if cargas > 0 and folego < cargas:   # fôlego (#68): uma barrinha por carga de rolamento; some quando estão todas cheias
		var larg := (26.0 - (cargas - 1) * 2.0) / cargas
		for k in cargas:
			var f := clampf(folego - k, 0.0, 1.0)
			draw_rect(Rect2(-13 + k * (larg + 2), 10, larg, 2), Color(0.1, 0.05, 0.1))
			draw_rect(Rect2(-13 + k * (larg + 2), 10, larg * f, 2), Color(0.55, 0.85, 1.0) if f >= 1.0 else Color(0.3, 0.45, 0.65))
