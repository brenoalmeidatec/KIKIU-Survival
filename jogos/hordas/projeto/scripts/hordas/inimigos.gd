extends Node2D
## Todos os inimigos da partida num lugar só (sem um nó por inimigo, pra caber 500 na tela).
## Cada inimigo é um objeto leve (classe V). Uma grade espacial acha quem está perto rápido.
## Também cuida dos tiros dos inimigos.

const Visual := preload("res://scripts/hordas/visual.gd")
const Perf := preload("res://scripts/hordas/perf.gd")
const Elementos := preload("res://scripts/hordas/elementos.gd")
const Legib := preload("res://scripts/hordas/legibilidade.gd")
const Anim := preload("res://scripts/hordas/animacao_monstros.gd")
const ESCALA := 2.0  # a arte gerada é desenhada 2x
const CELULA := 48.0
const AVISO_ANEL := 0.6  # segundos de aviso (anel vermelho no chão) antes dos tiros em anel (#68)
const TELEGRAFA_T := 0.4  # segundos de piscada avermelhada antes de um inimigo atirar (a investida e o anel já tinham aviso próprio)
const LONGE := 720.0  # mais longe que isso do jogador = reaparece do outro lado
const NASC_T := 0.26  # animação de nascer / reaparecer (teleporte): some e volta numa nuvem escura
const ACEL_VEL := 14.0  # suavização do andar: 1/ACEL_VEL s (~70 ms) pra chegar na velocidade pedida
const SEP_MAX := 1.2  # empurrão de separação: no máximo 1,2x a velocidade do bicho, por segundo
const KB_MAX := 360.0  # teto do empurrão (px/s): o knockback desliza, não teleporta
const SEP_PERIODO := 0.04  # a separação de cada bicho é recalculada a cada ~40 ms (em quadros: 40 ms / dt) e aplicada suave TODO quadro
const SEP_PERIODO_LONGE := 0.1  # ... e a cada ~100 ms se está longe do alvo (fora da tela)
const SEP_PERTO := 380.0
const SEP_VIZ: Array[int] = [-65537, -65536, -65535, -1, 0, 1, 65535, 65536, 65537]  # 3x3 células na chave inteira (x << 16) + y
const AUSENTE_T := 0.45  # cliente online: bicho que some da foto fica mais um pouco (foto cheia / borda) antes de sair
const GIRO_OLHAR := 9.42478  # velocidade máxima de giro do olhar: 540 graus/s
const HIST_OLHAR := 0.12  # folga (rad) além da divisa do setor antes de trocar de vista
const SNAP_ONLINE := 150.0  # cliente online: foto mais longe que isso do que se vê = teleporte (anima), não deslize


class V:
	var id := 0
	var tipo := ""
	var d: Dictionary  # dados do inimigos.json
	var tex: Texture2D
	var tam := Vector2.ZERO  # tamanho de um quadro (sem escala)
	var pos := Vector2.ZERO
	var hp := 1.0
	var hpmax := 1.0
	var dano := 1.0
	var vel := 40.0
	var raio := 8.0
	var esc := 1.0
	var kb := Vector2.ZERO
	var flash := 0.0
	var lento := 0.0
	var t_golpe := -99.0  # relógio do desenho (_t) no último golpe: a barra de elite mostra o nome logo depois
	var el_vis := 0  # estado de elemento pra pintar (bits: 1 fogo, 2 gelo, 4 raio, 8 veneno, 16 congelado); quem manda é elementos.gd
	var resist: Dictionary = {}  # resistência a elementos (inimigos.json > resist), lida uma vez
	var atordoado := 0.0  # parado no lugar (rugido do dragão)
	var elite := false
	var chefe := false
	var t_atira := 0.0
	var t_anel := 0.0
	var t_invoca := 0.0
	var t_inv := 0.0
	var estado := 0  # 0 normal, 1 se preparando pra investida, 2 investindo
	var t_estado := 0.0
	var dir_inv := Vector2.ZERO
	# comportamentos (lidos uma vez do json, pra não procurar no dicionário todo quadro)
	var distancia := 0.0
	var investida := 0.0
	var atira := 0.0
	var anel := 0.0
	var invoca: Dictionary = {}
	var pesado := false
	# vida no desenho (dados/inimigos.json): tudo lido uma vez aqui
	var ppx := 2.0  # pixels da tela por pixel do sprite (2 = vírus, 1 = arte de horror)
	var ritmo := 4.0  # quadros de andar por segundo
	var balanco := 0.0  # pulinho de andar, em px da tela
	var gira := false  # arte vista de cima com a cabeça pra cima (bug): gira pra onde anda em vez de espelhar
	var ang := 0.0  # ângulo atual do desenho (só com gira)
	var pos_ant := Vector2.INF  # posição no último desenho (só com gira): vale no solo e no cliente online
	var flutua := 0.0  # px acima do chão (a sombra fica no chão)
	var aura := Color(0, 0, 0, 0)  # brilho em volta (a > 0)
	var sz := Vector2.ZERO  # tamanho na tela (tam x escala x esc), calculado uma vez
	var luz := Vector2.ZERO  # x = raio, y = intensidade: ilumina a escuridão da fase de horror
	# suavidade do movimento
	var vm := Vector2.ZERO  # velocidade de andar atual (acelera até a desejada, não troca de uma vez)
	var sepv := Vector2.ZERO  # último empurrão de separação calculado (aplicado aos poucos, todo quadro)
	var t_nasc := 0.0  # > 0: nascendo / reaparecendo (animação de teleporte)
	# vistas (a folha tem uma linha por vista): vistas = 1 é o vírus, sempre de frente pra câmera (sem espelhar nem achatar);
	# vistas = 5 é o monstro de horror: 0 frente, 1 3/4 frente, 2 perfil, 3 3/4 costas, 4 costas (esquerda = espelho)
	var vistas := 1
	var cols := 3  # colunas da folha: quadros de andar + 1 de branco (a última). Folha antiga: 3
	var nq := 2  # quadros de andar (cols - 1)
	var anim := false  # ciclo de andar de verdade (vistas > 1 e mais de 2 quadros): a fase avança pela distância andada
	var fase := 0.0  # fase do passo, 0..1 (só com anim)
	var parado := 0.0  # há quanto tempo não anda (assenta nos pés juntos)
	var pos_f := Vector2.INF  # posição no último desenho (a distância andada vem daqui; INF = fora da tela, não conta)
	var lean := 0.0  # inclinação suavizada pro lado em que anda: -1..1 (só com anim)
	var ciclo := 40.0  # px da tela por ciclo de andar
	var inv_ciclo := 0.025  # 1 / ciclo
	var inv_vel := 0.02  # 1 / max(velocidade, 20): a inclinação é a fração da velocidade que ele anda de lado
	var q_ini := 1  # sombra: quadros de q_ini a q_ini + q_meio - 1 usam a sombra do meio do ciclo (ver Anim.coluna_sombra)
	var q_meio := 3
	var q_sh := 0  # coluna da sombra assada neste quadro
	var bob_px := 1.0  # quique do passo em px da tela (bob x altura, com piso)
	var qd := 0  # quadro de andar mostrado no último desenho (a morte e o fantasma do teleporte congelam este)
	var olhar := 0.0  # pra onde olha, em rad a partir da frente (pra baixo): +PI/2 = direita, PI = costas
	var setor := 0  # setor de 45° escolhido (com histerese): -3..4, negativo = lado esquerdo (espelhado)
	var vista := 0  # linha da folha em uso
	var espelho := false  # desenhado espelhado (olhando pra esquerda)
	var orientar := true  # primeira vez ou voltou de fora da tela: o olhar vai direto pro alvo, sem girar
	var pos_olho := Vector2.INF  # cliente online: posição no último desenho (o olhar vem do deslocamento desenhado)
	var dr := Rect2()  # último retângulo desenhado (os testes conferem a largura)
	var p_ini := Vector2.ZERO  # cliente online: de onde o deslize da foto parte
	var p_fim := Vector2.ZERO  # ... e pra onde vai (posição da foto do anfitrião)
	var t_foto := 0.0  # ... e há quanto tempo a foto chegou
	# causa do golpe final (mortes violentas): cada dano grava a arma e a direção; `causa_pend` é o elemento da bola (Poder Elemental)
	var arma_ult := ""
	var causa_pend := ""
	var causa_ult := ""
	var dir_ult := Vector2.ZERO
	var sombra_reg: Array = [Rect2(), Rect2(), Rect2(), Rect2()]  # sombra assada por (quadro, espelho): ver Visual.sombra_regiao
	var at := Vector2.ZERO  # canto da folha deste tipo no atlas dos inimigos (atlas_inimigos.gd), em pixels
	var at_gen := -1  # geração do atlas em que `at` vale (muda se o atlas for refeito)
	var t_ausente := 0.0  # ... e quanto tempo faz que ficou fora das fotos (some só depois de AUSENTE_T)


