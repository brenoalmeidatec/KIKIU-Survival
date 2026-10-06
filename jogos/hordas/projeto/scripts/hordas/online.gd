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
## Posição deste jogador pros outros, 15 vezes por segundo, em 12 bytes (era um Dictionary de ~150 bytes):
## x, y (float), direção do movimento (s8 em 1/127), vida (u8 em 1/255) e flags (1 caído, 2 ajudando, 4 olhando pra esquerda).
func estado_rede() -> PackedByteArray:
	var j: Node2D = arena.jogador
	var m: Vector2 = j.direcao_mov()
	var b := PackedByteArray()
	b.resize(12)
	b.encode_float(0, j.position.x)
	b.encode_float(4, j.position.y)
	b.encode_s8(8, clampi(roundi(m.x * 127.0), -127, 127))
	b.encode_s8(9, clampi(roundi(m.y * 127.0), -127, 127))
	b.encode_u8(10, roundi(clampf(j.hp / maxf(1.0, j.vida_max()), 0.0, 1.0) * 255.0))
	b.encode_u8(11, (1 if arena.caido else 0) | (2 if ajudando() else 0) | (4 if j.lado < 0 else 0) | (8 if j._rolando > 0.0 else 0))   # 8 = rolando (#68)
	return b


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
		# quem entra na foto: chefes e os mais perto (com mais que MAX_FOTO no raio, cortar por ordem da lista fazia
		# bicho entrar e sair da foto o tempo todo: piscava na tela do cliente)
		var cand: Array = []
		for v in lista:
			var d2: float = v.pos.distance_squared_to(c)
			if v.chefe or d2 <= r2:
				cand.append([-1.0 if v.chefe else d2, v])
		if cand.size() > MAX_FOTO:
			cand.sort_custom(func(a, b): return a[0] < b[0])
			cand.resize(MAX_FOTO)
		for ce in cand:
			var v = ce[1]
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
		Rede.enviar_foto(p, compactar(c, vir, ti))


## Foto compacta (#55, banda): 11 bytes por vírus em vez de 24 e 9 por tiro em vez de 20 (floats de 32 bits viravam
## a maior parte do upload do anfitrião). Cabeçalho: centro da foto (2 floats) e as quantidades. Posições relativas ao
## centro em meio pixel (s16: ±16 mil px), vida em 1/255, tipo/flags/sprite em 1 byte, id em u32.
static func compactar(c: Vector2, vir: PackedFloat32Array, ti: PackedFloat32Array) -> PackedByteArray:
	var nv := vir.size() / 6
	var nt := ti.size() / 5
	var b := PackedByteArray()
	b.resize(12 + nv * 11 + nt * 9)
	b.encode_float(0, c.x)
	b.encode_float(4, c.y)
	b.encode_u16(8, nv)
	b.encode_u16(10, nt)
	var o := 12
	for i in nv:
		var k := i * 6
		b.encode_u32(o, int(vir[k]))
		b.encode_u8(o + 4, int(vir[k + 1]))
		b.encode_s16(o + 5, clampi(roundi((vir[k + 2] - c.x) * 2.0), -32767, 32767))
		b.encode_s16(o + 7, clampi(roundi((vir[k + 3] - c.y) * 2.0), -32767, 32767))
		b.encode_u8(o + 9, roundi(clampf(vir[k + 4], 0.0, 1.0) * 255.0))
		b.encode_u8(o + 10, int(vir[k + 5]))
		o += 11
	for i in nt:
		var k := i * 5
		b.encode_s16(o, clampi(roundi((ti[k] - c.x) * 2.0), -32767, 32767))
		b.encode_s16(o + 2, clampi(roundi((ti[k + 1] - c.y) * 2.0), -32767, 32767))
		b.encode_s16(o + 4, clampi(roundi(ti[k + 2]), -32767, 32767))
		b.encode_s16(o + 6, clampi(roundi(ti[k + 3]), -32767, 32767))
		b.encode_u8(o + 8, int(ti[k + 4]))
		o += 9
	return b


## O contrário de compactar: devolve os mesmos arrays de floats que o resto do código usa ([] se veio torto).
static func descompactar(b: PackedByteArray) -> Array:
	if b.size() < 12:
		return []
	var c := Vector2(b.decode_float(0), b.decode_float(4))
	var nv := b.decode_u16(8)
	var nt := b.decode_u16(10)
	if b.size() != 12 + nv * 11 + nt * 9:
		return []
	var vir := PackedFloat32Array()
	vir.resize(nv * 6)
	var ti := PackedFloat32Array()
	ti.resize(nt * 5)
	var o := 12
	for i in nv:
		var k := i * 6
		vir[k] = b.decode_u32(o)
		vir[k + 1] = b.decode_u8(o + 4)
		vir[k + 2] = c.x + b.decode_s16(o + 5) * 0.5
		vir[k + 3] = c.y + b.decode_s16(o + 7) * 0.5
		vir[k + 4] = b.decode_u8(o + 9) / 255.0
		vir[k + 5] = b.decode_u8(o + 10)
		o += 11
	for i in nt:
		var k := i * 5
		ti[k] = c.x + b.decode_s16(o) * 0.5
		ti[k + 1] = c.y + b.decode_s16(o + 2) * 0.5
		ti[k + 2] = b.decode_s16(o + 4)
		ti[k + 3] = b.decode_s16(o + 6)
		ti[k + 4] = b.decode_u8(o + 8)
		o += 9
	return [vir, ti]


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

func foto(compacta: PackedByteArray) -> void:
	var f := descompactar(compacta)
	if f.is_empty() or arena.duelo_ativo:
		return
	arena.inimigos.aplicar_foto(f[0], f[1], self)


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
