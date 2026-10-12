extends CanvasLayer
## HUD da v2: vida, fôlego, XP com selo de nível, tempo, abates, monstros vivos, combo, brilho do nível novo, a faixa de anúncio
## (centro alto), a barra de chefe com fantasma e a vinheta de vida baixa.
## Fica numa CanvasLayer (layer 10) dentro da SubViewport 960x540 do mundo: pixel art na mesma resolução do mundo (o sharp bilinear
## escala junto), fonte PressStart2P sem anti-aliasing e sem hinting, e light_mask 0 para a luz do mundo não tocar nele.
## Lê o mundo com get() e valor padrão: sem combate mostra vida cheia, XP 0 e nível 1. Campos lidos: em mundo.heroi, vida, vida_max,
## xp, xp_proximo, nivel, folego, folego_max, cansado (bool, padrão false: a barra de fôlego pisca); em mundo, abates, combo,
## tempo_partida (segundos), monstros_vivos. Sinais do mundo, cada um ligado só se o mundo tiver: nivel_subiu(nivel),
## onda_forte(numero), elite_apareceu(nome), chefe_apareceu(nome, vida_max), chefe_vida(vida), evolucao(nome), anuncio(texto, cor).
## Uso no mundo (uma linha no _ready):
##   sv.add_child(preload("res://v2/hud.gd").criar(self))
## Layout em v2/hud.tscn (coordenadas de 960x540). O canto superior direito fica livre para o minimapa.

const Paleta := preload("res://v2/paleta.gd")
const CENA := "res://v2/hud.tscn"
const FONTE := "res://assets/fonte/PressStart2P.ttf"
const PULSO_T := 0.25  # segundos do pulso do combo a cada abate
const BRILHO_T := 1.2  # segundos do brilho da barra de XP ao subir de nível
const SALTO_PX := 4  # quantos pixels o combo sobe no pulso
const BRILHO_XP := Color(1.7, 1.5, 0.9)  # multiplicador de cor no pico do brilho: a barra e o selo clareiam para o dourado
const LIMIAR_VIDA_BAIXA := 0.25  # abaixo de 25% da vida: vinheta vermelha e barra de vida piscando
const VINHETA_MAX := 0.7  # opacidade máxima da vinheta (ela pulsa um pouco abaixo disso)
const POP_SELO_T := 0.3  # segundos do pop do selo ao subir de nível
const ANEL_T := 0.5  # segundos do anel de luz que sai do selo
const RELOGIO_PISCA_T := 0.8  # o tempo pisca dourado 0,8 s a cada minuto sobrevivido
const ROLAGEM_XP := 9.0  # quão rápido o número das almas rola até o valor da barra de XP
const CHEFE_ESPERA := 0.35  # segundos que a fantasma espera antes de descer atrás da barra real
const CHEFE_QUEDA := 1.2  # quão rápido a fantasma desce atrás da real (fração da diferença por segundo)
const MARCOS := [10, 25, 50, 100, 200]
const NOMES_MARCOS := ["SEQUÊNCIA!", "CARNIFICINA!", "MASSACRE!", "IMPARÁVEL!", "LENDÁRIO!"]
## Sinais do mundo e o método do HUD que cada um chama. Só se conecta o que o mundo tem.
const SINAIS := [
	["nivel_subiu", "_nivel_subiu"],
	["onda_forte", "_onda_forte"],
	["elite_apareceu", "_elite_apareceu"],
	["chefe_apareceu", "_chefe_apareceu"],
	["chefe_vida", "_chefe_vida"],
	["evolucao", "_evolucao"],
	["anuncio", "_anuncio_livre"],
]

## O mundo lido (o da v2, ou um falso nos testes). Pode ser null: aí o HUD mostra os valores padrão.
var mundo = null
## Segundos que faltam no pulso do combo e no brilho do XP. Públicos para os testes.
var pulso := 0.0
var brilho := 0.0
## Opacidade da vinheta de vida baixa, de 0 a VINHETA_MAX. Público para os testes.
var vinheta_alfa := 0.0

