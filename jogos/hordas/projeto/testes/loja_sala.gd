extends Node
# Teste automático (#112 itens 5 e 6): sala da loja com vendedor. Cada jogador tem a sua loja (estoque, compras e preço próprios);
# o preço sobe a cada compra do próprio jogador; sem ouro não compra; a porta leva à próxima etapa (o mapa).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/loja_sala.tscn  (imprime "LOJASALA falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Loja := preload("res://scripts/hordas/loja.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	# --- curva de preço (pura)
	var c: Dictionary = Loja.cfg().get("curva", {})
	ok(float(c.get("aumento", 0)) > 0.0 and float(c.get("teto", 0)) >= 1.0, "mapa.json: curva da loja (aumento e teto)")
	var base := 400
	ok(Loja.preco_atual(base, 0) == base, "sem compras: preço-base")
	ok(Loja.preco_atual(base, 1) > Loja.preco_atual(base, 0) and Loja.preco_atual(base, 2) > Loja.preco_atual(base, 1), "o preço sobe a cada compra")
	ok(Loja.preco_atual(base, 1) == int(round(base * (1.0 + float(c.aumento)))), "preço = base * (1 + aumento * compras)")
	ok(Loja.preco_atual(base, 9999) == int(round(base * float(c.teto))), "o preço tem teto")

	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = false
	a.semente = 7
	add_child(a)
	await esperar(0.3)
	a.bot = false
	a.jogador.bot = false
	var l = a.loja
	var cartas: Array = a.sortear_cartas(Sorte.criar("loja", 3))
	a.ouro = 100000
	l.abrir(cartas)
	await esperar(0.5)
	ok(l.aberto() and not l.vitrine_aberta(), "a sala abre (sem vitrine ainda)")
	var eu: int = l.id_local()
	var of: Array = l.estado(eu).ofertas
	ok(of.size() >= 3, "a vitrine tem itens (%d)" % of.size())
	# --- ir até o balcão
	ok(not l.perto_do_balcao(), "a sala começa longe do balcão")
	l._pos = Loja.VENDEDOR + Vector2(0, 40)
	ok(l.perto_do_balcao(), "junto do balcão dá pra falar com o vendedor")
	# --- preço sobe a cada compra do mesmo jogador (de todos os itens)
	var p0: int = l.preco_de(eu, 0)
	var p1: int = l.preco_de(eu, 1)
	ok(p0 == int(of[0].base), "antes de comprar: preço-base (%d)" % p0)
	var ouro0: int = a.ouro
	ok(l.comprar(0), "comprou o item 0")
	ok(a.ouro == ouro0 - p0, "o ouro foi gasto (%d -> %d)" % [ouro0, a.ouro])
	ok(l.compras_de(eu) == 1, "uma compra registrada")
	var p1b: int = l.preco_de(eu, 1)
	ok(p1b > p1, "o preço do outro item subiu depois da compra (%d -> %d)" % [p1, p1b])
	ok(l.comprar(1), "comprou o item 1 (pelo preço novo)")
	ok(l.compras_de(eu) == 2 and l.preco_de(eu, 2) > Loja.preco_atual(int(of[2].base), 1), "duas compras: o preço subiu mais")
	ok(not l.comprar(0), "item já comprado não compra de novo")
	# --- dois jogadores são independentes
	var outro := 2 if eu != 2 else 3
	l.estado(outro).ofertas = Loja.montar_ofertas(cartas)
	ok(l.compras_de(outro) == 0 and l.preco_de(outro, 2) == int(l.estado(outro).ofertas[2].base), "o outro jogador tem preço-base e 0 compras")
	l.estado(outro).ouro = 100000
	var meu_ouro: int = a.ouro
	ok(l.comprar(0, outro) and l.compras_de(outro) == 1, "o outro compra na loja dele")
	ok(l.compras_de(eu) == 2 and a.ouro == meu_ouro, "as compras (e o ouro) do outro não mexem nos meus")
	ok(bool(l.estado(eu).ofertas[0].comprado) and not bool(l.estado(outro).ofertas[1].comprado), "estoques separados")
	# --- sem ouro
	a.ouro = 0
	var compras_antes: int = l.compras_de(eu)
	var pend := -1
	for i in of.size():
		if not bool(of[i].comprado):
			pend = i
			break
	ok(pend >= 0 and not l.comprar(pend), "sem ouro: a compra falha")
	ok(a.ouro == 0 and l.compras_de(eu) == compras_antes and not bool(of[pend].comprado), "sem ouro: nada muda")
	# --- sair leva à próxima etapa (o mapa) no fluxo do nó
	l.fechar()
	ok(not l.aberto(), "fechar sai da sala")
	a.entre_fases = true
	a.inimigos.limpar()
	a.ouro = 1000
	var ac: Array = a.mapa_acessiveis()
	for x in ac:
		a.mapa.nos[a.mapa_pos.x + 1][x].tipo = "loja"
	var andar0: int = a.mapa_pos.x
	a.escolher_no(ac[0])
	var n := 0
	while not l.aberto() and n < 60:
		await esperar(0.1)
		n += 1
	ok(l.aberto() and a.no_tipo == "loja" and a.mapa_pos.x == andar0 + 1, "escolher o nó de loja abre a sala")
	ok(not a.tela_mapa.aberto(), "dentro da sala o mapa não está aberto")
	await esperar(0.5)
	l._pos = Loja.PORTA.get_center()  # o herói pisa na porta
	n = 0
	while l.aberto() and n < 30:
		await esperar(0.1)
		n += 1
	ok(not l.aberto(), "pisar na porta sai da sala")
	n = 0
	while not a.tela_mapa.aberto() and n < 30:
		await esperar(0.1)
		n += 1
	ok(a.tela_mapa.aberto() and not l.aberto(), "depois da loja segue a próxima etapa: o mapa abre")
	print("LOJASALA falhas=", falhas)
	get_tree().quit(1 if falhas > 0 else 0)
