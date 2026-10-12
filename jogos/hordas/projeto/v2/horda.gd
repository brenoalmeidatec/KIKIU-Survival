extends RefCounted
## A horda em lote (porte da ideia da v1, `scripts/hordas/inimigos.gd`, #127): os monstros comuns não têm nó. Cada um é uma linha de números
## (`Monstro`, em `mundo.monstros`) e a horda inteira sai por poucos MultiMeshInstance2D, com a luz e o normal map de sempre:
##  - SPRITES: um atlas único (albedo + normal num CanvasTexture, `Sprites.atlas`) e um shader que lê o recorte do quadro e o espelho do
##    "custom data" de cada instância (e o NORMAL_MAP do mesmo recorte, para a luz). Os monstros ficam em FATIAS na ordem de y: uma fatia é um
##    MultiMeshInstance2D filho do `no_mundo` (y-sort), posto na ordem certa entre os nós que ficam por perto (o herói, as elites, os chefes
##    e os objetos do cenário). Uma fatia vale para todos os monstros que não têm nó nenhum entre eles na ordem de y, e dentro dela as
##    instâncias saem ordenadas pelos pés: a ordem de desenho é a mesma do y-sort de antes, só que em poucas chamadas.
##  - SOMBRAS: um MultiMesh de silhuetas (o recorte do mesmo atlas, borrado na média e nítido na alta), com o cisalhamento de cada instância
##    pelo transform (a mesma conta de `sombras.gd`; a luz ponderada roda a cada DECIMA quadros por monstro), mais um de manchas dos pés.
##  - OLHOS: um MultiMesh aditivo na camada glow.
## O flash branco, o empurrão, os números e o hit-stop continuam como eram (efeitos.gd lê o quadro do monstro, não o nó). Elite e chefe
## continuam nós (`Monstro.virar_no`): são poucos.

const Sombras := preload("res://v2/sombras.gd")
const Monstro := preload("res://v2/monstro.gd")
const MARGEM_TELA := 96.0  # só monstro a até 96 px da tela é desenhado (e tem sombra)
const CAP_INI := 16  # instâncias de cada MultiMesh no começo (dobra quando falta)
const DECIMA := 3  # a conta da luz sobre a sombra de cada monstro roda a cada N quadros (o deslize suavizado esconde o degrau)
const MARGEM_AABB := 80.0  # folga em volta das instâncias (o maior quadro de monstro, em escala de elite, cabe)
const Y_MIN := 0.2  # espessura vertical mínima da sombra (a mesma de sombras.gd: luz bem ao lado não vira linha)

## Lê o recorte (x, y, largura, altura em px do atlas; largura negativa = espelhado) do custom data de cada instância e a cor (modulate)
## do COLOR. NORMAL_MAP do mesmo recorte: a luz 2D age como em qualquer Sprite2D com CanvasTexture.
const SHADER_SPRITE := """shader_type canvas_item;
varying flat vec4 reg;
varying flat vec4 cor;
void vertex() { reg = INSTANCE_CUSTOM; cor = COLOR; }
void fragment() {
	vec2 u = UV;
	if (reg.z < 0.0) { u.x = 1.0 - u.x; }
	vec2 uv = (reg.xy + u * vec2(abs(reg.z), reg.w)) / vec2(textureSize(TEXTURE, 0));
	COLOR = texture(TEXTURE, uv) * cor;
	NORMAL_MAP = texture(NORMAL_TEXTURE, uv).rgb;
}
"""
## Silhueta preta que esmaece ao longo do sprite (a mesma de sombras.gd): `cor.r` = a linha dos pés / 128 (altura do pé no quadro) e
## `cor.a` = o alfa da instância.
const SHADER_SOMBRA := """shader_type canvas_item;
render_mode unshaded;
uniform float fade_len = 140.0;
varying flat vec4 reg;
varying flat vec4 cor;
void vertex() { reg = INSTANCE_CUSTOM; cor = COLOR; }
void fragment() {
	vec2 u = UV;
	if (reg.z < 0.0) { u.x = 1.0 - u.x; }
	vec2 uv = (reg.xy + u * vec2(abs(reg.z), reg.w)) / vec2(textureSize(TEXTURE, 0));
	float up = cor.r * 128.0 - UV.y * reg.w;
	COLOR = vec4(0.0, 0.0, 0.0, texture(TEXTURE, uv).a * cor.a * clamp(1.0 - up / fade_len, 0.12, 1.0));
}
"""
const SHADER_OLHO := """shader_type canvas_item;
render_mode blend_add, unshaded;
varying flat vec4 reg;
void vertex() { reg = INSTANCE_CUSTOM; }
void fragment() {
	vec2 u = UV;
	if (reg.z < 0.0) { u.x = 1.0 - u.x; }
	COLOR = texture(TEXTURE, (reg.xy + u * vec2(abs(reg.z), reg.w)) / vec2(textureSize(TEXTURE, 0)));
}
"""
const SHADER_BLOB := """shader_type canvas_item;
render_mode unshaded;
varying flat float alfa;
void vertex() { alfa = COLOR.a; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(c.rgb, c.a * alfa);
}
"""


