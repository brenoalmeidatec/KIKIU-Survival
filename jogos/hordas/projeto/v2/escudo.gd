extends RefCounted
## O tiro SECUNDÁRIO da v2 (botão direito do mouse ou gatilho esquerdo), no padrão Overwatch: botão direito = secundário (definido por herói),
## E / LB = habilidade (a ruptura, v2/ruptura.gd), Q / RB = especial (um por herói, v2/especial.gd). Para o herói de hoje o
## secundário é o ESCUDO: segurar ergue um escudo na frente do herói (arco de ~120 graus na direção da mira) que bloqueia o dano que vem de
## dentro do arco (contato dos monstros, ataques anunciados e ataques do chefe). O herói anda a ~60%, não corre nem golpeia e o escudo gasta o
## MESMO fôlego da corrida; zerar o fôlego deixa cansado e o escudo cai. Bloqueio PERFEITO (nos primeiros ~0,15 s depois de erguer): não gasta
## fôlego e empurra e atordoa quem bateu. Soltar volta ao fôlego normal.
##
## Qual secundário cada herói tem é DADO (dados/v2_secundario.json > padrao e herois > chave do herói), para que a branch de heróis mapeie
## outro secundário depois sem mexer no código: aqui só existe o id "escudo"; id desconhecido deixa o botão direito sem efeito.
##
## O herói (v2/heroi.gd) cuida da entrada e do estado (`escudo_ativo`, `escudo_t`, velocidade, fôlego); este módulo cuida da geometria
## (`cobre`), do bloqueio (`bloquear`), do visual e do som. Dono: o combate (`combate.escudo`).
##
## O VISUAL é um escudo de verdade, um por personagem (pixel art de assets/v2/escudos/<id>.png, gerada por fonte_arte/escudos/gerar_escudos.py): uma faixa de 8
## células 32x32 (frente, lado, costas, rachado e 4 pedaços). O Sprite2D fica no mundo (y-sort: passa por trás do herói quando a mira vai para cima), na
## mira, a `distancia * raio` do herói, e troca de vista pelo ângulo. A animação é toda em código no relógio de parede (`efeitos`): ergue com um pulo,
## treme e solta faísca ao aparar, racha quando o fôlego está no fim (só o quadro de frente racha; de lado e de costas o aviso é o escudo avermelhado pulsando; os pedaços da quebra são sempre os da frente), QUEBRA em 4 pedaços que caem (fôlego zerou: o escudo cai) e volta "reforjado"
## no próximo erguer. Nada do visual muda a regra: `cobre`, `arco`, `raio` e `bloquear` seguem iguais. Perfil Baixo (sem partículas): sem tremor, faísca,
## estouro nem pedaços, só some e aparece. O clarão do acerto é um sprite aditivo filho do escudo (dentro do y-sort); o Node2D aditivo da camada glow (`no`) ficou só para as faíscas. A cobertura (arco por nível) não aparece no desenho.
##
## API: montar(c, camada), limpar(), id_de(chave) -> String, ativo_para(chave) -> bool, para_heroi(chave), cobre(h, de) -> bool, raio(h) -> float, arco(h) -> float, pontos_do_arco(h),
## ergueu(h), abaixou(h), bloquear(h, valor, de, quem) -> bool [perfeito?], efeitos(dt) [relógio de parede: o visual], resumo().

const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (a mesma da ruptura e dos avisos)
const COR_AZUL := Color(0.45, 0.82, 1.0)
const COR_OURO := Color(1.0, 0.85, 0.3)
const PTS := 20  # pontos do arco de cobertura (só para medir)
const FRENTE := 0  # células da faixa do escudo
const LADO := 1
const COSTAS := 2
const RACHADO := 3
const PEDACO := 4  # 4..7
const CEL := 32
const GRAVIDADE := 420.0  # px/s2 dos pedaços
const Piscadas := preload("res://v2/piscadas.gd")  # "Reduzir piscadas": o escudo não solta clarão no bloqueio
const Herois := preload("res://v2/herois.gd")  # a folha da partida decide qual escudo desenhar
const Progresso := preload("res://v2/progresso.gd")  # bonus_por_nivel: o crescimento do raio por nível (a mesma regra do golpe, outra tabela)