var arena: Node
var mortes: Node = null  # mortes.gd: desenha como o inimigo morreu (criado pela arena)
var online: Node = null  # online.gd (só na partida online)
var espelho := false  # cliente online: os vírus vêm do anfitrião, aqui não roda IA
var por_id := {}  # id -> V
var lista: Array = []
var tiros: Array = []  # {pos, vel, dano, tex, vida}
var _grade := {}
var _prox_id := 1
var _t := 0.0
var _quadro := 0
var _ordem: Array = []  # visíveis, do mais alto pro mais baixo (refeita todo quadro no _draw)
var _chaves := PackedFloat64Array()
## Flash branco de acerto: quem acabou de apanhar é desenhado de novo, por cima, como silhueta branca (shader).
## Um nó só pra todos; antes o acerto só trocava o quadro e achatava, e bicho escuro em chão escuro não "piscava".
const FLASH_BRANCO := 0.035  # s do flash (a primeira parte dos 0,09 s de v.flash)
const FLASH_MAX := 64
const SHADER_BRANCO := """shader_type canvas_item;
void fragment() { COLOR.rgb = vec3(1.0); }
"""
var _flash_no := Node2D.new()
var elementos: Node2D = preload("res://scripts/hordas/elementos.gd").new()  # estados de elemento (#72): fogo, gelo, raio, veneno
var _flashes: Array = []  # [tex, rect, fonte, alfa], refeito todo quadro no _draw

## Desenho em lote (#127): a horda inteira sai por duas MultiMeshInstance2D, uma pras sombras (atlas de sombras do Visual) e uma pros
## sprites (atlas das folhas, `atlas_inimigos.gd`), na ordem por altura. Cada instância = 16 floats: o retângulo na tela (transform 2D),
## a cor (modulate) e o recorte em PIXELS do atlas (x, y, largura, altura; largura negativa = espelhado; largura 0 = disco liso, o
## brilho de aura/elite e a nuvem de nascer). O shader é o único e simples; sem luz nem nada de Forward+.
const SHADER_MM := """shader_type canvas_item;
varying flat vec4 reg;
varying flat vec4 cor;
void vertex() { reg = INSTANCE_CUSTOM; cor = COLOR; }
void fragment() {
	if (reg.z == 0.0) {
		COLOR = vec4(cor.rgb, cor.a * step(length(UV - vec2(0.5)), 0.5));
	} else {
		COLOR = cor * texture(TEXTURE, (reg.xy + UV * reg.zw) / vec2(textureSize(TEXTURE, 0)));
	}
}
"""
const MM_CAP_INI := 256  # instâncias de cada MultiMesh no começo (dobra quando falta)
const AtlasInimigos := preload("res://scripts/hordas/atlas_inimigos.gd")
var _quad_mesh: ArrayMesh
var _atlas := AtlasInimigos.new()
var _mm_som: MultiMeshInstance2D
var _mm_spr: MultiMeshInstance2D
var _no_marcas := Node2D.new()  # faixas e anéis de aviso no chão: entre as sombras e os sprites
var _no_topo := Node2D.new()  # barras de elite/chefe, fantasmas do teleporte e tiros: por cima dos sprites
var _bs := PackedFloat32Array()  # instâncias das sombras (16 floats cada)
var _ns := 0
var _bi := PackedFloat32Array()  # instâncias dos sprites
var _ni := 0


func _ready() -> void:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = SHADER_BRANCO
	_flash_no.material = m
	_flash_no.draw.connect(_draw_flashes)
	_no_marcas.draw.connect(_desenhar_marcas)
	_no_topo.draw.connect(_desenhar_topo)
	# ordem dos filhos = ordem de desenho: sombras, marcas no chão, sprites, barras/tiros, flash branco, elementos
	_mm_som = _novo_mm(Visual.textura_sombras())
	_bs.resize(MM_CAP_INI * 16)
	_cor_branca_bs(0, MM_CAP_INI)
	add_child(_no_marcas)
	_mm_spr = _novo_mm(_atlas.textura)
	_bi.resize(MM_CAP_INI * 16)
	add_child(_no_topo)
	add_child(_flash_no)
	elementos.ino = self
	add_child(elementos)


func _novo_mm(tex: Texture2D) -> MultiMeshInstance2D:
	if _quad_mesh == null:
		_quad_mesh = ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		_quad_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad_mesh
	mm.instance_count = MM_CAP_INI
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-1.0e6, -1.0e6, -1.0), Vector3(2.0e6, 2.0e6, 2.0))  # nunca cortado pelo cálculo de área
	var mi := MultiMeshInstance2D.new()
	mi.multimesh = mm
	mi.texture = tex
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER_MM
	mi.material = mat
	add_child(mi)
	return mi


## Manda o lote do quadro: ajusta a capacidade se cresceu, copia o buffer e diz quantas instâncias valem.
func _enviar_mm(mi: MultiMeshInstance2D, buf: PackedFloat32Array, n: int) -> void:
	var mm := mi.multimesh
	if mm.instance_count * 16 != buf.size():
		mm.instance_count = buf.size() / 16
	mm.buffer = buf
	mm.visible_instance_count = n


## O buffer das sombras dobra de tamanho (as sombras são sempre brancas e sem giro: cor e eixos ficam gravados, só se escreve o retângulo e o recorte).
func _crescer_bs() -> void:
	var antes := _bs.size() >> 4
	_bs.resize(_bs.size() * 2)
	_cor_branca_bs(antes, antes * 2)


func _cor_branca_bs(de: int, ate: int) -> void:
	for i in range(de, ate):
		var o := i << 4
		_bs[o + 8] = 1.0
		_bs[o + 9] = 1.0
		_bs[o + 10] = 1.0
		_bs[o + 11] = 1.0


## O buffer dos sprites dobra de tamanho.
func _crescer_bi() -> void:
	_bi.resize(_bi.size() * 2)


## Uma instância de sprite sem giro: retângulo (x, y, w, h) na tela, recorte (rx, ry, rw, rh) em pixels do atlas e cor.
func _ii(x: float, y: float, w: float, h: float, rx: float, ry: float, rw: float, rh: float, c: Color) -> void:
	var o := _ni << 4
	if o + 16 > _bi.size():
		_bi.resize(_bi.size() * 2)
	_ni += 1
	var b := _bi
	b[o] = w
	b[o + 1] = 0.0
	b[o + 3] = x
	b[o + 4] = 0.0
	b[o + 5] = h
	b[o + 7] = y
	b[o + 8] = c.r
	b[o + 9] = c.g
	b[o + 10] = c.b
	b[o + 11] = c.a
	b[o + 12] = rx
	b[o + 13] = ry
	b[o + 14] = rw
	b[o + 15] = rh


## Sprite girado em `ang` em torno do centro (cx, cy) do retângulo gw x gh (o bicho visto de cima que aponta pra onde anda).
func _ig(cx: float, cy: float, gw: float, gh: float, ang: float, rx: float, ry: float, rw: float, rh: float, c: Color) -> void:
	var o := _ni << 4
	if o + 16 > _bi.size():
		_bi.resize(_bi.size() * 2)
	_ni += 1
	var cs := cos(ang)
	var sn := sin(ang)
	var b := _bi
	b[o] = cs * gw
	b[o + 1] = -sn * gh
	b[o + 3] = cx - 0.5 * (cs * gw - sn * gh)
	b[o + 4] = sn * gw
	b[o + 5] = cs * gh
	b[o + 7] = cy - 0.5 * (sn * gw + cs * gh)
	b[o + 8] = c.r
	b[o + 9] = c.g
	b[o + 10] = c.b
	b[o + 11] = c.a
	b[o + 12] = rx
	b[o + 13] = ry
	b[o + 14] = rw
	b[o + 15] = rh


## Disco liso (largura de recorte 0): aura, brilho de elite e as bolhas da nuvem de nascer.
func _id(cx: float, cy: float, raio: float, c: Color) -> void:
	_ii(cx - raio, cy - raio, raio * 2.0, raio * 2.0, 0.0, 0.0, 0.0, 0.0, c)


func _draw_flashes() -> void:
	for f in _flashes:
		_flash_no.draw_texture_rect_region(f[0], f[1], f[2], Color(1, 1, 1, f[3]))


var _dt := 0.016
var _barras: Array = []  # elites/chefes visíveis no quadro (legibilidade.gd)
var barras_n := 0  # quantas barras foram desenhadas no último quadro (o teste lê)
var fantasmas: Array = []  # quem acabou de sumir (teleporte): {pos, tex, tam, sz, vira, quadro, t}
var tp_n := 0  # quantos teleportes (reaparecimentos) já tocaram: o teste lê
# --- medição de saltos (--saltos): por inimigo, deslocamento por quadro contra a velocidade dele ---
var medir := false
var med_tempo := 0.0
var med_quadros := 0
var med_saltos := {}  # causa -> quantidade (passo > 2,5x a velocidade)
var med_grandes := {}  # causa -> quantidade (passo > 12 px num quadro)
var med_nasc_vis := 0  # nascimentos dentro da tela
var med_vistos := {}  # online (cliente): ids já vistos; recriar um id = o bicho piscou (saiu da foto e voltou)
var med_recriados := 0
var med_ex := {}  # causa -> até 3 exemplos