## Um MultiMeshInstance2D com seu buffer (16 floats por instância: transform 2D, cor e custom data). O buffer é por referência: quem escreve
## nele escreve aqui. `n` = quantas instâncias valem neste quadro; `cap` = a capacidade (dobra quando falta).
class Lote:
	extends RefCounted
	var mmi: MultiMeshInstance2D
	var mm: MultiMesh
	var buf := PackedFloat32Array()
	var n := 0
	var cap := 0
	var chave := 0.0  # só nas fatias de sprite: onde ela fica na ordem de y do mundo
	var visivel := false
	var x0 := 1.0e9  # limites das instâncias deste quadro (px, no espaço do nó): é o retângulo que a luz 2D usa para saber quem a recebe
	var y0 := 1.0e9
	var x1 := -1.0e9
	var y1 := -1.0e9

	func montar(quad: Mesh, tex: Texture2D, mat: Material, pai: Node) -> void:
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = CAP_INI
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-1.0e6, -1.0e6, -1.0), Vector3(2.0e6, 2.0e6, 2.0))  # nunca cortado pelo cálculo de área
		mmi = MultiMeshInstance2D.new()
		mmi.multimesh = mm
		mmi.texture = tex
		mmi.material = mat
		mmi.visible = false
		cap = CAP_INI
		buf.resize(cap * 16)
		pai.add_child(mmi)

	func crescer() -> void:
		cap *= 2
		mm.instance_count = cap
		buf.resize(cap * 16)

	func enviar(dy := 0.0) -> void:
		mm.buffer = buf
		mm.visible_instance_count = n
		# retângulo apertado (e não "o mundo todo"): sem isso toda luz da tela entra no desenho da fatia inteira
		if x1 >= x0:
			mm.custom_aabb = AABB(
				Vector3(x0 - MARGEM_AABB, y0 - MARGEM_AABB - dy, -1.0), Vector3(x1 - x0 + 2.0 * MARGEM_AABB, y1 - y0 + 2.0 * MARGEM_AABB, 2.0)
			)
			x0 = 1.0e9
			y0 = 1.0e9
			x1 = -1.0e9
			y1 = -1.0e9
		if not visivel:
			visivel = true
			mmi.visible = true

	func esconder() -> void:
		if visivel:
			visivel = false
			mmi.visible = false


var mundo
var sombras: Sombras
var atlas := {}
var com_normal := true
var fatias: Array[Lote] = []  # os sprites, na ordem de y
var usadas := 0  # quantas fatias valem neste quadro
var lote_sombra: Lote
var lote_blob: Lote
var lote_olhos: Lote
var n_lote := 0  # monstros em lote na tela neste quadro
var us := 0  # microssegundos gastos por `atualizar` (só para a medição)
var _quad: ArrayMesh
var _mat_sprite: ShaderMaterial
var _modo := -1
var ordem: Array[Monstro] = []  # os monstros em lote na tela, na ordem de desenho (pelos pés); `chave_y` de cada um é a da fatia dele
var _vis: Array[Monstro] = []
var _chaves := PackedFloat64Array()
var _seps := PackedFloat32Array()
var _seps_est := PackedFloat32Array()
var _versao_cenario := -1
var _ids := 0


func montar(m) -> void:
	mundo = m
	sombras = m.sombras
	com_normal = m.sprites.com_normal
	atlas = m.sprites.atlas(m.TIPOS_MONSTRO)
	_quad = _quadrado()
	_mat_sprite = _material(SHADER_SPRITE)
	lote_blob = Lote.new()
	lote_blob.montar(_quad, sombras.textura_blob(), _material(SHADER_BLOB), sombras.raiz_blobs)
	lote_blob.mmi.light_mask = 0
	lote_sombra = Lote.new()
	lote_sombra.montar(_quad, atlas.blur, _material(SHADER_SOMBRA), sombras.raiz_sombras)
	lote_sombra.mmi.light_mask = 0
	lote_sombra.mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lote_olhos = Lote.new()
	lote_olhos.montar(_quad, atlas.emissao, _material(SHADER_OLHO), m.glow)
	lote_olhos.mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _quadrado() -> ArrayMesh:
	var q := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	q.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return q


