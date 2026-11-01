extends RefCounted
## Toca as folhas do pixelfx (MIT) no mundo: efeito único em `pos` ou loop preso a um nó (status sobre monstro). As folhas e os números de cada
## uma ficam em dados/v2_pixelfx.json (como registrar um efeito novo: docs/PIXELFX.md). TUDO em pool de tamanho fixo (MAX): vetores e nenhum nó
## por disparo; os únicos nós são os de desenho, criados na montagem (um por camada x normal/aditivo), e cada um desenha todos os seus efeitos
## numa chamada por quadro. Posição e canto saem arredondados para pixel inteiro (o pixel art não treme).
##   tocar(id, pos, opcoes)          -> efeito único: volta ao pool sozinho no último quadro. true se tocou.
##   prender(id, alvo, desl, opcoes) -> loop que segue `alvo` (Node2D) até soltar(alca). Devolve a alça (0 = recusou). Repetir o mesmo id no
##                                      mesmo alvo devolve a alça que já existe (dá para "reaplicar" o status todo quadro sem duplicar).
##   soltar(alca)                    -> devolve o efeito ao pool. Alça velha ou repetida não faz nada.
## Cada id tem um `limite` de cópias vivas: tocar passado dele troca a cópia mais velha; prender passado dele recusa. Pool cheio, recusa.
## Perfil Baixo (Anim.suave desligado): efeito `decorativo` não nasce e some dos que já estavam no ar. `clarao` escala o alfa pela opção
## "Tremor e clarões" (0% não acende).

const Anim := preload("res://v2/anim_golpes.gd")  # só a chave Anim.suave (perfil Baixo = desligada)
const PASTA := "res://assets/v2/pixelfx/"
const MAX := 48  # efeitos ao mesmo tempo, somando todos os ids (a alça guarda o slot em 8 bits)
const LIMITE_PADRAO := 8
const UNICO := 1
const PRESO := 2

var ativos := 0
var usados := {"tocar": 0, "prender": 0, "recusados": 0}  # contadores para os testes
var _defs: Array[Dictionary] = []
var _ids := {}  # id -> índice em _defs
var _uso := PackedInt32Array()  # por definição: cópias vivas
var _ultimo := PackedFloat32Array()  # por definição: relógio do último tocar (o `intervalo`)
var _nos: Array[Node2D] = []  # 0 glow normal, 1 glow aditivo, 2 mundo normal, 3 mundo aditivo (sem camada de mundo: tudo no glow)
var _modo := PackedByteArray()  # por slot: 0 livre, UNICO, PRESO
var _def := PackedInt32Array()
var _t := PackedFloat32Array()
var _pos := PackedVector2Array()  # único: onde; preso: deslocamento a partir do alvo
var _esc := PackedFloat32Array()
var _cor := PackedColorArray()
var _gen := PackedInt32Array()
var _lz := PackedByteArray()  # em qual nó de desenho o slot aparece
var _alvo: Array = []
var _agora := 0.0
var _sujo := false  # sobrou desenho velho para apagar


## `camada`: onde os efeitos de camada "glow" aparecem (acima do escurecimento do cenário). `camada_mundo`: opcional, para os de camada
## "mundo" (sob o escurecimento); sem ela eles vão para o glow.
func montar(camada: Node, camada_mundo: Node = null) -> void:
	for c in [camada, camada_mundo]:
		for aditivo in [false, true]:
			if c == null:
				_nos.append(null)
				continue
			var no := Node2D.new()
			no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if aditivo:
				var mat := CanvasItemMaterial.new()
				mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				no.material = mat
			no.draw.connect(_desenhar.bind(no, _nos.size()))
			c.add_child(no)
			_nos.append(no)
	_modo.resize(MAX)
	_def.resize(MAX)
	_t.resize(MAX)
	_pos.resize(MAX)
	_esc.resize(MAX)
	_cor.resize(MAX)
	_gen.resize(MAX)
	_lz.resize(MAX)
	_alvo.resize(MAX)
	var reg: Dictionary = Dados.json("v2_pixelfx")
	var efeitos: Dictionary = reg.get("efeitos", {})
	for id in efeitos:
		registrar(str(id), efeitos[id])


