extends Node
# Teste automático: o golpe do cliente online leva o id da arma (índice numa tabela fixa) até o anfitrião.
# Id válido põe o elemento e a causa de morte; id inválido/ausente/de outro herói cai no golpe sem arma de antes.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/golpe_remoto.tscn  (imprime "GOLPE_REMOTO falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Online := preload("res://scripts/hordas/online.gd")
const Mortes := preload("res://scripts/hordas/mortes.gd")
var falhas := 0
var a
var ino
var on
var base := Vector2.ZERO


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func novo(vida := 1.0e6):
	var v = ino.criar("spam", base)
	v.hpmax = vida
	v.hp = vida
	v.t_nasc = 0.0
	v.vel = 0.0
	return v


## Manda um pacote de 1 acerto como o cliente mandaria (5 floats) pelo caminho do anfitrião.
func golpe(v, dano: float, idx: float, quem := 2) -> void:
	on.acertos(quem, PackedFloat32Array([v.id, dano, 10.0, 0.0, idx]))


func gelo_fogo(v, el: String) -> float:
	if not ino.elementos.estados.has(v.id):
		return 0.0
	return float(ino.elementos.estados[v.id].st.get(el, [0.0])[0])


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	a = Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	a.semente = 5
	add_child(a)
	await get_tree().create_timer(0.2, true, false, true).timeout
	a.set_process(false)
	a.jogador.invencivel = 999.0
	ino = a.inimigos
	ino.limpar()
	a.armas.lista.clear()
	base = a.jogador.position + Vector2(220, 0)
	on = Online.new()
	on.arena = a
	add_child(on)
	Rede.jogadores[2] = {"heroi": "joao", "nome": "Cliente"}

	# tabela fixa: alfabética, 1..N, estável
	var n: int = on.armas_ids.size()
	ok(n >= 30, "a tabela tem as armas do jogo (%d)" % n)
	var ord: Array = on.armas_ids.duplicate()
	ord.sort()
	ok(ord == on.armas_ids, "a tabela está em ordem alfabética (igual em todo computador)")
	for id in on.armas_ids:
		ok(on.armas_ids[on.arma_idx(id) - 1] == id, "ida e volta de " + str(id))
	ok(on.arma_idx("") == 0 and on.arma_idx("investida") == 0 and on.arma_idx("Bomba") == 0, "o que não é arma vira índice 0")

	# lado do cliente: 5 floats por acerto, o quinto é o índice
	on.acerto(77, 12.0, Vector2(3, 4), "machados_brasa")
	on.acerto(78, 5.0, Vector2.ZERO, "investida")
	on.acerto(79, 5.0, Vector2.ZERO)
	ok(on._acertos.size() == 15, "3 acertos = 15 floats (%d)" % on._acertos.size())
	ok(int(on._acertos[4]) == on.arma_idx("machados_brasa") and on._acertos[9] == 0.0 and on._acertos[14] == 0.0, "índice no quinto float; sem arma = 0")

	# validação do anfitrião
	ok(
		on.arma_do_cliente(2, 0) == "" and on.arma_do_cliente(2, -3) == "" and on.arma_do_cliente(2, n + 1) == "" and on.arma_do_cliente(2, 99999) == "",
		"índice fora da tabela = sem arma"
	)
	ok(on.arma_do_cliente(2, on.arma_idx("katana")) == "", "arma exclusiva do Hazaki: o cliente de João não pode")
	ok(on.arma_do_cliente(2, on.arma_idx("baforada")) == "", "arma de transformação de outro herói recusada")
	Rede.jogadores[3] = {"heroi": "hazaki", "nome": "Outro"}
	ok(on.arma_do_cliente(3, on.arma_idx("katana")) == "katana", "o cliente de Hazaki pode a katana")
	ok(on.arma_do_cliente(2, on.arma_idx("machados_brasa")) == "machados_brasa", "arma global vale pra qualquer cliente")

	# id válido: elemento + causa de morte
	var v = novo()
	golpe(v, 10.0, on.arma_idx("machados_brasa"))
	ok(v.hp == 1.0e6 - 10.0, "o dano entrou")
	ok(gelo_fogo(v, "fogo") > 0.0, "arma de fogo do cliente põe fogo")
	ok(v.arma_ult == "machados_brasa", "a arma do cliente é a causa do golpe")
	var v2 = novo()
	golpe(v2, 10.0, on.arma_idx("geada"))
	ok(gelo_fogo(v2, "gelo") > 0.0, "a Geada do cliente põe gelo")

	# sem id / inválido: igual a hoje (dano, sem elemento, causa padrão)
	var v3 = novo()
	golpe(v3, 10.0, 0.0)
	ok(v3.hp == 1.0e6 - 10.0 and not ino.elementos.estados.has(v3.id) and v3.arma_ult == "", "índice 0: dano sem elemento, como antes")
	var v4 = novo()
	golpe(v4, 10.0, 9999.0)
	ok(v4.hp == 1.0e6 - 10.0 and not ino.elementos.estados.has(v4.id) and v4.arma_ult == "", "índice inexistente: dano sem elemento")
	var v5 = novo()
	golpe(v5, 10.0, NAN)
	ok(v5.hp == 1.0e6 - 10.0 and v5.arma_ult == "", "índice NaN: dano sem arma")
	var v6 = novo()
	golpe(v6, 10.0, on.arma_idx("katana"))
	ok(v6.hp == 1.0e6 - 10.0 and v6.arma_ult == "" and not ino.elementos.estados.has(v6.id), "arma de outro herói: dano sem arma")

	# a `chance` de elemento do anfitrião não vaza pro golpe do cliente
	ino.elementos.chance = {"fogo": 1.0}
	var v8 = novo()
	golpe(v8, 10.0, 0.0)
	ok(not ino.elementos.estados.has(v8.id), "a chance de elemento do anfitrião não vale pro golpe do cliente")
	ino.elementos.chance = {}

	# morte: a causa usa a arma do cliente
	var vm = novo(5.0)
	golpe(vm, 50.0, on.arma_idx("geada"))
	ok(vm.hp <= 0.0 and vm.arma_ult == "geada" and Mortes.causa_de(vm.arma_ult, vm.causa_ult) == "gelo", "morte pela Geada do cliente: causa gelo")
	var vn = novo(5.0)
	golpe(vn, 50.0, on.arma_idx("pendrive"))
	ok(vn.arma_ult == "pendrive" and Mortes.causa_de(vn.arma_ult, vn.causa_ult) == "tiro", "morte pelo Pendrive: causa tiro")
	var vz = novo(5.0)
	golpe(vz, 50.0, 0.0)
	ok(vz.arma_ult == "" and Mortes.causa_de(vz.arma_ult, vz.causa_ult) == "padrao", "morte sem arma: causa padrão")

	# o resultado do cliente: o dano por arma é creditado no cliente (registrar_dano roda antes do envio)
	var cli = Arena.new()
	cli.heroi_id = "joao"
	cli.bot = true
	cli.semente = 5
	add_child(cli)
	await get_tree().create_timer(0.2, true, false, true).timeout
	cli.set_process(false)
	cli.registrar_dano("machados_brasa", 12.0, Vector2.ZERO)
	ok(is_equal_approx(float(cli.dano_por_arma.get("machados_brasa", 0.0)), 12.0), "resultado do cliente conta o dano por arma")

	print("GOLPE_REMOTO falhas=", falhas)
	get_tree().quit()
