extends Node2D
const Perf := preload("res://scripts/hordas/perf.gd")
## As armas do jogador. O jeito de cada uma vem do "tipo" no armas.json. Quando atiram vem do campo `disparo` (#161):
## "clique" = só com o jogador atacando (clique esquerdo do mouse ou gatilho direito; o robô segura sempre), no ritmo da recarga;
## "auto" = sozinha. A arma inicial do herói e a da forma transformada são "clique"; as das cartas, "auto".
## Tipos:
##   projetil  atira no vírus mais perto
##   chicote   golpe reto na frente (e atrás, com mais quantidade)
##   orbita    coisas girando em volta por um tempo
##   poca      poça no chão que machuca quem pisa
##   aura      círculo em volta do jogador que machuca e empurra
## e os tipos com arquivo próprio em MODULOS (katana, pistolas, marcial, aura_energia, elemental).
## Os atributos do jogador (dano, área, quantidade...) multiplicam os da arma na hora de atirar.

const ESCALA := 2.0
const Poca := preload("res://scripts/hordas/poca.gd")
const Legib := preload("res://scripts/hordas/legibilidade.gd")
## Curva de crescimento (#armas-crescem): a arma nasce fraca e pequena e cresce de nível em nível (dados/crescimento_armas.json).
const Cresc := preload("res://scripts/hordas/crescimento.gd")
const Universais := preload("res://scripts/hordas/universais.gd")
## Comportamentos que moram no próprio arquivo (scripts/hordas/armas/<tipo>.gd). Pra criar arma nova com
## comportamento próprio (ex.: exclusiva de outro personagem): escreva o arquivo com atualizar/passo/pintar/fundo
## (veja katana.gd) e registre aqui. atras() desenha o que fica atrás do personagem. Os tipos antigos (projetil, chicote...) continuam neste arquivo.
const MODULOS := {
	"katana": preload("res://scripts/hordas/armas/katana.gd"),
	"pistolas": preload("res://scripts/hordas/armas/pistolas.gd"),
	"marcial": preload("res://scripts/hordas/armas/marcial.gd"),
	"aura_energia": preload("res://scripts/hordas/armas/aura_energia.gd"),
	"elemental": preload("res://scripts/hordas/armas/elemental.gd"),
	# forma de dragão do Hazaki (habilidades.gd): só atacam enquanto ele está transformado
	"baforada": preload("res://scripts/hordas/armas/baforada.gd"),
	"garras": preload("res://scripts/hordas/armas/garras.gd"),
	"energia_draconica": preload("res://scripts/hordas/armas/energia_draconica.gd"),
	"rugido": preload("res://scripts/hordas/armas/rugido.gd"),
	# especiais dos heróis (especial.gd, tecla E): efeitos que só nascem quando o jogador usa o especial
	"pose": preload("res://scripts/hordas/especiais/pose.gd"),
	"manha": preload("res://scripts/hordas/especiais/manha.gd"),
	"onda": preload("res://scripts/hordas/especiais/onda.gd"),
	# armas globais com comportamento próprio (#65)
	"bumerangue": preload("res://scripts/hordas/armas/bumerangue.gd"),
	"raio": preload("res://scripts/hordas/armas/raio.gd"),
	"lanca": preload("res://scripts/hordas/armas/lanca.gd"),
	"corvos": preload("res://scripts/hordas/armas/corvos.gd"),
	"runas": preload("res://scripts/hordas/armas/runas.gd"),
	"sismo": preload("res://scripts/hordas/armas/sismo.gd"),
}

var arena: Node
## Quem usa a arma e contra quem ela bate. O jogador usa os vírus (inimigos.gd); no duelo final,
## o jogador e os rivais usam um "campo" que aponta pros outros lutadores (duelo.gd).
var dono: Node2D  # precisa de centro(), lado e curar()
var campo: Object  # precisa de no_circulo, n_mais_perto, aleatorio_na_tela, ferir
var statf: Callable  # nome do atributo -> valor (dano, recarga, area...)
var lista: Array = []  # {id, nivel, t, ativo, acertos{}}
## Armas da forma transformada (ex.: dragão, habilidades.gd). Enquanto tiver alguma, SÓ elas atacam; as de `lista`
## ficam paradas e intactas (as cartas continuam evoluindo a build humana), e voltam como estavam no fim.
var forma_lista: Array = []
var projeteis: Array = []  # {pos, vel, dano, perfura, vida, tex, esc, acertou[], arma}
var pocas: Array = []  # {pos, raio, vida, dano, tique, t, segue, arma}
var golpes: Array = []  # desenho do chicote {pos, lado, alcance, largura, t, arma}
var _fila: Array = []  # golpes atrasados do chicote {t, arma}
var especiais: Array = []  # efeitos das armas de MODULOS (cada um tem "tipo"; o módulo cuida do resto)
var aneis: Array = []  # ondas visuais de pulso/explosão dos comportamentos (#63): {pos, r, t, total, cor}
var _t := 0.0
var _chao_pocas := Node2D.new()  # poças ficam no chão: abaixo de quem pisa nelas, acima do piso
var _atras := Node2D.new()  # atrás do personagem (ex.: chamas da aura saindo de trás do corpo)


func limpar_tiros() -> void:
	projeteis.clear()
	pocas.clear()
	golpes.clear()
	_fila.clear()
	especiais.clear()
	aneis.clear()
	for a in lista + forma_lista:
		a.ativo = 0.0
		a.acertos = {}


func ativas() -> Array:
	return forma_lista if not forma_lista.is_empty() else lista


## "clique" ou "auto" (#161): o campo `disparo` da arma em armas.json; sem ele, a arma inicial é "clique" e as outras "auto".
static func disparo_de(id: String, inicial := false) -> String:
	var d := Dados.item(id)
	if d.has("disparo"):
		return str(d.disparo)
	return "clique" if inicial else "auto"


