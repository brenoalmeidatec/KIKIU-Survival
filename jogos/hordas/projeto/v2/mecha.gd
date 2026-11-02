extends RefCounted
## As duas formas do LightWolf (LW-2, #511): o MECHA (a forma padrão, tanque de tiro) e o LOBO (o piloto, frágil e letal). Este módulo só age em eventos:
##  - QUEBRA (`quebrou`, chamado por `Heroi.levar_dano` quando a vida zera): em vez de morrer, o mecha estoura (onda, estouro, empurrão nos vizinhos) e o herói
##    vira o Lobo, com 31% da vida máxima do mecha (cheia), invencível por um instante. O Q do mecha fica guardado e a carga do Q passa a ser o CHAMADO.
##  - CHAMADO (o Q do Lobo, `chamar` em v2/especial.gd): com a carga cheia o Lobo aperta Q, o mecha cai (aviso de 0,8 s, dano de queda) e `chegar` o devolve
##    à forma mecha com a vida cheia e o Q de antes. A carga do chamado enche por dano, abates e (para nunca travar sem monstro) por tempo (`atualizar`).
##  - AUTODESTRUIÇÃO (o Q do mecha, `autodestruir`, chamada por v2/especial.gd, LW-5): o piloto salta e vira Lobo NA HORA, sem o estouro da quebra (o fusível e a explosão são do Q),
##    com o chamado já em `inicio_autodestruicao` (35) e o Q do mecha gasto (volta a 0 quando o mecha cai). Depois dela o Lobo chama o mecha de volta como depois de uma quebra.
##  - Só a morte do Lobo é derrota: ela cai no `heroi_morreu` de sempre (tela de resultado e olho). Recomeçar a partida volta ao mecha (`reiniciar`).
## A troca NUNCA chama `iniciar_stats` (zeraria Q e E): `Heroi.trocar_forma` mexe só na chave, na folha, no corpo e na defesa, e `combate.cfg` passa a ser o do
## herói-forma (dados/v2_herois.json > lightwolf_lobo, com `forma_de`). O herói da partida (`combate.heroi_id`) segue "lightwolf": cartas, bônus e resultado
## não enxergam a troca. A segunda folha é carregada uma vez (`precarregar`), então trocar no meio da luta não decodifica nada.
## Números: dados/v2_herois.json (lightwolf > forma_lobo; lightwolf_lobo > vida_pct, invencivel, quebra) e dados/v2_especial.json > chamar (carga, queda).
##
## API: montar(c), tem(), precarregar(), quebrou(h) -> bool, autodestruir(h) -> bool, virar_lobo(h, chamado, quebra), chegar(h), reiniciar(h), atualizar(dt).

const Herois := preload("res://v2/herois.gd")
const LoboEspectral := preload("res://v2/lobo_espectral.gd")
const COR := Color(0.75, 0.95, 1.0)
const COR_CASCO := Color(0.55, 0.78, 1.0)

var combate
var mundo
var lobo_id := ""  # o id da forma Lobo no catálogo ("" = o herói da partida não tem formas)
var cfg_lobo: Dictionary = {}  # o registro do Lobo (vida_pct, invencivel, quebra)
var carga_mecha := 0.0  # o Q do mecha, guardado enquanto o herói é Lobo
var recarga_mecha := 0.0  # a recarga da E do mecha, guardada junto (a troca não zera nem enche a E)
var quebras := 0  # testes e calibragem: quantas vezes o mecha quebrou na partida
var autodestruicoes := 0  # quantas vezes o piloto saltou e o mecha explodiu (o Q do mecha, LW-5)
var chamados := 0  # quantas vezes o mecha foi chamado de volta
var tempo_lobo := 0.0  # s de Lobo na partida (calibragem: 8 a 18 s por quebra)


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	lobo_id = str(Herois.heroi(c.heroi_id).get("forma_lobo", ""))
	cfg_lobo = Herois.heroi(lobo_id) if lobo_id != "" else {}


## O herói desta partida tem as duas formas?
func tem() -> bool:
	return lobo_id != ""


## Carrega a folha do Lobo na partida (uma vez, no nascimento do herói): trocar no meio da luta não decodifica imagem nem borra a silhueta.
func precarregar() -> void:
	if tem():
		mundo.sprites.tipo(Herois.sprite(lobo_id))
		_garantir_espectral(mundo.heroi)


## O visual espectral do Lobo (v2/lobo_espectral.gd) nasce UMA vez por herói e é reaproveitado em toda troca (nenhum nó novo no meio da luta).
func _garantir_espectral(h) -> void:
	if h.espectral == null:
		h.espectral = LoboEspectral.new()
		h.espectral.montar(h, lobo_id)


func _bloco() -> Dictionary:
	return combate.especial.blocos.get("chamar", {})


## A vida do mecha zerou (Heroi.levar_dano): devolve true se ele quebrou e o herói segue vivo como Lobo. O Lobo não quebra: a morte dele é a derrota.
func quebrou(h) -> bool:
	if not tem() or h.forma_lobo or combate.jogo != "jogando":
		return false
	quebras += 1
	virar_lobo(h, float(_bloco().get("inicio_quebra", 20.0)))
	return true


