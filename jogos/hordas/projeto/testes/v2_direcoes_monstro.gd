extends Node
## A linha da folha do monstro por direção do movimento (v2/monstro.gd): folha de 5 linhas (frente, 3/4 baixo, perfil, 3/4 costas, costas)
## e retrocompatibilidade com a folha de 2 linhas (frente, três quartos). Também confere as folhas reais carregadas por v2/sprites.gd.
const Monstro := preload("res://v2/monstro.gd")
const Sprites := preload("res://v2/sprites.gd")
const TIPOS := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_espantalho", "inimigo_lobo_sombrio", "inimigo_cavaleiro_oco"]
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _monstro(n_lin: int) -> RefCounted:
	var m := Monstro.new()
	var linhas: Array = ["frente", "tres_quartos"] if n_lin == 2 else ["frente", "tq_baixo", "perfil", "tq_costas", "costas"]
	m.tipo = {"w": 40, "h": 42, "info": {"linhas": linhas}}
	m.n_col = 4
	m.n_lin = n_lin
	return m


func _anda(m, v: Vector2) -> void:
	m.vel_v = v
	m._escolher_quadro(v)


func _ready() -> void:
	# ---- 5 linhas
	var m := _monstro(5)
	_anda(m, Vector2(0, 50))
	ok(m.linha == 0, "descendo usa frente (linha %d)" % m.linha)
	_anda(m, Vector2(0, -50))
	ok(m.linha == 4, "subindo usa costas (linha %d)" % m.linha)
	_anda(m, Vector2(50, 0))
	ok(m.linha == 2 and not m.espelha, "indo para a direita: perfil sem espelho (linha %d, espelha %s)" % [m.linha, m.espelha])
	_anda(m, Vector2(-50, 0))
	ok(m.linha == 2 and m.espelha, "indo para a esquerda: perfil espelhado")
	_anda(m, Vector2(-35, -35))
	ok(m.linha == 3 and m.espelha, "diagonal para cima e esquerda: 3/4 costas espelhado (linha %d)" % m.linha)
	_anda(m, Vector2(35, -35))
	ok(m.linha == 3 and not m.espelha, "diagonal para cima e direita: 3/4 costas sem espelho")
	_anda(m, Vector2(35, 35))
	ok(m.linha == 1 and not m.espelha, "diagonal para baixo e direita: 3/4 baixo (linha %d)" % m.linha)
	_anda(m, Vector2(-35, 35))
	ok(m.linha == 1 and m.espelha, "diagonal para baixo e esquerda: 3/4 baixo espelhado")
	# de costas o espelho fica como estava (subindo reto não vira o bicho)
	_anda(m, Vector2(-50, 0))
	_anda(m, Vector2(0.2, -50))
	ok(m.linha == 4 and m.espelha, "subindo reto mantém o espelho")
	# parado mantém a última linha
	_anda(m, Vector2.ZERO)
	ok(m.linha == 4, "parado mantém a linha (costas)")
	# histerese: perto da fronteira (67,5 graus entre 3/4 baixo e perfil) não pisca
	var m2 := _monstro(5)
	_anda(m2, Vector2(0, 50))
	_anda(m2, Vector2.from_angle(deg_to_rad(90.0 - 70.0)) * 50.0)  # 70 graus da vertical: passou de 67,5, vira perfil
	var l_a: int = m2.linha
	_anda(m2, Vector2.from_angle(deg_to_rad(90.0 - 66.0)) * 50.0)  # 66 graus: voltou da fronteira, mas dentro da folga: fica
	ok(m2.linha == l_a, "histerese: 66 e 70 graus ficam na mesma linha (%d e %d)" % [l_a, m2.linha])
	var m3 := _monstro(5)
	_anda(m3, Vector2(50, 50))
	_anda(m3, Vector2.from_angle(deg_to_rad(90.0 - 72.0)) * 50.0)
	ok(m3.linha == 1, "histerese: a 72 graus (dentro da folga de 8) ainda é 3/4 baixo (linha %d)" % m3.linha)
	_anda(m3, Vector2.from_angle(deg_to_rad(90.0 - 80.0)) * 50.0)
	ok(m3.linha == 2, "além da folga troca para perfil (linha %d)" % m3.linha)
	# o recorte acompanha a linha (é o que a horda, o flash, a dissolução e o contorno leem)
	ok(is_equal_approx(m.regiao.position.y, 4 * 42.0), "regiao do quadro segue a linha 4")
	# ---- 2 linhas (como antes)
	var a := _monstro(2)
	_anda(a, Vector2(0, -50))
	ok(a.linha == 0, "2 linhas: subindo continua na linha 0")
	_anda(a, Vector2(50, 10))
	ok(a.linha == 1 and not a.espelha, "2 linhas: lado usa a linha 1")
	_anda(a, Vector2(-50, 10))
	ok(a.linha == 1 and a.espelha, "2 linhas: lado esquerdo espelha")
	_anda(a, Vector2(0.2, 50))
	ok(a.linha == 0 and a.espelha, "2 linhas: descendo reto mantém o espelho")
	# ---- folhas reais: o json diz quantas linhas e a emissão por linha bate
	var sp := Sprites.new()
	for nome in TIPOS:
		var t := sp.tipo(nome)
		var n_lin := int(t.info.get("linhas", []).size())
		ok(n_lin == 2 or n_lin == 5, "%s: folha com 2 ou 5 linhas (%d)" % [nome, n_lin])
		ok(int(t.alb.get_height()) == n_lin * int(t.h), "%s: altura da folha = linhas x quadro" % nome)
		if t.emissao != null:
			ok((t.emite as Array).size() == n_lin, "%s: emite tem uma entrada por linha (%d)" % [nome, (t.emite as Array).size()])
			ok(bool(t.emite[0]), "%s: a linha de frente tem olhos" % nome)
			if n_lin == 5:
				print("%s: emissão por linha %s" % [nome, t.emite])
	print("v2_direcoes_monstro falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
