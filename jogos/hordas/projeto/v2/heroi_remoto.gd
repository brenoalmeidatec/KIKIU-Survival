extends "res://v2/ator.gd"
## O herói de OUTRA pessoa no coop (docs/ONLINE_V2_PLANO.md, etapa 1): um corpo animado com o nome em cima, que segue o que a rede manda.
## Quem manda é o dono do herói (a cada 1/20 s, `Heroi.codificar`); aqui só se interpola a posição e se desenha o que chegou: andar, virar,
## o golpe (o mesmo arco de `combate.golpe_comecou`), a esquiva, o escudo erguido e o corpo caído. Não tem IA, colisão nem vida própria: o
## mundo o enxerga como um herói a mais em `mundo.herois` (pos, raio e vida são o que `alvo_mais_perto` lê).
## Pacote de 16 bytes: x f32 | y f32 | dir x s8 | dir y s8 | estado u8 | flags u8 (1 andando, 2 correndo, 4 escudo) | passo do combo u8 |
## golpes u16 (contador do dono, só cresce) | vida u8 (0 a 255).

const Heroi := preload("res://v2/heroi.gd")
const TAM := 16
const ORIGEM_GOLPE := Heroi.ORIGEM_GOLPE  # para combate.golpe_comecou
const SUAVIDADE := 16.0  # a posição chega a ~95% do alvo em 3/16 s (a foto vem a cada 50 ms)
const SALTO := 220.0  # mais longe que isso (teleporte, nascimento) o corpo vai direto

var mundo
var id := 0  # o peer do ENet
var nome := ""
var vida := 100.0  # >0 = vivo (é o que mundo.alvo_mais_perto lê)
var vida_max := 100.0
var contragolpe_t := 0.0  # para combate.golpe_comecou (o remoto nunca tem a janela do contragolpe)
var dir_olhar := Vector2(0, 1)
var estado := 0  # Heroi.Estado
var andando := false
var correndo := false
var escudo_ativo := false
var golpe_i := 0
var golpes := 0  # o contador que o dono mandou (0 a 65535)
var golpes_vistos := 0  # quantos golpes começaram DESTE lado (soma das diferenças do contador)
var pacotes := 0
var ultimo := PackedByteArray()  # o último pacote válido, como chegou (o anfitrião o repassa aos outros clientes)
var alvo := Vector2.ZERO  # a última posição que chegou
var _anim := 0.0
var _punch := 0.0
var _esq_t := 0.0
var _tem_golpes := false
var _tem_pos := false
var _off_base := Vector2.ZERO
var _rotulo: Label


## Os 16 bytes do herói local, prontos para enviar.
static func codificar(h) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(TAM)
	b.encode_float(0, h.pos.x)
	b.encode_float(4, h.pos.y)
	b.encode_s8(8, clampi(roundi(h.dir_olhar.x * 127.0), -127, 127))
	b.encode_s8(9, clampi(roundi(h.dir_olhar.y * 127.0), -127, 127))
	b.encode_u8(10, int(h.estado))
	b.encode_u8(11, (1 if h.andando else 0) | (2 if h.correndo else 0) | (4 if h.escudo_ativo else 0))
	b.encode_u8(12, clampi(h.golpe_i, 0, 255))
	b.encode_u16(13, h.golpes & 0xFFFF)
	var f := clampi(roundi(h.vida / maxf(h.vida_max, 1.0) * 255.0), 0, 255)
	if h.vida > 0.0:
		f = maxi(f, 1)
	b.encode_u8(15, f)
	return b


func criar(m, pai: Node, t: Dictionary, p: Vector2, quem: String) -> void:
	mundo = m
	chave = "hazaki"
	raio = 6.0
	nome = quem
	montar_animado(pai, t, p, 0, 0, false)
	_off_base = sprite.offset
	alvo = p
	_rotulo = Label.new()
	_rotulo.text = quem
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.position = Vector2(-60, -float(t.pe) - 18)
	_rotulo.custom_minimum_size = Vector2(120, 0)
	_rotulo.size = Vector2(120, 16)
	_rotulo.z_as_relative = false
	_rotulo.z_index = 300  # o nome fica por cima das árvores e dos monstros
	_rotulo.add_theme_font_override("font", Dados.fonte_texto)
	_rotulo.add_theme_font_size_override("font_size", 16)
	_rotulo.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.95))
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_rotulo.add_theme_constant_override("outline_size", 4)
	raiz.add_child(_rotulo)


func definir_nome(n: String) -> void:
	nome = n
	if _rotulo != null:
		_rotulo.text = n


