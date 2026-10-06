extends Node
# Teste: estados de animação do jogador (folha de 23 colunas) e compatibilidade com 9 colunas.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/animacao.tscn  (imprime "ANIM falhas=0")
const J := preload("res://scripts/hordas/jogador.gd")
const DIRS := ["baixo", "esquerda", "direita", "cima"]
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func tex(w: int) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(w, 480, false, Image.FORMAT_RGBA8))

func faixa(f: int, hf: int, d: String, c0: int, c1: int) -> bool:
	return f / hf == J.LINHA[d] and f % hf >= c0 and f % hf <= c1

func _ready() -> void:
	# função pura
	for d in DIRS:
		for t in [0.0, 0.05, 0.3, 1.0, 7.3]:
			var f9: int = J.quadro_de("andando", d, t, 9)
			ok(f9 == J.LINHA[d] * 9 + 1 + int(t * 12.0) % 8, "9 col andando %s %s" % [d, t])
			ok(J.quadro_de("parado", d, t, 9) == J.LINHA[d] * 9, "9 col parado %s" % d)
			for e in ["ataque", "defesa", "dano", "morte"]:
				ok(J.quadro_de(e, d, t, 9) == J.LINHA[d] * 9, "9 col %s cai em parado" % e)
			ok(faixa(J.quadro_de("andando", d, t, 23), 23, d, 1, 8), "23 col andando %s %s" % [d, t])
			ok(faixa(J.quadro_de("parado", d, t, 23), 23, d, 9, 11), "23 col parado %s %s" % [d, t])
			ok(faixa(J.quadro_de("ataque", d, t, 23), 23, d, 12, 14), "23 col ataque %s %s" % [d, t])
			ok(faixa(J.quadro_de("defesa", d, t, 23), 23, d, 15, 16), "23 col defesa %s %s" % [d, t])
			ok(faixa(J.quadro_de("dano", d, t, 23), 23, d, 17, 18), "23 col dano %s %s" % [d, t])
			ok(faixa(J.quadro_de("morte", d, t, 23), 23, d, 19, 22), "23 col morte %s %s" % [d, t])
		ok(J.quadro_de("morte", d, 5.0, 23) == J.LINHA[d] * 23 + 22, "morte fica no último quadro")
		ok(J.quadro_de("ataque", d, 0.0, 23) == J.LINHA[d] * 23 + 12 and J.quadro_de("ataque", d, 0.24, 23) == J.LINHA[d] * 23 + 14, "ataque 12..14 em 0,25 s")
	# no jogo
	var m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(0.3).timeout
	m._comecar("hazaki")
	var a = m._arena
	var j = a.jogador
	await get_tree().process_frame
	ok(j.spr.hframes == j.spr.texture.get_width() / 44, "hframes vem da textura")
	for c in j.camadas.values():
		ok(c.hframes == j.spr.hframes, "camada com os mesmos hframes")
	# 9 colunas
	j.spr.texture = tex(396)
	j.spr.hframes = 9
	j.atualizar(0.016)
	ok(j.spr.frame == 0, "9 col parado: frame %d" % j.spr.frame)
	j.atacou()
	j.atualizar(0.016)
	ok(j.spr.frame == 0, "9 col: ataque não muda nada (%d)" % j.spr.frame)
	# 23 colunas
	j.spr.texture = tex(1012)
	j.spr.hframes = 23
	j._atk_cool = 0.0
	j.invencivel = 0.0
	j.dash_t = 0.0
	j._olhar.angulo = -90.0
	j._olhar.alvo = -90.0
	j._olhar.dir = "esquerda"
	j._dir = "esquerda"
	for i in 10:
		j.atualizar(0.05)
	ok(faixa(j.spr.frame, 23, "esquerda", 9, 11), "parado respirando (%d)" % j.spr.frame)
	j.atacou()
	j.atualizar(0.05)
	ok(faixa(j.spr.frame, 23, "esquerda", 12, 14), "ataque (%d)" % j.spr.frame)
	var antes: float = j._atk_cool
	j.atacou()
	ok(j._atk_cool == antes, "intervalo mínimo entre ataques")
	for i in 8:
		j.atualizar(0.05)
	ok(faixa(j.spr.frame, 23, "esquerda", 9, 11), "volta ao parado depois do ataque (%d)" % j.spr.frame)
	j.dash_t = 0.1
	j.atualizar(0.01)
	ok(faixa(j.spr.frame, 23, "esquerda", 15, 16), "defesa no dash (%d)" % j.spr.frame)
	j.dash_t = 0.0
	j.atualizar(0.01)
	j.invencivel = 0.0
	j.sofrer(1.0)
	j.atualizar(0.01)
	ok(faixa(j.spr.frame, 23, "esquerda", 17, 18), "dano (%d)" % j.spr.frame)
	j.atacou()
	j.atualizar(0.01)
	ok(faixa(j.spr.frame, 23, "esquerda", 17, 18), "dano tem prioridade sobre ataque (%d)" % j.spr.frame)
	for i in 6:
		j.atualizar(0.05)
	# morte (a arena para de atualizar; _process anima)
	j.hp = 0.0
	for i in 40:
		j._process(0.05)
	ok(j.spr.frame == J.LINHA["esquerda"] * 23 + 22, "morte termina no último quadro (%d)" % j.spr.frame)
	j.hp = 50.0
	j.atualizar(0.05)
	ok(faixa(j.spr.frame, 23, "esquerda", 9, 11), "reviver volta ao parado (%d)" % j.spr.frame)
	print("ANIM falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