## Lê uma entrada do registro (o formato do dados/v2_pixelfx.json). Dá para registrar depois da montagem. false se a entrada estiver incompleta
## ou a folha não existir.
func registrar(id: String, e: Dictionary) -> bool:
	for k in ["arquivo", "quadro", "colunas", "quadros", "fps", "pivo"]:
		if not e.has(k):
			push_error("pixelfx '%s': falta o campo '%s'" % [id, k])
			return false
	var tex = load(PASTA + str(e.arquivo)) if ResourceLoader.exists(PASTA + str(e.arquivo)) else null
	if not (tex is Texture2D):
		push_error("pixelfx '%s': folha não encontrada (%s)" % [id, PASTA + str(e.arquivo)])
		return false
	var quadro := Vector2(float(e.quadro[0]), float(e.quadro[1]))
	var passo := maxi(int(e.get("passo", 1)), 1)
	var quadros := maxi(int(e.quadros), 1)
	var camada_mundo: bool = str(e.get("camada", "glow")) == "mundo" and _nos.size() > 2 and _nos[2] != null
	var d := {
		"tex": tex,
		"quadro": quadro,
		"colunas": maxi(int(e.colunas), 1),
		"quadros": quadros,
		"fps": maxf(float(e.fps), 1.0),
		"loop": bool(e.get("loop", false)),
		"pivo": Vector2(float(e.pivo[0]), float(e.pivo[1])),
		"escala": maxf(float(e.get("escala", 1.0)), 0.1),
		"cor": _ler_cor(e.get("cor", null)),
		"passo": passo,
		"ticks": ceili(float(quadros) / float(passo)),  # quadros mostrados numa volta
		"limite": maxi(int(e.get("limite", LIMITE_PADRAO)), 1),
		"intervalo": maxf(float(e.get("intervalo", 0.0)), 0.0),
		"deco": bool(e.get("decorativo", true)),
		"clarao": bool(e.get("clarao", false)),
		"lz": (2 if camada_mundo else 0) + (1 if bool(e.get("aditivo", false)) else 0),
	}
	if _ids.has(id):
		_defs[_ids[id]] = d  # reabrir um id troca a definição (os que estão no ar seguem com o índice)
	else:
		_ids[id] = _defs.size()
		_defs.append(d)
		_uso.append(0)
		_ultimo.append(-99.0)
	return true


func tem(id: String) -> bool:
	return _ids.has(id)


## Efeito único em `pos` (coordenada do mundo; o `pivo` da folha cai nela). opcoes: "escala" (troca a do registro) e "cor" (idem).
func tocar(id: String, pos: Vector2, opcoes := {}) -> bool:
	var s := _alocar(id, UNICO, opcoes)
	if s < 0:
		return false
	_pos[s] = pos
	usados.tocar += 1
	return true


## Loop preso a `alvo`, `desl` px acima/ao lado da posição global dele. Devolve a alça para soltar (0 = recusou: perfil Baixo, limite do id,
## pool cheio, id desconhecido ou alvo inválido). Pede o mesmo id no mesmo alvo e devolve a alça que já existe.
func prender(id: String, alvo: Node2D, desl := Vector2.ZERO, opcoes := {}) -> int:
	if alvo == null or not is_instance_valid(alvo) or not _ids.has(id):
		usados.recusados += 1
		return 0
	var idx: int = _ids[id]
	for s in MAX:
		if _modo[s] == PRESO and _def[s] == idx and _alvo[s] == alvo:
			_pos[s] = desl
			return _alca(s)
	var novo := _alocar(id, PRESO, opcoes)
	if novo < 0:
		return 0
	_pos[novo] = desl
	_alvo[novo] = alvo
	usados.prender += 1
	return _alca(novo)


func soltar(alca: int) -> void:
	var s := alca & 255
	if alca > 0 and s < MAX and _modo[s] == PRESO and _gen[s] == (alca >> 8):
		_liberar(s)


## A alça ainda vale (o efeito não foi solto nem trocado)?
func vivo(alca: int) -> bool:
	var s := alca & 255
	return alca > 0 and s < MAX and _modo[s] == PRESO and _gen[s] == (alca >> 8)


## Tudo de volta ao pool (a partida recomeça).
func limpar() -> void:
	for s in MAX:
		if _modo[s] != 0:
			_liberar(s)
	_ultimo.fill(-99.0)
	_agora = 0.0
	_atualizar_desenho()


func _alca(s: int) -> int:
	return (_gen[s] << 8) | s


