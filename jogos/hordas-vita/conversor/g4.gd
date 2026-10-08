extends Node
## Autoload "G4": o que o Godot 4 tem e o Godot 3.5 não, para os scripts gerados pelo conversor.py.
## Tudo aqui é chamado como G4.nome(...). Manter barato: o Vita roda GDScript ~30-45x mais devagar que o PC.

const FONTE_PADRAO = "res://assets/fonte/PressStart2P.ttf"
# ENetConnection.HOST_* do Godot 4 (estatística do online, fora da v1 no Vita)
const HOST_TOTAL_SENT_DATA = 0
const HOST_TOTAL_SENT_PACKETS = 1
const HOST_TOTAL_RECEIVED_DATA = 2
const HOST_TOTAL_RECEIVED_PACKETS = 3

var _fontes = {}            # [caminho/id dos dados, tamanho] -> DynamicFont
var _dados_padrao = null
var _pendentes = []


# ---------------------------------------------------------------- await robusto
## `await f()` vira `yield(G4.co(f()), "completed")`. No Godot 3, se f() não chegou a pausar, ela devolve o valor
## direto e o yield travaria para sempre; aqui o valor vira um objeto que emite "completed" no próximo quadro.
class Pronto:
	extends Reference
	signal completed(valor)
	var valor = null


func co(v):
	if v is GDScriptFunctionState:
		return v
	var p = Pronto.new()
	p.valor = v
	_pendentes.append(p)
	call_deferred("_emitir", p)
	return p


func _emitir(p) -> void:
	_pendentes.erase(p)
	p.emit_signal("completed", p.valor)


# ---------------------------------------------------------------- números
func roundi(x) -> int:
	return int(round(x))


func floori(x) -> int:
	return int(floor(x))


func ceili(x) -> int:
	return int(ceil(x))


func randi_range(a, b) -> int:
	a = int(a)
	b = int(b)
	if b < a:
		var t = a
		a = b
		b = t
	return a + randi() % (b - a + 1)


func pingpong(v, comp):
	if comp == 0:
		return 0.0
	var t = fposmod(v, comp * 2.0)
	return comp * 2.0 - t if t > comp else t


func from_angle(a) -> Vector2:
	return Vector2(cos(a), sin(a))


func angle_difference(de, para) -> float:
	var d = fmod(para - de, TAU)
	return fmod(2.0 * d, TAU) - d


func is_same(a, b) -> bool:
	if typeof(a) != typeof(b):
		return false
	if typeof(a) == TYPE_OBJECT:
		return a == b
	return a == b


func centro(r: Rect2) -> Vector2:
	return r.position + r.size * 0.5


func tem_area(r: Rect2) -> bool:
	return not r.has_no_area()


func v4i(a, b, c, d) -> Array:
	return [int(a), int(b), int(c), int(d)]


func is_finite(x) -> bool:
	return x == x and abs(x) != INF


func imagem(w, h, mip, fmt) -> Image:
	var i = Image.new()
	i.create(int(w), int(h), mip, fmt)
	return i


func imagem_de_dados(w, h, mip, fmt, dados) -> Image:
	var i = Image.new()
	i.create_from_data(int(w), int(h), mip, fmt, dados)
	return i


func textura(img, flags = 0) -> ImageTexture:
	var t = ImageTexture.new()
	t.create_from_image(img, flags)
	return t


## Godot 4: a.angle_to_point(b) = (b - a).angle(). No Godot 3 o sinal era o contrário.
func angle_to_point(a: Vector2, b: Vector2) -> float:
	return (b - a).angle()


# ---------------------------------------------------------------- texto, arrays
func contains(x, v) -> bool:
	if typeof(x) == TYPE_STRING:
		return x.find(v) != -1
	return x.has(v)


func repetir(s: String, n: int) -> String:
	var r = ""
	for _i in max(n, 0):
		r += s
	return r


func pick_random(a):
	if a.empty():
		return null
	return a[randi() % a.size()]


## Godot 4: slice(inicio, fim exclusivo). Godot 3: slice(inicio, fim INCLUSIVO).
func slice(a, ini = 0, fim = 2147483647, passo = 1, fundo = false):
	var n = a.size()
	if ini < 0:
		ini = max(n + ini, 0)
	if fim < 0:
		fim = n + fim
	fim = min(fim, n)
	if fim <= ini or n == 0:
		return [] if typeof(a) == TYPE_ARRAY else a.slice(1, 0)
	return a.slice(ini, fim - 1, passo, fundo)


func contar(a, v) -> int:
	return a.count(v)


# Array.filter/map/any/all/reduce com uma função (FuncRef). Lambdas do Godot 4 viram métodos + funcref.
func filtrar(a, f) -> Array:
	var r = []
	for e in a:
		if f.call_func(e):
			r.append(e)
	return r