var combate
var mundo
var cfg: Dictionary = {}  # dados/v2_secundario.json > escudo
var padrao := "escudo"
var herois: Dictionary = {}  # chave do herói -> id do secundário (os testes mexem aqui)
var no: Node2D
var bloqueios := 0  # testes: quantos golpes o escudo já barrou
var perfeitos := 0  # testes: quantos foram perfeitos
var ultimo: Dictionary = {}  # o último bloqueio (testes): perfeito, valor, empurrao, atordoa
var _flash_t := 0.0  # s do clarão do último bloqueio (comum)
var _perf_t := 0.0  # s do clarão dourado do bloqueio perfeito
var _desenhou := false
var _impacto := Vector2.ZERO
var visual: Dictionary = {}  # dados/v2_secundario.json > escudo > visual
var _raiz: Node2D  # o escudo no mundo (y-sort), com `_spr` dentro
var _spr: Sprite2D
var _bri: Sprite2D  # o clarão aditivo do escudo (filho de `_raiz`)
var _frags: Array = []  # 4 Sprite2D soltos no mundo (a quebra)
var _fv: Array = []  # estado de cada pedaço: {x, gy, z, vx, vz, rot, vrot, t}
var _tex: Texture2D  # guardado: o `load` solto devolve outra textura a cada uso
var _estilo := ""
var _sobe_t := 9.0  # s desde que ergueu
var _sobe_dur := 0.1
var _desce_t := 9.0  # s desde que soltou (voluntário)
var _treme_t := 0.0
var _treme_dur := 0.16
var _glint_t := 0.0  # clarão do "reforjado" e do aparo perfeito
var _quebra_t := 99.0  # s desde a quebra
var _quebrado := false  # o último erguer terminou em quebra: o próximo volta reforjado
var _celula := -1
var _flip := false
var _relogio := 0.0
var rachado_visivel := false  # testes: o quadro de agora é o rachado


func montar(c, camada: Node) -> void:
	combate = c
	mundo = c.mundo
	var d: Dictionary = Dados.json("v2_secundario")
	cfg = d.escudo
	padrao = str(d.get("padrao", "escudo"))
	herois = d.get("herois", {})
	visual = cfg.get("visual", {})
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no = Node2D.new()
	no.material = mat
	no.draw.connect(_desenhar)
	camada.add_child(no)


## Partida nova.
func limpar() -> void:
	bloqueios = 0
	perfeitos = 0
	ultimo = {}
	_flash_t = 0.0
	_perf_t = 0.0
	_desenhou = false
	_sobe_t = 9.0
	_desce_t = 9.0
	_treme_t = 0.0
	_glint_t = 0.0
	_quebra_t = 99.0
	_quebrado = false
	_celula = -1
	rachado_visivel = false
	_esconder_tudo()
	if no != null:
		no.queue_redraw()


## O id do secundário do herói `chave` (dados > herois, senão o padrão).
func id_de(chave: String) -> String:
	return str(herois.get(chave, padrao))


## O secundário deste herói é o escudo?
func ativo_para(chave: String) -> bool:
	return id_de(chave) == "escudo"


## O raio do escudo deste herói agora (a distância do sprite e a cobertura): o do dado MAIS o crescimento por nível (dados > escudo.raio_por_nivel). Não usa a área das cartas
## (h.m_area): o escudo do nível 1 é o de antes, para todo herói. Lido pela distância do sprite à frente do herói (`_deslocamento`) e pelo ponto da faísca.
func raio(h) -> float:
	return float(cfg.raio) * (1.0 + Progresso.bonus_por_nivel(int(h.nivel), cfg.raio_por_nivel))


