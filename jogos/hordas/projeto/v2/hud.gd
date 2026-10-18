extends CanvasLayer
## HUD da v2: vida, fôlego, XP com selo de nível, tempo, abates, monstros vivos, combo, brilho do nível novo, a faixa de anúncio
## (centro alto), a barra de chefe com fantasma e a vinheta de vida baixa.
## Fica numa CanvasLayer (layer 10) dentro do SubViewport da interface (mundo.ui): pixel art na resolução da UI (o sharp bilinear
## escala a UI inteira), fonte PressStart2P sem anti-aliasing e sem hinting, e light_mask 0 para a luz do mundo não tocar nele.
## Lê o mundo com get() e valor padrão: sem combate mostra vida cheia, XP 0 e nível 1. Campos lidos: em mundo.heroi, vida, vida_max,
## xp, xp_proximo, nivel, folego, folego_max, cansado (bool, padrão false: a barra de fôlego pisca); em mundo, abates, combo,
## tempo_partida (segundos), monstros_vivos. Sinais do mundo, cada um ligado só se o mundo tiver: nivel_subiu(nivel),
## onda_forte(numero), elite_apareceu(nome), chefe_apareceu(nome, vida_max), chefe_vida(vida), evolucao(nome), anuncio(texto, cor).
## Slot da ruptura (tecla E) logo abaixo da barra de fôlego, desenhado por código (sem PNG): lê em mundo.heroi, com padrão, rup_carga (0 a 1),
## rup_recarga, rup_recarga_max, rup_perfeita, rup_nega_t, contragolpe_t e contragolpe_max. Herói sem esses campos (mundo falso dos testes): o slot some.
## Faixa de GOLPES (canto inferior esquerdo, v2/hud_golpes.gd): um quadradinho fixo por golpe automático ganho, com nível, recarga e progresso da fusão.
## Lê mundo.combate.armas.ativas e mundo.combate.cartas; mundo sem combate (falso dos testes): a faixa some.
## Uso no mundo (uma linha no _ready):
##   ui.add_child(preload("res://v2/hud.gd").criar(self))
## Layout em v2/hud.tscn (coordenadas do bloco 960x540, que fica no centro do canvas da UI: v2/escala_ui.gd). Cada peça tem uma âncora
## (ANCORAS): a de canto/borda gruda no canvas (cima, baixo, esquerda), não no bloco, para o HUD não flutuar longe da borda quando a
## interface é menor que a janela. O canto superior direito fica livre para o minimapa.

