extends Node
## A partida online, dentro da arena (só existe quando a partida é online).
## Anfitrião: roda o diretor e a IA dos vírus pra todo mundo, manda a "foto" dos vírus perto de cada um,
## aplica os acertos que os clientes mandam e avisa quando um vírus morre.
## Cliente: não roda IA; recebe a foto, acerta os vírus com as próprias armas e manda os acertos.
## Todos: mostram os outros jogadores, cuidam do próprio XP/baú e do próprio corpo caído (reviver).
## Desenho em docs/ONLINE_KIKIU.md; o transporte e a validação ficam em rede.gd.

const Remoto := preload("res://scripts/hordas/remoto.gd")
const ENVIO := 1.0 / 15.0
const RAIO_FOTO := 420.0
const MAX_FOTO := 220               # vírus por foto (a internet de casa agradece)
const MAX_TIROS := 120
const CD_DANO := 0.45               # anfitrião: intervalo mínimo entre danos de vírus no mesmo cliente
const REVIVER_BASE := 3.0           # segundos pra levantar alguém, divididos pelo "reviver" de quem ajuda
const REVIVER_DIST := 40.0
const Mapa := preload("res://scripts/hordas/mapa.gd")
const ESPERA_PRONTOS := 60.0        # fim da fase: espera todo mundo terminar as cartas e votar no mapa, até 60 s (depois de nó sem combate, "espera_voto" de dados/mapa.json)
const TODOS_CAIDOS := 1.0           # todo mundo caído por 1 s = fim da corrida

var arena: Node
var avatares := {}                  # peer -> remoto.gd
var tipos: Array = []               # índice <-> tipo de vírus (mesma ordem em todo computador)
var _tipo_idx := {}
var sprites_tiro: Array = []
var _sprite_idx := {}
var reviver_prog := 0.0
var forcas := {}                    # anfitrião: peer -> força no duelo
var _t_envio := 0.0
var _acertos := PackedFloat32Array()  # cliente: acertos ainda não mandados
var _mortes := PackedFloat32Array()   # anfitrião: mortes ainda não mandadas
var _cd_dano := {}
var _prontos := {}              # anfitrião, votação do mapa: peer -> faixa votada
var _t_prontos := -1.0
var _t_caidos := 0.0
var n_tx := 0                     # teste: acertos mandados (cliente) / recebidos (anfitrião)


func _ready() -> void:
	Rede.online_no = self
	var inim: Dictionary = Dados.json("inimigos")
	var spr := {"proj_email": true}
	for k in inim:
		if k.begins_with("_") or not inim[k] is Dictionary:
			continue
		tipos.append(k)
		if inim[k].get("tiro") is Dictionary:
			spr[str(inim[k].tiro.get("sprite", "proj_email"))] = true
	tipos.sort()
	for i in tipos.size():
		_tipo_idx[tipos[i]] = i
	sprites_tiro = spr.keys()
	sprites_tiro.sort()
	for i in sprites_tiro.size():
		_sprite_idx[sprites_tiro[i]] = i


func _exit_tree() -> void:
	if Rede.online_no == self:
		Rede.online_no = null


func anfitriao() -> bool:
	return Rede.anfitriao()


func tipo_idx(tipo: String) -> int:
	return int(_tipo_idx.get(tipo, 0))


func sprite_idx(sprite: String) -> int:
	return int(_sprite_idx.get(sprite, 0))


## O que este computador manda pros outros ~15 vezes por segundo.
func estado_rede() -> Dictionary:
	var j: Node2D = arena.jogador
	var m: Vector2 = j.direcao_mov()
	return {"x": j.position.x, "y": j.position.y, "mx": m.x, "my": m.y,
		"hp": clampf(j.hp / maxf(1.0, j.vida_max()), 0.0, 1.0), "caido": arena.caido, "lado": j.lado, "ajuda": ajudando()}


## Jogadores em pé que os vírus podem perseguir: [centro, peer]. O local vem primeiro.
func alvos() -> Array:
	var res := []
	if not arena.caido:
		res.append([arena.jogador.centro(), Rede.eu()])
	for p in Rede.remotos:
		var d: Dictionary = Rede.remotos[p]
		if not d.caido and avatares.has(p):
			res.append([Vector2(d.x, d.y - 22.0), p])
	return res


# ---------- a cada quadro ----------

func atualizar(dt: float) -> void:
	_atualizar_avatares(dt)
	if arena.caido and not arena.duelo_ativo:
		_reviver(dt)
	if anfitriao():
		for p in _cd_dano.keys():
			_cd_dano[p] -= dt
		_checar_caidos(dt)
		if _t_prontos >= 0.0:
			_t_prontos -= dt
			_checar_prontos()
	_t_envio -= dt
	if _t_envio > 0.0:
		return
	_t_envio = ENVIO
	if anfitriao():
		_enviar_fotos()
		if not _mortes.is_empty():
			Rede.enviar_mortes(_mortes)
			_mortes = PackedFloat32Array()
	elif not _acertos.is_empty():
		n_tx += _acertos.size() / 4
		Rede.enviar_acertos(_acertos)
		_acertos = PackedFloat32Array()


