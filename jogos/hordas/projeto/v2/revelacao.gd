extends RefCounted
## Revelação aos poucos do primeiro desenho da partida (pedido do Alisson, 15/11: a tela de carregamento congelava ~5,7 s no PC). O
## renderizador Compatibility compila cada programa de shader no primeiro desenho que o usa, na hora, e o primeiro quadro da partida usava
## ~20 programas novos de uma vez. Aqui a partida monta inteira no _ready, como sempre, mas o mundo (`sv`) e a interface (`ui`) aparecem
## por partes nos quadros seguintes, ainda por baixo da tela de carregamento: um lote por quadro, e cada lote traz poucos programas novos.
##
## Como esconde sem brigar com o jogo (que mexe em `visible` o tempo todo): pelo `visibility_layer` de cada CanvasItem e pelo
## `canvas_cull_mask` do SubViewport. O motor (renderer_canvas_cull.cpp, 4.4.1) pula o item cuja camada não está na máscara e os
## filhos dele; os filhos de um nó com y-sort são achatados e conferidos um a um. As luzes 2D não passam pela máscara: ficam todas
## ligadas desde o primeiro lote, e cada item já compila a versão com luz que vai usar na partida (nada de a sem luz agora e a com luz depois).
##
## Lotes: cada item vira uma chave (viewport, se a luz 2D pega a camada dele, o shader do material efetivo, o tipo de desenho: retângulo,
## nine-patch, polígono, instâncias ou _draw próprio, e o estado das texturas: filtro, repetição, formato e lado potência de 2).
## Chaves iguais usam o mesmo programa (e a mesma variante dele no driver), então caem no mesmo lote. Cada chave com luz é um lote sozinho
## (são as caras: a versão com luz é dezenas de vezes maior); sem luz, cada shader próprio e a primeira do material padrão de cada
## viewport também; as outras do padrão sem luz (o programa já existe) vão juntas, `juntos_baratos` por lote. Chave sem nenhum item
## visível agora não desenha neste quadro e não ganha lote (vai com o último). O lote k é o bit k da camada (1 a 31); o bit 0, a camada
## padrão, é de quem nasce depois da classificação e só entra no passo final, com a máscara de antes. Um nó fica no menor lote entre o
## dele e os dos descendentes, para nunca esconder um filho já revelado.
## No fim cada viewport volta à máscara que tinha (0xFFFFFFFF) e as camadas voltam ao que eram (1): nada disso fica na partida.
## Os `extras` (as duas TextureRects que mostram o mundo e a interface na janela) entram do mesmo jeito, com o bit 0 da janela sempre
## ligado: a tela de carregamento e o resto da janela seguem desenhando.

const MAX_LOTES := 31

var vps: Array = []  # os viewports mexidos: os SubViewports revelados e o da janela, se houver `extras`
var lotes := 0  # quantos lotes há (sem contar o passo final, que solta a máscara)
var atual := 0  # quantos lotes já estão na máscara
var feito := false
var resumo: Array = []  # [n do lote, texto das chaves] (medição e teste)
var _base: Array = []  # a máscara que cada um tem durante a revelação (0; 1 no da janela: o resto dela, a tela de carregamento, segue)
var _antes: Array = []  # a máscara de cada um antes (volta no fim)
var _nos: Array = []  # [no, camada original] de quem mudou de camada
var _scripts_draw := {}  # Script -> bool (tem _draw próprio)


