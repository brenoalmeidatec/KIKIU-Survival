extends SceneTree
## Balanceamento simples dos chefes da v3: simula cada luta com um jogador que tira um dano constante por segundo
## e NÃO esquiva (pior caso para o jogador). Mede o tempo até a morte do chefe e quantos golpes e quanto dano o jogador
## levaria se ficasse parado. Também lista as janelas de esquiva (tempo de aviso de cada golpe). Não modela reação humana.
## Roda: godot --headless --path jogos/hordas/projeto -s res://testes/v3_balanco.gd

const Vornak := preload("res://v3/chefes/vornak.gd")
const Nythrax := preload("res://v3/chefes/nythrax.gd")
const Maltherion := preload("res://v3/chefes/maltherion.gd")
const PASSO := 0.05
const DPS_JOGADOR := [80.0, 150.0, 250.0]


func _initialize() -> void:
	for par in [["Vornak", Vornak], ["Nythrax", Nythrax], ["Maltherion", Maltherion]]:
		simular(par[0], par[1])
	quit(0)


func simular(nome: String, classe) -> void:
	print("== %s ==" % nome)
	for dps in DPS_JOGADOR:
		var c = classe.new()
		c.iniciar(classe.CONFIG)
		var golpes := [0]
		var dano := [0.0]
		c.golpe.connect(func(_n, _r, d): golpes[0] += 1; dano[0] += d)
		var tempo := 0.0
		while not c.morto() and tempo < 1200.0:
			c.avancar(PASSO)
			c.receber_dano(dps * PASSO)
			tempo += PASSO
		print("  jogador a %d de dano/s: chefe cai em %.0f s; parado levaria %d golpes e %.0f de dano" % [int(dps), tempo, golpes[0], dano[0]])
	print("  janelas de esquiva (aviso, dano, recarga):")
	for a in classe.CONFIG.ataques:
		print("    %s: aviso %.1f s, dano %.0f, recarga %.1f s, fase %d" % [a.nome, float(a.aviso), float(a.get("dano", 0.0)), float(a.recarga), int(a.fase)])