func tem(id: String) -> bool:
	return achar(id) != null


func achar(id: String):
	for a in lista:
		if a.id == id:
			return a
	return null


## `inicial` = a arma com que o herói começa (golpe principal): vale "clique", a não ser que o armas.json diga outro `disparo`.
func adicionar(id: String, inicial := false) -> void:
	lista.append({"id": id, "nivel": 1, "t": 0.3, "ativo": 0.0, "acertos": {}, "tique": 0.0, "comp": [], "disparo": disparo_de(id, inicial)})
	preaquecer()
	if arena:
		arena.build_mudou()  # etiquetas da arma nova: o conjunto liga na hora (#63)


# ---------- comportamentos (#63): cartas raras que mudam COMO a arma funciona ----------
## Cada arma guarda em a.comp os ids de dados/comportamentos.json que ela já tem; _s() entrega os parâmetros deles em
## s.comp (id -> param) e cada tipo de arma abaixo lê só o que lhe interessa. Sem comportamento, nada muda.


static func comp_def(id: String) -> Dictionary:
	return Dados.json("comportamentos").get("lista", {}).get(id, {})


func dar_comportamento(arma_id: String, comp_id: String) -> bool:
	if not tem(arma_id):
		return false
	var a: Dictionary = achar(arma_id)
	if comp_id in a.get("comp", []):
		return false
	if not a.has("comp"):
		a["comp"] = []
	a.comp.append(comp_id)
	preaquecer()  # o rastro de fogo gera textura de poça: melhor agora, com as cartas abertas
	return true


## Comportamentos que esta arma pode ganhar agora (tipo certo, nível mínimo, sem repetir nem conflitar).
func comportamentos_disponiveis(a: Dictionary) -> Array:
	var res := []
	var tipo := str(Dados.item(a.id).get("tipo", ""))
	var tem: Array = a.get("comp", [])
	var lista_c: Dictionary = Dados.json("comportamentos").get("lista", {})
	for id in lista_c:
		var d: Dictionary = lista_c[id]
		if d.get("so_fusao", false) or id in tem or not tipo in d.get("tipos", []) or int(a.nivel) < int(d.get("nivel_min", 3)):
			continue
		if d.get("exclui", []).any(func(x): return x in tem):
			continue
		res.append(id)
	return res


## Parâmetros dos comportamentos da arma: id -> param.
func _comp_de(a: Dictionary) -> Dictionary:
	var res := {}
	for id in a.get("comp", []):
		res[id] = comp_def(id).get("param", {})
	for id in Universais.mecanica_de(str(a.id)):  # fusão (#115): a mecânica da receita, com os ajustes dela por cima do padrão
		var p: Dictionary = comp_def(str(id)).get("param", {}).duplicate(true)
		p.merge(Universais.mecanica_de(str(a.id))[id], true)
		res[id] = p
	return res


func nivel_max(id: String) -> int:
	var d := Dados.item(id)
	return 1 + d.get("niveis", []).size()


func subir(id: String) -> void:
	var a = achar(id)
	if a:
		a.nivel = mini(a.nivel + 1, nivel_max(id))
	preaquecer()


func trocar(de: String, para: String) -> void:
	var a = achar(de)
	if a:
		a.id = para
		a.nivel = 1
		a.t = 0.1
		a.ativo = 0.0
	preaquecer()
	if arena:
		arena.build_mudou()  # a evolução tem etiquetas próprias


## Atributos da arma no nível atual (sem os bônus do jogador), já com a curva de crescimento de área e de dano.
func atributos(id: String, nivel: int) -> Dictionary:
	return Cresc.atributos(id, nivel)


func _s(a: Dictionary) -> Dictionary:
	## Atributos finais = arma x jogador.
	var s := atributos(a.id, a.nivel)
	s["tier"] = Cresc.tier(a.id, a.nivel)  # faixa visual 0-4: os módulos escolhem os enfeites por ela (crescimento.gd)
	s["dano"] = float(s.get("dano", 1)) * statf.call("dano")
	s["recarga"] = float(s.get("recarga", 1)) * statf.call("recarga")
	s["area"] = float(s.get("area", 1)) * statf.call("area")
	s["quantidade"] = int(s.get("quantidade", 1)) + int(statf.call("quantidade"))
	s["duracao"] = float(s.get("duracao", 1)) * statf.call("duracao")
	s["velocidade"] = float(s.get("velocidade", 200)) * statf.call("velocidade_proj")
	s["comp"] = _comp_de(a)
	var asc := int(a.get("asc", 0))  # #115: ascensão (degraus depois do nível máximo)
	if asc > 0:
		s["dano"] = float(s.dano) * Universais.fator_dano(asc)
		s["area"] = float(s.area) * Universais.fator_area(asc)
	return s


func atualizar(dt: float) -> void:
	var _pp := Perf.ini()
	atualizar_i(dt)
	Perf.fim("arm_a", _pp)


