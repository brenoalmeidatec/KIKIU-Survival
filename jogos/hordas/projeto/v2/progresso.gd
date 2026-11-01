extends RefCounted
## XP, nível e escolha de cartas da v2. O XP vem dos orbes (combate.coletar). Ao encher a barra: sobe o nível (sinal nivel_subiu do mundo),
## câmera lenta de 0,4 s e a escolha de 1 entre 3 cartas (v2/cartas.gd: raridade, golpes secundários, modificadores da katana, evoluções), que
## pausa o mundo até o jogador escolher. Na escolha o jogador pega uma carta ou usa o AUTOMÁTICO (não há rerrolar nem banir).
## Várias subidas seguidas viram várias escolhas, uma depois da outra. A curva de nível fica em dados/v2_combate.json ("xp", "nivel") e as
## cartas em dados/v2_cartas.json.

const Dificuldade := preload("res://v2/dificuldade.gd")
const Paleta := preload("res://v2/paleta.gd")

var combate
var cfg: Dictionary
var melhorias := {}  # id da carta -> quantas vezes pegou
var pendentes := 0  # níveis subidos que ainda esperam a escolha
var cartas: Array = []  # as cartas na tela
var escolhidas := 0  # quantas cartas o jogador já escolheu (testes)
var ultima_nome := ""  # o nome da última carta escolhida (o aviso da escolha automática diz qual foi)
var bau_picks := 0  # quantas cartas do baú aberto ainda faltam pegar (0 = a escolha na tela, se houver, é a de nível)


func montar(c) -> void:
	combate = c
	cfg = c.cfg
	var h = c.mundo.heroi
	if h != null:
		h.xp_proximo = xp_para(1)


## XP que falta para sair do nível `n`: base + passo*(n-1) + quad*(n-1)^2.
func xp_para(n: int) -> float:
	var k := float(n - 1)
	var x: Dictionary = cfg.xp
	return roundf(float(x.base) + float(x.passo) * k + float(x.quad) * k * k)


## Vida que o herói recupera a cada nível que sobe (a fração `cura_nivel` da vida máxima de agora). O card de status mostra este valor.
func cura_por_nivel() -> float:
	return combate.mundo.heroi.vida_max * float(cfg.heroi.cura_nivel) * float(combate.ritmo.cfg.cura_nivel_mult)


## Fração a mais por nível acima do 1 (regra = {por_nivel, teto}, de dados): nível 1 = 0; sobe `por_nivel` a cada nível e para no `teto`.
## Serve ao alcance do golpe (dados/v2_combate.json > golpe.raio_por_nivel, lido em combate.gd) e ao raio e ao arco do escudo (dados/v2_secundario.json > escudo).
static func bonus_por_nivel(nivel: int, regra: Dictionary) -> float:
	return minf(float(maxi(nivel - 1, 0)) * float(regra.por_nivel), float(regra.teto))


## Cada nível acima do 1 soma folego.por_nivel cargas ao fôlego máximo, até o teto (dados/v2_combate.json); soma só a diferença do nível
## novo, então o santuário e o herói continuam valendo por baixo. No Médio e no Difícil (folego_cheio) o fôlego também enche.
func _folego_do_nivel(h) -> void:
	var regra: Dictionary = cfg.folego.get("por_nivel", {})
	if not regra.is_empty():
		h.folego_max += bonus_por_nivel(h.nivel, regra) - bonus_por_nivel(h.nivel - 1, regra)
	if bool(Dificuldade.da_partida(combate.mundo).get("folego_cheio", false)):
		h.encher_folego()


func zerar() -> void:
	melhorias.clear()
	pendentes = 0
	bau_picks = 0
	cartas.clear()
	escolhidas = 0
	if combate.cartas != null:
		combate.cartas.zerar()
	var h = combate.mundo.heroi
	if h != null:
		h.xp = 0.0
		h.nivel = 1
		h.xp_proximo = xp_para(1)


