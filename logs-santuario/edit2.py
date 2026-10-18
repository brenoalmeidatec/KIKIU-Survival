from pathlib import Path
p=Path('jogos/hordas/projeto/v2/altar.gd');s=p.read_text(encoding='utf-8').replace('res://assets/icone/entrada.png','res://assets/titulo/fundo.png')
s=s.replace('\t\tvar nome := _texto("", 19, true, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(x + 8, y + 4, 168, 22))','''\t\tvar selecionar := _botao_detalhe(Rect2(x + 4, y + 2, 176, 42))
\t\tselecionar.focus_entered.connect(_selecionar.bind(str(m.id)))
\t\tselecionar.mouse_entered.connect(_selecionar.bind(str(m.id)))
\t\tselecionar.pressed.connect(_selecionar.bind(str(m.id)))
\t\tvar nome := _texto("", 19, true, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(x + 8, y + 4, 168, 22))''')
s=s.replace('"progresso": progresso}', '"progresso": progresso, "selecionar": selecionar}')
s=s.replace('\t\tvar cadeado := Cadeado.new()\n\t\tcadeado.position = Vector2(642, y + 8)', '''\t\tvar selecionar := _botao_detalhe(Rect2(636, y + 2, 284, 94))
\t\tselecionar.focus_entered.connect(_selecionar_conquista.bind(str(c.id)))
\t\tselecionar.mouse_entered.connect(_selecionar_conquista.bind(str(c.id)))
\t\tselecionar.pressed.connect(_selecionar_conquista.bind(str(c.id)))
\t\tvar cadeado := Cadeado.new()
\t\tcadeado.position = Vector2(642, y + 8)''')
s=s.replace('"barra": barra}', '"barra": barra, "selecionar": selecionar}')
s=s.replace('\t\tbotao.tooltip_text = "%s\\n%s" % [m.nome, _detalhe_melhoria(m, e)]','\t\tbotao.tooltip_text = "%s\\n%s" % [m.nome, _detalhe_melhoria(m, e)]\n\t\t(linha.selecionar as Button).tooltip_text = botao.tooltip_text')
s=s.replace('_selecionar(_selecionada)\n\tfor c', 'if _linhas.has(_selecionada):\n\t\t_selecionar(_selecionada)\n\telse:\n\t\t_selecionar_conquista(_selecionada)\n\tfor c')
s=s.replace('Control.MOUSE_FILTER_PASS','Control.MOUSE_FILTER_IGNORE')
s += '''

func _botao_detalhe(r: Rect2) -> Button:
\tvar b := Button.new()
\tb.position = r.position
\tb.size = r.size
\tfor estado in ["normal", "hover", "pressed"]:
\t\tb.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
\tvar foco := StyleBoxFlat.new()
\tfoco.bg_color = Color(0, 0, 0, 0)
\tfoco.set_border_width_all(1)
\tfoco.border_color = COR_OURO
\tb.add_theme_stylebox_override("focus", foco)
\tadd_child(b)
\treturn b


func _selecionar_conquista(id: String) -> void:
\t_selecionada = id
\tfor c in Meta.conquistas():
\t\tif str(c.id) == id:
\t\t\t_detalhe.text = str(c.desc)
\t\t\tvar recompensa := _texto_recompensa(c.recompensa)
\t\t\tif recompensa != "":
\t\t\t\t_detalhe.text += "\\nLibera: " + recompensa
'''
p.write_text(s,encoding='utf-8')