## Lê um pacote. Devolve false se vier lixo (tamanho errado, número que não é número): o estado anterior fica.
func aplicar(b: PackedByteArray, o := 0) -> bool:
	if b.size() < o + TAM:
		return false
	var x := b.decode_float(o)
	var y := b.decode_float(o + 4)
	if not is_finite(x) or not is_finite(y) or absf(x) > 100000.0 or absf(y) > 100000.0:
		return false
	var d := Vector2(b.decode_s8(o + 8), b.decode_s8(o + 9)) / 127.0
	if d.length_squared() > 0.01:
		dir_olhar = d.normalized()
	var e := b.decode_u8(o + 10)
	if e > Heroi.Estado.CARGA:
		return false
	if e == Heroi.Estado.ESQUIVA and estado != e:
		_esq_t = 0.0
	estado = e
	var flags := b.decode_u8(o + 11)
	andando = (flags & 1) != 0
	correndo = (flags & 2) != 0
	escudo_ativo = (flags & 4) != 0
	golpe_i = b.decode_u8(o + 12)
	var g := b.decode_u16(o + 13)
	if _tem_golpes:
		var novos := (g - golpes) & 0xFFFF
		if novos > 0 and novos < 1000:
			golpes_vistos += novos
			_golpe_visual()
	else:
		_tem_golpes = true
	golpes = g
	var fr := b.decode_u8(o + 15)
	vida = 0.0 if (e == Heroi.Estado.MORTO or fr == 0) else maxf(1.0, float(fr) / 255.0 * vida_max)
	alvo = Vector2(x, y)
	if not _tem_pos:
		_tem_pos = true
		definir_pos(alvo)
	ultimo = b.slice(o, o + TAM)
	pacotes += 1
	return true


## O arco do golpe que o dono acabou de dar (o mesmo corte do herói local).
func _golpe_visual() -> void:
	var passos: Array = mundo.combate.cfg.golpe.passos
	if passos.is_empty():
		return
	var i := clampi(golpe_i, 0, passos.size() - 1)
	_punch = 1.0
	mundo.combate.golpe_comecou(self, passos[i], dir_olhar, float(passos[i].duracao))


## Um passo de desenho: segue a posição que chegou e escolhe o quadro. Chamado por mundo.avancar (tempo do mundo).
func atualizar(dt: float) -> void:
	var dist := pos.distance_to(alvo)
	var antes := pos
	if dist > SALTO:
		definir_pos(alvo)
	elif dist > 0.05:
		definir_pos(pos.lerp(alvo, 1.0 - exp(-SUAVIDADE * dt)))
	var mexeu := pos.distance_squared_to(antes) > 0.0004
	_visual(dt, mexeu)


func _visual(dt: float, mexeu: bool) -> void:
	var l := Heroi.linha_de(dir_olhar)
	var c := 0
	if estado == Heroi.Estado.LIVRE and (andando or mexeu):
		_anim += dt * (1.45 if correndo else 1.0)
		c = 1 + int(_anim / Heroi.PASSO_ANIM) % (int(tipo.info.colunas.size()) - 1)
	else:
		_anim = 0.0
	if l != linha or c != coluna:
		quadro(c, l)
	var punch_k := 0.0
	if _punch > 0.0:
		_punch = maxf(0.0, _punch - dt / 0.16)
		punch_k = _punch
	var desloca := Vector2.ZERO
	var esc := Vector2.ONE
	if estado == Heroi.Estado.GOLPE:
		desloca = (dir_olhar * (-2.0 * (1.0 - punch_k) + 3.0 * punch_k)).round()
		esc = Vector2(1.0 + 0.1 * punch_k, 1.0 - 0.07 * punch_k)
	elif estado == Heroi.Estado.CARGA:
		esc = Vector2(1.05, 0.91)
	if estado == Heroi.Estado.MORTO:
		sprite.position = Vector2(0, -14)
		sprite.offset = _off_base + Vector2(0, 14)
		sprite.rotation = lerpf(sprite.rotation, 1.45 * (1.0 if dir_olhar.x >= 0 else -1.0), 1.0 - exp(-9.0 * dt))
		sprite.scale = Vector2.ONE
		sprite.modulate = Color(1, 0.8, 0.8, 0.85)
		return
	if estado == Heroi.Estado.ESQUIVA:
		_esq_t += dt
		var p := clampf(_esq_t / 0.42, 0.0, 1.0)
		var gira := signf(dir_olhar.x) if absf(dir_olhar.x) > 0.1 else 1.0
		sprite.position = Vector2(0, -14)
		sprite.offset = _off_base + Vector2(0, 14)
		sprite.rotation = gira * TAU * minf(p * 1.15, 1.0)
		esc = Vector2(1.0, 0.82)
		sprite.modulate = Color(1, 1, 1, 0.78)
	else:
		if sprite.rotation != 0.0:
			sprite.rotation = 0.0
			sprite.offset = _off_base
		sprite.position = desloca
		sprite.modulate = Color(0.8, 0.9, 1.0) if escudo_ativo else Color.WHITE
	sprite.scale = esc
