extends "res://testes/isolamento_v2.gd"
# Teste da colisão de monstro só perto da tela (#336). mundo.mover_monstro: fora da tela + margem o monstro anda sem colisão;
# dentro da margem a barreira segura; se a colisão liga com o monstro já dentro de uma forma, ele segue sem colisão até sair.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_colisao_tela.tscn  (imprime "v2_colisao_tela falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Colisao := preload("res://v2/colisao.gd")
const MARGEM := 120.0  # o mesmo MARGEM_COLISAO de mundo.gd

var falhas := 0
var w


class Corpo:
	var pos := Vector2.ZERO
	var raio := 7.0
	var colisao_ligada := false
	var sem_colisao_ate_sair := false

	func definir_pos(p: Vector2) -> void:
		pos = p


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	# o mapa inteiro fica só com a caixa de teste: as barreiras do cenário não atrapalham a conta
	Colisao.limpar()
	var tela: Rect2 = w.cam.retangulo(0.0)
	var cx := tela.position.x + 300.0
	var cy := tela.position.y + tela.size.y * 0.5
	Colisao.adicionar_objeto(Vector2(cx, cy), [{"tipo": "caixa", "centro": [0, 0], "meio": [20, 20]}])
	var m := Corpo.new()

	# 1. fora da tela + margem: a caixa não segura o monstro (anda em linha reta, atravessa)
	m.pos = Vector2(tela.position.x - 400.0, cy)  # 400 px antes da borda esquerda, bem fora da margem de 120
	var andou: Vector2 = w.mover_monstro(m, Vector2(900.0, 0.0))
	ok(not m.colisao_ligada, "fora da tela + margem: colisão desligada")
	ok(absf(andou.x - 900.0) < 0.5, "fora da tela: o monstro anda em linha reta (andou %.1f de 900)" % andou.x)

	# 2. dentro da margem: a caixa segura o monstro, que para antes dela
	m.pos = Vector2(cx - 100.0, cy)  # 100 px à esquerda da caixa, dentro da margem (tela + 120)
	m.colisao_ligada = false
	m.sem_colisao_ate_sair = false
	w.mover_monstro(m, Vector2(150.0, 0.0))
	ok(m.colisao_ligada, "dentro da margem: colisão ligada")
	ok(not m.sem_colisao_ate_sair, "fora da caixa ao ligar: colisão normal")
	ok(m.pos.x < cx - 20.0, "dentro da margem: a caixa segura o monstro (parou em x %.1f, caixa começa em %.1f)" % [m.pos.x, cx - 20.0])

	# 3. ligou dentro de uma forma: anda sem colisão até sair
	m.pos = Vector2(cx, cy)
	m.colisao_ligada = false
	m.sem_colisao_ate_sair = false
	w.mover_monstro(m, Vector2(30.0, 0.0))
	ok(m.sem_colisao_ate_sair, "ligou dentro da caixa: marca a saída livre")
	ok(absf(m.pos.x - (cx + 30.0)) < 0.5, "dentro da caixa com saída livre: segue sem empurrão (x %.1f)" % m.pos.x)
	w.mover_monstro(m, Vector2(100.0, 0.0))
	ok(not m.sem_colisao_ate_sair, "fora da caixa: a saída livre termina")

	# 4. fora da tela de novo, o monstro é deixado solto (sem colisão), com a flag limpa
	m.pos = Vector2(tela.position.x - 400.0, cy)
	w.mover_monstro(m, Vector2(10.0, 0.0))
	ok(not m.colisao_ligada, "volta a ficar longe: colisão desligada de novo")

	print("v2_colisao_tela falhas=%d" % falhas)
	get_tree().quit()