const Paleta := preload("res://v2/paleta.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const Herois := preload("res://v2/herois.gd")
const CENA := "res://v2/hud.tscn"
const SPRITES := "res://prototipos/cara_nova/sprites/"
const FONTE := "res://assets/fonte/PressStart2P.ttf"
const OURO := Paleta.OURO
const PULSO_T := 0.25  # segundos do pulso do combo a cada abate
const BRILHO_T := 1.2  # segundos do brilho da barra de XP ao subir de nível
const SALTO_PX := 4  # quantos pixels o combo sobe no pulso
const BRILHO_XP := Color(1.7, 1.5, 0.9)  # multiplicador de cor no pico do brilho: a barra e o selo clareiam para o dourado
const PISCA_CANSADO := Paleta.FOLEGO_CANSADO
const LIMIAR_VIDA_BAIXA := 0.25  # abaixo de 25% da vida: vinheta vermelha e barra de vida piscando
const PISCA_VIDA := Paleta.VIDA_PISCA
const VERMELHO_VINHETA := Paleta.PERIGO
const VINHETA_MAX := 0.7  # opacidade máxima da vinheta (ela pulsa um pouco abaixo disso)
const POP_SELO_T := 0.3  # segundos do pop do selo ao subir de nível
const ANEL_T := 0.5  # segundos do anel de luz que sai do selo
const RELOGIO_PISCA_T := 0.8  # o tempo pisca dourado 0,8 s a cada minuto sobrevivido
const ROLAGEM_XP := 9.0  # quão rápido o número das almas rola até o valor da barra de XP
const CHEFE_ESPERA := 0.35  # segundos que a fantasma espera antes de descer atrás da barra real
const CHEFE_QUEDA := 1.2  # quão rápido a fantasma desce atrás da real (fração da diferença por segundo)
const COR_ONDA := Paleta.PERIGO
const COR_ELITE := Paleta.ANUNCIO_ELITE
const COR_NIVEL := Paleta.ANUNCIO_NIVEL
const RB_POS := Vector2(54, 40)  # o slot da ruptura (hoje escondido por hud_habilidades.gd): 22x22, logo abaixo da moldura das barras (y 6 a 36)
const PESADELO_POS := Vector2(540.0, 10.0)  # o aviso PESADELO, ao lado do relógio
const RB_TAM := 22
const RB_POP_T := 0.15  # s do pop ao zerar a recarga
const RB_LARANJA := Paleta.CARGA_LARANJA
const RB_BORDA := Paleta.RUPTURA_BORDA
## Comprimento das barras de vida e de fôlego. No máximo de partida do herói escolhido (cfg do combate) a barra mede BARRA_BASE_PX;
## cada ponto de vida máxima acima da base soma BARRA_PX_VIDA px, e cada carga de fôlego, BARRA_PX_FOLEGO. O teto (BARRA_TETO_PX)
## segura a moldura antes do relógio (x 428). Ver _barras.
const BARRA_BASE_PX := 142.0
const BARRA_PX_VIDA := 1.2
const BARRA_PX_FOLEGO := 47.0
const BARRA_TETO_PX := 320.0
const BARRA_MIN_PX := 64.0  # cabe "999/999" em Press Start 2P de 8 px (56 px)
const BARRA_FOLGA := 4.0  # a moldura de pedra fica 4 px fora de cada lado da barra de vida
const BARRA_VELOC := 7.0  # quão rápido a barra desliza até o comprimento novo (suavização exponencial, por segundo)
const BASE_VIDA := 100.0  # sem combate (mundo falso dos testes)
const BASE_FOLEGO := 3.0
## Onde cada peça do HUD gruda: -1 = na borda esquerda/de cima do canvas, +1 = na direita/de baixo, 0 = fica no meio (centro do bloco).
const ANCORAS := {
	"Retrato": Vector2(-1, -1),
	"Vida": Vector2(-1, -1),
	"Folego": Vector2(-1, -1),
	"MolduraBarras": Vector2(-1, -1),
	"Tempo": Vector2(0, -1),
	"Abates": Vector2(0, -1),
	"Chefe": Vector2(0, -1),
	"Xp": Vector2(0, 1),
	"Selo": Vector2(0, 1),
	"Anel": Vector2(0, 1),
	"Habilidades": Vector2(0, 1),
	"Golpes": Vector2(-1, 1),  # faixa de golpes: canto inferior esquerdo do canvas, não do bloco (senão flutua sobre o campo)
}
const MARCOS := [10, 25, 50, 100, 200]
const NOMES_MARCOS := ["SEQUÊNCIA!", "CARNIFICINA!", "MASSACRE!", "IMPARÁVEL!", "LENDÁRIO!"]
const CORES_MARCOS := Paleta.COMBO_MARCOS
const FUSAO_T := 2.0  # s que o cartão grande da fusão fica na tela (com a saída de 0,4 s no fim)
const FUSAO_L := 600.0  # largura do cartão da fusão (espaço de 960 px da tela)
const FUSAO_A := 200.0
const FUSAO_X := 180.0
const FUSAO_Y := 150.0
const MOLDURA_FUSAO := preload("res://assets/v2/fusoes/moldura.png")  # 600 x 200 em 9-slice: a borda tem 12 px, o miolo estica
const MOLDURA_BORDA := 12
const HALO_FUSAO := preload("res://assets/v2/fusoes/halo.png")  # halo branco 48 x 48, tingido pela cor da fusão
const ICONE_FUSAO := preload("res://assets/v2/fusoes/icone.png")  # junção de duas setas, 16 x 16, mostrada em 2x
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
var _fusao: Control  # o cartão grande da fusão (montado na primeira fusão)
var _selo_pesadelo: Label  # "PESADELO" ao lado do relógio (modo do santuário)
var _fusao_nome: Label
var _fusao_desc: Label
var _fusao_tween: Tween
var _fusao_halos: Array = []  # os dois halos do cartão da fusão (tingidos pela cor dela)
var _combo_y := 0.0
var _bases := {}  # nome da peça -> posição do .tscn (no bloco), antes da âncora
var _combo_y0 := 0.0
var _desl := Vector2.ZERO  # deslocamento do bloco no canvas (EscalaUi.desloc_atual)
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
# slot da ruptura: o que foi desenhado por último (só redesenha quando muda)
var _rb: Control = null
var _ult: Control = null  # o slot do ULTIMATE (tecla Q): reservado, vazio, sem mecânica ainda
var _rb_chave := ""
var _rb_barra := 0  # px da barra de carga (0 a 20)
var _rb_cortina := 0  # px da cortina da recarga (0 a 20)
var _rb_contra := 0  # px da faísca do contragolpe (0 a 20)
var _rb_pronta := true
var _rb_perf := false  # moldura piscando em branco (janela perfeita)
var _rb_nega := false  # moldura vermelha
var _rb_pop := 0.0
var _rb_recarga_antes := 0.0
var _vida_px := -1.0  # comprimento atual da barra de vida (desliza até o alvo em _barras); -1 até o primeiro quadro
var _folego_px := -1.0  # o mesmo, para a barra de fôlego

@onready var _heroi_img: TextureRect = $Raiz/Retrato/Heroi
@onready var _vida_barra: TextureProgressBar = $Raiz/Vida/Barra
@onready var _vida_txt: Label = $Raiz/Vida/Texto
@onready var _folego: TextureProgressBar = $Raiz/Folego
@onready var _vida_caixa: Control = $Raiz/Vida
@onready var _moldura_barras: NinePatchRect = $Raiz/MolduraBarras
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
	_combo_y0 = _combo_y
	for nome in ANCORAS:
		_bases[nome] = (get_node("Raiz/" + nome) as Control).position
	_combo_num.pivot_offset = Vector2(100, 13)
	_selo.pivot_offset = Vector2(12, 12)
	_anel.pivot_offset = Vector2(10, 10)
	_vinheta.texture = _textura_vinheta()
	_vinheta.visible = false
	_retrato_do_heroi()
	_criar_slot_ruptura()
	_criar_selo_pesadelo()
	EscalaUi.cobrir(_vinheta)
	add_to_group("ui_escala")
	ui_reencaixar(EscalaUi.canvas_atual, EscalaUi.desloc_atual)


## A janela ou a opção "tamanho_ui" mudou: cada peça volta para a sua âncora no canvas novo. O combo e o anúncio (que se mexem sozinhos)
## recebem só o deslocamento de cima; o slot da ruptura anda com as barras (canto de cima à esquerda).
func ui_reencaixar(_canvas: Vector2, d: Vector2) -> void:
	_desl = d
	for nome in ANCORAS:
		var no := get_node_or_null("Raiz/" + nome) as Control
		if no == null:
			continue
		var a: Vector2 = ANCORAS[nome]
		if nome == "Habilidades":
			no.deslocar(a * d)
		else:
			no.position = (_bases[nome] as Vector2) + a * d
	_combo_y = _combo_y0 - d.y
	_anuncio.ancorar(-d.y)
	if _selo_pesadelo != null:
		_selo_pesadelo.position = PESADELO_POS + Vector2(0.0, -d.y)
	if _rb != null:
		_rb.position = RB_POS - d
	if _ult != null:
		_ult.position = RB_POS + Vector2(RB_TAM + 4, 0) - d


## O retrato: o quadro parado do herói da partida (linha "baixo", coluna "parado" da folha), sem filtro, dentro da moldura de pedra.
## Sem a folha ou sem o json, o retrato fica vazio (só moldura e fundo).
func _retrato_do_heroi() -> void:
	var base := SPRITES + Herois.sprite(Herois.escolhido())
	var folha := load(base + "_albedo.png") as Texture2D
	if folha == null or not FileAccess.file_exists(base + ".json"):
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if not info is Dictionary or not info.has("quadro"):
		return
	var quadro := Vector2(float(info.quadro[0]), float(info.quadro[1]))
	var recorte := AtlasTexture.new()
	recorte.atlas = folha
	recorte.region = Rect2(Vector2.ZERO, quadro)
	_heroi_img.texture = recorte
	_heroi_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_heroi_img.size = quadro


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
	var folego_max := maxf(_num(h, "folego_max", BASE_FOLEGO), 1.0)
	_folego.max_value = folego_max
	_folego.value = clampf(_num(h, "folego", folego_max), 0.0, folego_max)
	# Herói cansado (corrida no Shift esgotou o fôlego): a barra pisca em vermelho até recuperar.
	var cansado: bool = _campo(h, "cansado") == true
	_piscada = _piscada + dt if cansado else 0.0
	var pisca: bool = cansado and int(_piscada * 6.0) % 2 == 0
	_folego.modulate = PISCA_CANSADO if pisca else Color.WHITE
	var xp_prox := maxf(_num(h, "xp_proximo", 100.0), 1.0)
	var xp_alvo := clampf(_num(h, "xp", 0.0), 0.0, xp_prox)
	_xp_mostrado = _rolar_xp(xp_alvo, dt)
	_xp_barra.max_value = xp_prox
	_xp_barra.value = _xp_mostrado
	_xp_txt.text = "%d/%d" % [roundi(_xp_mostrado), roundi(xp_prox)]
	_selo_num.text = str(roundi(_num(h, "nivel", 1.0)))
	_selo_pesadelo.visible = mundo != null and mundo.has_method("pesadelo") and mundo.pesadelo()
	var tempo := maxf(_num(mundo, "tempo_partida", 0.0), 0.0)
	_relogio.text = "%02d:%02d" % [int(tempo) / 60, int(tempo) % 60]
	_checar_minuto(int(tempo) / 60)
	var abates := roundi(_num(mundo, "abates", 0.0))
	var combo := roundi(_num(mundo, "combo", 0.0))
	_abates.text = "ABATES %d\nVIVOS %d" % [abates, roundi(_num(mundo, "monstros_vivos", 0.0))]
	var cartas_na_tela := _cartas_na_tela()  # a escolha e o baú ocupam a tela toda: a HUD inteira some (volta ao fechar), sem misturar com os botões
	visible = not cartas_na_tela
	_barras(0.0 if cartas_na_tela else dt, vida_max, folego_max, _base_barras())  # sem correr com a HUD escondida: a barra cresce quando ela volta
	_combo.visible = combo > 0 and not cartas_na_tela
	_combo_num.text = "x%d" % combo
	_checar_marcos(_combo_antes, combo)
	if abates > _abates_antes or combo > _combo_antes:
		pulso = PULSO_T
	_abates_antes = abates
	_combo_antes = combo
	_cor_base = _cor_do_combo(combo)
	_chefe_quadro(dt)
	_ruptura(dt, h)
	_animar(dt)
	_anuncio.avancar(dt)
	_anuncio.visible = _anuncio.texto_ativo != "" and not cartas_na_tela


## O aviso PESADELO, ao lado do relógio: só aparece quando a partida é no modo Pesadelo (mundo.pesadelo()).
func _criar_selo_pesadelo() -> void:
	_selo_pesadelo = Label.new()
	_selo_pesadelo.text = "PESADELO"
	_selo_pesadelo.position = PESADELO_POS
	_selo_pesadelo.add_theme_font_override("font", Dados.fonte_titulo)
	_selo_pesadelo.add_theme_font_size_override("font_size", 20)
	_selo_pesadelo.add_theme_color_override("font_color", VERMELHO_VINHETA)
	_selo_pesadelo.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_selo_pesadelo.add_theme_constant_override("outline_size", 4)
	_selo_pesadelo.light_mask = 0
	_selo_pesadelo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selo_pesadelo.visible = false
	$Raiz.add_child(_selo_pesadelo)


## O slot da ruptura: um Control criado aqui (o laço de _ready que zera luz e mouse já rodou, então zera de novo).
func _criar_slot_ruptura() -> void:
	_rb = Control.new()
	_rb.name = "SlotRuptura"
	_rb.position = RB_POS
	_rb.size = Vector2(RB_TAM, RB_TAM)
	_rb.pivot_offset = Vector2(RB_TAM, RB_TAM) / 2.0
	_rb.light_mask = 0
	_rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rb.visible = false
	_rb.draw.connect(_desenhar_slot)
	$Raiz.add_child(_rb)
	_ult = Control.new()
	_ult.name = "SlotUltimate"
	_ult.position = RB_POS + Vector2(RB_TAM + 4, 0)
	_ult.size = Vector2(RB_TAM, RB_TAM)
	_ult.light_mask = 0
	_ult.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult.visible = false
	_ult.draw.connect(_desenhar_ultimate)
	$Raiz.add_child(_ult)


## Um quadro do slot: lê o herói, anima (pop, tremida) e pede redesenho só se algo mudou. Sem os campos da ruptura no herói, esconde.
func _ruptura(dt: float, h) -> void:
	if _rb == null:
		return
	var tem: bool = h != null and _campo(h, "rup_carga") != null
	if _rb.visible != tem:
		_rb.visible = tem
		_ult.visible = tem
		_ult.queue_redraw()
	if not tem:
		return
	var f := clampf(_num(h, "rup_carga", 0.0), 0.0, 1.0)
	var rec := maxf(_num(h, "rup_recarga", 0.0), 0.0)
	var rec_max := maxf(_num(h, "rup_recarga_max", 1.0), 0.001)
	var nega := maxf(_num(h, "rup_nega_t", 0.0), 0.0)
	var contra := maxf(_num(h, "contragolpe_t", 0.0), 0.0)
	var contra_max := maxf(_num(h, "contragolpe_max", 1.5), 0.001)
	if _rb_recarga_antes > 0.0 and rec <= 0.0:
		_rb_pop = RB_POP_T
	_rb_recarga_antes = rec
	_rb_pop = maxf(_rb_pop - dt, 0.0)
	var treme := 0.0
	if nega > 0.0:  # apertou na recarga: treme 2 px
		treme = 2.0 if int(nega * 40.0) % 2 == 0 else -2.0
	_rb.position = RB_POS - _desl + Vector2(treme, 0.0)
	_rb.scale = Vector2.ONE * (1.0 + roundf(3.0 * _rb_pop / RB_POP_T) / 10.0)  # 1,3 para 1,0 em degraus de pixel art
	_rb_pronta = rec <= 0.0
	_rb_barra = roundi(f * 20.0)
	_rb_cortina = ceili(rec / rec_max * 20.0) if rec > 0.0 else 0
	_rb_contra = ceili(contra / contra_max * 20.0) if contra > 0.0 else 0
	_rb_perf = _campo(h, "rup_perfeita") == true and int(Time.get_ticks_msec() / 50.0) % 2 == 0
	_rb_nega = nega > 0.0
	var chave := "%d|%d|%d|%s|%s|%s" % [_rb_barra, _rb_cortina, _rb_contra, _rb_pronta, _rb_perf, _rb_nega]
	if chave != _rb_chave:
		_rb_chave = chave
		_rb.queue_redraw()


func _desenhar_slot() -> void:
	var s := float(RB_TAM)
	_rb.draw_rect(Rect2(0, 0, s, s), Color(Paleta.HABILIDADE_FUNDO, 0.85))
	var borda := RB_BORDA
	if _rb_nega:
		borda = Paleta.PERIGO
	elif _rb_perf:
		borda = Color.WHITE
	_moldura(Rect2(0, 0, s, s), borda)
	# a tecla da habilidade: a letra E (7x9 px)
	var tecla := RB_LARANJA if _rb_pronta else Paleta.TECLA_APAGADA
	_rb.draw_rect(Rect2(7, 5, 2, 9), tecla)
	_rb.draw_rect(Rect2(9, 5, 5, 2), tecla)
	_rb.draw_rect(Rect2(9, 8, 4, 2), tecla)
	_rb.draw_rect(Rect2(9, 12, 5, 2), tecla)
	# recarga: cortina escura do topo para baixo, a fração que falta
	if _rb_cortina > 0:
		_rb.draw_rect(Rect2(1, 1, s - 2.0, float(_rb_cortina)), Color(0.0, 0.0, 0.0, 0.7))
		if _rb_cortina < 20:
			_rb.draw_rect(Rect2(1, 1 + _rb_cortina, s - 2.0, 1), Color(Paleta.RECARGA_BORDA, 0.8))  # a borda da cortina: a varredura se lê
	# carga: barra vertical de 3 px na borda direita, de baixo para cima, de laranja a branco, com marcas em 25, 50 e 75%
	_rb.draw_rect(Rect2(18, 1, 3, 20), Color(0.0, 0.0, 0.0, 0.5))
	if _rb_barra > 0:
		_rb.draw_rect(Rect2(18, 21 - _rb_barra, 3, _rb_barra), RB_LARANJA.lerp(Color.WHITE, float(_rb_barra) / 20.0))
		for marca in [5, 10, 15]:
			_rb.draw_rect(Rect2(18, 21 - marca, 3, 1), Color(Paleta.CARGA_MARCA, 0.9))
	# contragolpe aberto: faísca laranja de 1 px na borda de cima
	if _rb_contra > 0:
		_rb.draw_rect(Rect2(1, 0, float(_rb_contra), 1), Paleta.CONTRAGOLPE)


## O slot do ultimate (Q): moldura apagada e a letra Q, sem barra nem recarga (a mecânica ainda não existe).
func _desenhar_ultimate() -> void:
	var s := float(RB_TAM)
	var apagado := Paleta.HABILIDADE_DESATIVADA
	_ult.draw_rect(Rect2(0, 0, s, s), Color(Paleta.HABILIDADE_FUNDO, 0.6))
	_ult.draw_rect(Rect2(0, 0, s, 1), apagado)
	_ult.draw_rect(Rect2(0, s - 1, s, 1), apagado)
	_ult.draw_rect(Rect2(0, 1, 1, s - 2), apagado)
	_ult.draw_rect(Rect2(s - 1, 1, 1, s - 2), apagado)
	_ult.draw_rect(Rect2(6, 5, 8, 2), apagado)  # o Q: aro de 8x8 com o rabo
	_ult.draw_rect(Rect2(6, 12, 8, 2), apagado)
	_ult.draw_rect(Rect2(6, 7, 2, 5), apagado)
	_ult.draw_rect(Rect2(12, 7, 2, 5), apagado)
	_ult.draw_rect(Rect2(11, 12, 4, 4), apagado)


## Contorno de 1 px em retângulos cheios (draw_rect sem preencher borra em coordenada inteira). `redondo` corta os quatro cantos.
func _moldura(r: Rect2, cor: Color, redondo := false) -> void:
	var c := 1.0 if redondo else 0.0
	_rb.draw_rect(Rect2(r.position.x + c, r.position.y, r.size.x - 2.0 * c, 1), cor)
	_rb.draw_rect(Rect2(r.position.x + c, r.end.y - 1, r.size.x - 2.0 * c, 1), cor)
	_rb.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), cor)
	_rb.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), cor)


