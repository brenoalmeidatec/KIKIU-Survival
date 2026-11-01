extends RefCounted
## A FUMAÇA DO LUKE (DEF-5, #509): o secundário (botão direito, APERTAR) do Luke, no lugar do escudo (pedido 11: nem todo herói tem escudo). Uma bomba de fumaça cai no ponto da
## mira (até `alcance` px do herói) e abre uma nuvem de `raio` px por `duracao` s: os monstros dentro andam bem mais devagar (`m.deixar_lento`, 0,45 da velocidade) e o Luke leva
## `dano_mult` (50%) do dano enquanto estiver dentro dela. Recarga de `recarga` s, contada a partir do arremesso. Sem barra de defesa (def_max 0 na HUD).
##
## A nuvem NÃO é um nó nem tem pool próprio: ela ocupa um slot do pool de nuvens de v2/armas_novas.gd (`soltar_nuvem`, dicionários reaproveitados, `MAX` slots), com dano 0
## (`so_lentidao` no `st`: o tique só atrasa, sem número, sem flash e sem evento de golpe). O slot volta ao pool quando a vida da nuvem acaba (`duracao` s) e o 1º uso não cria
## nada que o 2º não reaproveite. O visual é o procedural das nuvens ("fumaça" cinza em camadas, sem folha de sprite; a nuvem com folha é da v3).
## Se o pool estiver cheio, o arremesso falha sem gastar a recarga (`lancar` devolve false).
##
## O herói (v2/heroi.gd) cuida da entrada (o aperto fica guardado `pedido` s), do dano reduzido (`protege`) e de publicar o slot S da HUD (`publicar`, contrato `sec_*`).
## Quem é "da fumaça" é dado (dados/v2_secundario.json > herois: id "fumaca"); este módulo só lê `combate.escudo.id_de`.
##
## API: montar(c), limpar(), atualizar(dt), para(chave), pronta(), lancar(h) -> bool, protege(h) -> bool, mult_dano(), publicar(h).

const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (a mesma da nuvem e do escudo)
const ID := "fumaca_luke"  # o id do "golpe" da nuvem no pool (fonte do desenho e do teste)

var combate
var mundo
var cfg: Dictionary = {}  # dados/v2_secundario.json > fumaca
var recarga := 0.0  # s até poder lançar de novo
var recarga_max := 1.0  # a recarga cheia (a fração da cortina do slot S)
var lancadas := 0  # testes: bombas lançadas
var falhas_pool := 0  # testes: arremessos sem slot livre no pool
var ultimo := Vector2.ZERO  # o ponto da última nuvem
var _a: Dictionary = {}  # o "golpe" da nuvem para o pool de armas_novas (montado uma vez)


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	cfg = Dados.json("v2_secundario").get("fumaca", {})
	var cor: Array = cfg.get("cor", [0.66, 0.68, 0.74])
	_a = {
		"id": ID,
		"tipo": "nuvem",
		"cor": Color(float(cor[0]), float(cor[1]), float(cor[2])),
		"fumaca": true,
		"st":
		{
			"raio": float(cfg.get("raio", 64.0)),
			"duracao": float(cfg.get("duracao", 4.0)),
			"tique": float(cfg.get("tique", 0.2)),
			"lentidao": float(cfg.get("lentidao_s", 0.5)),
			"dano": 0.0,
			"so_lentidao": true,
		}
	}


## Partida nova: recarga zerada (a nuvem que sobrou no pool some com `armas.limpar`).
func limpar() -> void:
	recarga = 0.0
	recarga_max = 1.0
	lancadas = 0
	falhas_pool = 0
	ultimo = Vector2.ZERO


## A recarga corre no tempo do mundo (pausa e hit-stop param, como a das outras habilidades).
func atualizar(dt: float) -> void:
	if recarga > 0.0:
		recarga = maxf(0.0, recarga - dt)


## O secundário do herói `chave` é a fumaça?
func para(chave: String) -> bool:
	return combate != null and combate.escudo != null and combate.escudo.id_de(chave) == "fumaca"


## Pode lançar agora? (o herói confere o resto: jogo rodando, pausa, estado livre.)
func pronta() -> bool:
	return recarga <= 0.0


## Quantos s o aperto do botão fica guardado (dados > fumaca > pedido).
func pedido() -> float:
	return float(cfg.get("pedido", 0.15))


## Lança a bomba: a nuvem cai no ponto da mira do herói `h`, no máximo a `alcance` px (no chão). Devolve false (e não gasta a recarga) se o pool estiver cheio.
func lancar(h) -> bool:
	var novas = combate.armas.novas if combate.armas != null else null
	if novas == null or recarga > 0.0:
		return false
	var alvo := _ponto(h)
	if not novas.soltar_nuvem(_a, alvo):
		falhas_pool += 1
		return false
	ultimo = alvo
	lancadas += 1
	recarga_max = float(cfg.get("recarga", 9.0))
	recarga = recarga_max
	combate.audio.tocar("ruptura_tique", 0.7, -4.0, 0.05)
	return true


## O ponto no chão onde a bomba cai: o mouse (ou a mira de 120 px do analógico e do teclado) preso a `alcance` px do herói, na conta do chão (y dividido pela achatada).
func _ponto(h) -> Vector2:
	var d: Vector2 = h.mira_mundo - h.centro() if h.fonte != h.Fonte.MOUSE else h.mira_mundo - h.pos
	var el := Vector2(d.x, d.y / ACHATA)
	var alc := float(cfg.get("alcance", 180.0))
	if el.length() > alc:
		el = el.normalized() * alc
	elif el.length() < 1.0:
		el = Vector2(h.dir_olhar.x, h.dir_olhar.y / ACHATA).normalized() * 8.0  # mira em cima do herói: cai aos pés
	return h.pos + Vector2(el.x, el.y * ACHATA)


## O herói `h` está dentro de uma nuvem de fumaça agora?
func protege(h) -> bool:
	if combate.armas == null:
		return false
	return combate.armas.novas.nuvem_cobre(ID, h.pos)


## O que o dano vira dentro da nuvem (dados > fumaca > dano_mult: 0,5 = leva metade).
func mult_dano() -> float:
	return float(cfg.get("dano_mult", 0.5))


## O que o slot S da HUD lê (contrato `sec_*`, v2/heroi.gd): pronta com a recarga zerada; "ativa" enquanto o herói está dentro da nuvem (o escudo dele); a cortina é a recarga.
func publicar(h) -> void:
	h.sec_ativo = protege(h)
	h.sec_pronta = recarga <= 0.0
	if recarga > 0.0:
		h.sec_recarga = clampf(recarga / maxf(recarga_max, 0.001), 0.0, 1.0)
		h.sec_recarga_s = recarga