func _material(codigo: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = codigo
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Número de série do monstro (para espalhar a conta da luz entre os quadros).
func novo_id() -> int:
	_ids += 1
	return _ids


## Esconde tudo (partida reiniciada ou cena saindo).
func limpar() -> void:
	for f in fatias:
		f.esconder()
	usadas = 0
	lote_sombra.esconder()
	lote_blob.esconder()
	lote_olhos.esconder()


func n_fatias() -> int:
	return usadas


func _trocar_modo(m: int) -> void:
	_modo = m
	lote_sombra.mmi.texture = atlas.blur if m == Sombras.MEDIA else atlas.alb
	if m == Sombras.NENHUMA:
		lote_blob.esconder()
	for mo in mundo.monstros:  # a conta da luz recomeça no modo novo (a alta guarda estado por sombra)
		if mo.lote:
			_zerar_luz(mo)


## Os nós do mundo (na ordem de y) que dividem os monstros em fatias: os objetos do cenário, o herói e as elites e chefes. Só os do
## cenário mudam raramente: ficam ordenados à parte e só refazem quando os blocos visíveis trocam.
func _separadores() -> void:
	var cen = mundo.cenario
	if cen.versao != _versao_cenario:
		_versao_cenario = cen.versao
		_seps_est.clear()
		for a in cen.ativos:
			_seps_est.append(a.raiz.position.y)
		_seps_est.sort()
	_seps = _seps_est.duplicate()
	_seps.append(mundo.heroi.raiz.position.y)
	for m in mundo.monstros:
		if not m.lote:
			_seps.append(m.raiz.position.y)
	_seps.sort()


## Um quadro da horda: escolhe quem está na tela, ordena pelos pés, reparte em fatias e escreve as instâncias (sprites, sombras, manchas e
## olhos). `t` = tempo do mundo, `rect` = o que a câmera mostra, `quadro` = contador de quadros (espalha a conta da luz).
func atualizar(t: float, rect: Rect2, quadro: int) -> void:
	var t0 := Time.get_ticks_usec()
	var modo: int = sombras.modo
	if modo != _modo:
		_trocar_modo(modo)
	var tela := rect.grow(MARGEM_TELA)
	_vis.clear()
	_chaves.clear()
	var i := 0
	for m: Monstro in mundo.monstros:
		if not m.lote:
			continue
		if tela.has_point(m.pos):
			if not m.ativo:
				m.ativo = true
				_zerar_luz(m)
			_vis.append(m)
			_chaves.append(float((int(m.pr.y) + 8192) << 16) + float(i))
			i += 1
		elif m.ativo:
			m.ativo = false
	n_lote = i
	_chaves.sort()
	_separadores()
	var ns := _seps.size()
	var sp := 0
	var sp_ant := -1
	var f: Lote = null
	usadas = 0
	var bs := lote_sombra
	var bb := lote_blob
	var bo := lote_olhos
	bs.n = 0
	bb.n = 0
	bo.n = 0
	ordem.clear()
	var com_sombra := modo != Sombras.NENHUMA
	var inclinada := modo >= Sombras.MEDIA
	var nslots := 1 if modo == Sombras.MEDIA else 2
	for kk in _chaves:
		var m: Monstro = _vis[int(kk) & 0xFFFF]
		var pr := m.pr
		while sp < ns and _seps[sp] <= pr.y:
			sp += 1
		if sp != sp_ant:
			sp_ant = sp
			f = _fatia()
			f.chave = pr.y + 0.5 if sp >= ns else (pr.y + _seps[sp]) * 0.5  # entre o último nó acima e o primeiro abaixo
		m.chave_y = f.chave
		ordem.append(m)
		m.visual()
		# ---- sprite
		if f.n >= f.cap:
			f.crescer()
		var buf := f.buf
		var o := f.n << 4
		f.n += 1
		var w := m.fw
		var h := m.fh
		var pe := m.fpe
		var sx := m.v_sx
		var sy := m.v_sy
		var cor := m.v_cor
		var cx := m.coluna * w + m.ao.x
		var cy := m.linha * h + m.ao.y
		var fl := -w if m.espelha else w
		var ox := pr.x + m.v_jx - w * 0.5 * sx
		var oy := pr.y - pe * sy
		buf[o] = w * sx
		buf[o + 3] = ox
		buf[o + 5] = h * sy
		buf[o + 7] = oy - f.chave
		buf[o + 8] = cor.r
		buf[o + 9] = cor.g
		buf[o + 10] = cor.b
		buf[o + 11] = cor.a
		buf[o + 12] = cx
		buf[o + 13] = cy
		buf[o + 14] = fl
		buf[o + 15] = h
		if pr.x < f.x0:
			f.x0 = pr.x
		if pr.x > f.x1:
			f.x1 = pr.x
		if pr.y < f.y0:
			f.y0 = pr.y
		if pr.y > f.y1:
			f.y1 = pr.y
		# ---- olhos (aditivos, na camada glow: coordenadas do mundo)
		if bo.n >= bo.cap:
			bo.crescer()
		var ob := bo.buf
		var oo := bo.n << 4
		bo.n += 1
		ob[oo] = w * sx
		ob[oo + 3] = ox
		ob[oo + 5] = h * sy
		ob[oo + 7] = oy
		ob[oo + 12] = cx
		ob[oo + 13] = cy
		ob[oo + 14] = fl
		ob[oo + 15] = h
		if not com_sombra:
			continue
		# ---- sombras: mancha dos pés (todas as qualidades) e a silhueta inclinada (média e alta)
		var b_esc := 1.0
		var b_alfa := 0.62
		if inclinada:
			if m.t_ult < 0.0 or (m.sid + quadro) % DECIMA == 0:
				sombras.calcular(m, t)
			b_esc = m.b_esc
			b_alfa = m.b_alfa
			var esc := m.escala
			for s in nslots:
				var vec := m.sv[s]
				var alfa := m.sa[s]
				if alfa <= 0.01:
					continue
				var vy := vec.y
				if absf(vy) < Y_MIN:
					vy = Y_MIN if vy >= 0.0 else -Y_MIN
				if bs.n >= bs.cap:
					bs.crescer()
				var sb := bs.buf
				var so := bs.n << 4
				bs.n += 1
				sb[so] = esc * w
				sb[so + 1] = -vec.x * esc * h
				sb[so + 3] = pr.x - esc * w * 0.5 + vec.x * esc * pe
				sb[so + 4] = 0.0
				sb[so + 5] = -vy * esc * h
				sb[so + 7] = pr.y + vy * esc * pe
				sb[so + 8] = pe / 128.0
				# o alfa cai um pouco com a luz bem ao lado (o estalo do espelho quase não aparece), como em sombras.gd
				sb[so + 11] = alfa * lerpf(0.45, 1.0, smoothstep(0.0, 0.3, absf(vec.y)))
				sb[so + 12] = cx
				sb[so + 13] = cy
				sb[so + 14] = fl
				sb[so + 15] = h
		var k := m.larg_blob * b_esc / 64.0
		if bb.n >= bb.cap:
			bb.crescer()
		var bf := bb.buf
		var bi := bb.n << 4
		bb.n += 1
		bf[bi] = 64.0 * k
		bf[bi + 3] = pr.x - 32.0 * k
		bf[bi + 5] = 28.8 * k  # 32 * 0,9
		bf[bi + 7] = pr.y - 1.0 - 14.4 * k  # centrada em (0, -1)
		bf[bi + 11] = b_alfa
	# ---- manda tudo para o desenho
	for j in usadas:
		var fa := fatias[j]
		fa.mmi.position = Vector2(0.0, fa.chave)
		fa.enviar(fa.chave)
	for j in range(usadas, fatias.size()):
		fatias[j].esconder()
	if n_lote > 0:
		bo.enviar()
		if com_sombra:
			bb.enviar()
		else:
			bb.esconder()
		if inclinada:
			bs.enviar()
		else:
			bs.esconder()
	else:
		bo.esconder()
		bb.esconder()
		bs.esconder()
	us += Time.get_ticks_usec() - t0


## A conta da luz sobre a sombra deste monstro recomeça (entrou na tela ou o modo mudou).
func _zerar_luz(m) -> void:
	m.t_ult = -1.0
	m.sa.fill(0.0)
	m.sl.fill(-1)


func _fatia() -> Lote:
	if usadas >= fatias.size():
		var l := Lote.new()
		l.montar(_quad, atlas.tex, _mat_sprite, mundo.no_mundo)
		l.mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fatias.append(l)
	var f := fatias[usadas]
	usadas += 1
	f.n = 0
	return f