## A abertura do escudo deste herói agora, em graus: a do dado MAIS o crescimento por nível (dados > escudo.arco_por_nivel). É a COBERTURA
## do bloqueio (`cobre` barra tudo o que vem dentro dela). O sprite tem o mesmo tamanho em qualquer nível: o ganho de cobertura NÃO aparece no desenho.
func arco(h) -> float:
	return float(cfg.arco) + Progresso.bonus_por_nivel(int(h.nivel), cfg.arco_por_nivel)


## Os pontos do arco de COBERTURA do escudo no chão (projetados na tela, de `h.pos + (0, -8)`): a geometria do bloqueio (raio e abertura) para os
## testes medirem. Não é desenhada: o visual é o sprite.
func pontos_do_arco(h) -> PackedVector2Array:
	var c: Vector2 = h.pos + Vector2(0, -8)
	var a0: float = atan2(h.dir_olhar.y / ACHATA, h.dir_olhar.x)  # o ângulo no chão, de volta para a tela
	var meio := deg_to_rad(arco(h) * 0.5)
	var r := raio(h)
	var pts := PackedVector2Array()
	for i in PTS + 1:
		var a := a0 - meio + 2.0 * meio * float(i) / float(PTS)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * ACHATA))
	return pts


## O dano que vem de `de` (posição no mundo) cai dentro do arco do escudo? A conta é no chão (y dividido pela achatada), a mesma da ruptura e dos avisos.
func cobre(h, de: Vector2) -> bool:
	var rel: Vector2 = de - h.pos
	rel = Vector2(rel.x, rel.y / ACHATA)
	if rel.length() < 0.5:
		return true  # em cima do herói: vem da frente de quem está encostado
	var d := Vector2(h.dir_olhar.x, h.dir_olhar.y / ACHATA).normalized()
	return rel.normalized().dot(d) >= cos(deg_to_rad(arco(h) * 0.5))


func ergueu(h) -> void:
	combate.audio.tocar("ruptura_tique", 1.5, -6.0, 0.05)
	_sobe_t = 0.0
	_desce_t = 9.0
	_sobe_dur = float(visual.get("sobe_s", 0.1))
	if _quebrado:  # volta reforjado: mais devagar, com um brilho que corre pelo escudo
		_quebrado = false
		_sobe_dur = float(visual.get("volta_s", 0.24))
		_glint_t = 0.24
		combate.audio.tocar("ruptura_tique", 1.9, -4.0, 0.0)
	_carregar(h)


## Soltou o botão ou o fôlego acabou: `h.cansado` quer dizer que o escudo CAIU (quebra, pedaços no chão); senão ele só desce.
func abaixou(h) -> void:
	if h != null and h.cansado and _raiz != null and _raiz.visible:
		_quebrar(h)
	else:
		_desce_t = 0.0


