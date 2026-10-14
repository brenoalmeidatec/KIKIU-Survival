extends Node
## Salão vivo: luz, partículas e movimento por cima da arte pronta do santuário (v2/salao.gd instancia e chama `montar`; mais nada lá).
## A arte de fundo é clara e aprovada: não se escurece o salão. O brilho é ADITIVO (camada sem escurecimento) e, em Médio e Alto, as
## PointLight2D reais entram com um CanvasModulate suave (nunca preto). Tudo procedural: texturas geradas uma vez no montar, nenhum nó
## criado nem load por quadro, pixel nítido (filtro nearest, posições inteiras). Para quando o painel ou a pausa estão abertos.
##
## Camadas (CanvasLayer, abaixo da interface do salão, que fica na tela padrão):
##   -2 cena: o cenário e o herói (movidos para cá), o vão animado dos portais, as luzes, as sombras e o CanvasModulate;
##   -1 brilho: halos, poças de luz, chamas, runas, partículas e névoa (aditivos; sem CanvasModulate).
## Perfis (dados/graficos.json): luz_relevo (2/6/10 luzes), sombras (modo de sombras.gd), nevoa, particulas_sim (20/45/80 partículas).

const Paleta := preload("res://v2/paleta.gd")
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Luzes := preload("res://v2/luzes.gd")
const Sombras := preload("res://v2/sombras.gd")
const Ator := preload("res://v2/ator.gd")
const Sombreador := preload("res://v2/salao_vivo.gdshader")

