extends RefCounted
## Carrega as folhas de sprites do protótipo 2.5D (herói e monstros). Ficam FORA de res://, em jogos/hordas/prototipos/cara_nova/sprites
## (gerados por gerar_cara_nova.py), e são lidas por caminho de arquivo, como o protótipo faz: nada é duplicado em assets/.
## Cada tipo vira {tex (CanvasTexture albedo + normal), w, h (quadro), info (json), emissao (olhos, ou null), alb, blur (silhueta
## borrada da sombra média), pe (linha dos pés no quadro)}.

const Sombras := preload("res://v2/sombras.gd")
const PASTA := "res://prototipos/cara_nova/sprites"
const PAD_ATLAS := 2

## Aquecimento (tela de carregamento, v2/carregando.gd): as imagens das folhas e as sombras borradas que a partida vai pedir, prontas
## ANTES do _ready do mundo. As imagens são lidas no quadro principal (uma folha por quadro) e o borrão, que é a parte cara, roda no
## WorkerThreadPool. `tipo()` e `_imagem()` usam o que estiver pronto e fazem a conta na hora para o que faltar: o resultado é o mesmo.
## O mundo solta tudo no fim do _ready (`soltar_aquecidos`), então nada fica guardado durante a partida.
static var _quentes := {}  # caminho do PNG -> Image
static var _borradas := {}  # nome da folha -> Image borrada (escrita pelas threads, sob _trava)
static var _tarefas: Array = []  # ids do WorkerThreadPool ainda não recolhidos
static var _trava := Mutex.new()

var com_normal := true
var ms_blur := 0.0
var _imgs := {}
var _tipos := {}


func _caminho(nome: String) -> String:
	return PASTA.path_join(nome)


## PNG por load(): no exe exportado o PNG de origem não vai para o pck (vira .ctex importado); get_image() devolve a imagem para os cálculos.
static func png(caminho: String) -> Image:
	var tex := load(caminho) as Texture2D
	return tex.get_image() if tex != null else null


## Adianta a folha `nome` (sem extensão): lê as imagens dela e põe a sombra borrada para rodar numa thread. Chamar no quadro principal.
## Folha que não existe ou que já foi adiantada não faz nada.
static func aquecer(nome: String) -> void:
	var base := PASTA.path_join(nome)
	if not ResourceLoader.exists(base + "_albedo.png") or not FileAccess.file_exists(base + ".json"):
		return
	for sufixo in ["_albedo.png", "_normal.png", "_emissao.png"]:
		var c: String = base + sufixo
		if not _quentes.has(c) and ResourceLoader.exists(c):
			_quentes[c] = png(c)
	_trava.lock()
	var ja := _borradas.has(nome)
	if not ja:
		_borradas[nome] = null  # reservado: uma segunda chamada não cria outra tarefa
	_trava.unlock()
	var im: Image = _quentes[base + "_albedo.png"]
	if ja or im == null:
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if not info is Dictionary or not info.has("quadro"):
		return
	# alta prioridade: as de baixa só usam ~30% dos núcleos (1 thread no i5-3470) e as folhas sairiam em fila; o quadro principal
	# não espera por elas (só consulta is_task_completed), então não trava nada
	_tarefas.append(WorkerThreadPool.add_task(_borrar_na_thread.bind(nome, im, int(info.quadro[0]), int(info.quadro[1])), true))


static func _borrar_na_thread(nome: String, im: Image, w: int, h: int) -> void:
	var b := Sombras.borrar_imagem(im, w, h)
	_trava.lock()
	_borradas[nome] = b
	_trava.unlock()


## Quantas sombras ainda estão sendo borradas (0 = tudo pronto). Recolhe as tarefas que terminaram.
static func aquecendo() -> int:
	var restam: Array = []
	for id in _tarefas:
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
		else:
			restam.append(id)
	_tarefas = restam
	return restam.size()


## Espera o que ainda estiver rodando e esvazia o aquecimento.
static func soltar_aquecidos() -> void:
	for id in _tarefas:
		WorkerThreadPool.wait_for_task_completion(id)
	_tarefas = []
	_trava.lock()
	_borradas.clear()
	_trava.unlock()
	_quentes.clear()


static func _borrada_pronta(nome: String) -> Image:
	_trava.lock()
	var b: Variant = _borradas.get(nome)
	_trava.unlock()
	return b as Image


func _imagem(nome: String) -> Image:
	if not _imgs.has(nome):
		var quente: Variant = _quentes.get(_caminho(nome))
		var im: Image = quente if quente is Image else png(_caminho(nome))
		if im == null:
			push_error("sem imagem: " + _caminho(nome))
		_imgs[nome] = im
	return _imgs[nome]


## A silhueta borrada da folha `t` (um tipo ou o atlas da horda) como textura, criada na primeira vez que a sombra média pede. No Alto e no
## Baixo ela não é desenhada: subir as de todas as folhas para a placa no _ready era memória e tempo à toa.
static func blur_de(t: Dictionary) -> Texture2D:
	if t.get("blur") == null and t.get("blur_img") is Image:
		t["blur"] = ImageTexture.create_from_image(t.blur_img)
	return t.get("blur")


