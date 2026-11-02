extends RefCounted
## O LOBO ESPECTRAL (lore do Isac, #511): "o LightWolf é um lobo espectral; quando o golem de aço quebra, a verdadeira forma é revelada num clarão, e essa forma é mais
## frágil". SÓ VISUAL, feito em código por cima da folha lightwolf_lobo (a arte não muda) e sem tocar em número de jogo (a fragilidade já é a vida de 31%).
##  - O corpo fica meio translúcido (alfa) e com uma tinta gelo (`corpo`, aplicada por Heroi._visual no lugar do branco).
##  - Um sprite ADITIVO e sem luz, irmão do corpo (copia recorte, espelho e transformação a cada quadro), com um shader simples: contorno claro em volta da silhueta
##    (é ele que mantém o Lobo legível no chão escuro e entre os inimigos), brilho ciano por dentro que pulsa devagar e faixas claras que sobem pelo corpo (cintilação de fantasma).
##  - Fiapos de névoa que saem do Lobo, pelas partículas de v2/efeitos.gd (pool fixo: nenhuma alocação).
##  - O CLARÃO da troca (`clarao`): silhueta branco-ciano no herói (fx.flash, que já respeita Reduzir piscadas) e um flash suave de tela (fx.clarao, que obedece a
##    "Tremor e clarões" e a "Reduzir piscadas"). Desligados, sobra só o brilho no herói. Reforça o estouro que a quebra já fazia (onda, cascos, luz), não cria outro.
## Perfil Baixo (combate._perfil_baixo()): só alfa e cor do corpo; o sprite do shader fica escondido e não há névoa. Com Reduzir piscadas: brilho parado, sem cintilação.
## Desempenho: o sprite e o material nascem UMA vez (Mecha.precarregar) e são reaproveitados em todas as trocas; por quadro são só cópias de propriedades, sem nó nem
## dicionário novo (os números são lidos uma vez em `montar`). Números: dados/v2_herois.json > lightwolf_lobo > espectral (com _ajuda).

