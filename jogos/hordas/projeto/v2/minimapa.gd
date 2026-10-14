extends CanvasLayer
## Minimapa da v2 (cena própria, v2/minimapa.tscn). O mundo o instancia dentro da apresentação 960x540 (layer 5: fora do CanvasModulate,
## como o brilho). Pequeno no canto superior direito; Tab segurado abre o mapa grande no centro, semitransparente; ao soltar, volta ao pequeno.
##
## Fundo: gerado UMA vez no _ready a partir de mundo.dados (trilhas e lajes em cinza, árvores em verde escuro, poças em azul, santuário
## dourado, bordas fechadas em escuro): 1 px do minimapa = 19,2 px do mundo, 150x84. A névoa começa escura e cada ponto que o herói
## alcança fica revelado até o fim da partida. Marcadores (herói, monstros perto, luzes fortes) são repintados a ~10 Hz, não a cada quadro.
##
## Dados do mundo, lidos com get() e valor padrão (o combate entra depois): mundo.heroi (pos, mira_mundo, dir_olhar), monstros_vivos
## (se existir; senão, mundo.monstros), mundo.cenario.objetos (só braseiro e fogueira viram luz), mundo.mapa e mundo.limite_andavel.
## Opções (após --): --minimapa=grande abre já no mapa grande (fotos); --sem_minimapa não monta nada (medir o custo).
## Testes: passar(dt) e ler_tecla(pressionada) são os passos (sem relógio de parede); testes/v2_minimapa.tscn.

const Heroi := preload("res://v2/heroi.gd")
const MOLDURA := preload("res://v2/hud/minimapa_moldura.png")

const LARG := 960
const ALT := 540
const MAPA_LARG := 150  # px do minimapa
const MAPA_ALT := 84
const MARGEM := 10  # a moldura tem 10 px de borda e miolo transparente (v2/hud/gerar_minimapa_moldura.py)
const MARGEM_TELA := 8  # distância do minimapa pequeno à borda direita e ao topo
const ESCALA_GRANDE := 4  # o mapa grande é o mesmo desenho ampliado em número inteiro: pixel art nítida
const PERIODO := 0.1  # 10 Hz
const RAIO_REVELA := 230.0  # px do mundo que a névoa revela em volta do herói
const RAIO_MONSTRO := 600.0  # monstros dentro disso aparecem como pontos vermelhos
const RAIO_SETA := 900.0  # missões mais longe do herói que isto ganham uma seta na borda do minimapa
const LUZES_FORTES := ["braseiro", "fogueira"]

# paleta de docs/visual_2_5d/paleta.json (ui e elementos)
const C_FORA := Color("07090d")
const C_CHAO := Color("26362d")
const C_FECHADO := Color("101a14")  # bordas do mapa, fechadas por árvores
const C_ARVORE := Color("2f7a40")  # verde escuro (um tom acima para aparecer sobre o chão)
const C_ARBUSTO := Color("3f8f4f")
const C_TRILHA := Color("8a929c")  # cinza
const C_LAJE := Color("a3abb4")
const C_PEDRA := Color("d2d8de")  # estruturas e pedras, mais claras
const C_AGUA := Color("3f8fd8")
const C_SANTUARIO := Color("ddcc80")  # objetivo
const C_HEROI := Color("edf0f6")  # texto
const C_MONSTRO := Color("c5251c")  # dano vermelho
const C_LUZ := Color("d87a2b")  # fogo
const C_NEVOA := Color("01030b")  # painel
const C_BAU := Color("f1c35a")  # baú ativo, só desenhado depois de visto pela névoa

const OBJETOS := {
	"arvore": C_ARVORE,
	"arvore_pantano": C_ARVORE,
	"arvore_morta": C_ARVORE,
	"arbusto": C_ARBUSTO,
	"juncos": C_ARBUSTO,
	"cogumelos": C_ARBUSTO,
	"raizes": C_ARBUSTO,
	"toco": C_ARBUSTO,
	"tronco": C_ARBUSTO,
	"lapide": C_PEDRA,
	"muro": C_PEDRA,
	"pilar": C_PEDRA,
	"coluna": C_PEDRA,
	"obelisco": C_PEDRA,
	"pedestal": C_PEDRA,
	"altar": C_PEDRA,
	"runa": C_PEDRA,
	"pedra": C_PEDRA,
	"pedras": C_PEDRA,
	"rocha": C_PEDRA,
	"cranio": C_PEDRA,
	"caixa_oferenda": C_PEDRA,
	"toro": C_PEDRA,
	"torii_quebrado": C_PEDRA,
}  # árvores com 2x2 px; o resto, 1 px
const DECALQUES := {
	"trilha_reta": C_TRILHA,
	"trilha_diagonal": C_TRILHA,
	"trilha_curva": C_TRILHA,
	"pedrinhas_1": C_LAJE,
	"pedrinhas_2": C_LAJE,
	"poca": C_AGUA,
}