func criar(tipo: String, pos: Vector2, nivel := 1, elite := false) -> V:
	var dd: Dictionary = Dados.json("inimigos").get(tipo, {})
	if dd.is_empty():
		return null
	var fase: Dictionary = Dados.json("fase").get("dificuldade", {})
	var v := V.new()
	v.id = _prox_id
	_prox_id += 1
	v.tipo = tipo
	v.d = dd
	v.tex = Dados.tex(str(dd.get("sprite", "inimigo_bug")))
	v.vistas = maxi(1, int(dd.get("vistas", 1)))
	v.cols = Anim.colunas(str(dd.get("sprite", "inimigo_bug"))) if v.vistas > 1 else 3
	v.nq = v.cols - 1
	v.anim = v.vistas > 1 and v.nq > 2
	v.tam = Vector2(v.tex.get_width() / float(v.cols), v.tex.get_height() / float(v.vistas))
	if v.vistas > 1:
		v.sombra_reg = []
		for _i in 4 * v.vistas:
			v.sombra_reg.append(Rect2())
	v.pos = pos
	v.chefe = bool(dd.get("chefe", false))
	var mult_vida := 1.0 + float(fase.get("vida_por_nivel", 0.2)) * (nivel - 1)
	if v.chefe:
		mult_vida = 1.0 + 0.08 * (nivel - 1)
	v.hpmax = float(dd.get("vida", 10)) * mult_vida
	v.dano = float(dd.get("dano", 5)) * (1.0 + float(fase.get("dano_por_nivel", 0.08)) * (nivel - 1))
	v.vel = float(dd.get("velocidade", 40)) * randf_range(0.9, 1.1)
	if arena and arena.has_method("ef"):  # calor (#63): modificadores que o jogador ligou antes da corrida
		v.hpmax *= 1.0 + arena.ef("inimigo_vida") + (arena.ef("chefe_vida") if v.chefe else 0.0)
		v.dano *= 1.0 + arena.ef("inimigo_dano")
		v.vel *= 1.0 + arena.ef("inimigo_velocidade")
	v.raio = float(dd.get("raio", 8))
	if bool(dd.get("elite", false)) and not v.chefe:
		v.elite = true  # elite "de fábrica" (Abominação): vida e tamanho já vêm do json
	elif elite and not v.chefe:
		v.elite = true
		v.hpmax *= 6.0
		v.esc = 1.4
		v.raio *= 1.4
		v.dano *= 1.5
	v.hp = v.hpmax
	v.distancia = float(dd.get("distancia", 0.0))
	v.investida = float(dd.get("investida", 0.0))
	v.atira = float(dd.get("atira", 0.0))
	v.anel = float(dd.get("anel", 0.0))
	v.invoca = dd.get("invoca", {}) if dd.get("invoca") is Dictionary else {}
	v.pesado = bool(dd.get("pesado", false))
	if dd.get("resist") is Dictionary:
		v.resist = dd.resist
	v.ppx = float(dd.get("escala", ESCALA))
	v.sz = v.tam * v.ppx * v.esc
	if v.anim:
		var ac := _cfg()
		v.ciclo = Anim.ciclo_px(v.sz.y, ac.ciclo_alt, ac.ciclo_min, float(Dados.json("animacao_monstros").get("ciclo_por_tipo", {}).get(tipo, -1.0)))
		v.inv_ciclo = 1.0 / v.ciclo
		v.inv_vel = 1.0 / maxf(v.vel, 20.0)
		v.q_ini = v.nq / 4
		v.q_meio = v.nq / 2
		v.bob_px = maxf(ac.bob_min_px, ac.bob * v.sz.y)
		v.fase = fmod(v.id * 0.618034, 1.0)  # a horda não anda em coro
	v.ritmo = float(dd.get("ritmo", 4.0))
	v.balanco = float(dd.get("balanco", 0.0))
	v.gira = bool(dd.get("gira", false))
	v.flutua = float(dd.get("flutua", 0.0))
	if dd.get("aura") is Array:
		v.aura = Color(dd.aura[0], dd.aura[1], dd.aura[2], 1.0)
	if dd.get("luz") is Array:
		v.luz = Vector2(dd.luz[0], dd.luz[1])
	v.t_atira = randf_range(0.5, float(dd.get("atira", 3.0)))
	v.t_anel = float(dd.get("anel", 0.0))
	v.t_inv = float(dd.get("investida", 0.0))
	v.t_invoca = float(dd.get("invoca", {}).get("a_cada", 0.0)) if dd.get("invoca") is Dictionary else 0.0
	v.t_nasc = NASC_T
	v.p_ini = pos
	v.p_fim = pos
	lista.append(v)
	por_id[v.id] = v
	if medir and arena and arena.jogador and absf(pos.x - arena.jogador.position.x) < 330 and absf(pos.y - arena.jogador.position.y) < 190:
		med_nasc_vis += 1
	return v


func _med_reg(v: V, dt: float, passo: float, causa: String, vmax: float) -> void:
	if passo > 2.5 * vmax * dt and passo > 0.5:
		med_saltos[causa] = int(med_saltos.get(causa, 0)) + 1
		if passo > 12.0:
			med_grandes[causa] = int(med_grandes.get(causa, 0)) + 1
		var ex: Array = med_ex.get(causa, [])
		if ex.size() < 3:
			ex.append("%s passo=%.1f vmax*dt=%.2f" % [v.tipo, passo, vmax * dt])
			med_ex[causa] = ex


func med_relatorio() -> String:
	return (
		"quadros=%d tempo=%.1fs saltos_sem_animacao(>2,5x vel)=%s  grandes(>12px)=%s  teleportes_animados=%d  nascimentos_na_tela=%d  recriados_online=%d  exemplos=%s"
		% [med_quadros, med_tempo, str(med_saltos), str(med_grandes), tp_n, med_nasc_vis, med_recriados, str(med_ex)]
	)


func vivos() -> int:
	return lista.size()


func _remover(v: V) -> void:
	por_id.erase(v.id)
	if v.el_vis != 0:
		elementos.vis.erase(v.id)  # cliente: o estado pintado some junto (no anfitrião, elementos.passo solta o registro)
	var i := lista.find(v)
	if i >= 0:
		lista[i] = lista[lista.size() - 1]
		lista.pop_back()


func limpar() -> void:
	elementos.limpar()
	lista.clear()
	por_id.clear()
	tiros.clear()
	_ordem.clear()


## Dá dano. Retorna true se matou.
func ferir(v: V, valor: float, empurrao := Vector2.ZERO, arma := "") -> bool:
	if v.hp <= 0:
		return false
	if not espelho and arena.get("jogador") != null and arena.jogador.has_method("golpe_extra"):
		valor *= arena.jogador.golpe_extra()  # esquiva perfeita (#126): o próximo golpe sai mais forte
	var crit: bool = randf() < arena.stat("critico")
	if crit:
		valor *= arena.stat("critico_mult")
	v.hp -= valor
	v.flash = 0.09
	v.t_golpe = _t
	if not espelho and v.lento < 0.6:  # conjunto Gelo (#63): o golpe deixa o bicho lento (só quem roda a IA vê)
		v.lento = maxf(v.lento, arena.conj("lento_acerto"))
	v.arma_ult = arma  # causa do golpe final (mortes violentas)
	var el_bola: String = v.causa_pend  # o Poder Elemental (#72) põe o elemento da bola aqui
	v.causa_ult = v.causa_pend
	v.causa_pend = ""
	if empurrao.length_squared() > 1.0:
		v.dir_ult = empurrao
	arena.registrar_dano(arma, valor, v.pos, crit)
	if espelho:
		# cliente: o anfitrião aplica de verdade (e avisa se morreu); aqui só some até a confirmação
		online.acerto(v.id, valor, empurrao, arma)
		if v.hp <= 0:
			_remover(v)
			_morte_visual(v)  # efeito só local: a morte em si o anfitrião já sincroniza
			return true
		return false
	var peso := 4.0 if v.pesado else 1.0
	if v.chefe:
		peso = 12.0
	v.kb = (v.kb + empurrao / peso).limit_length(KB_MAX)
	if v.hp <= 0:
		if (v.el_vis & 16) != 0:  # morreu congelado: estilhaça
			v.causa_ult = "gelo"
		_remover(v)
		_morte_visual(v)
		arena.inimigo_morreu(v)
		return true
	elementos.golpe(v, arma, el_bola)  # sobreviveu: o golpe soma acúmulos de elemento (fogo, gelo, raio, veneno)
	return false


