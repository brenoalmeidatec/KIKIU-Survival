extends RefCounted
## Paleta única da UI da v2 (HUD, SUA BUILD, pausa, santuário, escolha de cartas, baú e resultado).
## Os valores moram em dados/v2_paleta.json (leitura pelo Dados.json). O gerar_molduras.py (v2/hud) lê o mesmo arquivo.
## Use Paleta.OURO, Paleta.VIDA etc. Cor nova entra no JSON com nome de papel e vira constante aqui.
## Teste: res://testes/v2_paleta.tscn (confere valores, nomes e cores fora da paleta nos arquivos de UI).

static var PAINEL := _cor("painel")
static var CARTAO := _cor("cartao")
static var CARTAO_SELECIONADO := _cor("cartao_selecionado")
static var BORDA := _cor("borda")
static var MOLDURA := _cor("moldura")
static var MOLDURA_ESCURA := _cor("moldura_escura")
static var MOLDURA_APAGADA := _cor("moldura_apagada")
static var TEXTO := _cor("texto")
static var TEXTO_SECUNDARIO := _cor("texto_secundario")
static var CABECALHO := _cor("cabecalho")
static var TEXTO_APAGADO := _cor("texto_apagado")
static var FOCO := _cor("foco")
static var VALOR := _cor("valor")
static var OURO := _cor("ouro")
static var ALMA := _cor("alma")
static var DICA := _cor("dica")
static var BONUS := _cor("bonus")
static var DIVISOR := _cor("divisor")
static var VIDA := _cor("vida")
static var XP := _cor("xp")
static var FOLEGO := _cor("folego")
static var FOLEGO_CANSADO := _cor("folego_cansado")
static var BARRA_VAZIA := _cor("barra_vazia")
static var BARRA_BORDA := _cor("barra_borda")
static var PERIGO := _cor("perigo")
static var FUSAO := _cor("fusao")
static var CARTA_APAGADA := _cor("carta_apagada")
static var DANO_NUMERO := _cor("dano_numero")
static var DANO_CRITICO := _cor("dano_critico")
static var ANUNCIO_ELITE := _cor("anuncio_elite")
static var ANUNCIO_NIVEL := _cor("anuncio_nivel")
static var SECAO_HEROI := _cor("secao_heroi")
static var SECAO_KATANA := _cor("secao_katana")
static var SECAO_GOLPES := _cor("secao_golpes")
static var SECAO_PARTIDA := _cor("secao_partida")
## Cor de cada raridade, na ordem de "raridades" em dados/v2_cartas.json: 0 comum, 1 raro, 2 épico, 3 lendário.
static var RARIDADES: Array[Color] = _lista("raridades")
## Marcos do combo no HUD, do 1º ao 5º (o 1º é o ouro).
static var COMBO_MARCOS: Array[Color] = _lista("combo_marcos")


## A mesma cor com outro alfa: Paleta.alfa(Paleta.PAINEL, 0.72).
static func alfa(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


static func _cor(nome: String) -> Color:
	var v = Dados.json("v2_paleta").get(nome)
	if not v is String:
		push_error("v2_paleta: falta a cor '%s' em dados/v2_paleta.json" % nome)
		return Color.MAGENTA  # magenta gritando na tela: a cor que falta aparece logo
	return Color(v)


static func _lista(nome: String) -> Array[Color]:
	var out: Array[Color] = []
	for v in Dados.json("v2_paleta").get(nome, []):
		out.append(Color(str(v)))
	return out