var mundo
var grande := false  # true com o mapa grande aberto
var fundo: ImageTexture  # o mapa de fundo: criado uma vez
var monstros_mapa: Array[Vector2] = []  # monstros perto do herói (coordenadas do minimapa)
var luzes_mapa: Array[Vector2] = []  # braseiros e fogueiras do mapa
var luzes_vistas: Array[Vector2] = []  # as que a névoa já revelou
var baus_mapa: Array[Vector2] = []  # baús ativos que a névoa já revelou
var setas_mapa: Array[Vector2] = []  # pontos na borda do minimapa que apontam para as missões longe do herói
var heroi_mapa := Vector2.ZERO
var mira_dir := Vector2(0, 1)
var atualizacoes := 0  # quantas vezes os marcadores foram repintados (teste: 10 por segundo)

var _nevoa_img: Image
var _nevoa: ImageTexture
var _acum := 0.0
var _tab_antes := false
var _ultimo_texel := Vector2i(-1, -1)
var _k := 1
var _desenho: Control
var _quadro: NinePatchRect
var _escurecer: ColorRect


func _ready() -> void:
	if _opcao("sem_minimapa") != "":
		queue_free()
		return
	grande = _opcao("minimapa") == "grande"
	_montar_nos()
	_gerar_fundo()
	_nevoa_img = Image.create(MAPA_LARG, MAPA_ALT, false, Image.FORMAT_RGBA8)
	_nevoa_img.fill(C_NEVOA)
	_nevoa = ImageTexture.create_from_image(_nevoa_img)
	_ler_luzes()
	passar(PERIODO)  # a primeira leitura já revela a névoa em volta do herói
	_layout()


## O mundo chama isto antes de entrar na árvore: `sv.add_child(...instantiate().iniciar(self))`.
func iniciar(m) -> CanvasLayer:
	mundo = m
	return self


func _opcao(nome: String) -> String:
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		if p[0] == nome:
			return p[1] if p.size() > 1 else "1"
	return ""


# ------------------------------------------------------------------ montagem


func _montar_nos() -> void:
	_escurecer = ColorRect.new()  # só no mapa grande: escurece um pouco o mundo por trás
	_escurecer.color = Color(C_NEVOA, 0.45)
	_escurecer.size = Vector2(LARG, ALT)
	_escurecer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escurecer.visible = false
	add_child(_escurecer)
	_desenho = Control.new()
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_desenho.draw.connect(_pintar)
	add_child(_desenho)
	_quadro = NinePatchRect.new()  # a moldura fica por cima do mapa, e o miolo dela é transparente
	_quadro.texture = MOLDURA
	_quadro.draw_center = false
	_quadro.patch_margin_left = MARGEM
	_quadro.patch_margin_right = MARGEM
	_quadro.patch_margin_top = MARGEM
	_quadro.patch_margin_bottom = MARGEM
	_quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quadro)