## O herói barrou um golpe de `valor` que vinha de `de`; `quem` é o monstro que bateu (null: ataque de área, sem alvo para empurrar).
## Devolve true se foi PERFEITO. Comum: gasta um pouco de fôlego e empurra de leve; perfeito: não gasta e empurra e atordoa forte.
func bloquear(h, valor: float, de: Vector2, quem) -> bool:
	var perfeito: bool = h.escudo_t <= float((cfg.perfeito as Dictionary).janela)
	bloqueios += 1
	h.escudo_bloqueios += 1
	var p: Dictionary = cfg.perfeito
	var emp: float = float(p.empurrao) if perfeito else float(cfg.empurrao)
	var atordoa: float = float(p.atordoa) if perfeito else 0.0
	if perfeito:
		perfeitos += 1
		h.escudo_perfeitos += 1
	else:
		h._gastar(float(cfg.gasto_golpe))
	if quem != null:
		var longe: Vector2 = quem.pos - h.pos
		longe = longe.normalized() if longe.length() > 0.5 else h.dir_olhar
		quem.apanhar(0.0, longe * emp, atordoa)  # dano zero: só empurra e atordoa (elite vale metade e chefe nada, como em qualquer golpe)
	ultimo = {"perfeito": perfeito, "valor": valor, "empurrao": emp, "atordoa": atordoa}
	# o clarão, as faíscas e o som
	var fx = combate.fx
	var entrada := Vector2(de.x - h.pos.x, (de.y - h.pos.y) / ACHATA).normalized()
	if entrada.length_squared() < 0.1:
		entrada = Vector2(h.dir_olhar.x, h.dir_olhar.y / ACHATA).normalized()
	var para := Vector2(entrada.x, entrada.y * ACHATA)
	_impacto = _deslocamento(h) + para * 6.0 + Vector2(0, float(visual.get("centro_y", -15.0)))  # na superfície do escudo, do lado de quem bateu
	_treme_dur = 0.24 if perfeito else 0.16
	_treme_t = _treme_dur
	if perfeito:
		_glint_t = 0.2
	var ponto: Vector2 = h.pos + _impacto
	var cor := COR_OURO if perfeito else COR_AZUL
	if not _leve():  # perfil Baixo: sem partículas (o estouro tem piso de cinco mesmo com a escala no mínimo)
		fx.estouro(ponto, cor, 6 if perfeito else 3)
	fx.luz_rapida(ponto, cor, 1.6, 40.0, 0.18)
	if perfeito:
		_perf_t = 0.22
		combate.audio.tocar("critico", 1.2, -2.0, 0.0)
		combate.audio.tocar("ruptura_tique", 1.25, 0.0, 0.0)
		combate.hit_stop(float(p.hit_stop))
		mundo.cam.tremer(float(p.tremor), 0.14)
	else:
		_flash_t = 0.14
		combate.audio.tocar("impacto", 0.7, -1.0, 0.04)
		mundo.cam.tremer(1.0, 0.08)
	return perfeito


## Os números de agora para o painel de status.
func resumo() -> Dictionary:
	return {
		"arco": arco(mundo.heroi) if mundo.heroi != null else float(cfg.arco),
		"mov": float(cfg.mov),
		"gasto": float(cfg.gasto),
		"perfeito_janela": float((cfg.perfeito as Dictionary).janela),
	}


## Onde o escudo fica em relação ao herói: na direção da mira (no chão, com a mesma achatada), a `distancia` do raio.
func _deslocamento(h) -> Vector2:
	var g := Vector2(h.dir_olhar.x, h.dir_olhar.y / ACHATA).normalized()
	return Vector2(g.x, g.y * ACHATA) * (raio(h) * float(visual.get("distancia", 0.6)))


## O perfil Baixo (partículas em "poucas" ou "nenhuma", efe_particulas abaixo de 0,5): sem tremor, faísca nem pedaços.
func _leve() -> bool:
	if mundo == null or not mundo.has_method("_nivel_particulas"):
		return false
	return float(mundo._nivel_particulas().get("efe_particulas", 1.0)) < 0.5


## Qual escudo o herói da partida usa: o da folha de sprites do personagem (o Matheus joga com o kit do Hazaki mas tem o escudo dele), senão o do herói.
func _estilo_de(h) -> String:
	var pasta := str(visual.get("pasta", ""))
	var folha := str(Herois.sprite_da_partida(combate.heroi_id))
	if folha != "" and ResourceLoader.exists(pasta + folha + ".png"):
		return folha
	if ResourceLoader.exists(pasta + str(h.chave) + ".png"):
		return str(h.chave)
	return ""


func _carregar(h) -> void:
	if not _garantir_visual():
		return
	var id := _estilo_de(h)
	if id != _estilo or _tex == null:
		_estilo = id
		_tex = load(str(visual.pasta) + id + ".png") as Texture2D if id != "" else null
		_spr.texture = _tex
		_bri.texture = _tex
		_celula = -1


