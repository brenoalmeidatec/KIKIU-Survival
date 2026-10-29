extends RefCounted
## O foguinho no peito do herói (ideia do Isac, aprovada pelo Alisson em 29/10): a essência que resiste ao fim ("eu não aceito"), um brilho pequeno
## e quente que pulsa no meio do boneco. SÓ VISUAL: um Sprite2D aditivo e sem luz, filho da raiz do herói (anda com ele), sem corpo, área nem
## colisão; não toca em hitbox, dano nem física. Cor, tamanho, intensidade, pulso e posição de cada herói vêm de dados/v2_foguinho.json (tem _ajuda).
##
## Perfis gráficos (Config.g_perfil, relido no sinal graficos_mudou): Baixo é a versão barata, um sprite parado (pulsa=false: nenhuma conta por quadro);
## Médio e Alto pulsam (uma conta de seno por quadro); "ligado": false no json apaga o foguinho no perfil. Personalizado segue "Brilhos e halos".
## A textura é desenhada em código (halo suave + chama em pixel art) e guardada por cor e tamanho: nenhum arquivo de imagem.

const PADRAO := {
	"cor": [1.0, 0.52, 0.16],
	"tamanho": 13,
	"intensidade": 0.55,
	"miolo_branco": 0.55,
	"pulso_hz": 0.8,
	"pulso_amp": 0.3,
	"peito": [0, -21],
}
const PERFIL_PADRAO := {"ligado": true, "pulsa": true, "intensidade_mult": 1.0}

static var _texturas := {}

var no: Sprite2D = null  # o brilho (null antes de montar)
var _cfg := {}
var _peito := Vector2.ZERO
var _intensidade := 0.0  # já com o multiplicador do perfil
var _pulsa := false
var _t := 0.0
var _fade := 1.0  # 1 vivo, desce a 0 na dissolução do corpo
var _fator := 1.0  # o último fator do pulso (1 = sem pulso), para reaplicar o alfa quando só o _fade muda


## O nível gráfico que vale agora: "baixo", "medio", "alto" ou "desligado" (só no Personalizado com Brilhos e halos em 0%).
static func nivel() -> String:
	var p := str(Config.g_perfil())
	if p != "personalizado":
		return p
	var f := float(Config.fator_brilho())
	if f <= 0.0:
		return "desligado"
	if f <= 0.25:
		return "baixo"
	return "medio" if f <= 0.5 else "alto"


## Os números do herói `chave`: o padrão do código, coberto pelo json, coberto pelo ajuste do herói.
static func config_do_heroi(chave: String) -> Dictionary:
	var d: Dictionary = Dados.json("v2_foguinho")
	var r := PADRAO.duplicate(true)
	for k in PADRAO:
		if d.has(k):
			r[k] = d[k]
	var h: Dictionary = d.get("herois", {}).get(chave, {})
	for k in h:
		r[k] = h[k]
	r["perfis"] = d.get("perfis", {})
	return r


## Cria o brilho na raiz do herói (chamado uma vez, em Heroi.criar).
func montar(raiz: Node2D, chave: String) -> void:
	_cfg = config_do_heroi(chave)
	var c: Array = _cfg.cor
	var cor := Color(float(c[0]), float(c[1]), float(c[2]))
	var lado := maxi(5, int(_cfg.tamanho)) | 1  # ímpar: o centro cai num pixel
	no = Sprite2D.new()
	no.name = "Foguinho"
	no.texture = _textura(cor, lado, float(_cfg.miolo_branco))
	no.centered = true
	no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # aditivo: só clareia, nunca tapa o boneco
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # as luzes do cenário não tingem nem apagam o brilho
	no.material = mat
	_peito = Vector2(float(_cfg.peito[0]), float(_cfg.peito[1]))
	no.position = _peito
	raiz.add_child(no)  # depois do corpo: desenha por cima dele
	Config.graficos_mudou.connect(aplicar_perfil)
	aplicar_perfil()


