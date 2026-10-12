extends Node
# Teste da paleta única da UI da v2 (v2/paleta.gd, lida de dados/v2_paleta.json). Roda sem janela e confere:
#  - o JSON tem uma cor RRGGBB para cada nome, 4 raridades e 5 marcos de combo; e a raridade não tem cor própria em v2_cartas.json;
#  - cada constante Paleta.NOME é a cor do JSON (o que se pinta é o que está no arquivo, sem cor que falta);
#  - nos arquivos de UI não há cor escrita à mão: nem Color("#...") nem Color(r, g, b) com número de paleta. Sobram o neutro
#    (branco, preto e cinza de 0 ou 1) e os multiplicadores (componente acima de 1), que não são cor da paleta;
#  - o gerar_molduras.py lê o mesmo JSON (as cores-base das barras e do painel não se repetem nele).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_paleta.tscn  (imprime "v2_paleta falhas=0")
const Paleta := preload("res://v2/paleta.gd")
const ARQUIVOS_UI := ["status.gd", "telas.gd", "pausa.gd", "altar.gd", "hud.gd", "hud_anuncios.gd", "resultado_meta.gd"]

var falhas := 0
var _re_cor := RegEx.new()


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	_re_cor.compile("Color\\(([^()]*)\\)")
	_json()
	_constantes()
	_sem_cor_a_mao()
	var molduras := FileAccess.get_file_as_string("res://v2/hud/gerar_molduras.py")
	ok(molduras.contains("v2_paleta.json"), "gerar_molduras.py lê dados/v2_paleta.json (a mesma fonte da UI)")
	print("v2_paleta falhas=%d" % falhas)
	get_tree().quit()


func _json() -> void:
	var d: Dictionary = Dados.json("v2_paleta")
	var hex := RegEx.new()
	hex.compile("^#[0-9a-fA-F]{6}$")
	for k in d.keys():
		if k == "_ajuda":
			continue
		var v = d[k]
		if v is Array:
			for x in v:
				ok(hex.search(str(x)) != null, "%s: '%s' não é RRGGBB" % [k, x])
		else:
			ok(hex.search(str(v)) != null, "%s: '%s' não é RRGGBB" % [k, v])
	ok(d.get("raridades", []).size() == 4, "a paleta tem 4 raridades (comum, raro, épico, lendário)")
	ok(d.get("combo_marcos", []).size() == 5, "o HUD tem 5 marcos de combo")
	for r in Dados.json("v2_cartas").get("raridades", []):
		ok(not r.has("cor"), "raridade %s não tem cor própria em v2_cartas (a cor é da paleta)" % r.id)


func _constantes() -> void:
	var d: Dictionary = Dados.json("v2_paleta")
	var pares := {
		"painel": Paleta.PAINEL,
		"cartao": Paleta.CARTAO,
		"cartao_selecionado": Paleta.CARTAO_SELECIONADO,
		"borda": Paleta.BORDA,
		"moldura": Paleta.MOLDURA,
		"moldura_escura": Paleta.MOLDURA_ESCURA,
		"moldura_apagada": Paleta.MOLDURA_APAGADA,
		"texto": Paleta.TEXTO,
		"texto_secundario": Paleta.TEXTO_SECUNDARIO,
		"cabecalho": Paleta.CABECALHO,
		"texto_apagado": Paleta.TEXTO_APAGADO,
		"foco": Paleta.FOCO,
		"valor": Paleta.VALOR,
		"ouro": Paleta.OURO,
		"alma": Paleta.ALMA,
		"dica": Paleta.DICA,
		"bonus": Paleta.BONUS,
		"divisor": Paleta.DIVISOR,
		"vida": Paleta.VIDA,
		"xp": Paleta.XP,
		"folego": Paleta.FOLEGO,
		"folego_cansado": Paleta.FOLEGO_CANSADO,
		"barra_vazia": Paleta.BARRA_VAZIA,
		"barra_borda": Paleta.BARRA_BORDA,
		"perigo": Paleta.PERIGO,
		"fusao": Paleta.FUSAO,
		"carta_apagada": Paleta.CARTA_APAGADA,
		"dano_numero": Paleta.DANO_NUMERO,
		"dano_critico": Paleta.DANO_CRITICO,
		"anuncio_elite": Paleta.ANUNCIO_ELITE,
		"anuncio_nivel": Paleta.ANUNCIO_NIVEL,
		"secao_heroi": Paleta.SECAO_HEROI,
		"secao_katana": Paleta.SECAO_KATANA,
		"secao_golpes": Paleta.SECAO_GOLPES,
		"secao_partida": Paleta.SECAO_PARTIDA,
	}
	for k in pares:
		ok(pares[k] == Color(str(d.get(k, ""))), "Paleta.%s é a cor de '%s' no JSON" % [k.to_upper(), k])
	ok(Paleta.RARIDADES.size() == 4 and Paleta.COMBO_MARCOS.size() == 5, "as listas da paleta têm o tamanho do JSON")
	for i in Paleta.RARIDADES.size():
		ok(Paleta.RARIDADES[i] == Color(str(d.raridades[i])), "raridade %d é a do JSON" % i)
	for i in Paleta.COMBO_MARCOS.size():
		ok(Paleta.COMBO_MARCOS[i] == Color(str(d.combo_marcos[i])), "marco %d do combo é o do JSON" % i)
	var meia := Paleta.alfa(Paleta.PAINEL, 0.5)
	ok(meia.a == 0.5 and meia.r == Paleta.PAINEL.r and meia.g == Paleta.PAINEL.g and meia.b == Paleta.PAINEL.b, "Paleta.alfa só troca o alfa")
	ok(Paleta.VIDA != Color.MAGENTA and Paleta.OURO != Color.MAGENTA, "a paleta carregou (magenta seria cor que falta no JSON)")


func _sem_cor_a_mao() -> void:
	for nome in ARQUIVOS_UI:
		var txt := FileAccess.get_file_as_string("res://v2/%s" % nome)
		ok(not txt.is_empty(), "%s existe" % nome)
		var em_hex := txt.count('Color("#')
		ok(em_hex == 0, "%s: %d cor em hexadecimal escrita à mão (use Paleta)" % [nome, em_hex])
		var n := 0
		for linha in txt.split("\n"):
			if linha.strip_edges().begins_with("#"):
				continue
			for m in _re_cor.search_all(linha):
				if _cor_de_paleta(m.get_string(1)):
					n += 1
		ok(n == 0, "%s: %d Color(r, g, b) com número escrita à mão (use Paleta)" % [nome, n])


## Verdadeiro se os argumentos parecem uma cor da paleta: três números de 0 a 1 que não são todos 0 ou todos 1.
func _cor_de_paleta(args: String) -> bool:
	var partes := args.split(",")
	if partes.size() < 3:
		return false
	var valores: Array[float] = []
	for i in 3:
		var s := partes[i].strip_edges()
		if not s.is_valid_float():
			return false
		var f := s.to_float()
		if f < 0.0 or f > 1.0:
			return false  # multiplicador (ex.: Color(1.8, 1.8, 1.8)), não cor da paleta
		valores.append(f)
	var cinza := valores[0] == valores[1] and valores[1] == valores[2]
	return not (cinza and (valores[0] == 0.0 or valores[0] == 1.0))  # branco, preto e cinza de 0 ou 1 são neutros; Color(1, 0, 0) não é
