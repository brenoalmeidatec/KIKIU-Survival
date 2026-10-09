extends Node
## Autoload "G4": o que o Godot 4 tem e o Godot 3.5 não, para os scripts gerados pelo conversor.py.
## Tudo aqui é chamado como G4.nome(...). Manter barato: o Vita roda GDScript ~30-45x mais devagar que o PC.

const FONTE_PADRAO = "res://assets/fonte/PressStart2P.ttf"
# DisplayServer.* do Godot 4 (o conversor troca DisplayServer. por G4.)
const WINDOW_MODE_WINDOWED = 0
const WINDOW_MODE_MINIMIZED = 1
const WINDOW_MODE_MAXIMIZED = 2
const WINDOW_MODE_FULLSCREEN = 3
const WINDOW_MODE_EXCLUSIVE_FULLSCREEN = 4
const VSYNC_DISABLED = 0
const VSYNC_ENABLED = 1
const VSYNC_ADAPTIVE = 2
const VSYNC_MAILBOX = 3
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


## "==" do Godot 4 para Dictionary/Array (conteúdo, recursivo; número compara como float, 1 == 1.0).
func igual(a, b) -> bool:
	var ta = typeof(a)
	var tb = typeof(b)
	if (ta == TYPE_INT or ta == TYPE_REAL) and (tb == TYPE_INT or tb == TYPE_REAL):
		return float(a) == float(b)
	if ta != tb:
		return false
	if ta == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not igual(a[k], b[k]):
				return false
		return true
	if ta == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not igual(a[i], b[i]):
				return false
		return true
	return a == b


## move_child(filho, -1) do Godot 4 = por último (no 3 índice negativo é erro).
func mover_filho(pai: Node, filho: Node, pos: int) -> void:
	pai.move_child(filho, pai.get_child_count() + pos if pos < 0 else pos)


## get_window().get_final_transform() do Godot 4 (stretch viewport + keep): viewport -> janela.
func transformada_final(vp: Viewport) -> Transform2D:
	var k = min(OS.window_size.x / vp.size.x, OS.window_size.y / vp.size.y)
	var off = (OS.window_size - vp.size * k) / 2.0
	return Transform2D(Vector2(k, 0), Vector2(0, k), off)


# ---------------------------------------------------------------- timers em tempo real (ignore_time_scale do Godot 4)
class TimerReal:
	extends Reference
	signal timeout
	var fim = 0


var _timers_reais = []


func timer_real(seg) -> Reference:
	var t = TimerReal.new()
	t.fim = OS.get_ticks_msec() + int(float(seg) * 1000.0)
	_timers_reais.append(t)
	set_process(true)
	return t


func _timers_passo() -> void:
	if _timers_reais.empty():
		return
	var agora = OS.get_ticks_msec()
	var i = _timers_reais.size() - 1
	while i >= 0:
		var t = _timers_reais[i]
		if agora >= t.fim:
			_timers_reais.remove(i)
			t.emit_signal("timeout")
		i -= 1


## Input.get_vector/get_axis do Godot 4. No 3.5 eles leem a força "crua" da ação, que Input.action_press não
## preenche (o teste de movimento andava 0 px); get_action_strength funciona com eventos e com action_press.
func vetor(nx, px, ny, py, _zona = -1.0) -> Vector2:
	var v = Vector2(Input.get_action_strength(px) - Input.get_action_strength(nx),
		Input.get_action_strength(py) - Input.get_action_strength(ny))
	return v.limit_length(1.0)


func eixo(neg, pos) -> float:
	return Input.get_action_strength(pos) - Input.get_action_strength(neg)


func nada(_a = null, _b = null) -> void:
	pass


func merged(a: Dictionary, b: Dictionary, sobrescrever = false) -> Dictionary:
	var r = a.duplicate()
	for k in b:
		if sobrescrever or not r.has(k):
			r[k] = b[k]
	return r


# No Godot 3, get_pixel/set_pixel exigem Image.lock(). lock() de novo numa imagem já travada é inofensivo.
func px_set(img: Image, x, y, c) -> void:
	img.lock()
	img.set_pixel(int(x), int(y), c)


func px_setv(img: Image, p, c) -> void:
	img.lock()
	img.set_pixel(int(p.x), int(p.y), c)