var _abates_antes := 0
var _combo_antes := 0
var _piscada := 0.0  # segundos que o herói está cansado (para o pisca da barra de fôlego)
var _pisca_vida := 0.0  # segundos com vida baixa (para o pisca da barra de vida)
var _tempo_vinheta := 0.0  # segundos com vida baixa (para o pulso da vinheta)
var _combo_x := 0.0
var _combo_y := 0.0
var _cor_base := Color.WHITE  # cor do combo na contagem atual (sobe com os marcos)
var _minuto_antes := 0
var _relogio_pisca := 0.0
var _pop_selo := 0.0
var _anel_t := 0.0
var _xp_mostrado := 0.0  # o número de almas que rola até o valor do herói
var _chefe_visivel := false
var _chefe_max := 1.0
var _chefe_real := 1.0
var _chefe_fantasma := 1.0
var _chefe_espera := 0.0

@onready var _vida_barra: TextureProgressBar = $Raiz/Vida/Barra
@onready var _vida_txt: Label = $Raiz/Vida/Texto
@onready var _folego: TextureProgressBar = $Raiz/Folego
@onready var _relogio: Label = $Raiz/Tempo/Relogio
@onready var _abates: Label = $Raiz/Abates/Linhas
@onready var _combo: Control = $Raiz/Combo
@onready var _combo_num: Label = $Raiz/Combo/Numero
@onready var _xp_barra: TextureProgressBar = $Raiz/Xp/Barra
@onready var _xp_txt: Label = $Raiz/Xp/Texto
@onready var _selo: TextureRect = $Raiz/Selo
@onready var _selo_num: Label = $Raiz/Selo/Numero
@onready var _anel: TextureRect = $Raiz/Anel
@onready var _vinheta: TextureRect = $Raiz/Vinheta
@onready var _chefe: NinePatchRect = $Raiz/Chefe
@onready var _chefe_nome: Label = $Raiz/Chefe/Nome
@onready var _chefe_fantasma_barra: TextureProgressBar = $Raiz/Chefe/Fantasma
@onready var _chefe_barra: TextureProgressBar = $Raiz/Chefe/Barra
@onready var _chefe_txt: Label = $Raiz/Chefe/Texto
@onready var _anuncio = $Raiz/Anuncio


## Cria o HUD já ligado ao mundo. É o que o mundo.gd chama (numa linha).
static func criar(m) -> Node:
	var cena = load(CENA)
	var hud = cena.instantiate()
	hud.ligar(m)
	return hud


## Liga (ou troca) o mundo lido. Conecta cada sinal da lista SINAIS só se o mundo tiver o sinal.
func ligar(m) -> CanvasLayer:
	_desconectar()
	mundo = m
	if mundo != null:
		for par in SINAIS:
			if mundo.has_signal(par[0]):
				mundo.connect(par[0], Callable(self, par[1]))
	return self


func _ready() -> void:
	# A fonte do jogo sem anti-aliasing e sem hinting: a cópia é só deste HUD, o import compartilhado com a v1 não muda.
	var fonte := (load(FONTE) as FontFile).duplicate() as FontFile
	fonte.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fonte.hinting = TextServer.HINTING_NONE
	fonte.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	$Raiz.add_theme_font_override("font", fonte)
	$Raiz.light_mask = 0
	for n in $Raiz.find_children("*", "CanvasItem", true, false):
		n.light_mask = 0
		if n is Control:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_x = _combo.position.x
	_combo_y = _combo.position.y
	_combo_num.pivot_offset = Vector2(100, 13)
	_selo.pivot_offset = Vector2(12, 12)
	_anel.pivot_offset = Vector2(10, 10)
	_vinheta.texture = _textura_vinheta()
	_vinheta.visible = false


func _exit_tree() -> void:
	_desconectar()