func _alocar(id: String, modo: int, opcoes: Dictionary) -> int:
	if _modo.size() != MAX or not _ids.has(id):
		usados.recusados += 1
		return -1
	var idx: int = _ids[id]
	var d: Dictionary = _defs[idx]
	if d.deco and not Anim.suave:
		return -1  # perfil Baixo: enfeite não nasce (não conta como recusa por falta de pool)
	if modo == UNICO and d.intervalo > 0.0 and _agora - _ultimo[idx] < d.intervalo:
		return -1
	var cor: Color = opcoes.get("cor", d.cor)
	if d.clarao:
		var f = Config.g("tremor_clarao")
		if f != null:
			cor.a *= clampf(float(f) / 100.0, 0.0, 1.0)
		if cor.a <= 0.0:
			return -1
	if _uso[idx] >= d.limite:
		var velho := _mais_velho(idx) if modo == UNICO else -1
		if velho < 0:
			usados.recusados += 1
			return -1
		_liberar(velho)
	var s := _modo.find(0)
	if s < 0:
		usados.recusados += 1
		return -1
	_modo[s] = modo
	_def[s] = idx
	_t[s] = 0.0
	_esc[s] = float(opcoes.get("escala", d.escala))
	_cor[s] = cor
	_lz[s] = d.lz
	_gen[s] = ((_gen[s] + 1) & 0xFFFFF) | 1  # nunca 0, para a alça 0 significar "nada"
	_uso[idx] += 1
	_ultimo[idx] = _agora
	ativos += 1
	_sujo = true
	return s


## O único mais adiantado do id (o que está mais perto de acabar): é o que se troca ao estourar o limite.
func _mais_velho(idx: int) -> int:
	var melhor := -1
	var tmax := -1.0
	for s in MAX:
		if _modo[s] == UNICO and _def[s] == idx and _t[s] > tmax:
			tmax = _t[s]
			melhor = s
	return melhor


func _liberar(s: int) -> void:
	_modo[s] = 0
	_uso[_def[s]] -= 1
	_alvo[s] = null
	ativos -= 1
	_sujo = true


func _ler_cor(v) -> Color:
	if v is Array and v.size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]) if v.size() > 3 else 1.0)
	if v is String:
		return Color.from_string(v, Color.WHITE)
	return Color.WHITE


# ------------------------------------------------------------------ quadro (relógio de parede, como o Efeitos)


func atualizar(dt: float) -> void:
	_agora += dt
	if ativos == 0:
		if _sujo:
			_atualizar_desenho()
		return
	var suave: bool = Anim.suave
	for s in MAX:
		if _modo[s] == 0:
			continue
		var d: Dictionary = _defs[_def[s]]
		if d.deco and not suave:
			_liberar(s)
			continue
		if _modo[s] == PRESO and not is_instance_valid(_alvo[s]):
			_liberar(s)  # o nó do alvo foi liberado sem soltar
			continue
		_t[s] += dt
		if _modo[s] == UNICO and not d.loop and int(_t[s] * d.fps) >= d.ticks:
			_liberar(s)
	_atualizar_desenho()


func _atualizar_desenho() -> void:
	_sujo = false
	for no in _nos:
		if no != null:
			no.queue_redraw()


func _desenhar(no: Node2D, lz: int) -> void:
	if ativos == 0:
		return
	for s in MAX:
		if _modo[s] == 0 or _lz[s] != lz:
			continue
		var d: Dictionary = _defs[_def[s]]
		var tick := int(_t[s] * d.fps)
		tick = tick % d.ticks if d.loop else mini(tick, d.ticks - 1)
		var q := mini(tick * d.passo, d.quadros - 1)
		var origem: Vector2 = _pos[s]
		if _modo[s] == PRESO:
			var a: Node2D = _alvo[s]
			if not a.is_inside_tree() or not a.visible:
				continue  # monstro escondido (de volta ao pool dele): o efeito espera sem desenhar
			origem += a.global_position
		var esc: float = _esc[s]
		var tam: Vector2 = d.quadro
		var pivo: Vector2 = d.pivo
		var canto: Vector2 = origem.round() - (pivo * esc).round()
		var col := q % int(d.colunas)
		var lin := floori(float(q) / float(d.colunas))
		no.draw_texture_rect_region(d.tex, Rect2(canto, tam * esc), Rect2(Vector2(col, lin) * tam, tam), _cor[s])
