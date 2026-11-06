extends RefCounted
## Status sobre o monstro (e sobre o herói, quando é ele quem sofre): chama (queima_t), relógio (lento_t) e estrelas (atordoa_t). O fogo tem duas
## camadas: o corpo escurecido e a borda de brasa vêm do shader do sprite (v2/status_corpo.gd) e a CHAMA ALTA, de várias línguas e brasas
## soltas, é uma folha animada (12 quadros, fonte_arte/chama/gerar_chama.py) presa às costas do monstro, em 3 tamanhos pela altura dele (chama_p, chama_m,
## chama_g). Tudo é tocado por `combate.fx_folha` (v2/fx_folha.gd, folhas em dados/v2_pixelfx.json). O jogo só tem estes três status; congelado,
## envenenado e sangrando não existem como mecânica e por isso não têm efeito aqui.
## O monstro comum é desenhado em lote e não tem nó, então o efeito prende numa âncora: um Node2D de um pool fixo (`max_monstros`, criado na
## montagem) que acompanha o monstro. Nenhum nó nasce no meio da partida. Quem tem status é achado varrendo uma fatia da lista de monstros por
## quadro (o estado já mora no monstro: monstro.gd não sabe deste arquivo). Limites para o i5: no máximo `max_monstros` monstros com efeito (as últimas `reserva_elite` vagas
## são só de elite e chefe) e `limite` por tipo; os números moram em dados/v2_pixelfx.json, bloco "status"; só desenha o que está na tela (`ativo`). Perfil Baixo (Anim.suave desligado): nada é desenhado nem varrido, e o
## tingimento do corpo (monstro.gd) segue avisando. Morte, volta ao pool e fim de partida soltam as alças no quadro seguinte (`limpar` no mesmo quadro).

const Anim := preload("res://v2/anim_golpes.gd")
const FOGO := 0
const LENTO := 1
const ATORDOA := 2
const IDS := ["", "slowed", "stunned"]  # o fogo escolhe a folha pelo tamanho do monstro (`id_fogo`)
const ATORDOA_MIN := 0.4  # só vale atordoamento longo (muralha, batida, escudo perfeito); o corte comum de 0,3 s não acende estrelas
const FATIAS := 6  # a lista de monstros é varrida inteira em ~6 quadros

var combate
var ativos := 0  # monstros com efeito (testes)
var max_monstros := 12  # dados/v2_pixelfx.json "status"; estes valores valem se o dado faltar
var reserva_elite := 2  # das vagas, as últimas só elite e chefe ocupam
var limite := [12, 6, 6]  # efeitos por tipo (fogo, lento, atordoa), somando os monstros (o herói lento fica de fora: usa o 8 do registro)
var _faixas: Array = [{"id": "chama_p", "alt_ate": 56.0}, {"id": "chama_m", "alt_ate": 120.0}, {"id": "chama_g", "alt_ate": 9999.0}]
var _base_fogo := 0.45  # onde a chama nasce, fração do alt acima dos pés
var _alt_min := 16.0
var _alt_max := 200.0
var _m: Array = []  # por vaga: o monstro rastreado, ou null
var _anc: Array = []  # por vaga: a âncora (Node2D) que acompanha o monstro
var _alca := PackedInt32Array()  # vaga * 3 + tipo: alça do fx_folha (0 = sem efeito)
var _cont := PackedInt32Array([0, 0, 0])  # efeitos vivos por tipo
var _alca_heroi := 0
var _cursor := 0


func montar(c, camada: Node) -> void:
	combate = c
	_ler_dados()
	_m.resize(max_monstros)
	_alca.resize(max_monstros * 3)
	for i in max_monstros:
		var a := Node2D.new()
		a.visible = false
		camada.add_child(a)
		_anc.append(a)


func _ler_dados() -> void:
	var d: Dictionary = Dados.json("v2_pixelfx").get("status", {})
	max_monstros = clampi(int(d.get("max_monstros", max_monstros)), 1, 32)
	reserva_elite = clampi(int(d.get("reserva_elite", reserva_elite)), 0, max_monstros - 1)
	var lim: Dictionary = d.get("limite", {})
	limite = [int(lim.get("fogo", limite[0])), int(lim.get("lento", limite[1])), int(lim.get("atordoa", limite[2]))]
	var fogo: Dictionary = d.get("fogo", {})
	var faixas = fogo.get("faixas", [])
	if faixas is Array and not faixas.is_empty():
		_faixas = faixas
	_base_fogo = float(fogo.get("base", _base_fogo))
	_alt_min = float(fogo.get("alt_min", _alt_min))
	_alt_max = float(fogo.get("alt_max", _alt_max))


## A folha da chama que cabe num monstro de altura `alt` (a primeira faixa cujo alt_ate passa dele).
func id_fogo(alt: float) -> String:
	for f in _faixas:
		if alt < float(f.alt_ate):
			return str(f.id)
	return str(_faixas[_faixas.size() - 1].id)


## Tudo solto e as vagas livres (a partida recomeça). Chame antes do `fx_folha.limpar()` ou depois: os dois lados toleram.
func limpar() -> void:
	var fx = combate.fx_folha if combate != null else null
	for i in max_monstros:
		if _m[i] != null:
			_largar(i, fx)
	if fx != null and _alca_heroi != 0:
		fx.soltar(_alca_heroi)
	_alca_heroi = 0
	_cont.fill(0)
	ativos = 0