## Fundo do mapa: pintado uma vez, pixel a pixel, a partir dos dados do mundo (nada de desenhar por quadro).
func _gerar_fundo() -> void:
	var cfg: Dictionary = mundo.dados.get("minimapa", {})  # mapas novos: cores e tamanhos por nome (a floresta não tem a chave e usa as tabelas acima)
	var cor_fechado := Color(str(cfg.get("fechado", "101a14")))
	var img := Image.create(MAPA_LARG, MAPA_ALT, false, Image.FORMAT_RGBA8)
	img.fill(Color(str(cfg.get("chao", "26362d"))))
	var andavel: Rect2 = mundo.limite_andavel
	for y in MAPA_ALT:
		for x in MAPA_LARG:
			if not andavel.has_point(mapa_para_mundo(Vector2(x + 0.5, y + 0.5))):
				img.set_pixel(x, y, cor_fechado)
	for x in MAPA_LARG:
		img.set_pixel(x, 0, C_FORA)
		img.set_pixel(x, MAPA_ALT - 1, C_FORA)
	for y in MAPA_ALT:
		img.set_pixel(0, y, C_FORA)
		img.set_pixel(MAPA_LARG - 1, y, C_FORA)
	var dados: Dictionary = mundo.dados
	if not cfg.is_empty():
		_pintar_cfg(img, dados, cfg)
		fundo = ImageTexture.create_from_image(img)
		return
	for d in dados.get("decalques", []):
		var nome := str(d[0])
		var q := mundo_para_mapa(Vector2(float(d[1]), float(d[2])))
		if DECALQUES.has(nome):
			_quadrado(img, q, 2 if nome == "poca" else 1, DECALQUES[nome])
		elif nome == "circulo":
			_anel(img, q, 5.0, C_SANTUARIO)
	for o in dados.get("objetos", []):
		var nome := str(o[0])
		var q := mundo_para_mapa(Vector2(float(o[1]), float(o[2])))
		if nome == "torii":
			_torii(img, q)
		elif OBJETOS.has(nome):
			var arvore: bool = OBJETOS[nome] == C_ARVORE
			_quadrado(img, q, 2 if arvore else 1, OBJETOS[nome])
	fundo = ImageTexture.create_from_image(img)


## Mapas novos: "minimapa" do json = {chao, fechado, decalques: {nome: [cor, px] ou [cor, raio, "anel"]}, objetos: {nome: [cor, px]},
## luzes_fortes: [nomes]}. Só o que está na tabela aparece.
func _pintar_cfg(img: Image, dados: Dictionary, cfg: Dictionary) -> void:
	var td: Dictionary = cfg.get("decalques", {})
	for d in dados.get("decalques", []):
		var e = td.get(str(d[0]))
		if e == null:
			continue
		var q := mundo_para_mapa(Vector2(float(d[1]), float(d[2])))
		if e.size() > 2 and str(e[2]) == "anel":
			_anel(img, q, float(e[1]), Color(str(e[0])))
		else:
			_quadrado(img, q, int(e[1]), Color(str(e[0])))
	var to: Dictionary = cfg.get("objetos", {})
	for o in dados.get("objetos", []):
		var e = to.get(str(o[0]))
		if e != null:
			_quadrado(img, mundo_para_mapa(Vector2(float(o[1]), float(o[2]))), int(e[1]), Color(str(e[0])))


func _ler_luzes() -> void:
	var fortes: Array = mundo.dados.get("minimapa", {}).get("luzes_fortes", LUZES_FORTES)
	for a in mundo.cenario.objetos:
		if str(a.chave) in fortes:
			luzes_mapa.append(mundo_para_mapa(a.pos))


func _quadrado(img: Image, q: Vector2, n: int, cor: Color) -> void:
	var r := Rect2i(Vector2i(q.floor()) - Vector2i(n / 2, n / 2), Vector2i(n, n))
	img.fill_rect(r.intersection(Rect2i(0, 0, MAPA_LARG, MAPA_ALT)), cor)


func _anel(img: Image, q: Vector2, raio: float, cor: Color) -> void:
	for y in range(int(q.y - raio) - 1, int(q.y + raio) + 2):
		for x in range(int(q.x - raio) - 1, int(q.x + raio) + 2):
			if x < 0 or y < 0 or x >= MAPA_LARG or y >= MAPA_ALT:
				continue
			if absf(Vector2(x + 0.5, y + 0.5).distance_to(q) - raio) < 0.6:
				img.set_pixel(x, y, cor)


## Torii do santuário: barra de cima e dois pilares (5x3 px).
func _torii(img: Image, q: Vector2) -> void:
	var c := Vector2i(q.floor())
	for dx in range(-2, 3):
		_pixel(img, c + Vector2i(dx, -2), C_SANTUARIO)
	for dy in range(-1, 2):
		_pixel(img, c + Vector2i(-1, dy), C_SANTUARIO)
		_pixel(img, c + Vector2i(1, dy), C_SANTUARIO)


