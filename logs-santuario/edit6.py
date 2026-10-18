from pathlib import Path
p=Path('jogos/hordas/projeto/v2/altar.gd');s=p.read_text(encoding='utf-8').replace('_estilo_botao(_mapa, 37)', '_estilo_botao(_mapa, 19)').replace('(v.rec as Label).text = ("Cumprida. " + texto).strip_edges() if feita else texto','(v.rec as Label).text = texto');p.write_text(s,encoding='utf-8')
p=Path('jogos/hordas/projeto/testes/v2_santuario.gd');s=p.read_text(encoding='utf-8').replace('ev.position = a._voltar.get_global_rect().get_center()','ev.position = get_viewport().get_final_transform() * a._voltar.get_global_rect().get_center()');s=s.replace('func _ver_visual(a) -> void:\n', '''func _ver_visual(a) -> void:
\tfor nome in ["FLORESTA", "LABORATÓRIO", "RUÍNAS DA FLORESTA", "CIDADE"]:
\t\tvar largura := a._mapa.get_theme_font("font").get_string_size("< %s >" % nome, HORIZONTAL_ALIGNMENT_LEFT, -1, a._mapa.get_theme_font_size("font_size")).x
\t\tok(largura + 8 <= a._mapa.size.x, "nome completo %s cabe no botão" % nome)
\tok(a._mapa.position.x + a._mapa.size.x <= a._entrar.position.x, "MAPA não invade ENTRAR")
''');p.write_text(s,encoding='utf-8')