## Cria (ou recria, se o mundo foi refeito) o sprite do escudo e os 4 pedaços dentro do mundo y-sort. false = sem mundo para pôr (testes com mundo falso).
func _garantir_visual() -> bool:
	if visual.is_empty() or mundo == null:
		return false
	var pai = mundo.get("no_mundo")
	if pai == null:
		return false
	if _raiz != null and is_instance_valid(_raiz) and _raiz.get_parent() == pai:
		return true
	for f in _frags:
		if is_instance_valid(f):
			f.queue_free()
	_frags = []
	_fv = []
	_raiz = Node2D.new()
	_raiz.visible = false
	pai.add_child(_raiz)
	_spr = Sprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.region_enabled = true
	_raiz.add_child(_spr)
	_bri = Sprite2D.new()  # o clarão: o mesmo quadro por cima, aditivo, DENTRO do y-sort (na camada glow ele passaria por cima do herói de costas)
	_bri.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bri.region_enabled = true
	_bri.visible = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bri.material = mat
	_raiz.add_child(_bri)
	for i in 4:
		var f := Sprite2D.new()
		f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		f.region_enabled = true
		f.centered = false
		f.visible = false
		pai.add_child(f)
		_frags.append(f)
		_fv.append({})
	_celula = -1
	return true


func _esconder_tudo() -> void:
	if _raiz != null and is_instance_valid(_raiz):
		_raiz.visible = false
	for i in _frags.size():
		if is_instance_valid(_frags[i]):
			_frags[i].visible = false
		_fv[i] = {}


## O escudo cai: o quadro some e 4 pedaços saltam para fora, caem com gravidade, quicam uma vez e se apagam. No perfil Baixo só some.
func _quebrar(_h) -> void:
	_quebrado = true
	_quebra_t = 0.0
	_glint_t = 0.0
	_celula = RACHADO
	_flip = false
	_raiz.visible = false
	combate.audio.tocar("impacto", 0.55, 0.0, 0.05)
	combate.audio.tocar("critico", 0.7, -4.0, 0.0)
	if _tex == null or _leve() or _frags.size() < 4:
		return
	var cy := float(visual.get("centro_y", -15.0))
	var cents: Array = (visual.get("fragmentos", {}) as Dictionary).get(_estilo, [])
	var centro: Vector2 = _raiz.position + Vector2(0, cy)
	for i in 4:
		var c := Vector2(float(cents[i][0]), float(cents[i][1])) if i < cents.size() else Vector2(16.0, 16.0)
		var fora := c - Vector2(16.0, 16.0)
		fora = fora.normalized() if fora.length() > 0.1 else Vector2.RIGHT
		var f: Sprite2D = _frags[i]
		f.texture = _tex
		f.region_rect = Rect2((PEDACO + i) * CEL, 0, CEL, CEL)
		f.offset = -c
		f.rotation = 0.0
		f.modulate = Color.WHITE
		f.visible = true
		_fv[i] = {
			"x": centro.x + c.x - 16.0,
			"gy": _raiz.position.y + float(i) - 1.5,
			"z": -cy + (16.0 - c.y),
			"vx": fora.x * randf_range(30.0, 55.0),
			"vz": randf_range(70.0, 120.0) + fora.y * -20.0,
			"rot": 0.0,
			"vrot": randf_range(-7.0, 7.0),
			"t": 0.0,
		}
	combate.fx.estouro(centro, Color(0.8, 0.7, 0.55), 4)


## O visual no relógio de parede: troca de vista, ergue, treme, racha, solta e cai. Só redesenha as faíscas enquanto há algo (e uma vez ao apagar).
func efeitos(dt: float) -> void:
	_relogio += dt
	_flash_t = maxf(_flash_t - dt, 0.0)
	_perf_t = maxf(_perf_t - dt, 0.0)
	_glint_t = maxf(_glint_t - dt, 0.0)
	_treme_t = maxf(_treme_t - dt, 0.0)
	_sobe_t = minf(_sobe_t + dt, 9.0)
	_desce_t = minf(_desce_t + dt, 9.0)
	_quebra_t = minf(_quebra_t + dt, 99.0)
	var h = mundo.heroi
	var ativo: bool = h != null and h.escudo_ativo
	_atualizar_sprite(h, ativo)
	_atualizar_pedacos(dt)
	var brilho := _flash_t > 0.0 or _perf_t > 0.0  # só as faíscas do acerto ficam na camada glow
	if brilho or _desenhou:
		_desenhou = brilho
		no.queue_redraw()