## Põe acúmulos de um elemento (poças com elemento, reações). No duelo o campo não é este nó: quem chama confere has_method.
func aplicar_elemento(v: V, el: String, n := 1.0, fonte := "") -> void:
	if not espelho:
		elementos.aplicar(v, el, n, fonte)


## Anfitrião: acerto que veio de outro computador (o dano e o crítico já foram calculados lá).
func ferir_remoto(v: V, valor: float, empurrao: Vector2, arma := "") -> void:
	if v.hp <= 0:
		return
	v.hp -= valor
	v.flash = 0.09
	v.t_golpe = _t
	v.arma_ult = arma  # a arma do cliente, já conferida pelo anfitrião ("" = não declarou ou inválida: morte padrão)
	v.causa_ult = ""
	v.kb = (v.kb + empurrao / (12.0 if v.chefe else (4.0 if v.pesado else 1.0))).limit_length(KB_MAX)
	if v.hp <= 0:
		_remover(v)
		_morte_visual(v)
		arena.inimigo_morreu(v)
	elif arma != "":
		elementos.golpe_remoto(v, arma)  # só o elemento da arma dele (a `chance` de elemento é do anfitrião)


## Como o inimigo morre na tela. Chefe: a finalização (finalizacao.gd) cuida; os outros: mortes.gd.
func _morte_visual(v: V) -> void:
	if v.chefe:
		if arena.finalizacao:
			arena.finalizacao.iniciar(v)
	elif mortes:
		mortes.nova(v)


func remover_id(id: int) -> void:
	var v = por_id.get(id)
	if v:
		_remover(v)


## Cliente: aplica a foto do anfitrião. vir = [id, tipo_idx, x, y, hp_frac, flags] por vírus;
## tiros = [x, y, vx, vy, sprite_idx]. Quem não veio na foto sumiu (morreu ou ficou longe).
func aplicar_foto(vir: PackedFloat32Array, tir: PackedFloat32Array, onl: Node) -> void:
	var vistos := {}
	for i in range(0, vir.size(), 6):
		var id := int(vir[i])
		var ti := int(vir[i + 1])
		if ti < 0 or ti >= onl.tipos.size() or not is_finite(vir[i + 2]) or not is_finite(vir[i + 3]):
			continue
		var flags := int(vir[i + 5])
		var v: V = por_id.get(id)
		if v == null:
			v = criar(onl.tipos[ti], Vector2(vir[i + 2], vir[i + 3]), 1, (flags & 1) != 0)
			if v == null:
				continue
			if medir:
				if med_vistos.has(id):
					med_recriados += 1
				med_vistos[id] = true
			por_id.erase(v.id)
			v.id = id
			por_id[id] = v
		var np := Vector2(vir[i + 2], vir[i + 3])
		if v.pos.distance_squared_to(np) > SNAP_ONLINE * SNAP_ONLINE:
			_teleportar(v, np)  # salto grande (reciclagem no anfitrião, volta de longe): anima em vez de deslizar
			v.p_ini = np
		else:
			v.p_ini = v.pos
		v.p_fim = np
		v.t_foto = 0.0
		v.t_ausente = 0.0
		v.hp = clampf(vir[i + 4], 0.01, 1.0) * v.hpmax
		v.chefe = (flags & 2) != 0
		if (flags & 4) != 0:
			v.flash = maxf(v.flash, 0.05)
		v.estado = 1 if (flags & 8) != 0 else 0
		v.lento = 0.1 if (flags & 16) != 0 else 0.0
		if (flags & 240) != 0 or v.el_vis != 0:
			elementos.aplicar_vis(v, flags)
		vistos[id] = true
	for v in lista.duplicate():
		if not vistos.has(v.id):
			v.t_ausente += onl.ENVIO
			if v.t_ausente > AUSENTE_T:
				_remover(v)
	tiros.clear()
	for i in range(0, tir.size(), 5):
		var si := int(tir[i + 4])
		var spr: String = onl.sprites_tiro[si] if si >= 0 and si < onl.sprites_tiro.size() else "proj_email"
		tiros.append(
			{"pos": Vector2(tir[i], tir[i + 1]), "vel": Vector2(tir[i + 2], tir[i + 3]), "dano": 0.0, "tex": Dados.tex(spr), "vida": 1.0, "sprite": spr}
		)


# ---------- buscas ----------


func _celula(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELULA), floori(p.y / CELULA))


func no_circulo(c: Vector2, r: float) -> Array:
	var res := []
	var a := _celula(c - Vector2(r + 40, r + 40))
	var b := _celula(c + Vector2(r + 40, r + 40))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var cel = _grade.get(((cx + 32768) << 16) + cy + 32768)
			if cel == null:
				continue
			for v: V in cel:
				var rr: float = r + v.raio
				if v.pos.distance_squared_to(c) <= rr * rr:
					res.append(v)
	return res


func mais_perto(p: Vector2, maximo := 99999.0) -> V:
	var melhor: V = null
	var md := maximo * maximo
	for v in lista:
		var dd: float = v.pos.distance_squared_to(p)
		if dd < md:
			md = dd
			melhor = v
	return melhor


## Os n mais perto (pra armas com vários tiros).
func n_mais_perto(p: Vector2, n: int, maximo := 400.0) -> Array:
	var perto := no_circulo(p, maximo)
	perto.sort_custom(func(a, b): return a.pos.distance_squared_to(p) < b.pos.distance_squared_to(p))
	return perto.slice(0, n)


func aleatorio_na_tela(centro: Vector2) -> V:
	var na_tela := no_circulo(centro, 260)
	return na_tela.pick_random() if not na_tela.is_empty() else null


# ---------- atualização ----------