func atualizar_i(dt: float) -> void:
	_t += dt
	var jog: Node2D = dono
	var por_clique: bool = dono != null and "atacando" in dono  # só o jogador tem botão de ataque; o rival do duelo atira sozinho
	for a in ativas():
		var d := Dados.item(a.id)
		if por_clique and a.get("disparo", "auto") == "clique":
			if not dono.atacando and _espera_clique(a, d, dt):
				continue  # sem entrada de ataque: a arma só esfria e espera o clique
			d = _def_clique(a.id, d)
		var s := _s(a)
		match str(d.get("tipo", "")):
			"projetil":
				a.t -= dt
				if a.t <= 0:
					a.t = maxf(0.1, s.recarga)
					_atirar(a, d, s)
			"chicote":
				a.t -= dt
				if a.t <= 0:
					a.t = maxf(0.15, s.recarga)
					for i in s.quantidade:
						_fila.append({"t": i * 0.12, "arma": a, "lado": _lado_golpe(a) * (1 if i % 2 == 0 else -1)})
			"orbita":
				if a.ativo > 0:
					a.ativo -= dt
					_orbita(a, s)
					if a.ativo <= 0:
						a.t = s.recarga
				else:
					a.t -= dt
					if a.t <= 0:
						a.ativo = s.duracao
						a.acertos = {}
			"poca":
				a.t -= dt
				if a.t <= 0:
					a.t = maxf(0.3, s.recarga)
					_derramar(a, d, s)
			"aura":
				a.tique -= dt
				if a.tique <= 0:
					a.tique = maxf(0.15, float(s.get("tique", 0.5)))
					_aura(a, s)
					if s.comp.has("pulso"):
						a["pulsos"] = int(a.get("pulsos", 0)) + 1
						if a.pulsos % int(s.comp.pulso.get("cada", 3)) == 0:
							_pulso(a, s)
			var outro:
				if MODULOS.has(outro):
					var n0 := especiais.size()
					MODULOS[outro].atualizar(self, a, d, s, dt)
					for i in range(n0, especiais.size()):  # todo efeito novo sabe o tier e o tamanho (area) da arma que o criou
						especiais[i]["tier"] = s.tier
						especiais[i]["area"] = s.area
	for e in especiais.duplicate():
		var n1 := especiais.size()
		var vivo: bool = MODULOS[e.tipo].passo(self, e, dt)
		for i in range(n1, especiais.size()):  # efeito filho (lua da katana, estouro...) herda o tier e a área do pai
			var f: Dictionary = especiais[i]
			if not f.has("tier"):
				f["tier"] = e.get("tier", 0)
				f["area"] = e.get("area", 1.0)
		if not vivo:
			especiais.erase(e)
	_chicotes(dt)
	_projeteis(dt)
	_pocas(dt)
	for g in golpes.duplicate():
		g.t -= dt
		if g.t <= 0:
			golpes.erase(g)
	for r in aneis.duplicate():
		r.t -= dt
		if r.t <= 0.0:
			aneis.erase(r)
	queue_redraw()
	_chao_pocas.queue_redraw()
	_atras.queue_redraw()


## ---------- disparo por clique (#161) ----------

var _def_clique_cache: Dictionary = {}


## Arma de clique mira onde o jogador aponta (o cursor), seja qual for o tipo: vira "direcional" (ver `mirar`).
func _def_clique(id: String, d: Dictionary) -> Dictionary:
	if not _def_clique_cache.has(id):
		var c := d.duplicate()
		c["mira"] = "direcional"
		_def_clique_cache[id] = c
	return _def_clique_cache[id]


## Arma de clique sem o jogador atacando: só a recarga anda (nunca fura o cooldown) e devolve true (pula o quadro).
## Devolve false quando a arma ainda tem coisa pra fazer sozinha: a órbita já girando termina o giro.
func _espera_clique(a: Dictionary, d: Dictionary, dt: float) -> bool:
	if str(d.get("tipo", "")) == "orbita" and a.ativo > 0.0:
		return false
	a.t = maxf(0.0, a.t - dt)
	a.tique = maxf(0.0, float(a.get("tique", 0.0)) - dt)
	return true


## Para onde a arma de clique `a` golpeia: Vector2.ZERO se o jogador não está apontando (cai no mais perto, como antes) ou a arma é automática.
func dir_clique(origem: Vector2, alcance: float, a: Dictionary) -> Vector2:
	var m := entrada_mira()
	if m == Vector2.ZERO or a.get("disparo", "auto") != "clique":
		return Vector2.ZERO
	return _resolver(origem, m, alcance).dir


## Lado (1 ou -1) de um golpe horizontal (chicote): o do cursor se a arma é de clique e há mira; senão o lado em que o dono olha.
func _lado_golpe(a: Dictionary) -> float:
	var m := entrada_mira()
	if m != Vector2.ZERO and a.get("disparo", "auto") == "clique" and absf(m.x) > 0.05:
		return signf(m.x)
	return dono.lado


## ---------- mira direcional (#126) ----------


## "auto" (mira no mais perto) ou "direcional" (mira onde o jogador aponta). Vale o campo `mira` da arma em armas.json;
## sem ele, o padrão do tipo em dados/mira.json.
static func modo_mira(def: Dictionary) -> String:
	if def.has("mira"):
		return str(def.mira)
	return str(Dados.json("mira").get("tipos", {}).get(str(def.get("tipo", "")), "auto"))


## Função pura: pra onde a mira aponta. Sem inimigo dentro de `assist_rad` da linha apontada, a direção é a apontada mesma;
## com inimigo, gruda no mais alinhado. Devolve {dir, alvo}: `alvo` é a posição do inimigo grudado ou null.
static func resolver_mira(origem: Vector2, mira: Vector2, pontos: Array, assist_rad: float) -> Dictionary:
	var dir := mira.normalized() if mira != Vector2.ZERO else Vector2.RIGHT
	var melhor = null
	var md := assist_rad + 0.0001
	var base := dir.angle()
	for p in pontos:
		var dif: Vector2 = p - origem
		if dif.length_squared() < 4.0:
			continue
		var d := absf(angle_difference(base, dif.angle()))
		if d <= md:
			md = d
			melhor = p
	if melhor == null:
		return {"dir": dir, "alvo": null}
	return {"dir": (melhor - origem).normalized(), "alvo": melhor}


## A mira do dono neste quadro (ZERO = sem entrada de mira, ou o dono não mira: rival do duelo).
func entrada_mira() -> Vector2:
	if dono == null:
		return Vector2.ZERO
	var m = dono.get("mira_dir")
	return m if m is Vector2 else Vector2.ZERO


