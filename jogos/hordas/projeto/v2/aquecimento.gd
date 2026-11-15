extends RefCounted
## Aquecimento do primeiro desenho (pedido do Alisson, 15/11: "depois da tela de load, tá dando uma travada"). Medido no PC (RX 7600 XT,
## OpenGL): a primeira vez que a placa desenha uma coisa nova custa caro, e isso caía no meio da partida, já sem a tela de carregamento:
##  - ~1 s quando o primeiro monstro da horda chega perto da tela (nasce a primeira fatia, um MultiMeshInstance2D com o shader da horda,
##    e os lotes de olhos, manchas e sombras desenham pela primeira vez: v2/horda.gd);
##  - ~0,5 s no primeiro dano de contato (o flash do herói, os números com contorno, as faíscas, o impacto da folha fx_dano_heroi).
## Aqui tudo isso desenha uma vez, minúsculo, por baixo da tela de carregamento (que cobre os primeiros quadros da partida,
## Transicoes.ir_para_carregando > "quadros_depois"), e some antes de a tela começar a sumir.
## Só existe quando a partida entrou pela tela de carregamento: nos testes e na medição direta nada disso roda.
## Ordem: `quadro()` no fim do _ready e no fim de cada _process. As `quadros` primeiras chamadas desenham; a seguinte limpa e encerra.

const Anim := preload("res://v2/anim_golpes.gd")
const COR_NUMERO := Color(1.0, 0.3, 0.25)

var mundo
var restam := 2  # chamadas que desenham (o _ready e o primeiro _process); a próxima limpa
var feito := false
var _slot_fx := -1


func _init(m, quadros := 2) -> void:
	mundo = m
	restam = maxi(1, quadros)


## Desenha o aquecimento (enquanto restam chamadas) ou limpa tudo (na chamada seguinte). Devolve false quando acabou.
func quadro() -> bool:
	if feito:
		return false
	if restam <= 0:
		_limpar()
		feito = true
		return false
	restam -= 1
	var h = mundo.heroi
	var p: Vector2 = h.pos
	mundo.horda.aquecer(p)
	var c = mundo.combate
	if c == null:
		return true
	if c.fx != null:
		c.fx.flash(h, 0.5, Color(1.0, 0.3, 0.3), 0, 0.004)  # o flash do dano (o shader do flash), quase sem força
		c.fx.numero(p + Vector2(0, -44), "0123456789", COR_NUMERO, false)  # as páginas da fonte nos tamanhos dos números (16, 24 e 32)
		c.fx.numero(p + Vector2(0, -44), "0123456789", COR_NUMERO, true)
		c.fx.particula(p, Vector2.ZERO, 0.2, 2.0, Color(1, 1, 1, 0.01), 0.0, false)
		c.fx.particula(p, Vector2.ZERO, 0.2, 2.0, Color(1, 1, 1, 0.01), 0.0, true)
	if c.armas != null and c.armas.novas != null and _slot_fx < 0:
		var f: Dictionary = Anim.de("fx_dano_heroi").get("impacto", {})
		if not f.is_empty():
			_slot_fx = c.armas.novas._xi
			c.armas.novas.tocar_fx(f, p + Vector2(0, -16), 1.0, false, 1.0, Color(1, 1, 1, 0.004))
	return true


## Nada do aquecimento fica na partida: os efeitos voltam ao zero (a horda se esconde sozinha no próximo quadro dela).
func _limpar() -> void:
	var c = mundo.combate
	if c == null:
		return
	if c.fx != null:
		c.fx.limpar()
		for k in c.fx.usados:
			c.fx.usados[k] = 0
	if c.armas != null and c.armas.novas != null and _slot_fx >= 0:
		c.armas.novas.x_dur[_slot_fx] = 0.0
		c.armas.novas.impactos = maxi(0, c.armas.novas.impactos - 1)