func _desconectar() -> void:
	if mundo == null or not is_instance_valid(mundo):
		return
	for par in SINAIS:
		var cb := Callable(self, par[1])
		if mundo.has_signal(par[0]) and mundo.is_connected(par[0], cb):
			mundo.disconnect(par[0], cb)


func _process(delta: float) -> void:
	avancar(delta)


## Um quadro do HUD: lê o mundo e atualiza barras, textos, pulsos, vinheta, chefe e anúncios. Os testes chamam isto direto.
func avancar(dt: float) -> void:
	var h = _campo(mundo, "heroi")
	var vida_max := maxf(_num(h, "vida_max", 100.0), 1.0)
	var vida := clampf(_num(h, "vida", vida_max), 0.0, vida_max)
	_vida_barra.max_value = vida_max
	_vida_barra.value = vida
	_vida_txt.text = "%d/%d" % [roundi(vida), roundi(vida_max)]
	_vida_baixa(dt, vida / vida_max)
	var folego_max := maxf(_num(h, "folego_max", 100.0), 1.0)
	_folego.max_value = folego_max
	_folego.value = clampf(_num(h, "folego", folego_max), 0.0, folego_max)
	# Herói cansado (corrida no Shift esgotou o fôlego): a barra pisca em vermelho até recuperar.
	var cansado: bool = _campo(h, "cansado") == true
	_piscada = _piscada + dt if cansado else 0.0
	var pisca: bool = cansado and int(_piscada * 6.0) % 2 == 0
	_folego.modulate = Paleta.FOLEGO_CANSADO if pisca else Color.WHITE
	var xp_prox := maxf(_num(h, "xp_proximo", 100.0), 1.0)
	var xp_alvo := clampf(_num(h, "xp", 0.0), 0.0, xp_prox)
	_xp_mostrado = _rolar_xp(xp_alvo, dt)
	_xp_barra.max_value = xp_prox
	_xp_barra.value = _xp_mostrado
	_xp_txt.text = "%d/%d" % [roundi(_xp_mostrado), roundi(xp_prox)]
	_selo_num.text = str(roundi(_num(h, "nivel", 1.0)))
	var tempo := maxf(_num(mundo, "tempo_partida", 0.0), 0.0)
	_relogio.text = "%02d:%02d" % [int(tempo) / 60, int(tempo) % 60]
	_checar_minuto(int(tempo) / 60)
	var abates := roundi(_num(mundo, "abates", 0.0))
	var combo := roundi(_num(mundo, "combo", 0.0))
	_abates.text = "ABATES %d\nVIVOS %d" % [abates, roundi(_num(mundo, "monstros_vivos", 0.0))]
	var cartas_na_tela := _cartas_na_tela()  # a escolha e o baú têm o título grande no alto: combo e faixa saem
	_combo.visible = combo > 0 and not cartas_na_tela
	_combo_num.text = "x%d" % combo
	_checar_marcos(_combo_antes, combo)
	if abates > _abates_antes or combo > _combo_antes:
		pulso = PULSO_T
	_abates_antes = abates
	_combo_antes = combo
	_cor_base = _cor_do_combo(combo)
	_chefe_quadro(dt)
	_animar(dt)
	_anuncio.avancar(dt)
	_anuncio.visible = _anuncio.texto_ativo != "" and not cartas_na_tela


## Verdadeiro com a escolha de carta ou o baú abertos (telas.gd). Sem combate no mundo (testes), é falso.
func _cartas_na_tela() -> bool:
	var telas = _campo(_campo(mundo, "combate"), "telas")
	return _campo(telas, "escolha_aberta") == true or _campo(telas, "bau_aberto") == true