## Verdadeiro com a escolha de carta ou o baú abertos (telas.gd). Sem combate no mundo (testes), é falso.
func _cartas_na_tela() -> bool:
	var telas = _campo(_campo(mundo, "combate"), "telas")
	return _campo(telas, "escolha_aberta") == true or _campo(telas, "bau_aberto") == true


## Comprimento das barras (ver BARRA_*). O alvo segue o máximo atual; o comprimento desliza até ele com dt (suavização exponencial).
## Com a escolha de carta ou o baú na tela, dt vem 0 e a barra fica parada: cresce quando a HUD volta. A moldura de pedra acompanha o
## maior dos dois. Tudo por size: a posição já anda com o deslocamento do bloco no canvas (ui_reencaixar).
func _barras(dt: float, vida_max: float, folego_max: float, base: Vector2) -> void:
	var alvo_vida := clampf(BARRA_BASE_PX + BARRA_PX_VIDA * (vida_max - base.x), BARRA_MIN_PX, BARRA_TETO_PX)
	var alvo_folego := clampf(BARRA_BASE_PX + BARRA_PX_FOLEGO * (folego_max - base.y), BARRA_MIN_PX, BARRA_TETO_PX)
	if _vida_px < 0.0:  # primeiro quadro com o herói: começa no tamanho certo, sem animação de entrada
		_vida_px = alvo_vida
		_folego_px = alvo_folego
	var k := 1.0 - exp(-BARRA_VELOC * dt)
	_vida_px = _deslizar(_vida_px, alvo_vida, k)
	_folego_px = _deslizar(_folego_px, alvo_folego, k)
	_vida_barra.size.x = roundf(_vida_px)
	_vida_txt.size.x = roundf(_vida_px)
	_folego.size.x = roundf(_folego_px)
	var moldura := roundf(maxf(_vida_px, _folego_px) + 2.0 * BARRA_FOLGA)
	_vida_caixa.size.x = moldura
	_moldura_barras.size.x = moldura