func _ease_back(x: float) -> float:
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _atualizar_sprite(h, ativo: bool) -> void:
	if _raiz == null or not is_instance_valid(_raiz) or _tex == null:
		return
	var dur_desce := float(visual.get("desce_s", 0.1))
	var descendo := _desce_t < dur_desce
	if h == null or not (ativo or descendo):
		_raiz.visible = false
		return
	var g := Vector2(h.dir_olhar.x, h.dir_olhar.y / ACHATA).normalized()
	var cel := LADO
	var flip := g.x < 0.0
	if g.y > 0.55:
		cel = FRENTE
		flip = false
	elif g.y < -0.55:
		cel = COSTAS
		flip = false
	var frac: float = float(h.folego) / maxf(float(h.folego_max), 0.001)
	var baixo := ativo and frac <= float(visual.get("folego_rachado", 0.25))  # fôlego no fim: o escudo está para quebrar
	rachado_visivel = baixo and cel == FRENTE
	if rachado_visivel:
		cel = RACHADO
	if cel != _celula:
		_celula = cel
		_spr.region_rect = Rect2(cel * CEL, 0, CEL, CEL)
	var leve := _leve()
	var esc := 1.0
	var alfa := 1.0
	var dy := 0.0
	if descendo and not ativo:
		var p := _desce_t / dur_desce
		esc = 1.0 - 0.3 * p
		alfa = 1.0 - p
		dy = 5.0 * p
	elif _sobe_t < _sobe_dur and not leve:
		var p := _sobe_t / _sobe_dur
		var k := _ease_back(p)
		esc = 0.55 + 0.45 * k
		dy = 7.0 * (1.0 - minf(k, 1.0))
		alfa = minf(p * 3.0, 1.0)
	if cel == COSTAS:
		dy += float(visual.get("costas_dy", 0.0))  # de costas o escudo sobe um pouco: sem isso o corpo do herói o esconde por inteiro
	var desl := Vector2.ZERO
	if not leve:
		if _treme_t > 0.0:  # aparou um golpe: recua para dentro e treme
			var a := _treme_t / _treme_dur
			desl = -Vector2(g.x, g.y * ACHATA) * 3.0 * a + Vector2(sin(_relogio * 95.0), cos(_relogio * 83.0)) * 1.5 * a
		elif baixo:
			desl = Vector2(sin(_relogio * 70.0) * 0.7, 0.0)
	var chao: Vector2 = h.pos + _deslocamento(h)
	chao.y += 0.6  # empate de y-sort: de lado, o escudo fica na frente do herói
	_raiz.position = chao.round()
	_spr.position = (Vector2(0, float(visual.get("centro_y", -15.0)) + dy) + desl).round()
	_spr.scale = Vector2(esc, esc)
	_spr.flip_h = flip
	var tom := Color(1, 1, 1, alfa)
	if baixo and not rachado_visivel:  # de lado ou de costas não há quadro rachado: o aviso é o escudo avermelhado, pulsando
		var pulso := 0.5 + 0.5 * sin(_relogio * 14.0)
		tom = Color(1.0, 0.82 - 0.2 * pulso, 0.78 - 0.2 * pulso, alfa)
	_spr.modulate = tom
	_raiz.visible = true
	var b := _brilho(h)
	_bri.visible = b.a > 0.0
	if _bri.visible:
		_bri.region_rect = _spr.region_rect
		_bri.position = _spr.position
		_bri.scale = _spr.scale
		_bri.flip_h = flip
		_bri.modulate = b
	_flip = flip