func _atualizar_avatares(dt: float) -> void:
	for p in Rede.jogadores:
		if p == Rede.eu() or avatares.has(p):
			continue
		var r := Remoto.new()
		r.configurar(p, Rede.heroi_de(p), Rede.nome_de(p))
		r.visible = false
		arena.add_child(r)
		avatares[p] = r
	for p in avatares.keys():
		if not Rede.jogadores.has(p):
			avatares[p].queue_free()
			avatares.erase(p)
			continue
		if Rede.remotos.has(p):
			avatares[p].atualizar(dt, Rede.remotos[p])
		else:
			avatares[p].visible = false


func saiu(peer: int) -> void:
	if avatares.has(peer):
		avatares[peer].queue_free()
		avatares.erase(peer)
	if anfitriao():
		_prontos.erase(peer)
		forcas.erase(peer)
		if arena.duelo_ativo:
			arena.duelo.caiu_online(peer, 0)
	arena.mensagem("%s saiu da partida." % Rede.nome_de(peer) if Rede.heroi_de(peer) != "" else "Alguém saiu da partida.", Color(1, 0.7, 0.5))


# ---------- vírus: anfitrião ----------

func _enviar_fotos() -> void:
	if arena.duelo_ativo:
		return
	var lista: Array = arena.inimigos.lista
	var tiros: Array = arena.inimigos.tiros
	for p in Rede.jogadores:
		if p == 1 or not Rede.remotos.has(p):
			continue
		var d: Dictionary = Rede.remotos[p]
		var c := Vector2(d.x, d.y - 22.0)
		var r2 := RAIO_FOTO * RAIO_FOTO
		var vir := PackedFloat32Array()
		var n := 0
		for v in lista:
			if n >= MAX_FOTO:
				break
			if not v.chefe and v.pos.distance_squared_to(c) > r2:
				continue
			var flags := (1 if v.elite else 0) | (2 if v.chefe else 0) | (4 if v.flash > 0 else 0) \
				| (8 if v.estado == 1 else 0) | (16 if v.lento > 0 else 0)
			vir.append_array([v.id, tipo_idx(v.tipo), v.pos.x, v.pos.y, clampf(v.hp / v.hpmax, 0.0, 1.0), flags])
			n += 1
		var ti := PackedFloat32Array()
		n = 0
		for t in tiros:
			if n >= MAX_TIROS:
				break
			if t.pos.distance_squared_to(c) <= r2:
				ti.append_array([t.pos.x, t.pos.y, t.vel.x, t.vel.y, sprite_idx(t.get("sprite", ""))])
				n += 1
		Rede.enviar_foto(p, vir, ti)


## Um vírus encostou (ou um tiro acertou) um jogador de outro computador.
func dano_remoto(peer: int, valor: float, fonte: String) -> void:
	if float(_cd_dano.get(peer, 0.0)) > 0.0:
		return
	_cd_dano[peer] = CD_DANO
	Rede.enviar_dano(peer, valor, fonte)


## O anfitrião matou um vírus (com qualquer arma): avisa os outros pra cada um pegar a sua recompensa.
func morreu(v) -> void:
	_mortes.append_array([v.id, v.pos.x, v.pos.y, tipo_idx(v.tipo), 1.0 if v.elite else 0.0])


func acertos(_quem: int, a: PackedFloat32Array) -> void:
	n_tx += a.size() / 4
	for i in range(0, a.size(), 4):
		var dano := a[i + 1]
		if not is_finite(dano) or dano <= 0.0:
			continue
		var v = arena.inimigos.por_id.get(int(a[i]))
		if v == null:
			continue
		var kb := Vector2(a[i + 2], a[i + 3])
		arena.inimigos.ferir_remoto(v, minf(dano, 100000.0), kb.limit_length(400.0) if kb.is_finite() else Vector2.ZERO)


# ---------- vírus: cliente ----------

func foto(vir: PackedFloat32Array, tiros: PackedFloat32Array) -> void:
	if vir.size() % 6 != 0 or tiros.size() % 5 != 0 or arena.duelo_ativo:
		return
	arena.inimigos.aplicar_foto(vir, tiros, self)


func mortes(m: PackedFloat32Array) -> void:
	if anfitriao() or m.size() % 5 != 0:
		return
	for i in range(0, m.size(), 5):
		var ti := int(m[i + 3])
		if ti < 0 or ti >= tipos.size():
			continue
		arena.inimigos.remover_id(int(m[i]))
		arena.recompensa(Vector2(m[i + 1], m[i + 2]), tipos[ti], m[i + 4] > 0.5)