## `n` direções de tiro da arma `def` saindo de `origem`, se ela é direcional E o jogador está mirando; senão [] (use o
## mais perto, como antes). Os n tiros abrem em leque pequeno em volta da direção resolvida.
func mirar(origem: Vector2, n: int, alcance: float, def: Dictionary) -> Array:
	var m := entrada_mira()
	if m == Vector2.ZERO or modo_mira(def) != "direcional":
		return []
	var r := _resolver(origem, m, alcance)
	var esp := float(Dados.json("mira").get("espalhamento", 0.14))
	var dirs := []
	for i in n:
		dirs.append(r.dir.rotated((i - (n - 1) / 2.0) * esp))
	return dirs


## Igual a `mirar`, mas devolve {dir, alvo} da mira (alvo = posição do inimigo grudado ou null); {} se não é direcional/sem mira.
func mirar_alvo(origem: Vector2, alcance: float, def: Dictionary) -> Dictionary:
	var m := entrada_mira()
	if m == Vector2.ZERO or modo_mira(def) != "direcional":
		return {}
	return _resolver(origem, m, alcance)


func _resolver(origem: Vector2, m: Vector2, alcance: float) -> Dictionary:
	var graus := float(Dados.json("mira").get("assistencia_graus", 20.0)) if Config.v("mira_assistida") else 0.0
	var pontos := []
	if graus > 0.0:
		for v in campo.no_circulo(origem, alcance):
			pontos.append(v.pos)
	return resolver_mira(origem, m, pontos, deg_to_rad(graus))


## O jogador rolou: auras com "Aura Pulsante" soltam um pulso na hora (com uma pausa pra não virar spam).
func ao_rolar() -> void:
	for a in ativas():
		var s := _s(a)
		if s.comp.has("pulso") and _t >= float(a.get("pulso_ate", 0.0)):
			a["pulso_ate"] = _t + float(s.comp.pulso.get("recarga_rolar", 1.2))
			_pulso(a, s)


func _pulso(a: Dictionary, s: Dictionary) -> void:
	var p: Dictionary = s.comp.pulso
	var jog: Node2D = dono
	var r: float = float(s.get("raio", 50)) * s.area * float(p.get("area_mult", 1.8))
	var d := Dados.item(a.id)
	for v in campo.no_circulo(jog.centro(), r):
		campo.ferir(v, s.dano * float(p.get("dano_mult", 1.6)), (v.pos - jog.centro()).normalized() * float(s.get("empurra", 40)) * 2.0, a.id)
	aneis.append({"pos": jog.centro(), "r": r, "t": 0.35, "total": 0.35, "cor": cor_de(d, Color(0.5, 1.0, 0.6))})
	Som.tocar("queda", 0.2, 1.1, -12)


## Ponto comum dos golpes corpo a corpo (chicote, katana, marcial): avisa o dono pra animar o ataque na direção do golpe.
func golpe_corpo(dir := Vector2.ZERO) -> void:
	if dono and dono.has_method("atacou"):
		dono.atacou(dir)


## Os efeitos de golpe (meia-lua, impacto, faíscas) ficam no efeitos.gd da arena. O rival do duelo não tem `arena`,
## mas é filho do duelo, que tem. null = sem efeitos (os módulos continuam funcionando só com o `campo`).
func fx() -> Node2D:
	if arena and arena.efeitos:
		return arena.efeitos
	var p := get_parent()
	if p and "arena" in p and p.arena and p.arena.efeitos:
		return p.arena.efeitos
	return null


## Golpe corpo a corpo do herói que acertou alguém: tremidinha e congelada curtinha (o arena limita a frequência).
func golpe_acertou(forca := 1.0) -> void:
	if arena and dono == arena.jogador and arena.has_method("golpe_pesado"):
		arena.golpe_pesado(forca)


# ---------- projétil ----------