func _animar(dt: float) -> void:
	# Pulso do combo: sobe alguns pixels e dá um soco de escala (1,0 a 1,3 em degraus), e clareia para a cor do marco. Volta no repouso.
	pulso = maxf(pulso - dt, 0.0)
	var k := pulso / PULSO_T
	_combo.position = Vector2(_combo_x, _combo_y - roundf(SALTO_PX * k))
	_combo_num.scale = Vector2.ONE * (1.0 + 0.1 * roundf(3.0 * k))
	_combo_num.modulate = _cor_base.lerp(Color.WHITE, 0.6 * k)
	# Brilho do XP: a barra e o selo clareiam para o dourado, piscando em degraus de 1/4 (pixel art não tem alfa suave) e apagando até zero.
	brilho = maxf(brilho - dt, 0.0)
	var f := roundf(4.0 * (brilho / BRILHO_T) * (0.5 + 0.5 * sin(brilho * 16.0))) / 4.0
	_xp_barra.modulate = Color.WHITE.lerp(BRILHO_XP, f)
	# Pop do selo ao subir de nível (cresce 0,4 e volta, em degraus de 0,05) e o anel de luz que sai dele.
	_pop_selo = maxf(_pop_selo - dt, 0.0)
	_selo.scale = Vector2.ONE * (1.0 + roundf(8.0 * _pop_selo / POP_SELO_T) / 20.0)
	_selo.modulate = _xp_barra.modulate
	_anel_t = maxf(_anel_t - dt, 0.0)
	_anel.visible = _anel_t > 0.0
	if _anel.visible:
		var sumindo := _anel_t / ANEL_T
		var cresce := 1.0 - sumindo
		_anel.scale = Vector2.ONE * (0.6 + 1.6 * cresce)
		_anel.modulate = Color(1, 1, 1, sumindo)
	# Relógio: pisca dourado a cada minuto, em quatro degraus.
	_relogio_pisca = maxf(_relogio_pisca - dt, 0.0)
	_relogio.modulate = Color.WHITE.lerp(Paleta.OURO, roundf(4.0 * _relogio_pisca / RELOGIO_PISCA_T) / 4.0)


## Vida baixa (abaixo de 25%): a barra de vida pisca e a vinheta vermelha pulsa nas bordas. A vinheta entra e sai aos poucos.
func _vida_baixa(dt: float, fracao: float) -> void:
	var baixa := fracao < LIMIAR_VIDA_BAIXA
	_pisca_vida = _pisca_vida + dt if baixa else 0.0
	_tempo_vinheta = _tempo_vinheta + dt if baixa else 0.0
	var pisca := baixa and int(_pisca_vida * 5.0) % 2 == 0
	_vida_barra.modulate = Paleta.PERIGO if pisca else Color.WHITE
	var alvo := 0.0
	if baixa:
		alvo = VINHETA_MAX * (0.75 + 0.25 * sin(_tempo_vinheta * 7.0))
	vinheta_alfa = move_toward(vinheta_alfa, alvo, dt * 3.0)
	_vinheta.modulate = Paleta.alfa(Paleta.PERIGO, vinheta_alfa)
	_vinheta.visible = vinheta_alfa > 0.0


## Almas: o número rola até o valor do herói. Se o valor cair (nível novo), vai direto.
func _rolar_xp(alvo: float, dt: float) -> float:
	if alvo < _xp_mostrado or alvo - _xp_mostrado < 0.5:
		return alvo
	return _xp_mostrado + (alvo - _xp_mostrado) * (1.0 - exp(-ROLAGEM_XP * dt))


func _checar_minuto(minuto: int) -> void:
	if minuto > _minuto_antes and minuto > 0:
		_relogio_pisca = RELOGIO_PISCA_T
	_minuto_antes = minuto


## Marco de combo: o anúncio é o mais alto que o combo cruzou neste quadro (10, 25, 50, 100 ou 200).
func _checar_marcos(antes: int, agora: int) -> void:
	var marco := -1
	for i in MARCOS.size():
		if antes < MARCOS[i] and agora >= MARCOS[i]:
			marco = i
	if marco >= 0:
		_anuncio.anunciar(NOMES_MARCOS[marco], Paleta.COMBO_MARCOS[marco], marco)