## Um passo da suavização. Com k 0 não se mexe (HUD escondida); perto do alvo, meio px, cola nele para o pixel parar de tremer.
static func _deslizar(atual: float, alvo: float, k: float) -> float:
	if k <= 0.0:
		return atual
	if absf(alvo - atual) < 0.5:
		return alvo
	return lerpf(atual, alvo, k)


## Base da barra: a vida e o fôlego de partida do herói escolhido, o mesmo cfg do combate que o meta.gd soma os bônus por cima.
## Sem combate (mundo falso dos testes), os padrões.
func _base_barras() -> Vector2:
	var cfg = _campo(_campo(mundo, "combate"), "cfg")
	return Vector2(_num(_campo(cfg, "heroi"), "vida", BASE_VIDA), _num(_campo(cfg, "folego"), "max", BASE_FOLEGO))


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
	_relogio.modulate = Color.WHITE.lerp(OURO, roundf(4.0 * _relogio_pisca / RELOGIO_PISCA_T) / 4.0)


## Vida baixa (abaixo de 25%): a barra de vida pisca e a vinheta vermelha pulsa nas bordas. A vinheta entra e sai aos poucos.
func _vida_baixa(dt: float, fracao: float) -> void:
	var baixa := fracao < LIMIAR_VIDA_BAIXA
	_pisca_vida = _pisca_vida + dt if baixa else 0.0
	_tempo_vinheta = _tempo_vinheta + dt if baixa else 0.0
	var pisca := baixa and int(_pisca_vida * 5.0) % 2 == 0
	_vida_barra.modulate = PISCA_VIDA if pisca else Color.WHITE
	var alvo := 0.0
	if baixa:
		alvo = VINHETA_MAX * (0.75 + 0.25 * sin(_tempo_vinheta * 7.0))
	vinheta_alfa = move_toward(vinheta_alfa, alvo, dt * 3.0)
	_vinheta.modulate = Color(VERMELHO_VINHETA.r, VERMELHO_VINHETA.g, VERMELHO_VINHETA.b, vinheta_alfa)
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
		_anuncio.anunciar(NOMES_MARCOS[marco], CORES_MARCOS[marco], marco)