func _atirar(a: Dictionary, d: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = dono
	var origem: Vector2 = jog.centro()
	var mira := mirar(origem, s.quantidade, 380.0, d)  # direcional (#126): vazio = sem entrada de mira, vale o mais perto
	var alvos: Array = [] if not mira.is_empty() else campo.n_mais_perto(origem, s.quantidade, 380)
	for i in s.quantidade:
		var dir: Vector2
		if not mira.is_empty():
			dir = mira[i]
		elif alvos.is_empty():
			dir = Vector2(jog.lado, 0).rotated(randf_range(-0.3, 0.3))
		else:
			var alvo = alvos[i % alvos.size()]
			dir = (alvo.pos - origem).normalized()
			if i >= alvos.size():
				dir = dir.rotated(randf_range(-0.25, 0.25))
		var proj := {
			"pos": origem,
			"vel": dir * s.velocidade,
			"dano": s.dano,
			"perfura": int(s.get("perfura", 1)),
			"vida": s.duracao,
			"tex": Dados.tex(str(d.get("sprite", "proj_pendrive"))),
			"esc": s.area,
			"acertou": [],
			"arma": a.id,
			"tier": s.tier,
			"cor": Cresc.cor_arma(d)
		}
		if s.comp.has("ricochete"):  # pula pra outro vírus perto ao acertar
			proj["ric"] = int(s.comp.ricochete.get("ricochetes", 2))
			proj["ric_alc"] = float(s.comp.ricochete.get("alcance", 170.0))
			proj["ric_mult"] = float(s.comp.ricochete.get("dano_mult", 0.85))
		if s.comp.has("vai_e_volta"):  # vai até metade da vida, volta pro dono acertando de novo
			proj["volta_em"] = s.duracao * 0.5
			proj["perfura"] += int(s.comp.vai_e_volta.get("perfura_extra", 1))
			proj["volta_mult"] = float(s.comp.vai_e_volta.get("dano_volta", 0.7))
		projeteis.append(proj)
	Som.tocar("cursor", 0.08, 1.4, -10)


func _projeteis(dt: float) -> void:
	for p in projeteis.duplicate():
		if p.has("volta_em"):
			if not p.get("voltou", false) and p.vida <= p.volta_em:  # chegou no fim da ida: vira e volta
				p["voltou"] = true
				p.acertou = []
				p.dano *= p.volta_mult
				p.perfura = maxi(int(p.perfura), 2)
				p.vida = maxf(p.vida, 0.8)
			if p.get("voltou", false):  # na volta, mira no dono (some ao chegar)
				var alvo: Vector2 = dono.centro()
				p.vel = (alvo - p.pos).normalized() * p.vel.length()
				if p.pos.distance_to(alvo) < 14.0:
					projeteis.erase(p)
					continue
		p.pos += p.vel * dt
		p.vida -= dt
		if p.vida <= 0:
			projeteis.erase(p)
			continue
		for v in campo.no_circulo(p.pos, 6.0 * p.esc):
			if v.id in p.acertou:
				continue
			p.acertou.append(v.id)
			campo.ferir(v, p.dano, p.vel.normalized() * 60.0, p.arma)
			Cresc.fagulhas(self, p.pos, p.vel.normalized(), p.cor, p.tier, 150.0)
			p.perfura -= 1
			if p.perfura <= 0:
				if int(p.get("ric", 0)) > 0 and _ricochetear(p):
					break
				projeteis.erase(p)
				break


## Ricochete: redireciona o tiro pro vírus mais perto que ele ainda não acertou. false = não tem pra onde pular.
func _ricochetear(p: Dictionary) -> bool:
	for v in campo.n_mais_perto(p.pos, 4, float(p.ric_alc)):
		if v.id in p.acertou:
			continue
		p.ric -= 1
		p.vel = (v.pos - p.pos).normalized() * p.vel.length()
		p.perfura = 1
		p.dano *= float(p.get("ric_mult", 0.85))
		p.vida = maxf(p.vida, 0.6)
		return true
	return false


# ---------- chicote ----------


func _chicotes(dt: float) -> void:
	for f in _fila.duplicate():
		f.t -= dt
		if f.t > 0:
			continue
		_fila.erase(f)
		if not f.arma in lista:
			continue
		var a: Dictionary = f.arma
		var s := _s(a)
		var jog: Node2D = dono
		var alcance: float = float(s.get("alcance", 100)) * s.area
		var larg: float = float(s.get("largura", 30)) * s.area
		var c: Vector2 = jog.centro() + Vector2(f.lado * (alcance / 2 + 6), 0)
		var curou := 0
		var n := 0
		for v in campo.no_circulo(c, alcance / 2):
			if absf(v.pos.y - c.y) <= larg / 2 + v.raio:
				campo.ferir(v, s.dano, Vector2(f.lado * 120, 0), a.id)
				n += 1
				if s.has("rouba_vida") and curou < 5:
					jog.curar(float(s.rouba_vida))
					curou += 1
		if s.comp.has("rastro_fogo"):
			_rastro_fogo(a, s, jog.centro(), f.lado, alcance)
		golpe_corpo(Vector2(f.lado, 0))
		var ef := fx()
		var tier: int = s.tier
		var dg := Dados.item(str(a.id))
		var cor_g := cor_de(dg, Color(0.95, 0.8, 0.25))
		if ef:  # a chicotada vira uma meia-lua baixa e larga, da cor do chicote (mais grossa, brilhante e com 2º arco a cada tier)
			ef.corte(
				jog.centro() + Vector2(f.lado * 6, 4),
				0.0 if f.lado > 0 else PI,
				1.7,
				alcance * 0.62,
				Cresc.cor(cor_g, tier),
				larg * 0.7 * Cresc.grossura(tier),
				0.16,
				-f.lado
			)
			if Cresc.fx(tier).arco_extra and Cresc.fator() >= 0.5:
				ef.corte(jog.centro() + Vector2(f.lado * 6, 4), 0.0 if f.lado > 0 else PI, 1.4, alcance * 0.8, Cresc.cor(cor_g, tier), larg * 0.4, 0.2, -f.lado)
			Cresc.fagulhas(self, jog.centro() + Vector2(f.lado * alcance * 0.8, 0), Vector2(f.lado, 0), cor_g, tier)
		if n > 0:
			Cresc.acerto(self, 0.6, tier)
		golpes.append({"pos": jog.centro(), "lado": f.lado, "alcance": alcance, "largura": larg, "t": 0.16, "arma": a.id, "tier": tier})
		Som.tocar("whoosh", 0.05, 1.6, -8)


## Rastro de fogo: duas poças pequenas ao longo do golpe (limite de poças de rastro por arma, as mais velhas somem).
func _rastro_fogo(a: Dictionary, s: Dictionary, origem: Vector2, lado: int, alcance: float) -> void:
	var p: Dictionary = s.comp.rastro_fogo
	var dur := float(p.get("duracao", 2.5))
	for f in [0.5, 0.9]:
		pocas.append(
			{
				"pos": origem + Vector2(lado * alcance * f, 0),
				"raio": float(p.get("raio", 24)) * s.area,
				"vida": dur,
				"total": dur,
				"dano": s.dano * float(p.get("dano_pct", 0.3)),
				"tique": float(p.get("tique", 0.5)),
				"t": 0.0,
				"segue": false,
				"arma": a.id,
				"variante": randi() % 3,
				"semente": randf() * 10.0,
				"rampa": p.get("rampa", Poca.CAFE),
				"rastro": true,
				"elem": str(p.get("elem", ""))
			}
		)
	var n := 0
	for q in pocas:
		if q.get("rastro", false):
			n += 1
	var lim := int(p.get("max", 10))
	while n > lim:
		for q in pocas:
			if q.get("rastro", false):
				pocas.erase(q)
				n -= 1
				break


# ---------- órbita ----------


## Raio da órbita; "Giro em Espiral" faz ele respirar (abre e fecha).
func _raio_orbita(s: Dictionary) -> float:
	var r: float = float(s.get("raio", 60)) * s.area
	if s.comp.has("respiracao"):
		var p: Dictionary = s.comp.respiracao
		r *= 1.0 + float(p.get("amplitude", 0.45)) * sin(_t * float(p.get("freq", 2.2)))
	return r


func _orbita(a: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = dono
	var r: float = _raio_orbita(s)
	for i in s.quantidade:
		var p: Vector2 = jog.centro() + Vector2.from_angle(_t * float(s.get("giro", 3)) + TAU * i / s.quantidade) * r
		for v in campo.no_circulo(p, 9.0 * s.area):
			var prox: float = a.acertos.get(v.id, 0.0)
			if _t >= prox:
				a.acertos[v.id] = _t + 0.5
				campo.ferir(v, s.dano, (v.pos - jog.centro()).normalized() * 90.0, a.id)
	if a.acertos.size() > 600:
		a.acertos = {}


# ---------- poça ----------


func _derramar(a: Dictionary, d: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = dono
	var para := dir_clique(jog.centro(), 160.0, a)  # arma de clique (#161): a poça cai no rumo do cursor
	for i in s.quantidade:
		var alvo = campo.aleatorio_na_tela(jog.centro())
		var p: Vector2 = alvo.pos if alvo else jog.centro() + Vector2.from_angle(randf() * TAU) * randf_range(40, 140)
		if para != Vector2.ZERO:
			p = jog.centro() + para.rotated(randf_range(-0.35, 0.35)) * randf_range(50.0, 130.0)
		pocas.append(
			{
				"pos": p,
				"raio": float(s.get("raio", 40)) * s.area,
				"vida": s.duracao,
				"total": s.duracao,
				"dano": s.dano,
				"tique": float(s.get("tique", 0.4)),
				"t": 0.0,
				"segue": bool(d.get("base", {}).get("segue", false)),
				"arma": a.id,
				"variante": randi() % 3,
				"semente": randf() * 10.0,
				"rampa": rampa_de(d),
				"explode": s.comp.get("explosao_final", {}),
				"gelo": str(d.get("elemento", "")) == "gelo",
				"tier": s.tier
			}
		)
	Som.tocar("queda", 0.2, 1.5, -10)


func _pocas(dt: float) -> void:
	for p in pocas.duplicate():
		p.vida -= dt
		p.t -= dt
		if p.segue:
			p.pos = p.pos.move_toward(dono.centro(), 40.0 * dt)
		if p.t <= 0:
			p.t = p.tique
			var el: String = p.get("elem", "")  # poça com elemento (rastro de fogo, #72): cada tique soma acúmulos
			for v in campo.no_circulo(p.pos, p.raio * 0.85):
				campo.ferir(v, p.dano, Vector2.ZERO, p.arma)
				if el != "" and campo.has_method("aplicar_elemento") and v.hp > 0.0:
					campo.aplicar_elemento(v, el, 1.0, p.arma)
		if p.vida <= 0:
			pocas.erase(p)
			if not p.get("explode", {}).is_empty():  # "Poça Instável": explode ao sumir
				var ex: Dictionary = p.explode
				var re: float = p.raio * float(ex.get("raio_mult", 1.5))
				for v in campo.no_circulo(p.pos, re):
					campo.ferir(v, p.dano * float(ex.get("dano_mult", 4.0)), (v.pos - p.pos).normalized() * 80.0, p.arma)
				aneis.append({"pos": p.pos, "r": re, "t": 0.3, "total": 0.3, "cor": Color(1.0, 0.6, 0.2)})
				Som.tocar("queda", 0.1, 0.8, -10)


# ---------- aura ----------


func _aura(a: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = dono
	var r: float = float(s.get("raio", 50)) * s.area
	for v in campo.no_circulo(jog.centro(), r):
		if s.has("lentidao"):
			v.lento = 0.8
		campo.ferir(v, s.dano, (v.pos - jog.centro()).normalized() * float(s.get("empurra", 40)), a.id)


# ---------- desenho ----------


func _draw() -> void:
	var _pp := Perf.ini()
	_draw_i()
	Perf.fim("arm_d", _pp)


func _draw_i() -> void:
	var jog: Node2D = dono
	for a in ativas():
		var d := Dados.item(a.id)
		var tipo := str(d.get("tipo", ""))
		if MODULOS.has(tipo):
			MODULOS[tipo].fundo(self, a, _s(a))
		elif tipo == "aura":
			var s := _s(a)
			var r: float = float(s.get("raio", 50)) * s.area
			var pulso := 0.5 + 0.5 * sin(_t * 4.0)
			var cor := cor_de(d, Color(0.5, 1.0, 0.6))
			var tier_a: int = s.tier
			draw_circle(jog.centro(), r, Color(cor, 0.08 + 0.04 * pulso + 0.02 * tier_a))
			Legib.marca_aliada(self, jog.centro(), r, 1.0, false, 0.0, false)  # borda do alcance da aura
			for k in 3:
				var rr := fmod(_t * 40.0 + k * r / 3.0, r)
				draw_arc(jog.centro(), rr, 0, TAU, 32, Color(Cresc.cor(cor, tier_a), 0.35 * (1.0 - rr / r)), 1.5 * Cresc.grossura(tier_a))
			Cresc.halo(self, jog.centro(), r, cor, tier_a)  # tiers altos: brilho, brasas subindo e um anel por fora
			Cresc.brasas(self, jog.centro(), r, cor, tier_a, _t)
			Cresc.anel(self, jog.centro(), r, cor, tier_a, 1.0, 0.8)
		elif tipo == "orbita" and a.ativo > 0:
			var s := _s(a)
			var tex := Dados.tex(str(d.get("sprite", "proj_ventoinha")))
			var r: float = _raio_orbita(s)
			var sz: Vector2 = tex.get_size() * ESCALA * s.area * 0.8
			var tier_o: int = s.tier
			var giro_o := float(s.get("giro", 3))
			for i in s.quantidade:
				var ang_o: float = _t * giro_o + TAU * i / s.quantidade
				var p: Vector2 = jog.centro() + Vector2.from_angle(ang_o) * r
				# cópias fantasma ficam para trás na órbita (menos ângulo) e a luz acompanha a lâmina
				for k in range(int(round(float(Cresc.fx(tier_o).imagens) * Cresc.fator())), 0, -1):
					draw_set_transform(jog.centro() + Vector2.from_angle(ang_o - 0.16 * k) * r, _t * 12.0, Vector2.ONE)
					draw_texture_rect(tex, Rect2(-sz / 2, sz), false, Color(1, 1, 1, 0.32 / k))
				draw_set_transform(p, _t * 12.0, Vector2.ONE)
				draw_texture_rect(tex, Rect2(-sz / 2, sz), false)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				Cresc.halo(self, p, 16.0 * s.area, Cresc.cor_arma(d), tier_o)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			Cresc.brasas(self, jog.centro(), r, Cresc.cor_arma(d), tier_o, _t)
	for g in golpes:
		var alfa: float = g.t / 0.16
		var x0: float = g.pos.x + g.lado * 8
		var pts := PackedVector2Array()
		for i in 13:
			var f := i / 12.0
			pts.append(Vector2(x0 + g.lado * g.alcance * f, g.pos.y + sin(f * 9.0 + _t * 30.0) * g.largura * 0.25 * (1.0 - absf(f - 0.5))))
		var dg := Dados.item(str(g.arma))
		var tg: int = g.get("tier", 0)
		var fios: Array = dg.get("fios", [])  # evolução: várias linhas coloridas lado a lado (armas.json)
		if not fios.is_empty():
			for k in fios.size():
				var desl := PackedVector2Array()
				for p in pts:
					desl.append(p + Vector2(0, (k - (fios.size() - 1) / 2.0) * 3))
				draw_polyline(desl, Color(Cresc.cor(cor_de({"cor": fios[k]}, Color.WHITE), tg), alfa), 2.0 * Cresc.grossura(tg))
		else:
			draw_polyline(pts, Color(Cresc.cor(cor_de(dg, Color(0.95, 0.8, 0.25)), tg), alfa), 3.0 * Cresc.grossura(tg))
			draw_polyline(pts, Color(1, 1, 0.8, alfa), 1.0 + 0.5 * floorf(tg / 2.0))
		draw_rect(Rect2(Vector2(minf(x0, x0 + g.lado * g.alcance), g.pos.y - g.largura / 2), Vector2(g.alcance, g.largura)), Color(1, 1, 0.7, alfa * 0.12))
	for r in aneis:
		var u: float = 1.0 - r.t / r.total
		draw_arc(r.pos, r.r * (0.4 + 0.6 * u), 0, TAU, 40, Color(r.cor, 0.8 * (1.0 - u)), 3.0)
		draw_circle(r.pos, r.r * (0.4 + 0.6 * u), Color(r.cor, 0.12 * (1.0 - u)))
	for p in projeteis:
		var tex: Texture2D = p.tex
		var sz: Vector2 = tex.get_size() * ESCALA * p.esc
		var tp: int = p.get("tier", 0)
		if tp >= 2:  # tiers altos: imagens fantasma atrás e luz acompanhando
			Cresc.fantasmas(self, tex, p.pos, p.vel.angle(), sz, p.vel.normalized() * maxf(5.0, sz.x * 0.45), tp)
			Cresc.halo(self, p.pos, 14.0 * p.esc, p.cor, tp)
		draw_set_transform(p.pos, p.vel.angle(), Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz / 2, sz), false)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for e in especiais:
		MODULOS[e.tipo].pintar(self, e)
		var te: int = e.get("tier", 0)
		if te >= 2 and e.has("pos"):  # luz sob o efeito + anel/brasas no tier alto (módulos podem desenhar mais por conta própria)
			var rr: float = Cresc.raio_efeito(e)
			if rr > 0.0:
				Cresc.halo(self, e.pos, rr, e.get("cor_fx", Cresc.cor_arma(Dados.item(str(e.get("arma", ""))))), te)


## Cor [r, g, b] de uma arma no armas.json ("cor"), ou o padrão (#65: as cores dos efeitos moram nos dados).
static func cor_de(d: Dictionary, padrao: Color) -> Color:
	var c = d.get("cor")
	return Color(float(c[0]), float(c[1]), float(c[2])) if c is Array and c.size() >= 3 else padrao


## Rampa de tons da poça de uma arma ("rampa" no armas.json, do escuro ao reflexo); sem ela, a do café.
static func rampa_de(d: Dictionary) -> Array:
	var r = d.get("rampa")
	return r if r is Array and r.size() >= 6 else Poca.CAFE


## Gera antes as texturas das poças (o pior tamanho leva ~30 ms): chamado ao pegar/subir arma e passivo,
## quando a tela de cartas está aberta e o jogo parado, pra não dar engasgo no meio da horda.
func preaquecer() -> void:
	if not statf.is_valid():
		return
	for a in lista:
		var d := Dados.item(a.id)
		if str(d.get("tipo", "")) == "poca":
			var s := _s(a)
			for v in 3:
				Poca.textura(float(s.get("raio", 40)) * s.area, v, rampa_de(d))
		elif _comp_de(a).has("rastro_fogo"):  # poças de fogo do rastro (#63)
			var s := _s(a)
			var p: Dictionary = s.comp.rastro_fogo
			for v in 3:
				Poca.textura(float(p.get("raio", 24)) * s.area, v, p.get("rampa", Poca.CAFE))


func _ready() -> void:
	_chao_pocas.z_index = -5
	_chao_pocas.draw.connect(
		func():
			for p in pocas:
				_desenhar_poca(_chao_pocas, p)
	)
	add_child(_chao_pocas)
	_atras.z_index = -1
	_atras.draw.connect(
		func():
			for a in ativas():
				var tipo := str(Dados.item(a.id).get("tipo", ""))
				if MODULOS.has(tipo):
					MODULOS[tipo].atras(self, _atras, a, _s(a))
	)
	add_child(_atras)


## Poça em pixel art (poca.gd) + bolhas que estouram e vapor subindo, tudo alinhado ao pixel.
func _desenhar_poca(ci: CanvasItem, p: Dictionary) -> void:
	var alfa: float = clampf(p.vida / 0.4, 0.0, 1.0)
	var cresce: float = clampf((p.total - p.vida) / 0.15, 0.3, 1.0)
	var r: float = p.raio * cresce
	var var_: int = p.get("variante", 0)
	var s: float = p.get("semente", 0.0)
	# só a textura do tamanho final; os 0,15 s em que ela "cai" e cresce são uma escala rápida dela
	var rampa: Array = p.get("rampa", Poca.CAFE)
	var tex := Poca.textura(p.raio, var_, rampa)
	var tam_poca: Vector2 = tex.get_size() * cresce
	ci.draw_texture_rect(tex, Rect2((p.pos - tam_poca / 2.0).floor(), tam_poca.floor()), false, Color(1, 1, 1, alfa))
	# borda da área que machuca (raio real do golpe = 85% do raio) e, na "Poça Instável", o alcance da explosão que vem
	Legib.marca_aliada(ci, p.pos, p.raio * 0.85 * cresce, alfa)
	if not p.get("explode", {}).is_empty() and p.vida < 0.8:
		Legib.marca_aliada(ci, p.pos, p.raio * float(p.explode.get("raio_mult", 1.5)), 1.0 - p.vida / 0.8, true, _t)
	var tp: int = p.get("tier", 0)
	if tp >= 2:  # tiers altos: brasas subindo da poça, luz e um anel por fora (a poça nasce menor e cresce de nível em nível)
		var cp: Color = Color(rampa[5]).lerp(Color(1, 1, 1), 0.2)
		Cresc.brasas(ci, p.pos, r * 0.8, cp, tp, _t, s, alfa)
		Cresc.anel(ci, p.pos, r * 0.85, cp, tp, alfa, Poca.ACHATA)
		if ci == _chao_pocas:
			Cresc.halo(self, p.pos, r, cp, tp)
	if p.get("gelo", false):  # poça de gelo (#72): rachaduras claras saindo do centro e cristais no lugar do vapor
		var cr := Color(rampa[5], alfa * 0.75)
		for i in 5:
			var ang := i * 1.25 + s
			var d0 := Vector2(cos(ang), sin(ang) * Poca.ACHATA)
			var m0: Vector2 = p.pos + d0 * r * 0.15
			var m1: Vector2 = p.pos + d0 * r * (0.55 + 0.25 * fmod(s * 3.0 + i * 0.37, 1.0))
			ci.draw_line(m0.floor(), m1.floor(), cr, 1.0)
			ci.draw_line(m1.floor(), (m1 + Vector2(d0.y, -d0.x) * r * 0.18).floor(), Color(cr, cr.a * 0.7), 1.0)
		for i in 2:
			if int(_t * 4.0 + i * 3 + s * 7.0) % 4 == 0:
				var pc: Vector2 = (p.pos + Vector2(cos(s * 5.0 + i * 2.1) * r * 0.5, sin(s * 5.0 + i * 2.1) * r * 0.5 * Poca.ACHATA)).floor()
				ci.draw_rect(Rect2(pc.x - 1, pc.y, 3, 1), Color(1, 1, 1, alfa))
				ci.draw_rect(Rect2(pc.x, pc.y - 1, 1, 3), Color(1, 1, 1, alfa))
		return
	var bolha := Color(rampa[4])
	var vapor := Color(rampa[5]).lerp(Color.WHITE, 0.5)  # café: vapor branco; fogo: fagulha clara
	for i in 3:
		var fase := fmod(_t * 0.9 + i * 0.37 + s, 1.0)
		if fase > 0.8:
			continue  # estourou
		var a := i * 2.3 + s
		var pb: Vector2 = (p.pos + Vector2(cos(a) * r * 0.45, sin(a) * r * 0.45 * Poca.ACHATA)).floor()
		var tam := 1.0 if fase < 0.45 else 2.0
		ci.draw_rect(Rect2(pb, Vector2(tam, tam)), Color(bolha, alfa * 0.9))
		ci.draw_rect(Rect2(pb, Vector2.ONE), Color(1, 0.95, 0.85, alfa * 0.8))  # brilho da bolha
	var fios := 4 if p.segue else 2  # garrafa térmica: café mais quente, mais vapor
	for i in fios:
		var fv := fmod(_t * 0.55 + i * 0.5 / fios * 2.0 + s, 1.0)
		var pv: Vector2 = (p.pos + Vector2((i - (fios - 1) / 2.0) * r * 0.35 + sin(fv * 7.0 + i) * 2.0, -r * 0.2 - fv * 26.0)).floor()
		ci.draw_rect(Rect2(pv, Vector2(1, 2)), Color(vapor, alfa * 0.35 * (1.0 - fv)))