func atualizar(dt: float, jog: Node2D) -> void:
	var _p0 := Perf.ini()
	_t += dt
	_quadro += 1
	_dt = dt
	_fantasmas_passo(dt)
	if medir:
		med_tempo += dt
		med_quadros += 1
	# grade
	var _p1 := Perf.ini()
	_grade.clear()
	for v: V in lista:
		var k: int = ((floori(v.pos.x / CELULA) + 32768) << 16) + floori(v.pos.y / CELULA) + 32768  # chave inteira: bem mais barata que Vector2i
		var cel = _grade.get(k)
		if cel == null:
			_grade[k] = [v]
		else:
			cel.append(v)
	Perf.fim("ini_grade", _p1)
	if espelho:
		_atualizar_espelho(dt)
		if not elementos.vis.is_empty():
			elementos.queue_redraw()
		return
	elementos.passo(dt)  # só quem tem estado (dicionário próprio); o laço abaixo nem olha
	# quem os vírus perseguem: o jogador local ou, no online, o jogador em pé mais perto
	var alvos: Array = online.alvos() if online else [[jog.centro(), 0]]
	if alvos.is_empty():
		alvos = [[jog.centro(), -1]]  # todo mundo caído: vão pro corpo do anfitrião sem ferir
	var alvo: Vector2 = alvos[0][0]
	var dono: int = alvos[0][1]
	var local: int = Rede.eu() if online else 0
	var k_vm := minf(1.0, dt * ACEL_VEL)  # suavização do andar (constante de tempo ~0,1 s); a investida arranca de uma vez
	var k_sep := dt * 12.0
	var k_kb := exp(-9.0 * dt)  # o knockback some em ~0,1 s (calculado uma vez por quadro, não por bicho)
	var espaco := float(Config.g("calculo_monstros"))  # aba Gráficos: 0,5 (frequente), 1 (normal), 2 (espaçado) x o intervalo
	var cad_perto := clampi(roundi(SEP_PERIODO * espaco / maxf(dt, 0.0001)), 1, 12)  # quadros entre dois cálculos de separação
	var cad_longe := clampi(roundi(SEP_PERIODO_LONGE * espaco / maxf(dt, 0.0001)), 1, 24)

	var _p2 := Perf.ini()
	for v: V in lista.duplicate():
		if v.hp <= 0:
			continue
		if v.flash > 0.0:
			v.flash = maxf(0.0, v.flash - dt)
		if v.lento > 0.0:
			v.lento = maxf(0.0, v.lento - dt)
		if v.atordoado > 0.0:
			v.atordoado = maxf(0.0, v.atordoado - dt)
		if v.t_nasc > 0.0:
			v.t_nasc = maxf(0.0, v.t_nasc - dt)
		if alvos.size() > 1:
			var md := INF
			for a in alvos:
				var d2: float = v.pos.distance_squared_to(a[0])
				if d2 < md:
					md = d2
					alvo = a[0]
					dono = a[1]
		var para: Vector2 = alvo - v.pos
		var dist: float = para.length()
		var dir: Vector2 = para / dist if dist > 0.01 else Vector2.ZERO
		var vel: float = 0.0 if v.atordoado > 0 else v.vel * (0.45 if v.lento > 0 else 1.0)
		var mov: Vector2 = dir * vel

		# quem atira mantém distância
		if v.distancia > 0:
			var dd := v.distancia
			if dist < dd * 0.8:
				mov = -dir * vel * 0.6
			elif dist < dd:
				mov = Vector2.ZERO
		# investida: para, treme e corre reto
		if v.investida > 0:
			match v.estado:
				0:
					v.t_inv -= dt
					if v.t_inv <= 0 and dist < 360:
						v.estado = 1
						v.t_estado = 0.7
						v.dir_inv = dir
				1:
					mov = Vector2.ZERO
					v.t_estado -= dt
					if v.t_estado <= 0:
						v.estado = 2
						v.t_estado = 0.6
						Som.tocar("whoosh", 0.1, 0.7)
				2:
					mov = v.dir_inv * vel * 5.0
					v.t_estado -= dt
					if v.t_estado <= 0:
						v.estado = 0
						v.t_inv = v.investida
		if v.atira > 0 and v.atordoado <= 0.0:  # atordoado ou congelado não atira
			v.t_atira -= dt
			if v.t_atira <= 0 and dist < 330:
				v.t_atira = v.atira
				_atirar(v, dir)
		if v.anel > 0 and v.atordoado <= 0.0:
			v.t_anel -= dt
			if v.t_anel <= 0 and dist < 400:
				v.t_anel = v.anel
				_anel(v)
		if not v.invoca.is_empty():
			v.t_invoca -= dt
			if v.t_invoca <= 0:
				var inv: Dictionary = v.invoca
				v.t_invoca = float(inv.get("a_cada", 5.0))
				for i in int(inv.get("quantos", 4)):
					var a := TAU * i / float(inv.get("quantos", 4))
					criar(str(inv.get("tipo", "bug")), v.pos + Vector2.from_angle(a) * (v.raio + 20), arena.diretor.nivel())

		# separação dos vizinhos (não empilham): cada inimigo recalcula a cada SEP_PERIODO s (SEP_PERIODO_LONGE
		# se está longe do alvo, onde ninguém vê) e o resultado (`sepv`) é aplicado aos poucos TODO quadro, então não dá tranco
		if (v.id + _quadro) % (cad_perto if dist < SEP_PERTO else cad_longe) == 0:
			var sep := Vector2.ZERO
			var px := v.pos.x
			var py := v.pos.y
			var kc: int = ((floori(px / CELULA) + 32768) << 16) + floori(py / CELULA) + 32768
			var checados := 0
			for ko in SEP_VIZ:
				var cel = _grade.get(kc + ko)
				if cel == null or checados > 20:
					continue
				for o: V in cel:
					checados += 1
					if checados > 20:
						break
					if o == v:
						continue
					var dx: float = px - o.pos.x
					var dy: float = py - o.pos.y
					var rr: float = v.raio + o.raio
					var d2 := dx * dx + dy * dy
					if d2 < rr * rr and d2 > 0.0001:
						var dl := sqrt(d2)
						var f := (rr - dl) / dl
						sep.x += dx * f
						sep.y += dy * f
			v.sepv = sep * (0.1 if v.chefe else 1.0)
		# anda: a velocidade acelera até a desejada (sem trocar de uma vez), a separação entra aos poucos todo quadro
		# (antes entrava inteira a cada 2 quadros: o bicho dava tranco) e o empurrão tem teto
		v.vm += (mov - v.vm) * (1.0 if v.estado == 2 else k_vm)
		var push := Vector2.ZERO
		if v.sepv.x != 0.0 or v.sepv.y != 0.0:
			push = v.sepv * k_sep
			var lim_s: float = maxf(v.vel * SEP_MAX, 24.0) * dt
			if push.length_squared() > lim_s * lim_s:
				push = push.normalized() * lim_s
		var p_ant: Vector2 = v.pos
		v.pos += (v.vm + v.kb) * dt + push
		v.kb *= k_kb
		if medir:
			var comp := {"movimento": (v.vm * dt).length(), "knockback": (v.kb * dt).length(), "separacao": push.length()}
			var causa := "movimento"
			var mx := 0.0
			for k in comp:
				if comp[k] > mx:
					mx = comp[k]
					causa = k
			_med_reg(v, dt, p_ant.distance_to(v.pos), causa, v.vel * (5.0 if v.estado == 2 else 1.0))

		# encostou no jogador
		if dist < v.raio + 8:
			_ferir_jogador(jog, dono, local, v.dano, v.tipo)
		# muito longe: volta pra perto (do lado de onde o jogador está indo)
		if dist > LONGE and not v.chefe and not v.d.has("fixo"):  # "fixo" (totem do objetivo) não reaparece perto do jogador
			var mov_j: Vector2 = jog.direcao_mov() if dono == local else Vector2.ZERO
			var a: float = mov_j.angle() + randf_range(-1.0, 1.0)
			if mov_j == Vector2.ZERO:
				a = randf() * TAU
			var destino: Vector2 = alvo + Vector2.from_angle(a) * randf_range(380, 440)
			_teleportar(v, destino)

	Perf.fim("ini_laco", _p2)
	# tiros dos inimigos
	for t in tiros.duplicate():
		t.pos += t.vel * dt
		t.vida -= dt
		var acertou := false
		for a in alvos:
			if t.pos.distance_squared_to(a[0]) < 100.0:
				_ferir_jogador(jog, a[1], local, t.dano, "tiro")
				acertou = true
				break
		if acertou or t.vida <= 0:
			tiros.erase(t)
	queue_redraw()
	Perf.fim("ini_atualizar", _p0)


## Teleporte de propósito (reciclagem de quem ficou longe, salto grande no online): o bicho some numa nuvem escura onde
## estava e reaparece em outra, no sentido contrário, em NASC_T s. Só vira desenho se estiver perto da tela; fora dela
## fica só o contador. Custo zero pra quem anda normal.
func _teleportar(v: V, destino: Vector2) -> void:
	tp_n += 1  # (o relatório do --saltos conta esses à parte: são saltos de propósito, com animação)
	if _na_tela(v.pos) and fantasmas.size() < 24:
		fantasmas.append(
			{"pos": v.pos, "tex": v.tex, "tam": v.tam, "sz": v.sz, "vira": v.espelho, "y0": v.tam.y * v.vista, "quadro": v.qd, "t": 0.0, "id": v.id}
		)
	v.pos = destino
	v.vm = Vector2.ZERO
	v.kb = Vector2.ZERO
	v.t_nasc = NASC_T


func _na_tela(p: Vector2) -> bool:
	if not (arena and arena.jogador):
		return false
	var c: Vector2 = arena.jogador.position
	return absf(p.x - c.x) < 340.0 and absf(p.y - c.y) < 200.0


func _fantasmas_passo(dt: float) -> void:
	var i := fantasmas.size() - 1
	while i >= 0:
		fantasmas[i].t += dt
		if fantasmas[i].t >= NASC_T:
			fantasmas.remove_at(i)
		i -= 1


## Nuvem escura de fumaça (4 bolhas): u = 0 (começo) a 1 (fim); nasce densa e se esvai subindo.
func _nuvem(ci: CanvasItem, p: Vector2, larg: float, u: float, semente: int) -> void:
	var a := 0.6 * (1.0 - u)
	if a <= 0.01:
		return
	var raio := larg * (0.3 + 0.4 * u)
	for j in 4:
		var ang := float(semente * 7 + j) * 1.7 + u * 1.5
		ci.draw_circle(p + Vector2.from_angle(ang) * raio * 0.5 + Vector2(0, -u * 8.0), raio * (0.55 + 0.1 * j), Color(0.09, 0.06, 0.14, a))


## A mesma nuvem, mas como discos na MultiMesh dos sprites (fica na ordem por altura, atrás do bicho que nasce).
func _nuvem_i(p: Vector2, larg: float, u: float, semente: int) -> void:
	var a := 0.6 * (1.0 - u)
	if a <= 0.01:
		return
	var raio := larg * (0.3 + 0.4 * u)
	for j in 4:
		var ang := float(semente * 7 + j) * 1.7 + u * 1.5
		var c := p + Vector2.from_angle(ang) * raio * 0.5 + Vector2(0, -u * 8.0)
		_id(c.x, c.y, raio * (0.55 + 0.1 * j), Color(0.09, 0.06, 0.14, a))


## Dano de vírus: no jogador daqui, ou (anfitrião online) manda pro computador de quem foi acertado.
func _ferir_jogador(jog: Node2D, quem: int, local: int, dano: float, fonte: String) -> void:
	if quem == local and quem >= 0:
		jog.sofrer(dano, fonte)
	elif quem > 0 and online:
		online.dano_remoto(quem, dano, fonte)