func px_get(img: Image, x, y) -> Color:
	img.lock()
	return img.get_pixel(int(x), int(y))


func px_getv(img: Image, p) -> Color:
	img.lock()
	return img.get_pixel(int(p.x), int(p.y))


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
	img.unlock()
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


var _escrevendo = []


## Godot 4 descarrega o arquivo quando a referência some; no 3 só no close(). Quem lê depois chama _descarregar().
func _descarregar() -> void:
	for w in _escrevendo:
		var f = w.get_ref()
		if f and f.is_open():
			f.flush()
	_escrevendo = []


func abrir(caminho: String, modo: int):
	_descarregar()
	var f = File.new()
	if f.open(caminho, modo) != OK:
		return null
	if modo != File.READ:
		_escrevendo.append(weakref(f))
	return f


func existe(caminho: String) -> bool:
	_descarregar()
	return File.new().file_exists(caminho)


func ler_texto(caminho: String) -> String:
	_descarregar()
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


## OS.get_cmdline_user_args() do Godot 4: o que vem depois de "--" (ou tudo, se não houver "--").
func args_usuario() -> PoolStringArray:
	var a = Array(OS.get_cmdline_args())
	var i = a.find("--")
	if i < 0:
		return PoolStringArray(a)
	return PoolStringArray(a.slice(i + 1, a.size() - 1)) if i < a.size() - 1 else PoolStringArray()


## static var vista de fora: Alias._SV.nome = valor (sem regravar a constante no script).
func sv_def(dic: Dictionary, nome: String, valor) -> void:
	dic[nome] = valor


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


## draw_multiline_string do Godot 4: (fonte, pos, texto, alinh, largura, tamanho, max_linhas, cor, ...)
func texto_multilinha_em(ci: CanvasItem, fonte, pos: Vector2, texto, alinh = 0, larg = -1.0, tam = 16, max_l = -1,
		cor = Color.white, _b = 0, _j = 0, _d = 0, _o = 0) -> void:
	var f = fonte_tam(fonte, tam)
	var linhas = []
	for par in str(texto).split("\n"):
		var atual = ""
		for p in par.split(" "):
			var teste = p if atual == "" else atual + " " + p
			if larg > 0 and f.get_string_size(teste).x > larg and atual != "":
				linhas.append(atual)
				atual = p
			else:
				atual = teste
		linhas.append(atual)
	var alt = f.get_height()
	for i in linhas.size():
		if max_l > 0 and i >= max_l:
			break
		texto_em(ci, fonte, pos + Vector2(0, alt * i), linhas[i], alinh, larg, tam, cor)


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


func window_set_vsync_mode(modo, _id = 0) -> void:
	OS.vsync_enabled = modo != VSYNC_DISABLED


func window_get_vsync_mode(_id = 0) -> int:
	return VSYNC_ENABLED if OS.vsync_enabled else VSYNC_DISABLED


func screen_get_refresh_rate(_tela = -1) -> float:
	return 60.0


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


# ---------------------------------------------------------------- depuração no PC: --g4-foto=N (salva a tela) e --g4-sair=N
var _foto_t = -1.0
var _sair_t = -1.0


