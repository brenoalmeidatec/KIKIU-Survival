extends SceneTree
## Balanceamento simples dos chefes da v3, em porcentagem da vida do herói de referência.
## Herói de referência: 100 de vida (v2, dados/v2_combate.json > heroi.vida). PROVISÓRIO até a v3 ter o herói próprio.
## A luta é simulada com um jogador que tira um dano constante por segundo e NÃO esquiva (pior caso). Mede quanto o
## jogador levaria se ficasse parado durante a luta inteira.
## Metas (do coordenador): mini-chefes 30 a 40% da vida; Maltherion um pouco mais (40 a 60%); esquiva com aviso de no mínimo 0,5 s.
## Roda: godot --headless --path v3/godot -s res://testes/v3_balanco.gd  (imprime "v3_balanco falhas=0")

const Vornak := preload("res://chefes/vornak.gd")
const Nythrax := preload("res://chefes/nythrax.gd")
const Maltherion := preload("res://chefes/maltherion.gd")
const PASSO := 0.05
const DPS_JOGADOR := 80.0
const VIDA_HEROI := 100.0
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _initialize() -> void:
	var faixas := {"Vornak": [0.30, 0.40], "Nythrax": [0.30, 0.40], "Maltherion": [0.40, 0.60]}
	for par in [["Vornak", Vornak], ["Nythrax", Nythrax], ["Maltherion", Maltherion]]:
		var pct: float = simular(par[0], par[1])
		var f: Array = faixas[par[0]]
		ok(pct >= f[0] and pct <= f[1], "%s: parado custa %.0f%% da vida (meta %d a %d%%)" % [par[0], pct * 100.0, int(f[0] * 100), int(f[1] * 100)])
		ok(janelas_minimas(par[1]), "%s: janelas de esquiva com aviso de no mínimo 0,5 s" % par[0])
	print("v3_balanco falhas=", falhas)
	quit(1 if falhas > 0 else 0)


func simular(nome: String, classe) -> float:
	var c = classe.new()
	c.iniciar(classe.CONFIG)
	var golpes := [0]
	var dano := [0.0]
	c.golpe.connect(
		func(_n, _r, d):
			golpes[0] += 1
			dano[0] += d
	)
	var tempo := 0.0
	while not c.morto() and tempo < 1200.0:
		c.avancar(PASSO)
		c.receber_dano(DPS_JOGADOR * PASSO)
		tempo += PASSO
	var pct: float = dano[0] / VIDA_HEROI
	print(
		(
			"%s: chefe cai em %.0f s a %d de dano/s; parado levaria %d golpes e %.0f de dano (%.0f%% da vida do herói)"
			% [nome, tempo, int(DPS_JOGADOR), golpes[0], dano[0], pct * 100.0]
		)
	)
	return pct


func janelas_minimas(classe) -> bool:
	for a in classe.CONFIG.ataques:
		if float(a.aviso) < 0.5:
			print("  aviso curto demais: %s %.1f s" % [a.nome, float(a.aviso)])
			return false
	return true
