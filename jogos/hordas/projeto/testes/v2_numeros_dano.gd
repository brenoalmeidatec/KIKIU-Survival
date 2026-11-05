extends "res://testes/isolamento_v2.gd"
# Teste automático dos números de dano empilhados (efeitos.gd > numero): acertos que nascem juntos, no mesmo bicho ou em bichos colados, viram um
# número só com a soma exata (o dano de jogo não muda, só o que aparece); quem está longe, é de outra cor ou tamanho, nasceu depois da janela, é
# texto que não é dano ou tem lugar certo (exato) continua sozinho; e uma salva num bando em volta do herói, como as do LightWolf, deixa a tela legível.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_numeros_dano.tscn  (imprime "v2_numeros_dano falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const COR := Color(0.725, 0.9725, 1.0)
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var fx


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## Índices dos números vivos agora.
func vivos() -> Array:
	var r := []
	for i in fx.MAX_NUM:
		if fx.n_t[i] < fx.n_dur[i]:
			r.append(i)
	return r


## Soma do que está escrito nos números vivos que são só dígitos.
func soma_na_tela() -> int:
	var s := 0
	for i in vivos():
		if str(fx.n_txt[i]).is_valid_int():
			s += int(str(fx.n_txt[i]))
	return s


## Pares de números vivos de 1 dígito que se escondem (a caixa de cada um tem ~10 px de largura e ~12 de altura).
func pares_sobrepostos() -> int:
	var n := 0
	var v := vivos()
	for a in v.size():
		for b in range(a + 1, v.size()):
			var d: Vector2 = fx.n_pos[v[a]] - fx.n_pos[v[b]]
			if absf(d.x) < 9.0 and absf(d.y) < 12.0:
				n += 1
	return n


func limpo() -> void:
	fx.limpar()
	fx.usados.numeros = 0
	fx.usados["somados"] = 0


func esperar(s: float) -> void:
	for i in int(ceil(s / PASSO)):
		fx.atualizar(PASSO)


func _ready() -> void:
	seed(7)
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	fx = w.combate.fx

	# 1. cinco acertos no mesmo ponto, no mesmo quadro: um número, com a soma exata (6+6+6+10+12 = 40)
	limpo()
	var p := Vector2(500, 300)
	for d in [6, 6, 6, 10, 12]:
		fx.numero(p, str(d), COR)
	ok(vivos().size() == 1, "5 acertos no mesmo ponto viram 1 número (%d na tela)" % vivos().size())
	ok(soma_na_tela() == 40, "e a soma é a do dano: 40 (%d)" % soma_na_tela())
	ok(fx.usados.numeros == 5, "o contador de pedidos continua contando os 5 (%d)" % fx.usados.numeros)

	# 2. perto (a ~20 px) soma; longe (100 px) não
	limpo()
	fx.numero(p, "6", COR)
	fx.numero(p + Vector2(20, 6), "11", COR)
	ok(vivos().size() == 1 and soma_na_tela() == 17, "6 e 11 a 20 px viram 17 (%d números, soma %d)" % [vivos().size(), soma_na_tela()])
	fx.numero(p + Vector2(100, 0), "9", COR)
	ok(vivos().size() == 2 and soma_na_tela() == 26, "um acerto a 100 px fica sozinho (%d números, soma %d)" % [vivos().size(), soma_na_tela()])

	# 3. outra cor ou outro tamanho (crítico, número pequeno das armas) não se mistura
	limpo()
	fx.numero(p, "6", COR)
	fx.numero(p, "6", Color(1.0, 0.8, 0.2))
	fx.numero(p, "30", COR, true)
	fx.numero(p, "5", COR, false, 14)
	ok(vivos().size() == 4, "cor, crítico e tamanho diferentes ficam separados (%d)" % vivos().size())

	# 4. a janela: depois de 0,3 s o número já subiu e o acerto novo abre outro
	limpo()
	fx.numero(p, "6", COR)
	esperar(0.2)
	fx.numero(p, "6", COR)
	ok(vivos().size() == 1 and soma_na_tela() == 12, "dentro da janela (0,2 s) soma (%d números, soma %d)" % [vivos().size(), soma_na_tela()])
	esperar(0.2)
	fx.numero(p, "6", COR)
	ok(vivos().size() == 2, "passada a janela (0,4 s) nasce outro número (%d)" % vivos().size())

	# 5. o que não é conta de dano nem soma: lugar exato, texto, cura com "+"
	limpo()
	fx.numero(p, "6", COR, false, 14, true)
	fx.numero(p, "6", COR, false, 14, true)
	fx.numero(p, "LIMPOU x3", COR, true)
	fx.numero(p, "LIMPOU x3", COR, true)
	fx.numero(p, "+12", COR)
	fx.numero(p, "+12", COR)
	ok(vivos().size() == 6, "exato, texto e cura não somam (%d)" % vivos().size())

	# 6. uma salva em volta do herói (14 bichos num anel de ~45 px, 6 de dano cada, e uns diretos de 10 a 12): a soma é toda mostrada e a tela fica legível (nenhum par escondido)
	limpo()
	var total := 0
	for k in 14:
		var ang := TAU * float(k) / 14.0
		var onde := p + Vector2(cos(ang) * 45.0, sin(ang) * 22.0 - 24.0)
		var dn := 6 if k % 3 != 0 else 11
		fx.numero(onde, str(dn), COR)
		total += dn
	ok(soma_na_tela() == total, "a salva mostra todo o dano: %d (%d)" % [total, soma_na_tela()])
	ok(vivos().size() <= 8, "14 acertos colados ocupam no máximo 8 números (%d)" % vivos().size())
	ok(pares_sobrepostos() == 0, "nenhum par de números se esconde (%d)" % pares_sobrepostos())

	# 7. ponta a ponta: dois acertos de fonte secundária em bichos colados e um longe (o dano de cada bicho é o mesmo de antes)
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	fx = w.combate.fx
	limpo()
	var h: Vector2 = w.heroi.pos
	var a = w.nascer_monstro("inimigo_cao_ossos", h + Vector2(80, 0))
	var b = w.nascer_monstro("inimigo_cao_ossos", h + Vector2(88, 4))
	var longe = w.nascer_monstro("inimigo_cao_ossos", h + Vector2(-200, 0))
	for m in [a, b, longe]:
		m.vida = 10000.0
		m.vida_max = 10000.0
	var v0: float = a.vida + b.vida + longe.vida
	w.combate.ferir(a, 6.0, Vector2.RIGHT, 0.0, 0.0, COR)
	w.combate.ferir(b, 6.0, Vector2.RIGHT, 0.0, 0.0, COR)
	w.combate.ferir(longe, 6.0, Vector2.RIGHT, 0.0, 0.0, COR)
	ok(is_equal_approx(v0 - (a.vida + b.vida + longe.vida), 18.0), "o dano que os monstros levam não muda (18)")
	ok(vivos().size() == 2 and soma_na_tela() == 18, "na tela: 2 números somando 18 (%d números, soma %d)" % [vivos().size(), soma_na_tela()])

	print("v2_numeros_dano falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