static func _cor_do_combo(combo: int) -> Color:
	var cor := Color.WHITE
	for i in MARCOS.size():
		if combo >= MARCOS[i]:
			cor = Paleta.COMBO_MARCOS[i]
	return cor


func _nivel_subiu(nivel = 0) -> void:
	brilho = BRILHO_T
	_pop_selo = POP_SELO_T
	_anel_t = ANEL_T
	_anuncio.anunciar("NÍVEL %d!" % int(nivel), Paleta.ANUNCIO_NIVEL)


func _onda_forte(_numero = 0) -> void:
	_anuncio.anunciar("ONDA FORTE!", Paleta.PERIGO)


func _elite_apareceu(_nome = "") -> void:
	_anuncio.anunciar("ELITE!", Paleta.ANUNCIO_ELITE)


func _evolucao(nome = "") -> void:
	_anuncio.anunciar("EVOLUÇÃO: %s" % str(nome).to_upper(), Paleta.OURO)


func _anuncio_livre(texto = "", cor = Color.WHITE) -> void:
	_anuncio.anunciar(str(texto), _cor_de(cor))


func _chefe_apareceu(nome = "", vida_max = 1.0) -> void:
	_chefe_visivel = true
	_chefe_max = maxf(float(vida_max), 1.0)
	_chefe_real = _chefe_max
	_chefe_fantasma = _chefe_max
	_chefe_espera = 0.0
	_chefe_nome.text = str(nome).to_upper()
	_chefe_barra.max_value = _chefe_max
	_chefe_fantasma_barra.max_value = _chefe_max
	_chefe.visible = true


func _chefe_vida(vida = 0.0) -> void:
	if not _chefe_visivel:
		return
	var nova := clampf(float(vida), 0.0, _chefe_max)
	if nova < _chefe_real:
		_chefe_espera = CHEFE_ESPERA  # levou dano: a fantasma segura um instante e depois desce
	_chefe_real = nova


## Barra de chefe: a real vai na hora; a fantasma segura e desce devagar atrás dela (chip damage). Some quando o chefe chega a zero.
func _chefe_quadro(dt: float) -> void:
	if not _chefe_visivel:
		return
	if _chefe_fantasma > _chefe_real:
		if _chefe_espera > 0.0:
			_chefe_espera = maxf(_chefe_espera - dt, 0.0)
		else:
			_chefe_fantasma = _chefe_real + (_chefe_fantasma - _chefe_real) * exp(-CHEFE_QUEDA * dt)
			if _chefe_fantasma - _chefe_real < 0.5:
				_chefe_fantasma = _chefe_real
	else:
		_chefe_fantasma = _chefe_real
	_chefe_barra.value = _chefe_real
	_chefe_fantasma_barra.value = _chefe_fantasma
	_chefe_txt.text = "%d/%d" % [roundi(_chefe_real), roundi(_chefe_max)]
	if _chefe_real <= 0.0 and _chefe_fantasma <= 0.0:
		_chefe_visivel = false
		_chefe.visible = false


## Cor de um sinal: aceita Color ou o texto de uma cor (hexadecimal ou nome). Qualquer outra coisa vira branco.
static func _cor_de(v) -> Color:
	if typeof(v) == TYPE_COLOR:
		return v
	if typeof(v) == TYPE_STRING:
		return Color.from_string(v, Color.WHITE)
	return Color.WHITE


static func _textura_vinheta() -> Texture2D:
	# Radial de borda: transparente no miolo, opaco nas bordas. Um só quadro sobre a tela, sem shader.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


## Valor de um campo do mundo ou do herói, ou null se o objeto não existe ou não tem o campo.
static func _campo(obj, nome: String) -> Variant:
	if obj == null:
		return null
	return obj.get(nome)


static func _num(obj, nome: String, padrao: float) -> float:
	var v = _campo(obj, nome)
	return padrao if v == null else float(v)