## A arma deste cliente acertou um vírus: guarda pra mandar ao anfitrião no próximo pacote.
func acerto(id: int, valor: float, empurrao: Vector2) -> void:
	_acertos.append_array([id, valor, empurrao.x, empurrao.y])


func dano(valor: float, fonte: String) -> void:
	if not arena.caido and not arena.duelo_ativo and not arena.acabou:
		arena.jogador.sofrer(valor, fonte)


# ---------- reviver ----------

## Estou segurando o botão (Enter/E) perto de um amigo caído? O robô de teste segura sozinho.
func ajudando() -> bool:
	if arena.caido or arena.duelo_ativo or arena.cartas.aberto():
		return false
	if not arena.bot and not Input.is_action_pressed("confirmar"):
		return false
	for p in avatares:
		var a: Node2D = avatares[p]
		if a.visible and a.caido and a.position.distance_to(arena.jogador.position) <= REVIVER_DIST + 8.0:
			return true
	return false


func _reviver(dt: float) -> void:
	var melhor := 0.0
	for p in avatares:
		var a: Node2D = avatares[p]
		if a.visible and not a.caido and a.ajuda and a.position.distance_to(arena.jogador.position) <= REVIVER_DIST:
			melhor = maxf(melhor, float(Dados.json("herois").get(a.heroi, {}).get("reviver", 1.0)))
	if melhor > 0.0:
		reviver_prog += dt * melhor / REVIVER_BASE
		if reviver_prog >= 1.0:
			reviver_prog = 0.0
			arena.levantar(0.5)
			arena.mensagem("Te levantaram!", Color(0.6, 1, 0.7))
	else:
		reviver_prog = maxf(0.0, reviver_prog - dt * 0.5)


func _checar_caidos(dt: float) -> void:
	if arena.duelo_ativo or arena.pre_duelo or arena.entre_fases or arena.acabou:
		_t_caidos = 0.0
		return
	var todos: bool = arena.caido
	for p in Rede.jogadores:
		if p != 1 and not bool(Rede.remotos.get(p, {}).get("caido", false)):
			todos = false
	_t_caidos = _t_caidos + dt if todos else 0.0
	if _t_caidos >= TODOS_CAIDOS:
		_t_caidos = -999.0
		Rede.evento("fim_corrida")


# ---------- fases ----------

func _checar_prontos() -> void:
	var todos := true
	for p in Rede.jogadores:
		if not _prontos.has(p):
			todos = false
	if todos or _t_prontos < 0.0:
		# votação do mapa: maioria, empate = voto do anfitrião, sem voto = primeira opção (nunca trava)
		var faixa := Mapa.resolver_votos(_prontos, Rede.eu(), arena.mapa_acessiveis())
		_t_prontos = -1.0
		_prontos = {}
		var combate := Mapa.combate(arena.mapa_tipo_de(faixa))   # antes do evento: ele já move o mapa no anfitrião
		Rede.evento("proxima_fase", {"no": faixa})
		if not combate:   # nó sem combate: já abre a votação do andar seguinte
			_t_prontos = float(Mapa.cfg().get("espera_voto", 40.0))


# ---------- mensagens ----------

func evento(nome: String, d: Dictionary) -> void:
	var host := anfitriao()
	match nome:
		"anuncio":
			if not host:
				arena.anunciar(str(d.get("txt", "")), Color.from_string(str(d.get("cor", "#ffffff")), Color.WHITE))
		"chefe_final":
			if not host:
				arena.chefe_final_chegou(bool(d.get("final", false)), str(d.get("chefe", "")))
		"fase_completa":
			if host:
				_prontos = {}
				_t_prontos = ESPERA_PRONTOS
			arena.fase_completa()
		"proxima_fase":
			arena.escolher_no(int(d.get("no", -1)))
		"tela_azul_caiu":
			arena.tela_azul_caiu()
		"fim_corrida":
			arena.fim_corrida()
		"duelo_iniciar":
			arena.iniciar_duelo_online(d)
		"luta":
			arena.duelo.luta_online(d)
		"eliminado":
			arena.duelo.eliminado_online(d)
		"duelo_fim":
			arena.duelo.fim_online(d)


func aviso(quem: int, nome: String, valor: float, peer: int) -> void:
	match nome:
		"voto":   # valor = (andar de destino) * 10 + faixa; voto de outro andar (atrasado) não conta
			if _t_prontos >= 0.0 and int(valor) / 10 == arena.mapa_pos.x + 1:
				_prontos[quem] = int(valor) % 10
		"forca":
			if arena.duelo_ativo:
				forcas[quem] = clampf(valor, 0.5, 1.0e7)
				arena.duelo.checar_forcas()
		"caiu":
			if arena.duelo_ativo:
				arena.duelo.caiu_online(quem, peer)


func golpe(quem: int, dano_: float, empurrao: Vector2) -> void:
	if arena.duelo_ativo:
		arena.duelo.golpe_online(quem, dano_, empurrao)
