extends Control
## Efeitos do pixelfx na interface: folhas `fx_ui_*` tocadas uma vez sobre um controle do HUD. Só enfeite, sem estado de jogo. Com "Reduzir piscadas"
## ou o perfil Baixo, não toca. Tudo em lista curta, sem nó por efeito. Guia: docs/visual_2_5d/estilo_pixelfx.md.

const Anim := preload("res://v2/anim_golpes.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const MAX := 4

var _lista: Array = []  # [{f, t, pos, cor}]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


## Toca a folha `id` com o centro em `pos` (coordenadas deste controle), tingida de `cor`.
func tocar(id: String, pos: Vector2, cor: Color) -> void:
	var f: Dictionary = Anim.de(id).get("impacto", {})
	if f.is_empty() or not Anim.suave or Piscadas.ligado():
		return
	if _lista.size() >= MAX:
		_lista.pop_front()
	_lista.append({"f": f, "t": 0.0, "pos": pos.round(), "cor": cor})
	set_process(true)


func _process(dt: float) -> void:
	for i in range(_lista.size() - 1, -1, -1):
		var e: Dictionary = _lista[i]
		e.t = float(e.t) + dt
		if float(e.t) >= Anim.duracao(e.f):
			_lista.remove_at(i)
	if _lista.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for e in _lista:
		Anim.desenhar(self, e.f, Anim.quadro_em(e.f, float(e.t)), e.pos, 0.0, Vector2.ONE, e.cor)