func _pixel(img: Image, p: Vector2i, cor: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < MAPA_LARG and p.y < MAPA_ALT:
		img.set_pixel(p.x, p.y, cor)


## Tamanho e posição dos dois modos: pequeno (150x84 + moldura) no canto superior direito; grande (4x) no centro.
func _layout() -> void:
	_k = ESCALA_GRANDE if grande else 1
	var mapa_px := Vector2(MAPA_LARG, MAPA_ALT) * _k
	var quadro_tam := mapa_px + Vector2(MARGEM, MARGEM) * 2.0
	var quadro_pos := (Vector2(LARG, ALT) - quadro_tam) / 2.0
	if not grande:
		quadro_pos = Vector2(LARG - MARGEM_TELA - quadro_tam.x, MARGEM_TELA)
	_quadro.position = quadro_pos
	_quadro.size = quadro_tam
	_desenho.position = quadro_pos + Vector2(MARGEM, MARGEM)
	_desenho.size = mapa_px
	_desenho.modulate.a = 0.88 if grande else 1.0
	_escurecer.visible = grande
	_desenho.queue_redraw()


# ------------------------------------------------------------------ quadro e entrada


func _process(delta: float) -> void:
	ler_tecla(Input.is_key_pressed(KEY_TAB))
	passar(delta)


## Tab segurado: o mapa grande fica aberto enquanto o Tab está apertado e volta ao pequeno ao soltar. Só a mudança de estado conta
## (o --minimapa=grande não é desfeito no primeiro quadro). Fica por polling porque os nós de dentro do SubViewport não recebem _input.
func ler_tecla(pressionada: bool) -> void:
	if pressionada != _tab_antes:
		grande = pressionada
		_layout()
	_tab_antes = pressionada


## Um passo do minimapa. Acumula o tempo e, a cada 0,1 s, atualiza névoa e marcadores.
func passar(dt: float) -> void:
	_acum += dt
	if _acum < PERIODO:
		return
	_acum = fmod(_acum, PERIODO)  # guarda o resto: a média fica em 10 Hz mesmo com quadros que não caem certinho
	_atualizar()


func _atualizar() -> void:
	atualizacoes += 1
	var h = mundo.heroi
	var centro: Vector2 = h.pos + Heroi.CENTRO_CORPO
	heroi_mapa = mundo_para_mapa(centro)
	var d: Vector2 = h.mira_mundo - centro
	mira_dir = d.normalized() if d.length() > 1.0 else h.dir_olhar
	var texel := Vector2i(heroi_mapa.floor())
	if texel != _ultimo_texel:  # a névoa só muda quando o herói passa para outro ponto do minimapa
		_ultimo_texel = texel
		if _revelar(heroi_mapa):
			_nevoa.update(_nevoa_img)
	monstros_mapa.clear()
	for mo in _monstros():
		var p = mo.get("pos")
		if p is Vector2 and (p as Vector2).distance_to(centro) <= RAIO_MONSTRO:
			monstros_mapa.append(mundo_para_mapa(p))
	luzes_vistas.clear()
	for q in luzes_mapa:
		if _revelado_mapa(q):
			luzes_vistas.append(q)
	baus_mapa.clear()  # baús só aparecem depois de vistos pela névoa
	for b in _baus():
		var qb := mundo_para_mapa(b.pos)
		if b.ativo and _revelado_mapa(qb):
			baus_mapa.append(qb)
	setas_mapa.clear()
	for p in _missoes():
		if centro.distance_to(p) > RAIO_SETA:
			setas_mapa.append(_na_borda(heroi_mapa, mundo_para_mapa(p)))
	_desenho.queue_redraw()


## O mirante (marca do mundo): o mapa inteiro sai da névoa de uma vez.
func revelar_tudo() -> void:
	_nevoa_img.fill(Color(0, 0, 0, 0))
	_nevoa.update(_nevoa_img)


## Os baús do combate (cada um com `ativo` e `pos` do mundo). Lidos com get() e valor padrão, como o resto.
func _baus() -> Array:
	var c = mundo.get("combate")
	return c.baus.lista if c != null else []


## As missões que pedem seta (chefe e portão, das marcas do mundo) e ainda não foram cumpridas.
func _missoes() -> Array:
	var r: Array = []
	var marcas = mundo.get("_marcadores")
	if marcas is Array:
		for m in marcas:
			if (m.tipo == "chefe" or m.tipo == "portao") and not m.feito:
				r.append(m.pos)
	return r


## Onde a reta da origem ao alvo cruza a borda do minimapa: o ponto da seta.
func _na_borda(origem: Vector2, alvo: Vector2) -> Vector2:
	var d := alvo - origem
	if d.length() < 0.001:
		return origem
	var t := INF
	if d.x > 0.0:
		t = minf(t, (MAPA_LARG - 1.0 - origem.x) / d.x)
	elif d.x < 0.0:
		t = minf(t, -origem.x / d.x)
	if d.y > 0.0:
		t = minf(t, (MAPA_ALT - 1.0 - origem.y) / d.y)
	elif d.y < 0.0:
		t = minf(t, -origem.y / d.y)
	return origem + d * t


## Monstros do mundo: `mundo.monstros` é a lista dos VIVOS (o combate tira quem morre). `monstros_vivos` é só a contagem, para o HUD.
func _monstros() -> Array:
	var lista = mundo.get("monstros")
	return lista if lista is Array else []


## Revela os pontos a até RAIO_REVELA do centro (em coordenadas do minimapa). Devolve se algum ponto mudou.
func _revelar(c: Vector2) -> bool:
	var r := RAIO_REVELA * MAPA_LARG / float(mundo.mapa.size.x)
	var n := int(ceil(r))
	var ci := Vector2i(c.floor())
	var mudou := false
	for y in range(ci.y - n, ci.y + n + 1):
		for x in range(ci.x - n, ci.x + n + 1):
			if x < 0 or y < 0 or x >= MAPA_LARG or y >= MAPA_ALT:
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r and _nevoa_img.get_pixel(x, y).a > 0.5:
				_nevoa_img.set_pixel(x, y, Color(0, 0, 0, 0))
				mudou = true
	return mudou


func _revelado_mapa(q: Vector2) -> bool:
	var ci := Vector2i(q.floor())
	if ci.x < 0 or ci.y < 0 or ci.x >= MAPA_LARG or ci.y >= MAPA_ALT:
		return false
	return _nevoa_img.get_pixel(ci.x, ci.y).a < 0.5


## Está revelado este ponto do mundo (na névoa)? Para o teste e para as luzes.
func revelado(p: Vector2) -> bool:
	return _revelado_mapa(mundo_para_mapa(p))


# ------------------------------------------------------------------ conversão de coordenadas


## Posição do mundo (px) para o minimapa (0..150, 0..84).
func mundo_para_mapa(p: Vector2) -> Vector2:
	var r: Rect2 = mundo.mapa
	return (p - r.position) * Vector2(MAPA_LARG, MAPA_ALT) / r.size


## O contrário: do minimapa para o mundo.
func mapa_para_mundo(q: Vector2) -> Vector2:
	var r: Rect2 = mundo.mapa
	return r.position + q * r.size / Vector2(MAPA_LARG, MAPA_ALT)


# ------------------------------------------------------------------ desenho (só quando repintado)


func _pintar() -> void:
	var tam := Vector2(MAPA_LARG, MAPA_ALT) * _k
	_desenho.draw_texture_rect(fundo, Rect2(Vector2.ZERO, tam), false)
	_desenho.draw_texture_rect(_nevoa, Rect2(Vector2.ZERO, tam), false)
	for q in luzes_vistas:
		_marca(q, C_LUZ, 2)
	for q in baus_mapa:
		_marca(q, C_BAU, 2)
	for q in setas_mapa:
		_marca(q, C_SANTUARIO, 3)
	for q in monstros_mapa:
		_marca(q, C_MONSTRO, 2)
	_seta(heroi_mapa, mira_dir, C_HEROI)


## Um ponto de n x n px do minimapa (no mapa grande, cada px vira um bloco de _k x _k).
func _marca(q: Vector2, cor: Color, n: int) -> void:
	_desenho.draw_rect(Rect2(q.floor() * _k, Vector2.ONE * n * _k), cor)


## Herói: seta de pixels, do centro do corpo para a mira.
func _seta(origem: Vector2, dir: Vector2, cor: Color) -> void:
	var pix := {}
	var perp := Vector2(-dir.y, dir.x)
	var s := -2.0
	while s <= 5.0:
		pix[Vector2i((origem + dir * s).floor())] = true
		s += 0.5
	var ponta := origem + dir * 5.0
	for lado in [-1.0, 1.0]:
		pix[Vector2i((ponta - dir * 2.0 + perp * lado * 2.0).floor())] = true
	for p in pix:
		_desenho.draw_rect(Rect2(Vector2(p) * _k, Vector2.ONE * _k), cor)