## Cliente online: os vírus só deslizam até a posição da última foto e os tiros seguem reto.
func _atualizar_espelho(dt: float) -> void:
	var dur: float = online.ENVIO if online else 1.0 / 15.0
	_dt = dt
	_fantasmas_passo(dt)
	for v: V in lista:
		v.flash = maxf(0.0, v.flash - dt)
		if v.t_nasc > 0.0:
			v.t_nasc = maxf(0.0, v.t_nasc - dt)
		# anda em linha reta da posição de antes até a da foto (uma foto de atraso); se a próxima atrasar, segue na mesma
		# direção por até meia foto e para: nunca dá o puxão de "pular pra última posição"
		v.t_foto += dt
		var k: float = v.t_foto / dur
		var p_ant: Vector2 = v.pos
		if k <= 1.0:
			v.pos = v.p_ini.lerp(v.p_fim, k)
		else:
			v.pos = v.p_fim + (v.p_fim - v.p_ini) * (minf(k, 1.5) - 1.0)
		if medir:
			_med_reg(v, dt, p_ant.distance_to(v.pos), "espelho", v.vel)
	for t in tiros:
		t.pos += t.vel * dt
	queue_redraw()


func _atirar(v: V, dir: Vector2) -> void:
	var tiro: Dictionary = v.d.get("tiro", {})
	_novo_tiro(v.pos, dir * float(tiro.get("velocidade", 100)), float(tiro.get("dano", 6)) * _mult_tiro(), str(tiro.get("sprite", "proj_email")))


func _anel(v: V) -> void:
	var tiro: Dictionary = v.d.get("tiro", {})
	var n := int(tiro.get("quantos", 10))
	var giro := randf() * TAU
	for i in n:
		var dir := Vector2.from_angle(giro + TAU * i / n)
		_novo_tiro(v.pos, dir * float(tiro.get("velocidade", 90)), float(tiro.get("dano", 8)) * _mult_tiro(), str(tiro.get("sprite", "proj_email")))
	Som.tocar("tremor", 0.3, 1.3, -6)


func _novo_tiro(pos: Vector2, vel: Vector2, dano: float, sprite: String) -> void:
	if tiros.size() > 300:
		return
	tiros.append({"pos": pos, "vel": vel, "dano": dano, "tex": Dados.tex(sprite), "vida": 5.0, "sprite": sprite})


# ---------- desenho ----------


## Pra onde o monstro olha: gira com velocidade limitada (GIRO_OLHAR) até o alvo e escolhe a vista da folha por setores de
## 45° (com histerese pra não piscar na divisa). Solo: o alvo é o herói. Cliente online: o deslocamento desenhado (como o
## `gira` do besouro), porque a IA roda no anfitrião. Vírus (vistas = 1) não entram: ficam sempre de frente, sem espelho.
func _orientar(v: V, jx: float, jy: float) -> void:
	if v.vistas <= 1:
		return
	var alvo := v.olhar
	var tem := false
	if espelho:
		if v.pos_olho != Vector2.INF:
			var d: Vector2 = v.pos - v.pos_olho
			var l2 := d.length_squared()
			if l2 > 0.04 and l2 < 400.0:  # parado mantém; teleporte não gira
				alvo = atan2(d.x, d.y)
				tem = true
		v.pos_olho = v.pos
	else:
		var dx := jx - v.pos.x
		var dy := jy - v.pos.y
		if dx * dx + dy * dy > 4.0:
			alvo = atan2(dx, dy)
			tem = true
	if v.orientar:
		v.orientar = false
		if tem:
			v.olhar = alvo
			v.setor = roundi(alvo / (PI * 0.25))
			if v.setor == -4:
				v.setor = 4
	elif tem:
		var passo := GIRO_OLHAR * _dt
		v.olhar = wrapf(v.olhar + clampf(angle_difference(v.olhar, alvo), -passo, passo), -PI, PI)
	if absf(angle_difference(v.setor * (PI * 0.25), v.olhar)) > PI * 0.125 + HIST_OLHAR:
		var k := roundi(v.olhar / (PI * 0.25))
		v.setor = 4 if k == -4 else k
	v.vista = absi(v.setor) if v.vistas > 1 else 0
	v.espelho = v.setor < 0


var _ac: Dictionary = {}  # dados/animacao_monstros.json por cima dos padrões (lido uma vez)
var _fr_d := 0  # quadros desenhados (os bichos animados atualizam o passo um quadro sim, outro não)
var _dt2 := 0.033
var _inv_dt2 := 30.0
var _lean_dt := 0.16
var _parado_seg := 0.12
var _parado_vel := 1.5


func _cfg() -> Dictionary:
	if _ac.is_empty():
		_ac = Anim.config()
	return _ac