func mapear(a, f) -> Array:
	var r = []
	for e in a:
		r.append(f.call_func(e))
	return r


func algum(a, f) -> bool:
	for e in a:
		if f.call_func(e):
			return true
	return false


func todos(a, f) -> bool:
	for e in a:
		if not f.call_func(e):
			return false
	return true


func reduzir(a, f, ini = null):
	var acc = ini
	var i0 = 0
	if acc == null and not a.empty():
		acc = a[0]
		i0 = 1
	for i in range(i0, a.size()):
		acc = f.call_func(acc, a[i])
	return acc


# ---------------------------------------------------------------- JSON e arquivos
func json_texto(v, recuo = "", _ordenar = false, _precisao = false) -> String:
	if recuo == "":
		return to_json(v)
	return JSON.print(v, recuo)


func abrir(caminho: String, modo: int):
	var f = File.new()
	if f.open(caminho, modo) != OK:
		return null
	return f


func existe(caminho: String) -> bool:
	return File.new().file_exists(caminho)


func ler_texto(caminho: String) -> String:
	var f = File.new()
	if f.open(caminho, File.READ) != OK:
		return ""
	var t = f.get_as_text()
	f.close()
	return t


func arquivos_em(caminho: String) -> PoolStringArray:
	return _listar(caminho, false)


func pastas_em(caminho: String) -> PoolStringArray:
	return _listar(caminho, true)


func _listar(caminho: String, pastas: bool) -> PoolStringArray:
	var r = PoolStringArray()
	var d = Directory.new()
	if d.open(caminho) != OK:
		return r
	d.list_dir_begin(true, true)
	var n = d.get_next()
	while n != "":
		if d.current_is_dir() == pastas:
			# no pck exportado os recursos aparecem como .import / .remap: devolve o nome original
			if not pastas and (n.ends_with(".import") or n.ends_with(".remap")):
				n = n.get_basename()
				if r.has(n):
					n = d.get_next()
					continue
			r.append(n)
		n = d.get_next()
	d.list_dir_end()
	return r


func abrir_pasta(caminho: String):
	var d = Directory.new()
	if d.open(caminho) != OK:
		return null
	return d


func apagar(caminho: String) -> int:
	return Directory.new().remove(caminho)


func renomear(de: String, para: String) -> int:
	return Directory.new().rename(de, para)


func copiar(de: String, para: String) -> int:
	return Directory.new().copy(de, para)


## ThemeDB.get_default_theme() do Godot 4: no Vita a fonte do tema vem do project.godot (g4_fonte.tres).
class TemaG4:
	extends Reference
	var default_font = null
	var default_font_size = 8


var _tema = TemaG4.new()


func tema():
	return _tema


## TextServerManager.get_primary_interface() do Godot 4 (ligaduras de fonte): sem efeito no Godot 3.
class ServidorTextoG4:
	extends Reference

	func name_to_tag(_n) -> int:
		return 0


var _servidor_texto = ServidorTextoG4.new()


func servidor_texto():
	return _servidor_texto


## ProjectSettings.get_setting(nome, padrão) do Godot 4 (no 3 não tem padrão).
func config(nome: String, padrao = null):
	if ProjectSettings.has_setting(nome):
		return ProjectSettings.get_setting(nome)
	return padrao


func pasta_existe(caminho: String) -> bool:
	return Directory.new().dir_exists(caminho)


func criar_pasta(caminho: String) -> int:
	return Directory.new().make_dir_recursive(caminho)


# ---------------------------------------------------------------- fontes e texto (draw_string do Godot 4)
func _dados_fonte(fonte):
	if fonte is DynamicFontData:
		return fonte
	if fonte is DynamicFont and fonte.font_data:
		return fonte.font_data
	if _dados_padrao == null:
		_dados_padrao = load(FONTE_PADRAO)
	return _dados_padrao


func fonte_tam(fonte = null, tam = 16) -> DynamicFont:
	var dados = _dados_fonte(fonte)
	var chave = [dados.get_instance_id(), int(tam)]
	if _fontes.has(chave):
		return _fontes[chave]
	var f = DynamicFont.new()
	f.font_data = dados
	f.size = int(tam)
	_fontes[chave] = f
	return f


func fonte():
	return fonte_tam(null, 16)