const Herois := preload("res://v2/herois.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const RECHECA_S := 0.5  # de quanto em quanto tempo relê o perfil gráfico e Reduzir piscadas (mudar no meio da luta vale em até meio segundo)

const SHADER := """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform vec4 cor_brilho : source_color = vec4(0.45, 0.88, 1.0, 1.0);
uniform float brilho = 0.5;
uniform float contorno = 1.0;
uniform float pulso_hz = 0.7;
uniform float pulso_amp = 0.3;
uniform float cintila = 0.45;
uniform float cintila_vel = 0.9;
varying vec2 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 t = texture(TEXTURE, UV);
	float viz = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float borda = clamp(viz - t.a, 0.0, 1.0);
	float lum = dot(t.rgb, vec3(0.3, 0.55, 0.15));
	float pulso = 1.0 + pulso_amp * sin(TIME * 6.2832 * pulso_hz);
	float faixa = step(0.62, fract(lp.y * 0.11 - TIME * cintila_vel));
	float fantasma = 1.0 - cintila * 0.55 * faixa;
	float corpo = t.a * (0.35 + 0.65 * lum) * brilho;
	float e = (corpo + borda * contorno) * pulso * fantasma;
	COLOR = vec4(cor_brilho.rgb * e, clamp(max(t.a, borda), 0.0, 1.0));
}
"""

var heroi
var no: Sprite2D = null  # o sprite aditivo do shader (null antes de montar)
var ativo := false  # o herói é o Lobo e o visual espectral vale
var corpo := Color.WHITE  # a tinta do corpo (rgb de cor_corpo, alfa = translucidez); Heroi._visual a põe no sprite
var baixo := false  # perfil Baixo agora: só alfa e cor
var reduz := false  # Reduzir piscadas agora: brilho parado, sem cintilação
var claroes := 0  # testes: quantos clarões de troca dispararam na partida

var _mat: ShaderMaterial = null
var _cfg: Dictionary = {}
var _clarao: Dictionary = {}
var _alfa := 0.75
var _brilho := 0.5
var _cor_brilho := Color(0.45, 0.88, 1.0)
var _pulso_hz := 0.7
var _pulso_amp := 0.3
var _cintila := 0.45
var _nevoa_s := 9.0  # fiapos por segundo
var _nevoa_vida := 0.8
var _nevoa_tam := 5.0
var _nevoa_cor := Color(0.45, 0.88, 1.0, 0.5)
var _nevoa_sobe := -26.0
var _nevoa_raio := 7.0
var _acum := 0.0  # fiapos devidos
var _reche := 0.0
var _reg := Rect2()
var _off := Vector2.ZERO
var _tex: Texture2D = null


## Lê os números e cria o sprite do shader (uma vez por herói, escondido): `raiz` é o nó nos pés do herói, `lobo_id` o registro da forma Lobo.
func montar(h, lobo_id: String) -> void:
	heroi = h
	_cfg = Herois.heroi(lobo_id).get("espectral", {})
	_clarao = _cfg.get("clarao", {})
	_alfa = float(_cfg.get("alfa", 0.75))
	var cc: Array = _cfg.get("cor_corpo", [0.82, 0.95, 1.0])
	corpo = Color(float(cc[0]), float(cc[1]), float(cc[2]), _alfa)
	_brilho = float(_cfg.get("brilho", 0.5))
	var cb: Array = _cfg.get("cor_brilho", [0.45, 0.88, 1.0])
	_cor_brilho = Color(float(cb[0]), float(cb[1]), float(cb[2]))
	_pulso_hz = float(_cfg.get("pulso_hz", 0.7))
	_pulso_amp = float(_cfg.get("pulso_amp", 0.3))
	_cintila = float(_cfg.get("cintila", 0.45))
	var n: Dictionary = _cfg.get("nevoa", {})
	_nevoa_s = float(n.get("por_s", 0.0))
	_nevoa_vida = float(n.get("vida", 0.8))
	_nevoa_tam = float(n.get("tam", 5.0))
	_nevoa_cor = Color(_cor_brilho.r, _cor_brilho.g, _cor_brilho.b, float(n.get("alfa", 0.5)))
	_nevoa_sobe = float(n.get("sobe", -26.0))
	_nevoa_raio = float(n.get("raio", 7.0))
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("contorno", float(_cfg.get("contorno", 1.0)))
	_mat.set_shader_parameter("cintila_vel", float(_cfg.get("cintila_vel", 0.9)))
	_mat.set_shader_parameter("cor_brilho", _cor_brilho)
	_mat.set_shader_parameter("pulso_hz", _pulso_hz)
	no = Sprite2D.new()
	no.name = "LoboEspectral"
	no.region_enabled = true
	no.centered = false
	no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	no.material = _mat
	no.visible = false
	h.raiz.add_child(no)  # depois do corpo (e depois do foguinho): desenha por cima dele
	_ler_perfil()


## Liga o visual espectral (o herói acabou de virar Lobo). `trocar_forma` já pôs a folha do Lobo no herói.
func ligar() -> void:
	ativo = true
	_tex = null
	_reche = 0.0
	_acum = 0.0
	_ler_perfil()
	_sincronizar(true)


## Desliga (voltou ao mecha, recomeço ou morte): o mecha não muda.
func desligar() -> void:
	ativo = false
	if no != null:
		no.visible = false


## Perfil gráfico e Reduzir piscadas de agora: decide se o sprite do shader aparece e quanto ele pulsa/cintila.
func _ler_perfil() -> void:
	var c = heroi.mundo.combate
	baixo = c != null and c._perfil_baixo()
	reduz = Piscadas.ligado()
	if _mat == null:
		return
	_mat.set_shader_parameter("brilho", _brilho)
	_mat.set_shader_parameter("pulso_amp", 0.0 if reduz else _pulso_amp)
	_mat.set_shader_parameter("cintila", 0.0 if reduz else _cintila)
	var alvo: Material = null if baixo else _mat  # no Baixo o shader nem fica ligado ao sprite
	if no.material != alvo:
		no.material = alvo
	no.visible = ativo and not baixo


## Um quadro (dt = tempo do herói): copia o recorte e a transformação do corpo para o sprite do shader e solta a névoa.
func atualizar(dt: float) -> void:
	if not ativo or no == null:
		return
	_reche -= dt
	if _reche <= 0.0 or Piscadas.ligado() != reduz:
		_reche = RECHECA_S
		_ler_perfil()
	if baixo:
		return
	_sincronizar(false)
	if _nevoa_s <= 0.0 or dt <= 0.0:
		return
	var fx = heroi.mundo.combate.fx
	_acum += dt * _nevoa_s * fx.fator_part
	while _acum >= 1.0:
		_acum -= 1.0
		var p: Vector2 = heroi.pos + Vector2(randf_range(-_nevoa_raio, _nevoa_raio), randf_range(-24.0, -4.0))
		fx.particula(
			p, Vector2(randf_range(-8.0, 8.0), randf_range(-22.0, -8.0)), _nevoa_vida * randf_range(0.7, 1.2), _nevoa_tam, _nevoa_cor, _nevoa_sobe, true
		)


func _sincronizar(forcar: bool) -> void:
	var s: Sprite2D = heroi.sprite
	var t = heroi.tipo.alb
	if forcar or t != _tex:
		_tex = t
		no.texture = t
	if forcar or s.region_rect != _reg:
		_reg = s.region_rect
		no.region_rect = _reg
	if forcar or s.offset != _off:
		_off = s.offset
		no.offset = _off
	no.flip_h = s.flip_h
	no.position = s.position
	no.scale = s.scale
	no.rotation = s.rotation


## O clarão da troca de forma: `entrando` = o mecha quebrou e o Lobo apareceu (forte); falso = o mecha caiu de volta (mais fraco). Dispara UMA vez por troca.
## A silhueta no herói vale sempre (fx.flash já vira tinta fixa e sem repetir com Reduzir piscadas); o flash de tela só acende com "Tremor e clarões" > 0 e sem Reduzir piscadas.
func clarao(entrando: bool) -> void:
	claroes += 1
	var fx = heroi.mundo.combate.fx
	var hc: Array = _clarao.get("heroi_cor", [0.88, 1.0, 1.0])
	fx.flash(heroi, float(_clarao.get("heroi_dur", 0.4)), Color(float(hc[0]), float(hc[1]), float(hc[2])), 0, float(_clarao.get("heroi_forca", 1.0)))
	var tc: Array = _clarao.get("tela_cor", [0.82, 0.97, 1.0])
	var alfa := float(_clarao.get("tela_alfa", 0.3)) if entrando else float(_clarao.get("volta_tela_alfa", 0.16))
	var dur := float(_clarao.get("tela_dur", 0.45)) if entrando else float(_clarao.get("volta_dur", 0.35))
	fx.clarao(Color(float(tc[0]), float(tc[1]), float(tc[2]), alfa), dur)