## `viewports`: os SubViewports a revelar inteiros. `extras`: CanvasItems de outro viewport (as TextureRects que mostram o mundo e a
## interface na janela) que também entram por lotes; o resto desse viewport segue desenhando. `juntos_baratos`: chaves baratas por lote.
## Esconde tudo na hora: o quadro do _ready não desenha nada disso (é o quadro da montagem, que já é longo).
func _init(viewports: Array, extras: Array = [], juntos_baratos := 8) -> void:
	var raizes: Array = []  # [índice do viewport, nó a percorrer]
	for v in viewports:
		vps.append(v)
		_base.append(0)
		for c in (v as Node).get_children():
			raizes.append([vps.size() - 1, c])
	for e in extras:
		if not is_instance_valid(e) or not (e as Node).is_inside_tree():
			continue
		var v: Viewport = (e as Node).get_viewport()
		var i := vps.find(v)
		if i < 0:
			vps.append(v)
			_base.append(1)
			i = vps.size() - 1
		raizes.append([i, e])
	for v in vps:
		_antes.append((v as Viewport).canvas_cull_mask)
	var itens: Array = []  # [no, vp, camada do canvas, material, tipo, visível, estado das texturas]
	var luzes: Array = []  # [vp, min, max]
	for r in raizes:
		var no: Node = r[1]
		var camada := 0
		var pai := no.get_parent()
		while pai != null and not (pai is Viewport):  # um extra dentro de CanvasLayer: a camada dele vale para a luz
			if pai is CanvasLayer:
				camada = (pai as CanvasLayer).layer
				break
			pai = pai.get_parent()
		_andar(no, r[0], camada, "padrao", -1, -1, itens, luzes)
	# chave de cada item; ordem: a primeira vez que a chave aparece
	var chaves: Dictionary = {}  # chave -> {"luz": bool, "n": int}
	var ordem: Array = []
	var chave_de: Dictionary = {}  # no -> chave
	for it in itens:
		if it[4] == "":
			continue
		var luz := false
		for l in luzes:
			if l[0] == it[1] and it[2] >= l[1] and it[2] <= l[2]:
				luz = true
				break
		var k := "%d|%s|%s|%s" % [it[1], "luz" if luz else "sem", it[3], it[4]]
		k += it[6]  # o estado das texturas (filtro, repetição, formato e tamanho potência de 2 da cor e do normal) também separa: o
		# llvmpipe compila uma variante do mesmo programa para cada combinação (as quatro do cenário juntas passavam de 1 s); numa placa
		# de verdade o programa é o mesmo, e o lote a mais custa só um quadro barato
		if not chaves.has(k):
			chaves[k] = {"luz": luz, "n": 0, "vis": 0, "vp": it[1], "mat": it[3], "desenho": str(it[4]).begins_with("draw:")}
			ordem.append(k)
		chaves[k].n += 1
		if it[5]:
			chaves[k].vis += 1
		chave_de[it[0]] = k
	# lotes: cada chave com luz sozinha; sem luz, cada shader próprio sozinho e a primeira do material padrão de cada viewport sozinha;
	# as outras do padrão sem luz (o programa já existe: só muda o tipo de desenho ou a textura) e as de desenho próprio (_draw ou o
	# sinal draw: efeitos, avisos, rastros, que no começo da partida ainda não têm nada para desenhar) vão juntas, `juntos_baratos` por lote
	var lote_de: Dictionary = {}  # chave -> lote (1..)
	var sem: Array = []
	var com: Array = []
	var dormentes: Array = []  # nenhum item visível agora: não desenham neste quadro, então não ganham lote (vão com o último)
	for k in ordem:
		if chaves[k].vis == 0:
			dormentes.append(k)
		else:
			(com if chaves[k].luz else sem).append(k)
	var grupos: Array = []
	var baratos: Dictionary = {}  # vp -> [chaves]
	for k in com:
		if chaves[k].desenho:
			_juntar(baratos, chaves[k].vp, k)
		else:
			grupos.append([k])
	var padrao_visto: Dictionary = {}  # vp -> true
	for k in sem:
		var vp: int = chaves[k].vp
		if chaves[k].desenho:
			_juntar(baratos, vp, k)
			continue
		if chaves[k].mat == "padrao" and padrao_visto.has(vp):
			_juntar(baratos, vp, k)
			continue
		if chaves[k].mat == "padrao":
			padrao_visto[vp] = true
		grupos.append([k])
	var passo := maxi(1, juntos_baratos)
	for vp in baratos:
		for i in range(0, baratos[vp].size(), passo):
			grupos.append(baratos[vp].slice(i, i + passo))
	while grupos.size() > MAX_LOTES:  # mais lotes que bits (não acontece hoje): junta os vizinhos menores
		var menor := 0
		for i in range(grupos.size() - 1):
			if grupos[i].size() + grupos[i + 1].size() < grupos[menor].size() + grupos[menor + 1].size():
				menor = i
		grupos[menor].append_array(grupos[menor + 1])
		grupos.remove_at(menor + 1)
	for i in grupos.size():
		for k in grupos[i]:
			lote_de[k] = i + 1
		resumo.append([i + 1, " ".join(grupos[i].map(func(k): return "%s(%d/%d)" % [k, chaves[k].vis, chaves[k].n]))])
	lotes = grupos.size()
	for k in dormentes:
		lote_de[k] = maxi(lotes, 1)
	if not dormentes.is_empty():
		resumo.append([maxi(lotes, 1), "dormentes: %d chaves" % dormentes.size()])
	# camada de cada nó = o menor lote dele e dos descendentes
	for r in raizes:
		_marcar(r[1], chave_de, lote_de)
	for i in vps.size():
		(vps[i] as Viewport).canvas_cull_mask = _base[i]