func ganhar_xp(v: float) -> void:
	var h = combate.mundo.heroi
	if not h.vivo():
		return
	h.xp += v / combate.velocidade  # ritmo da partida 1,25: abates/s sobem 25%, então cada ponto vale 1/1,25 e as cartas aparecem no mesmo ritmo por minuto real
	while h.xp >= h.xp_proximo:
		h.xp -= h.xp_proximo
		h.nivel += 1
		h.xp_proximo = xp_para(h.nivel)
		h.curar(cura_por_nivel())
		h.repor_defesa_de("nivel")  # subir de nível repõe parte da barra do escudo (nas três dificuldades)
		_folego_do_nivel(h)
		pendentes += 1
		combate.nivel_subiu(h.nivel)
	if pendentes > 0 and combate.lento_acao == "" and not combate.pausado and combate.jogo == "jogando":
		combate.camera_lenta("nivel", float(cfg.nivel.camera_lenta), float(cfg.nivel.escala_lenta))


## Monta a mão (2 upgrades + 1 novidade, v2/cartas.gd montar_mao) e abre a escolha (pausa o mundo). Com as vagas cheias (limite do Difícil) a
## novidade vem marcada TROCA; se nenhuma carta servir ao automático (só TROCA e upgrades que passariam do nível 4), a última vira a cura: o limite de tempo sempre acha o que escolher.
func abrir_escolha() -> void:
	var cs = combate.cartas
	cartas = cs.montar_mao(combate.mundo.heroi.nivel, 1.0, 0, -1, true, true)
	var qtd := int(cs.cfg.escolha.cartas)
	if cartas.size() < qtd:  # sobrou pouca carta (tudo no máximo): uma cura ocupa o espaço, para não travar nem ficar sem mão
		cartas.append(_carta_cura())
	elif cs.limite_bonus() > 0 and not cartas.any(func(c: Dictionary) -> bool: return cs.serve_ao_automatico(c)):
		cartas[qtd - 1] = _carta_cura()
	combate.jogo = "escolha"
	combate.pausado = true
	combate.telas.mostrar_escolha(cartas, combate.mundo.heroi.nivel)


## Abre a escolha do BAÚ (v2/bau.gd): as mesmas cartas na mesma tela da escolha de nível, com a raridade melhor do baú, mais tempo (bau.limite_s). O jogador pega `picks` delas, uma por vez; as que sobram continuam na tela. Não mexe nos níveis pendentes.
func abrir_escolha_bau(candidatas: Array, picks: int) -> void:
	bau_picks = picks
	cartas = candidatas
	combate.jogo = "escolha"
	combate.pausado = true
	combate.telas.mostrar_escolha(cartas, combate.mundo.heroi.nivel)


func _carta_cura() -> Dictionary:
	return {
		"id": "cura",
		"nome": "Alma renovada",
		"desc": "Cura toda a vida",
		"cat": "stat",
		"stat": "cura",
		"icone": "icone_vida",
		"tipo": "",
		"valor": 0,
		"max": 99,
		"rar": 0,
		"rar_nome": "Comum",
		"cor": Color(0.8, 0.82, 0.86),
		"extra": ""
	}