const LARG := 960
const ALT := 540
const TOCHAS := [Vector2(44, 70), Vector2(918, 70)]  # centro da chama pintada em cada tocha do muro
const VELAS := [Vector2(-40, -44), Vector2(8, -44), Vector2(-40, -18), Vector2(8, -18)]  # velas do altar, relativas a ele
const CRISTAL := Vector2(-14, -68)  # cristal do altar, relativo a ele
const VAO := Vector2(40, 78)  # o vão do portal onde o redemoinho aparece (px)
const VAO_TOPO := -108.0  # topo do vão em relação aos pés do portal
const CADEADO := Vector2(-1, -59)  # cadeado do portal fechado, em relação aos pés dele
const TAPETE := Rect2(395, 425, 170, 115)
const MODULADO := Color("#c8cbe0")  # mais claro que o #8f93b0 do pedido: com ele a sala perdia ~35% de brilho médio (medido nos prints); o contraste vem das luzes
const COR_TOCHA := Color(1.0, 0.62, 0.28)
const COR_CHAMA_VELA := Color(0.78, 0.5, 1.0)
const PERIODO_CICLO := 90.0
const AMPLITUDE_CICLO := 0.06
const ALCANCE_PORTAL := 100.0
const ALCANCE_MOLA := 110.0
const MOLA_K := 70.0
const MOLA_C := 5.0
const NEVOA_RECT := Rect2(0, 430, 960, 76)
const RUNAS := [
	["..#..", "..#..", "#####", "..#..", "..#.."],
	["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	["#####", "#...#", "#.#.#", "#...#", "#####"],
	[".###.", "#...#", "..#..", ".#.#.", "..#.."]
]
const N_RUNAS := 8
const CADEADO_BITS := [".#####.", "#.....#", "#.....#", "#######", "#######", "###.###", "###.###", "#######"]


## Uma chama (tocha, vela, cristal, brilho de estação): núcleo + halo + poça no piso + língua de pixels. Reage ao herói por mola.
class Chama:
	extends RefCounted
	var pos := Vector2.ZERO
	var cor := Color.WHITE
	var semente := 0.0
	var forca := 1.0  # cresce com o nível comprado
	var halo_a := 0.3
	var nucleo_a := 0.5
	var poca_a := 0.2
	var x := 0.0  # mola: deslocamento horizontal (px) e velocidade
	var v := 0.0
	var mola := false
	var reativo := Vector2.ZERO  # ponto no chão que o herói pisa para balançar a chama
	var estacao := ""  # a estação cujo nível dá força a esta chama
	var pe := 0.0  # onde a base da língua fica, em relação a `pos`
	var halo: Sprite2D
	var nucleo: Sprite2D
	var poca: Sprite2D
	var lingua: Sprite2D
	var linguas: Array[Texture2D] = []


class Portal:
	extends RefCounted
	var id := ""
	var pos := Vector2.ZERO
	var cor := Color.WHITE
	var fechado := false
	var fase := 0.0
	var reacao := 0.0
	var vao: Sprite2D
	var mat: ShaderMaterial
	var halo: Sprite2D
	var poca: Sprite2D
	var cadeado: Sprite2D
	var info: Dictionary = {}  # a luz do portal (ou vazio, se o perfil não a tem)


class Estacao:
	extends RefCounted
	var id := ""
	var pos := Vector2.ZERO
	var cor := Color.WHITE
	var frac := 0.0
	var soma := 0
	var aura: Sprite2D
	var runas: Array[Sprite2D] = []
	var emissor: CPUParticles2D
	var base_particulas := 0


var _ctx  # o salão (v2/salao.gd): sem tipo, porque lemos dele membros e constantes dele
var _cena: CanvasLayer
var _mundo: Node2D
var _glow: CanvasLayer
var _fx: Node2D
var _modulador: CanvasModulate
var _rotulos: Node2D
var _mat_add: CanvasItemMaterial
var _ruido := FastNoiseLite.new()
var _tempo := 0.0
var _congelado := false
var _painel_antes := false
var _pos_ant := Vector2.ZERO
var _tex_cache := {}
var _tex_ponto: ImageTexture
var _chamas: Array[Chama] = []
var _portais: Array[Portal] = []
var _estacoes: Array[Estacao] = []
var _luzes: Luzes
var _infos_luz: Array[Dictionary] = []  # {e, base, en, sem, tipo, portal}
var _sombras: Sombras
var _ator: Ator
var _nevoa: Sprite2D
var _mat_nevoa: ShaderMaterial
var _po_pes: CPUParticles2D
var _po_tapete: CPUParticles2D
var _altar := Vector2.ZERO
var _tex_runas: Array[Texture2D] = []
var _particulas: Array[CPUParticles2D] = []
var _perfil_pendente := false
# perfil
var lim_luzes := 6
var com_modulador := true
var modo_sombra := Sombras.MEDIA
var com_nevoa := true
var total_particulas := 45
var com_ciclo := true


func _ler_perfil() -> void:
	lim_luzes = {"desligada": 2, "so_heroi": 6, "tudo": 10}.get(str(Config.g("luz_relevo")), 6)
	com_modulador = lim_luzes >= 6
	com_ciclo = lim_luzes >= 6
	com_nevoa = bool(Config.g("nevoa")) and lim_luzes >= 6
	modo_sombra = maxi(Sombras.NENHUMA, Sombras.NOMES.find(str(Config.g("sombras"))))
	var f := Config.fator_particulas("amb_particulas")
	total_particulas = 0 if f <= 0.0 else (20 if f < 0.4 else (45 if f < 0.9 else 80))


## Monta tudo. `ctx` é o salão (Control): lê dele _cenario, _heroi, _chamas, _alvos, _estruturas, _sprite e o tamanho do quadro.
func montar(ctx) -> void:
	_ctx = ctx
	process_priority = 1  # depois de salao._process: respiração não é sobrescrita pelo movimento
	_ler_perfil()
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0
	_ruido.seed = 7
	_mat_add = CanvasItemMaterial.new()
	_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_tex_ponto = _imagem_cor(Color.WHITE, 1, 1)
	_cena = CanvasLayer.new()
	_cena.layer = -2
	add_child(_cena)
	_mundo = Node2D.new()
	_cena.add_child(_mundo)
	ctx._chamas.visible = false  # as três manchas antigas deram lugar às chamas daqui
	ctx._cenario.reparent(_mundo, false)
	ctx._visual.rotulos_fora = true  # os nomes saem do cenário (que recebe luz e CanvasModulate) e vão para um nó sem luz, logo acima
	_rotulos = Node2D.new()
	var sem_luz := CanvasItemMaterial.new()
	sem_luz.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_rotulos.material = sem_luz
	_rotulos.draw.connect(_pintar_rotulos)
	_glow = CanvasLayer.new()
	_glow.layer = -1
	add_child(_glow)
	_fx = Node2D.new()
	_glow.add_child(_fx)
	_glow.add_child(_rotulos)  # nomes sem CanvasModulate, por cima dos brilhos
	_ler_niveis()
	_montar_portais()
	ctx._heroi.reparent(_mundo, false)
	_montar_chamas()
	_montar_estacoes()
	_montar_luzes()
	_montar_sombra_heroi()
	_montar_nevoa()
	_montar_particulas()
	_aplicar_niveis()
	if com_modulador:
		_modulador = CanvasModulate.new()
		_modulador.color = MODULADO
		_mundo.add_child(_modulador)
	_pos_ant = ctx._pos
	ctx._cenario.queue_redraw()
	Config.graficos_mudou.connect(_agendar_perfil)


## Ajustes podem emitir várias mudanças no mesmo quadro. Reconstrói só ao mudar a assinatura visual.
func _agendar_perfil() -> void:
	if _perfil_pendente:
		return
	_perfil_pendente = true
	_reaplicar_perfil.call_deferred()


func _reaplicar_perfil() -> void:
	if _ctx._painel.visible or _ctx.pausa.aberto:
		return  # Ajustes não reconstrói efeitos enquanto o salão está congelado
	_perfil_pendente = false
	var antes := [lim_luzes, modo_sombra, com_nevoa, total_particulas]
	_ler_perfil()
	if antes == [lim_luzes, modo_sombra, com_nevoa, total_particulas]:
		return
	for p in _particulas:
		p.free()
	_particulas.clear()
	_po_pes = null
	_po_tapete = null
	for est in _estacoes:
		est.emissor = null
	for info in _infos_luz:
		(info.e as Luzes.Entrada).luz.free()
	_infos_luz.clear()
	for portal in _portais:
		portal.info = {}
	if _sombras != null:
		_sombras.raiz_sombras.free()
		_sombras.raiz_blobs.free()
		_sombras = null
		_ator = null
	if _nevoa != null:
		_nevoa.free()
		_nevoa = null
		_mat_nevoa = null
	if _modulador != null:
		_modulador.free()
		_modulador = null
	_montar_luzes()
	_montar_sombra_heroi()
	_montar_nevoa()
	_montar_particulas()
	_aplicar_niveis()  # estado já lido ao montar/fechar o painel; não consulta Meta nos Ajustes
	if com_modulador:
		_modulador = CanvasModulate.new()
		_modulador.color = MODULADO
		_mundo.add_child(_modulador)
	for p in _particulas:
		p.speed_scale = 0.0 if _congelado else 1.0


func _pintar_rotulos() -> void:
	for a in _ctx._alvos:
		if a.tipo == "portal":
			_ctx._visual.rotulo_portal(_rotulos, a, Mapas.condicao(Mapas.buscar(str(a.id))) != "")
		else:
			_ctx._visual.rotulo_estrutura(_rotulos, a)


# ------------------------------------------------------------------ texturas (uma vez só)


static func _imagem_cor(cor: Color, w: int, h: int) -> ImageTexture:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(cor)
	return ImageTexture.create_from_image(im)


static func _par(n: float) -> int:
	return maxi(2, int(n) - int(n) % 2)


## Brilho em degraus (pixel art): disco ou elipse w x h, com `niveis` faixas de alfa. Sem borrão; o filtro é nearest.
func _tex_banda(w: int, h: int, niveis: int, expo: float) -> ImageTexture:
	var chave := "b%d_%d_%d_%.2f" % [w, h, niveis, expo]
	if _tex_cache.has(chave):
		return _tex_cache[chave]
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w / 2.0) / (w / 2.0)
			var dy := (y + 0.5 - h / 2.0) / (h / 2.0)
			var d := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if d < 1.0:
				a = floorf(pow(1.0 - d, expo) * niveis + 0.5) / niveis
			im.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(im)
	_tex_cache[chave] = t
	return t