## Um passo por quadro: põe o próximo lote na máscara. Depois do último lote, um passo final solta a máscara inteira (o bit 0 também,
## de quem nasceu no meio) e devolve as camadas; a chamada seguinte devolve false.
func quadro() -> bool:
	if feito:
		return false
	if atual < lotes:
		atual += 1
		var m := ((1 << (atual + 1)) - 1) & ~1
		for i in vps.size():
			if is_instance_valid(vps[i]):
				(vps[i] as Viewport).canvas_cull_mask = m | _base[i]
		return true
	encerrar()
	return true


## Solta tudo agora: máscara inteira e camadas de volta (também quando a partida sai no meio).
func encerrar() -> void:
	if feito:
		return
	feito = true
	atual = lotes
	for i in vps.size():
		if is_instance_valid(vps[i]):
			(vps[i] as Viewport).canvas_cull_mask = _antes[i]
	for par in _nos:
		if is_instance_valid(par[0]):
			(par[0] as CanvasItem).visibility_layer = par[1]
	_nos.clear()


static func _juntar(baratos: Dictionary, vp: int, k: String) -> void:
	if not baratos.has(vp):
		baratos[vp] = []
	baratos[vp].append(k)


## 0 a 1: quanto já foi revelado (a barra da tela de carregamento).
func progresso() -> float:
	if feito or lotes <= 0:
		return 1.0
	return float(atual) / float(lotes + 1)


func _andar(n: Node, vp: int, camada: int, mat_pai: String, filtro: int, rep: int, itens: Array, luzes: Array) -> void:
	if n is Viewport:
		return  # outro viewport tem a própria máscara
	if n is CanvasLayer:
		for c in n.get_children():
			_andar(c, vp, (n as CanvasLayer).layer, "padrao", -1, -1, itens, luzes)
		return
	var mat := mat_pai
	if n is CanvasItem:
		var ci := n as CanvasItem
		if not ci.use_parent_material or ci.top_level:
			mat = _material(ci.material)
		if ci.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			filtro = ci.texture_filter
		if ci.texture_repeat != CanvasItem.TEXTURE_REPEAT_PARENT_NODE:
			rep = ci.texture_repeat
		if n is Light2D:  # ligada ou não agora: a que acender depois pega as mesmas camadas
			luzes.append([vp, (n as Light2D).range_layer_min, (n as Light2D).range_layer_max])
		itens.append([n, vp, camada, mat, _tipo(ci), ci.is_visible_in_tree(), _texturas(ci, filtro, rep)])
	for c in n.get_children():
		_andar(c, vp, camada, mat, filtro, rep, itens, luzes)


