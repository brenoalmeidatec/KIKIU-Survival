from pathlib import Path
p=Path('jogos/hordas/projeto/testes/v2_santuario.gd');s=p.read_text(encoding='utf-8').replace('["escape", "start", "cancelar", "botao"]','["escape", "start", "cancelar", "botao", "mouse"]').replace('\t\telse:\n\t\t\ta._voltar.grab_focus()', '''\t\telif acao == "mouse":
\t\t\tfor pressionado in [true, false]:
\t\t\t\tvar ev := InputEventMouseButton.new()
\t\t\t\tev.button_index = MOUSE_BUTTON_LEFT
\t\t\t\tev.position = a._voltar.get_global_rect().get_center()
\t\t\t\tev.global_position = ev.position
\t\t\t\tev.pressed = pressionado
\t\t\t\tInput.parse_input_event(ev)
\t\t\t\tInput.flush_buffered_events()
\t\telse:
\t\t\ta._voltar.grab_focus()''')
s=s.replace('\t_limpar()\n\n\nfunc _tecla', '''\tMeta.creditar(10000)
\tfor i in int(Meta.melhoria("vida").max):
\t\tMeta.comprar("vida")
\ta._atualizar()
\tvar vida: Dictionary = a._linhas["vida"]
\tok(vida.botao.disabled and not vida.selecionar.disabled, "máximo ainda permite selecionar detalhe")
\tvida.selecionar.grab_focus()
\tok(a._detalhe.text.contains("nível máximo"), "máximo explica estado por foco")
\tok(vida.progresso.nivel == vida.progresso.maximo, "nível máximo preenche todos marcadores")
\tok(a._detalhe.get_minimum_size().y <= a._detalhe.size.y, "detalhe máximo cabe")
\t_limpar()


func _tecla''');p.write_text(s,encoding='utf-8')
p=Path('jogos/hordas/projeto/testes/v2_pausa.gd');s=p.read_text(encoding='utf-8').replace('# abre só "Sair?", e o botão Ajustes abre o submenu.','# é devolvido à navegação local, e o botão Ajustes abre o submenu.');p.write_text(s,encoding='utf-8')