static func _cor_do_combo(combo: int) -> Color:
	var cor := Color.WHITE
	for i in MARCOS.size():
		if combo >= MARCOS[i]:
			cor = CORES_MARCOS[i]
	return cor


func _nivel_subiu(nivel = 0) -> void:
	brilho = BRILHO_T
	_pop_selo = POP_SELO_T
	_anel_t = ANEL_T
	_anuncio.anunciar("NÍVEL %d!" % int(nivel), COR_NIVEL)


func _onda_forte(_numero = 0) -> void:
	_anuncio.anunciar("ONDA FORTE!", COR_ONDA)


func _elite_apareceu(_nome = "") -> void:
	_anuncio.anunciar("ELITE!", COR_ELITE)


## A fusão: além da faixa pequena, um cartão grande no centro com o nome e o que a arma faz. É o momento que o jogador precisa LER,
## então a fonte é a de título (Jersey 10) e o texto corrido é o da Spleen 8x16 em 16 px. Só uma tween (sem nó por quadro).
func _evolucao(nome = "", desc = "") -> void:
	_anuncio.anunciar("EVOLUÇÃO: %s" % str(nome).to_upper(), OURO)
	_mostrar_fusao(str(nome), str(desc), _cor_fusao(str(nome)))


## A cor da fusão é o campo cor da evolução em dados/v2_cartas.json (o halo sai nessa cor); sem ele, o magenta da fusão.
func _cor_fusao(nome: String) -> Color:
	for e in Dados.json("v2_cartas").get("evolucoes", []):
		if str(e.get("nome", "")) == nome and e.get("cor") is Array:
			var c: Array = e.cor
			return Color(float(c[0]), float(c[1]), float(c[2]))
	return Paleta.FUSAO