var _fps_label: Label = null
var _fps_t = 0.0
var _fps_n = 0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	var fps = OS.has_feature("Vita")
	for a in OS.get_cmdline_args():
		if a.begins_with("--g4-foto="):
			_foto_t = float(a.split("=")[1])
		elif a.begins_with("--g4-sair="):
			_sair_t = float(a.split("=")[1])
		elif a == "--g4-fps":
			fps = true
		elif a.begins_with("--g4-botoes="):   # depuração: "3:0,5.5:0" = aperta o botão 0 (Cross) aos 3 s e aos 5,5 s
			for par in a.split("=")[1].split(","):
				var tb = par.split(":")
				_botoes.append([float(tb[0]), int(tb[1])])
	if OS.has_feature("Vita"):
		call_deferred("_perfil_vita")
		_log_arq = "ux0:data/kikiu_vita_log.txt"
	elif Array(OS.get_cmdline_args()).has("--g4-log"):
		_log_arq = "user://kikiu_vita_log.txt"
	if _log_arq != "":
		_log_ini = OS.get_ticks_msec()
		var f = File.new()
		if f.open(_log_arq, File.WRITE) == OK:      # um arquivo novo por execução
			f.store_line("seg,fps,pior_ms,vivos,estado,mem_mb,mem_pico_mb")
			f.store_line("0,0,0,0,boot,%.1f,%.1f" % [OS.get_static_memory_usage() / 1048576.0,
				OS.get_static_memory_peak_usage() / 1048576.0])
			f.close()
	if fps:
		var camada = CanvasLayer.new()
		camada.layer = 128
		add_child(camada)
		_fps_label = Label.new()
		_fps_label.rect_position = Vector2(2, 2)
		_fps_label.add_color_override("font_color", Color(1, 1, 0.6))
		_fps_label.add_color_override("font_color_shadow", Color(0, 0, 0))
		_fps_label.add_constant_override("shadow_as_outline", 1)
		camada.add_child(_fps_label)
	set_process(_foto_t > 0.0 or _sair_t > 0.0 or _fps_label != null or _log_arq != "" or not _botoes.empty())


## Marcos de abertura: cada _ready/_init/_enter_tree do jogo grava uma linha ANTES de rodar (o conversor insere a
## chamada). Se o jogo cair, o último marco do arquivo aponta o script. Só nos primeiros 20 s.
var _marcas_ligado = -1
var _marcas_arq = ""
var _marcas_zero = 0


func marca(txt: String) -> void:
	if _marcas_ligado < 0:
		_marcas_ligado = 1 if (OS.has_feature("Vita") or Array(OS.get_cmdline_args()).has("--g4-log")) else 0
		_marcas_arq = "ux0:data/kikiu_boot.txt" if OS.has_feature("Vita") else "user://kikiu_boot.txt"
		_marcas_zero = OS.get_ticks_msec()
		var f0 = File.new()
		if _marcas_ligado == 1 and f0.open(_marcas_arq, File.WRITE) == OK:
			f0.store_line("ms,marco")
			f0.close()
	if _marcas_ligado != 1 or OS.get_ticks_msec() - _marcas_zero > 20000:
		return
	var f = File.new()
	if f.open(_marcas_arq, File.READ_WRITE) == OK:
		f.seek_end()
		f.store_line("%d,%s" % [OS.get_ticks_msec() - _marcas_zero, txt])
		f.close()


## Modo de segurança (bits): 1 sem VitaHW/touch traseiro, 2 sem efeitos de áudio, 4 sem núcleo C++ da horda,
## 8 sem os autoloads online (Salas, Chat, Voz, Rede). No Vita lê ux0:data/kikiu_modo.txt (um número); sem o arquivo
## vale 8 (online fora da v1). No PC vale 0 (ou --g4-modo=N).
var _modo = -1


func modo(bit: int) -> bool:
	if _modo < 0:
		_modo = 8 if OS.has_feature("Vita") else 0
		for a in OS.get_cmdline_args():
			if a.begins_with("--g4-modo="):
				_modo = int(a.split("=")[1])
		var f = File.new()
		if OS.has_feature("Vita") and f.open("ux0:data/kikiu_modo.txt", File.READ) == OK:
			_modo = int(f.get_as_text().strip_edges())
			f.close()
	return (_modo & bit) != 0


## No Vita: perfil de qualidade "baixa" (dados/qualidade.json) só nesta execução, hardware e som.
var _hw = null              # VitaHW (módulo C++ do template próprio)
var _tras_antes = false
var _dash_solta = false


func _perfil_vita() -> void:
	var cfg = get_node_or_null("/root/Config")
	if cfg and cfg.has_method("temporario"):
		cfg.temporario("qualidade", "baixa")
	marca("g4:_perfil_vita")
	if ClassDB.class_exists("VitaHW") and not modo(1):
		_hw = ClassDB.instance("VitaHW")
		if _hw != null:
			_hw.iniciar()
			set_process(true)
	marca("g4:vitahw_ok")
	# o Vita só tem saída estéreo: alargamento (atraso Haas) para os lados "saírem" da cabeça no fone + limiter
	if not modo(2):
		var largo = AudioEffectStereoEnhance.new()
		largo.pan_pullout = 1.2
		largo.time_pullout_ms = 6.0
		AudioServer.add_bus_effect(0, largo)
		AudioServer.add_bus_effect(0, AudioEffectLimiter.new())
	marca("g4:audio_ok")