## Quantos efeitos de status estão no ar sobre monstros (testes), e se o herói tem o relógio da teia.
func n_efeitos() -> int:
	return _cont[0] + _cont[1] + _cont[2]


func heroi_com_efeito() -> bool:
	return _alca_heroi != 0


func atualizar(_dt: float) -> void:
	if combate == null or combate.fx_folha == null:
		return
	var fx = combate.fx_folha
	if not Anim.suave:
		if ativos > 0 or _alca_heroi != 0:
			limpar()
		return
	for i in max_monstros:
		if _m[i] != null:
			_passo(i, fx)
	_varrer()
	_heroi(fx)


## Os efeitos da vaga seguem o estado do monstro; sem nenhum, a vaga volta.
func _passo(i: int, fx) -> void:
	var m = _m[i]
	var viva: bool = m.vivo and not m.morrendo and m.ativo  # fora da tela não se desenha: solta, e a varredura pega de volta ao voltar
	_ajustar(i, FOGO, viva and m.queima_t > 0.0, fx)
	_ajustar(i, LENTO, viva and m.lento_t > 0.0, fx)
	# o atordoamento começa só se for longo, mas continua até acabar (não pisca quando o resto passa de 0,4 s para baixo)
	_ajustar(i, ATORDOA, viva and m.atordoa_t > 0.0 and (_alca[i * 3 + ATORDOA] != 0 or m.atordoa_t >= ATORDOA_MIN), fx)
	if _alca[i * 3] == 0 and _alca[i * 3 + 1] == 0 and _alca[i * 3 + 2] == 0:
		_largar(i, fx)
		return
	(_anc[i] as Node2D).global_position = m.pr


func _ajustar(i: int, k: int, quer: bool, fx) -> void:
	var j := i * 3 + k
	var alca := _alca[j]
	if alca != 0 and not fx.vivo(alca):
		_alca[j] = 0  # o fx_folha soltou por conta própria (limpar, pool)
		_cont[k] -= 1
		alca = 0
	if quer:
		if alca == 0 and _cont[k] < limite[k]:
			var m = _m[i]
			var id: String = id_fogo(float(m.alt)) if k == FOGO else IDS[k]
			var opcoes := {"fase": fposmod(float(m.sid) * 0.382, 1.0)} if k == FOGO else {}  # cada chama começa num ponto da volta
			var nova: int = fx.prender(id, _anc[i], _deslocamento(k, m), opcoes)
			if nova != 0:
				_alca[j] = nova
				_cont[k] += 1
	elif alca != 0:
		fx.soltar(alca)
		_alca[j] = 0
		_cont[k] -= 1


## Onde o efeito fica em relação aos pés: a chama nas costas (a base dela; as línguas sobem dali), o relógio e as estrelas acima da cabeça.
func _deslocamento(k: int, m) -> Vector2:
	var alt := clampf(float(m.alt), _alt_min, _alt_max)
	match k:
		FOGO:
			return Vector2(0, -alt * _base_fogo)
		LENTO:
			return Vector2(0, -alt - 4.0)
	return Vector2(0, -alt + 2.0)


func _largar(i: int, fx) -> void:
	for k in 3:
		var alca := _alca[i * 3 + k]
		if alca != 0:
			if fx != null:
				fx.soltar(alca)
			_alca[i * 3 + k] = 0
			_cont[k] -= 1
	_m[i] = null
	(_anc[i] as Node2D).visible = false
	ativos -= 1


## Uma fatia da lista de monstros por quadro: quem está na tela e com status e ainda não tem vaga, ganha uma.
func _varrer() -> void:
	if ativos >= max_monstros:
		return
	var ms: Array = combate.mundo.monstros
	var n := ms.size()
	if n == 0:
		return
	for _k in mini(maxi(8, ceili(float(n) / FATIAS)), n):
		_cursor += 1
		if _cursor >= n:
			_cursor = 0
		var m = ms[_cursor]
		if not m.vivo or m.morrendo or not m.ativo:
			continue
		var quer_fogo: bool = m.queima_t > 0.0 and _cont[FOGO] < limite[FOGO]
		var quer_lento: bool = m.lento_t > 0.0 and _cont[LENTO] < limite[LENTO]
		var quer_atordoa: bool = m.atordoa_t >= ATORDOA_MIN and _cont[ATORDOA] < limite[ATORDOA]
		if not (quer_fogo or quer_lento or quer_atordoa) or _m.has(m):
			continue
		if ativos >= max_monstros - reserva_elite and not (m.elite or m.chefe):
			continue  # as últimas vagas ficam para elite e chefe
		var v := _m.find(null)
		if v < 0:
			return
		_m[v] = m
		ativos += 1
		(_anc[v] as Node2D).global_position = m.pr
		(_anc[v] as Node2D).visible = true
		if ativos >= max_monstros:
			return


## O herói só sofre a lentidão da teia da Rainha Tecelã (v2/chefe.gd): o relógio fica preso ao nó dele.
func _heroi(fx) -> void:
	var h = combate.mundo.heroi
	var quer: bool = h != null and h.vivo() and combate.chefes != null and combate.chefes.heroi_lento()
	if _alca_heroi != 0 and not fx.vivo(_alca_heroi):
		_alca_heroi = 0
	if quer:
		if _alca_heroi == 0:
			_alca_heroi = fx.prender("slowed", h.raiz, Vector2(0, -float(h.alt) - 4.0))
	elif _alca_heroi != 0:
		fx.soltar(_alca_heroi)
		_alca_heroi = 0