## Escolhe a carta `i`. Uma carta TROCA (bônus novo com as vagas cheias) ainda não vale: abre o painel em que o jogador larga um bônus (telas.abrir_troca),
## e é `trocar` que conclui.
func escolher(i: int) -> void:
	if i < 0 or i >= cartas.size():
		return
	var c: Dictionary = cartas[i]
	if str(c.get("tipo", "")) == "troca":
		combate.telas.abrir_troca(i)
		return
	aplicar(c)
	escolhidas += 1
	ultima_nome = str(c.get("nome", ""))
	combate.audio.tocar("escolher", 1.0, 0.0, 0.0)
	var h = combate.mundo.heroi
	var cor: Color = c.get("cor", Color(1.0, 0.9, 0.6))
	combate.fx.onda(h.pos + Vector2(0, -12), Color(cor.r, cor.g, cor.b, 0.9), 44.0 + 16.0 * float(c.get("rar", 0)), 0.25)
	var do_bau := bau_picks > 0
	if do_bau:  # o baú: a carta pega sai da tela e, se ainda falta pegar, as que sobraram ficam esperando (sem roleta, com a trava curta)
		combate.baus.ultimas.append(c)
		bau_picks -= 1
		cartas.remove_at(i)
		if bau_picks > 0 and not cartas.is_empty():
			combate.telas.mostrar_escolha(cartas, h.nivel, true)
			return
		bau_picks = 0
	else:
		pendentes = maxi(0, pendentes - 1)
	cartas = []
	combate.telas.esconder()
	combate.pausado = false
	combate.jogo = "jogando"
	if not do_bau and pendentes > 0:
		combate.camera_lenta("nivel", float(cfg.nivel.camera_lenta), float(cfg.nivel.escala_lenta))


## Conclui a carta TROCA `i`: larga o bônus `saida` (cartas.remover_bonus desfaz o efeito dele) e leva o bônus novo. Devolve false, sem mexer em nada,
## se `i` não é uma carta de troca ou `saida` não é um bônus que o herói possa largar.
func trocar(i: int, saida: String) -> bool:
	if i < 0 or i >= cartas.size() or str(cartas[i].get("tipo", "")) != "troca":
		return false
	var nome_saida := str(combate.cartas.definicao(saida).get("nome", saida))
	if not combate.cartas.remover_bonus(saida):
		return false
	cartas[i].tipo = "nov"  # a vaga abriu: a carta vale como novidade comum
	combate.anunciar("Largou %s por %s" % [nome_saida, str(cartas[i].get("nome", ""))], Paleta.OURO)
	escolher(i)
	return true


## Perde a rodada de cartas aberta (o "Sim" de "Pausar agora?" na escolha): nenhuma carta é aplicada e o nível pendente é consumido.
## Com mais níveis pendentes a próxima rodada abre depois, como depois de uma escolha.
func descartar_rodada() -> void:
	if combate.jogo != "escolha":
		return
	var do_bau := bau_picks > 0  # perder a rodada do baú perde as cartas dele, mas não consome nível
	bau_picks = 0
	if not do_bau:
		pendentes = maxi(0, pendentes - 1)
	cartas = []
	combate.telas.esconder()
	combate.pausado = false
	combate.jogo = "jogando"
	if not do_bau and pendentes > 0:
		combate.camera_lenta("nivel", float(cfg.nivel.camera_lenta), float(cfg.nivel.escala_lenta))


## Escolha AUTOMÁTICA: o sistema escolhe a carta dentro da mão pelo que o herói já tem (cartas.escolha_automatica) e aplica na hora. Sem custo, mas a
## raridade vem rebaixada. Devolve false se não está na escolha ou não sobrou carta nenhuma.
func automatico() -> bool:
	var cs = combate.cartas
	if combate.jogo != "escolha":
		return false
	if bau_picks > 0:  # no baú vale a mais rara das que estão na tela (a primeira em caso de empate), sem rebaixar nada
		var melhor := -1
		for i in cartas.size():
			if melhor < 0 or int(cartas[i].get("rar", 0)) > int(cartas[melhor].get("rar", 0)):
				melhor = i
		if melhor < 0:
			return false
		escolher(melhor)
		return true
	var c: Dictionary = cs.escolha_automatica(cartas)
	if c.is_empty():
		return false
	cartas = [c]
	escolher(0)
	return true


func aplicar(c: Dictionary) -> void:
	combate.cartas.aplicar(c)


static func texto_carta(c: Dictionary) -> String:
	return str(c.desc).replace("{v}", str(int(c.get("valor", 0))))
