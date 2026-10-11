extends Node
# Teste automático: armas públicas novas (#65, marco 2). Cada uma (base e evolução) machuca de verdade uma roda de
# inimigos, as evoluções estão bem ligadas (arma + passivo -> evolução) e os dados têm o que o duelo e a IA precisam.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/armas_novas.tscn  (imprime "ARMAS_NOVAS falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Armas := preload("res://scripts/hordas/armas.gd")
const NOVAS := [
	"machado", "machados_brasa", "raio", "furia_ceus", "lanca", "lanca_ardente", "corvos", "revoada", "runas", "circulo_runico", "martelo", "terremoto"
]
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
	# --- dados: tipo com módulo, família pro duelo, ícone; base tem níveis, evolução não
	for id in NOVAS:
		var d := Dados.item(id)
		ok(not d.is_empty(), "%s existe no armas.json" % id)
		ok(Armas.MODULOS.has(str(d.get("tipo", ""))), "%s: o tipo %s tem módulo" % [id, d.get("tipo", "")])
		ok(str(d.get("familia", "")) in ["projetil", "chicote", "orbita", "poca", "aura"], "%s: família pro duelo e pra IA" % id)
		ok(Dados.icone(str(d.get("icone", ""))) != null, "%s: o ícone existe" % id)
		ok(d.get("evolucao", false) == d.get("niveis", []).is_empty(), "%s: base tem níveis, evolução não" % id)
		if d.has("sprite"):
			ok(Dados.tex(str(d.sprite)) != null, "%s: o sprite existe" % id)
	# --- evoluções: toda arma nova tem a sua, com um passivo que existe, e nenhum passivo serve a duas
	var usados := {}
	for e in Dados.json("evolucoes").get("lista", []):
		ok(not Dados.item(str(e.arma)).is_empty() and Dados.item(str(e.vira)).get("evolucao", false), "evolução %s -> %s válida" % [e.arma, e.vira])
		ok(Dados.json("passivos").has(str(e.passivo)), "evolução de %s pede um passivo que existe (%s)" % [e.arma, e.passivo])
		ok(not usados.has(e.passivo), "o passivo %s abre só uma evolução" % e.passivo)
		usados[e.passivo] = true
	for id in NOVAS:
		if not Dados.item(id).get("evolucao", false):
			ok(Dados.json("evolucoes").get("lista", []).any(func(e): return e.arma == id), "%s tem evolução" % id)
	# --- cada arma machuca de verdade: herói parado no meio de uma roda de inimigos que não morrem
	for id in NOVAS:
		var a := Arena.new()
		a.heroi_id = "hazaki"
		add_child(a)
		await esperar(0.2)
		a.bot = false
		a.armas.lista.clear()
		a.armas.adicionar(id)
		for i in 16:
			var v = a.inimigos.criar("lobo_sombrio", a.jogador.centro() + Vector2.from_angle(TAU * i / 16) * (40.0 + 30.0 * (i % 3)))
			if v:
				v.hp = 99999.0
				v.hpmax = 99999.0
				v.vel = 0.0
		await esperar(4.5)
		ok(float(a.dano_por_arma.get(id, 0.0)) > 0.0, "%s machucou os inimigos (dano %d)" % [id, int(a.dano_por_arma.get(id, 0.0))])
		a.queue_free()
		await esperar(0.1)
	print("ARMAS_NOVAS falhas=%d" % falhas)
	get_tree().quit()
