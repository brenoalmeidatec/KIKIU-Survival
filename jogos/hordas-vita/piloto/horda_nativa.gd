extends "res://horda.gd"
## Mesma interface da horda em GDScript (horda.gd), mas a simulação e o desenho rodam no módulo C++ HordaVita,
## que só existe no template próprio do Vita (jogos/hordas-vita/modulo). O atlas e os recortes continuam sendo
## montados pelo horda.gd; aqui só repassa. No editor do PC a classe não existe e o main.gd usa a horda em GDScript.

var nat: Node2D


static func disponivel() -> bool:
	return ClassDB.class_exists("HordaVita")


func carregar(lista: Array, arq_proj: String) -> void:
	.carregar(lista, arq_proj)
	nat = ClassDB.instance("HordaVita")
	add_child(nat)
	var tipos = []
	for i in t_vel.size():
		tipos.append({"vel": t_vel[i], "raio": t_raio[i], "qx": t_qx[i], "qy": t_qy[i], "quadro_px": t_quadro_px[i],
			"nq": t_nq[i], "vistas": t_vistas[i], "luz": i == idx_luz, "src": t_src[i]})
	nat.configurar(tex_atlas, tipos, src_proj)


func definir_quantidade(n: int) -> void:
	nat.definir_quantidade(n)


func quantidade() -> int:
	return nat.quantidade()


func atualizar(dt: float) -> void:
	nat.definir_alvo(alvo, visivel)
	nat.definir_limites(max_desenho, lod_longe, ordenar_y)
	nat.passo(dt)
	var e: Dictionary = nat.estatisticas()
	n_perto = e.perto
	n_desenhados = e.desenhados
	us_logica = e.us_logica
	us_desenho = e.us_desenho      # do quadro anterior (o desenho acontece depois do passo)
	us_proj = e.us_proj
	n_proj = e.projeteis
	acertos = e.acertos


func golpe(centro: Vector2, raio: float) -> Array:
	return Array(nat.golpe(centro, raio))


func disparar(origem: Vector2, v: Vector2, vida: float) -> void:
	nat.disparar(origem, v, vida)


func atualizar_proj(_dt: float) -> Array:
	return []                      # os projéteis andam dentro do passo do C++


func luzes_visiveis(area: Rect2, maximo: int) -> Array:
	return Array(nat.luzes(area, maximo))


func _draw() -> void:
	pass                           # quem desenha é o nó C++ filho
