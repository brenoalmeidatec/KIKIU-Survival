from pathlib import Path
p=Path('jogos/hordas/projeto/v2/pausa.gd')
s=p.read_text(encoding='utf-8');s=s.replace('var ao_sair := Callable()', 'var sair_no_frontend := true  # só o título abre Sair com ESC; o santuário trata sua volta\nvar ao_sair := Callable()');s=s.replace('if mundo == null:\n\t\t\tabrir_sair()', 'if mundo == null:\n\t\t\tif not sair_no_frontend:\n\t\t\t\treturn false\n\t\t\tabrir_sair()');p.write_text(s,encoding='utf-8')
p=Path('jogos/hordas/projeto/v2/altar.gd');s=p.read_text(encoding='utf-8');s=s.replace('var trilha ', 'var _voltar: Button\nvar _detalhe: Label\nvar _selecionada := "vida"\nvar pausa\nvar trilha ')
s=s.replace('var pausa = preload("res://v2/pausa.tscn").instantiate().iniciar(null)  # ESC aqui abre só "Sair?"; o botão Ajustes abre o submenu (pausa.gd)', 'pausa = preload("res://v2/pausa.tscn").instantiate().iniciar(null)\n\tpausa.sair_no_frontend = false')
s=s.replace('_ajustes.pressed.connect(pausa.abrir_ajustes)', '_ajustes.pressed.connect(pausa.abrir_ajustes)\n\tpausa.fechou.connect(func(): _ajustes.grab_focus())')
start=s.index('\t# coluna da esquerda:');end=s.index('\n\t_status = ',start)
s=s[:start]+'''\t# Grade de cartões: o detalhe da seleção ocupa uma única faixa, sem repetir parágrafos.
\tadd_child(_texto("MELHORIAS", 37, true, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(36, 86, 572, 38)))
\tvar i := 0
\tfor m in Meta.melhorias_visiveis():
\t\tvar x := 36.0 + (i % 3) * 194.0
\t\tvar y := 128.0 + floori(i / 3.0) * 86.0
\t\tadd_child(_painel(Rect2(x, y, 184, 78)))
\t\tvar nome := _texto("", 19, true, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(x + 8, y + 4, 168, 22))
\t\tvar efeito := _texto("", 8, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_RIGHT, Rect2(x + 92, y + 29, 82, 12))
\t\tvar progresso := Marcadores.new()
\t\tprogresso.position = Vector2(x + 8, y + 30)
\t\tvar cadeado := Cadeado.new()
\t\tcadeado.position = Vector2(x + 158, y + 53)
\t\tvar botao := Button.new()
\t\tbotao.position = Vector2(x + 8, y + 48)
\t\tbotao.size = Vector2(142, 24)
\t\t_estilo_botao(botao, 8)
\t\tbotao.pressed.connect(_comprar.bind(str(m.id)))
\t\tbotao.focus_entered.connect(_selecionar.bind(str(m.id)))
\t\tbotao.mouse_entered.connect(_selecionar.bind(str(m.id)))
\t\tfor no in [nome, efeito, progresso, cadeado, botao]:
\t\t\tadd_child(no)
\t\t_linhas[str(m.id)] = {"nome": nome, "efeito": efeito, "botao": botao, "cadeado": cadeado, "progresso": progresso}
\t\ti += 1
\tadd_child(_painel(Rect2(36, 392, 572, 66)))
\t_detalhe = _texto("", 16, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(48, 398, 548, 54))
\t_detalhe.add_theme_font_override("font", Dados.fonte_texto)
\t_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tadd_child(_detalhe)
\tadd_child(_texto("CONQUISTAS", 37, true, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(632, 86, 292, 38)))
\ti = 0
\tfor c in Meta.conquistas():
\t\tvar y := 128.0 + i * 108.0
\t\tadd_child(_painel(Rect2(632, y, 292, 100)))
\t\tvar cadeado := Cadeado.new()
\t\tcadeado.position = Vector2(642, y + 8)
\t\tvar nome := _texto("", 19, true, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(664, y + 3, 250, 24))
\t\tvar desc := _texto("", 16, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(642, y + 43, 272, 34))
\t\tdesc.add_theme_font_override("font", Dados.fonte_texto)
\t\tdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\t\tvar rec := _texto("", 8, false, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(642, y + 79, 272, 14))
\t\trec.clip_text = true
\t\tvar barra := ProgressBar.new()
\t\tbarra.position = Vector2(642, y + 29)
\t\tbarra.size = Vector2(272, 8)
\t\tbarra.show_percentage = false
\t\tbarra.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t\tfor no in [cadeado, nome, desc, rec, barra]:
\t\t\tadd_child(no)
\t\t_conq[str(c.id)] = {"cadeado": cadeado, "nome": nome, "desc": desc, "rec": rec, "barra": barra}
\t\ti += 1
''' +s[end:]
s=s.replace('_ajustes.size = Vector2(168, 40)','_ajustes.size = Vector2(124, 40)').replace('_estilo_botao(_ajustes, 37)','_estilo_botao(_ajustes, 19)')
s=s.replace('\tadd_child(_ajustes)\n', '''\tadd_child(_ajustes)
\t_voltar = Button.new()
\t_voltar.text = "VOLTAR"
\t_voltar.position = Vector2(808, 478)
\t_voltar.size = Vector2(116, 40)
\t_estilo_botao(_voltar, 19)
\t_voltar.pressed.connect(_voltar_menu)
\tadd_child(_voltar)
''')
s=s.replace('Dados.fonte_titulo if tam >= 24 else Dados.fonte','Dados.fonte_titulo if tam >= 19 else Dados.fonte')
s=s.replace('nome.text = "%s   %d/%d" % [m.nome, n, int(m.max)]','nome.text = str(m.nome)\n\t\t(linha.progresso as Marcadores).nivel = n\n\t\t(linha.progresso as Marcadores).maximo = int(m.max)\n\t\t(linha.progresso as Marcadores).queue_redraw()')
s=s.replace('\tfor c in Meta.conquistas():\n\t\tvar v:', '\t\tefeito.text = "%d/%d" % [n, int(m.max)]\n\t\tbotao.tooltip_text = "%s\\n%s" % [m.nome, _detalhe_melhoria(m, e)]\n\t_selecionar(_selecionada)\n\tfor c in Meta.conquistas():\n\t\tvar v:')
s=s.replace('(v.desc as Label).text = str(c.desc)', '''var valor := 0.0
\t\tvar limite := float(c.get("limite", 1))
\t\tmatch str(c.condicao):
\t\t\t"tempo": valor = float(e.ultima.get("tempo", 0))
\t\t\t"combo": valor = float(e.ultima.get("maior_combo", 0))
\t\t(v.barra as ProgressBar).value = 100.0 if feita else minf(100.0, valor / limite * 100.0)
\t\tvar apoio := "Cumprida" if feita else "Última: %d/%d" % [int(valor), int(limite)]
\t\tif str(c.condicao) == "tempo" and not feita:
\t\t\tapoio = "Última: %d/300 s" % int(valor)
\t\tif str(c.condicao) == "venceu" and not feita:
\t\t\tapoio = "Vença o chefe da floresta"
\t\t(v.desc as Label).text = apoio
\t\t(v.nome as Label).tooltip_text = str(c.desc)
\t\t(v.nome as Label).mouse_filter = Control.MOUSE_FILTER_PASS''')
s=s.replace('var texto := ("Libera: " + libera) if libera != "" else ""','var texto := ("Libera: " + libera) if libera != "" else ""\n\t\t(v.rec as Label).tooltip_text = texto\n\t\t(v.rec as Label).mouse_filter = Control.MOUSE_FILTER_PASS')
s += '''

class Marcadores:
\textends Control
\tvar nivel := 0
\tvar maximo := 5

\tfunc _init() -> void:
\t\tsize = Vector2(80, 10)
\t\tmouse_filter = Control.MOUSE_FILTER_IGNORE

\tfunc _draw() -> void:
\t\tfor i in maximo:
\t\t\tdraw_rect(Rect2(i * 15, 0, 11, 8), COR_ALMA if i < nivel else Color(0.22, 0.24, 0.32))


func _detalhe_melhoria(m: Dictionary, e: Dictionary) -> String:
\tvar n := int(e.niveis[str(m.id)])
\tif not _liberada(m, e):
\t\treturn "Libera: " + _nome_conquista(str(m.requer))
\tif n >= int(m.max):
\t\treturn Meta.texto_efeito(m, n) + " — nível máximo"
\treturn (Meta.texto_efeito(m, n) if n > 0 else "Ainda não comprada") + "\\n" + Meta.texto_proximo(m, n)


func _selecionar(id: String) -> void:
\t_selecionada = id
\t_detalhe.text = _detalhe_melhoria(Meta.melhoria(id), Meta.estado())


func _unhandled_input(e: InputEvent) -> void:
\tif pausa != null and not pausa.aberto and pausa._pede_menu(e):
\t\tget_viewport().set_input_as_handled()
\t\t_voltar_menu()


func _voltar_menu() -> void:
\tget_tree().change_scene_to_file("res://v2/menu_principal.tscn")
'''
s=s.replace('## Visual: a arte de entrada escurecida, molduras de pedra do HUD (v2/hud/moldura_pedra.png). Títulos na Jersey 10 (Dados.fonte_titulo) e a lista densa na Press Start 2P (Dados.fonte), que tem a grade de 8 px que as 10 linhas pedem.', '## Visual: cartões em grade, níveis em marcadores e detalhe compartilhado por foco/mouse. Conquistas mostram a última partida,\n## sem fingir progresso acumulado. ESC e VOLTAR retornam ao título; Ajustes fecha devolvendo foco ao botão.')
p.write_text(s,encoding='utf-8')