## Relê o perfil gráfico: liga ou apaga o brilho, escolhe fixo ou pulsante e a intensidade.
func aplicar_perfil() -> void:
	if no == null or not is_instance_valid(no):
		return
	var n := nivel()
	var p: Dictionary = PERFIL_PADRAO.duplicate()
	if n == "desligado":
		p["ligado"] = false
	else:
		var do_json: Dictionary = _cfg.perfis.get(n, {})
		for k in do_json:
			p[k] = do_json[k]
	no.visible = bool(p.ligado)
	_pulsa = bool(p.pulsa) and no.visible
	_intensidade = clampf(float(_cfg.intensidade) * float(p.intensidade_mult), 0.0, 1.0)
	_aplicar_alfa(1.0)


## Volta ao começo de uma partida: vivo, no início do pulso.
func resetar() -> void:
	_fade = 1.0
	_t = 0.0
	aplicar_perfil()


## Segue o corpo: `desloca` é o quanto o tronco andou no golpe (px). Só escreve quando muda.
func seguir(desloca: Vector2) -> void:
	if no == null:
		return
	var p := _peito + desloca
	if no.position != p:
		no.position = p


## Um passo do pulso (no relógio do herói). Fixo (perfil Baixo) não gasta nada.
func atualizar(dt: float) -> void:
	if not _pulsa:
		return
	_t += dt
	var onda := sin(TAU * float(_cfg.pulso_hz) * _t)  # -1..1
	_aplicar_alfa(1.0 + float(_cfg.pulso_amp) * onda)


## Apaga com o corpo na morte: `f` de 1 (aceso) a 0 (sumiu).
func desvanecer(f: float) -> void:
	_fade = clampf(f, 0.0, 1.0)
	_aplicar_alfa(_fator)


func _aplicar_alfa(fator_pulso: float) -> void:
	_fator = fator_pulso
	no.modulate = Color(1, 1, 1, clampf(_intensidade * fator_pulso * _fade, 0.0, 1.0))


## Halo redondo e suave com uma chama de pixel art no meio. RGB = cor, alfa = quanto soma (modulate dá a intensidade).
static func _textura(cor: Color, lado: int, miolo_branco: float) -> Texture2D:
	var chave := "%s_%d_%.2f" % [cor.to_html(false), lado, miolo_branco]
	if _texturas.has(chave):
		return _texturas[chave]
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(cor.r, cor.g, cor.b, 0.0))
	var c := (lado - 1) / 2
	var raio := float(c) + 0.5
	for y in lado:
		for x in lado:
			var r := Vector2(x - c, y - c).length() / raio
			var a := snappedf(pow(clampf(1.0 - r, 0.0, 1.0), 2.0) * 0.5, 0.05)  # degraus: combina com o pixel art
			img.set_pixel(x, y, Color(cor.r, cor.g, cor.b, a))
	# a chama: 35% da largura e 55% da altura, ponta para cima, base arredondada
	var larg := maxi(3, roundi(lado * 0.35))
	var alt := maxi(4, roundi(lado * 0.55))
	var topo := c - alt / 2
	var claro := cor.lerp(Color.WHITE, miolo_branco)
	var borda := cor.lerp(Color.WHITE, miolo_branco * 0.35)
	for yy in alt:
		var f := (yy + 0.5) / alt  # 0 na ponta, 1 na base
		var meia := 0.5 * larg * sqrt(f) * (1.0 - 0.55 * smoothstep(0.7, 1.0, f))
		for dx in range(-c, c + 1):
			var ax := absf(dx)
			if ax > meia:
				continue
			var interno := ax <= meia * 0.45 and f > 0.35
			img.set_pixel(c + dx, topo + yy, Color(claro.r, claro.g, claro.b, 1.0) if interno else Color(borda.r, borda.g, borda.b, 0.95))
	var tex := ImageTexture.create_from_image(img)
	_texturas[chave] = tex
	return tex