## Registro de desempenho no Vita (ux0:data/kikiu_vita_log.txt, ou user:// com --g4-log no PC): a cada 5 s,
## fps médio, pior quadro, inimigos vivos e estado da tela. Para analisar depois pelo FTP do VitaShell.
var _log_t = 0.0
var _log_n = 0
var _log_pior = 0.0
var _log_ini = 0
var _log_arq = ""


func _log_passo(dt: float) -> void:
	if _log_arq == "":
		return
	_log_t += dt
	_log_n += 1
	_log_pior = max(_log_pior, dt)
	if _log_t < (2.0 if OS.get_ticks_msec() - _log_ini < 30000 else 5.0):
		return
	var vivos = -1
	var estado = ""
	var main = get_tree().current_scene
	if main and "_arena" in main and is_instance_valid(main._arena) and main._arena.get("inimigos"):
		vivos = main._arena.inimigos.vivos()
	if main and "_estado" in main:
		estado = str(main._estado)
	var f = File.new()
	var existe_arq = f.file_exists(_log_arq)
	if f.open(_log_arq, File.READ_WRITE if existe_arq else File.WRITE) == OK:
		f.seek_end()
		if not existe_arq:
			f.store_line("seg,fps,pior_ms,vivos,estado,mem_mb,mem_pico_mb")
		f.store_line("%d,%.1f,%.1f,%d,%s,%.1f,%.1f" % [(OS.get_ticks_msec() - _log_ini) / 1000, _log_n / _log_t,
			_log_pior * 1000.0, vivos, estado, OS.get_static_memory_usage() / 1048576.0,
			OS.get_static_memory_peak_usage() / 1048576.0])
		f.close()
	_log_t = 0.0
	_log_n = 0
	_log_pior = 0.0


## Touch traseiro = rolamento (ação "dash" do jogo): encostou atrás, rola; solta a ação no quadro seguinte.
func _hardware_vita() -> void:
	if _dash_solta:
		Input.action_release("dash")
		_dash_solta = false
	if _hw == null:
		return
	var tras = _hw.toques_tras().size() > 0
	if tras and not _tras_antes and InputMap.has_action("dash"):
		Input.action_press("dash")
		_dash_solta = true
	_tras_antes = tras


var _botoes = []
var _botoes_t = 0.0


var _soltar = []


func _botoes_passo(dt: float) -> void:
	_botoes_t += dt
	for idx in _soltar:      # solta no quadro seguinte (um dedo de verdade não aperta e solta no mesmo quadro)
		var e = InputEventJoypadButton.new()
		e.button_index = idx
		e.pressed = false
		Input.parse_input_event(e)
	_soltar = []
	while not _botoes.empty() and _botoes_t >= _botoes[0][0]:
		var idx = _botoes.pop_front()[1]
		var e = InputEventJoypadButton.new()
		e.button_index = idx
		e.pressed = true
		Input.parse_input_event(e)
		_soltar.append(idx)
		print("G4: botão ", idx, " aos ", _botoes_t, " s")


func _process(dt: float) -> void:
	_timers_passo()
	if not _botoes.empty() or not _soltar.empty():
		_botoes_passo(dt)
	_log_passo(dt)
	if _hw != null or _dash_solta:
		_hardware_vita()
	if _fps_label:
		_fps_t += dt
		_fps_n += 1
		if _fps_t >= 0.5:
			_fps_label.text = "%d fps  %.1f ms" % [round(_fps_n / _fps_t), _fps_t * 1000.0 / _fps_n]
			_fps_t = 0.0
			_fps_n = 0
	if _foto_t > 0.0:
		_foto_t -= dt
		if _foto_t <= 0.0:
			var img = get_viewport().get_texture().get_data()
			img.flip_y()
			img.save_png("user://g4_foto.png")
			print("G4: foto salva em ", ProjectSettings.globalize_path("user://g4_foto.png"))
	if _sair_t > 0.0:
		_sair_t -= dt
		if _sair_t <= 0.0:
			get_tree().quit()