func _mostrar_fusao(nome: String, desc: String, cor: Color) -> void:
	if _fusao == null:
		_montar_fusao()
	for halo in _fusao_halos:
		halo.modulate = Color(cor.r, cor.g, cor.b, 0.9)
	_fusao_nome.text = nome.to_upper()
	_fusao_desc.text = desc
	_fusao.modulate.a = 1.0
	_fusao.scale = Vector2.ONE * 1.25
	_fusao.visible = true
	if _fusao_tween != null:
		_fusao_tween.kill()
	_fusao_tween = create_tween()
	_fusao_tween.tween_property(_fusao, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fusao_tween.tween_interval(FUSAO_T - 0.6)
	_fusao_tween.tween_property(_fusao, "modulate:a", 0.0, 0.4)
	_fusao_tween.tween_callback(_fusao.hide)


func _montar_fusao() -> void:
	_fusao = Control.new()
	_fusao.position = Vector2(FUSAO_X, FUSAO_Y)
	_fusao.size = Vector2(FUSAO_L, FUSAO_A)
	_fusao.pivot_offset = _fusao.size * 0.5
	_fusao.visible = false
	var fundo := NinePatchRect.new()  # a moldura de pedra e ouro em 9-slice: o miolo liso já está no PNG
	fundo.texture = MOLDURA_FUSAO
	fundo.patch_margin_left = MOLDURA_BORDA
	fundo.patch_margin_top = MOLDURA_BORDA
	fundo.patch_margin_right = MOLDURA_BORDA
	fundo.patch_margin_bottom = MOLDURA_BORDA
	fundo.size = _fusao.size
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fusao.add_child(fundo)
	_fusao.add_child(_rotulo(Dados.fonte_titulo, 56, OURO, 12.0, 64.0, "FUSÃO!"))
	for x in [46.0, 506.0]:  # um de cada lado do título: o halo da fusão e o ícone de junção
		var halo := TextureRect.new()
		halo.texture = HALO_FUSAO
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.stretch_mode = TextureRect.STRETCH_SCALE
		halo.position = Vector2(x, 20.0)
		halo.size = Vector2(48.0, 48.0)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fusao.add_child(halo)
		_fusao_halos.append(halo)
		var icone := TextureRect.new()
		icone.texture = ICONE_FUSAO
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_SCALE
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.position = Vector2(x + 8.0, 28.0)
		icone.size = Vector2(32.0, 32.0)
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fusao.add_child(icone)
	_fusao_nome = _rotulo(Dados.fonte_titulo, 37, Color(1.0, 0.95, 0.8), 80.0, 44.0, "")
	_fusao.add_child(_fusao_nome)
	_fusao_desc = _rotulo(Dados.fonte_texto, 16, Color(0.88, 0.9, 1.0), 132.0, 60.0, "", true)
	_fusao_desc.position.x = MOLDURA_BORDA + 16.0  # o texto corrido fica dentro da borda de 12 px, com folga
	_fusao_desc.size.x = FUSAO_L - 2.0 * (MOLDURA_BORDA + 16.0)
	_fusao.add_child(_fusao_desc)
	$Raiz.add_child(_fusao)


func _rotulo(fonte: Font, tam: int, cor: Color, y: float, altura: float, texto: String, quebra := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 4 if tam > 16 else 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF
	l.position = Vector2(0.0, y)
	l.size = Vector2(FUSAO_L, altura)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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