func _draw() -> void:
	var _d0 := Perf.ini()
	var ac := _cfg()
	_fr_d += 1
	_dt2 = _dt * 2.0
	_inv_dt2 = 1.0 / maxf(_dt2, 0.0002)
	_lean_dt = minf(1.0, _dt2 * float(ac.inclina_suave))
	_parado_seg = ac.parado_seg
	_parado_vel = ac.parado_vel
	var jx: float = arena.jogador.position.x if arena and arena.jogador else 0.0
	var jy: float = arena.jogador.position.y if arena and arena.jogador else 0.0
	# só entra no desenho quem está na tela (com folga pro tamanho do sprite e da sombra): com 500 bichos, a maioria fica fora.
	# `_ordem` = os visíveis, do mais alto pro mais baixo (quem está embaixo fica na frente). Ordena uma lista de números
	# (y e posição na lista juntos numa chave só) com o sort nativo, todo quadro: bem mais barato que sort_custom.
	var sombra_proj: bool = Config.g("sombras") == "projetadas"  # perfil de qualidade (dados/graficos.json)
	var lod_x := float(Config.g("lod_monstros"))
	var vis: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var x0 := vis.position.x
	var x1 := vis.end.x
	var y0 := vis.position.y
	var y1 := vis.end.y
	_chaves.clear()
	var n := lista.size()
	for i in n:
		var v: V = lista[i]
		var m: float = maxf(v.sz.x, v.sz.y) + 28.0
		var p: Vector2 = v.pos
		if v.hp <= 0 or p.x < x0 - m or p.x > x1 + m or p.y < y0 - m or p.y > y1 + m:
			if v.gira:
				v.pos_ant = p  # fora da tela não gira (e não conta o passo como teleporte quando voltar)
			v.orientar = true  # ninguém vê: ao reaparecer já olha pro alvo (não gira de longe)
			v.pos_olho = Vector2.INF
			v.pos_f = Vector2.INF
			continue
		_chaves.append(float((int(p.y * 2.0) + 4194304) << 16) + float(i))
	_chaves.sort()
	_ordem.clear()
	for k in _chaves:
		_ordem.append(lista[int(k) & 65535])
	Perf.fim("ini_d_ordem", _d0)
	var _d1 := Perf.ini()
	_ns = 0
	_ni = 0
	var bs := _bs  # (escritas inline nas MultiMesh: roda por bicho por quadro; o buffer é por referência)
	var ns := 0
	var cap_s := bs.size() >> 4
	# 1ª passada: sombras (todas antes dos sprites, pra nenhuma sombra cair por cima de outro vírus). Vão pra MultiMesh das sombras
	# (a mancha de contato e o carimbo da sombra assada); só a sombra calculada na hora (sem orçamento de assar) sai direto no _draw.
	for v: V in _ordem:
		_orientar(v, jx, jy)  # (antes das sombras: elas dependem da vista e do espelho)
		var quadro: int
		if v.anim:
			# anda o ciclo pela distância percorrida desde o último desenho (conta inline: roda por bicho por quadro).
			# pos_f = INF (veio de fora da tela) dá l2 infinito: não conta; salto grande (teleporte) também não.
			# (um quadro sim, outro não, por bicho: a distância se acumula em pos_f e o dt vale o dobro; ninguém vê o quadro do
			# passo mudar 1 quadro de tela depois, e a conta sai pela metade do custo)
			if ((v.id + _fr_d) & 1) == 0:
				var ddx: float = v.pos.x - v.pos_f.x
				var ddy: float = v.pos.y - v.pos_f.y
				var l2: float = ddx * ddx + ddy * ddy
				v.pos_f = v.pos
				if l2 > 0.0004 and l2 < 1600.0:
					v.fase += sqrt(l2) * v.inv_ciclo
					if v.fase >= 1.0:
						v.fase -= 1.0
					v.parado = 0.0
					v.lean += (clampf(ddx * _inv_dt2 * v.inv_vel, -1.0, 1.0) - v.lean) * _lean_dt
				else:
					v.parado += _dt2
					v.lean -= v.lean * _lean_dt
					if v.parado > _parado_seg:
						v.fase = Anim.assentar(v.fase, _dt2, _parado_vel)
				v.qd = mini(int(v.fase * v.nq), v.nq - 1)
				# a sombra assada é a de 2 quadros do ciclo (o atlas de sombras não comporta todos)
				v.q_sh = v.q_meio if v.qd >= v.q_ini and v.qd < v.q_ini + v.q_meio else 0
			quadro = v.q_sh
		else:
			quadro = int(_t * v.ritmo + v.id) % 2
			v.qd = quadro
		if v.t_nasc > NASC_T * 0.4:
			continue
		var s: Vector2 = v.sz
		var pe: Vector2 = v.pos + Vector2(0, s.y * 0.4)
		var cw := s.x * 0.75  # mancha de contato (Visual.contato): largura cw, altura 0,32 cw, centrada no pé
		if not sombra_proj:  # perfil de qualidade baixa: só a mancha de contato no pé (a sombra inclinada é uma textura a mais por bicho)
			if ns + 2 > cap_s:
				_crescer_bs()
				cap_s = bs.size() >> 4
			var o1 := ns << 4
			bs[o1] = cw
			bs[o1 + 3] = pe.x - cw * 0.5
			bs[o1 + 5] = cw * 0.32
			bs[o1 + 7] = pe.y - cw * 0.16
			bs[o1 + 12] = 0.0
			bs[o1 + 13] = 0.0
			bs[o1 + 14] = 24.0
			bs[o1 + 15] = 8.0
			ns += 1
			continue
		var esp: bool = v.espelho
		var ic := (v.vista * 2 + (1 if quadro > 0 else 0)) * 2 + (1 if esp else 0)
		var reg: Rect2 = v.sombra_reg[ic]
		var esc_s := s.x / v.tam.x
		if reg.size.x <= 0.0:
			var src := Rect2(v.tam.x * quadro, v.tam.y * v.vista, v.tam.x, v.tam.y)
			reg = Visual.sombra_regiao(v.tex, src, esp)
			v.sombra_reg[ic] = reg
		if ns + 2 > cap_s:
			_crescer_bs()
			cap_s = bs.size() >> 4
		var o1 := ns << 4
		bs[o1] = cw
		bs[o1 + 3] = pe.x - cw * 0.5
		bs[o1 + 5] = cw * 0.32
		bs[o1 + 7] = pe.y - cw * 0.16
		bs[o1 + 12] = 0.0
		bs[o1 + 13] = 0.0
		bs[o1 + 14] = 24.0
		bs[o1 + 15] = 8.0
		ns += 1
		if reg.size.x > 0.0:
			# mesma conta de Visual.sombra: a base do sprite fica em pe.y + (-s.y + s.y) e a esquerda em pe.x - s.x/2 (ou pe.x + s.x/2 - s.x se espelhado = igual)
			var o2 := ns << 4
			bs[o2] = reg.size.x * esc_s
			bs[o2 + 3] = pe.x - s.x * 0.5
			bs[o2 + 5] = reg.size.y * esc_s
			bs[o2 + 7] = pe.y - esc_s
			bs[o2 + 12] = reg.position.x
			bs[o2 + 13] = reg.position.y
			bs[o2 + 14] = reg.size.x
			bs[o2 + 15] = reg.size.y
			ns += 1
		else:
			var src2 := Rect2(v.tam.x * quadro, v.tam.y * v.vista, v.tam.x, v.tam.y)
			var rs := Rect2(s.x / 2, -s.y, -s.x, s.y) if esp else Rect2(-s.x / 2, -s.y, s.x, s.y)
			Visual.sombra(self, v.tex, rs, src2, pe)
	_ns = ns
	_enviar_mm(_mm_som, _bs, _ns)
	Perf.fim("ini_d_sombra", _d1)
	_no_marcas.queue_redraw()  # marcas de aviso no chão: ver _desenhar_marcas
	var _d2 := Perf.ini()
	_flashes.clear()
	_barras.clear()
	# movimento secundário dos monstros (animacao_monstros.json): inclinação e quique só pra quem está perto do herói (LOD);
	# com horda enorme na tela o círculo encolhe. O aperto de golpe e o preparo de investida valem pra todos (são raros).
	var lod_d2: float = ac.lod_dist * ac.lod_dist * lod_x * lod_x * (0.25 if _ordem.size() > ac.lod_max else 1.0)
	var a_inclina: float = ac.inclina
	var a_topo: float = ac.inclina_topo
	var a_passo: float = ac.passo_aperto
	var a_respira: float = ac.respira
	var a_golpe: float = ac.aperto_golpe
	var a_golpe_seg: float = ac.aperto_golpe_seg
	var a_quique: float = ac.aperto_golpe_quique
	var ger: int = _atlas.geracao
	var bi := _bi
	for v: V in _ordem:
		if v.elite or v.chefe:
			_barras.append(v)  # barra de vida: só elite e chefe (os comuns só pagam este teste)
		if v.at_gen != ger:
			v.at = _atlas.deslocamento(v.tex)  # a folha entra no atlas na 1ª vez que o tipo aparece
			v.at_gen = _atlas.geracao
			ger = _atlas.geracao
		var s: Vector2 = v.sz
		var vira: bool = v.espelho
		var quadro: int = v.cols - 1 if v.flash > 0 else v.qd
		var th: float = _t - v.t_golpe if v.anim else 99.0
		var mexe := false  # anim e pertinho: ganha bob, inclinação e passo (senão desenha pelo caminho rápido)
		if v.anim:
			var ddx: float = v.pos.x - jx
			var ddy: float = v.pos.y - jy
			mexe = ddx * ddx + ddy * ddy < lod_d2
		var cor := Color.WHITE
		if v.aura.a > 0.0:
			_id(v.pos.x, v.pos.y, s.x * 0.5, Color(v.aura.r, v.aura.g, v.aura.b, 0.16 + 0.08 * sin(_t * 5.0 + v.id)))
		elif v.elite:
			_id(v.pos.x, v.pos.y, s.x * 0.55, Color(1.0, 0.85, 0.3, 0.25 + 0.15 * sin(_t * 8.0)))
		elif v.atordoado > 0:
			cor = Color(1.0, 0.95, 0.6)  # atordoado: amarelado, piscando de leve
		elif v.lento > 0:
			cor = Color(0.6, 0.85, 1.0)
		if v.el_vis != 0:  # estado de elemento (#72): tinta por estado, uma comparação por inimigo
			cor = Elementos.tinta(v.el_vis, _t, v.id) * Color(1, 1, 1, cor.a)
		if v.atira > 0.0 and v.t_atira > 0.0 and v.t_atira < TELEGRAFA_T and int(_t * 25.0) % 2 == 0:
			cor = Color(1.0, 0.55, 0.5, cor.a)  # telegrafa o tiro: pisca avermelhado nos 0,4 s antes de atirar (só no anfitrião/solo, que é quem tem o relógio)
		# Rect2 de largura negativa vira o sprite, mas o Godot desenha a partir da posição pra DIREITA (não normaliza):
		# por isso a posição é a borda esquerda nos dois casos (antes o bicho à direita do herói saía deslocado 1 largura).
		var r: Rect2
		if v.estado == 0 and v.flash <= 0.0 and (v.anim or v.balanco <= 0.0) and v.flutua <= 0.0 and v.t_nasc <= 0.0 and not mexe and th >= a_golpe_seg:
			r = Rect2(v.pos.x - s.x * 0.5, v.pos.y - s.y * 0.6, -s.x if vira else s.x, s.y)  # caminho rápido (vírus)
		else:
			var fase_a: float = (_t * v.ritmo + v.id) * PI  # o pulinho acompanha a troca de quadro
			var sx := 1.0
			var sy := 1.0
			var jit := 0.0
			var lift := 0.0
			if v.estado == 1:
				# telegrafa a investida: agacha, treme e avermelha; nos últimos 35% pisca branco
				var u := clampf(1.0 - v.t_estado / 0.7, 0.0, 1.0)
				var e := u
				var cl := 0.18
				var ca := 0.24
				if v.anim:  # monstros de 5 vistas: curva devagar-e-depois-rápido, puxa o corpo pra trás antes de disparar
					e = Anim.carga(u, ac.carga_curva)
					cl = ac.carga_largura
					ca = ac.carga_altura
					if v.dir_inv.x != 0.0:
						jit = -signf(v.dir_inv.x) * ac.carga_recuo * e
				sx = 1.0 + cl * e
				sy = 1.0 - ca * e
				jit += sin(_t * 90.0 + v.id) * 1.5 * u
				cor = Color(1.0, 1.0 - 0.55 * u, 1.0 - 0.6 * u)
				if u > 0.65 and int(_t * 20.0) % 2 == 0:
					quadro = v.cols - 1
			elif v.estado == 2:
				sx = 1.22  # em disparada: esticado no sentido da corrida
				sy = 0.86
			elif v.anim:
				# andando de verdade: o corpo sobe e desce com o passo (um quique por passo) e aperta de leve a cada pisada;
				# parado, só respira. Longe do herói (LOD) fica reto, desenhado como antes.
				if mexe:
					if v.parado < _parado_seg:
						var sub := 0.5 + 0.5 * cos(12.566371 * v.fase)  # = Anim.subida(fase), inline: roda por bicho por quadro
						lift = v.bob_px * sub
						sx = 1.0 + a_passo * (1.0 - sub)
						sy = 1.0 - a_passo * (1.0 - sub)
					else:
						var rs := a_respira * sin(_t * 2.5 + v.id)
						sx = 1.0 + rs
						sy = 1.0 - rs
			else:
				var sn := sin(fase_a)
				if v.balanco > 0.0:
					lift = absf(sn) * v.balanco
				var respira := 1.0 - 2.0 * sn * sn  # = cos(2 x fase), sem outra chamada trigonométrica
				sx = 1.0 + 0.045 * respira
				sy = 1.0 - 0.045 * respira
			if v.flutua > 0.0:
				lift += v.flutua * (1.0 + 0.25 * sin(_t * 3.0 + v.id))
			if v.anim:
				if th < a_golpe_seg:  # aperto ao levar golpe: achata e alarga, volta com um quique (aperto_golpe*)
					var ka := Anim.aperto(th, a_golpe_seg, a_quique)
					sx *= 1.0 + a_golpe * 1.15 * ka
					sy *= 1.0 - a_golpe * ka
			elif v.flash > 0.0:
				var k := v.flash / 0.09  # squash ao levar dano: achata e alarga, voltando em ~0,1 s
				sx *= 1.0 + 0.3 * k
				sy *= 1.0 - 0.24 * k
			if v.t_nasc > 0.0:
				# nasce / reaparece (teleporte): sai de uma nuvem escura, crescendo e ficando opaco
				var u := 1.0 - v.t_nasc / NASC_T
				sx *= 0.45 + 0.55 * u
				sy *= 0.3 + 0.7 * u
				cor.a = u
				_nuvem_i(v.pos + Vector2(0, s.y * 0.35), s.x, u, v.id)
			var w := roundf(s.x * sx)  # a largura nunca vai a ~0: virar é trocar de vista, não achatar
			var h := roundf(s.y * sy)
			r = Rect2(roundf(v.pos.x + jit) - roundf(w * 0.5), roundf(v.pos.y + s.y * 0.4 - lift) - h, -w if vira else w, h)
		v.dr = r
		# recorte da folha no atlas, em pixels (x, y do quadro; largura, altura de um quadro)
		var fw: float = v.tam.x
		var fh: float = v.tam.y
		var fx: float = v.at.x + fw * quadro
		var fy: float = v.at.y + fh * v.vista
		var rw: float = r.size.x
		if v.gira:
			# visto de cima: a cabeça aponta pra onde ele anda (antes vinha de ré quando descia na direção do herói)
			var passo: Vector2 = v.pos - v.pos_ant if v.pos_ant != Vector2.INF else Vector2.ZERO
			v.pos_ant = v.pos
			if passo.length_squared() > 0.04 and passo.length_squared() < 400.0:  # parado mantém; teleporte não gira
				v.ang = lerp_angle(v.ang, passo.angle() + PI * 0.5, minf(1.0, _dt * 10.0))
			var gw := absf(rw)
			_ig(r.position.x + gw * 0.5, r.position.y + r.size.y * 0.5, gw, r.size.y, v.ang, fx, fy, fw, fh, cor)
		else:
			var inc := 0
			if mexe and v.parado < _parado_seg:
				inc = roundi(v.lean * a_inclina * s.y)
			# (largura negativa = espelhado: o recorte começa na borda direita e anda pra esquerda)
			var rx: float = fx + fw if rw < 0.0 else fx
			var rcw: float = -fw if rw < 0.0 else fw
			var aw := absf(rw)
			if inc != 0:
				# inclinação pro lado em que anda: a faixa de cima do sprite se adianta `inc` px (cisalhamento por faixas:
				# o pixel continua nítido, o que girar o sprite não dá). `inclina_topo` = fração de cima que se desloca.
				var corte := maxi(1, roundi(v.tam.y * a_topo))
				var hc := roundf(r.size.y * corte / v.tam.y)
				_ii(r.position.x + inc, r.position.y, aw, hc, rx, fy, rcw, corte, cor)
				_ii(r.position.x, r.position.y + hc, aw, r.size.y - hc, rx, fy + corte, rcw, fh - corte, cor)
			else:
				# (o caso comum, escrito inline: um sprite inteiro, sem faixas)
				var o3 := _ni << 4
				if o3 + 16 > bi.size():
					_crescer_bi()
				bi[o3] = aw
				bi[o3 + 1] = 0.0
				bi[o3 + 3] = r.position.x
				bi[o3 + 4] = 0.0
				bi[o3 + 5] = r.size.y
				bi[o3 + 7] = r.position.y
				bi[o3 + 8] = cor.r
				bi[o3 + 9] = cor.g
				bi[o3 + 10] = cor.b
				bi[o3 + 11] = cor.a
				bi[o3 + 12] = rx
				bi[o3 + 13] = fy
				bi[o3 + 14] = rcw
				bi[o3 + 15] = fh
				_ni += 1
			if v.flash > 0.09 - FLASH_BRANCO and _flashes.size() < FLASH_MAX:
				_flashes.append([v.tex, r, Rect2(v.tam.x * quadro, v.tam.y * v.vista, v.tam.x, v.tam.y), 0.9 * cor.a])
	if _mm_spr.texture != _atlas.textura:
		_mm_spr.texture = _atlas.textura  # o atlas cresceu (textura nova)
	_atlas.enviar()
	_enviar_mm(_mm_spr, _bi, _ni)
	_flash_no.queue_redraw()
	Perf.fim("ini_d_sprite", _d2)
	barras_n = _barras.size()
	_no_topo.queue_redraw()  # barras de elite/chefe, fantasmas do teleporte e tiros: ver _desenhar_topo