## O estado das texturas de um sprite (" f0 r0 5 4"): filtro, repetição e formato da cor e do normal. "" se não tem textura.
static func _texturas(ci: CanvasItem, filtro: int, rep: int) -> String:
	var t: Texture2D = null
	if ci is Sprite2D:
		t = (ci as Sprite2D).texture
	elif ci is TextureRect:
		t = (ci as TextureRect).texture
	if t == null:
		return ""
	var nor: Texture2D = null
	if t is CanvasTexture:
		var ct := t as CanvasTexture
		if ct.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			filtro = ct.texture_filter
		if ct.texture_repeat != CanvasItem.TEXTURE_REPEAT_PARENT_NODE:
			rep = ct.texture_repeat
		nor = ct.normal_texture
		t = ct.diffuse_texture
	return " f%d r%d %s %s" % [filtro, rep, _formato(t), _formato(nor)]


static func _formato(t: Texture2D) -> String:
	if t == null:
		return "-"
	if t is AtlasTexture:
		return _formato((t as AtlasTexture).atlas)
	var w := t.get_width()
	var h := t.get_height()
	var pot := ("p" if w > 0 and (w & (w - 1)) == 0 else "n") + ("p" if h > 0 and (h & (h - 1)) == 0 else "n")  # potência de 2
	if t.has_method("get_format"):
		return str(t.call("get_format")) + pot
	return t.get_class() + pot


## Devolve o menor lote do nó e dos descendentes (MAX_LOTES + 1 se nada ali desenha) e grava a camada.
func _marcar(n: Node, chave_de: Dictionary, lote_de: Dictionary) -> int:
	if n is Viewport:
		return MAX_LOTES + 1
	var menor := MAX_LOTES + 1
	if chave_de.has(n):
		menor = int(lote_de[chave_de[n]])
	for c in n.get_children():
		menor = mini(menor, _marcar(c, chave_de, lote_de))
	if n is CanvasItem:
		var ci := n as CanvasItem
		var b := mini(menor, lotes)  # quem não desenha nada fica no último lote (os filhos que nascerem depois têm a camada 1)
		_nos.append([ci, ci.visibility_layer])
		ci.visibility_layer = 1 << b
	return menor


static func _material(m: Material) -> String:
	if m is ShaderMaterial:
		var s: Shader = (m as ShaderMaterial).shader
		return "s%d" % s.get_rid().get_id() if s != null else "padrao"
	if m is CanvasItemMaterial:
		var c := m as CanvasItemMaterial
		return "c%d.%d.%d" % [c.blend_mode, c.light_mode, int(c.particles_animation)]
	return "padrao"


## O tipo de desenho do item, que escolhe a especialização do programa (retângulo, nine-patch, polígono, instâncias). "" = não desenha.
func _tipo(ci: CanvasItem) -> String:
	var sc: Script = ci.get_script()
	if sc != null:
		if not _scripts_draw.has(sc):
			var tem := false
			for m in sc.get_script_method_list():
				if str(m.name) == "_draw":
					tem = true
					break
			_scripts_draw[sc] = tem
		if _scripts_draw[sc]:
			return "draw:" + sc.resource_path.get_file()
	var ligados := ci.draw.get_connections()
	if not ligados.is_empty():  # desenho por sinal (no.draw.connect): a chave é o script de quem desenha
		var dono: Object = (ligados[0].callable as Callable).get_object()
		var ds: Script = dono.get_script() if dono != null else null
		return "draw:" + (ds.resource_path.get_file() if ds != null else ci.get_class()) + ":" + str((ligados[0].callable as Callable).get_method())
	if ci is MultiMeshInstance2D or ci is CPUParticles2D or ci is GPUParticles2D:
		return "inst"
	if ci is Polygon2D or ci is Line2D or ci is MeshInstance2D:
		return "poli"
	if ci is NinePatchRect:
		return "nine"
	if ci is Sprite2D or ci is AnimatedSprite2D or ci is TextureRect or ci is ColorRect or ci is Label or ci is TextureProgressBar:
		return "ret"
	if ci is Node2D:
		return ""  # Node2D, luzes, câmera, colisão, CanvasModulate: não desenham nada por si
	if ci is Container and not (ci is PanelContainer) or ci.get_class() == "Control":
		return ""
	return "ctl:" + ci.get_class()