func tipo(nome: String) -> Dictionary:
	if _tipos.has(nome):
		return _tipos[nome]
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_caminho(nome + ".json")))
	var t := CanvasTexture.new()
	var alb := ImageTexture.create_from_image(_imagem(nome + "_albedo.png"))
	t.diffuse_texture = alb
	if com_normal:
		t.normal_texture = ImageTexture.create_from_image(_imagem(nome + "_normal.png"))
	var d := {"tex": t, "w": int(info.quadro[0]), "h": int(info.quadro[1]), "info": info, "emissao": null, "alb": alb}
	var t0 := Time.get_ticks_usec()
	var pronta := _borrada_pronta(nome)
	var borrada: Image = pronta if pronta != null else Sombras.borrar_imagem(_imagem(nome + "_albedo.png"), d.w, d.h)
	d["blur_img"] = borrada  # na memória: a textura só nasce quando a sombra média pede (blur_de); o atlas da horda não lê da placa
	d["img"] = _imagem(nome + "_albedo.png")
	ms_blur += (Time.get_ticks_usec() - t0) / 1000.0
	if ResourceLoader.exists(_caminho(nome + "_emissao.png")):
		d.emissao = ImageTexture.create_from_image(_imagem(nome + "_emissao.png"))
		d["emite"] = _linhas_com_emissao(_imagem(nome + "_emissao.png"), d.h)
	d["pe"] = int(info.get("pe_y", info.quadro[1] - 2))
	_tipos[nome] = d
	return d


## A folha grande do tipo `nome` desenhada em `n`x (elite e chefe: `inimigo_X_xN`, gerada por gerar_cara_nova.py com CARA_NOVA_MULT=N), ou {} se
## não existe. É a mesma arte renderizada com N vezes mais pixels: entra no lugar do sprite pequeno ampliado, sempre em escala 1.
func tipo_grande(nome: String, n: int) -> Dictionary:
	var g := "%s_x%d" % [nome, n]
	if not _tipos.has(g) and not ResourceLoader.exists(_caminho(g + "_albedo.png")):
		_tipos[g] = {}
	return tipo(g) if not _tipos.has(g) or not _tipos[g].is_empty() else {}


## Por linha da folha de emissão: tem algum pixel aceso? Quem desenha pula os olhos das linhas vazias (de costas, por exemplo).
static func _linhas_com_emissao(im: Image, alt_quadro: int) -> Array:
	var r: Array = []
	for l in maxi(im.get_height() / maxi(alt_quadro, 1), 1):
		r.append(im.get_region(Rect2i(0, l * alt_quadro, im.get_width(), alt_quadro)).get_used_rect().has_area())
	return r


## As folhas dos monstros empilhadas num atlas só (para o lote da horda, v2/horda.gd: uma textura, uma chamada de desenho). Devolve
## {tex (CanvasTexture albedo + normal), alb, blur (silhueta borrada da sombra média), emissao, tam, origem: {nome: Vector2}}; cada tipo
## também ganha `atlas_o` (o canto da folha dele no atlas). Entre as folhas ficam PAD_ATLAS px transparentes (o filtro linear da sombra não vaza).
func atlas(nomes: Array) -> Dictionary:
	var largura := 1
	var altura := 0
	for nome in nomes:
		var im := _imagem(nome + "_albedo.png")
		largura = maxi(largura, im.get_width())
		altura += im.get_height() + PAD_ATLAS
	var alb := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	var nor := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	nor.fill(Color(0.5, 0.5, 1.0, 1.0))  # normal "reto": o fundo e o espaço entre folhas
	var emi := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	var bor := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	var origem := {}
	var y := 0
	for nome in nomes:
		var t := tipo(nome)  # carrega a folha (e o blur)
		var a := _imagem(nome + "_albedo.png").duplicate() as Image
		a.convert(Image.FORMAT_RGBA8)
		var r := Rect2i(0, 0, a.get_width(), a.get_height())
		alb.blit_rect(a, r, Vector2i(0, y))
		var n := _imagem(nome + "_normal.png").duplicate() as Image
		n.convert(Image.FORMAT_RGBA8)
		nor.blit_rect(n, r, Vector2i(0, y))
		if ResourceLoader.exists(_caminho(nome + "_emissao.png")):
			var e := _imagem(nome + "_emissao.png").duplicate() as Image
			e.convert(Image.FORMAT_RGBA8)
			emi.blit_rect(e, r, Vector2i(0, y))
		var b := (t.blur_img as Image).duplicate() as Image if t.has("blur_img") else (t.blur as ImageTexture).get_image()
		b.convert(Image.FORMAT_RGBA8)
		bor.blit_rect(b, r, Vector2i(0, y))
		origem[nome] = Vector2(0, y)
		t["atlas_o"] = Vector2(0, y)
		y += a.get_height() + PAD_ATLAS
	var ct := CanvasTexture.new()
	var alb_t := ImageTexture.create_from_image(alb)
	ct.diffuse_texture = alb_t
	if com_normal:
		ct.normal_texture = ImageTexture.create_from_image(nor)
	return {"tex": ct, "alb": alb_t, "blur_img": bor, "emissao": ImageTexture.create_from_image(emi), "tam": Vector2(largura, altura), "origem": origem}  # a textura nasce em blur_de, só com a sombra média