## Marcas de aviso no chão (#68): a faixa por onde a investida vai passar e o anel antes dos tiros em anel. Ficam entre as sombras e
## os sprites. No online os clientes não recebem a direção da investida nem o relógio do anel: lá fica só o aviso no corpo.
func _desenhar_marcas() -> void:
	var c := _no_marcas
	for v: V in _ordem:
		if v.estado == 1 and v.dir_inv != Vector2.ZERO:
			var u := clampf(1.0 - v.t_estado / 0.7, 0.0, 1.0)
			var fim: Vector2 = v.pos + v.dir_inv * v.vel * 5.0 * 0.6  # o que ele corre na investida (5x por 0,6 s)
			c.draw_line(v.pos, fim, Color(1.0, 0.15, 0.1, 0.1 + 0.18 * u), maxf(10.0, v.raio * 1.6))
			c.draw_line(v.pos, fim, Color(1.0, 0.4, 0.3, 0.45 + 0.4 * u), 1.0)
		if v.anel > 0 and v.t_anel > 0.0 and v.t_anel < AVISO_ANEL:
			var u2 := 1.0 - v.t_anel / AVISO_ANEL
			Legib.marca_perigo(c, v.pos, v.raio + 26.0 - 12.0 * u2, u2)  # o mesmo anel de aviso das outras áreas (#72 marco 7)


## Por cima dos sprites: barra fina de elite/chefe (com o nome curto logo depois de um golpe), os fantasmas do teleporte e os tiros.
func _desenhar_topo() -> void:
	var c := _no_topo
	for v: V in _barras:
		var topo: float = v.pos.y - v.sz.y * 0.6
		Legib.barra(c, v.pos.x, topo, v.sz.x * 0.8, v.hp / maxf(v.hpmax, 1.0), v.chefe)
		if Config.v("nomes_inimigo") and Legib.mostra_nome(_t, v.t_golpe):
			Legib.nome_sobre(c, v.pos.x, topo - 14.0, Legib.nome_curto(str(v.d.get("nome", ""))))
	for f in fantasmas:  # quem acabou de teleportar: encolhe e some numa nuvem escura onde estava
		var u: float = f.t / NASC_T
		var fs: Vector2 = f.sz * (1.0 - 0.6 * u)
		var fp: Vector2 = f.pos
		var fe := fp + Vector2(0, f.sz.y * 0.4)
		_nuvem(c, fe + Vector2(0, -f.sz.y * 0.05), f.sz.x, u, f.id)
		c.draw_texture_rect_region(
			f.tex,
			Rect2(fp.x - fs.x * 0.5, fe.y - fs.y, -fs.x if f.vira else fs.x, fs.y),
			Rect2(f.tam.x * f.quadro, f.y0, f.tam.x, f.tam.y),
			Color(1, 1, 1, 1.0 - u)
		)
	for t in tiros:
		var tx: Texture2D = t.tex
		var sz := tx.get_size() * ESCALA
		c.draw_set_transform(t.pos, t.vel.angle(), Vector2.ONE)
		c.draw_texture_rect(tx, Rect2(-sz / 2, sz), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Dano dos tiros dos inimigos com o calor ("Garras Afiadas" vale pros tiros também).
func _mult_tiro() -> float:
	return 1.0 + (arena.ef("inimigo_dano") if arena and arena.has_method("ef") else 0.0)