## O Q do mecha (LW-5): o piloto salta e vira Lobo na hora, com o chamado em `inicio_autodestruicao`. Sem o estouro da quebra e sem tirar o herói do Estado.ESPECIAL
## (o fusível de 1 s e a explosão são do próprio Q, v2/especial.gd). O Q do mecha já foi gasto pelo disparo: `carga_mecha` guarda 0. false se o herói não tem formas ou já é Lobo.
func autodestruir(h) -> bool:
	if not tem() or h.forma_lobo or combate.jogo != "jogando":
		return false
	autodestruicoes += 1
	virar_lobo(h, float(_bloco().get("inicio_autodestruicao", 35.0)), false)
	return true


## Mecha -> Lobo. `chamado`: a carga do chamado com que o Lobo começa (a quebra dá 20; a Autodestruição do LW-5 dá 35, ULT-D). `quebra` = false (a Autodestruição): sem o estouro,
## o anúncio e o empurrão da quebra, e o estado do herói não muda (o Q segue em Estado.ESPECIAL).
func virar_lobo(h, chamado: float, quebra := true) -> void:
	var c = combate
	carga_mecha = h.esp_carga
	recarga_mecha = h.hab_recarga
	h.entrar_lobo(float(cfg_lobo.get("vida_pct", 0.31)))
	c.cfg = Herois.cfg_para(Dados.json("v2_combate"), lobo_id)
	h.trocar_forma(lobo_id, mundo.sprites.tipo(Herois.sprite(lobo_id)))
	_garantir_espectral(h)
	h.espectral.ligar()
	h.espectral.clarao(true)  # o mecha quebra e a verdadeira forma aparece num clarão (lore do Isac, #511)
	h.esp_carga = minf(chamado, h.esp_carga_max)
	h.invenc = maxf(h.invenc, float(cfg_lobo.get("invencivel", 1.5)))
	if quebra:
		h.estado = h.Estado.LIVRE
	h.combo_t = 0.0
	h.proximo = 0
	tempo_lobo = 0.0
	if not quebra:
		return
	# o mecha estoura: onda, estouro de cascos azuis, luz local e um empurrão nos vizinhos (sem dano, sem flash por monstro)
	var q: Dictionary = cfg_lobo.get("quebra", {})
	var raio := float(q.get("raio", 70.0))
	var centro: Vector2 = h.pos + Vector2(0, -16)
	c.fx.onda(centro, Color(COR.r, COR.g, COR.b, 0.9), raio, 0.4)
	c.fx.onda(centro, Color(1, 1, 1, 0.6), raio * 0.55, 0.25)
	c.fx.estouro(centro, COR_CASCO, 22)
	c.fx.luz_rapida(centro, COR, 2.0, raio * 2.0, 0.4)
	c.audio.tocar("ruptura_disparo", 0.6, 0.0, 0.0)
	c.audio.tocar("impacto", 0.5, 2.0, 0.0)
	mundo.cam.tremer(float(q.get("tremor", 3.0)), 0.3)
	var emp := float(q.get("empurrao", 260.0))
	for m in mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var rel: Vector2 = m.pos - h.pos
		if rel.length() > raio + float(m.raio):
			continue
		m.emp = (rel.normalized() if rel.length() > 0.5 else Vector2.from_angle(m.ang_cerco)) * emp
	c.anunciar("MECHA QUEBRADO", COR)


## O mecha cai (fim do aviso do CHAMAR, em v2/especial.gd): Lobo -> Mecha com a vida cheia e o Q que o mecha tinha.
func chegar(h) -> void:
	if not h.forma_lobo:
		return
	var c = combate
	chamados += 1
	h.sair_lobo()
	c.cfg = Herois.cfg_para(Dados.json("v2_combate"), c.heroi_id)
	h.trocar_forma(c.heroi_id, mundo.sprites.tipo(_folha_mecha()))
	if h.espectral != null:
		h.espectral.desligar()
		h.espectral.clarao(false)  # o mecha cai: clarão mais fraco
	h.esp_carga = minf(carga_mecha, h.esp_carga_max)
	h.hab_recarga = recarga_mecha
	h.vida = h.vida_max
	c.anunciar("MECHA DE VOLTA", COR)


## Recomeço da partida (Heroi.resetar): o LightWolf volta à forma mecha, sem anúncio nem efeito. `iniciar_stats` vem logo depois e zera o resto.
func reiniciar(h) -> void:
	carga_mecha = 0.0
	recarga_mecha = 0.0
	quebras = 0
	autodestruicoes = 0
	chamados = 0
	tempo_lobo = 0.0
	if h.espectral != null:
		h.espectral.desligar()
	if not tem() or str(h.chave) == str(combate.heroi_id):
		h.forma_lobo = false
		return
	h.forma_lobo = false  # a vida máxima é refeita por iniciar_stats
	combate.cfg = Herois.cfg_para(Dados.json("v2_combate"), combate.heroi_id)
	h.trocar_forma(combate.heroi_id, mundo.sprites.tipo(_folha_mecha()))


func _folha_mecha() -> String:
	return Herois.sprite_da_partida(combate.heroi_id, mundo.args.has("basico"))


## Um quadro (tempo do mundo): o Lobo ganha chamado por tempo, para nunca travar num mapa sem monstros (dados/v2_especial.json > chamar > carga > tempo).
func atualizar(dt: float) -> void:
	var h = mundo.heroi
	if h == null or not h.forma_lobo or combate.jogo != "jogando" or combate.pausado:
		return
	tempo_lobo += dt
	var tempo := float(_bloco().get("carga", {}).get("tempo", 0.0))
	if tempo > 0.0:
		combate.especial.carregar(h, tempo * dt, "tempo", false)