## Língua de fogo em pixels: ponta em cima, miolo claro, borda na cor `cor`.
func _tex_chama(w: int, h: int, cor: Color) -> ImageTexture:
	var chave := "c%d_%d_%s" % [w, h, cor.to_html()]
	if _tex_cache.has(chave):
		return _tex_cache[chave]
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var meio := (w - 1) / 2.0
	var quente := cor.lerp(Color(1, 0.95, 0.6), 0.55)
	var miolo := cor.lerp(Color.WHITE, 0.85)
	for y in h:
		var f := (y + 0.5) / h
		var larg := 0.6 + (w / 2.0 - 0.6) * sin(minf(f * 1.25, 1.0) * PI / 2.0)
		for x in w:
			var d := absf(x - meio) / larg
			if d > 1.0:
				continue
			var c := cor
			if d < 0.4 and f > 0.4:
				c = miolo
			elif d < 0.72 and f > 0.2:
				c = quente
			c.a = 0.85
			im.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(im)
	_tex_cache[chave] = t
	return t


func _tex_bits(bits: Array, cor: Color, k := 1) -> ImageTexture:
	var h: int = bits.size()
	var w: int = str(bits[0]).length()
	var im := Image.create(w * k, h * k, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if str(bits[y])[x] == "#":
				for j in k:
					for i in k:
						im.set_pixel(x * k + i, y * k + j, cor)
	return ImageTexture.create_from_image(im)


func _spr(tex: Texture2D, pos: Vector2, aditivo := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if aditivo:
		s.material = _mat_add
	s.position = pos.round()
	_fx.add_child(s)
	return s


# ------------------------------------------------------------------ leitura do que foi comprado (só leitura)


func _ler_niveis() -> void:
	var estado := Meta.estado()
	for e in _ctx._estruturas:
		var est := _estacao(str(e.id))
		if est == null:
			est = Estacao.new()
			est.id = str(e.id)
			_estacoes.append(est)
		var soma := 0
		var teto := 0
		if bool(e.get("conquistas", false)):
			for c in Meta.conquistas():
				teto += 1
				soma += 1 if bool(estado.conquistas.get(str(c.id), false)) else 0
		else:
			for id in e.melhorias:
				var m := Meta.melhoria(str(id))
				if m.is_empty():
					continue
				teto += int(m.max)
				soma += int(estado.niveis.get(str(id), 0))
		est.soma = soma
		est.frac = float(soma) / float(maxi(teto, 1))


func _estacao(id: String) -> Estacao:
	for e in _estacoes:
		if e.id == id:
			return e
	return null


func _pos_alvo(id: String) -> Vector2:
	for a in _ctx._alvos:
		if str(a.id) == id:
			return a.pos
	return Vector2.ZERO


# ------------------------------------------------------------------ portais


func _montar_portais() -> void:
	for a in _ctx._alvos:
		if a.tipo != "portal":
			continue
		var p := Portal.new()
		p.id = str(a.id)
		p.pos = a.pos
		p.fechado = Mapas.condicao(Mapas.buscar(p.id)) != ""
		p.cor = _ctx.COR_TRAVADO if p.fechado else _ctx.CORES_MAPA.get(p.id, _ctx.COR_TRAVADO)
		p.fase = float(_portais.size()) * 1.9
		if not p.fechado:
			var v := Sprite2D.new()
			v.texture = _imagem_cor(Color.WHITE, 1, 1)
			v.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			v.centered = false
			v.scale = VAO
			v.position = Vector2(p.pos.x - VAO.x / 2.0, p.pos.y + VAO_TOPO).round()
			var m := ShaderMaterial.new()
			m.shader = Sombreador
			m.set_shader_parameter("modo", 0)
			m.set_shader_parameter("cor", p.cor.lerp(Color.WHITE, 0.15))
			m.set_shader_parameter("tam", VAO)
			m.set_shader_parameter("semente", p.fase)
			v.material = m
			_mundo.add_child(v)
			p.vao = v
			p.mat = m
		p.halo = _spr(_tex_banda(_par(104), _par(128), 6, 1.8), p.pos + Vector2(0, -68))
		p.poca = _spr(_tex_banda(_par(116), _par(34), 5, 1.3), p.pos + Vector2(0, 11))
		if p.fechado:
			p.cadeado = _spr(_tex_bits(CADEADO_BITS, Color(1.0, 0.8, 0.35), 2), p.pos + CADEADO)
		_portais.append(p)


# ------------------------------------------------------------------ tochas, altar, velas (item 1)


func _nova_chama(pos: Vector2, cor: Color, escala: float, sem: float, com_poca: bool, piso: Vector2, lingua: Vector2i, pe := 0.0) -> Chama:
	var c := Chama.new()
	c.pos = pos
	c.pe = pe
	c.cor = cor
	c.semente = sem
	if com_poca:
		c.poca = _spr(_tex_banda(_par(132 * escala), _par(44 * escala), 5, 1.3), piso)
	c.halo = _spr(_tex_banda(_par(92 * escala), _par(92 * escala), 7, 1.7), pos)
	c.nucleo = _spr(_tex_banda(_par(22 * escala), _par(22 * escala), 4, 1.2), pos)
	if lingua != Vector2i.ZERO:
		for dh in [-2, 0, 2]:
			c.linguas.append(_tex_chama(lingua.x, lingua.y + dh, cor))
		c.lingua = _spr(c.linguas[1], pos)
		c.lingua.centered = false
	_chamas.append(c)
	return c


func _montar_chamas() -> void:
	for i in TOCHAS.size():
		var c := _nova_chama(TOCHAS[i], COR_TOCHA, 1.0, float(i) * 2.3 + 0.7, true, Vector2(TOCHAS[i].x + (6 if i == 0 else -6), 178), Vector2i(7, 11), 6.0)
		c.mola = true
		c.reativo = Vector2(TOCHAS[i].x, 190)
	_altar = _pos_alvo("altar")
	var cr := _nova_chama(_altar + CRISTAL, Paleta.ALMA, 1.15, 5.1, true, _altar + Vector2(0, 4), Vector2i.ZERO)
	cr.halo_a = 0.34
	cr.estacao = "altar"
	for i in VELAS.size():
		var v := _nova_chama(_altar + VELAS[i] + Vector2(0, -3), COR_CHAMA_VELA, 0.32, 9.0 + i * 1.3, false, Vector2.ZERO, Vector2i(3, 5), 3.0)
		v.mola = true
		v.reativo = _altar + VELAS[i] + Vector2(0, 10)
		v.estacao = "altar"
		v.halo_a = 0.4
		v.nucleo_a = 0.6
	var est := _pos_alvo("estatuas")
	if est != Vector2.ZERO:
		var rubi := _nova_chama(est + Vector2(-28, -46), Color(1.0, 0.3, 0.25), 0.5, 3.3, false, Vector2.ZERO, Vector2i.ZERO)
		rubi.halo_a = 0.22
		rubi.estacao = "estatuas"
		var agua := _nova_chama(est + Vector2(-23, -18), Color(0.45, 0.9, 1.0), 0.55, 6.6, false, Vector2.ZERO, Vector2i.ZERO)
		agua.halo_a = 0.16
		agua.estacao = "estatuas"
	var cod := _pos_alvo("codice")
	if cod != Vector2.ZERO:
		var livro := _nova_chama(cod + Vector2(2, -53), Color(1.0, 0.85, 0.5), 0.8, 8.2, false, Vector2.ZERO, Vector2i.ZERO)
		livro.halo_a = 0.18
		livro.estacao = "codice"


# ------------------------------------------------------------------ melhorias compradas nas estações (item 7)


func _montar_estacoes() -> void:
	var tex_run: Array[Texture2D] = []
	for r in RUNAS:
		tex_run.append(_tex_bits(r, Color.WHITE, 1))
	_tex_runas = tex_run
	for est in _estacoes:
		est.pos = _pos_alvo(est.id)
		est.cor = {"estatuas": Paleta.OURO, "altar": Paleta.ALMA, "codice": Color(0.95, 0.88, 0.62)}.get(est.id, Paleta.OURO)
		est.aura = _spr(_tex_banda(_par(120), _par(84), 6, 1.5), est.pos + Vector2(0, -40))
		for i in N_RUNAS:
			var a := lerpf(0.14, 0.86, float(i) / float(N_RUNAS - 1)) * PI
			var r := _spr(_tex_runas[i % _tex_runas.size()], Vector2.ZERO)
			r.centered = false
			r.position = (est.pos + Vector2(0, -11) + Vector2(cos(a) * 42.0, sin(a) * 12.0)).round() - Vector2(2, 2)
			est.runas.append(r)


# ------------------------------------------------------------------ luzes reais (item 2)


func _montar_luzes() -> void:
	var tipos := {
		"tocha": {"r": 430.0, "e": 1.6, "h": 45.0, "cor": [COR_TOCHA.r, COR_TOCHA.g, COR_TOCHA.b]},
		"altar": {"r": 430.0, "e": 1.9, "h": 50.0, "cor": [0.72, 0.45, 1.0]},
		"salao": {"r": 520.0, "e": 0.8, "h": 60.0, "cor": [1.0, 0.82, 0.6]},
		"estatuas": {"r": 190.0, "e": 0.7, "h": 40.0, "cor": [0.95, 0.6, 0.45]},
		"codice": {"r": 190.0, "e": 0.75, "h": 40.0, "cor": [1.0, 0.85, 0.5]},
		"emblema": {"r": 300.0, "e": 0.6, "h": 30.0, "cor": [0.85, 0.75, 0.55]}
	}
	for p in _portais:
		var cor: Color = p.cor.lerp(Color.WHITE, 0.1)
		tipos["portal_" + p.id] = {"r": 400.0, "e": 0.5 if p.fechado else 1.6, "h": 45.0, "cor": [cor.r, cor.g, cor.b]}
	_luzes = Luzes.new()
	_luzes.montar(_mundo, null, null, tipos)
	_luzes.orcamento = lim_luzes
	var lista: Array = []
	if lim_luzes <= 2:
		lista = [["altar", _altar + Vector2(-14, -50), null], ["salao", Vector2(480, 160), null]]
	else:
		lista = [["tocha", TOCHAS[0] + Vector2(8, 4), null], ["tocha", TOCHAS[1] + Vector2(-8, 4), null], ["altar", _altar + Vector2(-14, -50), null]]
		for p in _portais:
			lista.append(["portal_" + p.id, p.pos + Vector2(0, -70), p])
		if lim_luzes >= 10:
			lista.append(["estatuas", _pos_alvo("estatuas") + Vector2(-10, -40), null])
			lista.append(["codice", _pos_alvo("codice") + Vector2(2, -45), null])
			lista.append(["emblema", Vector2(480, 305), null])
	for i in lista.size():
		var item: Array = lista[i]
		var e: Luzes.Entrada = _luzes.criar(str(item[0]), item[1])
		var info := {"e": e, "base": item[1], "en": e.energia, "sem": float(i) * 1.7 + 0.3, "tipo": str(item[0]), "portal": item[2]}
		if item[2] != null:
			(item[2] as Portal).info = info
		_infos_luz.append(info)


func _montar_sombra_heroi() -> void:
	var tex: Texture2D = _ctx._sprite
	if modo_sombra < Sombras.MEDIA or tex == null:
		return  # em Baixo fica a mancha oval que o próprio herói já desenha
	var im := tex.get_image()
	if im == null or im.is_empty():
		return
	var w: int = _ctx._quadro_w
	var h: int = _ctx._quadro_h
	_sombras = Sombras.new()
	_sombras.luzes = _luzes
	_sombras.montar(_mundo)
	_sombras.raiz_blobs.z_index = 0  # entre o cenário e o herói, na ordem da árvore
	_sombras.raiz_sombras.z_index = 0
	_sombras.modo = modo_sombra
	_sombras.definir_ambiente({"e": 0.5, "ang": 90.0, "comp": 0.3})
	_ator = Ator.new()
	_ator.chave = "heroi"
	_ator.raiz = Ator.Ponto.new()
	_ator.alt = float(h) - 3.0
	_ator.esc = _ctx.ESCALA
	_ator.rmax = 1.0
	_ator.offset = Vector2(-w / 2.0, -h + 3.0)
	_ator.regiao = Rect2(0, 0, w, h)
	_ator.tex_n = tex
	_ator.tex_b = Sombras.borrar_folha(im, w, h)
	_ator.larg_blob = w * _ctx.ESCALA * 0.75
	_sombras.registrar_lote([_ator])
	_sombras.definir_modo(modo_sombra)
	_sombras.ativar(_ator, true)
	_ator.blob.visible = false  # a mancha dos pés já existe no desenho do herói
	# a ordem na árvore: as sombras ficam antes do herói (o herói foi movido para o fim de _mundo mais abaixo)
	_mundo.move_child(_ctx._heroi, _mundo.get_child_count() - 1)


# ------------------------------------------------------------------ névoa rasteira (item 8)


func _montar_nevoa() -> void:
	if not com_nevoa:
		return
	_nevoa = Sprite2D.new()
	_nevoa.texture = _imagem_cor(Color.WHITE, 1, 1)
	_nevoa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_nevoa.centered = false
	_nevoa.position = NEVOA_RECT.position
	_nevoa.scale = NEVOA_RECT.size
	_mat_nevoa = ShaderMaterial.new()
	_mat_nevoa.shader = Sombreador
	_mat_nevoa.set_shader_parameter("modo", 1)
	_mat_nevoa.set_shader_parameter("cor", Color(0.62, 0.68, 0.85))
	_mat_nevoa.set_shader_parameter("tam", Vector2(NEVOA_RECT.size.x / 4.0, NEVOA_RECT.size.y / 4.0))
	_nevoa.material = _mat_nevoa
	_fx.add_child(_nevoa)


# ------------------------------------------------------------------ partículas (item 4)


func _rampa(pontos: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cores := PackedColorArray()
	for p in pontos:
		offs.append(float(p[0]))
		cores.append(p[1])
	g.offsets = offs
	g.colors = cores
	return g


func _emissor(pos: Vector2, n: int, vida: float, rampa: Gradient, aditivo := true) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = maxi(n, 1)
	p.lifetime = vida
	p.preprocess = vida
	p.local_coords = false
	p.texture = _tex_ponto
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = rampa
	p.position = pos.round()
	if aditivo:
		p.material = _mat_add
	_fx.add_child(p)
	_particulas.append(p)
	return p


func _n(parte: float) -> int:
	return maxi(1, roundi(total_particulas * parte))


func _montar_particulas() -> void:
	if total_particulas <= 0:
		return
	# brasas das tochas
	for t in TOCHAS:
		var b := _emissor(
			t + Vector2(0, -4), _n(0.08), 1.7, _rampa([[0.0, Color(1, 0.85, 0.45, 0.0)], [0.12, Color(1, 0.75, 0.3, 1)], [1.0, Color(0.9, 0.2, 0.05, 0)]])
		)
		b.direction = Vector2(0, -1)
		b.spread = 28.0
		b.initial_velocity_min = 9.0
		b.initial_velocity_max = 26.0
		b.gravity = Vector2(0, -5)
	# poeira nos feixes de luz dos portais abertos
	for p in _portais:
		if p.fechado:
			continue
		var d := _emissor(
			p.pos + Vector2(0, -34),
			_n(0.04),
			5.0,
			_rampa([[0.0, Color(1, 1, 1, 0)], [0.25, Color(1, 1, 1, 0.7)], [0.75, Color(1, 1, 1, 0.5)], [1.0, Color(1, 1, 1, 0)]])
		)
		d.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		d.emission_rect_extents = Vector2(22, 34)
		d.direction = Vector2(0.4, -1)
		d.spread = 70.0
		d.initial_velocity_min = 2.0
		d.initial_velocity_max = 7.0
		d.color = p.cor.lerp(Color.WHITE, 0.6)
	# esporos e vaga-lumes verdes junto à Floresta
	var flo := _pos_alvo("floresta")
	if flo != Vector2.ZERO:
		var e := _emissor(
			flo + Vector2(0, -62),
			_n(0.12),
			4.5,
			_rampa([[0.0, Color(1, 1, 1, 0)], [0.3, Color(1, 1, 1, 1)], [0.6, Color(1, 1, 1, 0.15)], [0.8, Color(1, 1, 1, 0.9)], [1.0, Color(1, 1, 1, 0)]])
		)
		e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = 52.0
		e.direction = Vector2(0, -1)
		e.spread = 180.0
		e.initial_velocity_min = 3.0
		e.initial_velocity_max = 9.0
		e.color = Color(0.55, 1.0, 0.45)
	# fagulhas violeta do altar
	var fa := _emissor(_altar + CRISTAL, _n(0.1), 1.4, _rampa([[0.0, Color(0.9, 0.7, 1, 0)], [0.15, Color(0.85, 0.6, 1, 1)], [1.0, Color(0.5, 0.2, 1, 0)]]))
	fa.direction = Vector2(0, -1)
	fa.spread = 55.0
	fa.initial_velocity_min = 12.0
	fa.initial_velocity_max = 32.0
	fa.gravity = Vector2(0, 8)
	# partículas extras de cada estação, crescem com o nível comprado
	for est in _estacoes:
		est.base_particulas = _n(0.06)
		var x := _emissor(
			est.pos + Vector2(0, -44), est.base_particulas, 2.2, _rampa([[0.0, Color(1, 1, 1, 0)], [0.25, Color(1, 1, 1, 0.9)], [1.0, Color(1, 1, 1, 0)]])
		)
		x.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		x.emission_rect_extents = Vector2(32, 22)
		x.direction = Vector2(0, -1)
		x.spread = 30.0
		x.initial_velocity_min = 5.0
		x.initial_velocity_max = 15.0
		x.color = est.cor
		est.emissor = x
	# poeira dos pés ao andar e do tapete
	_po_pes = _emissor(
		Vector2(480, 400),
		_n(0.08),
		0.5,
		_rampa([[0.0, Color(0.66, 0.62, 0.56, 0.0)], [0.1, Color(0.66, 0.62, 0.56, 0.7)], [1.0, Color(0.5, 0.47, 0.45, 0)]]),
		false
	)
	_po_pes.direction = Vector2(0, -1)
	_po_pes.spread = 90.0
	_po_pes.initial_velocity_min = 6.0
	_po_pes.initial_velocity_max = 18.0
	_po_pes.gravity = Vector2(0, 14)
	_po_pes.emitting = false
	_po_tapete = _emissor(
		Vector2(480, 480),
		_n(0.06),
		0.9,
		_rampa([[0.0, Color(0.7, 0.55, 0.78, 0.0)], [0.15, Color(0.74, 0.6, 0.82, 0.6)], [1.0, Color(0.6, 0.5, 0.7, 0)]]),
		false
	)
	_po_tapete.direction = Vector2(0, -1)
	_po_tapete.spread = 60.0
	_po_tapete.initial_velocity_min = 4.0
	_po_tapete.initial_velocity_max = 12.0
	_po_tapete.gravity = Vector2(0, -3)
	_po_tapete.emitting = false


## Runas, aura e partículas de cada estação conforme o que foi comprado. Roda no montar e quando o painel fecha.
func _aplicar_niveis() -> void:
	for ch in _chamas:
		var dono := _estacao(ch.estacao)
		if dono != null:
			ch.forca = 0.75 + 0.9 * dono.frac
	for est in _estacoes:
		var acesas := 0 if est.soma <= 0 else clampi(roundi(est.frac * N_RUNAS), 1, N_RUNAS)
		for i in est.runas.size():
			est.runas[i].visible = i < acesas
			est.runas[i].modulate = Color(est.cor.r, est.cor.g, est.cor.b, 0.0)
		est.aura.visible = est.soma > 0
		if est.emissor != null:
			est.emissor.amount = maxi(1, roundi(est.base_particulas * (0.3 + 0.7 * est.frac)))
			est.emissor.emitting = est.soma > 0


# ------------------------------------------------------------------ quadro


func _flick(sem: float, vel := 6.0) -> float:
	var n := _ruido.get_noise_1d(_tempo * vel + sem * 37.0)
	var s := sin(_tempo * 11.3 + sem) * sin(_tempo * 4.7 + sem * 2.1)
	return clampf(1.0 + 0.36 * n + 0.07 * s, 0.55, 1.45)


func _jitter(sem: float, px: float) -> Vector2:
	return Vector2(roundf(_ruido.get_noise_2d(_tempo * 2.4 + sem * 13.0, 0.5) * px), roundf(_ruido.get_noise_2d(0.5, _tempo * 2.4 + sem * 29.0) * px))


func _process(dt: float) -> void:
	var c = _ctx
	if c == null or c.pausa == null:
		return
	var parado: bool = c._painel.visible or c.pausa.aberto
	if parado != _congelado:
		_congelado = parado
		_glow.process_mode = Node.PROCESS_MODE_DISABLED if parado else Node.PROCESS_MODE_INHERIT
		for p in _particulas:
			p.speed_scale = 0.0 if parado else 1.0  # congela também a simulação interna da engine
	if _painel_antes and not c._painel.visible:
		_ler_niveis_e_aplicar()
	_painel_antes = c._painel.visible
	if parado:
		return
	if _perfil_pendente:
		_reaplicar_perfil.call_deferred()
	dt = minf(dt, 0.05)
	_tempo += dt
	var pos: Vector2 = c._pos
	var vel := (pos - _pos_ant) / maxf(dt, 0.0001)
	_pos_ant = pos
	var andando: bool = c._quadro > 0
	_heroi_vivo(c, pos, andando)
	var ciclo := 1.0 + (AMPLITUDE_CICLO * sin(TAU * _tempo / PERIODO_CICLO) if com_ciclo else 0.0)
	if _modulador != null:
		_modulador.color = Color(MODULADO.r * ciclo, MODULADO.g * ciclo, MODULADO.b * ciclo)
	for ch in _chamas:
		_chama(ch, dt, pos, vel, ciclo)
	for p in _portais:
		_portal(p, dt, pos, ciclo)
	for est in _estacoes:
		_estacao_vivo(est, ciclo)
	_luzes_vivas(pos, ciclo)
	if _sombras != null:
		_ator.raiz.position = pos.round()
		var r := Rect2(c._quadro * c._quadro_w, c._dir * c._quadro_h, c._quadro_w, c._quadro_h)
		_ator.sh1.region_rect = r
		_ator.sh2.region_rect = r
		_sombras.atualizar(_ator, _tempo)
	if _mat_nevoa != null:
		_mat_nevoa.set_shader_parameter("t", _tempo)
		_mat_nevoa.set_shader_parameter("forca", ciclo)
	if _po_pes != null:
		_po_pes.position = (pos + Vector2(0, -1)).round()
		_po_pes.emitting = andando
		_po_tapete.position = (pos + Vector2(0, -1)).round()
		_po_tapete.emitting = andando and TAPETE.has_point(pos)


func _ler_niveis_e_aplicar() -> void:
	_ler_niveis()
	_aplicar_niveis()


# ------------------------------------------------------------------ herói (itens 5 e 6)


func _heroi_vivo(c, pos: Vector2, andando: bool) -> void:
	var resp := 0.0
	if not andando:
		resp = -1.0 if fmod(_tempo, 2.6) < 1.3 else 0.0  # respiração de 1 px, em pixel inteiro
		var alvo_id := str(c._prompt_de)
		if alvo_id != "":
			for a in c._alvos:
				if str(a.id) == alvo_id:
					var dir: int = c._linha_de(a.pos - pos)
					if dir != c._dir:
						c._dir = dir  # olha para o alvo do prompt
						c._heroi.queue_redraw()
					break
	c._heroi.position = pos.round() + Vector2(0, resp)


func _chama(ch: Chama, dt: float, heroi: Vector2, vel: Vector2, ciclo: float) -> void:
	var f := _flick(ch.semente)
	if ch.mola:
		var d := heroi.distance_to(ch.reativo)
		var prox := clampf(1.0 - d / ALCANCE_MOLA, 0.0, 1.0)
		if prox > 0.0:
			var lado := 1.0 if ch.pos.x > heroi.x else -1.0
			ch.v += lado * vel.length() * prox * 1.6 * dt
		ch.v += (-MOLA_K * ch.x - MOLA_C * ch.v) * dt
		ch.x = clampf(ch.x + ch.v * dt, -4.0, 4.0)
	var desl := Vector2(roundf(ch.x), 0.0)
	var base := ch.pos + desl
	var k := ch.forca * ciclo
	ch.halo.position = (ch.pos + Vector2(roundf(ch.x * 0.5), 0.0) + _jitter(ch.semente, 1.0)).round()
	ch.halo.modulate = Color(ch.cor.r, ch.cor.g, ch.cor.b, ch.halo_a * f * k)
	ch.nucleo.position = (base + _jitter(ch.semente + 3.0, 1.0)).round()
	ch.nucleo.modulate = Color(ch.cor.r, ch.cor.g, ch.cor.b, ch.nucleo_a * f * k).lerp(Color(1, 1, 1, ch.nucleo_a * f * k), 0.35)
	if ch.poca != null:
		ch.poca.modulate = Color(ch.cor.r, ch.cor.g, ch.cor.b, ch.poca_a * (0.8 + 0.4 * (f - 0.55) / 0.9) * k)
	if ch.lingua != null:
		var idx := 0 if f < 0.82 else (1 if f < 1.12 else 2)
		var tex := ch.linguas[idx]
		ch.lingua.texture = tex
		ch.lingua.position = (base + Vector2(-(tex.get_width() - 1) / 2, ch.pe - tex.get_height()) + _jitter(ch.semente + 7.0, 1.0) * Vector2(1, 0)).round()
		ch.lingua.modulate = Color(1, 1, 1, clampf(0.55 + 0.4 * f, 0.4, 1.0))


func _portal(p: Portal, dt: float, heroi: Vector2, ciclo: float) -> void:
	var perto := 1.0 if heroi.distance_to(p.pos) < ALCANCE_PORTAL else 0.0
	p.reacao = lerpf(p.reacao, perto, 1.0 - exp(-5.0 * dt))
	var respira := 0.82 + 0.18 * sin(_tempo * 1.4 + p.fase) + 0.06 * sin(_tempo * 3.7 + p.fase * 2.0)
	var r := 1.0 + 0.6 * p.reacao
	if p.fechado:
		var pulso := 0.5 + 0.5 * sin(_tempo * 2.2 + p.fase)
		p.cadeado.modulate = Color(1, 0.8, 0.35, 0.1 + 0.4 * pulso)
		p.halo.modulate = Color(1, 0.75, 0.3, 0.04 + 0.12 * pulso)
		p.poca.modulate = Color(1, 0.75, 0.3, 0.03 + 0.07 * pulso)
		return
	p.mat.set_shader_parameter("t", _tempo + p.fase * 5.0)
	p.mat.set_shader_parameter("forca", respira * r * ciclo)
	var cl := Color(p.cor.r, p.cor.g, p.cor.b)
	p.halo.modulate = Color(cl.r, cl.g, cl.b, 0.2 * respira * r)
	p.poca.modulate = Color(cl.r, cl.g, cl.b, 0.22 * respira * r)


func _estacao_vivo(est: Estacao, ciclo: float) -> void:
	if est.soma <= 0:
		return
	var f := est.frac
	var pulso := 0.5 + 0.5 * sin(_tempo * 1.1 + est.pos.x)
	est.aura.modulate = Color(est.cor.r, est.cor.g, est.cor.b, (0.05 + 0.2 * f) * (0.75 + 0.25 * pulso) * ciclo)
	for i in est.runas.size():
		if not est.runas[i].visible:
			continue
		var b := 0.5 + 0.5 * sin(_tempo * 1.7 + float(i) * 0.9 + est.pos.y)
		est.runas[i].modulate = Color(est.cor.r, est.cor.g, est.cor.b, (0.35 + 0.5 * f) * (0.55 + 0.45 * b) * ciclo)


func _luzes_vivas(heroi: Vector2, ciclo: float) -> void:
	for info in _infos_luz:
		var e: Luzes.Entrada = info.e
		var base: Vector2 = info.base
		var sem: float = info.sem
		var tipo: String = info.tipo
		var en: float = _luzes.tipos[tipo].e
		var j := Vector2.ZERO
		match tipo:
			"tocha", "altar":
				en *= _flick(sem + 0.4)
				j = _jitter(sem, 1.5)
			"salao":
				en *= 0.95 + 0.05 * sin(_tempo * 1.3)
			"emblema":
				en *= 0.8 + 0.2 * sin(_tempo * 0.8)
			_:
				if tipo.begins_with("portal_"):
					var p: Portal = info.portal
					en *= (0.85 + 0.15 * sin(_tempo * 1.4 + p.fase) + 0.05 * sin(_tempo * 3.7 + p.fase * 2.0)) * (1.0 + 0.5 * p.reacao)
					j = _jitter(sem, 1.0)
				else:
					en *= _flick(sem, 3.0)
		e.energia = en * ciclo
		e.pos = (base + j).round()
	_luzes.atualizar(_tempo, Rect2(heroi - Vector2(LARG / 2.0, ALT / 2.0), Vector2(LARG, ALT)))