## draw_string do Godot 4: (fonte, pos, texto, alinhamento=0, largura=-1, tamanho=16, cor=branco, ...)
func texto_em(ci: CanvasItem, fonte, pos: Vector2, texto, alinh = 0, larg = -1.0, tam = 16, cor = Color.white,
		_j = 0, _d = 0, _o = 0) -> void:
	var f = fonte_tam(fonte, tam)
	var t = str(texto)
	var p = pos
	if larg > 0 and alinh != 0:
		var w = f.get_string_size(t).x
		if alinh == 1:
			p.x += (larg - w) * 0.5
		elif alinh == 2:
			p.x += larg - w
	ci.draw_string(f, p, t, cor, int(larg) if larg > 0 and alinh == 0 else -1)


## draw_string_outline do Godot 4: (fonte, pos, texto, alinh, largura, tamanho, tamanho_contorno, cor)
func texto_contorno_em(ci: CanvasItem, fonte, pos: Vector2, texto, alinh = 0, larg = -1.0, tam = 16, contorno = 1,
		cor = Color.white, _j = 0, _d = 0, _o = 0) -> void:
	var d = max(1, int(contorno / 2))
	for o in [Vector2(-d, 0), Vector2(d, 0), Vector2(0, -d), Vector2(0, d)]:
		texto_em(ci, fonte, pos + o, texto, alinh, larg, tam, cor)


## font.get_string_size(texto, alinh, largura, tamanho) do Godot 4.
func medir(fonte, texto = "", _alinh = 0, _larg = -1.0, tam = 16, _j = 0, _d = 0, _o = 0) -> Vector2:
	return fonte_tam(fonte, tam).get_string_size(str(texto))


## add_theme_font_size_override("font_size", n) do Godot 4.
func tamanho_fonte(c: Control, _nome, tam) -> void:
	c.add_font_override("font", fonte_tam(null, tam))


# ---------------------------------------------------------------- DisplayServer / Time do Godot 4 (o que o jogo usa)
func window_set_mode(modo, _id = 0) -> void:
	OS.window_fullscreen = modo >= 3
	OS.window_maximized = modo == 2


func window_get_mode(_id = 0) -> int:
	return 3 if OS.window_fullscreen else (2 if OS.window_maximized else 0)


func window_get_size(_id = 0) -> Vector2:
	return OS.window_size


func window_set_size(s, _id = 0) -> void:
	OS.window_size = s


func screen_get_size(_tela = -1) -> Vector2:
	return OS.get_screen_size()


func window_set_title(t, _id = 0) -> void:
	OS.set_window_title(t)


func get_datetime_dict_from_system(_utc = false) -> Dictionary:
	return OS.get_datetime(_utc)


func get_date_dict_from_system(_utc = false) -> Dictionary:
	return OS.get_date(_utc)


func get_datetime_string_from_system(_utc = false, espaco = false) -> String:
	var d = OS.get_datetime(_utc)
	return "%04d-%02d-%02d%s%02d:%02d:%02d" % [d.year, d.month, d.day, " " if espaco else "T", d.hour, d.minute, d.second]


func get_unix_time_from_system() -> float:
	return float(OS.get_unix_time())


func get_ticks_msec() -> int:
	return OS.get_ticks_msec()


func get_ticks_usec() -> int:
	return OS.get_ticks_usec()


# ---------------------------------------------------------------- lambdas içadas (callables com valores capturados)
## G4.ligar(funcref(obj, "m"), [capturadas]) = Callable.bind do Godot 4: chama m(args..., capturadas...).
class Ligado:
	extends Reference
	const _N = "__g4_sem_arg__"
	var f
	var extra = []

	func call_func(a = _N, b = _N, c = _N, d = _N, e = _N, g = _N):
		var args = []
		for x in [a, b, c, d, e, g]:
			if typeof(x) == TYPE_STRING and x == _N:
				break
			args.append(x)
		return f.call_funcv(args + extra)

	func call_funcv(args):
		return f.call_funcv(args + extra)

	func is_valid():
		return f.is_valid()

	func _cmp(x, y):
		return f.call_funcv([x, y] + extra)


func ligar(f, extra) -> Reference:
	var l = Ligado.new()
	l.f = f
	l.extra = extra
	return l


## arr.sort_custom(callable com capturas) do Godot 4.
func ordenar(a, l) -> void:
	a.sort_custom(l, "_cmp")


## Color.from_string(texto, padrão) do Godot 4.
func cor_de_texto(s, padrao = Color.black) -> Color:
	s = str(s)
	if s.is_valid_html_color():
		return Color(s)
	var nomes = {"white": Color.white, "black": Color.black, "red": Color.red, "green": Color.green,
		"blue": Color.blue, "yellow": Color.yellow, "gray": Color.gray, "orange": Color.orange}
	return nomes.get(s.to_lower(), padrao)


## Color(cor_ou_hex, alfa) do Godot 4.
func cor(c, alfa) -> Color:
	var r = Color(c) if typeof(c) == TYPE_STRING else c
	return Color(r.r, r.g, r.b, alfa)