func _atualizar_pedacos(dt: float) -> void:
	if _quebra_t > 3.0:
		return
	var fim := float(visual.get("quebra_s", 0.9))
	for i in _fv.size():
		var v: Dictionary = _fv[i]
		if v.is_empty():
			continue
		v.t += dt
		v.vz -= GRAVIDADE * dt
		v.z += v.vz * dt
		v.x += v.vx * dt
		if v.z <= 0.0:
			v.z = 0.0
			v.vz = -v.vz * 0.3 if v.vz < -40.0 else 0.0
			v.vx *= 0.5
			v.vrot *= 0.5
		v.rot += v.vrot * dt
		var f: Sprite2D = _frags[i]
		f.position = Vector2(v.x, v.gy - v.z).round()
		f.rotation = v.rot
		f.modulate.a = clampf((fim - v.t) / 0.3, 0.0, 1.0)
		if v.t >= fim:
			f.visible = false
			_fv[i] = {}


## Os números do visual agora, para os testes: o escudo está à vista, qual estilo, a vista, e quantos pedaços ainda caem.
func visual_estado() -> Dictionary:
	var vivos := 0
	for f in _frags:
		if is_instance_valid(f) and f.visible:
			vivos += 1
	return {
		"visivel": _raiz != null and is_instance_valid(_raiz) and _raiz.visible,
		"estilo": _estilo,
		"celula": _celula,
		"rachado": rachado_visivel,
		"quebrado": _quebrado,
		"pedacos": vivos,
		"flip": _flip,
		"aviso": _spr != null and is_instance_valid(_spr) and _spr.modulate.g < 0.9,
		"pos": _raiz.position if _raiz != null and is_instance_valid(_raiz) else Vector2.ZERO,
	}


## A cor e o alfa do clarão aditivo do escudo agora: acerto comum (branco), bloqueio perfeito (dourado), reforjado e a janela do perfeito logo depois de erguer.
func _brilho(h) -> Color:
	var clarao := Piscadas.clarao_permitido()  # com "Reduzir piscadas" os clarões do bloqueio não acendem (a janela do perfeito, que cresce devagar, fica)
	if clarao and _perf_t > 0.0:
		return Color(COR_OURO.r, COR_OURO.g, COR_OURO.b, _perf_t / 0.22 * 0.8)
	if clarao and _flash_t > 0.0:
		return Color(1, 1, 1, _flash_t / 0.14 * 0.55)
	if clarao and _glint_t > 0.0:
		var c := COR_OURO.lerp(Color.WHITE, 0.5)
		return Color(c.r, c.g, c.b, sin(_glint_t / 0.24 * PI) * 0.6)
	var janela := float((cfg.perfeito as Dictionary).janela)
	if h.escudo_ativo and h.escudo_t <= janela:
		return Color(COR_OURO.r, COR_OURO.g, COR_OURO.b, 0.35 * (1.0 - h.escudo_t / maxf(janela, 0.001)))
	return Color(1, 1, 1, 0)


## O que sobrou no glow: as faíscas do acerto (o clarão do escudo é o `_bri`, dentro do y-sort).
func _desenhar() -> void:
	var h = mundo.heroi
	if h == null:
		return
	if (_flash_t > 0.0 or _perf_t > 0.0) and not _leve():
		var perfeito := _perf_t > 0.0
		var t := _perf_t / 0.22 if perfeito else _flash_t / 0.14
		var c2 := COR_OURO if perfeito else Color.WHITE
		var impacto: Vector2 = h.pos + _impacto
		var tamanho := (1.0 - t) * 16.0 + 5.0
		for i in 8 if perfeito else 4:
			var d := Vector2.from_angle(TAU * float(i) / (8.0 if perfeito else 4.0))
			no.draw_line(impacto + d * tamanho * 0.4, impacto + d * tamanho, Color(c2.r, c2.g, c2.b, t), 2.0)
		no.draw_circle(impacto, 3.0 * t, Color(1.0, 0.97, 0.8, t))
